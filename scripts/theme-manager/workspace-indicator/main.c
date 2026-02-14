/*
 * workspace-indicator — Minimal workspace OSD for Hyprland
 *
 * Displays a macOS-style frosted pill with dot indicators at bottom-centre.
 * Auto-triggers on workspace switch (Hyprland IPC); manual peek via SIGUSR1.
 * Reads theme colours from the active hyprland-palette.conf at startup.
 *
 * Build:   make
 * Install: make install
 * Deps:    gtk+-3.0  gtk-layer-shell-0
 */

#define _GNU_SOURCE
#include <cairo.h>
#include <ctype.h>
#include <fcntl.h>
#include <gtk-layer-shell.h>
#include <glib-unix.h>
#include <gtk/gtk.h>
#include <math.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

/* ── Tunables ────────────────────────────────────────────────────── */
enum {
    DISPLAY_MS    = 1200,   /* visible hold duration                 */
    FADE_IN_MS    = 150,    /* fade-in animation                     */
    FADE_OUT_MS   = 300,    /* fade-out animation                    */
    DEBOUNCE_MS   = 80,     /* coalesce rapid workspace switches     */
    MARGIN_BOTTOM = 60,     /* px from bottom edge                   */
    DOT_SPACING   = 20,     /* centre-to-centre between dots         */
    PAD_H         = 24,     /* horizontal pill padding               */
    PAD_V         = 14,     /* vertical pill padding                 */
    PERSISTENT_WS = 5,      /* always-visible workspace slots        */
    MAX_WS        = 10,     /* hard cap on shown dots                */
    BUF_SZ        = 4096,
};

static const double DOT_R    = 4.0;   /* inactive-dot radius  */
static const double ACTIVE_R = 5.5;   /* active-dot radius    */

/* ── RGBA colour ─────────────────────────────────────────────────── */
typedef struct { double r, g, b, a; } RGBA;

/* Fallback colours (Catppuccin Mocha) — overridden by palette load  */
static RGBA col_bg      = { 0.118, 0.118, 0.180, 0.75 };
static RGBA col_active  = { 0.537, 0.705, 0.980, 1.00 };
static RGBA col_fg      = { 0.804, 0.839, 0.957, 0.55 };
static RGBA col_dim     = { 0.576, 0.600, 0.698, 0.25 };

/* ── Runtime state ───────────────────────────────────────────────── */
static int        cur_ws    = 1;
static gboolean   occ[MAX_WS + 1];   /* 1-indexed occupancy flags */
static int        occ_max   = 0;

static GtkWidget *win;
static GtkWidget *da;                 /* drawing area */
static double     opacity   = 0.0;
static guint      tid_hide  = 0;      /* hide-delay timer */
static guint      tid_fade  = 0;      /* fade-step  timer */
static guint      tid_dbnc  = 0;      /* debounce   timer */

/* ── Theme palette loader ────────────────────────────────────────── */

static RGBA hex8_to_rgba(const char *hex)
{
    unsigned r = 0, g = 0, b = 0, a = 0xFF;
    sscanf(hex, "%2x%2x%2x%2x", &r, &g, &b, &a);
    return (RGBA){ r / 255.0, g / 255.0, b / 255.0, a / 255.0 };
}

/*
 * Read ~/.config/current/theme/hyprland-palette.conf
 * Lines: $name = rgba(RRGGBBAA)
 * Map standard names to our indicator colours.
 */
static void load_palette(void)
{
    const char *xdg = g_get_user_config_dir();
    char path[512];
    g_snprintf(path, sizeof path,
               "%s/current/theme/hyprland-palette.conf", xdg);

    FILE *f = fopen(path, "r");
    if (!f) {
        g_message("workspace-indicator: no palette at %s, using fallback", path);
        return;
    }

    char line[256];
    while (fgets(line, sizeof line, f)) {
        char name[64], hex[9];
        if (sscanf(line, " $%63[a-zA-Z_] = rgba(%8[0-9a-fA-F])", name, hex) != 2)
            continue;

        RGBA c = hex8_to_rgba(hex);

        /* Map palette names → indicator roles, preserving per-role alpha */
        if      (g_str_equal(name, "background"))  col_bg     = (RGBA){ c.r, c.g, c.b, 0.75 };
        else if (g_str_equal(name, "accent"))       col_active = c;
        else if (g_str_equal(name, "blue"))         col_active = c; /* blue fallback */
        else if (g_str_equal(name, "foreground"))   col_fg     = (RGBA){ c.r, c.g, c.b, 0.55 };
        else if (g_str_equal(name, "comment"))      col_dim    = (RGBA){ c.r, c.g, c.b, 0.25 };
    }
    fclose(f);
}

/* ── Minimal hyprctl helpers ─────────────────────────────────────── */

static char *run_cmd(const char *cmd)
{
    FILE *fp = popen(cmd, "r");
    if (!fp) return NULL;

    size_t len = 0, cap = 0;
    char  *buf = NULL, tmp[512];
    while (fgets(tmp, sizeof tmp, fp)) {
        size_t n = strlen(tmp);
        if (len + n + 1 > cap) {
            cap = (cap + n) * 2 + 256;
            buf = g_realloc(buf, cap);
        }
        memcpy(buf + len, tmp, n);
        len += n;
    }
    pclose(fp);
    if (buf) buf[len] = '\0';
    return buf;
}

/* Extract first "id": <int> from JSON text */
static int json_first_id(const char *js)
{
    const char *p = strstr(js, "\"id\":");
    if (!p) return -1;
    p += 5;
    while (*p == ' ') p++;
    return atoi(p);
}

/* Collect all positive "id": <int> ≤ MAX_WS */
static int json_all_ids(const char *js, int *ids, int max)
{
    int n = 0;
    const char *p = js;
    while (n < max && (p = strstr(p, "\"id\":")) != NULL) {
        p += 5;
        while (*p == ' ') p++;
        int id = atoi(p);
        if (id > 0 && id <= MAX_WS)
            ids[n++] = id;
        p++;
    }
    return n;
}

static void refresh_state(void)
{
    memset(occ, 0, sizeof occ);
    occ_max = 0;

    char *ws = run_cmd("hyprctl activeworkspace -j");
    if (ws) {
        cur_ws = json_first_id(ws);
        if (cur_ws < 1) cur_ws = 1;
        g_free(ws);
    }

    char *all = run_cmd("hyprctl workspaces -j");
    if (all) {
        int ids[MAX_WS];
        int n = json_all_ids(all, ids, MAX_WS);
        for (int i = 0; i < n; i++) {
            occ[ids[i]] = TRUE;
            if (ids[i] > occ_max) occ_max = ids[i];
        }
        g_free(all);
    }
}

/* ── Geometry ────────────────────────────────────────────────────── */

static int dot_count(void)
{
    int hi = occ_max > cur_ws ? occ_max : cur_ws;
    if (hi < PERSISTENT_WS) hi = PERSISTENT_WS;
    if (hi > MAX_WS) hi = MAX_WS;
    return hi;
}

static void resize_da(void)
{
    int n = dot_count();
    int w = PAD_H * 2 + (n - 1) * DOT_SPACING + (int)(ACTIVE_R * 2);
    int h = PAD_V * 2 + (int)(ACTIVE_R * 2);
    gtk_widget_set_size_request(da, w, h);
}

/* ── Cairo draw ──────────────────────────────────────────────────── */

static gboolean on_draw(GtkWidget *widget, cairo_t *cr, gpointer data)
{
    (void)data;
    double a = opacity;
    if (a < 0.001) return FALSE;

    GtkAllocation alloc;
    gtk_widget_get_allocation(widget, &alloc);
    double w = alloc.width, h = alloc.height;

    /* Pill background */
    double r = h / 2.0;
    cairo_new_sub_path(cr);
    cairo_arc(cr, r, r, r, G_PI * 0.5, G_PI * 1.5);
    cairo_arc(cr, w - r, r, r, G_PI * 1.5, G_PI * 0.5);
    cairo_close_path(cr);
    cairo_set_source_rgba(cr, col_bg.r, col_bg.g, col_bg.b, col_bg.a * a);
    cairo_fill(cr);

    /* Dots */
    int n = dot_count();
    double span = (double)(n - 1) * DOT_SPACING;
    double sx   = (w - span) / 2.0;
    double cy   = h / 2.0;

    for (int i = 0; i < n; i++) {
        int    ws  = i + 1;
        double cx  = sx + (double)i * DOT_SPACING;
        RGBA   c;
        double dr;

        if (ws == cur_ws)      { c = col_active; dr = ACTIVE_R; }
        else if (occ[ws])      { c = col_fg;     dr = DOT_R;    }
        else                   { c = col_dim;    dr = DOT_R - 1; }

        cairo_set_source_rgba(cr, c.r, c.g, c.b, c.a * a);
        cairo_arc(cr, cx, cy, dr, 0, G_PI * 2);
        cairo_fill(cr);
    }

    return FALSE;
}

/* ── Fade animation ──────────────────────────────────────────────── */

static double fade_tgt;
static double fade_step_d;

static gboolean fade_step(gpointer data)
{
    (void)data;
    opacity += fade_step_d;
    gboolean done = (fade_step_d >= 0)
        ? (opacity >= fade_tgt)
        : (opacity <= fade_tgt);
    if (done) opacity = fade_tgt;

    gtk_widget_queue_draw(da);

    if (done) {
        tid_fade = 0;
        if (fade_tgt <= 0.0)
            gtk_widget_set_opacity(win, 0.0);
        return G_SOURCE_REMOVE;
    }
    return G_SOURCE_CONTINUE;
}

static void fade_to(double target, int ms)
{
    if (tid_fade) { g_source_remove(tid_fade); tid_fade = 0; }
    int steps = ms / 16;
    if (steps < 1) steps = 1;
    fade_tgt    = target;
    fade_step_d = (target - opacity) / (double)steps;
    tid_fade    = g_timeout_add(16, fade_step, NULL);
}

/* ── Show / hide ─────────────────────────────────────────────────── */

static gboolean begin_hide(gpointer data)
{
    (void)data;
    tid_hide = 0;
    fade_to(0.0, FADE_OUT_MS);
    return G_SOURCE_REMOVE;
}

static void show_indicator(void)
{
    refresh_state();
    if (cur_ws < 1) return;           /* skip special workspaces */

    if (tid_hide) { g_source_remove(tid_hide); tid_hide = 0; }
    if (tid_fade) { g_source_remove(tid_fade); tid_fade = 0; }

    resize_da();
    gtk_widget_queue_draw(da);
    gtk_widget_set_opacity(win, 1.0);
    fade_to(1.0, FADE_IN_MS);
    tid_hide = g_timeout_add(DISPLAY_MS, begin_hide, NULL);
}

/* ── Debounced trigger (thread-safe) ─────────────────────────────── */

static gboolean do_show(gpointer data)
{
    (void)data;
    tid_dbnc = 0;
    show_indicator();
    return G_SOURCE_REMOVE;
}

static gboolean sched_show(gpointer data)
{
    (void)data;
    if (tid_dbnc) g_source_remove(tid_dbnc);
    tid_dbnc = g_timeout_add(DEBOUNCE_MS, do_show, NULL);
    return G_SOURCE_REMOVE;        /* remove idle source */
}

static void trigger(void) { g_idle_add(sched_show, NULL); }

/* ── IPC listener thread ─────────────────────────────────────────── */

static char *find_socket2(void)
{
    const char *sig = g_getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (!sig) return NULL;

    const char *xdg = g_getenv("XDG_RUNTIME_DIR");
    char *p;

    if (xdg) {
        p = g_strdup_printf("%s/hypr/%s/.socket2.sock", xdg, sig);
        if (g_file_test(p, G_FILE_TEST_EXISTS)) return p;
        g_free(p);
    }
    p = g_strdup_printf("/tmp/hypr/%s/.socket2.sock", sig);
    if (g_file_test(p, G_FILE_TEST_EXISTS)) return p;
    g_free(p);
    return NULL;
}

static void *ipc_thread(void *arg)
{
    (void)arg;
    char *path = find_socket2();
    if (!path) {
        g_warning("workspace-indicator: cannot locate Hyprland socket2");
        return NULL;
    }

    for (;;) {
        int fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0) { sleep(1); continue; }

        struct sockaddr_un addr = { .sun_family = AF_UNIX };
        g_strlcpy(addr.sun_path, path, sizeof addr.sun_path);

        if (connect(fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
            close(fd);
            sleep(1);
            continue;
        }

        char buf[BUF_SZ], line[BUF_SZ];
        size_t llen = 0;
        ssize_t n;

        while ((n = read(fd, buf, sizeof buf - 1)) > 0) {
            buf[n] = '\0';
            for (ssize_t i = 0; i < n; i++) {
                if (buf[i] == '\n') {
                    line[llen] = '\0';
                    if (g_str_has_prefix(line, "workspace>>") ||
                        g_str_has_prefix(line, "focusedmon>>"))
                        trigger();
                    llen = 0;
                } else if (llen < sizeof line - 1) {
                    line[llen++] = buf[i];
                }
            }
        }
        close(fd);
        sleep(1);   /* reconnect back-off */
    }

    g_free(path);
    return NULL;
}

/* ── GTK window construction ─────────────────────────────────────── */

static void on_realize(GtkWidget *widget, gpointer data)
{
    (void)data;
    /* Empty input region → click-through */
    cairo_region_t *rgn = cairo_region_create();
    gtk_widget_input_shape_combine_region(widget, rgn);
    cairo_region_destroy(rgn);
}

static void build_window(void)
{
    win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_widget_set_app_paintable(win, TRUE);

    GdkScreen *scr = gtk_widget_get_screen(win);
    GdkVisual *vis = gdk_screen_get_rgba_visual(scr);
    if (vis) gtk_widget_set_visual(win, vis);

    gtk_layer_init_for_window(GTK_WINDOW(win));
    gtk_layer_set_layer(GTK_WINDOW(win), GTK_LAYER_SHELL_LAYER_OVERLAY);
    gtk_layer_set_anchor(GTK_WINDOW(win), GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
    gtk_layer_set_margin(GTK_WINDOW(win), GTK_LAYER_SHELL_EDGE_BOTTOM, MARGIN_BOTTOM);
    gtk_layer_set_namespace(GTK_WINDOW(win), "workspace-indicator");
    gtk_layer_set_keyboard_mode(GTK_WINDOW(win),
                                GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);

    da = gtk_drawing_area_new();
    g_signal_connect(da, "draw", G_CALLBACK(on_draw), NULL);
    gtk_container_add(GTK_CONTAINER(win), da);

    g_signal_connect(win, "realize", G_CALLBACK(on_realize), NULL);

    resize_da();
    gtk_widget_set_opacity(win, 0.0);
    gtk_widget_show_all(win);
}

/* ── Single-instance lock ────────────────────────────────────────── */

static int acquire_lock(void)
{
    const char *cache = g_get_user_cache_dir();
    char *dir  = g_build_filename(cache, "workspace-indicator", NULL);
    g_mkdir_with_parents(dir, 0755);
    char *path = g_build_filename(dir, "lock", NULL);
    int fd = open(path, O_CREAT | O_RDWR, 0644);
    g_free(dir);
    g_free(path);
    if (fd < 0) return -1;
    if (flock(fd, LOCK_EX | LOCK_NB) < 0) return -1;
    return fd;
}

/* ── Signals ─────────────────────────────────────────────────────── */

static gboolean on_usr1(gpointer data)  { (void)data; trigger(); return G_SOURCE_CONTINUE; }
static gboolean on_usr2(gpointer data)  { (void)data; load_palette(); return G_SOURCE_CONTINUE; }
static gboolean on_quit(gpointer data)  { (void)data; gtk_main_quit(); return G_SOURCE_REMOVE; }

/* ── main ────────────────────────────────────────────────────────── */

int main(int argc, char *argv[])
{
    int lock_fd = acquire_lock();
    if (lock_fd < 0) {
        g_message("workspace-indicator: already running");
        return 0;
    }

    gtk_init(&argc, &argv);

    load_palette();
    build_window();

    g_unix_signal_add(SIGUSR1, on_usr1, NULL);
    g_unix_signal_add(SIGUSR2, on_usr2, NULL);  /* theme-set reload */
    g_unix_signal_add(SIGTERM, on_quit, NULL);
    g_unix_signal_add(SIGINT,  on_quit, NULL);

    pthread_t tid;
    pthread_create(&tid, NULL, ipc_thread, NULL);
    pthread_detach(tid);

    gtk_main();

    close(lock_fd);
    return 0;
}

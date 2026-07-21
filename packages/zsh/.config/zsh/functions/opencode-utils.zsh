#!/usr/bin/env zsh

oca() {
    emulate -L zsh
    setopt localoptions no_unset

    local attach_url="${OPENCODE_ATTACH_URL:-http://opencode-attach.home.arpa:4096}"
    local fallback_url="${OPENCODE_ATTACH_URL_FALLBACK:-http://100.96.128.10:4096}"
    local discovery_url="${OPENCODE_PROJECT_DISCOVERY_URL:-http://opencode-attach.home.arpa:4097}"
    local discovery_fallback_url="${OPENCODE_PROJECT_DISCOVERY_URL_FALLBACK:-http://192.168.0.237:4097}"
    local command="${1:-}"

    _oca_usage() {
        print "Usage:"
        print "  oca list"
        print "  oca url"
        print "  oca sessions [project]"
        print "  oca <project> [opencode attach args...]"
        print ""
        print "Examples:"
        print "  oca sui"
        print "  oca zenwriter --continue"
        print "  oca picoclaw --session <session_id>"
    }

    _oca_curl() {
        local args=(-fsS --max-time "${OPENCODE_ATTACH_TIMEOUT:-8}")
        if [[ -n "${OPENCODE_SERVER_PASSWORD:-}" ]]; then
            args+=(-u "${OPENCODE_SERVER_USERNAME:-opencode}:$OPENCODE_SERVER_PASSWORD")
        fi
        curl "${args[@]}" "$@"
    }

    _oca_ensure_vpn() {
        command -v pangolin-vpn >/dev/null 2>&1 || return 0
        pangolin-vpn status | grep -q 'ActiveState=active' && return 0
        pangolin-vpn on >/dev/null
    }

    _oca_select_url() {
        local primary="$1" fallback="$2"
        _oca_ensure_vpn || return 1
        if _oca_curl --max-time 3 "$primary/health" >/dev/null 2>&1; then
            print -r -- "$primary"
            return 0
        fi
        if [[ -n "$fallback" ]] && _oca_curl --max-time 3 "$fallback/health" >/dev/null 2>&1; then
            print -r -- "$fallback"
            return 0
        fi
        print -r -- "$primary"
    }

    _oca_discovery_base_url() {
        _oca_select_url "$discovery_url" "$discovery_fallback_url" /health
    }

    _oca_attach_base_url() {
        _oca_select_url "$attach_url" "$fallback_url" /global/health
    }

    _oca_projects_tsv() {
        local url="$1"
        _oca_curl "$url/project/discover" | python3 -c 'import json,sys
data=json.load(sys.stdin)
sw=max((len(str(p.get("sessionCount",0))) for p in data),default=1)
for p in data:
    print(("%"+str(sw)+"s\t%s\t%s") % (str(p.get("sessionCount",0)), p.get("alias",""), p.get("directory","")))'
    }

    _oca_each_project() {
        local selected_url
        selected_url="$(_oca_discovery_base_url)" || return 1
        _oca_projects_tsv "$selected_url"
    }

    _oca_resolve_project() {
        local requested="$1" selected_url alias dir sessions
        selected_url="$(_oca_discovery_base_url)" || return 1
        while IFS=$'\t' read -r sessions alias dir; do
            if [[ "$alias" == "$requested" ]]; then
                print -r -- "$dir"
                return 0
            fi
        done < <(_oca_projects_tsv "$selected_url")
        return 1
    }

    _oca_reject_unsafe_dir() {
        local dir="$1"
        case "$dir" in
            /|/home/coder|/home/coder/workspace|/home/coder/workspace/)
                print -u2 "oca: refusing unsafe attach directory: $dir"
                return 1
                ;;
        esac
    }

    _oca_sessions() {
        local maybe_project="${1:-}" dir="" selected_url encoded

        if [[ -n "$maybe_project" ]]; then
            dir="$(_oca_resolve_project "$maybe_project")" || {
                print -u2 "oca: unknown project: $maybe_project"
                return 1
            }
        fi

        if [[ -z "$dir" ]]; then
            _oca_each_project
            return 0
        fi

        selected_url="$(_oca_attach_base_url)" || return 1
        encoded=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$dir")
        _oca_curl "$selected_url/session?directory=$encoded&roots=true&limit=20" | python3 -c 'import datetime,json,sys
for s in json.load(sys.stdin):
    t=(s.get("time") or {}).get("updated") or s.get("time_updated") or 0
    when=datetime.datetime.fromtimestamp(t/1000).isoformat(timespec="seconds") if t else ""
    print("%s\t%s\t%s" % (s.get("id", ""), when, s.get("title", "")))'
    }

    case "$command" in
        ""|-h|--help|help)
            _oca_usage
            return 0
            ;;
        list|ls)
            _oca_each_project
            return 0
            ;;
        url)
            print "$attach_url"
            [[ -n "$fallback_url" ]] && print "$fallback_url"
            print "$discovery_url"
            [[ -n "$discovery_fallback_url" ]] && print "$discovery_fallback_url"
            return 0
            ;;
        sessions)
            shift
            _oca_sessions "$@"
            return $?
            ;;
    esac

    local project="$command"
    local project_dir
    project_dir="$(_oca_resolve_project "$project")" || {
        print -u2 "oca: unknown project: $project"
        print -u2 "oca: run 'oca list' to see known projects"
        return 1
    }

    _oca_reject_unsafe_dir "$project_dir" || return 1
    shift

    local selected_url
    selected_url="$(_oca_attach_base_url)"
    opencode attach "$selected_url" --dir "$project_dir" "$@"
}

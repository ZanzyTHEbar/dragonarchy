#!/usr/bin/env zsh

oca() {
    emulate -L zsh
    setopt localoptions no_unset

    local registry="${OPENCODE_PROJECT_REGISTRY:-$HOME/.config/opencode-projects/projects.tsv}"
    local attach_url="${OPENCODE_ATTACH_URL:-http://opencode-attach.home.arpa:4096}"
    local fallback_url="${OPENCODE_ATTACH_URL_FALLBACK:-http://100.96.128.10:4096}"
    local command="${1:-}"

    _oca_usage() {
        print "Usage:"
        print "  oca list"
        print "  oca url"
        print "  oca sessions [project]"
        print "  oca <project> [opencode attach args...]"
        print ""
        print "Examples:"
        print "  oca dragonserver"
        print "  oca actual-mcp --continue"
        print "  oca mealie-mcp --session <session_id>"
    }

    _oca_registry_exists() {
        if [[ ! -r "$registry" ]]; then
            print -u2 "oca: project registry not found: $registry"
            return 1
        fi
    }

    _oca_each_project() {
        local alias dir
        while IFS=$'\t' read -r alias dir; do
            [[ -z "$alias" || "$alias" == \#* ]] && continue
            [[ -z "$dir" ]] && continue
            print -r -- "$alias	$dir"
        done < "$registry"
    }

    _oca_resolve_project() {
        local requested="$1" alias dir
        while IFS=$'\t' read -r alias dir; do
            [[ -z "$alias" || "$alias" == \#* ]] && continue
            if [[ "$alias" == "$requested" ]]; then
                print -r -- "$dir"
                return 0
            fi
        done < "$registry"
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

    _oca_warn_if_local_dir_lacks_markers() {
        local dir="$1"
        [[ -d "$dir" ]] || return 0
        [[ -e "$dir/.git" || -e "$dir/go.mod" || -e "$dir/package.json" || -e "$dir/docker-compose.yaml" || -e "$dir/docker-compose.yml" || -e "$dir/compose.yaml" || -e "$dir/compose.yml" ]] && return 0
        print -u2 "oca: warning: $dir exists locally but no common project marker was found"
    }

    _oca_url_ready() {
        local url="$1"
        command -v curl >/dev/null 2>&1 || return 1
        curl -fsS --max-time 2 "$url/doc" >/dev/null 2>&1
    }

    _oca_select_attach_url() {
        if _oca_url_ready "$attach_url"; then
            print -r -- "$attach_url"
            return 0
        fi

        if [[ -n "$fallback_url" ]] && _oca_url_ready "$fallback_url"; then
            print -r -- "$fallback_url"
            return 0
        fi

        print -u2 "oca: warning: attach endpoint did not respond to /doc; trying primary URL anyway"
        print -r -- "$attach_url"
    }

    _oca_sessions() {
        local maybe_project="${1:-}"
        local db="${OPENCODE_DB_PATH:-$HOME/.local/share/opencode/opencode.db}"
        local dir=""

        if [[ -n "$maybe_project" ]]; then
            dir="$(_oca_resolve_project "$maybe_project")" || {
                print -u2 "oca: unknown project: $maybe_project"
                return 1
            }
        fi

        if ! command -v sqlite3 >/dev/null 2>&1 || [[ ! -r "$db" ]]; then
            print "oca sessions requires read access to the server-side OpenCode DB."
            print "Run this inside the OpenCode runtime, or use:"
            print "  oca <project> --continue"
            return 0
        fi

        if [[ -n "$dir" ]]; then
            sqlite3 -readonly -header -column "$db" \
                "select id, directory, title, datetime(time_updated / 1000, 'unixepoch') as updated from session where directory = '$dir' order by time_updated desc limit 20;"
        else
            sqlite3 -readonly -header -column "$db" \
                "select directory, count(*) as sessions, datetime(max(time_updated) / 1000, 'unixepoch') as latest from session group by directory order by max(time_updated) desc limit 30;"
        fi
    }

    case "$command" in
        ""|-h|--help|help)
            _oca_usage
            return 0
            ;;
        list|ls)
            _oca_registry_exists || return 1
            _oca_each_project
            return 0
            ;;
        url)
            print "$attach_url"
            [[ -n "$fallback_url" ]] && print "$fallback_url"
            return 0
            ;;
        sessions)
            shift
            _oca_registry_exists || return 1
            _oca_sessions "$@"
            return $?
            ;;
    esac

    _oca_registry_exists || return 1

    local project="$command"
    local project_dir
    project_dir="$(_oca_resolve_project "$project")" || {
        print -u2 "oca: unknown project: $project"
        print -u2 "oca: run 'oca list' to see known projects"
        return 1
    }

    _oca_reject_unsafe_dir "$project_dir" || return 1
    _oca_warn_if_local_dir_lacks_markers "$project_dir"
    shift

    local selected_url
    selected_url="$(_oca_select_attach_url)"
    opencode attach "$selected_url" --dir "$project_dir" "$@"
}

# Application launcher functions

# Run application in background and detach
runfree() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: runfree <command> [args...]"
        return 1
    fi
    
    nohup "$@" >/dev/null 2>&1 &
    disown
}

# Launch file manager
fm() {
    local path="${1:-.}"
    
    case "$(uname)" in
        Darwin*)
            open "$path"
            ;;
        Linux*)
            if command -v nautilus >/dev/null 2>&1; then
                runfree nautilus "$path"
            elif command -v nemo >/dev/null 2>&1; then
                runfree nemo "$path"
            elif command -v thunar >/dev/null 2>&1; then
                runfree thunar "$path"
            else
                echo "No supported file manager found"
                return 1
            fi
            ;;
    esac
}

# Launch terminal
term() {
    case "$(uname)" in
        Darwin*)
            osascript -e 'tell application "Terminal" to do script ""'
            ;;
        Linux*)
            if command -v kitty >/dev/null 2>&1; then
                runfree kitty
            elif command -v alacritty >/dev/null 2>&1; then
                runfree alacritty
            elif command -v gnome-terminal >/dev/null 2>&1; then
                runfree gnome-terminal
            elif command -v konsole >/dev/null 2>&1; then
                runfree konsole
            else
                echo "No supported terminal found"
                return 1
            fi
            ;;
    esac
}

# Launch web browser
web() {
    local url="${1:-}"
    
    case "$(uname)" in
        Darwin*)
            if [[ -n "$url" ]]; then
                open "$url"
            else
                open -a "Safari"
            fi
            ;;
        Linux*)
            if command -v vivaldi >/dev/null 2>&1; then
                runfree vivaldi "$url"
            elif command -v firefox >/dev/null 2>&1; then
                runfree firefox "$url"
            elif command -v google-chrome >/dev/null 2>&1; then
                runfree google-chrome "$url"
            elif command -v chromium >/dev/null 2>&1; then
                runfree chromium "$url"
            else
                echo "No supported browser found"
                return 1
            fi
            ;;
    esac
}

# Launch text editor
edit() {
    local file="${1:-}"
    
    if command -v code >/dev/null 2>&1; then
        runfree code "$file"
    elif command -v code-insiders >/dev/null 2>&1; then
        runfree code-insiders "$file"
    elif command -v nvim >/dev/null 2>&1; then
        nvim "$file"
    elif command -v vim >/dev/null 2>&1; then
        vim "$file"
    else
        echo "No supported editor found"
        return 1
    fi
}

# Launch image viewer
img() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: img <image_file>"
        return 1
    fi
    
    local image="$1"
    
    if [[ ! -f "$image" ]]; then
        echo "Error: File '$image' not found"
        return 1
    fi
    
    case "$(uname)" in
        Darwin*)
            open "$image"
            ;;
        Linux*)
            if command -v eog >/dev/null 2>&1; then
                runfree eog "$image"
            elif command -v gwenview >/dev/null 2>&1; then
                runfree gwenview "$image"
            elif command -v feh >/dev/null 2>&1; then
                runfree feh "$image"
            else
                echo "No supported image viewer found"
                return 1
            fi
            ;;
    esac
}

# Launch video player
video() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: video <video_file>"
        return 1
    fi
    
    local video_file="$1"
    
    if [[ ! -f "$video_file" ]]; then
        echo "Error: File '$video_file' not found"
        return 1
    fi
    
    case "$(uname)" in
        Darwin*)
            open "$video_file"
            ;;
        Linux*)
            if command -v vlc >/dev/null 2>&1; then
                runfree vlc "$video_file"
            elif command -v mpv >/dev/null 2>&1; then
                runfree mpv "$video_file"
            elif command -v totem >/dev/null 2>&1; then
                runfree totem "$video_file"
            else
                echo "No supported video player found"
                return 1
            fi
            ;;
    esac
}

# Launch PDF viewer
pdf() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: pdf <pdf_file>"
        return 1
    fi
    
    local pdf_file="$1"
    
    if [[ ! -f "$pdf_file" ]]; then
        echo "Error: File '$pdf_file' not found"
        return 1
    fi
    
    case "$(uname)" in
        Darwin*)
            open "$pdf_file"
            ;;
        Linux*)
            if command -v evince >/dev/null 2>&1; then
                runfree evince "$pdf_file"
            elif command -v okular >/dev/null 2>&1; then
                runfree okular "$pdf_file"
            elif command -v zathura >/dev/null 2>&1; then
                runfree zathura "$pdf_file"
            else
                echo "No supported PDF viewer found"
                return 1
            fi
            ;;
    esac
}

# Launch calculator
calc() {
    case "$(uname)" in
        Darwin*)
            open -a Calculator
            ;;
        Linux*)
            if command -v gnome-calculator >/dev/null 2>&1; then
                runfree gnome-calculator
            elif command -v kcalc >/dev/null 2>&1; then
                runfree kcalc
            elif command -v galculator >/dev/null 2>&1; then
                runfree galculator
            else
                echo "No supported calculator found"
                return 1
            fi
            ;;
    esac
}

# Quick screenshot
screenshot() {
    local filename="screenshot_$(date +%Y%m%d_%H%M%S).png"
    
    case "$(uname)" in
        Darwin*)
            screencapture "$filename"
            echo "Screenshot saved as $filename"
            ;;
        Linux*)
            if command -v gnome-screenshot >/dev/null 2>&1; then
                gnome-screenshot -f "$filename"
                echo "Screenshot saved as $filename"
            elif command -v spectacle >/dev/null 2>&1; then
                spectacle -f -o "$filename"
                echo "Screenshot saved as $filename"
            elif command -v scrot >/dev/null 2>&1; then
                scrot "$filename"
                echo "Screenshot saved as $filename"
            else
                echo "No supported screenshot tool found"
                return 1
            fi
            ;;
    esac
}

# Launch system monitor
sysmon() {
    case "$(uname)" in
        Darwin*)
            open -a "Activity Monitor"
            ;;
        Linux*)
            if command -v gnome-system-monitor >/dev/null 2>&1; then
                runfree gnome-system-monitor
            elif command -v ksysguard >/dev/null 2>&1; then
                runfree ksysguard
            elif command -v htop >/dev/null 2>&1; then
                htop
            else
                top
            fi
            ;;
    esac
}

# Kill application by name
killapp() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: killapp <application_name>"
        return 1
    fi
    
    local app_name="$1"
    
    case "$(uname)" in
        Darwin*)
            pkill -f "$app_name"
            ;;
        Linux*)
            pkill -f "$app_name"
            ;;
    esac
    
    echo "Killed processes matching '$app_name'"
} 
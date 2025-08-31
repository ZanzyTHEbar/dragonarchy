# Enhanced file utilities function for ZSH

# Smart move that creates directories and moves files
smv() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: smv <source> <destination>"
        return 1
    fi
    
    local dest_dir="$(dirname "$2")"
    
    if [[ ! -d "$dest_dir" ]]; then
        echo "Creating directory: $dest_dir"
        mkdir -p "$dest_dir"
    fi
    
    mv "$1" "$2"
}

# Smart copy that creates directories and copies files  
smartcp() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: scp <source> <destination>"
        return 1
    fi
    
    local dest_dir="$(dirname "$2")"
    
    if [[ ! -d "$dest_dir" ]]; then
        echo "Creating directory: $dest_dir"
        mkdir -p "$dest_dir"
    fi
    
    cp -r "$1" "$2"
}

# Find and replace in files
findreplace() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: findreplace <search_pattern> <replace_pattern>"
        echo "This will replace all occurrences in current directory recursively"
        return 1
    fi
    
    echo "Replacing '$1' with '$2' in all files recursively..."
    find . -type f -not -path './.git/*' -exec sed -i "s/$1/$2/g" {} +
    echo "Replacement complete."
}

# Create directory and cd into it
mkcd() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: mkcd <directory_name>"
        return 1
    fi
    
    mkdir -p "$1" && cd "$1"
}

# Extract archives based on extension
extract() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: extract <archive_file>"
        return 1
    fi
    
    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a valid file"
        return 1
    fi
    
    case "$1" in
        *.tar.bz2)   tar xvjf "$1"    ;;
        *.tar.gz)    tar xvzf "$1"    ;;
        *.tar.xz)    tar xvJf "$1"    ;;
        *.bz2)       bunzip2 "$1"     ;;
        *.rar)       unrar x "$1"     ;;
        *.gz)        gunzip "$1"      ;;
        *.tar)       tar xvf "$1"     ;;
        *.tbz2)      tar xvjf "$1"    ;;
        *.tgz)       tar xvzf "$1"    ;;
        *.zip)       unzip "$1"       ;;
        *.Z)         uncompress "$1"  ;;
        *.7z)        7z x "$1"        ;;
        *.deb)       ar x "$1"        ;;
        *.tar.Z)     tar xvZf "$1"    ;;
        *.lzma)      unlzma "$1"      ;;
        *.xz)        unxz "$1"        ;;
        *)           echo "Error: '$1' cannot be extracted via extract()" ;;
    esac
}

# Show file/directory sizes in current directory
dirsize() {
    du -sh * | sort -hr
}

# Quick backup function
backup() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: backup <file_or_directory>"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${1}.backup_${timestamp}"
    
    cp -r "$1" "$backup_name"
    echo "Backup created: $backup_name"
}

# Find large files
findlarge() {
    local size=${1:-100M}
    echo "Finding files larger than $size..."
    find . -type f -size +$size -exec ls -lh {} \; | awk '{ print $9 ": " $5 }'
}

# Find empty directories
findempty() {
    find . -type d -empty
}

# Safe delete (move to trash)
trash() {
    local trash_dir="$HOME/.local/share/Trash/files"
    
    if [[ ! -d "$trash_dir" ]]; then
        mkdir -p "$trash_dir"
    fi
    
    for item in "$@"; do
        if [[ -e "$item" ]]; then
            local timestamp=$(date +%Y%m%d_%H%M%S)
            local basename=$(basename "$item")
            mv "$item" "$trash_dir/${basename}_${timestamp}"
            echo "Moved '$item' to trash"
        else
            echo "Error: '$item' does not exist"
        fi
    done
}

# Restore from trash
untrash() {
    local trash_dir="$HOME/.local/share/Trash/files"
    
    if [[ ! -d "$trash_dir" ]]; then
        echo "Trash directory does not exist"
        return 1
    fi
    
    echo "Files in trash:"
    ls -la "$trash_dir"
    
    if [[ $# -eq 1 ]]; then
        local file_to_restore="$1"
        if [[ -e "$trash_dir/$file_to_restore" ]]; then
            mv "$trash_dir/$file_to_restore" .
            echo "Restored '$file_to_restore' from trash"
        else
            echo "Error: '$file_to_restore' not found in trash"
        fi
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Open file/directory with appropriate application
open_with() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: open_with <file_or_directory> [application]"
        return 1
    fi
    
    local file="$1"
    local app="${2:-}"
    
    if [[ ! -e "$file" ]]; then
        echo "Error: '$file' does not exist"
        return 1
    fi
    
    case "$(uname)" in
        Darwin*)
            if [[ -n "$app" ]]; then
                open -a "$app" "$file"
            else
                open "$file"
            fi
            ;;
        Linux*)
            if [[ -n "$app" ]]; then
                "$app" "$file" &
            else
                xdg-open "$file" &
            fi
            ;;
        *)
            echo "Unsupported platform"
            return 1
            ;;
    esac
}

# Quick file search
qfind() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: qfind <pattern> [directory]"
        return 1
    fi
    
    local pattern="$1"
    local search_dir="${2:-.}"
    
    find "$search_dir" -iname "*$pattern*" -type f
}

# Quick directory search
qdir() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: qdir <pattern> [directory]"
        return 1
    fi
    
    local pattern="$1"
    local search_dir="${2:-.}"
    
    find "$search_dir" -iname "*$pattern*" -type d
}

# Start a program but immediately disown it and detach it from the terminal
function runfree() {
	"$@" > /dev/null 2>&1 & disown
}

# Copy file with a progress bar
function cpp() {
	if [[ -x "$(command -v rsync)" ]]; then
		# rsync -avh --progress "${1}" "${2}"
		rsync -ah --info=progress2 "${1}" "${2}"
	else
		set -e
		strace -q -ewrite cp -- "${1}" "${2}" 2>&1 \
		| awk '{
		count += $NF
		if (count % 10 == 0) {
			percent = count / total_size * 100
			printf "%3d%% [", percent
			for (i=0;i<=percent;i++)
				printf "="
				printf ">"
				for (i=percent;i<100;i++)
					printf " "
					printf "]\r"
				}
			}
		END { print "" }' total_size=$(stat -c '%s' "${1}") count=0
	fi
}

# Copy and go to the directory
function cpg() {
	if [[ -d "$2" ]];then
		cp "$1" "$2" && cd "$2"
	else
		cp "$1" "$2"
	fi
}

# Move and go to the directory
function mvg() {
	if [[ -d "$2" ]];then
		mv "$1" "$2" && cd "$2"
	else
		mv "$1" "$2"
	fi
}

# Create and go to the directory
function mkdirg() {
	mkdir -p "$@" && cd "$@"
}
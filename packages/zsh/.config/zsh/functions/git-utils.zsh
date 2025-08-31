# Git utility functions

# Enhanced git push with automatic branch creation
gitpush() {
    local current_branch=$(git branch --show-current)
    
    if [[ -z "$current_branch" ]]; then
        echo "Error: Not in a git repository or no current branch"
        return 1
    fi
    
    # Check if remote tracking branch exists
    if ! git rev-parse --verify "origin/$current_branch" >/dev/null 2>&1; then
        echo "Remote tracking branch doesn't exist. Creating and pushing..."
        git push -u origin "$current_branch"
    else
        echo "Pushing to existing remote branch..."
        git push
    fi
}

# Enhanced git update (pull with rebase)
gitupdate() {
    local current_branch=$(git branch --show-current)
    
    if [[ -z "$current_branch" ]]; then
        echo "Error: Not in a git repository"
        return 1
    fi
    
    echo "Updating branch '$current_branch'..."
    
    # Stash any uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo "Stashing uncommitted changes..."
        git stash push -m "Auto-stash before update"
        local stashed=true
    fi
    
    # Pull with rebase
    git pull --rebase origin "$current_branch"
    
    # Pop stash if we stashed changes
    if [[ "$stashed" == "true" ]]; then
        echo "Restoring stashed changes..."
        git stash pop
    fi
}

# Quick commit with message
gitquick() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: gitquick <commit_message>"
        return 1
    fi
    
    git add .
    git commit -m "$*"
}

# Git status with enhanced information
gitstatus() {
    echo "=== Git Status ==="
    git status --short --branch
    
    echo ""
    echo "=== Recent Commits ==="
    git log --oneline -5
    
    echo ""
    echo "=== Branch Information ==="
    local current_branch=$(git branch --show-current)
    echo "Current branch: $current_branch"
    
    # Check if we're ahead/behind remote
    local remote_info=$(git status --porcelain=v1 --branch | head -1)
    if [[ "$remote_info" == *"ahead"* ]]; then
        echo "Status: Ahead of remote"
    elif [[ "$remote_info" == *"behind"* ]]; then
        echo "Status: Behind remote"
    else
        echo "Status: Up to date"
    fi
}

# Interactive rebase helper
gitrebase() {
    local commits=${1:-3}
    echo "Starting interactive rebase for last $commits commits..."
    git rebase -i HEAD~$commits
}

# Create and switch to new branch
gitbranch() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: gitbranch <branch_name> [base_branch]"
        return 1
    fi
    
    local new_branch="$1"
    local base_branch="${2:-main}"
    
    # Check if base branch exists
    if ! git show-ref --verify --quiet "refs/heads/$base_branch"; then
        echo "Warning: Base branch '$base_branch' doesn't exist locally"
        echo "Available branches:"
        git branch -a
        return 1
    fi
    
    echo "Creating branch '$new_branch' from '$base_branch'..."
    git checkout "$base_branch"
    git pull origin "$base_branch"
    git checkout -b "$new_branch"
}

# Delete branch (local and remote)
gitdelbranch() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: gitdelbranch <branch_name>"
        return 1
    fi
    
    local branch="$1"
    local current_branch=$(git branch --show-current)
    
    if [[ "$branch" == "$current_branch" ]]; then
        echo "Error: Cannot delete current branch. Switch to another branch first."
        return 1
    fi
    
    echo "Deleting branch '$branch'..."
    
    # Delete local branch
    git branch -d "$branch"
    
    # Delete remote branch if it exists
    if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
        echo "Deleting remote branch..."
        git push origin --delete "$branch"
    fi
}

# Show git log in a nice format
gitlog() {
    local count=${1:-10}
    git log --oneline --graph --decorate --color -$count
}

# Find commits by message
gitfind() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: gitfind <search_pattern>"
        return 1
    fi
    
    git log --grep="$1" --oneline --decorate
}

# Show files changed in last commit
gitlast() {
    echo "=== Last Commit ==="
    git log -1 --stat
    
    echo ""
    echo "=== Files Changed ==="
    git diff-tree --no-commit-id --name-only -r HEAD
}

# Undo last commit (keep changes)
gitundo() {
    echo "Undoing last commit (keeping changes)..."
    git reset --soft HEAD~1
}

# Reset to clean state
gitclean() {
    echo "Warning: This will remove all uncommitted changes!"
    read "response?Are you sure? [y/N] "
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        git reset --hard HEAD
        git clean -fd
        echo "Repository reset to clean state"
    else
        echo "Operation cancelled"
    fi
}

# Show current git configuration
gitconfig() {
    echo "=== Git Configuration ==="
    echo "User: $(git config user.name) <$(git config user.email)>"
    echo "Remote origin: $(git config --get remote.origin.url)"
    echo ""
    echo "=== Branch Information ==="
    git branch -vv
}

# Archive current branch
gitarchive() {
    local current_branch=$(git branch --show-current)
    local archive_name="${current_branch}_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    echo "Creating archive of current branch..."
    git archive --format=tar.gz --output="$archive_name" HEAD
    echo "Archive created: $archive_name"
}

# Cherry-pick commits interactively
gitcherry() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: gitcherry <source_branch>"
        return 1
    fi
    
    local source_branch="$1"
    
    echo "Commits in '$source_branch' not in current branch:"
    git log --oneline --cherry-pick --right-only "$source_branch"...HEAD
    
    echo ""
    read "commit_hash?Enter commit hash to cherry-pick (or 'q' to quit): "
    
    if [[ "$commit_hash" != "q" ]]; then
        git cherry-pick "$commit_hash"
    fi
}

# Sync fork with upstream
gitsync() {
    local upstream=${1:-upstream}
    local main_branch=${2:-main}
    
    echo "Syncing fork with $upstream/$main_branch..."
    
    git fetch "$upstream"
    git checkout "$main_branch"
    git merge "$upstream/$main_branch"
    git push origin "$main_branch"
} 
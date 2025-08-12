#compdef gh-branch

_gh_branch() {
    local -a commands
    commands=(
        'list:List all remote branches'
        'create:Create a new branch from default branch'
        'delete:Delete a remote branch'
        'rename:Rename a remote branch'
    )

    local state
    _arguments \
        '1:command:->cmd' \
        '*::arg:->args'

    case $state in
        cmd)
            _describe -t commands 'gh branch commands' commands
            ;;
        args)
            case $words[2] in
                delete)
                    local branches
                    branches=(${(f)"$(gh api "repos/$(gh repo view --json owner,name --jq '.owner.login + \"/\" + .name')/branches" --jq '.[].name' 2>/dev/null)"})
                    _describe 'branch' branches
                    ;;
                rename)
                    if (( CURRENT == 3 )); then
                        # First argument to rename: old branch name
                        local branches
                        branches=(${(f)"$(gh api "repos/$(gh repo view --json owner,name --jq '.owner.login + \"/\" + .name')/branches" --jq '.[].name' 2>/dev/null)"})
                        _describe 'branch' branches
                    elif (( CURRENT == 4 )); then
                        # Second argument to rename: new branch name (free text)
                        _message 'new branch name'
                    fi
                    ;;
                create)
                    # No enforced completion, just a hint message
                    _message 'new branch name (from default branch)'
                    ;;
            esac
            ;;
    esac
}

_gh_branch "$@"



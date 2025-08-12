#compdef gh-branch

# Completion function for `gh branch`
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
                delete|rename)
                    local branches
                    branches=(${(f)"$(gh api "repos/$(gh repo view --json owner,name --jq '.owner.login + \"/\" + .name')/branches" --jq '.[].name')"})
                    _describe 'branch' branches
                    ;;
            esac
            ;;
    esac
}

_gh_branch "$@"


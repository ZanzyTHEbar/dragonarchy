# # ex - archive extractor
# # usage: ex <file>
ex ()
{
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1   ;;
            *.tar.gz)    tar xzf $1   ;;
            *.tar.xz)    tar xJf $1   ;;
            *.bz2)       bunzip2 $1   ;;
            *.rar)       unrar x $1     ;;
            *.gz)        gunzip $1    ;;
            *.tar)       tar xf $1    ;;
            *.tbz2)      tar xjf $1   ;;
            *.tgz)       tar xzf $1   ;;
            *.zip)       unzip $1     ;;
            *.Z)         uncompress $1;;
            *.7z)        7z x $1      ;;
            *)           echo "'$1' cannot be extracted via ex()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

####################################
# CALENDAR
###################################
showcalendarjd() { export YEAR=2024;for monthly in "Jul" "Aug" "Sep" "Oct";do gcal -j  -s Mon -K --iso-week-number=yes ${monthly} ${YEAR};echo;done }
showcalendarjdb() { export YEAR=2024;for monthly in "Jul" "Aug" "Sep" "Oct";do gcal -jb -s Mon -K --iso-week-number=yes ${monthly} ${YEAR};echo;done }
showcalendarcw() { export YEAR=2024;for monthly in "Jul" "Aug" "Sep" "Oct";do gcal -s Mon -K --iso-week-number=yes ${monthly} ${YEAR};echo;done }

findFcn() {
    find . -cnewer "${1}" | ag -v '.config|.cache|.mozilla|.local/share|.git' | cat -n | less
}

alias findnew='findFcn'

export EDITOR=nvim

alias pacman-update='sudo pacman-mirrors --geoip'

########################################
# LSD
########################################

if [[ -x "$(command -v lsd)" ]]; then
	alias ls='lsd -F --group-dirs first'
	alias ll='lsd --all --header --long --group-dirs first'
	alias tree='lsd --tree'

	#alias lt='(lsd --color always --icon always --tree --ignore-glob node_modules --depth 3 | sed 99q | cat -n; echo; echo truncated at 99 lines - see alias lt for details.) &'
	alias ldot='lsd -ld .*'
	alias lS='lsd -1FSsh'
	alias lart='lsd -1Fcart'
	alias lrt='lsd -1Fcrt'

	# lsd, the common ones I use a lot shortened for rapid fire usage
	alias l='lsd -lFh'     #size,show type,human readable
	alias la='lsd -lAFh'   #long list,show almost all,show type,human readable
	alias lr='lsd -tRFh'   #sorted by date,recursive,show type,human readable
	#alias lt='lsd -ltFh --tree'   #long list,sorted by date,show type,human readable

	lst() {
    	  if [[ $1 =~ ^[0-9]+$ ]]; then  # Check if the first argument is a valid positive number
        		local depth=$1
	  else
        	echo "Error: Please provide a valid positive number for the depth."
	        return 1
	  fi
    
    	  local max_lines=${2:-99}  # Optional second argument to limit the number of lines, default is 99
	  lsd --color always --icon always --tree --ignore-glob node_modules --depth "$depth" | sed "${max_lines}q" | cat -n; echo; echo truncated at "$max_lines" lines - see alias lt for details. &
	}
fi
################################################
#
################################################

alias zshrc='${=EDITOR} ~/.zshrc' # Quick access to the ~/.zshrc file

alias grep='grep --color'
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '

alias t='tail -f'

# Command line head / tail shortcuts
alias -g H='| head'
alias -g T='| tail'
alias -g G='| grep'
alias -g L="| less"
alias -g M="| most"
alias -g LL="2>&1 | less"
alias -g CA="2>&1 | cat -A"
alias -g NE="2> /dev/null"
alias -g NUL="> /dev/null 2>&1"
alias -g P="2>&1| pygmentize -l pytb"

alias dud='du -d 1 -h'
alias duf='du -sh *'
alias fd='find . -type d -name'
alias ff='find . -type f -name'

alias h='history'
alias hgrep="fc -El 0 | grep"
alias help='man'
alias p='ps -f'
alias sortnr='sort -n -r'
alias unexport='unset'

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias vim='vim'
alias vi='vim'
alias gds-start='sudo systemctl start openvpn-client@gds'
alias gds-stop='sudo systemctl stop openvpn-client@gds'
gitpush() {
    git add .
    git commit -m "$*"
    git pull
    git push
}
gitupdate() {
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/github
    ssh -T git@github.com
}
alias gp=gitpush
alias gu=gitupdate
alias lbrynet='/opt/LBRY/resources/static/daemon/lbrynet'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias prisma-go="go run github.com/steebchen/prisma-client-go"

#######################################################
# Aliases
#######################################################

alias c='clear'
alias q='exit'
alias ..='cd ..'
alias mkdir='mkdir -pv'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -iv'
alias rmdir='rmdir -v'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Alias for neovim
if [[ -x "$(command -v nvim)" ]]; then
	alias vi='nvim'
	alias vim='nvim'
	alias svi='sudo nvim'
	alias vis='nvim "+set si"'
elif [[ -x "$(command -v vim)" ]]; then
	alias vi='vim'
	alias svi='sudo vim'
	alias vis='vim "+set si"'
fi

# Alias to launch a document, file, or URL in it's default X application
if [[ -x "$(command -v xdg-open)" ]]; then
	alias open='runfree xdg-open'
fi

# Alias to launch a document, file, or URL in it's default PDF reader
if [[ -x "$(command -v evince)" ]]; then
    alias pdf='runfree evince'
fi

# Alias For bat
# Link: https://github.com/sharkdp/bat
if [[ -x "$(command -v bat)" ]]; then
    alias cat='bat --paging=never'
fi

# Alias for lazygit
# Link: https://github.com/jesseduffield/lazygit
if [[ -x "$(command -v lazygit)" ]]; then
    alias lg='lazygit'
fi

# Alias for FZF
# Link: https://github.com/junegunn/fzf
if [[ -x "$(command -v fzf)" ]]; then
    alias fzf='fzf --preview "bat --style=numbers --color=always --line-range :500 {}"'
    # Alias to fuzzy find files in the current folder(s), preview them, and launch in an editor
	if [[ -x "$(command -v xdg-open)" ]]; then
		alias preview='open $(fzf --info=inline --query="${@}")'
	else
		alias preview='edit $(fzf --info=inline --query="${@}")'
	fi
fi

# Get local IP addresses
if [[ -x "$(command -v ip)" ]]; then
    alias iplocal="ip -br -c a"
else
    alias iplocal="ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'"
fi

# Get public IP addresses
if [[ -x "$(command -v curl)" ]]; then
    alias ipexternal="curl -s ifconfig.me && echo"
elif [[ -x "$(command -v wget)" ]]; then
    alias ipexternal="wget -qO- ifconfig.me && echo"
fi


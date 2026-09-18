# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
if [[ -o interactive ]] && [[ -z "$FASTFETCH_SHOWN" ]] && [[ -z "$TMUX" ]]; then
    export FASTFETCH_SHOWN=1
    
    LOGOS_DIR="$HOME/.config/rice/fastfetch/logos"
    LAST_LOGOS_FILE="$HOME/.cache/last_ff_logos"
    touch "$LAST_LOGOS_FILE" # Ensure the file exists
    
    # 1. Get all logos
    ALL_LOGOS=$(ls "$LOGOS_DIR"/*.txt 2>/dev/null)
    
    # 2. Filter out the last 3 logos
    # -s checks if the cache file is not empty to prevent grep errors
    if [[ -s "$LAST_LOGOS_FILE" ]]; then
        # grep -vFf reads the cache file line by line and removes those exact matches from ALL_LOGOS
        AVAILABLE_LOGOS=$(echo "$ALL_LOGOS" | grep -vFf "$LAST_LOGOS_FILE")
    else
        AVAILABLE_LOGOS="$ALL_LOGOS"
    fi
    
    # Failsafe: If you have 3 or fewer total files, filtering them all out leaves nothing.
    # This catches that and resets the pool so it doesn't break.
    if [[ -z "$AVAILABLE_LOGOS" ]]; then
        AVAILABLE_LOGOS="$ALL_LOGOS"
    fi
    
    # 3. Pick a random logo from the remaining available pool
    NEXT_LOGO=$(echo "$AVAILABLE_LOGOS" | shuf -n 1)
    
    # 4. Update the history cache
    # This puts the new logo at the top, adds the old ones below it, and keeps only the top 3 lines
    echo -e "$NEXT_LOGO\n$(cat "$LAST_LOGOS_FILE")" | head -n 3 > "$LAST_LOGOS_FILE"
    
    # 5. Random Color Logic
    # 31=Red, 32=Green, 33=Yellow, 34=Blue, 35=Magenta, 36=Cyan
    RAND_COLOR=$((31 + RANDOM % 6))
    
    # 6. Launch Fastfetch
    fastfetch --logo-type file --logo "$NEXT_LOGO" --logo-color-1 "$RAND_COLOR"
fi
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#aa9ca3"   # matches colors.bright.black from your palette
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
eval "$(starship init zsh)"
# Created by `pipx` on 2026-05-31 13:52:13
export PATH="$PATH:/home/tanishk/.local/bin"

eval $(thefuck --alias)

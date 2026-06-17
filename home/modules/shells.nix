{ config, pkgs, lib, ... }:

let
  keychainInit = ''
    # Keychain (only when no forwarded agent)
    if [ -z "$SSH_AUTH_SOCK" ]; then
        eval $(keychain --eval --systemd --quiet $(grep -rl "PRIVATE KEY" ~/.ssh/ 2>/dev/null))
    fi
  '';
in
{
  config = {
    # Bash
    programs.bash.enable = true;
    programs.bash.initExtra = ''
      [ -f ~/.bash_aliases ] && source ~/.bash_aliases
      [ -f ~/.bash_aliases.git ] && source ~/.bash_aliases.git

      ${keychainInit}
    '';

    # Direnv
    programs.direnv.enable = true;
    programs.direnv.nix-direnv.enable = true;
    programs.dircolors.enable = true;

    # Shared aliases
    home.file.".bash_aliases".source = ../dotfiles/bash_aliases;
    home.file.".bash_aliases.git".source = ../dotfiles/bash_aliases.git;

    # Zsh
    programs.zsh.enable = true;
    programs.zsh.autocd = true;
    programs.zsh.defaultKeymap = "viins";

    programs.zsh.history.path = "${config.home.homeDirectory}/.histfile";
    programs.zsh.history.size = 100000;
    programs.zsh.history.ignoreAllDups = true;
    programs.zsh.history.ignoreSpace = true;
    programs.zsh.history.ignorePatterns = [ "rm *" "pkill *" ];
    programs.zsh.history.append = true;
    programs.zsh.history.share = false;

    programs.zsh.setOptions = [
      "autopushd"
      #"extendedglob" # Too much, apparently not needed for *(/).
      "prompt_sp"
      "NO_BEEP"
    ];

    programs.zsh.initContent = lib.mkMerge [
      (lib.mkOrder 1000 ''
        # Completion styles
        zstyle ':completion:*:descriptions' format '%U%B%d%b%u'
        zstyle ':completion:*:warnings' format '%BSorry, no matches for: %d%b'
        zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin \
                                     /usr/sbin /usr/bin /sbin /bin /usr/X11R6/bin
        zstyle ':completion:*' menu select=2
        zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
        zstyle ':completion:*:*:kill:*:processes' list-colors "=(#b) #([0-9]#)*=36=31"
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
        zstyle ':completion::*:(vi|vim|gvim|gv):*' file-patterns '*~*.(aux|dvi|idx|pdf|rel|png|jpg|asc|raw)' '*'
        zstyle ':completion::*:(ev|evince):*' file-patterns '*.pdf:pdf-files *(-/):directories *.(dvi|ps):other' '*'
        export CORRECT_IGNORE=".vim"

        zmodload zsh/complist

        if [ -f ~/.bash_aliases ]; then
            . ~/.bash_aliases
        fi

        # Useful zsh builtins
        autoload -U zfinit
        zfinit
        autoload -U zcalc
        autoload -U zmv
        autoload -U zargs

        # Prompt (adam2) with custom color per host.
        case "$(hostname)" in
            klatch*)       host_color=yellow ;;
            sto-lat*)      host_color=magenta ;;
            ankh-morpork*) host_color=cyan ;;
            uberwald*)     host_color=blue ;;
        esac
        autoload -U promptinit
        promptinit
        prompt adam2 cyan green $host_color white

        ### key bindings

        bindkey "^H" backward-delete-word

        # vi mode tweaks
        export KEYTIMEOUT=1 # So <esc> acts faster (0.1s).
        function zle-keymap-select {
            zle reset-prompt
        }
        zle -N zle-keymap-select

        # terminfo bindings
        typeset -g -A key

        key[Home]="''${terminfo[khome]}"
        key[End]="''${terminfo[kend]}"
        key[Insert]="''${terminfo[kich1]}"
        key[Backspace]="''${terminfo[kbs]}"
        key[Delete]="''${terminfo[kdch1]}"
        key[Up]="''${terminfo[kcuu1]}"
        key[Down]="''${terminfo[kcud1]}"
        key[Left]="''${terminfo[kcub1]}"
        key[Right]="''${terminfo[kcuf1]}"
        key[PageUp]="''${terminfo[kpp]}"
        key[PageDown]="''${terminfo[knp]}"
        key[ShiftTab]="''${terminfo[kcbt]}"

        [[ -n "''${key[Home]}"      ]] && bindkey -- "''${key[Home]}"      beginning-of-line
        [[ -n "''${key[End]}"       ]] && bindkey -- "''${key[End]}"       end-of-line
        [[ -n "''${key[Insert]}"    ]] && bindkey -- "''${key[Insert]}"    overwrite-mode
        [[ -n "''${key[Backspace]}" ]] && bindkey -- "''${key[Backspace]}" backward-delete-char
        [[ -n "''${key[Delete]}"    ]] && bindkey -- "''${key[Delete]}"    delete-char
        [[ -n "''${key[Left]}"      ]] && bindkey -- "''${key[Left]}"      backward-char
        [[ -n "''${key[Right]}"     ]] && bindkey -- "''${key[Right]}"     forward-char
        [[ -n "''${key[PageUp]}"    ]] && bindkey -- "''${key[PageUp]}"    beginning-of-buffer-or-history
        [[ -n "''${key[PageDown]}"  ]] && bindkey -- "''${key[PageDown]}"  end-of-buffer-or-history
        [[ -n "''${key[ShiftTab]}"  ]] && bindkey -- "''${key[ShiftTab]}"  reverse-menu-complete

        # Application mode for correct terminfo values in zle
        if (( ''${+terminfo[smkx]} && ''${+terminfo[rmkx]} )); then
            autoload -Uz add-zle-hook-widget
            function zle_application_mode_start { echoti smkx }
            function zle_application_mode_stop { echoti rmkx }
            add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
            add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
        fi

        # History search with up/down arrows
        autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search
        [[ -n "''${key[Up]}"   ]] && bindkey -- "''${key[Up]}"   up-line-or-beginning-search
        [[ -n "''${key[Down]}" ]] && bindkey -- "''${key[Down]}" down-line-or-beginning-search
        bindkey          "^R" history-incremental-search-backward
        bindkey -M main  "^R" history-incremental-search-backward
        bindkey -M vicmd "^R" history-incremental-search-backward

        # Automatic rehash after package installs
        autoload -U add-zsh-hook
        TRAPUSR1() { rehash };
        precmd_install() { [[ $history[$[ HISTCMD -1 ]] == *(yaourt|pacman|pip|gem|nix-env|nixos-rebuild|home-manager|nix-update)* ]] && killall -USR1 zsh || true }
        add-zsh-hook precmd precmd_install

        # RPROMPT showing current environment
        RPROMPT='%F{green}$(detect_env)%f'
        function detect_env () {
            envs=($KEYMAP
                ''${IN_NIX_SHELL+nix} \
                ''${VCSH_DIRECTORY+vcsh} \
                ''${VIRTUAL_ENV+virtualenv} \
                ''${NIX_REMOTE+store} \
                ''${DIRENV_DIFF+direnv}\
            );
            [ -z "$VCSH_DIRECTORY" -a -n "$GIT_DIR" ] && envs+=("git")
            local IFS=',' envs="$envs[*]"
            echo "''${envs:+"($envs)"}"
        }

        # Keychain
        ${keychainInit}
      '')
    ];
  };
}

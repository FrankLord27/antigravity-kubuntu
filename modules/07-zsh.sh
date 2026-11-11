#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — modules/07-zsh.sh [Debian 13 / Ubuntu 26.04]
#  ZSH + Oh My Zsh + Powerlevel10k + MesloLGS NF
#
#  ORDEN:
#  ① Backup de todo antes de tocar nada
#  ② ZSH como shell por defecto
#  ③ Oh My Zsh limpio
#  ④ Plugins: autosuggestions + syntax-highlighting + completions
#  ⑤ Powerlevel10k + config predefinida (sin wizard al arrancar)
#  ⑥ Fuentes MesloLGS NF (iconos de Powerlevel10k)
#  ⑦ .zshrc completo con nvm, aliases, docker, git
#  ⑧ Konsole: perfil con MesloLGS NF como predeterminado
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

run_module_zsh() {
    ui_step "MÓDULO 07 — ZSH + POWERLEVEL10K"
    ui_panel_start "ZSH completo"
    export DEBIAN_FRONTEND=noninteractive
    local real_user="${SUDO_USER:-$USER}"
    local real_home; real_home=$(eval echo "~$real_user")

    _backup_config "$real_home"
    _install_zsh "$real_user" "$real_home"
    _install_oh_my_zsh "$real_user" "$real_home"
    _install_plugins "$real_user" "$real_home"
    _install_powerlevel10k "$real_user" "$real_home"
    _install_meslo_fonts "$real_user" "$real_home"
    _write_zshrc "$real_user" "$real_home"
    _configure_konsole "$real_user" "$real_home"

    ui_panel_end; ui_ok "Módulo 07 completado"
    _show_post_instructions "$real_user"
}

# ─── FASE 1: BACKUP ──────────────────────────────────────────────────────────
_backup_config() {
    local home="$1"
    local bdir="${home}/.auto-setup-backup-$(date '+%Y%m%d_%H%M%S')"
    ui_info "Creando backup de configuración existente..."
    mkdir -p "$bdir"
    local backed=false
    for f in .zshrc .zshrc.bak .p10k.zsh .bashrc; do
        [[ -f "${home}/${f}" ]] && cp "${home}/${f}" "${bdir}/${f}" && backed=true
    done
    [[ -d "${home}/.oh-my-zsh/custom" ]] && \
        cp -r "${home}/.oh-my-zsh/custom" "${bdir}/oh-my-zsh-custom" && backed=true
    $backed && ui_ok "Backup guardado en: $bdir" || ui_info "Sin configuración previa — instalación limpia"
    _log "OK" "Backup: $bdir"
}

# ─── FASE 2: ZSH ─────────────────────────────────────────────────────────────
_install_zsh() {
    local real_user="$1" home="$2"
    is_deb_installed zsh && ui_skip "ZSH ya instalado" \
        || run_cmd 2 "Instalar zsh" apt install -y zsh
    local current; current=$(getent passwd "$real_user" | cut -d: -f7)
    [[ "$current" == "$(which zsh)" ]] && ui_skip "ZSH ya es el shell por defecto" || {
        run_cmd 2 "chsh -s zsh" chsh -s "$(which zsh)" "$real_user"
        ui_ok "Shell cambiado a ZSH (activa en próximo login)"
    }
}

# ─── FASE 3: OH MY ZSH ───────────────────────────────────────────────────────
_install_oh_my_zsh() {
    local real_user="$1" home="$2"
    [[ -d "${home}/.oh-my-zsh" ]] && { ui_skip "Oh My Zsh ya instalado"; return; }
    run_cmd 2 "Instalar Oh My Zsh" sudo -u "$real_user" bash -c \
        'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    [[ -d "${home}/.oh-my-zsh" ]] && ui_ok "Oh My Zsh instalado" || ui_fail "Oh My Zsh no se instaló"
}

# ─── FASE 4: PLUGINS ─────────────────────────────────────────────────────────
_install_plugins() {
    local real_user="$1" home="$2"
    local pdir="${home}/.oh-my-zsh/custom/plugins"
    sudo -u "$real_user" mkdir -p "$pdir"
    for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
        [[ -d "${pdir}/${plugin}" ]] && ui_skip "$plugin ya instalado" || \
            run_cmd 2 "Instalar $plugin" sudo -u "$real_user" \
                git clone --depth=1 "https://github.com/zsh-users/${plugin}" "${pdir}/${plugin}"
    done
}

# ─── FASE 5: POWERLEVEL10K ───────────────────────────────────────────────────
_install_powerlevel10k() {
    local real_user="$1" home="$2"
    local tdir="${home}/.oh-my-zsh/custom/themes"
    sudo -u "$real_user" mkdir -p "$tdir"
    [[ -d "${tdir}/powerlevel10k" ]] && ui_skip "Powerlevel10k ya instalado" || \
        run_cmd 2 "Instalar Powerlevel10k" sudo -u "$real_user" \
            git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${tdir}/powerlevel10k"
    [[ -f "${home}/.p10k.zsh" ]] && ui_skip ".p10k.zsh ya existe" || _write_p10k_config "$home" "$real_user"
}

# ─── FASE 6: FUENTES MESLO LGS NF ────────────────────────────────────────────
_install_meslo_fonts() {
    local real_user="$1" home="$2"
    local fdir="${home}/.local/share/fonts"
    sudo -u "$real_user" mkdir -p "$fdir"
    ui_info "Instalando fuentes MesloLGS NF..."
    local base="https://github.com/romkatv/powerlevel10k-media/raw/master"
    local ok=true
    for font in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
        local fp="${fdir}/${font}"
        [[ -f "$fp" ]] && ui_skip "Fuente: $font" || {
            local enc; enc=$(echo "$font" | sed 's/ /%20/g')
            run_cmd 2 "Descargar $font" sudo -u "$real_user" \
                curl -fsSL "${base}/${enc}" -o "$fp" || ok=false
        }
    done
    $ok && run_cmd 1 "Actualizar caché fuentes" sudo -u "$real_user" fc-cache -fv \
        && ui_ok "Fuentes MesloLGS NF instaladas" \
        || ui_warn "Algunas fuentes no se descargaron — iconos pueden no verse"
}

# ─── FASE 7: .ZSHRC COMPLETO ─────────────────────────────────────────────────
_write_zshrc() {
    local real_user="$1" home="$2"
    ui_info "Escribiendo .zshrc completo..."
    local cuda_block=""
    [[ -d /usr/local/cuda ]] && cuda_block='
# CUDA
export PATH="/usr/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"'
    local gpu_alias=""
    command -v nvidia-smi &>/dev/null && gpu_alias="alias gpu='nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu --format=csv,noheader'"
    sudo -u "$real_user" tee "${home}/.zshrc" > /dev/null << ZSHRC
# ============================================================
#  .zshrc — AUTO SETUP [Debian 13 / Ubuntu 26.04]
#  Frank Felix Rodríguez — $(date '+%Y-%m-%d')
# ============================================================

# Powerlevel10k instant prompt (debe ir primero)
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi

# Oh My Zsh
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git sudo docker zsh-autosuggestions zsh-syntax-highlighting zsh-completions)

source \$ZSH/oh-my-zsh.sh

# Historial
HISTSIZE=10000; SAVEHIST=10000; HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY

# nvm — Node Version Manager (Node ${NODE_VERSION:-26} + pnpm via corepack)
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \\. "\$NVM_DIR/bash_completion"
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0   # que pnpm (corepack) no pregunte al bajarse
${cuda_block}

# Herramientas modernas
command -v eza &>/dev/null && {
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -la --icons --group-directories-first'
  alias lt='eza --tree --icons --level=2'
}
# En Debian `bat` se llama batcat y `fd` se llama fdfind.
if command -v bat &>/dev/null; then alias cat='bat --style=plain --paging=never'
elif command -v batcat &>/dev/null; then alias bat='batcat'; alias cat='batcat --style=plain --paging=never'; fi
command -v fdfind &>/dev/null && ! command -v fd &>/dev/null && alias fd='fdfind'

# Programas instalados en tu carpeta (claude, uv…)
export PATH="\$HOME/.local/bin:\$PATH"

# Aliases generales
alias cls='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'; alias du='du -h'; alias free='free -h'

# Docker
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dlog='docker logs -f'
alias dex='docker exec -it'
alias dprune='docker system prune -af'

# Git
alias gs='git status'; alias ga='git add .'
alias gc='git commit -m'; alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline --graph --decorate --all'

# Sistema
alias ports='ss -tulanp'
alias myip='curl -s ifconfig.me'
alias update='sudo apt update && sudo apt upgrade -y'
alias sysinfo='inxi -Fxz'
alias temp='sensors 2>/dev/null | grep -E "temp|Core|fan"'
${gpu_alias}

# Auto Setup
alias ag-setup='sudo bash \$HOME/antigravity-kubuntu/setup.sh'
alias ag-diag='sudo bash \$HOME/antigravity-kubuntu/modules/00-diagnostics.sh'
alias ag-verify='sudo bash \$HOME/antigravity-kubuntu/modules/90-verify.sh'

# Autocompletado
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c6c6c'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey '^ ' autosuggest-accept

# Powerlevel10k
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Claude Code (ai-lordkit): habilita claude --modo X y claude --kimi
[ -f "\$HOME/.claude/shell-init.sh" ] && . "\$HOME/.claude/shell-init.sh"

# TUS ajustes van en ~/.zshrc.local: este archivo se regenera, ese nunca se toca.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
ZSHRC
    chown "${real_user}:${real_user}" "${home}/.zshrc"
    ui_ok ".zshrc completo escrito"
}

# ─── CONFIG POWERLEVEL10K PREDEFINIDA ────────────────────────────────────────
_write_p10k_config() {
    local home="$1" real_user="$2"
    sudo -u "$real_user" tee "${home}/.p10k.zsh" > /dev/null << 'P10K'
# Powerlevel10k config — AUTO SETUP
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs newline prompt_char)
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs node_version time)

  typeset -g POWERLEVEL9K_MODE=nerdfont-v3
  typeset -g POWERLEVEL9K_ICON_PADDING=moderate

  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'

  typeset -g POWERLEVEL9K_DIR_FOREGROUND=31
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=39
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true

  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON='\uF126 '
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=39

  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=101
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=66
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=232
  typeset -g POWERLEVEL9K_OS_ICON_BACKGROUND=6
  typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND=70
  typeset -g POWERLEVEL9K_NODE_ICON='\uF898'
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=false

  (( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
} always { unset p10k_config_opts }
P10K
    chown "${real_user}:${real_user}" "${home}/.p10k.zsh"
    ui_ok ".p10k.zsh configurado (git, node, tiempo, directorio)"
}

# ─── FASE 8: KONSOLE ─────────────────────────────────────────────────────────
_configure_konsole() {
    local real_user="$1" home="$2"
    local kdir="${home}/.local/share/konsole"
    sudo -u "$real_user" mkdir -p "$kdir"
    local pf="${kdir}/Auto Setup.profile"
    [[ -f "$pf" ]] && ui_skip "Perfil Konsole Auto Setup ya existe" || {
        sudo -u "$real_user" tee "$pf" > /dev/null << 'PROFILE'
[Appearance]
ColorScheme=Breeze
Font=MesloLGS NF,13,-1,5,50,0,0,0,0,0

[General]
Command=/usr/bin/zsh
Name=Auto Setup
Parent=FALLBACK/
TerminalColumns=120
TerminalRows=30

[Scrolling]
HistorySize=10000
ScrollBarPosition=2
PROFILE
        ui_ok "Perfil Konsole 'Auto Setup' creado con MesloLGS NF"
    }

    local konsolerc="${home}/.config/konsolerc"
    if grep -q 'Auto Setup' "$konsolerc" 2>/dev/null; then
        ui_skip "Perfil Auto Setup ya predeterminado"
    else
        sudo -u "$real_user" bash -c \
            "grep -q 'DefaultProfile' '$konsolerc' 2>/dev/null && \
            sed -i 's/DefaultProfile=.*/DefaultProfile=Auto Setup.profile/' '$konsolerc' || \
            { mkdir -p '${home}/.config'; printf '[Desktop Entry]\nDefaultProfile=Auto Setup.profile\n' >> '$konsolerc'; }"
        ui_ok "Perfil Auto Setup establecido como predeterminado"
    fi
}


# ─── INSTRUCCIONES FINALES ────────────────────────────────────────────────────
_show_post_instructions() {
    echo ""
    echo -e "${C_BOLD}  ┌─ PASOS FINALES ───────────────────────────────────────────┐${C_RESET}"
    echo -e "  │                                                            │"
    echo -e "  │  ${C_WHITE}1.${C_RESET} Reinicia: ${C_DIM}sudo reboot${C_RESET}                               │"
    echo -e "  │                                                            │"
    echo -e "  │  ${C_WHITE}2.${C_RESET} Si ves cuadros en vez de iconos en ZSH:             │"
    echo -e "  │     Konsole → Settings → Edit Profile → Appearance         │"
    echo -e "  │     → Font → Selecciona ${C_CYAN}MesloLGS NF${C_RESET}                         │"
    echo -e "  │                                                            │"
    echo -e "  │  ${C_WHITE}3.${C_RESET} Para reconfigurar tema ZSH: ${C_DIM}p10k configure${C_RESET}          │"
    echo -e "  │                                                            │"
    echo -e "  │                                                            │"
    printf  "  │  ${C_WHITE}Backup:${C_RESET} ${C_DIM}~/.auto-setup-backup-*${C_RESET}%-34s│\n" ""
    echo -e "  └────────────────────────────────────────────────────────────┘"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/07-zsh.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_zsh; ui_summary
fi

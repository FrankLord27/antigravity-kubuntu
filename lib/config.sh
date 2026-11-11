#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — lib/config.sh
#  Datos personales de la instalación. Se preguntan UNA vez, al inicio, y se
#  guardan en configs/local.conf (fuera de git). Después nada más pregunta.
#
#  Variables: GIT_NAME, GIT_EMAIL
# =============================================================================

CONFIG_LOCAL="${SCRIPT_DIR}/configs/local.conf"
export GIT_NAME="${GIT_NAME:-}" GIT_EMAIL="${GIT_EMAIL:-}"

# Usuario real (el que lanzó sudo/su) y su carpeta personal.
real_user() { echo "${SUDO_USER:-$USER}"; }
real_home() { getent passwd "$(real_user)" | cut -d: -f6; }

config_load() {
    # shellcheck disable=SC1090
    [[ -f "$CONFIG_LOCAL" ]] && source "$CONFIG_LOCAL"
    local ru; ru="$(real_user)"
    # Si ya había identidad de git configurada, se respeta.
    [[ -z "$GIT_NAME"  ]] && GIT_NAME=$(sudo -u "$ru" git config --global user.name  2>/dev/null || true)
    [[ -z "$GIT_EMAIL" ]] && GIT_EMAIL=$(sudo -u "$ru" git config --global user.email 2>/dev/null || true)
    export GIT_NAME GIT_EMAIL
}

config_save() {
    local ru; ru="$(real_user)"
    {
        echo "# AUTO SETUP — datos personales (no se sube a git)"
        printf 'GIT_NAME=%q\n'  "$GIT_NAME"
        printf 'GIT_EMAIL=%q\n' "$GIT_EMAIL"
    } > "$CONFIG_LOCAL"
    chown "$ru":"$ru" "$CONFIG_LOCAL" 2>/dev/null || true
    chmod 600 "$CONFIG_LOCAL"
}

# Pregunta lo que falte. Sin terminal no pregunta: usa lo que haya.
config_ask() {
    config_load
    [[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]] && return 0
    if ! ( exec </dev/tty ) 2>/dev/null; then
        echo "  (sin terminal: la identidad de git queda pendiente — sudo bash modules/08-git.sh)"
        return 0
    fi
    echo ""
    echo -e "${C_BOLD}  Dos datos y no pregunto más (son para firmar tus commits de git):${C_RESET}"
    local ans
    if [[ -z "$GIT_NAME" ]]; then
        echo -ne "  ${C_CYAN}Nombre completo: ${C_RESET}"; read -r ans </dev/tty || true; GIT_NAME="$ans"
    fi
    if [[ -z "$GIT_EMAIL" ]]; then
        echo -ne "  ${C_CYAN}Email (el de tu cuenta de GitHub): ${C_RESET}"; read -r ans </dev/tty || true; GIT_EMAIL="$ans"
    fi
    export GIT_NAME GIT_EMAIL
    [[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]] && config_save
    echo ""
}

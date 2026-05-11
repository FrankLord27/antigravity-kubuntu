#!/usr/bin/env bash
# ANTIGRAVITY — modules/10-git.sh [Kubuntu 26.04 LTS]
# Git completo: identidad interactiva, aliases, SSH key, configuración global

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

_ask_git_identity() {
    local real_user="$1"
    local current_name; current_name=$(sudo -u "$real_user" git config --global user.name  2>/dev/null || echo "")
    local current_email; current_email=$(sudo -u "$real_user" git config --global user.email 2>/dev/null || echo "")

    echo ""
    ui_info "Identidad de Git — se usará en todos tus commits"
    [[ -n "$current_name"  ]] && echo -e "  ${C_DIM}Nombre actual : $current_name${C_RESET}"
    [[ -n "$current_email" ]] && echo -e "  ${C_DIM}Email actual  : $current_email${C_RESET}"
    echo ""

    local git_name git_email

    if ${GUM_AVAILABLE:-false} && command -v gum &>/dev/null; then
        git_name=$(gum input \
            --placeholder "${current_name:-Frank Rodriguez}" \
            --prompt "  ➤ Nombre completo: " \
            --value "${current_name}" < /dev/tty 2>/dev/tty) || git_name="$current_name"
        git_email=$(gum input \
            --placeholder "${current_email:-frank@email.com}" \
            --prompt "  ➤ Email          : " \
            --value "${current_email}" < /dev/tty 2>/dev/tty) || git_email="$current_email"
    else
        echo -ne "  ${C_CYAN}${C_BOLD}Nombre completo${C_RESET}${C_CYAN} [${current_name:-Frank Rodriguez}]: ${C_RESET}"
        read -r git_name < /dev/tty
        [[ -z "$git_name" ]] && git_name="$current_name"
        echo -ne "  ${C_CYAN}${C_BOLD}Email           ${C_RESET}${C_CYAN} [${current_email:-frank@email.com}]: ${C_RESET}"
        read -r git_email < /dev/tty
        [[ -z "$git_email" ]] && git_email="$current_email"
    fi

    if [[ -z "$git_name" ]] || [[ -z "$git_email" ]]; then
        ui_warn "Nombre o email vacío — identidad no configurada"
        return 1
    fi

    run_cmd 1 "Git user.name"  sudo -u "$real_user" git config --global user.name  "$git_name"
    run_cmd 1 "Git user.email" sudo -u "$real_user" git config --global user.email "$git_email"
    ui_ok "Identidad configurada: ${C_WHITE}$git_name${C_RESET} <${git_email}>"
}

_configure_git_settings() {
    local real_user="$1"
    ui_info "Aplicando configuración global recomendada..."

    # Comportamiento base
    run_cmd 1 "defaultBranch = main"  sudo -u "$real_user" git config --global init.defaultBranch main
    run_cmd 1 "pull.rebase false"     sudo -u "$real_user" git config --global pull.rebase     false
    run_cmd 1 "core.autocrlf input"   sudo -u "$real_user" git config --global core.autocrlf   input
    run_cmd 1 "core.editor nano"      sudo -u "$real_user" git config --global core.editor      nano
    run_cmd 1 "color.ui auto"         sudo -u "$real_user" git config --global color.ui         auto
    run_cmd 1 "push.default current"  sudo -u "$real_user" git config --global push.default     current
    run_cmd 1 "credential cache 1h"   sudo -u "$real_user" git config --global credential.helper "cache --timeout=3600"

    # Aliases útiles para el día a día
    run_cmd 1 "alias: st  → status"   sudo -u "$real_user" git config --global alias.st   status
    run_cmd 1 "alias: co  → checkout" sudo -u "$real_user" git config --global alias.co   checkout
    run_cmd 1 "alias: br  → branch"   sudo -u "$real_user" git config --global alias.br   branch
    run_cmd 1 "alias: lg  → log gráfico" sudo -u "$real_user" git config --global alias.lg \
        "log --oneline --graph --decorate --all"
    run_cmd 1 "alias: undo → reset HEAD~1" sudo -u "$real_user" git config --global alias.undo \
        "reset HEAD~1 --mixed"
    run_cmd 1 "alias: save → stash"   sudo -u "$real_user" git config --global alias.save \
        "stash push -m"
    run_cmd 1 "alias: aliases → listar" sudo -u "$real_user" git config --global alias.aliases \
        "config --get-regexp alias"

    ui_ok "Git configurado con aliases: st, co, br, lg, undo, save, aliases"
}

_setup_ssh_key() {
    local real_user="$1"
    local real_home; real_home=$(eval echo "~$real_user")
    local ssh_key="${real_home}/.ssh/id_ed25519"

    if [[ -f "$ssh_key" ]]; then
        ui_skip "SSH key ya existe: $ssh_key"
        echo ""
        echo -e "  ${C_BOLD}Clave pública (para GitHub/GitLab → Settings → SSH Keys):${C_RESET}"
        cat "${ssh_key}.pub" 2>/dev/null | sed 's/^/  /'
        echo ""
        return
    fi

    local git_email; git_email=$(sudo -u "$real_user" git config --global user.email 2>/dev/null || echo "")
    if [[ -z "$git_email" ]]; then
        ui_warn "Configura el email de Git primero para generar la SSH key"
        return
    fi

    local do_ssh=false
    if ${GUM_AVAILABLE:-false} && command -v gum &>/dev/null; then
        gum confirm "  ¿Generar clave SSH ed25519 para GitHub/GitLab?" \
            --affirmative="Sí, generar" --negative="Omitir" < /dev/tty 2>/dev/null && do_ssh=true
    else
        ui_confirm "¿Generar clave SSH ed25519 para GitHub/GitLab?" && do_ssh=true
    fi
    $do_ssh || return

    run_cmd 2 "Crear ~/.ssh"          mkdir -p "${real_home}/.ssh"
    chown "$real_user":"$real_user" "${real_home}/.ssh" 2>/dev/null || true
    run_cmd 2 "Permisos ~/.ssh 700"   chmod 700 "${real_home}/.ssh"
    run_cmd 2 "Generar ed25519 key"   sudo -u "$real_user" \
        ssh-keygen -t ed25519 -C "$git_email" -f "$ssh_key" -N ""
    run_cmd 1 "Permisos key 600"      chmod 600 "$ssh_key"
    run_cmd 1 "GitHub → known_hosts"  sudo -u "$real_user" bash -c \
        "ssh-keyscan -t ed25519 github.com >> '${real_home}/.ssh/known_hosts' 2>/dev/null"

    echo ""
    echo -e "${C_BOLD}  ╔══ CLAVE PÚBLICA SSH — CÓPIALA EN GITHUB / GITLAB ══╗${C_RESET}"
    echo -e "${C_BOLD}  ║  github.com → Settings → SSH and GPG Keys → New   ║${C_RESET}"
    echo -e "${C_BOLD}  ╚════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "  ${C_CYAN}$(cat "${ssh_key}.pub" 2>/dev/null)${C_RESET}"
    echo ""
    ui_ok "SSH key lista: $ssh_key"
}

run_module_git() {
    ui_step "MÓDULO 10 — GIT SETUP"
    ui_panel_start "Identidad + Aliases + SSH key"
    local real_user="${SUDO_USER:-$USER}"

    is_deb_installed git && ui_skip "git (ya instalado)" \
        || run_cmd 2 "Instalar git" apt install -y git

    _ask_git_identity    "$real_user"
    _configure_git_settings "$real_user"
    _setup_ssh_key       "$real_user"

    ui_panel_end; ui_ok "Módulo 10 completado"

    # Resumen final
    local gn; gn=$(sudo -u "$real_user" git config --global user.name  2>/dev/null || echo "—")
    local ge; ge=$(sudo -u "$real_user" git config --global user.email 2>/dev/null || echo "—")
    echo -e "  ${C_DIM}Identidad activa: ${C_WHITE}${gn}${C_RESET} ${C_DIM}<${ge}>${C_RESET}"
    echo -e "  ${C_DIM}Aliases: ${C_CYAN}git st, git lg, git co, git br, git undo, git save${C_RESET}"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/10-git.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_git; ui_summary
fi

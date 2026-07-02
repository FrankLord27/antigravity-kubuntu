#!/usr/bin/env bash
# =============================================================================
#  KUBUNTU AUTO SETUP — modules/12-apps.sh [Kubuntu 26.04 LTS]
#  Apps personales auditadas del sistema real (2026-07-02)
#  Lee las listas de configs/packages.conf — comenta ahí lo que no quieras.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/configs/packages.conf"

_install_apt_apps() {
    ui_info "Instalando apps apt (${#PKGS_APPS_EXTRA[@]} paquetes)..."
    for pkg in "${PKGS_APPS_EXTRA[@]}"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 2 "Instalar $pkg" apt install -y "$pkg"
    done
}

_install_anydesk() {
    [[ "${INSTALL_ANYDESK:-false}" == "true" ]] || { ui_skip "AnyDesk (desactivado en packages.conf)"; return 0; }
    is_deb_installed anydesk && { ui_skip "anydesk"; return 0; }
    ui_info "Configurando repo oficial de AnyDesk..."
    run_cmd 2 "GPG key AnyDesk" bash -c \
        "curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY | gpg --dearmor -o /usr/share/keyrings/anydesk.gpg"
    run_cmd 2 "Repo AnyDesk" bash -c \
        "echo 'deb [signed-by=/usr/share/keyrings/anydesk.gpg] https://deb.anydesk.com all main' > /etc/apt/sources.list.d/anydesk.list"
    run_cmd 2 "apt update post-AnyDesk" apt update
    run_cmd 2 "Instalar anydesk" apt install -y anydesk
}

_install_teamviewer() {
    [[ "${INSTALL_TEAMVIEWER:-false}" == "true" ]] || { ui_skip "TeamViewer (desactivado en packages.conf)"; return 0; }
    is_deb_installed teamviewer && { ui_skip "teamviewer"; return 0; }
    ui_info "Descargando TeamViewer (.deb oficial)..."
    local tmp; tmp=$(mktemp -d)
    run_cmd 2 "Descargar TeamViewer" curl -fsSL -o "${tmp}/teamviewer.deb" \
        "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb" \
        && run_cmd 2 "Instalar teamviewer" apt install -y "${tmp}/teamviewer.deb"
    rm -rf "$tmp"
}

_install_snap_apps() {
    command -v snap &>/dev/null || { ui_warn "snap no disponible — omitiendo apps snap"; return 0; }
    for app in "${SNAP_APPS[@]}"; do
        snap list "$app" &>/dev/null && ui_skip "snap: $app" || run_cmd 2 "snap install $app" snap install "$app"
    done
    for app in "${SNAP_APPS_CLASSIC[@]}"; do
        snap list "$app" &>/dev/null && ui_skip "snap: $app" || run_cmd 2 "snap install $app (classic)" snap install "$app" --classic
    done
}

_install_flatpak_apps() {
    if ! command -v flatpak &>/dev/null; then
        run_cmd 2 "Instalar flatpak" apt install -y flatpak
    fi
    flatpak remotes 2>/dev/null | grep -q flathub \
        || run_cmd 2 "Agregar Flathub" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    for app in "${FLATPAK_APPS[@]}"; do
        flatpak info "$app" &>/dev/null && ui_skip "flatpak: $app" \
            || run_cmd 2 "flatpak install $app" flatpak install -y flathub "$app"
    done
}

run_module_apps() {
    ui_step "MÓDULO 12 — APPS PERSONALES"
    ui_panel_start "apt + AnyDesk + TeamViewer + snap + flatpak"
    export DEBIAN_FRONTEND=noninteractive

    _install_apt_apps
    _install_anydesk
    _install_teamviewer
    _install_snap_apps
    _install_flatpak_apps

    ui_panel_end; ui_ok "Módulo 12 completado"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/12-apps.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_apps; ui_summary
fi

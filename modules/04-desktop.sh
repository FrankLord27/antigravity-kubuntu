#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — modules/04-desktop.sh [Debian 13 / Ubuntu 26.04]
#  Deja el escritorio KDE completo, hayas marcado KDE en el instalador o no:
#   • Si no hay Plasma (Debian mínimo), lo instala con SDDM y NetworkManager.
#   • Sesión X11 de respaldo (por si Wayland da guerra con NVIDIA).
#   • Audio (PipeWire), Bluetooth, códecs, miniaturas, fuentes, discos USB.
#   • Firewall (ufw): Debian no trae ninguno activo.
#   • Arregla la red "no gestionada" que deja el instalador de Debian.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/configs/packages.conf"

_install_list() { # $1 = nivel de error, resto = paquetes
    local lvl="$1"; shift
    for pkg in "$@"; do
        is_deb_installed "$pkg" && { ui_skip "$pkg"; continue; }
        apt-cache show "$pkg" &>/dev/null || { ui_info "$pkg no existe en esta versión — omitido"; continue; }
        run_cmd "$lvl" "Instalar $pkg" apt-get install -y "$pkg"
    done
}

_install_plasma() {
    if is_deb_installed plasma-desktop; then
        ui_skip "KDE Plasma (ya instalado)"
    else
        ui_info "No hay escritorio: instalando KDE Plasma (tarda varios minutos)..."
        _install_list 2 "${PKGS_KDE_BASE[@]}"
    fi
    _install_list 1 "${PKGS_KDE_EXTRA[@]}"
    if systemctl list-unit-files 2>/dev/null | grep -q '^sddm.service'; then
        is_service_enabled sddm || run_cmd 1 "Habilitar SDDM (pantalla de login)" systemctl enable sddm
        run_cmd 1 "Arranque en modo gráfico" systemctl set-default graphical.target
    fi
}

# El instalador de Debian deja la interfaz de red en /etc/network/interfaces. Con eso,
# NetworkManager la marca como "no gestionada" y el icono de red de KDE no sirve.
_fix_network_manager() {
    is_deb_installed network-manager || return 0
    local f=/etc/network/interfaces
    if [[ -f "$f" ]] && grep -Eq '^\s*(iface|allow-hotplug|auto)\s+[^l]' "$f"; then
        cp -n "$f" "${f}.auto-setup.bak"
        cat > "$f" <<'EOF'
# Gestionado por NetworkManager (AUTO SETUP). El original está en interfaces.auto-setup.bak
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
EOF
        ui_ok "Red pasada a NetworkManager (se aplica al reiniciar)"
        ui_warn "Si estabas por Wi-Fi, tras reiniciar vuelve a elegir tu red en el icono de red de KDE"
    else ui_skip "Red ya gestionada por NetworkManager"; fi
    is_service_enabled NetworkManager || run_cmd 1 "Habilitar NetworkManager" systemctl enable NetworkManager
}

_setup_firewall() {
    is_deb_installed ufw || run_cmd 1 "Instalar ufw" apt-get install -y ufw
    command -v ufw &>/dev/null || return 0
    if ufw status 2>/dev/null | grep -q 'Status: active'; then ui_skip "Firewall ya activo"; return 0; fi
    run_cmd 1 "Firewall: bloquear entrantes"  ufw default deny incoming
    run_cmd 1 "Firewall: permitir salientes"  ufw default allow outgoing
    run_cmd 1 "Firewall: KDE Connect (TCP)"   ufw allow 1714:1764/tcp
    run_cmd 1 "Firewall: KDE Connect (UDP)"   ufw allow 1714:1764/udp
    run_cmd 1 "Activar firewall"              ufw --force enable
}

_setup_language() {
    local lang; lang=$(grep -E '^LANG=' /etc/default/locale 2>/dev/null | cut -d= -f2 | tr -d '"')
    [[ "$lang" == es* ]] || { ui_skip "Paquetes de español (el sistema no está en español)"; return 0; }
    _install_list 1 "${PKGS_SPANISH[@]}"
    is_deb_installed firefox-esr && _install_list 1 firefox-esr-l10n-es-es
}

_user_services() {
    local ru="${SUDO_USER:-$USER}"
    local g; for g in audio video plugdev dialout netdev bluetooth; do
        getent group "$g" &>/dev/null && usermod -aG "$g" "$ru" 2>/dev/null || true
    done
    is_service_enabled bluetooth || run_cmd 1 "Habilitar Bluetooth" systemctl enable bluetooth
    is_service_enabled power-profiles-daemon || systemctl enable power-profiles-daemon &>/dev/null || true
}

run_module_desktop() {
    ui_step "MÓDULO 04 — ESCRITORIO KDE"
    ui_panel_start "Plasma + audio + Bluetooth + códecs + fuentes + firewall"
    export DEBIAN_FRONTEND=noninteractive
    detect_distro

    _install_plasma
    ui_info "Audio y Bluetooth..."
    _install_list 1 "${PKGS_AUDIO_BT[@]}"
    ui_info "Códecs y miniaturas..."
    _install_list 1 "${PKGS_CODECS[@]}"
    ui_info "Fuentes..."
    _install_list 1 "${PKGS_FONTS[@]}"
    ui_info "Discos externos, archivos comprimidos y utilidades..."
    _install_list 1 "${PKGS_DESKTOP_UTILS[@]}"
    _setup_language
    _fix_network_manager
    _setup_firewall
    _user_services

    ui_panel_end; ui_ok "Módulo 04 completado"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/04-desktop.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_desktop; ui_summary
fi

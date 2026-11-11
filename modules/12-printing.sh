#!/usr/bin/env bash
# AUTO SETUP — modules/12-printing.sh [Debian 13 / Ubuntu 26.04]
# Impresoras y escáner: CUPS, drivers comunes (HP, Epson, Brother…), impresión y
# escaneo en red sin drivers (IPP/AirPrint/eSCL) y las apps de KDE para usarlos.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/configs/packages.conf"

run_module_printing() {
    ui_step "MÓDULO 12 — IMPRESORAS Y ESCÁNER"
    ui_panel_start "CUPS + drivers + escaneo"
    export DEBIAN_FRONTEND=noninteractive
    local ru="${SUDO_USER:-$USER}"

    for pkg in "${PKGS_PRINTING[@]}"; do
        is_deb_installed "$pkg" && { ui_skip "$pkg"; continue; }
        apt-cache show "$pkg" &>/dev/null || { ui_info "$pkg no existe en esta versión — omitido"; continue; }
        run_cmd 1 "Instalar $pkg" apt-get install -y "$pkg"
    done

    is_service_enabled cups || run_cmd 1 "Habilitar CUPS" systemctl enable cups
    # Avahi descubre las impresoras de la red (las que no necesitan driver).
    is_service_enabled avahi-daemon || run_cmd 1 "Habilitar descubrimiento en red (avahi)" systemctl enable avahi-daemon
    local g; for g in lpadmin scanner; do getent group "$g" &>/dev/null && usermod -aG "$g" "$ru" 2>/dev/null || true; done
    # El firewall debe dejar entrar las respuestas de descubrimiento (mDNS).
    command -v ufw &>/dev/null && ufw allow 5353/udp &>/dev/null || true

    ui_panel_end; ui_ok "Módulo 12 completado"
    ui_info "Agrega tu impresora en: Preferencias del sistema → Impresoras"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/12-printing.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_printing; ui_summary
fi

#!/usr/bin/env bash
# ANTIGRAVITY — modules/01-system.sh [Kubuntu 26.04 LTS]
# Sistema base: apt optimizado, updates, firmware, microcode Intel i5-10400F

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

run_module_system() {
    ui_step "MÓDULO 01 — SISTEMA BASE"
    ui_panel_start "apt + firmware + microcode Intel"
    export DEBIAN_FRONTEND=noninteractive

    ui_info "Configurando apt para máxima velocidad..."
    if [[ ! -f /etc/apt/apt.conf.d/99-antigravity ]]; then
        run_cmd 1 "Configurar apt.conf" bash -c 'cat > /etc/apt/apt.conf.d/99-antigravity << EOF
Acquire::http::Pipeline-Depth "10";
Acquire::https::Pipeline-Depth "10";
Acquire::ForceIPv4 "true";
APT::Install-Recommends "false";
APT::Get::AutomaticRemove "true";
EOF'
    else ui_skip "apt.conf ya configurado"; fi

    run_cmd 3 "apt update" apt update
    run_cmd 3 "apt full-upgrade" apt full-upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"

    ui_info "Instalando herramientas base..."
    local base_pkgs=(
        curl wget git htop btop nano vim bash-completion unzip tar xz-utils
        p7zip-full pciutils usbutils lshw hwinfo inxi fastfetch
        build-essential dkms linux-headers-generic lm-sensors fwupd
        software-properties-common apt-transport-https ca-certificates gnupg
        mokutil python3 python3-pip
    )
    for pkg in "${base_pkgs[@]}"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 2 "Instalar $pkg" apt install -y "$pkg"
    done

    local kh="linux-headers-$(uname -r)"
    is_deb_installed "$kh" && ui_skip "$kh" || run_cmd 2 "Instalar $kh" apt install -y "$kh"

    is_deb_installed intel-microcode && ui_skip "intel-microcode" \
        || run_cmd 2 "Instalar intel-microcode" apt install -y intel-microcode

    is_deb_installed linux-firmware && ui_skip "linux-firmware" \
        || run_cmd 2 "Instalar linux-firmware" apt install -y linux-firmware

    run_cmd 1 "fwupd refresh" fwupdmgr refresh --force
    run_cmd 1 "fwupd update" fwupdmgr update -y

    run_cmd 1 "Habilitar universe"   add-apt-repository -y universe
    run_cmd 1 "Habilitar restricted" add-apt-repository -y restricted
    run_cmd 1 "Habilitar multiverse" add-apt-repository -y multiverse
    run_cmd 2 "apt update post-repos" apt update

    detect_hardware
    if [[ "$DETECT_SECURE_BOOT" == "enabled" ]]; then
        ui_warn "SECURE BOOT ACTIVO — desactívalo en BIOS antes de instalar NVIDIA"
    else
        ui_ok "Secure Boot desactivado — OK para NVIDIA propietario"
    fi

    run_cmd 1 "autoremove" apt autoremove -y
    run_cmd 1 "autoclean"  apt autoclean

    ui_panel_end; ui_ok "Módulo 01 completado"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/01-system.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_system; ui_summary
fi

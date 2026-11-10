#!/usr/bin/env bash
# AUTO SETUP — modules/01-system.sh [Debian 13 / Ubuntu 26.04]
# Sistema base: apt, repos (contrib/non-free o universe/multiverse), firmware, microcode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

_enable_repos_debian() {
    ui_info "Habilitando contrib, non-free y non-free-firmware (Debian)..."
    local changed=false
    # Formato deb822 (Debian 12+): /etc/apt/sources.list.d/debian.sources
    if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
        if ! grep -q 'non-free-firmware' /etc/apt/sources.list.d/debian.sources; then
            run_cmd 2 "Añadir componentes a debian.sources" \
                sed -i -E 's/^(Components:.*)$/Components: main contrib non-free non-free-firmware/' \
                /etc/apt/sources.list.d/debian.sources && changed=true
        else ui_skip "debian.sources ya incluye non-free"; fi
    fi
    # Formato clásico
    if [[ -f /etc/apt/sources.list ]] && grep -qE '^deb .*main' /etc/apt/sources.list; then
        if ! grep -qE '^deb .*non-free-firmware' /etc/apt/sources.list; then
            run_cmd 2 "Añadir componentes a sources.list" \
                sed -i -E '/^deb(-src)? /{/non-free-firmware/!s/ main( .*)?$/ main contrib non-free non-free-firmware/}' \
                /etc/apt/sources.list && changed=true
        else ui_skip "sources.list ya incluye non-free"; fi
    fi
    $changed && run_cmd 2 "apt update post-repos" apt update
}

_enable_repos_ubuntu() {
    run_cmd 1 "Habilitar universe"   add-apt-repository -y universe
    run_cmd 1 "Habilitar restricted" add-apt-repository -y restricted
    run_cmd 1 "Habilitar multiverse" add-apt-repository -y multiverse
    run_cmd 2 "apt update post-repos" apt update
}

run_module_system() {
    ui_step "MÓDULO 01 — SISTEMA BASE"
    ui_panel_start "apt + repos + firmware + microcode"
    export DEBIAN_FRONTEND=noninteractive
    detect_hardware

    ui_info "Configurando apt..."
    if [[ ! -f /etc/apt/apt.conf.d/99-auto-setup ]]; then
        run_cmd 1 "Configurar apt.conf" bash -c 'cat > /etc/apt/apt.conf.d/99-auto-setup << EOF
Acquire::http::Pipeline-Depth "10";
Acquire::https::Pipeline-Depth "10";
APT::Install-Recommends "false";
APT::Get::AutomaticRemove "true";
EOF'
    else ui_skip "apt.conf ya configurado"; fi

    # Deshabilitar PPAs rotos antes de actualizar (solo Ubuntu)
    for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [[ -f "$f" ]] || continue
        grep -q 'lutris' "$f" 2>/dev/null && {
            ui_warn "PPA lutris sin soporte — deshabilitando: $f"
            mv "$f" "${f}.disabled" 2>/dev/null || true
        }
    done

    is_debian && _enable_repos_debian || _enable_repos_ubuntu

    run_cmd 1 "apt update" apt update
    run_cmd 2 "apt full-upgrade" apt full-upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"

    ui_info "Instalando herramientas base..."
    local base_pkgs=(
        curl wget git htop btop nano vim bash-completion unzip tar xz-utils
        p7zip-full pciutils usbutils lshw hwinfo inxi fastfetch
        build-essential dkms lm-sensors fwupd
        apt-transport-https ca-certificates gnupg
        python3 python3-pip
    )
    is_ubuntu && base_pkgs+=(software-properties-common mokutil)
    for pkg in "${base_pkgs[@]}"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 2 "Instalar $pkg" apt install -y "$pkg"
    done

    # Headers del kernel (nombre distinto en cada distro)
    local kh
    is_debian && kh="linux-headers-amd64" || kh="linux-headers-generic"
    is_deb_installed "$kh" && ui_skip "$kh" || run_cmd 2 "Instalar $kh" apt install -y "$kh"

    # Microcode CPU
    if grep -qi 'GenuineIntel' /proc/cpuinfo; then
        is_deb_installed intel-microcode && ui_skip "intel-microcode" \
            || run_cmd 2 "Instalar intel-microcode" apt install -y intel-microcode
    elif grep -qi 'AuthenticAMD' /proc/cpuinfo; then
        is_deb_installed amd64-microcode && ui_skip "amd64-microcode" \
            || run_cmd 2 "Instalar amd64-microcode" apt install -y amd64-microcode
    fi

    # Firmware (Wi-Fi Intel, Bluetooth, GPU) — distinto en cada distro
    local fw_pkgs=()
    is_debian && fw_pkgs=(firmware-linux firmware-iwlwifi firmware-misc-nonfree) || fw_pkgs=(linux-firmware)
    for pkg in "${fw_pkgs[@]}"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 2 "Instalar $pkg" apt install -y "$pkg"
    done

    run_cmd 1 "fwupd refresh" fwupdmgr refresh --force
    run_cmd 1 "fwupd update" fwupdmgr update -y

    if has_nvidia && [[ "$DETECT_SECURE_BOOT" == "enabled" ]]; then
        ui_warn "SECURE BOOT ACTIVO — desactívalo en BIOS antes de instalar NVIDIA"
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

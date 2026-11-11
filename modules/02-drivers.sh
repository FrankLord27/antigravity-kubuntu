#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — modules/02-drivers.sh [Debian 13 / Ubuntu 26.04]
#  Drivers y firmware. Debian trae el kernel con casi todos los drivers, pero el
#  FIRMWARE (los archivos que cada chip necesita para arrancar) viene aparte: sin
#  él no hay Wi-Fi, Bluetooth, sonido en algunos equipos ni aceleración de video.
#
#  En vez de adivinar qué chip tiene cada PC, se instala el juego completo de
#  firmware: son solo archivos, no ralentizan nada, y así sirve para la PC de
#  escritorio, la laptop o un adaptador USB que conectes después.
#  Al final lista los dispositivos que se quedaron sin driver, si hay alguno.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/configs/packages.conf"

_install_firmware() {
    local pkgs=()
    if is_debian; then pkgs=("${PKGS_FIRMWARE_DEBIAN[@]}"); else pkgs=(linux-firmware); fi
    ui_info "Instalando firmware (${#pkgs[@]} paquetes)..."
    for pkg in "${pkgs[@]}"; do
        is_deb_installed "$pkg" && { ui_skip "$pkg"; continue; }
        apt-cache show "$pkg" &>/dev/null || { ui_info "$pkg no existe en esta versión — omitido"; continue; }
        run_cmd 2 "Instalar $pkg" apt-get install -y "$pkg"
    done
}

_install_microcode() {
    if grep -qi 'GenuineIntel' /proc/cpuinfo; then
        is_deb_installed intel-microcode && ui_skip "intel-microcode" \
            || run_cmd 2 "Instalar intel-microcode" apt-get install -y intel-microcode
    elif grep -qi 'AuthenticAMD' /proc/cpuinfo; then
        is_deb_installed amd64-microcode && ui_skip "amd64-microcode" \
            || run_cmd 2 "Instalar amd64-microcode" apt-get install -y amd64-microcode
    fi
}

_install_hw_tools() {
    for pkg in pciutils usbutils lshw inxi lm-sensors fwupd smartmontools nvme-cli dkms; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt-get install -y "$pkg"
    done
    # Headers del kernel: hacen falta para cualquier driver que se compile (NVIDIA, adaptadores USB).
    local kh; is_debian && kh="linux-headers-amd64" || kh="linux-headers-generic"
    is_deb_installed "$kh" && ui_skip "$kh" || run_cmd 2 "Instalar $kh" apt-get install -y "$kh"
    run_cmd 1 "Detectar sensores" bash -c 'yes "" | sensors-detect --auto >/dev/null 2>&1 || true'
}

# fwupd: solo se LISTAN las actualizaciones de BIOS/UEFI. Flashear firmware en medio de
# una instalación desatendida es buscarse un problema: se aplica a mano y con calma.
_check_fwupd() {
    command -v fwupdmgr &>/dev/null || return 0
    run_cmd 1 "fwupd: actualizar catálogo" fwupdmgr refresh --force
    local upd; upd=$(fwupdmgr get-updates 2>/dev/null | grep -E '^\s*[│├└ ]*(New version|Nueva versión)' | head -5 || true)
    if [[ -n "$upd" ]]; then
        ui_warn "Hay actualizaciones de firmware (BIOS/dispositivos). Aplícalas a mano: sudo fwupdmgr update"
    else ui_ok "Firmware de BIOS/dispositivos al día (o sin soporte en fwupd)"; fi
}

# Dispositivos PCI sin driver del kernel: es la señal real de "falta un controlador".
report_unbound_devices() {
    command -v lspci &>/dev/null || return 0
    local out
    out=$(lspci -nnk 2>/dev/null | awk '
        /^[0-9a-f]/ { if (dev != "" && !drv) print dev; dev=$0; drv=0 }
        /Kernel driver in use/ { drv=1 }
        END { if (dev != "" && !drv) print dev }' \
        | grep -viE 'bridge|SMBus|Signal processing|Performance counters|System peripheral|Memory controller|RAM memory|PIC|ISA|Non-Essential|Serial bus controller \[0c80\]|Communication controller.*(MEI|HECI)' || true)
    if [[ -z "$out" ]]; then
        ui_ok "Todos los dispositivos PCI tienen driver"
    else
        ui_warn "Dispositivos SIN driver (pueden necesitar un driver aparte):"
        while IFS= read -r l; do echo -e "      ${C_YELLOW}${l:0:110}${C_RESET}"; _log "WARN" "sin driver: $l"; done <<<"$out"
    fi
    # Firmware que el kernel pidió y no encontró en este arranque.
    local miss; miss=$(dmesg 2>/dev/null | grep -iE 'firmware.*(failed|not found|missing)|Direct firmware load.*failed' | grep -vE 'iwl-debug-yoyo|regulatory\.db' | sed 's/^\[[^]]*\] //' | sort -u | head -8 || true)
    if [[ -n "$miss" ]]; then
        ui_warn "El kernel pidió firmware que no encontró en ESTE arranque (tras reiniciar debería estar):"
        while IFS= read -r l; do echo -e "      ${C_DIM}${l:0:110}${C_RESET}"; done <<<"$miss"
    fi
}

run_module_drivers() {
    ui_step "MÓDULO 02 — DRIVERS Y FIRMWARE"
    ui_panel_start "Firmware completo + microcode + herramientas"
    export DEBIAN_FRONTEND=noninteractive
    detect_hardware

    _install_firmware
    _install_microcode
    _install_hw_tools
    _check_fwupd
    report_unbound_devices

    ui_panel_end; ui_ok "Módulo 02 completado"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/02-drivers.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_drivers; ui_summary
fi

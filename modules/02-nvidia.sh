#!/usr/bin/env bash
# =============================================================================
#  ANTIGRAVITY — modules/02-nvidia.sh [Kubuntu 26.04 LTS]
#  GTX 1660 SUPER (Turing/TU116)
#
#  DECISIONES:
#  • nvidia-driver-580-open — producción estable, NO 595 (regresiones Turing)
#  • Módulos abiertos GSP — mejor integración kernel 7.0 y Secure Boot
#  • X11 NO configurado — Kubuntu 26.04 es Wayland exclusivo
#  • nvidia-drm via modprobe.d — NO GRUB (kernel 7.0)
#  • Servicios suspensión + preservación VRAM — pantalla negra al despertar
#  • CUDA 12.8 — compatible serie 580, estable para Ollama + Docker
#  • NTSYNC — gaming Proton optimizado (kernel 7.0 nativo)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

readonly NVIDIA_TARGET_BRANCH="580"
readonly NVIDIA_TARGET_PKG="nvidia-driver-${NVIDIA_TARGET_BRANCH}-open"
readonly NVIDIA_MIN_VERSION=578
readonly CUDA_VERSION="12-8"

run_module_nvidia() {
    ui_step "MÓDULO 02 — NVIDIA GTX 1660 SUPER (580-open)"
    ui_panel_start "Driver producción estable para Turing + Wayland + CUDA 12.8"
    export DEBIAN_FRONTEND=noninteractive

    detect_nvidia
    _show_current_state

    if _is_correct_driver_loaded; then
        ui_ok "Driver 580-open ya instalado y funcionando"
        ui_skip "Instalación del driver"
        _configure_wayland_kubuntu2604
        _configure_suspend_services
        _configure_vram_preservation
        _configure_ntsync
        return 0
    fi

    _remove_conflicting_drivers
    _check_run_installer
    _blacklist_nouveau
    _install_nvidia_580_open
    _install_cuda_128
    _configure_wayland_kubuntu2604
    _configure_suspend_services
    _configure_vram_preservation
    _configure_ntsync

    ui_info "Regenerando initramfs..."
    run_cmd 2 "update-initramfs" update-initramfs -u -k all
    _verify_dkms_post_install

    ui_panel_end; ui_ok "Módulo 02 completado"
    ui_warn "REINICIO REQUERIDO — ejecuta 07-verify.sh tras reiniciar"
}

_show_current_state() {
    echo -e "${C_BOLD}  ┌─ Estado actual NVIDIA ─────────────────────────────────────┐${C_RESET}"
    printf "  │  %-26s %-30s│\n" "Módulo:"    "$DETECT_NVIDIA_MODULE"
    printf "  │  %-26s %-30s│\n" "Versión:"   "$DETECT_NVIDIA_DRIVER_VER"
    printf "  │  %-26s %-30s│\n" "Paquete:"   "$DETECT_NVIDIA_DEB_PKG"
    printf "  │  %-26s %-30s│\n" "Variante:"  "$DETECT_NVIDIA_IS_OPEN"
    printf "  │  %-26s %-30s│\n" "Sesión:"    "${XDG_SESSION_TYPE:-desconocida}"
    local rund="no"; [[ -f /usr/bin/nvidia-uninstall ]] && rund="${C_RED}SÍ — PROBLEMA${C_RESET}"
    printf "  │  %-26s %-30s│\n" "Driver .run manual:" "$rund"
    local mc; mc=$(dpkg -l 2>/dev/null | grep -cE '^ii.*nvidia-driver-[0-9]+' || true)
    mc=${mc:-0}; mc=$(echo "$mc" | tr -d '[:space:]')
    local mcc="$C_GREEN"; [[ "$mc" -gt 1 ]] && mcc="$C_RED"
    printf "  │  %-26s ${mcc}%-30s${C_RESET}│\n" "Versiones instaladas:" "$mc"
    echo -e "  └$(printf '─%.0s' {1..60})┘"; echo ""
}

_is_correct_driver_loaded() {
    [[ "$DETECT_NVIDIA_MODULE" != "loaded" ]] && return 1
    local vm; vm=$(echo "$DETECT_NVIDIA_DRIVER_VER" | cut -d. -f1)
    [[ -z "$vm" ]] && return 1
    [[ "$vm" -ge 580 ]] && [[ "$vm" -lt 590 ]] && is_deb_installed "nvidia-driver-${vm}-open"
}

_remove_conflicting_drivers() {
    ui_info "Verificando drivers conflictivos..."
    local installed found=false
    installed=$(dpkg -l 2>/dev/null | grep -E '^ii.*nvidia-driver-[0-9]+' | awk '{print $2}')
    for drv in $installed; do
        local ver; ver=$(echo "$drv" | grep -oE '[0-9]+(-open)?$' | grep -oE '^[0-9]+')
        if [[ "$ver" != "$NVIDIA_TARGET_BRANCH" ]]; then
            ui_warn "Eliminando driver conflictivo: $drv"
            run_cmd 2 "Eliminar $drv" apt remove -y --purge "$drv" || true
            found=true
        fi
    done
    $found && run_cmd 1 "autoremove post-limpieza" apt autoremove -y --purge \
        || ui_skip "Sin drivers conflictivos"
}

_check_run_installer() {
    [[ -f /usr/bin/nvidia-uninstall ]] || return 0
    ui_fail "DETECTADO driver NVIDIA instalado manualmente (.run)"
    ui_warn "Elimínalo primero con: sudo nvidia-uninstall"
    ui_confirm "¿Continuar de todas formas?" || { _log "WARN" "Abortado por driver .run"; exit 1; }
}

_blacklist_nouveau() {
    ui_info "Configurando blacklist nouveau..."
    local bf="/etc/modprobe.d/blacklist-nouveau.conf"
    [[ -f "$bf" ]] && grep -q 'blacklist nouveau' "$bf" 2>/dev/null && { ui_skip "nouveau ya en blacklist"; return; }
    run_cmd 2 "Crear blacklist nouveau" bash -c 'cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF'
    ui_ok "nouveau en blacklist"
}

_install_nvidia_580_open() {
    ui_info "Instalando nvidia-driver-${NVIDIA_TARGET_BRANCH}-open..."
    ui_warn "Puede tardar varios minutos — DKMS compilará el módulo. NO interrumpas."

    if ! dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
        run_cmd 2 "Habilitar i386" dpkg --add-architecture i386
        run_cmd 2 "apt update post-i386" apt update
    else ui_skip "i386 ya habilitado"; fi

    local pkgs=(
        "nvidia-driver-${NVIDIA_TARGET_BRANCH}-open"
        "nvidia-dkms-${NVIDIA_TARGET_BRANCH}-open"
        "nvidia-utils-${NVIDIA_TARGET_BRANCH}"
        "nvidia-settings"
        "libnvidia-gl-${NVIDIA_TARGET_BRANCH}"
        "libnvidia-gl-${NVIDIA_TARGET_BRANCH}:i386"
        "libnvidia-compute-${NVIDIA_TARGET_BRANCH}"
        "libnvidia-compute-${NVIDIA_TARGET_BRANCH}:i386"
        "libnvidia-decode-${NVIDIA_TARGET_BRANCH}"
        "libnvidia-encode-${NVIDIA_TARGET_BRANCH}"
        "libnvidia-fbc1-${NVIDIA_TARGET_BRANCH}"
        "xserver-xorg-video-nvidia-${NVIDIA_TARGET_BRANCH}"
    )
    for pkg in "${pkgs[@]}"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 2 "Instalar $pkg" apt install -y "$pkg"
    done
    ui_ok "nvidia-driver-${NVIDIA_TARGET_BRANCH}-open instalado"
}

_install_cuda_128() {
    ui_info "Instalando CUDA 12.8 (compatible con driver 580, estable para Ollama + Docker)..."

    # Ubuntu 26.04 aún no tiene repos CUDA oficiales — usar 24.04 (compatible)
    local uv="2404"
    local base="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${uv}/x86_64"

    # Limpiar repo roto de 26.04 si existe de una ejecución anterior
    rm -f /etc/apt/sources.list.d/cuda-ubuntu2604-x86_64.list 2>/dev/null

    if [[ ! -f /etc/apt/sources.list.d/cuda-ubuntu${uv}-x86_64.list ]]; then
        run_cmd 2 "GPG key CUDA" bash -c \
            "curl -fsSL ${base}/3bf863cc.pub | gpg --dearmor -o /usr/share/keyrings/cuda-archive-keyring.gpg"
        run_cmd 2 "Repo CUDA" bash -c \
            "echo 'deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] ${base}/ /' \
            > /etc/apt/sources.list.d/cuda-ubuntu${uv}-x86_64.list"
        run_cmd 2 "apt update post-CUDA" apt update
    else ui_skip "Repo CUDA ya configurado"; fi

    for pkg in "cuda-toolkit-${CUDA_VERSION}" "cuda-libraries-${CUDA_VERSION}" "libcudnn9-cuda-12"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done

    local real_user="${SUDO_USER:-$USER}"
    local real_home; real_home=$(eval echo "~$real_user")
    local snippet='
# CUDA 12.8 — ANTIGRAVITY
export PATH="/usr/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"'
    for rc in "${real_home}/.bashrc" "${real_home}/.zshrc"; do
        [[ -f "$rc" ]] && ! grep -q 'CUDA.*ANTIGRAVITY' "$rc" && echo "$snippet" >> "$rc" \
            && ui_ok "CUDA PATH → $(basename $rc)" || true
    done
    ui_ok "CUDA 12.8 instalado"
}

_configure_wayland_kubuntu2604() {
    ui_info "Configurando NVIDIA para Wayland en Kubuntu 26.04 (kernel 7.0, sin X11)..."

    # nvidia-drm via modprobe.d — NO GRUB en kernel 7.0
    local drmf="/etc/modprobe.d/nvidia-drm.conf"
    if [[ ! -f "$drmf" ]] || ! grep -q 'modeset=1' "$drmf" 2>/dev/null; then
        run_cmd 2 "Configurar nvidia-drm modeset" bash -c 'cat > /etc/modprobe.d/nvidia-drm.conf << EOF
# ANTIGRAVITY — NVIDIA DRM para Wayland Kubuntu 26.04
# Kernel 7.0 — via modprobe.d, NO via GRUB
options nvidia-drm modeset=1
options nvidia-drm fbdev=1
EOF'
        ui_ok "nvidia-drm.modeset=1 + fbdev=1 configurados"
    else ui_skip "nvidia-drm modeset ya configurado"; fi

    # Limpiar modeset de GRUB si alguien lo puso ahí
    if grep -q 'nvidia-drm.modeset' /etc/default/grub 2>/dev/null; then
        ui_warn "Limpiando nvidia-drm.modeset de GRUB (no necesario en kernel 7.0)..."
        run_cmd 1 "Limpiar GRUB" bash -c \
            "sed -i 's/ nvidia-drm\.modeset=1//g; s/nvidia-drm\.modeset=1 //g' /etc/default/grub"
        run_cmd 1 "Regenerar GRUB" update-grub
    fi

    # Módulos en carga automática
    run_cmd 1 "Modules-load NVIDIA" bash -c 'cat > /etc/modules-load.d/nvidia.conf << EOF
nvidia
nvidia_modeset
nvidia_uvm
nvidia_drm
EOF'

    # Variables de entorno para KDE Plasma 6.6 + Wayland + NVIDIA 580
    local ef="/etc/environment"
    declare -A envs=(
        ["NVD_BACKEND"]="direct"
        ["GBM_BACKEND"]="nvidia-drm"
        ["__GLX_VENDOR_LIBRARY_NAME"]="nvidia"
        ["LIBVA_DRIVER_NAME"]="nvidia"
        ["__GL_GSYNC_ALLOWED"]="1"
        ["__GL_VRR_ALLOWED"]="1"
        ["WLR_NO_HARDWARE_CURSORS"]="0"
        ["ELECTRON_OZONE_PLATFORM_HINT"]="wayland"
        ["QT_QPA_PLATFORM"]="wayland"
        ["SDL_VIDEODRIVER"]="wayland"
    )
    for key in "${!envs[@]}"; do
        grep -q "^${key}=" "$ef" 2>/dev/null && ui_skip "Variable $key" \
            || run_cmd 1 "Agregar $key" bash -c "echo '${key}=${envs[$key]}' >> $ef"
    done
    ui_ok "Entorno Wayland + NVIDIA 580 configurado"
}

_configure_suspend_services() {
    ui_info "Habilitando servicios de suspensión NVIDIA (solución pantalla negra en Turing)..."
    for svc in nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service; do
        if systemctl list-unit-files 2>/dev/null | grep -q "$svc"; then
            is_service_enabled "$svc" && ui_skip "$svc habilitado" \
                || run_cmd 1 "Habilitar $svc" systemctl enable "$svc"
        else ui_warn "$svc no encontrado — se activará tras reiniciar con driver 580"; fi
    done
}

_configure_vram_preservation() {
    ui_info "Configurando preservación de VRAM para suspensión estable..."
    local pf="/etc/modprobe.d/nvidia-power.conf"
    [[ -f "$pf" ]] && grep -q 'NVreg_PreserveVideoMemoryAllocations' "$pf" 2>/dev/null \
        && { ui_skip "VRAM preservation ya configurada"; return; }
    run_cmd 2 "Crear nvidia-power.conf" bash -c 'cat > /etc/modprobe.d/nvidia-power.conf << EOF
# ANTIGRAVITY — Preservación VRAM para suspensión/hibernate
# Solución documentada para pantalla negra en Turing (GTX 1660 SUPER)
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF'
    ui_ok "VRAM preservation configurada"
}

_configure_ntsync() {
    ui_info "Configurando NTSYNC para gaming con Steam Proton (kernel 7.0)..."
    if [[ -d /sys/module/ntsync ]] || modinfo ntsync &>/dev/null 2>&1; then
        echo "ntsync" > /etc/modules-load.d/ntsync.conf 2>/dev/null || true
        modprobe ntsync 2>/dev/null || true
        ui_ok "NTSYNC activo"
    else
        echo "ntsync" > /etc/modules-load.d/ntsync.conf 2>/dev/null || true
        ui_warn "NTSYNC se activará tras reinicio"
    fi
    local nr="/etc/udev/rules.d/99-ntsync.rules"
    [[ ! -f "$nr" ]] && run_cmd 1 "udev rule NTSYNC" bash -c \
        'echo "KERNEL==\"ntsync\", GROUP=\"games\", MODE=\"0660\"" > /etc/udev/rules.d/99-ntsync.rules' \
        && run_cmd 1 "Recargar udev" udevadm control --reload-rules \
        || ui_skip "udev rule NTSYNC ya existe"
}

_verify_dkms_post_install() {
    ui_info "Verificando DKMS..."
    local dout; dout=$(dkms status 2>/dev/null | grep -i nvidia || echo "")
    [[ -z "$dout" ]] && { ui_warn "DKMS no muestra módulos NVIDIA — forzar: sudo dkms autoinstall"; return; }
    echo "$dout" | grep -qi 'installed' && ui_ok "DKMS NVIDIA: $dout" \
        || ui_warn "DKMS: $dout — se completará en el reinicio"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/02-nvidia.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_nvidia; ui_summary
fi

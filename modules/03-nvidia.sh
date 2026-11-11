#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — modules/03-nvidia.sh [Debian 13 / Ubuntu 26.04]
#  Solo se ejecuta si se detecta GPU NVIDIA. En equipos sin NVIDIA se omite.
#
#  DEBIAN: por defecto el repo apt oficial de NVIDIA fijado en una rama
#          (NVIDIA_SOURCE/NVIDIA_BRANCH/NVIDIA_FLAVOR en packages.conf). Con
#          NVIDIA_SOURCE=debian usa el paquete nvidia-driver 550 de Debian.
#  UBUNTU (GTX 1660 SUPER, Turing/TU116) — DECISIONES:
#  • Rama 580 — producción estable, NO 595 (regresiones Turing persisten en 595.84)
#  • Variante configurable en packages.conf (2026-07-02: proprietary + GSP off)
#    El driver open FUERZA firmware GSP → stutter conocido en Turing/KDE
#    (open-gpu-kernel-modules #777/#693). El proprietary permite
#    NVreg_EnableGpuFirmware=0, única vía documentada de eliminarlo.
#  • X11 NO configurado — Kubuntu 26.04 es Wayland exclusivo
#  • nvidia-drm via modprobe.d — NO GRUB (kernel 7.0)
#  • Servicios suspensión + preservación VRAM — pantalla negra al despertar
#  • CUDA 12.8 — compatible serie 580, estable para Ollama + Docker
#  • NTSYNC — gaming Proton optimizado (kernel 7.0 nativo)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/configs/packages.conf"

readonly NVIDIA_TARGET_BRANCH="${NVIDIA_DRIVER_VERSION:-580}"
readonly NVIDIA_TARGET_SUFFIX="${NVIDIA_PKG_SUFFIX-}"
readonly NVIDIA_TARGET_PKG="nvidia-driver-${NVIDIA_TARGET_BRANCH}${NVIDIA_TARGET_SUFFIX}"
readonly NVIDIA_MIN_VERSION=578
CUDA_VERSION="${CUDA_VERSION:-12-8}"   # la define packages.conf

run_module_nvidia() {
    ui_step "MÓDULO 03 — DRIVER NVIDIA"
    export DEBIAN_FRONTEND=noninteractive
    detect_hardware
    if ! has_nvidia; then
        ui_skip "Sin GPU NVIDIA (${DETECT_GPU}) — módulo omitido"
        return 0
    fi

    detect_nvidia
    _show_current_state

    if is_debian; then
        ui_panel_start "Debian: driver NVIDIA (${NVIDIA_SOURCE:-nvidia-repo} ${NVIDIA_BRANCH:-}) + Wayland"
        _clean_old_env_vars
        _check_secure_boot
        if [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]] && is_deb_installed nvidia-driver; then
            ui_skip "nvidia-driver ya instalado y funcionando"
        else
            _check_run_installer
            if [[ "${NVIDIA_SOURCE:-nvidia-repo}" == "debian" ]]; then _install_nvidia_debian
            else _install_nvidia_repo; fi
        fi
        _configure_gsp
        _configure_drm_modeset
        if [[ "${NVIDIA_SOURCE:-nvidia-repo}" == "debian" ]]; then
            # El paquete de Debian no trae estas opciones activadas; el del repo de NVIDIA sí.
            _configure_suspend_services
            _configure_vram_preservation
        fi
        is_deb_installed nvtop || run_cmd 1 "Instalar nvtop" apt-get install -y nvtop
        run_cmd 2 "update-initramfs" update-initramfs -u -k all
        _verify_dkms_post_install
        ui_panel_end; ui_ok "Módulo 03 completado"
        ui_warn "REINICIO REQUERIDO"
        return 0
    fi

    ui_panel_start "Ubuntu: ${NVIDIA_TARGET_PKG} (Turing) + Wayland + CUDA 12.8"
    if _is_correct_driver_loaded; then
        ui_ok "Driver ${NVIDIA_TARGET_PKG} ya instalado y funcionando"
        ui_skip "Instalación del driver"
        _configure_gsp
        _configure_wayland_nvidia
        _configure_suspend_services
        _configure_vram_preservation
        _configure_ntsync
        return 0
    fi

    _remove_conflicting_drivers
    _check_run_installer
    _blacklist_nouveau
    _install_nvidia_580
    _configure_gsp
    _install_cuda_128
    _configure_wayland_nvidia
    _configure_suspend_services
    _configure_vram_preservation
    _configure_ntsync

    ui_info "Regenerando initramfs..."
    run_cmd 2 "update-initramfs" update-initramfs -u -k all
    _verify_dkms_post_install

    ui_panel_end; ui_ok "Módulo 03 completado"
    ui_warn "REINICIO REQUERIDO — ejecuta 90-verify.sh tras reiniciar"
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
    [[ "$vm" -ge 580 ]] && [[ "$vm" -lt 590 ]] && is_deb_installed "nvidia-driver-${vm}${NVIDIA_TARGET_SUFFIX}"
}

_remove_conflicting_drivers() {
    ui_info "Verificando drivers conflictivos (otra rama u otra variante)..."
    local installed found=false
    installed=$(dpkg -l 2>/dev/null | grep -E '^ii.*nvidia-driver-[0-9]+' | awk '{print $2}')
    for drv in $installed; do
        # Conflictivo = cualquier nvidia-driver que no sea exactamente el objetivo
        # (incluye misma rama con variante equivocada, ej. 580-open vs 580)
        if [[ "$drv" != "$NVIDIA_TARGET_PKG" ]]; then
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

# Variables que una versión anterior metía en /etc/environment. Rompen la sesión X11 de
# respaldo y el login de SDDM (QT_QPA_PLATFORM=wayland) y hacen fallar juegos
# (SDL_VIDEODRIVER=wayland). Los drivers actuales no las necesitan.
_clean_old_env_vars() {
    local ef=/etc/environment v removed=false
    [[ -f "$ef" ]] || return 0
    for v in NVD_BACKEND GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME LIBVA_DRIVER_NAME __GL_GSYNC_ALLOWED \
             __GL_VRR_ALLOWED WLR_NO_HARDWARE_CURSORS ELECTRON_OZONE_PLATFORM_HINT QT_QPA_PLATFORM SDL_VIDEODRIVER; do
        grep -q "^${v}=" "$ef" && { sed -i "/^${v}=/d" "$ef"; removed=true; }
    done
    $removed && ui_ok "Quitadas variables NVIDIA/Wayland antiguas de /etc/environment" || true
}

# Con Secure Boot activo el módulo compilado por DKMS no carga si su llave no está inscrita.
_check_secure_boot() {
    [[ "$DETECT_SECURE_BOOT" == "enabled" ]] || return 0
    ui_warn "SECURE BOOT ESTÁ ACTIVO: el driver NVIDIA no cargará hasta que hagas UNA de estas dos cosas:"
    ui_warn "  a) Desactivar Secure Boot en la BIOS (lo más simple), o"
    ui_warn "  b) Inscribir la llave de DKMS:  sudo mokutil --import /var/lib/dkms/mok.pub"
    ui_warn "     (pide una contraseña; al reiniciar eliges 'Enroll MOK' y la escribes)"
}

# Repo apt oficial de NVIDIA para Debian, fijado en una rama (packages.conf).
_install_nvidia_repo() {
    local branch="${NVIDIA_BRANCH:-610}" flavor="${NVIDIA_FLAVOR:-proprietary}"
    local distro="debian${DETECT_OS_VER%%.*}"
    local base="https://developer.download.nvidia.com/compute/cuda/repos/${distro}/x86_64"
    ui_info "Instalando driver NVIDIA ${branch} (${flavor}) desde el repo oficial de NVIDIA (${distro})..."
    ui_warn "Puede tardar varios minutos — DKMS compilará el módulo. NO interrumpas."

    if ! dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
        run_cmd 2 "Habilitar i386" dpkg --add-architecture i386
    else ui_skip "i386 ya habilitado"; fi

    if ! is_deb_installed cuda-keyring; then
        local tmp; tmp=$(mktemp -d)
        run_cmd 3 "Descargar la llave del repo de NVIDIA" curl -fsSL -o "${tmp}/cuda-keyring.deb" "${base}/cuda-keyring_1.1-1_all.deb"
        run_cmd 3 "Instalar la llave del repo de NVIDIA" dpkg -i "${tmp}/cuda-keyring.deb"
        rm -rf "$tmp"
    else ui_skip "Repo de NVIDIA ya configurado"; fi
    run_cmd 3 "apt update (repo NVIDIA)" apt-get update

    # El paquete de fijación hace que apt no salte a otra rama al actualizar.
    local pin="nvidia-driver-pinning-${branch}"
    is_deb_installed "$pin" && ui_skip "$pin" || {
        run_cmd 3 "Fijar la rama ${branch}" apt-get install -y "$pin"
        run_cmd 2 "apt update (rama fijada)" apt-get update
    }

    for pkg in linux-headers-amd64 dkms; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 3 "Instalar $pkg" apt-get install -y "$pkg"
    done

    # cuda-drivers = módulo propietario; nvidia-open = módulos open (obligan a usar GSP).
    local meta="cuda-drivers"; [[ "$flavor" == "open" ]] && meta="nvidia-open"
    run_cmd 3 "Instalar ${meta} (rama ${branch})" apt-get install -y "$meta"
    # Librerías de 32 bits: las usan Steam y Wine.
    run_cmd 1 "Instalar librerías NVIDIA de 32 bits" apt-get install -y "nvidia-driver-libs:i386"
    ui_ok "Driver NVIDIA ${branch} (${flavor}) instalado"
}

_configure_drm_modeset() {
    local drmf="/etc/modprobe.d/nvidia-drm.conf"
    if [[ ! -f "$drmf" ]] || ! grep -q 'modeset=1' "$drmf" 2>/dev/null; then
        run_cmd 2 "Configurar nvidia-drm (modeset + fbdev, necesarios para Wayland)" bash -c 'cat > /etc/modprobe.d/nvidia-drm.conf << EOF
# AUTO SETUP — NVIDIA DRM para Wayland (y consola a resolución nativa)
options nvidia-drm modeset=1
options nvidia-drm fbdev=1
EOF'
    else ui_skip "nvidia-drm modeset ya configurado"; fi
}

_install_nvidia_debian() {
    ui_info "Instalando nvidia-driver desde el repo non-free de Debian..."
    ui_warn "Puede tardar varios minutos — DKMS compilará el módulo. NO interrumpas."
    if ! dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
        run_cmd 2 "Habilitar i386" dpkg --add-architecture i386
        run_cmd 2 "apt update post-i386" apt update
    else ui_skip "i386 ya habilitado"; fi
    # nvidia-driver de Debian ya pone nouveau en blacklist por sí mismo
    for pkg in nvidia-driver firmware-misc-nonfree nvidia-settings "nvidia-driver-libs:i386"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 2 "Instalar $pkg" apt install -y "$pkg"
    done
    ui_ok "nvidia-driver instalado"
}

_install_nvidia_580() {
    ui_info "Instalando ${NVIDIA_TARGET_PKG}..."
    ui_warn "Puede tardar varios minutos — DKMS compilará el módulo. NO interrumpas."

    if ! dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
        run_cmd 2 "Habilitar i386" dpkg --add-architecture i386
        run_cmd 2 "apt update post-i386" apt update
    else ui_skip "i386 ya habilitado"; fi

    local pkgs=(
        "nvidia-driver-${NVIDIA_TARGET_BRANCH}${NVIDIA_TARGET_SUFFIX}"
        "nvidia-dkms-${NVIDIA_TARGET_BRANCH}${NVIDIA_TARGET_SUFFIX}"
        "nvidia-utils-${NVIDIA_TARGET_BRANCH}"
        "nvidia-settings"
        "libnvidia-gl-${NVIDIA_TARGET_BRANCH}"
        "libnvidia-gl-${NVIDIA_TARGET_BRANCH}:i386"
        "libnvidia-compute-${NVIDIA_TARGET_BRANCH}"
        "libnvidia-compute-${NVIDIA_TARGET_BRANCH}:i386"
        "libnvidia-decode-${NVIDIA_TARGET_BRANCH}"
        "libnvidia-encode-${NVIDIA_TARGET_BRANCH}"
        "libnvidia-fbc1-${NVIDIA_TARGET_BRANCH}"
    )
    for pkg in "${pkgs[@]}"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 2 "Instalar $pkg" apt install -y "$pkg"
    done
    ui_ok "${NVIDIA_TARGET_PKG} instalado"
}

_configure_gsp() {
    local gf="/etc/modprobe.d/nvidia-gsp.conf"
    if [[ "${NVIDIA_FLAVOR:-${NVIDIA_DRIVER_VARIANT:-open}}" == "proprietary" ]] && [[ "${NVIDIA_DISABLE_GSP:-false}" == "true" ]]; then
        if grep -q 'NVreg_EnableGpuFirmware=0' "$gf" 2>/dev/null; then
            ui_skip "GSP ya desactivado"
        else
            run_cmd 2 "Desactivar firmware GSP (fix stutter Turing)" bash -c 'cat > /etc/modprobe.d/nvidia-gsp.conf << EOF
# KUBUNTU AUTO SETUP — GSP desactivado (solo driver proprietary)
# Fix del stutter en Turing con KDE Plasma/juegos:
# github.com/NVIDIA/open-gpu-kernel-modules issues #777 y #693
options nvidia NVreg_EnableGpuFirmware=0
EOF'
            ui_ok "GSP desactivado — efectivo tras regenerar initramfs y reiniciar"
        fi
    else
        # El driver open REQUIERE GSP: este archivo impediría cargar el módulo
        if [[ -f "$gf" ]]; then
            run_cmd 2 "Eliminar config GSP (incompatible con driver open)" rm -f "$gf"
        else
            ui_skip "GSP por defecto (variante open o NVIDIA_DISABLE_GSP=false)"
        fi
    fi
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
# CUDA 12.8 — KUBUNTU AUTO SETUP
export PATH="/usr/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"'
    for rc in "${real_home}/.bashrc" "${real_home}/.zshrc"; do
        [[ -f "$rc" ]] && ! grep -q 'CUDA.*KUBUNTU AUTO SETUP' "$rc" && echo "$snippet" >> "$rc" \
            && ui_ok "CUDA PATH → $(basename $rc)" || true
    done
    ui_ok "CUDA 12.8 instalado"
}

_configure_wayland_nvidia() {
    ui_info "Configurando NVIDIA para Wayland (KDE Plasma)..."

    # nvidia-drm via modprobe.d — NO GRUB
    local drmf="/etc/modprobe.d/nvidia-drm.conf"
    if [[ ! -f "$drmf" ]] || ! grep -q 'modeset=1' "$drmf" 2>/dev/null; then
        run_cmd 2 "Configurar nvidia-drm modeset" bash -c 'cat > /etc/modprobe.d/nvidia-drm.conf << EOF
# AUTO SETUP — NVIDIA DRM para Wayland
# via modprobe.d, NO via GRUB
options nvidia-drm modeset=1
options nvidia-drm fbdev=1
EOF'
        ui_ok "nvidia-drm.modeset=1 + fbdev=1 configurados"
    else ui_skip "nvidia-drm modeset ya configurado"; fi

    # Limpiar modeset de GRUB si alguien lo puso ahí
    if grep -q 'nvidia-drm.modeset' /etc/default/grub 2>/dev/null; then
        ui_warn "Limpiando nvidia-drm.modeset de GRUB (va en modprobe.d)..."
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

    _clean_old_env_vars
    ui_ok "Entorno Wayland + NVIDIA configurado"
}

_configure_suspend_services() {
    ui_info "Habilitando servicios de suspensión NVIDIA (solución pantalla negra en Turing)..."
    for svc in nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service; do
        if systemctl list-unit-files 2>/dev/null | grep -q "$svc"; then
            is_service_enabled "$svc" && ui_skip "$svc habilitado" \
                || run_cmd 1 "Habilitar $svc" systemctl enable "$svc"
        else ui_warn "$svc no encontrado — se activará tras reiniciar"; fi
    done
}

_configure_vram_preservation() {
    ui_info "Configurando preservación de VRAM para suspensión estable..."
    local pf="/etc/modprobe.d/nvidia-power.conf"
    [[ -f "$pf" ]] && grep -q 'NVreg_PreserveVideoMemoryAllocations' "$pf" 2>/dev/null \
        && { ui_skip "VRAM preservation ya configurada"; return; }
    run_cmd 2 "Crear nvidia-power.conf" bash -c 'cat > /etc/modprobe.d/nvidia-power.conf << EOF
# KUBUNTU AUTO SETUP — Preservación VRAM para suspensión/hibernate
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
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/03-nvidia.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_nvidia; ui_summary
fi

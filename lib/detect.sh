#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — lib/detect.sh  [Debian 13 / Ubuntu 26.04]
#  Detección de distro, hardware, estado del sistema y reglas de armonía
# =============================================================================
export DETECT_DISTRO="" DETECT_OS_VER="" DETECT_OS_CODENAME=""
export DETECT_GPU="" DETECT_GPU_ARCH="" DETECT_HAS_NVIDIA="" DETECT_CPU="" DETECT_RAM_GB=""
export DETECT_DISK_FS="" DETECT_DISK_FREE_GB="" DETECT_KERNEL="" DETECT_SECURE_BOOT=""
export DETECT_SESSION_TYPE="" DETECT_NVIDIA_DRIVER_VER="" DETECT_NVIDIA_MODULE=""
export DETECT_NVIDIA_DEB_PKG="" DETECT_NVIDIA_IS_OPEN="" DETECT_NVIDIA_BRANCH=""
export DETECT_NVIDIA_WAYLAND_OK="" DETECT_SUSPEND_CONFIGURED="" DETECT_VRAM_PRESERVE=""
export DETECT_NTSYNC="" DETECT_CUDA_VER="" DETECT_DOCKER_RUNNING="" DETECT_DOCKER_GPU=""
export DETECT_GSP_OFF=""
export DETECT_NODE_VER="" DETECT_PNPM_VER="" DETECT_BTRFS=""

detect_distro() {
    source /etc/os-release 2>/dev/null
    case "${ID:-}" in
        debian) DETECT_DISTRO="debian" ;;
        ubuntu) DETECT_DISTRO="ubuntu" ;;
        *) [[ "${ID_LIKE:-}" == *ubuntu* ]] && DETECT_DISTRO="ubuntu" \
            || { [[ "${ID_LIKE:-}" == *debian* ]] && DETECT_DISTRO="debian" || DETECT_DISTRO="otra"; } ;;
    esac
    DETECT_OS_VER="${VERSION_ID:-}"; DETECT_OS_CODENAME="${VERSION_CODENAME:-}"
}

is_debian() { [[ "$DETECT_DISTRO" == "debian" ]]; }
is_ubuntu() { [[ "$DETECT_DISTRO" == "ubuntu" ]]; }
# nouveau bloqueado en modprobe.d = no cargará en el próximo arranque (lo hace el paquete del driver).
nouveau_blacklisted() { grep -rqsE '^[[:space:]]*blacklist[[:space:]]+nouveau' /etc/modprobe.d /usr/lib/modprobe.d /lib/modprobe.d; }
has_nvidia() { [[ "$DETECT_HAS_NVIDIA" == "yes" ]]; }

detect_hardware() {
    detect_distro
    DETECT_GPU=$(lspci 2>/dev/null | grep -i 'vga\|3d\|display' | head -1 | sed 's/.*: //;s/ (.*//')
    lspci 2>/dev/null | grep -i 'vga\|3d\|display' | grep -qi nvidia && DETECT_HAS_NVIDIA="yes" || DETECT_HAS_NVIDIA="no"
    DETECT_CPU=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | sed 's/.*: //;s/  */ /g')
    DETECT_RAM_GB=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}')
    DETECT_KERNEL=$(uname -r)
    DETECT_DISK_FS=$(findmnt -n -o FSTYPE / 2>/dev/null)
    DETECT_DISK_FREE_GB=$(df -BG / 2>/dev/null | awk 'NR==2{gsub("G",""); print $4}')
    DETECT_SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
    echo "$DETECT_GPU" | grep -qi 'GTX 16\|GTX 20\|RTX 20' && DETECT_GPU_ARCH="Turing" \
        || { echo "$DETECT_GPU" | grep -qi 'RTX 30' && DETECT_GPU_ARCH="Ampere" \
        || { echo "$DETECT_GPU" | grep -qi 'RTX 40' && DETECT_GPU_ARCH="Ada" \
        || { echo "$DETECT_GPU" | grep -qi 'RTX 50' && DETECT_GPU_ARCH="Blackwell" \
        || { echo "$DETECT_GPU" | grep -qi 'intel' && DETECT_GPU_ARCH="Intel iGPU" \
        || DETECT_GPU_ARCH="Otra"; }; }; }; }
    command -v mokutil &>/dev/null && \
        { mokutil --sb-state 2>/dev/null | grep -qi 'enabled' && DETECT_SECURE_BOOT="enabled" || DETECT_SECURE_BOOT="disabled"; } \
        || DETECT_SECURE_BOOT="unknown"
}

detect_nvidia() {
    if ! has_nvidia; then
        DETECT_NVIDIA_MODULE="n/a"; DETECT_NVIDIA_DRIVER_VER="sin GPU NVIDIA"
        DETECT_NVIDIA_DEB_PKG="ninguno"; DETECT_NVIDIA_IS_OPEN="n/a"; DETECT_NVIDIA_BRANCH="n/a"
        DETECT_NVIDIA_WAYLAND_OK="n/a"; DETECT_SUSPEND_CONFIGURED="n/a"; DETECT_VRAM_PRESERVE="n/a"
        DETECT_GSP_OFF="n/a"; DETECT_NTSYNC="n/a"; DETECT_CUDA_VER="n/a"
        return 0
    fi
    if lsmod 2>/dev/null | grep -q '^nvidia '; then
        DETECT_NVIDIA_MODULE="loaded"
        DETECT_NVIDIA_DRIVER_VER=$(modinfo -F version nvidia 2>/dev/null || echo "?")
    elif lsmod 2>/dev/null | grep -q '^nouveau '; then
        DETECT_NVIDIA_MODULE="nouveau"; DETECT_NVIDIA_DRIVER_VER="nouveau"
    else
        DETECT_NVIDIA_MODULE="missing"; DETECT_NVIDIA_DRIVER_VER="no instalado"
    fi
    DETECT_NVIDIA_DEB_PKG=$(dpkg -l 2>/dev/null | grep -E '^ii.*nvidia-driver(-[0-9]+)?' | awk '{print $2}' | sort -V | tail -1 || echo "ninguno")
    [[ -z "$DETECT_NVIDIA_DEB_PKG" ]] && DETECT_NVIDIA_DEB_PKG="ninguno"
    dpkg -l 2>/dev/null | grep -qE '^ii.*nvidia-driver-[0-9]+-open' && DETECT_NVIDIA_IS_OPEN="yes" \
        || { [[ "$DETECT_NVIDIA_DEB_PKG" != "ninguno" ]] && DETECT_NVIDIA_IS_OPEN="no" || DETECT_NVIDIA_IS_OPEN="unknown"; }
    if [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]]; then
        local vm; vm=$(echo "$DETECT_NVIDIA_DRIVER_VER" | cut -d. -f1)
        [[ -n "$vm" ]] && [[ "$vm" -ge 580 ]] && [[ "$vm" -lt 590 ]] && DETECT_NVIDIA_BRANCH="580 (producción ✓)" \
            || { [[ -n "$vm" ]] && [[ "$vm" -ge 590 ]] && DETECT_NVIDIA_BRANCH="${vm} (595 — regresiones Turing)" \
            || DETECT_NVIDIA_BRANCH="${vm}"; }
        [[ -n "$vm" ]] && [[ "$vm" -ge 580 ]] && DETECT_NVIDIA_WAYLAND_OK="sí" || DETECT_NVIDIA_WAYLAND_OK="parcial (driver antiguo)"
    else DETECT_NVIDIA_WAYLAND_OK="desconocida"; fi
    local sok=true
    for s in nvidia-suspend.service nvidia-resume.service; do
        systemctl is-enabled --quiet "$s" 2>/dev/null || sok=false
    done
    $sok && DETECT_SUSPEND_CONFIGURED="yes" || DETECT_SUSPEND_CONFIGURED="no"
    grep -q 'NVreg_PreserveVideoMemoryAllocations=1' /etc/modprobe.d/nvidia-power.conf 2>/dev/null \
        && DETECT_VRAM_PRESERVE="yes" || DETECT_VRAM_PRESERVE="no"
    grep -q 'NVreg_EnableGpuFirmware=0' /etc/modprobe.d/nvidia-gsp.conf 2>/dev/null \
        && DETECT_GSP_OFF="yes" || DETECT_GSP_OFF="no"
    { [[ -d /sys/module/ntsync ]] || lsmod 2>/dev/null | grep -q ntsync; } && DETECT_NTSYNC="loaded" \
        || { modinfo ntsync &>/dev/null 2>&1 && DETECT_NTSYNC="available" || DETECT_NTSYNC="missing"; }
    command -v nvcc &>/dev/null && DETECT_CUDA_VER=$(nvcc --version 2>/dev/null | grep 'release' | awk '{print $6}' | tr -d ',') \
        || { [[ -f /usr/local/cuda/version.txt ]] && DETECT_CUDA_VER=$(head -1 /usr/local/cuda/version.txt) \
        || DETECT_CUDA_VER="no instalado"; }
}

detect_docker() {
    systemctl is-active --quiet docker 2>/dev/null && DETECT_DOCKER_RUNNING="yes" || DETECT_DOCKER_RUNNING="no"
    DETECT_DOCKER_GPU="no verificado"
}

# node/pnpm viven en el home del usuario real (nvm) — se consultan como ese usuario
detect_dev_tools() {
    local ru="${SUDO_USER:-$USER}"
    local rh; rh=$(eval echo "~${ru}")
    local probe='[[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh" >/dev/null 2>&1; '
    DETECT_NODE_VER=$(sudo -u "$ru" HOME="$rh" bash -c "${probe}node -v 2>/dev/null" 2>/dev/null)
    [[ -z "$DETECT_NODE_VER" ]] && DETECT_NODE_VER="no instalado"
    DETECT_PNPM_VER=$(sudo -u "$ru" HOME="$rh" bash -c "${probe}pnpm -v 2>/dev/null" 2>/dev/null)
    [[ -z "$DETECT_PNPM_VER" ]] && DETECT_PNPM_VER="no instalado"
}

detect_btrfs() { [[ "$DETECT_DISK_FS" == "btrfs" ]] && DETECT_BTRFS="yes" || DETECT_BTRFS="no"; }

detect_all() { detect_hardware; detect_nvidia; detect_docker; detect_dev_tools; detect_btrfs; }

is_deb_installed() { dpkg -l "$1" 2>/dev/null | grep -q '^ii'; }
is_cmd_available() { command -v "$1" &>/dev/null; }
is_service_active() { systemctl is-active --quiet "$1" 2>/dev/null; }
is_service_enabled() { systemctl is-enabled --quiet "$1" 2>/dev/null; }

declare -a HARMONY_ISSUES=() HARMONY_WARNINGS=()

detect_harmony() {
    HARMONY_ISSUES=(); HARMONY_WARNINGS=()
    local ru="${SUDO_USER:-$USER}"

    if has_nvidia; then
        [[ "$DETECT_NVIDIA_DEB_PKG" != "ninguno" ]] && [[ "$DETECT_NVIDIA_MODULE" == "missing" ]] && \
            HARMONY_ISSUES+=("NVIDIA: paquete instalado pero módulo NO cargado — DKMS roto")
        [[ "$DETECT_NVIDIA_MODULE" == "nouveau" ]] && [[ "$DETECT_NVIDIA_DEB_PKG" != "ninguno" ]] && ! nouveau_blacklisted && \
            HARMONY_ISSUES+=("NVIDIA: nouveau activo con driver propietario instalado — conflicto")
        [[ "$DETECT_SECURE_BOOT" == "enabled" ]] && [[ "$DETECT_NVIDIA_DEB_PKG" != "ninguno" ]] && \
            HARMONY_ISSUES+=("Secure Boot ACTIVO — puede impedir carga del módulo NVIDIA")
        local kv; kv=$(uname -r)
        is_deb_installed "linux-headers-${kv}" || \
            HARMONY_WARNINGS+=("Kernel headers no coinciden con kernel activo ($kv) — DKMS fallará")
        if is_ubuntu && [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]]; then
            local vm; vm=$(echo "$DETECT_NVIDIA_DRIVER_VER" | cut -d. -f1)
            [[ -n "$vm" ]] && [[ "$vm" -ge 590 ]] && \
                HARMONY_ISSUES+=("Driver ${vm} (serie 595+) en Turing: parpadeos y fallos de suspensión — usa 580")
            [[ "$DETECT_NVIDIA_IS_OPEN" == "yes" ]] && [[ "$DETECT_GSP_OFF" == "yes" ]] && \
                HARMONY_ISSUES+=("nvidia-gsp.conf presente con driver open — el módulo puede NO cargar")
        fi
        [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]] && ! grep -q 'modeset=1' /etc/modprobe.d/nvidia-drm.conf 2>/dev/null && \
            HARMONY_ISSUES+=("nvidia-drm.modeset=1 no configurado via modprobe — Wayland no funcionará")
        [[ "$DETECT_SUSPEND_CONFIGURED" == "no" ]] && [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]] && \
            HARMONY_ISSUES+=("Servicios suspensión NVIDIA desactivados — pantalla negra al despertar")
        [[ "$DETECT_VRAM_PRESERVE" == "no" ]] && [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]] && \
            HARMONY_WARNINGS+=("NVreg_PreserveVideoMemoryAllocations no configurado — suspensión inestable")
        local nc; nc=$(dpkg -l 2>/dev/null | grep -cE '^ii.*nvidia-driver-[0-9]+' || true)
        nc=$(echo "${nc:-0}" | tr -d '[:space:]')
        [[ "$nc" -gt 1 ]] 2>/dev/null && HARMONY_ISSUES+=("Múltiples drivers NVIDIA instalados ($nc versiones) — conflicto activo")
        [[ -f /usr/bin/nvidia-uninstall ]] && \
            HARMONY_ISSUES+=("Driver NVIDIA instalado manualmente (.run) — incompatible con apt")
        is_service_active docker && [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]] && \
            ! is_deb_installed nvidia-container-toolkit && \
            HARMONY_ISSUES+=("Docker + NVIDIA sin nvidia-container-toolkit — GPU no disponible en contenedores")
    fi

    is_service_active docker && \
        { groups "$ru" 2>/dev/null | grep -q docker || HARMONY_WARNINGS+=("Docker activo pero '$ru' no está en grupo docker"); }
    local bf; bf=$(df -BM /boot 2>/dev/null | awk 'NR==2{gsub("M",""); print $4}')
    [[ -n "$bf" ]] && [[ "$bf" -lt 200 ]] && \
        HARMONY_ISSUES+=("/boot casi lleno (${bf}MB) — DKMS/kernel fallarán")
    command -v snap &>/dev/null && snap list docker &>/dev/null 2>&1 && \
        HARMONY_ISSUES+=("Docker instalado como snap — conflicto con Docker CE")
}

calculate_health_score() {
    local score=100 d=0
    d=$(( ${#HARMONY_ISSUES[@]} * 12 + ${#HARMONY_WARNINGS[@]} * 3 ))
    if has_nvidia; then
        [[ "$DETECT_NVIDIA_MODULE" == "missing" ]]  && d=$(( d + 20 ))
        [[ "$DETECT_NVIDIA_MODULE" == "nouveau" ]] && ! nouveau_blacklisted && d=$(( d + 10 ))
        [[ "$DETECT_SUSPEND_CONFIGURED" == "no" ]]  && d=$(( d + 6 ))
        [[ "$DETECT_VRAM_PRESERVE" == "no" ]]       && d=$(( d + 3 ))
        [[ "$DETECT_SECURE_BOOT" == "enabled" ]]    && d=$(( d + 8 ))
    fi
    [[ "$DETECT_DOCKER_RUNNING" == "no" ]]      && d=$(( d + 3 ))
    score=$(( score - d ))
    [[ $score -lt 0 ]] && score=0; [[ $score -gt 100 ]] && score=100
    echo "$score"
}

score_color() {
    local s="$1"
    [[ $s -ge 85 ]] && echo "$C_GREEN" || { [[ $s -ge 60 ]] && echo "$C_YELLOW" || echo "$C_RED"; }
}

score_label() {
    local s="$1"
    [[ $s -ge 85 ]] && echo "EXCELENTE" || { [[ $s -ge 70 ]] && echo "BUENO" || { [[ $s -ge 50 ]] && echo "REGULAR" || echo "CRÍTICO"; }; }
}

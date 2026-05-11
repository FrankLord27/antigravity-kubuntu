#!/usr/bin/env bash
# =============================================================================
#  ANTIGRAVITY — lib/detect.sh  [Kubuntu 26.04 LTS]
#  Detección hardware + estado sistema + 20 reglas de armonía
#  Driver recomendado: 580-open | CUDA: 12.8 | Wayland exclusivo
# =============================================================================
export DETECT_GPU="" DETECT_GPU_ARCH="" DETECT_CPU="" DETECT_RAM_GB=""
export DETECT_DISK_FS="" DETECT_DISK_FREE_GB="" DETECT_KERNEL=""
export DETECT_UBUNTU_VER="" DETECT_UBUNTU_CODENAME="" DETECT_SECURE_BOOT=""
export DETECT_SESSION_TYPE="" DETECT_NVIDIA_DRIVER_VER="" DETECT_NVIDIA_MODULE=""
export DETECT_NVIDIA_DEB_PKG="" DETECT_NVIDIA_IS_OPEN="" DETECT_NVIDIA_BRANCH=""
export DETECT_NVIDIA_WAYLAND_OK="" DETECT_SUSPEND_CONFIGURED="" DETECT_VRAM_PRESERVE=""
export DETECT_NTSYNC="" DETECT_CUDA_VER="" DETECT_DOCKER_RUNNING="" DETECT_DOCKER_GPU=""
export DETECT_NODE_VER="" DETECT_PNPM_VER="" DETECT_BTRFS=""

detect_hardware() {
    DETECT_GPU=$(lspci 2>/dev/null | grep -i 'vga\|3d\|display' | head -1 | sed 's/.*: //;s/ (.*//')
    DETECT_CPU=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | sed 's/.*: //;s/  */ /g')
    DETECT_RAM_GB=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}')
    DETECT_KERNEL=$(uname -r)
    source /etc/os-release 2>/dev/null
    DETECT_UBUNTU_VER="${VERSION_ID:-}"; DETECT_UBUNTU_CODENAME="${VERSION_CODENAME:-}"
    DETECT_DISK_FS=$(findmnt -n -o FSTYPE / 2>/dev/null)
    DETECT_DISK_FREE_GB=$(df -BG / 2>/dev/null | awk 'NR==2{gsub("G",""); print $4}')
    DETECT_SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
    echo "$DETECT_GPU" | grep -qi 'GTX 16\|GTX 20\|RTX 20' && DETECT_GPU_ARCH="Turing" \
        || { echo "$DETECT_GPU" | grep -qi 'RTX 30' && DETECT_GPU_ARCH="Ampere" \
        || { echo "$DETECT_GPU" | grep -qi 'RTX 40' && DETECT_GPU_ARCH="Ada" \
        || { echo "$DETECT_GPU" | grep -qi 'RTX 50' && DETECT_GPU_ARCH="Blackwell" \
        || DETECT_GPU_ARCH="Otra"; }; }; }
    command -v mokutil &>/dev/null && \
        { mokutil --sb-state 2>/dev/null | grep -qi 'enabled' && DETECT_SECURE_BOOT="enabled" || DETECT_SECURE_BOOT="disabled"; } \
        || DETECT_SECURE_BOOT="unknown"
}

detect_nvidia() {
    if lsmod 2>/dev/null | grep -q '^nvidia '; then
        DETECT_NVIDIA_MODULE="loaded"
        DETECT_NVIDIA_DRIVER_VER=$(modinfo -F version nvidia 2>/dev/null || echo "?")
    elif lsmod 2>/dev/null | grep -q '^nouveau '; then
        DETECT_NVIDIA_MODULE="nouveau"; DETECT_NVIDIA_DRIVER_VER="nouveau"
    else
        DETECT_NVIDIA_MODULE="missing"; DETECT_NVIDIA_DRIVER_VER="no instalado"
    fi
    DETECT_NVIDIA_DEB_PKG=$(dpkg -l 2>/dev/null | grep -E '^ii.*nvidia-driver-[0-9]+' | awk '{print $2}' | sort -V | tail -1 || echo "ninguno")
    dpkg -l 2>/dev/null | grep -qE '^ii.*nvidia-driver-[0-9]+-open' && DETECT_NVIDIA_IS_OPEN="yes" \
        || { [[ "$DETECT_NVIDIA_DEB_PKG" != "ninguno" ]] && DETECT_NVIDIA_IS_OPEN="no" || DETECT_NVIDIA_IS_OPEN="unknown"; }
    if [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]]; then
        local vm; vm=$(echo "$DETECT_NVIDIA_DRIVER_VER" | cut -d. -f1)
        [[ -n "$vm" ]] && [[ "$vm" -ge 580 ]] && [[ "$vm" -lt 590 ]] && DETECT_NVIDIA_BRANCH="580 (producción ✓)" \
            || { [[ -n "$vm" ]] && [[ "$vm" -ge 590 ]] && DETECT_NVIDIA_BRANCH="${vm} (595 — regresiones Turing)" \
            || DETECT_NVIDIA_BRANCH="${vm} (antiguo)"; }
        [[ -n "$vm" ]] && [[ "$vm" -ge 580 ]] && [[ "$vm" -lt 590 ]] && DETECT_NVIDIA_WAYLAND_OK="sí (driver 580)" \
            || { [[ -n "$vm" ]] && [[ "$vm" -ge 590 ]] && DETECT_NVIDIA_WAYLAND_OK="parcial (595 parpadeos)" \
            || DETECT_NVIDIA_WAYLAND_OK="no (driver antiguo)"; }
    else DETECT_NVIDIA_WAYLAND_OK="desconocida"; fi
    local sok=true
    for s in nvidia-suspend.service nvidia-resume.service; do
        systemctl is-enabled --quiet "$s" 2>/dev/null || sok=false
    done
    $sok && DETECT_SUSPEND_CONFIGURED="yes" || DETECT_SUSPEND_CONFIGURED="no"
    grep -q 'NVreg_PreserveVideoMemoryAllocations=1' /etc/modprobe.d/nvidia-power.conf 2>/dev/null \
        && DETECT_VRAM_PRESERVE="yes" || DETECT_VRAM_PRESERVE="no"
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

detect_dev_tools() {
    command -v node &>/dev/null && DETECT_NODE_VER=$(node -v 2>/dev/null) || DETECT_NODE_VER="no instalado"
    command -v pnpm &>/dev/null && DETECT_PNPM_VER=$(pnpm -v 2>/dev/null) || DETECT_PNPM_VER="no instalado"
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
    [[ "$DETECT_NVIDIA_DEB_PKG" != "ninguno" ]] && [[ "$DETECT_NVIDIA_MODULE" == "missing" ]] && \
        HARMONY_ISSUES+=("NVIDIA: paquete instalado pero módulo NO cargado — DKMS roto")
    [[ "$DETECT_NVIDIA_MODULE" == "nouveau" ]] && [[ "$DETECT_NVIDIA_DEB_PKG" != "ninguno" ]] && \
        HARMONY_ISSUES+=("NVIDIA: nouveau activo con driver propietario instalado — conflicto")
    [[ "$DETECT_SECURE_BOOT" == "enabled" ]] && [[ "$DETECT_NVIDIA_DEB_PKG" != "ninguno" ]] && \
        HARMONY_ISSUES+=("Secure Boot ACTIVO — puede impedir carga del módulo NVIDIA")
    local kv; kv=$(uname -r)
    is_deb_installed "linux-headers-${kv}" || \
        HARMONY_WARNINGS+=("Kernel headers no coinciden con kernel activo ($kv) — DKMS fallará")
    if [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]]; then
        local vm; vm=$(echo "$DETECT_NVIDIA_DRIVER_VER" | cut -d. -f1)
        [[ -n "$vm" ]] && [[ "$vm" -ge 590 ]] && \
            HARMONY_ISSUES+=("Driver ${vm} (serie 595+) en Turing: parpadeos, cursor invisible Steam, fallos suspensión — usa 580-open")
        [[ -n "$vm" ]] && [[ "$vm" -lt 578 ]] && [[ "$vm" -gt 0 ]] && \
            HARMONY_WARNINGS+=("Driver $DETECT_NVIDIA_DRIVER_VER antiguo — actualiza a 580-open")
    fi
    [[ "$DETECT_NVIDIA_IS_OPEN" == "no" ]] && \
        HARMONY_WARNINGS+=("Driver variante cerrada — recomendado -open para kernel 7.0")
    [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]] && ! grep -q 'modeset=1' /etc/modprobe.d/nvidia-drm.conf 2>/dev/null && \
        HARMONY_ISSUES+=("nvidia-drm.modeset=1 no configurado via modprobe — Wayland no funcionará")
    grep -q 'nvidia-drm.modeset' /etc/default/grub 2>/dev/null && \
        HARMONY_WARNINGS+=("nvidia-drm.modeset en GRUB — en kernel 7.0 debe estar en modprobe.d")
    [[ "$DETECT_SUSPEND_CONFIGURED" == "no" ]] && [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]] && \
        HARMONY_ISSUES+=("Servicios suspensión NVIDIA desactivados — pantalla negra al despertar garantizada")
    [[ "$DETECT_VRAM_PRESERVE" == "no" ]] && [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]] && \
        HARMONY_WARNINGS+=("NVreg_PreserveVideoMemoryAllocations no configurado — suspensión inestable en Turing")
    is_deb_installed plasma-session-x11 2>/dev/null && \
        HARMONY_WARNINGS+=("plasma-session-x11 instalado — Kubuntu 26.04 no soporta X11 oficialmente")
    local nc; nc=$(dpkg -l 2>/dev/null | grep -cE '^ii.*nvidia-driver-[0-9]+' || true)
    nc=${nc:-0}; nc=$(echo "$nc" | tr -d '[:space:]')
    [[ "$nc" -gt 1 ]] 2>/dev/null && HARMONY_ISSUES+=("Múltiples drivers NVIDIA instalados ($nc versiones) — conflicto activo")
    [[ -f /usr/bin/nvidia-uninstall ]] && \
        HARMONY_ISSUES+=("Driver NVIDIA instalado manualmente (.run) — incompatible con apt")
    is_service_active docker && [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]] && \
        ! is_deb_installed nvidia-container-toolkit && \
        HARMONY_ISSUES+=("Docker + NVIDIA sin nvidia-container-toolkit — GPU no disponible en contenedores")
    is_service_active docker && \
        { local ru="${SUDO_USER:-$USER}"; groups "$ru" 2>/dev/null | grep -q docker || \
        HARMONY_WARNINGS+=("Docker activo pero '$ru' no está en grupo docker"); }
    [[ "$DETECT_NTSYNC" == "missing" ]] && \
        HARMONY_WARNINGS+=("NTSYNC no disponible — gaming con Proton sin optimización")
    local bf; bf=$(df -BM /boot 2>/dev/null | awk 'NR==2{gsub("M",""); print $4}')
    [[ -n "$bf" ]] && [[ "$bf" -lt 200 ]] && \
        HARMONY_ISSUES+=("/boot casi lleno (${bf}MB) — DKMS/kernel fallarán")
    snap list docker &>/dev/null 2>&1 && \
        HARMONY_ISSUES+=("Docker instalado como snap — conflicto con Docker CE, GPU no disponible")
    [[ "$DETECT_NVIDIA_MODULE" == "loaded" ]] && is_service_active docker && \
        [[ "$DETECT_CUDA_VER" == "no instalado" ]] && ! [[ -d /usr/local/cuda ]] && \
        ! is_deb_installed cuda-toolkit-12-8 && \
        HARMONY_WARNINGS+=("NVIDIA + Docker sin CUDA — Ollama/Open WebUI no usarán GPU")
}

calculate_health_score() {
    local score=100 d=0
    # Solo issues activos penalizan (warnings reducen menos)
    d=$(( ${#HARMONY_ISSUES[@]} * 12 + ${#HARMONY_WARNINGS[@]} * 3 ))
    # Crítico: driver NVIDIA no cargado
    [[ "$DETECT_NVIDIA_MODULE" == "missing" ]]  && d=$(( d + 20 ))
    [[ "$DETECT_NVIDIA_MODULE" == "nouveau" ]]  && d=$(( d + 10 ))
    # Importante: variante y suspensión
    [[ "$DETECT_NVIDIA_IS_OPEN" == "no" ]]      && d=$(( d + 4 ))
    [[ "$DETECT_SUSPEND_CONFIGURED" == "no" ]]  && d=$(( d + 6 ))
    [[ "$DETECT_VRAM_PRESERVE" == "no" ]]       && d=$(( d + 3 ))
    # Docker es importante pero no crítico
    [[ "$DETECT_DOCKER_RUNNING" == "no" ]]      && d=$(( d + 3 ))
    [[ "$DETECT_SECURE_BOOT" == "enabled" ]]    && d=$(( d + 8 ))
    # NTSYNC y CUDA son opcionales — no penalizan
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

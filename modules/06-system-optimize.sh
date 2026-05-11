#!/usr/bin/env bash
# ANTIGRAVITY — modules/06-system-optimize.sh [Kubuntu 26.04 LTS]
# Optimización: swappiness, ZRAM, TRIM, PipeWire, Bluetooth, Timeshift

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

run_module_optimize() {
    ui_step "MÓDULO 06 — OPTIMIZACIÓN DEL SISTEMA"
    ui_panel_start "ZRAM + TRIM + PipeWire + Bluetooth + Timeshift"
    export DEBIAN_FRONTEND=noninteractive
    local real_user="${SUDO_USER:-$USER}"

    ui_info "Configurando sysctl..."
    if [[ ! -f /etc/sysctl.d/99-antigravity.conf ]]; then
        run_cmd 2 "Crear sysctl antigravity" bash -c 'cat > /etc/sysctl.d/99-antigravity.conf << EOF
# ANTIGRAVITY — sysctl Kubuntu 26.04
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
net.core.somaxconn = 65535
net.ipv4.tcp_fastopen = 3
net.core.netdev_max_backlog = 5000
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF'
        run_cmd 1 "Aplicar sysctl" sysctl --system
        ui_ok "sysctl optimizado"
    else ui_skip "sysctl ya configurado"; fi

    ui_info "Configurando ZRAM..."
    { is_deb_installed zram-config || is_deb_installed systemd-zram-generator; } && ui_skip "ZRAM ya instalado" || {
        run_cmd 1 "Instalar systemd-zram-generator" apt install -y systemd-zram-generator 2>/dev/null \
            || run_cmd 1 "Instalar zram-config (fallback)" apt install -y zram-config 2>/dev/null || true
    }

    if [[ ! -f /etc/systemd/zram-generator.conf ]]; then
        run_cmd 1 "Configurar ZRAM" bash -c 'cat > /etc/systemd/zram-generator.conf << EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF'
        systemctl daemon-reload
        systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
        ui_ok "ZRAM configurado"
    else ui_skip "ZRAM ya configurado"; fi

    is_service_enabled fstrim.timer && ui_skip "TRIM ya habilitado" \
        || run_cmd 1 "Habilitar fstrim" systemctl enable --now fstrim.timer

    ui_info "Desactivando servicios innecesarios..."
    for svc in apport whoopsie avahi-daemon cups-browsed; do
        systemctl is-enabled --quiet "$svc" 2>/dev/null \
            && run_cmd 1 "Desactivar $svc" systemctl disable --now "$svc" \
            || ui_skip "$svc (ya inactivo)"
    done

    ui_info "Instalando PipeWire..."
    for pkg in pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse wireplumber pavucontrol playerctl; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done
    sudo -u "$real_user" systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null \
        || ui_warn "PipeWire: activa servicios manualmente post-reinicio"

    ui_info "Instalando Bluetooth..."
    for pkg in bluez bluetooth; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done
    is_service_enabled bluetooth || run_cmd 1 "Habilitar bluetooth" systemctl enable --now bluetooth

    detect_btrfs
    if [[ "$DETECT_BTRFS" == "yes" ]]; then
        is_deb_installed timeshift && ui_skip "Timeshift" || run_cmd 1 "Instalar timeshift" apt install -y timeshift
        ui_ok "Timeshift instalado — configúralo en modo Btrfs desde la GUI"
    else
        is_deb_installed timeshift && ui_skip "Timeshift" || run_cmd 1 "Instalar timeshift" apt install -y timeshift
        ui_ok "Timeshift instalado — configúralo en modo rsync desde la GUI"
    fi

    is_deb_installed lm-sensors || run_cmd 1 "Instalar lm-sensors" apt install -y lm-sensors
    run_cmd 1 "Detectar sensores" bash -c 'yes "" | sensors-detect --auto 2>/dev/null || true'

    ui_info "Instalando fuentes..."
    for pkg in fonts-jetbrains-mono fonts-firacode fonts-cascadia-code fonts-noto fonts-noto-color-emoji fonts-liberation; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done

    ui_info "Instalando apps KDE útiles..."
    for pkg in dolphin konsole kate kde-spectacle ark kcalc kdeconnect filelight krename plasma-nm plasma-pa; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done

    run_cmd 1 "autoremove" apt autoremove -y
    run_cmd 1 "autoclean"  apt autoclean

    ui_panel_end; ui_ok "Módulo 06 completado"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/06-system-optimize.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_optimize; ui_summary
fi

#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — modules/10-optimize.sh [Debian 13 / Ubuntu 26.04]
#  Ajustes de rendimiento para una PC de desarrollo con 16 GB:
#   • zram: swap comprimida en RAM (Debian solo deja ~1 GB de swap en disco).
#   • earlyoom: mata el proceso que se come la memoria ANTES de que la PC se congele
#     (Docker + Chrome + VS Code lo logran fácil).
#   • TRIM semanal del SSD.
#   • inotify: límites altos para proyectos Node grandes (watchers de Next/Nest).
#  No desactiva servicios ni toca la red.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

run_module_optimize() {
    ui_step "MÓDULO 10 — AJUSTES DE RENDIMIENTO"
    ui_panel_start "zram + earlyoom + TRIM + inotify"
    export DEBIAN_FRONTEND=noninteractive

    ui_info "Configurando zram..."
    if is_deb_installed zram-config; then
        ui_skip "zram (zram-config de Ubuntu ya instalado)"
    else
        is_deb_installed systemd-zram-generator && ui_skip "systemd-zram-generator" \
            || run_cmd 1 "Instalar systemd-zram-generator" apt-get install -y systemd-zram-generator
        if [[ ! -f /etc/systemd/zram-generator.conf ]] || ! grep -q 'AUTO SETUP' /etc/systemd/zram-generator.conf; then
            run_cmd 1 "Configurar zram (mitad de la RAM, zstd)" bash -c 'cat > /etc/systemd/zram-generator.conf << EOF
# AUTO SETUP — swap comprimida en RAM
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
EOF'
            systemctl daemon-reload 2>/dev/null || true
            systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
        else ui_skip "zram ya configurado"; fi
    fi

    ui_info "Configurando sysctl..."
    if [[ ! -f /etc/sysctl.d/99-auto-setup.conf ]]; then
        run_cmd 1 "Crear sysctl auto-setup" bash -c 'cat > /etc/sysctl.d/99-auto-setup.conf << EOF
# AUTO SETUP
# Con zram conviene que el kernel use la swap comprimida antes que tirar caché.
vm.swappiness = 100
vm.page-cluster = 0
# Watchers de archivos para proyectos Node grandes (Next.js, NestJS, Turborepo).
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 1024
EOF'
        run_cmd 1 "Aplicar sysctl" sysctl --system
    else ui_skip "sysctl ya configurado"; fi

    ui_info "Instalando earlyoom..."
    is_deb_installed earlyoom && ui_skip "earlyoom" || run_cmd 1 "Instalar earlyoom" apt-get install -y earlyoom
    is_service_enabled earlyoom || run_cmd 1 "Habilitar earlyoom" systemctl enable --now earlyoom

    is_service_enabled fstrim.timer && ui_skip "TRIM ya habilitado" \
        || run_cmd 1 "Habilitar TRIM semanal del SSD" systemctl enable --now fstrim.timer

    ui_panel_end; ui_ok "Módulo 10 completado"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/10-optimize.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_optimize; ui_summary
fi

#!/usr/bin/env bash
# AUTO SETUP — modules/05-gaming.sh [Debian 13 / Ubuntu 26.04]
# Gaming (OPCIONAL): Steam + Lutris + Wine + Vulkan + MangoHud + GameMode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

run_module_gaming() {
    ui_step "MÓDULO 05 — GAMING"
    ui_panel_start "Steam + Lutris + Vulkan + MangoHud + GameMode"
    export DEBIAN_FRONTEND=noninteractive
    detect_hardware

    ui_info "Verificando arquitectura i386..."
    dpkg --print-foreign-architectures 2>/dev/null | grep -q i386 && ui_skip "i386 ya habilitado" || {
        run_cmd 2 "Habilitar i386" dpkg --add-architecture i386
        run_cmd 2 "apt update post-i386" apt update
    }

    ui_info "Instalando Vulkan + Mesa + OpenGL..."
    for pkg in vulkan-tools vulkan-validationlayers libvulkan1 "libvulkan1:i386" \
                mesa-vulkan-drivers "mesa-vulkan-drivers:i386" libgl1-mesa-dri "libgl1-mesa-dri:i386" \
                libglx-mesa0 "libglx-mesa0:i386" mesa-utils libgles2 libva2 libva-drm2 vdpauinfo vainfo; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done

    ui_info "Instalando Steam..."
    { is_deb_installed steam-installer || is_deb_installed steam; } && ui_skip "Steam" \
        || run_cmd 2 "Instalar steam-installer" apt install -y steam-installer

    ui_info "Instalando Lutris..."
    if ! is_deb_installed lutris; then
        run_cmd 1 "Instalar lutris" apt install -y lutris
    else ui_skip "Lutris"; fi

    ui_info "Instalando Wine..."
    if ! is_deb_installed wine64; then
        if ! ls /etc/apt/sources.list.d/ 2>/dev/null | grep -q winehq; then
            run_cmd 1 "GPG key WineHQ" bash -c \
                'curl -fsSL https://dl.winehq.org/wine-builds/winehq.key \
                | gpg --dearmor -o /usr/share/keyrings/winehq.gpg'
            run_cmd 1 "Repo WineHQ (${DETECT_DISTRO})" bash -c \
                "echo 'deb [arch=amd64,i386 signed-by=/usr/share/keyrings/winehq.gpg] \
                https://dl.winehq.org/wine-builds/${DETECT_DISTRO}/ ${DETECT_OS_CODENAME} main' \
                > /etc/apt/sources.list.d/winehq.list"
            run_cmd 1 "apt update post-WineHQ" apt update
        fi
        for pkg in wine64 wine32 winetricks; do
            is_deb_installed "$pkg" && ui_skip "$pkg" \
                || run_cmd 1 "Instalar $pkg" apt install -y --install-recommends "$pkg"
        done
    else ui_skip "Wine"; fi

    ui_info "Instalando MangoHud..."
    is_deb_installed mangohud && ui_skip "MangoHud" \
        || run_cmd 1 "Instalar mangohud" apt install -y mangohud

    local real_user="${SUDO_USER:-$USER}"
    local mango_dir; mango_dir="$(eval echo "~$real_user")/.config/MangoHud"
    mkdir -p "$mango_dir"
    [[ ! -f "${mango_dir}/MangoHud.conf" ]] && cat > "${mango_dir}/MangoHud.conf" << 'EOF'
# MangoHud — AUTO SETUP
fps
gpu_stats
gpu_temp
gpu_load_change
cpu_stats
cpu_temp
ram
vram
frametime
frame_timing
position=top-left
font_size=24
background_alpha=0.4
toggle_hud=Shift_R+F12
toggle_fps_limit=Shift_L+F1
EOF

    ui_info "Instalando GameMode..."
    is_deb_installed gamemode && ui_skip "GameMode" \
        || run_cmd 1 "Instalar gamemode" apt install -y gamemode libgamemode0 libgamemodeauto0

    ui_info "Instalando ProtonUp-Qt..."
    flatpak list 2>/dev/null | grep -q 'pupgui2' && ui_skip "ProtonUp-Qt" \
        || run_cmd 1 "Instalar ProtonUp-Qt" flatpak install -y flathub net.davidotek.pupgui2

    ui_info "Instalando codecs multimedia..."
    local codecs=(ffmpeg gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
                  gstreamer1.0-plugins-good gstreamer1.0-libav gstreamer1.0-vaapi mpv vlc)
    is_ubuntu && codecs+=(ubuntu-restricted-extras)
    for pkg in "${codecs[@]}"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done

    local monitors=(btop htop); has_nvidia && monitors+=(nvtop)
    for pkg in "${monitors[@]}"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done

    ui_panel_end; ui_ok "Módulo 05 completado"
    echo ""; ui_info "Tips:"
    echo -e "  ${C_DIM}• Steam: activar Proton para todos los juegos${C_RESET}"
    echo -e "  ${C_DIM}• Launch options: gamemoderun %command%${C_RESET}"
    echo -e "  ${C_DIM}• MangoHud: MANGOHUD=1 %command%${C_RESET}"
    echo -e "  ${C_DIM}• ProtonUp-Qt: instala Proton-GE para mayor compatibilidad${C_RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/05-gaming.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_gaming; ui_summary
fi

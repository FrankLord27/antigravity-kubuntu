#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — modules/14-theme.sh [Debian 13 / Ubuntu 26.04]
#  Tema «Arcade Tokyo»: escritorio retro de 8 bits con colores Tokyo Night.
#   • Fondo animado (batalla espacial), barra superior y dock con zoom en cada pantalla.
#   • HUD de escritorio: CPU, GPU, RAM, audio, clima y reloj.
#   • Colores, iconos y cursor pixel art, marcos neón, botones de ventana propios.
#   • Sonidos chiptune, terminal con fuente pixel y cartel de estado.
#   • Pantalla de arranque con marcianos (Plymouth).
#
#  Casi todo vive en la carpeta personal del usuario y lo aplica theme/aplicar.sh sin sudo.
#  Este módulo solo instala paquetes, copia el tema, lanza ese script como el usuario real
#  y, con permisos de root, instala la pantalla de arranque.
#  Opciones: configs/theme.conf
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/configs/theme.conf"

# Ejecuta un comando como el usuario real, con acceso a su sesión gráfica (D-Bus y Wayland).
_theme_as_user() {
    local ru uid; ru="$(real_user)"; uid="$(id -u "$ru")"
    sudo -u "$ru" env HOME="$(real_home)" XDG_RUNTIME_DIR="/run/user/${uid}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" DISPLAY="${DISPLAY:-:0}" "$@"
}

_theme_packages() {
    local pkg
    for pkg in "${PKGS_THEME[@]}"; do
        is_deb_installed "$pkg" && { ui_skip "$pkg"; continue; }
        apt-cache show "$pkg" &>/dev/null || { ui_info "$pkg no existe en esta versión — omitido"; continue; }
        run_cmd 1 "Instalar $pkg" apt-get install -y "$pkg"
    done
}

# El tema se copia a la carpeta del usuario para que siga disponible aunque se borre el repo
# (el arranque automático y las reinstalaciones lo ejecutan desde ahí).
# Las carpetas las crea el propio usuario: creadas por root, ~/.local quedaría sin permisos
# de escritura para él en una cuenta recién hecha.
_theme_copy() {
    local dest="$1" ru; ru="$(real_user)"
    _theme_as_user mkdir -p "$dest" || return 1
    rm -rf "${dest}/src"
    cp -r "${SCRIPT_DIR}/theme" "${dest}/src" || return 1
    cp "${SCRIPT_DIR}/configs/theme.conf" "${dest}/src/tema.conf" || return 1
    chmod +x "${dest}/src/aplicar.sh"
    chown -R "$ru":"$ru" "${dest}/src"
}

# Sin sesión de Plasma abierta (instalación desde una TTY o por SSH) la activación se deja
# para el primer inicio de sesión. El lanzador llama a un script sin argumentos ni comillas
# (el formato .desktop no las garantiza); el script se retira al terminar bien o al tercer intento.
_theme_autostart() {
    local home="$1" dest="$2" ru; ru="$(real_user)"
    local dir="${home}/.config/autostart"
    _theme_as_user mkdir -p "$dir" || return 1
    cat > "${dest}/autostart.sh" <<'EOF'
#!/usr/bin/env bash
# Activa el tema Arcade Tokyo en el primer inicio de sesión (lo deja modules/14-theme.sh).
here="$HOME/.local/share/arcade-tokyo"
launcher="$HOME/.config/autostart/arcade-tokyo.desktop"
tries=$(( $(cat "$here/autostart.intentos" 2>/dev/null || echo 0) + 1 ))
echo "$tries" > "$here/autostart.intentos"
sleep 8   # da tiempo a que Plasma termine de cargar
if "$here/src/aplicar.sh" sesion > "$here/autostart.log" 2>&1 || (( tries >= 3 )); then
    rm -f "$launcher" "$here/autostart.intentos"
fi
EOF
    chmod +x "${dest}/autostart.sh"
    cat > "${dir}/arcade-tokyo.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Aplicar tema Arcade Tokyo
Exec=${dest}/autostart.sh
X-KDE-autostart-phase=2
EOF
    chown "$ru":"$ru" "${dest}/autostart.sh" "${dir}/arcade-tokyo.desktop"
}

# La pantalla de arranque se genera en un directorio temporal de root y se instala con el
# script del repo: nada de lo que se ejecuta o se copia como root sale de la carpeta personal.
_theme_boot_splash() {
    local home="$1" tmp rc=0
    tmp="$(mktemp -d)" || return 1
    ARCADE_HOME="$tmp" ARCADE_FONT="${home}/.local/share/fonts/PressStart2P-Regular.ttf" \
        python3 -I "${SCRIPT_DIR}/theme/gen/arranque.py" \
        && bash "${SCRIPT_DIR}/theme/instalar_arranque.sh" "${tmp}/plymouth/arcade" || rc=$?
    rm -rf "$tmp"
    return $rc
}

run_module_theme() {
    ui_step "MÓDULO 14 — TEMA ARCADE TOKYO"
    if [[ "${INSTALL_THEME:-true}" != true ]]; then
        ui_info "INSTALL_THEME=false en configs/theme.conf — módulo omitido"; return 0
    fi
    ui_panel_start "Escritorio retro de 8 bits (Tokyo Night)"
    export DEBIAN_FRONTEND=noninteractive
    local home dest
    home="$(real_home)"; dest="${home}/.local/share/arcade-tokyo"

    if ! is_deb_installed plasma-desktop && ! is_deb_installed plasma-workspace; then
        ui_warn "No hay KDE Plasma instalado: ejecuta antes el módulo 4"; ui_panel_end; return 1
    fi

    _theme_packages
    run_cmd 2 "Copiar el tema a ${dest}" _theme_copy "$dest" || { ui_panel_end; return 1; }

    ui_info "Generando el tema (fondo animado, iconos, sonidos…): 1 o 2 minutos"
    run_cmd 1 "Generar e instalar los archivos del tema" _theme_as_user bash "${dest}/src/aplicar.sh" archivos

    if _theme_as_user qdbus6 org.kde.plasmashell /PlasmaShell &>/dev/null; then
        run_cmd 1 "Activar el tema en la sesión de Plasma" _theme_as_user bash "${dest}/src/aplicar.sh" sesion
    else
        run_cmd 1 "Dejar la activación para el próximo inicio de sesión" _theme_autostart "$home" "$dest"
        ui_info "No hay sesión de Plasma abierta: el tema se activará solo al iniciar sesión"
    fi

    if [[ "${THEME_BOOT_SPLASH:-true}" == true ]]; then
        if ! is_cmd_available plymouth-set-default-theme; then
            ui_warn "Pantalla de arranque omitida: falta Plymouth"
        elif [[ "$(plymouth-set-default-theme 2>/dev/null)" == "arcade" ]] && grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=.*splash' /etc/default/grub; then
            ui_skip "Pantalla de arranque arcade"
        else
            run_cmd 1 "Pantalla de arranque (reconstruye initramfs, ~1 min)" _theme_boot_splash "$home"
        fi
    fi

    ui_panel_end; ui_ok "Módulo 14 completado"
    ui_info "Cierra sesión y vuelve a entrar para que cursor, fuentes e iconos se carguen del todo"
    ui_info "Opciones (ciudad del clima, paneles, sonidos): configs/theme.conf"
    ui_info "Quitar la pantalla de arranque: sudo bash ${SCRIPT_DIR}/theme/instalar_arranque.sh --quitar"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/14-theme.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_theme; ui_summary
fi

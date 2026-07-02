#!/usr/bin/env bash
# =============================================================================
#  KUBUNTU AUTO SETUP — modules/11-desktop.sh [Kubuntu 26.04 LTS]
#  Desktop Snapshot: backup/restore fiel de la configuración visual de KDE
#
#  BACKUP  : copia al repo (configs/desktop/) los archivos reales del
#            escritorio actual — temas, paneles, decoración, fuentes, Konsole.
#  RESTORE : tras formatear, restaura todo 1:1 y reinstala por apt lo que
#            no cabe en git (papirus-icon-theme, wallpapers de Plasma).
#
#  NO respaldado (muy pesado para git, se reinstala aparte):
#  • Iconos Papirus (244MB)      → apt install papirus-icon-theme
#  • Iconos Fluent/Mkos (326MB)  → KDE Store, solo si los quieres de nuevo
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

readonly DESKTOP_BACKUP_DIR="${SCRIPT_DIR}/configs/desktop"

# Archivos de ~/.config que definen el aspecto del escritorio
readonly -a DESKTOP_CONFIG_FILES=(
    kdeglobals                                  # tema, iconos, colores, estilo apps
    kwinrc                                      # decoración ventanas, efectos, blur
    kwinrulesrc                                 # reglas de ventanas
    plasmarc                                    # tema Plasma
    plasma-org.kde.plasma.desktop-appletsrc     # paneles, dock, widgets, wallpaper
    kcminputrc                                  # cursor
    plasma-localerc                             # idioma/formatos KDE
    kscreenlockerrc                             # pantalla de bloqueo
    kglobalshortcutsrc                          # atajos de teclado
    konsolerc                                   # config Konsole
    dolphinrc                                   # config Dolphin
    gtk-3.0/settings.ini                        # tema apps GTK3
    gtk-4.0/settings.ini                        # tema apps GTK4
)

# Directorios de ~/.local/share con assets pequeños e irreproducibles
readonly -a DESKTOP_LOCAL_DIRS=(
    aurorae             # decoración Utterly-Round-Dark (KDE Store)
    konsole             # perfil Antigravity.profile
    fonts               # MesloLGS NF (p10k) + fuentes personales
    color-schemes       # esquemas de color personalizados
)

_desktop_backup() {
    local real_user="$1"
    local real_home; real_home=$(eval echo "~${real_user}")
    ui_info "Respaldando escritorio de ${real_user} → configs/desktop/"

    mkdir -p "${DESKTOP_BACKUP_DIR}/home-config" "${DESKTOP_BACKUP_DIR}/home-local"

    local f count=0
    for f in "${DESKTOP_CONFIG_FILES[@]}"; do
        if [[ -f "${real_home}/.config/${f}" ]]; then
            mkdir -p "${DESKTOP_BACKUP_DIR}/home-config/$(dirname "$f")"
            if cp -a "${real_home}/.config/${f}" "${DESKTOP_BACKUP_DIR}/home-config/${f}"; then
                (( count++ )) || true
            else
                ui_warn "No se pudo copiar ${f}"
            fi
        else
            ui_skip "~/.config/${f} no existe"
        fi
    done
    ui_ok "${count} archivos de ~/.config respaldados"

    local d
    for d in "${DESKTOP_LOCAL_DIRS[@]}"; do
        if [[ -d "${real_home}/.local/share/${d}" ]]; then
            rm -rf "${DESKTOP_BACKUP_DIR}/home-local/${d}"
            cp -a "${real_home}/.local/share/${d}" "${DESKTOP_BACKUP_DIR}/home-local/${d}" \
                && ui_ok "~/.local/share/${d} respaldado" || ui_warn "Fallo copiando ${d}"
        else
            ui_skip "~/.local/share/${d} no existe"
        fi
    done

    # Manifest: qué tema está activo y qué debe reinstalarse por apt en restore
    local icons cursor scheme lnf style
    icons=$(grep -A2 '^\[Icons\]' "${real_home}/.config/kdeglobals" 2>/dev/null | grep -oP '^Theme=\K.*' | head -1)
    cursor=$(grep -oP '^cursorTheme=\K.*' "${real_home}/.config/kcminputrc" 2>/dev/null | head -1)
    scheme=$(grep -oP '^ColorScheme=\K.*' "${real_home}/.config/kdeglobals" 2>/dev/null | head -1)
    if [[ -z "$scheme" ]] && command -v kreadconfig6 &>/dev/null; then
        if [[ $EUID -eq 0 ]]; then
            scheme=$(sudo -u "$real_user" kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)
        else
            scheme=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)
        fi
    fi
    lnf=$(grep -oP '^LookAndFeelPackage=\K.*' "${real_home}/.config/kdeglobals" 2>/dev/null | head -1)
    style=$(grep -oP '^widgetStyle=\K.*' "${real_home}/.config/kdeglobals" 2>/dev/null | head -1)
    cat > "${DESKTOP_BACKUP_DIR}/manifest.txt" << EOF
# KUBUNTU AUTO SETUP — Desktop Snapshot
# Fecha        : $(date '+%Y-%m-%d %H:%M:%S')
# Usuario      : ${real_user}
# Plasma       : $(plasmashell --version 2>/dev/null || echo desconocida)
IconTheme=${icons:-desconocido}
CursorTheme=${cursor:-desconocido}
ColorScheme=${scheme:-desconocido}
LookAndFeel=${lnf:-desconocido}
WidgetStyle=${style:-desconocido}
# Reinstalar por apt en restore (no respaldados por tamaño):
# - papirus-icon-theme          (iconos Papirus/Papirus-Dark)
# - plasma-workspace-wallpapers (wallpaper "Path")
# Temas NO respaldados (KDE Store, reinstala a mano si los quieres):
# - Iconos Fluent / Fluent-dark / Fluent-light
# - Iconos Mkos-Big-Sur (+ Night / Panel-white)
EOF
    ui_ok "Manifest generado (tema activo: ${icons:-?} / ${scheme:-?})"

    chown -R "${real_user}:${real_user}" "${DESKTOP_BACKUP_DIR}" 2>/dev/null || true
    ui_ok "Backup completo en configs/desktop/ — haz commit para conservarlo"
}

_desktop_restore() {
    local real_user="$1"
    local real_home; real_home=$(eval echo "~${real_user}")
    local uid; uid=$(id -u "$real_user")

    [[ ! -f "${DESKTOP_BACKUP_DIR}/manifest.txt" ]] && {
        ui_fail "No hay backup en configs/desktop/ — ejecuta primero el backup en tu PC configurada"
        return 1
    }
    ui_info "Restaurando escritorio desde configs/desktop/ ($(grep '# Fecha' "${DESKTOP_BACKUP_DIR}/manifest.txt" | cut -d: -f2-))"

    # Temas que se reinstalan por apt (demasiado pesados para git)
    for pkg in papirus-icon-theme plasma-workspace-wallpapers; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 2 "Instalar $pkg" apt install -y "$pkg"
    done

    # Detener plasmashell para que no sobrescriba los archivos al salir
    local user_env="XDG_RUNTIME_DIR=/run/user/${uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus"
    local shell_stopped=false
    if sudo -u "$real_user" env XDG_RUNTIME_DIR="/run/user/${uid}" \
        systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; then
        run_cmd 1 "Detener plasmashell" sudo -u "$real_user" env XDG_RUNTIME_DIR="/run/user/${uid}" \
            systemctl --user stop plasma-plasmashell.service && shell_stopped=true
    fi

    # Respaldo de seguridad de la config actual antes de pisarla
    local safety="${real_home}/.config/kubuntu-setup-pre-restore-$(date '+%Y%m%d-%H%M%S')"
    mkdir -p "$safety"
    local f count=0
    for f in "${DESKTOP_CONFIG_FILES[@]}"; do
        [[ -f "${real_home}/.config/${f}" ]] && { mkdir -p "${safety}/$(dirname "$f")"; cp -a "${real_home}/.config/${f}" "${safety}/${f}"; }
        if [[ -f "${DESKTOP_BACKUP_DIR}/home-config/${f}" ]]; then
            mkdir -p "${real_home}/.config/$(dirname "$f")"
            cp -a "${DESKTOP_BACKUP_DIR}/home-config/${f}" "${real_home}/.config/${f}" && { (( count++ )) || true; }
        fi
    done
    ui_ok "${count} archivos de config restaurados (respaldo previo: ${safety})"

    local d
    for d in "${DESKTOP_LOCAL_DIRS[@]}"; do
        if [[ -d "${DESKTOP_BACKUP_DIR}/home-local/${d}" ]]; then
            mkdir -p "${real_home}/.local/share"
            cp -a "${DESKTOP_BACKUP_DIR}/home-local/${d}" "${real_home}/.local/share/" \
                && ui_ok "~/.local/share/${d} restaurado" || ui_warn "Fallo restaurando ${d}"
        fi
    done

    chown -R "${real_user}:${real_user}" "${real_home}/.config" "${real_home}/.local/share" 2>/dev/null || true

    run_cmd 1 "Refrescar caché de fuentes" sudo -u "$real_user" fc-cache -f
    run_cmd 1 "Modo oscuro apps GTK" sudo -u "$real_user" bash -c \
        "${user_env} gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'"

    if $shell_stopped; then
        run_cmd 1 "Reiniciar plasmashell" sudo -u "$real_user" env XDG_RUNTIME_DIR="/run/user/${uid}" \
            systemctl --user start plasma-plasmashell.service
    fi
    ui_ok "Escritorio restaurado — cierra sesión y vuelve a entrar para aplicar todo"
    ui_warn "Iconos Fluent/Mkos-Big-Sur no incluidos (ver configs/desktop/manifest.txt)"
}

run_module_desktop() {
    ui_step "MÓDULO 11 — DESKTOP SNAPSHOT (backup/restore visual)"
    ui_panel_start "Configuración visual real de KDE Plasma 6"
    local real_user="${SUDO_USER:-$USER}"

    if [[ -f "${DESKTOP_BACKUP_DIR}/manifest.txt" ]]; then
        # Hay backup: en instalación desatendida restauramos; interactivo pregunta
        if [[ "${AG_DESKTOP_MODE:-}" == "backup" ]]; then
            _desktop_backup "$real_user"
        elif [[ "${AG_DESKTOP_MODE:-}" == "restore" ]]; then
            _desktop_restore "$real_user"
        else
            echo -e "  Backup existente: $(grep '# Fecha' "${DESKTOP_BACKUP_DIR}/manifest.txt" | cut -d: -f2-)"
            echo ""
            if ui_confirm "¿RESTAURAR ese backup en este sistema? (N = actualizar el backup con el escritorio actual)"; then
                _desktop_restore "$real_user"
            else
                _desktop_backup "$real_user"
            fi
        fi
    else
        ui_info "No existe backup previo — se creará uno con tu escritorio actual"
        _desktop_backup "$real_user"
    fi

    ui_panel_end; ui_ok "Módulo 11 completado"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/11-desktop.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_desktop; ui_summary
fi

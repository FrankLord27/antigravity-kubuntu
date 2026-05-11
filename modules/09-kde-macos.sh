#!/usr/bin/env bash
# ANTIGRAVITY — modules/09-kde-macos.sh [Kubuntu 26.04 LTS]
# KDE Plasma 6: macOS Look (Paneles, KWin) e Idioma Español

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

_configure_kde_macos() {
    local real_user="$1"
    ui_info "Configurando KDE Plasma 6 con estética macOS (paneles nativos)..."
    ui_warn "Requiere sesión gráfica activa"

    # Injecting DBUS_SESSION_BUS_ADDRESS to allow qdbus6/dbus-send under sudo
    local uid; uid=$(id -u "$real_user")
    local dbus_env="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus"

    # Configuración de Paneles vía DBus (Top Menu + Bottom Dock)
    # Usa archivos temporales para evitar el problema de variables locales no exportadas
    # bajo sudo y el infierno de quoting en dbus-send con scripts multilínea.
    local tmp_js; tmp_js=$(mktemp /tmp/antigravity-kde.XXXXXX.js)
    local wrapper; wrapper=$(mktemp /tmp/antigravity-kde.XXXXXX.sh)

    cat > "$tmp_js" << 'JS_EOF'
// Detectar pantalla primaria (la que está en la coordenada 0,0)
var primaryScreen = 0;
for (var s = 0; s < screenCount; s++) {
    var geo = screenGeometry(s);
    if (geo.x === 0 && geo.y === 0) { primaryScreen = s; break; }
}

// Guardar referencia a paneles viejos ANTES de crear los nuevos.
// Si borramos todo primero, Plasma detecta 0 paneles y revierte al config guardado.
var oldPanels = panels();
var oldRefs = [];
for (var i = 0; i < oldPanels.length; i++) { oldRefs.push(oldPanels[i]); }

// Crear barra superior estilo macOS en la pantalla primaria
var topPanel = new Panel();
topPanel.screen   = primaryScreen;
topPanel.location = "top";
topPanel.height   = 30;
topPanel.alignment = "center";
topPanel.hiding   = "none";
topPanel.addWidget("org.kde.plasma.kickoff");
topPanel.addWidget("org.kde.plasma.appmenu");
topPanel.addWidget("org.kde.plasma.panelspacer");
topPanel.addWidget("org.kde.plasma.digitalclock");
topPanel.addWidget("org.kde.plasma.panelspacer");
topPanel.addWidget("org.kde.plasma.systemtray");

// Crear dock inferior flotante en la pantalla primaria
var dock = new Panel();
dock.screen     = primaryScreen;
dock.location   = "bottom";
dock.alignment  = "center";
dock.lengthMode = "fit";
dock.floating   = true;
dock.height     = 58;
dock.hiding     = "dodgewindows";
dock.addWidget("org.kde.plasma.icontasks");

// Borrar paneles viejos (los nuevos ya existen, Plasma no ve 0 paneles)
for (var i = 0; i < oldRefs.length; i++) { oldRefs[i].remove(); }
JS_EOF

    # ${uid} y ${tmp_js} se expanden aquí; \$ se convierte en $ en el archivo wrapper
    cat > "$wrapper" << WRAPPER_EOF
#!/bin/bash
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus
PLASMA_SCRIPT=\$(cat "${tmp_js}")
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "\$PLASMA_SCRIPT"
WRAPPER_EOF

    chmod 644 "$tmp_js"
    chmod 755 "$wrapper"

    run_cmd 1 "Configurar paneles via DBus" sudo -u "$real_user" bash "$wrapper" \
        || ui_warn "DBus paneles: aplica manualmente en próxima sesión"

    rm -f "$tmp_js" "$wrapper"

    # Botones ventana a la izquierda estilo macOS
    run_cmd 1 "Botones izquierda" sudo -u "$real_user" bash -c \
        "${dbus_env} kwriteconfig6 --file kwinrc --group \"org.kde.kdecoration2\" --key \"ButtonsOnLeft\" \"XIA\""
    run_cmd 1 "Limpiar botones derecha" sudo -u "$real_user" bash -c \
        "${dbus_env} kwriteconfig6 --file kwinrc --group \"org.kde.kdecoration2\" --key \"ButtonsOnRight\" \"\""
    run_cmd 1 "Título centrado" sudo -u "$real_user" bash -c \
        "${dbus_env} kwriteconfig6 --file kwinrc --group \"org.kde.kdecoration2\" --key \"TitleAlignment\" \"Center\""

    # Efectos visuales
    run_cmd 1 "Habilitar compositing" sudo -u "$real_user" bash -c \
        "${dbus_env} kwriteconfig6 --file kwinrc --group \"Compositing\" --key \"Enabled\" \"true\""
    run_cmd 1 "Habilitar blur" sudo -u "$real_user" bash -c \
        "${dbus_env} kwriteconfig6 --file kwinrc --group \"Plugins\" --key \"blurEnabled\" \"true\""

    # Aplicar cambios KWin
    run_cmd 1 "Aplicar KWin" sudo -u "$real_user" bash -c \
        "${dbus_env} qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null" \
        || ui_warn "qdbus6 KWin: se aplicará tras reiniciar sesión"

    # Forzar modo oscuro en apps GTK (Chrome, instaladores, etc.) para evitar fondo blanco
    run_cmd 1 "Modo oscuro apps GTK" sudo -u "$real_user" bash -c \
        "${dbus_env} gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'" \
        || ui_warn "gsettings: si Chrome/apps salen con fondo blanco, ejecuta manualmente"

    # Breeze Dark es el tema Plasma que renderiza el dock flotante con bordes redondeados
    run_cmd 1 "Tema Plasma (bordes redondeados)" sudo -u "$real_user" bash -c \
        "${dbus_env} kwriteconfig6 --file plasmarc --group Theme --key name breeze-dark"

    ui_ok "KDE macOS look configurado"
}

_configure_spanish() {
    ui_info "Configurando idioma del sistema en español..."
    for pkg in language-pack-es language-pack-es-base language-pack-kde-es; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done
    run_cmd 1 "Generar locale es_ES.UTF-8" locale-gen es_ES.UTF-8 2>/dev/null || true
    run_cmd 1 "Generar locale es_DO.UTF-8" locale-gen es_DO.UTF-8 2>/dev/null || true

    [[ -f /etc/locale.conf ]] && grep -q 'es_' /etc/locale.conf 2>/dev/null && ui_skip "Locale español ya configurado" || {
        run_cmd 1 "Configurar locale español" bash -c 'cat > /etc/locale.conf << EOF
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
LC_ALL=es_ES.UTF-8
EOF'
        ui_ok "Locale configurado en español"
    }

    local real_user="${SUDO_USER:-$USER}"
    local uid; uid=$(id -u "$real_user")
    local dbus_env="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus"
    
    run_cmd 1 "Locale KDE español" sudo -u "$real_user" bash -c \
        "${dbus_env} kwriteconfig6 --file plasma-localerc --group \"Formats\" --key \"LANG\" \"es_ES.UTF-8\" 2>/dev/null" || true
    ui_ok "Idioma español configurado — activa tras cerrar sesión"
}

run_module_kde_macos() {
    ui_step "MÓDULO 09 — KDE MACOS LOOK"
    ui_panel_start "KDE Plasma 6 (Paneles, KWin, Idioma)"
    local real_user="${SUDO_USER:-$USER}"
    
    _configure_kde_macos "$real_user"
    _configure_spanish
    
    ui_panel_end; ui_ok "Módulo 09 completado"
    
    echo ""
    echo -e "${C_BOLD}  ┌─ PASOS MANUALES DE KDE MACOS ─────────────────────────────┐${C_RESET}"
    echo -e "  │                                                            │"
    echo -e "  │  ${C_WHITE}1.${C_RESET} Panel superior → clic derecho → Añadir widgets       │"
    echo -e "  │     → busca ${C_CYAN}Menú global${C_RESET} → arrástralo a la izquierda      │"
    echo -e "  │  ${C_WHITE}2.${C_RESET} Panel inferior → clic derecho gestor de tareas       │"
    echo -e "  │     → ${C_CYAN}Alternativas${C_RESET} → Solo iconos                        │"
    echo -e "  │  ${C_WHITE}3.${C_RESET} Panel → clic derecho → Configurar panel              │"
    echo -e "  │     → Opacidad → ${C_CYAN}Translúcido${C_RESET}                            │"
    echo -e "  │                                                            │"
    echo -e "  └────────────────────────────────────────────────────────────┘"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/09-kde-macos.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_kde_macos; ui_summary
fi

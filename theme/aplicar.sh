#!/usr/bin/env bash
# =============================================================================
#  Tema «Arcade Tokyo» — parte de usuario (se ejecuta SIN sudo, como tu usuario).
#
#    aplicar.sh archivos   Descarga, genera e instala los archivos del tema en tu carpeta
#                          personal. No necesita que Plasma esté abierto.
#    aplicar.sh sesion     Activa el tema y crea los paneles. Necesita una sesión de Plasma.
#    aplicar.sh todo       Las dos cosas (por defecto).
#
#  Se puede repetir: lo ya hecho se salta o se sobrescribe con el mismo resultado.
#  Lo llama modules/14-theme.sh; la configuración está en tema.conf (copia de configs/theme.conf).
# =============================================================================
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
export ARCADE_HOME="$DATA/arcade-tokyo"
CACHE="$ARCADE_HOME/cache"
VIDEO="$ARCADE_HOME/fondo.mp4"
FAILED=0

# shellcheck disable=SC1091
if [[ -f "$SRC/tema.conf" ]]; then source "$SRC/tema.conf"
elif [[ -f "$SRC/../configs/theme.conf" ]]; then source "$SRC/../configs/theme.conf"
else echo "No encuentro tema.conf"; exit 1; fi

ok()   { printf '  \e[32m✔\e[0m %s\n' "$*"; }
warn() { printf '  \e[33m!\e[0m %s\n' "$*"; }
# step "descripción" comando...  → ejecuta, informa y sigue aunque falle
step() {
    local desc="$1"; shift
    local out
    if out=$("$@" 2>&1); then ok "$desc"
    else warn "$desc — FALLÓ"; printf '%s\n' "$out" | tail -4 | sed 's/^/      /'; FAILED=$((FAILED + 1)); fi
}
py() { python3 -I "$@"; }  # -I: no carga módulos desde la carpeta actual

# descarga <url> <sha256> <destino>: solo se queda con el archivo si la suma coincide
download() {
    local url="$1" sha="$2" dest="$3" tmp
    [[ -f "$dest" ]] && echo "$sha  $dest" | sha256sum -c --quiet 2>/dev/null && return 0
    tmp="$(mktemp)"
    curl -fsSL --max-time 180 -o "$tmp" "$url" || { rm -f "$tmp"; echo "no se pudo descargar $url"; return 1; }
    echo "$sha  $tmp" | sha256sum -c --quiet || { rm -f "$tmp"; echo "suma SHA-256 distinta en $url"; return 1; }
    mkdir -p "$(dirname "$dest")" && mv "$tmp" "$dest"
}

# clona <repo> <ref> <carpeta> en una revisión exacta (tag o SHA)
clone_at() {
    local repo="$1" ref="$2" dir="$3"
    if [[ ! -d "$dir/.git" ]]; then rm -rf "$dir"; git init -q "$dir" && git -C "$dir" remote add origin "$repo" || return 1; fi
    git -C "$dir" fetch -q --depth 1 origin "$ref" && git -C "$dir" checkout -q FETCH_HEAD
}

kpackage() { # kpackage <tipo> <carpeta>: instala o actualiza
    kpackagetool6 -t "$1" -u "$2" >/dev/null 2>&1 || kpackagetool6 -t "$1" -i "$2"
}

# ─── FASE 1: ARCHIVOS ────────────────────────────────────────────────────────
_fonts() {
    download "$THEME_FONT_PIXEL_URL" "$THEME_FONT_PIXEL_SHA256" "$DATA/fonts/PressStart2P-Regular.ttf" || return 1
    download "$THEME_FONT_TERM_URL" "$THEME_FONT_TERM_SHA256" "$CACHE/DepartureMono.zip" || return 1
    unzip -o -q "$CACHE/DepartureMono.zip" DepartureMonoNerdFont-Regular.otf DepartureMonoNerdFontMono-Regular.otf -d "$DATA/fonts" || return 1
    fc-cache -f
}

_video() {
    [[ -s "$VIDEO" ]] && return 0
    (cd "$ARCADE_HOME" && py "$SRC/gen/video.py" "$VIDEO.tmp.mp4") && mv "$VIDEO.tmp.mp4" "$VIDEO"
}

_icons() {
    clone_at "$THEME_ICONS_REPO" "$THEME_ICONS_REF" "$CACHE/pixelitos" || return 1
    rm -rf "$DATA/icons/pixelitos-dark"
    mkdir -p "$DATA/icons" && cp -r "$CACHE/pixelitos/pixelitos-dark" "$DATA/icons/pixelitos-dark" || return 1
    # carpetas moradas, a juego con el acento del tema
    cp -r "$DATA/icons/pixelitos-dark/folder-colors/purple/16/." "$DATA/icons/pixelitos-dark/16/" || return 1
    py "$SRC/gen/iconos_nitidos.py"
}

_invader_icon() { # icono del menú de aplicaciones
    mkdir -p "$DATA/icons/arcade"
    py - "$DATA/icons/arcade/invader.svg" <<'EOF'
import sys
rows = ("00100000100", "00010001000", "00111111100", "01101110110", "11111111111", "10111111101", "10100000101", "00011011000")
r = "".join(f'<rect x="{c + 0.5}" y="{y + 2}" width="1" height="1"/>' for y, row in enumerate(rows) for c, v in enumerate(row) if v == "1")
open(sys.argv[1], "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12" shape-rendering="crispEdges" fill="#bb9af7">{r}</svg>')
EOF
}

_cursors() {
    py "$SRC/gen/cursores.py" || return 1
    # Plasma busca los cursores del usuario en ~/.icons
    mkdir -p "$HOME/.icons" && ln -sfn "$DATA/icons/ArcadePixel" "$HOME/.icons/ArcadePixel"
}

_video_plugin() {
    clone_at "$THEME_VIDEO_PLUGIN_REPO" "$THEME_VIDEO_PLUGIN_REF" "$CACHE/video-wallpaper" || return 1
    kpackage Plasma/Wallpaper "$CACHE/video-wallpaper/package"
}

_units() {
    mkdir -p "$CONFIG/systemd/user"
    cat > "$CONFIG/systemd/user/arcade-cava.service" <<'EOF'
[Unit]
Description=Visualizador de audio para Arcade Deck (cava por HTTP local)
After=pipewire.service

[Service]
ExecStart=/usr/bin/python3 -I %h/.local/share/arcade-tokyo/arcade_cava.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    cat > "$CONFIG/systemd/user/arcade-sound@.service" <<'EOF'
[Unit]
Description=Sonido arcade: %i

[Service]
Type=oneshot
ExecStart=/usr/bin/pw-play --volume 0.6 %h/.local/share/sounds/arcade/wav/%i.wav
LogLevelMax=warning
EOF
}

_konsole() {
    local dir="$DATA/konsole" profile name
    mkdir -p "$dir"
    # se reutiliza el perfil predeterminado si existe; si no, se crea uno
    name="$(kreadconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile 2>/dev/null)"
    if [[ -z "$name" || ! -f "$dir/$name" ]]; then
        name="Arcade Tokyo.profile"
        [[ -f "$dir/$name" ]] || printf '[General]\nName=Arcade Tokyo\nParent=FALLBACK/\n' > "$dir/$name"
        kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile "$name"
    fi
    profile="$dir/$name"
    kwriteconfig6 --file "$profile" --group Appearance --key ColorScheme TokyoNightArcade
    # Departure Mono trae los símbolos Nerd Font que usa el prompt de Powerlevel10k
    kwriteconfig6 --file "$profile" --group Appearance --key Font "DepartureMono Nerd Font,12.5,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    kwriteconfig6 --file "$profile" --group General --key TerminalMargin 12
    kwriteconfig6 --file "$profile" --group "Cursor Options" --key CursorShape 0
    kwriteconfig6 --file "$profile" --group "Cursor Options" --key UseCustomCursorColor true
    kwriteconfig6 --file "$profile" --group "Cursor Options" --key CustomCursorColor "125,207,255"
    kwriteconfig6 --file "$profile" --group "Terminal Features" --key BlinkingCursorEnabled true
}

# Quita las dos barras de botones de Konsole: sus funciones ya están en el menú de la barra superior.
# Konsole lleva la interfaz incrustada, así que se baja la de su misma versión y se guarda sin las barras.
_konsole_toolbars() {
    local ver f dest="$DATA/kxmlgui5/konsole"
    # dpkg-query no necesita pantalla (konsole --version puede fallar desde una TTY o por SSH)
    ver="$(dpkg-query -W -f='${Version}' konsole 2>/dev/null | sed -E 's/^[0-9]+://; s/[-+~].*//')"
    [[ -n "$ver" ]] || return 1
    mkdir -p "$dest" "$CACHE/konsole-$ver"
    for f in konsoleui.rc sessionui.rc; do
        if [[ ! -s "$CACHE/konsole-$ver/$f" ]]; then  # a un temporal: una descarga cortada no deja un archivo a medias
            curl -fsSL --max-time 30 -o "$CACHE/konsole-$ver/$f.tmp" "https://raw.githubusercontent.com/KDE/konsole/v$ver/desktop/$f" \
                && mv "$CACHE/konsole-$ver/$f.tmp" "$CACHE/konsole-$ver/$f" || { rm -f "$CACHE/konsole-$ver/$f.tmp"; return 1; }
        fi
        py - "$CACHE/konsole-$ver/$f" "$dest/$f" <<'EOF' || return 1
import re, sys
text = open(sys.argv[1]).read()
new, n = re.subn(r"[ \t]*<ToolBar name=\"\w+\">.*?</ToolBar>\n", "", text, flags=re.S)
if n != 1 or "<gui " not in text:
    sys.exit("formato inesperado en " + sys.argv[1])
open(sys.argv[2], "w").write(new)
EOF
    done
}

_zshrc() { # cartel con el estado del equipo al abrir Konsole; va en la primera línea, antes del instant prompt de p10k
    local rc="$HOME/.zshrc"
    [[ -f "$rc" ]] || { echo "no existe ~/.zshrc: ejecuta antes el módulo 7 (zsh)"; return 1; }
    grep -q "banner.zsh" "$rc" && return 0   # ya está (también vale una instalación anterior)
    sed -i --follow-symlinks '1i [[ -o interactive \&\& -n $KONSOLE_VERSION \&\& -r ~/.local/share/arcade-tokyo/banner.zsh ]] \&\& source ~/.local/share/arcade-tokyo/banner.zsh' "$rc"
}

phase_files() {
    echo "Tema Arcade Tokyo — archivos"
    mkdir -p "$ARCADE_HOME" "$CACHE"
    step "Copiar cartel de terminal y servidor del visualizador" cp "$SRC/banner.zsh" "$SRC/arcade_cava.py" "$ARCADE_HOME/"
    step "Fuentes pixel (Press Start 2P, Departure Mono)" _fonts
    step "Fondo animado (se genera aquí; tarda alrededor de un minuto)" _video
    step "Esquemas de color Tokyo Night" py "$SRC/gen/colores.py"
    step "Iconos Pixelitos nítidos" _icons
    step "Icono del menú" _invader_icon
    step "Cursores pixel art" _cursors
    step "Estilo de Plasma (marcos neón)" py "$SRC/gen/tema_plasma.py"
    step "Decoración de ventanas" py "$SRC/gen/ventanas.py"
    step "Sonidos chiptune" py "$SRC/gen/sonidos.py"
    step "Plugin de fondo de video" _video_plugin
    step "Widget Arcade Deck" kpackage Plasma/Applet "$SRC/widget"
    step "Script de sonidos de ventanas" kpackage KWin/Script "$SRC/kwin-sonidos"
    step "Servicios de usuario" _units
    step "Perfil de Konsole" _konsole
    step "Konsole sin barras de botones" _konsole_toolbars
    step "Cartel en ~/.zshrc" _zshrc
}

# ─── FASE 2: SESIÓN ──────────────────────────────────────────────────────────
_kwin() {
    local kv
    for kv in glideEnabled=true wobblywindowsEnabled=true magiclampEnabled=true fallapartEnabled=true scaleEnabled=false squashEnabled=false \
              "arcadesonidosEnabled=${THEME_WINDOW_SOUNDS:-true}"; do
        kwriteconfig6 --file kwinrc --group Plugins --key "${kv%=*}" "${kv#*=}" || return 1
    done
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__ArcadeTokyo
    kwriteconfig6 --file kdeglobals --group WM --key activeFont "Press Start 2P,7,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    kwriteconfig6 --file kdeglobals --group Sounds --key Theme arcade
    qdbus6 org.kde.KWin /KWin reconfigure
}

_icon_theme() {
    local tool
    tool="$(find /usr/lib /usr/libexec -name plasma-changeicons 2>/dev/null | head -1)"
    [[ -n "$tool" ]] || { echo "no encuentro plasma-changeicons"; return 1; }
    "$tool" pixelitos-dark
}

_services() {
    systemctl --user daemon-reload || return 1
    if [[ "${THEME_AUDIO_VISUALIZER:-true}" == true ]]; then systemctl --user enable --now arcade-cava.service
    else systemctl --user disable --now arcade-cava.service 2>/dev/null; true; fi
}

_panels() {
    local rc="$CONFIG/plasma-org.kde.plasma.desktop-appletsrc" script out hud width x
    # una sola copia: la del escritorio tal como estaba antes del tema
    [[ -f "$rc" && ! -f "$ARCADE_HOME/appletsrc.antes-del-tema" ]] && cp "$rc" "$ARCADE_HOME/appletsrc.antes-del-tema"
    [[ "$THEME_LAT" =~ ^-?[0-9]+(\.[0-9]+)?$ && "$THEME_LON" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || { echo "THEME_LAT/THEME_LON deben ser números"; return 1; }
    local city="${THEME_CITY//[^[:alnum:] .,-]/}"   # va dentro de una cadena de JavaScript
    esc() { printf '%s' "$1" | sed 's/[&|\\]/\\&/g'; }   # caracteres especiales del reemplazo de sed
    script="$(sed -e "s|@HOME@|$(esc "$HOME")|g" -e "s|@VIDEO@|$(esc "$VIDEO")|g" -e "s|@CITY@|$(esc "$city")|g" \
                  -e "s|@LAT@|$THEME_LAT|g" -e "s|@LON@|$THEME_LON|g" \
                  -e "s|@REPLACE@|$([[ "${THEME_REPLACE_PANELS:-true}" == true ]] && echo true || echo false)|g" "$SRC/paneles.js")"
    out="$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script")" || { echo "$out"; return 1; }
    echo "$out"
    # evaluateScript devuelve los errores del script como texto y con código 0
    grep -q '^PANELES=' <<<"$out" || { echo "paneles.js no terminó"; return 1; }
    # El script no puede elegir la posición del HUD: se corrige en el archivo con el shell parado.
    hud="$(sed -n 's/^HUD=\([0-9]*\) .*/\1/p' <<<"$out")"
    width="$(sed -n 's/^HUD=[0-9]* ANCHO=\([0-9]*\).*/\1/p' <<<"$out")"
    [[ -n "$hud" && -n "$width" ]] || return 0
    x=$(( width - 960 - 16 )); (( x < 0 )) && x=0
    systemctl --user stop plasma-plasmashell.service || { echo "no se pudo parar plasmashell: el HUD queda arriba a la izquierda"; return 0; }
    sleep 2
    sed -i -E "s/Applet-$hud:[0-9]+,[0-9]+,[0-9]+,[0-9]+,/Applet-$hud:$x,48,960,240,/g" "$rc" || true
    systemctl --user start plasma-plasmashell.service   # siempre se vuelve a arrancar, falle o no el cambio
}

phase_session() {
    echo "Tema Arcade Tokyo — sesión"
    if ! qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then
        warn "No hay una sesión de Plasma abierta: esta parte se aplicará al iniciar sesión."
        exit 3   # código propio: el módulo deja un arranque automático
    fi
    step "Colores Tokyo Night Arcade" plasma-apply-colorscheme TokyoNightArcade
    step "Iconos Pixelitos" _icon_theme
    step "Cursor Arcade Pixel" plasma-apply-cursortheme ArcadePixel
    step "Estilo de Plasma Arcade Tokyo" plasma-apply-desktoptheme ArcadeTokyo
    step "Efectos, decoración y sonidos de ventanas" _kwin
    step "Servicio del visualizador de audio" _services
    step "Fondo animado, paneles y HUD" _panels
}

case "${1:-todo}" in
    archivos) phase_files ;;
    sesion)   phase_session ;;
    todo)     phase_files; phase_session ;;
    *) echo "Uso: aplicar.sh [archivos|sesion|todo]"; exit 2 ;;
esac
(( FAILED == 0 )) || { warn "$FAILED paso(s) con error"; exit 1; }

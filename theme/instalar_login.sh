#!/usr/bin/env bash
# =============================================================================
#  Tema «Arcade Tokyo» — pantalla de login (SDDM). Necesita root.
#
#    sudo bash theme/instalar_login.sh <carpeta-del-tema> [usuario]   instala
#    sudo bash theme/instalar_login.sh --quitar [usuario]             vuelve al tema anterior
#
#  <carpeta-del-tema> la arma modules/14-theme.sh en un directorio temporal de root:
#  Main.qml, Key.qml, metadata.desktop, theme.conf, assets/fondo.png,
#  assets/PressStart2P-Regular.ttf y, si existe, «face» (la foto de [usuario]).
#  Nada de lo que se copia como root sale de la carpeta personal sin pasar por ahí.
# =============================================================================
set -euo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo "Ejecuta este script con sudo."; exit 1; }

DST=/usr/share/sddm/themes/arcade
CONF=/etc/sddm.conf.d/arcade.conf
FACES=/usr/share/sddm/faces

user_ok() { [[ -z "$1" || "$1" =~ ^[a-z_][a-z0-9_-]*$ ]]; }

if [[ "${1:-}" == "--quitar" ]]; then
    U="${2:-}"; user_ok "$U" || { echo "Usuario no válido."; exit 1; }
    rm -rf "$DST" "$CONF"
    if [[ -n "$U" ]]; then
        # se devuelve la foto que había antes (si había); si no, se quita la copia del tema
        if [[ -f "$FACES/$U.face.icon.respaldo-arcade" ]]; then mv -f "$FACES/$U.face.icon.respaldo-arcade" "$FACES/$U.face.icon"
        else rm -f "$FACES/$U.face.icon"; fi
    fi
    echo "Listo: quitado el login arcade; SDDM vuelve a su tema anterior."
    exit 0
fi

SRC="${1:-}"; U="${2:-}"
user_ok "$U" || { echo "Usuario no válido."; exit 1; }
for f in Main.qml Key.qml metadata.desktop theme.conf assets/fondo.png assets/PressStart2P-Regular.ttf; do
    [[ -f "$SRC/$f" ]] || { echo "Uso: $0 <carpeta-del-tema> [usuario] | --quitar [usuario]  (falta $f)"; exit 1; }
done
# no se siguen enlaces: solo archivos normales
if find "$SRC" -type l | grep -q .; then echo "La carpeta del tema contiene enlaces simbólicos: no se instala."; exit 1; fi

rm -rf "$DST"
install -d -m 755 "$DST" "$DST/assets"
install -m 644 -o root -g root "$SRC"/{Main.qml,Key.qml,metadata.desktop,theme.conf} "$DST"/
install -m 644 -o root -g root "$SRC"/assets/* "$DST/assets"/
install -d -m 755 /etc/sddm.conf.d
# InputMethod vacío: sin el teclado virtual de Qt (tapa media pantalla). El tema trae el suyo, con botón.
printf '[General]\nInputMethod=\n\n[Theme]\nCurrent=arcade\n' > "$CONF"
# La carpeta personal es privada: SDDM no puede leer ~/.face, así que la foto se copia donde sí puede.
if [[ -n "$U" && -f "$SRC/face" ]]; then
    [[ -f "$FACES/$U.face.icon" && ! -f "$FACES/$U.face.icon.respaldo-arcade" ]] && cp -p "$FACES/$U.face.icon" "$FACES/$U.face.icon.respaldo-arcade"
    install -D -m 644 -o root -g root "$SRC/face" "$FACES/$U.face.icon"
fi
echo "Listo: login «arcade» instalado. Se verá en la próxima pantalla de login."

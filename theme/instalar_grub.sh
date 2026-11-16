#!/usr/bin/env bash
# =============================================================================
#  Tema «Arcade Tokyo» — menú de GRUB. Necesita root.
#
#    sudo bash theme/instalar_grub.sh <carpeta-del-tema> [segundos]   instala
#    sudo bash theme/instalar_grub.sh --quitar                        vuelve al menú anterior
#
#  <carpeta-del-tema> la genera theme/gen/grub.py (theme.txt, fondo, marco, iconos, fuentes).
#  modules/14-theme.sh la genera en un directorio temporal de root y llama a este script:
#  así nada de lo que se ejecuta o se copia como root sale de la carpeta personal.
#  Un tema de GRUB solo cambia el aspecto del menú: si falla al cargar, GRUB vuelve solo
#  al menú de texto y el arranque no se afecta.
# =============================================================================
set -euo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo "Ejecuta este script con sudo."; exit 1; }

DST=/boot/grub/themes/arcade
GRUB=/etc/default/grub
RESPALDO="$GRUB.respaldo-grub-arcade"

# pone CLAVE="valor" en /etc/default/grub: reemplaza la línea, o la comentada, o la añade
poner() {
    local k="$1" v="$2"
    if grep -qE "^${k}=" "$GRUB"; then sed -i -E "s|^${k}=.*|${k}=\"${v}\"|" "$GRUB"
    elif grep -qE "^#\s*${k}=" "$GRUB"; then sed -i -E "0,/^#\s*${k}=.*/s||${k}=\"${v}\"|" "$GRUB"
    else printf '%s="%s"\n' "$k" "$v" >> "$GRUB"; fi
}

if [[ "${1:-}" == "--quitar" ]]; then
    sed -i -E '/^GRUB_THEME=/d; /^GRUB_GFXMODE=/d' "$GRUB"
    # el tiempo de espera vuelve al que había antes de instalar el tema
    if [[ -f "$RESPALDO" ]]; then
        ANTES="$(grep -E '^GRUB_TIMEOUT=' "$RESPALDO" | head -n 1 | cut -d= -f2- || true)"
        [[ -n "$ANTES" ]] && sed -i -E "s|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=${ANTES}|" "$GRUB"
    fi
    rm -rf "$DST"
    update-grub
    echo "Listo: quitado el menú arcade; GRUB vuelve a su aspecto anterior."
    exit 0
fi

SRC="${1:-}"; SEG="${2:-3}"
[[ "$SEG" =~ ^[0-9]{1,2}$ ]] || { echo "Los segundos deben ser un número."; exit 1; }
for f in theme.txt background.png pressstart12.pf2 pressstart16.pf2 pressstart32.pf2 menu_c.png select_c.png; do
    [[ -f "$SRC/$f" ]] || { echo "Uso: $0 <carpeta-del-tema> [segundos] | --quitar  (falta $f)"; exit 1; }
done
# no se siguen enlaces: solo archivos normales del tema
if find "$SRC" -type l | grep -q .; then echo "La carpeta del tema contiene enlaces simbólicos: no se instala."; exit 1; fi
[[ -d /boot/grub ]] || { echo "No hay /boot/grub: este equipo no usa GRUB."; exit 1; }

[[ -f "$RESPALDO" ]] || cp "$GRUB" "$RESPALDO"
rm -rf "$DST"
install -d -m 755 "$DST" "$DST/icons"
find "$SRC" -maxdepth 1 -type f -exec install -m 644 -o root -g root {} "$DST"/ \;
find "$SRC/icons" -maxdepth 1 -type f -exec install -m 644 -o root -g root {} "$DST/icons"/ \; 2>/dev/null || true
poner GRUB_THEME "$DST/theme.txt"
# 1920x1080 si la pantalla lo tiene; si no, la mejor que haya
poner GRUB_GFXMODE "1920x1080,auto"
sed -i -E "s|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=${SEG}|" "$GRUB"
grep -E '^(GRUB_THEME|GRUB_GFXMODE|GRUB_TIMEOUT)=' "$GRUB"
update-grub
echo "Listo. El menú nuevo se verá en el próximo arranque."

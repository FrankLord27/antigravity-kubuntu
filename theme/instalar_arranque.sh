#!/usr/bin/env bash
# =============================================================================
#  Tema «Arcade Tokyo» — pantalla de arranque (Plymouth). Necesita root.
#
#    sudo bash theme/instalar_arranque.sh <carpeta-del-tema>   instala
#    sudo bash theme/instalar_arranque.sh --quitar             vuelve al tema anterior
#
#  <carpeta-del-tema> es la que genera theme/gen/arranque.py (imágenes + arcade.script).
#  modules/14-theme.sh la genera en un directorio temporal de root y llama a este script:
#  así nada de lo que se ejecuta o se copia como root sale de la carpeta personal.
# =============================================================================
set -euo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo "Ejecuta este script con sudo."; exit 1; }

DST=/usr/share/plymouth/themes/arcade
GRUB=/etc/default/grub
PREV_FILE=/etc/plymouth/tema-anterior-arcade

if [[ "${1:-}" == "--quitar" ]]; then
    PREV="$(cat "$PREV_FILE" 2>/dev/null || true)"
    # sin tema anterior guardado se vuelve a «details», que existe en cualquier instalación de Plymouth
    [[ -n "$PREV" && -d "/usr/share/plymouth/themes/$PREV" ]] || PREV=details
    # solo se quita «splash»; el resto de /etc/default/grub se deja como esté ahora
    sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/ ?splash//' "$GRUB"
    plymouth-set-default-theme -R "$PREV"
    update-grub
    rm -rf "$DST" "$PREV_FILE"
    echo "Listo: restaurado el tema «$PREV» y quitado «splash» del arranque."
    exit 0
fi

SRC="${1:-}"
[[ -n "$SRC" && -f "$SRC/arcade.plymouth" && -f "$SRC/arcade.script" ]] || { echo "Uso: $0 <carpeta-del-tema> | --quitar"; exit 1; }
# no se siguen enlaces: solo archivos normales del tema
if find "$SRC" -type l | grep -q .; then echo "La carpeta del tema contiene enlaces simbólicos: no se instala."; exit 1; fi

[[ -f "$PREV_FILE" ]] || plymouth-set-default-theme > "$PREV_FILE" || true
[[ -f "$GRUB.respaldo-arcade" ]] || cp "$GRUB" "$GRUB.respaldo-arcade"
rm -rf "$DST"
install -d -m 755 "$DST"
install -m 644 -o root -g root "$SRC"/* "$DST"/
# «splash» activa la pantalla gráfica; «quiet» ya oculta los mensajes del kernel
if ! grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=.*splash' "$GRUB"; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash"/' "$GRUB"
fi
grep '^GRUB_CMDLINE_LINUX_DEFAULT' "$GRUB"
echo "Reconstruyendo el initramfs (tarda alrededor de un minuto)..."
plymouth-set-default-theme -R arcade
update-grub
echo "Listo. La pantalla nueva se verá en el próximo arranque."

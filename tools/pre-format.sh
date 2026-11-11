#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — tools/pre-format.sh
#  Córrelo en tu sistema ACTUAL, ANTES de formatear:
#
#     bash tools/pre-format.sh            (sin sudo; con sudo da más detalle de discos)
#
#  No cambia nada. Hace dos cosas:
#   1. Guarda el inventario de hardware en ~/pre-format/hardware.txt (para saber
#      qué chips tiene la PC si algo no funciona en Debian).
#   2. Te lista lo que se pierde al formatear y cuánto ocupa, para que lo copies
#      a un disco externo o a la nube.
# =============================================================================
set -u
OUT="${HOME}/pre-format"; mkdir -p "$OUT"
HW="${OUT}/hardware.txt"
B=$'\033[1m'; C=$'\033[0;36m'; Y=$'\033[1;33m'; G=$'\033[0;32m'; R=$'\033[0m'

sec() { printf '\n===== %s =====\n' "$1" >> "$HW"; }
run() { sec "$*"; "$@" >> "$HW" 2>&1 || echo "(no disponible)" >> "$HW"; }

: > "$HW"
echo "Inventario generado: $(date)" >> "$HW"
run uname -a
sec "os-release"; cat /etc/os-release >> "$HW" 2>/dev/null
run lscpu
run free -h
sec "placa base / BIOS"
for f in sys_vendor product_name board_vendor board_name bios_vendor bios_version bios_date; do
    printf '%s: %s\n' "$f" "$(cat /sys/class/dmi/id/$f 2>/dev/null)" >> "$HW"
done
sec "arranque"; { [[ -d /sys/firmware/efi ]] && echo "UEFI" || echo "BIOS heredado (Legacy)"; } >> "$HW"
command -v mokutil >/dev/null 2>&1 && run mokutil --sb-state
run lspci -nnk
run lsusb
run lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
run df -h
sec "red"; ip -br link >> "$HW" 2>&1
sec "módulos del kernel cargados"; lsmod 2>/dev/null | awk 'NR>1{print $1}' | sort | tr '\n' ' ' >> "$HW"; echo >> "$HW"
sec "firmware cargado en este arranque"; (dmesg 2>/dev/null || sudo -n dmesg 2>/dev/null) | grep -i firmware | sed 's/^\[[^]]*\] //' | sort -u | head -40 >> "$HW"
command -v nvidia-smi >/dev/null 2>&1 && run nvidia-smi
sec "paquetes instalados a mano (apt-mark showmanual)"; apt-mark showmanual 2>/dev/null >> "$HW"
command -v flatpak >/dev/null 2>&1 && { sec "flatpak"; flatpak list --app --columns=application 2>/dev/null >> "$HW"; }
command -v snap >/dev/null 2>&1 && { sec "snap"; snap list 2>/dev/null >> "$HW"; }
command -v code >/dev/null 2>&1 && { sec "extensiones de VS Code"; code --list-extensions 2>/dev/null >> "$HW"; }

echo ""
echo "${B}  ANTES DE FORMATEAR${R}"
echo ""
echo "  ${G}✓${R} Inventario de hardware guardado en ${C}${HW}${R}"
echo "    Cópialo fuera de esta PC (correo, nube, USB)."
echo ""
echo "${B}  Resumen del equipo${R}"
echo "    CPU   : $(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //')"
echo "    GPU   : $(lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed 's/.*: //' | head -2 | tr '\n' ';')"
echo "    Red   : $(lspci 2>/dev/null | grep -iE 'ethernet|network|wireless' | sed 's/.*: //' | head -3 | tr '\n' ';')"
echo "    Modo  : $([[ -d /sys/firmware/efi ]] && echo UEFI || echo 'BIOS heredado')   Secure Boot: $(mokutil --sb-state 2>/dev/null | head -1 || echo desconocido)"
echo ""
echo "${B}  Dispositivos USB de red o Bluetooth (los que más problemas dan)${R}"
lsusb 2>/dev/null | grep -iE 'wireless|wlan|802\.11|bluetooth|wi-fi|realtek|mediatek|ralink|tp-link' | sed 's/^/    /' || true
echo ""
echo "${B}  Lo que se pierde al formatear — respáldalo${R}"
item() { # $1 = ruta, $2 = qué es
    [[ -e "$1" ]] || return 0
    printf '    %s%-9s%s %-42s %s\n' "$Y" "$(du -sh "$1" 2>/dev/null | cut -f1)" "$R" "${1/#$HOME/\~}" "$2"
}
item "$HOME/.ssh"                    "claves SSH (si las pierdes, hay que volver a darlas de alta en GitHub y servidores)"
item "$HOME/.gnupg"                  "claves GPG"
item "$HOME/.gitconfig"              "configuración de git"
item "$HOME/.config/gh"              "sesión de GitHub CLI"
item "$HOME/.claude"                 "Claude Code: historial, memoria, configuración"
item "$HOME/.claude.json"            "Claude Code: servidores MCP y sesión"
item "$HOME/ai-lordkit-private"      "capa privada de ai-lordkit"
item "$HOME/.codex"                  "Codex CLI"
item "$HOME/.gemini"                 "Gemini CLI"
item "$HOME/.config/Code/User"       "VS Code: ajustes y atajos (o activa Settings Sync)"
item "$HOME/.config/google-chrome"   "Chrome: perfil (o activa la sincronización de Google)"
item "$HOME/.mozilla"                "Firefox: perfil"
item "$HOME/.thunderbird"            "Thunderbird: correo y cuentas"
item "$HOME/.config/remmina"         "Remmina: conexiones guardadas"
item "$HOME/.local/share/remmina"    "Remmina: conexiones guardadas"
item "$HOME/.zshrc"                  "tu configuración de shell"
item "$HOME/.p10k.zsh"               "tema de la terminal"
item "$HOME/.local/share/fonts"      "fuentes que instalaste a mano"
item "$HOME/.config/obs-studio"      "OBS: escenas y perfiles"
item "$HOME/.local/share/Steam"      "Steam: juegos (se pueden volver a bajar)"
for d in Documentos Documents Descargas Downloads Escritorio Desktop Imágenes Pictures Vídeos Videos Música Music Proyectos proyectos projects dev code; do
    item "$HOME/$d" "carpeta personal"
done
echo ""
echo "${B}  Repos de git con trabajo sin subir${R}"
found=0
while IFS= read -r g; do
    r="${g%/.git}"
    dirty=$(git -C "$r" status --porcelain 2>/dev/null | wc -l)
    ahead=$(git -C "$r" log --branches --not --remotes --oneline 2>/dev/null | wc -l)
    if [[ "$dirty" -gt 0 || "$ahead" -gt 0 ]]; then
        printf '    %s%s%s  (%s archivos sin commit, %s commits sin push)\n' "$Y" "${r/#$HOME/\~}" "$R" "$dirty" "$ahead"; found=1
    fi
done < <(find "$HOME" -maxdepth 4 -name .git -type d -not -path '*/node_modules/*' -not -path '*/.cache/*' 2>/dev/null)
[[ $found -eq 0 ]] && echo "    ${G}✓${R} Ninguno: todo está subido."
echo ""
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    echo "${B}  Docker: volúmenes con datos (bases de datos locales)${R}"
    docker volume ls --format '    {{.Name}}' 2>/dev/null | head -20
    echo "    Para guardar una base de datos:  docker exec <contenedor> pg_dump -U <usuario> <bd> > respaldo.sql"
    echo ""
fi
echo "${B}  Antes de apagar${R}"
echo "    1. Copia lo de arriba a un disco externo o a la nube y COMPRUEBA que abre."
echo "    2. Ten a mano las contraseñas de: GitHub, Google, Anthropic, OpenAI y tu Wi-Fi."
echo "    3. Sigue la guía: docs/GUIA-INSTALACION.md"
echo ""

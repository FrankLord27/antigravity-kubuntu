# Guía: formatear e instalar Debian 13 con todo configurado

De cero a la PC lista para trabajar. Son cuatro pasos: respaldar, instalar Debian, pegar un
comando y hacer los inicios de sesión.

Tiempo total aproximado: 1 hora (20 minutos tuyos, el resto es esperar).

---

## Paso 1 — Antes de formatear (en tu sistema actual)

1. Corre el script de respaldo. No cambia nada; solo revisa:

   ```bash
   cd ~/antigravity-kubuntu && git pull && bash tools/pre-format.sh
   ```

   Te muestra qué se pierde al formatear (claves SSH, perfiles, repos con trabajo sin subir,
   volúmenes de Docker) y guarda el inventario de hardware en `~/pre-format/hardware.txt`.

2. Copia todo lo que marque a un disco externo o a la nube, **incluido `hardware.txt`**, y
   comprueba que la copia abre.

3. Ten a mano las contraseñas de GitHub, Google, Anthropic, OpenAI y tu Wi-Fi.

4. Descarga la ISO y graba el USB:
   - ISO: <https://www.debian.org/download> → **debian-13.x.x-amd64-netinst.iso** (la normal;
     desde Debian 12 ya trae el firmware, no hace falta una ISO especial).
   - Grábala en un USB de 2 GB o más con **KDE ISO Image Writer**, **balenaEtcher** o:

     ```bash
     sudo dd if=debian-13.*-amd64-netinst.iso of=/dev/sdX bs=4M status=progress conv=fsync
     ```

     Cambia `sdX` por tu USB (míralo con `lsblk`). **Ese comando borra el disco que le digas.**

## Paso 2 — Instalar Debian

### En la BIOS (tecla Supr o F2 al encender)

- Modo de arranque: **UEFI** (no Legacy/CSM).
- **Secure Boot: desactivado.** Con Secure Boot activo el driver NVIDIA no carga y esta PC no
  tiene gráfica integrada. (Se puede dejar activo inscribiendo una llave; está al final.)
- Arranca desde el USB (F11 o F12 suele abrir el menú de arranque).

### En el instalador

Elige **Graphical install** y contesta así:

| Pantalla | Qué poner |
| --- | --- |
| Idioma / ubicación / teclado | Español · República Dominicana · Latinoamericano (o el que uses) |
| Red | Por cable se configura sola. Por Wi-Fi, elige tu red y pon la clave |
| Nombre de la máquina | El que quieras (ej. `frank-pc`) |
| **Contraseña de root** | **Déjala vacía** (las dos casillas). Así tu usuario queda con `sudo`. Si pones una, también funciona: el script te la pide una vez |
| Usuario | Tu nombre, tu usuario y tu contraseña |
| Particionado | **Guiado – utilizar todo el disco** → elige el disco → **Todos los ficheros en una partición** → Finalizar → **Sí** (esto borra el disco) |
| Réplica de paquetes | República Dominicana o Estados Unidos → `deb.debian.org` |
| Selección de programas | Marca **KDE Plasma**, **Utilidades estándar del sistema** y, si quieres, **Servidor SSH**. Desmarca GNOME |
| GRUB | Sí, en el disco principal |

> ¿Quieres un Debian más limpio? Deja marcado **solo** "Utilidades estándar del sistema" (sin
> escritorio). Arranca en pantalla negra con texto; entras con tu usuario y pegas el mismo
> comando. El script instala un KDE mínimo sin los programas de relleno. Solo te lo recomiendo
> si estás por cable: configurar Wi-Fi desde la consola es incómodo.

Al terminar, saca el USB y reinicia.

## Paso 3 — El comando

Entra con tu usuario, abre **Konsole** y pega:

```bash
wget -qO- https://raw.githubusercontent.com/FrankLord27/antigravity-kubuntu/main/install.sh | bash
```

Qué va a pasar:

1. Te pide tu contraseña (o la de root, si pusiste una).
2. Te pregunta **nombre y email para git**. Es lo único que pregunta.
3. Instala todo solo, unos 30 a 50 minutos según tu internet. Puedes dejarlo corriendo.
4. Al final muestra la verificación. **Léela antes de reiniciar**: si dice que el driver NVIDIA
   no está compilado, no reinicies y mira la sección de problemas.
5. `sudo reboot`

### Qué instala, en orden

| # | Módulo | Qué deja listo |
| --- | --- | --- |
| 1 | Sistema base | Repos `contrib`/`non-free`, actualización completa, herramientas, `sudo`, parches de seguridad automáticos |
| 2 | Drivers y firmware | Todo el firmware de Debian (Wi-Fi, Bluetooth, red, audio, video), microcode, headers del kernel. Lista los dispositivos que queden sin driver |
| 3 | NVIDIA | Driver **610 propietario** del repo oficial de NVIDIA, fijado en esa rama, con GSP apagado y librerías de 32 bits. Solo si hay tarjeta NVIDIA |
| 4 | Escritorio | KDE (si no lo marcaste), sesión X11 de respaldo, audio, Bluetooth, códecs, fuentes, discos USB, firewall |
| 5 | Docker | Docker CE + Compose + Portainer (solo en `localhost:9443`) |
| 6 | Desarrollo | nvm + Node 26 LTS + pnpm, VS Code, Chrome, Codex, Gemini, Orca, `psql`, `redis-cli`, Flatpak |
| 7 | Terminal | zsh + Oh My Zsh + Powerlevel10k + fuente MesloLGS |
| 8 | Git | Identidad, alias, clave SSH nueva, firma de commits, GitHub CLI |
| 9 | Apps | GIMP, OBS, Krita, Blender, Thunderbird, VLC, Remmina, AnyDesk, TeamViewer, Discord, Element… |
| 10 | Rendimiento | zram, earlyoom, TRIM del SSD, límites de inotify para proyectos Node |
| 11 | Gaming | Steam, Lutris, Wine, MangoHud, GameMode, ProtonUp-Qt, Heroic |
| 12 | Impresión | CUPS, drivers de impresora, escaneo |
| 13 | Claude | Claude Code + tu configuración **ai-lordkit** (agents, skills, hooks, modos, MCP, plugins) |
| 90 | Verificación | Revisa todo lo anterior |

Las listas de programas están en `configs/packages.conf`: comenta con `#` lo que no quieras
**antes** de correr el comando, o edítalo después y repite el módulo.

## Paso 4 — Después de reiniciar

En la pantalla de login, abajo a la izquierda, elige la sesión **Plasma (Wayland)**. Si notas
parpadeos o algo raro en pantalla, cierra sesión y entra con **Plasma (X11)**.

Abre Konsole (ya sale con zsh) y haz los inicios de sesión, una sola vez:

```bash
claude            # Claude Code: abre el navegador para iniciar sesión
gh auth login     # GitHub: elige SSH y deja que suba tu clave
codex login       # Codex
gemini            # Gemini
ag-verify         # vuelve a comprobar todo, ahora con el driver cargado
```

Luego:

- **Clave SSH en GitHub para firmar commits:**
  `gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "Debian"`
- **Restaura tu respaldo:** documentos, proyectos y, si quieres tus claves SSH antiguas,
  copia tu `~/.ssh` viejo encima (con permisos `chmod 600 ~/.ssh/id_*`).
- **Docker** ya funciona sin `sudo` (hizo falta el reinicio).
- **Orca:** ábrelo desde el menú y añade tus proyectos.
- **Tus ajustes de terminal** van en `~/.zshrc.local`. El `.zshrc` lo regenera el script; ese
  archivo nunca lo toca.

---

## Uso del script después

```bash
ag-setup                              # menú para correr o repetir módulos
ag-verify                             # verificación completa
ag-diag                               # diagnóstico de hardware y arranque
sudo bash ~/antigravity-kubuntu/setup.sh --auto     # repetir todo (salta lo ya instalado)
sudo bash ~/antigravity-kubuntu/modules/09-apps.sh  # un módulo suelto
```

Cada módulo detecta lo que ya está instalado y lo salta: se puede repetir sin miedo.
El log de cada ejecución queda en `/var/log/auto-setup/`.

Para actualizar el script: `git -C ~/antigravity-kubuntu pull`.

---

## Si algo falla

### Pantalla negra o no entra al escritorio tras reiniciar (NVIDIA)

1. Pulsa **Ctrl+Alt+F3**, entra con tu usuario.
2. Mira si el módulo se compiló: `sudo dkms status` (debe decir `installed`).
3. Repite el módulo: `sudo bash ~/antigravity-kubuntu/modules/03-nvidia.sh` y reinicia.
4. Si sigue igual, cambia de driver. Edita `~/antigravity-kubuntu/configs/packages.conf`:

   | Quiero | `NVIDIA_SOURCE` | `NVIDIA_BRANCH` | `NVIDIA_FLAVOR` |
   | --- | --- | --- | --- |
   | El 550 de Debian (el más probado) | `debian` | — | `proprietary` |
   | Otra rama propietaria de NVIDIA | `nvidia-repo` | `595` o `590` | `proprietary` |
   | La rama más nueva (solo existe open) | `nvidia-repo` | `620` | `open` |

   Luego quita el actual e instala el nuevo:

   ```bash
   sudo apt purge -y --auto-remove '*nvidia*' 'cuda-drivers*' 'libnvidia*' && sudo rm -f /etc/modprobe.d/nvidia-gsp.conf
   sudo bash ~/antigravity-kubuntu/modules/03-nvidia.sh && sudo reboot
   ```

   Si cambias a `open`, pon también `NVIDIA_DISABLE_GSP=false`: el driver open necesita GSP.

### Parpadeos o tirones en Wayland

Entra con la sesión **Plasma (X11)** desde la pantalla de login.

### No hay Wi-Fi o Bluetooth

`ag-diag` lista los dispositivos sin driver. Compara con tu `hardware.txt`. Los adaptadores
USB Realtek baratos (RTL88x2BU, RTL8821CU…) a veces necesitan un driver que Debian no trae;
con el identificador `xxxx:xxxx` de `lsusb` se busca el paquete DKMS correcto.

### Quiero dejar Secure Boot activado

```bash
sudo mokutil --import /var/lib/dkms/mok.pub   # te pide inventar una contraseña
sudo reboot                                   # en la pantalla azul: Enroll MOK → Continue → Yes → la contraseña
```

### El comando se cortó a mitad

Vuelve a pegarlo. Salta lo que ya está instalado y sigue.

### Un módulo dio error

Mira el log que indica al final (`/var/log/auto-setup/...`) y repite solo ese módulo con
`sudo bash ~/antigravity-kubuntu/modules/NN-nombre.sh`.

---

## Qué se probó y qué no

**Probado** dentro de un Debian 13 real (kernel 6.12.107), corriendo los módulos de verdad:

- Arranque desde un Debian sin `sudo`, `curl` ni `git`; línea `deb cdrom:` y repos `non-free`.
- Módulo 1 completo, sin errores.
- **Driver NVIDIA 610.57.04: instalado y compilado por DKMS para el kernel de Debian 13**, con
  la rama fijada, GSP apagado y librerías de 32 bits.
- Node 26.13 + pnpm, VS Code, Chrome, Codex, Gemini, zsh, git con clave SSH y firma.
- ai-lordkit: corre sin preguntar y usa el Node de nvm (no instala otro).
- Drivers, escritorio, apps, gaming e impresión: todos los paquetes existen y sus dependencias
  se resuelven en Debian 13.

**No se pudo probar** (hace falta la PC real):

- Que el driver 610 funcione bien en la GTX 1660 SUPER: carga del módulo, Wayland, suspensión.
- Wi-Fi, Bluetooth y audio de tu equipo.
- La descarga de Claude Code, TeamViewer, Orca y las apps de Flatpak (la red de la prueba no
  llegaba a esos servidores).
- La elevación con contraseña de root (`su`) y Docker en marcha.

# Instalador completo para Debian 13 — diseño

Fecha: 2026-11-10 · Estado: pendiente de aprobación

## Objetivo

Formatear la PC (i5-10400F sin gráfica integrada, GTX 1660 SUPER, 16 GB RAM), instalar
Debian 13 y, con **un solo comando**, dejarla lista para trabajar: drivers y firmware
completos, escritorio KDE, stack de desarrollo, apps y la configuración de Claude Code
(ai-lordkit). Sin preguntas a mitad de la instalación y sin pasos manuales ocultos.

Criterio de éxito: tras `reboot`, entra a KDE con el driver NVIDIA cargado, red, audio,
Bluetooth e impresión funcionando, `node`/`pnpm`/`docker`/`claude` en el PATH, y el
módulo de verificación sin errores.

## Decisiones tomadas (por Frank)

| Tema | Decisión |
| --- | --- |
| Driver NVIDIA | Repo apt oficial de NVIDIA para Debian 13, fijado en la rama **610 propietaria** (`nvidia-driver-pinning-610` + `cuda-drivers`), GSP apagado |
| Instalación de Debian | Guía paso a paso + script de post-instalación (sin preseed) |
| Discos | Solo Debian, se borra todo |
| Extras en la instalación automática | Ajustes de rendimiento, Gaming, Impresoras y escáner (Virtualización no) |
| ai-lordkit | Kit público, sin capa privada |
| Auditoría | PR de arreglos críticos/altos en ai-lordkit (subproyecto aparte) |
| 31 prácticas de rendimiento | PR en ai-lordkit con la checklist (subproyecto aparte) |

## Lo que se verificó contra Debian 13 real

Se descargaron los índices de paquetes de `trixie` y `trixie-backports` (70 847 paquetes)
y el índice del repo de NVIDIA para Debian 13. Todo nombre de paquete de este diseño
existe ahí. Datos clave: kernel 6.12.107, Plasma 6.3.6, `nvidia-driver` de Debian
550.163.01 (sin mantenimiento según la wiki de Debian), repo NVIDIA con 590 → 620
(la 580 no existe para Debian 13; la propietaria desaparece a partir de la 615).

## Fallos del instalador actual que este diseño corrige

1. **`sudo` puede no existir o el usuario no estar en el grupo.** Si en el instalador de
   Debian se pone contraseña de root, el usuario no queda en `sudo` y `install.sh` muere
   en la primera línea. → `install.sh` detecta el caso y se eleva con `su -c`, instala
   `sudo` y agrega el usuario al grupo.
2. **`curl` no viene en Debian** (prioridad `optional`; `wget` sí viene). El comando del
   README falla. → el comando de un paso usa `wget -qO-`.
3. **`APT::Install-Recommends "false"` global.** El script lo activa y por eso Debian
   queda "pelado": los paquetes llegan sin sus componentes recomendados. → se elimina.
4. **NVIDIA se decide antes de instalar `pciutils`.** Si `lspci` no está, el script cree
   que no hay GPU y se salta el driver; en esta PC eso es quedarse sin aceleración. →
   `pciutils` se instala en el arranque, antes de detectar hardware.
5. **Variables peligrosas en `/etc/environment`** (`QT_QPA_PLATFORM=wayland`,
   `SDL_VIDEODRIVER=wayland`, `GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`,
   `LIBVA_DRIVER_NAME`). Rompen la sesión X11 de respaldo y el login de SDDM, y hacen
   fallar juegos. → se eliminan; el driver 610 no las necesita.
6. **`fwupdmgr update -y` desatendido** puede flashear la BIOS a mitad de la instalación.
   → solo `refresh` + listar actualizaciones; aplicar queda manual.
7. **"Sin preguntas" es falso:** el módulo de git lee nombre y email de `/dev/tty` a
   mitad del proceso, y la confirmación de la clave SSH lee un stdin vacío (nunca se
   genera). → todas las preguntas se hacen **al inicio** y se guardan en
   `configs/local.conf` (fuera de git); la clave SSH se genera sin preguntar.
8. **`.zshrc` se reescribe entero en cada ejecución**, borrando el enlace de ai-lordkit y
   cualquier ajuste propio. → `.zshrc` carga `~/.zshrc.local` (nunca se toca) e incluye
   la línea de `shell-init.sh` de ai-lordkit.
9. **Claude Code duplicado:** el módulo 4 lo instala por npm y ai-lordkit con el
   instalador nativo. → se quita de npm; lo instala ai-lordkit.
10. **`bat` y `fd` en Debian se llaman `batcat` y `fdfind`:** los alias actuales nunca
    aplican. → alias corregidos.
11. **Repos duplicados de VS Code y Chrome** (el paquete crea su propio archivo de
    fuentes) → se usa el mismo nombre de archivo que crea el paquete.
12. **Portainer expuesto en todas las interfaces** → se ata a `127.0.0.1`.
13. **`wine32`** no existe como paquete amd64 → `wine32:i386`.
14. **Línea `deb cdrom:`** que deja el instalador rompe `apt update` → se comenta.
15. **Red "no gestionada":** si el instalador configuró la interfaz en
    `/etc/network/interfaces`, NetworkManager la ignora → se limpia ese archivo.

## Arquitectura

Se mantiene la estructura actual (un módulo por responsabilidad, `lib/` compartido,
listas en `configs/packages.conf`). Cambios por unidad:

| Unidad | Qué hace | Cambio |
| --- | --- | --- |
| `install.sh` | Bootstrap de un comando | Funciona con `wget`; se eleva con `sudo` o `su`; instala `git ca-certificates sudo pciutils`; clona y lanza `setup.sh --auto` |
| `setup.sh` | Orquestador | Fase de preguntas al inicio (`lib/config.sh`); nuevo orden; mantiene sudo vivo; resumen con rc real |
| `lib/config.sh` (nuevo) | Lee/escribe `configs/local.conf` | Nombre y email de git, hostname opcional; con `--auto` y sin TTY usa lo guardado |
| `01-system.sh` | Base | Repos Debian (deb822 y clásico), sin `Install-Recommends false`, arregla cdrom y `interfaces`, sudo, locales |
| `02-drivers.sh` (nuevo) | Firmware y hardware | Juego completo de firmware (`firmware-linux`, `-realtek`, `-iwlwifi`, `-atheros`, `-mediatek`, `-brcm80211`, `-intel-graphics`, `-intel-misc`, `-sof-signed`, `-amd-graphics`, `bluez-firmware`), microcode, `fwupd` (solo listar), sensores; al final lista dispositivos PCI/USB sin driver |
| `03-nvidia.sh` | GPU | Rama Debian: `cuda-keyring` → `nvidia-driver-pinning-610` → `cuda-drivers` + libs i386; GSP off; `NVreg_PreserveVideoMemoryAllocations=1`, `NVreg_TemporaryFilePath=/var/tmp`; `nvidia-drm modeset=1 fbdev=1`; Secure Boot: importa la MOK y avisa; fuente y rama configurables (`NVIDIA_SOURCE=nvidia-repo|debian`, `NVIDIA_BRANCH=610`, `NVIDIA_FLAVOR=proprietary|open`). La rama Ubuntu queda como está |
| `04-desktop.sh` (nuevo) | Escritorio | Si no hay Plasma, instala `kde-plasma-desktop` + SDDM + NetworkManager; siempre: sesión X11 de respaldo (`kwin-x11`), PipeWire, Bluetooth, portales, miniaturas, códecs (`libavcodec-extra`, gstreamer), fuentes, exFAT/NTFS, firewall `ufw` (deny entrante), español |
| `05-docker.sh` | Docker CE | Portainer en `127.0.0.1`; toolkit NVIDIA desde el mismo repo de NVIDIA |
| `06-dev.sh` | Desarrollo | nvm + Node 26 LTS + pnpm; Codex y Gemini por npm (Claude no); VS Code, Chrome, Orca, Flatpak; herramientas de base de datos (`postgresql-client`, `redis-tools`) |
| `07-zsh.sh` | Shell | `.zshrc` con `~/.zshrc.local`, alias `batcat`/`fdfind`, línea de ai-lordkit |
| `08-git.sh` | Git | Sin preguntas (usa `local.conf`), clave SSH automática, firma SSH |
| `09-apps.sh` | Apps | Igual que hoy |
| `10-optimize.sh` | Rendimiento | zram (`systemd-zram-generator`), `fstrim.timer`, `earlyoom`, inotify; **sin** desactivar servicios ni tocar red |
| `11-gaming.sh` | Gaming | Arreglo de `wine32:i386`; Steam, Lutris, MangoHud, GameMode, Heroic |
| `12-printing.sh` (nuevo) | Impresión | CUPS, `printer-driver-all`, `ipp-usb`, `sane-airscan`, `print-manager`, `skanlite` |
| `13-claude.sh` (nuevo) | ai-lordkit | Como el usuario, con nvm cargado: clona ai-lordkit en `~/.ai-lordkit` en un SHA fijo (`AI_LORDKIT_REF` en `packages.conf`) y corre `CLAUDE_YES=1 install.sh all`; revisa el log y reporta avisos |
| `90-verify.sh` | Verificación | Chequeos reales por módulo; el rc refleja fallos |
| `00-diagnostics.sh` | Diagnóstico | Igual, más la lista de dispositivos sin driver |
| `tools/pre-format.sh` (nuevo) | Antes de formatear | Se corre en el Kubuntu actual: guarda inventario de hardware (`lspci -nnk`, `lsusb`, discos) y lista qué respaldar (claves SSH/GPG, `.gitconfig`, perfiles, volúmenes Docker, `~/.claude`) |
| `docs/GUIA-INSTALACION.md` (nuevo) | Guía | ISO netinst, BIOS (UEFI, Secure Boot), qué marcar en el instalador, particionado guiado, primer arranque, el comando, pasos posteriores |

Orden de la instalación completa:
`01 → 02 → 03 (si hay NVIDIA) → 04 → 05 → 06 → 07 → 08 → 09 → 10 → 11 → 12 → 13 → 90`.

Los módulos se renumeran; `setup.sh` es el único lugar que conoce el orden.

## Flujo de datos y errores

- `configs/packages.conf`: listas y versiones (en git). `configs/local.conf`: datos
  personales (en `.gitignore`).
- Cada módulo sigue siendo idempotente y ejecutable suelto.
- Niveles de error como hoy (aviso / paso omitido / fatal). Fatal solo si falla el
  bootstrap, los repos base o el driver NVIDIA en una máquina sin otra GPU.
- Antes de reiniciar, `90-verify.sh` comprueba que el módulo NVIDIA se compiló con DKMS
  para el kernel instalado; si no, lo dice en rojo y **no** recomienda reiniciar a ciegas.

## Pruebas

1. `bash -n` y `shellcheck` sobre todos los scripts.
2. Validador (`tools/check-packages.sh`): extrae cada nombre de paquete de los módulos y
   lo comprueba contra los índices reales de Debian 13 y del repo de NVIDIA.
3. Ejecución real de los módulos en un chroot de Debian 13 (debootstrap) dentro de esta
   sesión: bootstrap sin sudo/curl, repos, firmware, simulación de la instalación de
   NVIDIA (`apt-get install -s`), escritorio, dev, zsh, git, apps, ai-lordkit.
4. Lo que no se puede probar aquí y se dirá claro: carga del módulo NVIDIA en la GTX 1660
   SUPER, suspensión, Wayland real, Wi-Fi/Bluetooth del equipo. Para eso queda
   `90-verify.sh` y la guía de qué hacer si falla (sesión X11, cambio de rama con un
   comando).

## Fuera de alcance

- Preseed / instalación desatendida de Debian.
- Tema visual de KDE.
- Virtualización (KVM).
- Arreglos de ai-lordkit y checklist de rendimiento: van como dos PR en el repo
  `ai-lordkit`, cada uno con su propio plan, después de terminar este instalador.

## Riesgo principal

No se pudo probar la rama 610 en una GTX 1660 SUPER. Mitigación: sesión X11 instalada,
`NVIDIA_BRANCH` configurable y un comando documentado para cambiar de rama o volver al
driver 550 de Debian desde una TTY.

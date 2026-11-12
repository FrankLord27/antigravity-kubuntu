# Auto Setup — Debian 13 (KDE)

Deja un Debian recién instalado listo para trabajar con un solo comando: drivers y firmware,
escritorio KDE, NVIDIA, Docker, stack de desarrollo, apps y Claude Code con
[ai-lordkit](https://github.com/FrankLord27/ai-lordkit). También funciona en Ubuntu.

**Guía completa, paso a paso: [docs/GUIA-INSTALACION.md](docs/GUIA-INSTALACION.md)**

## Resumen

1. **Antes de formatear**, en tu sistema actual: `bash tools/pre-format.sh` (dice qué respaldar
   y guarda el inventario de hardware).
2. **Instala Debian 13** con la ISO netinst normal. Marca *KDE Plasma* y *Utilidades estándar*.
   Secure Boot desactivado.
3. **Abre una terminal y pega:**

   ```bash
   wget -qO- https://raw.githubusercontent.com/FrankLord27/antigravity-kubuntu/main/install.sh | bash
   ```

   Pide tu contraseña y tu nombre y email para git. No pregunta nada más.
4. **Reinicia** y haz los inicios de sesión: `claude`, `gh auth login`, `codex login`, `gemini`.

## Qué instala

| # | Módulo | Qué hace |
| --- | --- | --- |
| 1 | Sistema base | Repos `contrib`/`non-free`, actualización, herramientas, `sudo`, parches de seguridad automáticos |
| 2 | Drivers y firmware | Firmware completo (Wi-Fi, Bluetooth, red, audio, video), microcode, headers. Avisa de dispositivos sin driver |
| 3 | NVIDIA | Solo si hay GPU NVIDIA. Debian: repo oficial de NVIDIA, rama 610 propietaria. Ubuntu: rama 580 |
| 4 | Escritorio | KDE si falta, sesión X11 de respaldo, audio, Bluetooth, códecs, fuentes, firewall |
| 5 | Docker | Docker CE + Compose + Portainer |
| 6 | Desarrollo | nvm + Node 26 + pnpm, VS Code, Chrome, Codex, Gemini, Orca, Flatpak |
| 7 | Terminal | zsh + Oh My Zsh + Powerlevel10k |
| 8 | Git | Identidad, alias, clave SSH, firma de commits, GitHub CLI |
| 9 | Apps | GIMP, OBS, Krita, Blender, Thunderbird, VLC, AnyDesk, TeamViewer, Discord… |
| 10 | Rendimiento | zram, earlyoom, TRIM, inotify |
| 11 | Gaming | Steam, Lutris, Wine, MangoHud, GameMode |
| 12 | Impresión | CUPS, drivers, escaneo |
| 13 | Claude | Claude Code + ai-lordkit |
| 14 | Tema Arcade Tokyo | Escritorio retro de 8 bits: fondo animado, dock con zoom, HUD de CPU/RAM/red, iconos y cursor pixel art, sonidos chiptune, pantalla de arranque y login (SDDM). Ver [theme/README.md](theme/README.md) |
| 90 | Verificación | Revisa todo y dice qué falta |

Las listas de programas y las versiones están en `configs/packages.conf`; las opciones del tema, en `configs/theme.conf`.

## Uso manual

```bash
sudo bash setup.sh                # menú
sudo bash setup.sh --auto         # todo, sin menú
sudo bash modules/06-dev.sh       # un módulo suelto
```

Cada módulo salta lo que ya está instalado; se puede repetir. Log: `/var/log/auto-setup/`.

## Estructura

```
antigravity-kubuntu/
├── install.sh              # bootstrap de un comando (funciona sin sudo, curl ni git)
├── setup.sh                # menú y orquestador
├── configs/packages.conf   # listas de paquetes, versiones y driver NVIDIA
├── lib/                    # ui.sh (salida y log), detect.sh (hardware), config.sh (tus datos)
├── modules/                # un archivo por módulo (00 diagnóstico … 90 verificación)
├── theme/                  # tema Arcade Tokyo: widget, generadores y aplicar.sh
├── tools/pre-format.sh     # qué respaldar antes de formatear
└── docs/GUIA-INSTALACION.md
```

## Lo que NO debes hacer

```bash
sudo bash NVIDIA-Linux-x86_64-*.run   # rompe apt y DKMS
sudo snap install docker               # choca con Docker CE
```

## Autor

Frank Felix

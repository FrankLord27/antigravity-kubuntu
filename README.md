# Auto Setup — Debian 13 / Ubuntu 26.04 (KDE)

Script que deja una instalación limpia de **Debian** (o Ubuntu) con todos mis programas de desarrollo listos, con un solo comando. Detecta el hardware: si no hay GPU NVIDIA, no instala nada de NVIDIA.

## Instalación tras formatear

Abre una terminal y pega:

```bash
curl -fsSL https://raw.githubusercontent.com/FrankLord27/antigravity-kubuntu/main/install.sh | bash
```

Pide la contraseña de `sudo` una vez e instala todo sin preguntas. Al final, reinicia.

> **Antes de instalar Debian:** descarga la ISO **netinst con firmware incluido** (`debian-13.x-amd64-netinst.iso` de la carpeta `firmware/`). Sin ella, el Wi-Fi Intel de la laptop no funciona al arrancar y el comando de arriba no tiene internet.

> **Repo privado:** el comando `curl` solo funciona si el repo es público. Si lo mantienes privado, usa:
>
> ```bash
> sudo apt install -y git gh && gh auth login && gh repo clone FrankLord27/antigravity-kubuntu ~/antigravity-kubuntu && sudo bash ~/antigravity-kubuntu/setup.sh --auto
> ```

## Qué instala la instalación completa

| #   | Módulo       | Qué hace                                                                                                                                                   |
| --- | ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Sistema base | `apt full-upgrade`, repos `contrib/non-free` (Debian) o `universe/multiverse` (Ubuntu), firmware Wi-Fi/Bluetooth, microcode                                |
| 2   | NVIDIA       | **Solo si hay GPU NVIDIA.** Debian: `nvidia-driver` (non-free). Ubuntu: rama 580                                                                           |
| 3   | Docker CE    | Repo oficial de Docker para la distro + Portainer. GPU en contenedores solo si hay NVIDIA                                                                  |
| 4   | Desarrollo   | **nvm + Node 26 + pnpm (corepack)**, VS Code, Google Chrome, **Claude Code + Codex CLI + Gemini CLI**, **Orca** (gestor de agentes de IA), Flatpak/Flathub |
| 10  | Git          | Identidad, aliases, clave SSH ed25519, GitHub CLI, firma de commits                                                                                        |
| 8   | ZSH          | Oh My Zsh + Powerlevel10k + plugins + fuente MesloLGS NF + perfil de Konsole                                                                               |
| 12  | Apps         | gimp, obs-studio, krita, blender, thunderbird, discord, fritzing, librepcb, samba, remmina, vlc, mpv, AnyDesk, TeamViewer, Element (flatpak)…              |
| 7   | Verificación | Reporte final y Health Score                                                                                                                               |

Las listas de apps se editan en `configs/packages.conf`.

## Módulos opcionales (solo desde el menú)

No entran en la instalación automática. Se ejecutan a mano con `sudo bash setup.sh` y eligiendo el número:

| #   | Módulo       | Qué hace                                                              |
| --- | ------------ | --------------------------------------------------------------------- |
| 5   | Gaming       | Steam, Lutris, Wine (WineHQ), Vulkan, MangoHud, GameMode, ProtonUp-Qt |
| 6   | Optimización | sysctl, ZRAM, TRIM, PipeWire, Bluetooth, Timeshift, fuentes extra     |
| 0   | Diagnóstico  | Hardware, drivers, logs de arranque, Health Score                     |

## Después de instalar

1. `sudo reboot`
2. Login de los agentes de IA (una sola vez): `claude`, `codex login`, `gemini`
3. Abre **Orca** desde el menú de aplicaciones y añade tus proyectos. Orca detecta los tres agentes y permite darle una tarea grande a uno para que la reparta entre los demás.
4. `gh auth login` y sube la clave SSH que muestra el módulo 10.

## Uso manual

```bash
sudo bash setup.sh          # menú interactivo
sudo bash setup.sh --auto   # instalación completa sin preguntas
sudo bash modules/04-dev.sh # un módulo suelto
```

Cada módulo detecta lo que ya está instalado y lo omite; es seguro repetirlo.

Log de cada ejecución: `/var/log/auto-setup/YYYY-MM-DD_HH-MM-SS.log`

## Estructura

```
antigravity-kubuntu/
├── install.sh            # bootstrap de un comando (clona + ejecuta setup.sh --auto)
├── setup.sh              # menú y orquestador
├── configs/packages.conf # listas de paquetes y versiones (Node, nvm, apps)
├── lib/
│   ├── ui.sh             # colores, log, run_cmd
│   └── detect.sh         # distro, hardware, NVIDIA, reglas de armonía
└── modules/
    ├── 00-diagnostics.sh
    ├── 01-system.sh
    ├── 02-nvidia.sh
    ├── 03-docker.sh
    ├── 04-dev.sh
    ├── 05-gaming.sh          (opcional)
    ├── 06-system-optimize.sh (opcional)
    ├── 07-verify.sh
    ├── 08-zsh.sh
    ├── 10-git.sh
    └── 12-apps.sh
```

## Lo que ya no hace

- **Tema de KDE** (paneles, iconos, decoración): se eliminó. Se reconstruye a mano tras instalar Debian.
- **Snaps**: nada se instala por snap. Lo que no está en apt va por Flatpak.
- **Ajustes del sistema** (ZRAM, sysctl, servicios): ya no son automáticos. Debian viene bien por defecto; el módulo 6 queda por si se quiere.

## Lo que NO debes hacer

```bash
sudo bash NVIDIA-Linux-x86_64-*.run   # rompe apt y DKMS
sudo snap install docker               # conflicto con Docker CE
```

## Autor

Frank Felix

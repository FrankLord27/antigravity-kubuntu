# ANTIGRAVITY Bootstrap — Kubuntu 26.04 LTS

Script de configuración automatizada para **Kubuntu 26.04 LTS** orientado a estaciones de trabajo con GPU NVIDIA, desarrollo de software, IA y gaming.

```bash
git clone git@github.com:FrankLord27/antigravity-kubuntu.git
cd antigravity-kubuntu
sudo bash antigravity.sh
```

---

## Requisitos

| Componente  | Mínimo                                          |
| ----------- | ----------------------------------------------- |
| OS          | Kubuntu / Ubuntu 26.04 LTS                      |
| GPU         | NVIDIA Turing o superior (GTX 1660+, RTX 20xx+) |
| RAM         | 8 GB                                            |
| Disco libre | 20 GB                                           |
| Internet    | Requerido                                       |

> Probado en: **GTX 1660 SUPER · i5-10400F · 16 GB RAM · Kubuntu 26.04 LTS**

---

## Módulos

| #   | Módulo                  | Qué instala / configura                                                          |
| --- | ----------------------- | -------------------------------------------------------------------------------- |
| 0   | Diagnóstico del sistema | Hardware, drivers, logs de arranque, Health Score 0–100                          |
| 1   | Sistema base            | `apt upgrade`, firmware, microcode Intel/AMD, sanitización de PPAs               |
| 2   | Driver NVIDIA           | Driver 580-open (producción estable Turing), DKMS, Wayland                       |
| 3   | Docker CE               | Docker Engine oficial + NVIDIA Container Toolkit (GPU en contenedores)           |
| 4   | Stack de desarrollo     | Node.js LTS (fnm), pnpm, VS Code, Google Chrome, Zsh                             |
| 5   | Gaming                  | Steam, Lutris, Wine, Vulkan, MangoHud, GameMode, ProtonUp-Qt                     |
| 6   | Optimización            | ZRAM swap, TRIM SSD, PipeWire audio, Bluetooth, Timeshift backups                |
| 7   | Verificación final      | Reporte completo del sistema, Health Score, próximos pasos                       |
| 8   | ZSH + Powerlevel10k     | Oh My Zsh, tema Powerlevel10k, plugins autosuggestions/syntax                    |
| 9   | KDE macOS Look          | Paneles, dock flotante, botones izquierda, modo oscuro GTK, español              |
| 10  | Git Setup               | Identidad interactiva, aliases, clave SSH ed25519 para GitHub/GitLab             |
| 11  | Desktop Snapshot        | Backup/restore 1:1 del escritorio real (temas, paneles, fuentes, Konsole)        |
| 12  | Apps personales         | gimp, obs, gh, AnyDesk, TeamViewer + snaps (discord, krita, blender…) + flatpaks |

### Instalación completa recomendada

La opción `[A]` ejecuta los módulos en este orden:

```
1 → 2 → 3 → 4 → 10 → 5 → 6 → 8 → 9 → 11 → 12 → 7
```

Cada módulo detecta si ya está instalado y omite los pasos completados — es seguro volver a ejecutar cualquier módulo.

---

## Estructura

```
antigravity-kubuntu/
├── antigravity.sh          # Entrada principal, TUI numérico, orquestador
├── lib/
│   ├── ui.sh               # Colores, íconos, funciones de UI (ui_ok, ui_warn, run_cmd…)
│   └── detect.sh           # Detección de hardware, driver y 20 reglas de armonía
└── modules/
    ├── 00-diagnostics.sh   # Diagnóstico completo + Health Score
    ├── 01-system.sh        # Sistema base
    ├── 02-nvidia.sh        # Driver NVIDIA 580-open
    ├── 03-docker.sh        # Docker CE + NVIDIA Container Toolkit
    ├── 04-dev.sh           # Stack desarrollo
    ├── 05-gaming.sh        # Gaming
    ├── 06-optimize.sh      # Optimización del sistema
    ├── 07-verify.sh        # Verificación final
    ├── 08-zsh.sh           # ZSH + Powerlevel10k
    ├── 09-kde-macos.sh     # KDE tema macOS
    ├── 10-git.sh           # Git Setup completo
    ├── 11-desktop.sh       # Desktop Snapshot (backup/restore visual)
    └── 12-apps.sh          # Apps personales (apt/snap/flatpak)
```

---

## Desktop Snapshot (módulo 11)

`configs/desktop/` contiene la copia REAL del escritorio (12 MB): kdeglobals,
kwinrc, paneles (appletsrc), decoración Aurorae Utterly-Round-Dark, fuentes
de usuario (MesloLGS NF) y perfil de Konsole.

- **En la PC configurada:** ejecutar el módulo 11 → backup → commit + push.
- **Tras formatear:** clonar el repo → módulo 11 → restore (la instalación
  completa `[A]` restaura automáticamente).
- Papirus y el wallpaper "Path" se reinstalan por apt (muy pesados para git).
- Los iconos Fluent/Mkos-Big-Sur (KDE Store, 326 MB) NO se respaldan — ver
  `configs/desktop/manifest.txt`.

---

## Decisiones técnicas clave

### NVIDIA: rama 580, variante proprietary + GSP off (NO 595)

La serie 595 mantiene regresiones en Turing (verificado 2026-07: clocks de
boost capados, pantallas negras y parpadeos en juegos, stutter en KDE Wayland).
La rama 580 sigue siendo la estable — último punto: 580.173.02.

**Variante proprietary en vez de open (cambio 2026-07-02):** el driver open
fuerza el firmware GSP, que tiene stutter conocido en Turing con KDE Plasma
(open-gpu-kernel-modules #777/#693: tirones al salir de idle hasta que la GPU
sube de clocks). El proprietary permite `NVreg_EnableGpuFirmware=0`
(`/etc/modprobe.d/nvidia-gsp.conf`), única vía documentada de eliminarlo.
Configurable en `configs/packages.conf` (`NVIDIA_DRIVER_VARIANT`,
`NVIDIA_DISABLE_GSP`) — con Secure Boot activo, valora volver a `open`.

### Wayland exclusivo

Kubuntu 26.04 eliminó X11. El script no instala ni configura X11.

### Suspensión: 3 capas

1. `nvidia-suspend/resume/hibernate.service`
2. `NVreg_PreserveVideoMemoryAllocations=1`
3. `NVreg_TemporaryFilePath=/var/tmp`

### NTSYNC

Kernel 7.0 lo incluye nativamente — mejora gaming con Proton sin configuración extra.

---

## Sistema de errores

| Nivel       | Comportamiento                    |
| ----------- | --------------------------------- |
| 1 — WARNING | Registra y continúa               |
| 2 — ERROR   | Salta el paso, continúa el módulo |
| 3 — FATAL   | Guarda log y aborta               |

Log de cada ejecución: `/var/log/antigravity/YYYY-MM-DD_HH-MM-SS.log`

---

## Lo que NO debes hacer

```bash
sudo bash NVIDIA-Linux-x86_64-*.run   # rompe apt y DKMS
sudo ubuntu-drivers autoinstall        # puede instalar 595 en Turing
sudo snap install docker               # GPU no disponible en snap
```

---

## Autor

Frank Felix — Kubuntu 26.04 LTS · GTX 1660 SUPER · i5-10400F

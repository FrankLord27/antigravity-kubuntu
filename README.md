# ANTIGRAVITY BOOTSTRAP — Kubuntu Edition

Sistema de post-instalación para **Kubuntu 26.04 LTS**.  
**GTX 1660 SUPER · i5-10400F · Docker + IA · Gaming · Dev**

---

## Inicio rápido

```bash
unzip antigravity-kubuntu.zip
cd antigravity-kubuntu
chmod +x antigravity.sh modules/*.sh
sudo bash antigravity.sh
```

---

## Estructura

```
antigravity-kubuntu/
├── antigravity.sh                  ← Entrada principal (TUI)
├── modules/
│   ├── 00-diagnostics.sh           ← Diagnóstico + Health Score 0-100
│   ├── 01-system.sh                ← apt + firmware + microcode Intel
│   ├── 02-nvidia.sh                ← Driver NVIDIA 580-open
│   ├── 03-docker.sh                ← Docker CE + NVIDIA Container Toolkit
│   ├── 04-dev.sh                   ← Node + pnpm + VS Code + Chrome + Zsh
│   ├── 05-gaming.sh                ← Steam + Lutris + Vulkan + MangoHud
│   ├── 06-system-optimize.sh       ← ZRAM + TRIM + PipeWire + Timeshift
│   ├── 07-verify.sh                ← Verificación final + Health Score
│   └── 08-zsh-kde.sh               ← ZSH + Powerlevel10k + KDE macOS look
├── lib/
│   ├── ui.sh                       ← TUI: colores, paneles, errores
│   └── detect.sh                   ← Detección hardware + 20 reglas armonía
├── configs/
│   └── packages.conf               ← Versiones y paquetes editables
└── README.md
```

---

## Módulos

| # | Módulo | Qué hace |
|---|--------|----------|
| 0 | Diagnóstico | Health Score 0-100, logs arranque, 20 reglas de armonía |
| 1 | Sistema base | apt optimizado, updates, firmware fwupd, microcode Intel |
| 2 | NVIDIA | 580-open, Wayland, CUDA 12.8, suspensión, NTSYNC, sin X11 |
| 3 | Docker | Docker CE oficial (no snap), NVIDIA Container Toolkit |
| 4 | Dev stack | Node.js LTS (fnm), pnpm, VS Code, Chrome, Git, Zsh |
| 5 | Gaming | Steam, Lutris, Wine, MangoHud, GameMode, ProtonUp-Qt |
| 6 | Optimización | ZRAM, TRIM SSD, PipeWire, Bluetooth, Timeshift |
| 7 | Verificación | Reporte completo, Health Score final, próximos pasos |
| 8 | ZSH + KDE | Powerlevel10k, MesloLGS NF, KDE look macOS, español |

---

## Decisiones técnicas clave

### NVIDIA: 580-open (NO 595)
Serie 595 tiene regresiones en Turing: parpadeos Wayland, cursor invisible Steam, pantalla negra suspensión.

### CUDA: 12.8 (NO 13.x)
Compatible con 580, estable para Ollama + Open WebUI + Docker GPU.

### Wayland exclusivo
Kubuntu 26.04 eliminó X11. El script no instala ni configura X11.

### Suspensión: 3 capas
1. `nvidia-suspend/resume/hibernate.service`
2. `NVreg_PreserveVideoMemoryAllocations=1`
3. `NVreg_TemporaryFilePath=/var/tmp`

### NTSYNC
Kernel 7.0 lo incluye nativamente. Mejora gaming con Proton.

---

## Sistema de errores

| Nivel | Tipo | Comportamiento |
|-------|------|----------------|
| 1 | WARNING | Registra y continúa |
| 2 | ERROR | Salta el paso, continúa el módulo |
| 3 | FATAL | Guarda log y aborta |

Log: `/var/log/antigravity/YYYY-MM-DD_HH-MM-SS.log`

---

## Módulos independientes

```bash
sudo bash modules/00-diagnostics.sh   # diagnóstico
sudo bash modules/02-nvidia.sh        # solo NVIDIA
sudo bash modules/07-verify.sh        # solo verificación
sudo bash modules/08-zsh-kde.sh       # solo ZSH + KDE
```

---

## Particiones recomendadas

| Partición | Tamaño | Formato | Flag |
|-----------|--------|---------|------|
| /boot/efi | 1 GB | FAT32 | arranque |
| /boot | 2 GB | EXT4 | — |
| / | 80 GB | EXT4 | raíz |
| swap | 16 GB | swap | intercambio |
| /home | ~144 GB | EXT4 | — |

---

## Lo que NO debes hacer

```bash
sudo bash NVIDIA-Linux-x86_64-*.run   # rompe apt y DKMS
sudo ubuntu-drivers autoinstall        # puede instalar 595 en Turing
sudo snap install docker               # GPU no disponible, conflicto con CE
```

---

## Autor

Frank Felix Rodríguez — antigravity  
Kubuntu 26.04 LTS · GTX 1660 SUPER · i5-10400F

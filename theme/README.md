# Tema Arcade Tokyo (módulo 14)

Escritorio KDE Plasma 6 con estética retro de 8 bits y colores Tokyo Night.

## Qué incluye

| Parte | Qué es |
| --- | --- |
| Fondo animado | Batalla espacial en perspectiva (video de 30 s en bucle, generado con `gen/video.py`) |
| Barra superior | Paginador, menú global del programa activo, reloj en fuente pixel y bandeja del sistema |
| Dock | Widget propio: iconos con zoom, nave que sigue al ratón y dispara al hacer clic, menú contextual por programa. Cada pantalla muestra solo sus ventanas |
| HUD de escritorio | El mismo widget puesto sobre el escritorio: CPU, GPU, RAM, visualizador de audio, clima y reloj |
| Apariencia | Esquema de colores, iconos Pixelitos ampliados sin suavizado, cursor pixel art, marcos de doble línea neón y botones de ventana propios |
| Sonidos | 35 sonidos chiptune sintetizados: ventanas, notificaciones y eventos del sistema |
| Terminal | Colores, fuente pixel con símbolos Nerd Font, sin barras de botones y cartel con el estado del equipo |
| Arranque | Pantalla de Plymouth con marcianos y barra de progreso |

## Instalar

```bash
sudo bash modules/14-theme.sh
```

También entra en la instalación completa (`setup.sh --auto`). Para dejarlo fuera, pon
`INSTALL_THEME=false` en `configs/theme.conf`; ahí están además la ciudad del clima y los
interruptores de paneles, sonidos, visualizador y pantalla de arranque.

Si se ejecuta sin una sesión de Plasma abierta, los archivos se instalan igual y el tema se
activa solo en el siguiente inicio de sesión.

## Cómo funciona

- `modules/14-theme.sh` (root): instala paquetes, copia esta carpeta a
  `~/.local/share/arcade-tokyo/src`, lanza `aplicar.sh` como tu usuario y, para la pantalla de
  arranque, la genera en un directorio temporal de root y la instala con `instalar_arranque.sh`
  (nada de lo que corre como root sale de la carpeta personal).
- `aplicar.sh archivos`: descarga lo de terceros en una versión fijada, genera video, iconos,
  cursores, sonidos y esquemas, e instala el widget y el script de KWin. No necesita sesión.
- `aplicar.sh sesion`: activa colores, iconos, cursor, estilo, efectos y decoración, y crea
  los paneles con `paneles.js`. Si el dock arcade ya existe, no toca los paneles.

Nada pesado está en el repo: el video, los sonidos y los iconos ampliados se generan al instalar.

## De terceros

Se descargan fijados en `configs/theme.conf` (tag o SHA, y suma SHA-256 en las fuentes):

- [Smart Video Wallpaper Reborn](https://github.com/luisbocanegra/plasma-smart-video-wallpaper-reborn) — plugin de fondo de video.
- [Pixelitos](https://github.com/ItzSelenux/pixelitos-icon-theme) — iconos pixel art.
- Press Start 2P (Google Fonts) y Departure Mono Nerd Font — fuentes.
- La definición de interfaz de Konsole de su misma versión, para guardarla sin las barras de botones.

El clima sale de [open-meteo.com](https://open-meteo.com), sin cuenta ni clave.

## Límites conocidos

- Probado en Debian 13 con Plasma 6.3 sobre Wayland y GPU NVIDIA. La creación de paneles en
  una instalación limpia y la pantalla de arranque no se han probado todavía en una máquina real.
- El medidor de GPU lee el sensor `gpu/gpu0`; sin ese sensor marca 0 %.
- El zoom del dock llega hasta el alto del panel: Plasma no deja que un widget se salga de él.
- Chrome y otras apps que no son de KDE no siguen el estilo de los marcos ni de los botones.

## Deshacer

- Paneles: antes de crearlos se guarda una copia en
  `~/.local/share/arcade-tokyo/appletsrc.antes-del-tema`.
- Pantalla de arranque: `sudo bash theme/instalar_arranque.sh --quitar` (desde el repo).
- Lo demás se cambia desde Preferencias del sistema (colores, iconos, cursores, estilo de
  Plasma, decoración de ventanas, guiones de KWin).

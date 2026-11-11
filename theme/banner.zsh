# Cartel de la terminal: estado real del equipo con estilo arcade.
# Se carga con `source` desde ~/.zshrc; solo lee /proc y llama a df, para no retrasar el prompt.
() {
  emulate -L zsh
  local rs=$'\e[0m' cy=$'\e[38;2;125;207;255m' pu=$'\e[38;2;187;154;247m' gr=$'\e[38;2;158;206;106m'
  local ye=$'\e[38;2;224;175;104m' pk=$'\e[38;2;247;118;142m' mu=$'\e[38;2;86;95;137m' fg=$'\e[38;2;192;202;245m'

  # barra de 10 bloques: verde, amarilla o rosa según el porcentaje
  local REPLY
  bar() {
    local -i pct=$1 n i
    (( pct < 0 )) && pct=0
    (( pct > 100 )) && pct=100
    n=$(( (pct + 9) / 10 ))
    local col=$gr
    (( pct >= 60 )) && col=$ye
    (( pct >= 85 )) && col=$pk
    REPLY=$col
    for (( i = 0; i < 10; i++ )); do
      (( i == n )) && REPLY+=$mu
      REPLY+="■"
    done
    REPLY+=$rs
  }

  # tiempo encendido
  local -i up=${$(</proc/uptime)[1]%.*}
  local uptxt="$(( up / 3600 ))h $(( up % 3600 / 60 ))m"
  (( up >= 86400 )) && uptxt="$(( up / 86400 ))d $(( up % 86400 / 3600 ))h"

  # carga de CPU (media de 1 min) respecto al número de núcleos
  local load=${$(</proc/loadavg)[1]}
  local -i cores=${#${(M)${(f)"$(</proc/cpuinfo)"}:#processor*}}
  (( cores < 1 )) && cores=1
  local -i cpu_pct=$(( load * 100 / cores ))

  # memoria
  local line; local -i mem_total=0 mem_avail=0
  for line in ${(f)"$(</proc/meminfo)"}; do
    case $line in
      MemTotal:*) mem_total=${${=line}[2]} ;;
      MemAvailable:*) mem_avail=${${=line}[2]} ;;
    esac
  done
  (( mem_total < 1 )) && mem_total=1
  local -i mem_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
  local mem_txt; printf -v mem_txt '%.1f/%.1f GiB' $(( (mem_total - mem_avail) / 1048576.0 )) $(( mem_total / 1048576.0 ))

  # disco raíz
  local -a d=( ${=${(f)"$(df -k --output=size,avail / 2>/dev/null)"}[2]} )
  local -i disk_pct=0; local disk_txt="?"
  if (( ${#d} == 2 && d[1] > 0 )); then
    disk_pct=$(( (d[1] - d[2]) * 100 / d[1] ))
    printf -v disk_txt '%d GiB libres' $(( d[2] / 1048576 ))
  fi

  # dos poses del marciano, para que mueva las patas
  local -a spr1=( "  ▀▄   ▄▀  " " ▄█▀███▀█▄ " "█▀███████▀█" "▀ ▀▄▄ ▄▄▀ ▀" )
  local -a spr2=( "▄ ▀▄   ▄▀ ▄" "█▄█▀███▀█▄█" "▀█████████▀" " ▄▀     ▀▄ " )

  # Animación de ~0,5 s: las barras se llenan y el marciano alterna de pose.
  # Solo en una terminal real; si la salida va a un archivo se dibuja un único cuadro.
  local -i steps=1 k i
  if [[ -t 1 ]] && zmodload zsh/zselect 2>/dev/null; then
    steps=8
  fi
  # La animación se dibuja en la pantalla alternativa de la terminal y el cuadro final en la
  # normal. Redibujar encima con «subir cursor» dejaba líneas repetidas en el historial cuando
  # la ventana aún se estaba abriendo y cambiaba de tamaño.
  local -a spr info
  (( steps > 1 )) && print -n $'\e[?1049h\e[?25l'
  for (( k = 1; k <= steps; k++ )); do
    info=( "${cy}${USER}@${HOST}${rs}  ${mu}encendido ${fg}${uptxt}${rs}" )
    bar $(( cpu_pct * k / steps ));  info+="${pu}CPU  ${rs} ${REPLY} ${fg}carga ${load}${mu} / ${cores} núcleos${rs}"
    bar $(( mem_pct * k / steps ));  info+="${pu}RAM  ${rs} ${REPLY} ${fg}${mem_txt}${rs}"
    bar $(( disk_pct * k / steps )); info+="${pu}DISCO${rs} ${REPLY} ${fg}${disk_txt}${rs}"
    if (( k < steps && k % 2 )); then spr=( $spr2 ); else spr=( $spr1 ); fi
    if (( k == steps && steps > 1 )); then
      print -n $'\e[?1049l\e[?25h'                   # vuelve a la pantalla normal para el cuadro final
    elif (( steps > 1 )); then
      print -n $'\e[H'                               # esquina superior: cada cuadro pisa al anterior
    fi
    print
    for (( i = 1; i <= 4; i++ )); do
      print -r -- "  ${pu}${spr[i]}${rs}   ${info[i]}"$'\e[K'
    done
    (( k < steps )) && zselect -t 6                  # 60 ms entre cuadros
  done
  unfunction bar
  print
}

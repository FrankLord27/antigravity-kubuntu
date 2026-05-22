#!/usr/bin/env bash
# =============================================================================
#  KUBUNTU AUTO SETUP — lib/ui.sh  [Kubuntu 26.04 LTS]
#  Sistema de errores:
#    Nivel 1 = WARNING  → registra y continúa automáticamente
#    Nivel 2 = ERROR    → registra, salta el paso, continúa el módulo
#    Nivel 3 = FATAL    → guarda log completo y aborta todo
# =============================================================================
export C_RED='\033[0;31m' C_GREEN='\033[0;32m' C_YELLOW='\033[1;33m'
export C_CYAN='\033[0;36m' C_BLUE='\033[0;34m' C_MAGENTA='\033[0;35m'
export C_WHITE='\033[1;37m' C_GRAY='\033[0;90m' C_BOLD='\033[1m'
export C_DIM='\033[2m' C_RESET='\033[0m'
export ICON_OK="✓" ICON_FAIL="✗" ICON_WARN="⚠" ICON_INFO="●"
export ICON_RUN="▶" ICON_SKIP="○" ICON_FATAL="☠"
export AG_OK_COUNT=0 AG_ERROR_COUNT=0 AG_WARN_COUNT=0 AG_SKIP_COUNT=0
export AG_LOG_DIR="/var/log/kubuntu-auto-setup"
export AG_LOG_FILE="${AG_LOG_DIR}/$(date '+%Y-%m-%d_%H-%M-%S').log"

ui_log_init() {
    mkdir -p "$AG_LOG_DIR"
    cat > "$AG_LOG_FILE" << EOF
# KUBUNTU AUTO SETUP BOOTSTRAP — LOG [Kubuntu 26.04 LTS]
# Fecha    : $(date '+%Y-%m-%d %H:%M:%S')
# Kernel   : $(uname -r)
# Ubuntu   : $(source /etc/os-release 2>/dev/null && echo "$VERSION_ID - $VERSION_CODENAME")
# Usuario  : ${SUDO_USER:-$USER}
# Host     : $(hostname)
EOF
    echo -e "  ${C_DIM}Log: ${AG_LOG_FILE}${C_RESET}"
}

_log() { printf "[%s] [%-5s] %s\n" "$(date '+%H:%M:%S')" "$1" "${*:2}" >> "$AG_LOG_FILE"; }

ui_ok()   { echo -e "${C_GREEN}${C_BOLD}  ${ICON_OK}  ${C_RESET}${C_GREEN}$*${C_RESET}"; _log "OK" "$*"; (( AG_OK_COUNT++ )) || true; }
ui_fail() { echo -e "${C_RED}${C_BOLD}  ${ICON_FAIL}  ${C_RESET}${C_RED}$*${C_RESET}"; _log "ERR" "$*"; (( AG_ERROR_COUNT++ )) || true; }
ui_warn() { echo -e "${C_YELLOW}${C_BOLD}  ${ICON_WARN}  ${C_RESET}${C_YELLOW}$*${C_RESET}"; _log "WARN" "$*"; (( AG_WARN_COUNT++ )) || true; }
ui_info() { echo -e "${C_CYAN}  ${ICON_INFO}  ${C_RESET}$*"; _log "INFO" "$*"; }
ui_run()  { echo -e "${C_MAGENTA}${C_BOLD}  ${ICON_RUN}  ${C_RESET}${C_DIM}$*${C_RESET}"; _log "RUN" "$*"; }
ui_skip() { echo -e "${C_GRAY}  ${ICON_SKIP}  $* ${C_DIM}(ya instalado — omitido)${C_RESET}"; _log "SKIP" "$*"; (( AG_SKIP_COUNT++ )) || true; }

ui_step() {
    local line; line=$(printf '─%.0s' {1..56})
    echo ""; echo -e "${C_BLUE}${C_BOLD}  ┌${line}┐${C_RESET}"
    printf "${C_BLUE}${C_BOLD}  │  %-54s│${C_RESET}\n" "$*"
    echo -e "${C_BLUE}${C_BOLD}  └${line}┘${C_RESET}"; echo ""
    _log "STEP" "$*"
}

ui_banner() {
    clear; echo ""
    echo -e "${C_CYAN}${C_BOLD}"
    echo "   ╔══════════════════════════════════════════════════════════╗"
    echo "   ║        A N T I G R A V I T Y   B O O T S T R A P       ║"
    echo "   ║                  [ Kubuntu Edition ]                    ║"
    echo "   ║   Kubuntu 26.04 LTS  •  GTX 1660 SUPER  •  i5-10400F  ║"
    echo "   ╚══════════════════════════════════════════════════════════╝"
    echo -e "${C_RESET}"
    echo -e "${C_GRAY}   $(date '+%A %d %b %Y')  •  $(date '+%H:%M')  •  Kernel: $(uname -r)${C_RESET}"; echo ""
}

ui_progress() {
    local current="$1" total="$2" label="${3:-}" width=38
    local pct=$(( current * 100 / total ))
    local filled=$(( current * width / total )) empty=$(( width - filled ))
    local bar; bar="$(printf '█%.0s' $(seq 1 "$filled") 2>/dev/null)$(printf '░%.0s' $(seq 1 "$empty") 2>/dev/null)"
    printf "\r  ${C_CYAN}[%s]${C_RESET} ${C_WHITE}%3d%%${C_RESET}  ${C_DIM}%-30s${C_RESET}" "$bar" "$pct" "$label"
    [[ "$current" -eq "$total" ]] && echo ""
}

ui_panel_start() {
    local title="${1:-Procesando...}"
    local pad=$(( 55 - ${#title} ))
    [[ $pad -lt 1 ]] && pad=1
    echo ""; printf "${C_BOLD}  ┌─ %s %s┐${C_RESET}\n" "$title" "$(printf '─%.0s' $(seq 1 $pad))"
}

ui_panel_end() { echo -e "  └$(printf '─%.0s' {1..58})┘"; echo ""; }

run_cmd() {
    local level="$1"; shift; local desc="$1"; shift
    local cmd_output exit_code=0
    ui_run "$desc"
    cmd_output=$("$@" 2>&1) || exit_code=$?
    { echo "  ┌─ CMD: $*"; echo "  │  EXIT: $exit_code"
      echo "$cmd_output" | sed 's/^/  │  /'; echo "  └─────────────"; echo ""; } >> "$AG_LOG_FILE"
    if [[ $exit_code -eq 0 ]]; then ui_ok "$desc"; return 0; fi
    local short_err; short_err=$(echo "$cmd_output" | grep -iE 'error|fail|fatal|denied|unable|cannot' | tail -2 || echo "$cmd_output" | tail -2)
    case "$level" in
        1) ui_warn "$desc (no crítico — continuando)"; [[ -n "$short_err" ]] && echo -e "      ${C_DIM}${short_err}${C_RESET}" ;;
        2) ui_fail "$desc — paso omitido"; [[ -n "$short_err" ]] && echo -e "      ${C_DIM}${short_err}${C_RESET}"; ui_warn "Detalle: $AG_LOG_FILE" ;;
        3) echo ""; echo -e "${C_RED}${C_BOLD}  ${ICON_FATAL}  ERROR FATAL — $desc${C_RESET}"
           echo -e "${C_RED}$(echo "$cmd_output" | tail -5 | sed 's/^/  /')${C_RESET}"
           echo -e "${C_YELLOW}  Log: ${C_BOLD}${AG_LOG_FILE}${C_RESET}"; _log "FATAL" "$desc — EXIT $exit_code"; exit 1 ;;
    esac
    return $exit_code
}

silent_cmd() { "$@" &>/dev/null; return $?; }

ui_confirm() {
    local prompt="${1:-¿Continuar?}"
    echo -ne "  ${C_YELLOW}${ICON_WARN}  ${prompt} [s/N]: ${C_RESET}"; read -r ans
    [[ "$ans" =~ ^[sS]$ ]]
}

ui_pause() { echo -e "\n  ${C_DIM}Presiona ENTER para continuar...${C_RESET}"; read -r; }

ui_summary() {
    local line; line=$(printf '═%.0s' {1..56})
    echo ""; echo -e "${C_BOLD}  ╔${line}╗${C_RESET}"
    printf "${C_BOLD}  ║${C_RESET}  %-54s${C_BOLD}║${C_RESET}\n" "RESUMEN DE LA SESIÓN"
    echo -e "${C_BOLD}  ╠${line}╣${C_RESET}"
    printf "  ║  ${C_GREEN}${ICON_OK}  OK        : %-4s${C_RESET}%-34s${C_BOLD}║${C_RESET}\n" "$AG_OK_COUNT" ""
    printf "  ║  ${C_YELLOW}${ICON_WARN}  Warnings  : %-4s${C_RESET}%-34s${C_BOLD}║${C_RESET}\n" "$AG_WARN_COUNT" ""
    printf "  ║  ${C_GRAY}${ICON_SKIP}  Omitidos  : %-4s${C_RESET}%-34s${C_BOLD}║${C_RESET}\n" "$AG_SKIP_COUNT" ""
    printf "  ║  ${C_RED}${ICON_FAIL}  Errores   : %-4s${C_RESET}%-34s${C_BOLD}║${C_RESET}\n" "$AG_ERROR_COUNT" ""
    echo -e "${C_BOLD}  ╠${line}╣${C_RESET}"
    printf "  ║  Log: %-50s║\n" "${AG_LOG_FILE}"
    echo -e "${C_BOLD}  ╚${line}╝${C_RESET}"; echo ""
}

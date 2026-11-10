#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — Entrada principal  [Debian 13 / Ubuntu 26.04]
#  Uso:  sudo bash setup.sh            → menú interactivo
#        sudo bash setup.sh --auto     → instalación completa sin preguntas
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

export GUM_AVAILABLE=true
export DEBIAN_FRONTEND=noninteractive
AUTO_MODE=false
[[ "${1:-}" == "--auto" ]] && AUTO_MODE=true

_preflight() {
    [[ $EUID -ne 0 ]] && { echo ""; echo "  ERROR: sudo bash setup.sh"; echo ""; exit 1; }
    ping -c 1 -W 3 1.1.1.1 &>/dev/null || { echo ""; echo "  ERROR: Sin internet."; echo ""; exit 1; }
    detect_distro
    if [[ "$DETECT_DISTRO" == "otra" ]]; then
        echo "  ADVERTENCIA: Este script está pensado para Debian o Ubuntu."
        $AUTO_MODE && exit 1
        echo -ne "  ¿Continuar? [s/N]: "; read -r ans; [[ "$ans" =~ ^[sS]$ ]] || exit 0
    fi
    command -v apt &>/dev/null || { echo "  ERROR: apt no encontrado."; exit 1; }
}

_ensure_gum() {
    $AUTO_MODE && { GUM_AVAILABLE=false; return 0; }
    command -v gum &>/dev/null && return 0
    echo -e "\n${C_CYAN}  Instalando gum (menú)...${C_RESET}"
    local tmp; tmp=$(mktemp -d)
    curl -sL "https://github.com/charmbracelet/gum/releases/download/v0.14.1/gum_0.14.1_Linux_x86_64.tar.gz" \
        -o "${tmp}/gum.tar.gz" 2>/dev/null && tar -xzf "${tmp}/gum.tar.gz" -C "$tmp" 2>/dev/null \
        && install -m 755 "${tmp}/gum" /usr/local/bin/gum 2>/dev/null; rm -rf "$tmp"
    command -v gum &>/dev/null || { echo -e "${C_YELLOW}  gum no disponible — modo numérico${C_RESET}"; GUM_AVAILABLE=false; }
}

declare -A MODULE_NAME=(
    [0]="Diagnóstico del sistema"
    [1]="Sistema base (apt + repos + firmware + microcode)"
    [2]="Driver NVIDIA (solo si hay GPU NVIDIA)"
    [3]="Docker CE (+ GPU si hay NVIDIA)"
    [4]="Desarrollo (Node 26 + pnpm + VS Code + Chrome + IA + Orca)"
    [5]="Gaming (Steam + Lutris + Vulkan + MangoHud) — opcional"
    [6]="Optimización del sistema (ZRAM, sysctl, servicios) — opcional"
    [7]="Verificación final del sistema"
    [8]="ZSH + Powerlevel10k"
    [10]="Git Setup (identidad + SSH + gh)"
    [12]="Apps personales (apt + flatpak)"
)
MODULE_IDS=(0 1 2 3 4 5 6 7 8 10 12)

declare -A MODULE_FILE=(
    [0]="${SCRIPT_DIR}/modules/00-diagnostics.sh"
    [1]="${SCRIPT_DIR}/modules/01-system.sh"
    [2]="${SCRIPT_DIR}/modules/02-nvidia.sh"
    [3]="${SCRIPT_DIR}/modules/03-docker.sh"
    [4]="${SCRIPT_DIR}/modules/04-dev.sh"
    [5]="${SCRIPT_DIR}/modules/05-gaming.sh"
    [6]="${SCRIPT_DIR}/modules/06-system-optimize.sh"
    [7]="${SCRIPT_DIR}/modules/07-verify.sh"
    [8]="${SCRIPT_DIR}/modules/08-zsh.sh"
    [10]="${SCRIPT_DIR}/modules/10-git.sh"
    [12]="${SCRIPT_DIR}/modules/12-apps.sh"
)

declare -A MODULE_FUNC=(
    [0]="run_diagnostics"
    [1]="run_module_system"
    [2]="run_module_nvidia"
    [3]="run_module_docker"
    [4]="run_module_dev"
    [5]="run_module_gaming"
    [6]="run_module_optimize"
    [7]="run_module_verify"
    [8]="run_module_zsh"
    [10]="run_module_git"
    [12]="run_module_apps"
)

# Instalación completa: solo programas. Sin gaming (5) ni ajustes del sistema (6).
# NVIDIA (2) se añade solo si se detecta GPU NVIDIA.
_full_install_order() {
    local order=(1)
    has_nvidia && order+=(2)
    order+=(3 4 10 8 12 7)
    echo "${order[@]}"
}

_module_status() {
    local real_home; real_home=$(eval echo "~${SUDO_USER:-$USER}")
    case "$1" in
        0) echo "diagnóstico" ;;
        1) is_deb_installed build-essential && echo "OK" || echo "pendiente" ;;
        2) has_nvidia || { echo "no aplica"; return; }
           lsmod 2>/dev/null | grep -q '^nvidia ' && echo "OK" || echo "pendiente" ;;
        3) is_service_active docker && echo "OK" || echo "pendiente" ;;
        4) [[ -s "${real_home}/.nvm/nvm.sh" ]] && echo "OK" || echo "pendiente" ;;
        5) { is_deb_installed steam-installer || is_deb_installed steam; } && echo "OK" || echo "pendiente" ;;
        6) [[ -f /etc/sysctl.d/99-auto-setup.conf ]] && echo "OK" || echo "pendiente" ;;
        7) echo "verificar" ;;
        8) [[ -d "${real_home}/.oh-my-zsh" ]] && echo "OK" || echo "pendiente" ;;
        10) local gn; gn=$(sudo -u "${SUDO_USER:-$USER}" git config --global user.name 2>/dev/null || echo "")
            [[ -n "$gn" ]] && echo "OK" || echo "pendiente" ;;
        12) is_deb_installed gimp && echo "OK" || echo "pendiente" ;;
    esac
}

_run_module() {
    local file="${MODULE_FILE[$1]}" func="${MODULE_FUNC[$1]}"
    [[ ! -f "$file" ]] && { ui_fail "Módulo no encontrado: $file"; return 1; }
    # shellcheck disable=SC1090
    source "$file"
    declare -f "$func" > /dev/null 2>&1 || { ui_fail "Función $func no encontrada"; return 1; }
    "$func"
}

_execute_module_flow() {
    local idx="$1"
    echo ""; ui_info "Módulo [${idx}] ${MODULE_NAME[$idx]}"; echo ""
    ui_confirm "¿Ejecutar módulo ${idx}?" || return
    echo ""; _run_module "$idx"; echo ""; ui_summary; ui_pause
}

_execute_full_install() {
    local order; read -ra order <<< "$(_full_install_order)"
    echo ""; ui_step "INSTALACIÓN COMPLETA — ${DETECT_DISTRO^} ${DETECT_OS_VER}"; echo ""
    echo -e "  Módulos en orden:"
    for idx in "${order[@]}"; do echo -e "    ${C_CYAN}[${idx}]${C_RESET} ${MODULE_NAME[$idx]}"; done; echo ""
    if ! $AUTO_MODE; then
        if $GUM_AVAILABLE; then
            gum confirm "¿Iniciar instalación completa?" --affirmative="Sí" --negative="Cancelar" < /dev/tty 2>/dev/null || return
        else ui_confirm "¿Iniciar instalación completa?" || return; fi
    fi
    echo ""; local total="${#order[@]}" current=0
    for idx in "${order[@]}"; do
        (( current++ )) || true
        ui_progress "$current" "$total" "${MODULE_NAME[$idx]}"; echo ""
        ui_step "[$current/$total] ${MODULE_NAME[$idx]}"
        _run_module "$idx" || ui_warn "Módulo $idx terminó con errores — continuando"
        echo ""
    done
    ui_ok "Instalación completa finalizada"; ui_summary
    $AUTO_MODE || ui_pause
}

_tui_gum() {
    while true; do
        ui_banner
        local options=()
        for i in "${MODULE_IDS[@]}"; do
            options+=("[${i}] ${MODULE_NAME[$i]}  ($(_module_status "$i"))")
        done
        options+=("────────────────────────────────────────────────")
        options+=("[A] Instalación completa (programas, sin gaming ni optimización)")
        options+=("[M] Seleccionar módulos (multi-select)")
        options+=("[Q] Salir")
        local selected
        selected=$(gum choose --cursor="  ▶ " --height=18 \
            --header="  AUTO SETUP — ${DETECT_DISTRO^} ${DETECT_OS_VER}  •  ↑↓ ENTER para seleccionar" \
            "${options[@]}" < /dev/tty 2>/dev/tty) || true
        if [[ -z "$selected" ]]; then
            ui_warn "gum no responde — cambiando a modo numérico"; _tui_numeric; return
        fi
        local choice; choice=$(echo "$selected" | grep -oP '^\[(\w+)\]' | tr -d '[]')
        case "${choice,,}" in
            [0-9]|1[02]) _execute_module_flow "$choice" ;;
            a) _execute_full_install ;;
            m) _tui_multiselect ;;
            q) break ;;
        esac
    done
}

_tui_multiselect() {
    ui_banner
    echo -e "${C_BOLD}  ESPACIO = marcar  •  ENTER = confirmar${C_RESET}"; echo ""
    local options=()
    for i in "${MODULE_IDS[@]}"; do options+=("[${i}] ${MODULE_NAME[$i]}"); done
    local selected_raw
    selected_raw=$(gum choose --no-limit \
            --selected-prefix="  ● " --unselected-prefix="  ○ " \
            --cursor="  ▶ " --height=14 \
            --header="  Selecciona módulos (ESPACIO = marcar, ENTER = confirmar)" \
            "${options[@]}" < /dev/tty 2>/dev/tty)
    [[ -z "$selected_raw" ]] && return
    local selected_indices=()
    while IFS= read -r line; do
        local idx; idx=$(echo "$line" | grep -oP '^\[(\d+)\]' | tr -d '[]')
        [[ -n "$idx" ]] && selected_indices+=("$idx")
    done <<< "$selected_raw"
    [[ ${#selected_indices[@]} -eq 0 ]] && { ui_warn "Nada seleccionado"; return; }
    echo ""; ui_info "Módulos: ${selected_indices[*]}"; echo ""
    gum confirm "¿Ejecutar ${#selected_indices[@]} módulo(s)?" --affirmative="Sí" --negative="Cancelar" < /dev/tty 2>/dev/null || return
    local total="${#selected_indices[@]}" current=0
    for idx in "${selected_indices[@]}"; do
        (( current++ )) || true
        ui_progress "$current" "$total" "${MODULE_NAME[$idx]}"; echo ""
        _run_module "$idx"
    done
    echo ""; ui_ok "Módulos completados"; ui_summary; ui_pause
}

_tui_numeric() {
    while true; do
        ui_banner
        echo -e "${C_BOLD}  MÓDULOS DISPONIBLES${C_RESET}"; echo ""
        for i in "${MODULE_IDS[@]}"; do
            local st; st=$(_module_status "$i")
            local sc="$C_GRAY" si=" "
            [[ "$st" == "OK" ]] && sc="$C_GREEN" && si="$ICON_OK"
            printf "  ${C_CYAN}[%-2s]${C_RESET}  %-58s ${sc}%s (%s)${C_RESET}\n" "$i" "${MODULE_NAME[$i]}" "$si" "$st"
        done
        echo ""; echo -e "  ${C_CYAN}[A] ${C_RESET}  Instalación completa (programas, sin gaming ni optimización)"
        echo -e "  ${C_CYAN}[Q] ${C_RESET}  Salir"; echo ""
        echo -ne "  ${C_BOLD}Selecciona opción: ${C_RESET}"; read -r choice
        case "${choice,,}" in
            [0-9]|1[02]) _execute_module_flow "$choice" ;;
            a) _execute_full_install ;;
            q) echo ""; ui_info "Saliendo..."; break ;;
            *) ui_warn "Opción inválida: '$choice'"; sleep 1 ;;
        esac
    done
}

main() {
    _preflight; _ensure_gum; ui_log_init

    ui_banner; ui_info "Detectando hardware y estado del sistema..."
    detect_all; echo ""
    echo -e "  ${C_DIM}Distro : ${DETECT_DISTRO^} ${DETECT_OS_VER} (${DETECT_OS_CODENAME}) | Kernel: ${DETECT_KERNEL}${C_RESET}"
    echo -e "  ${C_DIM}CPU    : ${DETECT_CPU}${C_RESET}"
    echo -e "  ${C_DIM}GPU    : ${DETECT_GPU} (${DETECT_GPU_ARCH}) | NVIDIA: ${DETECT_HAS_NVIDIA}${C_RESET}"
    echo -e "  ${C_DIM}Docker : ${DETECT_DOCKER_RUNNING} | Node: ${DETECT_NODE_VER} | pnpm: ${DETECT_PNPM_VER}${C_RESET}"
    echo ""

    if $AUTO_MODE; then
        _execute_full_install
    elif $GUM_AVAILABLE && command -v gum &>/dev/null; then
        sleep 2; _tui_gum
    else
        sleep 2; _tui_numeric
    fi

    echo ""; ui_ok "Auto Setup finalizado."
    echo -e "  ${C_DIM}Log: ${AG_LOG_FILE}${C_RESET}"; echo ""
    $AUTO_MODE && ui_warn "Reinicia el equipo para aplicar todo: sudo reboot"
}

main "$@"

#!/usr/bin/env bash
# =============================================================================
#  ANTIGRAVITY BOOTSTRAP — Entrada Principal [Kubuntu 26.04 LTS]
#  GTX 1660 SUPER • i5-10400F • Docker + IA • Gaming • Dev
#  Uso: sudo bash antigravity.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

export GUM_AVAILABLE=true
export DEBIAN_FRONTEND=noninteractive

_preflight() {
    [[ $EUID -ne 0 ]] && { echo ""; echo "  ERROR: sudo bash antigravity.sh"; echo ""; exit 1; }
    ping -c 1 -W 3 8.8.8.8 &>/dev/null || { echo ""; echo "  ERROR: Sin internet."; echo ""; exit 1; }
    source /etc/os-release 2>/dev/null
    [[ "$ID" != "ubuntu" ]] && [[ "$ID_LIKE" != *"ubuntu"* ]] && {
        echo "  ADVERTENCIA: Optimizado para Kubuntu/Ubuntu."
        echo -ne "  ¿Continuar? [s/N]: "; read -r ans; [[ "$ans" =~ ^[sS]$ ]] || exit 0
    }
    command -v apt &>/dev/null || { echo "  ERROR: apt no encontrado."; exit 1; }
}

_ensure_gum() {
    command -v gum &>/dev/null && return 0
    echo -e "\n${C_CYAN}  Instalando gum (TUI)...${C_RESET}"
    if curl -fsSL https://repo.charm.sh/apt/gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/charm.gpg &>/dev/null 2>&1; then
        echo "deb [signed-by=/usr/share/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
            > /etc/apt/sources.list.d/charm.list
        apt update -qq &>/dev/null && apt install -y gum &>/dev/null && return 0
    fi
    local tmp; tmp=$(mktemp -d)
    curl -sL "https://github.com/charmbracelet/gum/releases/download/v0.14.1/gum_0.14.1_Linux_x86_64.tar.gz" \
        -o "${tmp}/gum.tar.gz" 2>/dev/null && tar -xzf "${tmp}/gum.tar.gz" -C "$tmp" 2>/dev/null \
        && install -m 755 "${tmp}/gum" /usr/local/bin/gum 2>/dev/null && rm -rf "$tmp"
    command -v gum &>/dev/null || { echo -e "${C_YELLOW}  gum no disponible — modo numérico${C_RESET}"; GUM_AVAILABLE=false; }
}

declare -A MODULE_NAME=(
    [0]="Diagnóstico del sistema"
    [1]="Sistema base (apt + firmware + microcode)"
    [2]="Driver NVIDIA 580-open (producción estable Turing)"
    [3]="Docker CE + NVIDIA Container Toolkit"
    [4]="Stack de desarrollo (Node + pnpm + VS Code + Chrome + Zsh)"
    [5]="Gaming (Steam + Lutris + Vulkan + MangoHud)"
    [6]="Optimización (ZRAM + TRIM + PipeWire + Timeshift)"
    [7]="Verificación final del sistema"
    [8]="ZSH + Powerlevel10k"
    [9]="KDE macOS Look + Idioma Español"
)

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
    [9]="${SCRIPT_DIR}/modules/09-kde-macos.sh"
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
    [9]="run_module_kde_macos"
)

FULL_INSTALL_ORDER=(1 2 3 4 5 6 8 9 7)

_module_status() {
    local real_home; real_home=$(eval echo "~${SUDO_USER:-$USER}")
    case "$1" in
        0) echo "diagnóstico" ;;
        1) is_deb_installed build-essential && echo "OK" || echo "pendiente" ;;
        2) lsmod 2>/dev/null | grep -q '^nvidia ' && echo "OK" || echo "pendiente" ;;
        3) is_service_active docker && echo "OK" || echo "pendiente" ;;
        4) [[ -d "${real_home}/.local/share/fnm" ]] && echo "OK" || echo "pendiente" ;;
        5) { is_deb_installed steam-installer || is_deb_installed steam; } && echo "OK" || echo "pendiente" ;;
        6) [[ -f /etc/sysctl.d/99-antigravity.conf ]] && echo "OK" || echo "pendiente" ;;
        7) echo "verificar" ;;
        8) [[ -d "${real_home}/.oh-my-zsh" ]] && echo "OK" || echo "pendiente" ;;
        9) [[ -f "${real_home}/.config/plasma-localerc" ]] && grep -q "es_ES" "${real_home}/.config/plasma-localerc" 2>/dev/null && echo "OK" || echo "pendiente" ;;
    esac
}

_run_module() {
    local idx="$1" file="${MODULE_FILE[$1]}" func="${MODULE_FUNC[$1]}"
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
    echo ""; ui_step "INSTALACIÓN COMPLETA — KUBUNTU 26.04 LTS"; echo ""
    echo -e "  Módulos en orden:"; for idx in "${FULL_INSTALL_ORDER[@]}"; do
        echo -e "    ${C_CYAN}[${idx}]${C_RESET} ${MODULE_NAME[$idx]}"
    done; echo ""
    if $GUM_AVAILABLE; then
        gum confirm "¿Iniciar instalación completa?" --affirmative="Sí" --negative="Cancelar" < /dev/tty 2>/dev/null || return
    else ui_confirm "¿Iniciar instalación completa?" || return; fi
    echo ""; local total="${#FULL_INSTALL_ORDER[@]}" current=0
    for idx in "${FULL_INSTALL_ORDER[@]}"; do
        (( current++ )) || true
        ui_progress "$current" "$total" "${MODULE_NAME[$idx]}"; echo ""
        ui_step "[$current/$total] ${MODULE_NAME[$idx]}"
        _run_module "$idx" || ui_warn "Módulo $idx terminó con errores — continuando"
        echo ""
    done
    ui_ok "Instalación completa finalizada"; ui_summary; ui_pause
}

_tui_gum() {
    while true; do
        ui_banner
        local options=()
        for i in 0 1 2 3 4 5 6 7 8; do
            local st; st=$(_module_status "$i")
            options+=("[${i}] ${MODULE_NAME[$i]}  (${st})")
        done
        options+=("────────────────────────────────────")
        options+=("[A] Instalación completa recomendada")
        options+=("[Q] Salir")
        echo -e "${C_BOLD}  Navega con ↑↓ + ENTER:${C_RESET}"; echo ""
        local selected
        selected=$(gum choose --cursor="  ▶ " --height=16 \
            --header="  ANTIGRAVITY — Kubuntu 26.04 LTS" \
            "${options[@]}" < /dev/tty 2>/dev/null) || true
        if [[ -z "$selected" ]]; then
            ui_warn "gum no responde — cambiando a modo numérico"
            _tui_numeric; return
        fi
        local choice; choice=$(echo "$selected" | grep -oP '^\[(\w)\]' | tr -d '[]')
        case "${choice,,}" in
            [0-8]) _execute_module_flow "$choice" ;;
            a)     _execute_full_install ;;
            q)     break ;;
        esac
    done
}

_tui_multiselect() {
    ui_banner
    echo -e "${C_BOLD}  ESPACIO = marcar  •  ENTER = confirmar${C_RESET}"; echo ""
    local options=()
    for i in 0 1 2 3 4 5 6 7 8; do options+=("[${i}] ${MODULE_NAME[$i]}"); done
    local selected_raw
    selected_raw=$(gum choose --no-limit \
            --selected-prefix="  ● " --unselected-prefix="  ○ " \
            --cursor="  ▶ " --height=12 \
            --header="  Selecciona módulos" \
            "${options[@]}" < /dev/tty 2>/dev/null)
    [[ -z "$selected_raw" ]] && return
    local selected_indices=()
    while IFS= read -r line; do
        local idx; idx=$(echo "$line" | grep -oP '^\[(\d)\]' | tr -d '[]')
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
        for i in 0 1 2 3 4 5 6 7 8 9; do
            local st; st=$(_module_status "$i")
            local sc="$C_GRAY" si=" "
            [[ "$st" == "OK" ]] && sc="$C_GREEN" && si="$ICON_OK"
            printf "  ${C_CYAN}[%s]${C_RESET}  %-52s ${sc}%s (%s)${C_RESET}\n" \
                "$i" "${MODULE_NAME[$i]}" "$si" "$st"
        done
        echo ""; echo -e "  ${C_CYAN}[A]${C_RESET}  Instalación completa recomendada"
        echo -e "  ${C_CYAN}[Q]${C_RESET}  Salir"; echo ""
        echo -ne "  ${C_BOLD}Selecciona opción: ${C_RESET}"; read -r choice
        case "${choice,,}" in
            [0-9]) _execute_module_flow "$choice" ;;
            a)     _execute_full_install ;;
            q)     echo ""; ui_info "Saliendo..."; break ;;
            *)     ui_warn "Opción inválida: '$choice'"; sleep 1 ;;
        esac
    done
}

main() {
    _preflight; _ensure_gum; ui_log_init

    ui_banner; ui_info "Detectando hardware y estado del sistema..."
    detect_all; echo ""
    echo -e "  ${C_DIM}GPU    : ${DETECT_GPU} (${DETECT_GPU_ARCH})${C_RESET}"
    echo -e "  ${C_DIM}CPU    : ${DETECT_CPU}${C_RESET}"
    echo -e "  ${C_DIM}NVIDIA : ${DETECT_NVIDIA_DRIVER_VER} (${DETECT_NVIDIA_MODULE}) — Rama: ${DETECT_NVIDIA_BRANCH}${C_RESET}"
    echo -e "  ${C_DIM}Ubuntu : ${DETECT_UBUNTU_VER} ${DETECT_UBUNTU_CODENAME} | Kernel: ${DETECT_KERNEL}${C_RESET}"
    echo -e "  ${C_DIM}Docker : ${DETECT_DOCKER_RUNNING} | Node: ${DETECT_NODE_VER} | CUDA: ${DETECT_CUDA_VER}${C_RESET}"
    echo -e "  ${C_DIM}NTSYNC : ${DETECT_NTSYNC} | Suspensión: ${DETECT_SUSPEND_CONFIGURED} | VRAM: ${DETECT_VRAM_PRESERVE}${C_RESET}"
    echo ""; sleep 2

    _tui_numeric

    echo ""; ui_ok "Antigravity Bootstrap finalizado."
    echo -e "  ${C_DIM}Log: ${AG_LOG_FILE}${C_RESET}"; echo ""
}

main "$@"

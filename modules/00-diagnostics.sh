#!/usr/bin/env bash
# ANTIGRAVITY — modules/00-diagnostics.sh [Kubuntu 26.04 LTS]
# Diagnóstico: hardware, componentes, logs arranque, armonía, Health Score 0-100

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

run_diagnostics() {
    ui_step "DIAGNÓSTICO DEL SISTEMA — Kubuntu 26.04 LTS"
    ui_info "Analizando sistema..."; echo ""
    detect_all; detect_harmony
    _show_hardware; _show_component_status
    _show_log_analysis; _show_harmony_report; _show_health_score
}

_show_hardware() {
    echo -e "${C_BOLD}  ┌─ Hardware ─────────────────────────────────────────────────┐${C_RESET}"
    printf "  │  ${C_CYAN}%-22s${C_RESET} %-34s│\n" "GPU:"         "$DETECT_GPU"
    printf "  │  ${C_CYAN}%-22s${C_RESET} %-34s│\n" "GPU Arch:"    "$DETECT_GPU_ARCH"
    printf "  │  ${C_CYAN}%-22s${C_RESET} %-34s│\n" "CPU:"         "${DETECT_CPU:0:34}"
    printf "  │  ${C_CYAN}%-22s${C_RESET} %-34s│\n" "RAM:"         "${DETECT_RAM_GB} GB"
    printf "  │  ${C_CYAN}%-22s${C_RESET} %-34s│\n" "Kernel:"      "$DETECT_KERNEL"
    printf "  │  ${C_CYAN}%-22s${C_RESET} %-34s│\n" "Ubuntu:"      "$DETECT_UBUNTU_VER ($DETECT_UBUNTU_CODENAME)"
    printf "  │  ${C_CYAN}%-22s${C_RESET} %-34s│\n" "Filesystem:"  "$DETECT_DISK_FS"
    printf "  │  ${C_CYAN}%-22s${C_RESET} %-34s│\n" "Disco libre:" "${DETECT_DISK_FREE_GB} GB"
    printf "  │  ${C_CYAN}%-22s${C_RESET} %-34s│\n" "Sesión:"      "$DETECT_SESSION_TYPE"
    local sc="$C_GREEN"; [[ "$DETECT_SECURE_BOOT" == "enabled" ]] && sc="$C_RED"
    printf "  │  ${C_CYAN}%-22s${C_RESET} ${sc}%-34s${C_RESET}│\n" "Secure Boot:" "$DETECT_SECURE_BOOT"
    echo -e "  └$(printf '─%.0s' {1..60})┘"; echo ""
}

_show_component_status() {
    echo -e "${C_BOLD}  ┌─ Estado de Componentes ────────────────────────────────────┐${C_RESET}"
    local nc ni
    case "$DETECT_NVIDIA_MODULE" in
        loaded)  nc="$C_GREEN";  ni="$ICON_OK" ;;
        nouveau) nc="$C_YELLOW"; ni="$ICON_WARN" ;;
        *)       nc="$C_RED";    ni="$ICON_FAIL" ;;
    esac
    printf "  │  ${nc}${ni}${C_RESET}  %-24s ${nc}%-30s${C_RESET}│\n" "Driver NVIDIA:" "$DETECT_NVIDIA_DRIVER_VER ($DETECT_NVIDIA_MODULE)"
    printf "  │  ${C_CYAN}${ICON_INFO}${C_RESET}  %-24s ${C_DIM}%-30s${C_RESET}│\n" "Rama:" "$DETECT_NVIDIA_BRANCH"
    printf "  │  ${C_CYAN}${ICON_INFO}${C_RESET}  %-24s ${C_DIM}%-30s${C_RESET}│\n" "Variante -open:" "$DETECT_NVIDIA_IS_OPEN"
    printf "  │  ${C_CYAN}${ICON_INFO}${C_RESET}  %-24s ${C_DIM}%-30s${C_RESET}│\n" "Wayland:" "$DETECT_NVIDIA_WAYLAND_OK"
    local sc="$C_GREEN"; [[ "$DETECT_SUSPEND_CONFIGURED" == "no" ]] && sc="$C_RED"
    printf "  │  ${sc}${ICON_INFO}${C_RESET}  %-24s ${sc}%-30s${C_RESET}│\n" "Suspensión config:" "$DETECT_SUSPEND_CONFIGURED"
    local vc="$C_GREEN"; [[ "$DETECT_VRAM_PRESERVE" == "no" ]] && vc="$C_YELLOW"
    printf "  │  ${vc}${ICON_INFO}${C_RESET}  %-24s ${vc}%-30s${C_RESET}│\n" "VRAM preserve:" "$DETECT_VRAM_PRESERVE"
    printf "  │  ${C_CYAN}${ICON_INFO}${C_RESET}  %-24s ${C_DIM}%-30s${C_RESET}│\n" "NTSYNC:" "$DETECT_NTSYNC"
    printf "  │  ${C_CYAN}${ICON_INFO}${C_RESET}  %-24s ${C_DIM}%-30s${C_RESET}│\n" "CUDA:" "$DETECT_CUDA_VER"
    local dc="$C_GREEN"; [[ "$DETECT_DOCKER_RUNNING" == "no" ]] && dc="$C_RED"
    printf "  │  ${dc}${ICON_INFO}${C_RESET}  %-24s ${dc}%-30s${C_RESET}│\n" "Docker:" "$DETECT_DOCKER_RUNNING"
    printf "  │  ${C_CYAN}${ICON_INFO}${C_RESET}  %-24s ${C_DIM}%-30s${C_RESET}│\n" "Node.js:" "$DETECT_NODE_VER"
    printf "  │  ${C_CYAN}${ICON_INFO}${C_RESET}  %-24s ${C_DIM}%-30s${C_RESET}│\n" "pnpm:" "$DETECT_PNPM_VER"
    echo -e "  └$(printf '─%.0s' {1..60})┘"; echo ""
}

_show_log_analysis() {
    ui_step "ANÁLISIS DE LOGS DE ARRANQUE"
    ui_info "Analizando journalctl -b y dmesg..."

    local dmesg_errs dmesg_nv dmesg_fw dkms_j nv_j
    dmesg_errs=$(dmesg --level=err,crit,alert,emerg 2>/dev/null | tail -20)
    dmesg_nv=$(dmesg 2>/dev/null | grep -iE 'nvidia|nouveau|drm' | grep -iE 'error|fail|warn|unable' | tail -10)
    dmesg_fw=$(dmesg 2>/dev/null | grep -iE 'firmware|microcode|ACPI' | grep -iE 'error|fail|missing' | tail -10)
    dkms_j=$(journalctl -b --no-pager 2>/dev/null | grep -iE 'dkms' | tail -8)
    nv_j=$(journalctl -b --no-pager 2>/dev/null | grep -iE 'nvidia|nouveau|drm' | grep -iE 'error|fail|warn' | tail -10)

    _log_section "dmesg — Errores del Kernel" "$dmesg_errs"
    _log_section "dmesg — NVIDIA/DRM" "$dmesg_nv"
    _log_section "dmesg — Firmware/Microcode" "$dmesg_fw"
    _log_section "journalctl — DKMS este boot" "$dkms_j"
    _log_section "journalctl — Errores NVIDIA" "$nv_j"

    { echo "═══ LOGS ═══"
      echo "=dmesg errores="; echo "$dmesg_errs"
      echo "=dmesg nvidia="; echo "$dmesg_nv"
      echo "=firmware="; echo "$dmesg_fw"
      echo "=dkms="; echo "$dkms_j"
      echo "=nvidia journal="; echo "$nv_j"; } >> "$AG_LOG_FILE"
}

_log_section() {
    local label="$1" data="$2"
    local pad=$(( 46 - ${#label} ))
    echo -e "${C_BOLD}  ┌─ ${label} $(printf '─%.0s' $(seq 1 $pad))┐${C_RESET}"
    if [[ -z "$data" ]]; then
        printf "  │  ${C_GREEN}${ICON_OK}  Sin errores detectados${C_RESET}%-36s│\n" ""
    else
        echo "$data" | head -5 | while IFS= read -r l; do
            printf "  │  ${C_YELLOW}%-56s${C_RESET}│\n" "${l:0:56}"
        done
    fi
    echo -e "  └$(printf '─%.0s' {1..60})┘"; echo ""
}

_show_harmony_report() {
    echo -e "${C_BOLD}  ┌─ Armonía del Sistema ──────────────────────────────────────┐${C_RESET}"
    if [[ ${#HARMONY_ISSUES[@]} -eq 0 ]] && [[ ${#HARMONY_WARNINGS[@]} -eq 0 ]]; then
        printf "  │  ${C_GREEN}${ICON_OK}  Todos los componentes están alineados${C_RESET}%-20s│\n" ""
    else
        for i in "${HARMONY_ISSUES[@]}";   do printf "  │  ${C_RED}${ICON_FAIL}  %-54s│\n" "${i:0:54}"; done
        for w in "${HARMONY_WARNINGS[@]}"; do printf "  │  ${C_YELLOW}${ICON_WARN}  %-54s│\n" "${w:0:54}"; done
    fi
    echo -e "  └$(printf '─%.0s' {1..60})┘"; echo ""
}

_show_health_score() {
    local score; score=$(calculate_health_score)
    local color; color=$(score_color "$score")
    local label; label=$(score_label "$score")
    local filled=$(( score * 40 / 100 )) empty=$(( 40 - score * 40 / 100 ))
    local bar="${color}$(printf '█%.0s' $(seq 1 "$filled") 2>/dev/null)${C_GRAY}$(printf '░%.0s' $(seq 1 "$empty") 2>/dev/null)${C_RESET}"
    echo ""
    echo -e "${C_BOLD}  ╔══════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BOLD}  ║              HEALTH SCORE DEL SISTEMA               ║${C_RESET}"
    echo -e "${C_BOLD}  ╠══════════════════════════════════════════════════════╣${C_RESET}"
    printf  "  ║   %b  %b%3d%%%b  —  %b%-12s%b              ║\n" \
        "$bar" "$color$C_BOLD" "$score" "$C_RESET" "$color$C_BOLD" "$label" "$C_RESET"
    [[ ${#HARMONY_ISSUES[@]} -gt 0 ]]   && printf "  ║   ${C_RED}${ICON_FAIL}  %d problema(s) crítico(s)${C_RESET}%-27s║\n" "${#HARMONY_ISSUES[@]}" ""
    [[ ${#HARMONY_WARNINGS[@]} -gt 0 ]] && printf "  ║   ${C_YELLOW}${ICON_WARN}  %d advertencia(s)${C_RESET}%-35s║\n" "${#HARMONY_WARNINGS[@]}" ""
    echo -e "${C_BOLD}  ╚══════════════════════════════════════════════════════╝${C_RESET}"; echo ""
    _log "INFO" "Health Score: $score/100 — $label"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/00-diagnostics.sh" && exit 1
    ui_log_init; run_diagnostics; ui_summary
fi

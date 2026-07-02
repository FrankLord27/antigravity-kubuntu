#!/usr/bin/env bash
# KUBUNTU AUTO SETUP — modules/07-verify.sh [Kubuntu 26.04 LTS]
# Verificación completa post-instalación + Health Score final

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

run_module_verify() {
    ui_step "MÓDULO 07 — VERIFICACIÓN FINAL DEL SISTEMA"
    detect_all; detect_harmony
    _verify_nvidia; _verify_docker; _verify_dev; _verify_gaming
    _verify_system; _verify_harmony_final; _show_final_score; _show_next_steps
}

_verify_nvidia() {
    ui_step "Verificando NVIDIA — Driver 580-open / Wayland / Kubuntu 26.04"

    silent_cmd nvidia-smi && {
        local info; info=$(nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu --format=csv,noheader 2>/dev/null)
        ui_ok "nvidia-smi OK"; echo -e "  ${C_DIM}$info${C_RESET}"
        nvidia-smi 2>/dev/null >> "$AG_LOG_FILE" || true
    } || { ui_fail "nvidia-smi FALLA — driver no cargado"; ui_warn "journalctl -b | grep -i nvidia"; }

    local drv_ver; drv_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "")
    if [[ -n "$drv_ver" ]]; then
        local drv_major; drv_major=$(echo "$drv_ver" | cut -d. -f1)
        [[ "$drv_major" -ge 580 ]] && [[ "$drv_major" -lt 590 ]] \
            && ui_ok "Driver serie 580 confirmado ($drv_ver) — producción estable" \
            || { [[ "$drv_major" -ge 590 ]] \
                && ui_warn "Driver 595+ detectado ($drv_ver) — regresiones en Turing, considera degradar a 580" \
                || ui_warn "Driver $drv_ver — versión antigua, actualiza a 580-open"; }
    fi

    is_deb_installed "nvidia-driver-580-open" && ui_ok "Variante -open instalada (módulos kernel abiertos GSP)" \
        || ui_warn "Variante -open NO detectada — dpkg -l | grep nvidia-driver"

    local mods; mods=$(lsmod 2>/dev/null | grep '^nvidia' | awk '{print $1}' | tr '\n' ' ')
    [[ -n "$mods" ]] && ui_ok "Módulos NVIDIA: $mods" || ui_fail "Ningún módulo NVIDIA cargado — reinicia"

    lsmod 2>/dev/null | grep -q '^nouveau' \
        && ui_fail "nouveau ACTIVO — conflicto con driver propietario" \
        || ui_ok "nouveau correctamente desactivado"

    local ds; ds=$(dkms status 2>/dev/null | grep -i nvidia || echo "sin info")
    echo "$ds" | grep -qi 'installed' && ui_ok "DKMS NVIDIA: $ds" || ui_warn "DKMS: $ds"

    local session_type; session_type=$(loginctl show-session "$(loginctl list-sessions --no-legend 2>/dev/null | awk 'NR==1{print $1}')" -p Type --value 2>/dev/null || echo "")
    [[ -z "$session_type" ]] && session_type="${XDG_SESSION_TYPE:-}"
    [[ "$session_type" == "wayland" ]] \
        && ui_ok "Sesión Wayland activa — correcto para Kubuntu 26.04" \
        || ui_warn "Sesión: ${session_type:-desconocida} — Kubuntu 26.04 solo soporta Wayland"

    grep -q 'modeset=1' /etc/modprobe.d/nvidia-drm.conf 2>/dev/null \
        && ui_ok "nvidia-drm.modeset=1 via modprobe (correcto para kernel 7.0)" \
        || ui_warn "nvidia-drm.modeset no encontrado en modprobe.d"

    grep -q 'fbdev=1' /etc/modprobe.d/nvidia-drm.conf 2>/dev/null \
        && ui_ok "nvidia-drm.fbdev=1 activo — TTY funcional en Wayland" \
        || ui_warn "nvidia-drm.fbdev=1 no configurado"

    for svc in nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service; do
        is_service_enabled "$svc" && ui_ok "$svc habilitado" || ui_warn "$svc NO habilitado"
    done

    grep -q 'NVreg_PreserveVideoMemoryAllocations=1' /etc/modprobe.d/nvidia-power.conf 2>/dev/null \
        && ui_ok "Preservación de VRAM configurada" \
        || ui_warn "NVreg_PreserveVideoMemoryAllocations no configurado"

    { [[ -d /sys/module/ntsync ]] || lsmod 2>/dev/null | grep -q ntsync; } \
        && ui_ok "NTSYNC activo — gaming Proton optimizado" \
        || ui_info "NTSYNC no cargado — depende del kernel, no crítico"

    silent_cmd glxinfo && {
        local r; r=$(glxinfo 2>/dev/null | grep 'OpenGL renderer' | sed 's/.*: //')
        echo "$r" | grep -qi nvidia && ui_ok "OpenGL NVIDIA: $r" || ui_warn "OpenGL renderer: $r"
    } || ui_info "glxinfo no disponible (apt install mesa-utils) — no crítico en Wayland"

    silent_cmd vulkaninfo --summary && ui_ok "Vulkan OK" \
        || ui_warn "vulkaninfo no disponible — apt install vulkan-tools"

    if is_cmd_available nvcc; then
        ui_ok "CUDA: $(nvcc --version 2>/dev/null | grep 'release' | awk '{print $6}' | tr -d ',')"
    elif [[ -d /usr/local/cuda ]] || is_deb_installed cuda-toolkit-12-8; then
        ui_ok "CUDA toolkit instalado"
    else
        ui_info "CUDA toolkit no instalado — opcional, instala módulo 2 si usas GPU computing"
    fi
}

_verify_docker() {
    ui_step "Verificando Docker"
    is_service_active docker && ui_ok "Docker: $(docker --version 2>/dev/null)" \
        || { ui_fail "Docker no activo"; return; }
    silent_cmd docker compose version && ui_ok "Docker Compose OK" || ui_warn "Docker Compose no encontrado"
    local ru="${SUDO_USER:-$USER}"
    groups "$ru" 2>/dev/null | grep -q docker && ui_ok "Usuario '$ru' en grupo docker" \
        || ui_warn "'$ru' NO en grupo docker — cierra sesión y vuelve"
    is_deb_installed nvidia-container-toolkit && ui_ok "NVIDIA Container Toolkit instalado" \
        || ui_fail "NVIDIA Container Toolkit NO instalado — GPU no disponible en Docker"
}

_verify_dev() {
    ui_step "Verificando Stack de Desarrollo"
    local real_user="${SUDO_USER:-$USER}"
    local real_home; real_home=$(eval echo "~${real_user}")

    # Verificar node/pnpm desde el entorno del usuario real (fnm está en su home)
    local node_ver; node_ver=$(sudo -u "$real_user" bash -c '
        export HOME="'"$real_home"'"
        [[ -d "$HOME/.local/share/fnm" ]] && eval "$('"$real_home"'/.local/share/fnm/fnm env 2>/dev/null)" 2>/dev/null
        [[ -f "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh" 2>/dev/null
        node --version 2>/dev/null || echo "no"
    ' 2>/dev/null)
    [[ "$node_ver" != "no" && -n "$node_ver" ]] && ui_ok "Node.js: $node_ver" \
        || ui_fail "Node.js no encontrado — source ~/.bashrc"

    local pnpm_ver; pnpm_ver=$(sudo -u "$real_user" bash -c '
        export HOME="'"$real_home"'"
        [[ -d "$HOME/.local/share/fnm" ]] && eval "$('"$real_home"'/.local/share/fnm/fnm env 2>/dev/null)" 2>/dev/null
        [[ -f "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh" 2>/dev/null
        pnpm --version 2>/dev/null || echo "no"
    ' 2>/dev/null)
    [[ "$pnpm_ver" != "no" && -n "$pnpm_ver" ]] && ui_ok "pnpm: $pnpm_ver" \
        || ui_fail "pnpm no encontrado"

    is_cmd_available code && ui_ok "VS Code: $(code --version 2>/dev/null | head -1)" \
        || ui_warn "VS Code no en PATH — instala módulo 4"
    { is_cmd_available google-chrome || is_cmd_available google-chrome-stable; } \
        && ui_ok "Google Chrome instalado" || ui_warn "Chrome no encontrado — instala módulo 4"
    is_cmd_available git && ui_ok "$(git --version 2>/dev/null)" \
        || ui_fail "Git no encontrado — instala módulo 1"
    is_cmd_available zsh && ui_ok "Zsh: $(zsh --version 2>/dev/null | head -1)" \
        || ui_warn "Zsh no instalado — instala módulo 8"
    [[ -d "${real_home}/.oh-my-zsh" ]] && ui_ok "Oh My Zsh instalado" \
        || ui_warn "Oh My Zsh no encontrado — instala módulo 8"
    [[ -f "${real_home}/.p10k.zsh" ]] && ui_ok "Powerlevel10k configurado" \
        || ui_info ".p10k.zsh no encontrado — ejecuta 'p10k configure' en la terminal"

    # Git identity
    local gn; gn=$(sudo -u "$real_user" git config --global user.name  2>/dev/null || echo "")
    local ge; ge=$(sudo -u "$real_user" git config --global user.email 2>/dev/null || echo "")
    if [[ -n "$gn" ]] && [[ -n "$ge" ]]; then
        ui_ok "Git identidad: $gn <$ge>"
    else
        ui_warn "Git identidad no configurada — ejecuta módulo 10"
    fi
}

_verify_gaming() {
    ui_step "Verificando Gaming"
    { is_deb_installed steam-installer || is_deb_installed steam; } && ui_ok "Steam" || ui_warn "Steam no instalado"
    is_deb_installed lutris   && ui_ok "Lutris"   || ui_warn "Lutris no instalado"
    is_deb_installed mangohud && ui_ok "MangoHud" || ui_warn "MangoHud no instalado"
    is_deb_installed gamemode && ui_ok "GameMode" || ui_warn "GameMode no instalado"
    is_deb_installed ffmpeg   && ui_ok "FFmpeg"   || ui_warn "FFmpeg no instalado"
    flatpak list 2>/dev/null | grep -q 'pupgui2' && ui_ok "ProtonUp-Qt (Flatpak)" \
        || ui_info "ProtonUp-Qt no instalado — opcional, instala módulo 5"
}

_verify_system() {
    ui_step "Verificando Sistema"
    ui_ok "Kernel: $(uname -r)"
    local mc; mc=$(grep -m1 'microcode' /proc/cpuinfo 2>/dev/null | awk '{print $3}')
    [[ -n "$mc" ]] && ui_ok "Microcode Intel: $mc" || ui_warn "Microcode no detectado"

    local free_gb; free_gb=$(df -BG / 2>/dev/null | awk 'NR==2{gsub("G",""); print $4}')
    local disk_use; disk_use=$(df -h / 2>/dev/null | awk 'NR==2{print $3" de "$2" ("$5")"}')
    ui_info "Disco /: $disk_use"
    [[ "$free_gb" -lt 10 ]] && ui_warn "Poco espacio: ${free_gb}GB" || ui_ok "Espacio libre: ${free_gb}GB"

    local bf; bf=$(df -BM /boot 2>/dev/null | awk 'NR==2{gsub("M",""); print $4}')
    [[ -n "$bf" ]] && { [[ "$bf" -lt 200 ]] && ui_warn "/boot casi lleno (${bf}MB)" || ui_ok "/boot: ${bf}MB libre"; }

    is_deb_installed timeshift && ui_ok "Timeshift instalado" || ui_warn "Timeshift no instalado"
    [[ -b /dev/zram0 ]] && ui_ok "ZRAM activo" || ui_warn "ZRAM no activo"
    is_service_enabled fstrim.timer && ui_ok "TRIM SSD habilitado" || ui_warn "TRIM SSD no habilitado"

    silent_cmd nvidia-smi && {
        local t; t=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null)
        ui_info "Temperatura GPU: ${t}°C"
        [[ "$t" -gt 85 ]] && ui_warn "GPU temperatura alta (${t}°C)"
    }

    local kerr; kerr=$(journalctl -b -k -p err --no-pager 2>/dev/null | grep -vc '^--' || echo 0)
    [[ "$kerr" -eq 0 ]] && ui_ok "Sin errores del kernel en este arranque" \
        || { [[ "$kerr" -le 10 ]] && ui_ok "$kerr mensaje(s) del kernel (normal — hardware i2c/SGX)" \
        || ui_warn "$kerr error(s) del kernel — journalctl -b -k -p err"; }
}

_verify_harmony_final() {
    ui_step "Verificando Armonía del Sistema"
    [[ ${#HARMONY_ISSUES[@]} -eq 0 ]] && [[ ${#HARMONY_WARNINGS[@]} -eq 0 ]] \
        && { ui_ok "Todos los componentes correctamente alineados"; return; }
    for i in "${HARMONY_ISSUES[@]}";   do ui_fail "$i"; done
    for w in "${HARMONY_WARNINGS[@]}"; do ui_warn "$w"; done
}

_show_final_score() {
    local score; score=$(calculate_health_score)
    local color; color=$(score_color "$score")
    local label; label=$(score_label "$score")
    local filled=$(( score * 40 / 100 ))
    local empty=$(( 40 - score * 40 / 100 ))
    local bar; bar="${color}$(printf '█%.0s' $(seq 1 "$filled") 2>/dev/null)${C_GRAY}$(printf '░%.0s' $(seq 1 "$empty") 2>/dev/null)${C_RESET}"
    echo ""
    echo -e "${C_BOLD}  ╔══════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BOLD}  ║         HEALTH SCORE FINAL — KUBUNTU AUTO SETUP            ║${C_RESET}"
    echo -e "${C_BOLD}  ╠══════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "  ║  ${bar}"
    printf  "  ║  ${color}${C_BOLD}%-52s${C_RESET}║\n" "${score}%  —  ${label}"
    printf  "  ║  ${C_DIM}Issues: %-4s  Warnings: %-4s${C_RESET}%-24s║\n" \
        "${#HARMONY_ISSUES[@]}" "${#HARMONY_WARNINGS[@]}" ""
    echo -e "${C_BOLD}  ╚══════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    _log "INFO" "Score final: $score/100 ($label)"
}

_show_next_steps() {
    echo ""
    echo -e "${C_BOLD}  ┌─ PRÓXIMOS PASOS ──────────────────────────────────────┐${C_RESET}"
    echo -e "  │  ${C_WHITE}1.${C_RESET} Reinicia si instalaste NVIDIA: ${C_DIM}sudo reboot${C_RESET}        │"
    echo -e "  │  ${C_WHITE}2.${C_RESET} Configura Git (identidad + SSH):                  │"
    echo -e "  │     ${C_DIM}Ejecuta módulo [10] desde el menú principal${C_RESET}        │"
    echo -e "  │  ${C_WHITE}3.${C_RESET} Verifica NVIDIA: ${C_DIM}nvidia-smi && dkms status${C_RESET}       │"
    echo -e "  │  ${C_WHITE}4.${C_RESET} Verifica GPU Docker:                              │"
    echo -e "  │     ${C_DIM}docker run --rm --gpus all ubuntu nvidia-smi${C_RESET}       │"
    echo -e "  │  ${C_WHITE}5.${C_RESET} Configura Timeshift para snapshots               │"
    echo -e "  │  ${C_WHITE}6.${C_RESET} Instala Proton-GE con ProtonUp-Qt               │"
    echo -e "  │  ${C_WHITE}7.${C_RESET} Re-ejecuta diagnóstico: ${C_DIM}sudo bash modules/00-diagnostics.sh${C_RESET} │"
    printf  "  │  Log: ${C_DIM}%-51s${C_RESET}│\n" "$AG_LOG_FILE"
    echo -e "  └───────────────────────────────────────────────────────┘"; echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/07-verify.sh" && exit 1
    ui_log_init; run_module_verify
fi

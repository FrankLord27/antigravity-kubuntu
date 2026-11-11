#!/usr/bin/env bash
# AUTO SETUP — modules/90-verify.sh [Debian 13 / Ubuntu 26.04]
# Verificación completa post-instalación + Health Score final

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/modules/02-drivers.sh"

run_module_verify() {
    ui_step "VERIFICACIÓN FINAL DEL SISTEMA"
    detect_all; detect_harmony
    has_nvidia && _verify_nvidia
    _verify_desktop; _verify_docker; _verify_dev; _verify_gaming
    _verify_system; _verify_harmony_final; _show_final_score; _show_next_steps
}

_verify_nvidia() {
    ui_step "Verificando NVIDIA — Driver / Wayland"

    silent_cmd nvidia-smi && {
        local info; info=$(nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu --format=csv,noheader 2>/dev/null)
        ui_ok "nvidia-smi OK"; echo -e "  ${C_DIM}$info${C_RESET}"
        nvidia-smi 2>/dev/null >> "$AG_LOG_FILE" || true
    } || {
        if dkms status 2>/dev/null | grep -i nvidia | grep -qi installed; then
            ui_ok "Driver NVIDIA compilado por DKMS — se cargará al reiniciar"
        else
            ui_fail "El driver NVIDIA NO está compilado para este kernel — NO reinicies a ciegas"
            ui_warn "Mira: dkms status ; sudo bash modules/03-nvidia.sh ; guía: docs/GUIA-INSTALACION.md (sección NVIDIA)"
        fi
    }

    local drv_ver; drv_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "")
    if is_ubuntu && [[ -n "$drv_ver" ]]; then
        local drv_major; drv_major=$(echo "$drv_ver" | cut -d. -f1)
        [[ "$drv_major" -ge 580 ]] && [[ "$drv_major" -lt 590 ]] \
            && ui_ok "Driver serie 580 confirmado ($drv_ver) — producción estable" \
            || { [[ "$drv_major" -ge 590 ]] \
                && ui_warn "Driver 595+ detectado ($drv_ver) — regresiones en Turing, considera degradar a 580" \
                || ui_warn "Driver $drv_ver — versión antigua, actualiza a 580"; }
    elif [[ -n "$drv_ver" ]]; then
        ui_ok "Driver NVIDIA $drv_ver (paquete nvidia-driver de Debian)"
    fi

    local mods; mods=$(lsmod 2>/dev/null | grep '^nvidia' | awk '{print $1}' | tr '\n' ' ')
    [[ -n "$mods" ]] && ui_ok "Módulos NVIDIA: $mods" || ui_info "Módulos NVIDIA aún no cargados (normal antes de reiniciar)"

    lsmod 2>/dev/null | grep -q '^nouveau' \
        && ui_fail "nouveau ACTIVO — conflicto con driver propietario" \
        || ui_ok "nouveau correctamente desactivado"

    local ds; ds=$(dkms status 2>/dev/null | grep -i nvidia || echo "sin info")
    echo "$ds" | grep -qi 'installed' && ui_ok "DKMS NVIDIA: $ds" || ui_warn "DKMS: $ds"

    local session_type; session_type=$(loginctl show-session "$(loginctl list-sessions --no-legend 2>/dev/null | awk 'NR==1{print $1}')" -p Type --value 2>/dev/null || echo "")
    [[ -z "$session_type" ]] && session_type="${XDG_SESSION_TYPE:-}"
    [[ "$session_type" == "wayland" ]] \
        && ui_ok "Sesión Wayland activa" \
        || ui_warn "Sesión: ${session_type:-desconocida} — se recomienda Wayland"

    grep -q 'modeset=1' /etc/modprobe.d/nvidia-drm.conf 2>/dev/null \
        && ui_ok "nvidia-drm.modeset=1 via modprobe" \
        || ui_warn "nvidia-drm.modeset no encontrado en modprobe.d"

    grep -q 'fbdev=1' /etc/modprobe.d/nvidia-drm.conf 2>/dev/null \
        && ui_ok "nvidia-drm.fbdev=1 activo — TTY funcional en Wayland" \
        || ui_warn "nvidia-drm.fbdev=1 no configurado"

    grep -rqs 'NVreg_PreserveVideoMemoryAllocations' /etc/modprobe.d/ \
        && ui_ok "Opciones de suspensión NVIDIA configuradas" \
        || ui_info "Opciones de suspensión: las de fábrica del driver"

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

_verify_desktop() {
    ui_step "Verificando Escritorio y Drivers"
    is_deb_installed plasma-desktop && ui_ok "KDE Plasma instalado" || ui_fail "KDE Plasma NO instalado — módulo 4"
    is_service_enabled sddm && ui_ok "SDDM (login gráfico) habilitado" || ui_warn "SDDM no habilitado — módulo 4"
    is_deb_installed kwin-x11 && ui_ok "Sesión X11 de respaldo disponible" || ui_warn "Sin sesión X11 de respaldo — módulo 4"
    is_deb_installed network-manager && ui_ok "NetworkManager instalado" || ui_fail "NetworkManager NO instalado — módulo 4"
    is_deb_installed pipewire-audio || is_deb_installed pipewire-pulse && ui_ok "Audio PipeWire instalado" || ui_warn "PipeWire no instalado — módulo 4"
    is_deb_installed libavcodec-extra && ui_ok "Códecs multimedia instalados" || ui_warn "Códecs no instalados — módulo 4"
    is_deb_installed firmware-linux || is_deb_installed linux-firmware && ui_ok "Firmware instalado" || ui_fail "Firmware NO instalado — módulo 2"
    command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q 'Status: active' && ui_ok "Firewall activo" || ui_warn "Firewall inactivo — módulo 4"
    report_unbound_devices
}

_verify_docker() {
    ui_step "Verificando Docker"
    is_service_active docker && ui_ok "Docker: $(docker --version 2>/dev/null)" \
        || { ui_fail "Docker no activo"; return; }
    silent_cmd docker compose version && ui_ok "Docker Compose OK" || ui_warn "Docker Compose no encontrado"
    local ru="${SUDO_USER:-$USER}"
    groups "$ru" 2>/dev/null | grep -q docker && ui_ok "Usuario '$ru' en grupo docker" \
        || ui_warn "'$ru' NO en grupo docker — cierra sesión y vuelve"
    has_nvidia && { is_deb_installed nvidia-container-toolkit && ui_ok "NVIDIA Container Toolkit instalado" \
        || ui_fail "NVIDIA Container Toolkit NO instalado — GPU no disponible en Docker"; }
}

_verify_dev() {
    ui_step "Verificando Stack de Desarrollo"
    local real_user="${SUDO_USER:-$USER}"
    local real_home; real_home=$(eval echo "~${real_user}")

    # node/pnpm/agentes viven en el nvm del usuario real
    local probe='[[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh" >/dev/null 2>&1; '
    local node_ver; node_ver=$(sudo -u "$real_user" HOME="$real_home" bash -c "${probe}node -v 2>/dev/null")
    [[ -n "$node_ver" ]] && ui_ok "Node.js: $node_ver" || ui_fail "Node.js no encontrado — módulo 6"
    local pnpm_ver; pnpm_ver=$(sudo -u "$real_user" HOME="$real_home" bash -c "${probe}pnpm -v 2>/dev/null")
    [[ -n "$pnpm_ver" ]] && ui_ok "pnpm: $pnpm_ver" || ui_fail "pnpm no encontrado — módulo 6"
    [[ -x "${real_home}/.local/bin/claude" ]] && ui_ok "Claude Code instalado" || ui_warn "Claude Code no encontrado — módulo 13"
    [[ -x "${real_home}/.claude/hooks/guard.sh" ]] && ui_ok "ai-lordkit aplicado (~/.claude)" || ui_warn "ai-lordkit no aplicado — módulo 13"
    for cli in codex gemini; do
        sudo -u "$real_user" HOME="$real_home" bash -c "${probe}command -v $cli" &>/dev/null \
            && ui_ok "Agente IA: $cli" || ui_warn "Agente IA '$cli' no encontrado — módulo 6"
    done
    is_deb_installed orca-ide && ui_ok "Orca (gestor de agentes) instalado" \
        || ui_warn "Orca no instalado — módulo 6"

    is_cmd_available code && ui_ok "VS Code: $(code --version 2>/dev/null | head -1)" \
        || ui_warn "VS Code no en PATH — módulo 6"
    { is_cmd_available google-chrome || is_cmd_available google-chrome-stable; } \
        && ui_ok "Google Chrome instalado" || ui_warn "Chrome no encontrado — módulo 6"
    is_cmd_available git && ui_ok "$(git --version 2>/dev/null)" \
        || ui_fail "Git no encontrado — instala módulo 1"
    is_cmd_available zsh && ui_ok "Zsh: $(zsh --version 2>/dev/null | head -1)" \
        || ui_warn "Zsh no instalado — módulo 7"
    [[ -d "${real_home}/.oh-my-zsh" ]] && ui_ok "Oh My Zsh instalado" \
        || ui_warn "Oh My Zsh no encontrado — módulo 7"
    [[ -f "${real_home}/.p10k.zsh" ]] && ui_ok "Powerlevel10k configurado" \
        || ui_info ".p10k.zsh no encontrado — ejecuta 'p10k configure' en la terminal"

    # Git identity
    local gn; gn=$(sudo -u "$real_user" git config --global user.name  2>/dev/null || echo "")
    local ge; ge=$(sudo -u "$real_user" git config --global user.email 2>/dev/null || echo "")
    if [[ -n "$gn" ]] && [[ -n "$ge" ]]; then
        ui_ok "Git identidad: $gn <$ge>"
    else
        ui_warn "Git identidad no configurada — módulo 8"
    fi
}

_verify_gaming() {
    { is_deb_installed steam-installer || is_deb_installed steam || is_deb_installed lutris; } || return 0
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

    is_deb_installed timeshift && ui_ok "Timeshift instalado" || ui_info "Timeshift no instalado (módulo 10)"
    [[ -b /dev/zram0 ]] && ui_ok "ZRAM activo" || ui_info "ZRAM no activo (módulo 10)"
    is_service_enabled fstrim.timer && ui_ok "TRIM SSD habilitado" || ui_info "TRIM SSD no habilitado (módulo 10)"

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
    echo -e "${C_BOLD}  ║              HEALTH SCORE FINAL — AUTO SETUP              ║${C_RESET}"
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
    echo -e "${C_BOLD}  PRÓXIMOS PASOS${C_RESET}"
    echo -e "  ${C_WHITE}1.${C_RESET} Reinicia:  ${C_CYAN}sudo reboot${C_RESET}"
    echo -e "  ${C_WHITE}2.${C_RESET} En la pantalla de login elige la sesión ${C_CYAN}Plasma (Wayland)${C_RESET}; si ves parpadeos, ${C_CYAN}Plasma (X11)${C_RESET}"
    echo -e "  ${C_WHITE}3.${C_RESET} Inicia sesión en los agentes:  ${C_CYAN}claude${C_RESET} · ${C_CYAN}codex login${C_RESET} · ${C_CYAN}gemini${C_RESET}"
    echo -e "  ${C_WHITE}4.${C_RESET} GitHub:  ${C_CYAN}gh auth login${C_RESET}  y sube tu clave SSH (la muestra: cat ~/.ssh/id_ed25519.pub)"
    echo -e "  ${C_WHITE}5.${C_RESET} Comprueba todo otra vez tras reiniciar:  ${C_CYAN}ag-verify${C_RESET}"
    echo -e "  ${C_DIM}Guía completa: ~/antigravity-kubuntu/docs/GUIA-INSTALACION.md${C_RESET}"
    echo -e "  ${C_DIM}Log: ${AG_LOG_FILE}${C_RESET}"; echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/90-verify.sh" && exit 1
    ui_log_init; run_module_verify
fi

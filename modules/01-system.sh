#!/usr/bin/env bash
# AUTO SETUP — modules/01-system.sh [Debian 13 / Ubuntu 26.04]
# Sistema base: apt, repos (contrib/non-free o universe/multiverse), herramientas, sudo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

# ¿Le falta contrib, non-free o non-free-firmware a alguna línea de Debian?
# (el instalador de Debian solo pone "main non-free-firmware": faltan contrib y non-free,
#  y con ellos Steam, Lutris, winetricks…)
_components_incomplete() { # $1 = archivo, $2 = regex de las líneas a mirar
    local l
    while IFS= read -r l; do
        for c in contrib non-free non-free-firmware; do
            grep -Eq "(^|[[:space:]])${c}([[:space:]]|\$)" <<<"$l" || return 0
        done
    done < <(grep -E "$2" "$1" 2>/dev/null)
    return 1
}

_enable_repos_debian() {
    ui_info "Habilitando contrib, non-free y non-free-firmware (Debian)..."
    local changed=false f
    # Formato deb822 (Debian 12+): /etc/apt/sources.list.d/debian.sources
    f=/etc/apt/sources.list.d/debian.sources
    if [[ -f "$f" ]]; then
        if _components_incomplete "$f" '^Components:'; then
            run_cmd 2 "Añadir componentes a debian.sources" \
                sed -i -E 's/^Components:.*$/Components: main contrib non-free non-free-firmware/' "$f" && changed=true
        else ui_skip "debian.sources ya incluye contrib y non-free"; fi
    fi
    # Formato clásico
    f=/etc/apt/sources.list
    if [[ -f "$f" ]] && grep -qE '^deb(-src)? .* main' "$f"; then
        if _components_incomplete "$f" '^deb(-src)? .* main'; then
            run_cmd 2 "Añadir componentes a sources.list" \
                sed -i -E '/^deb(-src)? /s/ main( .*)?$/ main contrib non-free non-free-firmware/' "$f" && changed=true
        else ui_skip "sources.list ya incluye contrib y non-free"; fi
    fi
    if $changed; then run_cmd 2 "apt update post-repos" apt-get update; fi
    return 0
}

_enable_repos_ubuntu() {
    run_cmd 1 "Habilitar universe"   add-apt-repository -y universe
    run_cmd 1 "Habilitar restricted" add-apt-repository -y restricted
    run_cmd 1 "Habilitar multiverse" add-apt-repository -y multiverse
    run_cmd 2 "apt update post-repos" apt update
}

run_module_system() {
    ui_step "MÓDULO 01 — SISTEMA BASE"
    ui_panel_start "apt + repos + herramientas base"
    export DEBIAN_FRONTEND=noninteractive
    detect_hardware

    # Una versión anterior de este script desactivaba los paquetes recomendados de apt.
    # En Debian eso deja los programas a medias (sin plugins, sin códecs, sin extras).
    if [[ -f /etc/apt/apt.conf.d/99-auto-setup ]]; then
        rm -f /etc/apt/apt.conf.d/99-auto-setup
        ui_ok "Quitado apt.conf antiguo (Install-Recommends vuelve a su valor normal)"
    fi

    # El instalador deja una línea `deb cdrom:` que rompe `apt update`.
    if grep -Eq '^\s*deb cdrom:' /etc/apt/sources.list 2>/dev/null; then
        run_cmd 1 "Quitar la fuente cdrom de apt" sed -i -E 's/^\s*deb cdrom:/# deb cdrom:/' /etc/apt/sources.list
    fi

    # Deshabilitar PPAs rotos antes de actualizar (solo Ubuntu)
    for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [[ -f "$f" ]] || continue
        grep -q 'lutris' "$f" 2>/dev/null && {
            ui_warn "PPA lutris sin soporte — deshabilitando: $f"
            mv "$f" "${f}.disabled" 2>/dev/null || true
        }
    done

    if is_debian; then _enable_repos_debian; else _enable_repos_ubuntu; fi

    run_cmd 1 "apt update" apt update
    run_cmd 2 "apt full-upgrade" apt full-upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"

    ui_info "Instalando herramientas base..."
    local base_pkgs=(
        sudo curl wget git htop btop nano vim bash-completion unzip zip tar xz-utils
        7zip pciutils usbutils lshw inxi fastfetch lsb-release
        build-essential dkms jq tree ncdu rsync
        ca-certificates gnupg
        python3 python3-pip python3-venv
        man-db command-not-found
    )
    is_ubuntu && base_pkgs+=(software-properties-common mokutil)
    for pkg in "${base_pkgs[@]}"; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 2 "Instalar $pkg" apt install -y "$pkg"
    done

    # El usuario tiene que poder usar sudo después de reiniciar.
    local ru="${SUDO_USER:-$USER}"
    id -nG "$ru" 2>/dev/null | grep -qw sudo && ui_skip "$ru ya está en el grupo sudo" \
        || run_cmd 1 "Agregar $ru al grupo sudo" usermod -aG sudo "$ru"

    # Parches de seguridad automáticos (solo seguridad, sin reinicios).
    is_deb_installed unattended-upgrades && ui_skip "unattended-upgrades" \
        || run_cmd 1 "Instalar unattended-upgrades" apt-get install -y unattended-upgrades
    [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]] || run_cmd 1 "Activar parches de seguridad automáticos" bash -c \
        'printf "APT::Periodic::Update-Package-Lists \"1\";\nAPT::Periodic::Unattended-Upgrade \"1\";\n" > /etc/apt/apt.conf.d/20auto-upgrades'

    run_cmd 1 "autoremove" apt autoremove -y
    run_cmd 1 "autoclean"  apt autoclean

    ui_panel_end; ui_ok "Módulo 01 completado"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/01-system.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_system; ui_summary
fi

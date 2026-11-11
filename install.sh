#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — install.sh  (bootstrap de un solo comando)
#
#  Tras instalar Debian, en una terminal (como tu usuario normal, NO como root):
#    wget -qO- https://raw.githubusercontent.com/FrankLord27/antigravity-kubuntu/main/install.sh | bash
#
#  Funciona en un Debian recién instalado, donde puede que no haya ni `sudo`
#  ni `curl` ni `git`: se eleva con `sudo` si tu usuario lo tiene, o con la
#  contraseña de root (`su`) si no. Clona el repo en ~/antigravity-kubuntu y
#  lanza la instalación completa.
#
#  Todo va dentro de main(): si la descarga se corta, bash no ejecuta nada.
# =============================================================================

main() {
    set -euo pipefail

    local repo_url="${AUTO_SETUP_REPO:-https://github.com/FrankLord27/antigravity-kubuntu.git}"
    local branch="${AUTO_SETUP_BRANCH:-main}"
    local me; me="$(id -un)"
    local home; home="$(getent passwd "$me" | cut -d: -f6)"
    local target="${home}/antigravity-kubuntu"

    say()  { printf '\n  \033[1;36m▶\033[0m %s\n' "$*"; }
    fail() { printf '\n  \033[0;31m✗ %s\033[0m\n\n' "$*" >&2; exit 1; }

    [[ "$(id -u)" -eq 0 ]] && fail "Córrelo como tu usuario normal, no como root (el script pide la contraseña cuando hace falta)."
    command -v apt-get >/dev/null 2>&1 || fail "Esto es para Debian o Ubuntu (no encuentro apt-get)."

    # Con `wget ... | bash` la entrada estándar es el propio script: las contraseñas
    # y las preguntas se leen de la terminal.
    if [[ ! -t 0 ]]; then
        if ( exec </dev/tty ) 2>/dev/null; then exec </dev/tty
        else fail "No hay terminal para pedir la contraseña. Descarga install.sh y córrelo con: bash install.sh"; fi
    fi

    # Lo que hace falta antes de poder clonar y detectar hardware.
    local boot_pkgs="sudo git curl wget ca-certificates pciutils"
    # Un `deb cdrom:` que deja el instalador rompe `apt-get update`.
    local fix_cdrom="sed -i -E 's/^[[:space:]]*deb cdrom:/# deb cdrom:/' /etc/apt/sources.list 2>/dev/null || true"
    local root_prep="${fix_cdrom}; export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq ${boot_pkgs} && usermod -aG sudo '${me}'"
    local clone="if [ -d '${target}/.git' ]; then git -C '${target}' pull --ff-only || true; else git clone --depth=1 --branch '${branch}' '${repo_url}' '${target}'; fi"

    say "Auto Setup — preparando el sistema"

    if command -v sudo >/dev/null 2>&1 && id -nG "$me" | grep -qw sudo && sudo -v; then
        # Tu usuario ya tiene sudo (instalaste Debian sin contraseña de root).
        sudo bash -c "$root_prep"
        bash -c "$clone"
        say "Iniciando la instalación completa"
        exec sudo bash "${target}/setup.sh" --auto
    fi

    # Debian con contraseña de root: tu usuario no está en el grupo sudo todavía.
    command -v su >/dev/null 2>&1 || fail "No hay ni sudo ni su. Entra como root e instala sudo: apt install sudo"
    say "Tu usuario no tiene sudo. Escribe la contraseña de ROOT (la que pusiste al instalar Debian):"
    # Una sola elevación: prepara, clona como tu usuario y lanza la instalación.
    exec su - root -c "${root_prep} && runuser -u '${me}' -- bash -c \"${clone}\" && SUDO_USER='${me}' bash '${target}/setup.sh' --auto"
}

main "$@"

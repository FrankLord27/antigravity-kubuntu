#!/usr/bin/env bash
# AUTO SETUP — modules/06-dev.sh [Debian 13 / Ubuntu 26.04]
# Stack de desarrollo: nvm + Node 26 + pnpm (corepack) + VS Code + Chrome
#                      + Claude Code + Codex CLI + Gemini CLI + Orca

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/configs/packages.conf"

# Ejecuta un comando como el usuario real con nvm cargado
_as_user_node() {
    local real_user="$1" real_home="$2"; shift 2
    sudo -u "$real_user" HOME="$real_home" bash -c \
        'export NVM_DIR="$HOME/.nvm"; [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"; '"$*"
}

_install_node() {
    local real_user="$1" real_home="$2"
    ui_info "Instalando nvm ${NVM_VERSION} + Node ${NODE_VERSION} + pnpm (corepack)..."

    if [[ -s "${real_home}/.nvm/nvm.sh" ]]; then ui_skip "nvm ya instalado"
    else
        run_cmd 2 "Instalar nvm" sudo -u "$real_user" HOME="$real_home" bash -c \
            "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
    fi

    if _as_user_node "$real_user" "$real_home" "nvm ls ${NODE_VERSION} &>/dev/null"; then
        ui_skip "Node ${NODE_VERSION} ya instalado"
    else
        run_cmd 2 "nvm install ${NODE_VERSION}" _as_user_node "$real_user" "$real_home" \
            "nvm install ${NODE_VERSION} && nvm alias default ${NODE_VERSION}"
    fi

    if _as_user_node "$real_user" "$real_home" "COREPACK_ENABLE_DOWNLOAD_PROMPT=0 pnpm -v &>/dev/null"; then
        ui_skip "pnpm ya instalado"
    else
        run_cmd 2 "Instalar corepack + pnpm" _as_user_node "$real_user" "$real_home" \
            "export COREPACK_ENABLE_DOWNLOAD_PROMPT=0; npm install -g corepack && corepack enable pnpm && { corepack install -g pnpm@latest || corepack prepare pnpm@latest --activate; }"
    fi

    local nv pv
    nv=$(_as_user_node "$real_user" "$real_home" "node -v" 2>/dev/null || echo "?")
    pv=$(_as_user_node "$real_user" "$real_home" "COREPACK_ENABLE_DOWNLOAD_PROMPT=0 pnpm -v" 2>/dev/null || echo "?")
    ui_ok "Node ${nv} · pnpm ${pv}"
}

_install_ai_clis() {
    local real_user="$1" real_home="$2"
    ui_info "Instalando agentes de IA por npm (Codex, Gemini; Claude Code va en el módulo 13)..."
    for pkg in "${NPM_GLOBAL_PKGS[@]}"; do
        if _as_user_node "$real_user" "$real_home" "npm ls -g --depth=0 2>/dev/null | grep -q '${pkg}@'"; then
            ui_skip "$pkg"
        else
            run_cmd 2 "npm i -g $pkg" _as_user_node "$real_user" "$real_home" "npm install -g ${pkg}"
        fi
    done
}

_install_orca() {
    [[ "${INSTALL_ORCA:-false}" == "true" ]] || { ui_skip "Orca (desactivado en packages.conf)"; return 0; }
    is_deb_installed orca-ide && { ui_skip "Orca ya instalado"; return 0; }
    ui_info "Instalando Orca (gestor de agentes de IA)..."
    local url
    url=$(curl -fsSL "$ORCA_RELEASES_API" 2>/dev/null \
        | grep -oE '"browser_download_url": *"[^"]+orca-ide_[^"]+_amd64\.deb"' \
        | head -1 | sed -E 's/.*"(https[^"]+)"/\1/')
    [[ -z "$url" ]] && { ui_fail "No se pudo obtener la URL del .deb de Orca"; return 1; }
    local tmp; tmp=$(mktemp -d)
    run_cmd 2 "Descargar Orca" curl -fsSL -o "${tmp}/orca.deb" "$url" \
        && run_cmd 2 "Instalar Orca" apt install -y "${tmp}/orca.deb"
    rm -rf "$tmp"
}

_install_vscode() {
    is_cmd_available code && { ui_skip "VS Code ya instalado"; return 0; }
    ui_info "Instalando VS Code..."
    run_cmd 2 "GPG key Microsoft" bash -c \
        'curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor --yes -o /usr/share/keyrings/microsoft.gpg'
    # Mismo archivo que crea el propio paquete `code`: así apt no ve el repo duplicado.
    rm -f /etc/apt/sources.list.d/vscode.list
    run_cmd 2 "Repo VS Code" bash -c 'cat > /etc/apt/sources.list.d/vscode.sources << EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF'
    echo "code code/add-microsoft-repo boolean true" | debconf-set-selections 2>/dev/null || true
    run_cmd 2 "apt update post-vscode" apt-get update
    run_cmd 2 "Instalar code" apt-get install -y code
}

_install_chrome() {
    [[ "${INSTALL_CHROME:-false}" == "true" ]] || { ui_skip "Chrome (desactivado en packages.conf)"; return 0; }
    { is_cmd_available google-chrome || is_cmd_available google-chrome-stable; } \
        && { ui_skip "Google Chrome ya instalado"; return 0; }
    ui_info "Instalando Google Chrome..."
    # El .deb oficial configura él mismo su repo y su llave para las actualizaciones.
    rm -f /etc/apt/sources.list.d/google-chrome.list /etc/apt/keyrings/google-chrome.gpg
    local tmp; tmp=$(mktemp -d)
    run_cmd 2 "Descargar Google Chrome" curl -fsSL -o "${tmp}/chrome.deb" \
        "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
        && run_cmd 2 "Instalar google-chrome-stable" apt-get install -y "${tmp}/chrome.deb"
    rm -rf "$tmp"
}

run_module_dev() {
    ui_step "MÓDULO 06 — STACK DE DESARROLLO"
    ui_panel_start "Node + pnpm + VS Code + Chrome + agentes IA + Orca"
    export DEBIAN_FRONTEND=noninteractive
    local real_user="${SUDO_USER:-$USER}"
    local real_home; real_home=$(eval echo "~$real_user")

    ui_info "Instalando herramientas de compilación..."
    for pkg in build-essential gcc g++ make cmake libssl-dev libffi-dev zlib1g-dev \
                libreadline-dev libsqlite3-dev libbz2-dev pkg-config jq ripgrep fd-find bat eza fzf zsh httpie \
                shellcheck git-lfs postgresql-client redis-tools sqlite3; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done

    _install_node "$real_user" "$real_home"
    _install_ai_clis "$real_user" "$real_home"
    _install_vscode
    _install_chrome
    _install_orca

    ui_info "Configurando Flatpak + Flathub..."
    is_deb_installed flatpak && ui_skip "flatpak" || run_cmd 2 "Instalar flatpak" apt install -y flatpak
    is_deb_installed plasma-discover-backend-flatpak && ui_skip "plasma-discover-backend-flatpak" \
        || run_cmd 1 "Instalar backend Flatpak para Discover" apt install -y plasma-discover-backend-flatpak
    flatpak remotes 2>/dev/null | grep -q flathub && ui_skip "Flathub ya configurado" \
        || run_cmd 1 "Agregar Flathub" flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo

    ui_panel_end; ui_ok "Módulo 06 completado"
    echo ""
    ui_info "Login de agentes (una vez, en tu terminal): codex login · gemini"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/06-dev.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_dev; ui_summary
fi

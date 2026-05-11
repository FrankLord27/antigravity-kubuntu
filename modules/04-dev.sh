#!/usr/bin/env bash
# ANTIGRAVITY — modules/04-dev.sh [Kubuntu 26.04 LTS]
# Stack de desarrollo: Node.js LTS (fnm) + pnpm + VS Code + Chrome + Git + Zsh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

run_module_dev() {
    ui_step "MÓDULO 04 — STACK DE DESARROLLO"
    ui_panel_start "Node.js + pnpm + VS Code + Chrome + Git + Zsh"
    export DEBIAN_FRONTEND=noninteractive
    local real_user="${SUDO_USER:-$USER}"
    local real_home; real_home=$(eval echo "~$real_user")

    detect_dev_tools

    ui_info "Instalando herramientas de compilación..."
    for pkg in build-essential gcc g++ make cmake libssl-dev libffi-dev zlib1g-dev \
                libreadline-dev libsqlite3-dev libbz2-dev jq ripgrep fd-find bat eza fzf zsh httpie; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 1 "Instalar $pkg" apt install -y "$pkg"
    done

    ui_info "Configurando Git..."
    is_deb_installed git && ui_skip "git" || run_cmd 2 "Instalar git" apt install -y git
    sudo -u "$real_user" git config --global init.defaultBranch main   2>/dev/null || true
    sudo -u "$real_user" git config --global pull.rebase false          2>/dev/null || true
    sudo -u "$real_user" git config --global core.autocrlf input        2>/dev/null || true
    sudo -u "$real_user" git config --global core.editor nano           2>/dev/null || true
    ui_ok "Git configurado"

    ui_info "Instalando fnm (Fast Node Manager)..."
    local fnm_path="${real_home}/.local/share/fnm"
    [[ -f "${fnm_path}/fnm" ]] && ui_skip "fnm ya instalado" \
        || run_cmd 2 "Instalar fnm" sudo -u "$real_user" bash -c \
            'curl -fsSL https://fnm.vercel.app/install | bash'

    if [[ "$DETECT_NODE_VER" == "no instalado" ]]; then
        ui_info "Instalando Node.js LTS..."
        run_cmd 2 "fnm install LTS" sudo -u "$real_user" bash -c "
            export PATH=\"${fnm_path}:\$PATH\"
            eval \"\$(${fnm_path}/fnm env 2>/dev/null)\"
            fnm install --lts && fnm use lts-latest && fnm default lts-latest"
    else ui_skip "Node.js ya instalado ($DETECT_NODE_VER)"; fi

    local fnm_snip='
# fnm - Fast Node Manager
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd 2>/dev/null)"'
    for rc in "${real_home}/.bashrc" "${real_home}/.zshrc"; do
        [[ -f "$rc" ]] && ! grep -q 'fnm env' "$rc" && echo "$fnm_snip" >> "$rc" \
            && ui_ok "fnm → $(basename $rc)" || true
    done

    if [[ "$DETECT_PNPM_VER" == "no instalado" ]]; then
        run_cmd 2 "Instalar pnpm" sudo -u "$real_user" bash -c "
            export PATH=\"${fnm_path}:\$PATH\"
            eval \"\$(${fnm_path}/fnm env 2>/dev/null)\"
            npm install -g pnpm"
    else ui_skip "pnpm ya instalado ($DETECT_PNPM_VER)"; fi

    ui_info "Instalando VS Code..."
    if is_cmd_available code; then ui_skip "VS Code ya instalado"
    else
        run_cmd 2 "GPG key Microsoft" bash -c \
            'curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
            | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg'
        run_cmd 2 "Repo VS Code" bash -c \
            'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] \
            https://packages.microsoft.com/repos/code stable main" \
            > /etc/apt/sources.list.d/vscode.list'
        run_cmd 2 "apt update post-vscode" apt update
        run_cmd 2 "Instalar code" apt install -y code
    fi

    ui_info "Instalando Google Chrome..."
    if is_cmd_available google-chrome || is_cmd_available google-chrome-stable; then
        ui_skip "Google Chrome ya instalado"
    else
        if [[ ! -f /etc/apt/keyrings/google-chrome.gpg ]]; then
            run_cmd 2 "GPG key Google" bash -c \
                'curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
                | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg'
            run_cmd 2 "Repo Google Chrome" bash -c \
                'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] \
                https://dl.google.com/linux/chrome/deb/ stable main" \
                > /etc/apt/sources.list.d/google-chrome.list'
            run_cmd 2 "apt update post-chrome" apt update
        fi
        run_cmd 2 "Instalar google-chrome-stable" apt install -y google-chrome-stable
    fi

    ui_info "Configurando Flatpak + Flathub..."
    is_deb_installed flatpak && ui_skip "flatpak" || run_cmd 2 "Instalar flatpak" apt install -y flatpak
    flatpak remotes 2>/dev/null | grep -q flathub && ui_skip "Flathub ya configurado" \
        || run_cmd 1 "Agregar Flathub" flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo

    ui_panel_end; ui_ok "Módulo 04 completado"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/04-dev.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_dev; ui_summary
fi

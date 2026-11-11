#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — modules/13-claude.sh [Debian 13 / Ubuntu 26.04]
#  Claude Code + ai-lordkit (agents, skills, hooks, modos, MCP, plugins).
#
#  Debe correr DESPUÉS de zsh (07) y de Node (06), y como tu usuario, no root:
#   • con nvm cargado, para que ai-lordkit vea tu Node y no instale otro;
#   • con lo que ai-lordkit necesita de apt ya instalado, para que no pida sudo;
#   • sin terminal y con CLAUDE_YES=1, para que no pregunte nada.
#  Claude Code lo instala ai-lordkit con el instalador oficial (~/.local/bin/claude).
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"
source "${SCRIPT_DIR}/configs/packages.conf"

run_module_claude() {
    ui_step "MÓDULO 13 — CLAUDE CODE + AI-LORDKIT"
    ui_panel_start "Claude Code + configuración ai-lordkit"
    [[ "${INSTALL_AI_LORDKIT:-true}" == "true" ]] || { ui_skip "ai-lordkit (desactivado en packages.conf)"; return 0; }
    export DEBIAN_FRONTEND=noninteractive
    local ru="${SUDO_USER:-$USER}"
    local rh; rh=$(getent passwd "$ru" | cut -d: -f6)
    local kit="${rh}/.ai-lordkit" log="${rh}/ai-lordkit-install.log"
    local repo="${AI_LORDKIT_REPO:-https://github.com/FrankLord27/ai-lordkit.git}" ref="${AI_LORDKIT_REF:-main}"

    # Lo que ai-lordkit pediría con sudo: se deja instalado desde aquí (somos root).
    for pkg in git jq curl tar ca-certificates libnotify-bin; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 2 "Instalar $pkg" apt-get install -y "$pkg"
    done
    command -v gh &>/dev/null || run_cmd 1 "Instalar gh" apt-get install -y gh

    if [[ ! -s "${rh}/.nvm/nvm.sh" ]]; then
        ui_fail "No hay nvm/Node del usuario — corre antes el módulo 6 (sudo bash modules/06-dev.sh)"
        return 1
    fi

    # Un Claude Code instalado por npm chocaría con el nativo que instala ai-lordkit.
    sudo -u "$ru" HOME="$rh" bash -c 'export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
        npm ls -g --depth=0 2>/dev/null | grep -q "@anthropic-ai/claude-code@" && npm uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1 || true'

    if [[ -d "${kit}/.git" ]]; then
        run_cmd 1 "Actualizar ai-lordkit" sudo -u "$ru" git -C "$kit" pull --ff-only
    else
        run_cmd 2 "Clonar ai-lordkit (${ref})" sudo -u "$ru" git clone --branch "$ref" "$repo" "$kit" || return 1
    fi

    # `all` en una máquina limpia; `update` si ya había configuración (all la resetea).
    local action="all"
    [[ -x "${rh}/.claude/hooks/guard.sh" ]] && action="update"

    ui_info "Corriendo ai-lordkit: install.sh ${action} (varios minutos; log en ${log})..."
    local rc=0
    sudo -u "$ru" HOME="$rh" bash -c '
        export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh" >/dev/null 2>&1; nvm use default >/dev/null 2>&1
        command -v node >/dev/null && command -v pnpm >/dev/null || { echo "[✗] node/pnpm no están en el PATH"; exit 97; }
        export PATH="$HOME/.local/bin:$PATH" SHELL="$(command -v zsh || command -v bash)"
        export CLAUDE_YES=1 COREPACK_ENABLE_DOWNLOAD_PROMPT=0
        cd "$HOME/.ai-lordkit" && bash ./install.sh '"$action"' </dev/null
    ' > "$log" 2>&1 || rc=$?
    chown "$ru":"$ru" "$log" 2>/dev/null || true
    { echo "═══ ai-lordkit (rc=$rc) ═══"; cat "$log"; } >> "$AG_LOG_FILE" 2>/dev/null || true

    # El código de salida de ai-lordkit no refleja los avisos: se cuentan en el log.
    local errs warns
    errs=$(grep -c '\[✗\]' "$log" 2>/dev/null || true); warns=$(grep -c '\[!\]' "$log" 2>/dev/null || true)
    if [[ -x "${rh}/.local/bin/claude" && -x "${rh}/.claude/hooks/guard.sh" ]]; then
        ui_ok "Claude Code + ai-lordkit instalados (${warns:-0} avisos, ${errs:-0} errores en el log)"
    else
        ui_fail "ai-lordkit no terminó (rc=$rc) — revisa ${log} y repite: sudo bash modules/13-claude.sh"
        grep -E '\[✗\]' "$log" | sed 's/\x1b\[[0-9;]*m//g' | head -5 | while IFS= read -r l; do echo -e "      ${C_DIM}${l:0:120}${C_RESET}"; done
        ui_panel_end; return 1
    fi
    if [[ "${errs:-0}" -gt 0 || "${warns:-0}" -gt 0 ]]; then
        grep -E '\[✗\]|\[!\]' "$log" | sed 's/\x1b\[[0-9;]*m//g' | grep -vE 'Instalando uv|kimi|capa privada|Sin credenciales|GITHUB_MCP_TOKEN|gh sin autenticar|gh NO autenticado' | head -12 | while IFS= read -r l; do
            echo -e "      ${C_DIM}${l:0:120}${C_RESET}"; done
    fi

    if grep -q 'No se pudo instalar .*@' "$log" 2>/dev/null; then
        ui_warn "Algunos plugins de Claude no se instalaron. Tras iniciar sesión (claude y gh auth login): ~/.ai-lordkit/install.sh plugins"
    fi
    ui_panel_end; ui_ok "Módulo 13 completado"
    ui_info "Abre una terminal nueva y escribe: claude  (inicia sesión una vez)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/13-claude.sh" && exit 1
    ui_log_init; run_module_claude; ui_summary
fi

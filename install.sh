#!/usr/bin/env bash
# =============================================================================
#  AUTO SETUP — install.sh  (bootstrap de un solo comando)
#
#  Tras formatear, en una terminal:
#    curl -fsSL https://raw.githubusercontent.com/FrankLord27/antigravity-kubuntu/main/install.sh | bash
#
#  Clona el repo en ~/antigravity-kubuntu y lanza la instalación completa.
#  Pide la contraseña de sudo una sola vez.
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/FrankLord27/antigravity-kubuntu.git"
TARGET="${HOME}/antigravity-kubuntu"

echo ""
echo "  ▶ Auto Setup — preparando..."

if ! command -v git &>/dev/null || ! command -v curl &>/dev/null; then
    echo "  ▶ Instalando git y curl..."
    sudo apt update -qq
    sudo apt install -y -qq git curl
fi

if [[ -d "${TARGET}/.git" ]]; then
    echo "  ▶ Repo ya existe — actualizando..."
    git -C "$TARGET" pull --ff-only
else
    echo "  ▶ Clonando repo en ${TARGET}..."
    git clone --depth=1 "$REPO_URL" "$TARGET"
fi

echo "  ▶ Iniciando instalación completa (sin preguntas)..."
echo ""
exec sudo bash "${TARGET}/setup.sh" --auto

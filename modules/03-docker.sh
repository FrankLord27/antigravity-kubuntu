#!/usr/bin/env bash
# AUTO SETUP — modules/03-docker.sh [Debian 13 / Ubuntu 26.04]
# Docker CE oficial (repo de Docker para la distro detectada) + NVIDIA Container Toolkit si hay GPU

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/detect.sh"

run_module_docker() {
    ui_step "MÓDULO 03 — DOCKER CE"
    ui_panel_start "Docker CE oficial (+ NVIDIA Container Toolkit si hay GPU)"
    export DEBIAN_FRONTEND=noninteractive
    local real_user="${SUDO_USER:-$USER}"

    detect_hardware; detect_docker
    if [[ "$DETECT_DOCKER_RUNNING" == "yes" ]]; then
        ui_skip "Docker ya activo ($(docker --version 2>/dev/null))"
        _configure_docker_daemon
        _install_nvidia_container_toolkit
        return 0
    fi

    ui_info "Eliminando versiones antiguas de Docker..."
    for pkg in docker docker.io docker-engine docker-compose docker-compose-v2 podman-docker containerd runc; do
        is_deb_installed "$pkg" && run_cmd 1 "Eliminar $pkg" apt remove -y "$pkg" || true
    done

    # Eliminar snap Docker si existe (solo Ubuntu)
    command -v snap &>/dev/null && snap list docker &>/dev/null 2>&1 && {
        ui_warn "Docker Snap detectado — eliminando (conflicto con Docker CE)"
        run_cmd 2 "Eliminar Docker snap" snap remove docker
    } || true

    ui_info "Configurando repo oficial Docker CE (${DETECT_DISTRO})..."
    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        run_cmd 3 "Crear keyrings dir" install -m 0755 -d /etc/apt/keyrings
        run_cmd 3 "GPG key Docker" bash -c \
            "curl -fsSL https://download.docker.com/linux/${DETECT_DISTRO}/gpg \
            -o /etc/apt/keyrings/docker.asc && chmod a+r /etc/apt/keyrings/docker.asc"
        run_cmd 3 "Repo Docker CE" bash -c \
            "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
            https://download.docker.com/linux/${DETECT_DISTRO} ${DETECT_OS_CODENAME} stable\" \
            > /etc/apt/sources.list.d/docker.list"
        run_cmd 3 "apt update post-Docker" apt update
    else ui_skip "Repo Docker CE ya configurado"; fi

    for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
        is_deb_installed "$pkg" && ui_skip "$pkg" || run_cmd 3 "Instalar $pkg" apt install -y "$pkg"
    done

    run_cmd 2 "Habilitar docker" systemctl enable docker
    run_cmd 2 "Iniciar docker"   systemctl start docker

    groups "$real_user" 2>/dev/null | grep -q docker && ui_skip "$real_user ya en grupo docker" || {
        run_cmd 2 "Agregar $real_user a docker" usermod -aG docker "$real_user"
        ui_warn "Grupo docker activa en el próximo login"
    }

    _configure_docker_daemon
    _install_nvidia_container_toolkit
    _install_portainer_ce

    is_service_active docker && ui_ok "Docker CE activo: $(docker --version 2>/dev/null)" \
        || ui_fail "Docker no activo — journalctl -xe | grep docker"

    ui_panel_end; ui_ok "Módulo 03 completado"
}

_configure_docker_daemon() {
    ui_info "Configurando Docker daemon..."
    mkdir -p /etc/docker
    [[ -f /etc/docker/daemon.json ]] && { ui_skip "daemon.json ya existe"; return; }
    run_cmd 1 "Crear daemon.json" bash -c 'cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "storage-driver": "overlay2",
  "features": { "buildkit": true }
}
EOF'
    run_cmd 1 "Reiniciar Docker" systemctl restart docker
    ui_ok "daemon.json configurado"
}

_install_nvidia_container_toolkit() {
    has_nvidia || { ui_skip "NVIDIA Container Toolkit (sin GPU NVIDIA)"; return 0; }
    ui_info "Instalando NVIDIA Container Toolkit..."
    if is_deb_installed nvidia-container-toolkit; then
        ui_skip "NVIDIA Container Toolkit ya instalado"
    else
        if [[ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]]; then
            run_cmd 2 "GPG key nvidia-container" bash -c \
                'curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
                | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg'
            run_cmd 2 "Repo nvidia-container" bash -c \
                'curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
                | sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g" \
                > /etc/apt/sources.list.d/nvidia-container-toolkit.list'
            run_cmd 2 "apt update post-nvidia-container" apt update
        fi
        run_cmd 2 "Instalar nvidia-container-toolkit" apt install -y nvidia-container-toolkit
    fi
    if command -v nvidia-ctk &>/dev/null && is_service_active docker; then
        run_cmd 2 "Configurar runtime NVIDIA en Docker" nvidia-ctk runtime configure --runtime=docker
        run_cmd 1 "Reiniciar Docker post-runtime" systemctl restart docker
        ui_ok "GPU NVIDIA disponible en contenedores Docker"
    else
        ui_warn "nvidia-ctk no disponible aún — ejecuta tras reinicio:"
        ui_warn "  sudo nvidia-ctk runtime configure --runtime=docker"
        ui_warn "  sudo systemctl restart docker"
    fi
}

_install_portainer_ce() {
    ui_info "Verificando Portainer CE..."
    if ! is_service_active docker; then
        ui_warn "Docker no activo, saltando instalación de Portainer"
        return
    fi
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^portainer$'; then
        ui_skip "Portainer CE ya instalado"
    else
        ui_info "Instalando Portainer CE..."
        run_cmd 2 "Crear volumen portainer_data" docker volume create portainer_data
        run_cmd 2 "Iniciar contenedor portainer" docker run -d -p 8000:8000 -p 9443:9443 \
            --name portainer --restart=always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data portainer/portainer-ce:latest
        ui_ok "Portainer CE instalado (Acceso en https://localhost:9443)"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $EUID -ne 0 ]] && echo "Ejecuta: sudo bash modules/03-docker.sh" && exit 1
    export DEBIAN_FRONTEND=noninteractive
    ui_log_init; run_module_docker; ui_summary
fi

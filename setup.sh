#!/bin/bash
# ============================================================
# setup-opencode.sh - Configuracion inicial post-arranque
# Ejecutar dentro del contenedor como usuario: cloud
# ============================================================
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  OpenCode VPS - Setup Inicial${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================================
# 1. Cambiar contrasenas por defecto
# ============================================================
echo -e "${YELLOW}[1/4] Cambiando contrasenas por defecto...${NC}"
echo "Cambia las contrasenas de devadmin y cloud con:"
echo "  passwd devadmin"
echo "  passwd cloud"
echo ""

# ============================================================
# 2. Configurar OpenCode Go (API Key)
# ============================================================
echo -e "${YELLOW}[2/4] Configurar OpenCode Go${NC}"
echo "1. Ve a https://opencode.ai/auth"
echo "2. Inicia sesion y copia tu API key de OpenCode Go"
echo "3. Ejecuta:"
echo ""
echo "   /root/.opencode/bin/opencode auth login --provider opencode-go"
echo ""
echo "   Cuando pida la API key, pega la que copiaste."
echo ""

# ============================================================
# 3. Cloudflare Tunnel
# ============================================================
echo -e "${YELLOW}[3/4] Configurar Cloudflare Tunnel${NC}"
echo ""
echo "a) Autenticar con Cloudflare:"
echo "   cloudflared tunnel login"
echo ""
echo "b) Crear el tunnel:"
echo "   cloudflared tunnel create opencode-vps"
echo ""
echo "c) Anota el UUID que te da y actualiza:"
echo "   /home/cloud/.cloudflared/config.yml"
echo "   (reemplaza <TUNNEL-UUID> y los hostnames)"
echo ""
echo "d) Copiar el certificado JSON:"
echo "   cp ~/.cloudflared/<UUID>.json /home/cloud/.cloudflared/"
echo "   chown cloud:cloud /home/cloud/.cloudflared/<UUID>.json"
echo ""
echo "e) Route DNS:"
echo "   cloudflared tunnel route dns opencode-vps opencode.tudominio.com"
echo "   cloudflared tunnel route dns opencode-vps ssh.tudominio.com"
echo ""

# ============================================================
# 4. GitHub CLI
# ============================================================
echo -e "${YELLOW}[4/4] Configurar GitHub CLI${NC}"
echo ""
echo "a) Autenticar:"
echo "   gh auth login"
echo "   (Selecciona GitHub.com > HTTPS > Login with a web browser)"
echo ""
echo "b) Configurar git:"
echo "   gh auth setup-git"
echo ""
echo "c) Generar SSH key para GitHub (opcional, para repos privados):"
echo "   ssh-keygen -t ed25519 -C 'opencode-vps-agent'"
echo "   cat ~/.ssh/id_ed25519.pub"
echo "   (Anade la llave publica a GitHub > Settings > SSH keys)"
echo ""

# ============================================================
# 5. Hardening SSH (desde devadmin)
# ============================================================
echo -e "${YELLOW}[EXTRA] Hardening SSH (como devadmin)${NC}"
echo ""
echo "a) Copia tu llave publica al VPS:"
echo "   ssh-copy-id devadmin@<IP-del-VPS>"
echo ""
echo "b) Editar /etc/ssh/sshd_config:"
echo "   PermitRootLogin no"
echo "   PasswordAuthentication no"
echo "   PubkeyAuthentication yes"
echo ""
echo "c) Reiniciar SSH y activar UFW:"
echo "   systemctl restart ssh"
echo "   ufw allow 22/tcp"
echo "   ufw enable"
echo ""
echo "d) Instalar fail2ban:"
echo "   apt update && apt install fail2ban -y"
echo "   systemctl enable --now fail2ban"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup completo. Reinicia el contenedor${NC}"
echo -e "${GREEN}  para que supervisor inicie todo.${NC}"
echo -e "${GREEN}========================================${NC}"

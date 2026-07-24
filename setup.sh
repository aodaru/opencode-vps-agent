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
# 1. Contrasenas de usuarios (desde .env)
# ============================================================
echo -e "${YELLOW}[1/5] Contrasenas de usuarios (desde .env)${NC}"
echo "Los passwords de devadmin y cloud se definen en .env:"
echo "  DEVADMIN_PASSWORD=<password>"
echo "  CLOUD_PASSWORD=<password>"
echo ""
echo "Se aplican automaticamente al arrancar el contenedor via supervisor"
echo "(set-passwords, priority=2). No es necesario cambiar manualmente."
echo ""
echo "Para actualizar un password sin reiniciar:"
echo "  docker compose exec -it opencode-vps passwd devadmin"
echo "  docker compose exec -it opencode-vps passwd cloud"
echo ""

# ============================================================
# 1b. Validar ownership de /home/cloud/... y /home/devadmin/.ssh
# ============================================================
echo -e "${YELLOW}[1b/5] Validar ownership de /home/cloud/... y /home/devadmin/.ssh${NC}"
echo "Los bind mounts desde ./data/ se crean con la UID del usuario"
echo "del host (truenas_admin en TrueNAS), que no coincide con la UID"
echo "de 'cloud' adentro del contenedor. Esto rompe la escritura."
echo ""
echo "Verificar ownership actual:"
echo "  docker compose exec opencode-vps bash -c '"
echo "    for d in /home/cloud/proyectos \\"
echo "             /home/cloud/.config/opencode \\"
echo "             /home/cloud/.config/gh \\"
echo "             /home/cloud/.local/share/opencode \\"
echo "             /home/cloud/.ssh \\"
echo "             /home/devadmin/.ssh; do"
echo "      stat -c \"%U:%G %n\" \"\$d\""
echo "    done"
echo "  '"
echo ""
echo "Esperado:"
echo "  cloud:cloud       /home/cloud/proyectos"
echo "  cloud:cloud       /home/cloud/.config/opencode"
echo "  cloud:cloud       /home/cloud/.config/gh"
echo "  cloud:cloud       /home/cloud/.local/share/opencode"
echo "  cloud:cloud       /home/cloud/.ssh"
echo "  devadmin:devadmin /home/devadmin/.ssh"
echo ""
echo "Si aparece algo distinto de cloud:cloud (o devadmin:devadmin para"
echo "el ultimo), corregir:"
echo "  docker compose exec -u root opencode-vps chown -R cloud:cloud /home/cloud/"
echo "  docker compose exec -u root opencode-vps chown -R devadmin:devadmin /home/devadmin/.ssh"
echo ""
echo "Nota: el contenedor incluye fix-ownership.sh que corre automaticamente"
echo "al arrancar (supervisor > fix-ownership, priority=1) y corrige esto"
echo "por su cuenta. El chequeo de arriba es solo validacion manual."
echo ""

# ============================================================
# 2. Configurar OpenCode Go (auth.json + env var backup)
# ============================================================
echo -e "${YELLOW}[2/5] Configurar OpenCode Go${NC}"
echo "La fuente de verdad para la auth de opencode-go es"
echo "  ./data/opencode-auth/auth.json"
echo "que sobrevive a 'docker compose down -v'."
echo ""
echo "La env var OPENCODE_API_KEY en .env es OPCIONAL: solo un backup."
echo ""
echo "a) Crear auth.json (PRIMERA VEZ o tras perder ./data/opencode-auth/):"
echo "   1. Ve a https://opencode.ai/auth"
echo "   2. Inicia sesion y copia tu API key de OpenCode Go"
echo "   3. Ejecuta dentro del contenedor como 'cloud':"
echo ""
echo "        docker compose exec -u cloud opencode-vps \\"
echo "          opencode auth login --provider opencode-go"
echo ""
echo "      Cuando pida la API key, pega la que copiaste."
echo ""
echo "   Esto crea ./data/opencode-auth/auth.json. Listo."
echo ""
echo "b) Backup opcional en .env (para restores desde variable):"
echo "   1. Edita .env en el host:"
echo "        OPENCODE_API_KEY=sk-..."
echo "   2. Reinicia:  docker compose restart"
echo ""
echo "   Nota: la env var por si sola NO autentica. opencode lee auth.json"
echo "   primero. La env var se usa como fallback si auth.json no existe."
echo ""

# ============================================================
# 3. Cloudflare Tunnel (en el HOST, no en el contenedor)
# ============================================================
echo -e "${YELLOW}[3/5] Cloudflare Tunnel (HOST)${NC}"
echo ""
echo "El tunnel de Cloudflare se configura en el HOST del VPS,"
echo "no dentro del contenedor. Solo se necesita agregar una"
echo "regla de ingress en el cloudflared config.yml del host"
echo "apuntando a http://127.0.0.1:4096."
echo ""
echo "Para verificar que el tunnel esta activo desde el host:"
echo "  ssh truenas_admin@10.0.5.16 'sudo systemctl status cloudflared'"
echo ""

# ============================================================
# 4. GitHub CLI
# ============================================================
echo -e "${YELLOW}[4/5] Configurar GitHub CLI${NC}"
echo ""
echo "a) Agregar GH_TOKEN al .env del host (PAT fine-grained de GitHub)"
echo ""
echo "b) Autenticar (dentro del contenedor como cloud):"
echo "   echo \"\$GH_TOKEN\" | gh auth login --hostname github.com --git-protocol https --with-token"
echo ""
echo "c) Configurar git:"
echo "   gh auth setup-git"
echo ""
echo "d) Generar SSH key para git push directo:"
echo "   ssh-keygen -t ed25519 -C 'opencode-vps-agent' -f ~/.ssh/id_ed25519_github_opencode"
echo "   cat ~/.ssh/id_ed25519_github_opencode.pub"
echo "   (Anade la publica a GitHub > Settings > SSH keys)"
echo ""

# ============================================================
# 5. Hardening SSH (desde devadmin)
# ============================================================
echo -e "${YELLOW}[5/5] Hardening SSH (como devadmin)${NC}"
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

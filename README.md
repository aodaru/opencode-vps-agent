# OpenCode VPS Agent

Agente OpenCode 24/7 corriendo en un VPS, accesible desde cualquier
dispositivo via navegador gracias a un Cloudflare Tunnel. Pensado para
uso personal como dev playground: el agente sobrevive a que tu maquina
local se duerma, pierda conexion o se apague.

## Caracteristicas

- OpenCode CLI embebido (binario estatico, sin Node.js)
- Web UI servida en el puerto 4096
- Acceso remoto seguro via Cloudflare Tunnel (sin abrir puertos)
- Fallback SSH en el puerto 2222
- Persistencia de auth, config, proyectos y SSH keys en volumenes Docker
- Hardening base: UFW, fail2ban, SSH sin root, sudo no password
- Supervisord gestiona OpenCode Web, cloudflared y sshd

## Stack

- Ubuntu 24.04 LTS (Docker)
- OpenCode + OpenCode Go (model provider)
- Cloudflare Tunnel
- GitHub CLI

## Requisitos

- VPS con Docker + Docker Compose
- Dominio delegado a Cloudflare
- Tunnel creado en Cloudflare (token en `CLOUDFLARE_TUNNEL_TOKEN`)
- API key de OpenCode Go (en `OPENCODE_GO_API_KEY`)

## Uso rapido

1. Clonar y copiar `.env.example` a `.env`:

   ```bash
   cp .env.example .env
   # editar .env con tus secretos reales
   ```

2. Levantar el contenedor:

   ```bash
   docker compose up -d --build
   ```

3. Acceder a la web UI en `https://<tu-hostname>` (HTTP Basic Auth).

## Estructura del repo

- `Dockerfile` - imagen base (Ubuntu 24.04 + opencode + cloudflared + gh)
- `docker-compose.yml` - servicios, puertos y volumenes
- `config/` - opencode.json y cloudflared.yml precargados
- `supervisor/` - supervisord y servicios (opencode-web, sshd)
- `setup.sh` - guia post-arranque (auth, tunnel, GitHub CLI, SSH hardening)
- `specs/` - mission, roadmap, tech-stack
- `AGENTS.md` - contexto completo del proyecto para agentes AI

## Estado del proyecto

Fases completadas:

- Fase 1: Contenedor base
- Fase 2: Autenticacion OpenCode Go + SSH
- Fase 3: Cloudflare Tunnel + acceso remoto

Pendientes: Fase 4 (Git integration), Fase 5 (operacion continua), Fase 6 (post-MVP).
Ver `specs/roadmap.md` para detalles.

## Seguridad

`.env` esta en `.gitignore`. **Nunca** commitees secretos.

Tras el primer arranque del contenedor:

1. **Cambiar las contrasenas por defecto** de los usuarios del contenedor
   (el `Dockerfile` crea `devadmin` y `cloud` con `changeme`):
   ```bash
   docker compose exec -it opencode-vps passwd devadmin
   docker compose exec -it opencode-vps passwd cloud
   ```

2. **Validar ownership de `~/.ssh/`**. El volumen `opencode-ssh` puede
   inicializar `/home/cloud/.ssh` como `root`, lo que rompe
   `ssh-copy-id`. El contenedor incluye un script que corrige esto
   automaticamente al arrancar (`supervisor > ssh-fix-ownership`), pero
   se puede verificar/corrigir manualmente:
   ```bash
   docker compose exec opencode-vps stat -c '%U:%G %n' /home/*/.ssh
   # Esperado:
   #   devadmin:devadmin /home/devadmin/.ssh
   #   cloud:cloud       /home/cloud/.ssh
   # Si aparece 'root', corregir:
   docker compose exec -u root opencode-vps chown -R devadmin:devadmin /home/devadmin/.ssh
   docker compose exec -u root opencode-vps chown -R cloud:cloud /home/cloud/.ssh
   ```

3. Rotar la API key de OpenCode Go y el token de Cloudflare Tunnel.

4. Habilitar autenticacion por clave publica en SSH y deshabilitar password auth.

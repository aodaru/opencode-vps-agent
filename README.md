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
- Persistencia de auth, config, proyectos y SSH keys en **bind mounts a `./data/`** (host filesystem)
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
- API key de OpenCode Go (en `OPENCODE_API_KEY`)

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
- Fase 4: GitHub + git (gh CLI + SSH key + flujo de PRs)
- Fix: Persistencia bind mounts (migracion a `./data/` en host)

- Fase 6: Passwords dinámicos + validación persistencia

Pendiente: Fase 7 (post-MVP).
Ver `specs/roadmap.md` para detalles.

## Persistencia

Toda la data del agente persiste en **bind mounts a `./data/`** en el
host (no en named volumes de Docker). Esto garantiza que sobrevive a
`docker compose down -v` y es respaldable con `tar`.

```bash
# Bootstrap (primera vez)
./scripts/init-data.sh

# Migracion desde named volumes (una sola vez)
./scripts/migrate-volumes.sh

# Backup
tar -czf backup-$(date +%F).tar.gz ./data/
```

Estructura de `./data/`:

| Subdir | Contenido |
|--------|-----------|
| `opencode-auth/` | `auth.json` (opencode-go API key) |
| `opencode-config/` | `opencode.json` (config editable) |
| `gh-config/` | `hosts.yml` (gh CLI auth) |
| `cloudflared/` | Credenciales del tunnel |
| `ssh-cloud/` | SSH keys + `known_hosts` de `cloud` |
| `ssh-devadmin/` | SSH keys de `devadmin` |
| `proyectos/` | Workspace del agente |

> **Bug corregido**: antes el named volume `opencode-config` se montaba
> en dos paths distintos (`~/.config/opencode` y `~/.config/gh`),
> corrompiendo ambas configs. Ahora cada path tiene su propio bind mount.

## Seguridad

`.env` esta en `.gitignore`. **Nunca** commitees secretos.

Tras el primer arranque del contenedor:

1. **Contrasenas de usuarios**: se definen en `.env` via `DEVADMIN_PASSWORD`
   y `CLOUD_PASSWORD`. Se aplican automaticamente al arrancar via supervisor
   (set-passwords, priority=2). Si se omiten, los usuarios quedan con el
   password aleatorio generado en el build.

   Para actualizar un password sin reiniciar:
   ```bash
   docker compose exec -it opencode-vps passwd devadmin
   docker compose exec -it opencode-vps passwd cloud
   ```

2. **Validar ownership de los bind mounts**. Los bind mounts desde
   `./data/` se crean con la UID del usuario del host (ej:
   `truenas_admin`), que no coincide con la UID de `cloud` adentro
   del contenedor. Esto puede romper la escritura de `opencode web` y
   la lectura de `auth.json`. El contenedor incluye
   `fix-ownership.sh` que corrige esto al arrancar
   (`supervisor > fix-ownership`, `priority=1`), pero se puede
   verificar/corrigir manualmente:
   ```bash
   docker compose exec opencode-vps bash -c '
     for d in /home/cloud/proyectos \
              /home/cloud/.config/opencode \
              /home/cloud/.config/gh \
              /home/cloud/.local/share/opencode \
              /home/cloud/.cloudflared \
              /home/cloud/.ssh \
              /home/devadmin/.ssh; do
       stat -c "%U:%G %n" "$d"
     done
   '
   # Esperado:
   #   cloud:cloud       /home/cloud/proyectos
   #   cloud:cloud       /home/cloud/.config/opencode
   #   cloud:cloud       /home/cloud/.config/gh
   #   cloud:cloud       /home/cloud/.local/share/opencode
   #   cloud:cloud       /home/cloud/.cloudflared
   #   cloud:cloud       /home/cloud/.ssh
   #   devadmin:devadmin /home/devadmin/.ssh
   # Si algo aparece con owner distinto:
   docker compose exec -u root opencode-vps chown -R cloud:cloud /home/cloud/
   docker compose exec -u root opencode-vps chown -R devadmin:devadmin /home/devadmin/.ssh
   ```

3. **Confirmar que `opencode-web` corre como `cloud`**. Es el
   usuario correcto (no root). Esto es importante porque cualquier
   archivo creado en `/home/cloud/proyectos/` debe ser de `cloud`,
   no de root:
   ```bash
   docker compose exec opencode-vps bash -c '
     PID=$(pgrep -f "opencode web")
     ps -o user,pid,cmd -p $PID
     readlink /proc/$PID/cwd
   '
   # Esperado:
   #   cloud  ...  /usr/local/bin/opencode web ...
   #   /home/cloud/proyectos
   ```

4. Rotar la API key de OpenCode Go y el token de Cloudflare Tunnel.

5. Habilitar autenticacion por clave publica en SSH y deshabilitar password auth.

# Roadmap

Fases pequeñas y secuenciales. Cada fase debe funcionar de forma
independiente antes de pasar a la siguiente.

---

## Fase 1: Contenedor base

- [x] Limpiar Dockerfile: quitar cloudflared, supervisor, cloudflared.yml
- [x] CMD directo: `opencode web --hostname 0.0.0.0 --port 4096`
- [x] docker-compose.yml: agregar `4096:4096` (sin binding de IP)
- [x] Crear `.env` para contraseñas (quitar del compose)
- [x] `.gitignore`: excluir `.env`
- [x] Build + smoke test local

**Criterio de éxito:** `docker compose up -d` arranca y `opencode web`
responde en `localhost:4096` dentro del contenedor. ✅

---

## Fase 2: Autenticación OpenCode Go

- [x] Instalar `openssh-server` en el contenedor
- [x] Configurar `sshd_config` para permitir autenticación por contraseña
- [x] Agregar `supervisor/sshd.conf` para gestionar sshd
- [x] Agregar `OPENCODE_API_KEY` al `.env` (renombrada de `OPENCODE_GO_API_KEY`
      en `fix/persistencia-bind-mounts`)
- [x] Inyectar `OPENCODE_API_KEY` al contenedor via docker-compose
- [x] Ejecutar `opencode auth login --provider opencode-go`
- [x] Obtener API key de https://opencode.ai/auth
- [x] Verificar que los modelos Go aparecen en `/models`
- [x] Verificar que `/init` funciona en un proyecto

**Criterio de éxito:** OpenCode responde con un modelo Go y puede analizar
un proyecto. ✅

---

## Fase 3: Tunnel + acceso remoto

- [x] Cloudflared dentro del contenedor con token (no credentials-file)
- [x] Protocolo HTTP/2 para evitar problemas QUIC en Docker
- [x] Verificar acceso desde browser externo (móvil, otra red)
- [x] Confirmar que `OPENCODE_SERVER_PASSWORD` protege el acceso

**Criterio de éxito:** Se puede acceder a OpenCode desde el celular vía
`https://opencode.adalgarcia.com`. ✅

---

## Fase 4: GitHub + git

- [x] `gh auth login` (flujo headless con código)
- [x] `gh auth setup-git`
- [x] Generar SSH key: `ssh-keygen -t ed25519`
- [x] Agregar llave pública a GitHub
- [x] Probar: clonar repo privado + crear PR

**Criterio de éxito:** El agente puede clonar repos privados y crear PRs
sin intervención manual. ✅

---

## Fix: Persistencia bind mounts

- [x] **Grupo 1: Scripts de bootstrap**
  - [x] `scripts/init-data.sh` (idempotente, crea los 7 subdirs + siembra `opencode.json`)
  - [x] `scripts/migrate-volumes.sh` (one-shot, migra named volumes + inspecciona bug)
  - [x] Idempotencia validada
- [x] **Grupo 2: Refactor `docker-compose.yml`**
  - [x] 7 bind mounts a `./data/...` (sin sección `volumes:` final)
  - [x] Rename `OPENCODE_GO_API_KEY` → `OPENCODE_API_KEY` en `environment:`
  - [x] `docker compose config` sin errores
- [x] **Grupo 3: Rename de env var** (`.env`, `.env.example`, `supervisor/opencode-web.conf`)
- [x] **Grupo 4: `.gitignore`** — agregado `data/`
- [x] **Grupo 5: `setup.sh`** — sección [2/5] reescrita (auth.json + env var opcional)
- [x] **Grupo 6: Documentación** — `AGENTS.md`, `README.md`, `specs/tech-stack.md` actualizados
- [x] **Grupo 7: Validación destructiva end-to-end** ✅
  - [x] PR #2 mergeado a `main` via `gh pr merge --merge --delete-branch`
- [x] **Grupo 8: Merge** ✅
  - [x] Branch `fix/persistencia-bind-mounts` pusheado y mergeado
  - [x] Cleanup local hecho

**Criterio de éxito:** Test destructivo pasa + PR mergeado a `main`. ✅

---

## Fix: usuario cloud + workdir proyectos

`opencode-web` corre como `root` en lugar de `cloud`, y los bind
mounts desde `./data/` (creados con la UID del host) no coinciden
con la UID de `cloud` adentro del contenedor, por lo que `cloud` no
puede escribir en su propio workspace.

- [x] **Grupo 1: `user=cloud` en supervisor**
  - [x] `supervisor/opencode-web.conf` con `user=cloud`
  - [x] `directory=/home/cloud/proyectos` (sin cambios)
- [x] **Grupo 2: Extender `fix-ownership.sh`**
  - [x] `scripts/fix-ownership.sh` reemplaza al viejo `fix-ssh-ownership.sh`
  - [x] Cubre los 7 paths bind-mountados (proyectos, configs, auth, cloudflared, ssh)
  - [x] `supervisor/fix-ownership.conf` reemplaza a `ssh-fix-ownership.conf`
- [x] **Grupo 3: Dockerfile actualizado** (COPY del nuevo script + conf)
- [x] **Grupo 4: `setup.sh` actualizado** — sección [1b/5] lista todos los paths
- [x] **Grupo 5: Documentación** — `AGENTS.md`, `README.md` actualizados
- [x] **Grupo 6: Spec nueva** — `specs/2026-07-06-fix-usuario-cloud-workdir-proyectos/`
- [x] **Grupo 7: Validación en VPS** ✅
  - [x] PR #3 mergeado a `main`
  - [x] `ps -o user` muestra `cloud` para el proceso opencode-web
  - [x] `readlink /proc/<pid>/cwd` muestra `/home/cloud/proyectos`
  - [x] Ownership correcto en los 7 paths
  - [x] Test destructivo (`down -v && up -d`) pasa

**Criterio de éxito:** Proceso corre como `cloud`, cwd correcto, ownership
de los 7 paths consistente, test destructivo pasa, PR mergeado a `main`. ✅

---

## Fase 5: Operación continua

- [x] Healthcheck en docker-compose (curl cada 30s)
- [x] Verificar logs: `docker compose logs -f` (Docker captura stdout/stderr)
- [x] Script de backup: `./scripts/backup-data.sh` (backup con timestamp + rotación)
- [x] `restart: unless-stopped` confirmado

**Criterio de éxito:** El contenedor sobrevive reinicios del host y los
volúmenes se pueden respaldar. ✅

---

## Fase 6 (post-MVP)

- [ ] Multi-agente (distintos proyectos/configs)
- [ ] CI/CD pipeline para actualizar OpenCode
- [ ] Alertas de uptime (UptimeRobot, Healthchecks.io)
- [ ] Backups automáticos programados
- [ ] Rotación de contraseñas y API keys

---

## Estado actual

| Fase | Estado |
|------|--------|
| Fase 1: Contenedor base | ✅ Completada |
| Fase 2: Autenticación | ✅ Completada |
| Fase 3: Tunnel | ✅ Completada |
| Fase 4: GitHub + git | ✅ Completada |
| Fix: Persistencia bind mounts | ✅ Completada (PR #2 mergeado) |
| Fix: usuario cloud + workdir proyectos | ✅ Completada (PR #3 mergeado) |
| Fase 5: Operación | ✅ Completada |
| Fase 6: Post-MVP | ⬜ Pendiente |

---

## Notas de implementación

### Configuración actual
- **Servidor**: VPS `10.0.5.16` (TrueNAS / FreeBSD)
- **Usuario SSH**: `truenas_admin` con key `~/.ssh/id_ed25519_github`
- **Directorio**: `~/opencode-vps/`
- **Password web**: `OPENCODE_SERVER_PASSWORD` en `.env`
- **Tunnel**: Cloudflare token-based (no credentials-file)
- **URL**: `https://opencode.adalgarcia.com`

### Cambios realizados al Dockerfile
- Agregado `xdg-utils` para evitar crash de opencode web
- Binario `opencode` copiado a `/usr/local/bin/` para acceso global
- `supervisor` gestiona `opencode-web` + `cloudflared`

### Cambios realizados al compose
- Eliminado campo `version` (obsoleto en Docker Compose v2)
- Secretos externalizados a `.env` via `${VAR}` syntax
- Puerto `4096:4096` expuesto sin binding de IP (cloudflared necesita acceso)
- Puerto `2222:22` mapeado como fallback SSH

### Cambios realizados al supervisor
- Cloudflared usa `%(ENV_CLOUDFLARE_TUNNEL_TOKEN)s` desde variable de entorno
- Protocolo HTTP/2 forzado (`--protocol http2`) para evitar problemas QUIC en Docker
- `xdg-open` dummy creado para evitar crash de opencode web
- `HOME="/home/cloud"` en environment de opencode-web (supervisord no setea HOME
  automáticamente al usar `user=cloud`, causaba `EACCES` al escribir en `/root/`)

### Notas importantes
- Username por defecto para HTTP Basic Auth: `opencode`
- Cambiable con `OPENCODE_SERVER_USERNAME` en `.env`
- Cloudflared dentro del contenedor (no en el host) con token
- Dashboard de Cloudflare apunta a `http://127.0.0.1:4096` (IPv4, no localhost)

### Cambios realizados en Fase 4 (GitHub + git)
- `gh` CLI instalado en Dockerfile
- `fix-ownership.sh` reemplaza al viejo `fix-ssh-ownership.sh`
- SSH key del agente: `id_ed25519_github_opencode` (con passphrase +
  `ssh-agent`)
- PAT fine-grained en `.env` con scopes mínimos (Contents, Pull requests,
  Metadata), inyectado al contenedor como `GH_TOKEN`
- Flujo dual: HTTPS via `gh` (para `gh` subcommands) + SSH (para
  `git push/pull` directo)

### Cambios en fix/persistencia-bind-mounts (completado)
- Migración de named volumes a bind mounts en `./data/`
- Bug corregido: `opencode-config` se usaba para dos paths distintos
- Scripts: `init-data.sh` (bootstrap) + `migrate-volumes.sh` (one-shot)
- Ver spec: `specs/2026-07-05-fix-persistencia-bind-mounts/`

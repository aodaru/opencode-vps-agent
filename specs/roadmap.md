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
- [x] Agregar `OPENCODE_GO_API_KEY` al `.env`
- [x] Inyectar `OPENCODE_GO_API_KEY` al contenedor via docker-compose
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

- [ ] `gh auth login` (flujo headless con código)
- [ ] `gh auth setup-git`
- [ ] Generar SSH key: `ssh-keygen -t ed25519`
- [ ] Agregar llave pública a GitHub
- [ ] Probar: clonar repo privado + crear PR

**Criterio de éxito:** El agente puede clonar repos privados y crear PRs
sin intervención manual.

---

## Fase 5: Operación continua

- [ ] Healthcheck en docker-compose
- [ ] Verificar logs: `docker compose logs -f`
- [ ] Script de backup de volúmenes
- [ ] `restart: unless-stopped` confirmado

**Criterio de éxito:** El contenedor sobrevive reinicios del host y los
volúmenes se pueden respaldar.

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
| Fase 4: GitHub | ⬜ Pendiente |
| Fase 5: Operación | ⬜ Pendiente |
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

### Notas importantes
- Username por defecto para HTTP Basic Auth: `opencode`
- Cambiable con `OPENCODE_SERVER_USERNAME` en `.env`
- Cloudflared dentro del contenedor (no en el host) con token
- Dashboard de Cloudflare apunta a `http://127.0.0.1:4096` (IPv4, no localhost)

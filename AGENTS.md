# OpenCode VPS Agent - AGENTS.md

## Misión

Desplegar un agente OpenCode 24/7 en un VPS, accesible desde cualquier dispositivo (móvil, tablet, laptop) mediante web browser, sin depender del estado de la máquina local.

### Audiencia objetivo
- Uso personal (dev playground)
- Un solo desarrollador: @adalgarcia
- Proyectos personales accesibles remoto

### Problema que resuelve
La máquina local se suspende, pierde conectividad, o simplemente se apaga. Con OpenCode en un VPS:
- El agente está siempre disponible
- Las sesiones persisten entre reinicios
- Se puede acceder desde el celular en cualquier momento
- No se pierde progreso en refactorizaciones o migraciones largas

### Contexto técnico
Adaptado de una guía original de Claude Code a OpenCode, aprovechando:
- **Cloudflare Tunnel** existente en el host (sin abrir puertos)
- **Docker Compose** para aislamiento y reproducibilidad
- **OpenCode Go** como proveedor de modelos (bajo costo, alta confiabilidad)

---

## Servidor de Implementación

| Parámetro | Valor |
|-----------|-------|
| IP del VPS | `10.0.5.16` |
| Usuario SSH | `truenas_admin` |
| SSH Key | `~/.ssh/id_ed25519_github` |
| SO Host | TrueNAS (FreeBSD) |

### Conexión SSH
```bash
ssh -i ~/.ssh/id_ed25519_github truenas_admin@10.0.5.16
```

---

## Fases del Proyecto

| Fase | Estado |
|------|--------|
| Fase 1: Contenedor base | ✅ Completada |
| Fase 2: Autenticación OpenCode Go | ✅ Completada |
| Fase 3: Tunnel + acceso remoto | ✅ Completada |
| Fase 4: GitHub + git | ✅ Completada |
| Fix: Persistencia bind mounts | ✅ Completada |
| Fix: usuario cloud + workdir proyectos | ✅ Completada |
| Fase 5: Operación continua | ✅ Completada |
| Chore: ffmpeg | ✅ Completada |
| Fase 6: Passwords dinámicos + persistencia | ✅ Completada |
| Fase 7: Post-MVP | ⬜ Pendiente |

## Persistencia en host (`~/opencode-vps/data/`)

Toda la data del agente persiste en **bind mounts a `./data/`** en el
host, no en named volumes de Docker. Esto garantiza que **sobrevive a
`docker compose down -v`** y es respaldable con `tar -czf backup.tar.gz ./data/`.

| Subdir en `./data/` | Ruta en contenedor | Contenido |
|---------------------|-------------------|-----------|
| `opencode-auth/` | `/home/cloud/.local/share/opencode/` | `auth.json` (opencode-go API key) |
| `opencode-config/` | `/home/cloud/.config/opencode/` | `opencode.json` (editable) |
| `gh-config/` | `/home/cloud/.config/gh/` | `hosts.yml` (gh CLI auth) |
| `cloudflared/` | `/home/cloud/.cloudflared/` | Credenciales del tunnel |
| `ssh-cloud/` | `/home/cloud/.ssh/` | SSH keys + `known_hosts` de cloud |
| `ssh-devadmin/` | `/home/devadmin/.ssh/` | SSH keys de devadmin |
| `proyectos/` | `/home/cloud/proyectos/` | Workspace del agente |

Bootstrap: `./scripts/init-data.sh` (idempotente). Migración desde
named volumes antiguos: `./scripts/migrate-volumes.sh` (one-shot).

### Usuario y workdir del agente

El servicio `opencode-web` (gestionado por supervisord) corre como:

- **Usuario**: `cloud` (NO root)
- **Working directory**: `/home/cloud/proyectos`

Esto está definido en `supervisor/opencode-web.conf` con
`user=cloud` + `directory=/home/cloud/proyectos`. El proceso es hijo
de supervisord, que corre como root para poder gestionar los procesos
y para correr `fix-ownership.sh` (ver abajo).

### Corrección automática de ownership

`scripts/fix-ownership.sh` corre al arrancar el contenedor
(`supervisor > fix-ownership`, `priority=1`, antes que
`opencode-web` y `cloudflared`). Corrige el ownership de todos los
paths bind-mountados para que coincidan con el UID de `cloud` y
`devadmin` adentro del contenedor (resuelve el problema de UID
mismatch entre el host y el contenedor).

Cubre: `/home/cloud/proyectos`, `/home/cloud/.config/opencode`,
`/home/cloud/.config/gh`, `/home/cloud/.local/share/opencode`,
`/home/cloud/.cloudflared`, `/home/cloud/.ssh` y
`/home/devadmin/.ssh`.

---

## Stack Tecnológico

| Componente | Tecnología |
|------------|-----------|
| SO host | Ubuntu 24.04 LTS (VPS) |
| Contenedor | Docker + Docker Compose |
| Agente | OpenCode (binario estático) |
| Provider | OpenCode Go ($10/mes) |
| Tunnel | Cloudflare Tunnel (en el HOST) |
| CLI GitHub | gh |

---

## Arquitectura

```
HOST (VPS 10.0.5.16)           CONTENEDOR
─────────────────────────         ────────────────────────
SSH (port 22)                     opencode web
cloudflared (tunnel existente)    → expone :4096
  ├─ servicio A                   →        otro servicio
  └─ opencode.adalgarcia.com      → 4096   OpenCode Web UI
```

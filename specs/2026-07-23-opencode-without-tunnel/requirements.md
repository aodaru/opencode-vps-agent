# Requirements — Remover Cloudflare Tunnel

## Contexto

El proyecto original asumía Cloudflare Tunnel dentro del contenedor
para acceso remoto. En la práctica, el tunnel ya existe en el HOST
del VPS y no es necesario tener cloudflared dentro del contenedor.
Esto simplifica el build, reduce la superficie de ataque y elimina
la dependencia del token de Cloudflare en el `.env`.

## Scope (qué se hace)

- Remover cloudflared del Dockerfile (instalación + binario)
- Remover cloudflared del supervisor (opencode-web.conf → sección cloudflared)
- Eliminar `config/cloudflared.yml`
- Eliminar bind mount `./data/cloudflared/` del docker-compose
- Eliminar `CLOUDFLARE_TUNNEL_TOKEN` del `.env`, `.env.example` y compose
- Eliminar referencia a cloudflared en `scripts/fix-ownership.sh`
- Eliminar referencia a cloudflared en `scripts/init-data.sh`
- Actualizar `setup.sh` (sección 3 de tunnel)
- Actualizar `README.md`, `AGENTS.md`, `specs/roadmap.md`,
  `specs/tech-stack.md`, `specs/mission.md`
- Dejar el puerto `4096:4096` expuesto (acceso directo a OpenCode Web UI)
- Mantener `fix-ownership.sh` pero sin la línea de `.cloudflared`

## Scope negativo (qué NO se hace)

- No se cambia la arquitectura de red del host
- No se toca el tunnel de Cloudflare en el host
- No se modifica SSH, supervisor, ni opencode-web
- No se agregan nuevas features

## Decisiones

| Decisión | Opción elegida | Alternativa |
|----------|---------------|-------------|
| Puerto 4096 | Mantener expuesto (`4096:4096`) | Cerrarlo (solo acceso local) |
| Rama snapshot | `opencode-cloudflare-tunnel` persistente | — |
| Rama feature | `2026-07-23-opencode-without-tunnel` → merge a `main` | — |

## Archivos afectados

- `Dockerfile` (líneas 44-48: cloudflared install; línea 1: comentario)
- `docker-compose.yml` (línea 11: env var; línea 36: bind mount)
- `.env.example` (líneas 17-18)
- `config/cloudflared.yml` (ELIMINAR)
- `supervisor/opencode-web.conf` (sección [program:cloudflared], líneas 15-26)
- `scripts/fix-ownership.sh` (línea 117)
- `scripts/init-data.sh` (línea 34)
- `setup.sh` (sección 3 completa)
- `README.md` (múltiples referencias)
- `AGENTS.md` (múltiples referencias)
- `specs/roadmap.md` (Fase 3, notas)
- `specs/tech-stack.md` (tabla, arquitectura)
- `specs/mission.md` (contexto técnico)

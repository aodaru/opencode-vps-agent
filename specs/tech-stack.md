# Stack Tecnológico

| Componente | Tecnología | Versión / Detalle |
|------------|-----------|-------------------|
| SO host    | Ubuntu    | 24.04 LTS (VPS) |
| Contenedor | Docker + Docker Compose | última estable |
| Agente     | OpenCode  | binario estático (último release) |
| Provider   | OpenCode Go | suscripción $10/mes |
| Tunnel     | Cloudflare Tunnel | cloudflared (instalado en el HOST) |
| CLI GitHub | gh        | última estable |
| Shell      | bash + tmux | — |
| SSH        | openssh-server | dentro del contenedor |

## Arquitectura

```
HOST (VPS)                          CONTENEDOR
─────────────────────────           ────────────────────────
SSH (port 22)                       opencode web
cloudflared (tunnel existente)      → expone :4096
  ├─ servicio A                     →        otro servicio
  └─ opencode.tudominio.com         → 4096   OpenCode Web UI
```

## Decisiones técnicas

### Binario estático (no Node.js)

Se usa el instalador oficial (`curl .../install | bash`) que descarga un
binario autocontenido. No requiere Node.js, Bun ni npm en el contenedor.

### Cloudflare Tunnel en el HOST

El tunnel ya existe y se usa para otros servicios. No se instala cloudflared
dentro del contenedor. Solo se agrega una regla de ingress al `config.yml`
del host apuntando a `http://127.0.0.1:4096`.

### Docker Compose

Un solo servicio con **bind mounts a `./data/`** en el host para
persistencia. Esto reemplaza los named volumes (que se borraban con
`docker compose down -v` y no eran respaldables directamente).

> Ver spec `specs/2026-07-05-fix-persistencia-bind-mounts/` para el
> detalle del refactor.

## Variables de entorno

| Variable | Propósito |
|----------|-----------|
| `OPENCODE_SERVER_PASSWORD` | Autenticación web (HTTP Basic Auth) |
| `OPENCODE_CONFIG` | Ruta al archivo de configuración |
| `OPENCODE_API_KEY` | API key de OpenCode Go (provider). Renombrada de `OPENCODE_GO_API_KEY` (el nombre original no coincidía con el que opencode-go busca según models.dev) |
| `CLOUDFLARE_TUNNEL_TOKEN` | Token del tunnel de Cloudflare |
| `GH_TOKEN` | PAT de GitHub para `gh auth login` |

## Directorios persistentes

Bind mounts a `./data/` en el host (no son named volumes):

| Subdir en `./data/` | Ruta en contenedor | Contenido |
|---------------------|-------------------|-----------|
| `opencode-auth/` | `/home/cloud/.local/share/opencode/` | `auth.json` (opencode-go API key) |
| `opencode-config/` | `/home/cloud/.config/opencode/` | `opencode.json` (editable) |
| `gh-config/` | `/home/cloud/.config/gh/` | `hosts.yml` (gh CLI auth) |
| `cloudflared/` | `/home/cloud/.cloudflared/` | Credenciales del tunnel |
| `ssh-cloud/` | `/home/cloud/.ssh/` | SSH keys + `known_hosts` de cloud |
| `ssh-devadmin/` | `/home/devadmin/.ssh/` | SSH keys de devadmin |
| `proyectos/` | `/home/cloud/proyectos/` | Workspace del agente |

> **Nota sobre el bug corregido**: antes de este fix, el named volume
> `opencode-config` se montaba en dos paths distintos (`~/.config/opencode`
> y `~/.config/gh`), corrompiendo ambas configs. Ahora cada path tiene su
> propio bind mount.

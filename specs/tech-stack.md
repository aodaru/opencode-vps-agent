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

Un solo servicio con volúmenes nombrados para persistencia:

- `opencode-auth` → API keys y sesiones
- `opencode-config` → configuración de OpenCode
- `opencode-proyectos` → código fuente
- `opencode-ssh` → llaves SSH para GitHub

## Variables de entorno

| Variable | Propósito |
|----------|-----------|
| `OPENCODE_SERVER_PASSWORD` | Autenticación web (HTTP Basic Auth) |
| `OPENCODE_CONFIG` | Ruta al archivo de configuración |

## Directorios persistentes

| Volumen | Ruta en contenedor | Contenido |
|---------|-------------------|-----------|
| `opencode-auth` | `/home/cloud/.local/share/opencode/` | API keys, sesiones |
| `opencode-config` | `/home/cloud/.config/opencode/` | opencode.json |
| `opencode-proyectos` | `/home/cloud/proyectos/` | Código fuente |
| `opencode-ssh` | `/home/cloud/.ssh/` | Llaves SSH para GitHub |

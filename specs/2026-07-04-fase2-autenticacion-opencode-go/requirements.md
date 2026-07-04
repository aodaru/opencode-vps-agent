# Requisitos - Fase 2: Autenticación OpenCode Go

## Alcance

Configurar la autenticación con el provider **OpenCode Go** (suscripción $10/mes) para que el agente OpenCode en el VPS pueda utilizar modelos Go. Además, instalar SSH dentro del contenedor para acceso directo.

### Incluido
- Instalación de `openssh-server` en el contenedor
- Configuración de SSH con autenticación por contraseña
- Configuración de API key de OpenCode Go como variable de entorno
- Inyección de la API key al contenedor Docker
- Verificación de que los modelos Go están disponibles
- Smoke test básico de autenticación

### No incluido
- Soporte multi-provider (solo OpenCode Go)
- Fallback a otros providers
- Healthcheck automatizado de autenticación (se deja para Fase 5)

## Decisiones

| Decisión | Racional |
|----------|----------|
| `openssh-server` dentro del contenedor | El mapeo `2222:22` del compose no funcionaba sin SSH interno |
| API key como variable de entorno (`OPENCODE_GO_API_KEY`) | Coherente con el patrón de `.env` ya establecido en Fase 1 |
| Solo OpenCode Go | Un solo developer, un solo provider, simplicidad |
| Smoke test básico | Validación suficiente para MVP; healthchecks automatizados en Fase 5 |

## Contexto

- **Servidor**: VPS `172.9.30.113`
- **Directorio de trabajo**: `~/opencode-vps/`
- **Contenedor**: Docker Compose con servicio único
- **Provider**: OpenCode Go ($10/mes)
- **URL de autenticación**: https://opencode.ai/auth
- **Puerto expuesto**: `4096` (accesible vía Cloudflare Tunnel)
- **Puerto SSH**: `2222:22` (mapeado al SSH interno del contenedor)

### Variables de entorno existentes
- `OPENCODE_SERVER_PASSWORD` - HTTP Basic Auth para la web UI
- `OPENCODE_CONFIG` - Ruta al archivo de configuración
- `CLOUDFLARE_TUNNEL_TOKEN` - Token del tunnel de Cloudflare

### Nuevas variables
- `OPENCODE_GO_API_KEY` - API key del provider OpenCode Go

### Usuarios SSH
- `devadmin` - usuario con sudo, contraseña `changeme`
- `cloud` - usuario agente, sin sudo, contraseña `changeme`

## Dependencias

- **Fase 1**: Contenedor base funcionando (✅ completada)
- **Fase 3**: Tunnel + acceso remoto (✅ completada, no bloquea esta fase)

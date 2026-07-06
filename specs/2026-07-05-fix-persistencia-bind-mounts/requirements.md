# Requisitos - Refactor de persistencia: bind mounts en host

## Alcance

Migrar la persistencia del contenedor `opencode-vps` de Docker named volumes
a bind mounts en el host filesystem, de modo que **toda la data del agente
sobreviva a `docker compose down -v`**. Además, corregir el bug donde el
mismo named volume (`opencode-config`) se usaba para dos paths distintos
en el contenedor, y renombrar la env var `OPENCODE_GO_API_KEY` a
`OPENCODE_API_KEY` (nombre que opencode-go espera según models.dev).

### Incluido

- Reemplazar los 5 named volumes por bind mounts a `./data/` en el host
- Crear `scripts/init-data.sh` para inicializar `./data/` con permisos
  correctos
- Crear `scripts/migrate-volumes.sh` para migrar contenido de named
  volumes existentes a `./data/`
- Corregir bug: `opencode-config` se montaba en `/home/cloud/.config/opencode`
  Y en `/home/cloud/.config/gh` (mismo volumen, paths distintos)
- Agregar persistencia para `/home/devadmin/.ssh` (no estaba en ningún
  volumen)
- Renombrar env var `OPENCODE_GO_API_KEY` → `OPENCODE_API_KEY` en todos
  los archivos que la referencian
- Hacer que `auth.json` (creado por `opencode auth login`) sea la fuente
  de verdad para la auth de opencode-go
- Actualizar `setup.sh` para reflejar el nuevo flujo (auth.json primero,
  env var como backup)
- Actualizar `AGENTS.md`, `README.md`, `specs/tech-stack.md` con la nueva
  estructura
- Validación destructiva: `docker compose down -v && up` y verificar que
  todo persiste

### No incluido

- Script de backup automático (Fase 5)
- Rotación programada de secrets (Fase 6)
- Migración de git history (no relevante, los named volumes no estaban
  en git)
- Cambio de provider (sigue siendo opencode-go)
- Cambio de puerto o configuración de red
- Healthcheck automatizado (Fase 5)
- Sincronización automática de `config/opencode.json` (repo) →
  `./data/opencode-config/opencode.json` (host). Una vez sembrado en el
  host, se considera "fork local" editable.

## Decisiones

| ID  | Decisión                                          | Racional                                                                                              | Alternativa descartada                  |
| --- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------- |
| D1  | Bind mounts a `./data/` en lugar de named volumes | Visibles, respaldables con `tar`, sobreviven a `docker compose down -v`. El usuario explícitamente pidió esto. | Named volumes (default Docker, pero frágiles) |
| D2  | Estructura `./data/{opencode-auth,opencode-config,gh-config,cloudflared,ssh-cloud,ssh-devadmin,proyectos}` | Un subdir por cada path del contenedor. Explícito, fácil de mapear. | Montar el home completo (oculta archivos del image) |
| D3  | `init-data.sh` copia `config/opencode.json` desde el repo a `./data/opencode-config/` | El bind mount oculta el archivo del image. Hay que sembrar el host con la config actual. | Dejar `./data/opencode-config/` vacío (rompe opencode) |
| D4  | `migrate-volumes.sh` solo copia, no borra named volumes originales | El usuario debe confirmar manualmente que la migración funcionó antes de borrar volúmenes. Más seguro. | Borrar volúmenes inmediatamente (riesgoso) |
| D5  | Separación manual de `opencode.json` (opencode) vs `hosts.yml` (gh) en `./data/opencode-config/` | El bug del volumen duplicado mezcló los archivos. El script no puede saber cuál es cuál sin heurísticas. | Asumir heurística (frágil) |
| D6  | Rename `OPENCODE_GO_API_KEY` → `OPENCODE_API_KEY` | OpenCode busca `OPENCODE_API_KEY` en env (no `OPENCODE_GO_API_KEY`, según API de models.dev). El nombre actual es incorrecto. | Mantener el nombre viejo (sigue roto) |
| D7  | `auth.json` como fuente principal; env var como backup opcional | `auth.json` persiste en `./data/opencode-auth/` y sobrevive a `down -v`. La env var solo se usa si `auth.json` no existe. | Solo env var (pierde auth al recrear contenedor si OPENCODE_API_KEY no está seteado) |
| D8  | Rama base: `main`, nombre: `fix/persistencia-bind-mounts` | Es un fix de bug + refactor, no una nueva fase. | Crear rama desde `fase2-...` (stale branch) |

## Contexto

### Servidor y stack (sin cambios)

- **Servidor**: VPS `10.0.5.16` (TrueNAS / FreeBSD)
- **Directorio de trabajo en VPS**: `~/opencode-vps/`
- **Contenedor**: Docker Compose con servicio único (`opencode-vps`)
- **URL web**: `https://opencode.adalgarcia.com`

### Bug encontrado durante la fase

**Bug**: en `docker-compose.yml` línea 23, el mismo named volume
`opencode-config` se usaba para dos paths distintos:

```yaml
- opencode-config:/home/cloud/.config/opencode   # línea 21
- opencode-config:/home/cloud/.config/gh         # línea 23
```

Docker no permite montar el mismo volume en dos paths distintos sin
solapamiento. El contenido escrito en uno aparece en el otro. Esto
corrompe la config de `opencode` y la de `gh` cuando se usan ambos.

**Fix**: cada path tiene su propio bind mount a `./data/`.

### Estado actual de la persistencia (antes del fix)

| Named volume | Mount path | Estado |
|--------------|-----------|--------|
| `opencode-auth` | `/home/cloud/.local/share/opencode` | ✅ Persiste |
| `opencode-config` | `/home/cloud/.config/opencode` | ⚠️ Compartido con `gh` (bug) |
| `opencode-config` | `/home/cloud/.config/gh` | ⚠️ Compartido con opencode (bug) |
| `opencode-tunnel` | `/home/cloud/.cloudflared` | ✅ Persiste |
| `opencode-proyectos` | `/home/cloud/proyectos` | ✅ Persiste |
| `opencode-ssh` | `/home/cloud/.ssh` | ✅ Persiste, pero solo `cloud` |
| (ninguno) | `/home/devadmin/.ssh` | ❌ NO persiste |

### Estado objetivo (después del fix)

| Bind mount | Contenido |
|------------|-----------|
| `./data/opencode-auth` → `/home/cloud/.local/share/opencode` | `auth.json` (opencode-go API key) |
| `./data/opencode-config` → `/home/cloud/.config/opencode` | `opencode.json` (editable) |
| `./data/gh-config` → `/home/cloud/.config/gh` | `hosts.yml` (gh auth) |
| `./data/cloudflared` → `/home/cloud/.cloudflared` | Tunnel credentials |
| `./data/ssh-cloud` → `/home/cloud/.ssh` | SSH keys + `known_hosts` de cloud |
| `./data/ssh-devadmin` → `/home/devadmin/.ssh` | SSH keys de devadmin (NUEVO) |
| `./data/proyectos` → `/home/cloud/proyectos` | Workspace del agente |

### Variables de entorno

**Existentes** (sin cambios):

- `OPENCODE_SERVER_PASSWORD` - HTTP Basic Auth
- `CLOUDFLARE_TUNNEL_TOKEN` - Tunnel de Cloudflare
- `GH_TOKEN` - PAT de GitHub

**Renombrada** (esta fase):

- `OPENCODE_GO_API_KEY` → `OPENCODE_API_KEY` (6 archivos a actualizar)

### Auth flow (después del fix)

1. **Primera vez** (o tras `docker compose down -v` sin `./data/opencode-auth/`):
   ```bash
   docker compose exec -u cloud opencode-vps \
     opencode auth login --provider opencode-go
   # pegar API key
   ```
   Esto crea `./data/opencode-auth/auth.json`.

2. **Reinicios normales**: `auth.json` se lee del bind mount. No requiere
   re-autenticar.

3. La env var `OPENCODE_API_KEY` queda como backup opcional. Si en el
   futuro se quiere automatizar la creación de `auth.json` desde la env
   var al primer arranque, se puede agregar un script (no en este PR).

## Dependencias

- **Fase 1**: Contenedor base funcionando (✅)
- **Fase 2**: `opencode-go` provider configurado (✅, parcialmente roto
  por env var mal nombrada — este fix lo corrige)
- **Fase 3**: Tunnel + acceso remoto (✅, no afecta este fix)
- **Fase 4**: `gh` CLI + SSH keys (✅, afectado por el bug del volumen
  duplicado)

## Riesgos identificados

| Riesgo                                                  | Mitigación                                                                 |
| ------------------------------------------------------- | -------------------------------------------------------------------------- |
| Bug del `opencode-config` mezcló archivos de opencode y gh; al migrar, pueden estar entrelazados | `migrate-volumes.sh` lista el contenido del volume y pide separación manual |
| Permisos de archivos en `./data/` no coinciden con los del contenedor | `init-data.sh` setea `chmod 700` para SSH dirs; `fix-ssh-ownership.sh` (existente) corrige al arrancar |
| `init-data.sh` copia `opencode.json` antiguo, sin updates futuros | Documentar en `setup.sh` y AGENTS.md que para cambios de config hay que editar `./data/opencode-config/opencode.json` y reiniciar |
| Olvidar commitear `data/` o `.env` por error            | `.gitignore` excluye ambos; checklist en Grupo 8 de `plan.md`            |
| El `opencode.json` del repo se desincroniza con el de `./data/opencode-config/` | Si en el futuro se cambia `config/opencode.json` en el repo, el `./data/opencode-config/opencode.json` NO se actualiza automáticamente. Documentar en AGENTS.md. |
| SSH agent de `cloud` pierde la key tras `docker compose down -v` | `ssh-agent` se reinicia con el contenedor (es volátil); el usuario debe re-ejecutar `ssh-add` al entrar. Ya documentado en setup.sh de Fase 4. |

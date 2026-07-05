# Requisitos - Fase 4: GitHub + git

## Alcance

Configurar la integración del agente OpenCode con GitHub para que pueda
operar contra repos remotos sin intervención manual. Esto cubre
autenticación de la CLI de GitHub, configuración de git, generación de
llave SSH y validación del flujo completo (clonar + push + PR).

### Incluido

- Autenticación de `gh` CLI contra github.com vía PAT inyectado por `.env`
- Configuración de git para usar `gh` como credential helper (HTTPS)
- Generación de llave SSH ed25519 dedicada al agente
- Registro de la llave pública en GitHub (Authentication Key)
- Persistencia de la SSH key en el volumen `opencode-ssh`
- Smoke test end-to-end: clonar repo privado, commitear, pushear,
  abrir PR via `gh pr create`
- Refinamiento de `setup.sh` para reflejar el flujo real

### No incluido

- Soporte para GitHub Enterprise Server (solo github.com)
- Multi-cuenta o multi-org (una sola cuenta, scopes mínimos)
- CI/CD pipeline para actualizar el agente (Fase 6)
- Backups automáticos de la SSH key (Fase 6)
- Rotación programada de PAT/SSH key (Fase 6)
- 2FA / SSO enforcement (depende de la org del usuario, fuera de scope)
- GPG signing de commits (no pedido, fuera de scope)

## Decisiones

| ID  | Decisión                                          | Racional                                                                                              | Alternativa descartada                  |
| --- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------- |
| D1  | PAT inyectado en `.env` + `gh auth login --with-token` | Headless container sin browser: el flujo web no aplica. PAT permite no-interactive setup.             | Device code flow (más fricción manual)  |
| D2  | Git protocol dual: HTTPS (gh auth) + SSH (push/pull directo) | `gh` subcommands usan HTTPS con su propio token; `git push` directo sobre SSH es más estándar.        | Solo SSH (rompe integración con `gh`)   |
| D3  | SSH key ed25519 con passphrase + `ssh-agent`        | Defensa en profundidad: passphrase protege la key en disco; ssh-agent evita tipearla cada vez.        | Sin passphrase (cómodo pero menos seguro) |
| D4  | PAT fine-grained con scopes mínimos                | Principio de menor privilegio. Solo `repo`, `workflow`, `read:org` para esta fase.                    | Classic PAT (más simple, más scopes)     |
| D5  | Repo de prueba: crear `opencode-vps-test` privado nuevo | Aislado, descartable, ideal para smoke test sin contaminar otros repos.                              | Usar repo existente (mezcla concerns)   |
| D6  | SSH key nombrada `id_ed25519_github_opencode`      | Evita pisar nombres comunes; identifica el origen (opencode agent).                                  | `id_ed25519` genérico (riesgo de colisión) |

### Detalle de scopes del PAT (D4)

Fine-grained token sobre la cuenta personal `@adalgarcia`:

- **Repository access**: `All repositories` (suficiente para Fase 4; en Fase 6
  se puede restringir a `Only select repositories`)
- **Permissions**:
  - `Contents`: Read and write (clone, commit, push)
  - `Pull requests`: Read and write (para `gh pr create`)
  - `Metadata`: Read-only (obligatorio, default)
  - `Workflows`: Read and write (si vamos a tocar Actions en el futuro)
  - `Administration`: Read-only (opcional, para crear repos en smoke test)

> Nota: `Administration: Read` es necesario solo si D5 requiere crear el repo
> desde la CLI. Si el repo se crea desde la web de GitHub, no hace falta.

## Contexto

### Servidor y stack

- **Servidor**: VPS `10.0.5.16` (TrueNAS / FreeBSD)
- **Directorio de trabajo en VPS**: `~/opencode-vps/`
- **Contenedor**: Docker Compose con servicio único (`opencode-vps`)
- **Acceso al contenedor**: SSH por tunnel (`ssh.adalgarcia.com`) o directo
  (`ssh -p 2222 cloud@<host>`)
- **URL web**: `https://opencode.adalgarcia.com`

### Stack actual (sin cambios)

- Ubuntu 24.04 LTS dentro del contenedor
- `gh` CLI ya instalado en el Dockerfile (Fase 2, líneas 44-49)
- `opencode-ssh` volumen ya declarado y montado en `/home/cloud/.ssh`
- `setup.sh` tiene placeholder en sección 4 (se va a refinar en Grupo 7)

### Variables de entorno

**Existentes** (no se modifican):

- `OPENCODE_SERVER_PASSWORD` - HTTP Basic Auth
- `CLOUDFLARE_TUNNEL_TOKEN` - token del tunnel
- `OPENCODE_GO_API_KEY` - API key del provider OpenCode Go

**Nueva** (esta fase):

- `GH_TOKEN` - Personal Access Token para `gh auth login --with-token`

### Volúmenes (sin cambios)

- `opencode-ssh` montado en `/home/cloud/.ssh/` ya garantiza persistencia
  de la SSH key entre reinicios del contenedor.

### Usuarios

- `cloud` (sin sudo) - usuario agente, dueño de la SSH key y del git config
- `devadmin` (con sudo) - mantenimiento, no se usa para Fase 4

### Pre-condiciones de seguridad (validadas en commit `4e83489`)

Estas condiciones NO son parte de Fase 4 propiamente dicha, pero son
requisito previo. Se heredan de Fase 2 y se formalizaron en un commit
anterior de esta misma rama (`4e83489`):

- Passwords de `devadmin` y `cloud` cambiadas desde `changeme` (Dockerfile:54-59)
- Ownership correcto de `/home/devadmin/.ssh` y `/home/cloud/.ssh`
  - Script `scripts/fix-ssh-ownership.sh` corre al arrancar (vía supervisord)
  - Idempotente: corrige automáticamente si el volumen los creó como root
- `ssh-copy-id` funcional contra el contenedor
- `git push` directo contra GitHub sobre SSH requiere que `cloud` sea
  dueño de `/home/cloud/.ssh` (lo cual ya está garantizado por el script)

## Dependencias

- **Fase 1**: Contenedor base funcionando (✅)
- **Fase 2**: `gh` CLI instalado y usuario `cloud` creado (✅)
- **Fase 3**: Tunnel + acceso remoto funcionando (✅, no bloqueante para
  esta fase pero útil para acceder a la web del agente durante la
  implementación)

## Riesgos identificados

| Riesgo                                                  | Mitigación                                                                 |
| ------------------------------------------------------- | -------------------------------------------------------------------------- |
| PAT se filtra al repo por error                         | `.env` en `.gitignore` (verificado en Fase 1) + pre-commit mental check    |
| SSH key generada como root en vez de cloud              | Hacer `su - cloud` antes de `ssh-keygen`; verificar ownership con `ls -la` |
| Permisos amplios en private key (`644` en vez de `600`) | `chmod 600` explícito en Grupo 4; ssh rechaza keys con permisos amplios    |
| Fine-grained PAT sin scope para el repo específico      | Usar "All repositories" en D4 o seleccionar el repo de prueba explícitamente |
| `gh auth login --web` no funciona en headless           | D1 = `--with-token` (flujo no interactivo)                                 |
| SSH agent no persiste entre reinicios                   | Documentar paso de `ssh-add` en `setup.sh` (re-ejecutar al entrar al contenedor) |

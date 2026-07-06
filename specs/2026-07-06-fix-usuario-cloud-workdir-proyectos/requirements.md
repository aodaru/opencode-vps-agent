# Requisitos - Fix: usuario `cloud` + workdir `/home/cloud/proyectos`

## Alcance

Hacer que el servicio `opencode-web` (gestionado por supervisord) corra como
el usuario `cloud` en el directorio `/home/cloud/proyectos`, en línea con
lo que la documentación del proyecto establece desde Fase 2.

Actualmente corre como **root** en `/home/cloud/proyectos` (que pertenece
a `cloud`), lo cual rompe el modelo de permisos: opencode no puede
escribir sesión/proyectos con el ownership correcto, y cualquier archivo
nuevo en `/home/cloud/proyectos` queda con `root:root`.

Adicionalmente, extender el script de corrección de ownership
(`fix-ssh-ownership.sh`, que hoy solo cubre `~/.ssh/`) para que cubra
**todos los paths bind-mountados** de `/home/cloud/...` y
`/home/devadmin/...`. Esto resuelve el problema de UID mismatch entre
el host (donde `init-data.sh` crea los dirs como `truenas_admin`) y el
contenedor (donde `cloud` tiene un UID distinto).

### Incluido

- Agregar `user=cloud` al programa `[program:opencode-web]` en
  `supervisor/opencode-web.conf`
- Renombrar `scripts/fix-ssh-ownership.sh` → `scripts/fix-ownership.sh`
  y extenderlo para corregir ownership de:
  - `/home/cloud/proyectos` (workspace)
  - `/home/cloud/.config/opencode` y `/home/cloud/.config/gh`
  - `/home/cloud/.local/share/opencode` (donde vive `auth.json`)
  - `/home/cloud/.cloudflared` (credenciales del tunnel)
  - `/home/cloud/.ssh` (ya estaba)
  - `/home/devadmin/.ssh` (ya estaba)
- Renombrar `supervisor/ssh-fix-ownership.conf` →
  `supervisor/fix-ownership.conf` (mismo contenido, nombre coherente con
  el nuevo alcance)
- Actualizar `Dockerfile` para hacer `COPY` del nuevo script y de la
  nueva conf de supervisor; borrar referencias al script viejo
- Actualizar `setup.sh` para que el chequeo `[1b/5]` liste todos los
  paths de `/home/cloud/...` (no solo `~/.ssh`)
- Documentar el fix en `AGENTS.md` y `README.md`
- Crear spec: `specs/2026-07-06-fix-usuario-cloud-workdir-proyectos/`
- Marcar el fix en `specs/roadmap.md`
- Validación en VPS: confirmar que el proceso corre como `cloud`, cwd
  es `/home/cloud/proyectos`, y que el test destructivo
  (`docker compose down -v && up -d`) no rompe nada

### No incluido

- Cambiar el provider de OpenCode
- Cambiar la configuración de red (puertos, tunnel)
- Cambiar la estrategia de bind mounts
- Multi-usuario (sigue siendo solo `cloud` + `devadmin`)
- Rotación de passwords (los passwords `changeme` del Dockerfile ya
  están documentados como a cambiar en el primer `setup.sh`)
- Cambiar el `WORKDIR` del Dockerfile (sigue `/home/cloud/proyectos`
  como valor por defecto; el `user=cloud` de supervisord hace que el
  proceso realmente arranque con ese cwd como propiedad de `cloud`)

## Contexto

### Inconsistencia detectada

La documentación del proyecto (Fase 2, Fase 4, AGENTS.md, setup.sh)
establece consistentemente que el servicio debe correr como `cloud` y
trabajar en `/home/cloud/proyectos`:

| Fuente | Dice |
|--------|------|
| `specs/2026-07-04-fase2-autenticacion-opencode-go/requirements.md:48-49` | "`cloud` - usuario agente, sin sudo" |
| `specs/2026-07-05-fase4-github-git/requirements.md:96` | "`cloud` - usuario agente, dueño de la SSH key y del git config" |
| `specs/2026-07-05-fase4-github-git/plan.md:67-69` | "estar logueado como usuario `cloud`, NO como root" |
| `AGENTS.md:69` | `proyectos/` → `/home/cloud/proyectos/` (workspace) |
| `setup.sh:4-5` | "Ejecutar dentro del contenedor como usuario: cloud" |

Sin embargo, en la implementación actual, `supervisor/opencode-web.conf`
no tiene `user=cloud`, por lo que el proceso arranca como **root** (el
default de supervisord, que a su vez corre como root del container, que
a su vez es root porque el Dockerfile no tiene `USER`).

`cloudflared` sí tiene `user=cloud` correctamente configurado
(`supervisor/opencode-web.conf:16`), lo cual confirma que el patrón se
olvidó solo en `opencode-web`.

### Causa raíz #1: `user=cloud` ausente en supervisor

`supervisor/opencode-web.conf`:
```ini
[program:opencode-web]
command=/usr/local/bin/opencode web --port 4096 --hostname 0.0.0.0
directory=/home/cloud/proyectos
environment=PATH=...
autostart=true
# ⚠️ Falta: user=cloud
```

### Causa raíz #2: UID mismatch en bind mounts

`scripts/init-data.sh` se ejecuta en el host (VPS) como `truenas_admin`
(típico UID 1000 en TrueNAS). Crea `./data/proyectos/` con ownership
UID 1000.

Dentro del contenedor:
- `devadmin` se crea primero con `useradd -m` → UID 1000
- `cloud` se crea después → UID 1001

Cuando `./data/proyectos/` se bind-mountea a `/home/cloud/proyectos/`,
el contenedor ve el directorio con UID 1000 (que en el container es
`devadmin`). `cloud` (UID 1001) **no puede escribir** en su propio
workspace.

El script actual `fix-ssh-ownership.sh` resuelve este problema para
`~/.ssh/` (corre como root al arrancar, antes de que sshd levante).
Pero no cubre los otros paths críticos, que también son bind-mountados
y sufren el mismo problema.

### Estado actual vs objetivo

**Actual** (antes del fix):

| Aspecto | Valor |
|---------|-------|
| Usuario de `opencode-web` | `root` (default de supervisord) |
| Working directory de `opencode-web` | `/home/cloud/proyectos` (correcto, pero `root` no es el dueño) |
| Ownership de archivos creados por opencode | `root:root` (rompe modelo de permisos) |
| ¿Puede `cloud` escribir en `/home/cloud/proyectos/`? | Probablemente NO (UID mismatch con bind mount) |
| ¿Puede `cloud` editar `opencode.json`? | Solo si el bind mount se creó con UID 1001 en el host (no es nuestro caso) |
| ¿Sobrevive a `docker compose down -v`? | Sí (gracias al fix de bind mounts previo) |

**Objetivo** (después del fix):

| Aspecto | Valor |
|---------|-------|
| Usuario de `opencode-web` | `cloud` |
| Working directory de `opencode-web` | `/home/cloud/proyectos` (cloud es dueño) |
| Ownership de archivos creados por opencode | `cloud:cloud` |
| ¿Puede `cloud` escribir en `/home/cloud/proyectos/`? | Sí (fix-ownership.sh corrige el UID al arrancar) |
| ¿Puede `cloud` editar `opencode.json`? | Sí |
| ¿Sobrevive a `docker compose down -v`? | Sí |

## Decisiones

| ID  | Decisión                                          | Racional                                                                                              | Alternativa descartada                  |
| --- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------- |
| D1  | `user=cloud` en `[program:opencode-web]` (no `USER cloud` en Dockerfile) | Supervisord corre como root (necesario para gestionar procesos hijos y para que `fix-ownership.sh` pueda hacer `chown`). Solo `opencode-web` y `cloudflared` deben ser `cloud`. | `USER cloud` en Dockerfile (rompe supervisord) |
| D2  | Extender `fix-ssh-ownership.sh` → `fix-ownership.sh` en vez de crear uno nuevo al lado | El script actual ya tiene el patrón correcto (idempotente, log coloreado, conditional chown). Solo hay que agregarle paths. Renombrar evita confusión sobre cuál es la "fuente de verdad". | Dejar el viejo + agregar uno nuevo (duplicación) |
| D3  | Renombrar también la conf de supervisor (`ssh-fix-ownership.conf` → `fix-ownership.conf`) | Consistencia con el nombre del script. | Dejar el nombre viejo (desactualizado) |
| D4  | `fix-ownership.sh` corre como root al arrancar (`priority=1`), antes de `opencode-web` y `cloudflared` | Necesita root para `chown`. Si corre antes, garantiza que cuando opencode-web intente leer `auth.json` o escribir en `proyectos/`, los permisos ya están bien. | Correrlo dentro de cada programa (no se puede: no son root) |
| D5  | No tocar el `WORKDIR` del Dockerfile ni agregar `user:` al docker-compose | `WORKDIR=/home/cloud/proyectos` ya está bien. El `user=cloud` de supervisor es suficiente para que el proceso corra con ese cwd como propiedad de cloud. Cambiar el `user:` del compose rompería supervisord. | Cambiar el WORKDIR/USER a nivel compose/imagen (innecesario) |
| D6  | Validar con `ps -o user,pid,cmd` + `readlink /proc/<pid>/cwd` + test destructivo | Estos son los criterios objetivos que demuestran que el fix funciona, independientemente del entorno. | Confiar en que "anda" (no verificable) |
| D7  | Branch base: `main`, nombre: `fix/usuario-cloud-workdir` | Es un fix de bug (no una fase nueva). Consistente con el patrón de `fix/persistencia-bind-mounts`. | Branch desde `fase2-...` (stale) |

### Detalle de paths a corregir en `fix-ownership.sh`

Todos los paths que se bind-mountean desde `./data/` al contenedor
(tomados de `docker-compose.yml:28-40` y `specs/tech-stack.md:61-69`):

| Path en contenedor | Usuario esperado | Permisos |
|--------------------|------------------|----------|
| `/home/cloud/proyectos` | `cloud` | `755` (workspace) |
| `/home/cloud/.config/opencode` | `cloud` | `755` (config editable) |
| `/home/cloud/.config/gh` | `cloud` | `755` (gh auth) |
| `/home/cloud/.local/share/opencode` | `cloud` | `755` (auth.json) |
| `/home/cloud/.cloudflared` | `cloud` | `755` (tunnel creds) |
| `/home/cloud/.ssh` | `cloud` | `700` (SSH keys) |
| `/home/devadmin/.ssh` | `devadmin` | `700` (SSH keys) |

El script conserva la lógica actual del viejo `fix-ssh-ownership.sh`:
- `id "$user"` para chequear que el usuario existe
- `chown -R "$user:$user"` solo si el owner actual no coincide
- `chmod 700` para SSH dirs, `chmod 755` para el resto
- No usa `set -e` (los condicionales `[ -f X ] && chmod X` devuelven
  1 si el archivo no existe, lo cual mata el script con set -e)

## Dependencias

- **Fix: Persistencia bind mounts** (✅ mergeado a main en este fix)
  - Necesario porque `fix-ownership.sh` asume que los paths existen
    (los crea `init-data.sh`)
  - El test destructivo de este fix es similar al del fix previo
- **Fase 1: Contenedor base** (✅)
- **Fase 2: Autenticación OpenCode Go** (✅)
- **Fase 4: GitHub + git** (✅, provee el patrón de chequeo de ownership
  en `setup.sh` que vamos a extender)

## Riesgos identificados

| Riesgo | Mitigación |
|--------|-----------|
| `user=cloud` rompe la lectura de `OPENCODE_CONFIG` o `auth.json` si los archivos no son legibles por `cloud` | `fix-ownership.sh` setea `cloud:cloud` recursivamente en todos los paths ANTES de que `opencode-web` arranque (`priority=1` < priority default de supervisord) |
| `user=cloud` rompe `cloudflared` si dependía de opencode-web | `cloudflared` no depende de opencode-web (procesos independientes). Ya tenía `user=cloud` funcionando. |
| `fix-ownership.sh` extendido rompe el fix de SSH que ya funcionaba | Se preserva exactamente la misma lógica para los paths de SSH. Solo se agregan nuevos paths. Se valida con los 7 checks del script. |
| El `chmod 755` de `proyectos/` no es suficiente para que `cloud` escriba | `cloud` es dueño del directorio, así que el dueño puede escribir siempre que el dir tenga permisos de escritura para dueño (que es `755` para dueño). `chown` antes de `chmod` garantiza esto. |
| Cambio de usuario afecta `OPENCODE_SERVER_PASSWORD` o el proxy HTTP Basic Auth | El env var se inyecta en el `environment=` del programa. Supervisord setea env vars ANTES de cambiar de usuario (es el comportamiento default). Validado leyendo docs de supervisord. |
| El script extendido es lento si `proyectos/` tiene muchos archivos | Solo se hace `chown -R` si el owner NO coincide (chequeo previo con `stat -c '%U'`). Si ya está bien, es instantáneo. |
| Branch rename rompe la convención de las otras ramas | Las otras ramas usan `fix/<scope>`. Esta usa `fix/usuario-cloud-workdir`. Consistente. |

## Criterio de éxito (resumen)

1. `ps -o user,pid,cmd -p $(pgrep -f 'opencode web')` muestra `cloud`
2. `readlink /proc/$(pgrep -f 'opencode web')/cwd` muestra
   `/home/cloud/proyectos`
3. `touch /home/cloud/proyectos/.smoke-test` como `cloud` funciona
4. `stat -c '%U' /home/cloud/proyectos/.smoke-test` muestra `cloud`
5. La web UI sigue respondiendo en `localhost:4096` con auth
6. `opencode models opencode-go` lista modelos sin re-autenticar
7. El test destructivo (`docker compose down -v && up -d`) pasa todos
   los checks anteriores

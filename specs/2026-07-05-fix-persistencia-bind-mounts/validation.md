# Validación - Refactor de persistencia: bind mounts en host

## Criterios de éxito

La fase se considera completada y mergeable cuando se cumplan **todos** los
siguientes criterios.

### 1. Scripts de bootstrap

- [ ] `scripts/init-data.sh` existe y es ejecutable
- [ ] `scripts/init-data.sh` es idempotente (correrlo 2 veces termina OK)
- [ ] `./scripts/init-data.sh` crea los 7 subdirs en `./data/` con
      permisos correctos (`700` para SSH, `755` para el resto)
- [ ] `./scripts/init-data.sh` copia `config/opencode.json` a
      `./data/opencode-config/opencode.json`
- [ ] `scripts/migrate-volumes.sh` existe y es ejecutable
- [ ] `./scripts/migrate-volumes.sh` migra los 4 named volumes simples
      a `./data/`
- [ ] `./scripts/migrate-volumes.sh` inspecciona `opencode-config` y
      deja instrucciones para separar manualmente

### 2. `docker-compose.yml` refactorizado

- [ ] Las 7 líneas de `volumes:` del servicio son bind mounts a `./data/...`
- [ ] La sección `volumes:` final (5 named volumes) está eliminada
- [ ] `OPENCODE_GO_API_KEY` → `OPENCODE_API_KEY` en `environment:`
- [ ] `docker compose config` no muestra errores de sintaxis
- [ ] `docker compose config --volumes` no muestra los 5 named volumes
      antiguos

### 3. Migración de datos existentes

- [ ] `./data/opencode-auth/` contiene el `auth.json` previo (si existía)
- [ ] `./data/ssh-cloud/` contiene las SSH keys previas de `cloud`
- [ ] `./data/ssh-devadmin/` existe (NUEVO, antes no persistía)
- [ ] `./data/proyectos/` contiene los proyectos previos
- [ ] `./data/opencode-config/` tiene `opencode.json` (sembrado por
      `init-data.sh`)
- [ ] `./data/gh-config/` tiene `hosts.yml` (separado manualmente del bug)

### 4. Rename de env var

- [ ] `.env` tiene `OPENCODE_API_KEY=...` (sin `_GO_`)
- [ ] `.env.example` actualizado
- [ ] `supervisor/opencode-web.conf` actualizado
- [ ] `grep -r OPENCODE_GO_API_KEY . --exclude-dir=specs` no encuentra
      nada en el repo (excepto `validation.md` como referencia histórica)

### 5. Documentación

- [ ] `AGENTS.md` tiene sección "Persistencia en host
      (`~/opencode-vps/data/`)" con tabla de subdirs
- [ ] `AGENTS.md` usa `OPENCODE_API_KEY` (sin `_GO_`)
- [ ] `README.md` tiene sección "Persistencia" explicando `./data/` y
      el bug del volumen duplicado
- [ ] `README.md` usa `OPENCODE_API_KEY`
- [ ] `specs/tech-stack.md` actualizado (tabla "Directorios persistentes"
      con bind mounts)
- [ ] `specs/tech-stack.md` actualizado ("Variables de entorno" con rename)
- [ ] `setup.sh` sección 2 reescrita con flujo `auth.json` + env var backup

### 6. Validación destructiva end-to-end (CRITERIO CLAVE)

- [ ] `docker compose up -d` (con la nueva config) arranca sin errores
- [ ] `docker compose exec -u cloud opencode-vps opencode models opencode-go`
      lista los 3 modelos
- [ ] `docker compose exec opencode-vps ls -la /home/devadmin/.ssh/`
      muestra `devadmin:devadmin`
- [ ] `docker compose exec -u cloud opencode-vps gh auth status` muestra
      autenticado
- [ ] **Test destructivo**: `docker compose down -v` ejecutado
- [ ] `docker compose up -d` re-arranca
- [ ] **Verificación post-destructivo**:
  - [ ] `./data/opencode-auth/auth.json` existe (en host, fuera del contenedor)
  - [ ] `./data/ssh-cloud/` tiene las SSH keys (en host)
  - [ ] `./data/ssh-devadmin/` tiene archivos (en host, NUEVO)
  - [ ] `./data/proyectos/` tiene los proyectos (en host)
  - [ ] Dentro del contenedor, `opencode models opencode-go` lista
        modelos **SIN re-autenticar**
  - [ ] Dentro del contenedor, `gh auth status` muestra autenticado
        **SIN re-autenticar**
  - [ ] Dentro del contenedor, SSH key de cloud sigue funcionando
        (test `ssh -T git@github.com`)

## Cómo verificar

```bash
# 1. Verificar que los scripts existen y son ejecutables
ls -la scripts/init-data.sh scripts/migrate-volumes.sh

# 2. Verificar que init-data.sh es idempotente (correrlo 2 veces)
./scripts/init-data.sh && ./scripts/init-data.sh
# debe terminar OK ambas veces

# 3. Verificar la estructura de ./data/
ls -la ~/opencode-vps/data/

# 4. Verificar docker-compose.yml
docker compose config
# debe parsear sin errores

# 5. Test destructivo (EL CRITERIO CLAVE)
cd ~/opencode-vps
docker compose down -v
docker compose up -d
sleep 10  # esperar a que opencode-web arranque

# 6. Verificar que TODO persiste
docker compose exec opencode-vps bash -c '
  echo "=== auth.json (debe existir) ==="
  cat /home/cloud/.local/share/opencode/auth.json 2>/dev/null | head -c 100; echo
  echo "=== SSH keys cloud ==="
  ls -la /home/cloud/.ssh/
  echo "=== SSH keys devadmin (NUEVO) ==="
  ls -la /home/devadmin/.ssh/
  echo "=== gh auth ==="
  gh auth status 2>&1 | head -5
  echo "=== proyectos ==="
  ls -la /home/cloud/proyectos/ | head -10
  echo "=== modelos Go ==="
  opencode models opencode-go
'

# 7. Verificar que no se commiteó .env ni data/
git status
# no debe haber .env ni data/ en el staging
```

## Criterio de merge a main

- [ ] Todos los checkboxes de "Criterios de éxito" marcados
- [ ] PR abierto via `gh pr create` (con `--body-file validation.md`
      para que se vea el plan)
- [ ] Al menos 1 reviewer (o auto-merge si es proyecto personal single-dev)
- [ ] No hay secrets commiteados
      (`git diff main...HEAD -- .env` debe estar vacío)
- [ ] `data/` no está commiteado
      (`git ls-files | grep ^data/` debe estar vacío)
- [ ] El branch `fix/persistencia-bind-mounts` se puede borrar post-merge:
      `gh pr merge --merge --delete-branch`

## Anti-criterios (lo que NO debe pasar)

- ❌ `git log` muestra el contenido de `.env` en cualquier commit
- ❌ `git log` muestra archivos dentro de `data/` (debería estar en
  `.gitignore`)
- ❌ Después de `docker compose down -v && up`, hay que re-autenticar
  (auth.json o gh)
- ❌ Después de `docker compose down -v && up`, las SSH keys se perdieron
- ❌ Después de `docker compose down -v && up`, los proyectos del usuario
  se perdieron
- ❌ `/home/devadmin/.ssh/` no existe tras el primer arranque (FIX bug)
- ❌ `docker compose config` muestra errores de parseo
- ❌ `grep -r OPENCODE_GO_API_KEY` encuentra la variable vieja (excepto
  en `validation.md` como referencia histórica)
- ❌ La UI de opencode sigue diciendo "missing api key" tras el fix
- ❌ Los named volumes antiguos (`opencode-auth`, `opencode-config`,
  `opencode-tunnel`, `opencode-proyectos`, `opencode-ssh`) siguen
  existiendo en `docker volume ls` tras la migración exitosa (limpiar
  con `docker volume rm` después de confirmar)

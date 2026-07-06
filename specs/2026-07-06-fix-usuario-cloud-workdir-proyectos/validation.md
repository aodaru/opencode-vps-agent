# Validación - Fix: usuario `cloud` + workdir `/home/cloud/proyectos`

## Criterios de éxito

La fase se considera completada y mergeable cuando se cumplan **todos**
los siguientes criterios.

### 1. `opencode-web` corre como `cloud`

- [ ] `ps -o user,pid,cmd -p $(pgrep -f 'opencode web')` muestra
      `cloud` en la columna `user`
- [ ] `readlink /proc/$(pgrep -f 'opencode web')/cwd` devuelve
      `/home/cloud/proyectos`
- [ ] `supervisor/opencode-web.conf` tiene `user=cloud` en la sección
      `[program:opencode-web]`
- [ ] `supervisor/opencode-web.conf` mantiene `directory=/home/cloud/proyectos`

### 2. Ownership correcto en todos los paths bind-mountados

- [ ] `/home/cloud/proyectos` → `cloud:cloud`, `755`
- [ ] `/home/cloud/.config/opencode` → `cloud:cloud`, `755`
- [ ] `/home/cloud/.config/gh` → `cloud:cloud`, `755`
- [ ] `/home/cloud/.local/share/opencode` → `cloud:cloud`, `755`
- [ ] `/home/cloud/.cloudflared` → `cloud:cloud`, `755`
- [ ] `/home/cloud/.ssh` → `cloud:cloud`, `700`
- [ ] `/home/devadmin/.ssh` → `devadmin:devadmin`, `700`

### 3. `fix-ownership.sh` extendido

- [ ] `scripts/fix-ownership.sh` existe y es ejecutable
- [ ] `scripts/fix-ownership.sh` cubre los 7 paths listados arriba
- [ ] `scripts/fix-ssh-ownership.sh` NO existe (borrado)
- [ ] `supervisor/fix-ownership.conf` existe y referencia
      `/usr/local/bin/fix-ownership.sh`
- [ ] `supervisor/ssh-fix-ownership.conf` NO existe (borrado)
- [ ] `Dockerfile` hace `COPY scripts/fix-ownership.sh` y
      `COPY supervisor/fix-ownership.conf` (no los nombres viejos)
- [ ] `grep -r fix-ssh-ownership . --exclude-dir=specs --exclude-dir=.git`
      no encuentra nada

### 4. Escritura funciona como `cloud`

- [ ] `docker compose exec -u cloud opencode-vps touch
      /home/cloud/proyectos/.smoke-test` no tira error
- [ ] `stat -c '%U:%G' /home/cloud/proyectos/.smoke-test` muestra
      `cloud:cloud`
- [ ] `docker compose exec -u cloud opencode-vps touch
      /home/cloud/.config/opencode/.smoke-test` no tira error
- [ ] Mismo check para `/home/cloud/.local/share/opencode` y
      `/home/cloud/.cloudflared`

### 5. Servicio sigue funcional

- [ ] `curl -u opencode:$OPENCODE_SERVER_PASSWORD -s -o /dev/null
      -w "%{http_code}\n" http://localhost:4096` devuelve `200` (o `401`
      si requiere auth adicional)
- [ ] `opencode models opencode-go` lista los 3 modelos Go SIN
      re-autenticar
- [ ] `gh auth status` muestra autenticado SIN re-autenticar
- [ ] `cloudflared` sigue corriendo (verificar con
      `docker compose exec opencode-vps pgrep cloudflared`)
- [ ] `sshd` sigue corriendo (verificar con
      `docker compose exec opencode-vps pgrep sshd`)

### 6. Test destructivo (CRITERIO CLAVE)

- [ ] `docker compose down -v` ejecutado
- [ ] `docker compose up -d` re-arranca
- [ ] **Verificación post-destructivo** (repetir todos los checks de
      arriba):
  - [ ] Proceso corre como `cloud`, cwd es `/home/cloud/proyectos`
  - [ ] Ownership de los 7 paths sigue correcto
  - [ ] `auth.json` se lee correctamente (modelos Go disponibles)
  - [ ] `gh auth status` sigue autenticado
  - [ ] SSH keys de `cloud` siguen funcionando (`ssh -T git@github.com`)

### 7. Documentación

- [ ] `AGENTS.md` tiene subsección "Usuario y workdir del agente"
      explicitando `cloud` + `/home/cloud/proyectos`
- [ ] `AGENTS.md` menciona `fix-ownership.sh` (no el nombre viejo)
- [ ] `README.md` actualizado con nota similar
- [ ] `setup.sh` sección `[1b/5]` lista todos los paths de
      `/home/cloud/...` (no solo `~/.ssh`)
- [ ] `specs/roadmap.md` marca el nuevo fix con sus criterios

## Cómo verificar

> ⚠️ **En el VPS** (`~/opencode-vps/`), no en la máquina local.

```bash
# 0. Setup
cd ~/opencode-vps
git fetch origin
git checkout fix/usuario-cloud-workdir
git pull
docker compose up -d --build
sleep 10  # esperar a que opencode-web arranque

# 1. Proceso y workdir (CRITERIO CLAVE)
docker compose exec opencode-vps bash -c '
  PID=$(pgrep -f "opencode web")
  echo "=== Proceso opencode-web ==="
  ps -o user,pid,cmd -p $PID
  echo "=== Working directory ==="
  readlink /proc/$PID/cwd
'
# Esperado:
#   USER  cloud
#   cwd   /home/cloud/proyectos

# 2. Ownership de los 7 paths
docker compose exec opencode-vps bash -c '
  for d in /home/cloud/proyectos \
           /home/cloud/.config/opencode \
           /home/cloud/.config/gh \
           /home/cloud/.local/share/opencode \
           /home/cloud/.cloudflared \
           /home/cloud/.ssh \
           /home/devadmin/.ssh; do
    stat -c "%U:%G %n" "$d"
  done
'
# Esperado: cloud:cloud para los 6 de cloud, devadmin:devadmin para el último

# 3. Escritura como cloud
docker compose exec -u cloud opencode-vps touch /home/cloud/proyectos/.smoke-test
docker compose exec opencode-vps stat -c '%U:%G' /home/cloud/proyectos/.smoke-test
# Esperado: cloud:cloud
docker compose exec opencode-vps rm /home/cloud/proyectos/.smoke-test

# 4. Web UI + auth
curl -u opencode:$OPENCODE_SERVER_PASSWORD -s -o /dev/null \
  -w "HTTP: %{http_code}\n" http://localhost:4096
# Esperado: HTTP: 200 (o 401)

docker compose exec -u cloud opencode-vps opencode models opencode-go | head -3
# Esperado: 3 modelos Go

docker compose exec -u cloud opencode-vps gh auth status | head -3
# Esperado: Logged in to github.com as aodaru

# 5. cloudflared y sshd siguen corriendo
docker compose exec opencode-vps pgrep -l cloudflared
docker compose exec opencode-vps pgrep -l sshd

# 6. Test destructivo (EL CRITERIO CLAVE)
cd ~/opencode-vps
docker compose down -v
docker compose up -d
sleep 10

# Repetir checks 1-5

# 7. Verificar secrets no commiteados
git status
# no debe haber .env ni data/ en el staging
```

## Criterio de merge a main

- [ ] Todos los checkboxes de "Criterios de éxito" marcados
- [ ] PR abierto via `gh pr create` (con `--body-file validation.md`
      para que se vea el plan)
- [ ] Al menos 1 reviewer (o auto-merge si es proyecto personal
      single-dev)
- [ ] No hay secrets commiteados
      (`git diff main...HEAD -- .env` debe estar vacío)
- [ ] `data/` no está commiteado
      (`git ls-files | grep ^data/` debe estar vacío)
- [ ] El branch `fix/usuario-cloud-workdir` se puede borrar post-merge:
      `gh pr merge --merge --delete-branch`

## Anti-criterios (lo que NO debe pasar)

- [ ] ❌ `ps` muestra `root` como user de `opencode-web`
- [ ] ❌ `readlink /proc/<pid>/cwd` devuelve `/` o cualquier cosa
      distinta de `/home/cloud/proyectos`
- [ ] ❌ `stat -c '%U' /home/cloud/proyectos` muestra `root` o
      `devadmin` (algo que NO sea `cloud`)
- [ ] ❌ `docker compose exec -u cloud opencode-vps touch ...` tira
      `Permission denied`
- [ ] ❌ Después de `docker compose down -v && up`, hay que
      re-autenticar (auth.json, gh)
- [ ] ❌ `web UI` no responde (puerto 4096 cerrado o no levanta)
- [ ] ❌ `cloudflared` o `sshd` no corren (regresión del fix de
      supervisord)
- [ ] ❌ `git log` muestra archivos dentro de `data/` (debería estar
      en `.gitignore`)
- [ ] ❌ `grep -r fix-ssh-ownership .` encuentra referencias (el nombre
      viejo debe haber sido completamente reemplazado)

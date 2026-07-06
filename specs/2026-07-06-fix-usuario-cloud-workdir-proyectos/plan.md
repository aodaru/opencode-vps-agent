# Plan - Fix: usuario `cloud` + workdir `/home/cloud/proyectos`

Plan secuencial. Cada grupo debe completarse antes del siguiente.
Marcar checkboxes al ejecutar.

## Pre-requisitos

- [x] Estar en la rama `fix/usuario-cloud-workdir` (creada desde `main`)
- [x] `main` actualizado con el merge de `fix/persistencia-bind-mounts`
      (PR #2 mergeado)
- [x] Contenedor NO necesariamente detenido (este fix no requiere
      rearrancar desde cero, pero se va a probar en VPS después)

## Grupo 1: Refactor de `opencode-web` en supervisor

> Corrige la causa raíz #1: opencode-web corre como root.

1. [ ] Editar `supervisor/opencode-web.conf`
2. [ ] Agregar `user=cloud` a la sección `[program:opencode-web]`
      (justo después de `command=...`, antes de `directory=`)
3. [ ] Dejar intacto el `directory=/home/cloud/proyectos`
4. [ ] Dejar intacto el bloque `environment=` (OPENCODE_SERVER_PASSWORD,
      OPENCODE_CONFIG, OPENCODE_API_KEY)
5. [ ] Verificar que `[program:cloudflared]` no se tocó (ya tiene
      `user=cloud`)

**Diff esperado:**
```diff
 [program:opencode-web]
 command=/usr/local/bin/opencode web --port 4096 --hostname 0.0.0.0
+user=cloud
 directory=/home/cloud/proyectos
 environment=PATH="...",BROWSER="none",OPENCODE_SERVER_PASSWORD=...
```

## Grupo 2: Extender `fix-ownership.sh`

> Corrige la causa raíz #2: UID mismatch en bind mounts.

6. [ ] Crear `scripts/fix-ownership.sh` (nuevo, basado en el viejo
      `scripts/fix-ssh-ownership.sh`)
7. [ ] El script debe:
   - Mantener el header/comentario y la lógica de logging del original
   - Mantener la función `fix_user_ssh()` para SSH dirs (sin cambios)
   - Agregar una nueva función `fix_user_dir()` para dirs no-SSH
     (con `chmod 755` en vez de `chmod 700`)
   - Llamar a `fix_user_ssh()` para `cloud` y `devadmin` (sin cambios)
   - Llamar a `fix_user_dir()` para los nuevos paths de `cloud`
8. [ ] Paths a corregir (D7 de requirements.md):

   | Path | User | Perms |
   |------|------|-------|
   | `/home/cloud/proyectos` | `cloud` | `755` |
   | `/home/cloud/.config/opencode` | `cloud` | `755` |
   | `/home/cloud/.config/gh` | `cloud` | `755` |
   | `/home/cloud/.local/share/opencode` | `cloud` | `755` |
   | `/home/cloud/.cloudflared` | `cloud` | `755` |
   | `/home/cloud/.ssh` | `cloud` | `700` (ya estaba) |
   | `/home/devadmin/.ssh` | `devadmin` | `700` (ya estaba) |

9. [ ] Borrar `scripts/fix-ssh-ownership.sh` (reemplazado por
      `fix-ownership.sh` con alcance extendido)
10. [ ] `chmod +x scripts/fix-ownership.sh`
11. [ ] Validar sintaxis: `bash -n scripts/fix-ownership.sh` (no debe
      tirar errores)
12. [ ] Validar idempotencia manualmente: revisar que los condicionales
      `if [ ... ]` no fallen cuando un path no existe

## Grupo 3: Refactor de conf de supervisor

13. [ ] Crear `supervisor/fix-ownership.conf` (basado en
      `supervisor/ssh-fix-ownership.conf`)
14. [ ] Cambiar el `command=` para apuntar al nuevo script:
      `command=/usr/local/bin/fix-ownership.sh`
15. [ ] Mantener `user=root`, `priority=1`, `autorestart=false`,
      `exitcodes=0` (todo lo que necesita root)
16. [ ] Borrar `supervisor/ssh-fix-ownership.conf` (reemplazado)

## Grupo 4: Actualizar Dockerfile

17. [ ] Cambiar `COPY scripts/fix-ssh-ownership.sh ...` →
      `COPY scripts/fix-ownership.sh /usr/local/bin/fix-ownership.sh`
18. [ ] Cambiar
      `COPY supervisor/ssh-fix-ownership.conf /etc/supervisor/conf.d/ssh-fix-ownership.conf` →
      `COPY supervisor/fix-ownership.conf /etc/supervisor/conf.d/fix-ownership.conf`
19. [ ] Cambiar el `RUN chmod +x /usr/local/bin/fix-ssh-ownership.sh` →
      `RUN chmod +x /usr/local/bin/fix-ownership.sh`
20. [ ] Validar: `grep -n fix-ssh-ownership Dockerfile` debe estar
      vacío (no debe quedar ninguna referencia al nombre viejo)

## Grupo 5: Actualizar `setup.sh`

21. [ ] Reescribir la sección `[1b/5]` para que liste TODOS los paths
      de `/home/cloud/...` y `/home/devadmin/.ssh`, no solo `~/.ssh`
22. [ ] Cambiar el chequeo a usar `find` o un loop, en vez de paths
      hardcodeados
23. [ ] Actualizar la nota sobre "el contenedor incluye un script que
      corrige esto automáticamente" para mencionar el nombre nuevo
      (`fix-ownership.sh` + `supervisor > fix-ownership`)

## Grupo 6: Documentación

24. [ ] `AGENTS.md`:
    - Renombrar referencias al script viejo (`fix-ssh-ownership.sh` →
      `fix-ownership.sh`, `supervisor > ssh-fix-ownership` →
      `supervisor > fix-ownership`)
    - Agregar subsección "Usuario y workdir del agente" en la sección
      "Persistencia en host" explicitando: `opencode-web` corre como
      `cloud` en `/home/cloud/proyectos` (no como root)
    - Documentar que `fix-ownership.sh` corre al arrancar (priority=1)
      y corrige ownership de todos los paths bind-mountados
25. [ ] `README.md`:
    - Misma nota en la sección "Seguridad" o crear nueva subsección
      "Usuario del agente"
    - Actualizar referencia al script
26. [ ] `specs/roadmap.md`:
    - Marcar el fix de bind mounts como ✅ (ya está mergeado)
    - Agregar nueva entrada "Fix: usuario cloud + workdir proyectos"
      con sus checks
    - Actualizar la tabla "Estado actual"

## Grupo 7: Validación local (sanity check, sin VPS)

27. [ ] `docker compose config` no tira errores
28. [ ] `bash -n scripts/fix-ownership.sh` no tira errores
29. [ ] `grep -r fix-ssh-ownership .` (excluyendo `specs/` que es
      histórico) no encuentra nada

## Grupo 8: Validación en VPS (criterio clave)

> ⚠️ En el VPS (`~/opencode-vps/`), no en la máquina local.

30. [ ] Pull de la rama:
    ```bash
    cd ~/opencode-vps
    git fetch origin
    git checkout fix/usuario-cloud-workdir
    git pull
    ```
31. [ ] Reconstruir y rearrancar:
    ```bash
    docker compose up -d --build
    ```
32. [ ] Verificar el proceso (criterio clave #1):
    ```bash
    docker compose exec opencode-vps bash -c '
      PID=$(pgrep -f "opencode web")
      echo "PID: $PID"
      ps -o user,pid,cmd -p $PID
      echo "cwd: $(readlink /proc/$PID/cwd)"
    '
    # Esperado:
    #   user: cloud
    #   cwd:  /home/cloud/proyectos
    ```
33. [ ] Verificar escritura (criterio clave #2):
    ```bash
    docker compose exec -u cloud opencode-vps touch /home/cloud/proyectos/.smoke-test
    docker compose exec opencode-vps stat -c '%U:%G %n' /home/cloud/proyectos/.smoke-test
    # Esperado: cloud:cloud /home/cloud/proyectos/.smoke-test
    docker compose exec opencode-vps rm /home/cloud/proyectos/.smoke-test
    ```
34. [ ] Verificar ownership de todos los paths críticos:
    ```bash
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
    # Esperado:
    #   cloud:cloud       /home/cloud/proyectos
    #   cloud:cloud       /home/cloud/.config/opencode
    #   cloud:cloud       /home/cloud/.config/gh
    #   cloud:cloud       /home/cloud/.local/share/opencode
    #   cloud:cloud       /home/cloud/.cloudflared
    #   cloud:cloud       /home/cloud/.ssh
    #   devadmin:devadmin /home/devadmin/.ssh
    ```
35. [ ] Verificar que la web UI sigue respondiendo:
    ```bash
    curl -u opencode:$OPENCODE_SERVER_PASSWORD -s \
      -o /dev/null -w "%{http_code}\n" http://localhost:4096
    # Esperado: 200 (o 401 si requiere auth)
    ```
36. [ ] Verificar auth sin re-login:
    ```bash
    docker compose exec -u cloud opencode-vps opencode models opencode-go | head -3
    # Esperado: 3 modelos (glm-5.2, qwen3.7-max, kimi-k2.7-code)
    docker compose exec -u cloud opencode-vps gh auth status | head -3
    # Esperado: Logged in to github.com as aodaru
    ```
37. [ ] **Test destructivo** (criterio clave de aceptación):
    ```bash
    docker compose down -v
    docker compose up -d
    sleep 10  # esperar a que opencode-web arranque
    ```
38. [ ] Repetir checks 32-36 después del test destructivo

## Grupo 9: Merge

39. [ ] Validar criterios de éxito (ver `validation.md`)
40. [ ] `git status` para revisar staging (asegurar que `.env` y
      `data/` NO estén staged)
41. [ ] `git add .`
42. [ ] `git commit -m "fix(usuario): correr opencode-web como cloud en /home/cloud/proyectos"`
43. [ ] `git push -u origin fix/usuario-cloud-workdir`
44. [ ] `gh pr create --base main --title "..." --body-file specs/2026-07-06-fix-usuario-cloud-workdir-proyectos/validation.md`
45. [ ] Validar criterios de merge (ver `validation.md`)
46. [ ] `gh pr merge --merge --delete-branch`
47. [ ] Cleanup local: `git checkout main && git pull`

---

## Pendiente: ejecución en próxima sesión desde truenas

> ⚠️ El PR #3 ya está abierto y mergeado a `main` quedaría pendiente de
> esta validación. La rama `fix/usuario-cloud-workdir` ya está pusheada
> a `origin`. **Falta ejecutar los pasos de Grupo 8 + Grupo 9** en el
> VPS `10.0.5.16` (TrueNAS) para validar el fix end-to-end antes de
> mergear.

### Información de conexión

| Parámetro | Valor |
|-----------|-------|
| Host | `10.0.5.16` (TrueNAS) |
| Usuario | `truenas_admin` |
| SSH key | `~/.ssh/id_ed25519_github` |
| Working dir en VPS | `~/opencode-vps/` |
| Branch a validar | `fix/usuario-cloud-workdir` |
| PR abierto | https://github.com/aodaru/opencode-vps-agent/pull/3 |

### SSH al VPS (desde la sesión del agente)

> **El agente puede ejecutar estos pasos directamente vía SSH a truenas**
> en la próxima sesión. No requiere que el usuario intervenga en cada
> paso, salvo si la validación falla y hay que decidir cómo proceder.

```bash
# 1. Conectarse al VPS
ssh -i ~/.ssh/id_ed25519_github truenas_admin@10.0.5.16

# 2. Una vez dentro, ir al directorio del proyecto
cd ~/opencode-vps

# 3. Verificar que estamos en main (pre-validación)
git status
git log --oneline -3
```

### Pasos de validación (Grupo 8, ejecutables en orden)

```bash
# A. Setup: bajar la rama y rearrancar el contenedor
git fetch origin
git checkout fix/usuario-cloud-workdir
git pull
docker compose up -d --build
sleep 10  # esperar a que opencode-web arranque

# B. Criterio clave #1: proceso y cwd
docker compose exec opencode-vps bash -c '
  PID=$(pgrep -f "opencode web")
  echo "PID: $PID"
  echo "=== Proceso opencode-web ==="
  ps -o user,pid,cmd -p $PID
  echo "=== Working directory ==="
  readlink /proc/$PID/cwd
'
# Esperado:
#   USER   cloud
#   cwd    /home/cloud/proyectos

# C. Criterio clave #2: ownership de los 7 paths
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
# Esperado:
#   cloud:cloud       /home/cloud/proyectos
#   cloud:cloud       /home/cloud/.config/opencode
#   cloud:cloud       /home/cloud/.config/gh
#   cloud:cloud       /home/cloud/.local/share/opencode
#   cloud:cloud       /home/cloud/.cloudflared
#   cloud:cloud       /home/cloud/.ssh
#   devadmin:devadmin /home/devadmin/.ssh

# D. Criterio clave #3: escritura funciona como cloud
docker compose exec -u cloud opencode-vps touch /home/cloud/proyectos/.smoke-test
docker compose exec opencode-vps stat -c '%U:%G %n' /home/cloud/proyectos/.smoke-test
# Esperado: cloud:cloud /home/cloud/proyectos/.smoke-test
docker compose exec opencode-vps rm /home/cloud/proyectos/.smoke-test

# E. Criterio clave #4: web UI + auth sin re-login
curl -u opencode:"$OPENCODE_SERVER_PASSWORD" -s -o /dev/null \
  -w "HTTP: %{http_code}\n" http://localhost:4096
# Esperado: HTTP: 200 (o 401)

docker compose exec -u cloud opencode-vps opencode models opencode-go | head -3
# Esperado: 3 modelos Go (glm-5.2, qwen3.7-max, kimi-k2.7-code)

docker compose exec -u cloud opencode-vps gh auth status | head -3
# Esperado: Logged in to github.com as aodaru

# F. Servicios auxiliares siguen corriendo
docker compose exec opencode-vps pgrep -l cloudflared
docker compose exec opencode-vps pgrep -l sshd
```

### Test destructivo (criterio clave de aceptación)

```bash
# Bajar y volver a levantar (esto borra named volumes, NO los bind mounts)
cd ~/opencode-vps
docker compose down -v
docker compose up -d
sleep 10

# Repetir los pasos B-F completos. Si todo sigue OK, el fix es válido.
```

### Si todo OK → merge (Grupo 9)

```bash
# 1. Validar secretos no commiteados
cd ~/opencode-vps
git status
# No debe haber .env ni data/ en el staging
git diff main...HEAD -- .env  # debe estar vacío
git ls-files | grep ^data/    # debe estar vacío

# 2. Marcar los checkboxes en este archivo
# (editar specs/2026-07-06-fix-usuario-cloud-workdir-proyectos/validation.md)

# 3. Commitear los checks marcados
git add specs/2026-07-06-fix-usuario-cloud-workdir-proyectos/
git commit -m "docs: marcar checks de validacion como completados"

# 4. Merge del PR
gh pr merge 3 --merge --delete-branch

# 5. Cleanup
git checkout main
git pull
git branch -d fix/usuario-cloud-workdir 2>/dev/null || true
git remote prune origin

# 6. Actualizar roadmap y AGENTS.md (marcar fix como ✅)
```

### Si algo falla → troubleshooting

| Síntoma | Posible causa | Acción |
|---------|--------------|--------|
| `ps` muestra `root` como user | El `user=cloud` no se aplicó (revisar `supervisor/opencode-web.conf`) | Verificar que el commit está en la rama, re-aplicar con `git pull` |
| `cwd` no es `/home/cloud/proyectos` | El `directory=` se borró o cambió | Restaurar desde git |
| `stat` muestra owner incorrecto en algún path | El `fix-ownership.sh` no corrió o falló | Ver logs: `docker compose logs opencode-vps \| grep fix-ownership` |
| `Permission denied` en `touch` | Ownership no se corrigió | Re-ejecutar manualmente: `docker compose exec -u root opencode-vps chown -R cloud:cloud /home/cloud/proyectos` |
| Web UI no responde | El proceso no arrancó o el puerto está mal | `docker compose logs -f` para ver errores de supervisord |
| `gh auth` dice "not logged in" | El bind mount `gh-config` está vacío (no se migró en su día) | Re-autenticar manualmente (es esperado si nunca se hizo `gh auth login`) |
| `docker compose down -v` pierde auth | El bind mount de `opencode-auth` está vacío | Re-autenticar con `opencode auth login --provider opencode-go` |

### Notas para la próxima sesión

- El contenedor tiene `restart: unless-stopped`, así que va a estar
  corriendo entre sesiones.
- Si el fix funciona, el próximo paso natural es **Fase 5: Operación
  continua** (healthcheck + script de backup de `./data/`).
- Hay un branch stale local `fase2-autenticacion-opencode-go` que se
  puede borrar en algún momento (no es bloqueante).
- Hay un branch remoto `master` que aparece en `git branch -a` pero no
  existe en el repo remoto. Se puede ignorar.

# Plan - Refactor de persistencia: bind mounts en host

Plan secuencial. Cada grupo debe completarse antes del siguiente.
Marcar checkboxes al ejecutar.

## Pre-requisitos

- [ ] Estar en la rama `fix/persistencia-bind-mounts` (creada desde `main`)
- [ ] Contenedor detenido: `docker compose down` (sin `-v` para preservar
      named volumes durante la migración)
- [ ] Backup manual de seguridad del volume bugueado (por si acaso):
      ```bash
      docker run --rm \
        -v opencode-config:/data \
        -v $(pwd):/backup \
        alpine tar czf /backup/opencode-config-backup.tar.gz -C /data .
      ```

## Grupo 1: Scripts de bootstrap

1. [ ] Crear `scripts/init-data.sh` (idempotente, ejecutable):
   - Crea `./data/{opencode-auth,opencode-config,gh-config,cloudflared,ssh-cloud,ssh-devadmin,proyectos}/`
   - Setea permisos: `chmod 700` para SSH dirs, `chmod 755` para el resto
   - Copia `config/opencode.json` desde el repo a `./data/opencode-config/opencode.json`
   - Imprime la estructura resultante
2. [ ] Crear `scripts/migrate-volumes.sh` (idempotente, **usar una sola vez**):
   - Helper `migrate_volume()` que copia un named volume a un dir destino
     con `docker run --rm -v <vol>:/src -v <dest>:/dst alpine cp -a /src/. /dst/`
   - Migra `opencode-auth` → `./data/opencode-auth/`
   - Migra `opencode-tunnel` → `./data/cloudflared/`
   - Migra `opencode-proyectos` → `./data/proyectos/`
   - Migra `opencode-ssh` → `./data/ssh-cloud/`
   - Inspecciona `opencode-config` (bug: usado para dos paths) y lo
     migra a `./data/opencode-config/`
   - Imprime instrucciones para separar manualmente `opencode.json`
     (opencode) de `hosts.yml` (gh) y mover gh a `./data/gh-config/`
3. [ ] `chmod +x scripts/init-data.sh scripts/migrate-volumes.sh`
4. [ ] Validar idempotencia: `./scripts/init-data.sh && ./scripts/init-data.sh`
      (debe terminar OK ambas veces)

## Grupo 2: Refactor `docker-compose.yml`

5. [ ] Reemplazar la sección `volumes:` del servicio `opencode-vps` con
      bind mounts a `./data/...`
6. [ ] Renombrar `OPENCODE_GO_API_KEY` → `OPENCODE_API_KEY` en
      la sección `environment:`
7. [ ] Eliminar la sección `volumes:` final (los 5 named volumes ya no
      se usan)
8. [ ] Validar sintaxis: `docker compose config`

> El nuevo `volumes:` del servicio debe verse así:
> ```yaml
> volumes:
>   - ./data/opencode-auth:/home/cloud/.local/share/opencode
>   - ./data/opencode-config:/home/cloud/.config/opencode
>   - ./data/gh-config:/home/cloud/.config/gh
>   - ./data/cloudflared:/home/cloud/.cloudflared
>   - ./data/ssh-cloud:/home/cloud/.ssh
>   - ./data/ssh-devadmin:/home/devadmin/.ssh
>   - ./data/proyectos:/home/cloud/proyectos
> ```

## Grupo 3: Fix del nombre de env var (rename)

9. [ ] `.env` línea 11: `OPENCODE_GO_API_KEY` → `OPENCODE_API_KEY`
10. [ ] `.env.example` línea 21: mismo rename
11. [ ] `supervisor/opencode-web.conf` línea 4:
      `OPENCODE_GO_API_KEY="%(ENV_OPENCODE_GO_API_KEY)s"` →
      `OPENCODE_API_KEY="%(ENV_OPENCODE_API_KEY)s"`
12. [ ] Verificar: `grep -r OPENCODE_GO_API_KEY . --exclude-dir=specs`
      no debe encontrar nada (excepto `validation.md` como referencia
      histórica)

## Grupo 4: `.gitignore`

13. [ ] Agregar `data/` (raíz de bind mounts, NO commitear nunca)

## Grupo 5: `setup.sh`

14. [ ] Reescribir sección "[2/5] Configurar OpenCode Go" con el nuevo flujo:
    - Documentar que `./data/opencode-auth/auth.json` es la fuente de verdad
    - Documentar: si `auth.json` no existe, correr
      `opencode auth login --provider opencode-go`
    - Documentar que la env var `OPENCODE_API_KEY` es **opcional** (solo
      como backup para futuras automatizaciones)
    - Mantener el resto de `setup.sh` sin cambios

## Grupo 6: Documentación

15. [ ] `AGENTS.md`:
    - Renombrar referencias a `OPENCODE_GO_API_KEY` → `OPENCODE_API_KEY`
    - Agregar sección "Persistencia en host (`~/opencode-vps/data/`)"
      con tabla de subdirs ↔ path en contenedor
16. [ ] `README.md`:
    - Renombrar referencias
    - Agregar sección "Persistencia" explicando `./data/`, el bug del
      `opencode-config` duplicado, y cómo sobrevivir a `docker compose down -v`
17. [ ] `specs/tech-stack.md`:
    - Renombrar `OPENCODE_GO_API_KEY` → `OPENCODE_API_KEY` en
      "Variables de entorno"
    - Actualizar tabla "Directorios persistentes" con bind mounts
      en lugar de named volumes
    - Agregar nota sobre el bug del volumen duplicado que se corrigió

## Grupo 7: Validación destructiva end-to-end

> **En el VPS** (`~/opencode-vps/`), no en la máquina local.

18. [ ] Pull de la rama y aplicar cambios:
    ```bash
    cd ~/opencode-vps
    git fetch origin
    git checkout fix/persistencia-bind-mounts
    git pull
    ```
19. [ ] Inicializar `./data/`:
    ```bash
    ./scripts/init-data.sh
    ```
20. [ ] Migrar named volumes existentes (UNA sola vez):
    ```bash
    ./scripts/migrate-volumes.sh
    ```
21. [ ] Separar manualmente `opencode.json` de `hosts.yml`:
    ```bash
    ls -la data/opencode-config/   # ver qué hay
    # opencode.json → dejar en data/opencode-config/
    # hosts.yml (gh) → mover a data/gh-config/
    mv data/opencode-config/hosts.yml data/gh-config/  # ejemplo
    ```
22. [ ] Levantar contenedor con la nueva config:
    ```bash
    docker compose up -d
    ```
23. [ ] Verificar primer arranque (sin re-autenticar):
    - [ ] `docker compose exec -u cloud opencode-vps opencode models opencode-go`
          lista los 3 modelos (`glm-5.2`, `qwen3.7-max`, `kimi-k2.7-code`)
    - [ ] `docker compose exec opencode-vps ls -la /home/devadmin/.ssh/`
          existe y es `devadmin:devadmin`
    - [ ] `docker compose exec -u cloud opencode-vps gh auth status`
          muestra autenticado
24. [ ] **Test destructivo** (el criterio clave de aceptación):
    ```bash
    docker compose down -v
    docker compose up -d
    sleep 10  # esperar a que opencode-web arranque
    ```
25. [ ] Verificar que TODO persiste tras `down -v`:
    - [ ] `./data/opencode-auth/auth.json` existe (en host, fuera del contenedor)
    - [ ] `./data/ssh-cloud/` tiene las SSH keys (en host)
    - [ ] `./data/ssh-devadmin/` tiene archivos (en host, NUEVO)
    - [ ] `./data/proyectos/` tiene los proyectos del usuario
    - [ ] Dentro del contenedor, `opencode models opencode-go` lista
          modelos **SIN re-autenticar**
    - [ ] Dentro del contenedor, `gh auth status` muestra autenticado
          **SIN re-autenticar**

## Grupo 8: Merge

26. [ ] Validar criterios de éxito (ver `validation.md`)
27. [ ] `git status` para revisar staging (asegurar que `.env` y `data/`
      NO estén staged)
28. [ ] `git add .` (solo specs/ + scripts/ + compose/ + docs/ + .gitignore)
29. [ ] `git commit -m "fix(persistencia): migrar a bind mounts en host"`
30. [ ] `git push -u origin fix/persistencia-bind-mounts`
31. [ ] `gh pr create --base main --title "..." --body-file specs/2026-07-05-fix-persistencia-bind-mounts/validation.md`
32. [ ] Validar criterios de merge (ver `validation.md`)
33. [ ] `gh pr merge --merge --delete-branch`
34. [ ] Cleanup local: `git checkout main && git pull && docker compose down && docker compose up -d`

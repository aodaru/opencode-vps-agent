# Plan — Nueva Fase 6: Passwords dinámicos + validación persistencia

Plan secuencial. Cada grupo debe completarse antes del siguiente.
Marcar checkboxes al ejecutar.

## Pre-requisitos

- [ ] Estar en la rama `feat/fase6-passwords-config` (ya creada)
- [ ] Archivos leídos: Dockerfile, docker-compose.yml, .env, .env.example,
      scripts/fix-ownership.sh, supervisor/*.conf, setup.sh, README.md,
      AGENTS.md, specs/roadmap.md, specs/tech-stack.md

---

## Grupo 1: Variables de entorno

1. [ ] Agregar al `.env`:
   ```bash
   DEVADMIN_PASSWORD=changeme
   CLOUD_PASSWORD=changeme
   ```
2. [ ] Agregar a `.env.example` con comentario explicativo
3. [ ] Agregar a `docker-compose.yml` → `environment:`:
   ```yaml
   - DEVADMIN_PASSWORD=${DEVADMIN_PASSWORD}
   - CLOUD_PASSWORD=${CLOUD_PASSWORD}
   ```
4. [ ] Verificar: `docker compose config` sin errores

---

## Grupo 2: Script set-passwords.sh

5. [ ] Crear `scripts/set-passwords.sh`:
   - Ejecutable (`chmod +x`)
   - `set -euo pipefail`
   - Lee `DEVADMIN_PASSWORD` y `CLOUD_PASSWORD` del entorno
   - Si están seteadas y no vacías: `echo "user:pass" | chpasswd`
   - Si no están: log warning, no falla
   - Logging con timestamp a stdout/stderr

---

## Grupo 3: Supervisor conf

6. [ ] Crear `supervisor/set-passwords.conf`:
   - `command=/usr/local/bin/set-passwords.sh`
   - `user=root`
   - `autostart=true`, `autorestart=false`
   - `priority=2`
   - `exitcodes=0`
   - Logs en `/var/log/set-passwords.{log,err}`

---

## Grupo 4: Dockerfile

7. [ ] Eliminar línea 64: `&& echo "devadmin:changeme" | chpasswd \`
   (conservar `useradd` + `adduser devadmin sudo`)
8. [ ] Eliminar línea 68: `&& echo "cloud:changeme" | chpasswd`
   (conservar `useradd` para cloud)
9. [ ] Agregar COPY del nuevo script:
   ```dockerfile
   COPY scripts/set-passwords.sh /usr/local/bin/set-passwords.sh
   ```
10. [ ] Agregar COPY del nuevo supervisor conf:
    ```dockerfile
    COPY supervisor/set-passwords.conf /etc/supervisor/conf.d/set-passwords.conf
    ```
11. [ ] Agregar chmod +x:
    ```dockerfile
    RUN chmod +x /usr/local/bin/set-passwords.sh
    ```

---

## Grupo 5: Documentación

12. [ ] `setup.sh` — reescribir sección [1/5] para referenciar el nuevo
     mecanismo de `.env` en lugar de instrucciones manuales de passwd
13. [ ] `README.md` — actualizar tabla de persistencia y sección de
     seguridad con las nuevas variables
14. [ ] `AGENTS.md` — agregar `DEVADMIN_PASSWORD` y `CLOUD_PASSWORD`
     a la documentación de variables de entorno
15. [ ] `specs/tech-stack.md` — agregar filas a la tabla de variables

---

## Grupo 6: Roadmap

16. [ ] `specs/roadmap.md`:
     - Renombrar "Fase 6 (post-MVP)" → "Fase 7 (post-MVP)"
     - Insertar nueva "Fase 6: Passwords dinámicos + persistencia"
       antes de Fase 7
     - Actualizar tabla de estado

---

## Grupo 7: Build y validación

17. [ ] Build imagen:
     ```bash
     docker compose build --no-cache
     ```
18. [ ] Smoke test passwords:
     ```bash
     docker compose run --rm -e DEVADMIN_PASSWORD=test123 -e CLOUD_PASSWORD=test456 opencode-vps \
       bash -c '/usr/local/bin/set-passwords.sh && echo "devadmin:test123" | chpasswd -e 2>&1 || echo "OK no-op"'
     ```
19. [ ] Smoke test persistencia:
     ```bash
     # Arrancar, modificar opencode.json, bajar con -v, subir, verificar que el cambio persiste
     docker compose up -d
     docker compose exec -u cloud opencode-vps bash -c 'echo "{\"test\": true}" > /home/cloud/.config/opencode/test-persist.json'
     docker compose down -v
     docker compose up -d
     docker compose exec -u cloud opencode-vps cat /home/cloud/.config/opencode/test-persist.json
     # Debe mostrar {"test": true}
     docker compose exec -u cloud opencode-vps rm /home/cloud/.config/opencode/test-persist.json
     ```
20. [ ] Verificar que `opencode-web` arranca con la config persistida

---

## Grupo 8: Commit, push y merge

21. [ ] `git add -A`
22. [ ] `git commit -m "feat: fase6 - passwords desde .env + validacion persistencia"`
23. [ ] Validar criterios de éxito (ver `validation.md`)
24. [ ] `git push -u origin feat/fase6-passwords-config`
25. [ ] `gh pr create --base main --title "feat: fase6 - passwords desde .env" --body "$(cat specs/2026-07-08-auth-passwords-persist/validation.md)"`
26. [ ] Mergear PR y limpiar rama local

# Plan - Fix: Healthcheck HTTP en supervisord

Plan secuencial. Cada grupo debe completarse antes del siguiente.
Marcar checkboxes al ejecutar.

## Pre-requisitos

- [x] Estar en la rama `fix/healthcheck-supervisor` (creada desde `main`)
- [x] `main` actualizado con Fase 5 completada (healthcheck en docker-compose + script backup)

## Grupo 1: Agregar healthcheck program en supervisord

> Agrega un programa healthcheck que verifica HTTP cada 30s dentro del contenedor.

1. [ ] Editar `supervisor/opencode-web.conf`
2. [ ] Agregar sección `[program:healthcheck]` al final del archivo
3. [ ] Configurar:
   - command: loop curl cada 30s con logging
   - autostart=true
   - autorestart=true
   - startsecs=0
   - logs en /var/log/healthcheck.log

**Diff esperado:**
```diff
 [program:cloudflared]
 command=/usr/bin/cloudflared tunnel ...
 ...
 stderr_logfile_maxbytes=10MB
+
+[program:healthcheck]
+command=/bin/bash -c "while true; do curl -sf http://localhost:4096 > /dev/null && echo '[$(date)] OK' || echo '[$(date)] FAIL'; sleep 30; done"
+autostart=true
+autorestart=true
+startsecs=0
+stdout_logfile=/var/log/healthcheck.log
+stdout_logfile_maxbytes=5MB
+stderr_logfile=/var/log/healthcheck.err
+stderr_logfile_maxbytes=1MB
```

## Grupo 2: Validación local

4. [ ] Verificar que el archivo tiene la sintaxis correcta
5. [ ] No requiere cambios en Dockerfile (curl ya instalado)
6. [ ] No requiere cambios en docker-compose.yml

## Grupo 3: Deploy y validación en VPS

> ⚠️ Ejecutar en el VPS (`10.0.5.16`)

7. [ ] Pull de la rama:
   ```bash
   cd ~/opencode-vps
   git fetch origin
   git checkout fix/healthcheck-supervisor
   git pull
   ```

8. [ ] Reconstruir y rearrancar:
   ```bash
   docker compose up -d --build
   ```

9. [ ] Verificar healthcheck corriendo:
   ```bash
   docker exec opencode-vps supervisorctl status healthcheck
   # Esperado: healthcheck   RUNNING
   ```

10. [ ] Verificar logs:
    ```bash
    docker exec opencode-vps tail -5 /var/log/healthcheck.log
    # Esperado: registros con [date] OK
    ```

11. [ ] Verificar servicios existentes:
    ```bash
    curl -s -o /dev/null -w "HTTP: %{http_code}\n" http://localhost:4096
    # Esperado: HTTP: 200

    docker exec opencode-vps pgrep cloudflared
    docker exec opencode-vps pgrep sshd
    ```

## Grupo 4: Merge

12. [ ] Validar criterios de éxito (ver `validation.md`)
13. [ ] `git add .`
14. [ ] `git commit -m "feat: healthcheck HTTP en supervisord"`
15. [ ] `git push -u origin fix/healthcheck-supervisor`
16. [ ] `gh pr create --base main --title "feat: Healthcheck HTTP en supervisord" --body-file specs/2026-07-06-fix-healthcheck-supervisor/validation.md`
17. [ ] Merge PR
18. [ ] Cleanup: `git checkout main && git pull`

---

## Notas de implementación

### Por qué curl loop en vez de healthcheck estático de supervisord

Supervisord tiene un parámetro `healthcheck` nativo pero es limitado:
- Solo ejecuta un comando una vez
- No permite logging continuo
- No muestra historial de checks

El enfoque con loop permite:
- Logging continuo en `/var/log/healthcheck.log`
- Visibilidad de uptime/downtime
- Fácil debugging con `tail -f`

### Diferencia con el healthcheck de Docker

- **Docker healthcheck** (en docker-compose.yml): verificación externa, controla restart del contenedor
- **Supervisord healthcheck** (este fix): verificación interna, logging, monitoreo

Ambos son complementarios, no se reemplazan.

### Información de conexión VPS

| Parámetro | Valor |
|-----------|-------|
| Host | `10.0.5.16` (TrueNAS) |
| Usuario | `truenas_admin` |
| SSH key | `~/.ssh/id_ed25519_github` |
| Working dir en VPS | `/mnt/Aodnas/Docker/opencode-vps/` |

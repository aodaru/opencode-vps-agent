# Validación - Healthcheck HTTP en supervisord

## Criterios de éxito

La fase se considera completada y mergeable cuando se cumplan **todos**
los siguientes criterios.

### 1. Healthcheck program existe y es correcto

- [ ] `supervisor/opencode-web.conf` tiene sección `[program:healthcheck]`
- [ ] El command ejecuta curl cada 30s con logging
- [ ] Los logs van a `/var/log/healthcheck.log`
- [ ] `stdout_logfile_maxbytes=5MB` para rotación

### 2. Servicio corriendo en VPS

- [ ] `supervisorctl status healthcheck` muestra RUNNING
- [ ] `/var/log/healthcheck.log` tiene registros `[date] OK`
- [ ] Web UI sigue funcionando (HTTP 200)
- [ ] cloudflared sigue corriendo
- [ ] sshd sigue corriendo

### 3. Test destructivo

- [ ] `docker compose down -v && up -d`
- [ ] Healthcheck vuelve a correr automáticamente
- [ ] Logs se reinician (nuevos registros OK)

### 4. Documentación

- [ ] `specs/roadmap.md` actualizado si es necesario
- [ ] No se rompió nada existente

## Cómo verificar

```bash
# En el VPS (10.0.5.16)
cd /mnt/Aodnas/Docker/opencode-vps

# 1. Setup
git fetch origin
git checkout fix/healthcheck-supervisor
git pull
docker compose up -d --build
sleep 10

# 2. Verificar healthcheck
docker exec opencode-vps supervisorctl status healthcheck
# Esperado: healthcheck   RUNNING

# 3. Verificar logs
docker exec opencode-vps tail -5 /var/log/healthcheck.log
# Esperado: [Mon Jul  6 17:00:00 UTC 2026] OK

# 4. Verificar servicios
curl -s -o /dev/null -w "HTTP: %{http_code}\n" http://localhost:4096
# Esperado: HTTP: 200

docker exec opencode-vps pgrep cloudflared
docker exec opencode-vps pgrep sshd

# 5. Test destructivo
docker compose down -v
docker compose up -d
sleep 10

# Repetir checks 2-4
```

## Criterio de merge a main

- [ ] Todos los checkboxes de "Criterios de éxito" marcados
- [ ] PR abierto via `gh pr create`
- [ ] No hay secrets commiteados
- [ ] `data/` no está commiteado

## Anti-criterios (lo que NO debe pasar)

- [ ] ❌ `supervisorctl status healthcheck` muestra FATAL o EXITED
- [ ] ❌ `/var/log/healthcheck.log` muestra solo FAIL
- [ ] ❌ Web UI no responde después del cambio
- [ ] ❌ cloudflared o sshd dejaron de correr
- [ ] ❌ El healthcheck usa mucha CPU (debería ser <1%)

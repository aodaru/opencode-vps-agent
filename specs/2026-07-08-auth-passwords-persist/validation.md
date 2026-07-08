# Validación — Nueva Fase 6: Passwords dinámicos + persistencia

## Estado de la fase

**⬜ PENDIENTE**

## Criterios de éxito

### 1. Dockerfile

- [ ] Líneas `echo "devadmin:changeme" | chpasswd` eliminadas
- [ ] Líneas `echo "cloud:changeme" | chpasswd` eliminadas
- [ ] `COPY scripts/set-passwords.sh /usr/local/bin/set-passwords.sh` agregado
- [ ] `COPY supervisor/set-passwords.conf /etc/supervisor/conf.d/set-passwords.conf` agregado
- [ ] `RUN chmod +x /usr/local/bin/set-passwords.sh` agregado
- [ ] Build exitoso: `docker compose build --no-cache`

### 2. Variables de entorno

- [ ] `.env` contiene `DEVADMIN_PASSWORD` y `CLOUD_PASSWORD`
- [ ] `.env.example` contiene ambas variables con placeholder
- [ ] `docker-compose.yml` inyecta ambas variables al contenedor
- [ ] `docker compose config` no muestra errores

### 3. Script set-passwords.sh

- [ ] Script existe en `scripts/set-passwords.sh`
- [ ] Es ejecutable (`chmod +x`)
- [ ] Aplica `DEVADMIN_PASSWORD` cuando está definida
- [ ] Aplica `CLOUD_PASSWORD` cuando está definida
- [ ] Warningea (no falla) cuando alguna variable no está definida
- [ ] Funciona en modo dry-run / smoke test con env vars inline

### 4. Supervisor

- [ ] `supervisor/set-passwords.conf` existe
- [ ] `priority=2` (tras fix-ownership priority=1)
- [ ] `user=root`, `autorestart=false`
- [ ] Logs se escriben en `/var/log/set-passwords.log`

### 5. Persistencia de config/opencode

- [ ] Bind mount `./data/opencode-config:/home/cloud/.config/opencode` existe
- [ ] Modificar un archivo dentro de `/home/cloud/.config/opencode/`
      sobrevive a `docker compose down -v && docker compose up -d`
- [ ] `opencode-web` arranca correctamente con la config persistida

### 6. Roadmap

- [ ] Fase 6 actual (Post-MVP) renombrada a Fase 7
- [ ] Nueva Fase 6 insertada en el roadmap
- [ ] Tabla de estado actualizada

## Cómo verificar

```bash
# 1. Build
docker compose build --no-cache

# 2. Smoke test del script set-passwords
docker compose run --rm \
  -e DEVADMIN_PASSWORD=test123 \
  -e CLOUD_PASSWORD=test456 \
  opencode-vps \
  /usr/local/bin/set-passwords.sh

# 3. Verificar que los passwords se aplicaron
docker compose run --rm \
  -e DEVADMIN_PASSWORD=test123 \
  -e CLOUD_PASSWORD=test456 \
  opencode-vps \
  bash -c '
    /usr/local/bin/set-passwords.sh
    # Intentar login con los passwords (usando chpasswd -e como verificador indirecto)
    echo "devadmin:test123" | chpasswd -e 2>&1 && echo "OK: devadmin password works" || echo "FAIL"
    echo "cloud:test456" | chpasswd -e 2>&1 && echo "OK: cloud password works" || echo "FAIL"
  '

# 4. Verificar persistencia de config/opencode
docker compose up -d
docker compose exec -u cloud opencode-vps bash -c \
  'echo "{\"persist_test\": true}" > /home/cloud/.config/opencode/test-persist.json'
docker compose down -v
docker compose up -d
docker compose exec -u cloud opencode-vps bash -c \
  'cat /home/cloud/.config/opencode/test-persist.json'
# Output esperado: {"persist_test": true}
# Cleanup:
docker compose exec -u cloud opencode-vps bash -c \
  'rm /home/cloud/.config/opencode/test-persist.json'
```

## Criterio de merge a main

- [ ] Todos los criterios de éxito marcados
- [ ] PR abierto via `gh pr create`
- [ ] Validación manual ejecutada
- [ ] No hay cambios accidentales (solo Dockerfile, compose, .env, scripts/,
      supervisor/, specs/, setup.sh, README.md, AGENTS.md, .env.example)

## Anti-criterios (lo que NO debe pasar)

- ❌ Passwords hardcoded en la imagen Docker (no debe haber `changeme` en
     las líneas de `chpasswd` del Dockerfile)
- ❌ `set-passwords.sh` falla si una variable no está definida (debe warningear
     y seguir)
- ❌ La config de opencode se pierde tras `down -v`
- ❌ Se modificaron archivos fuera del alcance definido
- ❌ El build falla por errores de sintaxis en Dockerfile o conf

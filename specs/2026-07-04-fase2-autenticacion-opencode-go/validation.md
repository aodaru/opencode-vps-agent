# Validación - Fase 2: Autenticación OpenCode Go

## Criterios de éxito

La Fase 2 se considera completada y mergeable cuando se cumplan **todos** los siguientes criterios:

### 1. SSH en contenedor
- [x] `openssh-server` instalado en el Dockerfile
- [x] `sshd` corriendo bajo supervisord
- [x] `sshd` escuchando en puerto 22 dentro del contenedor
- [x] `PasswordAuthentication yes` configurado en `sshd_config`

### 2. Configuración correcta
- [x] `.env` contiene `OPENCODE_GO_API_KEY` con valor válido
- [x] `docker-compose.yml` inyecta `OPENCODE_GO_API_KEY` al contenedor
- [x] `.env` está en `.gitignore` (no se commitea al repositorio)

### 3. Contenedor funcionando
- [x] `docker compose up -d` ejecuta sin errores
- [x] `docker compose ps` muestra el contenedor en estado `running`
- [x] `docker compose exec opencode-vps env | grep OPENCODE_GO_API_KEY` muestra la variable

### 4. Smoke test básico
- [x] Los modelos Go aparecen en el endpoint `/models`
- [x] `opencode web` responde en `localhost:4096` dentro del contenedor
- [x] OpenCode puede analizar un proyecto de prueba con un modelo Go (comando `opencode init` o equivalente)

### 5. Acceso remoto (verificación adicional)
- [x] Se puede acceder a la web UI desde un browser externo vía `https://opencode.adalgarcia.com`
- [x] La autenticación HTTP Basic Auth sigue funcionando (`OPENCODE_SERVER_PASSWORD`)

## Cómo verificar

```bash
# 1. Verificar que el contenedor está corriendo
docker compose ps

# 2. Verificar sshd corriendo
docker compose exec opencode-vps ps aux | grep sshd

# 3. Verificar puerto 22 escuchando
docker compose exec opencode-vps ss -tlnp | grep 22

# 4. Verificar variable de entorno
docker compose exec opencode-vps env | grep OPENCODE_GO_API_KEY

# 5. Verificar modelos disponibles
curl -s http://localhost:4096/models | jq

# 6. Verificar acceso web
curl -s -o /dev/null -w "%{http_code}" http://localhost:4096
# Debe retornar 200 (o 401 si requiere auth)
```

## Criterio de merge

- [x] Todos los checkboxes de "Criterios de éxito" marcados
- [x] No hay secrets commiteados al repositorio
- [x] `docker compose up -d` funciona en el VPS sin intervención manual
- [x] `sshd` corriendo dentro del contenedor

# Validación — Instalar ffmpeg

## Estado de la fase

**⬜ PENDIENTE**

## Criterios de éxito

### 1. Dockerfile

- [x] `ffmpeg` agregado a la lista de paquetes en `apt-get install` (líneas 12-24)
- [ ] Build de imagen exitoso
- [ ] `docker compose config` no muestra errores de sintaxis
- [ ] `docker compose run --rm opencode-vps ffmpeg -version` devuelve la versión

### 2. ffmpeg instalado y accesible

- [ ] `docker compose run --rm opencode-vps ffmpeg -version` devuelve la versión
- [ ] El usuario `cloud` puede ejecutar ffmpeg:
      `docker compose run --rm -u cloud opencode-vps ffmpeg -version`

## Cómo verificar

```bash
# Build
docker compose build --no-cache

# Smoke test
docker compose run --rm opencode-vps ffmpeg -version 2>&1 | head -3

# Como cloud
docker compose run --rm -u cloud opencode-vps ffmpeg -version 2>&1 | head -1

# Output esperado:
# ffmpeg version N.0.1 Copyright (c) 2000-2024 the FFmpeg developers
```

## Criterio de merge a main

- [ ] Todos los criterios de éxito marcados
- [ ] PR abierto via `gh pr create`
- [ ] Validación manual ejecutada
- [ ] No hay cambios accidentales (solo `Dockerfile` + spec)

## Anti-criterios (lo que NO debe pasar)

- ❌ `ffmpeg -version` falla con "command not found"
- ❌ Se modificaron archivos que no son `Dockerfile` (aparte del spec nuevo)
- ❌ El build falla por un typo en el nombre del paquete

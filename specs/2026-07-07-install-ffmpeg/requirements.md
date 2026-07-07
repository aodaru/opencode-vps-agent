# Requisitos — Instalar ffmpeg

## Alcance

Agregar `ffmpeg` al contenedor OpenCode VPS para que el usuario `cloud`
pueda procesar audio/video desde el agente (ej. transcodificar, extraer
audio, generar thumbnails).

### Incluido

- Agregar `ffmpeg` al `apt-get install` existente en el Dockerfile
- Validar post-build con `ffmpeg -version`

### No incluido

- Configuración adicional de ffmpeg (codecs, perfiles)
- Scripts wrapper o helpers
- Instalación de `ffprobe` (viene con ffmpeg)
- Cambios en supervisor, compose, o documentación

## Decisiones

| ID | Decisión | Racional | Alternativa descartada |
|----|----------|----------|------------------------|
| D1 | Agregar `ffmpeg` al `apt-get install` existente (línea 12-24) | Evita una capa RUN extra. ffmpeg es pequeño (~30MB) y no alarga significativamente el build. | RUN separado (más capas, no necesario) |
| D2 | Usar `-qq` en apt (consistente con el patrón que pidió el usuario) | Menos ruido en build output. En Dockerfile `2>&1 \| tail -5` no es necesario (Docker ya captura stdout/stderr). | Sin `-qq` (más verbose) |

## Contexto

- **Dockerfile**: el `apt-get install` actual está en líneas 12-24, dentro de
  un solo `RUN`. ffmpeg se agrega a la misma lista de paquetes.
- **Stack**: Ubuntu 24.04 LTS. ffmpeg está disponible en los repos oficiales.
- **Usuario**: `cloud` (sin sudo). ffmpeg será ejecutable por cualquier usuario
  al instalarse en `/usr/bin/`.

## Dependencias

- **Fase 1**: Contenedor base funcionando (✅)

## Riesgos identificados

| Riesgo | Mitigación |
|--------|------------|
| ffmpeg no disponible en repos de Ubuntu 24.04 | Está en `universe` repo, habilitado por defecto |
| Capa de imagen más grande | ffmpeg ~30MB comprimido, ~80MB instalado. Impacto mínimo |
| Build falla si el mirror está caído | `apt-get update` ya ocurre antes, y el Dockerfile tiene `rm -rf /var/lib/apt/lists/*` al final |

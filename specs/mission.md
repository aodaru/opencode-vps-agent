# Misión

Tener un agente OpenCode 24/7 alojado en un VPS, accesible desde cualquier
dispositivo (móvil, tablet, laptop) mediante web browser, sin depender del
estado de la máquina local.

## Audiencia objetivo

- Uso personal (dev playground)
- Un solo desarrollador: @adalgarcia
- Proyectos personales accesibles remoto

## Problema que resuelve

La máquina local se suspende, pierde conectividad, o simplemente se apaga.
Con OpenCode en un VPS:

- El agente está siempre disponible
- Las sesiones persisten entre reinicios
- Se puede acceder desde el celular en cualquier momento
- No se pierde progreso en refactorizaciones o migraciones largas

## Contexto técnico

Adaptado de una guía original de Claude Code a OpenCode, aprovechando:

- **Cloudflare Tunnel** existente en el host (sin abrir puertos)
- **Docker Compose** para aislamiento y reproducibilidad
- **OpenCode Go** como proveedor de modelos (bajo costo, alta confiabilidad)

# Plan - Fase 2: Autenticación OpenCode Go

## Grupo 1: Instalar y configurar SSH en contenedor

1. [x] Agregar `openssh-server` al `apt-get install` en el Dockerfile
2. [x] Crear directorio `/run/sshd` (requerido por sshd)
3. [x] Configurar `sshd_config`: permitir autenticación por contraseña (`PasswordAuthentication yes`)
4. [x] Crear `supervisor/sshd.conf` para gestionar sshd bajo supervisord
5. [x] Verificar que el servicio SSH arranca con el contenedor

## Grupo 2: Configuración de autenticación OpenCode Go

6. [x] Agregar variable `OPENCODE_GO_API_KEY` al archivo `.env` existente
7. [x] Actualizar `docker-compose.yml` para inyectar `OPENCODE_GO_API_KEY` como variable de entorno al contenedor
8. [x] Actualizar `.gitignore` para confirmar que `.env` está excluido (verificar Fase 1)
9. [x] Actualizar `supervisor/opencode-web.conf` para pasar `OPENCODE_GO_API_KEY` al proceso

## Grupo 3: Verificación en contenedor

10. [x] Ejecutar `docker compose up -d` para reconstruir con la nueva variable
11. [x] Verificar dentro del contenedor que la variable está disponible
12. [x] Verificar que sshd está corriendo y escuchando en puerto 22

## Grupo 4: Smoke test

13. [x] Verificar que los modelos Go aparecen en el endpoint `/models`
14. [x] Verificar que `opencode web` responde correctamente en `localhost:4096`
15. [x] Confirmar que OpenCode puede analizar un proyecto de prueba con un modelo Go

## Grupo 5: Documentación

16. [x] Actualizar `specs/roadmap.md` marcando Fase 2 como completada
17. [x] Actualizar `specs/tech-stack.md` con `openssh-server` en el stack

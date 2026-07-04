# Plan - Fase 2: Autenticación OpenCode Go

## Grupo 1: Instalar y configurar SSH en contenedor

1. Agregar `openssh-server` al `apt-get install` en el Dockerfile
2. Crear directorio `/run/sshd` (requerido por sshd)
3. Configurar `sshd_config`: permitir autenticación por contraseña (`PasswordAuthentication yes`)
4. Crear `supervisor/sshd.conf` para gestionar sshd bajo supervisord
5. Verificar que el servicio SSH arranca con el contenedor

## Grupo 2: Configuración de autenticación OpenCode Go

6. Agregar variable `OPENCODE_GO_API_KEY` al archivo `.env` existente
7. Actualizar `docker-compose.yml` para inyectar `OPENCODE_GO_API_KEY` como variable de entorno al contenedor
8. Actualizar `.gitignore` para confirmar que `.env` está excluido (verificar Fase 1)
9. Actualizar `supervisor/opencode-web.conf` para pasar `OPENCODE_GO_API_KEY` al proceso

## Grupo 3: Verificación en contenedor

10. Ejecutar `docker compose up -d` para reconstruir con la nueva variable
11. Verificar dentro del contenedor que la variable está disponible
12. Verificar que sshd está corriendo y escuchando en puerto 22

## Grupo 4: Smoke test

13. Verificar que los modelos Go aparecen en el endpoint `/models`
14. Verificar que `opencode web` responde correctamente en `localhost:4096`
15. Confirmar que OpenCode puede analizar un proyecto de prueba con un modelo Go

## Grupo 5: Documentación

16. Actualizar `specs/roadmap.md` marcando Fase 2 como completada
17. Actualizar `specs/tech-stack.md` con `openssh-server` en el stack

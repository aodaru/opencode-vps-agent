# Requisitos — Nueva Fase 6: Passwords dinámicos + validación persistencia

## Alcance

Dos objetivos independientes pero agrupados en una misma fase:

### Objetivo A: Validar persistencia de `/home/cloud/.config/opencode/`

El bind mount `./data/opencode-config:/home/cloud/.config/opencode` ya
existe desde el fix de persistencia (PR #2). Este objetivo consiste en
documentar formalmente la validación de que la config de opencode
sobrevive a `docker compose down -v && docker compose up -d`, y que
cambios hechos via Web UI o edición directa del archivo se mantienen.

### Objetivo B: Passwords de `devadmin` y `cloud` desde `.env`

Actualmente los passwords están hardcoded como `changeme` en el
Dockerfile (líneas 64 y 68). Hay que cambiarlos manualmente post-
arranque con `docker compose exec ... passwd`.

Este objetivo permite definir `DEVADMIN_PASSWORD` y `CLOUD_PASSWORD` en
`.env` para que se apliquen automáticamente al arrancar el contenedor,
sin intervención manual y sin dejar secretos en la imagen Docker.

### Incluido

- Agregar `DEVADMIN_PASSWORD` y `CLOUD_PASSWORD` a `.env` / `.env.example`
- Inyectar ambas variables al contenedor via `docker-compose.yml`
- Crear `scripts/set-passwords.sh` (lee env vars y ejecuta `chpasswd`)
- Crear `supervisor/set-passwords.conf` (corre una vez al arrancar,
  priority=2, tras fix-ownership)
- Modificar Dockerfile: eliminar `echo "user:changeme" | chpasswd`
  (los usuarios se crean sin password o con password aleatorio)
- Documentar el mecanismo en `setup.sh`, `README.md`, `AGENTS.md`,
  `specs/tech-stack.md`
- Validar persistencia del bind mount `opencode-config`
- Mover Fase 6 (Post-MVP) actual a Fase 7 en el roadmap

### No incluido

- Rotación periódica de passwords (eso queda para Fase 7)
- Integración con gestor de secretos externo (Vault, etc.)
- Multi-agente ni otros items de Post-MVP
- Cambios en cloudflared, gh CLI, SSH keys, u otros servicios

## Decisiones

| ID | Decisión | Racional | Alternativa descartada |
|----|----------|----------|------------------------|
| D1 | Script independiente `set-passwords.sh` + supervisor conf propio | Separación clara de concerns, fácil de deshabilitar o debuggear individualmente | Extender `fix-ownership.sh` (mezclaba lógica de filesystem con cuentas de usuario) |
| D2 | Passwords se eliminan del Dockerfile (no se setea ningún password en build) | Evita que secretos queden en capas de la imagen. El startup script los aplica antes de que sshd acepte conexiones | Usar `--build-arg` (quedan en history de Docker) |
| D3 | Variables en `.env` con nombres `DEVADMIN_PASSWORD` y `CLOUD_PASSWORD` | Consistentes con el patrón existente (`OPENCODE_SERVER_PASSWORD`). Claros respecto a qué usuario afectan | `SSH_USER_PASSWORD` (ambiguo) |
| D4 | Supervisor priority=2 (tras fix-ownership priority=1) | `fix-ownership` asegura que los home dirs existan antes de setear passwords | No importa el orden real (chpasswd no depende de ownership), pero es buena práctica |

## Contexto

- **Dockerfile**: líneas 63-68 crean `devadmin` y `cloud` con `changeme`
- **`fix-ownership.sh`**: corre en startup via supervisor (priority=1)
- **`docker-compose.yml`**: ya inyecta `OPENCODE_SERVER_PASSWORD`,
  `CLOUDFLARE_TUNNEL_TOKEN`, `OPENCODE_API_KEY`, `GH_TOKEN`
- **Stack**: Ubuntu 24.04, usuarios locales, SSH con PasswordAuthentication
- **Usuario cloud**: corre opencode-web; necesita poder hacer SSH desde el
  agente hacia GitHub (ya configurado con SSH key)

## Dependencias

- **Fase 1-5**: todas completadas (✅)
- **Fix persistencia bind mounts**: bind mount `opencode-config` existe (✅)

## Riesgos identificados

| Riesgo | Mitigación |
|--------|------------|
| Variables no definidas en `.env` | Script set-passwords.sh warninguea y deja password aleatorio (no falla) |
| Password débil | Responsabilidad del usuario. El script no valida fortaleza |
| `chpasswd` falla si el usuario no existe | Los usuarios se crean en Dockerfile, siempre existen |
| Supervisor no alcanza a correr set-passwords antes de sshd | sshd corre en paralelo. Ventana de ~1s donde el password sigue siendo el aleatorio del build. Aceptable para un contenedor single-user |

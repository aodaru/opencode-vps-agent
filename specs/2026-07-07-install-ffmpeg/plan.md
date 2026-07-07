# Plan — Instalar ffmpeg

Plan secuencial. Cada grupo debe completarse antes del siguiente.
Marcar checkboxes al ejecutar.

## Pre-requisitos

- [ ] Estar en la rama `feat/install-ffmpeg` (ya creada)
- [ ] Dockerfile leído y línea de apt-get localizada (líneas 12-24)

## Grupo 1: Editar Dockerfile

1. [ ] Agregar `ffmpeg` al `apt-get install` existente en el Dockerfile:
   ```dockerfile
   RUN apt-get update -qq && apt-get install -y \
       sudo \
       curl \
       git \
       tmux \
       ufw \
       fail2ban \
       ca-certificates \
       supervisor \
       xdg-utils \
       openssh-server \
       ffmpeg \
       && rm -rf /var/lib/apt/lists/* \
       && mkdir -p /run/sshd
   ```
2. [ ] Verificar sintaxis: `docker compose config`

## Grupo 2: Build y validación

3. [ ] Build de la imagen:
   ```bash
   docker compose build --no-cache
   ```
4. [ ] Smoke test:
   ```bash
   docker compose run --rm opencode-vps ffmpeg -version 2>&1 | head -3
   ```
5. [ ] Verificar que `cloud` puede ejecutarlo:
   ```bash
   docker compose run --rm -u cloud opencode-vps ffmpeg -version 2>&1 | head -1
   ```

## Grupo 3: Commit y merge

6. [ ] `git add Dockerfile specs/2026-07-07-install-ffmpeg/`
7. [ ] `git commit -m "feat: instalar ffmpeg en el contenedor"`
8. [ ] Validar criterios de éxito (ver `validation.md`)
9. [ ] `git push -u origin feat/install-ffmpeg`
10. [ ] `gh pr create --base main --title "feat: instalar ffmpeg" --body-file specs/2026-07-07-install-ffmpeg/validation.md`
11. [ ] Mergear PR y limpiar rama local

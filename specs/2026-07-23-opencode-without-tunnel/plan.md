# Plan — Remover Cloudflare Tunnel

Plan secuencial. Cada grupo debe completarse antes del siguiente.
Marcar checkboxes al ejecutar.

## Pre-requisitos

- [ ] Estar en la rama `2026-07-23-opencode-without-tunnel` (verificada)
- [ ] Rama persistente `opencode-cloudflare-tunnel` ya creada desde `main`
- [ ] Archivos leídos: todos los que lista `requirements.md`

---

## Grupo 1: Config de infraestructura

1. [ ] `Dockerfile`:
   - Remover sección 3 (cloudflared install, líneas 44-48)
   - Actualizar comentario de cabecera (línea 3)
2. [ ] `docker-compose.yml`:
   - Remover `CLOUDFLARE_TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}` de `environment:`
   - Remover bind mount `./data/cloudflared:/home/cloud/.cloudflared`
   - Actualizar comentario del puerto 4096 (ya no es para el tunnel)
3. [ ] `.env.example`:
   - Remover línea `CLOUDFLARE_TUNNEL_TOKEN=...` y su comentario
4. [ ] `config/cloudflared.yml` — **eliminar archivo**

---

## Grupo 2: Supervisor

5. [ ] `supervisor/opencode-web.conf`:
   - Remover sección `[program:cloudflared]` (líneas 15-26)

---

## Grupo 3: Scripts

6. [ ] `scripts/fix-ownership.sh`:
   - Remover línea `fix_dir "cloud" "/home/cloud/.cloudflared"` (línea 117)
7. [ ] `scripts/init-data.sh`:
   - Remover entrada `[cloudflared]=755` del array DIRS (línea 34)

---

## Grupo 4: Documentación

8. [ ] `setup.sh`:
   - Reemplazar sección `[3/5] Configurar Cloudflare Tunnel` con un aviso
     de que el tunnel se configuró en el host y no es necesario dentro
     del contenedor
9. [ ] `README.md`:
   - Remover referencias a Cloudflare Tunnel en características, stack,
     requisitos, estructura, estado del proyecto, persistencia
10. [ ] `AGENTS.md`:
    - Remover referencias en misión, contexto técnico, stack, arquitectura,
      tabla de persistencia, fases del proyecto
11. [ ] `specs/roadmap.md`:
    - Marcar Fase 3 como obsoleta (reemplazada)
    - Actualizar notas de implementación
    - Actualizar tabla de estado
12. [ ] `specs/tech-stack.md`:
    - Remover cloudflared de la tabla, arquitectura, decisiones técnicas
    - Remover `CLOUDFLARE_TUNNEL_TOKEN` de variables de entorno
    - Remover bind mount cloudflared de directorios persistentes
13. [ ] `specs/mission.md`:
    - Actualizar contexto técnico (ya no depende de Cloudflare Tunnel)

---

## Grupo 5: Verificación

14. [ ] Verificar que no quedan referencias a cloudflared/Cloudflare Tunnel:
     ```bash
     rg -i "cloudflared|cloudflare.tunnel|CLOUDFLARE_TUNNEL" --type-add 'all:*' -t all
     ```
     Solo deben aparecer en:
     - La rama `opencode-cloudflare-tunnel` (snapshot, no se toca)
     - La documentación histórica (specs anteriores, no se modifican)
     - El README/AGENTS como nota de migración histórica (opcional)
15. [ ] Verificar que `opencode-web.conf` ya no tiene la sección cloudflared
16. [ ] Verificar que `docker-compose.yml` no referencia cloudflared ni el token
17. [ ] Verificar que `fix-ownership.sh` no referencia `/home/cloud/.cloudflared`

---

## Grupo 6: Commit, push y PR

18. [ ] `git add -A`
19. [ ] `git commit -m "feat: remove cloudflare tunnel from container"`
20. [ ] Validar criterios de éxito (ver `validation.md`)
21. [ ] `git push -u origin 2026-07-23-opencode-without-tunnel`
22. [ ] `gh pr create --base main --title "feat: remove cloudflare tunnel from container" --body "$(cat specs/2026-07-23-opencode-without-tunnel/validation.md)"`
23. [ ] Mergear PR y limpiar rama local

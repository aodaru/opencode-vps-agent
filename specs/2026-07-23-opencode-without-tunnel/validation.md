# Validation — Remover Cloudflare Tunnel

## Criterios de éxito

1. **Build exitoso**: `docker compose build --no-cache` pasa sin errores
2. **Sin cloudflared en el contenedor**:
   ```bash
   docker compose run --rm opencode-vps which cloudflared
   # Esperado: no encontrado (exit 1)
   ```
3. **Sin proceso cloudflared**:
   ```bash
   docker compose up -d && docker compose exec opencode-vps ps aux | grep cloudflared
   # Esperado: sin resultados (vacío)
   ```
4. **OpenCode Web funciona**:
   ```bash
   curl -sf -u opencode:${OPENCODE_SERVER_PASSWORD} http://localhost:4096
   # Esperado: respuesta HTTP 200
   ```
5. **Sin referencias residuales**:
   ```bash
   rg -i "cloudflared|cloudflare.tunnel|CLOUDFLARE_TUNNEL" --type-add 'all:*' -t all
   ```
   Solo deben aparecer en:
   - `opencode-cloudflare-tunnel` branch (no se toca)
   - Specs históricos anteriores (no se modifican)
6. **Configs limpias**:
   - `docker compose config` no muestra `CLOUDFLARE_TUNNEL_TOKEN`
   - `opencode-web.conf` no tiene sección `[program:cloudflared]`
   - `fix-ownership.sh` no menciona `.cloudflared`
   - `init-data.sh` no incluye `cloudflared` en DIRS
   - `.env.example` no tiene `CLOUDFLARE_TUNNEL_TOKEN`

## Prerequisitos para mergear a main

- [ ] Todos los criterios de éxito validados
- [ ] `docker compose build --no-cache` sin errores
- [ ] Smoke test: `docker compose up -d` + `curl localhost:4096` OK
- [ ] Rama `opencode-cloudflare-tunnel` existe en origin (persistente)
- [ ] No hay cambios sin commitear

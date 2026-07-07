# Plan: Node.js 22 + pnpm para usuario cloud

## Objetivo
Que el usuario `cloud` (sin sudo, sin root) pueda usar `node`, `npm`, `npx` y `pnpm` dentro de `/home/cloud/proyectos` para instalar frameworks como Astro.

## Restricciones
- `cloud` **no puede** hacer `npm install -g` (protegido por permisos de `/usr/local/`)
- `pnpm` debe funcionar normalmente (via corepack)
- No se instalan paquetes globales con npm
- No se modifica la configuración de usuarios existentes

## Archivos a modificar

| Archivo | Cambio |
|---------|--------|
| `Dockerfile` | Agregar RUN de Node.js 22 LTS tarball + `corepack enable pnpm` |

## Archivos nuevos

| Archivo | Contenido |
|---------|-----------|
| `2025-07-06-node-pnpm/specs.md` | Especificación técnica detallada |

## Pasos

1. Crear rama `feat/node-pnpm`
2. Crear carpeta `2025-07-06-node-pnpm/` con specs
3. Editar `Dockerfile` (insertar bloque Node.js entre apt-get y OpenCode)
4. Commit local
5. scp archivos modificados al VPS TrueNAS
6. SSH a TrueNAS: `docker compose build --no-cache && docker compose up -d`
7. Verify: `docker exec opencode-vps su - cloud -c "node --version && pnpm --version"`
8. Commit final

## Verificación

```bash
docker exec opencode-vps su - cloud -c '
  echo "node: $(node --version)"
  echo "npm:  $(npm --version)"
  echo "npx:  $(npx --version)"
  echo "pnpm: $(pnpm --version)"
  # Probar que npm install -g falla
  npm install -g cowsay 2>&1 && echo "ERROR: deberia haber fallado" || echo "OK: npm -g bloqueado"
  # Probar que pnpm funciona
  pnpm --help > /dev/null && echo "OK: pnpm accesible"
'
```

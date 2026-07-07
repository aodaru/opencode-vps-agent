# Specs: Node.js 22 + pnpm en OpenCode VPS

## Cambio en Dockerfile

Insertar después del bloque de dependencias base (línea 24: `rm -rf /var/lib/apt/lists/*`) y antes de la sección OpenCode (línea 27):

```dockerfile
# ============================================================
# 1b. Node.js 22 LTS (pnpm via corepack, sin npm global)
# ============================================================
ENV NODE_VERSION=22.14.0
RUN curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz \
    | tar -xzf - -C /usr/local --strip-components=1 \
    && corepack enable pnpm
```

## Por qué tarball en lugar de NodeSource

| Método | Ventaja | Desventaja |
|--------|---------|------------|
| NodeSource APT repo | Sigue releases de Ubuntu | Agrega repos APT, más pasos en build |
| Tarball oficial | Directo en `/usr/local/`, no requiere repos | Actualización manual de `NODE_VERSION` |
| nvm | Fácil de versionar | Requiere bashrc, no es system-wide |

## Seguridad: bloqueo de npm global

- `/usr/local/lib/node_modules` es propiedad de root (0300)
- `/usr/local/bin/` es propiedad de root
- `cloud` no tiene sudo → cualquier `npm install -g` falla con EACCES
- `pnpm` usa corepack, que no escribe en `/usr/local/` para installs

## Resultado esperado

```bash
# Como cloud:
$ node --version   # v22.14.0
$ npm --version    # 10.x
$ npx --version    # 10.x
$ pnpm --version   # 9.x
$ npm install -g anything  # EACCES → denegado ✓
```

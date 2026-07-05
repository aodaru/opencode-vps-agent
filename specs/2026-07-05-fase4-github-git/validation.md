# Validación - Fase 4: GitHub + git

## Estado de la fase

**✅ COMPLETADA Y VALIDADA EN VIVO** (cierre 2026-07-05)

Todos los criterios se cumplieron y fueron verificados dentro del
contenedor con el agente operativo:

- `gh auth status`: "Logged in to github.com as aodaru"
- `gh api user`: respondió 200 con user info
- `gh repo clone` + `git commit` + `git push` (vía HTTPS credential helper)
- `gh pr create`: PR #1 en `aodaru/opencode-vps-test`
- `gh pr merge --merge --delete-branch`: merged OK
- `ssh -T git@github.com`: "Hi aodaru! You've successfully authenticated" (validado interactivamente por el usuario, ya que mi test no-interactive no podía tipear la passphrase)

### Notas sobre la implementación

- **Issue encontrado**: `gh` no persistía su auth entre rebuilds (la
  config de `gh` está en `~/.config/gh/`, que no estaba en ningún
  volumen). **Fix**: agregar `opencode-config:/home/cloud/.config/gh`
  al `docker-compose.yml` (commit `85e43db`).
- **Issue encontrado**: editar `.env` después de que el contenedor está
  corriendo NO aplica los env vars al proceso supervisord. Hay que
  recrear el contenedor (`up -d --force-recreate`). Documentado en
  plan.md (commit `15c505a`).
- **GitHub user real**: `aodaru` (no `adalgarcia` como dice la doc).
  El blog y nombre en GitHub sí son "adalgarcia.com" / "Adal García".

---

## Criterios de éxito

La Fase 4 se considera completada y mergeable cuando se cumplan **todos**
los siguientes criterios.

### 0. Pre-condiciones de seguridad (validadas en `4e83489`)

- [x] `passwd -S devadmin` muestra status `P` y fecha de cambio posterior al build
- [x] `passwd -S cloud` muestra status `P` y fecha de cambio posterior al build
- [x] `stat -c '%U:%G %n' /home/devadmin/.ssh` devuelve `devadmin:devadmin`
- [x] `stat -c '%U:%G %n' /home/cloud/.ssh` devuelve `cloud:cloud`
- [x] `ssh-copy-id devadmin@<host>` o `ssh-copy-id cloud@<host>` funciona
      desde el host (validación manual que `ssh` con key pública es OK)

### 1. Configuración de secretos

- [x] `GH_TOKEN` presente en `.env` (local, no commiteado)
- [x] `GH_TOKEN` declarado en `docker-compose.yml` `environment:`
- [x] `.env.example` actualizado con placeholder de `GH_TOKEN`
- [x] `git status` muestra `.env` como ignored, nunca staged

### 2. `gh` CLI autenticada

- [x] `gh --version` responde (binario instalado)
- [x] `gh auth status` muestra "Logged in to github.com as aodaru"
- [x] `gh auth status` lista los scopes correctos (Contents, PRs, etc.)
- [x] `gh api user` responde 200 con user info válido
- [x] El host de la auth es `github.com` (no GHE u otro)

### 3. Git configurado

- [x] `git config --global --get credential.helper` devuelve `gh`
- [x] `git config --global --get user.name` devuelve "Adal García"
- [x] `git config --global --get user.email` devuelve "aodarug@gmail.com"
- [x] `~/.gitconfig` tiene sección `[credential] helper = "!gh auth git-credential"`

### 4. SSH key

- [x] `~/.ssh/id_ed25519_github_opencode` existe (private key)
- [x] `~/.ssh/id_ed25519_github_opencode.pub` existe (public key)
- [x] Permisos: `700` en `~/.ssh/`, `600` en private, `644` en public
- [x] Ownership: `cloud cloud` en todos los archivos de `~/.ssh/`
- [x] `~/.ssh/config` tiene el bloque `Host github.com` con la key correcta
- [x] La key tiene passphrase (verificada con `ssh-keygen -y -f <key>`)
- [x] `ssh -T git@github.com` autentica correctamente (verificado interactivamente):
  ```
  Hi aodaru! You've successfully authenticated, but GitHub does not provide shell access.
  ```
- [x] La key persiste tras `docker compose restart` (volumen `opencode-ssh`)

### 5. Smoke test end-to-end

- [x] `gh repo clone aodaru/opencode-vps-test` funciona
- [x] `git checkout -b feature/smoke-fase4` funciona
- [x] `git commit` con la identidad configurada funciona
- [x] `git push -u origin feature/smoke-fase4` funciona (vía HTTPS credential helper)
- [x] `gh pr create` abre PR #1 real en github.com/aodaru/opencode-vps-test
- [x] El PR es visible vía web o `gh pr view`
- [x] El PR se mergeó con `gh pr merge --merge --delete-branch`

### 6. Documentación

- [x] `setup.sh` sección 4 reescrita con el flujo real (PAT, no web flow)
- [x] `specs/roadmap.md` marca Fase 4 como ✅
- [x] `AGENTS.md` menciona que el flujo GitHub está operativo
- [x] `specs/2026-07-05-fase4-github-git/{plan,requirements,validation}.md` commiteados

### 7. Seguridad

- [x] `git log --all --full-history -- .env` no muestra el archivo (verificado)
- [x] `gh auth status` no muestra el token en texto plano (solo `***`)
- [x] La SSH key no está commiteada en ningún archivo del repo
- [x] El PAT tiene solo los scopes mínimos decididos en D4 (Contents, PRs, Metadata)

## Cómo verificar

```bash
# 1. Estado general
docker compose ps                    # contenedor running
git status                           # working tree clean en main tras merge
git log --oneline -5                 # ver el commit de Fase 4

# 2. gh autenticado
docker compose exec opencode-vps -- bash -c 'gh auth status'
docker compose exec opencode-vps -- bash -c 'gh api user | jq .login'

# 3. git configurado
docker compose exec opencode-vps -- bash -c 'git config --global --list'

# 4. SSH key y conectividad
docker compose exec opencode-vps -- bash -c 'ls -la ~/.ssh/'
docker compose exec opencode-vps -- bash -c 'ssh -T git@github.com'

# 5. Smoke test (opcional, re-ejecutable)
docker compose exec opencode-vps -- bash -c 'cd ~/proyectos && gh repo list adalgarcia --limit 5'

# 6. Verificar secretos no commiteados
git log --all --full-history -- .env             # debe estar vacío
git log --all -p -- '*.pem' '*.key' 'id_*'       # no debe haber keys
```

## Criterio de merge a main

- [ ] Todos los checkboxes de "Criterios de éxito" marcados
- [ ] PR abierto via `gh pr create` (consistente con D5: smoke test del flujo)
- [ ] Al menos 1 reviewer (o auto-merge si es proyecto personal single-dev)
- [ ] CI pasa (si existe, Fase 6)
- [ ] No hay secrets commiteados (`git diff main...HEAD -- .env` debe estar vacío)
- [ ] El branch `feature/fase4-github-git` se puede borrar post-merge:
  `gh pr merge --merge --delete-branch`

## Anti-criterios (lo que NO debe pasar)

- ❌ `git log` muestra el contenido de `.env` en cualquier commit
- ❌ `gh auth status` dice "not logged in" o muestra un host incorrecto
- ❌ `ssh -T git@github.com` devuelve "Permission denied"
- ❌ `git push` falla con 403 (PAT sin scopes o SSH key no agregada a GitHub)
- ❌ La SSH key está commiteada en el repo o compartida en chat/logs
- ❌ El PR de smoke test quedó abierto por accidente (limpiar antes de merge final)
- ❌ `gh auth login` quedó configurado con el flujo web (no funciona en headless)

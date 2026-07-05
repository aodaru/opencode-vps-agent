# Validación - Fase 4: GitHub + git

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

- [ ] `GH_TOKEN` presente en `.env` (local, no commiteado)
- [ ] `GH_TOKEN` declarado en `docker-compose.yml` `environment:`
- [ ] `.env.example` actualizado con placeholder de `GH_TOKEN`
- [ ] `git status` muestra `.env` como ignored, nunca staged

### 2. `gh` CLI autenticada

- [ ] `gh --version` responde (binario instalado)
- [ ] `gh auth status` muestra "Logged in to github.com as adalgarcia"
- [ ] `gh auth status` lista los scopes correctos (Contents, PRs, etc.)
- [ ] `gh api user` responde 200 con user info válido
- [ ] El host de la auth es `github.com` (no GHE u otro)

### 3. Git configurado

- [ ] `git config --global --get credential.helper` devuelve `gh`
- [ ] `git config --global --get user.name` devuelve `adalgarcia`
- [ ] `git config --global --get user.email` devuelve el email de GitHub
- [ ] `~/.gitconfig` tiene sección `[credential] helper = "gh"` o `helper = "!gh auth git-credential"`

### 4. SSH key

- [ ] `~/.ssh/id_ed25519_github_opencode` existe (private key)
- [ ] `~/.ssh/id_ed25519_github_opencode.pub` existe (public key)
- [ ] Permisos: `700` en `~/.ssh/`, `600` en private, `644` en public
- [ ] Ownership: `cloud cloud` en todos los archivos de `~/.ssh/`
- [ ] `~/.ssh/config` tiene el bloque `Host github.com` con la key correcta
- [ ] La key tiene passphrase (verificable con `ssh-keygen -y -f <key>`)
- [ ] `ssh -T git@github.com` autentica correctamente:
  ```
  Hi adalgarcia! You've successfully authenticated, but GitHub does not provide shell access.
  ```
- [ ] La key persiste tras `docker compose restart` (volumen `opencode-ssh`)

### 5. Smoke test end-to-end

- [ ] `gh repo clone adalgarcia/opencode-vps-test` funciona
- [ ] `git checkout -b feature/test-fase4` funciona
- [ ] `git commit` con la identidad configurada funciona
- [ ] `git push -u origin feature/test-fase4` funciona vía SSH
- [ ] `gh pr create` abre un PR real en github.com/adalgarcia/opencode-vps-test
- [ ] El PR es visible vía web o `gh pr view`
- [ ] El PR se puede mergear (vía web o `gh pr merge --merge`)

### 6. Documentación

- [ ] `setup.sh` sección 4 reescrita con el flujo real (PAT, no web flow)
- [ ] `specs/roadmap.md` marca Fase 4 como ✅
- [ ] `AGENTS.md` menciona que el flujo GitHub está operativo
- [ ] `specs/2026-07-05-fase4-github-git/{plan,requirements,validation}.md` commiteados

### 7. Seguridad

- [ ] `git log --all --full-history -- .env` no muestra el archivo (verificar
  que nunca se filtró)
- [ ] `gh auth status` no muestra el token en texto plano
- [ ] La SSH key no está commiteada en ningún archivo del repo
- [ ] El PAT tiene solo los scopes mínimos decididos en D4

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

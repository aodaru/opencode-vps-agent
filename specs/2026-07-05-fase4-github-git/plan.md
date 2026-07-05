# Plan - Fase 4: GitHub + git

Plan secuencial. Cada grupo debe completarse antes de pasar al siguiente.
Marcar checkboxes al ejecutar.

## Pre-requisitos (antes de empezar)

- [x] Estar en la rama `feature/fase4-github-git`
- [x] **Pre-condiciones de seguridad (heredadas de Fase 2, validadas en `4e83489`)**:
  - [x] Passwords de `devadmin` y `cloud` cambiadas (Dockerfile los crea con `changeme`)
  - [x] Ownership de `/home/devadmin/.ssh` y `/home/cloud/.ssh` correcto
    (script `fix-ssh-ownership.sh` valida y corrige al arrancar)
  - [x] `ssh-copy-id` funciona desde el host al contenedor
- [ ] Tener cuenta de GitHub con acceso a al menos un repo privado
- [ ] Decidir scopes del PAT (ver `requirements.md` D4)
- [ ] Generar PAT en https://github.com/settings/tokens con los scopes decididos
- [ ] Decidir passphrase de la SSH key (D3: con passphrase recomendado)

## Grupo 1: Inyectar PAT como secreto

1. [ ] Agregar al `.env` (local, NO commitear):
   ```bash
   GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
2. [ ] Actualizar `.env.example` con la variable vacía como placeholder + comentario
3. [ ] Verificar que `.gitignore` cubre `.env` (debería estar OK desde Fase 1)
4. [ ] Agregar `GH_TOKEN` a `docker-compose.yml` en la sección `environment:`
5. [ ] `docker compose up -d` (sin `--build` salvo que haya cambios al Dockerfile)
6. [ ] Verificar que la variable llega al contenedor:
   `docker compose exec opencode-vps env | grep GH_TOKEN`

## Grupo 2: Autenticación `gh` dentro del contenedor

Entrar al contenedor:
```bash
ssh cloud@ssh.adalgarcia.com
# o directo: ssh -p 2222 cloud@<host>
```

7. [ ] `gh --version` (sanity check)
8. [ ] `echo "$GH_TOKEN" | gh auth login --hostname github.com --gitprotocol https --with-token`
9. [ ] Verificar: `gh auth status` → debe mostrar "Logged in to github.com as adalgarcia"
10. [ ] Verificar scopes concedidos: `gh auth status` (sección "Token scopes")
11. [ ] Smoke test API: `gh api user` → debe devolver user info en JSON

## Grupo 3: Configurar git con `gh` (HTTPS credential helper)

12. [ ] `gh auth setup-git` → configura `credential.helper=gh` en `~/.gitconfig`
13. [ ] Verificar: `git config --global --get credential.helper` → debe devolver `gh`
14. [ ] Configurar identidad git si no la tiene:
    ```bash
    git config --global user.name "adalgarcia"
    git config --global user.email "tu-email@github.com"
    ```
15. [ ] Verificar: `git config --global --list` (revisar user.name, user.email, credential.helper)

## Grupo 4: Generar SSH key para `git push/pull` directo

> **Importante**: estar logueado como usuario `cloud`, NO como root.
> La key debe quedar en `/home/cloud/.ssh/` (volumen `opencode-ssh`).

16. [ ] Confirmar usuario actual: `whoami` → debe ser `cloud`
17. [ ] Generar la key:
    ```bash
    ssh-keygen -t ed25519 -C "opencode-vps-agent" -f ~/.ssh/id_ed25519_github_opencode
    ```
    - Cuando pida passphrase: usar una fuerte (D3)
18. [ ] Permisos correctos:
    ```bash
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/id_ed25519_github_opencode
    chmod 644 ~/.ssh/id_ed25519_github_opencode.pub
    ```
19. [ ] Verificar ownership: `ls -la ~/.ssh/` → todos los archivos deben ser `cloud cloud`
20. [ ] Configurar `~/.ssh/config`:
    ```
    Host github.com
      IdentityFile ~/.ssh/id_ed25519_github_opencode
      IdentitiesOnly yes
    ```
21. [ ] Permisos en config: `chmod 600 ~/.ssh/config`
22. [ ] Iniciar ssh-agent y agregar la key (para no tipear passphrase cada vez):
    ```bash
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519_github_opencode
    ```
23. [ ] Verificar: `ssh-add -l` → debe listar la key

## Grupo 5: Agregar llave pública a GitHub

24. [ ] Mostrar la pública: `cat ~/.ssh/id_ed25519_github_opencode.pub`
25. [ ] Copiar el output completo (una línea, empieza con `ssh-ed25519 ...`)
26. [ ] Ir a https://github.com/settings/keys → "New SSH key"
27. [ ] **Title**: `opencode-vps-agent` (o lo que prefieras)
28. [ ] **Key type**: `Authentication Key`
29. [ ] Pegar la pública → **Add SSH key**
30. [ ] **Verificar SSH funciona**:
    ```bash
    ssh -T git@github.com
    # Esperado: "Hi adalgarcia! You've successfully authenticated..."
    # (El "failed to use... github.com" es normal, ignorar)
    ```

## Grupo 6: Probar flujo completo (clonar + PR)

> Smoke test del repo `opencode-vps-test` (D5). Si el repo no existe, crearlo
> desde la web de GitHub (privado) o via `gh repo create` (requiere
> `Administration: Read` en el PAT).

31. [ ] Clonar el repo de prueba:
    ```bash
    cd ~/proyectos
    gh repo clone adalgarcia/opencode-vps-test test-fase4
    cd test-fase4
    ```
    Alternativa SSH: `git clone git@github.com:adalgarcia/opencode-vps-test.git test-fase4`
32. [ ] Crear branch de feature:
    ```bash
    git checkout -b feature/test-fase4
    ```
33. [ ] Hacer un cambio:
    ```bash
    echo "# OpenCode VPS - Test Fase 4" > README.md
    echo "## Smoke test del flujo git + gh" >> README.md
    git add README.md
    git commit -m "test: fase 4 smoke test"
    ```
34. [ ] Push del branch:
    ```bash
    git push -u origin feature/test-fase4
    ```
35. [ ] Crear el PR:
    ```bash
    gh pr create \
      --title "Test Fase 4: GitHub + git integration" \
      --body "Smoke test del flujo completo de la Fase 4.
    - gh auth via PAT
    - SSH key auth
    - git push
    - gh pr create"
    ```
36. [ ] Confirmar en GitHub (web o `gh pr view`) que el PR existe
37. [ ] Mergear el PR (vía web o `gh pr merge --merge`)
38. [ ] Limpiar el repo de prueba (opcional): borrar el repo desde GitHub
    o dejarlo como referencia

## Grupo 7: Refinar `setup.sh`

39. [ ] Reescribir sección 4 de `setup.sh` con los pasos reales:
    - Quitar "Login with a web browser" (no aplica en headless)
    - Documentar `GH_TOKEN` en `.env` + `gh auth login --with-token`
    - Documentar generación de SSH key con passphrase + ssh-agent
    - Documentar `gh auth setup-git`
40. [ ] Agregar nota sobre `GH_TOKEN` en `.env` (misma lógica que otros secretos)

## Grupo 8: Documentación y merge

41. [ ] Actualizar `specs/roadmap.md`: marcar Fase 4 como ✅
42. [ ] Actualizar `specs/tech-stack.md` si hace falta (probablemente no,
    `gh` ya está listado)
43. [ ] Actualizar `AGENTS.md` con nota breve de que el flujo GitHub
    está operativo
44. [ ] Commit de todos los cambios:
    ```bash
    git add .
    git status  # REVISAR que .env NO esté staged
    git commit -m "feat: Fase 4 - GitHub + git integration"
    ```
45. [ ] Push de la rama:
    ```bash
    git push -u origin feature/fase4-github-git
    ```
46. [ ] Crear PR a main con `gh pr create` (smoke test final):
    ```bash
    gh pr create \
      --base main \
      --title "Fase 4: GitHub + git integration" \
      --body-file specs/2026-07-05-fase4-github-git/validation.md
    ```
47. [ ] Validar criterios de éxito (ver `validation.md`)
48. [ ] Mergear el PR (vía web o `gh pr merge --merge --delete-branch`)
49. [ ] Cleanup local: `git checkout main && git pull`

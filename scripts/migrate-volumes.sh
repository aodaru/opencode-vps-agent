#!/usr/bin/env bash
# ============================================================
# migrate-volumes.sh - Migra named volumes existentes a ./data/
#
# Helper de MIGRACION ONE-SHOT. Usar UNA sola vez para mover
# la data de los 5 named volumes antiguos a los 7 bind mounts
# de ./data/.
#
# NO borra los named volumes originales: el usuario debe
# confirmar manualmente con `docker compose up -d` + smoke test
# antes de limpiarlos con `docker volume rm`.
#
# Ejecutar desde la raiz del repo, con el contenedor DETENIDO:
#   docker compose down           # sin -v, para preservar volumes
#   ./scripts/migrate-volumes.sh
# ============================================================
set -euo pipefail

# ------------------------------------------------------------
# Configuracion: volume -> dir destino
# ------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
DATA_DIR="${REPO_ROOT}/data"

# Volumes simples (1 path en el contenedor)
declare -A SIMPLE_VOLUMES=(
  [opencode-auth]="opencode-auth"
  [opencode-tunnel]="cloudflared"
  [opencode-proyectos]="proyectos"
  [opencode-ssh]="ssh-cloud"
)

# Volume problematico: opencode-config
# Se usaba para /home/cloud/.config/opencode Y /home/cloud/.config/gh
# (mismo volume, dos paths -> contenido mezclado)
BUGGY_VOLUME="opencode-config"
BUGGY_DEST="${DATA_DIR}/opencode-config"

# ------------------------------------------------------------
# Pre-flight
# ------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker no esta en PATH." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: docker daemon no responde (socorro? necesitas sudo?)." >&2
  exit 1
fi

if [[ ! -d "${DATA_DIR}" ]]; then
  echo "ERROR: ${DATA_DIR} no existe." >&2
  echo "Corré primero:  ./scripts/init-data.sh" >&2
  exit 1
fi

# ------------------------------------------------------------
# Helper: migrar un volume completo a un dir destino
# Usa un container alpine efimero para copiar el contenido.
# Sobrescribe archivos en el destino (no falla si esta vacio).
# ------------------------------------------------------------
migrate_volume() {
  local volume="$1"
  local dest="$2"

  if ! docker volume inspect "${volume}" >/dev/null 2>&1; then
    echo "  [skip] volume '${volume}' no existe (probablemente ya migrado)"
    return 0
  fi

  echo "  [migrate] ${volume} -> ${dest}"
  # -a preserva permisos, ownership, symlinks
  # Usamos un sub-shell con cd para que cp /src/. copie el contenido
  docker run --rm \
    -v "${volume}:/src:ro" \
    -v "${dest}:/dst" \
    alpine sh -c 'cp -a /src/. /dst/ && echo "  [ok] contenido copiado"'
}

# ------------------------------------------------------------
# 1. Migrar los 4 volumes simples
# ------------------------------------------------------------
echo "[migrate] === Volumes simples ==="
for vol in "${!SIMPLE_VOLUMES[@]}"; do
  dest_subdir="${SIMPLE_VOLUMES[$vol]}"
  migrate_volume "${vol}" "${DATA_DIR}/${dest_subdir}"
done

# ------------------------------------------------------------
# 2. Inspeccionar y migrar el volume bugueado (opencode-config)
# ------------------------------------------------------------
echo ""
echo "[migrate] === Volume bugueado: ${BUGGY_VOLUME} ==="
echo "  Este volume se usaba para 2 paths en el contenedor:"
echo "    - /home/cloud/.config/opencode  (opencode.json)"
echo "    - /home/cloud/.config/gh        (hosts.yml)"
echo "  Docker montaba el MISMO volume en ambos paths,"
echo "  asi que los archivos estan mezclados."

if docker volume inspect "${BUGGY_VOLUME}" >/dev/null 2>&1; then
  echo ""
  echo "  [inspect] Listando contenido de ${BUGGY_VOLUME}:"
  docker run --rm -v "${BUGGY_VOLUME}:/src:ro" alpine ls -la /src/
  echo ""

  # Migrar a ./data/opencode-config/
  echo "  [migrate] ${BUGGY_VOLUME} -> ${BUGGY_DEST}/"
  docker run --rm \
    -v "${BUGGY_VOLUME}:/src:ro" \
    -v "${BUGGY_DEST}:/dst" \
    alpine sh -c 'cp -a /src/. /dst/ && echo "  [ok] contenido copiado"'

  echo ""
  echo "  [inspect] Contenido copiado a ${BUGGY_DEST}/:"
  ls -la "${BUGGY_DEST}/"
  echo ""
  echo "  >>> ACCION MANUAL REQUERIDA <<<"
  echo ""
  echo "  Este volume se usaba para 2 paths del contenedor:"
  echo "    - /home/cloud/.config/opencode  (opencode.json + runtime)"
  echo "    - /home/cloud/.config/gh        (config.yml + hosts.yml)"
  echo ""
  echo "  Archivos que DEBEN quedarse en ${BUGGY_DEST}/ (son de opencode):"
  echo "    - opencode.json"
  echo "    - node_modules/  (dependencias de opencode, runtime)"
  echo "    - package.json, package-lock.json  (runtime)"
  echo "    - .gitignore  (de opencode)"
  echo ""
  echo "  Archivos que DEBEN moverse a ${DATA_DIR}/gh-config/ (son de gh):"
  echo "    - config.yml   (config principal de gh CLI)"
  echo "    - hosts.yml    (auth tokens de GitHub)"
  echo ""
  echo "  Ejemplo (adaptar a los archivos que veas arriba):"
  echo "    mv ${BUGGY_DEST}/config.yml ${DATA_DIR}/gh-config/"
  echo "    mv ${BUGGY_DEST}/hosts.yml  ${DATA_DIR}/gh-config/"
  echo ""
  echo "  Si opencode.json NO esta en ${BUGGY_DEST}/, copialo desde el repo:"
  echo "    cp ${REPO_ROOT}/config/opencode.json ${BUGGY_DEST}/opencode.json"
else
  echo "  [skip] volume '${BUGGY_VOLUME}' no existe (probablemente ya migrado)"
fi

# ------------------------------------------------------------
# 3. Resumen y siguiente paso
# ------------------------------------------------------------
echo ""
echo "[migrate] === Migracion completada ==="
echo ""
echo "Siguiente paso:"
echo "  1. Verificar que ${DATA_DIR}/opencode-config/opencode.json existe"
echo "  2. Mover hosts.yml a ${DATA_DIR}/gh-config/ (si aplica)"
echo "  3. Levantar el contenedor:  docker compose up -d"
echo "  4. Smoke test: ver ${REPO_ROOT}/specs/2026-07-05-fix-persistencia-bind-mounts/validation.md"
echo "  5. Si todo OK, borrar los named volumes antiguos:"
echo "       docker volume rm opencode-auth opencode-config opencode-tunnel opencode-proyectos opencode-ssh"
echo ""
echo "  Los volumes NO se borran automaticamente por seguridad"
echo "  (decision D4: confirmacion manual antes de destruir data)."

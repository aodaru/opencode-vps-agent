#!/usr/bin/env bash
# ============================================================
# init-data.sh - Inicializa ./data/ para bind mounts
#
# Crea los 6 subdirs que se montan en el contenedor y siembra
# ./data/opencode-config/opencode.json desde el repo.
#
# Es IDEMPOTENTE: se puede correr multiples veces sin efectos
# colaterales. Si ./data/opencode-config/opencode.json ya existe
# (porque el usuario lo edito), NO lo sobreescribe.
#
# Ejecutar desde la raiz del repo:
#   ./scripts/init-data.sh
# ============================================================
set -euo pipefail

# ------------------------------------------------------------
# Resolver la raiz del repo (directorio padre de scripts/)
# ------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
DATA_DIR="${REPO_ROOT}/data"
SEED_CONFIG="${REPO_ROOT}/config/opencode.json"

# ------------------------------------------------------------
# Subdirs a crear: nombre -> permisos (octal)
#   700 para SSH dirs (contienen private keys)
#   755 para el resto
# ------------------------------------------------------------
declare -A DIRS=(
  [opencode-auth]=755
  [opencode-config]=755
  [gh-config]=755
  [ssh-cloud]=700
  [ssh-devadmin]=700
  [proyectos]=755
)

# ------------------------------------------------------------
# Pre-flight
# ------------------------------------------------------------
if ! command -v install >/dev/null 2>&1; then
  echo "ERROR: se requiere el comando 'install' (coreutils)." >&2
  exit 1
fi

# ------------------------------------------------------------
# 1. Crear subdirs (idempotente)
# ------------------------------------------------------------
echo "[init-data] Creando subdirs en ${DATA_DIR}/"
for dir in "${!DIRS[@]}"; do
  perms="${DIRS[$dir]}"
  target="${DATA_DIR}/${dir}"
  # install -d es idempotente: si el dir existe, no falla
  install -d -m "${perms}" "${target}"
  echo "  - ${dir}/ (${perms})"
done

# ------------------------------------------------------------
# 2. Sembrar opencode.json (solo si no existe)
# ------------------------------------------------------------
TARGET_CONFIG="${DATA_DIR}/opencode-config/opencode.json"
if [[ -e "${TARGET_CONFIG}" ]]; then
  echo ""
  echo "[init-data] ${TARGET_CONFIG} ya existe, NO se sobreescribe."
  echo "            Si queres volver a la config del repo:"
  echo "            rm ${TARGET_CONFIG} && ./scripts/init-data.sh"
else
  if [[ ! -f "${SEED_CONFIG}" ]]; then
    echo "ERROR: no se encontro el seed config en ${SEED_CONFIG}" >&2
    exit 1
  fi
  install -m 644 "${SEED_CONFIG}" "${TARGET_CONFIG}"
  echo ""
  echo "[init-data] Sembrado: ${TARGET_CONFIG}"
  echo "            (editado desde config/opencode.json del repo)"
fi

# ------------------------------------------------------------
# 3. Mostrar estructura resultante
# ------------------------------------------------------------
echo ""
echo "[init-data] Estructura de ${DATA_DIR}/:"
if command -v tree >/dev/null 2>&1; then
  (cd "${REPO_ROOT}" && tree -p -L 1 data/ 2>/dev/null || ls -la data/)
else
  ls -la "${DATA_DIR}/"
fi

echo ""
echo "[init-data] OK. Listo para 'docker compose up -d'."

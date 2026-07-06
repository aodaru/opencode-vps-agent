#!/usr/bin/env bash
# ============================================================
# backup-data.sh - Backup de ./data/ (bind mounts del agente)
#
# Crea un backup comprimido de todo el directorio data/ con
# timestamp. Los backups se guardan en ./backups/.
#
# Ejecutar desde la raiz del repo:
#   ./scripts/backup-data.sh
#
# Para restaurar:
#   tar -xzf backups/opencode-vps-YYYYMMDD-HHMMSS.tar.gz -C ./
# ============================================================
set -euo pipefail

# ------------------------------------------------------------
# Resolver la raiz del repo
# ------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
DATA_DIR="${REPO_ROOT}/data"
BACKUP_DIR="${REPO_ROOT}/backups"

# ------------------------------------------------------------
# Pre-flight
# ------------------------------------------------------------
if [[ ! -d "${DATA_DIR}" ]]; then
  echo "ERROR: no se encontro ${DATA_DIR}" >&2
  echo "       Ejecuta primero: ./scripts/init-data.sh" >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "ERROR: se requiere el comando 'tar'." >&2
  exit 1
fi

# ------------------------------------------------------------
# Crear directorio de backups
# ------------------------------------------------------------
install -d -m 755 "${BACKUP_DIR}"

# ------------------------------------------------------------
# Generar nombre del backup con timestamp
# ------------------------------------------------------------
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_NAME="opencode-vps-${TIMESTAMP}.tar.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# ------------------------------------------------------------
# Crear backup
# ------------------------------------------------------------
echo "[backup] Respaldando ${DATA_DIR}/"
echo "         -> ${BACKUP_PATH}"

# Calcular tamaño antes del backup
DATA_SIZE="$(du -sh "${DATA_DIR}" 2>/dev/null | cut -f1)"
echo "         Tamaño: ${DATA_SIZE}"

tar -czf "${BACKUP_PATH}" -C "${REPO_ROOT}" data/

# ------------------------------------------------------------
# Verificar integrity
# ------------------------------------------------------------
if tar -tzf "${BACKUP_PATH}" >/dev/null 2>&1; then
  BACKUP_SIZE="$(du -sh "${BACKUP_PATH}" | cut -f1)"
  echo ""
  echo "[backup] OK. Backup creado: ${BACKUP_NAME} (${BACKUP_SIZE})"
  echo "         Para restaurar:"
  echo "           tar -xzf ${BACKUP_PATH} -C ${REPO_ROOT}/"
else
  echo "ERROR: el backup esta corrupto" >&2
  rm -f "${BACKUP_PATH}"
  exit 1
fi

# ------------------------------------------------------------
# Limpiar backups antiguos (mantener ultimos 7)
# ------------------------------------------------------------
BACKUP_COUNT="$(ls -1 "${BACKUP_DIR}"/opencode-vps-*.tar.gz 2>/dev/null | wc -l)"
if [[ "${BACKUP_COUNT}" -gt 7 ]]; then
  REMOVE_COUNT=$((BACKUP_COUNT - 7))
  echo ""
  echo "[backup] Limpiando ${REMOVE_COUNT} backup(s) antiguo(s)..."
  ls -1t "${BACKUP_DIR}"/opencode-vps-*.tar.gz | tail -n "${REMOVE_COUNT}" | xargs rm -f
fi

echo ""
echo "[backup] Backups disponibles:"
ls -lh "${BACKUP_DIR}"/opencode-vps-*.tar.gz 2>/dev/null | awk '{print "  " $NF " (" $5 ")"}'
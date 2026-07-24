#!/bin/bash
# ============================================================
# set-passwords.sh - Aplica passwords desde variables de entorno
#
# Lee DEVADMIN_PASSWORD y CLOUD_PASSWORD del entorno y ejecuta
# chpasswd para cada usuario. Si una variable no está definida
# o está vacía, warningea y sigue (no falla).
#
# Corre una vez al arrancar via supervisor (priority=2, tras
# fix-ownership). Idempotente: safe de re-ejecutar.
# ============================================================
set -euo pipefail

log()  { echo "[set-passwords] $*"; }
warn() { echo "[set-passwords] WARN $*" >&2; }

if [ -n "${DEVADMIN_PASSWORD:-}" ]; then
    echo "devadmin:${DEVADMIN_PASSWORD}" | chpasswd
    log "devadmin password updated from env var"
else
    warn "DEVADMIN_PASSWORD not set — devadmin keeps build-time password"
fi

if [ -n "${CLOUD_PASSWORD:-}" ]; then
    echo "cloud:${CLOUD_PASSWORD}" | chpasswd
    log "cloud password updated from env var"
else
    warn "CLOUD_PASSWORD not set — cloud keeps build-time password"
fi

log "set-passwords complete"

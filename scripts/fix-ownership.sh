#!/bin/bash
# ============================================================
# fix-ownership.sh
# Ensure ownership is correct for /home/cloud/... and
# /home/devadmin/... bind mounts.
#
# Runs once on container start as root (via supervisord).
# Idempotent: safe to re-run; only chowns when ownership
# doesn't match the expected user.
#
# History: this script extends the previous fix-ssh-ownership.sh
# (which only covered ~/.ssh/) to cover all bind-mounted paths
# under /home/cloud/... and /home/devadmin/.ssh.
#
# The bind mounts come from ./data/ on the host, which is created
# by init-data.sh with the host's user ownership (typically
# truenas_admin, UID 1000). Inside the container:
#   - devadmin is UID 1000
#   - cloud is UID 1001
# So the bind mount is owned by what looks like devadmin inside
# the container, and cloud (the actual agent user) can't write
# to its own workspace. This script fixes that.
#
# NOTA: no usamos `set -e` porque las condicionales del final
# (`[ -f X ] && chmod X`) devuelven 1 cuando el archivo no
# existe, lo cual mata el script con set -e.
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[fix-ownership]${NC} $*"; }
warn() { echo -e "${YELLOW}[fix-ownership]${NC} $*"; }
err()  { echo -e "${RED}[fix-ownership]${NC} $*" >&2; }

# ------------------------------------------------------------
# Fix ownership and permissions of an SSH directory.
# Perms: 700 on the dir, 600 on private keys, 644 on public keys.
# ------------------------------------------------------------
fix_ssh_dir() {
    local user="$1"
    local ssh_dir="$2"

    if [ ! -d "$ssh_dir" ]; then
        warn "SSH dir $ssh_dir does not exist, creating with correct ownership"
        mkdir -p "$ssh_dir"
    fi

    local current_owner
    current_owner=$(stat -c '%U' "$ssh_dir")

    if [ "$current_owner" != "$user" ]; then
        warn "$ssh_dir owned by '$current_owner', fixing to '$user:$user'"
        chown -R "$user:$user" "$ssh_dir"
    else
        log "$ssh_dir ownership OK ($user:$user)"
    fi

    chmod 700 "$ssh_dir"

    [ -f "$ssh_dir/id_ed25519" ]      && chmod 600 "$ssh_dir/id_ed25519"
    [ -f "$ssh_dir/id_ed25519.pub" ]  && chmod 644 "$ssh_dir/id_ed25519.pub"
    [ -f "$ssh_dir/id_rsa" ]          && chmod 600 "$ssh_dir/id_rsa"
    [ -f "$ssh_dir/id_rsa.pub" ]      && chmod 644 "$ssh_dir/id_rsa.pub"
    [ -f "$ssh_dir/authorized_keys" ] && chmod 600 "$ssh_dir/authorized_keys"
    [ -f "$ssh_dir/known_hosts" ]     && chmod 644 "$ssh_dir/known_hosts"
    [ -f "$ssh_dir/config" ]          && chmod 600 "$ssh_dir/config"
}

# ------------------------------------------------------------
# Fix ownership and permissions of a non-SSH directory.
# Perms: 755 (rwxr-xr-x) on the dir, recursive.
# Use this for config dirs, workspace, and other non-sensitive paths.
# ------------------------------------------------------------
fix_dir() {
    local user="$1"
    local dir="$2"

    if [ ! -d "$dir" ]; then
        warn "Dir $dir does not exist, creating with correct ownership"
        mkdir -p "$dir"
    fi

    local current_owner
    current_owner=$(stat -c '%U' "$dir")

    if [ "$current_owner" != "$user" ]; then
        warn "$dir owned by '$current_owner', fixing to '$user:$user'"
        chown -R "$user:$user" "$dir"
    else
        log "$dir ownership OK ($user:$user)"
    fi

    chmod 755 "$dir"
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
log "Starting ownership fix"

# 1. SSH dirs (700, special handling for key files)
log "=== SSH dirs ==="
fix_ssh_dir "devadmin" "/home/devadmin/.ssh"
fix_ssh_dir "cloud"    "/home/cloud/.ssh"

# 2. Non-SSH dirs under /home/cloud/ (755, owned by cloud)
# These are bind-mounted from ./data/ on the host, so the UID
# mismatch is the main reason this script exists.
log "=== cloud's config/workspace dirs ==="
fix_dir "cloud" "/home/cloud/proyectos"
fix_dir "cloud" "/home/cloud/.config/opencode"
fix_dir "cloud" "/home/cloud/.config/gh"
fix_dir "cloud" "/home/cloud/.local/share/opencode"
log "Ownership fix complete"

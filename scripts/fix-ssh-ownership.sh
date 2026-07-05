#!/bin/bash
# ============================================================
# fix-ssh-ownership.sh
# Ensure ~/.ssh ownership is correct for devadmin and cloud
# Runs once on container start as root (via supervisord)
# Idempotent: safe to re-run
# ============================================================
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[fix-ssh]${NC} $*"; }
warn() { echo -e "${YELLOW}[fix-ssh]${NC} $*"; }
err()  { echo -e "${RED}[fix-ssh]${NC} $*" >&2; }

fix_user_ssh() {
    local user="$1"
    local home="/home/$user"
    local ssh_dir="$home/.ssh"

    if ! id "$user" &>/dev/null; then
        warn "User $user does not exist, skipping"
        return 0
    fi

    if [ ! -d "$home" ]; then
        err "Home directory $home does not exist for $user"
        return 1
    fi

    chown "$user:$user" "$home"

    if [ ! -d "$ssh_dir" ]; then
        warn "$ssh_dir does not exist, creating with correct ownership"
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

log "Starting SSH ownership fix"
fix_user_ssh "devadmin"
fix_user_ssh "cloud"
log "SSH ownership fix complete"

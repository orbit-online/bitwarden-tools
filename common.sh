#!/usr/bin/env bash

LOCKDIR="/var/run/lock/bitwarden-tools"

# shellcheck disable=SC1091
source "${pkgroot:?}/.upkg/records.sh/records.sh"
# shellcheck disable=SC1091
source "${pkgroot:?}/.upkg/collections.sh/collections.sh"

bw_acquire_lock() {
  [[ -d "$LOCKDIR" ]] || mkdir "$LOCKDIR"
  local lockpath="$LOCKDIR/${1//[^A-Za-z0-9_]/_}.lock"
  verbose "Acquiring lock on %s" "$lockpath"
  exec 9<>"$lockpath"
  flock 9
  trap "bw_release_lock" EXIT
}

bw_release_lock() {
  ! { : >&9; } 2>/dev/null || exec 9>&-
}

bw() {
  command bw "$@" 2> >(LOGPROGRAM=bw tee_debug)
}

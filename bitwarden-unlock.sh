#!/usr/bin/env bash
set -e

unlock_bw() {
  DOC="Unlock Bitwarden, uses pinentry from GnuPG to prompt for the passphrase
Usage:
  bitwarden-unlock
"
  if [[ $1 = '--help' || $1 = '-h' ]]; then
    printf -- "%s" "$DOC"
    return 0
  fi
  if [[ $# -gt 0 ]]; then
    printf -- "%s" "$DOC"
    return 1
  fi

  local PINENTRY="pinentry"
  local pinentry_win="/mnt/c/Program Files (x86)/Gpg4win/bin/pinentry.exe"
  type "$pinentry_win" &>/dev/null && PINENTRY=$pinentry_win
  checkdeps bw "$PINENTRY"

  # Prevent double unlocking by using a shared lock
  local LOCK_PATH="${TMP:-/tmp}/bitwarden-unlock.lock"
  exec 9<>"$LOCK_PATH"
  flock 9
  trap "exec 9>&-" EXIT

  local pinentry_script="SETPROMPT Unlock Bitwarden
SETDESC Enter your Bitwarden Master Password
SETOK Unlock
SETCANCEL Abort
GETPIN
"
  local tries=0
  while true; do
    ((tries++)) || true
    local out
    out=$("$PINENTRY" <<<"$pinentry_script")
    if [[ $out = *$'\nOK' ]]; then
      local pass=${out%%$'\nOK'}
      pass=${pass##*$'\nD '}
      pinentry_script="SETERROR Invalid password
$pinentry_script"
      local session_key
      if session_key=$(bw unlock --raw <<<"$pass" 2>/dev/null); then
        printf "%s\n" "$session_key"
        return 0
      elif [[ $tries -ge 3 ]]; then
        echo "Unlocking Bitwarden failed" >&2
        return 1
      fi
    else
      return 1
    fi
  done
}

checkdeps() {
  local deps=("$@")
  local dep
  local out
  local ret=0
  for dep in "${deps[@]}"; do
    if ! out=$(type "$dep" 2>&1); then
      printf -- "Dependency %s not found:\n%s\n" "$dep" "$out"
      ret=1
    fi
  done
  return $ret
}

unlock_bw "$@"

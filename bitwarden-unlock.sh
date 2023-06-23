#!/usr/bin/env bash

bitwarden_unlock() {
  set -eo pipefail
  shopt -s inherit_errexit
  local pkgroot
  pkgroot=$(upkg root "${BASH_SOURCE[0]}")
  # shellcheck source=.upkg/orbit-online/records.sh/records.sh
  source "$pkgroot/.upkg/orbit-online/records.sh/records.sh"
  PATH="$pkgroot/.upkg/.bin:$PATH"

  DOC="Unlock Bitwarden, uses pinentry from GnuPG to prompt for the master password
Usage:
  bitwarden-unlock [options]
Options:
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
  --debug               Turn on bash -x
"
# docopt parser below, refresh this parser with `docopt.sh bitwarden-unlock.sh`
# shellcheck disable=2016,1090,1091,2034
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || { ret=$?
printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e; trimmed_doc=${DOC:0:353}
usage=${DOC:77:35}; digest=4c641; shorts=('' -p); longs=(--debug --purpose)
argcounts=(0 1); node_0(){ switch __debug 0; }; node_1(){ value __purpose 1; }
node_2(){ optional 0 1; }; node_3(){ optional 2; }; node_4(){ required 3; }
node_5(){ required 4; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:77:35}" >&2; exit 1
}'; unset var___debug var___purpose; parse 5 "$@"
local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__debug" "${prefix}__purpose"
eval "${prefix}"'__debug=${var___debug:-false}'
eval "${prefix}"'__purpose=${var___purpose:-}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}__debug" "${prefix}__purpose"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' bitwarden-unlock.sh`
  eval "$(docopt "$@")"

  # shellcheck disable=2154
  if $__debug; then
    set -x
  fi

  local PINENTRY="pinentry"
  local pinentry_mac="pinentry-mac"
  local pinentry_win="/mnt/c/Program Files (x86)/Gpg4win/bin/pinentry.exe"
  type "$pinentry_mac" &>/dev/null && PINENTRY=$pinentry_mac
  type "$pinentry_win" &>/dev/null && PINENTRY=$pinentry_win
  checkdeps bw "$PINENTRY"

  # Prevent double unlocking by using a shared lock
  local LOCK_PATH="${TMP:-/tmp}/bitwarden-unlock.lock"
  exec 9<>"$LOCK_PATH"
  flock 9
  trap "exec 9>&-" EXIT

  PURPOSE="Enter your Bitwarden Master Password"
  # shellcheck disable=2154
  if [[ -n $__purpose ]]; then
    PURPOSE="$PURPOSE to $__purpose"
  fi
  local pinentry_script pinentry_script_base="SETPROMPT Unlock Bitwarden
SETDESC $PURPOSE
SETOK Unlock
SETCANCEL Abort
GETPIN
"
  pinentry_script=$pinentry_script_base
  local tries=0
  while true; do
    ((tries++)) || true
    local out
    out=$("$PINENTRY" <<<"$pinentry_script" || true)
    if [[ $out = *$'\nOK' ]]; then
      local pass=${out%%$'\nOK'}
      pass=${pass##*$'\nD '}
      pinentry_script="SETERROR Invalid password
$pinentry_script_base"
      local session_key
      if session_key=$(bw unlock --raw <<<"$pass" 2>/dev/null); then
        printf "%s\n" "$session_key"
        return 0
      elif [[ $tries -ge 3 ]]; then
        fatal "Unlocking Bitwarden failed"
      fi
    elif [[ $out = *'ERR 83886179'* ]]; then
      return 2
    fi
  done
}

bitwarden_unlock "$@"

#!/usr/bin/env bash

bitwarden_unlock() {
  set -eo pipefail; shopt -s inherit_errexit
  local pkgroot; pkgroot=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
  source "$pkgroot/.upkg/orbit-online/records.sh/records.sh"
  source "$pkgroot/common.sh"
  PATH=$("$pkgroot/.upkg/.bin/path_prepend" "$pkgroot/.upkg/.bin")

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
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:353}; usage=${DOC:77:35}; digest=4c641; shorts=('' -p)
longs=(--debug --purpose); argcounts=(0 1); node_0(){ switch __debug 0; }
node_1(){ value __purpose 1; }; node_2(){ optional 0 1; }; node_3(){ optional 2
}; node_4(){ required 3; }; node_5(){ required 4; }; cat <<<' docopt_exit() {
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

  checkdeps bw
  bw_acquire_lock "unlock"
  local desc="Enter your Bitwarden Master Password"
  # shellcheck disable=2154
  if [[ -n $__purpose ]]; then
    desc="$desc to $__purpose"
  fi
  local tries=0 errarg=() pass session_key
  while true; do
    # shellcheck disable=2068
    if ((tries >= 3)); then
      fatal "Unlocking Bitwarden failed"
    elif pass=$(pinentry-wrapper --desc "$desc" --ok Unlock --cancel Abort "${errarg[@]}" 'Unlock Bitwarden'); then
      if session_key=$(bw unlock --raw <<<"$pass"); then
        printf "%s\n" "$session_key"
        return 0
      else
        errarg=(--error 'Invalid password')
      fi
    elif [[ $? -eq 2 ]]; then
      # Cancelled
      return 2
    else
      fatal "An unknown error occurred"
    fi
    ((tries++)) || true
  done
}

bitwarden_unlock "$@"

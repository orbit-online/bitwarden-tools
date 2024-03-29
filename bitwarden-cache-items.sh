#!/usr/bin/env bash

bitwarden_cache_items() {
  set -eo pipefail; shopt -s inherit_errexit
  local pkgroot; pkgroot=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
  source "$pkgroot/.upkg/orbit-online/records.sh/records.sh"
  source "$pkgroot/.upkg/orbit-online/collections.sh/collections.sh"
  PATH=$("$pkgroot/.upkg/.bin/path_prepend" "$pkgroot/.upkg/.bin")

  DOC="Cache Bitwarden multiple items in the socket-credential-cache
Usage:
  bitwarden-cache-items [options] ITEMNAME...

Options:
  --cache-for=SECONDS   Cache item for retrieval without a session [default: 0]
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
                        [default: retrieve the items \"\$ITEMNAME\"...]
  --check               Only check whether items are cached, return 1 otherwise
  -q --quiet            Don't print progress
"
# docopt parser below, refresh this parser with `docopt.sh bitwarden-cache-items.sh`
# shellcheck disable=2016,1090,1091,2034,2154
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:590}; usage=${DOC:62:52}; digest=ca6ed; shorts=(-q -p '' '')
longs=(--quiet --purpose --check --cache-for); argcounts=(0 1 0 1); node_0(){
switch __quiet 0; }; node_1(){ value __purpose 1; }; node_2(){ switch __check 2
}; node_3(){ value __cache_for 3; }; node_4(){ value ITEMNAME a true; }
node_5(){ optional 0 1 2 3; }; node_6(){ optional 5; }; node_7(){ oneormore 4; }
node_8(){ required 6 7; }; node_9(){ required 8; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:62:52}" >&2; exit 1
}'; unset var___quiet var___purpose var___check var___cache_for var_ITEMNAME
parse 9 "$@"; local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__quiet" \
"${prefix}__purpose" "${prefix}__check" "${prefix}__cache_for" \
"${prefix}ITEMNAME"; eval "${prefix}"'__quiet=${var___quiet:-false}'
eval "${prefix}"'__purpose=${var___purpose:-'"'"'retrieve the items "$ITEMNAME"...'"'"'}'
eval "${prefix}"'__check=${var___check:-false}'
eval "${prefix}"'__cache_for=${var___cache_for:-0}'
if declare -p var_ITEMNAME >/dev/null 2>&1; then
eval "${prefix}"'ITEMNAME=("${var_ITEMNAME[@]}")'; else
eval "${prefix}"'ITEMNAME=()'; fi; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}__quiet" "${prefix}__purpose" "${prefix}__check" \
"${prefix}__cache_for" "${prefix}ITEMNAME"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' bitwarden-cache-items.sh`
  eval "$(docopt "$@")"

  checkdeps bw
  local name
  if [[ $__purpose = "retrieve the items \"\$ITEMNAME\"..." ]]; then
    __purpose="retrieve \"$(join_by ", " "${ITEMNAME[@]}")\""
  fi
  local progress=0
  for name in "${ITEMNAME[@]}"; do
    # shellcheck disable=2154
    if ! $__quiet; then
      [[ ! -t 2 || $progress -eq 0 ]] || printf "\e[1A\r\e[K" >&2
      printf 'bitwarden-cache-items: %d/%d "%s"\n'  "$((progress++))" "${#ITEMNAME[@]}" "$name" >&2
    fi
    # shellcheck disable=2154
    if ! "$pkgroot/bitwarden-fields.sh" -m cache "$name" >/dev/null 2>&1; then
      ! $__check || return 1
      if [[ -z $BW_SESSION ]]; then
        export BW_SESSION
        # shellcheck disable=2154
        BW_SESSION=$(bitwarden-unlock --purpose "$__purpose")
        trap "bw lock >/dev/null" EXIT
      fi
      "$pkgroot/bitwarden-fields.sh" --cache-for="$__cache_for" "$name" >/dev/null
    fi
  done
  if ! $__quiet; then
    [[ ! -t 2 ]] || printf "\e[1A\r\e[K" >&2
    printf "bitwarden-cache-items: %d/%d All items cached\n" "$progress" "${#ITEMNAME[@]}" >&2
  fi
}

bitwarden_cache_items "$@"

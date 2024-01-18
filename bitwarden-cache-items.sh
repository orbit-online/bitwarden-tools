#!/usr/bin/env bash

bitwarden_cache_items() {
  set -eo pipefail; shopt -s inherit_errexit
  local pkgroot; pkgroot=$(upkg root "${BASH_SOURCE[0]}")
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
  -q --quiet            Don't print progress
"
# docopt parser below, refresh this parser with `docopt.sh bitwarden-cache-items.sh`
# shellcheck disable=2016,1090,1091,2034,2154
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:510}; usage=${DOC:62:52}; digest=da5ef; shorts=('' -p -q)
longs=(--cache-for --purpose --quiet); argcounts=(1 1 0); node_0(){
value __cache_for 0; }; node_1(){ value __purpose 1; }; node_2(){
switch __quiet 2; }; node_3(){ value ITEMNAME a true; }; node_4(){
optional 0 1 2; }; node_5(){ optional 4; }; node_6(){ oneormore 3; }; node_7(){
required 5 6; }; node_8(){ required 7; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:62:52}" >&2; exit 1
}'; unset var___cache_for var___purpose var___quiet var_ITEMNAME; parse 8 "$@"
local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__cache_for" \
"${prefix}__purpose" "${prefix}__quiet" "${prefix}ITEMNAME"
eval "${prefix}"'__cache_for=${var___cache_for:-0}'
eval "${prefix}"'__purpose=${var___purpose:-'"'"'retrieve the items "$ITEMNAME"...'"'"'}'
eval "${prefix}"'__quiet=${var___quiet:-false}'
if declare -p var_ITEMNAME >/dev/null 2>&1; then
eval "${prefix}"'ITEMNAME=("${var_ITEMNAME[@]}")'; else
eval "${prefix}"'ITEMNAME=()'; fi; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}__cache_for" "${prefix}__purpose" "${prefix}__quiet" \
"${prefix}ITEMNAME"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' bitwarden-cache-items.sh`
  eval "$(docopt "$@")"

  checkdeps bw socket-credential-cache
    # shellcheck disable=2154
  ! $__quiet || BW_CACHE_ITEMS_PROGRESS=false
  local name cache_name
  if [[ $__purpose = "retrieve the items \"\$ITEMNAME\"..." ]]; then
    __purpose="retrieve \"$(join_by ", " "${ITEMNAME[@]}")\""
  fi
  local progress=0
  for name in "${ITEMNAME[@]}"; do
    # shellcheck disable=2154
    progress '%d/%d "%s"' "$((progress++))" "${#ITEMNAME[@]}" "$name" >&2
    cache_name="Bitwarden $name"
    # shellcheck disable=2154
    if ! socket-credential-cache get "$cache_name" >/dev/null 2>&1; then
      if [[ -z $BW_SESSION ]]; then
        export BW_SESSION
        # shellcheck disable=2154
        BW_SESSION=$(bitwarden-unlock --purpose "$__purpose")
        trap "bw lock >/dev/null" EXIT
      fi
      "$pkgroot/bitwarden-fields.sh" --cache-for="$__cache_for" "$name" >/dev/null
    fi
  done
  progress '%d/%d All items cached' "$progress" "${#ITEMNAME[@]}" >&2
}

progress() {
  ${BW_CACHE_ITEMS_PROGRESS:-true} || return 0
  local tpl=$1; shift
  # shellcheck disable=2059
  if [[ -t 2 ]]; then
    printf "\e[1A\r\e[Kbitwarden-cache-items: $tpl\n" "$@" >&2
  else
    printf "bitwarden-cache-items: $tpl\n" "$@" >&2
  fi
}

bitwarden_cache_items "$@"

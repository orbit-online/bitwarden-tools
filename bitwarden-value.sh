#!/usr/bin/env bash

bitwarden_value() {
  set -eo pipefail
  shopt -s inherit_errexit
  local pkgroot
  pkgroot=$(upkg root "${BASH_SOURCE[0]}")
  PATH="$pkgroot/.upkg/.bin:$PATH"

  DOC="Retrieve a single field value from Bitwarden and output it verbatim
Usage:
  bitwarden-value [options] ITEM FIELD

Options:
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
                        [default: retrieve \"\$FIELD\" from \"\$ITEM\"]
"
# docopt parser below, refresh this parser with `docopt.sh bitwarden-value.sh`
# shellcheck disable=2016,1090,1091,2034
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:381}; usage=${DOC:68:45}; digest=2edfd; shorts=(-p)
longs=(--purpose); argcounts=(1); node_0(){ value __purpose 0; }; node_1(){
value ITEM a; }; node_2(){ value FIELD a; }; node_3(){ optional 0; }; node_4(){
optional 3; }; node_5(){ required 4 1 2; }; node_6(){ required 5; }
cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:68:45}" >&2; exit 1; }'; unset var___purpose var_ITEM \
var_FIELD; parse 6 "$@"; local prefix=${DOCOPT_PREFIX:-''}
unset "${prefix}__purpose" "${prefix}ITEM" "${prefix}FIELD"
eval "${prefix}"'__purpose=${var___purpose:-'"'"'retrieve "$FIELD" from "$ITEM"'"'"'}'
eval "${prefix}"'ITEM=${var_ITEM:-}'; eval "${prefix}"'FIELD=${var_FIELD:-}'
local docopt_i=1; [[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2
for ((;docopt_i>0;docopt_i--)); do declare -p "${prefix}__purpose" \
"${prefix}ITEM" "${prefix}FIELD"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' bitwarden-value.sh`
  # shellcheck disable=2034
  DOCOPT_OPTIONS_FIRST=true
  eval "$(docopt "$@")"
  checkdeps jq
  if [[ $__purpose = "retrieve \"\$BW_FIELD\" from \"\$BW_ITEM\"" ]]; then
    __purpose="retrieve \"$FIELD\" from \"$ITEM\""
  fi
  "$pkgroot/bitwarden-fields.sh" --purpose "$__purpose" --json "$ITEM" "$FIELD" | jq -re --arg field "$FIELD" '.[$field]'
}

bitwarden_value "$@"

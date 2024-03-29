#!/usr/bin/env bash

bitwarden_value() {
  set -eo pipefail; shopt -s inherit_errexit
  local pkgroot; pkgroot=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
  PATH=$("$pkgroot/.upkg/.bin/path_prepend" "$pkgroot/.upkg/.bin")

  DOC="Retrieve a single field value from Bitwarden and output it verbatim
Usage:
  bitwarden-value [options] ITEM FIELD

Options:
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
                        [default: retrieve FIELD from ITEM]
  -m --mechanism=MECH   Use \"bw\" or \"cache\" to retrieve the item [default: both]
  --cache-for=SECONDS   Cache item with socket-credential-cache [default: 0]
"
# docopt parser below, refresh this parser with `docopt.sh bitwarden-value.sh`
# shellcheck disable=2016,1090,1091,2034
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:533}; usage=${DOC:68:45}; digest=8f886; shorts=(-m -p '')
longs=(--mechanism --purpose --cache-for); argcounts=(1 1 1); node_0(){
value __mechanism 0; }; node_1(){ value __purpose 1; }; node_2(){
value __cache_for 2; }; node_3(){ value ITEM a; }; node_4(){ value FIELD a; }
node_5(){ optional 0 1 2; }; node_6(){ optional 5; }; node_7(){ required 6 3 4
}; node_8(){ required 7; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:68:45}" >&2; exit 1
}'; unset var___mechanism var___purpose var___cache_for var_ITEM var_FIELD
parse 8 "$@"; local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__mechanism" \
"${prefix}__purpose" "${prefix}__cache_for" "${prefix}ITEM" "${prefix}FIELD"
eval "${prefix}"'__mechanism=${var___mechanism:-both}'
eval "${prefix}"'__purpose=${var___purpose:-'"'"'retrieve FIELD from ITEM'"'"'}'
eval "${prefix}"'__cache_for=${var___cache_for:-0}'
eval "${prefix}"'ITEM=${var_ITEM:-}'; eval "${prefix}"'FIELD=${var_FIELD:-}'
local docopt_i=1; [[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2
for ((;docopt_i>0;docopt_i--)); do declare -p "${prefix}__mechanism" \
"${prefix}__purpose" "${prefix}__cache_for" "${prefix}ITEM" "${prefix}FIELD"
done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' bitwarden-value.sh`
  # shellcheck disable=2034
  DOCOPT_OPTIONS_FIRST=true
  eval "$(docopt "$@")"
  checkdeps jq
  if [[ $__purpose = "retrieve FIELD from ITEM" ]]; then
    __purpose="retrieve \"$FIELD\" from \"$ITEM\""
  fi
  # shellcheck disable=2154
  "$pkgroot/bitwarden-fields.sh" \
    --mechanism "$__mechanism" --cache-for "$__cache_for" --purpose "$__purpose" --json \
    "$ITEM" "$FIELD" | \
    jq -re --arg field "$FIELD" '.[$field]'
}

bitwarden_value "$@"

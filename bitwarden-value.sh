#!/usr/bin/env bash

bitwarden_value() {
  set -eo pipefail
  shopt -s inherit_errexit
  local pkgroot
  pkgroot=$(upkg root "${BASH_SOURCE[0]}")
  PATH="$pkgroot/.upkg/.bin:$PATH"

  DOC="Retrieve a single field value from Bitwarden and output it verbatim
Usage:
  bitwarden-value [options] [[--] ANYARGS...]

Options:
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
                        [default: retrieve \"\$BW_FIELD\" from \"\$BW_ITEM\"]
  --item ITEM    The name of the Bitwarden item [default: \$BW_ITEM]
  --field FIELD  The name of the field on the item [default: \$BW_FIELD]

Note:
  You can specify both parameters through environment variables. This allows
  bitwarden-value to be used as an SSH askpass program. e.g.:
  env DISPLAY=':0.0' SSH_ASKPASS='bitwarden-value' \\
    BW_SESSION='...' BW_ITEM='SSH Key' BW_FIELD='passphrase' ssh ...
  Any arguments are ignored
"
# docopt parser below, refresh this parser with `docopt.sh bitwarden-value.sh`
# shellcheck disable=2016,1090,1091,2034,2154
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:566}; usage=${DOC:68:52}; digest=2a27b; shorts=('' '')
longs=(--field --item); argcounts=(1 1); node_0(){ value __field 0; }; node_1(){
value __item 1; }; node_2(){ value ANYARGS a true; }; node_3(){ _command __ --
}; node_4(){ optional 0 1; }; node_5(){ optional 4; }; node_6(){ optional 3; }
node_7(){ oneormore 2; }; node_8(){ optional 6 7; }; node_9(){ required 5 8; }
node_10(){ required 9; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:68:52}" >&2; exit 1
}'; unset var___field var___item var_ANYARGS var___; parse 10 "$@"
local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__field" "${prefix}__item" \
"${prefix}ANYARGS" "${prefix}__"
eval "${prefix}"'__field=${var___field:-'"'"'$BW_FIELD'"'"'}'
eval "${prefix}"'__item=${var___item:-'"'"'$BW_ITEM'"'"'}'
if declare -p var_ANYARGS >/dev/null 2>&1; then
eval "${prefix}"'ANYARGS=("${var_ANYARGS[@]}")'; else
eval "${prefix}"'ANYARGS=()'; fi; eval "${prefix}"'__=${var___:-false}'
local docopt_i=1; [[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2
for ((;docopt_i>0;docopt_i--)); do declare -p "${prefix}__field" \
"${prefix}__item" "${prefix}ANYARGS" "${prefix}__"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' bitwarden-value.sh`
  # shellcheck disable=2034
  DOCOPT_OPTIONS_FIRST=true
  eval "$(docopt "$@")"
  checkdeps jq
  [[ $__item != "\$BW_ITEM" ]] || __item="$BW_ITEM"
  [[ $__field != "\$BW_FIELD" ]] || __field="$BW_FIELD"
  if [[ $__purpose = "retrieve \"\$BW_FIELD\" from \"\$BW_ITEM\"" ]]; then
    __purpose="retrieve \"$BW_FIELD\" from \"$BW_ITEM\""
  fi
  bitwarden-fields --purpose "$__purpose" --json "$__item" "$__field" | jq -re --arg field "$__field" '.[$field]'
}

bitwarden_value "$@"

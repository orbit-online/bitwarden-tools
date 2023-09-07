#!/usr/bin/env bash

bitwarden_ssh_askpass() {
  set -eo pipefail
  shopt -s inherit_errexit
  local pkgroot
  pkgroot=$(upkg root "${BASH_SOURCE[0]}")
  PATH="$pkgroot/.upkg/.bin:$PATH"

  DOC="Retrieve a single field value from Bitwarden and output it verbatim
Usage:
  bitwarden-ssh-askpass [options] [[--] ANYARGS...]

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
# docopt parser below, refresh this parser with `docopt.sh bitwarden-ssh-askpass.sh`
# shellcheck disable=2016,1090,1091,2034,2154
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:830}; usage=${DOC:68:52}; digest=e604f; shorts=('' -p '')
longs=(--item --purpose --field); argcounts=(1 1 1); node_0(){ value __item 0; }
node_1(){ value __purpose 1; }; node_2(){ value __field 2; }; node_3(){
value ANYARGS a true; }; node_4(){ _command __ --; }; node_5(){ optional 0 1 2
}; node_6(){ optional 5; }; node_7(){ optional 4; }; node_8(){ oneormore 3; }
node_9(){ optional 7 8; }; node_10(){ required 6 9; }; node_11(){ required 10; }
cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:68:52}" >&2; exit 1; }'; unset var___item var___purpose \
var___field var_ANYARGS var___; parse 11 "$@"; local prefix=${DOCOPT_PREFIX:-''}
unset "${prefix}__item" "${prefix}__purpose" "${prefix}__field" \
"${prefix}ANYARGS" "${prefix}__"
eval "${prefix}"'__item=${var___item:-'"'"'$BW_ITEM'"'"'}'
eval "${prefix}"'__purpose=${var___purpose:-'"'"'retrieve "$BW_FIELD" from "$BW_ITEM"'"'"'}'
eval "${prefix}"'__field=${var___field:-'"'"'$BW_FIELD'"'"'}'
if declare -p var_ANYARGS >/dev/null 2>&1; then
eval "${prefix}"'ANYARGS=("${var_ANYARGS[@]}")'; else
eval "${prefix}"'ANYARGS=()'; fi; eval "${prefix}"'__=${var___:-false}'
local docopt_i=1; [[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2
for ((;docopt_i>0;docopt_i--)); do declare -p "${prefix}__item" \
"${prefix}__purpose" "${prefix}__field" "${prefix}ANYARGS" "${prefix}__"; done
}
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' bitwarden-ssh-askpass.sh`
  # shellcheck disable=2034
  DOCOPT_OPTIONS_FIRST=true
  eval "$(docopt "$@")"
  [[ $__item != "\$BW_ITEM" ]] || __item="$BW_ITEM"
  [[ $__field != "\$BW_FIELD" ]] || __field="$BW_FIELD"
  if [[ $__purpose = "retrieve \"\$BW_FIELD\" from \"\$BW_ITEM\"" ]]; then
    __purpose="retrieve \"$__field\" from \"$__item\""
  fi
  "$pkgroot/bitwarden-value.sh" --purpose "$__purpose" "$__item" "$__field"
}

bitwarden_ssh_askpass "$@"

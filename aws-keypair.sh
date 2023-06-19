#!/usr/bin/env bash

aws_keypair() {
  set -e
  local pkgroot
  pkgroot=$(upkg root "${BASH_SOURCE[0]}")

  DOC="Output AWS credentials stored in Bitwarden
Usage:
  aws-keypair [options] ITEMNAME

Options:
  --env, -e            Output credentials as exported bash vars instead of json
  --cache-for=SECONDS  Cache item for retrieval without a session [default: 0]
"
# docopt parser below, refresh this parser with `docopt.sh aws-keypair.sh`
# shellcheck disable=2016,1090,1091,2034
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || { ret=$?
printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e; trimmed_doc=${DOC:0:251}
usage=${DOC:43:39}; digest=805f4; shorts=(-e ''); longs=(--env --cache-for)
argcounts=(0 1); node_0(){ switch __env 0; }; node_1(){ value __cache_for 1; }
node_2(){ value ITEMNAME a; }; node_3(){ optional 0 1; }; node_4(){ optional 3
}; node_5(){ required 4 2; }; node_6(){ required 5; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:43:39}" >&2; exit 1
}'; unset var___env var___cache_for var_ITEMNAME; parse 6 "$@"
local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__env" \
"${prefix}__cache_for" "${prefix}ITEMNAME"
eval "${prefix}"'__env=${var___env:-false}'
eval "${prefix}"'__cache_for=${var___cache_for:-0}'
eval "${prefix}"'ITEMNAME=${var_ITEMNAME:-}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}__env" "${prefix}__cache_for" "${prefix}ITEMNAME"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' aws-keypair.sh`
  eval "$(docopt "$@")"
  if [[ $FILE != /* && $FILE != ~* ]]; then
    FILE=$HOME/$FILE
  fi
  # shellcheck disable=2154
  eval "$("$pkgroot/bitwarden-fields.sh" --cache-for="$__cache_for" 'AWS API user' AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY || echo return 1)"
  # shellcheck disable=2154
  if $__env; then
    printf 'export AWS_ACCESS_KEY_ID="%s"\nexport AWS_SECRET_ACCESS_KEY="%s"\n' "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY"
  else
    printf '{\n  "Version": 1,\n  "AccessKeyId": "%s",\n  "SecretAccessKey": "%s"\n}\n' "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY"
  fi
}

aws_keypair "$@"

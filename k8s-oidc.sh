#!/usr/bin/env bash
set -e

bw_oidc() {
  DOC="Output OIDC credentials for a cluster
Usage:
  k8s-oidc.sh ITEMNAME
"
# docopt parser below, refresh this parser with `docopt.sh k8s-oidc.sh`
# shellcheck disable=2016,1090,1091,2034
docopt() { source "$PKGROOT/docopt-lib-1.0.0.sh" '1.0.0' || { ret=$?
printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e; trimmed_doc=${DOC:0:67}
usage=${DOC:38:29}; digest=259d6; shorts=(); longs=(); argcounts=(); node_0(){
value ITEMNAME a; }; node_1(){ required 0; }; node_2(){ required 1; }
cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:38:29}" >&2; exit 1; }'; unset var_ITEMNAME; parse 2 "$@"
local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}ITEMNAME"
eval "${prefix}"'ITEMNAME=${var_ITEMNAME:-}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}ITEMNAME"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$PKGROOT/docopt-lib-1.0.0.sh"' k8s-oidc.sh`
  eval "$(docopt "$@")"
  local data
  data=$(bitwarden-fields --cache-for=900 "$ITEMNAME" oidc-issuer-url oidc-client-id oidc-client-secret)
  eval "$data"
  # shellcheck disable=SC2154
  kubectl \
    oidc-login \
    get-token \
    --oidc-issuer-url="$oidc_issuer_url" \
    --oidc-client-id="$oidc_client_id" \
    --oidc-client-secret="$oidc_client_secret"
}

bw_oidc "$@"

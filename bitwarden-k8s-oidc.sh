#!/usr/bin/env bash
# shellcheck source-path=../..

k8s_oidc() {
  set -eo pipefail; shopt -s inherit_errexit
  local pkgroot; pkgroot=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
  (cd "$pkgroot" && UPKG_SILENT=true upkg install)
  PATH=$("$pkgroot/.upkg/.bin/path_prepend" "$pkgroot/.upkg/.bin")

  DOC="Output OIDC credentials for a cluster
Usage:
  bitwarden-k8s-oidc [options] ITEMNAME

Options:
  --cache-for=SECONDS   Cache item with socket-credential-cache [default: 0]
"
# docopt parser below, refresh this parser with `docopt.sh bitwarden-k8s-oidc.sh`
# shellcheck disable=2016,1090,1091,2034
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:171}; usage=${DOC:38:46}; digest=1500c; shorts=('')
longs=(--cache-for); argcounts=(1); node_0(){ value __cache_for 0; }; node_1(){
value ITEMNAME a; }; node_2(){ optional 0; }; node_3(){ optional 2; }; node_4(){
required 3 1; }; node_5(){ required 4; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:38:46}" >&2; exit 1
}'; unset var___cache_for var_ITEMNAME; parse 5 "$@"
local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__cache_for" \
"${prefix}ITEMNAME"; eval "${prefix}"'__cache_for=${var___cache_for:-0}'
eval "${prefix}"'ITEMNAME=${var_ITEMNAME:-}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}__cache_for" "${prefix}ITEMNAME"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' bitwarden-k8s-oidc.sh`
  eval "$(docopt "$@")"
  # shellcheck disable=2154
  eval "$("$pkgroot/bitwarden-fields.sh" -e --cache-for="$__cache_for" "$ITEMNAME" oidc-issuer-url oidc-client-id oidc-client-secret)"
  # shellcheck disable=2154
  kubectl \
    oidc-login \
    get-token \
    --oidc-issuer-url="$oidc_issuer_url" \
    --oidc-client-id="$oidc_client_id" \
    --oidc-client-secret="$oidc_client_secret"
}

k8s_oidc "$@"

#!/usr/bin/env bash

k8s_cert() {
  set -e
  PKGROOT=$(cd "$(dirname "$(bpkg realpath "${BASH_SOURCE[0]}")")"; echo "$PWD")

  DOC="Output client cert credentials for a cluster
Usage:
  k8s-cert.sh ITEMNAME
"
# docopt parser below, refresh this parser with `docopt.sh k8s-cert.sh`
# shellcheck disable=2016,1090,1091,2034
docopt() { source "$PKGROOT/deps/docopt.sh/docopt-lib.sh" '1.0.0' || { ret=$?
printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e; trimmed_doc=${DOC:0:74}
usage=${DOC:45:29}; digest=0018f; shorts=(); longs=(); argcounts=(); node_0(){
value ITEMNAME a; }; node_1(){ required 0; }; node_2(){ required 1; }
cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:45:29}" >&2; exit 1; }'; unset var_ITEMNAME; parse 2 "$@"
local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}ITEMNAME"
eval "${prefix}"'ITEMNAME=${var_ITEMNAME:-}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}ITEMNAME"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$PKGROOT/deps/docopt.sh/docopt-lib.sh"' k8s-cert.sh`
  eval "$(docopt "$@")"
  local data
  data="$(bitwarden-fields --cache-for=900 "$ITEMNAME" attachment:tls.crt attachment:tls.key || echo return 1)"
  eval "$data"
  # shellcheck disable=SC2154
  printf '{
  "apiVersion": "client.authentication.k8s.io/v1beta1",
  "kind": "ExecCredential",
  "status": {
    "clientCertificateData": "%s",
    "clientKeyData": "%s"
  }
}\n' "${tls_crt//$'\n'/\\n}" "${tls_key//$'\n'/\\n}"
}

if [[ ${BASH_SOURCE[0]} = "$0" ]]; then
  k8s_cert "$@"
fi

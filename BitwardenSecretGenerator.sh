#!/usr/bin/env bash

bitwarden_secret_generator() {
  set -e
  local pkgroot
  pkgroot=$(upkg root "${BASH_SOURCE[0]}")
  # shellcheck source=.upkg/orbit-online/records.sh/records.sh
  source "$pkgroot/.upkg/orbit-online/records.sh/records.sh"
  # shellcheck source=lib.sh
  source "$pkgroot/lib.sh"

  DOC="BitwardenSecretGenerator - Output a bitwarden entry as a kubernetes secret
Usage:
  BitwardenSecretGenerator [options] --name=NAME ITEMNAME FIELD...

Options:
  --name=NAME            Name of the secret
  --namespace=NAMESPACE  Namespace of the secret
  --type=TYPE            The type of secret [default: Opaque]

ITEMNAME format:
  To retrieve attachments prefix the field with \`attachment:\` or \`attachmentid:\`
  To rename a field, prefix the the field with \`NAME@\` before \`attachment:\`
  To encode as stringdata prefix the field with \`stringdata:\` before \`NAME@\`
"
# docopt parser below, refresh this parser with `docopt.sh BitwardenSecretGenerator.sh`
# shellcheck disable=2016,1090,1091,2034,2154
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || { ret=$?
printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e; trimmed_doc=${DOC:0:565}
usage=${DOC:75:73}; digest=bc693; shorts=('' '' '')
longs=(--namespace --type --name); argcounts=(1 1 1); node_0(){
value __namespace 0; }; node_1(){ value __type 1; }; node_2(){ value __name 2; }
node_3(){ value ITEMNAME a; }; node_4(){ value FIELD a true; }; node_5(){
optional 0 1; }; node_6(){ optional 5; }; node_7(){ oneormore 4; }; node_8(){
required 6 2 3 7; }; node_9(){ required 8; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:75:73}" >&2; exit 1
}'; unset var___namespace var___type var___name var_ITEMNAME var_FIELD
parse 9 "$@"; local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__namespace" \
"${prefix}__type" "${prefix}__name" "${prefix}ITEMNAME" "${prefix}FIELD"
eval "${prefix}"'__namespace=${var___namespace:-}'
eval "${prefix}"'__type=${var___type:-Opaque}'
eval "${prefix}"'__name=${var___name:-}'
eval "${prefix}"'ITEMNAME=${var_ITEMNAME:-}'
if declare -p var_FIELD >/dev/null 2>&1; then
eval "${prefix}"'FIELD=("${var_FIELD[@]}")'; else eval "${prefix}"'FIELD=()'; fi
local docopt_i=1; [[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2
for ((;docopt_i>0;docopt_i--)); do declare -p "${prefix}__namespace" \
"${prefix}__type" "${prefix}__name" "${prefix}ITEMNAME" "${prefix}FIELD"; done
}
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' BitwardenSecretGenerator.sh`
  checkdeps bw jq yq base64
  [[ $1 == *kust-plugin-config* ]] && shift
  eval "$(docopt "$@")"

  local stringdata secret data field_spec field_name secret_field_name field_names=()
  for field_spec in "${FIELD[@]}"; do
    if ! [[ $field_spec =~ ^(stringdata:)?(([^@]+)@)?(attachment(id)?:)?(.*)$ ]]; then
      fatal 'Unable to parse field name %s\n' "$field_spec"
    fi
    field_names+=("${BASH_REMATCH[4]}${BASH_REMATCH[6]}")
  done

  data="$("$pkgroot/bitwarden-fields.sh" --cache-for=900 --json "$ITEMNAME" "${field_names[@]}")"
  secret="kind: Secret
apiVersion: v1
metadata:"
  # shellcheck disable=SC2154
  secret=$(yq eval ".metadata.name=\"$__name\"" - <<<"$secret")
  # shellcheck disable=SC2154
  secret=$(yq eval ".type=\"$__type\"" - <<<"$secret")
  # shellcheck disable=SC2154
  if [[ -n $__namespace ]]; then
    secret=$(yq eval ".metadata.namespace=\"$__namespace\"" - <<<"$secret")
  fi
  for field_spec in "${FIELD[@]}"; do
    if ! [[ $field_spec =~ ^(stringdata:)?(([^@]+)@)?(attachment(id)?:)?(.*)$ ]]; then
      fatal 'Unable to parse field spec %s\n' "$field_spec"
    fi
    field_name=${BASH_REMATCH[6]}
    if [[ -n ${BASH_REMATCH[1]} ]]; then
      stringdata=true
    else
      stringdata=false
    fi
    if [[ -n ${BASH_REMATCH[3]} ]]; then
      secret_field_name=${BASH_REMATCH[3]}
    else
      secret_field_name=${field_name//[^-._a-zA-Z0-9]+/_}
    fi
    IFS= read -rd '' value < <(jq -r --arg name "$field_name" '.[$name]' <<<"$data") || true
    value=${value%$'\n'}
    # shellcheck disable=SC2154
    if $stringdata; then
      secret=$(yq eval ".stringData.\"$secret_field_name\"=\"$value\"" - <<<"$secret")
    else
      encoded_value=$(printf -- "%s" "$value" | base64 --wrap=0)
      secret=$(yq eval ".data.\"$secret_field_name\"=\"$encoded_value\"" - <<<"$secret")
    fi
  done
  printf -- "%s\n" "$secret"
}

bitwarden_secret_generator "$@"

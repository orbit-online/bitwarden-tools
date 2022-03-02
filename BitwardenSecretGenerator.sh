#!/usr/bin/env bash
set -e

main() {
  DOC="BitwardenSecretGenerator - Output a bitwarden entry as a kubernetes secret
Usage:
  BitwardenSecretGenerator [--namespace=NAMESPACE] --name=NAME ITEMNAME FIELD...

Options:
  --name=NAME            Name of the secret
  --namespace=NAMESPACE  Namespace of the secret

ITEMNAME format:
  To retrieve attachments prefix the field with \`attachment:\` or \`attachmentid:\`
  To rename a field, prefix the the field with \`NAME@\` before \`attachment:\`
  To encode as stringdata prefix the field with \`stringdata:\` before \`NAME@\`
"
# docopt parser below, refresh this parser with `docopt.sh BitwardenSecretGenerator.sh`
# shellcheck disable=2016,1075,2154
docopt() { parse() { if ${DOCOPT_DOC_CHECK:-true}; then local doc_hash
if doc_hash=$(printf "%s" "$DOC" | (sha256sum 2>/dev/null || shasum -a 256)); then
if [[ ${doc_hash:0:5} != "$digest" ]]; then
stderr "The current usage doc (${doc_hash:0:5}) does not match \
what the parser was generated with (${digest})
Run \`docopt.sh\` to refresh the parser."; _return 70; fi; fi; fi
local root_idx=$1; shift; argv=("$@"); parsed_params=(); parsed_values=()
left=(); testdepth=0; local arg; while [[ ${#argv[@]} -gt 0 ]]; do
if [[ ${argv[0]} = "--" ]]; then for arg in "${argv[@]}"; do
parsed_params+=('a'); parsed_values+=("$arg"); done; break
elif [[ ${argv[0]} = --* ]]; then parse_long
elif [[ ${argv[0]} = -* && ${argv[0]} != "-" ]]; then parse_shorts
elif ${DOCOPT_OPTIONS_FIRST:-false}; then for arg in "${argv[@]}"; do
parsed_params+=('a'); parsed_values+=("$arg"); done; break; else
parsed_params+=('a'); parsed_values+=("${argv[0]}"); argv=("${argv[@]:1}"); fi
done; local idx; if ${DOCOPT_ADD_HELP:-true}; then
for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue
if [[ ${shorts[$idx]} = "-h" || ${longs[$idx]} = "--help" ]]; then
stdout "$trimmed_doc"; _return 0; fi; done; fi
if [[ ${DOCOPT_PROGRAM_VERSION:-false} != 'false' ]]; then
for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue
if [[ ${longs[$idx]} = "--version" ]]; then stdout "$DOCOPT_PROGRAM_VERSION"
_return 0; fi; done; fi; local i=0; while [[ $i -lt ${#parsed_params[@]} ]]; do
left+=("$i"); ((i++)) || true; done
if ! required "$root_idx" || [ ${#left[@]} -gt 0 ]; then error; fi; return 0; }
parse_shorts() { local token=${argv[0]}; local value; argv=("${argv[@]:1}")
[[ $token = -* && $token != --* ]] || _return 88; local remaining=${token#-}
while [[ -n $remaining ]]; do local short="-${remaining:0:1}"
remaining="${remaining:1}"; local i=0; local similar=(); local match=false
for o in "${shorts[@]}"; do if [[ $o = "$short" ]]; then similar+=("$short")
[[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ ${#similar[@]} -gt 1 ]]; then
error "${short} is specified ambiguously ${#similar[@]} times"
elif [[ ${#similar[@]} -lt 1 ]]; then match=${#shorts[@]}; value=true
shorts+=("$short"); longs+=(''); argcounts+=(0); else value=false
if [[ ${argcounts[$match]} -ne 0 ]]; then if [[ $remaining = '' ]]; then
if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
error "${short} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}")
else value=$remaining; remaining=''; fi; fi; if [[ $value = false ]]; then
value=true; fi; fi; parsed_params+=("$match"); parsed_values+=("$value"); done
}; parse_long() { local token=${argv[0]}; local long=${token%%=*}
local value=${token#*=}; local argcount; argv=("${argv[@]:1}")
[[ $token = --* ]] || _return 88; if [[ $token = *=* ]]; then eq='='; else eq=''
value=false; fi; local i=0; local similar=(); local match=false
for o in "${longs[@]}"; do if [[ $o = "$long" ]]; then similar+=("$long")
[[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ $match = false ]]; then i=0; for o in "${longs[@]}"; do
if [[ $o = $long* ]]; then similar+=("$long"); [[ $match = false ]] && match=$i
fi; ((i++)) || true; done; fi; if [[ ${#similar[@]} -gt 1 ]]; then
error "${long} is not a unique prefix: ${similar[*]}?"
elif [[ ${#similar[@]} -lt 1 ]]; then
[[ $eq = '=' ]] && argcount=1 || argcount=0; match=${#shorts[@]}
[[ $argcount -eq 0 ]] && value=true; shorts+=(''); longs+=("$long")
argcounts+=("$argcount"); else if [[ ${argcounts[$match]} -eq 0 ]]; then
if [[ $value != false ]]; then
error "${longs[$match]} must not have an argument"; fi
elif [[ $value = false ]]; then
if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
error "${long} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}")
fi; if [[ $value = false ]]; then value=true; fi; fi; parsed_params+=("$match")
parsed_values+=("$value"); }; required() { local initial_left=("${left[@]}")
local node_idx; ((testdepth++)) || true; for node_idx in "$@"; do
if ! "node_$node_idx"; then left=("${initial_left[@]}"); ((testdepth--)) || true
return 1; fi; done; if [[ $((--testdepth)) -eq 0 ]]; then
left=("${initial_left[@]}"); for node_idx in "$@"; do "node_$node_idx"; done; fi
return 0; }; optional() { local node_idx; for node_idx in "$@"; do
"node_$node_idx"; done; return 0; }; oneormore() { local i=0
local prev=${#left[@]}; while "node_$1"; do ((i++)) || true
[[ $prev -eq ${#left[@]} ]] && break; prev=${#left[@]}; done
if [[ $i -ge 1 ]]; then return 0; fi; return 1; }; value() { local i
for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; local value
value=$(printf -- "%q" "${parsed_values[$l]}"); if [[ $3 = true ]]; then
eval "var_$1+=($value)"; else eval "var_$1=$value"; fi; return 0; fi; done
return 1; }; stdout() { printf -- "cat <<'EOM'\n%s\nEOM\n" "$1"; }; stderr() {
printf -- "cat <<'EOM' >&2\n%s\nEOM\n" "$1"; }; error() {
[[ -n $1 ]] && stderr "$1"; stderr "$usage"; _return 1; }; _return() {
printf -- "exit %d\n" "$1"; exit "$1"; }; set -e; trimmed_doc=${DOC:0:517}
usage=${DOC:75:87}; digest=20789; shorts=('' ''); longs=(--namespace --name)
argcounts=(1 1); node_0(){ value __namespace 0; }; node_1(){ value __name 1; }
node_2(){ value ITEMNAME a; }; node_3(){ value FIELD a true; }; node_4(){
optional 0; }; node_5(){ oneormore 3; }; node_6(){ required 4 1 2 5; }
node_7(){ required 6; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:75:87}" >&2; exit 1
}'; unset var___namespace var___name var_ITEMNAME var_FIELD; parse 7 "$@"
local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__namespace" \
"${prefix}__name" "${prefix}ITEMNAME" "${prefix}FIELD"
eval "${prefix}"'__namespace=${var___namespace:-}'
eval "${prefix}"'__name=${var___name:-}'
eval "${prefix}"'ITEMNAME=${var_ITEMNAME:-}'
if declare -p var_FIELD >/dev/null 2>&1; then
eval "${prefix}"'FIELD=("${var_FIELD[@]}")'; else eval "${prefix}"'FIELD=()'; fi
local docopt_i=1; [[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2
for ((;docopt_i>0;docopt_i--)); do declare -p "${prefix}__namespace" \
"${prefix}__name" "${prefix}ITEMNAME" "${prefix}FIELD"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh BitwardenSecretGenerator.sh`
  checkdeps bw jq yq base64
  [[ $1 == *kust-plugin-config* ]] && shift
  eval "$(docopt "$@")"

  local stringdata secret data field_spec field_name secret_field_name field_names=()
  for field_spec in "${FIELD[@]}"; do
    if ! [[ $field_spec =~ ^(stringdata:)?(([^@]+)@)?(attachment(id)?:)?(.*)$ ]]; then
      printf -- $'Unable to parse field name %s\n' "$field_spec" >&2
      return 1
    fi
    field_names+=("${BASH_REMATCH[4]}${BASH_REMATCH[6]}")
  done

  data="$(bitwarden-fields --cache-for=900 --json "$ITEMNAME" "${field_names[@]}")"
  secret="kind: Secret
apiVersion: v1
metadata:"
  # shellcheck disable=SC2154
  secret=$(yq eval ".metadata.name=\"$__name\"" - <<<"$secret")
  # shellcheck disable=SC2154
  if [[ -n $__namespace ]]; then
    secret=$(yq eval ".metadata.namespace=\"$__namespace\"" - <<<"$secret")
  fi
  for field_spec in "${FIELD[@]}"; do
    if ! [[ $field_spec =~ ^(stringdata:)?(([^@]+)@)?(attachment(id)?:)?(.*)$ ]]; then
      printf -- $'Unable to parse field spec %s\n' "$field_spec" >&2
      return 1
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

checkdeps() {
  local deps=("$@")
  local dep
  local out
  local ret=0
  for dep in "${deps[@]}"; do
    if ! out=$(type "$dep" 2>&1); then
      printf -- "Dependency %s not found:\n%s\n" "$dep" "$out"
      ret=1
    fi
  done
  return $ret
}

main "$@"

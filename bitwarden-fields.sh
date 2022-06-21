#!/usr/bin/env bash
set -e

bw_fields() {
  DOC="Output Bitwarden item fields as bash variables
Usage:
  bitwarden-fields [options] ITEMNAME [FIELD...]

Options:
  --cache-for=SECONDS  Cache item for retrieval without a session [default: 0]
  --json -j            Output as JSON instead of bash variables
Note:
  To retrieve attachments, prefix their name with \`attachment:\`
  For attachment IDs use \`attachmentid:\`
  To retrieve all fields, omit the FIELD argument entirely
"
# docopt parser below, refresh this parser with `docopt.sh bitwarden-fields.sh`
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
if [[ $i -ge 1 ]]; then return 0; fi; return 1; }; switch() { local i
for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; if [[ $3 = true ]]; then
eval "((var_$1++))" || true; else eval "var_$1=true"; fi; return 0; fi; done
return 1; }; value() { local i; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; local value
value=$(printf -- "%q" "${parsed_values[$l]}"); if [[ $3 = true ]]; then
eval "var_$1+=($value)"; else eval "var_$1=$value"; fi; return 0; fi; done
return 1; }; stdout() { printf -- "cat <<'EOM'\n%s\nEOM\n" "$1"; }; stderr() {
printf -- "cat <<'EOM' >&2\n%s\nEOM\n" "$1"; }; error() {
[[ -n $1 ]] && stderr "$1"; stderr "$usage"; _return 1; }; _return() {
printf -- "exit %d\n" "$1"; exit "$1"; }; set -e; trimmed_doc=${DOC:0:425}
usage=${DOC:47:55}; digest=04b0b; shorts=(-j ''); longs=(--json --cache-for)
argcounts=(0 1); node_0(){ switch __json 0; }; node_1(){ value __cache_for 1; }
node_2(){ value ITEMNAME a; }; node_3(){ value FIELD a true; }; node_4(){
optional 0 1; }; node_5(){ optional 4; }; node_6(){ oneormore 3; }; node_7(){
optional 6; }; node_8(){ required 5 2 7; }; node_9(){ required 8; }
cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:47:55}" >&2; exit 1; }'; unset var___json var___cache_for \
var_ITEMNAME var_FIELD; parse 9 "$@"; local prefix=${DOCOPT_PREFIX:-''}
unset "${prefix}__json" "${prefix}__cache_for" "${prefix}ITEMNAME" \
"${prefix}FIELD"; eval "${prefix}"'__json=${var___json:-false}'
eval "${prefix}"'__cache_for=${var___cache_for:-0}'
eval "${prefix}"'ITEMNAME=${var_ITEMNAME:-}'
if declare -p var_FIELD >/dev/null 2>&1; then
eval "${prefix}"'FIELD=("${var_FIELD[@]}")'; else eval "${prefix}"'FIELD=()'; fi
local docopt_i=1; [[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2
for ((;docopt_i>0;docopt_i--)); do declare -p "${prefix}__json" \
"${prefix}__cache_for" "${prefix}ITEMNAME" "${prefix}FIELD"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh bitwarden-fields.sh`

  checkdeps bw jq

  eval "$(docopt "$@")"

  local data
  local cache_name="Bitwarden $ITEMNAME"
  local LOCK_PATH="${TMP:-/tmp}/${cache_name//[^A-Za-z0-9_]/_}.lock"
  exec 9<>"$LOCK_PATH"
  flock 9
  trap "exec 9>&-" EXIT
  if ! data=$(socket-credential-cache get "$cache_name" 2>/dev/null); then
    if [[ -z $BW_SESSION ]]; then
      export BW_SESSION
      BW_SESSION=$(bitwarden-unlock --purpose="retrieve \"$ITEMNAME\"")
      # shellcheck disable=2064
      trap "exec 9>&-; BW_SESSION=\"$BW_SESSION\" bw lock >/dev/null" EXIT
    fi
    if ! data=$(bw --nointeraction --raw get item "$ITEMNAME"); then
      local ret=$?
      printf "Unable to retrieve '%s'\n" "$ITEMNAME" >&2
      return $ret
    fi
    local item_id
    item_id=$(jq -r '.id' <<<"$data")
    local attachment_id
    local attachment_path
    for attachment_id in $(jq -r '(.attachments // [])[].id' <<<"$data"); do
      attachment_path=$(mktemp)
      bw --nointeraction --quiet get attachment "$attachment_id" --itemid "$item_id" --output "$attachment_path"
      data=$(
        jq --arg id "$attachment_id" '.attachments[(.attachments | map(.id == $id) | index(true))].data = '"$(jq --slurp -R . "$attachment_path")" \
        <<<"$data"
        r=$?
        rm "$attachment_path"
        exit $r
      )
    done
    unset BW_SESSION
    # shellcheck disable=2154
    if [[ $__cache_for -gt 0 ]]; then
      socket-credential-cache --timeout="$__cache_for" set "$cache_name" <<<"$data"
    fi
  fi
  # shellcheck disable=2154
  if $__json; then
    local json_out='{}'
  fi
  if [[ ${#FIELD[@]} -eq 0 ]]; then
    readarray -td $'\n' FIELD < <(
      jq -r '((.login // {}) | keys[]), ((.attachments // [])[] | ("attachment:" + .fileName)), ((.fields // [])[] | .name)' <<<"$data"
    )
  fi
  local field_name
  for field_name in "${FIELD[@]}"; do
    local variable_name=$field_name
    # We read $value weirdly to preserve trailing newlines. Command substitution removes all trailing newlines
    if [[ $field_name = username || $field_name = password || $field_name = totp || $field_name = uris || $field_name = passwordRevisionDate ]]; then
      IFS= read -rd '' value < <(jq -r --arg name "$field_name" '.login[$name]' <<<"$data") || true
    elif [[ $field_name = attachmentid:* ]]; then
      local attachment_id=${field_name/#attachmentid:/}
      variable_name=${variable_name/#attachmentid:/}
      IFS= read -rd '' value < <(jq -r --arg id "$attachment_id" '.attachments[] | select(.id==$id).data' <<<"$data") || true
    elif [[ $field_name = attachment:* ]]; then
      local attachment_name=${field_name/#attachment:/}
      variable_name=${variable_name/#attachment:/}
      IFS= read -rd '' value < <( jq -r --arg name "$attachment_name" '.attachments[] | select(.fileName==$name).data' <<<"$data" ) || true
    else
      IFS= read -rd '' value < <(jq -r --arg name "$field_name" '.fields[] | select(.name==$name).value' <<<"$data") || true
    fi
    # jq itself attaches a newline to its output, remove that, but keep others
    value=${value%$'\n'}
    if $__json; then
      json_out=$(jq --arg key "$variable_name" --arg value "$value" '.[$key]=$value' <<<"$json_out")
    else
      variable_name=${variable_name//[^A-Za-z0-9_]/_}
      variable_name=${variable_name/#[^A-Za-z_]/_}
      printf -- 'declare -- %s=%q\n' "$variable_name" "$value"
    fi
  done
  if $__json; then
    printf "%s\n" "$json_out"
  fi
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

bw_fields "$@"

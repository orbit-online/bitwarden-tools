#!/usr/bin/env bash

bitwarden_fields() {
  set -eo pipefail
  shopt -s inherit_errexit
  local pkgroot
  pkgroot=$(upkg root "${BASH_SOURCE[0]}")
  # shellcheck source=.upkg/orbit-online/records.sh/records.sh
  source "$pkgroot/.upkg/orbit-online/records.sh/records.sh"
  PATH="$pkgroot/.upkg/.bin:$PATH"

  DOC="Output Bitwarden item fields as bash variables
Usage:
  bitwarden-fields [options] ITEMNAME [FIELD...]

Options:
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
                        [default: retrieve \"\$ITEMNAME\"]
  --cache-for=SECONDS   Cache item with socket-credential-cache [default: 0]
  -j --json             Output as JSON instead of bash variables
  --prefix=PREFIX       Prefix variable names with supplied string
  -e                    Print 'false' on error
  --debug               Turn on bash -x
Note:
  To retrieve attachments, prefix their name with \`attachment:\`
  For attachment IDs use \`attachmentid:\`
  To retrieve all fields, omit the FIELD argument entirely
"
# docopt parser below, refresh this parser with `docopt.sh bitwarden-fields.sh`
# shellcheck disable=2016,1090,1091,2034,2154
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:826}; usage=${DOC:47:55}; digest=abacd
shorts=('' '' -p '' -e -j)
longs=(--debug --cache-for --purpose --prefix '' --json)
argcounts=(0 1 1 1 0 0); node_0(){ switch __debug 0; }; node_1(){
value __cache_for 1; }; node_2(){ value __purpose 2; }; node_3(){
value __prefix 3; }; node_4(){ switch _e 4; }; node_5(){ switch __json 5; }
node_6(){ value ITEMNAME a; }; node_7(){ value FIELD a true; }; node_8(){
optional 0 1 2 3 4 5; }; node_9(){ optional 8; }; node_10(){ oneormore 7; }
node_11(){ optional 10; }; node_12(){ required 9 6 11; }; node_13(){ required 12
}; cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:47:55}" >&2; exit 1; }'; unset var___debug \
var___cache_for var___purpose var___prefix var__e var___json var_ITEMNAME \
var_FIELD; parse 13 "$@"; local prefix=${DOCOPT_PREFIX:-''}
unset "${prefix}__debug" "${prefix}__cache_for" "${prefix}__purpose" \
"${prefix}__prefix" "${prefix}_e" "${prefix}__json" "${prefix}ITEMNAME" \
"${prefix}FIELD"; eval "${prefix}"'__debug=${var___debug:-false}'
eval "${prefix}"'__cache_for=${var___cache_for:-0}'
eval "${prefix}"'__purpose=${var___purpose:-'"'"'retrieve "$ITEMNAME"'"'"'}'
eval "${prefix}"'__prefix=${var___prefix:-}'
eval "${prefix}"'_e=${var__e:-false}'
eval "${prefix}"'__json=${var___json:-false}'
eval "${prefix}"'ITEMNAME=${var_ITEMNAME:-}'
if declare -p var_FIELD >/dev/null 2>&1; then
eval "${prefix}"'FIELD=("${var_FIELD[@]}")'; else eval "${prefix}"'FIELD=()'; fi
local docopt_i=1; [[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2
for ((;docopt_i>0;docopt_i--)); do declare -p "${prefix}__debug" \
"${prefix}__cache_for" "${prefix}__purpose" "${prefix}__prefix" "${prefix}_e" \
"${prefix}__json" "${prefix}ITEMNAME" "${prefix}FIELD"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' bitwarden-fields.sh`

  checkdeps bw jq # Keep socket-credential-cachel optional, but let it fail when e.g. --cache-for is used

  eval "$(docopt "$@")"

  # shellcheck disable=2154
  if $__debug; then
    set -x
  fi

  local data lockdir="/var/run/lock/bitwarden-fields" cache_name="Bitwarden $ITEMNAME"
  [[ -d "$lockdir" ]] || mkdir "$lockdir"
  local lockpath="$lockdir/${ITEMNAME//[^A-Za-z0-9_]/_}.lock"
  exec 9<>"$lockpath"
  flock 9
  trap "exec 9>&-" EXIT
  local was_cached=true
  if ! data=$(socket-credential-cache get "$cache_name" 2>/dev/null); then
    was_cached=false
    if [[ -z $BW_SESSION ]]; then
      if [[ $__purpose = "retrieve \"\$ITEMNAME\"" ]]; then
        __purpose="retrieve \"$ITEMNAME\""
      fi
      export BW_SESSION
      BW_SESSION=$("$pkgroot/bitwarden-unlock.sh" --purpose "$__purpose")
      # shellcheck disable=2064
      trap "exec 9>&-; BW_SESSION=\"$BW_SESSION\" bw lock </dev/null >/dev/null" EXIT
    fi
    if ! data=$(bw --nointeraction --raw get item "$ITEMNAME" </dev/null); then
      printf "\n"
      # shellcheck disable=2154
      [[ $_e != 'true' ]] || printf "false\n"
      fatal "Unable to retrieve '%s'" "$ITEMNAME"
    fi
    local item_id
    item_id=$(jq -r '.id' <<<"$data")
    local attachment_id
    local attachment_path
    for attachment_id in $(jq -r '(.attachments // [])[].id' <<<"$data"); do
      attachment_path=$(mktemp)
      bw --nointeraction --quiet get attachment "$attachment_id" --itemid "$item_id" --output "$attachment_path" </dev/null
      data=$(
        jq --arg id "$attachment_id" '.attachments[(.attachments | map(.id == $id) | index(true))].data = '"$(jq --slurp -R . "$attachment_path")" \
        <<<"$data"
        r=$?
        rm "$attachment_path"
        exit $r
      )
    done
    unset BW_SESSION
  fi
  # shellcheck disable=2154
  if $__json; then
    local json_out='{}'
  fi
  if [[ ${#FIELD[@]} -eq 0 ]]; then
    # No fields specified, output everything
    readarray -td $'\n' FIELD < <(
      jq -r '((.login // {}) | del(.[] | nulls) | keys[]), ((.attachments // [])[] | ("attachment:" + .fileName)), ((.fields // [])[] | .name)' <<<"$data"
    )
  fi
  local field_name
  for field_name in "${FIELD[@]}"; do
    local variable_name=$field_name
    # Command substitution removes all trailing newlines, so we append an ETX (end of text) char and then remove it afterwards
    if [[ $field_name = id ]]; then
      if ! value=$(jq -jre '.id' <<<"$data" && printf '\3'); then
        [[ $_e != 'true' ]] || printf "false\n"
        fatal "Unable to retried the ID field."
      fi
    elif [[ $field_name = username || $field_name = password || $field_name = totp || $field_name = uris || $field_name = passwordRevisionDate ]]; then
      if ! value=$(jq -jre --arg name "$field_name" '.login[$name]' <<<"$data" && printf '\3'); then
        [[ $_e != 'true' ]] || printf "false\n"
        fatal "The field %s is not set." "$field_name"
      fi
    elif [[ $field_name = attachmentid:* ]]; then
      local attachment_id=${field_name/#attachmentid:/}
      variable_name=${variable_name/#attachmentid:/}
      if ! value=$(jq -jre --arg id "$attachment_id" '.attachments[] | select(.id==$id).data' <<<"$data" && printf '\3'); then
        [[ $_e != 'true' ]] || printf "false\n"
        fatal "The attachment %s does not exist." "$attachment_id"
      fi
    elif [[ $field_name = attachment:* ]]; then
      local attachment_name=${field_name/#attachment:/}
      variable_name=${variable_name/#attachment:/}
      if ! value=$(jq -jre --arg name "$attachment_name" '.attachments[] | select(.fileName==$name).data' <<<"$data" && printf '\3'); then
        [[ $_e != 'true' ]] || printf "false\n"
        fatal "The attachment %s does not exist." "$attachment_name"
      fi
    else
      if ! value=$(jq -jre --arg name "$field_name" '.fields[] | select(.name==$name).value' <<<"$data" && printf '\3'); then
        [[ $_e != 'true' ]] || printf "false\n"
        fatal "The field %s is not set." "$field_name"
      fi
    fi
    # Remove the ETX char
    value=${value%$'\3'}
    # shellcheck disable=2154
    variable_name=$__prefix$variable_name
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
  # shellcheck disable=2154
  if ! $was_cached && [[ $__cache_for -gt 0 ]]; then
    socket-credential-cache --timeout="$__cache_for" set "$cache_name" <<<"$data"
  fi
}

bitwarden_fields "$@"

#!/usr/bin/env bash

CACHE_FOR=$((60 * 60 * 8))

docker_credential_bitwarden() {
  set -eo pipefail
  shopt -s inherit_errexit
  local pkgroot
  pkgroot=$(upkg root "${BASH_SOURCE[0]}")
  # shellcheck source=.upkg/orbit-online/records.sh/records.sh
  source "$pkgroot/.upkg/orbit-online/records.sh/records.sh"
  PATH="$pkgroot/.upkg/.bin:$PATH"

  DOC="docker-credential-bitwarden - Bitwarden backing for docker logins
Usage:
  docker-credential-bitwarden (get|store|erase|list|version)

Note:
  Configure this backing in ~/.docker/config.json with
  {\"credsStore\": \"bitwarden\"}
"
# docopt parser below, refresh this parser with `docopt.sh docker-credential-bitwarden.sh`
# shellcheck disable=2016,1090,1091,2034
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:225}; usage=${DOC:66:67}; digest=a1f4e; shorts=(); longs=()
argcounts=(); node_0(){ _command get; }; node_1(){ _command store; }; node_2(){
_command erase; }; node_3(){ _command list; }; node_4(){ _command version; }
node_5(){ either 0 1 2 3 4; }; node_6(){ required 5; }; node_7(){ required 6; }
node_8(){ required 7; }; cat <<<' docopt_exit() {
[[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:66:67}" >&2; exit 1
}'; unset var_get var_store var_erase var_list var_version; parse 8 "$@"
local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}get" "${prefix}store" \
"${prefix}erase" "${prefix}list" "${prefix}version"
eval "${prefix}"'get=${var_get:-false}'
eval "${prefix}"'store=${var_store:-false}'
eval "${prefix}"'erase=${var_erase:-false}'
eval "${prefix}"'list=${var_list:-false}'
eval "${prefix}"'version=${var_version:-false}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}get" "${prefix}store" "${prefix}erase" "${prefix}list" \
"${prefix}version"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' docker-credential-bitwarden.sh`
  eval "$(docopt "$@")"

  checkdeps bw jq socket-credential-cache
  # shellcheck disable=2154
  if $get; then
    creds_get
  elif $store; then
    creds_store
  elif $erase; then
    creds_del
  elif $list; then
    creds_list
  elif $version; then
    printf "docker-credential-bitwarden (github.com/orbit-online/bitwarden-tools) %s\n" \
      "$(jq -re '.version // empty' "$pkgroot/upkg.json" || git symbolic-ref -C "$pkgroot" HEAD)"
  else
    fatal 'Unknown subcommand: "%s"' "$1"
  fi
}

creds_get() {
  local registry item_name
  registry=$(cat)
  registry=${registry%/*}
  item_name="Container Registry - $registry"
  if [[ $(socket-credential-cache get "docker-cred-bw $registry" 2>/dev/null) = 'Not found' ]]; then
    # Cached not found case
    # Do not change these error messages. They are part of the protocol!
    printf "credentials not found in native keychain\n"
    return 1
  fi
  if eval "$("$pkgroot/bitwarden-fields.sh" -e --cache-for=$CACHE_FOR "$item_name" username password 2>/dev/null)"; then
    :
  elif [[ $? -gt 2 ]]; then
    # Not found case (cache not found)
    socket-credential-cache set --timeout $CACHE_FOR "docker-cred-bw $registry" <<<'Not found'
    printf "credentials not found in native keychain\n"
    return 1
  else
    # Login failed case (don't cache)
    printf "credentials not found in in native keychain\n"
    return 1
  fi
  # shellcheck disable=2154
  jq -c --arg serverurl "$registry" --arg username "$username" --arg secret "$password" '.ServerURL=$serverurl | .Username=$username | .Secret=$secret' <<<"{}"
}

creds_store() {
  local details=()
  readarray -t -d$'\n' details <<<"$(jq -re '.ServerURL,.Username,.Secret')"
  local bw_item_id item_name registry=${details[0]} username=${details[1]} secret=${details[2]}
  item_name="Container Registry - $registry"
  if [[ "$username:$secret" = $(socket-credential-cache get "Bitwarden $item_name" 2>/dev/null | jq -r '"\(.login.username):\(.login.password)"') ]]; then
    # docker always stores the creds after fetching them
    return 0
  fi
  unlock_bw "Store credentials for \"$item_name\""
  if bw_item_id="$(bw --nointeraction get item "$item_name" 2>/dev/null | jq -re .id)"; then
    bw --nointeraction --quiet delete item "$bw_item_id"
  fi
  printf '{
    "type": 1,
    "name": "%s",
    "login": {
      "uris": [{"match":null, "uri":"%s"}],
      "username": "%s",
      "password": "%s"
    }
  }' "$item_name" "$registry" "$username" "$secret" | base64 -w0 | bw --nointeraction --quiet create item
  socket-credential-cache clear "Bitwarden $item_name"
  "$pkgroot/bitwarden-cache-items.sh" --cache-for=$CACHE_FOR "$item_name"
}

creds_del() {
  local registry item_name
  registry=$(cat)
  registry=${registry%/*}
  item_name="Container Registry - $registry"
  unlock_bw "Remove credentials for \"$item_name\""
  if bw_item_id="$(bw --nointeraction get item "$item_name" 2>/dev/null | jq -re .id)"; then
    bw --nointeraction --quiet delete item "$bw_item_id"
  fi
  socket-credential-cache clear "Bitwarden $item_name"
}

creds_list() {
  unlock_bw "Retrieve all container registry credentials"
  bw list items --search "Container Registry - " | jq -c '[.[] | {key: .login.uris[0].uri, value: .login.username}] | from_entries'
}

unlock_bw() {
  local purpose=$1
  if [[ -z $BW_SESSION ]]; then
    export BW_SESSION
    BW_SESSION=$("$pkgroot/bitwarden-unlock.sh" --purpose "$purpose")
    # shellcheck disable=2064
    trap "BW_SESSION=\"$BW_SESSION\" bw lock >/dev/null" EXIT
  fi
}

docker_credential_bitwarden "$@"

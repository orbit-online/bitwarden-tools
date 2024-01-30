#!/usr/bin/env bash

CACHE_FOR=$((60 * 60 * 8))
CACHE_NAME=docker-credential-bitwarden

docker_credential_bitwarden() {
  set -eo pipefail; shopt -s inherit_errexit
  local pkgroot; pkgroot=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
  source "$pkgroot/.upkg/orbit-online/records.sh/records.sh"
  source "$pkgroot/common.sh"
  PATH=$("$pkgroot/.upkg/.bin/path_prepend" "$pkgroot/.upkg/.bin")

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
    creds_erase
  elif $list; then
    creds_list
  elif $version; then
    printf "docker-credential-bitwarden (github.com/orbit-online/bitwarden-tools) %s\n" \
      "$(jq -re '.version // empty' "$pkgroot/upkg.json" || git -C "$pkgroot" symbolic-ref HEAD)"
  else
    fatal 'Unknown subcommand: "%s"' "$1"
  fi
}

creds_cache() {
  if ! socket-credential-cache get "$CACHE_NAME" 2>/dev/null; then
    bw_acquire_lock "$CACHE_NAME"
    # Check again, the line above is a race condition
    if ! socket-credential-cache get "$CACHE_NAME" 2>/dev/null; then
      unlock_bw "retrieve all container registry credentials"
      local credentials
      credentials=$(bw --nointeraction list items --search "Container Registry - ")
      socket-credential-cache set --timeout $CACHE_FOR "$CACHE_NAME" <<<"$credentials"
      printf "%s\n" "$credentials"
    fi
  fi
}

creds_get() {
  if ${DOCKER_CREDENTIAL_BITWARDEN_FORCE_ANONYMOUS:-false}; then
    printf "credentials not found in native keychain\n"
    return 1
  fi
  local registry credentials
  registry=$(cat)
  creds_cache | \
    get_registry "$registry" | \
    jq -ce '{ServerURL: .login.uris[0].uri, Username: .login.username, Secret: .login.password} // empty' || \
    {
      printf "credentials not found in native keychain\n"
      return 1
    }
}

creds_store() {
  local details=()
  readarray -t -d$'\n' details <<<"$(jq -re '.ServerURL,.Username,.Secret')"
  local registry=${details[0]} username=${details[1]} secret=${details[2]}
  if [[ "$username:$secret" = $(socket-credential-cache get "$CACHE_NAME" 2>/dev/null | \
    get_registry "$registry" | jq -re '"\(.login.username):\(.login.password)"') ]]; then
    # docker always stores the creds after fetching them
    return 0
  fi
  local item_name credentials bw_item_id
  item_name="Container Registry - $registry"
  unlock_bw "store credentials for \"$item_name\""
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
  socket-credential-cache clear "$CACHE_NAME"
  creds_cache >/dev/null
}

creds_erase() {
  local registry cached
  registry=$(cat)
  # docker logout makes sure to remove all variations of a
  # registry URL (i.e. prefixed with http://, https://, or nothing)
  # but we don't want to password prompt for every call, so check
  # first if the registry in question has already been removed
  if cached=$(socket-credential-cache get "$CACHE_NAME" 2>/dev/null); then
    if ! get_registry "$registry" <<<"$cached"; then
      # credentials don't exist or have already been removed
      return 0
    fi
  fi
  local item_name="Container Registry - $registry"
  unlock_bw "remove credentials for \"$item_name\""
  if bw_item_id="$(bw --nointeraction get item "$item_name" 2>/dev/null | jq -re .id)"; then
    bw --nointeraction --quiet delete item "$bw_item_id"
  fi
  socket-credential-cache clear "$CACHE_NAME"
  creds_cache >/dev/null
}

creds_list() {
  creds_cache | jq -c '[.[] | {key: .login.uris[0].uri, value: .login.username}] | from_entries'
}

get_registry() {
  jq -re --arg registry "$1" 'first(.[] | select(.name == "Container Registry - \($registry)"))'
}

unlock_bw() {
  local purpose=$1
  if [[ -z $BW_SESSION ]]; then
    export BW_SESSION
    BW_SESSION=$("$pkgroot/bitwarden-unlock.sh" --purpose "$purpose")
    # shellcheck disable=2064
    trap "BW_SESSION=\"$BW_SESSION\" bw --nointeraction lock >/dev/null" EXIT
  fi
}

docker_credential_bitwarden "$@"

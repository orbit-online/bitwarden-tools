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
  docker-credential-bitwarden get
  docker-credential-bitwarden store

Note:
  Configure this backing in ~/.docker/config.json with
  {\"credsStore\": \"bitwarden\"}
"
# docopt parser below, refresh this parser with `docopt.sh docker-credential-bitwarden.sh`
# shellcheck disable=2016,1090,1091,2034
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || {
ret=$?; printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e
trimmed_doc=${DOC:0:234}; usage=${DOC:66:76}; digest=c5bc0; shorts=(); longs=()
argcounts=(); node_0(){ _command get; }; node_1(){ _command store; }; node_2(){
required 0; }; node_3(){ required 1; }; node_4(){ either 2 3; }; node_5(){
required 4; }; cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:66:76}" >&2; exit 1; }'; unset var_get var_store
parse 5 "$@"; local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}get" \
"${prefix}store"; eval "${prefix}"'get=${var_get:-false}'
eval "${prefix}"'store=${var_store:-false}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}get" "${prefix}store"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' docker-credential-bitwarden.sh`
  eval "$(docopt "$@")"

  checkdeps bw jq socket-credential-cache
  # shellcheck disable=2154
  if $get; then
    local registry item_name
    registry=$(cat)
    item_name="Container Registry - $registry"
    eval "$("$pkgroot/bitwarden-fields.sh" -e --cache-for=$CACHE_FOR "$item_name" username password 2>/dev/null)"
    jq -c --arg serverurl "$registry" --arg username "$username" --arg secret "$password" '.ServerURL=$serverurl | .Username=$username | .Secret=$secret' <<<"{}"
  elif $store; then
    local details=()
    readarray -t -d$'\n' details <<<"$(jq -re '.ServerURL,.Username,.Secret')"
    local bw_item_id item_name registry=${details[0]} username=${details[1]} secret=${details[2]}
    item_name="Container Registry - $registry"
    if [[ "$username:$secret" = $(socket-credential-cache get "Bitwarden $item_name" 2>/dev/null | jq -r '"\(.login.username):\(.login.password)"') ]]; then
      # docker always stores the creds after fetching them
      return 0
    fi
    if [[ -z $BW_SESSION ]]; then
      export BW_SESSION
      BW_SESSION=$("$pkgroot/bitwarden-unlock.sh" --purpose "Store credentials for \"$item_name\"")
      # shellcheck disable=2064
      trap "BW_SESSION=\"$BW_SESSION\" bw lock >/dev/null" EXIT
    fi
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
  else
    fatal 'Unknown subcommand: "%s"' "$1"
  fi
}

docker_credential_bitwarden "$@"

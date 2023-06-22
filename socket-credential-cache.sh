#!/usr/bin/env bash

socket_credential_cache() {
  set -e
  local pkgroot
  pkgroot=$(upkg root "${BASH_SOURCE[0]}")
  # shellcheck source=.upkg/orbit-online/records.sh/records.sh
  source "$pkgroot/.upkg/orbit-online/records.sh/records.sh"
  # shellcheck source=lib.sh
  source "$pkgroot/lib.sh"

  DOC="socket-credential-cache
Usage:
  socket-cache-credential [options] set [--timeout=S] ITEMNAME
  socket-cache-credential [options] get ITEMNAME
  socket-cache-credential [options] list
  socket-cache-credential [options] clear [ITEMNAME]
  socket-cache-credential [options] serve ITEMNAME

Options:
  --timeout=S  Terminate after S seconds of no activity [default: 900]
  --debug      Turn on bash -x
"
# docopt parser below, refresh this parser with `docopt.sh socket-credential-cache.sh`
# shellcheck disable=2016,1090,1091,2034
docopt() { source "$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh" '1.0.0' || { ret=$?
printf -- "exit %d\n" "$ret"; exit "$ret"; }; set -e; trimmed_doc=${DOC:0:399}
usage=${DOC:24:263}; digest=97de8; shorts=('' ''); longs=(--debug --timeout)
argcounts=(0 1); node_0(){ switch __debug 0; }; node_1(){ value __timeout 1; }
node_2(){ value ITEMNAME a; }; node_3(){ _command set; }; node_4(){ _command get
}; node_5(){ _command list; }; node_6(){ _command clear; }; node_7(){
_command serve; }; node_8(){ optional 0; }; node_9(){ optional 8; }; node_10(){
optional 1; }; node_11(){ required 9 3 10 2; }; node_12(){ required 9 4 2; }
node_13(){ required 9 5; }; node_14(){ optional 2; }; node_15(){ required 9 6 14
}; node_16(){ required 9 7 2; }; node_17(){ either 11 12 13 15 16; }; node_18(){
required 17; }; cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:24:263}" >&2; exit 1; }'; unset var___debug var___timeout \
var_ITEMNAME var_set var_get var_list var_clear var_serve; parse 18 "$@"
local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__debug" \
"${prefix}__timeout" "${prefix}ITEMNAME" "${prefix}set" "${prefix}get" \
"${prefix}list" "${prefix}clear" "${prefix}serve"
eval "${prefix}"'__debug=${var___debug:-false}'
eval "${prefix}"'__timeout=${var___timeout:-900}'
eval "${prefix}"'ITEMNAME=${var_ITEMNAME:-}'
eval "${prefix}"'set=${var_set:-false}'; eval "${prefix}"'get=${var_get:-false}'
eval "${prefix}"'list=${var_list:-false}'
eval "${prefix}"'clear=${var_clear:-false}'
eval "${prefix}"'serve=${var_serve:-false}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}__debug" "${prefix}__timeout" "${prefix}ITEMNAME" \
"${prefix}set" "${prefix}get" "${prefix}list" "${prefix}clear" "${prefix}serve"
done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --library='"$pkgroot/.upkg/andsens/docopt.sh/docopt-lib.sh"' socket-credential-cache.sh`
  eval "$(docopt "$@")"

  # shellcheck disable=2154
  if $__debug; then
    set -x
  fi

  checkdeps socat systemctl
  # shellcheck disable=2154
  local socketspath=$HOME/.cache/credential-sockets unitname socketbasename socketpath socketsetuppath

  socketbasename=${ITEMNAME//[^A-Za-z0-9_]/_}
  socketbasename=${socketbasename/#[^A-Za-z_]/_}
  socketsetuppath=$socketspath/${socketbasename/#[^A-Za-z_]/_}_setup.sock
  socketpath=$socketspath/${socketbasename/#[^A-Za-z_]/_}.sock
  unitname=${ITEMNAME//'@'/'\x64'}
  unitname=${ITEMNAME//'*'/_}
  unitname="socket-credential-cache@$unitname.service"

  if [[ ${#socketsetuppath} -gt 108 ]]; then
    fatal "Unable to cache '%s', the resulting socket path would be greater than 108 characters" "$ITEMNAME"
  fi

  # shellcheck disable=2154
  if $set; then
    mkdir -p "$socketspath"
    if systemctl --user is-active --quiet "$unitname"; then
      fatal "'%s' is already cached" "$ITEMNAME"
    fi
    if ! systemctl --user start --quiet "$unitname"; then
      if ! systemctl --user list-unit-files --plain --no-legend | grep -q socket-credential-cache@.service; then
        fatal "Failed to start unit '%s'\nsocket-credential-cache@.service is not installed (run \`homeshick link')" "$unitname"
      else
        fatal "Failed to start unit '%s'" "$unitname"
      fi
    fi
    if ! waitforsocket "$socketsetuppath"; then
      systemctl --user stop --quiet "$unitname"
      fatal "Timed out waiting for '%s' to become ready" "$socketsetuppath"
    fi
    if ! (printf "%d\n" "$__timeout"; cat) | socat UNIX-CONNECT:"$socketsetuppath" STDIN 2>/dev/null; then
      fatal "Failed to connect to '%s'" "$socketsetuppath"
    fi
    if ! waitforsocket "$socketpath"; then
      systemctl --user stop --quiet "$unitname"
      fatal "Timed out waiting for '%s' to become ready" "$socketpath"
    fi

  elif $get; then
    # When redirecting socat output it fails with "Bad file descriptor", so we pipe it to `cat` instead
    set -o pipefail
    socat -t0 UNIX-CONNECT:"$socketpath" STDOUT | cat

  elif $list; then
    for unitname in $(systemctl --user list-units 'socket-credential-cache@*.service' --plain --no-legend --state=active | cut -d' ' -f1); do
      unitname=${unitname%\.service*}
      unitname=${unitname#socket-credential-cache\@}
      # The var in printf is on purpose, it's an easy way to unescape all the \x escapes
      # shellcheck disable=2059
      printf "$unitname\n"
    done

  elif $clear; then
    if [[ -n $ITEMNAME ]]; then
      systemctl --user stop --quiet "$unitname"
    else
      for unitname in $(systemctl --user list-units 'socket-credential-cache@*.service' --plain --no-legend --state=active | cut -d' ' -f1); do
        systemctl --user stop --quiet "$unitname"
      done
    fi

  elif $serve; then
    # clean up socketpath after e.g. a system crash
    rm -f "$socketsetuppath" "$socketpath"
    systemd-notify --ready
    local DATA
    IFS= read -t 1 -r -d '' DATA < <(socat -t0 UNIX-LISTEN:"$socketsetuppath,unlink-close,umask=177" STDOUT) || true
    [[ -z $DATA ]] && fatal "No data passed to setup socket '%s' or timeout exceeded" "$socketsetuppath"
    local EXTEND_TIMEOUT_USEC=$((${DATA%%$'\n'*} * 1000000))
    systemd-notify "EXTEND_TIMEOUT_USEC=$EXTEND_TIMEOUT_USEC"
    # shellcheck disable=2016,2097,2098
    socketpath=$socketpath EXTEND_TIMEOUT_USEC=$EXTEND_TIMEOUT_USEC SECRET=${DATA#*$'\n'} exec \
      socat UNIX-LISTEN:"$socketpath,unlink-close,fork,umask=177" SYSTEM:'systemd-notify "EXTEND_TIMEOUT_USEC=$EXTEND_TIMEOUT_USEC"; printf -- "%s" \"\$SECRET\"'
  fi
}

waitforsocket() {
  local tries socketpath=$1
  for ((tries=0;tries<5;tries++)); do
    if [[ -S "$socketpath" ]]; then
      return 0
    fi
    sleep .1
  done
  return 1
}

socket_credential_cache "$@"

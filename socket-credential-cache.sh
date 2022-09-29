#!/usr/bin/env bash
set -e

main() {
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
# shellcheck disable=2016,1075
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
return 0; }; either() { local initial_left=("${left[@]}"); local best_match_idx
local match_count; local node_idx; ((testdepth++)) || true
for node_idx in "$@"; do if "node_$node_idx"; then
if [[ -z $match_count || ${#left[@]} -lt $match_count ]]; then
best_match_idx=$node_idx; match_count=${#left[@]}; fi; fi
left=("${initial_left[@]}"); done; ((testdepth--)) || true
if [[ -n $best_match_idx ]]; then "node_$best_match_idx"; return 0; fi
left=("${initial_left[@]}"); return 1; }; optional() { local node_idx
for node_idx in "$@"; do "node_$node_idx"; done; return 0; }; _command() {
local i; local name=${2:-$1}; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = 'a' ]]; then
if [[ ${parsed_values[$l]} != "$name" ]]; then return 1; fi
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; if [[ $3 = true ]]; then
eval "((var_$1++)) || true"; else eval "var_$1=true"; fi; return 0; fi; done
return 1; }; switch() { local i; for i in "${!left[@]}"; do local l=${left[$i]}
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
printf -- "exit %d\n" "$1"; exit "$1"; }; set -e; trimmed_doc=${DOC:0:399}
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
# docopt parser above, complete command for generating this parser is `docopt.sh socket-credential-cache.sh`
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
  unitname="socket-credential-cache@${ITEMNAME//[@*]/_}.service"

  if [[ ${#socketsetuppath} -gt 108 ]]; then
    printf -- "Error: Unable to cache '%s', the resulting socket path would be greater than 108 characters\n" "$ITEMNAME" >&2
    return 1
  fi

  # shellcheck disable=2154
  if $set; then
    mkdir -p "$socketspath"
    if systemctl --user is-active --quiet "$unitname"; then
      fatal "socket-credential-cache.sh: '%s' is already cached\n" "$ITEMNAME"
    fi
    if ! systemctl --user start --quiet "$unitname"; then
      if ! systemctl --user list-unit-files --plain --no-legend | grep -q socket-credential-cache@.service; then
        fatal "socket-credential-cache.sh: Failed to start unit '%s'\nsocket-credential-cache@.service is not installed (run \`homeshick link')" "$unitname"
      else
        fatal "socket-credential-cache.sh: Failed to start unit '%s'" "$unitname"
      fi
    fi
    if ! waitforsocket "$socketsetuppath"; then
      systemctl --user stop --quiet "$unitname"
      fatal "socket-credential-cache.sh: Timed out waiting for '%s' to become ready" "$socketsetuppath"
    fi
    if ! (printf "%d\n" "$__timeout"; cat) | socat UNIX-CONNECT:"$socketsetuppath" STDIN 2>/dev/null; then
      fatal "socket-credential-cache.sh: Failed to connect to '%s'" "$socketsetuppath"
    fi
    if ! waitforsocket "$socketpath"; then
      systemctl --user stop --quiet "$unitname"
      fatal "socket-credential-cache.sh: Timed out waiting for '%s' to become ready" "$socketpath"
    fi

  elif $get; then
    # When redirecting socat output it fails with "Bad file descriptor", so we pipe it to `cat` instead
    set -o pipefail
    socat -t0 UNIX-CONNECT:"$socketpath" STDOUT | cat

  elif $list; then
    for unitname in $(systemctl --user list-units 'socket-credential-cache@*.service' --plain --no-legend --state=active | cut -d' ' -f1); do
      unitname=${unitname%\.service*}
      unitname=${unitname#socket-credential-cache\@}
      unitname=${unitname//'\x20'/ }
      printf "%s\n" "$unitname"
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
    [[ -z $DATA ]] && fatal "socket-credential-cache.sh: No data passed to setup socket '%s' or timeout exceeded" "$socketsetuppath"
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

fatal() {
  # shellcheck disable=2059
  printf -- "$@"
  printf -- "\n"
  exit 1
}

main "$@"

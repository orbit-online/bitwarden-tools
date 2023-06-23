#!/usr/bin/env bash

checkdeps() {
  local deps=("$@") dep out ret=0
  for dep in "${deps[@]}"; do
    if ! out=$(type "$dep" 2>&1); then
      error "Dependency %s not found: %s" "$dep" "$out"
      ret=1
    fi
  done
  return $ret
}

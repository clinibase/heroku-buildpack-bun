#!/usr/bin/env bash

create_signature() {
  echo "v2; ${STACK}; $(bun --version); ${PREBUILD}"
}

save_signature() {
  local cache_dir="$1"
  create_signature > "$cache_dir/bun/signature"
}

load_signature() {
  local cache_dir="$1"
  if test -f "$cache_dir/bun/signature"; then
    cat "$cache_dir/bun/signature"
  else
    echo ""
  fi
}

get_cache_status() {
  local cache_dir="$1"
  if ! ${BUN_CACHE:-true}; then
    echo "disabled"
  elif ! test -d "$cache_dir/bun/"; then
    echo "not-found"
  elif [ "$(create_signature)" != "$(load_signature "$cache_dir")" ]; then
    echo "new-signature"
  else
    echo "valid"
  fi
}

get_cache_directories() {
  local build_dir="$1"
  local dirs1 dirs2
  dirs1=$(read_json "$build_dir/package.json" ".cacheDirectories | .[]?")
  dirs2=$(read_json "$build_dir/package.json" ".cache_directories | .[]?")

  if [ -n "$dirs1" ]; then
    echo "$dirs1"
  else
    echo "$dirs2"
  fi
}

restore_default_cache_directories() {
  local build_dir=${1:-}
  local cache_dir=${2:-}
  local bun_cache_dir=${3:-}

  if [[ -d "$cache_dir/bun/install" ]]; then
    rm -rf "$bun_cache_dir"
    mv "$cache_dir/bun/install" "$bun_cache_dir"
    echo "- bun cache"
  else
    echo "- bun cache (not cached - skipping)"
  fi
}

restore_custom_cache_directories() {
  local cache_directories
  local build_dir=${1:-}
  local cache_dir=${2:-}
  # Parse the input string with multiple lines: "a\nb\nc" into an array
  mapfile -t cache_directories <<< "$3"

  echo "Loading ${#cache_directories[@]} from cacheDirectories (package.json):"

  for cachepath in "${cache_directories[@]}"; do
    if [ -e "$build_dir/$cachepath" ]; then
      echo "- $cachepath (exists - skipping)"
    else
      if [ -e "$cache_dir/bun/cache/$cachepath" ]; then
        echo "- $cachepath"
        mkdir -p "$(dirname "$build_dir/$cachepath")"
        mv "$cache_dir/bun/cache/$cachepath" "$build_dir/$cachepath"
      else
        echo "- $cachepath (not cached - skipping)"
      fi
    fi
  done
}

clear_cache() {
  local cache_dir="$1"
  rm -rf "$cache_dir/bun"
  mkdir -p "$cache_dir/bun"
  mkdir -p "$cache_dir/bun/cache"
}

save_default_cache_directories() {
  local build_dir=${1:-}
  local cache_dir=${2:-}
  local bun_cache_dir=${3:-}

  if [[ -d "$bun_cache_dir" ]]; then
    mv "$bun_cache_dir" "$cache_dir/bun/install"
    echo "- bun cache"
  fi
}

save_custom_cache_directories() {
  local cache_directories
  local build_dir=${1:-}
  local cache_dir=${2:-}
  # Parse the input string with multiple lines: "a\nb\nc" into an array
  mapfile -t cache_directories <<< "$3"

  echo "Saving ${#cache_directories[@]} cacheDirectories (package.json):"

  for cachepath in "${cache_directories[@]}"; do
    if [ -e "$build_dir/$cachepath" ]; then
      echo "- $cachepath"
      mkdir -p "$cache_dir/bun/cache/$cachepath"
      cp -a "$build_dir/$cachepath" "$(dirname "$cache_dir/bun/cache/$cachepath")"
    else
      echo "- $cachepath (nothing to cache)"
    fi
  done
}

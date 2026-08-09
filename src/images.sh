#!/bin/bash

# Image access layer: list images as JSON, look one up, and act on it.

. src/containers.sh

# Print all images as a JSON array. Prints "[]" when the daemon is up with no
# images. Fails (no output) when docker is missing or the daemon is down.
list_images_json() {
  local bin raw
  bin="$(docker_bin)" || return 1
  raw="$("$bin" images --format '{{json .}}' 2>/dev/null)" || return 1
  [[ -n "$raw" ]] || { printf '[]'; return 0; }
  printf '%s' "$raw" | jq -s '.' 2>/dev/null
  return 0
}

# Print one image object (compact JSON) whose ID starts with the argument.
image_by_id() {
  local id="$1" json
  json="$(list_images_json)" || return 0
  printf '%s' "$json" | jq -c --arg id "$id" 'map(select(.ID|startswith($id)))[0] // empty' 2>/dev/null
  return 0
}

# Remove an image by reference (repo:tag or id), force.
image_remove() {
  local ref="$1" bin
  bin="$(docker_bin)" || return 0
  "$bin" rmi -f "$ref" >/dev/null 2>&1
  return 0
}

# Write "docker inspect" JSON for an image to a temp file and open it.
inspect_image() {
  local ref="$1" bin safe tmp
  bin="$(docker_bin)" || return 0
  safe="$(printf '%s' "$ref" | tr -c 'A-Za-z0-9._-' '-')"
  tmp="${alfred_workflow_cache:-/tmp}/image-$safe.json"
  mkdir -p "$(dirname "$tmp")"
  "$bin" inspect "$ref" > "$tmp" 2>/dev/null
  open -e "$tmp"
  return 0
}

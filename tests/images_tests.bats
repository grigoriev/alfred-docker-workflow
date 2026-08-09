#!/usr/bin/env bats

# Integration tests for the image views and actions in src/docker.sh.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$alfred_workflow_data" "$alfred_workflow_cache"
  export DOCKER_BIN="$BATS_TEST_DIRNAME/mocks/bin/docker"
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  export OSASCRIPT_LOG="$BATS_TEST_TMPDIR/osa.log"
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
  export PBCOPY_LOG="$BATS_TEST_TMPDIR/pb.log"
}

# --- image list ------------------------------------------------------------

@test "images: docker images lists images, dangling last, then switch" {
  run bash -c '. src/docker.sh list "images"'
  echo "$output" | jq -e '[.items[].title] == ["nginx:latest", "postgres:16", "<none>:<none>", "Containers →"]' >/dev/null
}

@test "images: img is a shorthand for the image view" {
  run bash -c '. src/docker.sh list "img"'
  echo "$output" | jq -e '.items[0].title == "nginx:latest"' >/dev/null
}

@test "images: filters images by repository" {
  run bash -c '. src/docker.sh list "images postgres"'
  echo "$output" | jq -e '[.items[].title] == ["postgres:16", "Containers →"]' >/dev/null
}

@test "images: an image drills into its menu with remove/pull mods" {
  run bash -c '. src/docker.sh list "images"'
  echo "$output" | jq -e '.items[0].arg == "img-menu img111"' >/dev/null
  echo "$output" | jq -e '.items[0].autocomplete == "#img111 "' >/dev/null
  echo "$output" | jq -e '.items[0].mods.cmd.arg == "img-remove nginx:latest"' >/dev/null
  echo "$output" | jq -e '.items[0].mods.alt.arg == "img-pull nginx:latest"' >/dev/null
}

@test "images: a dangling image uses its id and cannot be pulled" {
  run bash -c '. src/docker.sh list "images"'
  echo "$output" | jq -e '.items[2].mods.cmd.arg == "img-remove img333"' >/dev/null
  echo "$output" | jq -e '.items[2].mods.alt.valid == false' >/dev/null
}

@test "images: the containers switch is last and routes back" {
  run bash -c '. src/docker.sh list "images"'
  echo "$output" | jq -e '.items[-1].title == "Containers →" and .items[-1].arg == "view-containers"' >/dev/null
}

@test "images: no match yields an empty-state and the switch" {
  run bash -c '. src/docker.sh list "images nomatch"'
  echo "$output" | jq -e '.items[0].title == "No images"' >/dev/null
  echo "$output" | jq -e '.items[-1].title == "Containers →"' >/dev/null
}

@test "images: a stopped daemon is reported in the image view" {
  DOCKER_DOWN=1 run bash -c '. src/docker.sh list "images"'
  echo "$output" | jq -e '.items[0].title == "Docker is not running"' >/dev/null
}

# --- image menu ------------------------------------------------------------

@test "images: a tagged image menu lists run, pull, copy, inspect, remove" {
  run bash -c '. src/docker.sh list "#img111 "'
  echo "$output" | jq -e '[.items[].title] | index("Run") != null and index("Pull / update") != null and index("Copy repo:tag") != null and index("Copy image id") != null and index("Inspect") != null and index("Remove") != null' >/dev/null
}

@test "images: a dangling image menu omits pull and copy repo:tag" {
  run bash -c '. src/docker.sh list "#img333 "'
  echo "$output" | jq -e '[.items[].title] | index("Run") != null and index("Copy image id") != null and index("Remove") != null and index("Pull / update") == null and index("Copy repo:tag") == null' >/dev/null
}

@test "images: menu filters its actions by a substring" {
  run bash -c '. src/docker.sh list "#img111 remo"'
  echo "$output" | jq -e '[.items[].title] == ["Remove"]' >/dev/null
}

@test "images: an unknown image id reports not found" {
  run bash -c '. src/docker.sh list "#zzz "'
  echo "$output" | jq -e '.items[0].title == "Image not found"' >/dev/null
}

# --- run mode --------------------------------------------------------------

@test "images: view-images and view-containers switch the view" {
  bash -c '. src/docker.sh run "view-images"'
  grep -q 'docker images' "$OSASCRIPT_LOG"
  : > "$OSASCRIPT_LOG"
  bash -c '. src/docker.sh run "view-containers"'
  grep -qE 'docker ?$' "$OSASCRIPT_LOG"
}

@test "images: img-menu reopens Alfred at the image" {
  run bash -c '. src/docker.sh run "img-menu img111"'
  grep -q 'docker #img111' "$OSASCRIPT_LOG"
}

@test "images: run launches docker run in iTerm" {
  run bash -c '. src/docker.sh run "img-run nginx:latest"'
  grep -q 'run --rm -it nginx:latest' "$OSASCRIPT_LOG"
}

@test "images: pull launches docker pull in iTerm" {
  run bash -c '. src/docker.sh run "img-pull nginx:latest"'
  grep -q 'pull nginx:latest' "$OSASCRIPT_LOG"
}

@test "images: inspect writes json and opens it" {
  run bash -c '. src/docker.sh run "img-inspect nginx:latest"'
  grep -q 'inspect nginx:latest' "$DOCKER_LOG"
  grep -q 'image-nginx-latest.json' "$OPEN_LOG"
}

@test "images: remove runs docker rmi -f and refreshes" {
  run bash -c '. src/docker.sh run "img-remove nginx:latest"'
  grep -q 'rmi -f nginx:latest' "$DOCKER_LOG"
  grep -q 'docker images' "$OSASCRIPT_LOG"
}

@test "images: copy ref and copy id write the clipboard" {
  bash -c '. src/docker.sh run "img-copy-ref nginx:latest"'
  [ "$(cat "$PBCOPY_LOG")" = "nginx:latest" ]
  bash -c '. src/docker.sh run "img-copy-id img111"'
  [ "$(cat "$PBCOPY_LOG")" = "img111" ]
}

# --- unit ------------------------------------------------------------------

@test "images.sh: list_images_json returns an array" {
  run bash -c '. src/images.sh; list_images_json'
  echo "$output" | jq -e 'type == "array" and length == 3' >/dev/null
}

@test "images.sh: image_by_id finds an image by id prefix" {
  run bash -c '. src/images.sh; image_by_id img2'
  echo "$output" | jq -e '.Repository == "postgres"' >/dev/null
}

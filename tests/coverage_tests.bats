#!/usr/bin/env bats

# Coverage tests for the less-trodden paths: binary fallback, iterm id reads,
# prune default, the image filter view, the update routes, and run fall-throughs.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$alfred_workflow_data" "$alfred_workflow_cache"
  export DOCKER_BIN="$BATS_TEST_DIRNAME/mocks/bin/docker"
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  export OSASCRIPT_LOG="$BATS_TEST_TMPDIR/osa.log"
  export OPEN_LOG="$BATS_TEST_TMPDIR/open.log"
}

@test "containers.sh: docker_bin falls back to a docker on PATH" {
  run bash -c 'unset DOCKER_BIN; . src/containers.sh; docker_bin'
  [ "$status" -eq 0 ]
  [[ "$output" == *"/mocks/bin/docker" ]]
}

@test "containers.sh: iterm_session_id reads a stored id" {
  printf '{"m1":"SID-1"}' > "$alfred_workflow_data/iterm.json"
  run bash -c '. src/containers.sh; iterm_session_id m1'
  [ "$output" = "SID-1" ]
}

@test "containers.sh: docker_prune ignores an unknown target" {
  run bash -c '. src/containers.sh; docker_prune bogus; echo rc=$?'
  [[ "$output" == *"rc=0"* ]]
}

@test "docker.sh: img with a filter lists matching images" {
  run bash -c '. src/docker.sh list "img postgres"'
  echo "$output" | jq -e '.items[0].title == "postgres:16"' >/dev/null
}

@test "docker.sh: > update runs the fetched updater" {
  run bash -c '. src/docker.sh list "> update"'
  echo "$output" | jq -e 'has("items")' >/dev/null
}

@test "docker.sh: > update reports a missing updater bundle" {
  cp src/update.sh "$BATS_TEST_TMPDIR/u.bak"
  rm -f src/update.sh
  run bash -c '. src/docker.sh list "> update"'
  cp "$BATS_TEST_TMPDIR/u.bak" src/update.sh
  echo "$output" | jq -e '.items[0].title == "Updater unavailable"' >/dev/null
}

@test "docker.sh: run with a download url routes to the installer" {
  run bash -c '. src/docker.sh run "https://example.com/Docker.alfredworkflow"'
  [ "$status" -eq 0 ]
}

@test "docker.sh: run ignores an unknown action" {
  run bash -c '. src/docker.sh run "bogus payload"'
  [ "$status" -eq 0 ]
}

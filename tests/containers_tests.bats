#!/usr/bin/env bats

# Unit tests for src/containers.sh: binary resolution, listing, and lookup.

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$alfred_workflow_data" "$alfred_workflow_cache"
  export DOCKER_BIN="$BATS_TEST_DIRNAME/mocks/bin/docker"
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  . src/containers.sh
}

@test "containers.sh: docker_bin honors the DOCKER_BIN hook" {
  run docker_bin
  [ "$status" -eq 0 ]
  [ "$output" = "$DOCKER_BIN" ]
}

@test "containers.sh: docker_bin fails when the hook points nowhere" {
  DOCKER_BIN="/nope/docker" run docker_bin
  [ "$status" -eq 1 ]
}

@test "containers.sh: a path override is used when no hook is set" {
  local mock="$BATS_TEST_DIRNAME/mocks/bin/docker"
  printf '%s\n' "$mock" > "$alfred_workflow_data/docker-path"
  unset DOCKER_BIN
  run docker_bin
  [ "$status" -eq 0 ]
  [ "$output" = "$mock" ]
}

@test "containers.sh: path_config_value ignores comments and blanks" {
  printf '# a comment\n\n/usr/local/bin/docker\n' > "$alfred_workflow_data/docker-path"
  run path_config_value
  [ "$output" = "/usr/local/bin/docker" ]
}

@test "containers.sh: list_containers_json returns an array" {
  run bash -c '. src/containers.sh; list_containers_json'
  echo "$output" | jq -e 'type == "array" and length == 2' >/dev/null
}

@test "containers.sh: list_containers_json is empty when there are no containers" {
  local fixture="$BATS_TEST_TMPDIR/empty"
  : > "$fixture"
  DOCKER_PS_FIXTURE="$fixture" run bash -c '. src/containers.sh; list_containers_json'
  [ "$output" = "[]" ]
}

@test "containers.sh: list_containers_json fails when the daemon is down" {
  DOCKER_DOWN=1 run bash -c '. src/containers.sh; list_containers_json'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "containers.sh: container_by_id finds a container by id prefix" {
  run bash -c '. src/containers.sh; container_by_id aaaa'
  echo "$output" | jq -e '.Names == "web"' >/dev/null
}

@test "containers.sh: container_by_id yields nothing for an unknown id" {
  run bash -c '. src/containers.sh; container_by_id zzzz'
  [ -z "$output" ]
}

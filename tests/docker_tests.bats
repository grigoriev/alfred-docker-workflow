#!/usr/bin/env bats

# Integration tests for src/docker.sh. docker, osascript and open are mocked.

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

# --- list mode -------------------------------------------------------------

@test "docker.sh: lists containers, running first" {
  run bash -c '. src/docker.sh list ""'
  echo "$output" | jq -e '[.items[].title] == ["web", "db"]' >/dev/null
}

@test "docker.sh: subtitle carries image, status and ports" {
  run bash -c '. src/docker.sh list ""'
  echo "$output" | jq -e '.items[0].subtitle | contains("nginx:latest") and contains("Up 3 minutes") and contains("8080")' >/dev/null
}

@test "docker.sh: filters by a word across name, image and status" {
  run bash -c '. src/docker.sh list "postgres"'
  echo "$output" | jq -e '[.items[].title] == ["db"]' >/dev/null
}

@test "docker.sh: a container drills into its menu and offers stop/logs mods" {
  run bash -c '. src/docker.sh list ""'
  echo "$output" | jq -e '.items[0].arg == "menu aaaa111"' >/dev/null
  echo "$output" | jq -e '.items[0].autocomplete == "@aaaa111 "' >/dev/null
  echo "$output" | jq -e '.items[0].mods.cmd.arg == "stop aaaa111"' >/dev/null
  echo "$output" | jq -e '.items[0].mods.alt.arg == "logs aaaa111"' >/dev/null
}

@test "docker.sh: a stopped container offers a start mod" {
  run bash -c '. src/docker.sh list ""'
  echo "$output" | jq -e '.items[1].mods.cmd.arg == "start bbbb222"' >/dev/null
}

@test "docker.sh: no match yields an empty-state item" {
  run bash -c '. src/docker.sh list "nomatch"'
  echo "$output" | jq -e '.items[0].title == "No containers"' >/dev/null
}

# --- action menu -----------------------------------------------------------

@test "docker.sh: running container menu lists actions and ports" {
  run bash -c '. src/docker.sh list "@aaaa111 "'
  echo "$output" | jq -e '[.items[].title] | index("Shell") != null and index("Logs") != null and index("Restart") != null and index("Stop") != null and index("Open port 8080") != null and index("Inspect") != null and index("Remove") != null' >/dev/null
}

@test "docker.sh: stopped container menu offers start, not shell or stop" {
  run bash -c '. src/docker.sh list "@bbbb222 "'
  echo "$output" | jq -e '[.items[].title] | index("Start") != null and index("Logs") != null and index("Shell") == null and index("Stop") == null' >/dev/null
}

@test "docker.sh: menu filters its actions by a substring" {
  run bash -c '. src/docker.sh list "@aaaa111 rem"'
  echo "$output" | jq -e '[.items[].title] == ["Remove"]' >/dev/null
}

@test "docker.sh: an unknown container id reports not found" {
  run bash -c '. src/docker.sh list "@zzz "'
  echo "$output" | jq -e '.items[0].title == "Container not found"' >/dev/null
}

# --- globals ---------------------------------------------------------------

@test "docker.sh: > lists prune, docker path and update commands" {
  run bash -c '. src/docker.sh list ">"'
  echo "$output" | jq -e '[.items[].title] | index("Prune stopped containers") != null and index("Prune dangling images") != null and index("System prune") != null and index("Set docker binary path") != null and index("Check for updates") != null' >/dev/null
}

# --- daemon and binary state ----------------------------------------------

@test "docker.sh: reports a stopped daemon" {
  DOCKER_DOWN=1 run bash -c '. src/docker.sh list ""'
  echo "$output" | jq -e '.items[0].title == "Docker is not running"' >/dev/null
}

@test "docker.sh: reports a missing binary" {
  DOCKER_BIN="/nonexistent/docker" run bash -c '. src/docker.sh list ""'
  echo "$output" | jq -e '.items[0].title == "Docker not found"' >/dev/null
}

# --- run mode --------------------------------------------------------------

@test "docker.sh: menu run reopens Alfred at the container" {
  run bash -c '. src/docker.sh run "menu aaaa111"'
  grep -q 'docker @aaaa111' "$OSASCRIPT_LOG"
}

@test "docker.sh: stop runs docker stop and refreshes" {
  run bash -c '. src/docker.sh run "stop aaaa111"'
  grep -q 'stop aaaa111' "$DOCKER_LOG"
  grep -q 'docker ' "$OSASCRIPT_LOG"
}

@test "docker.sh: start runs docker start" {
  run bash -c '. src/docker.sh run "start bbbb222"'
  grep -q 'start bbbb222' "$DOCKER_LOG"
}

@test "docker.sh: restart runs docker restart" {
  run bash -c '. src/docker.sh run "restart aaaa111"'
  grep -q 'restart aaaa111' "$DOCKER_LOG"
}

@test "docker.sh: remove runs docker rm -f" {
  run bash -c '. src/docker.sh run "remove aaaa111"'
  grep -q 'rm -f aaaa111' "$DOCKER_LOG"
}

@test "docker.sh: shell opens an exec session in iTerm and stores it" {
  run bash -c '. src/docker.sh run "shell aaaa111"'
  grep -q 'exec -it aaaa111' "$OSASCRIPT_LOG"
  jq -e '."docker-shell-aaaa111" == "MOCKSESSION"' < "$alfred_workflow_data/iterm.json" >/dev/null
}

@test "docker.sh: logs tails in iTerm" {
  run bash -c '. src/docker.sh run "logs aaaa111"'
  grep -q 'logs -f --tail 200 aaaa111' "$OSASCRIPT_LOG"
}

@test "docker.sh: inspect writes json and opens it" {
  run bash -c '. src/docker.sh run "inspect aaaa111"'
  grep -q 'inspect aaaa111' "$DOCKER_LOG"
  grep -q 'inspect-aaaa111.json' "$OPEN_LOG"
}

@test "docker.sh: open-port opens localhost in the browser" {
  run bash -c '. src/docker.sh run "open-port 8080"'
  grep -q 'http://localhost:8080' "$OPEN_LOG"
}

@test "docker.sh: system prune runs and refreshes the menu" {
  run bash -c '. src/docker.sh run "prune-system"'
  grep -q 'system prune -f' "$DOCKER_LOG"
  grep -q 'docker >' "$OSASCRIPT_LOG"
}

@test "docker.sh: prune-containers and prune-images run" {
  bash -c '. src/docker.sh run "prune-containers"'
  bash -c '. src/docker.sh run "prune-images"'
  grep -q 'container prune -f' "$DOCKER_LOG"
  grep -q 'image prune -f' "$DOCKER_LOG"
}

@test "docker.sh: set-path opens the config file" {
  run bash -c '. src/docker.sh run "set-path"'
  grep -q 'docker-path' "$OPEN_LOG"
  [ -f "$alfred_workflow_data/docker-path" ]
}

@test "docker.sh: autoupdate on writes the flag" {
  run bash -c '. src/docker.sh run "autoupdate on"'
  [ -f "$alfred_workflow_data/autoupdate" ]
}

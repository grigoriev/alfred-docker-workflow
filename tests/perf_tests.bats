#!/usr/bin/env bats

# Performance guard for the Script Filter. Times the container list render over
# a large fixture and fails only on an order-of-magnitude regression. Times with
# jq's `now` (BSD `date` has no %N).

BUDGET_MS=2000
N=300

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks/bin:$PATH"
  export alfred_workflow_data="$BATS_TEST_TMPDIR/data"
  export alfred_workflow_cache="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$alfred_workflow_data" "$alfred_workflow_cache"
  export DOCKER_BIN="$BATS_TEST_DIRNAME/mocks/bin/docker"
  export DOCKER_LOG="/dev/null"
  local fixture="$BATS_TEST_TMPDIR/many.json" i state
  : > "$fixture"
  for i in $(seq 1 "$N"); do
    state=$([ $(( i % 2 )) -eq 0 ] && echo running || echo exited)
    printf '{"ID":"id%04d","Names":"svc%d","Image":"img:%d","State":"%s","Status":"Up %dm","Ports":""}\n' \
      "$i" "$i" "$i" "$state" "$i" >> "$fixture"
  done
  export DOCKER_PS_FIXTURE="$fixture"
}

now_ms() { jq -n 'now * 1000 | floor'; }

@test "perf: container list over many containers stays fast" {
  local start end ms
  start="$(now_ms)"
  run bash -c '. src/docker.sh list "svc"'
  end="$(now_ms)"
  ms=$(( end - start ))
  [ "$status" -eq 0 ]
  echo "# docker list ($N containers): ${ms}ms (budget ${BUDGET_MS}ms)" >&3
  [ "$ms" -lt "$BUDGET_MS" ]
}

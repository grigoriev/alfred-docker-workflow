# CLAUDE.md

Alfred workflow that lists Docker containers and images and acts on them.
Container actions: shell, logs, restart, stop, start, open a port, inspect, remove. Image actions: run, pull, copy, inspect, remove.
Keyword: `docker`. Artifact: `Docker.alfredworkflow`.

## Layout

- `src/docker.sh` - the entry point. It takes `mode` (`list` for the Script Filter, `run` for the Run Script) and `query`.
- `src/containers.sh` - `docker_bin` lookup, container listing and actions, iTerm2 session reuse.
- `src/images.sh` - image listing and actions.
- `src/cache.sh` - the cache under `$alfred_workflow_cache`.
- `src/globals.sh` - the `docker >` settings menu (`globals_menu`): prune, docker binary path, updates.
- `src/list-containers.jq`, `src/list-images.jq` - extracted jq programs.
- `src/workflow_handler.sh` - shared JSON feedback helpers, identical in all sibling workflows.
- `src/media.sh` - icon paths. `icons/` holds the PNGs, built from Octicons.
- `src/update.sh`, `src/autoupdate.sh` - fetched at build time from `alfred-workflow-updater`. Gitignored, never committed.
- `info.plist` - Alfred objects, the hotkey trigger and the workflow `version`.
- `tests/*.bats`, including `tests/coverage_tests.bats` for rare paths and `tests/perf_tests.bats`.
- `tests/mocks/bin/` - fake `docker`, `open`, `osascript` and `pbcopy`.

## Commands

```sh
make lint       # ShellCheck docker, containers, images, cache, globals in Docker
make test       # fetch the updater, then run bats tests (macOS)
make coverage   # bats under kcov in Docker, writes sonar-coverage.xml
make build      # fetch the updater, smoke-test it, zip Docker.alfredworkflow
make icons      # regenerate PNG icons from Octicons (macOS)
make clean      # remove the artifact, fetched updater and coverage
```

1. Install tools with `brew install bats-core jq`.
2. `make lint SHELLCHECK=shellcheck` uses a local ShellCheck instead of Docker.
3. `make test` needs network access, because it fetches the updater bundle first.
4. The `DOCKER_BIN` env var pins the docker binary in tests.

## Constraints and conventions

- Scripts run under stock macOS `/bin/bash` 3.2.
- No bash 4+ features: no `mapfile`, `readarray`, `declare -A`, `${var,,}` or `${var^^}`.
- Check a construct with `/bin/bash -c '...'`. zsh and Homebrew bash 5 hide 3.2 gaps.
- No perl. Use `awk`, `sed`, `jq` or bash.
- Alfred runs with a minimal `PATH`. Resolve docker through `docker_bin`, never a bare `docker`.
- Build Script Filter JSON with `add_result` and `get_json_results`, never by hand.
- Render the list with one `jq` pass over `docker ps` or `docker images` JSON.
- Put multi-line jq or awk programs in `src/*.jq` or `src/*.awk` and call them with `-f`.
- Shell and Logs reuse an iTerm2 session by its stored `id`. Compile-check AppleScript with `osacompile -o /dev/null -`.
- Alfred clears an imported hotkey. Keep the hotkey object wired and document the manual setup.
- Settings and updates live behind the `docker >` menu. `globals_menu` calls the shared `autoupdate_menu`.
- Update logic lives only in `alfred-workflow-updater`. Never reimplement it here.
- SonarCloud shell rules: `[[ ]]` not `[ ]`, positional params into named lowercase `local`s, snake_case functions, explicit `return` at function end, a `*)` default in every `case`, HTTPS for `curl`.

## Review focus

Flag these in a pull request:

- Any bash 4+ feature, or any perl call.
- A new or changed function without a bats test. A bug fix without a test that fails before the fix.
- Unquoted variable expansions, especially container names, ids, image tags and ports.
- Container or image names interpolated into `osascript` or a shell command without quoting.
- A bare `docker` call instead of `"$(docker_bin)"`.
- A destructive action (remove, prune) reachable without a deliberate selection.
- `jq`, `docker` or a subshell spawned inside a per-container loop.
- A multi-line jq or awk program embedded in `$(...)` instead of a `src/*.jq` or `src/*.awk` file.
- Hand-built JSON strings instead of `add_result` and `json_encode`.
- A test that runs the real Docker CLI or iTerm2 instead of a mock.
- A violation of the Sonar shell rules listed above.
- A new `src/*.sh` script that the `SCRIPTS` list in the Makefile does not lint.
- Update or autoupdate logic added here, or a committed `src/update.sh` or `src/autoupdate.sh`.
- A change to `.github/workflows/ci.yml`, `release.yml` or `bump-version.yml` in this repo only. These are byte-identical across all 8 Alfred repos.
- A user-facing change without an entry under `## [Unreleased]` in `CHANGELOG.md`.
- A behavior change without a README update.

Commit, branch and pull request rules are in `CONTRIBUTING.md`.

## CI and release

- `ci.yml`: ShellCheck, actionlint and zizmor on Ubuntu, bats on `macos-latest`, the build, and a SonarCloud scan with kcov coverage.
- The version lives in `info.plist`. `make print-version` and `make set-version VERSION=x.y.z` read and write it.
- A maintainer runs **Bump Version & Release**. It cuts the `CHANGELOG.md` section and tags `v*`.
- `release.yml` builds with `CHECK_PROVENANCE=1`, attests the artifact, and publishes an immutable release.

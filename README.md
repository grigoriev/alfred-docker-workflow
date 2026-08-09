# Alfred Docker Workflow

![CI](https://github.com/grigoriev/alfred-docker-workflow/actions/workflows/ci.yml/badge.svg)
[![Release](https://img.shields.io/github/v/release/grigoriev/alfred-docker-workflow)](https://github.com/grigoriev/alfred-docker-workflow/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=grigoriev_alfred-docker-workflow&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=grigoriev_alfred-docker-workflow)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=grigoriev_alfred-docker-workflow&metric=coverage)](https://sonarcloud.io/summary/new_code?id=grigoriev_alfred-docker-workflow)

List your Docker containers in Alfred and act on them: open a shell, tail logs,
restart, stop, start, inspect, open a published port, or remove.

## Usage

Type `docker` to list all containers. Running ones sort first, with a green
icon; stopped ones follow. The subtitle shows the image, status, and published
ports. Type to filter by name, image, id, or status.

- <kbd>Enter</kbd> on a container opens its **action menu**.
- <kbd>⌘</kbd> stops a running container, or starts a stopped one.
- <kbd>⌥</kbd> tails the container's logs in iTerm2.

### Action menu

Enter on a container drills into its actions (filter them by typing):

- **Shell** - open a shell inside a running container in iTerm2 (prefers `bash`,
  falls back to `sh`).
- **Logs** - tail `docker logs -f` in iTerm2.
- **Restart**, **Stop** / **Start**.
- **Open port `N`** - open `http://localhost:N` for each published port.
- **Inspect** - open the `docker inspect` JSON in a text editor.
- **Remove** - remove the container (force).

Shell and Logs reuse an iTerm2 session: launching the same one again focuses the
existing window instead of stacking new ones.

## Settings

Type `docker >` for settings and updates:

- **Prune stopped containers** (`docker container prune -f`).
- **Prune dangling images** (`docker image prune -f`).
- **System prune** (`docker system prune -f`).
- **Set docker binary path** - Alfred runs with a minimal `PATH`. The workflow
  finds docker in the usual Docker Desktop, Homebrew, and Colima locations; set
  an explicit path here if yours is elsewhere.
- **Check for updates** and the autoupdate toggle.

## Hotkey

The workflow ships a hotkey trigger wired to the list, suggesting
<kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>D</kbd>. Alfred clears an imported
workflow's hotkey on install, on purpose, so it cannot clash with your existing
hotkeys. So assign a combo once: double-click the Hotkey object in the workflow
editor and press your keys.

## Requirements

- Docker CLI (Docker Desktop, Colima, or similar).
- iTerm2, for the Shell and Logs actions.
- Alfred 5 with the Powerpack.

## Development

```sh
make lint    # shellcheck
make test    # bats (docker, osascript and open are mocked)
make build   # produce Docker.alfredworkflow
make icons   # regenerate PNG icons from Octicons (macOS)
```

Bash 3.2 compatible (stock macOS `/bin/bash`). The Script Filter renders with a
single `jq` pass over `docker ps` JSON.

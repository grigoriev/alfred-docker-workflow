#!/bin/bash

. src/workflow_handler.sh
. src/media.sh
. src/containers.sh
. src/images.sh
. src/globals.sh

# Single entry point behind the "docker" keyword. Called two ways from Alfred:
#   list mode (Script Filter): . src/docker.sh list "{query}"
#   run mode  (Run Script):    . src/docker.sh run  "{query}"
#
# Query grammar:
#   docker <query>     -> filter containers by name, image, id, or status
#   docker @<id> <f>   -> the action menu for one container
#   docker >           -> global commands (prune, docker path, update)
#
# On a container, Enter opens its action menu, the cmd modifier stops or starts
# it, and the alt modifier tails its logs.

mode="$1"
query="$2"

# Reopen Alfred on a query so the list refreshes in place after an action.
alfred_search() {
  local text="$1"
  osascript - "$text" <<'APPLESCRIPT'
on run argv
  tell application id "com.runningwithcrayons.Alfred" to search (item 1 of argv)
end run
APPLESCRIPT
  return 0
}

# Open a command in iTerm2, or focus the session already opened for the same
# marker. The session id is stored so the next launch can find and select it.
run_iterm_cmd() {
  local cmd="$1" marker="$2" savedid newid
  savedid="$(iterm_session_id "$marker")"
  newid="$(osascript - "$cmd" "$savedid" <<'APPLESCRIPT'
on run argv
  set theCmd to item 1 of argv
  set savedId to item 2 of argv
  tell application "iTerm"
    activate
    if savedId is not "" then
      repeat with w in windows
        repeat with t in tabs of w
          repeat with s in sessions of t
            if (id of s) is savedId then
              select w
              tell t to select
              return ""
            end if
          end repeat
        end repeat
      end repeat
    end if
    set newWin to (create window with default profile)
    set theSession to (current session of newWin)
    tell theSession to write text theCmd
    return (id of theSession)
  end tell
end run
APPLESCRIPT
)"
  [[ -n "$newid" ]] && iterm_set_session_id "$marker" "$newid"
  return 0
}

# Open an interactive shell in a running container, preferring bash over sh.
shell_command() {
  local id="$1" bin
  bin="$(docker_bin)" || return 0
  printf "%s exec -it %s sh -c 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'" "$bin" "$id"
  return 0
}

# Tail a container's logs.
logs_command() {
  local id="$1" bin
  bin="$(docker_bin)" || return 0
  printf '%s logs -f --tail 200 %s' "$bin" "$id"
  return 0
}

# Queue an action-menu item when its token contains the filter.
menu_item() {
  local token="$1" filter="$2" title="$3" subtitle="$4" arg="$5" icon="$6"
  case "$(docker_lower "$token")" in
    *"$(docker_lower "$filter")"*) add_result "" "$arg" "$title" "$subtitle" "$icon" "yes" ;;
    *) : ;;
  esac
  return 0
}

# The action menu for one container, filtered by a substring.
render_menu() {
  local cid="$1" filter="$2" obj state name ports hp
  obj="$(container_by_id "$cid")"
  if [[ -z "$obj" ]]; then
    add_result "" "" "Container not found" "It may have been removed" "$ICON_STOPPED" "no"
    get_json_results
    return 0
  fi
  state="$(printf '%s' "$obj" | jq -r '.State // ""')"
  name="$(printf '%s' "$obj" | jq -r '(.Names // "") | split(",")[0]')"
  ports="$(printf '%s' "$obj" | jq -r '.Ports // ""')"
  if [[ "$state" == "running" ]]; then
    menu_item "shell"   "$filter" "Shell"   "Open a shell in iTerm2 ($name)" "shell $cid"   "$ICON_TERMINAL"
    menu_item "logs"    "$filter" "Logs"    "Tail the logs in iTerm2"        "logs $cid"    "$ICON_LOGS"
    menu_item "restart" "$filter" "Restart" "Restart the container"          "restart $cid" "$ICON_RESTART"
    menu_item "stop"    "$filter" "Stop"    "Stop the container"             "stop $cid"    "$ICON_STOP"
    for hp in $(printf '%s' "$ports" | grep -oE ':[0-9]+->' | sed -E 's/[^0-9]//g' | sort -un); do
      menu_item "open port $hp" "$filter" "Open port $hp" "http://localhost:$hp" "open-port $hp" "$ICON_PORT"
    done
  else
    menu_item "logs"  "$filter" "Logs"  "Tail the logs in iTerm2" "logs $cid"  "$ICON_LOGS"
    menu_item "start" "$filter" "Start" "Start the container"     "start $cid" "$ICON_START"
  fi
  menu_item "inspect" "$filter" "Inspect" "Open the docker inspect JSON"  "inspect $cid" "$ICON_INSPECT"
  menu_item "remove"  "$filter" "Remove"  "Remove the container (force)"  "remove $cid"  "$ICON_TRASH"
  get_json_results
  return 0
}

# Queue the right message when docker is unavailable: a stopped daemon (the
# binary resolves) or a missing binary.
no_docker_item() {
  if docker_bin >/dev/null 2>&1; then
    add_result "" "" "Docker is not running" "Start Docker and try again" "$ICON_STOPPED" "no"
  else
    add_result "" "set-path" "Docker not found" "Type docker > to set the binary path" "$ICON_GEAR" "no"
  fi
  get_json_results
  return 0
}

# Print an items array with any queued banner first and a trailing view-switch
# item last. $1 items json, $2 title, $3 subtitle, $4 arg, $5 autocomplete, $6 icon.
emit_with_switch() {
  local items="$1" title="$2" subtitle="$3" arg="$4" auto="$5" icon="$6" sw
  sw="$(jq -cn --arg t "$title" --arg s "$subtitle" --arg a "$arg" --arg ac "$auto" --arg icon "$icon" \
    '{title:$t, subtitle:$s, arg:$a, valid:true, autocomplete:$ac, icon:{path:$icon}}')"
  printf '{"items":%s}\n' "$(jq -c --argjson extra "$(get_json_results)" --argjson sw "$sw" '$extra.items + . + [$sw]' <<< "$items")"
  return 0
}

# The image list view, filtered by a substring. Ends with a "Containers" switch.
list_images_view() {
  local filter="$1" json items
  json="$(list_images_json)"
  if [[ -z "$json" ]]; then
    no_docker_item
    return 0
  fi
  items="$(jq -c -f src/list-images.jq --arg q "$filter" --arg icon_image "$ICON_IMAGE" <<< "$json" 2>/dev/null)"
  [[ -n "$items" ]] || items="[]"
  if [[ "$items" == "[]" ]]; then
    add_result "" "" "No images" "Nothing matches this query" "$ICON_IMAGE" "no"
  fi
  emit_with_switch "$items" "Containers →" "Back to containers" "view-containers" "" "$ICON_RUNNING"
  return 0
}

# The action menu for one image, filtered by a substring.
render_image_menu() {
  local iid="$1" filter="$2" obj dangling ref title
  obj="$(image_by_id "$iid")"
  if [[ -z "$obj" ]]; then
    add_result "" "" "Image not found" "It may have been removed" "$ICON_IMAGE" "no"
    get_json_results
    return 0
  fi
  if [[ "$(printf '%s' "$obj" | jq -r '.Repository // "<none>"')" == "<none>" ]]; then
    dangling=1
    ref="$(printf '%s' "$obj" | jq -r '.ID')"
    title="<none>:<none>"
  else
    dangling=0
    ref="$(printf '%s' "$obj" | jq -r '.Repository + ":" + .Tag')"
    title="$ref"
  fi
  menu_item "run"      "$filter" "Run"      "docker run --rm -it $title in iTerm2" "img-run $ref"    "$ICON_TERMINAL"
  if [[ "$dangling" == "0" ]]; then
    menu_item "pull"       "$filter" "Pull / update" "docker pull $title in iTerm2" "img-pull $ref"        "$ICON_RESTART"
    menu_item "copy ref"   "$filter" "Copy repo:tag" "Copy $ref to the clipboard"   "img-copy-ref $ref"    "$ICON_INSPECT"
  fi
  menu_item "copy id"  "$filter" "Copy image id" "Copy the image id to the clipboard" "img-copy-id $(printf '%s' "$obj" | jq -r '.ID')" "$ICON_INSPECT"
  menu_item "inspect"  "$filter" "Inspect"  "Open the docker inspect JSON"  "img-inspect $ref" "$ICON_INSPECT"
  menu_item "remove"   "$filter" "Remove"   "Remove the image (rmi -f)"     "img-remove $ref"  "$ICON_TRASH"
  get_json_results
  return 0
}

# Run mode: dispatch the item action.
if [[ "$mode" == "run" ]]; then
  action="${query%% *}"
  payload="${query#"$action"}"
  payload="${payload# }"
  case "$action" in
    menu)      alfred_search "docker @$payload " ;;
    shell)     run_iterm_cmd "$(shell_command "$payload")" "docker-shell-$payload" ;;
    logs)      run_iterm_cmd "$(logs_command "$payload")" "docker-logs-$payload" ;;
    restart)   docker_action restart "$payload"; alfred_search "docker " ;;
    stop)      docker_action stop "$payload"; alfred_search "docker " ;;
    start)     docker_action start "$payload"; alfred_search "docker " ;;
    remove)    docker_action remove "$payload"; alfred_search "docker " ;;
    inspect)   inspect_container "$payload" ;;
    open-port) open "http://localhost:$payload" ;;
    view-images)     alfred_search "docker images " ;;
    view-containers) alfred_search "docker " ;;
    img-menu)     alfred_search "docker #$payload " ;;
    img-run)      run_iterm_cmd "$(docker_bin) run --rm -it $payload" "" ;;
    img-pull)     run_iterm_cmd "$(docker_bin) pull $payload" "docker-pull-$payload" ;;
    img-inspect)  inspect_image "$payload" ;;
    img-remove)   image_remove "$payload"; alfred_search "docker images " ;;
    img-copy-ref) printf '%s' "$payload" | pbcopy ;;
    img-copy-id)  printf '%s' "$payload" | pbcopy ;;
    prune-containers) docker_prune containers; alfred_search "docker >" ;;
    prune-images)     docker_prune images; alfred_search "docker >" ;;
    prune-system)     docker_prune system; alfred_search "docker >" ;;
    set-path)  edit_path ;;
    autoupdate) set_autoupdate "$payload" ;;
    http://*|https://*) autoupdate_clear; [[ -f src/update.sh ]] && . src/update.sh "$query" ;;
    *) : ;;
  esac
  exit
fi

# List mode: global commands.
if [[ "$query" == ">"* ]]; then
  sub="${query#>}"
  sub="${sub# }"
  if [[ "$sub" == update* ]]; then
    if [[ -f src/update.sh ]]; then
      . src/update.sh ""
    else
      add_result "" "" "Updater unavailable" "Rebuild the workflow bundle" "$ICON_UPDATE" "no"
      get_json_results
    fi
  else
    globals_menu "$sub"
  fi
  exit
fi

# List mode: one container's action menu.
if [[ "$query" == "@"* ]]; then
  rest="${query#@}"
  cid="${rest%% *}"
  filter="${rest#"$cid"}"
  filter="${filter# }"
  render_menu "$cid" "$filter"
  exit
fi

# List mode: one image's action menu.
if [[ "$query" == "#"* ]]; then
  rest="${query#\#}"
  iid="${rest%% *}"
  ifilter="${rest#"$iid"}"
  ifilter="${ifilter# }"
  render_image_menu "$iid" "$ifilter"
  exit
fi

# List mode: the image list view (docker images / img).
case "$query" in
  images)    list_images_view ""; exit ;;
  images\ *) list_images_view "${query#images }"; exit ;;
  img)       list_images_view ""; exit ;;
  img\ *)    list_images_view "${query#img }"; exit ;;
  *) : ;;
esac

# List mode: the container list.
if [[ -z "$query" ]]; then
  autoupdate_refresh
  autoupdate_banner
fi

json="$(list_containers_json)"
if [[ -z "$json" ]]; then
  no_docker_item
  exit
fi

items="$(jq -c -f src/list-containers.jq --arg q "$query" \
  --arg icon_running "$ICON_RUNNING" --arg icon_stopped "$ICON_STOPPED" <<< "$json" 2>/dev/null)"
[[ -n "$items" ]] || items="[]"
if [[ "$items" == "[]" ]]; then
  add_result "" "" "No containers" "Nothing matches this query" "$ICON_STOPPED" "no"
fi

# Any update banner first, then the containers, then the Images switch last.
emit_with_switch "$items" "Images →" "Browse Docker images" "view-images" "images " "$ICON_IMAGE"

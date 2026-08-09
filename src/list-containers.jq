# Turn the container array (docker ps -a, one object per element) into Alfred
# Script Filter items. Running containers sort first, then by name. Enter drills
# into the per-container action menu; the cmd modifier stops or starts it, and
# the alt modifier tails its logs.
#
# Args: --arg q, --arg icon_running, --arg icon_stopped

def haystack:
  [.Names, .Image, .ID, .Status, .State] | map(. // "") | join(" ") | ascii_downcase;

def matches($q):
  ($q | ascii_downcase | split(" ") | map(select(length > 0))) as $w
  | ($w | length) == 0
  or (haystack as $h | all($w[]; . as $t | $h | contains($t)));

def name0: (.Names // "") | split(",")[0];

map(select(matches($q)))
| sort_by((if .State == "running" then 0 else 1 end), (name0 | ascii_downcase))
| map(
    (.State == "running") as $up
    | {
        uid: .ID,
        title: name0,
        subtitle: ([.Image, .Status] + (if (.Ports // "") != "" then [.Ports] else [] end) | join("   ·   ")),
        arg: ("menu " + .ID),
        autocomplete: ("@" + .ID + " "),
        valid: true,
        icon: { path: (if $up then $icon_running else $icon_stopped end) },
        mods: {
          cmd: (if $up
                then { valid: true, arg: ("stop " + .ID), subtitle: "Stop this container" }
                else { valid: true, arg: ("start " + .ID), subtitle: "Start this container" }
                end),
          alt: { valid: true, arg: ("logs " + .ID), subtitle: "Tail logs in iTerm2" }
        }
      }
  )

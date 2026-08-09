# Turn the image array (docker images, one object per element) into Alfred
# Script Filter items. Tagged images sort by repository; dangling (<none>) sink
# to the bottom. Enter drills into the per-image action menu; the cmd modifier
# removes it, and the alt modifier pulls (updates) it.
#
# Args: --arg q, --arg icon_image

def dangling: (.Repository // "<none>") == "<none>";
def title: if dangling then "<none>:<none>" else (.Repository + ":" + .Tag) end;
def ref: if dangling then .ID else (.Repository + ":" + .Tag) end;

def haystack:
  [.Repository, .Tag, .ID] | map(. // "") | join(" ") | ascii_downcase;

def matches($q):
  ($q | ascii_downcase | split(" ") | map(select(length > 0))) as $w
  | ($w | length) == 0
  or (haystack as $h | all($w[]; . as $t | $h | contains($t)));

map(select(matches($q)))
| sort_by((if dangling then 1 else 0 end), (.Repository // "" | ascii_downcase), (.Tag // ""))
| map(
    {
      uid: .ID,
      title: title,
      subtitle: ([.ID, (.Size // ""), (.CreatedSince // "")] | map(select(. != "")) | join("   ·   ")),
      arg: ("img-menu " + .ID),
      autocomplete: ("#" + .ID + " "),
      valid: true,
      icon: { path: $icon_image },
      mods: {
        cmd: { valid: true, arg: ("img-remove " + ref), subtitle: "Remove this image (rmi -f)" },
        alt: (if dangling
               then { valid: false, subtitle: "A dangling image cannot be pulled" }
               else { valid: true, arg: ("img-pull " + ref), subtitle: "Pull / update this image" }
               end)
      }
    }
  )

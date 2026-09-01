# Changelog

## 1.1.0-alpha3

- Fixed the windows not appearing while Sszorak is targeted. Which zone you are
  in was only ever read when entering the world, and the game does not always
  have that answer ready at the moment it says so. One wrong reading stranded
  the addon for the rest of the session: it decided it was not in the raid, and
  nothing asked again until the next loading screen, which is exactly what
  reloading inside the raid would do. The zone is now read on zone changes as
  well, and again shortly after entering the world
- `/sszmap comms` also reports what the targeting half can see: the instance it
  thinks you are in, whether it is watching your target, and the guid of
  whatever you have selected

## 1.1.0-alpha2

- Fixed sharing not working at all. Two faults, either of which was enough on
  its own:
  - The receiver threw every message away. Addon messages name the sender as
    Name-Realm even for someone on your own realm, and that form does not
    resolve as a unit, so the leader-or-assist check was false for everybody.
    The sender is now matched against the group roster and the check is asked of
    the real unit
  - Messages could go out on the wrong channel. If LE_PARTY_CATEGORY_INSTANCE is
    missing on this client then IsInGroup answers true for any group at all, and
    a normal raid's messages were addressed to INSTANCE_CHAT, where nobody is
    listening. The category number is used directly now, as DBM does
- `/sszmap comms` prints what the sharing layer can see - whether the prefix is
  registered, which channel it would use, whether you have the rank to send -
  and switches on a trace of everything sent, received and dropped, with the
  reason for each drop

## 1.1.0-alpha1

- **Share the set with your raid.** The leader or an assist clicks, and everyone
  else running the addon sees the placements appear on their own board. Every
  message carries the whole set rather than a change to it, so a dropped one is
  repaired by the next instead of leaving somebody a step behind. On by default,
  and it does nothing at all unless you have the rank to lead
- **Send my markers to the raid**, in the settings, puts your marker layout on
  everyone else's map so the shared calls mean the same thing on their screen as
  on yours. Never sent on its own: nobody's config changes unless you press it
- The default layout now matches NSRT's marker map for this fight, so a raid
  running both sees the same markers in the same places without configuring
  either. Only new installs and Reset markers are affected - an existing layout
  is left exactly as it is
- **Markers you do not need fade back** once all three placements are recorded.
  It waits for the full set, so it can never fade a sector you still have to
  click. Empty placement slots fade with them
- North and south can carry a marker now, for raids that mark all eight. Both
  start with NSRT's, and Clear marker in their right-click menu puts the bare
  letter back. The other six cannot be emptied, since that would leave the
  sector opposite with nothing to call
- Markers are drawn slightly smaller, which leaves the octagon less crowded

## 1.0.5

- All eight raid markers are offered when you right-click a sector, not just the
  six the default layout happens to use. Moon and Skull were sitting out for no
  good reason
- The windows also come up while Sszorak is targeted, so markers can be placed
  before the pull rather than during it. They go away again when you drop
  target, unless a pull is running or the settings are open. Works on any client
  language, and costs nothing outside The Venomous Abyss

## 1.0.4

- The windows now come up with the settings panel and go away with it, which is
  what you wanted them for. The Show the windows now tickbox is gone: it had
  nothing left to do. `/sszmap place` still shows them without the panel
- Fixed the windows appearing on their own at login. Whether they are up is
  session state now rather than something saved, so a session always starts with
  them away until a pull or the settings panel brings them back
- Dropped Wago. Releases go to GitHub and CurseForge

## 1.0.3

- An Advanced options section in the settings, folded away by default so the
  everyday panel stays short
- Both warnings can be reworded: Tornado warning and Damage Amp warning.
  Clearing a box puts the default back rather than leaving you with no text, and
  a default you never touched is not copied into your settings, so a later
  reword still reaches you
- A Hide warning text tickbox. The placements still clear on schedule, you just
  do not get shouted at
- The four timings around each Damage Amp are editable: first prompt after the
  pull, the middle call before an amp, how long after an amp the set clears, and
  how long after that the prompt returns. The amp times themselves are shown for
  reference but stay fixed, since nine numbers across three difficulties is a
  spreadsheet rather than a settings row

## 1.0.2

- Setting a marker no longer rearranges the others. Picking one used to shunt
  whatever it displaced into the slot it came from, which kept the six unique
  but meant the board moved under you while you were trying to set it up. What
  you pick is now simply what goes there

## 1.0.1

- The palette says "Click where the tornadoes are", which is the thing you are
  actually looking for rather than a general instruction
- A one-line greeting the first time you log in after installing. A fresh
  install puts nothing on screen on purpose, and without a word that is hard to
  tell apart from an addon that did not install. Said once, in chat, never again
- The set now clears itself when the winds are actually done with, rather than
  waiting for you. The timing follows Damage Amp, which is what the winds ride
  on, using the times NorthernSkyRaidTools measured for Normal, Heroic and Mythic
- A prompt line above the placements. Red LOOK FOR TORNADOES five seconds into
  the pull and five seconds after each set clears, taking itself away as soon as
  all three placements are in, since by then you have found them. Amber RUN TO
  MIDDLE for the five seconds before each Damage Amp, which outranks it
- An entry in the game's own AddOns settings list, with a button that opens the
  options. One button rather than a second copy of the settings, so there is no
  way for two versions of the same option to disagree

## 1.0.0

First public release.

- Click the sector you can see and the addon records the marker sitting opposite
  it, which is the one you actually have to call. Three placements to a set
- The room is drawn as its eight sectors, north up, with the six live ones
  wearing your markers and the dead north and south pair greyed out. The three
  pairings are spelled out under the ring so the layout can be checked at a glance
- A separate placements readout lists the calls in order, big enough to read
  without looking away from the fight
- Right-click any sector out of combat to change which marker sits there.
  Whatever it displaces swaps into the slot it left, so the six always stay one
  to one and the layout can never end up with a marker missing
- Both windows drag where you want them, remember the spot and carry their own
  padlock. Locking only stops a window being dragged, the sectors stay clickable
- Options under `/sszmap`, including window sizes and a positioning mode that
  brings the windows up outside a pull so they can be placed
- Only loads for Sszorak in Venomous Abyss, on Normal, Heroic and Mythic. The
  set clears at the start and end of every pull

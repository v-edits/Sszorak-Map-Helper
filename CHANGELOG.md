# Changelog

## 1.0.1

- The palette says "Click where the tornadoes are", which is the thing you are
  actually looking for rather than a general instruction
- A one-line greeting the first time you log in after installing. A fresh
  install puts nothing on screen on purpose, and without a word that is hard to
  tell apart from an addon that did not install. Said once, in chat, never again
- The set now clears itself when the winds are actually done with, rather than
  waiting for you. The timing follows Damage Amp, which is what the winds ride
  on, using the times NorthernSkyRaidTools measured for Normal, Heroic and Mythic
- A red LOOK FOR TORNADOES prompt above the placements: five seconds into the
  pull, and five seconds after each set clears. It takes itself away as soon as
  all three placements are in, since by then you have found them
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

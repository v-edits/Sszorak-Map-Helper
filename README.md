# Sszorak Map Helper

A small helper for **Sszorak** in Venomous Abyss. The fight asks you to place
something opposite something you can see. This addon helps with that... so you
don't swing your camera around wildly while trying to figure it out, bathing in
tornadoes while you wonder where on earth you even are.

![The palette, the placements readout and the options panel](docs/screenshot.png)

## Commands

| | |
| --- | --- |
| `/sszmap` | open the options |

## Using it

- Pre-place the markers in the raid as they appear in the `/sszmap` preview.
- See a tornado? Click the icon that matches what you see! You can click them in
  order if you like, clicking the 1 tornado icon first, then the one with 2
  tornadoes, and so on.
- The **Placements** window lists them in call order, `1 = Star`, `2 = Triangle`,
  big enough to read without looking away from the fight.
- **Undo** drops the last one, **Clear** restarts the set. It also clears itself
  at the start and end of every pull.

## Features

- **Click what you see, get what to call.** The room is drawn as its eight
  sectors, north up, with the dead north and south pair greyed out. Click the
  sector a tornado is in and it records the marker opposite it.
- **Placements readout** in call order, `1 = Star`, `2 = Triangle`, sized to be
  read out of the corner of your eye rather than studied.
- **Warnings timed to the fight.** A red tornado warning when there is something
  to find, and an amber Damage Amp warning five seconds before each amp.
- **The set clears itself** once the winds are done with, so you never call a
  stale one. Timed off Damage Amp on Normal, Heroic and Mythic.
- **Your marker layout, unchanged.** Right-click any sector to set what sits
  there. Nothing gets rearranged for you, and the three pairings are printed
  under the ring so the whole layout can be checked at a glance.
- **Both windows** drag where you like, remember the spot, scale independently
  and carry their own padlock. Locking never stops the sectors being clickable.
- **Advanced options** to reword either warning, hide them entirely, or change
  any of the four timings around each amp.
- **Reachable where you expect it** — an entry in the game's own AddOns settings
  list, as well as `/sszmap`.
- **Close to free when it is not needed.** No `OnUpdate`, no combat log parsing,
  no hooks into Blizzard's frames. Outside a Sszorak pull it listens to two
  events and does nothing else at all.

## Licence

MIT. Do what you like with it. See [LICENSE](LICENSE) for the full text.

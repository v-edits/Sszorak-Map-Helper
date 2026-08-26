# Sszorak Map Helper

**Open the options with `/sszmap`.**

A small helper for **Sszorak** in Venomous Abyss. The fight asks you to place
something *opposite* something you can see. This does that one bit of arithmetic
for you, so you can call it out without having to work it out.

Click the sector you can see the thing in. It tells you the marker opposite it.
That is the whole addon.

![The palette, the placements readout and the options panel](docs/screenshot.png)

## Why

The room is eight sectors. North and south are dead; the other six carry
markers. Facing the boss in the middle, the marker you need to call is the one
behind you, which is whatever sits opposite the sector you are looking at.

Easy at a keyboard. Awkward in the three seconds you actually get.

## Using it

- **Click a sector** to record the marker opposite it. Three placements per set.
- The **Placements** window lists them in call order, `1 = Star`, `2 = Triangle`,
  big enough to read without looking away from the fight.
- **Undo** drops the last one, **Clear** restarts the set. It also clears itself
  at the start and end of every pull.
- **Right-click a sector** out of combat to change which marker sits there.
  Whatever it displaces swaps into the slot it left, so the six always stay one
  to one. You can never end up with a marker duplicated or missing.
- The three pairings are printed under the ring, so you can check the layout at
  a glance instead of hovering every sector.

Both windows drag where you like, remember the spot, and carry a padlock in the
corner. Locking only stops dragging; the sectors stay clickable either way.

## Commands

| | |
| --- | --- |
| `/sszmap` | open the options |
| `/sszmap place` | show the windows outside a pull, so they can be dragged into place |
| `/sszmap lock` | lock or unlock both windows |
| `/sszmap clear` | drop the recorded placements |
| `/sszmap reset` | back to the default layout and window positions |

`/ssz` and `/ao` do the same thing.

## When it loads

Only for Sszorak, and only on Normal, Heroic and Mythic. Everywhere else the
windows do not exist.

It is built to cost as close to nothing as an addon can: no `OnUpdate`, no
timers, no combat log parsing, no hooks into Blizzard's frames. At rest it
listens to exactly two events, both of which only fire when a boss encounter
starts or ends. Everything else is registered only while a window is on screen,
so questing and dungeons cost nothing at all.

To place the windows before a pull, tick **Show the windows now**, drag them,
then untick it.

## Licence

MIT. Do what you like with it.

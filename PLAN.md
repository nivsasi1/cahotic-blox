# Morph Duels - work plan

Working title only. The idea is inspired by the show Chaotic (travel between worlds,
collect creature DNA, turn into creatures, duel other players), but the game must use
its own name, creatures and art. Roblox takes down games that use someone else's IP.

## Scope right now

Only the flow around the duel, from the task list we got:

1. Hub: an empty flat map.
2. Walk up to a player and click them. A window opens at the top: invite to duel.
3. The other player gets a popup and accepts.
4. A room is reserved.
5. Both players teleport there and turn into another sprite.
6. The room has a black cube. First to touch it wins and gets a scoreboard point.
7. Both teleport back to the hub and the room is released.

Not now: real combat, powers, DNA, other worlds, monster models. The friends decide those.

## Milestones

Each one ends with something you can open and try.

- [x] **M1 - Hub and invites.** Flat hub, hover and click a player, top invite window,
      popup with accept/decline, timeout, cooldown, all checks on the server.
      Try it: Studio > Test > Clients and Servers > 2 Players.
- [x] **M2 - Full duel loop.** Room pool, teleport, form swap, black cube, Wins on the
      scoreboard, return to hub, room released. Handles leaving and resetting mid-duel.
      Try it: same 2-player test. This finishes the friends' task list.
- [x] **Bigger room.** 128 by 128 room with a hut, alcoves, pillars, crates and low walls.
      The cube hides at one of 5 spots, never the same one twice in a row. 90 seconds a duel.
- [ ] **M3 - Go live (needs Niv).** Publish as private, invite friends, test on real
      servers, save Wins with DataStore. Stops for Niv: publishing needs their account.
- [ ] **M4 - Friends' content.** Drop-in monster models and arenas, then whatever the
      friends ask for next.

## Decisions

- Rooms are arenas inside the same server, not Roblox reserved servers. Reserve and release
  then match the task list exactly, and it can be tested in Studio. TeleportService does
  not run in Studio. `RoomPool` is one module, so this can change later.
- Clicking uses a client raycast, not ClickDetectors, so it keeps working on any model.
- Everything is checked on the server. The client only asks.
- Logic with no Roblox calls lives in pure modules, so Lune can test it from the terminal.
- Only touching the cube gives a point. Dying, leaving and time running out end the duel with no point.
- The cube hides behind cover and spawns face the middle of the room, so a duel is a search, not
  a straight run. Hiding spots are mirrored so neither spawn has an edge.
- Forms are full character swaps (`player.Character = model`), the same path a friend's
  rigged monster will use. Placeholders are recoloured default rigs.

## Resume notes

Update this section whenever work stops, so a fresh session can continue.

- M1 and M2 are done and verified on 2026-11-02: 11 unit tests, 56 checks in the two-player
  Studio test, screenshots reviewed. Next is M3, which needs Niv.
- The bigger room is on the `bigger-arena` branch, verified on 2026-11-10 with 58 checks and
  a top-down screenshot. The friends' next ask is a fighting engine (HP, damage, hitboxes, a
  toy blaster), planned on `toy-blaster` on top of it.
- The code is on GitHub at https://github.com/nivsasi1/cahotic-blox. From here all work goes on
  branches with pull requests into `main`. [ROADMAP.md](ROADMAP.md) maps the code.
- Not covered by the automated test: a real mouse click and the hover highlight (the test calls
  the raycast directly), and anything on real Roblox servers.
- Rules from the owner: no combat, powers, DNA or monster models until the friends decide.

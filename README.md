# Morph Duels

Working title. A Roblox game: walk up to a player in the hub, invite them to a duel, and race
them to a black cube in your own room, each in a different form. Winner gets a point.

See [PLAN.md](PLAN.md) for milestones and decisions.

## Try it

1. Build the place, or use the `morph-duels.rbxlx` that is already there:

   ```bash
   rojo build -o morph-duels.rbxlx
   ```

2. Open `morph-duels.rbxlx` in Roblox Studio.
3. In the **Test** tab choose **Clients and Servers**, set **2 Players**, press **Start**.
   Two windows open, one per player.
4. In one window, walk to the other player and click them. Press **Invite**.
   In the other window, press **Accept**.

## Change it

Live sync, so saved files show up in Studio right away:

```bash
rojo serve
```

Then in Studio: **Plugins** tab, **Rojo**, **Connect**.

| What | Where |
|---|---|
| Timers, room count, invite range, placeholder forms | `src/shared/Config.luau` |
| Hub map | `default.project.json`, under `Workspace` |
| Duel room | `src/arena/ArenaTemplate.model.json` |
| Monster models | `assets/forms`, see the README there |
| Server code | `src/server` |
| Client code and UI | `src/client` |

In Rojo JSON files, place parts with `CFrame`, never `Position`. `rojo build` keeps `Position`
but Studio ignores it when loading the place, so the part ends up at the origin.

## Test it

```bash
lune run tests/unit
```

Runs the room and invite logic in the terminal, no Studio needed.

```powershell
.\tests\integration\run.ps1
```

Plays the real game: opens Studio with one server and two clients, runs a scripted match through
invites, decline, cooldown, a cube win, dying, time running out and leaving, then prints every
check. Screenshots land in `.cache\shots`. Studio must be installed and signed in. It closes the
Studio windows it opened.

The `rojo`, `lune`, `luau-lsp` and `selene` versions are pinned in `rokit.toml`. On a new machine,
run `rokit install` once.

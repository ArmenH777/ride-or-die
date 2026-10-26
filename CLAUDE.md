# Ride or Die

A Roblox co-op survival game on a subway train: drive the train to Midnight Station while keeping
passengers calm (snacks, chatting) and fixing everything that breaks. Inspired by the *genre* of
"Land or Die" (plane version) — keep it its own game, not a copy. Published as **"Ride or DIE!"**
(placeId 76547775888210). The player is the owner/designer; keep explanations kid-friendly and plain.

## Where the game lives

- **Roblox Studio is the source of truth.** All scripts, the train, the lobby and every part live in
  the Studio place. Edit through the Roblox Studio MCP tools (`execute_luau`, `multi_edit`,
  `script_read`, playtest with `start_stop_play`).
- **`src/` is a read-only mirror** of the scripts, exported for git history. It uses Rojo-style
  names (`*.server.luau`, `*.client.luau`, plain `*.luau` = ModuleScript) but there is no Rojo setup —
  don't sync it back into Studio. After changing scripts in Studio, re-export the changed ones to
  `src/` (same path as in Studio) before committing.
- Builds made with Luau (train geometry, lobby, sounds, item tools, remotes) exist only in the place —
  there is no script that rebuilds them. Ctrl+S in Studio saves to the published game.
- `reference-notes.md` — what Land or Die's UI/gameplay looks like and the plane→train idea mapping.

## Script layout (Studio paths)

| Path | What it does |
|---|---|
| `ServerScriptService.GameServer` | Round loop + server modes (lobby vs ride server), reward payout, hooks between modules |
| `ServerScriptService.Modules.Train` | Throttle/speed/distance, red signals, curves, track junction + crash, cab levers |
| `…Modules.Passengers` | NPC passengers: fear, snack wants, talk/feed, fleeing, VIP |
| `…Modules.Breakdowns` | Window / Leak / Door / Power / Fire breakdowns, fix prompts, effects |
| `…Modules.Items` | Snack machine + tool rack/extinguisher cabinet pickups, hotbar drop |
| `…Modules.Lobby` | Boarding pads (host, join, friends-only, depart) |
| `…Modules.Shop` / `Data` / `Quests` / `Leaderboards` | Shop purchases + perks, DataStore saving, daily quests + login rewards, lobby leaderboards |
| `…Modules.Util` | Notify helpers (`NotifyAll` = riders only), `PlaySound`, `FindItem` vs `FindHeld` |
| `ReplicatedStorage.Config` | **All tuning numbers** (fear rates, difficulties, trains, perks, quests, rewards) |
| `ReplicatedStorage.UIStyle` | Shared cartoon UI helpers (outlined text, glossy buttons) — use for new UI |
| `StarterPlayerScripts.TunnelClient` | Client-only scrolling tunnel, stations, signals, junction visuals, rumble, camera sway |
| `…HUD` / `Hotbar` / `LobbyClient` / `ShopClient` / `QuestClient` | Ride HUD, custom 3-slot hotbar, lobby/matchmaking UI, shops, quests/rewards |

Also in the place: `ReplicatedStorage.Remotes` (RemoteEvents/Functions), `ReplicatedStorage.RoundState`
(Configuration whose attributes are the shared ride state), `ReplicatedStorage.Sounds` (sound templates,
mostly ProSoundEffects IDs), `ServerStorage.Items` (Tool templates with `DisplayName`/`Icon` attributes),
`workspace.Train` (car at the origin, ~96 studs long along X, nose at x=48), `workspace.Lobby` (around z≈370).

## Key design decisions

- **The train never moves.** It sits at the origin; `TunnelClient` scrolls client-side tunnel parts
  past it from `RoundState.Distance`/`Speed`. Route objects are placed by route position
  (`Config.StudsPerMile`).
- **Lobby server vs ride server.** Ride servers are reserved servers of the same place
  (`game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0`), reached via `TeleportAsync` with
  `ShouldReserveServer`. In Studio (or `Config.LocalRides`) rides run inside the lobby server instead,
  one at a time. Teleports, DataStores and leaderboards only work in the published game.
- **`InRide` player attribute** decides ride vs lobby for spawning, HUD visibility, rumble, camera
  zoom (12 in rides, 28 in the lobby) and fog.
- **Hold-to-use:** fixes and feeding require the tool/snack to be *equipped* (`Util.FindHeld`).
- **Custom hotbar:** Roblox's backpack is disabled; 3 slots (+2 with Big Pockets perk).
- **Style:** the user wants Land or Die's chunky cartoon look everywhere (bold outlined text, thick
  borders, glossy colored buttons, orange warning cards with a "!" badge). Use `UIStyle`.
- Wrong side at a track junction = crash = lose, on every difficulty (user's choice).
- The host's equipped train sets ride stats + seat/stripe colors (`Train.SetModel`).

## Testing in Studio

- Rides: step on a lobby pad → matchmaking → START (or fire `Remotes.PadSetup` from the client).
- Jump ahead: set the workspace attribute `DebugDistance` (miles) during a ride (Studio only).
- Give test Tokens on the server: `player.leaderstats.Tokens.Value = N`.
- Studio and the live game share the same DataStore — test edits to saved data are real.
- Playtesting blocks the Edit datamodel; stop play before editing scripts.

## Open items / user requests

- Not built yet (user said wait): training car. Ideas offered but not chosen: rockslide, oncoming
  train, flooded tunnel, crying baby, sleepwalker, Halloween update, Robux purchases.
- Untested so far: VIP bonus payout, fire spreading, live teleports/saving/leaderboards.

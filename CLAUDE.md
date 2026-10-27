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
- Builds made with Luau (sounds, remotes, colliders, lights, signs) exist only in the place — there is
  no script that rebuilds them. Ctrl+S in Studio saves to the published game.
- `reference-notes.md` — what Land or Die's UI/gameplay looks like and the plane→train idea mapping.
- `blender/` — the 3D models (train car, tools/snacks, lobby station) are made in Blender from Python
  build scripts (see "Blender models" below). `RideOrDie.blend` is the saved result.

## Script layout (Studio paths)

| Path | What it does |
|---|---|
| `ReplicatedFirst.LoadingScreen` | Self-contained join screen: closed train doors, tunnel rushing past the windows, logo, Line 13 map progress, tips, SKIP; brakes into the station and the doors slide open (min 3.5 s) |
| `ServerScriptService.GameServer` | Round loop + server modes (lobby vs ride server), reward payout, hooks between modules |
| `ServerScriptService.Modules.Train` | Throttle/speed/distance, red signals, curves, track junction + crash, cab levers |
| `…Modules.Passengers` | NPC passengers: fear, snack wants, talk/feed, fleeing, VIP |
| `…Modules.Breakdowns` | Window / Leak / Door / Power / Fire breakdowns, fix prompts, effects |
| `…Modules.Items` | Snack machine + tool rack/extinguisher cabinet pickups, hotbar drop |
| `…Modules.Lobby` | Boarding pads (host, join, friends-only, depart) |
| `…Modules.Shop` / `Data` / `Quests` / `Leaderboards` | Shop purchases + perks, DataStore saving, daily quests + login rewards, lobby leaderboards |
| `…Modules.Admin` | `/admin` chat command (TextChatCommand) + server-checked panel actions; admins = game creator + `Config.Admins` |
| `…Modules.Util` | Notify helpers (`NotifyAll` = riders only), `PlaySound`, `FindItem` vs `FindHeld` |
| `ReplicatedStorage.Config` | **All tuning numbers** (fear rates, difficulties, trains, perks, quests, rewards) |
| `ReplicatedStorage.UIStyle` | Shared cartoon UI helpers — use for new UI: `UI.window` (dark window, title above, red X; opening one closes the others, `UI.anyWindowOpen()`), `UI.menuButton` (left button column), `UI.bar`, `UI.rays` (sunburst), `UI.check` (big tick — the ✔ character renders as a grey emoji), `UI.pop`/`UI.popText`, `UI.comma` (1,671). Any open window blurs the world behind it. `UI.Actions` = functions one script offers others (`OpenRewards` from QuestClient, used by the Tokens "+" window in HUD) |
| `StarterPlayerScripts.TunnelClient` | Client-only scrolling tunnel, stations, signals, junction visuals, rumble, camera sway |
| `…HUD` / `Hotbar` / `LobbyClient` / `ShopClient` / `QuestClient` | Ride HUD, custom 3-slot hotbar, lobby/matchmaking UI, shops, quests/rewards |
| `…AdminClient` | The admin panel window (tokens, give items, break/fix, calm/scare, win/lose, jump ahead, teleport) |
| `…PadFX` | Client-only glow on the lobby pads (light walls, rising rings, sparkles, floor arrows) in the pad's colour; faster when hosted |
| `…LobbyLife` | Client-only lobby life: music playlist + crowd murmur, station announcements (chime + bottom banner), distant train, departures board (clock + flipping platform lines), "DIE!" wobble on the logo, NPCs (`Lobby.NPCs`), pigeons that flee, and the SETTINGS window (Music / Station sounds) |

Also in the place: `ReplicatedStorage.Remotes` (RemoteEvents/Functions), `ReplicatedStorage.RoundState`
(Configuration whose attributes are the shared ride state), `ReplicatedStorage.Sounds` (sound templates,
mostly ProSoundEffects IDs), `ServerStorage.Items` (Tool templates with `DisplayName`/`Icon` attributes;
Handle = Blender mesh, extra colored meshes welded to it), `ServerStorage.MeshTemplates` (symmetric
Blender meshes used to swap functional parts: Window, DoorPanel, Strip, Pad, Board...),
`workspace.Train` (car at the origin, ~96 studs long along X, nose at x=48), `workspace.Lobby`
("Central Station" hall: x ±48, z 294–414, floor top y=1).

### Train / lobby structure after the Blender rebuild (2026-10-26)

- `Train.Visual` = all the new meshes (non-colliding) except the shell pieces that must block the camera:
  `SideWallR/L`, `CeilingLining`, `RearWall`, `FrontWall`, `Console`, `SnackBody` collide with
  Box fidelity (Roblox's camera only zooms through non-colliding parts). `Train.Ads` = poster Parts with
  SurfaceGuis on the sloped ceiling. Functional parts (Windows, door Panels, light Strips, vents, cab
  lever/switch bases, Headlights, BreakerBox Box/Lever) are meshes with the old names, so scripts work
  unchanged. `Shell.Floor/Ceiling/Partition*` and `Interior.BenchBase` are invisible colliders.
  `Shell.WallLow/Stripe` and `Interior.Cushion` (one per bench side) are recoloured by `Train.SetModel`.
  Cab levers sit on the sloped console top (Train.luau takes the pivots from the bases at load);
  the lever labels were removed at the user's request. The snack machine has no text either: each
  coloured button shows a 3D copy of its snack standing on a little shelf (`SnackMachine.Displays`,
  outside `Buttons`).
- `ReplicatedStorage.TrainPreview` = the train's outside (cloned from Train/Lobby meshes, glass made
  solid) used by the TRAINS shop viewport; parts with a `Paint` attribute (Body/Accent/Lower) take the
  train's colours.
- Item pictures: `blender/render_icons.py` renders the tools/snacks + a gold star as outlined PNGs; they
  were uploaded with the Studio MCP `upload_image` (serve the folder on localhost first) and their ids
  live in `Config.Icons` (passenger bubbles, hotbar, results stars). Soda's emoji is 🥫 to match the can.
- Results screen: server sets `RoundState` Stars (1 = arrived, 2 = ≥80% saved, 3 = all + VIP), MVP /
  MVPLine (most fixes + snacks); best times per difficulty are player attributes `Best_<Difficulty>`
  saved by Data (`LastNewBest` flags a record).
- Phones: HUD pieces carry a UIScale set from screen height (`fitScreen` in HUD); on touch screens the
  Tokens pill moves top-right (jump button) and the lobby buttons/quest list sit higher. The hotbar hides
  while results show. Test with Studio's device simulator at real phone size (~852x393), not the
  preset's pixel resolution.
- `Lobby.Visual` meshes, `Lobby.Colliders` (invisible blocks: platform edge, pillars, benches, gates,
  stairs wedge...), `Lobby.Lights` (pendant PointLights at 0.3 brightness — brighter washes the white
  tiles out), `Lobby.Signs` ("CENTRAL" plaques, EXIT). Pads sit on the platform at z=321
  (x = -27, -9, 9, 27) in front of the parked train's open doors; their Boards hang at z=328.6.
  Shop prompts live in the old (invisible) `Counter` parts at x=±38, z=363. Spawn medallion at z=400;
  `LobbySpawn` itself is at z=393 so the starting camera isn't inside the (non-colliding) exit stairs.

### Lobby polish pass (2026-10-27)

- `Lobby.Decor` holds everything added in Studio (Parts + SurfaceGuis, no Blender import needed):
  `LogoSign` (pill-shaped "RIDE OR DIE!" banner at z=332.5, just in front of the z=331 lamp row so lamps
  and board cables sit behind it; its "Die" labels wobble), `FlowerBed` (replaced the tree, which hid the
  pads from the spawn), `Posters` (Line 13 map, Midnight Station, Fizz Cola, Pretzel Palace, fire + duct
  tape ads on the side walls; frames are scaled `MeshTemplates.Board`), `ShopDisplays` (mini
  `TrainPreview` copies in each train's colours + price tags), `Gates` (gold bands + green arrow screens),
  `PadNumbers`, `Vending` (FIZZ/SNAX logo boxes + glow), `ExitScene` (night street at the top of the
  stairs), `TrainLights` (parked train ends), `Pigeons`, `Dust` (floating specks), `MedallionBadge`.
- `Lobby.NPCs`: R15 rigs made with `CreateHumanoidModelFromDescription` (free Roblox hair only), HRP
  anchored. Attribute `Role` = Shopkeeper (`Title`, `Lines` split by `|`), Sitter, Walker (`Path` =
  "x,z;x,z;..." loop) or Idle. LobbyLife moves/animates them locally with Roblox's default R15 animations.
- `ServerStorage.LobbyRemoved` keeps what was taken out (tree meshes, old TitleSign, toy-train pills,
  4 CENTRAL plaques) in case they're wanted back.
- Floor has a `Tiles` Texture (rbxassetid://127539213550302, 8 studs). Each lobby `Lamp` has a `Pool`
  SpotLight pointing down. Free pads are station blue (`IDLE` in Lobby.luau).
- Settings: attributes `SettingMusic` / `SettingSounds` (missing = on), set via `Remotes.SetSetting`,
  saved by Data in `Settings`. New sounds in `ReplicatedStorage.Sounds`: Music1-3 (APM), LobbyAmbience,
  Chime, PigeonFlap, DistantTrain (ProSoundEffects).
- The top hint hides once you're past the fare gates (z < 345). Daily Quests folds itself into an
  "All done!" line when every quest is claimed. TRAINS / PERKS show a "!" while you can afford something.

## Blender models

- Built in **Roblox coordinates** (studs, Y up): `rod_lib.py` converts Roblox (x, y, z) → Blender
  (x, -z, y) and has the shape helpers (rounded boxes, rounded-rect slabs/frames, lathe, pipes, booleans)
  and the palette. `build_train.py`, `build_tools.py`, `build_lobby.py` make one collection each; objects
  carry `rbx_path`/`rbx_name`/`pal` props, and objects with the same path+name+palette merge into one
  MeshPart (≤19k triangles; bigger groups split). `template=True` objects export as swap templates.
- Export: `blender.exe -b --factory-startup --python blender/export_all.py -- blender/export/json`, then
  Blender's Python runs `json_to_obj.py <json dir> blender/export/RideOrDie_<x>.obj <prefix>[:Name+Name]`.
  The user imports the OBJ with Studio's **Import 3D** (each OBJ `g` group → a MeshPart named
  `<prefix>_NNN`, matching the JSON manifest). The importer turns meshes 180° around Y, so placed parts
  use `CFrame.new(center) * CFrame.Angles(0, math.pi, 0)` — see `blender/place_meshes.luau`.
- Dead ends (2026-10-26): `AssetService:CreateAssetAsync` says "not available yet" even from a local
  plugin, so meshes can't be uploaded by script; EditableMesh is blocked in playtests unless the
  Security setting is on; Blender's `normals_split_custom_set` crashes on degenerate triangles (that's
  why FBX export was dropped for OBJ).

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
  borders, glossy colored buttons, orange warning cards with a "!" badge). Windows follow the user's
  reference screenshots (2026-10-26): near-black rounded panel, big title + tilted emoji above it, red
  square X on the corner, sunburst reward cards, lime "Claim" buttons. Use `UIStyle`.
- **3D style:** the user wants it to look like "a billion dollar company made it" but cartoony like
  Land or Die: smooth rounded Blender meshes, flat SmoothPlastic colours, warm lighting, no realism.
- **Lobby layout:** left = REWARDS / TRAINS / PERKS buttons, right = Daily Quests list (click header to
  fold), top centre = hint + open trains, bottom centre = "leaving in" panel. The LOGIN REWARD window
  pops up on join when a reward is waiting. `DailyData.Total` = days in a row ("Your streak").
- Wrong side at a track junction = crash = lose, on every difficulty (user's choice).
- Prices (rebalanced 2026-10-26 against ~225 Tokens per Easy ride, ~675 on Extreme): trains 750 /
  2,500 / 6,000 / 15,000, perks 1,000 / 1,500 / 2,000 / 2,500.
- The host's equipped train sets ride stats + seat/stripe colors (`Train.SetModel`).

## Testing in Studio

- Rides: step on a lobby pad → matchmaking → START (or fire `Remotes.PadSetup` from the client).
- Jump ahead: set the workspace attribute `DebugDistance` (miles) during a ride (Studio only).
- Give test Tokens on the server: `player.leaderstats.Tokens.Value = N`.
- Studio and the live game share the same DataStore — test edits to saved data are real (that includes
  the admin panel's Tokens and "Win now", which pays a normal win reward and counts for quests).
- Admin panel: type `/admin` in chat. Ride buttons only work while a ride is Running.
- Loading screen: set the workspace attribute `HoldLoadingScreen = true` (Studio only) to keep it up
  for screenshots; set it false to watch the arrival + doors opening. Clear it before saving.
- Big script edits can be pushed into Studio by serving the file on localhost and fetching it with
  HttpService (turn `HttpEnabled` on only for that call, then off again).
- Playtesting blocks the Edit datamodel; stop play before editing scripts.

## Open items / user requests

- Not built yet (user said wait): training car. Ideas offered but not chosen: rockslide, oncoming
  train, flooded tunnel, crying baby, sleepwalker, Halloween update, Robux purchases.
- Untested so far: VIP bonus payout, fire spreading, live teleports/saving/leaderboards.

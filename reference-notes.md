# Ride or Die: reference notes

Taken from two Land or Die recordings (2026-10-26). The plan is to match the *genre and feel*, not copy the game: same core loop, our own train-themed look, events and names.

## Decisions (2026-10-26)
- **Train:** subway. Underground tunnels and stations along the route; dark, spooky events.
- **Driving:** players drive from a cab (throttle, brake, horn); slow for curves and red signals.
- **Players:** 1–4 co-op on one train, harder with more players; solo still works.
- **First milestone:** one playable round (train, passengers and moods, snacks, 3–4 breakdowns, HUD, win/lose). Lobby comes later.
- **Platform:** Roblox, built through Roblox Studio.

## What Land or Die does

### Lobby (hub world)
- Free-roam airport hub with a seasonal (Halloween) theme.
- Left side button column: Store, Planes, Stats, Classes, plus limited-time bundles.
- Top-right: Quests, Rewards, event currency.
- Bottom-right: soft currency counter ("Miles").
- Right side: list of open lobbies with a difficulty tag and a Join button, plus paid-upsell cards.
- Physical "step in to host" pads. Stepping on one opens a **Matchmaking** panel: player count (3–4 recommended), difficulty (Easy / Medium / Hard / Extreme, harder = more currency), game mode, friends-only, and a big Start button. "Auto leaving in Xs" countdown.
- Vehicle shop: list of planes on the left, stat card on the right (Speed, Fuel Usage, Handling, Max Altitude, Build Quality, Crew Size), skins, priced in currency or Robux.
- Classes area and a "Training" (tutorial) area.

### In-round HUD
- **Top center:** progress bar from start to destination, coloured green → yellow → orange → red, with a vehicle icon moving along it and a "XXX mi away" readout.
- **Under it:** one face per passenger (green happy → orange worried → red angry → purple/skull = lost) plus "PASSENGERS: 6 / 6".
- **Right side:** stacked warning toasts with an ⚠ icon, e.g. "RADIO malfunction!", "SEATBELT malfunction!", "LOW FUEL: refuel on the wing!", "A WINDOW is BROKEN! x2", "Fuel leak detected", "Power has been LOST", "Someone left a door open!", hazard events like acid rain or a tsunami.
- **Center-bottom:** short feedback text ("Power restored!", "Fed Passenger #3!", "You need a Wrench!", "Passenger #6 isn't in the mood to chat…").
- **Bottom center:** 3-slot tool hotbar (fire extinguisher, plunger, wrench, fuel can), each with a durability bar.
- **Bottom-left:** player stat bars that appear when relevant: health, oxygen, stamina/energy.
- **Subtitle line** for radio chatter from air traffic control.

### Gameplay loop
- The round is a trip of ~350 miles that lasts ~9 minutes. Survive until you arrive.
- **Passengers** sit in seats with a thought bubble showing what they want (sandwich, burger, milkshake, water). Their name tag shows mood ("Anxious", "Stressed", "Cooked"). Grab food from a snack station and hand it over to calm them. Panicked passengers can be lost.
- **Breakdowns** pop up around the vehicle. Each needs the right tool or action: broken window, toilet leak (plunger), power out (climb to a breaker/ladder area), fuel leak, radio, seatbelts, oxygen masks (wrench).
- **Tool wall** where you pick up tools; "Break glass in case of emergency" items cost currency.
- **Cockpit:** seat to sit in and steer, with throttle, engine levers, fuel gauge, radar, weather/time-of-day panel and a radio that rings with instructions.
- **Escalating hazards:** weather, then big scripted disasters later in the round (giant wave, "something attacking the plane"). Several problems stack up at once near the end.
- Areas: cabin, cargo hold, cockpit, toilets, outside on the wing (refuelling).
- Rewards: currency for each round, more on harder difficulties, plus event currency.

## Train version ideas

| Land or Die | Ride or Die |
|---|---|
| Airport lobby | Train station / subway platform hub |
| Distance to airport | Distance to the final station, with stops along the way |
| Cockpit + flight controls | Driver's cab: throttle, brake, horn, headlights; slow down for curves and red signals |
| Refuel on the wing | Shovel coal, swap a battery, or reset the pantograph on the roof |
| Broken window | Broken window (rocks thrown, tunnel debris) |
| Toilet leak | Toilet leak, or a burst pipe between cars |
| Power lost | Lights out in a tunnel: flip the breaker in the electrical cabinet |
| Seatbelt / oxygen masks | Doors jam open, brakes overheat, couplings come loose between cars |
| Weather / tsunami | Storms, flooded tunnel, rockslide on the track, a cow on the tracks, mystery thing in the tunnel |
| Snack station | Snack trolley you push down the aisle |
| Passengers' moods | Same idea, plus standing commuters, a crying baby, someone missing their stop |
| Plane shop | Train shop: steam train, subway car, bullet train, cargo train |

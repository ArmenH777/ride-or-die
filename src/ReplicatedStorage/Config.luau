-- Ride or Die: all the numbers you might want to tweak live here.
local Config = {}

-- Route
Config.LineName = "LINE 13"
Config.RouteMiles = 4
Config.StudsPerMile = 5040 -- how far the tunnel scrolls per mile (visual only)
Config.Stations = {
	{ Name = "Start", Mile = 0 },
	{ Name = "Elm Street", Mile = 1.0 },
	{ Name = "Old Mill", Mile = 2.1 },
	{ Name = "Hollow Park", Mile = 3.1 },
	{ Name = "Midnight Station", Mile = 4 },
}

-- Driving
Config.MaxSpeed = 55 -- mph
Config.Accel = 3.5 -- mph gained per second
Config.Brake = 7 -- mph lost per second when slowing down
Config.Coast = 1.2 -- mph lost per second with no power
Config.ThrottleRate = 0.5 -- how fast holding W/S moves the lever (per second)
Config.CurveLimit = 25
Config.Curves = 3
Config.Signals = 3
Config.Splits = 1 -- track junctions per ride (wrong side = crash)
Config.SplitWarning = 0.25 -- miles of warning before a junction

-- Round flow
Config.CountdownTime = 15
Config.ResultsTime = 10

-- Passengers
Config.BasePassengers = 6
Config.PassengersPerExtraPlayer = 2
Config.MaxPassengers = 12
Config.Fear = {
	Base = 0.18, -- fear gained per second just from riding
	PerExtraPlayer = 0.15, -- extra multiplier per extra player
	WantWaiting = 0.25, -- extra fear per second while their snack wish is ignored
	Feed = 45,
	Talk = 8,
	TalkCooldown = 15,
	CurveTooFast = 2.5, -- fear per second while speeding through a curve
	RedSignal = 20, -- fear from running a red signal
	WantDelay = { 18, 35 }, -- seconds until they want another snack
}
Config.Moods = {
	{ Max = 25, Name = "Calm", Face = "😀", Color = Color3.fromRGB(70, 200, 90) },
	{ Max = 50, Name = "Uneasy", Face = "😐", Color = Color3.fromRGB(240, 200, 40) },
	{ Max = 75, Name = "Anxious", Face = "😟", Color = Color3.fromRGB(245, 140, 30) },
	{ Max = 101, Name = "Panicking", Face = "😱", Color = Color3.fromRGB(230, 50, 50) },
}

-- Snacks (name -> emoji)
Config.SnackOrder = { "Sandwich", "Soda", "Pretzel", "Water" }
Config.Snacks = { Sandwich = "🥪", Soda = "🥤", Pretzel = "🥨", Water = "💧" }
Config.MaxCarry = 3 -- hotbar slots (Big Pockets adds 2)

-- Icons shown in the hotbar
Config.ItemIcons = {
	Wrench = "🔧", DuctTape = "🩹", Extinguisher = "🧯",
	Sandwich = "🥪", Soda = "🥤", Pretzel = "🥨", Water = "💧",
}
-- Where each tool can be found (used in "you need..." messages)
Config.ToolHints = {
	Wrench = "the tool rack at the back",
	DuctTape = "the tool rack at the back",
	Extinguisher = "the red cabinet at the back",
}

-- VIP passenger: one per ride. Scares a bit faster, pays everyone a bonus if they arrive.
Config.VIP = { Chance = 1, Bonus = 75, Fear = 1.25 }

-- Breakdowns
Config.Breakdowns = {
	Window = { Label = "A WINDOW is BROKEN!", Action = "Tape up", Tool = "DuctTape", Hold = 2.5, Fear = 0.25, Weight = 3 },
	Leak = { Label = "A PIPE is LEAKING!", Action = "Tighten pipe", Tool = "Wrench", Hold = 2.5, Fear = 0.15, Weight = 3 },
	Door = { Label = "A DOOR is stuck OPEN!", Action = "Force shut", Hold = 3, Fear = 0.3, Weight = 2 },
	Power = { Label = "POWER has been LOST!", Action = "Flip breaker", Hold = 1.5, Fear = 0.5, Weight = 2 },
	Fire = { Label = "A VENT is ON FIRE!", Action = "Put out fire", Tool = "Extinguisher", Hold = 3, Fear = 0.6, Weight = 2 },
}
Config.FireSpreadTime = 25 -- seconds before an untouched fire spreads to another vent
Config.FirstBreakdownAt = 25 -- seconds into the ride
Config.BreakdownInterval = { 32, 15 } -- seconds between breakdowns (start of ride -> end of ride)

-- Rewards (Tokens)
Config.Rewards = { Win = 50, PerPassenger = 20, Fix = 5, Feed = 3 }

-- Difficulties picked when hosting a ride in the lobby.
-- Fear: how fast passengers get scared. Breakdowns: how often things break. Reward: token multiplier.
Config.DifficultyOrder = { "Easy", "Medium", "Hard", "Extreme" }
Config.Difficulties = {
	Easy = { Fear = 0.75, Breakdowns = 0.8, Reward = 1, Color = Color3.fromRGB(80, 200, 100) },
	Medium = { Fear = 1, Breakdowns = 1, Reward = 1.5, Color = Color3.fromRGB(240, 190, 40) },
	Hard = { Fear = 1.3, Breakdowns = 1.25, Reward = 2, Color = Color3.fromRGB(240, 110, 40) },
	Extreme = { Fear = 1.6, Breakdowns = 1.5, Reward = 3, Color = Color3.fromRGB(220, 40, 60) },
}

-- Daily quests: each player gets QuestsPerDay random ones every day (UTC).
-- Stat is what counts towards it: Win, WinHard, Fix, Fire, Feed, VIP, Junction, Saved.
-- Hard = true shows a red [Hard] tag in the quest list.
Config.QuestsPerDay = 3
Config.Quests = {
	{ Id = "Win2", Text = "Win 2 rides", Stat = "Win", Goal = 2, Reward = 150 },
	{ Id = "WinHard", Text = "Win a ride on Hard or Extreme", Stat = "WinHard", Goal = 1, Reward = 250, Hard = true },
	{ Id = "Fix10", Text = "Fix 10 breakdowns", Stat = "Fix", Goal = 10, Reward = 120 },
	{ Id = "Fire3", Text = "Put out 3 fires", Stat = "Fire", Goal = 3, Reward = 120 },
	{ Id = "Feed15", Text = "Feed 15 passengers", Stat = "Feed", Goal = 15, Reward = 120 },
	{ Id = "VIP1", Text = "Get a VIP to Midnight Station", Stat = "VIP", Goal = 1, Reward = 150 },
	{ Id = "Junction2", Text = "Pick the right track 2 times", Stat = "Junction", Goal = 2, Reward = 150 },
	{ Id = "Save20", Text = "Save 20 passengers", Stat = "Saved", Goal = 20, Reward = 200, Hard = true },
}
-- Daily login rewards: day 1..7 of a streak (miss a day and it starts over)
Config.DailyRewards = { 50, 75, 100, 150, 200, 250, 500 }

-- Lobby
Config.MaxPartySize = 4
Config.PadLeaveTime = 20 -- seconds a hosted pad waits for more players before departing
-- Rides normally run in their own private server. In Studio (where teleports don't work)
-- or when this is true, rides run inside the lobby server instead, one at a time.
Config.LocalRides = false

-- Players who can open the /admin panel (UserIds). The game's creator always can.
Config.Admins = { 3081589715 }

-- Shop: trains (the host's equipped train is the one everyone rides).
-- Breakdowns: multiplier on how often things break (lower = sturdier train).
Config.Trains = {
	{
		Id = "Rattler", Name = "The Rattler", Rarity = "Common", Price = 0,
		MaxSpeed = 55, Accel = 3.5, Brake = 7, Breakdowns = 1.0,
		Description = "Old, loud, and held together with hope.",
		Accent = Color3.fromRGB(140, 70, 210), Lower = Color3.fromRGB(46, 66, 112),
		SeatA = Color3.fromRGB(236, 132, 38), SeatB = Color3.fromRGB(36, 156, 168), Body = Color3.fromRGB(185, 190, 198),
	},
	{
		Id = "Commuter", Name = "Commuter 200", Rarity = "Common", Price = 600,
		MaxSpeed = 60, Accel = 4, Brake = 8, Breakdowns = 0.95,
		Description = "A bit faster, a bit newer. Still smells weird.",
		Accent = Color3.fromRGB(40, 120, 220), Lower = Color3.fromRGB(40, 50, 70),
		SeatA = Color3.fromRGB(60, 110, 200), SeatB = Color3.fromRGB(120, 130, 145), Body = Color3.fromRGB(210, 214, 220),
	},
	{
		Id = "NightOwl", Name = "Night Owl", Rarity = "Rare", Price = 1800,
		MaxSpeed = 58, Accel = 4, Brake = 9, Breakdowns = 0.8,
		Description = "Built tough for the late shift. Breaks down less.",
		Accent = Color3.fromRGB(50, 210, 180), Lower = Color3.fromRGB(20, 40, 50),
		SeatA = Color3.fromRGB(30, 110, 110), SeatB = Color3.fromRGB(70, 60, 120), Body = Color3.fromRGB(60, 66, 80),
	},
	{
		Id = "Express", Name = "Express X", Rarity = "Epic", Price = 4500,
		MaxSpeed = 70, Accel = 5.5, Brake = 10, Breakdowns = 0.9,
		Description = "Blazing fast. Careful on the curves!",
		Accent = Color3.fromRGB(225, 40, 50), Lower = Color3.fromRGB(30, 30, 34),
		SeatA = Color3.fromRGB(200, 40, 50), SeatB = Color3.fromRGB(235, 235, 240), Body = Color3.fromRGB(240, 240, 245),
	},
	{
		Id = "Ghost", Name = "Ghost Line", Rarity = "Legendary", Price = 12000,
		MaxSpeed = 66, Accel = 5, Brake = 12, Breakdowns = 0.65,
		Description = "Nobody knows who built it. It never seems to break.",
		Accent = Color3.fromRGB(120, 255, 150), Lower = Color3.fromRGB(25, 30, 28),
		SeatA = Color3.fromRGB(50, 60, 55), SeatB = Color3.fromRGB(80, 120, 90), Body = Color3.fromRGB(40, 46, 44),
	},
}
Config.DefaultTrain = "Rattler"
Config.Rarities = {
	Common = Color3.fromRGB(170, 175, 185),
	Rare = Color3.fromRGB(60, 140, 240),
	Epic = Color3.fromRGB(170, 80, 230),
	Legendary = Color3.fromRGB(250, 190, 40),
}

-- Shop: perks you own forever. They work on every ride.
Config.Perks = {
	{ Id = "SmoothTalker", Name = "Smooth Talker", Icon = "💬", Price = 600, Description = "Chatting calms passengers twice as much." },
	{ Id = "BigPockets", Name = "Big Pockets", Icon = "🎒", Price = 800, Description = "Carry 5 items instead of 3." },
	{ Id = "Sprinter", Name = "Sprinter", Icon = "👟", Price = 1000, Description = "Run 25% faster." },
	{ Id = "FastHands", Name = "Fast Hands", Icon = "🔧", Price = 1200, Description = "Fix breakdowns 35% faster." },
}

function Config.FindItem(id)
	for _, train in Config.Trains do
		if train.Id == id then
			return train, "Train"
		end
	end
	for _, perk in Config.Perks do
		if perk.Id == id then
			return perk, "Perk"
		end
	end
	return nil
end

-- 0-100 score shown in the shop (higher = breaks down less)
function Config.BuildQuality(train)
	return math.floor((1.6 - train.Breakdowns) * 100 + 0.5)
end

function Config.MoodFor(fear)
	for _, m in Config.Moods do
		if fear < m.Max then
			return m
		end
	end
	return Config.Moods[#Config.Moods]
end

return Config

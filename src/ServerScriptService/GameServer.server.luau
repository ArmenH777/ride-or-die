-- Ride or Die server.
-- Lobby servers run the boarding pads; each ride normally happens in its own private (reserved) server
-- and players are sent back to a lobby afterwards. In Studio, rides run right here instead.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

PhysicsService:RegisterCollisionGroup("NPC")
PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:CollisionGroupSetCollidable("NPC", "Players", false)
PhysicsService:CollisionGroupSetCollidable("NPC", "NPC", false)

local Config = require(ReplicatedStorage.Config)
local Modules = script.Parent.Modules
local Util = require(Modules.Util)
local Data = require(Modules.Data)
local Train = require(Modules.Train)
local Passengers = require(Modules.Passengers)
local Breakdowns = require(Modules.Breakdowns)
local Items = require(Modules.Items)
local Lobby = require(Modules.Lobby)
local Shop = require(Modules.Shop)
local Quests = require(Modules.Quests)
local Leaderboards = require(Modules.Leaderboards)
local Admin = require(Modules.Admin)

local RoundState = ReplicatedStorage.RoundState
local rideSpawn = workspace.Train.RideSpawn

local isRideServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local useLocalRides = Config.LocalRides or RunService:IsStudio()

local stats = { Fixes = 0, Feeds = 0, ByPlayer = {} }
local difficulty = Config.Difficulties.Easy
local riding = false

local function setState(state)
	RoundState:SetAttribute("State", state)
end

local function liveRiders()
	local list = {}
	for _, player in Util.Riders do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function setRiders(list)
	Util.Riders = list
	for _, player in list do
		player:SetAttribute("PadId", nil)
		player:SetAttribute("InRide", true)
	end
end

------------------------------------------------------------------ players
Data.Init()
Quests.Init()
Players.PlayerAdded:Connect(function(player)
	Util.SetupLeaderstats(player)
	task.spawn(Data.Load, player)
	if isRideServer then
		player:SetAttribute("InRide", true)
		if riding then
			table.insert(Util.Riders, player)
		end
	end
	player.CharacterAdded:Connect(function(character)
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.CollisionGroup = "Players"
			end
		end
		character.DescendantAdded:Connect(function(part)
			if part:IsA("BasePart") then
				part.CollisionGroup = "Players"
			end
		end)
		-- riders appear inside the train instead of the lobby
		if player:GetAttribute("InRide") then
			character:WaitForChild("HumanoidRootPart")
			task.wait()
			character:PivotTo(rideSpawn.CFrame * CFrame.new(math.random(-3, 3), 3.5, math.random(-1, 1)))
		end
	end)
end)

------------------------------------------------------------------ ride hooks
Shop.Init()
Train.Init()
Items.Init()
Breakdowns.Init(Train)
Admin.Train, Admin.Passengers, Admin.Breakdowns = Train, Passengers, Breakdowns
Admin.Init()

Train.OnRanRedSignal = function()
	Util.NotifyAll("Bad", "🚨 You ran a RED SIGNAL! Emergency brakes!")
	local squeal = Util.PlaySound("Brake", workspace.Train.Shell.Floor)
	if squeal then
		squeal.RollOffMinDistance = 70
		task.delay(3.5, function()
			squeal:Destroy()
		end)
	end
	Passengers.AddFearAll(Config.Fear.RedSignal)
	Passengers.React(4)
	Breakdowns.Spawn("Window")
end

Train.OnCurveTooFast = function(announce)
	Passengers.AddFearAll(Config.Fear.CurveTooFast)
	if announce then
		Util.NotifyAll("Bad", "😵 Way too fast on the curve! Passengers are terrified!")
		local squeal = Util.PlaySound("Squeal", workspace.Train.Shell.Floor, 0.1)
		if squeal then
			squeal.RollOffMinDistance = 70
		end
		Passengers.React(1)
	end
	if math.random() < 0.15 then
		Breakdowns.Spawn("Window")
	end
end

Train.OnJunction = function(correct)
	if correct then
		for _, player in liveRiders() do
			Quests.Add(player, "Junction")
		end
	else
		Passengers.React(4)
	end
end

Train.OnCrash = function()
	local floor = workspace.Train.Shell.Floor
	local crash = Util.PlaySound("Crash", floor)
	if crash then
		crash.RollOffMinDistance = 80
	end
	Util.PlaySound("Glass", floor)
	Util.NotifyAll("Bad", "💥 CRASH! The train hit the dead end!")
	for _ = 1, 3 do
		Breakdowns.Spawn("Window")
	end
	Passengers.React(8)
end

-- per-player counts for the results screen's MVP
local function credit(player, key)
	local mine = stats.ByPlayer[player] or { Fixes = 0, Feeds = 0 }
	mine[key] += 1
	stats.ByPlayer[player] = mine
end

Breakdowns.OnFixed = function(player, kind)
	stats.Fixes += 1
	credit(player, "Fixes")
	Quests.Add(player, "Fix")
	if kind == "Fire" then
		Quests.Add(player, "Fire")
	end
end
Breakdowns.OnBroke = function(kind)
	Passengers.React(kind == "Power" and 3 or 1)
end
Passengers.OnFed = function(player)
	stats.Feeds += 1
	credit(player, "Feeds")
	Quests.Add(player, "Feed")
end

------------------------------------------------------------------ one ride
local function resetRound(playerCount)
	Breakdowns.Reset()
	Train.Reset()
	stats = { Fixes = 0, Feeds = 0, ByPlayer = {} }
	Admin.ForcedResult = nil
	local count = math.min(Config.MaxPassengers, Config.BasePassengers + Config.PassengersPerExtraPlayer * (playerCount - 1))
	Passengers.Scale = (1 + Config.Fear.PerExtraPlayer * (playerCount - 1)) * difficulty.Fear
	Passengers.Spawn(count)
	for _, player in liveRiders() do
		task.spawn(player.LoadCharacter, player)
	end
	for _, key in { "Result", "Saved", "Reward", "Fixes", "Feeds", "RideTime", "VIPBonus", "Stars", "MVP", "MVPLine" } do
		RoundState:SetAttribute(key, nil)
	end
end

local function runRide(playerCount)
	local elapsed = 0
	local nextBreakdown = Config.FirstBreakdownAt / difficulty.Breakdowns
	local publishTimer = 0
	while true do
		local dt = RunService.Heartbeat:Wait()
		local now = os.clock()
		elapsed += dt

		-- Studio testing shortcut: set the workspace attribute DebugDistance to jump the train ahead (in miles)
		local jump = RunService:IsStudio() and workspace:GetAttribute("DebugDistance")
		if jump then
			workspace:SetAttribute("DebugDistance", nil)
			Train.Distance = jump
		end

		local arrived = Train.Update(dt, now)
		Passengers.Update(dt, now, Breakdowns.FearRate() * difficulty.Fear)
		Breakdowns.Update(dt)

		local progress = Train.Distance / Config.RouteMiles
		if elapsed >= nextBreakdown then
			local maxActive = 1 + math.floor(progress * 3) + (playerCount >= 3 and 1 or 0)
			if Breakdowns.ActiveCount() < maxActive then
				Breakdowns.Spawn()
			end
			local range = Config.BreakdownInterval
			local interval = range[1] + (range[2] - range[1]) * progress
			interval = interval / (1 + 0.15 * (playerCount - 1)) / (difficulty.Breakdowns * Train.Stats.Breakdowns) * (0.8 + math.random() * 0.4)
			nextBreakdown = elapsed + interval
		end

		publishTimer += dt
		if publishTimer >= 0.1 or arrived then
			publishTimer = 0
			Train.Publish()
		end

		if Train.Crashed then
			Train.Publish()
			task.wait(2.5) -- let the crash sink in before the results
			return "Crash", elapsed
		end
		if arrived then
			return "Win", elapsed
		end
		if Passengers.AliveCount() == 0 then
			return "Lose", elapsed
		end
		if Admin.ForcedResult then
			local forced = Admin.ForcedResult
			Admin.ForcedResult = nil
			return forced, elapsed
		end
		if #liveRiders() == 0 then
			return "Abandoned", elapsed
		end
	end
end

-- Runs countdown -> ride -> results for these players.
local function runRound(players, settings)
	local difficultyName = Config.Difficulties[settings.Difficulty] and settings.Difficulty or "Easy"
	difficulty = Config.Difficulties[difficultyName]
	RoundState:SetAttribute("Difficulty", difficultyName)
	local trainDef, kind = Config.FindItem(settings.Train or "")
	if kind ~= "Train" then
		trainDef = Config.FindItem(Config.DefaultTrain)
	end
	Train.SetModel(trainDef)
	riding = true
	setRiders(players)

	local playerCount = math.max(1, #players)
	resetRound(playerCount)
	setState("Countdown")
	for t = Config.CountdownTime, 1, -1 do
		RoundState:SetAttribute("Countdown", t)
		task.wait(1)
	end

	setState("Running")
	Util.NotifyAll("Info", "🚇 Doors closing! Someone get in the driver's seat!")
	if Passengers.VIPSafe() ~= nil then
		local bonus = math.floor(Config.VIP.Bonus * difficulty.Reward)
		task.delay(3, Util.NotifyAll, "Good", "⭐ A VIP is on board! Get them to Midnight Station for +" .. bonus .. " Tokens each!")
	end
	local result, rideTime = runRide(playerCount)
	Train.Speed = 0
	Train.Input = 0
	Train.Publish()

	local saved = Passengers.AliveCount()
	local reward = 0
	local vipBonus = 0
	if result == "Win" then
		reward = math.floor((Config.Rewards.Win + Config.Rewards.PerPassenger * saved) * difficulty.Reward)
		if Passengers.VIPSafe() then
			vipBonus = math.floor(Config.VIP.Bonus * difficulty.Reward)
		end
		local hard = difficultyName == "Hard" or difficultyName == "Extreme"
		for _, player in liveRiders() do
			Util.AddTokens(player, reward + vipBonus)
			local wins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Wins")
			if wins then
				wins.Value += 1
			end
			Quests.Add(player, "Win")
			Quests.Add(player, "Saved", saved)
			if hard then
				Quests.Add(player, "WinHard")
			end
			if vipBonus > 0 then
				Quests.Add(player, "VIP")
			end
		end
	end
	-- stars: 1 = made it, 2 = saved at least 80%, 3 = saved everyone (and the VIP, if there was one)
	local stars = 0
	if result == "Win" then
		local total = RoundState:GetAttribute("PassengersTotal") or saved
		stars = 1
		if saved >= math.ceil(total * 0.8) then
			stars = 2
		end
		if saved >= total and Passengers.VIPSafe() ~= false then
			stars = 3
		end
	end
	RoundState:SetAttribute("Stars", stars)

	-- MVP: whoever fixed + fed the most
	local mvp, best = nil, 0
	for _, player in liveRiders() do
		local mine = stats.ByPlayer[player]
		local score = mine and (mine.Fixes + mine.Feeds) or 0
		if score > best then
			mvp, best = player, score
		end
	end
	if mvp then
		local mine = stats.ByPlayer[mvp]
		RoundState:SetAttribute("MVP", mvp.DisplayName)
		RoundState:SetAttribute("MVPLine", mine.Fixes .. (mine.Fixes == 1 and " fix" or " fixes") .. ", " .. mine.Feeds .. (mine.Feeds == 1 and " snack" or " snacks"))
	end

	-- personal best time for this difficulty (saved by Data as Best_<Difficulty>)
	for _, player in liveRiders() do
		local key = "Best_" .. difficultyName
		local old = player:GetAttribute(key)
		local newBest = result == "Win" and (not old or rideTime < old)
		if newBest then
			player:SetAttribute(key, math.floor(rideTime))
		end
		player:SetAttribute("LastNewBest", newBest or nil)
	end

	RoundState:SetAttribute("VIPBonus", vipBonus)
	RoundState:SetAttribute("Result", result)
	RoundState:SetAttribute("Saved", saved)
	RoundState:SetAttribute("Reward", reward)
	RoundState:SetAttribute("Fixes", stats.Fixes)
	RoundState:SetAttribute("Feeds", stats.Feeds)
	RoundState:SetAttribute("RideTime", math.floor(rideTime))
	setState("Ended")
	task.wait(Config.ResultsTime)
	Breakdowns.Reset()
	riding = false
end

------------------------------------------------------------------ server modes
if isRideServer then
	-- Wait for the party that was sent here, then ride and send everyone back to a lobby.
	while #Players:GetPlayers() == 0 do
		task.wait(0.5)
	end
	local joinData = Players:GetPlayers()[1]:GetJoinData()
	local data = type(joinData.TeleportData) == "table" and joinData.TeleportData or {}
	local expected = tonumber(data.Expected) or 1
	local deadline = os.clock() + 15
	while #Players:GetPlayers() < expected and os.clock() < deadline do
		task.wait(0.5)
	end

	while #Players:GetPlayers() > 0 do
		runRound(Players:GetPlayers(), { Difficulty = data.Difficulty, Train = data.Train })
		setState("Returning")
		local everyone = Players:GetPlayers()
		for _, player in everyone do
			Data.Save(player)
		end
		local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, everyone)
		if not ok then
			warn("[GameServer] Could not send players back to the lobby:", err)
		end
		task.wait(15) -- if anyone is still here (teleport failed), give them another ride
	end
else
	setState("Idle")
	Leaderboards.Init()
	Lobby.OnLaunch = function(players, settings)
		local party = {}
		for _, player in players do
			if player.Parent then
				table.insert(party, player)
			end
		end
		if #party == 0 then
			return
		end

		if useLocalRides then
			Lobby.Busy = true
			task.spawn(function()
				runRound(party, settings)
				-- back to the lobby
				local finished = liveRiders()
				Util.Riders = {}
				for _, player in finished do
					player:SetAttribute("InRide", nil)
					task.spawn(player.LoadCharacter, player)
				end
				setState("Idle")
				Lobby.Busy = false
			end)
			return
		end

		for _, player in party do
			Util.Notify(player, "Info", "🚇 Boarding the train...")
			Data.Save(player)
		end
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = true
		options:SetTeleportData({ Difficulty = settings.Difficulty, Train = settings.Train, Expected = #party })
		local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, party, options)
		if not ok then
			warn("[GameServer] Teleport failed:", err)
			for _, player in party do
				Util.Notify(player, "Bad", "Couldn't reach the train. Try again in a moment!")
			end
		end
	end
	Lobby.Init()
end

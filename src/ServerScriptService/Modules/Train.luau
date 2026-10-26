-- Driving: throttle, speed, distance, red signals, curves and track junctions.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Config)
local Util = require(script.Parent.Util)

local Remotes = ReplicatedStorage.Remotes
local RoundState = ReplicatedStorage.RoundState
local cab = workspace.Train.Cab
local seat = cab.DriverSeat

local Train = {
	Speed = 0,
	Distance = 0,
	Throttle = 0,
	Input = 0,
	Power = true,
	Events = {},
	EmergencyUntil = 0,
	CurveOverspeed = 0,
	CurveWarnAt = 0,
	-- set from the ridden train's shop stats
	Stats = { MaxSpeed = Config.MaxSpeed, Accel = Config.Accel, Brake = Config.Brake, Breakdowns = 1 },
	Switch = "Right", -- which way the track switch points ("Left" / "Right")
	Crashed = false,
	-- set by GameServer
	OnRanRedSignal = nil,
	OnCurveTooFast = nil,
	OnJunction = nil, -- function(correct)
	OnCrash = nil,
}

local LEVER_PIVOT = cab.LeverBase.Position + Vector3.new(0, 0.25, 0)

local function updateLever()
	local angle = math.rad(-40 + 80 * Train.Throttle)
	local pivot = CFrame.new(LEVER_PIVOT) * CFrame.Angles(0, 0, -angle)
	cab.LeverStick.CFrame = pivot * CFrame.new(0, 0.7, 0)
	cab.LeverKnob.CFrame = pivot * CFrame.new(0, 1.4, 0)
end

local SWITCH_PIVOT = cab.SwitchBase.Position + Vector3.new(0, 0.25, 0)
local function updateSwitchLever()
	-- tilts toward the side the track will go (left = -Z when facing forward)
	local angle = math.rad(Train.Switch == "Left" and -35 or 35)
	local pivot = CFrame.new(SWITCH_PIVOT) * CFrame.Angles(angle, 0, 0)
	cab.SwitchStick.CFrame = pivot * CFrame.new(0, 0.6, 0)
	cab.SwitchKnob.CFrame = pivot * CFrame.new(0, 1.2, 0)
end

function Train.SetSwitch(side)
	if side ~= "Left" and side ~= "Right" or side == Train.Switch then
		return
	end
	Train.Switch = side
	RoundState:SetAttribute("Switch", side)
	updateSwitchLever()
	Util.PlaySound("Switch", cab.SwitchBase)
end

-- Spread curves and signals along the route, away from stations and each other.
local function generateEvents()
	local taken = {}
	local function freeSpot()
		for _ = 1, 300 do
			local mile = 0.4 + math.random() * (Config.RouteMiles - 0.9)
			local ok = true
			for _, station in Config.Stations do
				if math.abs(station.Mile - mile) < 0.2 then
					ok = false
				end
			end
			for _, other in taken do
				if math.abs(other - mile) < 0.3 then
					ok = false
					break
				end
			end
			if ok then
				table.insert(taken, mile)
				return mile
			end
		end
		return nil
	end

	local events = {}
	for _ = 1, Config.Curves do
		local mile = freeSpot()
		if mile then
			local direction = math.random() < 0.5 and -1 or 1
			table.insert(events, { Type = "Curve", Start = mile, End = mile + 0.12 + math.random() * 0.06, Limit = Config.CurveLimit, Dir = direction })
		end
	end
	for _ = 1, Config.Signals do
		local mile = freeSpot()
		if mile then
			table.insert(events, { Type = "Signal", Mile = mile })
		end
	end
	for i = 1, Config.Splits do
		local mile = freeSpot()
		if mile then
			table.insert(events, { Type = "Split", Mile = mile, Id = i, Correct = math.random() < 0.5 and "Left" or "Right" })
		end
	end
	table.sort(events, function(a, b)
		return (a.Mile or a.Start) < (b.Mile or b.Start)
	end)
	local signalId = 0
	for _, event in events do
		if event.Type == "Signal" then
			signalId += 1
			event.Id = signalId
		end
	end
	return events
end

function Train.Publish()
	RoundState:SetAttribute("Speed", math.floor(Train.Speed * 10 + 0.5) / 10)
	RoundState:SetAttribute("Distance", Train.Distance)
	RoundState:SetAttribute("Throttle", Train.Throttle)
	RoundState:SetAttribute("Power", Train.Power)
	updateLever()
end

function Train.Reset()
	Train.Speed = 0
	Train.Distance = 0
	Train.Throttle = 0
	Train.Input = 0
	Train.Power = true
	Train.EmergencyUntil = 0
	Train.CurveOverspeed = 0
	Train.Crashed = false
	Train.Events = generateEvents()
	Train.Switch = math.random() < 0.5 and "Left" or "Right"
	RoundState:SetAttribute("Switch", Train.Switch)
	RoundState:SetAttribute("SplitWrong", nil)
	for i = 1, Config.Splits do
		RoundState:SetAttribute("SplitTaken" .. i, nil)
	end
	updateSwitchLever()

	local shared = {}
	for _, event in Train.Events do
		table.insert(shared, { Type = event.Type, Mile = event.Mile, Start = event.Start, End = event.End, Limit = event.Limit, Dir = event.Dir, Id = event.Id, Correct = event.Correct })
		if event.Type == "Signal" then
			event.State = "Red"
			RoundState:SetAttribute("Signal" .. event.Id, "Red")
		end
	end
	RoundState:SetAttribute("TrackEvents", HttpService:JSONEncode(shared))
	Train.Publish()
end

-- Uses a train from Config.Trains: its stats for driving and its colours for the car.
function Train.SetModel(def)
	Train.Stats = { MaxSpeed = def.MaxSpeed, Accel = def.Accel, Brake = def.Brake, Breakdowns = def.Breakdowns }
	RoundState:SetAttribute("TrainName", def.Name)
	RoundState:SetAttribute("MaxSpeed", def.MaxSpeed)
	local model = workspace.Train
	for _, part in model.Shell:GetChildren() do
		if part.Name == "Stripe" then
			part.Color = def.Accent
		elseif part.Name == "WallLow" then
			part.Color = def.Lower
		end
	end
	for _, part in model.Interior:GetChildren() do
		if part.Name == "Cushion" or part.Name == "Backrest" then
			local middle = part.Position.X > -17 and part.Position.X < 11
			part.Color = middle and def.SeatB or def.SeatA
		end
	end
end

function Train.SetPower(on)
	Train.Power = on
	RoundState:SetAttribute("Power", on)
end

-- Returns the curve the train is in right now (or nil).
function Train.CurrentCurve()
	for _, event in Train.Events do
		if event.Type == "Curve" and Train.Distance >= event.Start and Train.Distance <= event.End then
			return event
		end
	end
	return nil
end

-- Advances the train. Returns true once it has arrived at the last station.
function Train.Update(dt, now)
	Train.Throttle = math.clamp(Train.Throttle + Train.Input * Config.ThrottleRate * dt, 0, 1)

	local stats = Train.Stats
	local target = Train.Power and Train.Throttle * stats.MaxSpeed or 0
	local decel = Train.Power and stats.Brake or Config.Coast
	if now < Train.EmergencyUntil then
		target = 0
		decel = 20
	end

	-- automatic slow-down into the final station
	local remaining = Config.RouteMiles - Train.Distance
	if remaining < 0.25 then
		target = math.min(target, math.max(10, remaining / 0.25 * 35))
	end

	if Train.Speed < target then
		Train.Speed = math.min(target, Train.Speed + stats.Accel * dt)
	else
		Train.Speed = math.max(target, Train.Speed - decel * dt)
	end

	local before = Train.Distance
	local after = before + Train.Speed / 3600 * dt

	for _, event in Train.Events do
		if event.Type == "Signal" and not event.Passed then
			local ahead = event.Mile - before
			if not event.GreenAt and ahead < 0.3 then
				event.GreenAt = now + 10 + math.random() * 6
				Util.NotifyAll("Warn", "🚦 RED SIGNAL ahead! Slow down and wait for green!")
			end
			if event.State == "Red" and event.GreenAt and now >= event.GreenAt then
				event.State = "Green"
				RoundState:SetAttribute("Signal" .. event.Id, "Green")
				Util.NotifyAll("Good", "🟢 Signal is GREEN. Go go go!")
			end
			if before < event.Mile and after >= event.Mile then
				if event.State == "Green" then
					event.Passed = true
				elseif Train.Speed > 3 then
					event.Passed = true
					Train.EmergencyUntil = now + 4
					if Train.OnRanRedSignal then
						Train.OnRanRedSignal()
					end
				else
					-- crawled up to the red signal: wait here
					after = event.Mile - 0.0005
					Train.Speed = 0
				end
			end
		elseif event.Type == "Curve" and not event.Warned and event.Start - before < 0.2 then
			event.Warned = true
			Util.NotifyAll("Warn", "↪ SHARP CURVE ahead! Slow down to " .. event.Limit .. " mph!")
		elseif event.Type == "Split" then
			if not event.Warned and event.Mile - before < Config.SplitWarning then
				event.Warned = true
				Util.NotifyAll("Bad", "⚠ JUNCTION AHEAD! Take the " .. event.Correct:upper() .. " track! (driver: A / D)", "Buzzer")
			end
			if not event.Taken and before < event.Mile and after >= event.Mile then
				event.Taken = Train.Switch
				RoundState:SetAttribute("SplitTaken" .. event.Id, event.Taken)
				if event.Taken == event.Correct then
					Util.NotifyAll("Good", "✔ Right track! Nice driving!")
					if Train.OnJunction then
						Train.OnJunction(true)
					end
				else
					event.WrongAt = now
					RoundState:SetAttribute("SplitWrong", event.Id)
					Util.NotifyAll("Bad", "❌ WRONG TRACK! DEAD END AHEAD!", "Buzzer")
					if Train.OnJunction then
						Train.OnJunction(false)
					end
				end
			end
			-- the wrong branch ends in a wall a little way past the junction
			if event.WrongAt and not Train.Crashed and (after >= event.Mile + 0.02 or now >= event.WrongAt + 2.5) then
				Train.Crashed = true
				Train.Speed = 0
				after = math.max(after, event.Mile + 0.02)
				if Train.OnCrash then
					Train.OnCrash()
				end
			end
		end
	end
	Train.Distance = after

	local curve = Train.CurrentCurve()
	if curve and Train.Speed > curve.Limit + 3 then
		Train.CurveOverspeed += dt
		if Train.CurveOverspeed >= 1 then
			Train.CurveOverspeed -= 1
			if Train.OnCurveTooFast then
				Train.OnCurveTooFast(now >= Train.CurveWarnAt)
			end
			if now >= Train.CurveWarnAt then
				Train.CurveWarnAt = now + 3
			end
		end
	else
		Train.CurveOverspeed = 0
	end

	if Train.Distance >= Config.RouteMiles then
		Train.Distance = Config.RouteMiles
		Train.Speed = 0
		return true
	end
	return false
end

function Train.Init()
	Remotes.DriverInput.OnServerEvent:Connect(function(player, input)
		if typeof(input) ~= "number" then
			return
		end
		local occupant = seat.Occupant
		if occupant and occupant.Parent == player.Character then
			Train.Input = math.clamp(math.round(input), -1, 1)
		end
	end)

	Remotes.SwitchTrack.OnServerEvent:Connect(function(player, side)
		local occupant = seat.Occupant
		if occupant and occupant.Parent == player.Character then
			Train.SetSwitch(side)
		end
	end)

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		Train.Input = 0
		local occupant = seat.Occupant
		local player = occupant and game.Players:GetPlayerFromCharacter(occupant.Parent)
		RoundState:SetAttribute("Driver", player and player.DisplayName or "")
	end)
	RoundState:SetAttribute("Driver", "")

	local horn = cab.HornButton.Prompt
	local hornCooldown = 0
	horn.Triggered:Connect(function()
		if os.clock() < hornCooldown then
			return
		end
		hornCooldown = os.clock() + 2.5
		local sound = Util.PlaySound("Horn", cab.HornButton)
		if sound then
			sound.RollOffMinDistance = 80
			-- the clip has several blasts; keep only the first one
			task.delay(2, function()
				TweenService:Create(sound, TweenInfo.new(0.4), { Volume = 0 }):Play()
				task.wait(0.45)
				sound:Destroy()
			end)
		end
		Remotes.Horn:FireAllClients()
	end)

	Train.Reset()
end

return Train

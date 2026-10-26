-- Breakdowns: broken windows, leaking pipes, stuck doors, power cuts and vent fires.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Config)
local Util = require(script.Parent.Util)

local RoundState = ReplicatedStorage.RoundState
local train = workspace.Train

local Breakdowns = {
	Spots = {}, -- every place something can break
	-- set by GameServer
	Train = nil,
	OnFixed = nil,
	OnBroke = nil,
}

local powerAlarm = nil

local function toolName(id)
	local template = ServerStorage.Items:FindFirstChild(id)
	return template and template:GetAttribute("DisplayName") or id
end

local function makePrompt(parent, kind)
	local cfg = Config.Breakdowns[kind]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FixPrompt"
	prompt.ActionText = cfg.Action
	prompt.ObjectText = cfg.Tool and ("Needs " .. toolName(cfg.Tool)) or ""
	prompt.HoldDuration = cfg.Hold
	prompt:SetAttribute("BaseHold", cfg.Hold) -- the Fast Hands perk shortens this on the player's screen
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Enabled = false
	prompt.Parent = parent
	return prompt
end

local function wind(parent)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Wind"
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 210, 220))
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) })
	pe.Size = NumberSequence.new(0.08)
	pe.Lifetime = NumberRange.new(0.4, 0.7)
	pe.Rate = 60
	pe.Speed = NumberRange.new(20, 30)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.EmissionDirection = Enum.NormalId.Front
	pe.Parent = parent
	return pe
end

local function tween(instance, time, goal)
	TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Quad), goal):Play()
end

local function removeTape(glass)
	for _, child in glass:GetChildren() do
		if child.Name == "Tape" then
			child:Destroy()
		end
	end
end

------------------------------------------------------------------ spot types

local Handlers = {}

Handlers.Window = {
	Activate = function(spot)
		local glass = spot.Part
		Util.PlaySound("Glass", spot.Attachment, 0.1)
		removeTape(glass) -- an old repair shatters along with the glass
		glass.Transparency = 1
		spot.Effects = { wind(spot.Attachment) }
		for _ = 1, 3 do
			local shard = Instance.new("WedgePart")
			shard.Size = Vector3.new(0.1, 0.6 + math.random() * 0.8, 0.5 + math.random() * 0.8)
			shard.Color = glass.Color
			shard.Material = Enum.Material.Glass
			shard.Transparency = 0.4
			shard.Anchored = true
			shard.CanCollide = false
			local corner = Vector3.new((math.random() - 0.5) * glass.Size.X * 0.8, (math.random() < 0.5 and -1 or 1) * glass.Size.Y * 0.38, 0)
			shard.CFrame = glass.CFrame * CFrame.new(corner) * CFrame.Angles(0, math.rad(90), math.rad(math.random(0, 360)))
			shard.Parent = glass
			table.insert(spot.Effects, shard)
		end
	end,
	Fix = function(spot)
		spot.Part.Transparency = spot.Original
		Util.PlaySound("Tape", spot.Attachment, 0.1)
		-- leave a taped X on the window until the next ride
		for _, angle in { 35, -35 } do
			local tape = Instance.new("Part")
			tape.Name = "Tape"
			tape.Size = Vector3.new(5.6, 0.35, 0.36)
			tape.Color = Color3.fromRGB(165, 168, 172)
			tape.Material = Enum.Material.Fabric
			tape.Anchored = true
			tape.CanCollide = false
			tape.CFrame = spot.Part.CFrame * CFrame.Angles(0, 0, math.rad(angle))
			tape.Parent = spot.Part
		end
	end,
	Reset = function(spot)
		spot.Part.Transparency = spot.Original
		removeTape(spot.Part)
	end,
}

Handlers.Leak = {
	Activate = function(spot)
		spot.Model.Vent.Drip.Drip.Enabled = true
		spot.Grow = 0
		spot.Model.Puddle.Transparency = 0.35
	end,
	Update = function(spot, dt)
		spot.Grow = math.min(1, spot.Grow + dt / 30)
		local d = 0.5 + spot.Grow * 6.5
		spot.Model.Puddle.Size = Vector3.new(0.1, d, d)
	end,
	Fix = function(spot)
		spot.Model.Vent.Drip.Drip.Enabled = false
		Util.PlaySound("Ratchet", spot.Model.Spot, 0.05)
		tween(spot.Model.Puddle, 1.5, { Transparency = 1, Size = Vector3.new(0.1, 0.5, 0.5) })
	end,
	Reset = function(spot)
		spot.Model.Vent.Drip.Drip.Enabled = false
		spot.Model.Puddle.Transparency = 1
		spot.Model.Puddle.Size = Vector3.new(0.1, 0.5, 0.5)
	end,
}

local function slideDoor(spot, open)
	local offset = open and 2.8 or 0
	for _, part in spot.Model:GetChildren() do
		local home = spot.Home[part]
		if home then
			local dir = part.Name:sub(1, 6) == "PanelL" and -1 or 1
			tween(part, 0.6, { CFrame = home * CFrame.new(dir * offset, 0, 0) })
		end
	end
end

Handlers.Door = {
	Activate = function(spot)
		slideDoor(spot, true)
		Util.PlaySound("DoorOpen", spot.Model.Spot)
		spot.Effects = { wind(spot.Attachment) }
	end,
	Fix = function(spot)
		slideDoor(spot, false)
		Util.PlaySound("DoorClose", spot.Model.Spot)
	end,
	Reset = function(spot)
		for part, home in spot.Home do
			part.CFrame = home
		end
	end,
}

local lights = train.Lights
local LIGHT_ON = Color3.fromRGB(255, 246, 228)
local function setPower(on)
	Breakdowns.Train.SetPower(on)
	for _, strip in lights:GetChildren() do
		if strip:IsA("BasePart") then
			strip.Color = on and LIGHT_ON or Color3.fromRGB(60, 60, 64)
			strip.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			local light = strip:FindFirstChildOfClass("SurfaceLight")
			if light then
				light.Enabled = on
			end
		end
	end
	for _, e in lights.EmergencyLights:GetChildren() do
		e.Color = on and Color3.fromRGB(90, 20, 20) or Color3.fromRGB(255, 40, 30)
		e.Material = on and Enum.Material.SmoothPlastic or Enum.Material.Neon
		e.PointLight.Enabled = not on
	end
	for _, hl in train.Cab:GetChildren() do
		if hl.Name == "Headlight" then
			hl.SpotLight.Enabled = on
			hl.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
	local lever = train.BreakerBox.Lever
	lever.Color = on and Color3.fromRGB(60, 200, 80) or Color3.fromRGB(220, 40, 40)
	lever.CFrame = CFrame.new(32.8, on and 15.3 or 14.7, -4.6)
end

local function stopAlarm()
	if powerAlarm then
		powerAlarm:Destroy()
		powerAlarm = nil
	end
end

Handlers.Power = {
	Activate = function()
		setPower(false)
		Util.PlaySound("PowerDown", train.BreakerBox.Box)
		stopAlarm()
		-- alarm rings through the whole car until someone flips the breaker
		powerAlarm = Util.PlaySound("PowerAlarm", train.Shell.Ceiling)
		if powerAlarm then
			powerAlarm.RollOffMinDistance = 70
		end
	end,
	Fix = function()
		setPower(true)
		stopAlarm()
		Util.PlaySound("Switch", train.BreakerBox.Box)
	end,
	Reset = function()
		setPower(true)
		stopAlarm()
	end,
}

local function setFire(spot, on)
	local flame = spot.Model.Flame
	flame.Fire.Enabled = on
	flame.Smoke.Enabled = on
	flame.Glow.Enabled = on
	spot.Model.Vent.Color = on and Color3.fromRGB(60, 30, 20) or Color3.fromRGB(80, 84, 92)
	if spot.Loop then
		spot.Loop:Destroy()
		spot.Loop = nil
	end
	if on then
		spot.Loop = Util.PlaySound("FireLoop", flame)
	end
end

Handlers.Fire = {
	Activate = function(spot)
		spot.Burn = 0
		spot.Spread = false
		setFire(spot, true)
	end,
	Update = function(spot, dt)
		spot.Burn += dt
		spot.Model.Flame.Glow.Brightness = 2 + math.noise(os.clock() * 6, spot.Burn) * 1.5
		-- an ignored fire spreads to another vent
		if not spot.Spread and spot.Burn >= Config.FireSpreadTime then
			spot.Spread = true
			task.defer(function()
				if spot.Active and Breakdowns.Spawn("Fire") then
					Util.NotifyAll("Bad", "🔥 The fire is SPREADING!")
				end
			end)
		end
	end,
	Fix = function(spot)
		setFire(spot, false)
		spot.Model.Flame.Spray:Emit(40)
		Util.PlaySound("Spray", spot.Model.Spot)
	end,
	Reset = function(spot)
		setFire(spot, false)
	end,
}

------------------------------------------------------------------ core

local function publish()
	local counts = {}
	for _, spot in Breakdowns.Spots do
		if spot.Active then
			counts[spot.Kind] = (counts[spot.Kind] or 0) + 1
		end
	end
	RoundState:SetAttribute("Breakdowns", HttpService:JSONEncode(counts))
end

local function clearEffects(spot)
	if spot.Effects then
		for _, e in spot.Effects do
			e:Destroy()
		end
	end
	spot.Effects = nil
end

local function fix(spot, player)
	if not spot.Active then
		return
	end
	spot.Active = false
	spot.Prompt.Enabled = false
	clearEffects(spot)
	Handlers[spot.Kind].Fix(spot)
	publish()
	Util.AddTokens(player, Config.Rewards.Fix)
	Util.NotifyAll("Good", "🔧 " .. player.DisplayName .. " fixed it: " .. Config.Breakdowns[spot.Kind].Action:lower() .. "! (+" .. Config.Rewards.Fix .. " Tokens)")
	if Breakdowns.OnFixed then
		Breakdowns.OnFixed(player, spot.Kind)
	end
end

local function addSpot(kind, data, promptParent)
	data.Kind = kind
	data.Active = false
	data.Prompt = makePrompt(promptParent, kind)
	local cfg = Config.Breakdowns[kind]
	-- the right tool has to be in your hand, not just in your bag
	data.Prompt.PromptButtonHoldBegan:Connect(function(player)
		if cfg.Tool and not Util.FindHeld(player, cfg.Tool) then
			local name = toolName(cfg.Tool)
			if Util.FindItem(player, cfg.Tool) then
				Util.Notify(player, "Warn", "Hold the " .. name .. " to do this! (pick it in your hotbar)")
			else
				Util.Notify(player, "Warn", "You need the " .. name .. "! Grab it from " .. (Config.ToolHints[cfg.Tool] or "the back of the car") .. ".")
			end
		end
	end)
	data.Prompt.Triggered:Connect(function(player)
		if cfg.Tool and not Util.FindHeld(player, cfg.Tool) then
			return
		end
		fix(data, player)
	end)
	table.insert(Breakdowns.Spots, data)
end

function Breakdowns.Init(trainModule)
	Breakdowns.Train = trainModule

	for _, glass in train.Windows:GetChildren() do
		local att = Instance.new("Attachment")
		att.Name = "FixPoint"
		local inward = glass.Position.Z > 0 and -1 or 1
		att.CFrame = CFrame.lookAt(Vector3.new(0, -1, inward * 1.2), Vector3.new(0, -1, inward * 5))
		att.Parent = glass
		addSpot("Window", { Part = glass, Attachment = att, Original = glass.Transparency }, att)
	end

	for _, leak in train.Leaks:GetChildren() do
		addSpot("Leak", { Model = leak }, leak.Spot)
	end

	for _, door in train.Doors:GetChildren() do
		local home = {}
		for _, part in door:GetChildren() do
			if part:IsA("BasePart") and part.Name:sub(1, 5) == "Panel" then
				home[part] = part.CFrame
			end
		end
		local att = Instance.new("Attachment")
		att.Name = "WindPoint"
		local inward = door:GetAttribute("Side") == 1 and -1 or 1
		att.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, inward))
		att.Parent = door.Spot
		addSpot("Door", { Model = door, Home = home, Attachment = att }, door.Spot)
	end

	addSpot("Power", {}, train.BreakerBox.Spot)

	for _, vent in train.FireVents:GetChildren() do
		addSpot("Fire", { Model = vent }, vent.Spot)
	end
	publish()
end

function Breakdowns.ActiveCount()
	local n = 0
	for _, spot in Breakdowns.Spots do
		if spot.Active then
			n += 1
		end
	end
	return n
end

-- Extra fear per second caused by everything that's currently broken.
function Breakdowns.FearRate()
	local rate = 0
	for _, spot in Breakdowns.Spots do
		if spot.Active then
			rate += Config.Breakdowns[spot.Kind].Fear
		end
	end
	return rate
end

-- Breaks something. Pass a kind ("Window", "Leak", "Door", "Power", "Fire") or nil for a random one.
function Breakdowns.Spawn(kind)
	local free = {}
	for _, spot in Breakdowns.Spots do
		if not spot.Active and (kind == nil or spot.Kind == kind) then
			free[spot.Kind] = free[spot.Kind] or {}
			table.insert(free[spot.Kind], spot)
		end
	end
	if not kind then
		local total = 0
		for k in free do
			total += Config.Breakdowns[k].Weight
		end
		if total == 0 then
			return false
		end
		local roll = math.random() * total
		for k in free do
			roll -= Config.Breakdowns[k].Weight
			if roll <= 0 then
				kind = k
				break
			end
		end
	end
	local options = free[kind]
	if not options then
		return false
	end
	local spot = options[math.random(1, #options)]
	spot.Active = true
	spot.Prompt.Enabled = true
	Handlers[kind].Activate(spot)
	publish()
	Util.NotifyAll("Bad", "⚠ " .. Config.Breakdowns[kind].Label, "Buzzer")
	if Breakdowns.OnBroke then
		Breakdowns.OnBroke(kind)
	end
	return true
end

function Breakdowns.Update(dt)
	for _, spot in Breakdowns.Spots do
		local handler = Handlers[spot.Kind]
		if spot.Active and handler.Update then
			handler.Update(spot, dt)
		end
	end
end

function Breakdowns.Reset()
	for _, spot in Breakdowns.Spots do
		spot.Active = false
		spot.Prompt.Enabled = false
		clearEffects(spot)
		Handlers[spot.Kind].Reset(spot)
	end
	publish()
end

return Breakdowns

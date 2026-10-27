-- Passengers: they sit, get scared, want snacks, and flee if they panic.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Config)
local Util = require(script.Parent.Util)

local RoundState = ReplicatedStorage.RoundState
local anchors = workspace.Train.SeatAnchors

local SIT_ANIM = "rbxassetid://2506281703"
local WALK_ANIM = "rbxassetid://507777826"
local EXIT_POINT = Vector3.new(-46.5, 10, 0)

local SKIN = {
	Color3.fromRGB(255, 220, 185), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(150, 100, 70), Color3.fromRGB(105, 70, 50), Color3.fromRGB(245, 205, 48),
}
local SHIRTS = {
	Color3.fromRGB(200, 60, 60), Color3.fromRGB(60, 110, 200), Color3.fromRGB(70, 160, 90), Color3.fromRGB(240, 170, 40),
	Color3.fromRGB(150, 80, 190), Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 40, 46), Color3.fromRGB(230, 120, 170),
}
local PANTS = {
	Color3.fromRGB(40, 50, 90), Color3.fromRGB(30, 30, 34), Color3.fromRGB(110, 90, 70), Color3.fromRGB(80, 85, 95),
}

local Passengers = {
	List = {},
	Scale = 1,
	-- set by GameServer
	OnFed = nil,
}

local folder = workspace:FindFirstChild("Passengers") or Instance.new("Folder")
folder.Name = "Passengers"
folder.Parent = workspace

local function pick(list)
	return list[math.random(1, #list)]
end

local function playAnim(humanoid, id, looped)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = animator:LoadAnimation(anim)
	track.Looped = looped
	track:Play()
	return track
end

-- Thought bubble + mood bar above the head.
local function buildBillboard(model, index)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Mood"
	gui.Size = UDim2.fromScale(3, 2.6)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0

	local bubble = Instance.new("TextLabel")
	bubble.Name = "Bubble"
	bubble.AnchorPoint = Vector2.new(0.5, 0)
	bubble.Position = UDim2.fromScale(0.5, 0)
	bubble.Size = UDim2.fromScale(0.42, 0.5)
	bubble.SizeConstraint = Enum.SizeConstraint.RelativeYY
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.TextScaled = true
	bubble.Text = ""
	bubble.Visible = false
	bubble.Parent = gui
	Instance.new("UICorner", bubble).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke", bubble)
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 40, 50)
	local pad = Instance.new("UIPadding", bubble)
	pad.PaddingTop = UDim.new(0.15, 0)
	pad.PaddingBottom = UDim.new(0.15, 0)
	pad.PaddingLeft = UDim.new(0.15, 0)
	pad.PaddingRight = UDim.new(0.15, 0)
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.Size = UDim2.fromScale(1, 1)
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Parent = bubble

	local name = Instance.new("TextLabel")
	name.Name = "MoodText"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0, 0.55)
	name.Size = UDim2.fromScale(1, 0.22)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = "#" .. index .. " Calm"
	name.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0.15, 0.8)
	bar.Size = UDim2.fromScale(0.7, 0.1)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	bar.Parent = gui
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Config.Moods[1].Color
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	gui.Parent = model:FindFirstChild("Head")
	return gui
end

local function tag(p)
	return p.VIP and "⭐ VIP" or ("#" .. p.Index)
end

local function refreshLook(p)
	local mood = Config.MoodFor(p.Fear)
	p.Gui.MoodText.Text = tag(p) .. " " .. mood.Name
	p.Gui.MoodText.TextColor3 = mood.Color
	p.Gui.Bar.Fill.Size = UDim2.fromScale(math.clamp(p.Fear / 100, 0, 1), 1)
	p.Gui.Bar.Fill.BackgroundColor3 = mood.Color
	p.Gui.Bubble.Visible = p.Want ~= nil
	-- a picture of the real snack; the emoji is only a fallback
	local icon = p.Want and Config.Icons[p.Want]
	p.Gui.Bubble.Picture.Image = icon or ""
	p.Gui.Bubble.Text = p.Want and not icon and Config.Snacks[p.Want] or ""
	p.Prompt.ActionText = p.Want and ("Give " .. p.Want) or "Talk"
	p.Model:SetAttribute("Fear", math.floor(p.Fear))
	p.Model:SetAttribute("Want", p.Want or "")
end

local function flee(p)
	p.State = "Fled"
	p.Model:SetAttribute("State", "Fled")
	p.Prompt.Enabled = false
	p.Gui.Bubble.Text = "😱"
	p.Gui.Bubble.Visible = true
	p.Gui.MoodText.Text = tag(p) .. " FLED!"
	Util.PlaySound("Scream", p.Model:FindFirstChild("Head"), 0.15)
	if p.VIP then
		Util.NotifyAll("Bad", "😱 The VIP panicked and ran off! No VIP bonus this ride.")
	else
		Util.NotifyAll("Bad", "😱 Passenger #" .. p.Index .. " panicked and ran to the next car!")
	end
	RoundState:SetAttribute("PassengersLeft", Passengers.AliveCount())

	task.spawn(function()
		local model, humanoid, root = p.Model, p.Humanoid, p.Root
		if p.SitTrack then
			p.SitTrack:Stop()
		end
		root.CFrame = CFrame.lookAt(Vector3.new(root.Position.X, 13, 0), EXIT_POINT + Vector3.new(0, 3, 0))
		root.Anchored = false
		humanoid.WalkSpeed = 18
		playAnim(humanoid, WALK_ANIM, true)
		humanoid:MoveTo(EXIT_POINT)
		local deadline = os.clock() + 7
		while model.Parent and os.clock() < deadline and (root.Position - EXIT_POINT).Magnitude > 3 do
			task.wait(0.2)
		end
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") or part:IsA("Decal") then
				TweenService:Create(part, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.6)
		model:Destroy()
	end)
end

local function onPrompt(p, player)
	if p.State ~= "Seated" then
		return
	end
	local now = os.clock()
	if p.Want then
		local snack = Util.FindHeld(player, p.Want)
		if not snack and Util.FindItem(player, p.Want) then
			Util.Notify(player, "Warn", "Hold the " .. p.Want .. " " .. Config.Snacks[p.Want] .. " to give it! (pick it in your hotbar)")
			return
		end
		if snack then
			snack:Destroy()
			Util.PlaySound("Eat", p.Model:FindFirstChild("Head"), 0.1)
			p.Fear = math.max(0, p.Fear - Config.Fear.Feed)
			p.Want = nil
			p.NextWant = now + math.random(Config.Fear.WantDelay[1], Config.Fear.WantDelay[2])
			refreshLook(p)
			Util.AddTokens(player, Config.Rewards.Feed)
			Util.Notify(player, "Good", "Fed Passenger #" .. p.Index .. "! +" .. Config.Rewards.Feed .. " Tokens")
			if Passengers.OnFed then
				Passengers.OnFed(player)
			end
		else
			Util.Notify(player, "Warn", "Passenger #" .. p.Index .. " wants a " .. p.Want .. " " .. Config.Snacks[p.Want] .. " (snack machine at the back!)")
		end
		return
	end
	if now < p.TalkReady then
		Util.Notify(player, "Info", "Passenger #" .. p.Index .. " isn't in the mood to chat...")
		return
	end
	p.TalkReady = now + Config.Fear.TalkCooldown
	local calm = Config.Fear.Talk * (player:GetAttribute("Owned_SmoothTalker") and 2 or 1)
	p.Fear = math.max(0, p.Fear - calm)
	refreshLook(p)
	Util.Notify(player, "Good", "You chatted with Passenger #" .. p.Index .. ". They feel a bit better.")
end

local function spawnOne(index, anchor, isVIP)
	local desc = Instance.new("HumanoidDescription")
	local skin, shirt, pants = pick(SKIN), pick(SHIRTS), pick(PANTS)
	if isVIP then
		shirt, pants = Color3.fromRGB(250, 195, 40), Color3.fromRGB(25, 25, 30)
	end
	desc.HeadColor = skin
	desc.LeftArmColor = shirt
	desc.RightArmColor = shirt
	desc.TorsoColor = shirt
	desc.LeftLegColor = pants
	desc.RightLegColor = pants
	desc.HeightScale = 0.9 + math.random() * 0.2
	desc.WidthScale = 0.9 + math.random() * 0.2

	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = "Passenger" .. index
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	local root = model:FindFirstChild("HumanoidRootPart")
	root.Anchored = true
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "NPC"
		end
	end
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	local height = humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(anchor.CFrame * CFrame.new(0, height - 1.65, 0.35))
	local head = model:FindFirstChild("Head")
	if head and not head:FindFirstChildOfClass("Decal") then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end
	model:SetAttribute("Index", index)
	model:SetAttribute("State", "Seated")
	model:SetAttribute("VIP", isVIP or nil)
	if isVIP and head then
		-- a little gold crown so the VIP stands out
		local crown = Instance.new("Part")
		crown.Name = "Crown"
		crown.Size = Vector3.new(1.1, 0.5, 1.1)
		crown.Color = Color3.fromRGB(255, 205, 50)
		crown.Material = Enum.Material.Neon
		crown.CanCollide = false
		crown.Massless = true
		crown.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.25, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = crown
		weld.Parent = crown
		crown.Parent = model
	end
	model.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = isVIP and "⭐ VIP Passenger" or ("Passenger #" .. index)
	prompt.ActionText = "Talk"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local p = {
		Index = index,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Prompt = prompt,
		Gui = buildBillboard(model, index),
		Fear = math.random(0, 20),
		Personality = (0.7 + math.random() * 0.65) * (isVIP and Config.VIP.Fear or 1),
		VIP = isVIP,
		Want = nil,
		WantSince = 0,
		NextWant = os.clock() + math.random(6, 22),
		TalkReady = 0,
		State = "Seated",
	}
	p.SitTrack = playAnim(humanoid, SIT_ANIM, true)
	prompt.Triggered:Connect(function(player)
		onPrompt(p, player)
	end)
	refreshLook(p)
	return p
end

function Passengers.Clear()
	for _, p in Passengers.List do
		if p.Model.Parent then
			p.Model:Destroy()
		end
	end
	Passengers.List = {}
	folder:ClearAllChildren()
end

function Passengers.Spawn(count)
	Passengers.Clear()
	local seats = anchors:GetChildren()
	for i = #seats, 2, -1 do
		local j = math.random(1, i)
		seats[i], seats[j] = seats[j], seats[i]
	end
	local total = math.min(count, #seats)
	local vipIndex = math.random() < Config.VIP.Chance and math.random(1, total) or nil
	for i = 1, total do
		table.insert(Passengers.List, spawnOne(i, seats[i], i == vipIndex))
	end
	RoundState:SetAttribute("PassengersTotal", #Passengers.List)
	RoundState:SetAttribute("PassengersLeft", #Passengers.List)
end

-- A few seated passengers gasp in fright (window smash, emergency stop...).
function Passengers.React(count)
	local seated = {}
	for _, p in Passengers.List do
		if p.State == "Seated" then
			table.insert(seated, p)
		end
	end
	for _ = 1, math.min(count, #seated) do
		local p = table.remove(seated, math.random(1, #seated))
		task.delay(math.random() * 0.4, function()
			Util.PlaySound("Gasp", p.Model:FindFirstChild("Head"), 0.2)
		end)
	end
end

-- true if the ride's VIP is still on board, false if they fled, nil if there's no VIP.
function Passengers.VIPSafe()
	for _, p in Passengers.List do
		if p.VIP then
			return p.State == "Seated"
		end
	end
	return nil
end

function Passengers.AliveCount()
	local n = 0
	for _, p in Passengers.List do
		if p.State == "Seated" then
			n += 1
		end
	end
	return n
end

function Passengers.AddFearAll(amount)
	for _, p in Passengers.List do
		if p.State == "Seated" then
			p.Fear = math.clamp(p.Fear + amount * p.Personality, 0, 100)
		end
	end
end

local refreshTimer = 0
function Passengers.Update(dt, now, extraRate)
	refreshTimer += dt
	local refresh = refreshTimer >= 0.25
	if refresh then
		refreshTimer = 0
	end
	for _, p in Passengers.List do
		if p.State == "Seated" then
			if not p.Want and now >= p.NextWant then
				p.Want = pick(Config.SnackOrder)
				p.WantSince = now
			end
			local rate = Config.Fear.Base * Passengers.Scale * p.Personality + extraRate
			if p.Want and now - p.WantSince > 8 then
				rate += Config.Fear.WantWaiting
			end
			p.Fear = math.min(100, p.Fear + rate * dt)
			-- gasp once when they start panicking
			if p.Fear >= 75 and not p.Gasped then
				p.Gasped = true
				Util.PlaySound("Gasp", p.Model:FindFirstChild("Head"), 0.15)
			elseif p.Fear < 60 then
				p.Gasped = false
			end
			if p.Fear >= 100 then
				flee(p)
			elseif refresh then
				refreshLook(p)
			end
		end
	end
end

return Passengers

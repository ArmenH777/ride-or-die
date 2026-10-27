-- Brings the lobby to life (client only, so it costs the server nothing): music + station sounds,
-- shopkeepers that wave and chat, commuters that walk and sit, pigeons that scatter when you run at
-- them, the departures board, station announcements and the SETTINGS window. Paused during rides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local UI = require(ReplicatedStorage:WaitForChild("UIStyle"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")
local player = Players.LocalPlayer
local lobby = workspace:WaitForChild("Lobby")
local padsFolder = lobby:WaitForChild("Pads")
local decor = lobby:WaitForChild("Decor")
local C = UI.Colors
local new, text = UI.new, UI.text

local function inLobby()
	return player:GetAttribute("InRide") ~= true
end
-- settings are saved by the server (Data); missing = on
local function setting(name)
	return player:GetAttribute("Setting" .. name) ~= false
end
local function nearestPlayerDistance(position)
	local best = math.huge
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - position) * Vector3.new(1, 0, 1)
			best = math.min(best, d.Magnitude)
		end
	end
	return best
end
local function myRoot()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local gui = new("ScreenGui", { Name = "LobbyLife", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 3, Parent = player:WaitForChild("PlayerGui") })

------------------------------------------------------------------ music playlist + crowd murmur
local function soundFrom(name, parent)
	local template = Sounds:WaitForChild(name)
	local s = template:Clone()
	s.Parent = parent or SoundService
	return s, template.Volume
end
local tracks = {}
for _, name in { "Music1", "Music2", "Music3" } do
	local s, volume = soundFrom(name)
	s.Looped = false
	s.Volume = 0
	table.insert(tracks, { Sound = s, Volume = volume })
end
local trackIndex = math.random(#tracks)
for i, t in tracks do
	t.Sound.Ended:Connect(function()
		if i == trackIndex then
			trackIndex = trackIndex % #tracks + 1
			tracks[trackIndex].Sound.TimePosition = 0
			tracks[trackIndex].Sound:Play()
		end
	end)
end
local ambience, ambienceVolume = soundFrom("LobbyAmbience")
ambience.Volume = 0

-- fade a looping sound toward a volume; pause it once it's silent so it keeps its place
local function fade(s, target, dt)
	s.Volume += (target - s.Volume) * math.min(1, dt * 2.5)
	if target > 0 and not s.IsPlaying then
		s:Resume()
		if not s.IsPlaying then
			s:Play()
		end
	elseif target == 0 and s.Volume < 0.005 and s.IsPlaying then
		s:Pause()
	end
end

------------------------------------------------------------------ station announcements (chime + a line at the bottom of the screen)
local ANNOUNCEMENTS = {
	"Line 13 to Midnight Station is now boarding! Step on a glowing platform to ride.",
	"Please keep your passengers calm. Snacks help. Screaming does not.",
	"Harder rides pay more Tokens. Good luck out there!",
	"Reminder: duct tape fixes everything. Seriously.",
	"Faster trains are waiting at the Train Yard!",
	"Please do not feed the pigeons. They have had enough pretzels.",
	"Fire on board? Don't panic! Grab the extinguisher.",
}
local chime = soundFrom("Chime")
local banner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10), Size = UDim2.fromOffset(620, 54),
	BackgroundColor3 = C.Panel, BackgroundTransparency = 0.1, Parent = gui,
}, { UI.corner(16), UI.stroke(C.Yellow, 3) })
local bannerScale = new("UIScale", { Parent = banner })
text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(46, 54), Text = "🔔", TextSize = 30, Outline = false, Parent = banner })
local bannerText = text({
	Position = UDim2.fromOffset(60, 4), Size = UDim2.new(1, -74, 1, -8), Text = "", TextScaled = true, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = banner,
})
new("UITextSizeConstraint", { MaxTextSize = 20, Parent = bannerText })
local announcing = false
local function announce(message)
	if announcing then
		return
	end
	announcing = true
	if setting("Sounds") then
		chime:Play()
	end
	bannerText.Text = message
	local shown = UDim2.new(0.5, 0, 1, -24 - 54)
	local hidden = UDim2.new(0.5, 0, 1, 10)
	TweenService:Create(banner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = shown }):Play()
	task.delay(7, function()
		TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = hidden }):Play()
		task.wait(0.4)
		announcing = false
	end)
end

-- a train rumbling through the tunnel now and then (3D sound from a tunnel mouth)
local tunnelSpeaker = new("Part", {
	Name = "TunnelSpeaker", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
	Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(-58, 6, 305.6), Parent = workspace,
})
local distantTrain = soundFrom("DistantTrain", tunnelSpeaker)
distantTrain.RollOffMinDistance = 30
distantTrain.RollOffMaxDistance = 180

------------------------------------------------------------------ departures board: clock + status lines that flip
local boardGui = lobby:WaitForChild("DepartureBoard"):FindFirstChildOfClass("SurfaceGui")
local clockLabel = boardGui and boardGui:FindFirstChild("Clock", true)
local statusLabel = boardGui and boardGui:FindFirstChild("Status", true)
local boardSlot = 0
local function padByIndex(index)
	for _, model in padsFolder:GetChildren() do
		if model:GetAttribute("Index") == index then
			return model
		end
	end
	return nil
end
local function boardLine(slot)
	local model = slot > 0 and padByIndex(slot)
	if not model then
		return "NOW BOARDING  •  NEXT STOP: MIDNIGHT STATION"
	end
	local state = model:GetAttribute("State")
	if state == "Open" then
		local left = math.max(0, math.ceil((model:GetAttribute("LeaveAt") or 0) - workspace:GetServerTimeNow()))
		return string.format("PLATFORM %d  •  %s  •  %d/%d  •  %s", slot, string.upper(model:GetAttribute("Difficulty") or ""),
			model:GetAttribute("Count") or 0, model:GetAttribute("Max") or 0, model:GetAttribute("Waiting") and "WAITING" or ("LEAVES IN " .. left .. "s"))
	elseif state == "Setup" then
		return string.format("PLATFORM %d  •  HOST GETTING READY", slot)
	elseif state == "Launching" then
		return string.format("PLATFORM %d  •  DEPARTING NOW!", slot)
	end
	return string.format("PLATFORM %d  •  WAITING FOR A HOST", slot)
end
local function flipBoard()
	if not statusLabel then
		return
	end
	boardSlot = (boardSlot + 1) % (#padsFolder:GetChildren() + 1)
	local out = TweenService:Create(statusLabel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0, 16, -1, 3) })
	out:Play()
	out.Completed:Wait()
	statusLabel.Text = boardLine(boardSlot)
	statusLabel.Position = UDim2.new(0, 16, 1, 3)
	TweenService:Create(statusLabel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(16, 3) }):Play()
end

-- "DIE!" on the big logo gives a spooky wobble now and then
local dieWords = {}
local logo = decor:FindFirstChild("LogoSign")
if logo then
	for _, d in logo:GetDescendants() do
		if d.Name == "Die" and d:IsA("TextLabel") then
			table.insert(dieWords, d)
		end
	end
end
local function wobble()
	for _, word in dieWords do
		task.spawn(function()
			for _, angle in { -7, 6, -4, 0 } do
				local t = TweenService:Create(word, TweenInfo.new(0.09, Enum.EasingStyle.Sine), { Rotation = angle })
				t:Play()
				t.Completed:Wait()
			end
		end)
	end
end

------------------------------------------------------------------ people: shopkeepers, commuters
local ANIMS = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Sit = "rbxassetid://2506281703",
	Wave = "rbxassetid://507770239",
	Point = "rbxassetid://507770453",
}
local WALK_SPEED = 5
local people = {}

local function loadTracks(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or new("Animator", { Parent = humanoid }))
	local loaded = {}
	if animator then
		for name, id in ANIMS do
			local ok, track = pcall(function()
				return animator:LoadAnimation(new("Animation", { AnimationId = id }))
			end)
			if ok then
				loaded[name] = track
			end
		end
	end
	return loaded
end

local function speechBubble(person)
	local head = person.Model:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = new("BillboardGui", {
		Name = "Speech", Adornee = head, Size = UDim2.new(9, 0, 2.6, 0), StudsOffset = Vector3.new(0, 3, 0), AlwaysOnTop = false,
		MaxDistance = 45, LightInfluence = 0, Enabled = false, Parent = gui,
	})
	local bubble = new("Frame", { Size = UDim2.fromScale(1, 0.66), BackgroundColor3 = C.White }, { UI.corner(14), UI.stroke(C.Outline, 2.5) })
	bubble.Parent = bb
	local line = text({ Position = UDim2.fromScale(0.05, 0.08), Size = UDim2.fromScale(0.9, 0.84), Text = "", TextScaled = true, TextWrapped = true, TextColor3 = C.Navy, Parent = bubble })
	local tag = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.62, 0.28), BackgroundColor3 = C.Yellow }, { UI.corner(10), UI.stroke(C.Outline, 2) })
	tag.Parent = bb
	text({ Position = UDim2.fromScale(0.05, 0.1), Size = UDim2.fromScale(0.9, 0.8), Text = person.Model:GetAttribute("Title") or "", TextScaled = true, TextColor3 = C.Navy, Parent = tag })
	person.Bubble, person.Line = bb, line
	person.Lines = string.split(person.Model:GetAttribute("Lines") or "", "|")
	person.LineIndex = 0
end

local function parsePath(s)
	local points = {}
	for x, z in string.gmatch(s or "", "(-?[%d%.]+),(-?[%d%.]+)") do
		table.insert(points, Vector3.new(tonumber(x), 0, tonumber(z)))
	end
	return points
end

local function setupPerson(model)
	local root = model:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local person = { Model = model, Root = root, Role = model:GetAttribute("Role"), Home = root.CFrame, Tracks = loadTracks(model), Timer = math.random() * 4 }
	local tracks = person.Tracks
	if person.Role == "Sitter" and tracks.Sit then
		tracks.Sit.Looped = true
		tracks.Sit:Play()
	elseif tracks.Idle then
		tracks.Idle.Looped = true
		tracks.Idle:Play()
	end
	if person.Role == "Walker" then
		person.Path = parsePath(model:GetAttribute("Path"))
		person.Target = 2
		person.Position = root.Position
		person.Yaw = math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
		person.Pause = 0
		if tracks.Walk then
			tracks.Walk.Looped = true
			tracks.Walk:Play(0.2, 1, WALK_SPEED / 11)
		end
	elseif person.Role == "Shopkeeper" then
		speechBubble(person)
	end
	table.insert(people, person)
end

local function turnToward(current, target, dt, rate)
	local diff = (target - current + math.pi) % (2 * math.pi) - math.pi
	return current + diff * math.min(1, dt * rate)
end

local function updatePerson(p, dt)
	local tracks = p.Tracks
	if p.Role == "Walker" and #p.Path > 1 then
		if p.Pause > 0 then
			p.Pause -= dt
			if p.Pause <= 0 and tracks.Walk then
				tracks.Walk:Play(0.25, 1, WALK_SPEED / 11)
			end
		else
			local goal = Vector3.new(p.Path[p.Target].X, p.Position.Y, p.Path[p.Target].Z)
			local offset = goal - p.Position
			if offset.Magnitude < 0.4 then
				p.Target = p.Target % #p.Path + 1
				-- now and then they stop for a moment, like they forgot something
				if math.random() < 0.2 then
					p.Pause = 1.5 + math.random() * 2.5
					if tracks.Walk then
						tracks.Walk:Stop(0.25)
					end
				end
			else
				local dir = offset.Unit
				p.Position += dir * math.min(offset.Magnitude, WALK_SPEED * dt)
				p.Yaw = turnToward(p.Yaw, math.atan2(-dir.X, -dir.Z), dt, 8)
			end
		end
		p.Root.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, p.Yaw, 0)
	elseif p.Role == "Shopkeeper" then
		local myPos = myRoot() and myRoot().Position
		local close = myPos and (myPos - p.Root.Position).Magnitude or math.huge
		-- look at you when you come over, then back to the hall
		local homeYaw = math.atan2(-p.Home.LookVector.X, -p.Home.LookVector.Z)
		local yaw = homeYaw
		if close < 24 then
			local d = myPos - p.Root.Position
			local want = math.atan2(-d.X, -d.Z)
			local diff = (want - homeYaw + math.pi) % (2 * math.pi) - math.pi
			yaw = homeYaw + math.clamp(diff, -1, 1)
		end
		p.Yaw = turnToward(p.Yaw or homeYaw, yaw, dt, 3)
		p.Root.CFrame = CFrame.new(p.Home.Position) * CFrame.Angles(0, p.Yaw, 0)
		-- wave hello when you walk up
		if close < 16 and not p.Greeted then
			p.Greeted = true
			if tracks.Wave then
				tracks.Wave:Play(0.2)
			end
		elseif close > 26 then
			p.Greeted = false
		end
		if p.Bubble then
			p.Bubble.Enabled = close < 32 and #p.Lines > 0
			p.Timer -= dt
			if p.Bubble.Enabled and p.Timer <= 0 then
				p.Timer = 6
				p.LineIndex = p.LineIndex % #p.Lines + 1
				p.Line.Text = p.Lines[p.LineIndex]
				UI.pop(p.Line.Parent)
			end
		end
	elseif p.Role == "Idle" then
		p.Timer -= dt
		if p.Timer <= 0 then
			p.Timer = 9 + math.random() * 6
			if tracks.Point then
				tracks.Point:Play(0.3)
			end
		end
	end
end

------------------------------------------------------------------ pigeons: peck, hop, and fly off when someone runs at them
local FLEE_DISTANCE = 9
local pigeons = {}
local function setupPigeon(model)
	local parts = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(parts, { Part = part, Offset = part:GetAttribute("Offset") or CFrame.new() })
		end
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root then
		return
	end
	table.insert(pigeons, {
		Model = model, Parts = parts, Home = root.CFrame, Pivot = root.CFrame, State = "Ground", Timer = math.random() * 2,
		Action = nil, ActionTime = 0, Peck = 0, Flap = 0, Hidden = false,
	})
end
local NECK = Vector3.new(0, 0.95, -0.38)
local HEAD_PARTS = { Head = true, Beak = true, Eye = true }
local function drawPigeon(b)
	for _, entry in b.Parts do
		local offset = entry.Offset
		local name = entry.Part.Name
		if HEAD_PARTS[name] and b.Peck ~= 0 then
			offset = CFrame.new(NECK) * CFrame.Angles(-b.Peck, 0, 0) * CFrame.new(-NECK) * offset
		elseif (name == "WingL" or name == "WingR") and b.Flap ~= 0 then
			local s = name == "WingL" and -1 or 1
			local hinge = Vector3.new(s * 0.32, 0.85, 0.1)
			offset = CFrame.new(hinge) * CFrame.Angles(0, 0, s * b.Flap) * CFrame.new(-hinge) * offset
		end
		entry.Part.CFrame = b.Pivot * offset
		entry.Part.LocalTransparencyModifier = b.Hidden and 1 or 0
	end
end
local function flapSound(b)
	if setting("Sounds") then
		local s = soundFrom("PigeonFlap", b.Parts[1].Part)
		s.RollOffMaxDistance = 60
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
end
local function updatePigeon(b, dt, now)
	local home = b.Home.Position
	if b.State == "Ground" then
		if nearestPlayerDistance(b.Pivot.Position) < FLEE_DISTANCE then
			-- take off, away from whoever came close
			b.State = "Fly"
			b.ActionTime = 0
			local away = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - b.Pivot.Position).Magnitude < FLEE_DISTANCE + 4 then
					away += (b.Pivot.Position - root.Position) * Vector3.new(1, 0, 1)
				end
			end
			b.FlyFrom = b.Pivot.Position
			b.FlyDir = away.Magnitude > 0.01 and away.Unit or Vector3.new(1, 0, 0)
			b.Peck = 0
			flapSound(b)
			return
		end
		b.Timer -= dt
		if not b.Action and b.Timer <= 0 then
			local roll = math.random()
			b.Action = roll < 0.45 and "Peck" or roll < 0.8 and "Hop" or "Turn"
			b.ActionTime = 0
			b.Start = b.Pivot
			local yaw = (math.random() - 0.5) * 2.2
			if (b.Pivot.Position - home).Magnitude > 2.5 then
				-- wandered too far: turn back toward home
				local d = home - b.Pivot.Position
				local _, current = b.Pivot:ToEulerAnglesYXZ()
				yaw = ((math.atan2(-d.X, -d.Z) - current + math.pi) % (2 * math.pi) - math.pi)
			end
			b.TurnBy = yaw
		end
		if b.Action then
			b.ActionTime += dt
			local t = b.ActionTime
			if b.Action == "Peck" then
				b.Peck = math.rad(55) * math.sin(math.clamp(t / 0.5, 0, 1) * math.pi)
				if t >= 0.5 then
					b.Action, b.Peck = nil, 0
				end
			elseif b.Action == "Turn" then
				local k = math.clamp(t / 0.3, 0, 1)
				b.Pivot = b.Start * CFrame.Angles(0, b.TurnBy * k, 0)
				if k >= 1 then
					b.Action = nil
				end
			else -- hop forward with a little arc
				local k = math.clamp(t / 0.35, 0, 1)
				local turned = b.Start * CFrame.Angles(0, b.TurnBy * 0.5, 0)
				b.Pivot = turned * CFrame.new(0, math.sin(k * math.pi) * 0.35, -0.9 * k)
				if k >= 1 then
					b.Action = nil
					b.Pivot = turned * CFrame.new(0, 0, -0.9)
				end
			end
			if not b.Action then
				b.Timer = 0.4 + math.random() * 1.8
			end
		end
	elseif b.State == "Fly" then
		b.ActionTime += dt
		local t = b.ActionTime
		local pos = b.FlyFrom + b.FlyDir * (t * 9) + Vector3.new(0, t * t * 2.2 + t * 4, 0)
		b.Pivot = CFrame.lookAt(pos, pos + b.FlyDir + Vector3.new(0, 0.4, 0))
		b.Flap = math.rad(30) + math.rad(45) * (0.5 + 0.5 * math.sin(now * 32))
		if t > 2.2 then
			b.State, b.Hidden, b.Timer = "Away", true, 14 + math.random() * 10
		end
	elseif b.State == "Away" then
		b.Timer -= dt
		if b.Timer <= 0 and nearestPlayerDistance(home) > FLEE_DISTANCE + 4 then
			b.State, b.Hidden, b.ActionTime = "Land", false, 0
			flapSound(b)
		end
	elseif b.State == "Land" then
		b.ActionTime += dt
		local k = math.clamp(b.ActionTime / 1.6, 0, 1)
		local ease = 1 - (1 - k) ^ 2
		local from = home + Vector3.new(6, 10, 4)
		local pos = from:Lerp(home, ease)
		b.Pivot = CFrame.new(pos) * b.Home.Rotation
		b.Flap = k < 1 and (math.rad(30) + math.rad(45) * (0.5 + 0.5 * math.sin(now * 30))) or 0
		if k >= 1 then
			b.State, b.Flap, b.Pivot, b.Timer = "Ground", 0, b.Home, 1
		end
	end
	drawPigeon(b)
end

------------------------------------------------------------------ SETTINGS window (left menu button)
local settingsWin = UI.window({ Title = "SETTINGS", Icon = "⚙️", Width = 420, Height = 200, Parent = gui })
local toggles = {}
for i, row in { { "Music", "🎵 Music", "Lobby tunes" }, { "Sounds", "🔊 Station sounds", "Crowd, chimes and pigeons" } } do
	local y = 24 + (i - 1) * 84
	text({ Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(240, 30), Text = row[2], TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = settingsWin.Body })
	text({ Position = UDim2.fromOffset(24, y + 30), Size = UDim2.fromOffset(240, 20), Text = row[3], TextSize = 15, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = settingsWin.Body })
	local b = UI.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, y + 4), Size = UDim2.fromOffset(110, 44), Text = "", TextSize = 22, Parent = settingsWin.Body }, C.Lime)
	b.Activated:Connect(function()
		local on = not setting(row[1])
		player:SetAttribute("Setting" .. row[1], on) -- feels instant; the server saves it
		Remotes.SetSetting:FireServer(row[1], on)
	end)
	toggles[row[1]] = b
end
local settingsButton = UI.menuButton(4, "⚙️", "SETTINGS", C.Blue)
settingsButton.Activated:Connect(function()
	if settingsWin.Frame.Visible then
		settingsWin.Close()
	else
		settingsWin.Open()
	end
end)

------------------------------------------------------------------ start up + per frame
for _, model in lobby:WaitForChild("NPCs"):GetChildren() do
	task.spawn(setupPerson, model)
end
local pigeonFolder = decor:FindFirstChild("Pigeons")
if pigeonFolder then
	for _, model in pigeonFolder:GetChildren() do
		setupPigeon(model)
	end
end

local nextAnnouncement = os.clock() + 20
local nextTrain = os.clock() + 45
local nextFlip = os.clock() + 3.5
local nextWobble = os.clock() + 4
local slow = 0
RunService.RenderStepped:Connect(function(dt)
	local here = inLobby()
	local now = os.clock()
	-- sounds
	for i, t in tracks do
		if i == trackIndex then
			fade(t.Sound, (here and setting("Music")) and t.Volume or 0, dt)
		elseif t.Sound.IsPlaying then
			t.Sound:Stop()
		end
	end
	fade(ambience, (here and setting("Sounds")) and ambienceVolume or 0, dt)
	for name, b in toggles do
		local on = setting(name)
		b.Text = on and "ON" or "OFF"
		b.BackgroundColor3 = on and C.Lime or C.Grey
	end
	bannerScale.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / 700, 0.55, 1)
	banner.Visible = here and not player:GetAttribute("PadId")
	if not here then
		if settingsWin.Frame.Visible then
			settingsWin.Close()
		end
		return
	end
	if now >= nextAnnouncement then
		nextAnnouncement = now + 70 + math.random() * 50
		announce(ANNOUNCEMENTS[math.random(#ANNOUNCEMENTS)])
	end
	if now >= nextTrain then
		nextTrain = now + 110 + math.random() * 80
		if setting("Sounds") then
			distantTrain:Play()
		end
	end
	if now >= nextFlip then
		nextFlip = now + 3.5
		task.spawn(flipBoard)
	end
	if now >= nextWobble then
		nextWobble = now + 5 + math.random() * 4
		wobble()
	end
	slow += dt
	if slow >= 0.25 then
		slow = 0
		if clockLabel then
			clockLabel.Text = os.date("%H:%M")
		end
		if statusLabel and boardSlot > 0 then
			statusLabel.Text = boardLine(boardSlot)
		end
	end
	for _, p in people do
		updatePerson(p, dt)
	end
	for _, b in pigeons do
		updatePigeon(b, dt, now)
	end
end)

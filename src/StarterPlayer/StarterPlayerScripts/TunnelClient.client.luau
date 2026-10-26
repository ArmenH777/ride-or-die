-- The train never actually moves: the tunnel, signals and stations scroll past it.
-- Everything here only exists on this player's screen.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local RoundState = ReplicatedStorage:WaitForChild("RoundState")
local camera = workspace.CurrentCamera

local FRONT_X = 48 -- world X of the train's nose
local SEG = 40
local BEHIND, AHEAD = 360, 720
local COUNT = (BEHIND + AHEAD) / SEG
local SPM = Config.StudsPerMile
local PARK = CFrame.new(0, -500, 0)

local STATION_BACK, STATION_FRONT = -170, 40 -- platform extent around a station's position

local tunnel = Instance.new("Folder")
tunnel.Name = "Tunnel"
tunnel.Parent = workspace

local function part(size, color, material, cf, parent)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CFrame = cf or PARK
	p.Anchored = true
	-- solid so the camera can't zoom out through the tunnel walls
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or tunnel
	return p
end

local function sign(p, face, text, textColor, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = font or Enum.Font.FredokaOne
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	return label
end

local CONCRETE = Color3.fromRGB(66, 66, 70)
local RIB = Color3.fromRGB(52, 52, 56)

------------------------------------------------------------------ static tunnel shell
local midX = FRONT_X + (AHEAD - BEHIND) / 2
local length = BEHIND + AHEAD + 120
part(Vector3.new(length, 1, 26), Color3.fromRGB(48, 44, 42), Enum.Material.Slate, CFrame.new(midX, 5.5, 0))
part(Vector3.new(length, 22, 1), CONCRETE, Enum.Material.Concrete, CFrame.new(midX, 16, -12.5))
part(Vector3.new(length, 1, 26), CONCRETE, Enum.Material.Concrete, CFrame.new(midX, 27.5, 0))
for _, s in { -1, 1 } do
	part(Vector3.new(length, 1, 7), CONCRETE, Enum.Material.Concrete, CFrame.new(midX, 25.4, s * 10.6) * CFrame.Angles(math.rad(s * 45), 0, 0))
	part(Vector3.new(length, 0.45, 0.35), Color3.fromRGB(150, 150, 155), Enum.Material.Metal, CFrame.new(midX, 6.6, s * 2.5))
end
-- third rail with its yellow cover
part(Vector3.new(length, 0.3, 0.6), Color3.fromRGB(220, 180, 40), Enum.Material.SmoothPlastic, CFrame.new(midX, 7, -4.6))
for i, y in { 15, 15.5, 16 } do
	part(Vector3.new(length, 0.3, 0.3), Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic, CFrame.new(midX, y, -11.85))
end

------------------------------------------------------------------ scrolling segments
local PLATE_TEXTS = { "⚡ DANGER: HIGH VOLTAGE", "LINE 13", "NO ENTRY", "EMERGENCY EXIT ▶", "⚠ DO NOT TOUCH THE THIRD RAIL", "KEEP OUT" }

local slots = {}
for k = 0, COUNT - 1 do
	local slot = { Parts = {}, Offsets = {}, Hideable = {}, Index = nil }
	local function add(p, offset, hideable)
		table.insert(slot.Parts, p)
		table.insert(slot.Offsets, offset)
		table.insert(slot.Hideable, hideable or false)
		return p
	end
	add(part(Vector3.new(SEG, 22, 1), CONCRETE, Enum.Material.Concrete), CFrame.new(SEG / 2, 16, 12.5), true)
	for _, y in { 15, 15.5 } do
		add(part(Vector3.new(SEG, 0.3, 0.3), Color3.fromRGB(20, 20, 22)), CFrame.new(SEG / 2, y, 11.85), true)
	end
	add(part(Vector3.new(1.6, 21, 1.2), RIB, Enum.Material.Concrete), CFrame.new(2, 16, -11.5))
	add(part(Vector3.new(1.6, 21, 1.2), RIB, Enum.Material.Concrete), CFrame.new(2, 16, 11.5), true)
	add(part(Vector3.new(1.6, 1.2, 25), RIB, Enum.Material.Concrete), CFrame.new(2, 26.5, 0))
	for i = 0, 3 do
		add(part(Vector3.new(1.4, 0.4, 7), Color3.fromRGB(72, 56, 42), Enum.Material.Wood), CFrame.new(5 + i * 10, 6.2, 0))
	end
	local lamp = add(part(Vector3.new(1.2, 0.7, 0.5), Color3.fromRGB(255, 190, 120), Enum.Material.Neon), CFrame.new(22, 21, -11.7))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 110)
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = lamp
	add(part(Vector3.new(1.2, 0.7, 0.5), Color3.fromRGB(255, 190, 120), Enum.Material.Neon), CFrame.new(22, 21, 11.7), true)
	slot.Plate = add(part(Vector3.new(4, 1.4, 0.1), Color3.fromRGB(230, 200, 40)), CFrame.new(30, 12.5, -11.85))
	slot.PlateText = sign(slot.Plate, Enum.NormalId.Back, "", Color3.fromRGB(20, 20, 20))
	slots[k] = slot
end

------------------------------------------------------------------ route objects (signals, curve signs, stations)
local objects = {}
local function addObject(stud, z, parts, offsets)
	local obj = { Stud = stud, Z = z, Parts = parts, Offsets = offsets, Parked = false }
	table.insert(objects, obj)
	return obj
end

local function newGroup()
	local parts, offsets = {}, {}
	return parts, offsets, function(p, offset)
		table.insert(parts, p)
		table.insert(offsets, offset)
		return p
	end
end

local stationSpans = {}
local STATION_COLORS = {
	Color3.fromRGB(60, 110, 200), Color3.fromRGB(60, 160, 90), Color3.fromRGB(200, 120, 50), Color3.fromRGB(130, 70, 190), Color3.fromRGB(150, 30, 40),
}
for i, station in Config.Stations do
	local stud = station.Mile * SPM
	table.insert(stationSpans, { stud + STATION_BACK, stud + STATION_FRONT })
	local parts, offsets, add = newGroup()
	local len = STATION_FRONT - STATION_BACK
	local mid = (STATION_FRONT + STATION_BACK) / 2
	local tile = STATION_COLORS[(i - 1) % #STATION_COLORS + 1]
	add(part(Vector3.new(len, 4.5, 11.5), Color3.fromRGB(150, 148, 142), Enum.Material.Concrete), CFrame.new(mid, 7.75, 6.25))
	add(part(Vector3.new(len, 0.06, 0.8), Color3.fromRGB(250, 210, 40)), CFrame.new(mid, 10.03, 0.9))
	add(part(Vector3.new(len, 17, 1), tile, Enum.Material.Marble), CFrame.new(mid, 18.5, 12.5))
	add(part(Vector3.new(len, 0.6, 0.2), Color3.fromRGB(240, 240, 240)), CFrame.new(mid, 13, 11.9))
	add(part(Vector3.new(len, 1, 13), Color3.fromRGB(40, 40, 44), Enum.Material.Concrete), CFrame.new(mid, 27.5, 6.5))
	for _, x in { STATION_BACK, STATION_FRONT } do
		add(part(Vector3.new(1, 17, 12), CONCRETE, Enum.Material.Concrete), CFrame.new(x, 18.5, 6.5))
	end
	for x = STATION_BACK + 15, STATION_FRONT - 10, 30 do
		local l = add(part(Vector3.new(6, 0.3, 1), Color3.fromRGB(240, 245, 255), Enum.Material.Neon), CFrame.new(x, 26.8, 6))
		local pl = Instance.new("PointLight")
		pl.Range = 24
		pl.Brightness = 1.6
		pl.Color = Color3.fromRGB(235, 240, 255)
		pl.Parent = l
		add(part(Vector3.new(1.4, 17, 1.4), Color3.fromRGB(200, 200, 205), Enum.Material.Marble), CFrame.new(x + 8, 18.5, 5.5))
	end
	for x = STATION_BACK + 25, STATION_FRONT - 10, 45 do
		local s = add(part(Vector3.new(9, 1.8, 0.2), Color3.fromRGB(25, 30, 60)), CFrame.new(x, 17.5, 11.9))
		sign(s, Enum.NormalId.Front, station.Name, Color3.new(1, 1, 1))
		add(part(Vector3.new(5, 0.8, 1.6), Color3.fromRGB(110, 75, 50), Enum.Material.Wood), CFrame.new(x + 18, 11.4, 10.8))
	end
	if i == #Config.Stations then
		local s = add(part(Vector3.new(14, 2.4, 0.2), Color3.fromRGB(150, 20, 30)), CFrame.new(-60, 22.5, 11.9))
		sign(s, Enum.NormalId.Front, "END OF THE LINE", Color3.new(1, 1, 1))
	end
	addObject(stud, 12, parts, offsets)
end

local routeObjects = {} -- rebuilt every ride
local signalLamps = {}

local function clearRoute()
	for _, obj in routeObjects do
		for _, p in obj.Parts do
			p:Destroy()
		end
		table.remove(objects, table.find(objects, obj))
	end
	routeObjects = {}
	signalLamps = {}
end

local function buildRoute()
	clearRoute()
	local ok, events = pcall(HttpService.JSONDecode, HttpService, RoundState:GetAttribute("TrackEvents") or "[]")
	if not ok then
		return
	end
	for _, event in events do
		if event.Type == "Signal" then
			local parts, offsets, add = newGroup()
			add(part(Vector3.new(0.5, 9, 0.5), Color3.fromRGB(40, 40, 44), Enum.Material.Metal), CFrame.new(0, 10.5, 0))
			add(part(Vector3.new(1.2, 2.8, 1.2), Color3.fromRGB(20, 20, 22)), CFrame.new(0, 15.6, 0))
			local red = add(part(Vector3.new(0.3, 0.8, 0.8), Color3.fromRGB(255, 40, 30), Enum.Material.Neon), CFrame.new(-0.65, 16.4, 0))
			local green = add(part(Vector3.new(0.3, 0.8, 0.8), Color3.fromRGB(20, 40, 20), Enum.Material.SmoothPlastic), CFrame.new(-0.65, 14.9, 0))
			local glow = Instance.new("PointLight")
			glow.Range = 16
			glow.Brightness = 2
			glow.Color = Color3.fromRGB(255, 40, 30)
			glow.Parent = red
			signalLamps[event.Id] = { Red = red, Green = green, Glow = glow }
			table.insert(routeObjects, addObject(event.Mile * SPM, -9.5, parts, offsets))
		elseif event.Type == "Curve" then
			local parts, offsets, add = newGroup()
			add(part(Vector3.new(0.4, 6, 0.4), Color3.fromRGB(40, 40, 44), Enum.Material.Metal), CFrame.new(0, 9, 0))
			local board = add(part(Vector3.new(0.2, 3, 3), Color3.fromRGB(250, 200, 30)), CFrame.new(0, 13, 0))
			sign(board, Enum.NormalId.Left, (event.Dir > 0 and "↱ " or "↰ ") .. event.Limit, Color3.fromRGB(20, 20, 20))
			table.insert(routeObjects, addObject(event.Start * SPM - 260, -9.5, parts, offsets))
			-- chevrons on the outside wall of the bend
			local outsideZ = event.Dir > 0 and -11.8 or 11.8
			for stud = event.Start * SPM, event.End * SPM, 60 do
				local cp, co, cadd = newGroup()
				local chevron = cadd(part(Vector3.new(2.4, 1.6, 0.2), Color3.fromRGB(250, 200, 30)), CFrame.new(0, 14, 0))
				sign(chevron, outsideZ < 0 and Enum.NormalId.Back or Enum.NormalId.Front, event.Dir > 0 and "❯❯" or "❮❮", Color3.fromRGB(20, 20, 20))
				table.insert(routeObjects, addObject(stud, outsideZ, cp, co))
			end
		elseif event.Type == "Split" then
			local stud = event.Mile * SPM
			local arrow = event.Correct == "Left" and "◀◀  TAKE LEFT" or "TAKE RIGHT  ▶▶"
			-- warning signs hanging over the track
			for _, back in { 320, 60 } do
				local sp, so, sadd = newGroup()
				local board = sadd(part(Vector3.new(0.4, 4, 16), Color3.fromRGB(250, 200, 30)), CFrame.new(0, 22.5, 0))
				sign(board, Enum.NormalId.Left, back > 100 and ("JUNCTION AHEAD\n" .. arrow) or arrow, Color3.fromRGB(20, 20, 20))
				for _, z in { -6, 6 } do
					sadd(part(Vector3.new(0.3, 3, 0.3), Color3.fromRGB(40, 40, 44), Enum.Material.Metal), CFrame.new(0, 26, z))
				end
				table.insert(routeObjects, addObject(stud - back, 0, sp, so))
			end
			-- divider wall between the two branches, on the side the train is NOT going
			for _, side in { -1, 1 } do
				local dp, dO, dadd = newGroup()
				dadd(part(Vector3.new(400, 10, 1), RIB, Enum.Material.Concrete), CFrame.new(200, 11, 0))
				dadd(part(Vector3.new(0.6, 10, 1.4), Color3.fromRGB(250, 200, 30)), CFrame.new(0, 11, 0))
				for y = 7, 15, 4 do
					dadd(part(Vector3.new(0.7, 1.2, 1.5), Color3.fromRGB(20, 20, 20)), CFrame.new(0, y, 0))
				end
				local lamp = dadd(part(Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(255, 40, 30), Enum.Material.Neon), CFrame.new(0, 16.6, 0))
				local glow = Instance.new("PointLight")
				glow.Color = Color3.fromRGB(255, 40, 30)
				glow.Range = 14
				glow.Parent = lamp
				local obj = addObject(stud, side * 9.6, dp, dO)
				obj.Show = function()
					local going = RoundState:GetAttribute("SplitTaken" .. event.Id) or RoundState:GetAttribute("Switch")
					local otherSide = going == "Left" and 1 or -1
					return side == otherSide
				end
				table.insert(routeObjects, obj)
			end
			-- dead end, only there if the train took the wrong branch
			local wp, wo, wadd = newGroup()
			for i = -3, 2 do
				local color = i % 2 == 0 and Color3.fromRGB(220, 30, 30) or Color3.fromRGB(240, 240, 240)
				wadd(part(Vector3.new(2, 21, 4), color), CFrame.new(0, 16, i * 4 + 2))
			end
			wadd(part(Vector3.new(3, 3, 8), Color3.fromRGB(200, 30, 30), Enum.Material.Metal), CFrame.new(-2, 8.5, 0))
			for _, z in { -5, 5 } do
				local stop = wadd(part(Vector3.new(0.5, 1.2, 1.2), Color3.fromRGB(255, 40, 30), Enum.Material.Neon), CFrame.new(-1.2, 20, z))
				local glow = Instance.new("PointLight")
				glow.Color = Color3.fromRGB(255, 40, 30)
				glow.Range = 20
				glow.Brightness = 2
				glow.Parent = stop
			end
			local dead = addObject(stud + 0.02 * SPM, 0, wp, wo)
			dead.Show = function()
				return RoundState:GetAttribute("SplitWrong") == event.Id
			end
			table.insert(routeObjects, dead)
		end
	end
end

local function refreshSignals()
	for id, lamp in signalLamps do
		local green = RoundState:GetAttribute("Signal" .. id) == "Green"
		lamp.Red.Color = green and Color3.fromRGB(50, 15, 15) or Color3.fromRGB(255, 40, 30)
		lamp.Red.Material = green and Enum.Material.SmoothPlastic or Enum.Material.Neon
		lamp.Green.Color = green and Color3.fromRGB(40, 255, 90) or Color3.fromRGB(20, 40, 20)
		lamp.Green.Material = green and Enum.Material.Neon or Enum.Material.SmoothPlastic
		lamp.Glow.Parent = green and lamp.Green or lamp.Red
		lamp.Glow.Color = green and Color3.fromRGB(40, 255, 90) or Color3.fromRGB(255, 40, 30)
	end
end

RoundState:GetAttributeChangedSignal("TrackEvents"):Connect(function()
	buildRoute()
	refreshSignals()
end)
RoundState.AttributeChanged:Connect(function(name)
	if name:sub(1, 6) == "Signal" then
		refreshSignals()
	end
end)
buildRoute()
refreshSignals()

------------------------------------------------------------------ per-frame placement
local distance = RoundState:GetAttribute("Distance") or 0
local moveParts, moveCFrames = {}, {}

local function inStation(stud0, stud1)
	for _, span in stationSpans do
		if stud1 > span[1] and stud0 < span[2] then
			return true
		end
	end
	return false
end

local function plateText(index)
	if index % 4 ~= 0 then
		return nil
	end
	return PLATE_TEXTS[(index // 4) % #PLATE_TEXTS + 1]
end

RunService.RenderStepped:Connect(function(dt)
	local serverDistance = RoundState:GetAttribute("Distance") or 0
	local speed = RoundState:GetAttribute("Speed") or 0
	distance += speed / 3600 * dt
	if math.abs(serverDistance - distance) > 0.02 then
		distance = serverDistance
	else
		distance += (serverDistance - distance) * math.min(1, dt * 3)
	end
	local offset = distance * SPM

	table.clear(moveParts)
	table.clear(moveCFrames)

	local base = math.floor((offset - BEHIND) / SEG)
	for k = 0, COUNT - 1 do
		local slot = slots[k]
		local n = base + ((k - base) % COUNT)
		local x0 = FRONT_X + n * SEG - offset
		local hide = inStation(n * SEG, n * SEG + SEG)
		if slot.Index ~= n then
			slot.Index = n
			local text = plateText(n)
			slot.PlateText.Text = text or ""
			slot.Plate.Transparency = text and 0 or 1
		end
		local origin = CFrame.new(x0, 0, 0)
		for i, p in slot.Parts do
			table.insert(moveParts, p)
			table.insert(moveCFrames, (hide and slot.Hideable[i]) and PARK or origin * slot.Offsets[i])
		end
	end

	for _, obj in objects do
		local rel = obj.Stud - offset
		if rel > -BEHIND - 250 and rel < AHEAD + 50 and (not obj.Show or obj.Show()) then
			obj.Parked = false
			local origin = CFrame.new(FRONT_X + rel, 0, obj.Z)
			for i, p in obj.Parts do
				table.insert(moveParts, p)
				table.insert(moveCFrames, origin * obj.Offsets[i])
			end
		elseif not obj.Parked then
			obj.Parked = true
			for _, p in obj.Parts do
				table.insert(moveParts, p)
				table.insert(moveCFrames, PARK)
			end
		end
	end

	workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end)

------------------------------------------------------------------ train rumble (louder and faster with speed)
local rumble = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Rumble"):Clone()
rumble.Parent = game:GetService("SoundService")
rumble.Volume = 0
rumble:Play()
local BASE_RUMBLE = rumble:GetAttribute("BaseVolume") or 0.5

RunService.Heartbeat:Connect(function(dt)
	local frac = math.clamp((RoundState:GetAttribute("Speed") or 0) / Config.MaxSpeed, 0, 1)
	local inRide = Players.LocalPlayer:GetAttribute("InRide") == true
	local targetVolume = inRide and BASE_RUMBLE * (0.08 + 0.92 * frac) or 0
	rumble.Volume += (targetVolume - rumble.Volume) * math.min(1, dt * 2)
	rumble.PlaybackSpeed = 0.75 + 0.45 * frac
end)

------------------------------------------------------------------ camera rumble + leaning in curves
local curves = {}
local function loadCurves()
	local ok, events = pcall(HttpService.JSONDecode, HttpService, RoundState:GetAttribute("TrackEvents") or "[]")
	curves = {}
	if ok then
		for _, e in events do
			if e.Type == "Curve" then
				table.insert(curves, e)
			end
		end
	end
end
loadCurves()
RoundState:GetAttributeChangedSignal("TrackEvents"):Connect(loadCurves)

local roll = 0
local lastSpeed = 0
local jolt = 0
RunService:BindToRenderStep("TrainSway", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if Players.LocalPlayer:GetAttribute("InRide") ~= true then
		return
	end
	local speed = RoundState:GetAttribute("Speed") or 0
	local frac = speed / Config.MaxSpeed
	local decel = (lastSpeed - speed) / math.max(dt, 1 / 240)
	lastSpeed = speed
	if decel > 12 then
		jolt = 1
	end
	jolt = math.max(0, jolt - dt * 1.5)

	local targetRoll = 0
	for _, c in curves do
		if distance >= c.Start and distance <= c.End then
			targetRoll = -c.Dir * math.rad(5) * math.clamp(frac * 1.6, 0, 1.6)
		end
	end
	roll += (targetRoll - roll) * math.min(1, dt * 2)

	local t = os.clock()
	local shake = 0.04 * frac + 0.25 * jolt
	local jitter = Vector3.new(math.noise(t * 9, 0) * shake, math.noise(t * 11, 5) * shake, 0)
	camera.CFrame = camera.CFrame * CFrame.new(jitter) * CFrame.Angles(0, 0, roll + math.noise(t * 3, 9) * 0.004 * frac)
end)

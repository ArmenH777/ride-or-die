-- Lobby boarding pads: step on an empty pad to host a ride, pick settings, and others step on to join.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)
local Util = require(script.Parent.Util)

local Remotes = ReplicatedStorage.Remotes
local padsFolder = workspace.Lobby.Pads

local Lobby = {
	Pads = {},
	Busy = false, -- true while a local ride is using the train (Studio / LocalRides)
	-- set by GameServer: function(players, settings, padIndex)
	OnLaunch = nil,
}

local PURPLE = Color3.fromRGB(150, 80, 230)

local function now()
	return workspace:GetServerTimeNow()
end

local function inZone(pad, player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or player:GetAttribute("InRide") then
		return false
	end
	local rel = pad.Part.CFrame:PointToObjectSpace(root.Position)
	return math.abs(rel.X) <= 6.3 and math.abs(rel.Z) <= 6.3 and rel.Y > -1 and rel.Y < 10
end

local function pushOut(pad, player, message)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(pad.Part.Position + Vector3.new(math.random(-3, 3), 3.5, 10)))
	end
	if message then
		Util.Notify(player, "Warn", message)
	end
end

local friendCache = {}
local function areFriends(a, b)
	local key = math.min(a.UserId, b.UserId) .. "_" .. math.max(a.UserId, b.UserId)
	if friendCache[key] == nil then
		local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
		friendCache[key] = ok and result or false
	end
	return friendCache[key]
end

local function publish(pad)
	local model, display = pad.Model, pad.Display
	local settings = pad.Settings
	local difficulty = settings and Config.Difficulties[settings.Difficulty]
	model:SetAttribute("State", pad.State)
	model:SetAttribute("Host", pad.Host and pad.Host.DisplayName or "")
	model:SetAttribute("HostId", pad.Host and pad.Host.UserId or 0)
	model:SetAttribute("Count", #pad.Members)
	model:SetAttribute("Max", settings and settings.Max or 0)
	model:SetAttribute("Difficulty", settings and settings.Difficulty or "")
	model:SetAttribute("FriendsOnly", settings and settings.FriendsOnly or false)
	local train = settings and Config.FindItem(settings.Train)
	model:SetAttribute("Train", train and train.Name or "")
	model:SetAttribute("LeaveAt", pad.LeaveAt or 0)
	model:SetAttribute("Waiting", Lobby.Busy and pad.State == "Open")

	local status, detail, color = "STEP IN TO HOST", "", Color3.new(1, 1, 1)
	if pad.State == "Setup" then
		status, detail = "SETTING UP...", "Host: " .. pad.Host.DisplayName
	elseif pad.State == "Open" then
		status = settings.Difficulty:upper() .. "  •  " .. #pad.Members .. "/" .. settings.Max
		color = difficulty.Color
		if Lobby.Busy then
			detail = "Waiting for the train..."
		else
			detail = "Leaving in " .. math.max(0, math.ceil(pad.LeaveAt - now())) .. "s  •  " .. (train and train.Name or "") .. (settings.FriendsOnly and "  •  Friends only" or "")
		end
	elseif pad.State == "Launching" then
		status, detail = "DEPARTING!", "Next stop: Midnight Station"
	end
	display.Status.Text = status
	display.Status.TextColor3 = color
	display.Detail.Text = detail
	pad.Part.Color = difficulty and difficulty.Color or PURPLE
end

local function reset(pad)
	for _, member in pad.Members do
		if member:GetAttribute("PadId") == pad.Index then
			member:SetAttribute("PadId", nil)
		end
	end
	pad.State = "Empty"
	pad.Host = nil
	pad.Members = {}
	pad.Settings = nil
	pad.LeaveAt = nil
	publish(pad)
end

local function removeMember(pad, player)
	local i = table.find(pad.Members, player)
	if i then
		table.remove(pad.Members, i)
		if player:GetAttribute("PadId") == pad.Index then
			player:SetAttribute("PadId", nil)
		end
	end
end

local function launch(pad)
	pad.State = "Launching"
	local members = table.clone(pad.Members)
	local settings = table.clone(pad.Settings)
	publish(pad)
	task.spawn(function()
		if Lobby.OnLaunch then
			Lobby.OnLaunch(members, settings, pad.Index)
		end
		task.wait(1)
		reset(pad)
	end)
end

local function padHostedBy(player)
	for _, pad in Lobby.Pads do
		if pad.Host == player then
			return pad
		end
	end
	return nil
end

local function updatePad(pad)
	local occupants = {}
	for _, player in Players:GetPlayers() do
		if inZone(pad, player) then
			table.insert(occupants, player)
		end
	end

	if pad.State == "Empty" then
		for _, player in occupants do
			if not player:GetAttribute("PadId") then
				pad.State = "Setup"
				pad.Host = player
				pad.Members = { player }
				player:SetAttribute("PadId", pad.Index)
				Remotes.OpenMatchmaking:FireClient(player, pad.Index)
				break
			end
		end
	elseif pad.State == "Setup" then
		if not table.find(occupants, pad.Host) then
			Remotes.CloseMatchmaking:FireClient(pad.Host)
			reset(pad)
			return
		end
		for _, player in occupants do
			if player ~= pad.Host then
				pushOut(pad, player, "Wait for " .. pad.Host.DisplayName .. " to finish setting up!")
			end
		end
	elseif pad.State == "Open" then
		for i = #pad.Members, 1, -1 do
			local member = pad.Members[i]
			if not table.find(occupants, member) then
				removeMember(pad, member)
				if member.Parent then
					Util.Notify(member, "Info", "You left Platform " .. pad.Index)
				end
			end
		end
		for _, player in occupants do
			if not table.find(pad.Members, player) and not player:GetAttribute("PadId") then
				if #pad.Members >= pad.Settings.Max then
					pushOut(pad, player, "This train is full!")
				elseif pad.Settings.FriendsOnly and pad.Members[1] and not areFriends(pad.Members[1], player) then
					pushOut(pad, player, "This train is friends only!")
				else
					table.insert(pad.Members, player)
					player:SetAttribute("PadId", pad.Index)
					Util.Notify(player, "Good", "Joined Platform " .. pad.Index .. "!")
				end
			end
		end
		if #pad.Members == 0 then
			reset(pad)
			return
		end
		pad.Host = pad.Members[1]
		local t = now()
		if Lobby.Busy then
			pad.LeaveAt = math.max(pad.LeaveAt, t + 3)
		elseif #pad.Members >= pad.Settings.Max and pad.LeaveAt - t > 3 then
			pad.LeaveAt = t + 3
		end
		if t >= pad.LeaveAt then
			launch(pad)
			return
		end
	end
	publish(pad)
end

function Lobby.Init()
	for _, model in padsFolder:GetChildren() do
		local pad = {
			Index = model:GetAttribute("Index"),
			Model = model,
			Part = model.Pad,
			Display = model.Board.Display,
			State = "Empty",
			Members = {},
		}
		Lobby.Pads[pad.Index] = pad
		publish(pad)
	end

	Remotes.PadSetup.OnServerEvent:Connect(function(player, settings)
		local pad = padHostedBy(player)
		if not pad or pad.State ~= "Setup" or type(settings) ~= "table" then
			return
		end
		local difficulty = Config.Difficulties[settings.Difficulty] and settings.Difficulty or "Easy"
		local max = math.clamp(math.floor(tonumber(settings.Max) or 1), 1, Config.MaxPartySize)
		local trainId = player:GetAttribute("EquippedTrain") or Config.DefaultTrain
		pad.Settings = { Difficulty = difficulty, Max = max, FriendsOnly = settings.FriendsOnly == true, Train = trainId }
		pad.State = "Open"
		pad.LeaveAt = now() + (max == 1 and 3 or Config.PadLeaveTime)
		publish(pad)
	end)

	Remotes.PadCancel.OnServerEvent:Connect(function(player)
		for _, pad in Lobby.Pads do
			if pad.State == "Setup" and pad.Host == player then
				reset(pad)
				pushOut(pad, player)
			elseif pad.State == "Open" and table.find(pad.Members, player) then
				removeMember(pad, player)
				pushOut(pad, player)
			end
		end
	end)

	Remotes.DepartNow.OnServerEvent:Connect(function(player)
		local pad = padHostedBy(player)
		if pad and pad.State == "Open" then
			pad.LeaveAt = math.min(pad.LeaveAt, now())
		end
	end)

	Remotes.JoinPad.OnServerEvent:Connect(function(player, index)
		local pad = Lobby.Pads[index]
		local character = player.Character
		if not pad or pad.State ~= "Open" or not character or player:GetAttribute("InRide") or player:GetAttribute("PadId") then
			return
		end
		character:PivotTo(CFrame.new(pad.Part.Position + Vector3.new(math.random(-2, 2), 3.5, math.random(-2, 2))))
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, pad in Lobby.Pads do
			removeMember(pad, player)
			if pad.Host == player and pad.State == "Setup" then
				reset(pad)
			end
		end
	end)

	task.spawn(function()
		while true do
			for _, pad in Lobby.Pads do
				if pad.State ~= "Launching" then
					updatePad(pad)
				end
			end
			task.wait(0.2)
		end
	end)
end

return Lobby

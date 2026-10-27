-- Admin panel (server side): who is an admin, the /admin chat command, and the actions the panel runs.
-- Every action is checked here again, so a hacked client can't use it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Config)
local Util = require(script.Parent.Util)

local RoundState = ReplicatedStorage.RoundState

local Admin = {
	-- set by GameServer
	Train = nil,
	Passengers = nil,
	Breakdowns = nil,
	-- "Win" or "Lose": GameServer's ride loop ends the ride with this and clears it
	ForcedResult = nil,
}

function Admin.IsAdmin(player)
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		if ok and rank == 255 then
			return true
		end
	end
	return table.find(Config.Admins, player.UserId) ~= nil
end

local function remote(class, name)
	local r = ReplicatedStorage.Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = ReplicatedStorage.Remotes
	end
	return r
end

local function riding()
	return RoundState:GetAttribute("State") == "Running"
end

local NOT_RIDING = "Only works while a ride is going"

local Actions = {}

function Actions.Tokens(player, amount)
	amount = math.clamp(math.floor(tonumber(amount) or 0), -1000000, 1000000)
	local tokens = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Tokens")
	if not tokens then
		return false, "Your Tokens haven't loaded yet"
	end
	-- straight onto the balance, so it doesn't count toward the "most tokens earned" leaderboard
	tokens.Value = math.max(0, tokens.Value + amount)
	return true, (amount >= 0 and "+" or "") .. amount .. " Tokens"
end

function Actions.Give(player, name)
	local template = ServerStorage.Items:FindFirstChild(tostring(name))
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not template or not backpack then
		return false, "Can't give that"
	end
	template:Clone().Parent = backpack
	return true, "Gave you a " .. template:GetAttribute("DisplayName")
end

function Actions.Break(_, kind)
	if not riding() then
		return false, NOT_RIDING
	end
	local ok = Admin.Breakdowns.Spawn(kind ~= "Random" and kind or nil)
	return ok, ok and ("Broke: " .. kind) or "Nothing like that is left to break"
end

function Actions.FixAll()
	if not riding() then
		return false, NOT_RIDING
	end
	Admin.Breakdowns.Reset()
	return true, "Fixed everything"
end

function Actions.Calm()
	if not riding() then
		return false, NOT_RIDING
	end
	Admin.Passengers.AddFearAll(-100)
	return true, "Everyone is calm"
end

function Actions.Scare()
	if not riding() then
		return false, NOT_RIDING
	end
	Admin.Passengers.AddFearAll(30)
	return true, "Boo! Passengers got scared"
end

function Actions.Jump(_, miles)
	if not riding() then
		return false, NOT_RIDING
	end
	miles = math.clamp(tonumber(miles) or 0, 0, Config.RouteMiles - 0.05)
	Admin.Train.Distance = miles
	return true, string.format("Jumped to mile %.1f", miles)
end

function Actions.End(_, result)
	if not riding() then
		return false, NOT_RIDING
	end
	if result ~= "Win" and result ~= "Lose" then
		return false, "Unknown result"
	end
	Admin.ForcedResult = result
	return true, result == "Win" and "Ending the ride: WIN" or "Ending the ride: LOSE"
end

local PLACES = {
	Lobby = function()
		return workspace.Lobby.LobbySpawn.CFrame + Vector3.new(0, 4, 0)
	end,
	Train = function()
		return workspace.Train.RideSpawn.CFrame + Vector3.new(0, 3.5, 0)
	end,
	Cab = function()
		return CFrame.new(40, 13.5, 0) * CFrame.Angles(0, math.rad(-90), 0)
	end,
}
function Actions.Teleport(player, where)
	local place = PLACES[where]
	if not place or not player.Character then
		return false, "Can't go there"
	end
	player.Character:PivotTo(place())
	return true, "Teleported to " .. where
end

function Admin.Init()
	local actionRemote = remote("RemoteFunction", "AdminAction")
	local openRemote = remote("RemoteEvent", "AdminOpen")

	local function mark(player)
		player:SetAttribute("IsAdmin", Admin.IsAdmin(player) or nil)
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end

	actionRemote.OnServerInvoke = function(player, action, value)
		if not Admin.IsAdmin(player) then
			return false, "You're not an admin"
		end
		local fn = Actions[action]
		if not fn then
			return false, "Unknown action"
		end
		local ok, result, message = pcall(fn, player, value)
		if not ok then
			warn("[Admin] " .. tostring(action) .. " failed:", result)
			return false, "That didn't work (see the output)"
		end
		return result, message
	end

	-- typing /admin in chat opens the panel (the message itself is never shown to anyone)
	local command = Instance.new("TextChatCommand")
	command.Name = "AdminCommand"
	command.PrimaryAlias = "/admin"
	command.Triggered:Connect(function(source)
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player then
			return
		end
		if Admin.IsAdmin(player) then
			openRemote:FireClient(player)
		else
			Util.Notify(player, "Warn", "Only admins can use /admin.")
		end
	end)
	command.Parent = TextChatService
end

return Admin

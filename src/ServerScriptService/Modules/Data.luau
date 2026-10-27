-- Saves each player's progress so it carries over between the lobby and ride servers:
-- Tokens + Wins (leaderstats), owned shop items (attributes Owned_<ItemId>), EquippedTrain,
-- TokensEarned, best ride times (attributes Best_<Difficulty>, in seconds), quest / daily reward
-- progress (JSON in attributes QuestData and DailyData) and settings (attributes Setting<Name>).
-- Also feeds the lobby leaderboards (most wins, most tokens earned).
-- In Studio this only works once the place is published and
-- Game Settings > Security > "Enable Studio Access to API Services" is on.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)

local Data = {
	-- set by other modules: called after a player's data has loaded (or failed to)
	OnLoaded = nil,
}

local store, winsBoard, earnedBoard
do
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore("RideOrDie_v1")
		winsBoard = DataStoreService:GetOrderedDataStore("Leaderboard_Wins")
		earnedBoard = DataStoreService:GetOrderedDataStore("Leaderboard_Earned")
	end)
	if not ok then
		store, winsBoard, earnedBoard = nil, nil, nil
		warn("[Data] Progress won't be saved:", err)
	end
end
Data.WinsBoard = winsBoard
Data.EarnedBoard = earnedBoard

local loaded = {} -- only save players whose data loaded, so a failed load never wipes their progress
local SETTINGS = { Music = true, Sounds = true } -- on/off settings from the SETTINGS window

local function stat(player, name)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild(name)
end

function Data.Load(player)
	-- everyone starts with the free train
	player:SetAttribute("Owned_" .. Config.DefaultTrain, true)
	player:SetAttribute("EquippedTrain", Config.DefaultTrain)
	player:SetAttribute("TokensEarned", 0)
	if store then
		local ok, value = pcall(store.GetAsync, store, "player_" .. player.UserId)
		if not ok then
			warn("[Data] Could not load data for", player.Name, value)
		else
			if type(value) == "table" then
				local tokens, wins = stat(player, "Tokens"), stat(player, "Wins")
				if tokens and type(value.Tokens) == "number" then
					tokens.Value = value.Tokens
				end
				if wins and type(value.Wins) == "number" then
					wins.Value = value.Wins
				end
				if type(value.Earned) == "number" then
					player:SetAttribute("TokensEarned", value.Earned)
				end
				if type(value.Owned) == "table" then
					for _, id in value.Owned do
						if Config.FindItem(id) then
							player:SetAttribute("Owned_" .. id, true)
						end
					end
				end
				if type(value.Equipped) == "string" and player:GetAttribute("Owned_" .. value.Equipped) then
					player:SetAttribute("EquippedTrain", value.Equipped)
				end
				if type(value.Quests) == "table" then
					player:SetAttribute("QuestData", HttpService:JSONEncode(value.Quests))
				end
				if type(value.Daily) == "table" then
					player:SetAttribute("DailyData", HttpService:JSONEncode(value.Daily))
				end
				if type(value.Settings) == "table" then
					for name, on in value.Settings do
						if SETTINGS[name] and type(on) == "boolean" then
							player:SetAttribute("Setting" .. name, on)
						end
					end
				end
				if type(value.Best) == "table" then
					for difficulty, seconds in value.Best do
						if Config.Difficulties[difficulty] and type(seconds) == "number" then
							player:SetAttribute("Best_" .. difficulty, seconds)
						end
					end
				end
			end
			loaded[player] = true
		end
	end
	if Data.OnLoaded then
		Data.OnLoaded(player)
	end
end

function Data.Owns(player, id)
	return player:GetAttribute("Owned_" .. id) == true
end

local function decode(text)
	local ok, value = pcall(HttpService.JSONDecode, HttpService, text or "")
	return ok and value or nil
end

function Data.Save(player)
	local tokens, wins = stat(player, "Tokens"), stat(player, "Wins")
	if not store or not loaded[player] or not tokens then
		return
	end
	local owned, best, settings = {}, {}, {}
	for name in SETTINGS do
		settings[name] = player:GetAttribute("Setting" .. name) ~= false
	end
	for name, value in player:GetAttributes() do
		if value == true and name:sub(1, 6) == "Owned_" then
			table.insert(owned, name:sub(7))
		elseif type(value) == "number" and name:sub(1, 5) == "Best_" then
			best[name:sub(6)] = value
		end
	end
	local record = {
		Tokens = tokens.Value,
		Wins = wins and wins.Value or 0,
		Earned = player:GetAttribute("TokensEarned") or 0,
		Owned = owned,
		Equipped = player:GetAttribute("EquippedTrain"),
		Quests = decode(player:GetAttribute("QuestData")),
		Daily = decode(player:GetAttribute("DailyData")),
		Best = best,
		Settings = settings,
	}
	local ok, err = pcall(store.UpdateAsync, store, "player_" .. player.UserId, function()
		return record
	end)
	if not ok then
		warn("[Data] Could not save progress for", player.Name, err)
	end
	pcall(winsBoard.SetAsync, winsBoard, tostring(player.UserId), record.Wins)
	pcall(earnedBoard.SetAsync, earnedBoard, tostring(player.UserId), math.floor(record.Earned))
end

function Data.Init()
	ReplicatedStorage.Remotes.SetSetting.OnServerEvent:Connect(function(player, name, on)
		if SETTINGS[name] and type(on) == "boolean" then
			player:SetAttribute("Setting" .. name, on)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Data.Save(player)
		loaded[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			Data.Save(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				Data.Save(player)
			end
		end
	end)
end

return Data

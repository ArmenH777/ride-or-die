-- Daily quests and daily login rewards.
-- Progress lives in player attributes as JSON (QuestData, DailyData) and is saved by Data.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)
local Util = require(script.Parent.Util)
local Data = require(script.Parent.Data)

local Remotes = ReplicatedStorage.Remotes

local Quests = {}

local function today()
	return math.floor(os.time() / 86400)
end

local function decode(text)
	local ok, value = pcall(HttpService.JSONDecode, HttpService, text or "")
	return ok and type(value) == "table" and value or nil
end

local function questDef(id)
	for _, def in Config.Quests do
		if def.Id == id then
			return def
		end
	end
	return nil
end

-- Makes sure the player has today's quests (rolls new ones each day).
function Quests.Ensure(player)
	local data = decode(player:GetAttribute("QuestData"))
	if data and data.Day == today() and type(data.List) == "table" then
		return data
	end
	local pool = table.clone(Config.Quests)
	local list = {}
	for _ = 1, math.min(Config.QuestsPerDay, #pool) do
		local def = table.remove(pool, math.random(1, #pool))
		table.insert(list, { Id = def.Id, Progress = 0, Claimed = false })
	end
	data = { Day = today(), List = list }
	player:SetAttribute("QuestData", HttpService:JSONEncode(data))
	return data
end

-- Adds progress to every quest of today that counts this stat.
function Quests.Add(player, statName, amount)
	if not player.Parent then
		return
	end
	local data = Quests.Ensure(player)
	local changed = false
	for _, q in data.List do
		local def = questDef(q.Id)
		if def and def.Stat == statName and q.Progress < def.Goal then
			q.Progress = math.min(def.Goal, q.Progress + (amount or 1))
			changed = true
			if q.Progress >= def.Goal then
				Util.Notify(player, "Good", "📜 Quest complete: " .. def.Text .. "! Claim it in the lobby.", "Coins")
			end
		end
	end
	if changed then
		player:SetAttribute("QuestData", HttpService:JSONEncode(data))
	end
end

-- Daily reward state: can they claim right now, and which day of the streak would it be?
function Quests.DailyStatus(player)
	local daily = decode(player:GetAttribute("DailyData")) or { LastDay = 0, Streak = 0 }
	local day = today()
	local canClaim = daily.LastDay ~= day
	local nextStreak = daily.Streak or 0
	if canClaim then
		nextStreak = (daily.LastDay == day - 1) and (nextStreak % #Config.DailyRewards) + 1 or 1
	end
	return canClaim, nextStreak, daily
end

local function claimQuest(player, id)
	local data = Quests.Ensure(player)
	for _, q in data.List do
		if q.Id == id then
			local def = questDef(id)
			if not def or q.Claimed or q.Progress < def.Goal then
				return false, "That quest isn't finished yet."
			end
			q.Claimed = true
			player:SetAttribute("QuestData", HttpService:JSONEncode(data))
			Util.AddTokens(player, def.Reward)
			task.spawn(Data.Save, player)
			return true, "+" .. def.Reward .. " Tokens!"
		end
	end
	return false, "Quest not found."
end

local function claimDaily(player)
	local canClaim, streak, daily = Quests.DailyStatus(player)
	if not canClaim then
		return false, "Come back tomorrow for your next reward!"
	end
	local reward = Config.DailyRewards[streak]
	-- Streak = day of the 7-day reward cycle, Total = days in a row (shown as "Your streak")
	local total = (daily.LastDay == today() - 1) and (daily.Total or daily.Streak or 0) + 1 or 1
	player:SetAttribute("DailyData", HttpService:JSONEncode({ LastDay = today(), Streak = streak, Total = total }))
	Util.AddTokens(player, reward)
	task.spawn(Data.Save, player)
	return true, "Day " .. streak .. " reward: +" .. reward .. " Tokens!"
end

function Quests.Init()
	Remotes.ClaimQuest.OnServerInvoke = claimQuest
	Remotes.ClaimDaily.OnServerInvoke = claimDaily
	Data.OnLoaded = function(player)
		Quests.Ensure(player)
		if not player:GetAttribute("DailyData") then
			player:SetAttribute("DailyData", HttpService:JSONEncode({ LastDay = 0, Streak = 0 }))
		end
	end
	-- roll over to new quests at midnight UTC for players who stay online
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				Quests.Ensure(player)
			end
		end
	end)
end

return Quests

-- Shop: buy trains and perks with Tokens, equip trains, and apply perk effects.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)
local Data = require(script.Parent.Data)

local Remotes = ReplicatedStorage.Remotes

local Shop = {}

local WALK_SPEED = 16

function Shop.ApplyPerks(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Data.Owns(player, "Sprinter") and WALK_SPEED * 1.25 or WALK_SPEED
	end
end

local function buy(player, id)
	local item, kind = Config.FindItem(type(id) == "string" and id or "")
	if not item then
		return false, "That item doesn't exist."
	end
	if Data.Owns(player, id) then
		return false, "You already own " .. item.Name .. "!"
	end
	local stats = player:FindFirstChild("leaderstats")
	local tokens = stats and stats:FindFirstChild("Tokens")
	if not tokens or tokens.Value < item.Price then
		return false, "Not enough Tokens! Win more rides to earn them."
	end
	tokens.Value -= item.Price
	player:SetAttribute("Owned_" .. id, true)
	if kind == "Train" then
		player:SetAttribute("EquippedTrain", id)
	else
		Shop.ApplyPerks(player)
	end
	task.spawn(Data.Save, player)
	return true, "You bought " .. item.Name .. "!"
end

local function equip(player, id)
	local item, kind = Config.FindItem(type(id) == "string" and id or "")
	if not item or kind ~= "Train" or not Data.Owns(player, id) then
		return false, "You don't own that train."
	end
	player:SetAttribute("EquippedTrain", id)
	return true, item.Name .. " equipped!"
end

function Shop.Init()
	Remotes.ShopBuy.OnServerInvoke = buy
	Remotes.ShopEquip.OnServerInvoke = equip

	local function watch(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			Shop.ApplyPerks(player)
		end)
		if player.Character then
			Shop.ApplyPerks(player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Shop

-- Small helpers shared by the server modules.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")

local Util = {
	Riders = {}, -- players on the current ride (set by GameServer)
}

-- kind: "Good", "Bad", "Warn" or "Info" (changes the colour on screen)
-- sound (optional): name of a sound in ReplicatedStorage.Sounds to play on their screen
function Util.Notify(player, kind, text, sound)
	Remotes.Notify:FireClient(player, kind, text, sound)
end

-- Tells everyone on the ride (not people waiting in the lobby).
function Util.NotifyAll(kind, text, sound)
	for _, player in Util.Riders do
		if player.Parent then
			Remotes.Notify:FireClient(player, kind, text, sound)
		end
	end
end

-- Plays a sound from ReplicatedStorage.Sounds at a part/attachment in the world (everyone hears it).
-- Returns the Sound so looping sounds can be stopped later.
function Util.PlaySound(name, parent, pitchVariation)
	local template = Sounds:FindFirstChild(name)
	if not template or not parent then
		return nil
	end
	local sound = template:Clone()
	if pitchVariation then
		sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * pitchVariation
	end
	sound.Parent = parent
	sound:Play()
	if not sound.Looped then
		-- TimeLength is 0 until the audio has loaded, so fall back to a safe guess
		local length = sound.TimeLength > 0 and sound.TimeLength or 6
		Debris:AddItem(sound, length / sound.PlaybackSpeed + 1)
	end
	return sound
end

-- Finds a tool the player is holding or has in their backpack.
function Util.FindItem(player, name)
	local character = player.Character
	local tool = character and character:FindFirstChild(name)
	if tool and tool:IsA("Tool") then
		return tool
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	tool = backpack and backpack:FindFirstChild(name)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

-- Finds a tool only if the player is holding it (equipped).
function Util.FindHeld(player, name)
	local character = player.Character
	local tool = character and character:FindFirstChild(name)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

function Util.CountItems(player)
	local count = 0
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					count += 1
				end
			end
		end
	end
	return count
end

function Util.SetupLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local tokens = Instance.new("IntValue")
	tokens.Name = "Tokens"
	tokens.Parent = stats
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = stats
	stats.Parent = player
end

function Util.AddTokens(player, amount)
	local stats = player:FindFirstChild("leaderstats")
	local tokens = stats and stats:FindFirstChild("Tokens")
	if tokens then
		tokens.Value += amount
		if amount > 0 then
			player:SetAttribute("TokensEarned", (player:GetAttribute("TokensEarned") or 0) + amount)
		end
	end
end

return Util

-- Snack machine and tool rack: click to grab items.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Config)
local Util = require(script.Parent.Util)

local train = workspace.Train
local templates = ServerStorage.Items

local Items = {}

local function give(player, name)
	if not player.Character then
		return
	end
	local maxCarry = Config.MaxCarry + (player:GetAttribute("Owned_BigPockets") and 2 or 0)
	if Util.CountItems(player) >= maxCarry then
		Util.Notify(player, "Warn", "Your hands are full! (max " .. maxCarry .. " items)")
		return
	end
	local item = templates[name]:Clone()
	item.Parent = player:FindFirstChildOfClass("Backpack")
	local emoji = Config.Snacks[name]
	Util.Notify(player, "Info", "Grabbed " .. item:GetAttribute("DisplayName") .. (emoji and (" " .. emoji) or ""))
end

function Items.Init()
	-- hotbar "drop" button: throws away the item you're holding
	ReplicatedStorage.Remotes.DropItem.OnServerEvent:Connect(function(player)
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		if tool and templates:FindFirstChild(tool.Name) then
			tool:Destroy()
		end
	end)

	for _, button in train.SnackMachine.Buttons:GetChildren() do
		button.ClickDetector.MouseClick:Connect(function(player)
			give(player, button:GetAttribute("Snack"))
		end)
	end

	-- clicking a tool you already carry puts it back on the rack
	for _, hit in train.ToolRack.Tools:GetChildren() do
		hit.ClickDetector.MouseClick:Connect(function(player)
			local name = hit:GetAttribute("Tool")
			local owned = Util.FindItem(player, name)
			if owned then
				owned:Destroy()
				Util.Notify(player, "Info", "Put the " .. templates[name]:GetAttribute("DisplayName") .. " back")
			else
				give(player, name)
			end
		end)
	end
end

return Items

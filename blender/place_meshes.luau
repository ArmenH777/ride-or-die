-- Studio-side helpers used to place meshes imported from blender/export/*.obj (run via the Studio MCP
-- as a temporary ModuleScript; it is not part of the game). The manifests come from export_all.py.
--   Kit.place(part, entry, palette)  puts an imported MeshPart where Blender had it, styled from the palette
--   Kit.swap(old, template)          replaces a functional part with a mesh copy (same name/CFrame/children)
local HttpService = game:GetService("HttpService")

local Kit = {}

-- Roblox's Import 3D turns every OBJ mesh 180 degrees around Y; this turns them back.
-- Template meshes are symmetric, so swaps don't need it.
Kit.FLIP = CFrame.Angles(0, math.pi, 0)

local cache = {}
-- Reads "<prefix>_manifest.json" from a local file server (HttpEnabled must be on while importing).
function Kit.manifest(prefix)
	if not cache[prefix] then
		local m = HttpService:JSONDecode(HttpService:GetAsync("http://127.0.0.1:8765/" .. prefix .. "_manifest.json"))
		m.byFile = {}
		for _, e in m.meshes do
			m.byFile[e.file:sub(1, -6)] = e
		end
		cache[prefix] = m
	end
	return cache[prefix]
end

function Kit.style(part, pal, palette)
	local p = palette[pal]
	part.Color = Color3.fromHex(p.color)
	if p.material == "Glass" then
		part.Material = Enum.Material.Glass
	elseif p.material == "Neon" then
		part.Material = Enum.Material.Neon
	else
		part.Material = Enum.Material.SmoothPlastic
	end
	part.Transparency = p.transparency
	part.Reflectance = 0
	part.CastShadow = p.material ~= "Glass" and p.material ~= "Neon"
end

function Kit.place(part, entry, palette)
	part.Anchored = true
	part.Name = entry.name
	part.CFrame = CFrame.new(entry.center[1], entry.center[2], entry.center[3]) * Kit.FLIP
	Kit.style(part, entry.pal, palette)
	-- collidable meshes are the walls/floors; Box collision keeps the camera inside the car
	part.CanCollide = entry.collide
	part.CanQuery = entry.collide
	part.CanTouch = false
	if entry.collide then
		part.CollisionFidelity = Enum.CollisionFidelity.Box
	end
end

function Kit.swap(old, template, keepLook)
	local new = template:Clone()
	new.Name = old.Name
	new.CFrame = old.CFrame
	new.Anchored = old.Anchored
	new.CanCollide = old.CanCollide
	new.CanQuery = old.CanQuery
	new.CanTouch = old.CanTouch
	if keepLook then
		new.Color = old.Color
		new.Material = old.Material
		new.Transparency = old.Transparency
	end
	for k, v in old:GetAttributes() do
		new:SetAttribute(k, v)
	end
	for _, child in old:GetChildren() do
		child.Parent = new
	end
	new.Parent = old.Parent
	old:Destroy()
	return new
end

function Kit.folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

return Kit

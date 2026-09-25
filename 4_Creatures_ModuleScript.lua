--[[
	GRAB A GOOBER  -  CREATURES  (v7)
	Script type : ModuleScript
	Name        : Creatures          (must be exactly "Creatures")
	Location    : ReplicatedStorage  (next to Config)

	Builds the 3D models for Goobers AND Pets: cats, bunnies, bears, penguins, robots,
	dragons, angels, jellyfish, crabs, mushrooms... in different body shapes and sizes.
	Which style a creature uses comes from Config (Goober.Style / Pet.Style).
]]

local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Config"))

local Creatures = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local ORANGE = Color3.fromRGB(255, 175, 55)
local PINK = Color3.fromRGB(255, 140, 170)

-- body proportions for each Shape (x, y, z)
local SHAPES = {
	egg = Vector3.new(0.9, 1.22, 0.9),
	wide = Vector3.new(1.3, 0.8, 1.05),
	tall = Vector3.new(0.8, 1.45, 0.8),
}

-- Optional custom 3D models: ReplicatedStorage > GooberModels / PetModels / BossModels > a Model named like the Goober / pet / boss.
local function findCustom(kind, id)
	if not id then
		return nil
	end
	local folder = RS:FindFirstChild(Config.CustomModels[kind])
	return folder and folder:FindFirstChild(id) or nil
end

local function customExtents(source)
	local ext = source:IsA("Model") and source:GetExtentsSize() or source.Size
	local longest = math.max(ext.X, ext.Y, ext.Z, 0.001)
	return ext.Y / longest, longest
end

local function nameHash(s)
	local h = 0
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 1000
	end
	return h / 1000
end

function Creatures.SpecForGoober(id, mutation)
	local def = Config.GooberById[id]
	local mut = Config.Mutations[mutation] or Config.Mutations.Normal
	local rar = Config.Rarities[def.Rarity]
	local img = Config.Images.Goober[id]
	return {
		Style = def.Style,
		Color = mut.Color or def.Color,
		Material = mut.Material,
		Rank = rar.Rank,
		RarityColor = rar.Color,
		Image = (img and img ~= "") and img or nil,
		-- rarer = bigger, plus a small per-Goober variation
		Scale = (Config.RarityScale[def.Rarity] or 1) * (0.92 + 0.16 * nameHash(id)),
		Mutation = mutation or "Normal",
		Custom = findCustom("Goobers", id),
	}
end

function Creatures.SpecForPet(id)
	local def = Config.PetById[id]
	local rar = Config.Rarities[def.Rarity]
	return { Style = def.Style, Color = def.Color, Rank = rar.Rank, RarityColor = rar.Color, Scale = 1, Mutation = "Normal", Custom = findCustom("Pets", id) }
end

-- a boss (cfg comes from Config.BossFor)
function Creatures.SpecForBoss(cfg)
	return { Style = cfg.Style, Color = cfg.Color, Rank = 6, RarityColor = cfg.Color, Scale = 1, Mutation = "Normal", Custom = findCustom("Bosses", cfg.Name) }
end

-- how tall the body is (so callers can stand it on the ground)
function Creatures.HalfHeight(spec, size)
	if spec.Custom then
		local aspect = customExtents(spec.Custom)
		return 0.5 * size * (spec.Scale or 1) * aspect
	end
	local st = Config.Styles[spec.Style or "blob"] or {}
	local sy = (SHAPES[st.Shape] and SHAPES[st.Shape].Y) or (st.Boxy and 0.9) or 1
	return 0.5 * size * (spec.Scale or 1) * sy
end

-- builds YOUR 3D model instead of the built-in shape (see Config.CustomModels). Returns the main part.
local function buildCustom(spec, size, cf, anchored, parent)
	local clone = spec.Custom:Clone()
	local _, longest = customExtents(clone)
	local target = size * (spec.Scale or 1)
	local parts = {}
	if clone:IsA("Model") then
		clone:ScaleTo(clone:GetScale() * target / longest)
		clone:PivotTo(cf)
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
	else
		clone.Size = clone.Size * (target / longest)
		clone.CFrame = cf
		parts[1] = clone
	end
	local body = (clone:IsA("Model") and clone.PrimaryPart) or parts[1]
	if not body then
		error("custom model '" .. tostring(spec.Custom.Name) .. "' has no parts in it")
	end
	local recolor = spec.Mutation ~= nil and spec.Mutation ~= "Normal"
	for _, p in ipairs(parts) do
		p.CanCollide = false
		p.Massless = true
		p.Anchored = anchored
		if recolor then -- mutations (Golden, Neon...) recolour a custom model completely
			p.Color = spec.Color
			if spec.Material then
				p.Material = spec.Material
			end
		end
		if not anchored and p ~= body then
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = p
			w.Parent = p
		end
	end
	clone.Parent = parent
	return body
end

-- spec = { Style, Color, Material?, Rank, RarityColor, Image?, Scale?, Custom? }
-- size = body diameter in studs. cf = where the FRONT of the creature (-Z) points.
-- Returns the body part. Every other part is welded to it and parented under it.
function Creatures.Build(spec, size, cf, anchored, parent)
	if spec.Custom then
		return buildCustom(spec, size, cf, anchored, parent)
	end
	local S = size * (spec.Scale or 1)
	local st = Config.Styles[spec.Style or "blob"] or {}
	local col = spec.Color
	local light = col:Lerp(WHITE, 0.55)
	local dark = col:Lerp(BLACK, 0.4)
	local rank = spec.Rank or 1
	local rcol = spec.RarityColor or WHITE
	local boxy = st.Boxy == true
	local shape = SHAPES[st.Shape]
	local sx, sy, sz = 1, 1, 1
	if shape then
		sx, sy, sz = shape.X, shape.Y, shape.Z
	elseif boxy then
		sx, sy, sz = 0.95, 0.9, 0.9
	end
	local hx, hy, hz = 0.5 * S * sx, 0.5 * S * sy, 0.5 * S * sz -- half sizes of the body
	local dy = hy - 0.5 * S -- how far the top (and bottom) moved compared to a ball
	local function X(v) -- side positions follow the body width
		return v * sx
	end

	local body = Instance.new("Part")
	body.Name = "Goober"
	body.Size = Vector3.new(hx * 2, hy * 2, hz * 2)
	if boxy then
		body.Shape = Enum.PartType.Block
	elseif shape then
		body.Shape = Enum.PartType.Block
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = body
	else
		body.Shape = Enum.PartType.Ball
	end
	body.CFrame = cf
	body.Anchored = anchored
	body.CanCollide = false
	body.Massless = true
	body.Color = col
	body.Material = spec.Material or Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	if st.Ghost then
		body.Transparency = 0.12
	end
	body.Parent = parent

	-- kind: "ball" (ellipsoid), "block", "cyl" (axis = local X, so roll it 90 degrees to stand it up)
	local function add(name, kind, sz3, off, color, material, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz3
		p.CFrame = cf * off
		p.Anchored = anchored
		p.CanCollide = false
		p.Massless = true
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if kind == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		elseif kind == "ball" then
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = p
		end
		p.Parent = body
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = p
		w.Parent = p
		return p
	end
	local V, CF = Vector3.new, CFrame.new
	local function rz(deg)
		return CFrame.Angles(0, 0, math.rad(deg))
	end
	local UP = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder upright

	-- height of the front surface at (x, y) so eyes sit ON the body
	local function surf(x, y)
		if boxy then
			return -0.45 * S
		end
		local k = 1 - (x / hx) ^ 2 - (y / hy) ^ 2
		return -hz * math.sqrt(math.max(k, 0.04))
	end

	-- ===== BACK / SIDE PARTS (behind the face) =====
	if st.Wings then
		local wc = st.Halo and light or dark
		for _, s in ipairs({ -1, 1 }) do
			add("Wing", "ball", V(S * 0.5, S * 0.09, S * 0.32), CF(s * X(S * 0.52), S * 0.08, S * 0.22) * CFrame.Angles(0, s * math.rad(-25), s * math.rad(-22)), wc)
		end
	end
	if st.Tail then
		add("Tail", "ball", V(S * 0.24, S * 0.24, S * 0.24), CF(0, -S * 0.28 - dy * 0.5, hz), (spec.Style == "bunny") and WHITE or light)
	end
	if st.Ears == "round" then
		for _, s in ipairs({ -1, 1 }) do
			add("Ear", "ball", V(S * 0.3, S * 0.3, S * 0.14), CF(s * X(S * 0.31), S * 0.4 + dy, 0), col)
			add("EarInner", "ball", V(S * 0.17, S * 0.17, S * 0.05), CF(s * X(S * 0.31), S * 0.4 + dy, -S * 0.05), PINK)
		end
	elseif st.Ears == "point" then
		for _, s in ipairs({ -1, 1 }) do
			add("Ear", "block", V(S * 0.24, S * 0.24, S * 0.1), CF(s * X(S * 0.27), S * 0.44 + dy, 0) * rz(45), col)
			add("EarInner", "block", V(S * 0.13, S * 0.13, S * 0.06), CF(s * X(S * 0.27), S * 0.44 + dy, -S * 0.03) * rz(45), PINK)
		end
	elseif st.Ears == "long" then
		for _, s in ipairs({ -1, 1 }) do
			add("Ear", "ball", V(S * 0.17, S * 0.55, S * 0.1), CF(s * X(S * 0.17), S * 0.72 + dy, 0) * rz(-s * 9), col)
			add("EarInner", "ball", V(S * 0.08, S * 0.4, S * 0.05), CF(s * X(S * 0.17), S * 0.72 + dy, -S * 0.03) * rz(-s * 9), PINK)
		end
	end
	if st.Flippers then
		for _, s in ipairs({ -1, 1 }) do
			add("Flipper", "ball", V(S * 0.13, S * 0.36, S * 0.2), CF(s * (hx + S * 0.02), -S * 0.05, 0) * rz(s * 22), dark)
		end
	end
	if st.Claws then
		for _, s in ipairs({ -1, 1 }) do
			add("Claw", "ball", V(S * 0.3, S * 0.26, S * 0.26), CF(s * (hx + S * 0.06), -S * 0.08, -S * 0.12), dark)
			add("ClawTip", "ball", V(S * 0.14, S * 0.14, S * 0.14), CF(s * (hx + S * 0.16), S * 0.06, -S * 0.12), dark)
		end
	end
	if st.Arms then
		for _, s in ipairs({ -1, 1 }) do
			add("Arm", "ball", V(S * 0.2, S * 0.34, S * 0.2), CF(s * (hx + S * 0.02), S * 0.04, 0) * rz(s * 15), col)
		end
	end
	if st.Fins then
		add("DorsalFin", "block", V(S * 0.22, S * 0.22, S * 0.06), CF(0, hy, S * 0.05) * rz(45), light)
		for _, s in ipairs({ -1, 1 }) do
			add("SideFin", "ball", V(S * 0.06, S * 0.26, S * 0.3), CF(s * hx, -S * 0.1, S * 0.05), light)
		end
	end
	if st.Ghost then
		for i = 1, 6 do
			local a = (i / 6) * math.pi * 2
			add("Skirt", "ball", V(S * 0.24, S * 0.24, S * 0.24), CF(math.cos(a) * hx * 0.6, -hy + S * 0.08, math.sin(a) * hz * 0.6), col, nil, 0.12)
		end
	end
	if st.Tentacles then
		for i = 1, 6 do
			local a = (i / 6) * math.pi * 2
			add("Tentacle", "ball", V(S * 0.15, S * 0.34, S * 0.15), CF(math.cos(a) * hx * 0.5, -hy - S * 0.04, math.sin(a) * hz * 0.5), col, nil, 0.2)
		end
	end
	if st.Puffs then
		add("Puff", "ball", V(S * 0.5, S * 0.5, S * 0.5), CF(-X(S * 0.4), S * 0.12 + dy, 0), light)
		add("Puff", "ball", V(S * 0.5, S * 0.5, S * 0.5), CF(X(S * 0.4), S * 0.12 + dy, 0), light)
		add("Puff", "ball", V(S * 0.52, S * 0.52, S * 0.52), CF(0, S * 0.42 + dy, 0), light)
	end
	if st.Spikes then
		for i = 1, 3 do
			add("Spike", "block", V(S * 0.16, S * 0.16, S * 0.06), CF(0, S * (0.52 - i * 0.12) + dy, S * (0.05 + i * 0.13)) * CFrame.Angles(math.rad(45), 0, 0), ORANGE)
		end
	end

	-- ===== TOP PARTS =====
	if st.Cap then
		local capCol = rcol:Lerp(Color3.fromRGB(230, 70, 110), 0.5)
		add("MushroomCap", "ball", V(S * 1.25, S * 0.62, S * 1.25), CF(0, hy - S * 0.05, 0), capCol)
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2
			add("CapSpot", "ball", V(S * 0.2, S * 0.1, S * 0.2), CF(math.cos(a) * S * 0.38, hy + S * 0.16, math.sin(a) * S * 0.38), WHITE)
		end
	end
	if st.Horn then
		for i = 1, 3 do
			add("Horn", "cyl", V(S * 0.13, S * (0.17 - i * 0.04), S * (0.17 - i * 0.04)), CF(0, S * (0.5 + i * 0.1) + dy, 0) * UP, i == 3 and Color3.fromRGB(255, 240, 150) or WHITE, Enum.Material.Neon)
		end
	end
	if st.Horns then
		for _, s in ipairs({ -1, 1 }) do
			for i = 1, 2 do
				add("Horn", "cyl", V(S * 0.12, S * (0.13 - i * 0.03), S * (0.13 - i * 0.03)), CF(s * X(S * 0.24 + i * S * 0.02), S * (0.44 + i * 0.1) + dy, 0) * rz(90 - s * 12), ORANGE)
			end
		end
	end
	if st.Antenna then
		add("AntennaStem", "cyl", V(S * 0.3, S * 0.05, S * 0.05), CF(0, S * 0.62 + dy, 0) * UP, dark)
		add("AntennaTip", "ball", V(S * 0.14, S * 0.14, S * 0.14), CF(0, S * 0.8 + dy, 0), rcol, Enum.Material.Neon)
	end
	if st.Antennae then
		for _, s in ipairs({ -1, 1 }) do
			add("Stalk", "cyl", V(S * 0.32, S * 0.05, S * 0.05), CF(s * X(S * 0.16), S * 0.6 + dy, 0) * rz(90 - s * 14), dark)
			add("StalkTip", "ball", V(S * 0.13, S * 0.13, S * 0.13), CF(s * X(S * 0.23), S * 0.77 + dy, 0), Color3.fromRGB(150, 255, 170), Enum.Material.Neon)
		end
	end
	if st.Sprout then
		add("Stem", "cyl", V(S * 0.2, S * 0.045, S * 0.045), CF(0, S * 0.55 + dy, 0) * UP, Color3.fromRGB(90, 190, 90))
		for _, s in ipairs({ -1, 1 }) do
			add("Leaf", "ball", V(S * 0.24, S * 0.07, S * 0.14), CF(s * S * 0.11, S * 0.66 + dy, 0) * rz(s * 22), Color3.fromRGB(110, 220, 100))
		end
	end
	if st.Frosting then
		add("Frosting", "ball", V(S * 0.72, S * 0.3, S * 0.72), CF(0, S * 0.38 + dy, 0), Color3.fromRGB(255, 200, 225))
		add("Frosting", "ball", V(S * 0.46, S * 0.26, S * 0.46), CF(0, S * 0.56 + dy, 0), Color3.fromRGB(255, 225, 240))
		add("Cherry", "ball", V(S * 0.14, S * 0.14, S * 0.14), CF(0, S * 0.7 + dy, 0), Color3.fromRGB(230, 40, 60))
	end
	if st.HatTop then
		add("HatBrim", "cyl", V(S * 0.05, S * 0.56, S * 0.56), CF(0, S * 0.47 + dy, 0) * UP, Color3.fromRGB(35, 35, 45))
		add("HatCrown", "cyl", V(S * 0.3, S * 0.34, S * 0.34), CF(0, S * 0.62 + dy, 0) * UP, Color3.fromRGB(45, 45, 60))
		add("HatBand", "cyl", V(S * 0.07, S * 0.36, S * 0.36), CF(0, S * 0.53 + dy, 0) * UP, Color3.fromRGB(220, 60, 70))
	end
	if st.Crown then
		local gold = Color3.fromRGB(255, 205, 60)
		add("CrownBand", "cyl", V(S * 0.09, S * 0.52, S * 0.52), CF(0, S * 0.52 + dy, 0) * UP, gold, Enum.Material.Neon)
		for i = -1, 1 do
			add("CrownSpike", "block", V(S * 0.15, S * 0.15, S * 0.1), CF(i * S * 0.18, S * 0.63 + dy, 0) * rz(45), gold, Enum.Material.Neon)
		end
	end
	if rank >= 4 or st.Halo then
		add("Halo", "cyl", V(S * 0.09, S * 0.62, S * 0.62), CF(0, S * 0.72 + dy, 0) * UP, rcol, Enum.Material.Neon, 0.1)
	end

	-- ===== FACE =====
	if spec.Image then
		local d = Instance.new("Decal")
		d.Texture = spec.Image
		d.Face = Enum.NormalId.Front
		d.Parent = body
		return body
	end
	if st.Belly then
		add("Belly", "ball", V(S * 0.56 * sx, S * 0.42, S * 0.1), CF(0, -S * 0.3, surf(0, -S * 0.3) + S * 0.02), light)
	end
	if st.Visor then
		add("Visor", "block", V(S * 0.72, S * 0.3, S * 0.06), CF(0, S * 0.12, -S * 0.46), Color3.fromRGB(25, 30, 48))
		for _, s in ipairs({ -1, 1 }) do
			add("RobotEye", "block", V(S * 0.16, S * 0.14, S * 0.05), CF(s * S * 0.18, S * 0.12, -S * 0.5), Color3.fromRGB(80, 255, 255), Enum.Material.Neon)
		end
		add("Grille", "block", V(S * 0.3, S * 0.07, S * 0.05), CF(0, -S * 0.15, -S * 0.46), Color3.fromRGB(40, 45, 60))
	else
		for _, s in ipairs({ -1, 1 }) do
			local ex, ey = s * S * 0.2 * sx, S * 0.14
			local eyeCol = st.Ghost and Color3.fromRGB(25, 25, 40) or WHITE
			add("Eye", "ball", V(S * 0.26, S * 0.3, S * 0.12), CF(ex, ey, surf(ex, ey) + S * 0.018), eyeCol)
			if not st.Ghost then
				add("Pupil", "ball", V(S * 0.13, S * 0.16, S * 0.08), CF(ex, ey - S * 0.01, surf(ex, ey) - S * 0.035), Color3.fromRGB(20, 20, 30))
				add("Shine", "ball", V(S * 0.05, S * 0.05, S * 0.03), CF(ex + S * 0.03, ey + S * 0.05, surf(ex, ey) - S * 0.045), WHITE)
				local cx, cy = s * S * 0.32 * sx, -S * 0.04
				add("Cheek", "ball", V(S * 0.14, S * 0.08, S * 0.04), CF(cx, cy, surf(cx, cy) + S * 0.005), PINK, Enum.Material.Neon, 0.25)
			end
		end
		if st.Beak then
			add("Beak", "ball", V(S * 0.2, S * 0.13, S * 0.18), CF(0, -S * 0.02, surf(0, -S * 0.02) - S * 0.02), ORANGE)
		else
			add("Mouth", "ball", V(S * 0.2, S * 0.09, S * 0.05), CF(0, -S * 0.1, surf(0, -S * 0.1) - S * 0.005), Color3.fromRGB(70, 20, 45))
		end
	end
	if st.Nose then
		add("Nose", "cyl", V(S * 0.3, S * 0.07, S * 0.07), CF(0, -S * 0.02, -hz - S * 0.05) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 130, 40))
	end
	if st.Whiskers then
		for _, s in ipairs({ -1, 1 }) do
			for k = -1, 1, 2 do
				add("Whisker", "block", V(S * 0.3, S * 0.014, S * 0.014), CF(s * S * 0.4, -S * 0.09 + k * S * 0.04, -S * 0.3) * rz(s * k * 10), WHITE)
			end
		end
	end
	return body
end

return Creatures
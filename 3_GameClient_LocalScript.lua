--[[
	GRAB A GOOBER: ESCAPE THE FLOOD  -  CLIENT  (v7, all UI is built by code)
	Script type : LocalScript
	Name        : GameClient
	Location    : StarterPlayer > StarterPlayerScripts
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
player.CameraMinZoomDistance = 8
player.CameraMaxZoomDistance = 75 -- enough to see the zone around you, not so much you can see past the walls into empty space
local camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera -- if Roblox ever swaps the camera object, everything keeps following the new one
end)
local Config = require(RS:WaitForChild("Config"))
local Creatures = require(RS:WaitForChild("Creatures"))
local Remotes = RS:WaitForChild("Remotes")
local Action = Remotes:WaitForChild("Action")
local Notify = Remotes:WaitForChild("Notify")
local Announce = Remotes:WaitForChild("Announce")
local UI = Remotes:WaitForChild("UI")
local F = Config.Format

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(60, 210, 100)
local GREY = Color3.fromRGB(110, 110, 125)
local GOLD = Color3.fromRGB(255, 190, 40)
local BLUE = Color3.fromRGB(70, 140, 255)
local PINK = Color3.fromRGB(255, 100, 190)
local FONT = Enum.Font.FredokaOne

local play -- sound function (defined below)

----------------------------------------------------------------
-- UI helpers (bubbly = round corners + thick outlines + fredoka font)
----------------------------------------------------------------
local function make(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

local function corner(parent, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 12) }, parent)
end

local function stroke(parent, thickness, color)
	return make("UIStroke", { Thickness = thickness or 2, Color = color or BLACK }, parent)
end

local function label(props, parent)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = FONT
	props.TextColor3 = props.TextColor3 or WHITE
	local l = make("TextLabel", props, parent)
	stroke(l, 2.5, Color3.fromRGB(40, 14, 70)) -- deep grape outline: softer and more cartoony than pure black
	return l
end

local function makeButton(props, parent, color)
	props.Font = FONT
	props.TextColor3 = WHITE
	props.AutoButtonColor = false
	props.BackgroundColor3 = color
	local btn = make("TextButton", props, parent)
	make("UICorner", { CornerRadius = UDim.new(0.34, 0) }, btn)
	stroke(btn, 2.5) -- outlines the text
	make("UIGradient", { -- candy shading: bright top half, shaded bottom, like a jelly bean
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 240, 240)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 165)),
		}),
		Rotation = 90,
	}, btn)
	-- bubble outline ring + glossy highlight
	local ring = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false }, btn)
	make("UICorner", { CornerRadius = UDim.new(0.34, 0) }, ring)
	make("UIStroke", { Thickness = 3.5, Color = color:Lerp(BLACK, 0.55), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
	local gloss = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.new(0.84, 0, 0.26, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.7, Active = false }, btn)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, gloss)
	local sc = make("UIScale", {}, btn)
	local function tw(s)
		TweenService:Create(sc, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Scale = s }):Play()
	end
	btn.MouseEnter:Connect(function()
		tw(1.07)
	end)
	btn.MouseLeave:Connect(function()
		tw(1)
	end)
	btn.MouseButton1Down:Connect(function()
		tw(0.9)
	end)
	btn.MouseButton1Up:Connect(function()
		tw(1.07)
	end)
	btn.Activated:Connect(function()
		play("click")
	end)
	return btn
end

local function panel(props, parent)
	local f = make("Frame", props, parent)
	f.BackgroundColor3 = Color3.fromRGB(120, 86, 240) -- grape-soda purple
	f.BackgroundTransparency = 0.03
	corner(f, 24)
	make("UIStroke", { Thickness = 3.5, Color = WHITE, Transparency = 0.05 }, f)
	make("UIGradient", { -- top-to-bottom: bright, then a bubblegum-pink tint at the bottom
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(225, 215, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 175, 225)),
		}),
		Rotation = 90,
	}, f)
	return f
end

-- soft see-through bubbles in the corners of a window or card (pure decoration, it sits behind everything else)
local function bubbleDeco(parent)
	for _, s in ipairs({ { 0.06, 0.12, 70 }, { 0.93, 0.2, 46 }, { 0.84, 0.88, 90 }, { 0.12, 0.92, 54 }, { 0.5, 0.98, 34 }, { 0.98, 0.58, 28 } }) do
		local b = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(s[1], s[2]), Size = UDim2.fromOffset(s[3], s[3]), BackgroundColor3 = WHITE, BackgroundTransparency = 0.86, Active = false }, parent)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
		make("UIStroke", { Thickness = 2, Color = WHITE, Transparency = 0.7 }, b)
	end
end

-- little glyphs drawn from frames (on the round badge of each left-hand button)
local function drawIcon(parent, kind)
	local DARK = Color3.fromRGB(60, 44, 110)
	local function sh(x, y, w, h, rot, round, col, z)
		local f = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Rotation = rot or 0,
			BackgroundColor3 = col or WHITE,
			ZIndex = z or 2,
			Active = false,
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(round or 0.5, 0) }, f)
		return f
	end
	local function hollow(x, y, w, h, round)
		local f = sh(x, y, w, h, 0, round)
		f.BackgroundTransparency = 1
		make("UIStroke", { Thickness = 2, Color = WHITE }, f)
		return f
	end
	if kind == "shop" then -- an up arrow: UPGRADES
		sh(0.5, 0.36, 0.42, 0.42, 45, 0.12)
		sh(0.5, 0.68, 0.2, 0.34, 0, 0.2)
	elseif kind == "index" then -- an open book
		sh(0.34, 0.5, 0.34, 0.54, -6, 0.15)
		sh(0.66, 0.5, 0.34, 0.54, 6, 0.15)
		sh(0.5, 0.5, 0.05, 0.54, 0, 0.3, DARK, 3)
	elseif kind == "pets" then
		for _, p in ipairs({ { 0.27, 0.36 }, { 0.42, 0.24 }, { 0.58, 0.24 }, { 0.73, 0.36 } }) do
			sh(p[1], p[2], 0.17, 0.2)
		end
		sh(0.5, 0.64, 0.42, 0.34)
	elseif kind == "base" then
		sh(0.5, 0.36, 0.44, 0.44, 45, 0.12)
		sh(0.5, 0.66, 0.46, 0.34, 0, 0.12)
		sh(0.5, 0.72, 0.12, 0.2, 0, 0.3, DARK, 3)
	elseif kind == "market" then
		sh(0.5, 0.4, 0.44, 0.44)
		sh(0.5, 0.66, 0.24, 0.24, 45, 0.1)
		sh(0.5, 0.4, 0.16, 0.16, 0, 0.5, DARK, 3)
	elseif kind == "trade" then
		sh(0.48, 0.36, 0.5, 0.1, 0, 0.5)
		sh(0.8, 0.36, 0.16, 0.16, 45, 0.12)
		sh(0.52, 0.64, 0.5, 0.1, 0, 0.5)
		sh(0.2, 0.64, 0.16, 0.16, 45, 0.12)
	elseif kind == "codes" then
		sh(0.5, 0.5, 0.64, 0.42, 0, 0.2)
		sh(0.18, 0.5, 0.14, 0.2, 0, 0.5, DARK, 3)
		sh(0.82, 0.5, 0.14, 0.2, 0, 0.5, DARK, 3)
		sh(0.5, 0.5, 0.26, 0.08, 0, 0.5, DARK, 3)
	elseif kind == "daily" then
		sh(0.5, 0.64, 0.5, 0.34, 0, 0.15)
		sh(0.5, 0.44, 0.6, 0.16, 0, 0.3, Color3.fromRGB(255, 225, 120))
		sh(0.5, 0.56, 0.1, 0.56, 0, 0.2, Color3.fromRGB(255, 120, 170), 3)
		sh(0.4, 0.28, 0.2, 0.16, -20, 0.5, Color3.fromRGB(255, 120, 170), 3)
		sh(0.6, 0.28, 0.2, 0.16, 20, 0.5, Color3.fromRGB(255, 120, 170), 3)
	elseif kind == "group" then
		for _, x in ipairs({ 0.34, 0.66 }) do
			sh(x, 0.34, 0.22, 0.22)
			sh(x, 0.64, 0.3, 0.28, 0, 0.5)
		end
	elseif kind == "donate" then -- a little heart
		sh(0.35, 0.4, 0.32, 0.32, 0, 0.5)
		sh(0.65, 0.4, 0.32, 0.32, 0, 0.5)
		sh(0.5, 0.62, 0.42, 0.42, 45, 0.12)
	elseif kind == "settings" then
		for _, a in ipairs({ 0, 45, 90, 135 }) do
			sh(0.5, 0.5, 0.74, 0.15, a, 0.3)
		end
		sh(0.5, 0.5, 0.5, 0.5)
		sh(0.5, 0.5, 0.2, 0.2, 0, 0.5, DARK, 3)
	elseif kind == "admin" then
		sh(0.5, 0.46, 0.46, 0.5, 0, 0.3)
		sh(0.5, 0.68, 0.32, 0.32, 45, 0.15)
		sh(0.5, 0.46, 0.18, 0.18, 45, 0.15, Color3.fromRGB(255, 200, 60), 3)
	elseif kind == "trails" then -- three speed streaks and a sparkle
		sh(0.44, 0.3, 0.62, 0.12, -12, 0.5)
		sh(0.4, 0.5, 0.74, 0.14, -12, 0.5)
		sh(0.44, 0.7, 0.56, 0.12, -12, 0.5)
		sh(0.8, 0.46, 0.2, 0.2, 45, 0.15, Color3.fromRGB(255, 225, 90), 3)
	elseif kind == "rebirth" then -- a renewal ring with a little spark, like a refresh symbol
		hollow(0.5, 0.5, 0.6, 0.6, 0.5)
		sh(0.76, 0.28, 0.16, 0.05, 40, 0.3)
		sh(0.8, 0.34, 0.05, 0.16, 40, 0.3)
		sh(0.5, 0.5, 0.14, 0.14, 0, 0.5, Color3.fromRGB(255, 210, 90), 3)
	end
end

-- a bubbly button with a round icon badge on the left. Returns the button and its text label.
local function bubbleButton(props, parent, color, icon, text)
	props.Text = ""
	local b = makeButton(props, parent, color)
	local disc = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = color:Lerp(BLACK, 0.32), Active = false }, b)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, disc)
	make("UIStroke", { Thickness = 2.5, Color = WHITE, Transparency = 0.15 }, disc)
	drawIcon(disc, icon)
	local l = label({ Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -52, 1, 0), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Text = text }, b)
	return b, l
end

-- Draws a creature (cat, bunny, robot, dragon...) out of UI frames. spec = { Style, Color, RarityColor, Rank, Image }
-- Uses the same style table as the 3D models (Config.Styles) so cards match what you see in the world.
local function drawCreature(parent, spec, px)
	local st = Config.Styles[spec.Style or "blob"] or {}
	local col = spec.Color
	local light = col:Lerp(WHITE, 0.55)
	local dark = col:Lerp(BLACK, 0.4)
	local rcol = spec.RarityColor or WHITE
	local rank = spec.Rank or 1
	local ORANGE = Color3.fromRGB(255, 175, 55)
	local PINKC = Color3.fromRGB(255, 140, 170)
	local holder = make("Frame", { Size = UDim2.fromOffset(px, px), BackgroundTransparency = 1 }, parent)
	-- x, y = center (0..1), w, h = size (0..1)
	local function shape(x, y, w, h, color, z, rot, roundness)
		local f = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundColor3 = color,
			ZIndex = z or 2,
			Rotation = rot or 0,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(roundness or 0.5, 0) }, f)
		return f
	end
	local BY = 0.57 -- body center y
	-- body proportions follow the 3D shape (egg / wide / tall), so cards match the models in the world
	local bw, bh = 0.72, 0.68
	if st.Shape == "egg" then
		bw, bh, BY = 0.62, 0.78, 0.58
	elseif st.Shape == "wide" then
		bw, bh, BY = 0.88, 0.56, 0.6
	elseif st.Shape == "tall" then
		bw, bh, BY = 0.56, 0.8, 0.58
	end

	-- behind the body
	if st.Wings then
		shape(0.07, 0.48, 0.3, 0.2, light, 1, 30)
		shape(0.93, 0.48, 0.3, 0.2, light, 1, -30)
	end
	if st.Puffs then
		shape(0.15, 0.55, 0.34, 0.34, light, 1)
		shape(0.85, 0.55, 0.34, 0.34, light, 1)
		shape(0.5, 0.2, 0.36, 0.36, light, 1)
	end
	if st.Tail then
		shape(0.87, 0.82, 0.18, 0.18, (spec.Style == "bunny") and WHITE or light, 1)
	end
	if st.Ears == "round" then
		shape(0.24, 0.2, 0.22, 0.22, col, 1)
		shape(0.76, 0.2, 0.22, 0.22, col, 1)
	elseif st.Ears == "point" then
		shape(0.27, 0.2, 0.2, 0.2, col, 1, 45, 0.12)
		shape(0.73, 0.2, 0.2, 0.2, col, 1, 45, 0.12)
	elseif st.Ears == "long" then
		shape(0.36, 0.1, 0.14, 0.34, col, 1, -8)
		shape(0.64, 0.1, 0.14, 0.34, col, 1, 8)
		shape(0.36, 0.1, 0.06, 0.24, PINKC, 1, -8)
		shape(0.64, 0.1, 0.06, 0.24, PINKC, 1, 8)
	end
	if st.Flippers then
		shape(0.1, 0.6, 0.12, 0.3, dark, 1, 20)
		shape(0.9, 0.6, 0.12, 0.3, dark, 1, -20)
	end
	if st.Claws then
		shape(0.09, 0.62, 0.2, 0.2, dark, 1)
		shape(0.91, 0.62, 0.2, 0.2, dark, 1)
	end
	if st.Arms then
		shape(0.1, 0.58, 0.14, 0.3, col, 1)
		shape(0.9, 0.58, 0.14, 0.3, col, 1)
	end
	if st.Fins then
		shape(0.5, 0.15, 0.2, 0.2, light, 1, 45, 0.12)
	end
	if st.Ghost then
		for _, x in ipairs({ 0.3, 0.43, 0.57, 0.7 }) do
			shape(x, 0.92, 0.15, 0.15, col, 1)
		end
	end
	if st.Tentacles then
		for _, x in ipairs({ 0.3, 0.43, 0.57, 0.7 }) do
			shape(x, 0.93, 0.1, 0.22, col, 1)
		end
	end
	if st.Spikes then
		for i = 1, 3 do
			shape(0.72 + i * 0.05, 0.28 - i * 0.03, 0.09, 0.09, ORANGE, 1, 45, 0.1)
		end
	end
	if st.Antenna then
		shape(0.5, 0.11, 0.03, 0.16, dark, 1, 0, 0)
		shape(0.5, 0.03, 0.09, 0.09, rcol, 1)
	end
	if st.Antennae then
		shape(0.36, 0.12, 0.03, 0.2, dark, 1, -14, 0)
		shape(0.64, 0.12, 0.03, 0.2, dark, 1, 14, 0)
		shape(0.33, 0.03, 0.09, 0.09, Color3.fromRGB(150, 255, 170), 1)
		shape(0.67, 0.03, 0.09, 0.09, Color3.fromRGB(150, 255, 170), 1)
	end
	if st.Horn then
		shape(0.5, 0.1, 0.09, 0.22, Color3.fromRGB(255, 245, 190), 1, 0, 0.3)
	end
	if st.Horns then
		shape(0.3, 0.13, 0.08, 0.2, ORANGE, 1, -22, 0.3)
		shape(0.7, 0.13, 0.08, 0.2, ORANGE, 1, 22, 0.3)
	end
	if st.Sprout then
		shape(0.5, 0.11, 0.03, 0.16, Color3.fromRGB(90, 190, 90), 1, 0, 0)
		shape(0.42, 0.05, 0.14, 0.07, Color3.fromRGB(110, 220, 100), 1, -20)
		shape(0.58, 0.05, 0.14, 0.07, Color3.fromRGB(110, 220, 100), 1, 20)
	end
	if st.Frosting then
		shape(0.5, 0.2, 0.5, 0.2, Color3.fromRGB(255, 200, 225), 1)
		shape(0.5, 0.1, 0.32, 0.16, Color3.fromRGB(255, 225, 240), 1)
		shape(0.5, 0.02, 0.09, 0.09, Color3.fromRGB(230, 40, 60), 1)
	end
	if st.HatTop then
		shape(0.5, 0.2, 0.5, 0.06, Color3.fromRGB(35, 35, 45), 3, 0, 0.5)
		shape(0.5, 0.1, 0.28, 0.2, Color3.fromRGB(45, 45, 60), 1, 0, 0.1)
	end
	if rank >= 4 or st.Halo then
		local halo = shape(0.5, 0.03, 0.4, 0.09, rcol, 4)
		halo.BackgroundTransparency = 0.15
	end

	-- body
	local body = shape(0.5, BY, bw, bh, col, 2, 0, st.Boxy and 0.16 or 0.5)
	make("UIStroke", { Thickness = math.max(2, px / 26), Color = rcol }, body)
	make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 190, 190)), Rotation = 90 }, body)
	if st.Ghost then
		body.BackgroundTransparency = 0.1
	end
	if spec.Image then
		make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = spec.Image, ScaleType = Enum.ScaleType.Fit, ZIndex = 6 }, holder)
		return holder
	end
	if st.Belly then
		shape(0.5, 0.72, 0.4, 0.26, light, 3)
	end
	if st.Cap then -- mushroom cap with white spots
		local capCol = rcol:Lerp(Color3.fromRGB(230, 70, 110), 0.5)
		local cap = shape(0.5, 0.2, 0.96, 0.36, capCol, 3)
		make("UIStroke", { Thickness = math.max(2, px / 30), Color = capCol:Lerp(BLACK, 0.4) }, cap)
		shape(0.3, 0.2, 0.12, 0.09, WHITE, 4)
		shape(0.52, 0.12, 0.13, 0.1, WHITE, 4)
		shape(0.72, 0.22, 0.1, 0.08, WHITE, 4)
	end

	-- face
	if st.Visor then
		shape(0.5, 0.5, 0.56, 0.2, Color3.fromRGB(25, 30, 48), 3, 0, 0.3)
		shape(0.38, 0.5, 0.12, 0.1, Color3.fromRGB(80, 255, 255), 4, 0, 0.3)
		shape(0.62, 0.5, 0.12, 0.1, Color3.fromRGB(80, 255, 255), 4, 0, 0.3)
	else
		for _, x in ipairs({ 0.38, 0.62 }) do
			local eyeCol = st.Ghost and Color3.fromRGB(25, 25, 40) or WHITE
			local eye = shape(x, 0.5, 0.15, 0.19, eyeCol, 4)
			if not st.Ghost then
				local pupil = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.62, 0.62), BackgroundColor3 = Color3.fromRGB(20, 20, 30), ZIndex = 5 }, eye)
				make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pupil)
				shape(x < 0.5 and 0.27 or 0.73, 0.64, 0.1, 0.06, PINKC, 4)
			end
		end
		if st.Beak then
			shape(0.5, 0.62, 0.17, 0.1, ORANGE, 5)
		else
			shape(0.5, 0.68, 0.18, 0.07, Color3.fromRGB(70, 20, 45), 4)
		end
	end
	if st.Nose then
		shape(0.5, 0.62, 0.2, 0.06, Color3.fromRGB(255, 130, 40), 5)
	end
	if st.Whiskers then
		for _, sx in ipairs({ 0.2, 0.8 }) do
			shape(sx, 0.62, 0.16, 0.012, WHITE, 5, 0, 0)
			shape(sx, 0.67, 0.16, 0.012, WHITE, 5, 0, 0)
		end
	end
	return holder
end

-- A cute UI version of a Goober or a Pet (used on cards, trade window, shop, reveal)
-- A real 3D picture: the very same model the world uses, shown in a ViewportFrame (Config.Icons3D). Small icons stay flat (faster).
local function icon3D(parent, spec, px)
	local holder = make("Frame", { Size = UDim2.fromOffset(px, px), BackgroundTransparency = 1 }, parent)
	local vp = make("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(190, 190, 205), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-0.4, -0.7, -0.6) }, holder)
	local model = Instance.new("Model")
	model.Parent = vp
	local size = 4
	Creatures.Build(spec, size, CFrame.new(0, Creatures.HalfHeight(spec, size), 0), true, model)
	local extent = size * (spec.Scale or 1)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(extent * 0.18, extent * 0.55, -extent * 2.7), Vector3.new(0, extent * 0.45, 0)) -- creatures face -Z, so the camera stands in front
	cam.Parent = vp
	vp.CurrentCamera = cam
	return holder
end

local function gooberIcon(parent, id, mut, px)
	local spec = Creatures.SpecForGoober(id, mut or "Normal")
	if Config.Icons3D and px >= 44 then
		return icon3D(parent, spec, px)
	end
	return drawCreature(parent, spec, px)
end

local function petIcon(parent, id, px)
	local spec = Creatures.SpecForPet(id)
	if Config.Icons3D and px >= 44 then
		return icon3D(parent, spec, px)
	end
	return drawCreature(parent, spec, px)
end

-- 12-point golden sunburst (used for the sale star)
local function burst(parent, px, color)
	local holder = make("Frame", { Size = UDim2.fromOffset(px, px), BackgroundTransparency = 1 }, parent)
	for i = 0, 2 do
		local sq = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.72, 0.72),
			Rotation = i * 30,
			BackgroundColor3 = color,
		}, holder)
		stroke(sq, 3)
	end
	return holder
end

local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local screen = make("ScreenGui", {
	Name = "GooberGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, -- keeps buttons out of phone notches
}, player:WaitForChild("PlayerGui"))

-- Everything lives inside "gui", which is scaled to fit the screen: phones get a smaller UI, big monitors a bigger one.
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local gui = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, screen)
local rootScale = make("UIScale", {}, gui)
local function updateScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = math.clamp(math.min(vp.X / 1100, vp.Y / 560), 0.62, 1.25)
	rootScale.Scale = s
	gui.Size = UDim2.fromScale(1 / s, 1 / s)
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)

----------------------------------------------------------------
-- LOADING SCREEN (shows the logo until the world is built, then the intro takes over)
----------------------------------------------------------------
local introOverlay = make("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 60,
}, gui)
do -- a candy sky that slowly swirls
	local bg = make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 90, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 190, 255)),
		}),
		Rotation = 60,
	}, introOverlay)
	TweenService:Create(bg, TweenInfo.new(8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 150 }):Play()
end
local loadTitle = label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.38),
	Size = UDim2.fromOffset(820, 140),
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "GRAB A GOOBER!",
	ZIndex = 61,
}, introOverlay)
loadTitle.Font = Enum.Font.LuckiestGuy
loadTitle:FindFirstChildOfClass("UIStroke").Thickness = 8
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 250, 150), Color3.fromRGB(255, 160, 40)), Rotation = 90 }, loadTitle) -- golden candy letters
loadTitle.Rotation = -3
TweenService:Create(loadTitle, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 3 }):Play()
local loadBarBg = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromOffset(440, 30), BackgroundColor3 = Color3.fromRGB(50, 25, 110), ZIndex = 61 }, introOverlay)
corner(loadBarBg, 15)
stroke(loadBarBg, 4, WHITE)
local loadBar = make("Frame", { Size = UDim2.fromScale(0.05, 1), BackgroundColor3 = WHITE, ZIndex = 62, ClipsDescendants = true }, loadBarBg)
corner(loadBar, 15)
do -- rainbow-candy fill whose stripes scroll along
	local keys = {}
	local cols = { Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 225, 90), Color3.fromRGB(120, 230, 255) }
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, cols[i % 3 + 1]))
	end
	local stripes = make("UIGradient", { Color = ColorSequence.new(keys) }, loadBar)
	stripes.Offset = Vector2.new(-0.5, 0)
	TweenService:Create(stripes, TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(0.5, 0) }):Play()
end
local loadTip = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.79), Size = UDim2.fromOffset(640, 28), TextSize = 20, TextColor3 = WHITE, Text = "Loading...", ZIndex = 61 }, introOverlay)
do
	-- everything decorative lives in LoadDeco, so the intro can clear it in one go
	local deco = make("Frame", { Name = "LoadDeco", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 60 }, introOverlay)
	label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(520, 44), TextScaled = true, TextColor3 = Color3.fromRGB(190, 240, 255), Text = "🌊 ESCAPE THE FLOOD! 🌊" }, deco)
	-- three Goober mascots bouncing along the bottom
	local picks, seen = {}, {}
	for _, want in ipairs({ "Common", "Epic", "Mythic" }) do
		for _, g in ipairs(Config.Goobers) do
			if g.Rarity == want and not seen[want] then
				seen[want] = true
				table.insert(picks, g)
			end
		end
	end
	for i, g in ipairs(picks) do
		local rar = Config.Rarities[g.Rarity]
		local slot = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.2 + (i - 1) * 0.3, 0, 1, -24), Size = UDim2.fromOffset(110, 110), BackgroundTransparency = 1 }, deco)
		local art = drawCreature(slot, { Style = g.Style, Color = g.Color, RarityColor = rar.Color, Rank = rar.Rank }, 110)
		art.Position = UDim2.fromOffset(0, 0)
		TweenService:Create(slot, TweenInfo.new(0.45 + i * 0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true), { Position = UDim2.new(0.2 + (i - 1) * 0.3, 0, 1, -54) }):Play()
	end
	-- soapy bubbles drifting up the screen
	task.spawn(function()
		while deco.Parent do
			local sz = math.random(18, 64)
			local b = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(math.random(), 0, 1, sz), Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = WHITE, BackgroundTransparency = 0.8 }, deco)
			corner(b, sz / 2)
			make("UIStroke", { Thickness = 2, Color = WHITE, Transparency = 0.4 }, b)
			local d = 3 + math.random() * 3
			tween(b, d, { Position = UDim2.new(b.Position.X.Scale + (math.random() - 0.5) * 0.15, 0, 0, -sz) }, Enum.EasingStyle.Sine)
			task.delay(d, function()
				b:Destroy()
			end)
			task.wait(0.22)
		end
	end)
end
local LOAD_TIPS = {
	"Floods can't hurt you in the plaza 🏝️",
	"Walk on a pad to collect your money 💰",
	"Rebirth to carry more Goobers ✨",
	"Galaxy, Chocolate and Toxic Goobers give you perks 🌌🍫☢️",
	"A zone's boss wakes up if you steal ITS Goobers 👹",
	"Some waves are jumpable... some are NOT 🌈😈",
}
loadTip.Text = LOAD_TIPS[math.random(#LOAD_TIPS)]
task.spawn(function()
	local t, nextTip = 0, 2.8
	while introOverlay.Parent and not workspace:GetAttribute("WorldReady") do
		t += 0.1
		loadBar.Size = UDim2.fromScale(math.min(0.92, 0.05 + t * 0.09), 1)
		if t >= nextTip and loadTip.Parent then
			nextTip = t + 2.8
			loadTip.Text = LOAD_TIPS[math.random(#LOAD_TIPS)]
		end
		task.wait(0.1)
	end
	if loadBar.Parent then
		loadBar.Size = UDim2.fromScale(1, 1)
	end
end)

-- red flash for flood announcements (created first so it sits behind everything)
local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BackgroundTransparency = 1, Active = false }, gui)

local settings, startMusic, setMusic, setSfx, MOODS
----------------------------------------------------------------
-- NPC ARM POSES (shared by the NPCs in the world and by Gus's portrait in the shop window)
-- Every pose is computed from the torso, so it always looks right.
----------------------------------------------------------------
local function npcPoseArms(torso, rArm, lArm, rDeg, lDeg, rFwd, lFwd)
	local function pose(arm, side, deg, fwd)
		local shoulder = torso.CFrame * CFrame.new(side * 1.5, 1, 0)
		arm.CFrame = shoulder * CFrame.Angles(math.rad(fwd or 0), 0, math.rad(deg) * side) * CFrame.new(0, -1, 0)
	end
	pose(rArm, 1, rDeg, rFwd)
	pose(lArm, -1, lDeg, lFwd)
end

local function npcPoseLegs(torso, rLeg, lLeg, rDeg, lDeg)
	local function pose(leg, side, deg)
		local hip = torso.CFrame * CFrame.new(side * 0.5, -1, 0)
		leg.CFrame = hip * CFrame.Angles(math.rad(deg), 0, 0) * CFrame.new(0, -1, 0)
	end
	pose(rLeg, 1, rDeg)
	pose(lLeg, -1, lDeg)
end

-- Every NPC has its own idle behaviour. Returns: right arm out, left arm out, right arm forward, left arm forward, right leg, left leg (degrees).
-- states: "idle", "hello" (big wave), "bye" (slower wave). Personas: pete (jogs on the spot), gus (tinkers with a gadget),
-- bea (shrugs, shifts her weight), cleo (hugs an egg and bounces).
local function npcTargetAngles(state, t, phase, persona)
	local rS, lS = 7 + 4 * math.sin(t * 1.6 + phase), 7 + 4 * math.sin(t * 1.6 + phase + 1.4)
	local rF, lF, rL, lL = 0, 0, 0, 0
	if persona == "pete" then
		local s = math.sin(t * 7 + phase)
		rS, lS = 8, 8
		rF, lF = 42 * s, -42 * s
		rL, lL = -34 * s, 34 * s
	elseif persona == "gus" then
		rS = 14 + 8 * math.sin(t * 1.3 + phase)
		rF = 40 + 22 * math.sin(t * 2.6 + phase)
		lS = 12
		lF = 34 + 6 * math.sin(t * 1.1)
	elseif persona == "bea" then
		local shrug = math.max(0, math.sin(t * 0.75 + phase)) ^ 10
		rS, lS = 9 + 34 * shrug, 9 + 34 * shrug
		rF, lF = -8, -8
		rL, lL = 4 * math.sin(t * 0.9), -4 * math.sin(t * 0.9)
	elseif persona == "cleo" then
		local b = math.sin(t * 3 + phase)
		rS, lS = 4, 4
		rF, lF = 55 + 6 * b, 55 + 6 * b
		rL, lL = 5 * b, -5 * b
	end
	if state == "hello" then
		rS, rF = 140 + 26 * math.sin(t * 8), 0
	elseif state == "bye" then
		rS, rF = 136 + 30 * math.sin(t * 5.5), 0
	end
	return rS, lS, rF, lF, rL, lL
end

-- Gus's window asks the world NPC to wave goodbye (assigned by the world code below)
local npcSay
-- admin fly + tutorial hooks (assigned in the world code further down)
local setFly, startTutorial, tutorialCutscene, itemArt, startWheel
local wackPunch -- makes the custom Wacker button swing (assigned in the world code)
local flyOn, flySpeed = false, 80


do
	----------------------------------------------------------------
	-- SOUND + MUSIC
	-- Uses Roblox's built-in sounds as a fallback so it works out of the box.
	-- Put real audio ids into Config.Sounds for a much better sound.
	----------------------------------------------------------------
	local SND_PING = "rbxasset://sounds/electronicpingshort.wav"
	local SND_SWISH = "rbxasset://sounds/swordslash.wav"
	local SND_OOF = "rbxasset://sounds/uuhhh.mp3"
	local SND_CLICK = "rbxasset://sounds/clickfast.wav"

	local sfxGroup = make("SoundGroup", { Name = "GooberSFX", Volume = Config.Sounds.SfxVolume }, SoundService)
	local musicGroup = make("SoundGroup", { Name = "GooberMusic", Volume = Config.Sounds.MusicVolume }, SoundService)
	settings = { music = true, sfx = true, lowPerf = false }

	local function playRaw(id, pitch, volume, group)
		local s = Instance.new("Sound")
		s.SoundId = id
		s.PlaybackSpeed = pitch or 1
		s.Volume = volume or 0.6
		s.SoundGroup = group or sfxGroup
		s.Parent = SoundService
		s:Play()
		s.Ended:Connect(function()
			s:Destroy()
		end)
		task.delay(8, function()
			if s.Parent then
				s:Destroy()
			end
		end)
	end

	local function tone(pitch, vol)
		playRaw(SND_PING, pitch, vol or 0.5)
	end

	local function seq(notes, gap, vol)
		task.spawn(function()
			for _, p in ipairs(notes) do
				tone(p, vol)
				task.wait(gap)
			end
		end)
	end

	local SFX = {
		pop = function()
			tone(1.6, 0.28)
		end,
		grab = function()
			seq({ 1.4, 2 }, 0.06, 0.3)
		end,
		deposit = function()
			seq({ 1, 1.25, 1.5, 2 }, 0.07, 0.55)
		end,
		sell = function()
			seq({ 2, 2.5 }, 0.08, 0.5)
		end,
		buy = function()
			seq({ 1.2, 1.6 }, 0.07, 0.5)
		end,
		error = function()
			seq({ 0.6, 0.45 }, 0.1, 0.6)
		end,
		click = function()
			playRaw(SND_CLICK, 1.2, 0.45)
		end,
		reveal = function()
			seq({ 1, 1.25, 1.5, 2, 2.5 }, 0.08, 0.6)
		end,
		trap = function()
			playRaw(SND_SWISH, 0.6, 0.9)
			task.delay(0.1, function()
				tone(0.4, 0.8)
			end)
		end,
		wack = function()
			playRaw(SND_SWISH, 1.1, 0.9)
		end,
		stuck = function()
			playRaw(SND_OOF, 1, 0.9)
		end,
		alarm = function() -- an urgent two-tone siren: a boss just woke up because you picked up its egg
			seq({ 2.2, 1.3, 2.2, 1.3 }, 0.09, 0.7)
		end,
		whoosh = function() -- teleport: a quick rising chime
			seq({ 0.8, 1.0, 1.25, 1.6, 2.0 }, 0.035, 0.3)
		end,
		lift = function() -- elevator: two soft rising notes
			seq({ 1.0, 1.5 }, 0.09, 0.3)
		end,
		crack = function() -- egg cracking
			seq({ 0.7, 0.55, 0.8 }, 0.05, 0.4)
		end,
		collect = function() -- coins
			seq({ 2.0, 2.6, 3.2 }, 0.045, 0.4)
		end,
		horn = function() -- loud blaring horn: three low double-blasts
			task.spawn(function()
				for _ = 1, 3 do
					tone(0.28, 1)
					tone(0.35, 1)
					task.wait(0.55)
				end
			end)
		end,
	}
	local SFX_KEYS = {
		pop = "Pop", grab = "Grab", deposit = "Deposit", sell = "Sell", buy = "Buy", error = "Error", click = "Click",
		reveal = "Reveal", trap = "Trap", wack = "Wack", stuck = "Stuck", whoosh = "Whoosh", horn = "Horn", lift = "Lift", collect = "Collect", alarm = "Alarm",
	}

	function play(name)
		if not settings.sfx then
			return
		end
		local key = SFX_KEYS[name]
		local custom = key and Config.Sounds[key]
		if custom and custom ~= "" then
			playRaw(custom, 1, 0.9)
			return
		end
		local fn = SFX[name]
		if fn then
			fn()
		end
	end

	-- posts a message into ROBLOX'S OWN chat window (every player in the server sees it there), in a bubbly rounded
	-- font - separate from this game's own toast/banner UI, which stays as it was
	function postToRobloxChat(text)
		task.spawn(function()
			local channels = TextChatService:FindFirstChild("TextChannels")
			local general = channels and channels:FindFirstChild("RBXGeneral")
			if not general then
				return
			end
			local rich = ('<font face="FredokaOne" size="20" color="#FF69B4">%s</font>'):format(text)
			pcall(function()
				general:DisplaySystemMessage(rich)
			end)
		end)
	end

	local musicStarted = false
	function startMusic()
		musicStarted = true
	end

	-- Calm, spacious sound: a soft reverb and a gentle high-cut on everything in the music group.
	make("ReverbSoundEffect", { DecayTime = 3.5, Density = 0.9, Diffusion = 0.9, DryLevel = 0, WetLevel = -4 }, musicGroup)
	make("EqualizerSoundEffect", { LowGain = 2, MidGain = 0, HighGain = -6 }, musicGroup) -- (was -16: that cut made it sound muffled and quiet)

	local function musicTarget()
		return settings.music and Config.Sounds.MusicVolume or 0
	end

	local function fadeMusic(toVolume, seconds)
		TweenService:Create(musicGroup, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = toVolume }):Play()
	end

	-- Built-in generative soundtrack: slow wandering notes in a gentle scale, a soft bass note now and then,
	-- and a NEW mood (different scale / key / tempo) every minute or so. Never the same loop twice.
	-- Kept deliberately calm: a slow beat, plenty of space between notes, and a melody that mostly steps or holds
	-- rather than leaping around, so it sits in the background instead of demanding attention.
	MOODS = {
		{ name = "Morning", scale = { 0, 2, 4, 7, 9 }, root = 0, beat = 2.0, density = 0.26 },
		{ name = "Dusk", scale = { 0, 3, 5, 7, 10 }, root = -2, beat = 2.3, density = 0.24 },
		{ name = "Lagoon", scale = { 0, 2, 4, 6, 7, 9, 11 }, root = 3, beat = 2.1, density = 0.24 },
		{ name = "Starlight", scale = { 0, 2, 7, 9, 12 }, root = 5, beat = 2.6, density = 0.2 },
		{ name = "Meadow", scale = { 0, 2, 4, 5, 7, 9 }, root = -4, beat = 1.95, density = 0.24 },
	}

	local function shuffled(n)
		local t = {}
		for i = 1, n do
			t[i] = i
		end
		for i = n, 2, -1 do
			local j = math.random(i)
			t[i], t[j] = t[j], t[i]
		end
		return t
	end

	task.spawn(function()
		local ids = Config.Sounds.MusicIds
		while not musicStarted do
			task.wait(0.1)
		end
		local switchEvery = Config.Sounds.MusicSwitchSeconds

		if #ids > 0 then
			-- real songs: shuffled playlist, a new song every MusicSwitchSeconds (or when the song ends), with fades
			local order, i = shuffled(#ids), 1
			while true do
				local s = Instance.new("Sound")
				s.SoundId = ids[order[i]]
				s.Volume = 0
				s.SoundGroup = musicGroup
				s.Parent = SoundService
				local ended = false
				s.Ended:Connect(function()
					ended = true
				end)
				s:Play()
				TweenService:Create(s, TweenInfo.new(2.5), { Volume = 1 }):Play()
				local waited = 0
				repeat
					task.wait(1)
					waited += 1
				until ended or not s.Parent or waited >= switchEvery or (s.TimeLength == 0 and waited > 10)
				TweenService:Create(s, TweenInfo.new(2.5), { Volume = 0 }):Play()
				task.wait(2.6)
				s:Destroy()
				i += 1
				if i > #order then
					order, i = shuffled(#ids), 1
				end
			end
		end

		local moodIdx = math.random(#MOODS)
		local nextSwitch = os.clock() + switchEvery * (0.8 + math.random() * 0.4)
		local pos, step = 3, 0
		while true do
			local mood = MOODS[moodIdx]
			if os.clock() > nextSwitch then
				fadeMusic(0, 2)
				task.wait(2.2)
				local new = math.random(#MOODS)
				while new == moodIdx do
					new = math.random(#MOODS)
				end
				moodIdx = new
				mood = MOODS[moodIdx]
				pos = math.random(2, #mood.scale)
				fadeMusic(musicTarget(), 2)
				nextSwitch = os.clock() + switchEvery * (0.8 + math.random() * 0.4)
			end
			if settings.music then
				step += 1
				if math.random() < mood.density then
					-- mostly a small step, or holding the same note - a smooth, settled melody rather than a jumpy one
					local moves = { -1, -1, 0, 0, 0, 1, 1 }
					pos = math.clamp(pos + moves[math.random(#moves)], 1, #mood.scale + 2)
					local octave = (pos - 1) // #mood.scale
					local deg = mood.scale[(pos - 1) % #mood.scale + 1] + 12 * octave
					playRaw(SND_PING, 0.36 * 2 ^ ((mood.root + deg) / 12), 0.3 + math.random() * 0.08, musicGroup)
				end
				if step % 6 == 1 then -- a soft, sparse bass note underneath
					playRaw(SND_PING, 0.18 * 2 ^ (mood.root / 12), 0.36, musicGroup)
				end
			end
			task.wait(mood.beat * (0.9 + math.random() * 0.2))
		end
	end)

	function setMusic(on)
		settings.music = on
		fadeMusic(musicTarget(), 0.5)
	end
	function setSfx(on)
		settings.sfx = on
	end
	function setLowPerf(on) -- fewer particles, no shadows, no tree-sway/ripple animation - all client-local, nobody else is affected
		settings.lowPerf = on
		local Lighting = game:GetService("Lighting")
		local ok = pcall(function()
			Lighting.GlobalShadows = not on
		end)
		if on then
			for _, inst in ipairs(workspace:GetDescendants()) do
				if inst:IsA("ParticleEmitter") then
					inst.Enabled = false
				end
			end
		end
	end

end

local toast
do
	----------------------------------------------------------------
	-- TOAST MESSAGES (bottom-center, pops in)
	----------------------------------------------------------------
	local toastLabel = label({
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 42),
		Position = UDim2.new(0.5, 0, 1, -150),
		TextSize = 22,
		TextTransparency = 1,
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
	}, gui)
	toastLabel.BackgroundColor3 = Color3.fromRGB(95, 45, 175)
	make("UIPadding", { PaddingLeft = UDim.new(0, 24), PaddingRight = UDim.new(0, 24) }, toastLabel)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, toastLabel)
	-- no outline: just the indigo pill and the coloured text (a coloured text-stroke looked like a jagged mismatched red line)
	local toastStroke = toastLabel:FindFirstChildOfClass("UIStroke")
	toastStroke.Thickness = 0
	toastStroke.Transparency = 1
	local toastScale = make("UIScale", {}, toastLabel)

	local toastId = 0
	function toast(msg, color, sfx)
		if msg == nil or msg == "" then
			if sfx then
				play(sfx)
			end
			return
		end
		toastId += 1
		local id = toastId
		toastLabel.Text = msg
		toastLabel.TextColor3 = color or WHITE
		toastLabel.TextTransparency = 0
		toastLabel.BackgroundTransparency = 0.1
		toastScale.Scale = 0.6
		tween(toastScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		if sfx then
			play(sfx)
		elseif color == RED then
			play("error")
		end
		task.delay(3.5, function()
			if id == toastId then
				tween(toastLabel, 0.6, { TextTransparency = 1, BackgroundTransparency = 1 })
			end
		end)
	end
	Notify.OnClientEvent:Connect(toast)

end

----------------------------------------------------------------
-- HUD (top-left): animated cash counter, income, and three small chips
----------------------------------------------------------------
local stats = panel({
	Size = UDim2.fromOffset(262, 98),
	Position = UDim2.fromOffset(12, 58),
}, gui)

-- coin icon
local coin = make("Frame", { Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.fromRGB(255, 200, 50) }, stats)
corner(coin, 19)
stroke(coin, 2.5)
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 210), Color3.fromRGB(230, 160, 20)), Rotation = 60 }, coin)
local coinRing = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.68, 0.68), BackgroundTransparency = 1 }, coin)
corner(coinRing, 14)
make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(190, 120, 10) }, coinRing)
label({ Size = UDim2.fromScale(1, 1), TextSize = 22, TextColor3 = Color3.fromRGB(150, 90, 0), Text = "$" }, coin):FindFirstChildOfClass("UIStroke").Thickness = 0

local cashL = label({ Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -66, 0, 30), TextSize = 30, TextColor3 = Color3.fromRGB(130, 255, 150), TextXAlignment = Enum.TextXAlignment.Left, Text = "$0" }, stats)
local incomeL = label({ Position = UDim2.fromOffset(58, 36), Size = UDim2.new(1, -66, 0, 18), TextSize = 16, TextColor3 = Color3.fromRGB(255, 220, 110), TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, stats)
incomeL:FindFirstChildOfClass("UIStroke").Thickness = 1.8

local chipRow = make("Frame", { Position = UDim2.fromOffset(10, 62), Size = UDim2.new(1, -20, 0, 26), BackgroundTransparency = 1 }, stats)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, chipRow)
local function statChip(color, width)
	local c = label({ Size = UDim2.fromOffset(width, 26), BackgroundTransparency = 0, BackgroundColor3 = color:Lerp(BLACK, 0.45), TextSize = 14, Text = "" }, chipRow)
	corner(c, 13)
	local st = c:FindFirstChildOfClass("UIStroke")
	st.Color = color
	st.Thickness = 1.8
	return c
end
local bagChip = statChip(Color3.fromRGB(255, 170, 60), 76)
local baseChip = statChip(Color3.fromRGB(110, 235, 130), 88)
local rebChip = statChip(Color3.fromRGB(230, 130, 255), 58)

do
	local cashPop = make("UIScale", {}, cashL)
	local lastCash = player:GetAttribute("Cash") or 0
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local now = player:GetAttribute("Cash") or 0
		if now > lastCash then
			cashPop.Scale = 1.14
			tween(cashPop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		lastCash = now
	end)
	coin.Rotation = -8
	TweenService:Create(coin, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 8 }):Play()
end

-- the cash number rolls up smoothly instead of jumping
local displayCash = 0
RunService.RenderStepped:Connect(function(dt)
	local target = player:GetAttribute("Cash") or 0
	displayCash += (target - displayCash) * math.min(1, dt * 7)
	if math.abs(target - displayCash) < 1 or target < displayCash and target < 1000 then
		displayCash = target
	end
	cashL.Text = "$" .. F(displayCash)
end)

-- AUTO COLLECT (only shown if you own the game pass): one tap banks every Goober's cash instantly
local collectBtn = makeButton({ Position = UDim2.fromOffset(12, 162), Size = UDim2.fromOffset(262, 40), TextSize = 16, Text = "💰 COLLECT ALL" }, gui, Color3.fromRGB(255, 200, 60))
collectBtn.Activated:Connect(function()
	if player:GetAttribute("Own_AutoCollect") == true then
		Action:FireServer("CollectAll")
	else
		local id = Config.GamePasses.AutoCollect.Id
		if id > 0 then
			MarketplaceService:PromptGamePassPurchase(player, id)
		end
	end
end)

-- PERK CHIPS (bottom-right): one pill per active boost, stacking upward as more become active. Hover (PC) or tap
-- (touch) a chip to see what it actually does and exactly how long is left.
local boostRow = make("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = isTouch and UDim2.new(1, -14, 1, -360) or UDim2.new(1, -14, 1, -14),
	Size = UDim2.fromOffset(170, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.Name }, boostRow)
local boostChips, boostTip = {}, nil
do
	boostTip = make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(250, 62), BackgroundColor3 = Color3.fromRGB(30, 26, 60), Visible = false, ZIndex = 20 }, gui)
	corner(boostTip, 12)
	stroke(boostTip, 2.5, WHITE)
	label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, boostTip).Name = "Title"
	label({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 32), TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(210, 210, 235), TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, boostTip).Name = "Desc"
end
-- Puts the tooltip to the LEFT of a chip, and always fully on screen. (AbsolutePosition is in real screen pixels but the
-- tooltip lives inside the scaled "gui" frame, so it has to be converted - that mismatch is what pushed it off-screen.)
function placeTip(chip)
	local sc = rootScale.Scale
	local rel = (chip.AbsolutePosition - gui.AbsolutePosition) / sc
	local chipH = chip.AbsoluteSize.Y / sc
	local tipW, tipH = boostTip.Size.X.Offset, boostTip.Size.Y.Offset
	local screenW, screenH = gui.AbsoluteSize.X / sc, gui.AbsoluteSize.Y / sc
	local x = math.clamp(rel.X - 8, tipW + 6, screenW - 6)
	local y = math.clamp(rel.Y + chipH / 2, tipH / 2 + 6, screenH - tipH / 2 - 6)
	boostTip.Position = UDim2.fromOffset(x, y)
end
for _, info in ipairs({
	{ "Speed", Color3.fromRGB(70, 210, 255) }, { "Jump", Color3.fromRGB(120, 255, 130) }, { "Shield", Color3.fromRGB(255, 220, 70) },
	{ "Cash", Color3.fromRGB(90, 230, 120) }, { "Magnet", Color3.fromRGB(190, 120, 255) }, { "Guard", Color3.fromRGB(80, 150, 255) },
	}) do
	local kind, col = info[1], info[2]
	local chip = make("TextButton", { Name = kind, Size = UDim2.fromOffset(170, 34), BackgroundColor3 = col:Lerp(BLACK, 0.35), Text = "", Visible = false, AutoButtonColor = false }, boostRow)
	corner(chip, 17)
	local chStroke = stroke(chip, 2.5, col)
	label({ Size = UDim2.fromScale(1, 1), TextSize = 15, Text = "" }, chip).Name = "Label"
	local shownItem
	for _, it in ipairs(Config.ShopItems) do
		if it.Id == kind then
			shownItem = it
		end
	end
	local function showTip()
		if not shownItem then
			return
		end
		placeTip(chip)
		boostTip.Title.Text = shownItem.Label
		boostTip.Title.TextColor3 = col
		local remaining = math.max(0, math.ceil((player:GetAttribute("Boost" .. kind) or 0) - workspace:GetServerTimeNow()))
		boostTip.Desc.Text = shownItem.Desc .. "  (" .. remaining .. "s left)"
		boostTip.Visible = true
	end
	local function hideTip()
		boostTip.Visible = false
	end
	if isTouch then
		chip.Activated:Connect(function()
			if boostTip.Visible then
				hideTip()
			else
				showTip()
			end
		end)
	else
		chip.MouseEnter:Connect(showTip)
		chip.MouseLeave:Connect(hideTip)
	end
	boostChips[kind] = { Chip = chip, Stroke = chStroke, Label = chip.Label, Col = col }
end

-- MUTATION PERK chips: one per event mutation (Galaxy / Chocolate / Toxic) you have placed in your base. Same pill style.
do
	local PERK_ICON = { Galaxy = "🌌", Chocolate = "🍫", Toxic = "☢️" }
	local chips = {}
	for i, name in ipairs(Config.EventMutations or {}) do
		local def = Config.Mutations[name]
		local col = def.Color
		local chip = make("TextButton", { Name = "Perk" .. i, Size = UDim2.fromOffset(170, 34), BackgroundColor3 = col:Lerp(BLACK, 0.35), Text = "", Visible = false, AutoButtonColor = false }, boostRow)
		corner(chip, 17)
		stroke(chip, 2.5, col)
		label({ Size = UDim2.fromScale(1, 1), TextSize = 15, Text = (PERK_ICON[name] or "✨") .. " " .. name:upper() .. " PERK" }, chip)
		local function showTip()
			placeTip(chip)
			boostTip.Title.Text = name .. " Goober placed"
			boostTip.Title.TextColor3 = col
			boostTip.Desc.Text = def.PerkText or ""
			boostTip.Visible = true
		end
		if isTouch then
			chip.Activated:Connect(function()
				if boostTip.Visible then
					boostTip.Visible = false
				else
					showTip()
				end
			end)
		else
			chip.MouseEnter:Connect(showTip)
			chip.MouseLeave:Connect(function()
				boostTip.Visible = false
			end)
		end
		chips[name] = chip
	end
	local function refreshPerks()
		local have = {}
		for n in (player:GetAttribute("MutPerks") or ""):gmatch("[^,]+") do
			have[n] = true
		end
		for name, chip in pairs(chips) do
			chip.Visible = have[name] == true
		end
	end
	player:GetAttributeChangedSignal("MutPerks"):Connect(refreshPerks)
	refreshPerks()
end

-- Base Lock chip: same style as the potion chips, but its own simple tooltip (it isn't a Gus shop item)
do -- scoped: lockChipStroke/lockShowTip are only needed to build this chip once; lockChip/lockChipLabel escape as globals (needed by the HUD loop)
	lockChip = make("TextButton", { Name = "Lock", Size = UDim2.fromOffset(170, 34), BackgroundColor3 = Color3.fromRGB(120, 130, 255):Lerp(BLACK, 0.35), Text = "", Visible = false, AutoButtonColor = false }, boostRow)
	corner(lockChip, 17)
	lockChipStroke = stroke(lockChip, 2.5, Color3.fromRGB(120, 130, 255))
	lockChipLabel = label({ Size = UDim2.fromScale(1, 1), TextSize = 15, Text = "" }, lockChip)
	local function lockShowTip()
		placeTip(lockChip)
		boostTip.Title.Text = "Base Lock"
		boostTip.Title.TextColor3 = Color3.fromRGB(120, 130, 255)
		local remaining = math.max(0, math.ceil((player:GetAttribute("LockedUntil") or 0) - workspace:GetServerTimeNow()))
		boostTip.Desc.Text = "Nobody can steal from your base.  (" .. remaining .. "s left)"
		boostTip.Visible = true
	end
	if isTouch then
		lockChip.Activated:Connect(function()
			if boostTip.Visible then
				boostTip.Visible = false
			else
				lockShowTip()
			end
		end)
	else
		lockChip.MouseEnter:Connect(lockShowTip)
		lockChip.MouseLeave:Connect(function()
			boostTip.Visible = false
		end)
	end
end

----------------------------------------------------------------
-- FLOOD BANNER (top-center) + EVENT TEXT
----------------------------------------------------------------
local banner = panel({
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(400, 44),
	Position = UDim2.new(0.5, 0, 0, 66), -- (under the track bar)
}, gui)
local bannerText = label({ Size = UDim2.fromScale(1, 1), TextSize = 20, Text = "" }, banner)
function waveTag(name) -- each wave type has its own fixed emoji (looked up by name), shown right next to its name
	if not name or name == "" then
		return ""
	end
	for _, wt in ipairs(Config.WaveTypes) do
		if wt.Name == name then
			return (wt.Emoji or "") .. "  "
		end
	end
	return ""
end

local eventL = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(520, 26),
	Position = UDim2.new(0.5, 0, 0, 116),
	TextColor3 = Color3.fromRGB(255, 140, 255),
	TextSize = 17,
	Text = "",
}, gui)

-- MUTATION HOUR icon: top-right, hover/tap to see which mutation is favored and what perk it gives
-- (mutationIcon/mutationTip/mutationTipDesc are left as implicit globals - no "local" - so they don't cost a top-level register)
do
	mutationIcon = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = Color3.fromRGB(150, 90, 230), Visible = false, ZIndex = 6 }, gui)
	corner(mutationIcon, 26)
	stroke(mutationIcon, 3, WHITE)
	local mutLabel = label({ Size = UDim2.fromScale(1, 1), TextSize = 28, Text = "✨" }, mutationIcon)
	local mutScale = make("UIScale", {}, mutationIcon)
	TweenService:Create(mutScale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 }):Play()
	mutationTip = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 70), Size = UDim2.fromOffset(240, 60), BackgroundColor3 = Color3.fromRGB(30, 26, 60), Visible = false, ZIndex = 20 }, gui)
	corner(mutationTip, 12)
	stroke(mutationTip, 2.5, WHITE)
	label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), TextSize = 16, TextColor3 = Color3.fromRGB(200, 150, 255), Text = "MUTATION HOUR" }, mutationTip)
	mutationTipDesc = label({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 30), TextSize = 14, TextWrapped = true, TextColor3 = Color3.fromRGB(220, 220, 255), Text = "" }, mutationTip)
	local function showMutTip()
		mutationTip.Visible = true
	end
	local function hideMutTip()
		mutationTip.Visible = false
	end
	if isTouch then
		local btn = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, mutationIcon)
		btn.Activated:Connect(function()
			mutationTip.Visible = not mutationTip.Visible
		end)
	else
		mutationIcon.MouseEnter:Connect(showMutTip)
		mutationIcon.MouseLeave:Connect(hideMutTip)
	end
end

do
	----------------------------------------------------------------
	-- BIG FLOOD ANNOUNCEMENT (title + sub text, red flash, camera shake, horn)
	----------------------------------------------------------------
	local announceFrame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(1000, 150),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 8,
	}, gui)
	local announceScale = make("UIScale", {}, announceFrame)
	local announceTitle = label({ Size = UDim2.new(1, 0, 0.62, 0), TextScaled = true, Text = "", ZIndex = 8 }, announceFrame)
	announceTitle.Font = Enum.Font.LuckiestGuy
	announceTitle:FindFirstChildOfClass("UIStroke").Thickness = 5
	local announceSub = label({ Position = UDim2.fromScale(0, 0.64), Size = UDim2.new(1, 0, 0.32, 0), TextScaled = true, Text = "", ZIndex = 8 }, announceFrame)
	announceSub:FindFirstChildOfClass("UIStroke").Thickness = 3

	local shakeUntil = 0
	RunService:BindToRenderStep("GooberShake", Enum.RenderPriority.Camera.Value + 1, function()
		if os.clock() < shakeUntil then
			local k = math.min(1, shakeUntil - os.clock()) * 0.012
			camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * k, (math.random() - 0.5) * k, (math.random() - 0.5) * k)
		end
	end)

	local announceId = 0
	Announce.OnClientEvent:Connect(function(title, sub, color, sfx)
		announceId += 1
		local id = announceId
		announceTitle.Text = title
		announceTitle.TextColor3 = color
		announceSub.Text = sub
		announceFrame.Visible = true
		announceScale.Scale = 0.3
		tween(announceScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		shakeUntil = os.clock() + 1.4
		if sfx then
			play(sfx)
		end
		task.spawn(function()
			for _ = 1, 3 do
				flash.BackgroundColor3 = color
				flash.BackgroundTransparency = 0.72
				tween(flash, 0.45, { BackgroundTransparency = 1 })
				task.wait(0.55)
			end
		end)
		task.delay(4.5, function()
			if id == announceId then
				tween(announceScale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				task.wait(0.35)
				if id == announceId then
					announceFrame.Visible = false
				end
			end
		end)
	end)

end

----------------------------------------------------------------
-- MENUS (only one centered window open at a time)
----------------------------------------------------------------
local menus = {}
local menuHooks = {} -- [menu name] = { OnClose = fn, Intercept = fn -> true to delay closing }
local activeMenu = nil

-- dark backdrop behind every window (tap it to close)
local backdrop = make("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(30, 10, 60),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 20,
}, gui)

local function hideAll()
	for name, f in pairs(menus) do
		if f.Visible then
			f.Visible = false
			local h = menuHooks[name]
			if h and h.OnClose then
				h.OnClose()
			end
		end
	end
	backdrop.Visible = false
	activeMenu = nil
end

local function closeMenus(force)
	if force ~= true and activeMenu then
		local h = menuHooks[activeMenu]
		if h and h.Intercept and h.Intercept() then
			return
		end
	end
	hideAll()
end
backdrop.Activated:Connect(function()
	closeMenus()
end)

local function toggleMenu(name, forceOpen)
	local f = menus[name]
	if not f then
		return
	end
	if not (forceOpen or not f.Visible) then
		closeMenus()
		return
	end
	if activeMenu ~= name then
		hideAll()
	end
	activeMenu = name
	f.Visible = true
	backdrop.Visible = true
	backdrop.BackgroundTransparency = 1
	tween(backdrop, 0.25, { BackgroundTransparency = 0.42 })
	local sc = f:FindFirstChild("PopScale")
	if sc then
		sc.Scale = 0.82
		tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	play("pop")
end

-- a centered window with a header bar, big title and a close button. Returns the frame, a body frame and the title label.
local function modal(name, maxW, maxH, title, accent)
	local f = panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.86),
		Visible = false,
		ZIndex = 21,
	}, gui)
	make("UISizeConstraint", { MaxSize = Vector2.new(maxW, maxH) }, f)
	make("UIScale", { Name = "PopScale" }, f)
	local fStroke = f:FindFirstChildOfClass("UIStroke")
	fStroke.Color = WHITE
	fStroke.Thickness = 6
	do -- a candy-rainbow border (tinted toward the window's own colour) that slowly spins around the window
		local rainbow = make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, accent),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 120, 210)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 235, 120)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 230, 255)),
				ColorSequenceKeypoint.new(1, accent),
			}),
		}, fStroke)
		TweenService:Create(rainbow, TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
	end
	f.BackgroundColor3 = Color3.fromRGB(120, 86, 240):Lerp(accent, 0.3) -- every window has its own colour
	bubbleDeco(f)
	local hdr = make("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 52), BackgroundColor3 = accent:Lerp(Color3.fromRGB(90, 70, 190), 0.25) }, f)
	corner(hdr, 26)
	make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 185, 215)), Rotation = 90 }, hdr)
	local hdrGloss = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(0.94, 0, 0.26, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.72, Active = false }, hdr)
	corner(hdrGloss, 8)
	local titleL = label({ Size = UDim2.new(1, -76, 0, 42), Position = UDim2.fromOffset(20, 11), Text = title, TextScaled = true, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left }, f)
	titleL.Font = Enum.Font.LuckiestGuy -- chunky cartoon title font
	make("UITextSizeConstraint", { MaxTextSize = 34 }, titleL)
	titleL:FindFirstChildOfClass("UIStroke").Thickness = 3.5
	local close = makeButton({ Position = UDim2.new(1, -50, 0, 10), Size = UDim2.fromOffset(38, 38), Text = "X", TextSize = 22 }, f, RED)
	close.Activated:Connect(function()
		closeMenus()
	end)
	local body = make("Frame", { Position = UDim2.fromOffset(12, 64), Size = UDim2.new(1, -24, 1, -76), BackgroundTransparency = 1 }, f)
	menus[name] = f
	return f, body, titleL
end

local function scroller(parent, gap)
	local sf = make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, parent)
	make("UIListLayout", { Padding = UDim.new(0, gap or 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, sf)
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, sf)
	return sf
end

-- one big colorful item row (icon, title, description, buy button)
local ART_IDS = { Slots = true, Floors = true, Luck = true, LuckyBox = true, SuperLock = true, Rebirth = true }
local function itemRow(parent, accent, symbol, height, order)
	height = height or 88
	local row = make("Frame", { Size = UDim2.new(1, -6, 0, height), BackgroundColor3 = accent:Lerp(Color3.fromRGB(100, 90, 215), 0.62), LayoutOrder = order or 0 }, parent)
	corner(row, 22)
	make("UIStroke", { Thickness = 3.5, Color = accent }, row)
	make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(196, 190, 232)), Rotation = 90 }, row)
	local icon = make("Frame", { Position = UDim2.fromOffset(10, height / 2 - 34), Size = UDim2.fromOffset(68, 68), BackgroundColor3 = accent }, row)
	corner(icon, 34)
	stroke(icon, 3, WHITE)
	make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 170)), Rotation = 90 }, icon)
	if ART_IDS[symbol] then
		itemArt(icon, symbol, accent)
	else
		local sym = label({ Size = UDim2.fromScale(1, 1), TextScaled = true, Text = symbol }, icon)
		make("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16) }, sym)
	end
	local title = label({ Position = UDim2.fromOffset(86, 6), Size = UDim2.new(1, -214, 0, 26), TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, row)
	local desc = label({
		Position = UDim2.fromOffset(86, 32),
		Size = UDim2.new(1, -214, 0, 34),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(215, 220, 255),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	}, row)
	desc:FindFirstChildOfClass("UIStroke").Thickness = 1.5
	local btn = makeButton({ Position = UDim2.new(1, -120, 0.5, -26), Size = UDim2.fromOffset(110, 52), TextSize = 17, Text = "" }, row, GREEN)
	return { Row = row, Title = title, Desc = desc, Btn = btn }
end

local function setBtn(btn, text, color)
	btn.Text = text
	btn.BackgroundColor3 = color
end

local updateShop
do
	----------------------------------------------------------------
	-- UPGRADE SHOP (Speed + Capacity moved to the physical stands in the plaza)
	----------------------------------------------------------------
	-- draws a little picture for each gadget / Robux item out of frames (bubbly, glossy, outlined).
	-- Want your OWN images instead? Put a decal id into Config.Images.Shop[id] and it is used automatically.
	local function drawItemIcon(parent, id, color)
		local PINKC2, GOLD2 = Color3.fromRGB(255, 105, 185), Color3.fromRGB(255, 215, 70)
		local function shape(x, y, w, h, c, rot, roundness, z)
			local f = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, y),
				Size = UDim2.fromScale(w, h),
				BackgroundColor3 = c,
				Rotation = rot or 0,
				ZIndex = z or 2,
			}, parent)
			make("UICorner", { CornerRadius = UDim.new(roundness or 0.5, 0) }, f)
			make("UIStroke", { Thickness = 2.5, Color = BLACK, Transparency = 0.35 }, f)
			make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(175, 175, 175)), Rotation = 90 }, f)
			return f
		end
		local function shine(x, y, w, h, rot) -- a soft white glint
			local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, Rotation = rot or 0, ZIndex = 8, Active = false }, parent)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
		end
		local function text(x, y, w, h, str, col)
			return label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), TextScaled = true, TextColor3 = col or WHITE, Text = str, ZIndex = 9 }, parent)
		end
		local function bottle(liquid, glyph)
			shape(0.5, 0.66, 0.66, 0.6, liquid, 0, 0.5)
			shape(0.5, 0.3, 0.22, 0.3, Color3.fromRGB(225, 240, 255), 0, 0.25)
			shape(0.5, 0.13, 0.3, 0.1, Color3.fromRGB(160, 105, 62), 0, 0.3)
			shape(0.7, 0.5, 0.08, 0.08, WHITE, 0, 0.5, 3)
			shape(0.3, 0.8, 0.06, 0.06, WHITE, 0, 0.5, 3)
			shine(0.3, 0.6, 0.1, 0.22, 20)
			if glyph ~= "" then
				text(0.5, 0.68, 0.44, 0.3, glyph)
			end
		end
		if id == "Wacker" then -- the upright mallet, same as the real one
			shape(0.5, 0.66, 0.13, 0.56, Color3.fromRGB(170, 110, 62), 0, 0.3)
			for k = 0, 2 do
				shape(0.5, 0.78 + k * 0.07, 0.17, 0.04, (k % 2 == 0) and PINKC2 or WHITE, 0, 0.3, 3)
			end
			shape(0.5, 0.94, 0.18, 0.09, GOLD2, 0, 0.5)
			shape(0.5, 0.3, 0.74, 0.34, PINKC2, 0, 0.42)
			shape(0.29, 0.3, 0.07, 0.36, GOLD2, 0, 0.2, 3)
			shape(0.71, 0.3, 0.07, 0.36, GOLD2, 0, 0.2, 3)
			shape(0.5, 0.08, 0.13, 0.13, GOLD2, 45, 0.3, 3)
			shape(0.42, 0.26, 0.1, 0.1, WHITE, 0, 0.5, 4)
			shape(0.58, 0.26, 0.1, 0.1, WHITE, 0, 0.5, 4)
			shape(0.42, 0.275, 0.05, 0.05, Color3.fromRGB(30, 20, 40), 0, 0.5, 5)
			shape(0.58, 0.275, 0.05, 0.05, Color3.fromRGB(30, 20, 40), 0, 0.5, 5)
			shine(0.3, 0.2, 0.16, 0.06, -10)
		elseif id == "Trap" then
			for i = 1, 8 do
				local a = (i / 8) * math.pi * 2
				shape(0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.36, 0.11, 0.11, WHITE, 45, 0.1)
			end
			shape(0.5, 0.5, 0.66, 0.66, Color3.fromRGB(95, 95, 115), 0, 0.5)
			shape(0.5, 0.5, 0.28, 0.28, Color3.fromRGB(255, 70, 70), 0, 0.5, 3)
			shine(0.36, 0.34, 0.16, 0.1, -30)
		elseif id == "Shield" then
			shape(0.5, 0.5, 0.62, 0.72, Color3.fromRGB(255, 215, 70), 0, 0.3)
			shape(0.5, 0.5, 0.44, 0.52, Color3.fromRGB(255, 240, 150), 0, 0.25, 3)
			shape(0.5, 0.5, 0.12, 0.34, Color3.fromRGB(255, 180, 40), 0, 0.2, 4)
			shape(0.5, 0.5, 0.34, 0.12, Color3.fromRGB(255, 180, 40), 0, 0.2, 4)
			shine(0.32, 0.3, 0.1, 0.2, 20)
		elseif id == "Guard" then -- a wave
			shape(0.5, 0.62, 0.7, 0.4, color, 0, 0.5)
			shape(0.36, 0.42, 0.34, 0.34, color:Lerp(WHITE, 0.4), 0, 0.5, 3)
			shape(0.64, 0.5, 0.3, 0.3, color:Lerp(WHITE, 0.6), 0, 0.5, 3)
			shine(0.3, 0.36, 0.1, 0.1, 0)
		elseif id == "Magnet" then -- horseshoe magnet
			shape(0.5, 0.42, 0.62, 0.62, Color3.fromRGB(230, 60, 80), 0, 0.5)
			shape(0.5, 0.5, 0.32, 0.4, color:Lerp(Color3.fromRGB(70, 60, 130), 0.5), 0, 0.5, 3)
			shape(0.27, 0.78, 0.16, 0.2, Color3.fromRGB(235, 235, 245), 0, 0.15, 4)
			shape(0.73, 0.78, 0.16, 0.2, Color3.fromRGB(235, 235, 245), 0, 0.15, 4)
			shine(0.3, 0.28, 0.1, 0.16, 25)
		elseif id == "Cash" then -- coin with a dollar sign
			shape(0.5, 0.5, 0.7, 0.7, Color3.fromRGB(255, 205, 60), 0, 0.5)
			shape(0.5, 0.5, 0.5, 0.5, Color3.fromRGB(255, 232, 130), 0, 0.5, 3)
			text(0.5, 0.5, 0.36, 0.4, "$", Color3.fromRGB(170, 105, 0))
			shine(0.32, 0.3, 0.12, 0.08, -30)
		elseif id == "Speed" then
			bottle(color, ">>")
		elseif id == "Jump" then
			bottle(color, "UP")
		elseif id == "Thief" then -- a hooded bandit
			shape(0.5, 0.5, 0.74, 0.74, Color3.fromRGB(70, 70, 95), 0, 0.5)
			shape(0.5, 0.5, 0.6, 0.24, Color3.fromRGB(255, 222, 180), 0, 0.4, 3)
			shape(0.38, 0.5, 0.11, 0.11, WHITE, 0, 0.5, 4)
			shape(0.62, 0.5, 0.11, 0.11, WHITE, 0, 0.5, 4)
			shape(0.38, 0.5, 0.05, 0.05, BLACK, 0, 0.5, 5)
			shape(0.62, 0.5, 0.05, 0.05, BLACK, 0, 0.5, 5)
			shape(0.5, 0.8, 0.56, 0.14, Color3.fromRGB(230, 60, 70), 0, 0.5, 3)
			shine(0.3, 0.26, 0.14, 0.08, -30)
		elseif id == "DoubleCash" then
			shape(0.38, 0.64, 0.5, 0.5, Color3.fromRGB(255, 205, 60), 0, 0.5)
			shape(0.62, 0.4, 0.5, 0.5, Color3.fromRGB(255, 225, 100), 0, 0.5, 3)
			text(0.62, 0.4, 0.36, 0.3, "2x", Color3.fromRGB(30, 140, 60))
			shine(0.5, 0.22, 0.12, 0.06, -20)
		elseif id == "VIP" then -- a crown
			shape(0.5, 0.74, 0.74, 0.2, GOLD2, 0, 0.3)
			for _, p in ipairs({ { 0.24, 0.46 }, { 0.5, 0.34 }, { 0.76, 0.46 } }) do
				shape(p[1], p[2], 0.2, 0.2, GOLD2, 45, 0.2)
				shape(p[1], p[2] - 0.13, 0.09, 0.09, WHITE, 0, 0.5, 4)
			end
			shape(0.5, 0.56, 0.5, 0.26, GOLD2, 0, 0.2, 3)
			shape(0.3, 0.74, 0.1, 0.1, Color3.fromRGB(255, 70, 90), 0, 0.5, 4)
			shape(0.5, 0.74, 0.1, 0.1, Color3.fromRGB(80, 170, 255), 0, 0.5, 4)
			shape(0.7, 0.74, 0.1, 0.1, Color3.fromRGB(90, 230, 130), 0, 0.5, 4)
			shine(0.3, 0.42, 0.1, 0.05, -20)
		elseif id == "LuckyBox" then -- a gift box with a ?
			shape(0.5, 0.66, 0.66, 0.46, Color3.fromRGB(255, 120, 190), 0, 0.2)
			shape(0.5, 0.4, 0.74, 0.16, Color3.fromRGB(255, 160, 215), 0, 0.3, 3)
			shape(0.5, 0.42, 0.12, 0.34, GOLD2, 0, 0.2, 3)
			shape(0.4, 0.24, 0.2, 0.16, GOLD2, -20, 0.5, 3)
			shape(0.6, 0.24, 0.2, 0.16, GOLD2, 20, 0.5, 3)
			text(0.5, 0.74, 0.28, 0.26, "?", WHITE)
		elseif id == "CashPack" then -- a money bag
			shape(0.5, 0.64, 0.68, 0.62, Color3.fromRGB(80, 200, 110), 0, 0.5)
			shape(0.5, 0.3, 0.3, 0.2, Color3.fromRGB(60, 170, 90), 0, 0.3)
			shape(0.5, 0.36, 0.42, 0.06, GOLD2, 0, 0.5, 3)
			text(0.5, 0.64, 0.4, 0.4, "$", WHITE)
			shine(0.3, 0.56, 0.1, 0.2, 20)
		elseif id == "SuperLock" then -- a padlock
			shape(0.5, 0.36, 0.46, 0.46, Color3.fromRGB(170, 175, 195), 0, 0.5)
			shape(0.5, 0.4, 0.26, 0.27, color:Lerp(WHITE, 0.15), 0, 0.5, 3)
			shape(0.5, 0.66, 0.64, 0.5, GOLD2, 0, 0.2, 4)
			shape(0.5, 0.63, 0.1, 0.14, Color3.fromRGB(80, 50, 20), 0, 0.5, 5)
			shape(0.5, 0.72, 0.06, 0.14, Color3.fromRGB(80, 50, 20), 0, 0.2, 5)
			shine(0.32, 0.56, 0.08, 0.12, 15)
		elseif id == "donate" then -- a heart
			shape(0.32, 0.38, 0.32, 0.32, Color3.fromRGB(255, 90, 140), 0, 0.5)
			shape(0.68, 0.38, 0.32, 0.32, Color3.fromRGB(255, 90, 140), 0, 0.5)
			shape(0.5, 0.62, 0.42, 0.42, Color3.fromRGB(255, 90, 140), 45, 0.12)
			shine(0.26, 0.32, 0.09, 0.09, 20)
		elseif id == "PetSlot" then -- a paw print
			shape(0.5, 0.66, 0.46, 0.38, PINKC2, 0, 0.5)
			for _, p in ipairs({ { 0.24, 0.44 }, { 0.42, 0.3 }, { 0.6, 0.3 }, { 0.78, 0.44 } }) do
				shape(p[1], p[2], 0.17, 0.21, Color3.fromRGB(255, 150, 210), 0, 0.5, 3)
			end
			shine(0.4, 0.62, 0.1, 0.06, -20)
		elseif id == "Slots" then -- pedestals with little goobers on them
			shape(0.5, 0.8, 0.88, 0.16, Color3.fromRGB(150, 130, 210), 0, 0.5)
			for _, x in ipairs({ 0.24, 0.5, 0.76 }) do
				shape(x, 0.66, 0.2, 0.16, color:Lerp(WHITE, 0.2), 0, 0.5, 3)
				shape(x, 0.44, 0.17, 0.22, GOLD2, 0, 0.5, 4)
			end
			text(0.5, 0.17, 0.3, 0.24, "+", WHITE)
		elseif id == "Floors" then -- a stack of floors with an arrow pointing up
			for i = 0, 2 do
				shape(0.4, 0.8 - i * 0.2, 0.6 - i * 0.06, 0.16, color:Lerp(Color3.fromRGB(140, 110, 220), i * 0.25), 0, 0.3, 2 + i)
			end
			shape(0.84, 0.46, 0.13, 0.34, GOLD2, 0, 0.3, 5)
			shape(0.84, 0.24, 0.22, 0.22, GOLD2, 45, 0.15, 5)
		elseif id == "Luck" then -- a four-leaf clover
			for _, p in ipairs({ { 0.36, 0.36 }, { 0.64, 0.36 }, { 0.36, 0.62 }, { 0.64, 0.62 } }) do
				shape(p[1], p[2], 0.3, 0.3, Color3.fromRGB(80, 220, 110), 0, 0.5, 3)
			end
			shape(0.53, 0.86, 0.07, 0.26, Color3.fromRGB(60, 160, 80), 12, 0.3, 2)
			shine(0.32, 0.3, 0.08, 0.1, 20)
		elseif id == "Rebirth" then -- a glowing ring with an R and a spark
			shape(0.5, 0.5, 0.68, 0.68, Color3.fromRGB(255, 120, 110), 0, 0.5)
			shape(0.5, 0.5, 0.44, 0.44, color:Lerp(Color3.fromRGB(120, 60, 130), 0.3), 0, 0.5, 3)
			shape(0.76, 0.26, 0.2, 0.2, GOLD2, 45, 0.15, 5)
			text(0.5, 0.5, 0.34, 0.3, "R", WHITE)
			shine(0.32, 0.3, 0.1, 0.12, 20)
		else -- any other potion
			bottle(color, "")
		end
	end

	-- picture for an item: YOUR image if you set one in Config.Images.Shop, otherwise the drawn one
	function itemArt(parent, id, color) -- (shared with the Robux shop)
		local img = Config.Images.Shop and Config.Images.Shop[id]
		if img and img ~= "" then
			make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit }, parent)
		else
			drawItemIcon(parent, id, color)
		end
	end

	local UPG = {
		Slots = { attr = "SlotsLvl", col = Color3.fromRGB(110, 255, 130), sym = "Slots" },
		Floors = { attr = "FloorsLvl", col = Color3.fromRGB(200, 120, 255), sym = "Floors" },
		Luck = { attr = "LuckLvl", col = Color3.fromRGB(255, 230, 70), sym = "Luck" },
	}

	local _, shopBody = modal("shop", 620, 640, "UPGRADES", Color3.fromRGB(110, 235, 255))
	local shopList = scroller(shopBody, 8)
	label({
		Size = UDim2.new(1, -6, 0, 40),
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(255, 235, 150),
		Text = "Speed and Capacity upgrades are bought at the stands in the plaza. Tap MARKET to go there!",
		LayoutOrder = 0,
	}, shopList)
	local upgRows = {}
	for i, id in ipairs(Config.UpgradeOrder) do
		local st = UPG[id]
		local r = itemRow(shopList, st.col, st.sym, 96, i)
		r.Title.Text = Config.Upgrades[id].Label
		local track = make("Frame", { Position = UDim2.fromOffset(86, 74), Size = UDim2.new(1, -214, 0, 10), BackgroundColor3 = Color3.fromRGB(25, 25, 60) }, r.Row)
		corner(track, 5)
		local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = st.col }, track)
		corner(fill, 5)
		r.Fill = fill
		r.Btn.Activated:Connect(function()
			Action:FireServer("Upgrade", id)
		end)
		upgRows[id] = r
	end

	local extraRows = {}
	local function extraRow(order, color, sym, title, desc, onClick)
		local r = itemRow(shopList, color, sym, 84, order)
		r.Title.Text = title
		r.Desc.Text = desc
		r.Btn.Activated:Connect(onClick)
		extraRows[order] = r
		return r
	end
	local lockRow = extraRow(11, Color3.fromRGB(120, 140, 255), "SuperLock", "Base Lock", "Nobody can steal for " .. Config.LockSeconds .. " seconds.", function()
		Action:FireServer("LockBase")
	end)

	function updateShop()
		local cash = player:GetAttribute("Cash") or 0
		for id, r in pairs(upgRows) do
			local lvl = player:GetAttribute(UPG[id].attr) or 0
			local max = Config.Upgrades[id].Max
			local luckCap = (id == "Luck" and (player:GetAttribute("LuckMax") or max)) or (id == "Slots" and (player:GetAttribute("SlotsMax") or max)) or max -- Luck + Slots levels unlock with Rebirths
			r.Title.Text = ("%s   Lv %d/%d"):format(Config.Upgrades[id].Label, lvl, max)
			r.Fill.Size = UDim2.fromScale(math.clamp(lvl / max, 0, 1), 1)
			local floorsLvl = player:GetAttribute("FloorsLvl") or 0
			if lvl >= max then
				r.Desc.Text = "MAXED OUT!"
				setBtn(r.Btn, "MAX", GREY)
			elseif lvl >= luckCap then
				r.Desc.Text = (id == "Luck") and ("%.1f%% mutate chance. REBIRTH to unlock more Luck levels!"):format(Config.LuckMutateChance(lvl) * 100) or "REBIRTH to unlock more base slots!"
				setBtn(r.Btn, "REBIRTH", GREY)
			elseif id == "Slots" and 4 + lvl >= Config.SlotsPerFloor * (1 + floorsLvl) then
				r.Desc.Text = "Floors full - build a Base Floor first!"
				setBtn(r.Btn, "FULL", GREY)
			else
				local cost = Config.UpgradeCost(id, lvl)
				r.Desc.Text = Config.Upgrades[id].Desc
				if id == "Luck" then
					r.Desc.Text = ("Mutate chance when you grab a Goober: %.1f%% -> %.1f%%"):format(Config.LuckMutateChance(lvl) * 100, Config.LuckMutateChance(lvl + 1) * 100)
				end
				setBtn(r.Btn, "$" .. F(cost), cash >= cost and GREEN or GREY)
			end
		end
		local lockPrice = Config.LockPrice(player:GetAttribute("LockBuys") or 0) -- goes up every time you buy one
		lockRow.Btn.Text = "$" .. F(lockPrice)
		lockRow.Btn.BackgroundColor3 = cash >= lockPrice and GREEN or GREY
	end

end

local updateNpc, onOpenNpc
do
	----------------------------------------------------------------
	-- GUS'S GADGET SHOP (window: animated NPC portrait + speech bubble + item cards with drawn icons)
	-- Gus says hello when you walk in, idles while you shop, and waves goodbye when you leave after buying.
	----------------------------------------------------------------
	local PINKC = Color3.fromRGB(255, 110, 190)
	local npcFrame, npcBody = modal("npc", 900, 560, "GUS'S GADGETS", PINKC)
	local boughtSomething = false
	local byeing = false

	local portrait = make("Frame", { Size = UDim2.new(0, 236, 1, 0), BackgroundColor3 = Color3.fromRGB(118, 90, 208) }, npcBody)
	corner(portrait, 18)
	stroke(portrait, 3, PINKC)
	local vp = make("ViewportFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 236),
		BackgroundColor3 = Color3.fromRGB(255, 226, 246),
		Ambient = Color3.fromRGB(190, 190, 205),
		LightColor = Color3.fromRGB(255, 250, 240),
	}, portrait)
	corner(vp, 14)
	local vcam = make("Camera", { FieldOfView = 34 }, vp)
	vp.CurrentCamera = vcam

	local portraitLoaded = false
	local portraitFallback = nil
	local pParts = nil -- { Torso, RArm, LArm } of the clone in the portrait
	local pState, pUntil, pR, pL, pRF, pLF = "idle", 0, 7, 7, 0, 0

	local function setPortraitState(state, seconds)
		pState = state
		pUntil = os.clock() + seconds
	end

	local function loadPortrait()
		if portraitLoaded then
			return
		end
		local world = workspace:FindFirstChild("GooberWorld")
		local gus = world and world:FindFirstChild("Gus")
		local head = gus and gus:FindFirstChild("Head")
		local torso = gus and gus:FindFirstChild("Torso")
		local rArm = gus and gus:FindFirstChild("Right Arm")
		local lArm = gus and gus:FindFirstChild("Left Arm")
		if gus and head and torso and rArm and lArm and head:IsA("BasePart") then
			local clone = gus:Clone()
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
					d:Destroy()
				end
			end
			clone.Parent = vp
			-- the clone gets the SAME pose logic as the world Gus (from his torso), never a frozen mid-wave snapshot
			pParts = { Torso = clone:FindFirstChild("Torso"), RArm = clone:FindFirstChild("Right Arm"), LArm = clone:FindFirstChild("Left Arm") }
			local target = head.Position + Vector3.new(0, -0.9, 0)
			local camPos = target + head.CFrame.LookVector * 10.5 + Vector3.new(0.6, 0.7, 0)
			vcam.CFrame = CFrame.lookAt(camPos, target)
			portraitLoaded = true
			if portraitFallback then
				portraitFallback:Destroy()
				portraitFallback = nil
			end
		elseif not portraitFallback then
			-- Gus hasn't streamed in yet: show a friendly drawn face instead
			portraitFallback = drawCreature(vp, { Style = "bear", Color = Color3.fromRGB(255, 204, 153), RarityColor = PINKC, Rank = 5 }, 200)
			portraitFallback.Position = UDim2.new(0.5, -100, 0.5, -100)
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		if not pParts or not npcFrame.Visible then
			return
		end
		local t = os.clock()
		if pState ~= "idle" and t > pUntil then
			pState = "idle"
		end
		local tr, tl, trf, tlf = npcTargetAngles(pState, t, 0, "gus")
		local k = math.min(1, dt * 12)
		pR += (tr - pR) * k
		pL += (tl - pL) * k
		pRF += (trf - pRF) * k
		pLF += (tlf - pLF) * k
		if pParts.Torso and pParts.RArm and pParts.LArm then
			npcPoseArms(pParts.Torso, pParts.RArm, pParts.LArm, pR, pL, pRF, pLF)
		end
	end)

	label({ Position = UDim2.fromOffset(0, 244), Size = UDim2.new(1, 0, 0, 30), TextSize = 22, TextColor3 = Color3.fromRGB(255, 230, 120), Text = "GUS" }, portrait)

	local bubble = make("Frame", { Position = UDim2.fromOffset(10, 278), Size = UDim2.new(1, -20, 1, -290), BackgroundColor3 = Color3.fromRGB(255, 250, 255) }, portrait)
	corner(bubble, 16)
	stroke(bubble, 2, PINKC)
	local bubbleText = make("TextLabel", {
		Size = UDim2.new(1, -16, 1, -12),
		Position = UDim2.fromOffset(8, 6),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(70, 40, 100),
		Text = "",
	}, bubble)
	local GUS_QUOTES = {
		"Need to WHACK somebody? I got you!",
		"Bear traps! Step on one and drop everything. Hehe!",
		"Flood Guard = floods can't touch you!",
		"Magnet Potion: Goobers come to YOU.",
		"Prices go up every time you buy. Sorry, not sorry!",
		"Potions STACK: buy two and get double the time!",
		"Flood Guard is 30 seconds and does NOT stack.",
		"The Magnet only pulls the rarities YOU pick!",
	}

	local itemsHolder = make("Frame", { Position = UDim2.fromOffset(246, 0), Size = UDim2.new(1, -246, 1, 0), BackgroundTransparency = 1 }, npcBody)
	local itemsScroll = make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, itemsHolder)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(196, 206), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, itemsScroll)
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, itemsScroll)

	-- Magnet Potion: which rarities it pulls in (all picked by default). The server keeps the same list while a magnet is running.
	local magnetRarities, magnetSel, chipButtons, rarityByRank = {}, {}, {}, {}
	for id, r in pairs(Config.Rarities) do
		local entry = { Id = id, Rank = r.Rank, Color = r.Color }
		table.insert(magnetRarities, entry)
		rarityByRank[r.Rank] = entry
		magnetSel[r.Rank] = true
	end
	table.sort(magnetRarities, function(a, b)
		return a.Rank < b.Rank
	end)
	local function magnetCsv()
		return Config.RankSetCsv(magnetSel)
	end
	local function styleMagnetChips()
		for rank, chip in pairs(chipButtons) do
			local on = magnetSel[rank]
			chip.BackgroundColor3 = on and rarityByRank[rank].Color or Color3.fromRGB(58, 58, 90)
			chip.TextColor3 = on and WHITE or Color3.fromRGB(130, 130, 160)
			chip:FindFirstChildOfClass("UIStroke").Transparency = on and 0 or 0.7
		end
	end
	local function toggleMagnetRank(rank)
		if not Config.ToggleRankSet(magnetSel, rank) then
			toast("Pick at least one rarity", GOLD)
			return
		end
		styleMagnetChips()
		if (player:GetAttribute("BoostMagnet") or 0) > workspace:GetServerTimeNow() then
			Action:FireServer("MagnetFilter", magnetCsv()) -- a running magnet changes right away (free)
		end
	end

	local npcCards = {}
	for i, item in ipairs(Config.ShopItems) do
		local card = make("Frame", { BackgroundColor3 = item.Color:Lerp(Color3.fromRGB(96, 84, 200), 0.5), LayoutOrder = i }, itemsScroll)
		corner(card, 24)
		make("UIStroke", { Thickness = 4, Color = item.Color:Lerp(WHITE, 0.2) }, card)
		make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(178, 168, 218)), Rotation = 90 }, card)
		bubbleDeco(card)
		local iconBox = make("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(82, 82), BackgroundColor3 = item.Color:Lerp(WHITE, 0.12) }, card)
		corner(iconBox, 41) -- a round bubble
		stroke(iconBox, 3.5)
		make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(175, 175, 175)), Rotation = 90 }, iconBox)
		itemArt(iconBox, item.Id, item.Color)
		label({ Position = UDim2.fromOffset(94, 10), Size = UDim2.new(1, -100, 0, 38), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = item.Label }, card)
		local d = label({
			Position = UDim2.fromOffset(94, 52),
			Size = UDim2.new(1, -100, 0, 30),
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(190, 255, 210),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = item.Duration and (item.Duration .. "s each\n" .. (item.Stackable == false and "DOES NOT STACK" or "STACKS!")) or "One purchase",
		}, card)
		d:FindFirstChildOfClass("UIStroke").Thickness = 1.5
		if item.Stackable == false then
			d.TextColor3 = Color3.fromRGB(255, 190, 130)
		end
		local desc = label({
			Position = UDim2.fromOffset(10, 94),
			Size = UDim2.new(1, -20, 0, 50),
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(215, 220, 255),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = item.Desc,
		}, card)
		desc:FindFirstChildOfClass("UIStroke").Thickness = 1.5
		-- Magnet Potion: tap the rarities you want it to pull in BEFORE you buy
		if item.Filter then
			desc.Position = UDim2.fromOffset(10, 124)
			desc.Size = UDim2.new(1, -20, 0, 26)
			desc.TextSize = 12
			for k, rr in ipairs(magnetRarities) do
				local chip = make("TextButton", { Position = UDim2.fromOffset(10 + (k - 1) * 30, 92), Size = UDim2.fromOffset(26, 26), Text = rr.Id:sub(1, 1), Font = FONT, TextSize = 15, TextColor3 = WHITE, AutoButtonColor = false, BackgroundColor3 = rr.Color }, card)
				make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, chip)
				make("UIStroke", { Thickness = 2.5, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
				chipButtons[rr.Rank] = chip
				chip.Activated:Connect(function()
					toggleMagnetRank(rr.Rank)
				end)
			end
			styleMagnetChips()
		end
		-- "time left" bubble on potion cards
		local pill
		if item.Duration then
			pill = label({ Position = UDim2.fromOffset(10, 72), Size = UDim2.fromOffset(76, 22), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(40, 150, 80), TextSize = 14, Text = "", Visible = false, ZIndex = 4 }, card)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pill)
		end
		local btn = makeButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 42), TextSize = 22, Text = "" }, card, GREEN)
		btn.Activated:Connect(function()
			local price = player:GetAttribute("Price_" .. item.Id) or item.Price
			if (player:GetAttribute("Cash") or 0) >= price then
				boughtSomething = true
				if not byeing then
					bubbleText.Text = "Pleasure doing business!"
					setPortraitState("hello", 1.2)
				end
			end
			Action:FireServer("ShopBuy", item.Id, item.Filter and magnetCsv() or nil)
		end)
		npcCards[item.Id] = { Btn = btn, Pill = pill }
	end

	function updateNpc()
		local cash = player:GetAttribute("Cash") or 0
		local traps = player:GetAttribute("Traps") or 0
		local hasWacker = player:GetAttribute("HasWacker")
		local now = workspace:GetServerTimeNow()
		for _, item in ipairs(Config.ShopItems) do
			local c = npcCards[item.Id]
			local price = player:GetAttribute("Price_" .. item.Id) or item.Price
			local left = item.Duration and math.max(0, (player:GetAttribute("Boost" .. item.Id) or 0) - now) or 0
			if c.Pill then
				c.Pill.Visible = left > 0
				if left > 0 then
					c.Pill.Text = ("%d:%02d"):format(left // 60, math.floor(left) % 60)
				end
			end
			if item.Id == "Wacker" and hasWacker then
				setBtn(c.Btn, "OWNED", GREY)
			elseif item.Id == "Trap" and traps + Config.TrapPackSize > Config.MaxTraps then
				setBtn(c.Btn, "FULL", GREY)
			elseif item.Duration and item.Stackable == false and left > 0 then
				setBtn(c.Btn, "ACTIVE", GREY)
			elseif item.Duration and left + item.Duration > Config.MaxPotionStack then
				setBtn(c.Btn, "MAX TIME", GREY)
			else
				local txt = "$" .. F(price)
				if item.Id == "Trap" then
					txt = txt .. "  (have " .. traps .. ")"
				elseif item.Duration and left > 0 then
					txt = txt .. "  +" .. item.Duration .. "s"
				end
				setBtn(c.Btn, txt, cash >= price and GREEN or GREY)
			end
		end
	end

	function onOpenNpc()
		local saved = player:GetAttribute("MagnetFilter")
		if type(saved) == "string" and saved ~= "" then -- show what the running magnet is set to
			for _, rr in ipairs(magnetRarities) do
				magnetSel[rr.Rank] = false
			end
			for digits in string.gmatch(saved, "%d+") do
				magnetSel[tonumber(digits)] = true
			end
			styleMagnetChips()
		end
		boughtSomething = false
		byeing = false
		loadPortrait()
		bubbleText.Text = "Hey there, friend! Welcome in!"
		setPortraitState("hello", 1.9)
		task.delay(2.4, function()
			if npcFrame.Visible and not byeing then
				bubbleText.Text = GUS_QUOTES[math.random(#GUS_QUOTES)]
			end
		end)
	end

	-- leaving after buying something: Gus waves goodbye (in the window and out in the world) before it closes
	menuHooks.npc = {
		Intercept = function()
			if byeing then
				return true
			end
			if boughtSomething then
				byeing = true
				bubbleText.Text = "Thanks for shopping! Bye bye!"
				setPortraitState("bye", 1.6)
				if npcSay then
					npcSay("Gus", "bye")
				end
				task.delay(1.5, function()
					byeing = false
					boughtSomething = false
					closeMenus(true)
				end)
				return true
			end
			return false
		end,
		OnClose = function()
			byeing = false
			pState = "idle"
		end,
	}


end

local refreshPets, petBuffText, petsSig
do
	----------------------------------------------------------------
	-- PETS (only 2 slots to start - more slots cost Robux)
	----------------------------------------------------------------
	local _, petsBody = modal("pets", 860, 620, "MY PETS & STORAGE", Color3.fromRGB(255, 170, 225))
	local petsInfo = label({ Size = UDim2.new(1, 0, 0, 28), TextSize = 18, TextColor3 = Color3.fromRGB(255, 235, 150), Text = "" }, petsBody)
	local petsScroll = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, petsBody)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, petsScroll)
	make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10) }, petsScroll)
	petsSig = ""

	function petBuffText(def)
		local parts = {}
		if def.Cash > 0 then
			table.insert(parts, "+" .. math.floor(def.Cash * 100 + 0.5) .. "% cash")
		end
		if def.Speed > 0 then
			table.insert(parts, "+" .. math.floor(def.Speed * 100 + 0.5) .. "% speed")
		end
		return table.concat(parts, "   ")
	end

	local petSwapSel = nil -- a stored pet you picked to swap into an equipped slot
	function refreshPets()
		local csv = player:GetAttribute("Pets") or ""
		local boxCsv = player:GetAttribute("PetBox") or ""
		local slots = player:GetAttribute("PetSlots") or Config.PetSlotsFree
		local cashNow = player:GetAttribute("Cash") or 0
		local nextCost = Config.PetSlotCost(slots + 1)
		local canBuyNext = nextCost ~= nil and cashNow >= nextCost
		local names, box = {}, {}
		for n in string.gmatch(csv, "[^,]+") do
			table.insert(names, n)
		end
		for n in string.gmatch(boxCsv, "[^,]+") do
			table.insert(box, n)
		end
		if petSwapSel and not box[petSwapSel] then
			petSwapSel = nil
		end
		petsInfo.Text = ("Slots %d/%d     Storage %d     Cash +%d%%     Speed +%d%%"):format(#names, slots, #box, math.floor((player:GetAttribute("PetCash") or 0) * 100 + 0.5), math.floor((player:GetAttribute("PetSpeed") or 0) * 100 + 0.5))
		local sig = csv .. "|" .. boxCsv .. "|" .. slots .. "|" .. (canBuyNext and 1 or 0) .. "|" .. tostring(petSwapSel)
		if sig == petsSig then
			return
		end
		petsSig = sig
		for _, c in ipairs(petsScroll:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local function header(text, order, color)
			return label({ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order, TextSize = 20, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Text = text }, petsScroll)
		end
		local function grid(order, cw, ch)
			local g = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, petsScroll)
			make("UIGridLayout", { CellSize = UDim2.fromOffset(cw, ch), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, g)
			return g
		end
		-- SELL (two taps: the first one asks "SURE?")
		local function sellButton(card, y, def, where, idx)
			local price = Config.PetSell[def.Rarity] or 0
			local btn = makeButton({ Position = UDim2.new(0, 8, 0, y), Size = UDim2.new(1, -16, 0, 30), TextSize = 14, Text = "SELL $" .. F(price) }, card, Color3.fromRGB(240, 110, 110))
			local armedUntil = 0
			btn.Activated:Connect(function()
				if os.clock() < armedUntil then
					Action:FireServer("PetSell", where, idx)
				else
					armedUntil = os.clock() + 3
					btn.Text = "SURE?"
					task.delay(3, function()
						if btn.Parent then
							btn.Text = "SELL $" .. F(price)
						end
					end)
				end
			end)
		end

		header("EQUIPPED PETS  (they follow you and give buffs)", 1, Color3.fromRGB(255, 225, 130))
		local g1 = grid(2, 150, 236)
		for i = 1, Config.MaxPetSlots do
			local card = make("Frame", { BackgroundColor3 = Color3.fromRGB(104, 98, 226), LayoutOrder = i }, g1)
			corner(card, 18)
			if i <= #names then
				local def = Config.PetById[names[i]]
				local rcol = Config.Rarities[def.Rarity].Color
				make("UIStroke", { Thickness = 3, Color = rcol }, card)
				local icon = petIcon(card, def.Id, 90)
				icon.Position = UDim2.new(0.5, -45, 0, 6)
				label({ Position = UDim2.fromOffset(4, 98), Size = UDim2.new(1, -8, 0, 24), TextScaled = true, TextColor3 = rcol, Text = def.Id }, card)
				label({ Position = UDim2.fromOffset(4, 122), Size = UDim2.new(1, -8, 0, 34), TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 225, 120), Text = def.Rarity:upper() .. "\n" .. petBuffText(def) }, card)
				if petSwapSel then
					local sw = makeButton({ Position = UDim2.new(0, 8, 0, 160), Size = UDim2.new(1, -16, 0, 32), TextSize = 16, Text = "SWAP IN" }, card, GREEN)
					sw.Activated:Connect(function()
						Action:FireServer("PetSwap", i, petSwapSel)
						petSwapSel = nil
						petsSig = ""
					end)
				else
					local st = makeButton({ Position = UDim2.new(0, 8, 0, 160), Size = UDim2.new(1, -16, 0, 32), TextSize = 16, Text = "STORE" }, card, BLUE)
					st.Activated:Connect(function()
						Action:FireServer("PetUnequip", i)
					end)
				end
				sellButton(card, 198, def, "eq", i)
			elseif i <= slots then
				make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(140, 150, 230) }, card)
				card.BackgroundTransparency = 0.4
				label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.new(1, -20, 0, 34), TextSize = 22, TextColor3 = Color3.fromRGB(190, 200, 255), Text = "EMPTY SLOT" }, card)
				label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.new(1, -20, 0, 70), TextSize = 14, TextWrapped = true, TextColor3 = Color3.fromRGB(215, 220, 255), Text = "Hatch an egg at the Pet Stand, or EQUIP a stored pet below!" }, card)
			else
				card.BackgroundColor3 = Color3.fromRGB(74, 70, 150)
				local cashCost = Config.PetSlotCost(i)
				local isNext = i == slots + 1
				make("UIStroke", { Thickness = 2, Color = cashCost and GREEN or GOLD }, card)
				label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.new(1, -20, 0, 36), TextSize = 24, TextColor3 = GOLD, Text = "LOCKED" }, card)
				label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.new(1, -20, 0, 40), TextSize = 14, TextWrapped = true, TextColor3 = Color3.fromRGB(215, 220, 255), Text = cashCost and "Unlock with cash" or "Unlock with Robux" }, card)
				if cashCost then
					local buy = makeButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 42), TextSize = 18, Text = "$" .. F(cashCost) }, card, (isNext and canBuyNext) and GREEN or GREY)
					buy.Activated:Connect(function()
						if not isNext then
							toast("Unlock slot " .. (i - 1) .. " first", GOLD)
						else
							Action:FireServer("BuyPetSlot")
						end
					end)
				else
					local prod = i == 5 and Config.Products.PetSlot5 or Config.Products.PetSlot6
					local buy = makeButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 42), TextSize = 15, Text = isNext and ("BUY  R$" .. prod.Price) or ("UNLOCK SLOT " .. (i - 1) .. " FIRST") }, card, isNext and GOLD or GREY)
					buy.Activated:Connect(function()
						if not isNext then
							toast("Unlock slot " .. (i - 1) .. " first", GOLD)
							return
						end
						local id = prod.Id
						if id == 0 then
							toast(prod.Label .. ": set its Developer Product ID in the Config first!", GOLD)
						else
							MarketplaceService:PromptProductPurchase(player, id)
						end
					end)
				end
			end
		end

		header("PET STORAGE  (" .. #box .. " pets - keep, swap or sell as many as you like)", 3, Color3.fromRGB(190, 225, 255))
		if #box == 0 then
			label({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4, TextSize = 15, TextColor3 = Color3.fromRGB(215, 220, 255), Text = "Empty. Pets you hatch when your slots are full are kept here safely!" }, petsScroll)
		end
		local g2 = grid(5, 132, 214)
		for i, id in ipairs(box) do
			local def = Config.PetById[id]
			local rcol = Config.Rarities[def.Rarity].Color
			local card = make("Frame", { BackgroundColor3 = Color3.fromRGB(104, 98, 226), LayoutOrder = i }, g2)
			corner(card, 18)
			make("UIStroke", { Thickness = petSwapSel == i and 5 or 3, Color = petSwapSel == i and GOLD or rcol }, card)
			local icon = drawCreature(card, Creatures.SpecForPet(id), 66)
			icon.Position = UDim2.new(0.5, -33, 0, 6)
			label({ Position = UDim2.fromOffset(4, 76), Size = UDim2.new(1, -8, 0, 22), TextScaled = true, TextColor3 = rcol, Text = def.Id }, card)
			label({ Position = UDim2.fromOffset(4, 98), Size = UDim2.new(1, -8, 0, 32), TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 225, 120), Text = def.Rarity:upper() .. "\n" .. petBuffText(def) }, card)
			local free = #names < slots
			local eq = makeButton({ Position = UDim2.new(0, 8, 0, 134), Size = UDim2.new(1, -16, 0, 32), TextSize = 15, Text = free and "EQUIP" or (petSwapSel == i and "CANCEL" or "SWAP") }, card, free and GREEN or (petSwapSel == i and GREY or Color3.fromRGB(255, 170, 60)))
			eq.Activated:Connect(function()
				if free then
					Action:FireServer("PetEquip", i)
				elseif petSwapSel == i then
					petSwapSel = nil
					petsSig = ""
				else
					petSwapSel = i
					petsSig = ""
					toast("Now tap SWAP IN on the equipped pet to replace", GOLD)
				end
			end)
			sellButton(card, 172, def, "box", i)
		end
	end
end

do
	----------------------------------------------------------------
	-- CODES
	----------------------------------------------------------------
	local _, codesBody = modal("codes", 460, 300, "CODES", Color3.fromRGB(255, 200, 70))
	label({ Size = UDim2.new(1, 0, 0, 30), TextSize = 18, TextColor3 = Color3.fromRGB(230, 230, 255), Text = "Type a code to get free rewards!" }, codesBody)
	local codeBox = make("TextBox", {
		Position = UDim2.new(0.5, 0, 0, 50),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0.85, 0, 0, 52),
		BackgroundColor3 = Color3.fromRGB(25, 25, 60),
		Font = FONT,
		TextSize = 26,
		TextColor3 = WHITE,
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = Color3.fromRGB(150, 150, 190),
		Text = "",
		ClearTextOnFocus = false,
	}, codesBody)
	corner(codeBox, 14)
	stroke(codeBox, 2.5, Color3.fromRGB(255, 200, 70))
	local redeemBtn = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(190, 54), Text = "REDEEM", TextSize = 24 }, codesBody, GREEN)
	redeemBtn.Activated:Connect(function()
		if codeBox.Text ~= "" then
			Action:FireServer("Redeem", codeBox.Text)
			codeBox.Text = ""
		end
	end)

end

----------------------------------------------------------------
-- TRADING
----------------------------------------------------------------
local tradeFrame, tradeBody = modal("trade", 800, 560, "TRADING", Color3.fromRGB(120, 255, 170))
local tradeList = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, tradeBody)
local tradeSession = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, tradeBody)
local inTrade = false

local tradeHint = label({ Size = UDim2.new(1, 0, 0, 30), TextSize = 18, TextColor3 = Color3.fromRGB(255, 235, 150), Text = "" }, tradeList)
local tradePlayers = make("Frame", { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), BackgroundTransparency = 1 }, tradeList)
local tradePlayerList = scroller(tradePlayers, 8)
local tradeSignature = ""

local function fmtTime(sec)
	sec = math.max(0, math.ceil(sec))
	return ("%d:%02d"):format(sec // 60, sec % 60)
end

local function refreshTradeList()
	local myOK = player:GetAttribute("TradeOK")
	local left = Config.TradeUnlockSeconds - (player:GetAttribute("PlayTime") or 0)
	tradeHint.Text = myOK and "Pick a player to trade Goobers with!" or ("Trading unlocks in " .. fmtTime(left) .. " of play time")
	local sig = tostring(myOK)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			sig ..= p.UserId .. tostring(p:GetAttribute("TradeOK"))
		end
	end
	if sig == tradeSignature then
		return
	end
	tradeSignature = sig
	for _, c in ipairs(tradePlayerList:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			n += 1
			local ok = p:GetAttribute("TradeOK")
			local r = itemRow(tradePlayerList, ok and GREEN or GREY, "TRADE", 70, n)
			r.Title.Text = p.DisplayName
			r.Desc.Text = ok and "Ready to trade" or "Hasn't unlocked trading yet"
			setBtn(r.Btn, ok and "TRADE" or "LOCKED", (ok and myOK) and GREEN or GREY)
			r.Btn.Activated:Connect(function()
				if not myOK then
					toast("Trading unlocks after 15 minutes of play time!", RED)
				elseif not p:GetAttribute("TradeOK") then
					toast(p.DisplayName .. " hasn't unlocked trading yet.", RED)
				else
					Action:FireServer("TradeRequest", p.UserId)
				end
			end)
		end
	end
	if n == 0 then
		local r = label({ Size = UDim2.new(1, 0, 0, 60), TextSize = 20, TextColor3 = Color3.fromRGB(210, 215, 255), Text = "No other players in this server yet!" }, tradePlayerList)
		r.LayoutOrder = 1
		r.Name = "Empty"
	end
end

-- Goober card used inside the trade window
local function gooberCard(parent, item, onClick, order)
	local def = Config.GooberById[item.Id]
	local rcol = Config.Rarities[def.Rarity].Color
	local card = make("Frame", { Size = UDim2.fromOffset(92, 116), BackgroundColor3 = Color3.fromRGB(104, 98, 226), LayoutOrder = order or 0 }, parent)
	corner(card, 12)
	make("UIStroke", { Thickness = 2.5, Color = rcol }, card)
	local icon = gooberIcon(card, item.Id, item.Mut, 60)
	icon.Position = UDim2.new(0.5, -30, 0, 4)
	label({ Position = UDim2.fromOffset(2, 64), Size = UDim2.new(1, -4, 0, 26), TextScaled = true, TextColor3 = rcol, Text = (item.Mut ~= "Normal" and (item.Mut .. " ") or "") .. item.Id }, card)
	local inc = Config.GooberById[item.Id].Income * Config.Mutations[item.Mut].Mult
	label({ Position = UDim2.fromOffset(2, 90), Size = UDim2.new(1, -4, 0, 20), TextScaled = true, TextColor3 = Color3.fromRGB(255, 225, 120), Text = "$" .. F(inc) .. "/s" }, card)
	local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 4 }, card)
	hit.Activated:Connect(function()
		play("click")
		onClick()
	end)
	return card
end

local function cardRow(parent, size, position, title, horizontalScroll)
	local box = make("Frame", { Size = size, Position = position, BackgroundColor3 = Color3.fromRGB(35, 38, 85) }, parent)
	corner(box, 14)
	stroke(box, 2, Color3.fromRGB(120, 130, 220))
	label({ Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(8, 2), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Text = title }, box)
	local sf = make("ScrollingFrame", {
		Position = UDim2.fromOffset(6, 28),
		Size = UDim2.new(1, -12, 1, -32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
	}, box)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	return sf
end

local mineBox = cardRow(tradeSession, UDim2.new(0.5, -6, 0, 158), UDim2.fromOffset(0, 0), "YOU OFFER  (click to take back)")
local theirBox = cardRow(tradeSession, UDim2.new(0.5, -6, 0, 158), UDim2.new(0.5, 6, 0, 0), "THEY OFFER")
local baseBox = cardRow(tradeSession, UDim2.new(1, 0, 0, 158), UDim2.fromOffset(0, 170), "YOUR BASE  (click a Goober to offer it)")
local tradeStatus = label({ Position = UDim2.new(0, 0, 1, -96), Size = UDim2.new(1, 0, 0, 30), TextSize = 20, TextColor3 = Color3.fromRGB(255, 235, 150), Text = "" }, tradeSession)
local readyBtn = makeButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.3, 0, 1, -8), Size = UDim2.fromOffset(200, 56), Text = "READY", TextSize = 26 }, tradeSession, GREEN)
local cancelBtn = makeButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.7, 0, 1, -8), Size = UDim2.fromOffset(200, 56), Text = "CANCEL", TextSize = 26 }, tradeSession, RED)
local myReady = false
readyBtn.Activated:Connect(function()
	Action:FireServer("TradeReady", not myReady)
end)
cancelBtn.Activated:Connect(function()
	Action:FireServer("TradeCancel")
end)

local function clearCards(box)
	for _, c in ipairs(box:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
end

local function renderTrade(state)
	inTrade = true
	tradeList.Visible = false
	tradeSession.Visible = true
	clearCards(mineBox)
	clearCards(theirBox)
	clearCards(baseBox)
	for i, item in ipairs(state.Mine) do
		gooberCard(mineBox, item, function()
			Action:FireServer("TradeRemove", i)
		end, i)
	end
	for i, item in ipairs(state.Theirs) do
		gooberCard(theirBox, item, function() end, i)
	end
	for i, item in ipairs(state.Base) do
		gooberCard(baseBox, item, function()
			Action:FireServer("TradeAdd", i)
		end, i)
	end
	myReady = state.MyReady
	readyBtn.Text = myReady and "UNREADY" or "READY"
	readyBtn.BackgroundColor3 = myReady and GOLD or GREEN
	if state.MyReady and state.TheirReady then
		tradeStatus.Text = "Completing trade..."
	elseif state.TheirReady then
		tradeStatus.Text = state.Partner .. " is READY! Check the offer and press READY."
	elseif state.MyReady then
		tradeStatus.Text = "Waiting for " .. state.Partner .. "..."
	else
		tradeStatus.Text = "Trading with " .. state.Partner .. " - offer up to " .. Config.TradeMaxItems .. " Goobers."
	end
end

-- incoming trade request popup
local invite = panel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 130),
	Size = UDim2.fromOffset(420, 110),
	Visible = false,
	ZIndex = 9,
}, gui)
local inviteText = label({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 8), TextSize = 22, Text = "", ZIndex = 9 }, invite)
local inviteYes = makeButton({ Position = UDim2.new(0, 24, 1, -58), Size = UDim2.fromOffset(170, 46), Text = "ACCEPT", TextSize = 22, ZIndex = 9 }, invite, GREEN)
local inviteNo = makeButton({ Position = UDim2.new(1, -194, 1, -58), Size = UDim2.fromOffset(170, 46), Text = "DECLINE", TextSize = 22, ZIndex = 9 }, invite, RED)
inviteYes.Activated:Connect(function()
	invite.Visible = false
	Action:FireServer("TradeRespond", true)
end)
inviteNo.Activated:Connect(function()
	invite.Visible = false
	Action:FireServer("TradeRespond", false)
end)

local updateDeals
do
	----------------------------------------------------------------
	-- ROBUX DEALS (star badge button + modal with big cards)
	----------------------------------------------------------------
	local DEAL_STYLE = {
		Thief = { col = Color3.fromRGB(255, 90, 90), sym = "STEAL" },
		DoubleCash = { col = Color3.fromRGB(90, 230, 120), sym = "2x" },
		VIP = { col = Color3.fromRGB(70, 210, 255), sym = ">>" },
		LuckyBox = { col = Color3.fromRGB(255, 110, 190), sym = "?" },
		CashPack = { col = Color3.fromRGB(255, 205, 60), sym = "$$$" },
		SuperLock = { col = Color3.fromRGB(130, 140, 255), sym = "LOCK" },
		PetSlot = { col = Color3.fromRGB(255, 140, 210), sym = "PET" },
	}

	local _, dealsBody = modal("deals", 820, 560, "🧺 SHOP", Color3.fromRGB(255, 215, 70))
	local dealsScroll = make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, dealsBody)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(232, 268), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, dealsScroll)
	make("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, dealsScroll)

	local dealCards = {}
	for i, entry in ipairs(Config.RobuxOrder) do
		local info = (entry.Kind == "pass") and Config.GamePasses[entry.Key] or Config.Products[entry.Key]
		local st = DEAL_STYLE[entry.Key] or { col = BLUE, sym = "R$" }
		local deal = Config.Deals[entry.Key]

		local card = make("Frame", { BackgroundColor3 = st.col:Lerp(Color3.fromRGB(96, 84, 200), 0.5), LayoutOrder = i }, dealsScroll)
		corner(card, 24)
		make("UIStroke", { Thickness = 4, Color = st.col:Lerp(WHITE, 0.2) }, card)
		make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(178, 168, 218)), Rotation = 90 }, card)
		bubbleDeco(card)
		local icon = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(98, 98), BackgroundColor3 = st.col:Lerp(WHITE, 0.12) }, card)
		corner(icon, 49)
		stroke(icon, 3.5)
		make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 170)), Rotation = 90 }, icon)
		itemArt(icon, entry.Key, st.col)
		label({ Position = UDim2.fromOffset(6, 112), Size = UDim2.new(1, -12, 0, 30), TextScaled = true, Text = info.Label }, card)
		local d = label({ Position = UDim2.fromOffset(10, 144), Size = UDim2.new(1, -20, 0, 38), TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(215, 220, 255), Text = info.Desc }, card)
		d:FindFirstChildOfClass("UIStroke").Thickness = 1.5
		local price = label({ Position = UDim2.fromOffset(6, 184), Size = UDim2.new(1, -12, 0, 26), TextSize = 16, RichText = true, TextColor3 = Color3.fromRGB(255, 225, 120), Text = "" }, card)
		if deal and deal.Was then
			price.Text = ("<s>R$ %d</s>   R$ %d"):format(deal.Was, info.Price)
		else
			price.Text = "R$ " .. info.Price
		end
		local buy = makeButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -30, 0, 44), Text = "BUY", TextSize = 24 }, card, GREEN)
		buy.Activated:Connect(function()
			if info.Id == 0 then
				toast(info.Label .. ": set its ID in the Config script first!", GOLD)
			elseif entry.Kind == "pass" then
				MarketplaceService:PromptGamePassPurchase(player, info.Id)
			else
				MarketplaceService:PromptProductPurchase(player, info.Id)
			end
		end)
		if deal and deal.Was and deal.Was > info.Price then
			local pct = math.floor((1 - info.Price / deal.Was) * 100 + 0.5)
			local b = burst(card, 78, GOLD)
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Position = UDim2.new(1, -20, 0, 26)
			b.Rotation = 12
			label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), TextScaled = true, TextColor3 = Color3.fromRGB(190, 20, 40), Text = pct .. "%\nOFF", ZIndex = 4 }, b)
			b.ZIndex = 4
		end
		dealCards[entry.Key] = { Buy = buy, Kind = entry.Kind, Key = entry.Key }
	end

	function updateDeals()
		for key, c in pairs(dealCards) do
			if c.Kind == "pass" and player:GetAttribute("Own_" .. key) then
				setBtn(c.Buy, "OWNED", GREY)
			else
				setBtn(c.Buy, "BUY", GREEN)
			end
		end
	end

end

----------------------------------------------------------------
-- SPEED / CAPACITY MINI WINDOW (opens when you step on the glowing pad in front of the stand)
-- Buy 1, 5 or 10 levels at once. Capacity is limited by your Rebirths.
----------------------------------------------------------------
local openStand, updateStand
do
	local ACC = { Speed = Color3.fromRGB(70, 210, 255), Carry = Color3.fromRGB(255, 170, 60) }
	local standFrame, standBody, standTitle = modal("stand", 520, 440, "SPEED UPGRADE", ACC.Speed)
	local standStroke = standFrame:FindFirstChildOfClass("UIStroke")
	local cur = "Speed"
	local lvlL = label({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 52), TextSize = 44, Text = "" }, standBody)
	local infoL = label({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 30), TextSize = 22, TextColor3 = Color3.fromRGB(215, 225, 255), Text = "" }, standBody)
	local noteL = label({ Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 26), TextSize = 16, TextColor3 = Color3.fromRGB(255, 225, 130), Text = "" }, standBody)
	local rows = {}
	for i, n in ipairs({ 1, 5, 10 }) do
		local b = makeButton({ Position = UDim2.fromOffset(0, 128 + (i - 1) * 78), Size = UDim2.new(1, 0, 0, 68), TextSize = 25, Text = "" }, standBody, GREEN)
		b.Activated:Connect(function()
			Action:FireServer("Upgrade", cur, n)
		end)
		rows[i] = { Btn = b, N = n }
	end

	function updateStand()
		if not standFrame.Visible then
			return
		end
		local lvl = player:GetAttribute(cur == "Speed" and "SpeedLvl" or "CarryLvl") or 0
		local cash = player:GetAttribute("Cash") or 0
		local vip = player:GetAttribute("Own_VIP")
		local maxLvl = player:GetAttribute("CarryMax") or 3
		if cur == "Speed" then
			lvlL.Text = "LEVEL " .. lvl
			infoL.Text = ("Run speed: %d"):format(Config.WalkSpeed(lvl, vip))
			noteL.Text = lvl >= Config.Upgrades.Speed.Max and "MAX SPEED reached!" or ("Top speed: %d"):format(Config.MaxWalkSpeed)
		else
			local cap = player:GetAttribute("CarryCap") or 1
			lvlL.Text = "CARRY " .. cap
			infoL.Text = ("You can carry %d Goobers at once"):format(cap)
			noteL.Text = lvl >= maxLvl and "LIMIT REACHED - Rebirth to carry more!" or ("Limit right now: %d   (each Rebirth adds +2)"):format(Config.CarryCap(maxLvl))
		end
		for _, r in ipairs(rows) do
			local n = r.N
			if cur == "Carry" then
				n = math.min(n, math.max(0, maxLvl - lvl))
			elseif cur == "Speed" then
				n = math.min(n, math.max(0, Config.Upgrades.Speed.Max - lvl))
			end
			if n <= 0 then
				setBtn(r.Btn, cur == "Speed" and "MAX SPEED" or "REBIRTH TO UNLOCK", GREY)
			else
				local cost = 0
				for k = 0, n - 1 do
					cost += Config.UpgradeCost(cur, lvl + k)
				end
				local gain
				if cur == "Speed" then
					gain = ("+%d speed"):format(Config.WalkSpeed(lvl + n, vip) - Config.WalkSpeed(lvl, vip))
				else
					gain = ("+%d carry"):format(n)
				end
				setBtn(r.Btn, ("x%d    %s    $%s"):format(n, gain, F(cost)), cash >= cost and GREEN or GREY)
			end
		end
	end

	function openStand(up)
		if not Config.Upgrades[up] or not ACC[up] then
			return
		end
		cur = up
		standTitle.Text = up == "Speed" and "SPEED UPGRADE" or "CAPACITY UPGRADE"
		standTitle.TextColor3 = ACC[up]:Lerp(WHITE, 0.35)
		standStroke.Color = ACC[up]
		toggleMenu("stand", true)
		updateStand()
	end
end

----------------------------------------------------------------
-- REBIRTH: its own dedicated window (moved out of the Upgrades list). Shows the Speed requirement as a progress bar,
-- what you get for rebirthing, and a reminder that Speed/Capacity/Slots/etc are still in the Upgrades tab.
----------------------------------------------------------------
local openRebirth, updateRebirth
do
	local RCOL = Color3.fromRGB(255, 90, 90)
	local rFrame, rBody = modal("rebirth", 600, 680, "REBIRTH", RCOL)
	local iconBox = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(96, 96), BackgroundColor3 = RCOL:Lerp(WHITE, 0.15) }, rBody)
	corner(iconBox, 48)
	stroke(iconBox, 4, WHITE)
	make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 170)), Rotation = 90 }, iconBox)
	itemArt(iconBox, "Rebirth", RCOL)
	local rTitle = label({ Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 0, 46), TextSize = 36, TextColor3 = RCOL, Text = "REBIRTH 1" }, rBody)
	local reqLabel = label({ Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 30), TextSize = 22, TextColor3 = Color3.fromRGB(255, 230, 150), Text = "Requirement" }, rBody)
	local barBg = make("Frame", { Position = UDim2.fromOffset(0, 190), Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Color3.fromRGB(40, 32, 70) }, rBody)
	corner(barBg, 16)
	stroke(barBg, 3, RCOL)
	local barFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 230, 140) }, barBg)
	corner(barFill, 16)
	local barText = label({ Size = UDim2.fromScale(1, 1), TextSize = 18, Text = "" }, barBg)
	local rebirthBtn = makeButton({ Position = UDim2.fromOffset(0, 236), Size = UDim2.new(1, 0, 0, 70), TextSize = 30, Text = "REBIRTH" }, rBody, GREEN)
	label({ Position = UDim2.fromOffset(0, 320), Size = UDim2.new(1, 0, 0, 30), TextSize = 20, TextColor3 = Color3.fromRGB(255, 225, 130), Text = "WHAT YOU GET:" }, rBody)
	local perksList = label({
		Position = UDim2.fromOffset(4, 354),
		Size = UDim2.new(1, -8, 0, 190),
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(220, 225, 255),
		Text = "",
	}, rBody)
	rebirthBtn.Activated:Connect(function()
		Action:FireServer("Rebirth")
	end)
	function openRebirth()
		toggleMenu("rebirth", true)
		updateRebirth()
	end
	function updateRebirth()
		if not rFrame.Visible then
			return
		end
		local rebirths = player:GetAttribute("Rebirths") or 0
		local speedLvl = player:GetAttribute("SpeedLvl") or 0
		local need = Config.RebirthSpeedLevel(rebirths)
		local cash = player:GetAttribute("Cash") or 0
		local rc = Config.RebirthCost(rebirths)
		rTitle.Text = "REBIRTH " .. (rebirths + 1)
		local ready = speedLvl >= need
		local atCap = need >= Config.Upgrades.Speed.Max
		reqLabel.Text = ready and "Requirement met!" or ("Reach Speed Level %d to unlock"):format(need)
		barFill.Size = UDim2.fromScale(math.clamp(speedLvl / need, 0, 1), 1)
		barFill.BackgroundColor3 = ready and Color3.fromRGB(90, 230, 140) or Color3.fromRGB(255, 170, 60)
		barText.Text = ("Speed Level %d / %d"):format(math.min(speedLvl, need), need)
		if not ready then
			setBtn(rebirthBtn, "SPEED LEVEL " .. need .. " NEEDED", GREY)
		else
			setBtn(rebirthBtn, "$" .. F(rc), cash >= rc and GREEN or GREY)
		end
		perksList.Text = ("⚡ Cash, Speed and Luck all reset to 0\n💰 Permanent x%s income multiplier\n🎒 Unlocks more Carry Capacity\n🏃 +%d extra top speed, forever\n\n📈 Each rebirth after this needs even more Speed%s"):format(tostring(Config.Multiplier(rebirths + 1)), Config.MaxWalkSpeedPerRebirth, atCap and " (you've reached the highest requirement - more is coming in a future update!)" or "")
	end
end

----------------------------------------------------------------
-- EGG WINDOW: every pet in the egg with its exact odds. Open 1 with cash, or 3 with Robux.
----------------------------------------------------------------
local openEgg, updateEggButtons
do
	local eggFrame, eggBody, eggTitle = modal("egg", 800, 540, "EGG", Color3.fromRGB(255, 170, 225))
	local eggStroke = eggFrame:FindFirstChildOfClass("UIStroke")
	local curEgg = Config.Eggs[1]
	local eggIndex = 1

	local left = make("Frame", { Size = UDim2.new(0, 220, 1, 0), BackgroundColor3 = Color3.fromRGB(118, 90, 208) }, eggBody)
	corner(left, 18)
	local leftStroke = stroke(left, 3, PINK)
	local eggArt = make("Frame", { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 190), BackgroundTransparency = 1 }, left)
	local eggShape = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(118, 150), BackgroundColor3 = WHITE }, eggArt)
	corner(eggShape, 60)
	stroke(eggShape, 4)
	make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(175, 175, 195)), Rotation = 90 }, eggShape)
	for _, p in ipairs({ { 0.3, 0.32, 20 }, { 0.68, 0.45, 26 }, { 0.42, 0.66, 22 }, { 0.72, 0.74, 16 } }) do
		local s = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(p[1], p[2]), Size = UDim2.fromOffset(p[3], p[3]), BackgroundColor3 = WHITE, BackgroundTransparency = 0.35 }, eggShape)
		corner(s, 13)
	end
	local shine = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.28, 0.2), Size = UDim2.fromOffset(16, 30), BackgroundColor3 = WHITE, Rotation = 30, BackgroundTransparency = 0.2 }, eggShape)
	corner(shine, 8)
	TweenService:Create(eggShape, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 4 }):Play()

	local nameL = label({ Position = UDim2.fromOffset(0, 194), Size = UDim2.new(1, 0, 0, 30), TextSize = 24, Text = "" }, left)
	local tiersL = label({ Position = UDim2.fromOffset(4, 220), Size = UDim2.new(1, -8, 0, 18), TextSize = 13, TextColor3 = Color3.fromRGB(255, 235, 150), Text = "" }, left)
	local prevB = makeButton({ Position = UDim2.fromOffset(6, 72), Size = UDim2.fromOffset(34, 48), TextSize = 26, Text = "<" }, left, Color3.fromRGB(110, 120, 230))
	local nextB = makeButton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 72), Size = UDim2.fromOffset(34, 48), TextSize = 26, Text = ">" }, left, Color3.fromRGB(110, 120, 230))
	local open1 = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 240), Size = UDim2.new(1, -24, 0, 60), TextSize = 22, Text = "" }, left, GREEN)
	local open3 = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 312), Size = UDim2.new(1, -24, 0, 60), TextSize = 22, Text = "" }, left, GOLD)
	local hint = label({ Position = UDim2.fromOffset(8, 380), Size = UDim2.new(1, -16, 0, 58), TextSize = 14, TextWrapped = true, TextColor3 = Color3.fromRGB(215, 220, 255), Text = "OPEN 3 hatches three at once. Pets that don't fit are sold for cash. The % is your exact chance!" }, left)

	local right = make("ScrollingFrame", {
		Position = UDim2.fromOffset(230, 0),
		Size = UDim2.new(1, -230, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, eggBody)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(124, 150), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, right)
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, right)

	open1.Activated:Connect(function()
		Action:FireServer("Hatch", curEgg.Id)
	end)
	prevB.Activated:Connect(function()
		openEgg(Config.Eggs[(eggIndex - 2) % #Config.Eggs + 1].Id)
	end)
	nextB.Activated:Connect(function()
		openEgg(Config.Eggs[eggIndex % #Config.Eggs + 1].Id)
	end)
	open3.Activated:Connect(function()
		if curEgg.Product3.Id == 0 then
			toast("Set this egg's Product3 Id in Config", GOLD)
		else
			MarketplaceService:PromptProductPurchase(player, curEgg.Product3.Id)
		end
	end)

	local function build(egg)
		for _, c in ipairs(right:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local list = {}
		for _, e in ipairs(egg.Pool) do
			table.insert(list, { Def = Config.PetById[e[1]], Chance = e[2] })
		end
		table.sort(list, function(a, b)
			local ra, rb = Config.Rarities[a.Def.Rarity].Rank, Config.Rarities[b.Def.Rarity].Rank
			if ra ~= rb then
				return ra > rb
			end
			if a.Chance ~= b.Chance then
				return a.Chance > b.Chance
			end
			return a.Def.Id < b.Def.Id
		end)
		for i, e in ipairs(list) do
			local rcol = Config.Rarities[e.Def.Rarity].Color
			local card = make("Frame", { BackgroundColor3 = rcol:Lerp(Color3.fromRGB(96, 84, 200), 0.7), LayoutOrder = i }, right)
			corner(card, 18)
			make("UIStroke", { Thickness = 3, Color = rcol }, card)
			make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(180, 172, 220)), Rotation = 90 }, card)
			local ic = petIcon(card, e.Def.Id, 70)
			ic.Position = UDim2.new(0.5, -35, 0, 6)
			label({ Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 0, 22), TextScaled = true, TextColor3 = rcol, Text = e.Def.Id }, card)
			label({ Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, Text = e.Def.Rarity:upper() }, card)
			label({ Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 26), TextSize = 22, TextColor3 = Color3.fromRGB(255, 235, 130), Text = string.format("%g", e.Chance) .. "%" }, card)
			if e.Def.Rarity == egg.Tiers.New then -- the rarity that only THIS egg brings
				local rib = label({ Position = UDim2.fromOffset(-4, 4), Size = UDim2.fromOffset(48, 20), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 90, 100), TextSize = 13, Rotation = -12, Text = "NEW!", ZIndex = 5 }, card)
				make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, rib)
			end
		end
	end

	function openEgg(id)
		local egg = Config.EggById[id]
		if not egg then
			return
		end
		curEgg = egg
		for i, e in ipairs(Config.Eggs) do
			if e == egg then
				eggIndex = i
			end
		end
		eggTitle.Text = egg.Label:upper()
		eggTitle.TextColor3 = egg.Color:Lerp(WHITE, 0.4)
		eggStroke.Color = egg.Color
		leftStroke.Color = egg.Color
		eggShape.BackgroundColor3 = egg.Color
		nameL.Text = egg.Label
		nameL.TextColor3 = egg.Color:Lerp(WHITE, 0.3)
		tiersL.Text = egg.Tiers.Previous .. " (stronger)  +  NEW: " .. egg.Tiers.New
		build(egg)
		toggleMenu("egg", true)
	end

	-- keeps the buttons showing the right prices / affordability
	function updateEggButtons()
		if not eggFrame.Visible then
			return
		end
		local cash = player:GetAttribute("Cash") or 0
		setBtn(open1, "OPEN 1    $" .. F(curEgg.Price), cash >= curEgg.Price and GREEN or GREY)
		open3.Text = "OPEN 3    R$" .. curEgg.Product3.Price
	end
end

----------------------------------------------------------------
-- DAILY REWARDS (7-day streak - day 7 is King Goldie, and every full week you complete makes next week's rewards better)
----------------------------------------------------------------
local updateDaily
do
	local DAILY_COL = Color3.fromRGB(255, 205, 80)
	local dFrame, dBody = modal("daily", 780, 470, "DAILY REWARDS", DAILY_COL)
	local weekLabel = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(160, 26), TextSize = 15, TextColor3 = Color3.fromRGB(180, 255, 200), TextXAlignment = Enum.TextXAlignment.Right, Text = "" }, dBody)
	local cards = {}
	local function fillBox(i, week)
		local r, c = Config.DailyRewards[i], cards[i]
		for _, ch in ipairs(c.Box:GetChildren()) do
			ch:Destroy()
		end
		if r.Goober then
			local ic = gooberIcon(c.Box, r.Goober, Config.DailyMutationForWeek(week), 72)
			ic.Position = UDim2.fromOffset(4, 10)
		elseif r.Traps then
			local bonus = math.floor(week / Config.DailyWeekTrapGrowth)
			label({ Size = UDim2.fromScale(1, 1), TextSize = 26, TextColor3 = RED, Text = "x" .. (r.Traps + bonus) .. "\nTRAPS" }, c.Box)
		else
			label({ Size = UDim2.fromScale(1, 1), TextSize = 22, TextColor3 = Color3.fromRGB(130, 255, 150), Text = "$" .. F(math.floor(r.Cash * Config.DailyRewardScale(week))) }, c.Box)
		end
	end
	for i, r in ipairs(Config.DailyRewards) do
		local special = i == 7
		local card = make("Frame", { Position = UDim2.fromOffset((i - 1) * 103, 4), Size = UDim2.fromOffset(96, 250), BackgroundColor3 = Color3.fromRGB(104, 98, 226) }, dBody)
		corner(card, 16)
		local st = make("UIStroke", { Thickness = 3, Color = special and Color3.fromRGB(255, 90, 210) or Color3.fromRGB(140, 150, 230) }, card)
		label({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 24), TextSize = 18, TextColor3 = special and Color3.fromRGB(255, 130, 230) or WHITE, Text = "DAY " .. i }, card)
		local box = make("Frame", { Position = UDim2.fromOffset(8, 36), Size = UDim2.fromOffset(80, 92), BackgroundColor3 = Color3.fromRGB(74, 76, 178) }, card)
		corner(box, 12)
		local txt = r.Goober or (r.Traps and "Bear Traps" or "Cash")
		label({ Position = UDim2.fromOffset(2, 132), Size = UDim2.new(1, -4, 0, 40), TextScaled = true, TextWrapped = true, Text = txt }, card)
		local tag = label({ Position = UDim2.fromOffset(0, 190), Size = UDim2.new(1, 0, 0, 40), TextSize = 16, Text = "" }, card)
		cards[i] = { Card = card, Stroke = st, Tag = tag, Box = box }
		fillBox(i, 0)
	end
	local lastWeek = 0
	local claim = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 280), Size = UDim2.fromOffset(300, 66), TextSize = 30, Text = "CLAIM" }, dBody, GREEN)
	local timerL = label({ Position = UDim2.fromOffset(0, 356), Size = UDim2.new(1, 0, 0, 26), TextSize = 18, TextColor3 = Color3.fromRGB(215, 225, 255), Text = "" }, dBody)
	claim.Activated:Connect(function()
		Action:FireServer("ClaimDaily")
	end)

	function updateDaily()
		if not dFrame.Visible then
			return
		end
		local week = player:GetAttribute("DailyWeeks") or 0
		if week ~= lastWeek then
			lastWeek = week
			weekLabel.Text = week > 0 and ("WEEK " .. (week + 1) .. " - rewards are better now!") or ""
			for i in ipairs(cards) do
				fillBox(i, week)
			end
		end
		local ready = player:GetAttribute("DailyReady")
		local day = player:GetAttribute("DailyDay") or 1
		local done = player:GetAttribute("DailyDone") or 0
		for i, c in ipairs(cards) do
			if i <= done and not (ready and i == day) then
				c.Card.BackgroundColor3 = Color3.fromRGB(40, 90, 70)
				c.Tag.Text = "CLAIMED"
				c.Tag.TextColor3 = Color3.fromRGB(130, 255, 160)
				c.Stroke.Color = Color3.fromRGB(90, 220, 130)
			elseif ready and i == day then
				c.Card.BackgroundColor3 = Color3.fromRGB(96, 84, 40)
				c.Tag.Text = "TODAY!"
				c.Tag.TextColor3 = DAILY_COL
				c.Stroke.Color = DAILY_COL
			else
				c.Card.BackgroundColor3 = Color3.fromRGB(104, 98, 226)
				c.Tag.Text = ""
				c.Stroke.Color = i == 7 and Color3.fromRGB(255, 90, 210) or Color3.fromRGB(140, 150, 230)
			end
		end
		if ready then
			setBtn(claim, "CLAIM DAY " .. day, GREEN)
			timerL.Text = "Log in every day - don't break the streak!"
		else
			setBtn(claim, "COME BACK TOMORROW", GREY)
			local left = Config.DayLength - (os.time() % Config.DayLength)
			timerL.Text = ("Next reward in %02d:%02d:%02d"):format(left // 3600, (left % 3600) // 60, left % 60)
		end
	end
end

----------------------------------------------------------------
-- DONATE: pure Robux support, no reward - just a thank-you. Updates the in-game Top Donators board immediately.
----------------------------------------------------------------
do
	local DCOL = Color3.fromRGB(255, 105, 160)
	local dFrame, dBody = modal("donate", 620, 520, "DONATE", DCOL)
	label({ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 44), TextSize = 16, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 220, 235), Text = "Support the game! Pick any amount - it's pure support, no reward, and you'll show up on the Top Donators board right away." }, dBody)
	local grid = make("Frame", { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1 }, dBody)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(140, 178), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for i, key in ipairs(Config.DonationTiers) do
		local prod = Config.Products[key]
		local card = make("Frame", { BackgroundColor3 = Color3.fromRGB(104, 98, 226), LayoutOrder = i }, grid)
		corner(card, 18)
		make("UIStroke", { Thickness = 2.5, Color = DCOL }, card)
		local ic = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.05), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1 }, card)
		itemArt(ic, "donate", DCOL)
		label({ Position = UDim2.fromOffset(4, 52), Size = UDim2.new(1, -8, 0, 26), TextScaled = true, TextColor3 = GOLD, Text = "R$" .. prod.Price }, card)
		local descBox = make("Frame", { Position = UDim2.fromOffset(6, 80), Size = UDim2.new(1, -12, 0, 48), BackgroundTransparency = 1 }, card)
		label({ Size = UDim2.fromScale(1, 1), TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(230, 220, 255), Text = prod.Desc }, descBox)
		local buy = makeButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 32), TextSize = 14, Text = "DONATE" }, card, DCOL)
		buy.Activated:Connect(function()
			if prod.Id == 0 then
				toast(prod.Label .. ": set its Developer Product ID in the Config first!", GOLD)
			else
				MarketplaceService:PromptProductPurchase(player, prod.Id)
			end
		end)
	end
end

----------------------------------------------------------------
-- GROUP REWARD (only shown once you set Config.Group.Id)
----------------------------------------------------------------
local updateGroup
do
	local GCOL = Color3.fromRGB(120, 200, 255)
	local gFrame, gBody = modal("group", 560, 470, "GROUP REWARD", GCOL)
	label({ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 34), TextSize = 26, TextColor3 = Color3.fromRGB(255, 235, 140), Text = "FREE EPIC PET + $" .. F(Config.Group.Cash or 0) .. "!" }, gBody)
	local rewardPet = Config.PetById[Config.Group.Pet]
	if rewardPet then
		local ic = petIcon(gBody, rewardPet.Id, 150)
		ic.Position = UDim2.new(0.5, -75, 0, 40)
		label({ Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 30), TextSize = 24, TextColor3 = Config.Rarities[rewardPet.Rarity].Color, Text = rewardPet.Rarity:upper() .. " PET:  " .. rewardPet.Id }, gBody)
	end
	label({ Position = UDim2.fromOffset(0, 232), Size = UDim2.new(1, 0, 0, 62), TextSize = 17, TextWrapped = true, TextColor3 = Color3.fromRGB(215, 225, 255), Text = ("1. Like the game and join the Roblox group  \"%s\"\n2. Come back here and press CLAIM"):format(Config.Group.Name) }, gBody)
	local claim = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 312), Size = UDim2.fromOffset(300, 66), TextSize = 30, Text = "CLAIM" }, gBody, GREEN)
	claim.Activated:Connect(function()
		Action:FireServer("ClaimGroup")
	end)
	function updateGroup()
		if not gFrame.Visible then
			return
		end
		local claimed = player:GetAttribute("GroupClaimed")
		setBtn(claim, claimed and "CLAIMED" or "CLAIM", claimed and GREY or GREEN)
	end
end

----------------------------------------------------------------
-- INDEX: every Goober and pet in the game. The ones you have found are in colour, the rest are a dark "?".
-- Every 5 new finds pays cash (each payout is bigger than the last).
----------------------------------------------------------------
local refreshIndex
do
	local ICOL = Color3.fromRGB(255, 190, 80)
	local iFrame, iBody = modal("index", 900, 620, "INDEX", ICOL)
	local tab = "G"
	local tabB = {
		G = makeButton({ Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(180, 44), TextSize = 22, Text = "GOOBERS" }, iBody, Color3.fromRGB(70, 200, 255)),
		P = makeButton({ Position = UDim2.fromOffset(190, 0), Size = UDim2.fromOffset(180, 44), TextSize = 22, Text = "PETS" }, iBody, Color3.fromRGB(255, 120, 200)),
	}
	local info = label({ Position = UDim2.fromOffset(384, 0), Size = UDim2.new(1, -384, 0, 44), TextSize = 16, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 235, 150), TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, iBody)
	local barBg = make("Frame", { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Color3.fromRGB(60, 50, 140) }, iBody)
	corner(barBg, 7)
	stroke(barBg, 2)
	local barFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ICOL }, barBg)
	corner(barFill, 7)
	local scroll = make("ScrollingFrame", { Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 1, -74), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, iBody)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, scroll)
	local lastSig = ""

	local function parseSet(csv)
		local set = {}
		for id in string.gmatch(csv or "", "[^,]+") do
			set[id] = true
		end
		return set
	end

	local function build(foundG, foundP)
		for _, c in ipairs(scroll:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local order = 0
		local function header(text, color)
			order += 1
			label({ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, TextSize = 19, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Text = text }, scroll)
		end
		local function grid()
			order += 1
			local g = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, scroll)
			make("UIGridLayout", { CellSize = UDim2.fromOffset(84, 112), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, g)
			return g
		end
		local function card(g, def, spec, found, rarityColor)
			local c = make("Frame", { BackgroundColor3 = found and rarityColor:Lerp(Color3.fromRGB(96, 84, 200), 0.65) or Color3.fromRGB(58, 52, 120) }, g)
			corner(c, 14)
			make("UIStroke", { Thickness = 2.5, Color = found and rarityColor or Color3.fromRGB(96, 90, 160) }, c)
			local shown = found and spec or { Style = def.Style, Color = Color3.fromRGB(26, 22, 58), RarityColor = Color3.fromRGB(70, 66, 120), Rank = 1, Scale = 1, Mutation = "Normal" }
			local ic = drawCreature(c, shown, 58)
			ic.Position = UDim2.new(0.5, -29, 0, 5)
			if not found then
				label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.fromOffset(30, 30), TextSize = 26, TextColor3 = Color3.fromRGB(200, 195, 255), Text = "?" }, c)
			end
			label({ Position = UDim2.fromOffset(2, 68), Size = UDim2.new(1, -4, 0, 20), TextScaled = true, TextColor3 = found and rarityColor or Color3.fromRGB(150, 145, 200), Text = found and def.Id or "???" }, c)
			label({ Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 16), TextSize = 11, TextColor3 = found and WHITE or Color3.fromRGB(150, 145, 200), Text = def.Rarity:upper() }, c)
		end
		if tab == "G" then
			for z = 1, Config.ZoneCount do
				header(("ZONE %d  -  %s"):format(z, Config.Zones[z].Name), Config.Zones[z].Accent)
				local g = grid()
				for _, def in ipairs(Config.Goobers) do
					if def.Zone == z then
						card(g, def, Creatures.SpecForGoober(def.Id, "Normal"), foundG[def.Id], Config.Rarities[def.Rarity].Color)
					end
				end
			end
			header("SPECIAL", GOLD)
			local g = grid()
			for _, def in ipairs(Config.Goobers) do
				if def.Zone == 0 then
					card(g, def, Creatures.SpecForGoober(def.Id, "Normal"), foundG[def.Id], Config.Rarities[def.Rarity].Color)
				end
			end
		else
			for _, egg in ipairs(Config.Eggs) do
				header(egg.Label .. "  -  " .. egg.Tiers.Previous .. " + NEW " .. egg.Tiers.New, egg.Color:Lerp(WHITE, 0.3))
				local g = grid()
				for _, e in ipairs(egg.Pool) do
					local def = Config.PetById[e[1]]
					card(g, def, Creatures.SpecForPet(def.Id), foundP[def.Id], Config.Rarities[def.Rarity].Color)
				end
			end
			header("GIFTS", GOLD)
			local g = grid()
			for _, id in ipairs({ Config.Group.Pet }) do
				local def = Config.PetById[id]
				if def and not Config.PetEgg[id] then
					card(g, def, Creatures.SpecForPet(def.Id), foundP[def.Id], Config.Rarities[def.Rarity].Color)
				end
			end
		end
	end

	local function count(set)
		local n = 0
		for _ in pairs(set) do
			n += 1
		end
		return n
	end

	function refreshIndex()
		if not iFrame.Visible then
			return
		end
		local gCsv, pCsv = player:GetAttribute("IndexG") or "", player:GetAttribute("IndexP") or ""
		local sig = tab .. "|" .. gCsv .. "|" .. pCsv
		if sig == lastSig then
			return
		end
		lastSig = sig
		local foundG, foundP = parseSet(gCsv), parseSet(pCsv)
		local isG = tab == "G"
		local total = 0
		if isG then
			for _ in ipairs(Config.Goobers) do
				total += 1
			end
		else
			total = #Config.Pets
		end
		local found = count(isG and foundG or foundP)
		info.Text = found >= total and "You found EVERYTHING! Every new find pays cash the instant you get it." or ("Found %d / %d      Every NEW find pays cash instantly - rarer = more!"):format(found, total)
		barFill.Size = UDim2.fromScale(math.clamp(found / math.max(1, total), 0, 1), 1)
		barFill.BackgroundColor3 = isG and Color3.fromRGB(70, 200, 255) or Color3.fromRGB(255, 120, 200)
		tabB.G.BackgroundColor3 = isG and Color3.fromRGB(70, 200, 255) or Color3.fromRGB(96, 90, 170)
		tabB.P.BackgroundColor3 = (not isG) and Color3.fromRGB(255, 120, 200) or Color3.fromRGB(96, 90, 170)
		build(foundG, foundP)
	end
	tabB.G.Activated:Connect(function()
		tab = "G"
		lastSig = ""
		refreshIndex()
	end)
	tabB.P.Activated:Connect(function()
		tab = "P"
		lastSig = ""
		refreshIndex()
	end)
end

----------------------------------------------------------------
-- MARKET: teleport list
----------------------------------------------------------------
do
	local _, mBody = modal("market", 520, 460, "MARKET", Color3.fromRGB(255, 150, 90))
	local list = scroller(mBody, 8)
	local function entry(order, color, title, key)
		local b = makeButton({ Size = UDim2.new(1, -6, 0, 62), TextSize = 26, Text = title, LayoutOrder = order }, list, color)
		b.Activated:Connect(function()
			Action:FireServer("TeleportMarket", key)
			closeMenus(true)
		end)
	end
	entry(1, Color3.fromRGB(70, 210, 255), "SPEED STAND", "Speed")
	entry(2, Color3.fromRGB(255, 170, 60), "CAPACITY STAND", "Capacity")
	entry(3, Color3.fromRGB(255, 110, 190), "GUS'S GADGETS", "Gus")
	entry(4, Color3.fromRGB(255, 170, 225), "PET STAND (EGGS)", "Pets")
	entry(5, Color3.fromRGB(150, 110, 255), "LEADERBOARDS", "Boards")
end

----------------------------------------------------------------
-- ADMIN MENU (press U) - the server only accepts these from the developer
----------------------------------------------------------------
local updateAdmin
do
	local ACOL = Color3.fromRGB(255, 100, 100)
	local aFrame, aBody = modal("admin", 720, 580, "ADMIN  -  DEV ONLY", ACOL)
	local scroll = scroller(aBody, 6)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local function section(text)
		label({ Size = UDim2.new(1, -6, 0, 26), TextSize = 19, TextColor3 = Color3.fromRGB(255, 225, 130), TextXAlignment = Enum.TextXAlignment.Left, Text = text, LayoutOrder = nextOrder() }, scroll)
		local g = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder() }, scroll)
		make("UIGridLayout", { CellSize = UDim2.fromOffset(150, 40), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, g)
		return g
	end
	local function abtn(parent, text, color, fn)
		local b = makeButton({ Text = text, TextSize = 15 }, parent, color)
		b.Activated:Connect(fn)
		return b
	end
	local function cmd(name, a, b)
		return function()
			Action:FireServer("Admin", name, a, b)
		end
	end
	local function box(parent, placeholder, default)
		local t = make("TextBox", {
			Size = UDim2.fromOffset(150, 40),
			BackgroundColor3 = Color3.fromRGB(30, 32, 70),
			Font = FONT,
			TextSize = 16,
			TextColor3 = WHITE,
			PlaceholderText = placeholder,
			PlaceholderColor3 = Color3.fromRGB(150, 155, 200),
			Text = default or "",
			ClearTextOnFocus = false,
		}, parent)
		corner(t, 10)
		stroke(t, 2, Color3.fromRGB(140, 150, 230))
		return t
	end
	local BLUE2 = Color3.fromRGB(80, 130, 255)

	local g = section("MONEY")
	for _, v in ipairs({ { "+ $1M", 1e6 }, { "+ $1B", 1e9 }, { "+ $1T", 1e12 }, { "+ $1Qa", 1e15 }, { "+ $1Qi", 1e18 } }) do
		abtn(g, v[1], GREEN, cmd("Cash", v[2]))
	end
	local cashBox = box(g, "amount e.g. 5e9", "1e9")
	abtn(g, "GIVE AMOUNT", GREEN, function()
		local n = tonumber(cashBox.Text)
		if n then
			Action:FireServer("Admin", "Cash", n)
		end
	end)

	g = section("TESTING")
	abtn(g, "Unlock Trading", BLUE2, cmd("UnlockTrade"))
	abtn(g, "Rebirth +1 (free)", BLUE2, cmd("Rebirth"))
	abtn(g, "Speed +10 levels", BLUE2, cmd("SpeedLevels", 10))
	abtn(g, "Max Capacity", BLUE2, cmd("MaxCapacity"))
	abtn(g, "Unlock all base", BLUE2, cmd("UnlockBase"))
	abtn(g, "All potions 5 min", BLUE2, cmd("Boosts"))
	abtn(g, "Give Wacker", BLUE2, cmd("Wacker"))
	abtn(g, "Full traps", BLUE2, cmd("Traps"))

	g = section("FLYING + GOD MODE")
	local flyBtn = abtn(g, "FLY: OFF", Color3.fromRGB(190, 110, 255), function()
		if setFly then
			setFly(not flyOn)
		end
	end)
	abtn(g, "Fly speed +20", Color3.fromRGB(190, 110, 255), function()
		flySpeed = math.min(400, flySpeed + 20)
	end)
	abtn(g, "Fly speed -20", Color3.fromRGB(190, 110, 255), function()
		flySpeed = math.max(20, flySpeed - 20)
	end)
	abtn(g, "God Mode (toggle)", Color3.fromRGB(190, 110, 255), cmd("God"))

	g = section("FLOODS - tap one to send it right now")
	for _, wt in ipairs(Config.WaveTypes) do -- one button per wave type, in its own colour, so each can be tested on its own
		local b = abtn(g, (wt.Emoji or "") .. " " .. wt.Name, wt.Color:Lerp(BLACK, 0.15), cmd("Wave", wt.Name))
		b.TextScaled = true
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
	end
	abtn(g, "🎲 RANDOM WAVE", RED, cmd("Wave"))
	abtn(g, "Pause / resume floods", Color3.fromRGB(80, 170, 255), cmd("PauseWaves"))
	abtn(g, "Clear all floods", Color3.fromRGB(80, 170, 255), cmd("ClearWaves"))

	g = section("TELEPORT")
	local zoneBox = box(g, "zone 1-" .. Config.ZoneCount, "1")
	abtn(g, "GO TO ZONE", Color3.fromRGB(255, 170, 60), function()
		local n = tonumber(zoneBox.Text)
		if n then
			Action:FireServer("Admin", "Zone", n)
		end
	end)
	abtn(g, "Go to my base", Color3.fromRGB(255, 170, 60), cmd("Home"))
	abtn(g, "Respawn pickups", Color3.fromRGB(255, 170, 60), cmd("ClearPickups"))

	g = section("GIVE ITEMS")
	local gooberBox = box(g, "Goober name", "King Goldie")
	local mutBox = box(g, "Normal/Golden/Neon/Glitched", "Normal")
	abtn(g, "GIVE GOOBER", GREEN, function()
		Action:FireServer("Admin", "Goober", gooberBox.Text, mutBox.Text)
	end)
	local petBox = box(g, "Pet name", "Phoenix")
	abtn(g, "GIVE PET", GREEN, function()
		Action:FireServer("Admin", "Pet", petBox.Text)
	end)

	g = section("TEMPORARY ADMINS  (only the host can use these)")
	local plist = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder() }, scroll)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, plist)
	local plistSig = nil
	local function rebuildPlayers()
		local amHost = player:GetAttribute("AdminHost") == true
		local others, sig = {}, tostring(amHost)
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				table.insert(others, p)
				sig = sig .. "|" .. p.UserId .. (p:GetAttribute("IsAdmin") and "A" or "-") .. (p:GetAttribute("AdminHost") and "H" or "")
			end
		end
		if sig == plistSig then
			return
		end
		plistSig = sig
		for _, c in ipairs(plist:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local function note(text)
			label({ Size = UDim2.new(1, 0, 0, 30), TextSize = 15, TextColor3 = Color3.fromRGB(215, 220, 255), TextXAlignment = Enum.TextXAlignment.Left, Text = text }, plist)
		end
		if not amHost then
			note("Only the host can give or remove admin.")
			return
		end
		if #others == 0 then
			note("No other players in this server right now.")
			return
		end
		for i, p in ipairs(others) do
			local row = make("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Color3.fromRGB(38, 40, 88), LayoutOrder = i }, plist)
			make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, row)
			local isAdm, isHst = p:GetAttribute("IsAdmin") == true, p:GetAttribute("AdminHost") == true
			label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(190, 46), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = isAdm and Color3.fromRGB(255, 225, 120) or WHITE, Text = p.DisplayName .. (isHst and "  (HOST)" or (isAdm and "  (ADMIN)" or "")) }, row)
			if not isHst then
				local x = 206
				for _, opt in ipairs({ { "10 MIN", 10 }, { "1 HOUR", 60 }, { "SERVER", 0 } }) do
					local gb = makeButton({ Position = UDim2.fromOffset(x, 6), Size = UDim2.fromOffset(72, 34), TextSize = 13, Text = opt[1] }, row, GREEN)
					gb.Activated:Connect(function()
						Action:FireServer("Admin", "GrantAdmin", p.UserId, opt[2])
					end)
					x += 78
				end
				local rb = makeButton({ Position = UDim2.fromOffset(x, 6), Size = UDim2.fromOffset(78, 34), TextSize = 13, Text = "REMOVE" }, row, RED)
				rb.Activated:Connect(function()
					Action:FireServer("Admin", "RevokeAdmin", p.UserId)
				end)
			end
		end
	end
	label({ Size = UDim2.new(1, -6, 0, 24), TextSize = 13, TextColor3 = Color3.fromRGB(190, 195, 235), TextXAlignment = Enum.TextXAlignment.Left, Text = "10 MIN / 1 HOUR run out by themselves. SERVER lasts until they leave. Temporary admins cannot give admin to anyone.", LayoutOrder = nextOrder() }, scroll)

	g = section("DANGER ZONE")
	local wipeBtn = abtn(g, "WIPE MY DATA", RED, function() end)
	local armedUntil = 0
	wipeBtn.Activated:Connect(function()
		if os.clock() < armedUntil then
			armedUntil = 0
			wipeBtn.Text = "WIPE MY DATA"
			Action:FireServer("Admin", "Wipe")
		else
			armedUntil = os.clock() + 4
			wipeBtn.Text = "SURE? PRESS AGAIN"
			task.delay(4, function()
				if os.clock() >= armedUntil and wipeBtn.Parent then
					wipeBtn.Text = "WIPE MY DATA"
				end
			end)
		end
	end)
	label({ Size = UDim2.fromOffset(300, 40), TextSize = 13, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 170, 170), TextXAlignment = Enum.TextXAlignment.Left, Text = "Erases your cash, goobers, pets, upgrades, rebirths and codes (and your leaderboard entries). Starts you as a new player." }, g)

	g = section("DAILY / TUTORIAL")
	abtn(g, "Next day (keep streak)", Color3.fromRGB(255, 205, 80), cmd("NextDay"))
	abtn(g, "Reset daily streak", Color3.fromRGB(255, 205, 80), cmd("ResetDaily"))
	abtn(g, "Replay tutorial + wheel", Color3.fromRGB(255, 205, 80), function()
		Action:FireServer("Admin", "ResetTutorial")
		if tutorialCutscene then
			task.delay(0.4, tutorialCutscene)
		end
	end)

	g = section("VIP PERKS (TEST)")
	label({ Size = UDim2.fromOffset(300, 58), TextSize = 13, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 230, 150), TextXAlignment = Enum.TextXAlignment.Left, Text = ("VIP gives: +%d run speed, +%d%% income, the gold safe-zone gates open for you, a gold VIP tag over your head. The button turns ALL of them on/off for you."):format(Config.VIP.SpeedBonus, math.floor((Config.VIP.IncomeMult - 1) * 100 + 0.5)) }, g)
	abtn(g, "Toggle ALL VIP perks", Color3.fromRGB(255, 205, 80), cmd("VIP"))
	abtn(g, "Bosses ON / OFF", Color3.fromRGB(255, 110, 110), cmd("Bosses"))

	function updateAdmin()
		if not aFrame.Visible then
			return
		end
		rebuildPlayers()
		flyBtn.Text = flyOn and ("FLY: ON  (" .. flySpeed .. ")") or "FLY: OFF"
	end
end


do
	----------------------------------------------------------------
	-- SETTINGS WINDOW (music / sound toggles)
	----------------------------------------------------------------
	local _, settingsBody = modal("settings", 460, 410, "SETTINGS", Color3.fromRGB(150, 190, 255))
	local musicBtn = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0.8, 0, 0, 56), Text = "MUSIC: ON", TextSize = 26 }, settingsBody, BLUE)
	local sfxBtn = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.new(0.8, 0, 0, 56), Text = "SOUND FX: ON", TextSize = 26 }, settingsBody, BLUE)
	local perfBtn = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 154), Size = UDim2.new(0.8, 0, 0, 56), Text = "LOW PERFORMANCE MODE: OFF", TextSize = 20 }, settingsBody, GREY)
	label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 226),
		Size = UDim2.new(0.9, 0, 0, 100),
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(215, 220, 255),
		Text = "Low Performance Mode turns off decorations' sparkles, ripples and tree sway, and drops shadows - good for older phones. The music changes mood every minute or so. On phones: tap the glowing prompt buttons near shops and Goobers to use them.",
	}, settingsBody)
	musicBtn.Activated:Connect(function()
		setMusic(not settings.music)
		musicBtn.Text = settings.music and "MUSIC: ON" or "MUSIC: OFF"
		musicBtn.BackgroundColor3 = settings.music and BLUE or GREY
	end)
	sfxBtn.Activated:Connect(function()
		setSfx(not settings.sfx)
		sfxBtn.Text = settings.sfx and "SOUND FX: ON" or "SOUND FX: OFF"
		sfxBtn.BackgroundColor3 = settings.sfx and BLUE or GREY
	end)
	perfBtn.Activated:Connect(function()
		setLowPerf(not settings.lowPerf)
		perfBtn.Text = "LOW PERFORMANCE MODE: " .. (settings.lowPerf and "ON" or "OFF")
		perfBtn.BackgroundColor3 = settings.lowPerf and Color3.fromRGB(255, 170, 70) or GREY
	end)

end

----------------------------------------------------------------
-- TRAILS: a glowing trail behind you + a permanent speed boost while it's equipped. Each costs ~100x the last.
----------------------------------------------------------------
do
	local TCOL = Color3.fromRGB(90, 200, 255)
	local _, tBody = modal("trails", 640, 620, "✨ TRAILS", TCOL)
	label({ Size = UDim2.new(1, 0, 0, 22), TextScaled = true, TextColor3 = Color3.fromRGB(220, 235, 255), Text = "Trails make you FASTER while equipped - stack with Speed, pets & rebirths to outrun bosses!" }, tBody)
	local holder = make("Frame", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28), BackgroundTransparency = 1 }, tBody)
	local list = scroller(holder, 8)
	local rows = {}
	for i, def in ipairs(Config.Trails) do
		local mid = def.Colors[math.ceil(#def.Colors / 2)]
		local r = itemRow(list, mid, "✨", 92, i)
		r.Title.Text = ("%s  +%d%% speed"):format(def.Label, math.floor(def.Speed * 100 + 0.5))
		-- a preview of the trail's colours
		local stripe = make("Frame", { Position = UDim2.fromOffset(86, 70), Size = UDim2.new(1, -214, 0, 12), BackgroundColor3 = WHITE }, r.Row)
		corner(stripe, 6)
		stroke(stripe, 1.5, WHITE)
		local keys = {}
		for k, c in ipairs(def.Colors) do
			table.insert(keys, ColorSequenceKeypoint.new(#def.Colors == 1 and 0 or (k - 1) / (#def.Colors - 1), c))
		end
		if #keys == 1 then
			table.insert(keys, ColorSequenceKeypoint.new(1, def.Colors[1]))
		end
		make("UIGradient", { Color = ColorSequence.new(keys) }, stripe)
		r.Btn.Activated:Connect(function()
			local owned = (","  .. (player:GetAttribute("TrailsOwned") or "") .. ","):find("," .. def.Id .. ",", 1, true)
			Action:FireServer(owned and "EquipTrail" or "BuyTrail", def.Id)
		end)
		rows[def.Id] = r
	end
	local function updateTrails()
		local owned = "," .. (player:GetAttribute("TrailsOwned") or "") .. ","
		local on = player:GetAttribute("TrailOn") or ""
		local cash = player:GetAttribute("Cash") or 0
		for _, def in ipairs(Config.Trails) do
			local r = rows[def.Id]
			if on == def.Id then
				r.Desc.Text = "EQUIPPED - tap to take it off"
				setBtn(r.Btn, "ON", Color3.fromRGB(90, 200, 255))
			elseif owned:find("," .. def.Id .. ",", 1, true) then
				r.Desc.Text = "Owned"
				setBtn(r.Btn, "EQUIP", GREEN)
			else
				r.Desc.Text = "Costs $" .. F(def.Price)
				setBtn(r.Btn, "$" .. F(def.Price), cash >= def.Price and GREEN or GREY)
			end
		end
	end
	for _, attr in ipairs({ "TrailsOwned", "TrailOn", "Cash" }) do
		player:GetAttributeChangedSignal(attr):Connect(updateTrails)
	end
	updateTrails()
end

----------------------------------------------------------------
-- SIDE BUTTONS (2-column grid: fits phones) + THE PULSING SALE STAR
----------------------------------------------------------------
local left = make("Frame", { Position = UDim2.fromOffset(12, 236), Size = UDim2.fromOffset(292, 336), BackgroundTransparency = 1 }, gui)
make("UIGridLayout", { CellSize = isTouch and UDim2.fromOffset(134, 42) or UDim2.fromOffset(142, 50), CellPadding = isTouch and UDim2.fromOffset(6, 6) or UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, left)
local function sideButton(order, text, color, icon, onClick)
	local b, l = bubbleButton({ LayoutOrder = order }, left, color, icon, text)
	b.Activated:Connect(onClick)
	b.Rotation = -1.5
	task.delay(order * 0.23 % 1.4, function()
		TweenService:Create(b, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 1.5 }):Play()
	end)
	return b, l
end
-- a small red dot on a button ("something is waiting for you")
local function badge(btn)
	local d = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = RED, Visible = false, ZIndex = 8 }, btn)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, d)
	make("UIStroke", { Thickness = 2.5, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, d)
	local pulse = make("UIScale", {}, d)
	TweenService:Create(pulse, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.25 }):Play()
	return d
end
sideButton(1, "UPGRADES", Color3.fromRGB(60, 190, 255), "shop", function()
	toggleMenu("shop")
end)
sideButton(2, "PETS", Color3.fromRGB(255, 130, 200), "pets", function()
	toggleMenu("pets")
end)
local indexBtn = sideButton(3, "INDEX", Color3.fromRGB(255, 190, 70), "index", function()
	toggleMenu("index")
	local gCsv, pCsv = player:GetAttribute("IndexG") or "", player:GetAttribute("IndexP") or ""
	local n = 0
	for _ in gCsv:gmatch("[^,]+") do n += 1 end
	for _ in pCsv:gmatch("[^,]+") do n += 1 end
	indexSeenTotal = n
end)
indexBadge = badge(indexBtn)
indexSeenTotal = 0
sideButton(4, "MY BASE", GREEN, "base", function()
	Action:FireServer("Teleport")
end)
sideButton(13, "REBIRTH", Color3.fromRGB(255, 90, 90), "rebirth", function()
	openRebirth()
end)
sideButton(5, "MARKET", Color3.fromRGB(255, 150, 90), "market", function()
	toggleMenu("market")
end)
local tradeBtn, tradeLabel = sideButton(6, "TRADE", Color3.fromRGB(80, 210, 160), "trade", function()
	if player:GetAttribute("TradeOK") then
		toggleMenu("trade")
	else
		local remaining = Config.TradeUnlockSeconds - (player:GetAttribute("PlayTime") or 0)
		toast("Trading unlocks in " .. fmtTime(remaining), GOLD)
	end
end)
sideButton(7, "CODES", GOLD, "codes", function()
	toggleMenu("codes")
end)
local dailyBtn = sideButton(8, "DAILY", Color3.fromRGB(255, 205, 80), "daily", function()
	toggleMenu("daily")
end)
local dailyBadge = badge(dailyBtn)
sideButton(10, "SETTINGS", Color3.fromRGB(130, 150, 230), "settings", function()
	toggleMenu("settings")
end)
local adminBtn = sideButton(11, "ADMIN [U]", Color3.fromRGB(255, 100, 100), "admin", function()
	toggleMenu("admin")
end)
sideButton(12, "DONATE", Color3.fromRGB(255, 105, 160), "donate", function()
	toggleMenu("donate")
end)
sideButton(14, "TRAILS", Color3.fromRGB(90, 200, 255), "trails", function()
	toggleMenu("trails")
end)
adminBtn.Visible = false -- only the developer sees this

----------------------------------------------------------------
-- (The big bottom bar is gone.) A small zone tag at the bottom, the flood timer as a slim pill at the TOP, and a DROP button
-- that only shows while you are carrying a Goober (key Q).
----------------------------------------------------------------
local updateDock, updateZoneTag, updateTrack
do
	-- zone tag. Hidden in the plaza, so a new player sees almost no text: it appears when you enter the first zone.
	local zoneTag = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 210, 1, -14), Size = UDim2.fromOffset(300, 32), BackgroundColor3 = Color3.fromRGB(94, 84, 208), Visible = false, ZIndex = 2 }, gui)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, zoneTag)
	local zoneStroke = make("UIStroke", { Thickness = 3, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, zoneTag)
	local zoneText = label({ Size = UDim2.fromScale(1, 1), TextSize = 17, Text = "" }, zoneTag)
	local zoneScale = make("UIScale", {}, zoneTag)
	local shownKey = nil
	-- SKY TRANSITION: every zone has its own colours (Config.SkyFor). Running into a new zone fades the lighting over Config.SkyFade
	-- seconds and washes a soft tint of the zone's colour across the screen.
	local Lighting = game:GetService("Lighting")
	local wash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Active = false, ZIndex = 3 }, gui)
	local skyZone = nil
	local function applySky(z)
		if z == skyZone then
			return
		end
		local first = skyZone == nil
		skyZone = z
		local s = Config.SkyFor(z)
		local info = TweenInfo.new(first and 0.05 or Config.SkyFade, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local function to(obj, props)
			if obj then
				TweenService:Create(obj, info, props):Play()
			end
		end
		to(Lighting, { ClockTime = s.Clock, Brightness = s.Brightness, Ambient = s.Ambient, OutdoorAmbient = s.Outdoor, ExposureCompensation = s.Exposure })
		to(Lighting:FindFirstChildOfClass("Atmosphere"), { Color = s.Atmo, Decay = s.Decay, Haze = s.Haze, Density = s.Density })
		to(Lighting:FindFirstChildOfClass("ColorCorrectionEffect"), { TintColor = s.Tint, Saturation = s.Saturation })
		to(Lighting:FindFirstChildOfClass("BloomEffect"), { Intensity = s.Bloom })
		if not first then
			wash.BackgroundColor3 = z >= 1 and Config.Zones[z].Accent or WHITE
			wash.BackgroundTransparency = 0.72
			tween(wash, 1.6, { BackgroundTransparency = 1 })
		end
	end

	function updateZoneTag(zoneIdx, safe)
		applySky(zoneIdx)
		local key = tostring(zoneIdx) .. (safe and "S" or "")
		if key == shownKey then
			return
		end
		shownKey = key
		if zoneIdx < 1 then
			zoneTag.Visible = false
			return
		end
		local z = Config.Zones[zoneIdx]
		zoneTag.Visible = true
		zoneStroke.Color = safe and Color3.fromRGB(80, 255, 140) or z.Accent
		zoneText.TextColor3 = safe and Color3.fromRGB(150, 255, 190) or WHITE
		zoneText.Text = safe and "SAFE - the flood can't reach you" or ("ZONE %d / %d   %s"):format(zoneIdx, Config.ZoneCount, z.Name)
		zoneScale.Scale = 0.7
		tween(zoneScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	-- THE TRACK BAR (top middle): every zone is a coloured piece; YOUR avatar's face slides along it, so you always know where you are and
	-- where to go. It has a START flag but NO end on purpose (more zones can be added), it just fades away to the right.
	local Plrs = game:GetService("Players")
	local trackW = isTouch and 330 or 520
	local trackBar = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(trackW + 104, 50), BackgroundColor3 = Color3.fromRGB(84, 80, 190), ClipsDescendants = true, ZIndex = 2 }, gui)
	corner(trackBar, 25) -- ClipsDescendants respects this rounding, so the square corners of the zone segments never poke past the pill's rounded ends
	stroke(trackBar, 3, WHITE)
	make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 180, 245)), Rotation = 90 }, trackBar)
	label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(62, 50), TextSize = 15, TextColor3 = Color3.fromRGB(150, 255, 170), Text = "START" }, trackBar)
	local strip = make("Frame", { Position = UDim2.fromOffset(72, 14), Size = UDim2.fromOffset(trackW, 22), BackgroundTransparency = 1 }, trackBar)
	local trackLen = Config.RunwayEnd - Config.RunwayStart
	local trackSegs = {}
	for z = 1, Config.ZoneCount do
		local zn = Config.Zones[z]
		local seg = make("Frame", { Position = UDim2.fromScale((Config.ZoneStarts[z] - Config.RunwayStart) / trackLen, 0), Size = UDim2.fromScale(zn.Length / trackLen, 1), BackgroundColor3 = Config.Zones[z].Accent }, strip)
		local segStroke = make("UIStroke", { Thickness = 0.8, Color = BLACK, Transparency = 0.8 }, seg) -- a barely-there seam, not a hard border
		make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 190, 190)), Rotation = 90 }, seg)
		if z == Config.ZoneCount then -- the last piece fades out: the road goes on
			make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.85) }) }, seg)
		end
		label({ Size = UDim2.fromScale(1, 1), TextSize = 12, Text = tostring(z) }, seg)
		trackSegs[z] = segStroke
	end
	label({ Position = UDim2.new(1, -34, 0, 0), Size = UDim2.fromOffset(30, 50), TextSize = 18, TextColor3 = Color3.fromRGB(255, 255, 255), Text = ">>" }, trackBar)
	local face = make("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = WHITE, Image = "", ZIndex = 6 }, strip)
	corner(face, 20)
	stroke(face, 3.5, GOLD)
	task.spawn(function()
		local ok, img = pcall(function()
			return Plrs:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and img then
			face.Image = img
		end
	end)
	local trackFrac, trackZone = 0, -1
	function updateTrack(x)
		local target = math.clamp((x - Config.RunwayStart) / trackLen, 0, 1)
		trackFrac += (target - trackFrac) * 0.3
		face.Position = UDim2.new(trackFrac, 0, 0.5, 0)
		local z = Config.ZoneAtX(x)
		if z ~= trackZone then
			trackZone = z
			for i, s in pairs(trackSegs) do
				s.Color = (i == z) and WHITE or BLACK
				s.Thickness = (i == z) and 3.5 or 0.8
				s.Transparency = (i == z) and 0 or 0.8
			end
		end
		return trackFrac
	end

	-- DROP: puts down the Goober you picked up last. Bottom-left of the trap button on PC, above it on phones.
	local dropBtn = makeButton({
		AnchorPoint = isTouch and Vector2.new(1, 1) or Vector2.new(0.5, 1),
		Position = isTouch and UDim2.new(1, -30, 1, -290) or UDim2.new(0.5, 0, 1, -78),
		Size = UDim2.fromOffset(isTouch and 150 or 160, 42),
		Text = isTouch and "DROP" or "DROP  [Q]",
		TextSize = 18,
		Visible = false,
	}, gui, Color3.fromRGB(255, 160, 70))
	dropBtn.Activated:Connect(function()
		Action:FireServer("Drop")
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Q and (player:GetAttribute("Carrying") or 0) > 0 then
			Action:FireServer("Drop")
		end
	end)

	function updateDock() -- (same name as before: the HUD loop calls it a few times a second)
		dropBtn.Visible = (player:GetAttribute("Carrying") or 0) > 0 and not activeMenu
	end

	-- CARRY POSE: while you carry a Goober, both arms lift up in front of you like you are holding an egg.
	-- (Motor6D.Transform is set after the walking animation each frame; R15 is done properly, R6 is best-effort.)
	local pose = 0
	RunService.RenderStepped:Connect(function(dt)
		local carrying = (player:GetAttribute("Carrying") or 0) > 0
		pose += ((carrying and 1 or 0) - pose) * math.min(1, dt * 9)
		if pose < 0.02 then
			return
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or hum.PlatformStand then
			return
		end
		local up = math.rad(128) -- how high the arms come up
		for _, side in ipairs({ 1, -1 }) do -- 1 = right, -1 = left
			local upperName = side == 1 and "RightUpperArm" or "LeftUpperArm"
			local lowerName = side == 1 and "RightLowerArm" or "LeftLowerArm"
			local upper = char:FindFirstChild(upperName)
			local shoulder = upper and upper:FindFirstChild(side == 1 and "RightShoulder" or "LeftShoulder")
			if shoulder and shoulder:IsA("Motor6D") then -- R15
				local target = CFrame.Angles(0, 0, -side * math.rad(14)) * CFrame.Angles(up, 0, 0)
				shoulder.Transform = shoulder.Transform:Lerp(target, pose)
				local lower = char:FindFirstChild(lowerName)
				local elbow = lower and lower:FindFirstChild(side == 1 and "RightElbow" or "LeftElbow")
				if elbow and elbow:IsA("Motor6D") then
					elbow.Transform = elbow.Transform:Lerp(CFrame.Angles(math.rad(38), 0, 0), pose)
				end
			else -- R6
				local torso = char:FindFirstChild("Torso")
				local sh = torso and torso:FindFirstChild(side == 1 and "Right Shoulder" or "Left Shoulder")
				if sh and sh:IsA("Motor6D") then
					sh.Transform = sh.Transform:Lerp(CFrame.Angles(0, 0, side * math.rad(125)), pose)
				end
			end
		end
	end)
end


-- the SHOP button: a round candy badge with a basket full of goodies (opens the Robux shop)
local starHolder = make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, -60), Size = UDim2.fromOffset(120, 132), BackgroundTransparency = 1 }, gui)
do
	local BROWN, BROWN_D, BROWN_L = Color3.fromRGB(205, 135, 65), Color3.fromRGB(120, 70, 30), Color3.fromRGB(240, 180, 100)
	local badgeF = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(104, 104), BackgroundColor3 = Color3.fromRGB(90, 220, 120) }, starHolder)
	corner(badgeF, 52)
	make("UIStroke", { Thickness = 4, Color = WHITE }, badgeF)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 170, 150)), Rotation = 90 }, badgeF)
	local function bit(x, y, w, h, color, z, round, rot)
		local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = color, ZIndex = z, Rotation = rot or 0 }, badgeF)
		make("UICorner", { CornerRadius = round or UDim.new(0, 6) }, f)
		return f
	end
	-- handle (a hollow ring whose bottom half hides behind the basket)
	local handle = bit(52, 46, 54, 54, BROWN, 2, UDim.new(0.5, 0))
	handle.BackgroundTransparency = 1
	make("UIStroke", { Thickness = 6, Color = BROWN_D }, handle)
	-- goodies peeking out: a gold coin, a pink gem and a blue sweet
	stroke(bit(38, 50, 22, 22, Color3.fromRGB(255, 210, 60), 3, UDim.new(0.5, 0)), 2, BROWN_D)
	stroke(bit(56, 46, 18, 18, Color3.fromRGB(255, 110, 190), 3, UDim.new(0, 4), 45), 2, BROWN_D)
	stroke(bit(69, 52, 18, 18, Color3.fromRGB(110, 200, 255), 3, UDim.new(0.5, 0)), 2, BROWN_D)
	-- woven basket body + rim
	local body = bit(52, 72, 66, 34, BROWN, 4, UDim.new(0, 10))
	stroke(body, 2.5, BROWN_D)
	for i = 1, 2 do
		make("Frame", { Position = UDim2.new(0, 4, 0, 8 + (i - 1) * 11), Size = UDim2.new(1, -8, 0, 3), BackgroundColor3 = BROWN_D, BackgroundTransparency = 0.35, ZIndex = 5 }, body)
	end
	for i = 1, 4 do
		make("Frame", { Position = UDim2.new(i / 5, -1, 0, 3), Size = UDim2.new(0, 2, 1, -6), BackgroundColor3 = BROWN_D, BackgroundTransparency = 0.5, ZIndex = 5 }, body)
	end
	stroke(bit(52, 56, 76, 11, BROWN_L, 5, UDim.new(0.5, 0)), 2.5, BROWN_D)
	-- a pulsing SALE tag
	local tag = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 12), Size = UDim2.fromOffset(52, 24), BackgroundColor3 = Color3.fromRGB(255, 70, 90), Rotation = 14, ZIndex = 6 }, starHolder)
	corner(tag, 12)
	make("UIStroke", { Thickness = 2.5, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tag)
	label({ Size = UDim2.fromScale(1, 1), TextSize = 15, Text = "SALE", ZIndex = 7 }, tag)
	local tagScale = make("UIScale", {}, tag)
	TweenService:Create(tagScale, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.15 }):Play()
	local shopL = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.fromOffset(120, 28), TextSize = 26, TextColor3 = Color3.fromRGB(255, 240, 150), Text = "SHOP", ZIndex = 3 }, starHolder)
	shopL.Font = Enum.Font.LuckiestGuy
	local sc = make("UIScale", {}, starHolder)
	TweenService:Create(sc, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.07 }):Play()
	badgeF.Rotation = -5
	TweenService:Create(badgeF, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 5 }):Play()
	local btn = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 8 }, starHolder)
	btn.Activated:Connect(function()
		toggleMenu("deals")
	end)
end

-- SPIN icon: sits directly below the Robux star, same center column
-- spinCountL, spinBanner: these two are updated from the HUD loop far below; left as implicit globals (no "local") so they don't cost a top-level register
do -- scoped: everything else here is only needed to build/wire the Spin icon once
	local spinHolder = make("Frame", { Name = "SpinHolder", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 90), Size = UDim2.fromOffset(96, 138), BackgroundTransparency = 1 }, gui)
	-- a real little prize wheel: gold rim with light bulbs, 5 solid pie wedges (the same colours as the big wheel) that slowly turn,
	-- white dividers, a gold hub showing your spin count, and a red pointer on top
	local spinWheelIcon = make("Frame", { Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(96, 96), BackgroundColor3 = Color3.fromRGB(255, 200, 60) }, spinHolder)
	corner(spinWheelIcon, 48)
	stroke(spinWheelIcon, 3, Color3.fromRGB(120, 60, 10))
	local face = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(82, 82), BackgroundColor3 = WHITE }, spinWheelIcon)
	corner(face, 41)
	local SPIN_SEG_COLORS = { Color3.fromRGB(220, 220, 230), Color3.fromRGB(90, 170, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(255, 170, 60), Color3.fromRGB(230, 60, 70) }
	-- Each wedge is filled by thin "rays". A GUI frame always rotates about its OWN centre, so every ray is a full-diameter
	-- bar centred on the wheel with its bottom half faded out by a gradient: only the half pointing outward shows.
	local HALF = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) })
	local function ray(width, angle, color, z)
		local r = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, 82), Rotation = angle, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z or 1 }, face)
		make("UIGradient", { Rotation = 90, Transparency = HALF }, r)
	end
	local RAYS = 14 -- overlapping rays fill each wedge solid
	for seg = 1, 5 do
		for k = 0, RAYS - 1 do
			ray(9, (seg - 1) * 72 + (k + 0.5) * (72 / RAYS), SPIN_SEG_COLORS[seg])
		end
	end
	for seg = 1, 5 do
		ray(3, (seg - 1) * 72, WHITE, 2) -- white dividers between the wedges
	end
	TweenService:Create(face, TweenInfo.new(9, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
	for i = 1, 10 do -- light bulbs around the rim, half of them twinkling
		local a = math.rad(i * 36)
		local bulb = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * 44.5, 0.5, math.sin(a) * 44.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(255, 255, 220), ZIndex = 3 }, spinWheelIcon)
		corner(bulb, 3)
		if i % 2 == 0 then
			TweenService:Create(bulb, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.8 }):Play()
		end
	end
	local pointer = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(28, 26), TextScaled = true, TextColor3 = Color3.fromRGB(255, 60, 80), Text = "▼", ZIndex = 5 }, spinWheelIcon)
	pointer:FindFirstChildOfClass("UIStroke").Color = WHITE
	local spinHub = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.36, 0.36), BackgroundColor3 = Color3.fromRGB(255, 200, 60), ZIndex = 4 }, spinWheelIcon)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, spinHub)
	stroke(spinHub, 2.5, BLACK)
	spinCountL = label({ Size = UDim2.fromScale(1, 1), TextSize = 22, TextColor3 = Color3.fromRGB(120, 70, 0), Text = "0" }, spinHub)
	spinCountL:FindFirstChildOfClass("UIStroke").Thickness = 0
	spinTimerL = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(110, 26), TextSize = 12, TextWrapped = true, TextColor3 = Color3.fromRGB(220, 220, 255), Text = "" }, spinHolder)
	local spinScale = make("UIScale", {}, spinWheelIcon)
	TweenService:Create(spinScale, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 }):Play()
	local spinBtn = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, spinHolder)
	spinBtn.Activated:Connect(function()
		if (player:GetAttribute("Spins") or 0) > 0 then
			startWheel(true)
		else
			local lastRegen = player:GetAttribute("LastSpinRegen") or os.time()
			local left = math.max(0, Config.SpinRegenSeconds - (os.time() - lastRegen))
			toast(("No free spins yet - next one in %d:%02d!"):format(left // 60, left % 60), GOLD)
		end
	end)

	-- small "you have a free spin" banner near the top (stays up while you have at least one)
	spinBanner = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 144),
		Size = UDim2.fromOffset(280, 20),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 225, 120),
		Text = "",
		Visible = false,
	}, gui)
end

-- trap button: bottom-center on PC, above the jump button on phones
local trapBtn = makeButton({
	AnchorPoint = isTouch and Vector2.new(1, 1) or Vector2.new(0.5, 1),
	Position = isTouch and UDim2.new(1, -30, 1, -220) or UDim2.new(0.5, 0, 1, -128),
	Size = UDim2.fromOffset(isTouch and 150 or 200, 50),
	Text = "PLACE TRAP",
	TextSize = 20,
	Visible = false,
}, gui, RED)
trapBtn.Activated:Connect(function()
	Action:FireServer("PlaceTrap")
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.T and (player:GetAttribute("Traps") or 0) > 0 then
		Action:FireServer("PlaceTrap")
	end
end)
-- LEFT-SIDE HIDE ARROW: a tab just right of the button grid slides the grid (and COLLECT ALL) off-screen; tap again to bring it back.
do
	local items = { left, collectBtn }
	local home = {}
	for i, it in ipairs(items) do
		home[i] = it.Position
	end
	local tucked = false
	local tabHome = UDim2.fromOffset(310, 236)
	local tab = makeButton({ Position = tabHome, Size = UDim2.fromOffset(isTouch and 40 or 34, 58), Text = "<", TextSize = 28, ZIndex = 6 }, gui, Color3.fromRGB(160, 110, 255))
	tab.Activated:Connect(function()
		tucked = not tucked
		tab.Text = tucked and ">" or "<"
		for i, it in ipairs(items) do
			tween(it, 0.35, { Position = tucked and (home[i] - UDim2.fromOffset(340, 0)) or home[i] }, Enum.EasingStyle.Back, tucked and Enum.EasingDirection.In or Enum.EasingDirection.Out)
		end
		tween(tab, 0.35, { Position = tucked and UDim2.fromOffset(0, 236) or tabHome }, Enum.EasingStyle.Back)
	end)
end

-- RIGHT-SIDE HIDE ARROW: a little tab on the right edge tucks the Robux star + Spin icons off-screen (great on phones),
-- tap it again to slide them back.
do
	local items = { starHolder, gui:FindFirstChild("SpinHolder") }
	local home = {}
	for i, it in ipairs(items) do
		home[i] = it.Position
	end
	local tucked = false
	local tab = makeButton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, -150), Size = UDim2.fromOffset(isTouch and 40 or 34, 58), Text = ">", TextSize = 28, ZIndex = 6 }, gui, Color3.fromRGB(160, 110, 255))
	tab.Activated:Connect(function()
		tucked = not tucked
		tab.Text = tucked and "<" or ">"
		for i, it in ipairs(items) do
			tween(it, 0.35, { Position = tucked and (home[i] + UDim2.fromOffset(170, 0)) or home[i] }, Enum.EasingStyle.Back, tucked and Enum.EasingDirection.In or Enum.EasingDirection.Out)
		end
	end)
end

----------------------------------------------------------------
-- CONFETTI + REVEAL ("YOU GOT!" popup with a bouncing Goober)
----------------------------------------------------------------
local function confetti(parent, count)
	for _ = 1, count do
		local f = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(8, 14)),
			BackgroundColor3 = Color3.fromHSV(math.random(), 0.75, 1),
			Rotation = math.random(0, 360),
			ZIndex = 70,
		}, parent)
		local ang = math.random() * math.pi * 2
		local dist = math.random(140, 460)
		tween(f, math.random(9, 17) / 10, {
			Position = UDim2.new(0.5, math.cos(ang) * dist, 0.5, math.sin(ang) * dist * 0.7 + 60),
			Rotation = f.Rotation + math.random(-500, 500),
			BackgroundTransparency = 1,
		})
		task.delay(1.8, function()
			f:Destroy()
		end)
	end
end

local function showReveal(id, mut)
	local def = Config.GooberById[id]
	local rar = Config.Rarities[def.Rarity]
	local inc = def.Income * Config.Mutations[mut].Mult
	local overlay = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 40,
	}, gui)
	tween(overlay, 0.3, { BackgroundTransparency = 0.35 })
	local card = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(340, 410) }, overlay)
	local st = card:FindFirstChildOfClass("UIStroke")
	st.Color = rar.Color
	st.Thickness = 5
	local sc = make("UIScale", { Scale = 0 }, card)
	label({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 42), TextSize = 32, TextColor3 = GOLD, Text = "YOU GOT!" }, card)
	local icon = gooberIcon(card, id, mut, 190)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 58)
	label({ Position = UDim2.fromOffset(8, 254), Size = UDim2.new(1, -16, 0, 38), TextScaled = true, TextColor3 = rar.Color, Text = (mut ~= "Normal" and (mut .. " ") or "") .. id }, card)
	label({ Position = UDim2.fromOffset(0, 294), Size = UDim2.new(1, 0, 0, 26), TextSize = 22, TextColor3 = WHITE, Text = def.Rarity:upper() }, card)
	label({ Position = UDim2.fromOffset(0, 322), Size = UDim2.new(1, 0, 0, 28), TextSize = 24, TextColor3 = Color3.fromRGB(255, 225, 120), Text = "+$" .. F(inc) .. "/s" }, card)
	label({ Position = UDim2.fromOffset(0, 372), Size = UDim2.new(1, 0, 0, 22), TextSize = 15, TextColor3 = Color3.fromRGB(210, 215, 255), Text = "TAP TO CONTINUE" }, card)
	play("reveal")
	tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	TweenService:Create(icon, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 8 }):Play()
	task.delay(0.3, function()
		confetti(overlay, 34)
	end)
	overlay.Activated:Connect(function()
		overlay:Destroy()
	end)
end

local function showPetReveal(list, eggId)
	if typeof(list) ~= "table" or #list == 0 then
		return
	end
	local n = #list
	local egg = eggId and Config.EggById[eggId]
	local overlay = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 40,
	}, gui)
	tween(overlay, 0.3, { BackgroundTransparency = 0.35 })
	local cw, gap = (n == 1) and 300 or 220, 14
	local holder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(n * cw + (n - 1) * gap, 420),
		BackgroundTransparency = 1,
	}, overlay)
	label({ Size = UDim2.new(1, 0, 0, 40), TextSize = 32, TextColor3 = Color3.fromRGB(255, 170, 225), Text = n == 1 and "NEW PET!" or "3 EGGS HATCHED!" }, holder)
	local hint = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 24), TextSize = 16, TextColor3 = Color3.fromRGB(210, 215, 255), Text = "TAP TO CONTINUE", TextTransparency = 1 }, holder)
	local allShown = false

	-- the egg wobbles harder and harder, then cracks open
	local intro = 0
	if egg then
		intro = 1.5
		local eggArt = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(150, 190), BackgroundColor3 = egg.Color, ZIndex = 45 }, overlay)
		corner(eggArt, 75)
		stroke(eggArt, 5)
		make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 190)), Rotation = 90 }, eggArt)
		for _, p in ipairs({ { 0.3, 0.3, 26 }, { 0.68, 0.45, 30 }, { 0.42, 0.68, 24 } }) do
			local sp = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(p[1], p[2]), Size = UDim2.fromOffset(p[3], p[3]), BackgroundColor3 = WHITE, BackgroundTransparency = 0.35, ZIndex = 46 }, eggArt)
			corner(sp, 16)
		end
		local crackL = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.3), TextScaled = true, TextTransparency = 1, Text = "/\\/\\/", TextColor3 = BLACK, ZIndex = 47 }, eggArt)
		holder.Visible = false
		task.spawn(function()
			local t0 = os.clock()
			local nextCrack = 0.35
			while overlay.Parent and os.clock() - t0 < intro do
				local t = os.clock() - t0
				local k = t / intro
				eggArt.Rotation = math.sin(t * (12 + k * 26)) * (3 + k * 16)
				eggArt.Size = UDim2.fromOffset(150 + math.sin(t * 20) * 4 * k, 190 + math.sin(t * 20) * 4 * k)
				if t > nextCrack then
					nextCrack += 0.28
					play("crack")
					crackL.TextTransparency = 0.2
				end
				task.wait()
			end
			-- flash + pop
			local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 50 }, overlay)
			tween(flash, 0.5, { BackgroundTransparency = 1 })
			task.delay(0.55, function()
				flash:Destroy()
			end)
			eggArt:Destroy()
			holder.Visible = true
			confetti(overlay, 40)
		end)
	end

	for i, e in ipairs(list) do
		local def = Config.PetById[e.Id]
		local rar = Config.Rarities[def.Rarity]
		local card = panel({ Position = UDim2.fromOffset((i - 1) * (cw + gap), 48), Size = UDim2.fromOffset(cw, 340) }, holder)
		local st = card:FindFirstChildOfClass("UIStroke")
		st.Color = rar.Color
		st.Thickness = 5
		local sc = make("UIScale", { Scale = 0 }, card)
		local iconPx = (n == 1) and 180 or 130
		local icon = petIcon(card, e.Id, iconPx)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 16)
		label({ Position = UDim2.fromOffset(6, iconPx + 22), Size = UDim2.new(1, -12, 0, 34), TextScaled = true, TextColor3 = rar.Color, Text = e.Id }, card)
		label({ Position = UDim2.fromOffset(0, iconPx + 60), Size = UDim2.new(1, 0, 0, 24), TextSize = 20, Text = def.Rarity:upper() }, card)
		if e.Stored then
			label({ Position = UDim2.fromOffset(4, iconPx + 88), Size = UDim2.new(1, -8, 0, 40), TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(120, 255, 190), Text = "Kept safe in your PET STORAGE!" }, card)
		elseif e.Kept == false then
			label({ Position = UDim2.fromOffset(4, iconPx + 88), Size = UDim2.new(1, -8, 0, 40), TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 200, 120), Text = "No room - sold for $" .. F(e.Sold or 0) }, card)
		else
			label({ Position = UDim2.fromOffset(4, iconPx + 88), Size = UDim2.new(1, -8, 0, 40), TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 225, 120), Text = petBuffText(def) }, card)
		end
		TweenService:Create(icon, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 8 }):Play()
		task.delay(intro + 0.25 + (i - 1) * 0.7, function()
			if not overlay.Parent then
				return
			end
			tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			play("reveal")
			if not egg or i > 1 then
				confetti(overlay, 22)
			end
			if i == n then
				allShown = true
				tween(hint, 0.3, { TextTransparency = 0 })
			end
		end)
	end
	overlay.Activated:Connect(function()
		if allShown then
			overlay:Destroy()
		end
	end)
end

-- WELCOME BACK: a big, eye-catching claim popup for the cash your Goobers earned while you were away.
-- After claiming, if you don't already own 2x Cash, a quick upsell offers to double what you just got.
function showOfflineEarnings(amount, elapsedSeconds)
	local hours = math.floor(elapsedSeconds / 3600)
	local mins = math.floor((elapsedSeconds % 3600) / 60)
	local timeText = hours > 0 and (hours .. "h " .. mins .. "m") or (mins .. "m")
	local overlay = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 42 }, gui)
	tween(overlay, 0.35, { BackgroundTransparency = 0.4 })
	local card = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 440), ZIndex = 43 }, overlay)
	local cardStroke = card:FindFirstChildOfClass("UIStroke")
	cardStroke.Color = GOLD
	cardStroke.Thickness = 6
	local sc = make("UIScale", { Scale = 0 }, card)
	label({ Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 46), TextSize = 34, TextColor3 = GOLD, Text = "WELCOME BACK!", ZIndex = 43 }, card)
	label({ Position = UDim2.fromOffset(8, 66), Size = UDim2.new(1, -16, 0, 40), TextSize = 17, TextWrapped = true, TextColor3 = Color3.fromRGB(230, 230, 255), Text = ("Your Goobers kept working for " .. timeText .. " while you were away!"), ZIndex = 43 }, card)
	local sunburst = burst(card, 220, GOLD)
	sunburst.Position = UDim2.fromOffset(100, 110)
	sunburst.ZIndex = 43
	local amountL = label({ Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 90), TextSize = 56, TextColor3 = Color3.fromRGB(130, 255, 150), Text = "+$" .. F(amount), ZIndex = 45 }, card)
	local claimBtn = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 260), Size = UDim2.fromOffset(300, 66), TextSize = 28, Text = "CLAIM", ZIndex = 44 }, card, GREEN)
	local pulse = make("UIScale", {}, claimBtn)
	TweenService:Create(pulse, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.06 }):Play()
	play("reveal")
	tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	task.spawn(function()
		confetti(overlay, 40)
	end)
	claimBtn.Activated:Connect(function()
		Action:FireServer("ClaimOffline")
		if player:GetAttribute("Own_DoubleCash") == true then
			overlay:Destroy()
			return
		end
		-- upsell: offer to double what was just claimed
		for _, c in ipairs(card:GetChildren()) do
			if c:IsA("GuiObject") or c:IsA("UIScale") then
				c:Destroy()
			end
		end
		cardStroke.Color = Color3.fromRGB(90, 230, 120)
		local info = Config.GamePasses.DoubleCash
		label({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 40), TextSize = 30, TextColor3 = Color3.fromRGB(90, 230, 120), Text = "WANT DOUBLE THAT?", ZIndex = 43 }, card)
		label({ Position = UDim2.fromOffset(8, 66), Size = UDim2.new(1, -16, 0, 60), TextSize = 17, TextWrapped = true, TextColor3 = Color3.fromRGB(230, 230, 255), Text = ("2x Cash doubles ALL your income forever - including offline earnings next time!"), ZIndex = 43 }, card)
		local iconBox = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 136), Size = UDim2.fromOffset(110, 110), BackgroundColor3 = Color3.fromRGB(90, 230, 120) }, card)
		corner(iconBox, 55)
		stroke(iconBox, 4, WHITE)
		itemArt(iconBox, "DoubleCash", Color3.fromRGB(90, 230, 120))
		local buyBtn = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 256), Size = UDim2.fromOffset(300, 60), TextSize = 22, Text = "BUY 2x CASH - R$" .. info.Price, ZIndex = 44 }, card, Color3.fromRGB(90, 230, 120))
		buyBtn.Activated:Connect(function()
			if info.Id > 0 then
				MarketplaceService:PromptGamePassPurchase(player, info.Id)
			end
		end)
		local skipBtn = makeButton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 326), Size = UDim2.fromOffset(200, 44), TextSize = 16, Text = "No thanks", ZIndex = 44 }, card, GREY)
		skipBtn.Activated:Connect(function()
			overlay:Destroy()
		end)
	end)
end

----------------------------------------------------------------
-- INTRO: the first 5 seconds. Title slam + confetti + camera fly-over + music,
-- then a FREE GIFT for new players.
----------------------------------------------------------------
local function runIntro()
	-- the loading screen is showing while the server builds the world; wait for it
	local waited = 0
	while not workspace:GetAttribute("WorldReady") and waited < 40 do
		task.wait(0.1)
		waited += 0.1
	end
	local skip = false
	local overlay = introOverlay
	if loadBarBg.Parent then
		loadBarBg:Destroy()
	end
	if loadTip.Parent then
		loadTip:Destroy()
	end
	if overlay:FindFirstChild("LoadDeco") then
		overlay.LoadDeco:Destroy()
	end
	overlay.Activated:Connect(function()
		skip = true
	end)

	local title = loadTitle
	title.Position = UDim2.fromScale(0.5, 0.4)
	title.Size = UDim2.fromOffset(900, 150)
	local tStroke = title:FindFirstChildOfClass("UIStroke")
	tStroke.Thickness = 8
	local tScale = make("UIScale", { Scale = 0 }, title)
	local sub = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromOffset(700, 70),
		TextScaled = true,
		TextColor3 = WHITE,
		TextTransparency = 1,
		Text = "ESCAPE THE FLOOD!",
		ZIndex = 61,
	}, overlay)
	local subStroke = sub:FindFirstChildOfClass("UIStroke")
	subStroke.Transparency = 1
	label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(300, 24), TextSize = 16, TextColor3 = Color3.fromRGB(230, 230, 255), Text = "tap to skip", ZIndex = 61 }, overlay)

	startMusic()
	tween(tScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)

	-- camera fly-over: from high above the far end of the runway down to the plaza
	local A = CFrame.lookAt(Vector3.new(Config.RunwayStart + 800, 170, 90), Vector3.new(Config.RunwayStart + 300, 10, 0))
	local B = CFrame.lookAt(Vector3.new(Config.RunwayStart - 10, 45, 70), Vector3.new(-30, 8, 0))
	local t0 = os.clock()
	local DURATION = 4.4
	local conn = RunService.RenderStepped:Connect(function()
		camera.CameraType = Enum.CameraType.Scriptable
		local a = math.clamp((os.clock() - t0) / DURATION, 0, 1)
		a = a * a * (3 - 2 * a)
		camera.CFrame = A:Lerp(B, a)
	end)

	local step = 0
	while not skip and os.clock() - t0 < DURATION do
		local t = os.clock() - t0
		if step == 0 and t > 0.5 then
			step = 1
			tween(sub, 0.3, { TextTransparency = 0 })
			tween(subStroke, 0.3, { Transparency = 0 })
			confetti(overlay, 40)
			play("reveal")
		elseif step == 1 and t > 1.7 then
			step = 2
			tween(overlay, 1.0, { BackgroundTransparency = 1 })
			tween(title, 1.0, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.25) })
			tween(tStroke, 1.0, { Transparency = 1 })
			tween(sub, 0.8, { TextTransparency = 1 })
			tween(subStroke, 0.8, { Transparency = 1 })
		end
		task.wait()
	end
	conn:Disconnect()
	camera.CameraType = Enum.CameraType.Custom
	overlay:Destroy()
end

-- TUTORIAL CUTSCENE + PRIZE WHEEL
-- A new player first sees a short cutscene that explains the game and chooses START (the 4 tutorial steps) or SKIP.
-- When the tutorial is finished (or skipped) the server sends "WheelStart": they spin a wheel and win a FREE GOOBER of a random rarity.
local wheelOverlay, wheelResult, wheelClose = nil, nil, nil

function startWheel(bankMode)
	if wheelOverlay then
		return
	end
	wheelResult = nil
	local segs = Config.TutorialWheel
	local N = #segs
	local R = 150
	local overlay = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, ZIndex = 46, Active = true }, gui)
	wheelOverlay = overlay
	tween(overlay, 0.4, { BackgroundTransparency = 0.35 })
	local card = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 600) }, overlay)
	card:FindFirstChildOfClass("UIStroke").Color = GOLD
	card:FindFirstChildOfClass("UIStroke").Thickness = 5
	local sc = make("UIScale", { Scale = 0 }, card)
	local viewH = gui.AbsoluteSize.Y -- on a phone the wheel card shrinks so it always fits
	local fit = type(viewH) == "number" and math.clamp(viewH / 660, 0.55, 1) or 1
	tween(sc, 0.5, { Scale = fit }, Enum.EasingStyle.Back)
	label({ Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 46), TextSize = 36, TextColor3 = GOLD, Text = "SPIN THE WHEEL!" }, card)
	local sub = label({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 34), TextSize = 20, TextWrapped = true, TextScaled = true, Text = "Win a FREE GOOBER!" }, card)
	local closeX = makeButton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(38, 38), Text = "X", TextSize = 22 }, card, RED)

	local holder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(2 * R + 20, 2 * R + 20), BackgroundTransparency = 1 }, card)
	local wheel = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2 * R, 2 * R), BackgroundColor3 = Color3.fromRGB(94, 84, 208) }, holder)
	corner(wheel, R)
	stroke(wheel, 6)
	local function ring(angleDeg, dist) -- a point on the wheel (angle clockwise from the top)
		local a = math.rad(angleDeg)
		return Vector2.new(R + math.sin(a) * dist, R - math.cos(a) * dist)
	end
	for k = 1, N do -- spokes between the segments
		local ang = (k - 0.5) * 360 / N
		local p = ring(ang, R / 2)
		make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(4, R), Rotation = ang, BackgroundColor3 = WHITE, BackgroundTransparency = 0.5 }, wheel)
	end
	local badges = {}
	for k, seg in ipairs(segs) do
		local rar = Config.Rarities[seg.Rarity]
		local p = ring((k - 1) * 360 / N, R * 0.64)
		local b = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(78, 78), BackgroundColor3 = rar.Color }, wheel)
		corner(b, 39)
		stroke(b, 3)
		label({ Size = UDim2.fromScale(1, 1), TextScaled = true, TextWrapped = true, Text = seg.Rarity:upper() .. "\nGOOBER" }, b)
		badges[k] = b
	end
	local hub = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(R, R), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = GOLD }, wheel)
	corner(hub, 29)
	stroke(hub, 4)
	local pointer = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(30, 30), Rotation = 45, BackgroundColor3 = GOLD, ZIndex = 5 }, holder)
	stroke(pointer, 3)
	local spin = makeButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.fromOffset(300, 70), Text = "SPIN!", TextSize = 42, TextWrapped = true, TextScaled = true }, card, GREEN)
	make("UITextSizeConstraint", { MaxTextSize = 42 }, spin)

	local keepUpright = RunService.RenderStepped:Connect(function() -- the labels stay readable while the wheel turns
		for _, b in ipairs(badges) do
			b.Rotation = -wheel.Rotation
		end
	end)
	local function close()
		keepUpright:Disconnect()
		if overlay.Parent then
			overlay:Destroy()
		end
		wheelOverlay, wheelClose = nil, nil
	end
	wheelClose = close
	closeX.Activated:Connect(close)

	local busy = false
	spin.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		spin.Text = "SPINNING..."
		Action:FireServer(bankMode and "UseSpin" or "SpinWheel") -- the SERVER picks the egg; this just animates the wheel onto it
		local waited = 0
		while wheelResult == nil and waited < 5 do
			task.wait(0.05)
			waited += 0.05
		end
		if wheelResult == nil then
			toast("The wheel didn't spin - try again later", RED, "error")
			close()
			return
		end
		local seg = 360 / N
		local final = 360 * 6 - (wheelResult - 1) * seg -- lands segment number wheelResult under the pointer at the top
		local dur = math.max(2, Config.WheelSpinSeconds - 1.2)
		tween(wheel, dur, { Rotation = final }, Enum.EasingStyle.Quart)
		local lastIdx, t0 = 0, os.clock()
		while os.clock() - t0 < dur do -- a tick every time a segment passes the pointer
			local idx = math.floor(wheel.Rotation / seg)
			if idx ~= lastIdx then
				lastIdx = idx
				play("pop")
			end
			task.wait(0.03)
		end
		local wonRarity = segs[wheelResult].Rarity
		sub.Text = "You won a " .. wonRarity .. " GOOBER!"
		sub.TextColor3 = Config.Rarities[wonRarity].Color
		play("reveal")
		local pulse = make("UIScale", {}, badges[wheelResult])
		TweenService:Create(pulse, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 6, true), { Scale = 1.3 }):Play()
		spin.Text = "GETTING\nYOUR GOOBER..."
		task.delay(Config.WheelSpinSeconds + 6, function() -- safety net (the egg reveal normally closes this window first)
			if wheelClose == close then
				close()
			end
		end)
	end)
	play("pop")
	-- the DAILY LOGIN reward pops up right away too (it sits behind the wheel and is open as soon as the wheel closes) - tutorial flow only
	if not bankMode and player:GetAttribute("DailyReady") then
		toggleMenu("daily", true)
	end
end

-- CARRY POSE: while someone is holding Goobers (the little stack above their head), their arms lift up as if holding
-- it in place. This runs for every player so everyone sees it, not just yourself. The Wacker can't be used like this.
do
	local UP = CFrame.new()
	local function armPose(side) -- side: 1 = right arm, -1 = left arm
		return CFrame.Angles(math.rad(-108), 0, math.rad(side * 14))
	end
	local posed = {}
	local function applyPose(char, on)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		if hum.RigType == Enum.HumanoidRigType.R15 then
			local ru, lu = char:FindFirstChild("RightUpperArm"), char:FindFirstChild("LeftUpperArm")
			local rs = ru and ru:FindFirstChild("RightShoulder")
			local ls = lu and lu:FindFirstChild("LeftShoulder")
			if rs then
				rs.Transform = on and armPose(1) or UP
			end
			if ls then
				ls.Transform = on and armPose(-1) or UP
			end
		else -- R6 (or best-effort for anything else with the classic joint names)
			local torso = char:FindFirstChild("Torso")
			local rs = torso and torso:FindFirstChild("Right Shoulder")
			local ls = torso and torso:FindFirstChild("Left Shoulder")
			if rs then
				rs.Transform = on and armPose(1) or UP
			end
			if ls then
				ls.Transform = on and armPose(-1) or UP
			end
		end
	end
	local function watch(plr)
		local function sync()
			local char = plr.Character
			local on = (plr:GetAttribute("Carrying") or 0) > 0
			if char then
				applyPose(char, on)
			end
		end
		plr:GetAttributeChangedSignal("Carrying"):Connect(sync)
		plr.CharacterAdded:Connect(function()
			task.wait(0.3) -- let the rig's Motor6Ds finish loading first
			sync()
		end)
		sync()
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		watch(plr)
	end
	Players.PlayerAdded:Connect(watch)
end

-- LEAVING REMINDER: Roblox has no real "about to disconnect" signal, so this fires the first time the game
-- window loses focus (tabbing away, alt-tabbing, opening another app) as the closest practical proxy - a big,
-- can't-miss reminder of how much is waiting for them, so they come back.
do
	local shown = false
	UserInputService.WindowFocusReleased:Connect(function()
		if shown or not player.Character then
			return
		end
		shown = true
		local perDay = math.floor((player:GetAttribute("Income") or 0) * 86400 * Config.OfflineEarnRate)
		if perDay <= 0 then
			return
		end
		local overlay = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 41 }, gui)
		tween(overlay, 0.3, { BackgroundTransparency = 0.45 })
		local card = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.08), Size = UDim2.fromOffset(420, 150), ZIndex = 42 }, overlay)
		card:FindFirstChildOfClass("UIStroke").Color = GOLD
		card:FindFirstChildOfClass("UIStroke").Thickness = 5
		local sc = make("UIScale", { Scale = 0 }, card)
		label({ Position = UDim2.fromOffset(8, 12), Size = UDim2.new(1, -16, 0, 34), TextSize = 24, TextColor3 = GOLD, Text = "DON'T FORGET YOUR GOOBERS!", ZIndex = 42 }, card)
		label({ Position = UDim2.fromOffset(8, 50), Size = UDim2.new(1, -16, 0, 66), TextSize = 17, TextWrapped = true, TextColor3 = Color3.fromRGB(230, 230, 255), Text = ("They'll keep earning about $" .. F(perDay) .. " a day while you're away - come back tomorrow to collect it!") }, card)
		play("reveal")
		tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(6, function()
			if overlay.Parent then
				tween(overlay, 0.5, { BackgroundTransparency = 1 })
				tween(sc, 0.4, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				task.wait(0.5)
				overlay:Destroy()
			end
		end)
		overlay.Activated:Connect(function()
			overlay:Destroy()
		end)
	end)
end

-- BOSS RUMBLE: a mild camera shake that grows as a hunting boss gets closer to you (never when it's just idling)
do
	local bosses, nextScan = {}, 0
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if t >= nextScan then
			nextScan = t + 2
			bosses = CollectionService:GetTagged("BossBody")
		end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp or settings.lowPerf then
			return
		end
		local closest = math.huge
		for _, b in ipairs(bosses) do
			if b.Parent and b:GetAttribute("Hunting") then
				local d = (b.Position - hrp.Position).Magnitude
				if d < closest then
					closest = d
				end
			end
		end
		if closest < 70 then
			local k = (1 - closest / 70) * 0.01
			camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * k, (math.random() - 0.5) * k, (math.random() - 0.5) * k)
		end
	end)
end

-- WORLD LIFE: ripples spread on the fountain water and the trees near you sway in the wind
do
	local ripples, trees, nextScan = {}, {}, 0
	RunService.RenderStepped:Connect(function()
		if settings.lowPerf then
			return
		end
		local t = os.clock()
		if t >= nextScan then
			nextScan = t + 3
			ripples, trees = CollectionService:GetTagged("FountainRipple"), CollectionService:GetTagged("SwayTree")
		end
		for _, r in ipairs(ripples) do
			if r.Parent then
				local ph = (t * 0.35 + (r:GetAttribute("Phase") or 0)) % 1
				local d = 3 + ph * (r:GetAttribute("MaxSize") or 25)
				r.Size = Vector3.new(0.12, d, d)
				r.Transparency = 0.45 + ph * 0.55
			end
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			for _, m in ipairs(trees) do
				local base = m.Parent and m:GetAttribute("BaseCF")
				if base and (base.Position - root.Position).Magnitude < 140 then
					local ph = m:GetAttribute("Phase") or 0
					m:PivotTo(base * CFrame.Angles(math.sin(t * 1.1 + ph) * 0.012, 0, math.sin(t * 0.8 + ph * 1.7) * 0.016))
				end
			end
		end
	end)
end

local cutsceneGui = nil
-- The cutscene: a short camera fly-through with captions (NO black bars, and it never stays: it ends by itself and the tutorial begins).
-- SKIP (top right, or the ENTER key) jumps straight to the prize wheel. It lives in its own top-most ScreenGui so nothing can cover its button.
function tutorialCutscene()
	if cutsceneGui then
		return
	end
	local sg = make("ScreenGui", { Name = "CutsceneGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 200, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	cutsceneGui = sg
	local title = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(460, 58), TextSize = 44, TextColor3 = GOLD, Text = "HOW TO PLAY" }, sg)
	local capBox = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.new(0.9, 0, 0, 78), BackgroundColor3 = Color3.fromRGB(104, 98, 224) }, sg)
	make("UISizeConstraint", { MaxSize = Vector2.new(660, 78) }, capBox)
	corner(capBox, 39)
	stroke(capBox, 4, GOLD)
	make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 180, 245)), Rotation = 90 }, capBox)
	local cap = label({ Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -36, 1, 0), TextSize = 28, TextWrapped = true, Text = "" }, capBox)
	local capScale = make("UIScale", {}, capBox)
	local skipB = makeButton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 22), Size = UDim2.fromOffset(150, 54), Text = "SKIP", TextSize = 28 }, sg, Color3.fromRGB(120, 130, 235))
	label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 80), Size = UDim2.fromOffset(150, 18), TextSize = 13, TextColor3 = Color3.fromRGB(230, 235, 255), Text = "or press ENTER" }, sg)

	local captions = {
		"Welcome to GRAB A GOOBER!",
		"1.  GRAB a Goober from the runway",
		"2.  Carry it HOME and put it on a pedestal",
		"3.  Step on the pad to COLLECT cash - then UPGRADE!",
		"Watch out for FLOODS and the big BOSSES!",
		"Finish the tutorial to spin for a FREE GOOBER!",
	}
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local home = root and root.Position or Vector3.new(0, 6, 0)
	local rx = Config.RunwayStart
	local frames = { -- { camera position, what it looks at }
		{ Vector3.new(home.X - 26, home.Y + 22, home.Z - 40), home },
		{ Vector3.new(rx + 40, 30, -70), Vector3.new(rx + 170, 6, 0) },
		{ Vector3.new(home.X + 40, home.Y + 26, home.Z + 30), home },
		{ Vector3.new(home.X + 70, home.Y + 30, home.Z - 30), home },
		{ Vector3.new(rx + 260, 70, 0), Vector3.new(rx + 620, 8, 0) },
		{ Vector3.new(rx + 330, 40, 60), Vector3.new(rx + 500, 10, 0) },
	}
	local SEG, t0, shown, done = 2.6, os.clock(), 0, false
	local conn, keyConn
	local function close(skipped)
		if done then
			return
		end
		done = true
		if conn then
			conn:Disconnect()
		end
		if keyConn then
			keyConn:Disconnect()
		end
		camera.CameraType = Enum.CameraType.Custom
		sg:Destroy()
		cutsceneGui = nil
		if skipped then
			Action:FireServer("TutorialDone") -- skipping counts as finishing: the wheel comes next
		else
			startTutorial() -- the cutscene is over: the 4 tutorial steps begin (they have their own SKIP)
		end
	end
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= SEG * #captions then
			close(false)
			return
		end
		local i = math.min(#frames - 1, math.floor(t / SEG) + 1)
		local f = math.clamp((t - (i - 1) * SEG) / SEG, 0, 1)
		f = f * f * (3 - 2 * f)
		local a, b = frames[i], frames[i + 1]
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(a[1]:Lerp(b[1], f), a[2]:Lerp(b[2], f))
		local ci = math.min(#captions, math.floor(t / SEG) + 1)
		if ci ~= shown then
			shown = ci
			cap.Text = captions[ci]
			capScale.Scale = 0.85
			tween(capScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			play("pop")
		end
	end)
	skipB.Activated:Connect(function()
		close(true)
	end)
	keyConn = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Return then
			close(true)
		end
	end)
end

task.spawn(function()
	runIntro()
	local waited = 0
	while (player:GetAttribute("TutDone") == nil or player:GetAttribute("WheelReady") == nil) and waited < 15 do
		task.wait(0.25)
		waited += 0.25
	end
	if player:GetAttribute("TutDone") == false then
		tutorialCutscene() -- brand new player
	elseif player:GetAttribute("WheelReady") == true then
		startWheel() -- did the tutorial before but never spun the wheel
	end
end)

----------------------------------------------------------------
-- SERVER -> CLIENT EVENTS
----------------------------------------------------------------
local inviteToken = 0
UI.OnClientEvent:Connect(function(kind, a, b)
	if kind == "OpenShop" then
		toggleMenu("npc", true)
		onOpenNpc()
	elseif kind == "OpenPets" then
		toggleMenu("pets", true)
	elseif kind == "OpenGroup" then
		toggleMenu("group", true)
	elseif kind == "ChatAnnounce" then
		postToRobloxChat(a)
	elseif kind == "OfflineEarnings" then
		showOfflineEarnings(a, b)
	elseif kind == "WheelStart" then
		startWheel()
	elseif kind == "WheelResult" then
		wheelResult = a
	elseif kind == "PetReveal" then
		if wheelClose then -- the wheel's egg just opened: close the wheel window and show the pet
			wheelClose()
		end
		showPetReveal(a, b)
	elseif kind == "OpenStand" then
		openStand(a)
	elseif kind == "OpenEgg" then
		openEgg(a)
	elseif kind == "DailyClaimed" then
		toast("DAY " .. tostring(a) .. " CLAIMED!", GOLD, "reveal")
	elseif kind == "Sfx" then
		play(a)
		if a == "wack" and wackPunch then
			wackPunch()
		end
	elseif kind == "Reveal" then
		if wheelClose then
			-- the wheel already celebrated (the spin, the landing, the pulse) - closing it and popping ANOTHER big
			-- full-screen card on top would be overkill, so the wheel's own prize is revealed discreetly: just a toast
			wheelClose()
			local def = Config.GooberById[a]
			toast(("Got a %s %s!"):format(def.Rarity:upper(), a), Config.Rarities[def.Rarity].Color, "reveal")
		else
			showReveal(a, b)
		end
	elseif kind == "TradeInvite" then
		inviteText.Text = a .. " wants to trade!"
		invite.Visible = true
		inviteToken += 1
		local id = inviteToken
		play("pop")
		task.delay(30, function()
			if id == inviteToken then
				invite.Visible = false
			end
		end)
	elseif kind == "TradeOpen" then
		inTrade = true
		tradeList.Visible = false
		tradeSession.Visible = true
		invite.Visible = false
		toggleMenu("trade", true)
	elseif kind == "TradeState" then
		renderTrade(a)
		if not tradeFrame.Visible then
			toggleMenu("trade", true)
		end
	elseif kind == "TradeClosed" then
		inTrade = false
		tradeSession.Visible = false
		tradeList.Visible = true
		tradeSignature = ""
		closeMenus()
		toast(a, GREEN, "reveal")
	end
end)

----------------------------------------------------------------
-- STEAL / SELL PROMPTS (owner can't steal own Goobers, only the owner can sell)
----------------------------------------------------------------
local function handlePrompt(pp)
	local mine = pp:GetAttribute("OwnerId") == player.UserId
	if CollectionService:HasTag(pp, "StealPrompt") then
		if mine then
			pp.Enabled = false
		end
	elseif not mine then
		pp.Enabled = false
	end
end
for _, tag in ipairs({ "StealPrompt", "SellPrompt" }) do
	for _, pp in ipairs(CollectionService:GetTagged(tag)) do
		handlePrompt(pp)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(handlePrompt)
end

-- upgrade buttons in the bases: only the owner can press theirs
local function handleUpgradePrompt(pp)
	local function apply()
		pp.MaxActivationDistance = (pp:GetAttribute("OwnerId") == player.UserId) and 7 or 0
	end
	apply()
	pp:GetAttributeChangedSignal("OwnerId"):Connect(apply)
end
for _, pp in ipairs(CollectionService:GetTagged("UpgradePrompt")) do
	handleUpgradePrompt(pp)
end
CollectionService:GetInstanceAddedSignal("UpgradePrompt"):Connect(handleUpgradePrompt)

local syncPets
do
	----------------------------------------------------------------
	-- ANIMATED GOOBERS
	--  WalkGoober : runway pickups walk in a little circle, hopping, facing where they walk
	--  IdleGoober : goobers in your base face forward, bounce and look around
	--  BobModel   : the eggs float and spin
	-- Every position comes from the "home" attributes the server set (HX/HY/HZ), so a model can never end up in the wrong place.
	----------------------------------------------------------------
	local animated = {}
	local function fmtClock(sec)
		sec = math.max(0, math.ceil(sec))
		return ("%d:%02d"):format(sec // 60, sec % 60)
	end

	local function register(kind, m)
		if not m:IsA("Model") then
			return
		end
		task.spawn(function()
			local waited = 0
			while m.Parent and not m.PrimaryPart and waited < 6 do -- wait until the whole model has replicated
				task.wait(0.1)
				waited += 0.1
			end
			if not m.Parent or not m.PrimaryPart then
				return
			end
			local hx, hy, hz = m:GetAttribute("HX"), m:GetAttribute("HY"), m:GetAttribute("HZ")
			if not (hx and hy and hz) then
				return
			end
			animated[m] = {
				Kind = kind,
				Home = Vector3.new(hx, hy, hz),
				Yaw = m:GetAttribute("Yaw") or 0,
				R = m:GetAttribute("Circle") or 4,
				Dir = m:GetAttribute("Dir") or 1,
				Rate = m:GetAttribute("Rate") or 0.7,
				Seed = math.random() * 6.28,
				NextText = 0,
			}
		end)
	end
	for _, tag in ipairs({ "WalkGoober", "IdleGoober", "BobModel" }) do
		for _, m in ipairs(CollectionService:GetTagged(tag)) do
			register(tag, m)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(m)
			register(tag, m)
		end)
	end

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local camPos = camera.CFrame.Position
		for m, info in pairs(animated) do
			if not m.Parent then
				animated[m] = nil
			else
				local home = info.Home
				if (home - camPos).Magnitude < 300 then
					local kind = info.Kind
					if kind == "WalkGoober" then
						local a = t * info.Rate * info.Dir + info.Seed
						local hop = math.abs(math.sin(t * 5 + info.Seed)) * 0.8
						local pos = Vector3.new(home.X + math.cos(a) * info.R, home.Y + hop, home.Z + math.sin(a) * info.R)
						local heading = Vector3.new(-math.sin(a) * info.Dir, 0, math.cos(a) * info.Dir)
						m:PivotTo(CFrame.lookAt(pos, pos + heading) * CFrame.Angles(0, 0, math.sin(t * 5 + info.Seed) * 0.07))
						if t >= info.NextText then
							info.NextText = t + 0.25
							local on = (m:GetAttribute("Zone") or 0) <= (player:GetAttribute("MaxZone") or 0) + 1
							if info.TextOn ~= on then
								info.TextOn = on
								for _, gname in ipairs({ "NameGui", "TimerGui" }) do
									local gg = m:FindFirstChild(gname, true)
									if gg then
										gg.Enabled = on
									end
								end
							end
							local expireAt = m:GetAttribute("ExpireAt")
							if expireAt then
								local tl = info.Timer
								if not tl or not tl.Parent then
									tl = m:FindFirstChild("Timer", true)
									info.Timer = tl
								end
								if tl then
									local left = expireAt - workspace:GetServerTimeNow()
									tl.Text = fmtClock(left)
									tl.TextColor3 = left < 10 and RED or WHITE
								end
							end
						end
					elseif kind == "IdleGoober" then
						local bounce = math.max(0, math.sin(t * 2.1 + info.Seed)) ^ 4 * 0.9
						local look = math.sin(t * 0.8 + info.Seed) * 0.4
						m:PivotTo(CFrame.new(home.X, home.Y + bounce, home.Z) * CFrame.Angles(0, info.Yaw + look, 0))
					else
						m:PivotTo(CFrame.new(home.X, home.Y + math.sin(t * 2 + info.Seed) * 0.7, home.Z) * CFrame.Angles(0, t * 1.4 + info.Seed, 0))
					end
				end
			end
		end
	end)

	----------------------------------------------------------------
	-- DEPOSIT SIGN: only the base owner sees "DEPOSIT HERE"
	----------------------------------------------------------------
	local function handleDeposit(bb)
		local function apply()
			bb.Enabled = bb:GetAttribute("OwnerId") == player.UserId
		end
		apply()
		bb:GetAttributeChangedSignal("OwnerId"):Connect(apply)
	end
	for _, bb in ipairs(CollectionService:GetTagged("DepositGui")) do
		handleDeposit(bb)
	end
	CollectionService:GetInstanceAddedSignal("DepositGui"):Connect(handleDeposit)

	----------------------------------------------------------------
	-- STAND PADS: step on the glowing pad in front of the Speed / Capacity stand to open its window
	----------------------------------------------------------------
	do
		local inside = {}
		task.spawn(function()
			while true do
				task.wait(0.15)
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local p = hrp.Position
					for _, pad in ipairs(CollectionService:GetTagged("StandPad")) do
						local pp = pad.Position
						local on = math.abs(p.X - pp.X) < pad.Size.X / 2 + 0.5 and math.abs(p.Z - pp.Z) < pad.Size.Z / 2 + 0.5 and p.Y < 12
						if on and not inside[pad] then
							openStand(pad:GetAttribute("Upgrade"))
						end
						inside[pad] = on
					end
				end
			end
		end)
	end

	----------------------------------------------------------------
	-- NPCs: idle -> hello (when you walk up) -> bye (when you leave Gus after buying)
	----------------------------------------------------------------
	local npcs = {}
	local function addNPC(m)
		if not m:IsA("Model") then
			return
		end
		task.spawn(function()
			local waited = 0
			local function ready()
				return m:FindFirstChild("Torso") and m:FindFirstChild("Right Arm") and m:FindFirstChild("Left Arm") and m:FindFirstChild("Right Leg") and m:FindFirstChild("Left Leg")
			end
			while m.Parent and not ready() and waited < 6 do
				task.wait(0.2)
				waited += 0.2
			end
			if m.Parent and ready() then
				npcs[m] = {
					Torso = m.Torso, RArm = m["Right Arm"], LArm = m["Left Arm"], RLeg = m["Right Leg"], LLeg = m["Left Leg"],
					Persona = m:GetAttribute("Persona") or "",
					State = "idle", Until = 0, A = { 7, 7, 0, 0, 0, 0 }, Phase = math.random() * 6, Near = false,
				}
			end
		end)
	end
	for _, m in ipairs(CollectionService:GetTagged("NPC")) do
		addNPC(m)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(addNPC)

	function npcSay(name, state)
		for m, info in pairs(npcs) do
			if m.Name == name then
				info.State = state
				info.Until = os.clock() + 2.4
			end
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local myPos = hrp and hrp.Position
		local camPos = camera.CFrame.Position
		local k = math.min(1, dt * 10)
		for m, info in pairs(npcs) do
			if not m.Parent or not info.Torso.Parent or not info.RArm.Parent then
				npcs[m] = nil
			elseif (info.Torso.Position - camPos).Magnitude < 180 then
				if myPos then
					local dist = (info.Torso.Position - myPos).Magnitude
					if dist < 22 and not info.Near then
						info.Near = true
						if info.State == "idle" then
							info.State = "hello"
							info.Until = t + 2
						end
					elseif dist > 36 then
						info.Near = false
					end
				end
				if info.State ~= "idle" and t > info.Until then
					info.State = "idle"
				end
				local goal = { npcTargetAngles(info.State, t, info.Phase, info.Persona) }
				for n = 1, 6 do
					info.A[n] += (goal[n] - info.A[n]) * k
				end
				npcPoseArms(info.Torso, info.RArm, info.LArm, info.A[1], info.A[2], info.A[3], info.A[4])
				npcPoseLegs(info.Torso, info.RLeg, info.LLeg, info.A[5], info.A[6])
			end
		end
	end)

	----------------------------------------------------------------
	-- PETS follow their owner (built on each player's own screen, so it costs the server nothing)
	----------------------------------------------------------------
	local petFolder = Instance.new("Folder")
	petFolder.Name = "GooberPets"
	petFolder.Parent = workspace
	local petState = {}

	local function clearPets(plr)
		local st = petState[plr]
		if st then
			for _, e in ipairs(st.List) do
				e.Model:Destroy()
			end
			petState[plr] = nil
		end
	end

	function syncPets()
		for _, plr in ipairs(Players:GetPlayers()) do
			local csv = plr:GetAttribute("Pets") or ""
			local st = petState[plr]
			if (not st and csv ~= "") or (st and st.Key ~= csv) then
				clearPets(plr)
				if csv ~= "" then
					local list = {}
					for id in string.gmatch(csv, "[^,]+") do
						if Config.PetById[id] then
							local model = Instance.new("Model")
							model.Name = "Pet_" .. id
							local body = Creatures.Build(Creatures.SpecForPet(id), 2.4, CFrame.new(), true, model)
							model.PrimaryPart = body
							model.Parent = petFolder
							model:PivotTo(CFrame.new(0, -500, 0)) -- hidden until it is placed next to its owner
							table.insert(list, { Model = model })
						end
					end
					petState[plr] = { Key = csv, List = list }
				end
			end
		end
	end
	Players.PlayerRemoving:Connect(clearPets)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local camPos = camera.CFrame.Position
		for plr, st in pairs(petState) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				for i, e in ipairs(st.List) do
					local side = (i % 2 == 1) and -1 or 1
					local row = math.ceil(i / 2)
					local target = hrp.CFrame * CFrame.new(side * (3.2 + (row - 1) * 0.6), -1.4 + math.sin(t * 3 + i * 1.7) * 0.4, 2.6 + (row - 1) * 2.6)
					if not e.CF then
						e.CF = target
					end
					e.CF = e.CF:Lerp(target, math.min(1, dt * 7))
					local pos = e.CF.Position
					e.Model:PivotTo(CFrame.lookAt(pos, Vector3.new(camPos.X, pos.Y, camPos.Z) + Vector3.new(0, 0, 0.001)))
				end
			end
		end
	end)


end

----------------------------------------------------------------
-- WAVY FLOODS: every screen draws the water itself from the numbers on the server's tiny marker
-- (start position, start time, speed, height...). The wave is a row of columns whose heights ripple along the wave, each
-- topped by a rolling foam crest and a curling lip, so it looks like real water and moves perfectly smoothly.
-- The height never goes above the flood's real height, so what you see is what can hit you.
----------------------------------------------------------------
do
	local floods = {} -- [marker] = { Seg = {...} or nil, ...numbers }
	local SEGMENTS = isTouch and 8 or 14 -- phones draw fewer water columns (much cheaper, still looks like a wave)
	local DETAIL_DIST = isTouch and 450 or 700 -- beyond this only the plain slab is drawn

	local function register(m)
		if not m:IsA("BasePart") then
			return
		end
		task.spawn(function()
			local waited = 0
			while m.Parent and m:GetAttribute("StartX") == nil and waited < 5 do -- attributes arrive with the marker
				task.wait(0.1)
				waited += 0.1
			end
			if not m.Parent or m:GetAttribute("StartX") == nil then
				return
			end
			floods[m] = {
				StartX = m:GetAttribute("StartX"),
				StartTime = m:GetAttribute("StartTime"),
				Speed = m:GetAttribute("Speed"),
				Height = m:GetAttribute("Height"),
				Thick = m:GetAttribute("Thickness"),
				Width = m:GetAttribute("Width"),
				Color = m:GetAttribute("WaveColor") or Color3.fromRGB(60, 200, 255),
				Rainbow = m:GetAttribute("Rainbow") == true,
				SideToSide = m:GetAttribute("SideToSide") == true,
				OscAmp = m:GetAttribute("OscAmp") or 0,
				OscFreq = m:GetAttribute("OscFreq") or 1,
				SlabT = m.Transparency, -- how see-through the server's plain slab is
			}
		end)
	end
	for _, m in ipairs(CollectionService:GetTagged("FloodWave")) do
		register(m)
	end
	CollectionService:GetInstanceAddedSignal("FloodWave"):Connect(register)

	local function newPart(props, parent)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in pairs(props) do
			p[k] = v
		end
		p.Parent = parent
		return p
	end

	local function build(info)
		local folder = Instance.new("Folder")
		folder.Name = "FloodVisual"
		folder.Parent = workspace
		info.Folder = folder
		info.Seg = {}
		local foam = info.Color:Lerp(WHITE, 0.8)
		local water = { Material = Enum.Material.SmoothPlastic, Reflectance = 0.12 }
		-- each slice of the wave is a real breaking-wave profile (seen from the side):
		--   Back  = a long ramp of water rising from behind up to the crest
		--   Fill  = the thick body of the wave (exactly where the deadly slab is)
		--   Face  = the steep front face, leaning forward as the wave starts to break
		--   Shade = the dark hollow ("barrel") tucked under the curl
		--   Lip   = the curling white foam lip on top, Foam = a whitecap riding behind it
		for i = 1, SEGMENTS do
			info.Seg[i] = {
				Back = newPart({ Name = "WaveBack", Shape = Enum.PartType.Wedge, Material = water.Material, Reflectance = water.Reflectance, Color = info.Color, Transparency = 0.18 }, folder),
				Fill = newPart({ Name = "WaveBody", Material = water.Material, Reflectance = water.Reflectance, Color = info.Color:Lerp(BLACK, 0.12), Transparency = 0.12 }, folder),
				Face = newPart({ Name = "WaveFace", Material = water.Material, Reflectance = 0.2, Color = info.Color:Lerp(WHITE, 0.15), Transparency = 0.1 }, folder),
				Shade = newPart({ Name = "WaveBarrel", Shape = Enum.PartType.Cylinder, Material = water.Material, Color = info.Color:Lerp(BLACK, 0.4), Transparency = 0.3 }, folder),
				Lip = newPart({ Name = "WaveLip", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = foam, Transparency = 0.05 }, folder),
				Foam = newPart({ Name = "Whitecap", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = foam, Transparency = 0.15 }, folder),
			}
		end
		-- glow + spray from the middle of the wave
		local mid = info.Seg[SEGMENTS // 2].Lip
		local light = Instance.new("PointLight")
		light.Color = info.Color
		light.Range = 60
		light.Brightness = 2.5
		light.Parent = info.Seg[SEGMENTS // 2].Fill
		local spray = Instance.new("ParticleEmitter")
		spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spray.Rate = 35
		spray.Lifetime = NumberRange.new(0.7, 1.3)
		spray.Speed = NumberRange.new(5, 11)
		spray.SpreadAngle = Vector2.new(35, 35)
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Color = ColorSequence.new(foam)
		spray.Size = NumberSequence.new(1.1)
		spray.LightEmission = 0.8
		spray.Parent = mid
	end

	local function destroyVisual(info)
		if info.Folder then
			info.Folder:Destroy()
			info.Folder = nil
			info.Seg = nil
		end
	end

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local now = workspace:GetServerTimeNow()
		-- Distances are measured from the PLAYER, not from the camera, so turning or moving the camera can never change what is drawn.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		local viewX = root and root.Position.X or (cam and cam.CFrame.Position.X) or 0
		for m, info in pairs(floods) do
			if not m.Parent then
				destroyVisual(info)
				floods[m] = nil
			else
				local x = info.StartX - info.Speed * (now - info.StartTime)
				local zOff = info.SideToSide and math.sin((now - info.StartTime) * info.OscFreq) * info.OscAmp or 0
				m.LocalTransparencyModifier = 0 -- the server's slab is ALWAYS visible: the wave can never disappear, whatever the camera does
				if math.abs(x - viewX) > DETAIL_DIST then
					destroyVisual(info) -- far away: only the plain slab
					m.Transparency = info.SlabT
				else
					if info.Folder and info.Folder.Parent ~= workspace then
						destroyVisual(info) -- something removed the detailed water: build it again
					end
					if not info.Folder then
						build(info)
					end
					m.Transparency = math.max(info.SlabT, 0.78) -- the slab fades back so the rippling water on top of it shows
					local W, thick, H = info.Width, info.Thick, info.Height
					local segW = W / SEGMENTS
					local sw = segW * 1.04
					local f = x - thick / 2 -- the FRONT (deadly) edge of the slab; the wave travels toward -X
					local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder so it runs along the wave's width
					for i, s in ipairs(info.Seg) do
						local z = zOff + (-W / 2 + (i - 0.5) * segW)
						local ph = t * 3.1 + i * 0.8
						local hf = 0.86 + 0.14 * math.sin(ph) -- the top edge ripples along the wave (never above the real height)
						local h = H * hf
						local over = math.min(h * 0.22, 1.5 + thick * 0.35) -- how far the curling lip hangs out over the front
						local lean = math.atan(over / h)
						local cr = math.clamp(h * 0.14, 0.6, 5) -- foam lip radius
						local tf = math.max(0.8, thick * 0.35) -- front face thickness
						local L = math.max(thick * 1.5, h * 1.1) -- length of the back ramp
						if info.Rainbow then -- the colour itself travels along the wave's length, cycling over time
							local hue = (t * 0.25 + i * 0.09) % 1
							local col = Color3.fromHSV(hue, 0.85, 1)
							s.Back.Color = col
							s.Fill.Color = col:Lerp(BLACK, 0.12)
							s.Face.Color = col:Lerp(WHITE, 0.15)
							s.Shade.Color = col:Lerp(BLACK, 0.4)
							s.Lip.Color = col:Lerp(WHITE, 0.7)
							s.Foam.Color = col:Lerp(WHITE, 0.7)
						end
						s.Fill.Size = Vector3.new(thick, h * 0.85, sw)
						s.Fill.CFrame = CFrame.new(f + thick / 2, h * 0.425, z)
						-- wedge: tall end toward the crest (front), sloping down to the water behind
						local bx = f + thick + L / 2
						s.Back.Size = Vector3.new(sw, h * 0.85, L)
						s.Back.CFrame = CFrame.lookAt(Vector3.new(bx, h * 0.425, z), Vector3.new(bx + 1, h * 0.425, z))
						s.Face.Size = Vector3.new(tf, h, sw)
						s.Face.CFrame = CFrame.new(f + tf / 2 - (h / 2) * math.sin(lean), (h / 2) * math.cos(lean), z) * CFrame.Angles(0, 0, lean)
						s.Shade.Size = Vector3.new(sw, cr * 2.2, cr * 2.2)
						s.Shade.CFrame = CFrame.new(f - over * 0.3 + cr * 0.9, h - cr * 1.7, z) * ALONG_Z
						local bob = math.sin(ph * 1.3 + 1.2) * cr * 0.12
						s.Lip.Size = Vector3.new(sw * 1.02, cr * 2, cr * 2)
						s.Lip.CFrame = CFrame.new(f - over + cr * 0.7, h - cr + bob, z) * ALONG_Z
						s.Foam.Size = Vector3.new(cr * 1.8, cr * 1.8, cr * 1.8)
						s.Foam.Position = Vector3.new(f + cr * 1.3, h - cr * 0.95 - bob, z)
					end
				end
			end
		end
	end)
end

----------------------------------------------------------------
-- THE WACKER: our own on-screen button (a drawn mallet) instead of Roblox's plain name box.
-- It wiggles while equipped, swings when you whack, and fills up while it recharges.
----------------------------------------------------------------
do
	local StarterGui = game:GetService("StarterGui")
	task.spawn(function() -- hide Roblox's own hotbar (the Wacker is the only tool)
		for _ = 1, 20 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			if ok then
				break
			end
			task.wait(0.5)
		end
	end)
	local PINKC, GOLDC = Color3.fromRGB(255, 105, 185), Color3.fromRGB(255, 215, 70)
	local slot = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = isTouch and UDim2.new(0.5, 0, 1, -12) or UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = Color3.fromRGB(58, 38, 108),
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 2,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, slot)
	local slotStroke = make("UIStroke", { Thickness = 4, Color = PINKC, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, slot)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 160, 200)), Rotation = 90 }, slot)
	local slotScale = make("UIScale", {}, slot)
	local gloss = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(0.8, 0, 0.16, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, Active = false }, slot)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, gloss)

	-- the mallet, drawn from frames
	local icon = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(62, 62), BackgroundTransparency = 1 }, slot)
	local function sh(x, y, w, h, rot, round, col)
		local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), Rotation = rot or 0, BackgroundColor3 = col, Active = false }, icon)
		make("UICorner", { CornerRadius = UDim.new(round or 0.5, 0) }, f)
		return f
	end
	sh(0.5, 0.6, 0.12, 0.46, 0, 0.3, Color3.fromRGB(165, 105, 62)) -- shaft (upright, like the real thing)
	sh(0.5, 0.84, 0.15, 0.09, 0, 0.5, GOLDC) -- pommel
	sh(0.5, 0.26, 0.68, 0.34, 0, 0.35, PINKC) -- head
	sh(0.31, 0.26, 0.07, 0.36, 0, 0.2, GOLDC) -- gold bands
	sh(0.69, 0.26, 0.07, 0.36, 0, 0.2, GOLDC)
	sh(0.42, 0.22, 0.1, 0.1, 0, 0.5, WHITE) -- eyes
	sh(0.58, 0.22, 0.1, 0.1, 0, 0.5, WHITE)
	sh(0.42, 0.235, 0.05, 0.05, 0, 0.5, Color3.fromRGB(30, 20, 40))
	sh(0.58, 0.235, 0.05, 0.05, 0, 0.5, Color3.fromRGB(30, 20, 40))
	label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.fromOffset(80, 16), TextSize = 12, Text = "WACKER" }, slot)
	if not isTouch then
		local keyBadge = make("Frame", { Position = UDim2.fromOffset(-6, -6), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = GOLDC, ZIndex = 6 }, slot)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, keyBadge)
		make("UIStroke", { Thickness = 2.5, Color = Color3.fromRGB(120, 70, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, keyBadge)
		label({ Size = UDim2.fromScale(1, 1), TextSize = 16, TextColor3 = Color3.fromRGB(90, 40, 0), Text = "1", ZIndex = 7 }, keyBadge):FindFirstChildOfClass("UIStroke").Thickness = 0
	end
	local cd = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 0.4, ZIndex = 5, Active = false }, slot)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, cd)
	local hitFlash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 6, Active = false }, slot)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, hitFlash)
	local tip = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.fromOffset(170, 20), TextSize = 14, TextColor3 = Color3.fromRGB(255, 225, 240), Text = isTouch and "TAP TO WHACK!" or "CLICK TO WHACK!", Visible = false }, slot)

	local punch, wasEquipped = 0, false
	local function getTool()
		local char = player.Character
		if not char then
			return nil, false, nil
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local eq = char:FindFirstChild("Wacker")
		if eq then
			return eq, true, hum
		end
		local bp = player:FindFirstChildOfClass("Backpack")
		return bp and bp:FindFirstChild("Wacker"), false, hum
	end
	local function toggle()
		if (player:GetAttribute("Carrying") or 0) > 0 then
			toast("Your hands are full! Drop the Goober first (Q)", GOLD)
			return
		end
		local tool, equipped, hum = getTool()
		if not tool or not hum then
			return
		end
		if equipped then
			hum:UnequipTools()
		else
			hum:EquipTool(tool)
		end
	end
	slot.Activated:Connect(toggle)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		if (player:GetAttribute("Carrying") or 0) > 0 then
			local _, equipped, hum = getTool()
			if equipped and hum then
				hum:UnequipTools() -- picking something up puts the Wacker away automatically
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.One then
			toggle()
		end
	end)
	function wackPunch()
		punch = 1
		hitFlash.BackgroundTransparency = 0.35
		tween(hitFlash, 0.3, { BackgroundTransparency = 1 })
	end
	RunService.RenderStepped:Connect(function(dt)
		if player:GetAttribute("HasWacker") ~= true then
			slot.Visible = false
			return
		end
		slot.Visible = true
		local _, equipped = getTool()
		local t = os.clock()
		if equipped and not wasEquipped then
			play("pop")
			slotScale.Scale = 1.35 -- pops when you pull it out
		end
		wasEquipped = equipped
		slotScale.Scale += ((equipped and 1.12 or 1) - slotScale.Scale) * math.min(1, dt * 10)
		punch = math.max(0, punch - dt * 3.5)
		icon.Rotation = (equipped and math.sin(t * 4) * 8 or 0) - 60 * punch
		slotStroke.Color = equipped and PINKC:Lerp(GOLDC, (math.sin(t * 5) + 1) / 2) or PINKC:Lerp(BLACK, 0.35)
		slotStroke.Thickness = equipped and 5 or 3
		tip.Visible = equipped
		local left = (player:GetAttribute("WackReadyAt") or 0) - workspace:GetServerTimeNow()
		cd.Size = UDim2.fromScale(1, math.clamp(left / Config.WackCooldown, 0, 1))
	end)
end

----------------------------------------------------------------
-- TUTORIAL (new players only): an arrow + glowing beam points you to the next thing to do.
--   1. grab a Goober   2. bring it to your base   3. step on the pad to get cash   4. upgrade it
----------------------------------------------------------------
do
	local active = false
	local tutBanner = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(360, 48), Visible = false, ZIndex = 6 }, gui)
	tutBanner:FindFirstChildOfClass("UIStroke").Color = GOLD
	local tutText = label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -84, 1, 0), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, tutBanner)
	local skipBtn = makeButton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(60, 32), TextSize = 14, Text = "SKIP" }, tutBanner, GREY)

	-- arrow that floats above the target (3D)
	local marker = Instance.new("Part")
	marker.Name = "TutorialMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(70, 80)
	bb.AlwaysOnTop = true
	bb.Adornee = marker
	bb.Parent = marker
	local arrow = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(34, 34), Rotation = 45, BackgroundColor3 = GOLD }, bb)
	corner(arrow, 6)
	stroke(arrow, 3)
	local distL = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(70, 24), TextSize = 18, Text = "" }, bb)

	-- glowing beam from you to the target
	local attTarget = Instance.new("Attachment")
	attTarget.Parent = marker
	local beam = Instance.new("Beam")
	beam.Attachment1 = attTarget
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90))
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(0.35)
	beam.Segments = 1
	beam.Parent = marker
	local attPlayer

	-- arrow on the edge of the screen when the target is out of view
	local edge = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 30 }, screen)
	local ec = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = GOLD, ZIndex = 30 }, edge)
	corner(ec, 19)
	stroke(ec, 3)
	local nose = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(26, 0), Size = UDim2.fromOffset(18, 18), Rotation = 45, BackgroundColor3 = GOLD, ZIndex = 29 }, edge)
	corner(nose, 3)
	stroke(nose, 3)

	local function plotModel()
		local w = workspace:FindFirstChild("GooberWorld")
		local idx = player:GetAttribute("PlotIndex")
		return w and idx and w:FindFirstChild("Plot" .. idx)
	end
	local function myPos()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return hrp and hrp.Position, hrp
	end
	local function nearestGoober()
		local pos = myPos()
		local best, bestD = nil, math.huge
		if not pos then
			return nil
		end
		for _, m in ipairs(CollectionService:GetTagged("WalkGoober")) do
			local p = m.PrimaryPart
			if p then
				local d = (p.Position - pos).Magnitude
				if d < bestD then
					best, bestD = p, d
				end
			end
		end
		return best
	end
	local function inPlot(name)
		return function()
			local pm = plotModel()
			return pm and pm:FindFirstChild(name, true)
		end
	end

	local steps = {
		{ Text = "1/4  Grab a Goober!", Target = nearestGoober, Done = function() return (player:GetAttribute("Carrying") or 0) > 0 or (player:GetAttribute("UsedSlots") or 0) > 0 end },
		{ Text = "2/4  Take it to your base!", Target = inPlot("DepositPad"), Done = function() return (player:GetAttribute("UsedSlots") or 0) > 0 end },
		{ Text = "3/4  Step on the glowing pad!", Target = inPlot("CollectPad1"), Done = function() return (player:GetAttribute("Collects") or 0) > 0 end },
		{ Text = "4/4  Upgrade it with the button!", Target = inPlot("UpgradeButton1"), Done = function() return (player:GetAttribute("GooberUpgrades") or 0) > 0 end, Timeout = 14 },
	}

	local conn
	local function finish(silent)
		if conn then
			conn:Disconnect()
			conn = nil
		end
		active = false
		tutBanner.Visible = false
		marker.Parent = nil
		edge.Visible = false
		beam.Attachment0 = nil
		if attPlayer then
			attPlayer:Destroy()
			attPlayer = nil
		end
		Action:FireServer("TutorialDone")
		if not silent then
			toast("You're ready - have fun!", GREEN, "reveal")
		end
	end
	skipBtn.Activated:Connect(function()
		finish(true)
	end)

	function startTutorial()
		if active then
			return
		end
		active = true
		local step, stepStart = 1, os.clock()
		tutBanner.Visible = true
		tutText.Text = steps[1].Text
		marker.Parent = workspace
		conn = RunService.RenderStepped:Connect(function()
			local s = steps[step]
			local t = os.clock()
			if s.Done() or (s.Timeout and t - stepStart > s.Timeout) then
				step += 1
				stepStart = t
				if step > #steps then
					finish(false)
					return
				end
				s = steps[step]
				tutText.Text = s.Text
				play("pop")
			end
			if activeMenu then -- a window is open: stay quiet so nothing distracts the player
				tutBanner.Visible = false
				edge.Visible = false
				bb.Enabled = false
				beam.Enabled = false
				return
			end
			tutBanner.Visible = true
			local target = s.Target()
			local pos, hrp = myPos()
			if not target or not pos or not hrp then
				bb.Enabled = false
				edge.Visible = false
				beam.Enabled = false
				return
			end
			bb.Enabled = true
			beam.Enabled = true
			if not attPlayer or attPlayer.Parent ~= hrp then
				if attPlayer then
					attPlayer:Destroy()
				end
				attPlayer = Instance.new("Attachment")
				attPlayer.Parent = hrp
				beam.Attachment0 = attPlayer
			end
			local tp = target.Position
			marker.Position = tp + Vector3.new(0, target.Size.Y / 2 + 3.5 + math.sin(t * 5) * 0.6, 0)
			distL.Text = math.floor((tp - pos).Magnitude) .. "m"
			-- off-screen indicator
			local v, on = camera:WorldToViewportPoint(tp)
			if on then
				edge.Visible = false
			else
				local vs = camera.ViewportSize
				local center = vs / 2
				local dir = Vector2.new(v.X, v.Y) - center
				if v.Z < 0 then
					dir = -dir
				end
				if dir.Magnitude < 1 then
					dir = Vector2.new(0, -1)
				end
				dir = dir.Unit
				local sx = (vs.X / 2 - 60) / math.max(math.abs(dir.X), 0.001)
				local sy = (vs.Y / 2 - 100) / math.max(math.abs(dir.Y), 0.001)
				local p = center + dir * math.min(sx, sy)
				edge.Position = UDim2.fromOffset(p.X, p.Y)
				edge.Rotation = math.deg(math.atan2(dir.Y, dir.X))
				edge.Visible = true
			end
		end)
	end
end

----------------------------------------------------------------
-- ADMIN: FLY (toggle from the admin menu). Camera-relative, Space = up, Shift/Q = down.
----------------------------------------------------------------
do
	local flyConn, flyLV, flyAtt
	local function stopFly()
		if flyConn then
			flyConn:Disconnect()
			flyConn = nil
		end
		if flyLV then
			flyLV:Destroy()
			flyLV = nil
		end
		if flyAtt then
			flyAtt:Destroy()
			flyAtt = nil
		end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
		end
		flyOn = false
	end
	function setFly(on)
		stopFly()
		if not on or player:GetAttribute("IsAdmin") ~= true then
			return
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp then
			return
		end
		flyOn = true
		flyAtt = Instance.new("Attachment")
		flyAtt.Parent = hrp
		flyLV = Instance.new("LinearVelocity")
		flyLV.Attachment0 = flyAtt
		flyLV.MaxForce = 1e8
		flyLV.RelativeTo = Enum.ActuatorRelativeTo.World
		flyLV.VectorVelocity = Vector3.new(0, 0, 0)
		flyLV.Parent = hrp
		hum.PlatformStand = true
		flyConn = RunService.RenderStepped:Connect(function()
			local look = camera.CFrame.LookVector
			local move = hum.MoveDirection
			local v = Vector3.new(0, 0, 0)
			if move.Magnitude > 0.1 then
				local flat = Vector3.new(look.X, 0, look.Z)
				local fwd = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
				v = move * flySpeed + Vector3.new(0, look.Y * move:Dot(fwd) * flySpeed, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) or hum.Jump then
				v += Vector3.new(0, flySpeed, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
				v -= Vector3.new(0, flySpeed, 0)
			end
			flyLV.VectorVelocity = v
		end)
	end
	player.CharacterAdded:Connect(stopFly)
end

-- press U to open the admin menu (only the developer has this attribute; the server double-checks every command)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.U and player:GetAttribute("IsAdmin") == true then
		toggleMenu("admin")
	end
end)

-- the camera opens up a little when you run fast
RunService.RenderStepped:Connect(function(dt)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and camera.CameraType == Enum.CameraType.Custom then
		local target = 70 + math.clamp((hum.WalkSpeed - 20) / 6, 0, 16)
		camera.FieldOfView += (target - camera.FieldOfView) * math.min(1, dt * 4)
	end
end)

----------------------------------------------------------------
-- HUD LOOP
----------------------------------------------------------------
local function chipText(kind)
	local exp = player:GetAttribute("Boost" .. kind) or 0
	local remaining = exp - workspace:GetServerTimeNow()
	if remaining > 0 then
		return ("%s %ds"):format(kind:upper(), math.ceil(remaining))
	end
	return nil
end

task.spawn(function()
	while true do
		local income = player:GetAttribute("Income") or 0
		local mult = player:GetAttribute("Multiplier") or 1
		incomeL.Text = ("+$%s/s%s"):format(F(income), mult > 1 and ("   x" .. tostring(mult)) or "")
		bagChip.Text = ("BAG %d/%d"):format(player:GetAttribute("Carrying") or 0, player:GetAttribute("CarryCap") or 1)
		baseChip.Text = ("BASE %d/%d"):format(player:GetAttribute("UsedSlots") or 0, player:GetAttribute("MaxSlots") or 4)
		rebChip.Text = "R" .. (player:GetAttribute("Rebirths") or 0) .. (player:GetAttribute("Locked") and " LOCK" or "")

		-- perk chips: pop in when a boost starts, pulse gently while active, and hide the tooltip if its chip vanished
		for kind, info in pairs(boostChips) do
			local txt = chipText(kind)
			local wasVisible = info.Chip.Visible
			info.Chip.Visible = txt ~= nil
			if txt then
				info.Label.Text = txt
				if not wasVisible then
					local sc = info.Chip:FindFirstChildOfClass("UIScale") or make("UIScale", { Scale = 0.4 }, info.Chip)
					tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				end
				info.Stroke.Color = info.Col:Lerp(WHITE, (math.sin(os.clock() * 4) + 1) / 2 * 0.4) -- a gentle pulse while active
			elseif wasVisible then
				boostTip.Visible = false -- don't leave a tooltip open for a perk that just ran out
			end
		end
		do
			local lockedUntil = player:GetAttribute("LockedUntil") or 0
			local lockLeft = lockedUntil - workspace:GetServerTimeNow()
			local wasVisible = lockChip.Visible
			lockChip.Visible = lockLeft > 0
			if lockLeft > 0 then
				lockChipLabel.Text = ("LOCKED %ds"):format(math.ceil(lockLeft))
				if not wasVisible then
					local sc = lockChip:FindFirstChildOfClass("UIScale") or make("UIScale", { Scale = 0.4 }, lockChip)
					tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				end
				lockChipStroke.Color = Color3.fromRGB(120, 130, 255):Lerp(WHITE, (math.sin(os.clock() * 4) + 1) / 2 * 0.4)
			elseif wasVisible then
				boostTip.Visible = false
			end
		end

		-- progressive text: a new player sees only the essentials; more shows up as you reach each zone
		local maxZone = player:GetAttribute("MaxZone") or 0
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local curZone, safe = 0, false
		if hrp then
			local p = hrp.Position
			curZone = Config.ZoneAtX(p.X)
			if math.abs(p.Z) > Config.RunwayWidth / 2 + 1 and p.X > Config.RunwayStart then
				for _, sh in ipairs(Config.Shelters) do
					if math.abs(p.X - sh.X) <= Config.ShelterWidth / 2 + 1 and (p.Z > 0) == (sh.Side > 0) then
						safe = true
						break
					end
				end
			end
		end
		updateZoneTag(curZone, safe)
		updateTrack(hrp and hrp.Position.X or 0)
		for _, zs in ipairs(CollectionService:GetTagged("ZoneSign")) do
			zs.Enabled = (zs:GetAttribute("Zone") or 99) <= maxZone + 1
		end
		if flyOn and player:GetAttribute("IsAdmin") ~= true then
			setFly(false)
		end
		if activeMenu == "admin" and player:GetAttribute("IsAdmin") ~= true then
			closeMenus(true)
		end

		-- flood banner (short!)
		local state = workspace:GetAttribute("WaveState")
		local name = workspace:GetAttribute("WaveName") or "FLOOD"
		local nextIn = workspace:GetAttribute("NextWave") or 0
		local jumpable = workspace:GetAttribute("WaveJumpable")
		if state == "Warning" then
			bannerText.Text = waveTag(name) .. ("%s in %ds!"):format(name, nextIn)
			bannerText.TextColor3 = RED
		elseif state == "Active" then
			bannerText.Text = waveTag(name) .. name .. (jumpable and " - JUMP!" or " - HIDE!")
			bannerText.TextColor3 = jumpable and Color3.fromRGB(255, 230, 120) or RED
		else
			bannerText.Text = ("Next flood in %ds"):format(nextIn)
			bannerText.TextColor3 = WHITE
		end
		eventL.Text = (maxZone >= 1) and (workspace:GetAttribute("Event") or "") or ""
		banner.Visible = state == "Warning" or state == "Active" or maxZone >= 1
		do
			local mutName = workspace:GetAttribute("MutationEventName") or ""
			mutationIcon.Visible = mutName ~= ""
			if mutName ~= "" then
				local mutDef = Config.Mutations[mutName]
				mutationTipDesc.Text = mutName .. " Goobers are everywhere! Perk: " .. (mutDef and (mutDef.PerkText or mutDef.Perk) or "")
			end
		end

		-- trap button + trade button + side button badges
		local traps = player:GetAttribute("Traps") or 0
		trapBtn.Visible = traps > 0
		trapBtn.Text = (isTouch and "TRAP x%d" or "PLACE TRAP x%d [T]"):format(traps)
		if player:GetAttribute("TradeOK") then
			tradeLabel.Text = "TRADE"
			tradeLabel.TextSize = 19
		else
			tradeLabel.Text = "TRADE " .. fmtTime(Config.TradeUnlockSeconds - (player:GetAttribute("PlayTime") or 0))
			tradeLabel.TextSize = 14
		end
		dailyBadge.Visible = player:GetAttribute("DailyReady") == true
		do
			local gCsv, pCsv = player:GetAttribute("IndexG") or "", player:GetAttribute("IndexP") or ""
			local n = 0
			for _ in gCsv:gmatch("[^,]+") do n += 1 end
			for _ in pCsv:gmatch("[^,]+") do n += 1 end
			indexBadge.Visible = n > indexSeenTotal
		end
		if player:GetAttribute("Own_AutoCollect") == true then
			collectBtn.Text = "💰 COLLECT ALL"
			collectBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
		else
			collectBtn.Text = "🔒 AUTO COLLECTOR - GET IT"
			collectBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 170)
		end
		local spins = player:GetAttribute("Spins") or 0
		spinCountL.Text = tostring(spins)
		spinBanner.Visible = spins > 0
		if spins > 0 then
			spinBanner.Text = ("🎡 You have %d free spin%s!"):format(spins, spins > 1 and "s" or "")
		end
		if spins >= Config.SpinMax then
			spinTimerL.Text = "MAX"
		else
			local lastRegen = player:GetAttribute("LastSpinRegen") or os.time()
			local left = math.max(0, Config.SpinRegenSeconds - (os.time() - lastRegen))
			spinTimerL.Text = ("Next spin\n%d:%02d"):format(left // 60, left % 60)
		end
		adminBtn.Visible = player:GetAttribute("IsAdmin") == true

		updateShop()
		updateNpc()
		updateDeals()
		refreshPets()
		refreshIndex()
		updateDock()
		updateStand()
		updateRebirth()
		updateEggButtons()
		updateDaily()
		updateGroup()
		updateAdmin()
		syncPets()
		if not inTrade then
			refreshTradeList()
		end
		task.wait(0.25)
	end
end)

----------------------------------------------------------------
-- MOBILE: less text in the way. Phones have a small screen, so world labels (Goober names/incomes, pads, signs, egg tags)
-- are drawn smaller and only when you are closer, and the extra HUD text lines are removed (the Mutation Hour icon
-- and the spin wheel's counter already show the same info).
----------------------------------------------------------------
if isTouch then
	eventL.Parent = nil
	spinBanner.Parent = nil
	local function tune(bb)
		if not bb:IsA("BillboardGui") or bb:GetAttribute("MobileTuned") then
			return
		end
		bb:SetAttribute("MobileTuned", true)
		bb.Size = UDim2.new(bb.Size.X.Scale * 0.75, bb.Size.X.Offset * 0.75, bb.Size.Y.Scale * 0.75, bb.Size.Y.Offset * 0.75)
		if bb.MaxDistance > 0 and bb.MaxDistance < math.huge then
			bb.MaxDistance = math.max(22, bb.MaxDistance * 0.55)
		else
			bb.MaxDistance = 120
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		tune(d)
	end
	workspace.DescendantAdded:Connect(tune)
end

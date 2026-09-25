--[[
	GRAB A GOOBER: ESCAPE THE FLOOD  -  SERVER  (v4)
	Script type : Script (normal Script, NOT LocalScript)
	Name        : GameServer
	Location    : ServerScriptService

	Builds the whole world (plaza, shop NPC, runway, 12 zones, bases with floors,
	walls, scenery) and runs Goobers, random floods, income, wackers, traps,
	trading, stealing, upgrades, codes, saving and Robux items.
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(RS:WaitForChild("Config"))
local Creatures = require(RS:WaitForChild("Creatures"))

local RW = Config.RunwayWidth
local ZONES = Config.ZoneCount
local RS_START = Config.RunwayStart
local RUNWAY_END = Config.RunwayEnd
local HUB_BACK = Config.HubBack
local HUB_HALF_Z = Config.PlotCount * Config.PlotSpacing / 2 + 20

local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(90, 255, 130)
local GOLD = Color3.fromRGB(255, 215, 80)
local WHITE = Color3.new(1, 1, 1)

----------------------------------------------------------------
-- REMOTES
----------------------------------------------------------------
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
local function newRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end
local ActionRemote = newRemote("Action") -- client -> server
local NotifyRemote = newRemote("Notify") -- server -> client toasts (+ sound)
local AnnounceRemote = newRemote("Announce") -- big flood announcements
local UIRemote = newRemote("UI") -- server -> client: open shop, trade state, reveal...
Remotes.Parent = RS

local okStore, Store = pcall(function()
	return DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not okStore then
	Store = nil
end

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local Data = {} -- [player] = save data
local Carrying = {} -- [player] = { {Id=, Mut=}, ... }
local PlotOf = {} -- [player] = plot
local SaveAllowed = {} -- [player] = true if data loaded OK (protects against overwriting)
local OwnsPass = {} -- [player] = { Thief = true, ... }
local LastAction = {}
local LastSweep = {}
local LastTP = {}
local LastWack = {}
local Stunned = {} -- [player] = os.clock() time when the stun ends
local Boosts = {} -- [player] = { Speed = t, Jump = t, Shield = t } (server time)
local Trades = {} -- [player] = trade session
local Invites = {} -- [target player] = { From = player, Time = clock }
local TrapList = {}
local PickupInfo = {} -- [pickup model] = { Grab = function } (used by the Magnet Potion)
local GodMode = {} -- admin: [player] = true
local NoGrab = {} -- [player] = os.clock() until which they can't pick up goobers (after dropping one)
local MagnetFilter = {} -- [player] = { [rarityRank] = true }: which rarities the Magnet Potion pulls in
local TempAdmins = {} -- [userId] = os.clock() when the temporary admin ends (math.huge = until they leave)
local WavesPaused = false
local MutationEvent = false -- during a Mutation Hour: the name of the event mutation it picked ("Galaxy" / "Chocolate" / "Toxic")
local Plots = {}
local rng = Random.new()

local World = Instance.new("Folder")
World.Name = "GooberWorld"
World.Parent = Workspace

local function newFolder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = World
	return f
end
local Pickups = newFolder("Pickups")
local Decor = newFolder("Decor")
local Walls = newFolder("Walls")
local FloorFolder = newFolder("Floor")
local TrapFolder = newFolder("Traps")

-- forward declarations (functions defined further down)
local stealGoober
local sellGoober
local saveData
local pushTrade
local spawnPickup
local triggerWave -- (defined with the floods)
local clearWaves
local respawnAllPickups
local isAdmin
local isHost
local applyVipAccess -- (defined with the VIP code)
local wipeLeaderboards

----------------------------------------------------------------
-- SMALL HELPERS
----------------------------------------------------------------
local function notify(player, msg, color, sfx)
	NotifyRemote:FireClient(player, msg, color or WHITE, sfx)
end

local function notifyAll(msg, color, sfx)
	NotifyRemote:FireAllClients(msg, color or WHITE, sfx)
end

local function announceToChat(text) -- posts to ROBLOX's own chat (every player sees it there, in a bubbly font) - not the in-game toast
	UIRemote:FireAllClients("ChatAnnounce", text)
end

local DIM_TARGET = Color3.fromRGB(35, 38, 60)
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	-- make the whole world less bright (Config.DimAmount)
	if props.Color and Config.DimAmount > 0 and p.Material ~= Enum.Material.Glass then
		local amount = (p.Material == Enum.Material.Neon) and Config.DimAmount * 0.5 or Config.DimAmount
		p.Color = props.Color:Lerp(DIM_TARGET, amount)
	end
	p.Parent = parent
	if parent == Decor and props.CastShadow == nil then
		p.CastShadow = false -- decorative dressing never needs to cast a shadow (keeps the world light on phones)
	end
	return p
end

local function billboard(parent, text, color, offset, size, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Size = size or UDim2.fromOffset(200, 50)
	bb.StudsOffset = offset or Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = maxDist or 100
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextColor3 = color or WHITE
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Color3.new(0, 0, 0)
	st.Parent = tl
	bb.Parent = parent
	return bb, tl
end

-- Builds a Goober model (cat, bunny, robot, dragon... depends on its style). See the Creatures module.
local function buildGoober(id, mutation, size, cf, anchored, parent)
	return Creatures.Build(Creatures.SpecForGoober(id, mutation), size, cf, anchored, parent)
end

local function itemName(item)
	local prefix = (item.Mut ~= "Normal") and (item.Mut .. " ") or ""
	return prefix .. item.Id
end

-- event-mutation perks (Galaxy / Chocolate / Toxic) from the Goobers placed in this player's base.
-- (plain globals, not locals: this file is close to Luau's 200-local limit)
function perksOf(d)
	return Config.MutationPerks(d.Placed, Config.MaxSlots(d.SlotLvl, d.FloorLvl))
end
function carryCapOf(d)
	return Config.CarryCap(d.CarryLvl) + perksOf(d).Carry
end

local function itemIncome(item)
	local base = Config.GooberById[item.Id].Income * Config.Mutations[item.Mut].Mult
	return base * (1 + Config.GooberLevelBonus * (item.Lvl or 0))
end

-- where a player appears in their base: facing FORWARD (+X, towards the plaza)
local function spawnCFrame(plot)
	return CFrame.new(plot.Spawn.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, -math.pi / 2, 0)
end

local function rarityColor(item)
	return Config.Rarities[Config.GooberById[item.Id].Rarity].Color
end

local function shopPrice(d, def)
	local n = (d.ShopBuys and d.ShopBuys[def.Id]) or 0
	return math.floor(def.Price * (def.Growth or Config.ShopPriceGrowth) ^ n)
end

local function petBonus(d)
	local cash, speed = 0, 0
	for _, id in ipairs(d.Pets) do
		local p = Config.PetById[id]
		if p then
			cash += p.Cash
			speed += p.Speed
		end
	end
	return math.min(cash, Config.PetCashCap), speed -- (the cash bonus from pets has a cap)
end

local function computeMult(player, d)
	local m = Config.Multiplier(d.Rebirths) * (1 + (petBonus(d)))
	if OwnsPass[player] and OwnsPass[player].DoubleCash then
		m *= 2
	end
	if OwnsPass[player] and OwnsPass[player].VIP then
		m *= Config.VIP.IncomeMult -- VIP perk
	end
	local b = Boosts[player]
	if b and (b.Cash or 0) > Workspace:GetServerTimeNow() then
		m *= 2 -- Cash Potion
	end
	return m
end

-- only Goobers that have a pedestal earn money
local function computeIncome(player, d)
	local total = 0
	local maxSlots = Config.MaxSlots(d.SlotLvl, d.FloorLvl)
	for i, item in ipairs(d.Placed) do
		if i <= maxSlots then
			total += itemIncome(item)
		end
	end
	return total * computeMult(player, d)
end

----------------------------------------------------------------
-- BASE RENDERING (floors, glowing pedestals, animated Goobers, collect pads, upgrade buttons)
----------------------------------------------------------------
local function setFloors(plot, count)
	for k = 2, Config.MaxFloors do
		local fm = plot.FloorModels[k]
		local show = k <= count
		if (fm.Parent ~= nil) ~= show then
			fm.Parent = show and plot.Model or nil
		end
	end
end

local PAD_ON = Color3.fromRGB(255, 200, 60)
local PAD_OFF = Color3.fromRGB(80, 86, 110)

-- keeps the "$stored" label and glow of a collect pad up to date
local function refreshPad(plot, s, item)
	local pad, gui = plot.Pads[s], plot.PadGuis[s]
	if not item then
		pad.Transparency = 1
		pad.CanTouch = false
		gui.Enabled = false
		plot.PadOn[s] = nil
		return
	end
	pad.Transparency = 0.1
	pad.CanTouch = true
	gui.Enabled = true
	local stored = math.floor(item.Stored or 0)
	local text = "$" .. Config.Format(stored)
	local label = plot.PadLabels[s]
	if label.Text ~= text then
		label.Text = text
	end
	local on = stored >= 1
	if plot.PadOn[s] ~= on then
		plot.PadOn[s] = on
		pad.Color = on and PAD_ON or PAD_OFF
		label.TextColor3 = on and Color3.fromRGB(255, 235, 140) or Color3.fromRGB(170, 175, 200)
	end
end

local function renderBase(player)
	local plot, d = PlotOf[player], Data[player]
	if not plot or not d then
		return
	end
	local locked = plot.Locked
	local maxSlots = Config.MaxSlots(d.SlotLvl, d.FloorLvl)
	setFloors(plot, 1 + d.FloorLvl)
	for k = 1, Config.MaxFloors - 1 do
		plot.UpPrompts[k].Enabled = d.FloorLvl >= k
		plot.DownPrompts[k + 1].Enabled = d.FloorLvl >= k
	end
	plot.SignLabel.Text = player.DisplayName .. "'s Base" .. (locked and "  [LOCKED]" or "")
	local face = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(player.UserId)
	plot.SignFace.Image = face
	plot.SignFace.Visible = true
	plot.GateFace.Image = face
	plot.FaceGui.Enabled = true

	for s = 1, Config.TotalSlots do
		local ped, ring = plot.Pedestals[s], plot.Rings[s]
		local old = plot.Models[s]
		if old then
			old:Destroy()
			plot.Models[s] = nil
		end
		local item = (s <= maxSlots) and d.Placed[s] or nil
		if s > maxSlots then
			ped.Color = Color3.fromRGB(50, 50, 50)
			ped.Transparency = 0.6
			ring.Transparency = 1
		elseif not item then
			ped.Transparency = 0
			ped.Color = Color3.fromRGB(225, 225, 235)
			ring.Color = WHITE
			ring.Transparency = 0.7
		else
			ped.Transparency = 0
			ped.Color = Color3.fromRGB(255, 215, 90)
			ring.Color = rarityColor(item)
			ring.Transparency = 0.1

			-- the Goober lives in a Model so it can be animated (the client makes it hop and look around)
			local model = Instance.new("Model")
			model.Name = "BaseGoober"
			local top = ped.Position.Y + ped.Size.Y / 2
			-- faces +X = forward, towards the plaza and the runway
			local gy = top + Creatures.HalfHeight(Creatures.SpecForGoober(item.Id, item.Mut), 4) + 0.15
			local cf = CFrame.new(ped.Position.X, gy, ped.Position.Z) * CFrame.Angles(0, -math.pi / 2, 0)
			local ball = buildGoober(item.Id, item.Mut, 4, cf, true, model)
			model.PrimaryPart = ball
			model:SetAttribute("HX", ped.Position.X)
			model:SetAttribute("HY", gy)
			model:SetAttribute("HZ", ped.Position.Z)
			model:SetAttribute("Yaw", -math.pi / 2)
			model:SetAttribute("Seed", s * 1.7)
			model.Parent = plot.FloorModels[math.ceil(s / Config.SlotsPerFloor)]
			CollectionService:AddTag(model, "IdleGoober")
			plot.Models[s] = model

			local lvl = item.Lvl or 0
			local text = itemName(item) .. (lvl > 0 and ("  Lv" .. lvl) or "") .. "\n$" .. Config.Format(itemIncome(item)) .. "/s"
			billboard(ball, text, rarityColor(item), Vector3.new(0, 3.8, 0), UDim2.fromOffset(220, 60), 90)

			local light = Instance.new("PointLight")
			light.Color = rarityColor(item)
			light.Range = 12
			light.Brightness = 1
			light.Parent = ball

			if item.Mut ~= "Normal" then
				local mutDef = Config.Mutations[item.Mut]
				ball.Reflectance = 0.35
				light.Range = 20
				light.Brightness = 2.2
				local mutTag = billboard(ball, "✨ " .. item.Mut:upper() .. " ✨", (mutDef and mutDef.Color) or GOLD, Vector3.new(0, 5.3, 0), UDim2.fromOffset(180, 30), 90)
				mutTag.Name = "MutationTag"
			end

			-- STEAL prompt (everyone except the owner sees this; the client hides it for the owner)
			local pp = Instance.new("ProximityPrompt")
			pp.Name = "StealPrompt"
			pp.ActionText = "Steal"
			pp.ObjectText = itemName(item)
			pp.HoldDuration = 3
			pp.MaxActivationDistance = 10
			pp.RequiresLineOfSight = false
			pp.Enabled = not locked
			pp:SetAttribute("OwnerId", player.UserId)
			pp:SetAttribute("Slot", s)
			pp.Parent = ball
			CollectionService:AddTag(pp, "StealPrompt")
			pp.Triggered:Connect(function(thief)
				stealGoober(thief, player, s)
			end)

			-- SELL prompt (only the owner sees this; hold F)
			local sp = Instance.new("ProximityPrompt")
			sp.Name = "SellPrompt"
			sp.ActionText = "Sell"
			sp.ObjectText = "$" .. Config.Format(itemIncome(item) * Config.SellMultiplier)
			sp.KeyboardKeyCode = Enum.KeyCode.F
			sp.GamepadKeyCode = Enum.KeyCode.ButtonX
			sp.HoldDuration = 2
			sp.MaxActivationDistance = 10
			sp.RequiresLineOfSight = false
			sp:SetAttribute("OwnerId", player.UserId)
			sp.Parent = ball
			CollectionService:AddTag(sp, "SellPrompt")
			sp.Triggered:Connect(function(who)
				if who == player then
					sellGoober(player, s)
				end
			end)
		end

		-- collect pad + upgrade button (only for slots that hold a Goober)
		refreshPad(plot, s, item)
		local btn, bgui, blabel, bprompt = plot.Buttons[s], plot.ButtonGuis[s], plot.ButtonLabels[s], plot.ButtonPrompts[s]
		if item then
			local lvl = item.Lvl or 0
			local maxed = lvl >= Config.GooberMaxLevel
			local baseInc = Config.GooberById[item.Id].Income * Config.Mutations[item.Mut].Mult
			btn.Transparency = 0.1
			bgui.Enabled = true
			blabel.Text = maxed and "MAX" or ("LV " .. lvl .. "\n$" .. Config.Format(Config.GooberUpgradeCost(baseInc, lvl)))
			bprompt.Enabled = not maxed
			bprompt.ObjectText = "Lv " .. lvl
			bprompt:SetAttribute("OwnerId", player.UserId)
		else
			btn.Transparency = 1
			bgui.Enabled = false
			bprompt.Enabled = false
		end
	end
end

local function clearPlot(plot)
	for s, ped in ipairs(plot.Pedestals) do
		local old = plot.Models[s]
		if old then
			old:Destroy()
			plot.Models[s] = nil
		end
		ped.Color = Color3.fromRGB(50, 50, 50)
		ped.Transparency = 0.6
		plot.Rings[s].Transparency = 1
		refreshPad(plot, s, nil)
		plot.Buttons[s].Transparency = 1
		plot.ButtonGuis[s].Enabled = false
		plot.ButtonPrompts[s].Enabled = false
	end
	setFloors(plot, 1)
	for k = 1, Config.MaxFloors - 1 do
		plot.UpPrompts[k].Enabled = false
		plot.DownPrompts[k + 1].Enabled = false
	end
	plot.SignLabel.Text = "Unclaimed"
	plot.SignFace.Visible = false
	plot.FaceGui.Enabled = false
end

----------------------------------------------------------------
-- STATS (replicated to the client through Attributes)
----------------------------------------------------------------
-- Daily reward state: (ready to claim?, which day is next, how many days are ticked, today's day number)
local function dailyInfo(d)
	local today = math.floor(os.time() / Config.DayLength)
	if d.DailyLast > 0 and today - d.DailyLast > 1 then
		d.DailyStreak = 0 -- missed a day: the streak starts over
	end
	local claimedToday = d.DailyLast >= today and d.DailyLast > 0
	local done = d.DailyStreak
	if claimedToday and d.DailyStreak == 0 then
		done = 7
	end
	return not claimedToday, d.DailyStreak + 1, done, today
end

local function updateStats(player)
	local d = Data[player]
	if not d then
		return
	end
	-- INDEX: the instant you discover a Goober or Pet you've never had before, you get a one-time cash reward
	-- scaled by its rarity (paid once ever, tracked in the Index so it can never be re-triggered by selling/re-finding)
	do
		local I = d.Index
		for _, item in ipairs(d.Placed) do
			if not I.G[item.Id] then
				I.G[item.Id] = true
				local def = Config.GooberById[item.Id]
				local reward = def and Config.Index.GooberReward[def.Rarity]
				if reward then
					d.Cash += reward
					notify(player, ("NEW GOOBER DISCOVERED: %s!  +$%s"):format(item.Id, Config.Format(reward)), GOLD, "reveal")
				end
			end
		end
		for _, id in ipairs(d.Pets) do
			if not I.P[id] then
				I.P[id] = true
				local def = Config.PetById[id]
				local reward = def and Config.Index.PetReward[def.Rarity]
				if reward then
					d.Cash += reward
					notify(player, ("NEW PET DISCOVERED: %s!  +$%s"):format(id, Config.Format(reward)), GOLD, "reveal")
				end
			end
		end
		for _, id in ipairs(d.PetBox) do
			if not I.P[id] then
				I.P[id] = true
				local def = Config.PetById[id]
				local reward = def and Config.Index.PetReward[def.Rarity]
				if reward then
					d.Cash += reward
					notify(player, ("NEW PET DISCOVERED: %s!  +$%s"):format(id, Config.Format(reward)), GOLD, "reveal")
				end
			end
		end
	end
	local plot = PlotOf[player]
	player:SetAttribute("Cash", d.Cash)
	player:SetAttribute("Income", computeIncome(player, d))
	player:SetAttribute("Multiplier", computeMult(player, d))
	player:SetAttribute("Rebirths", d.Rebirths)
	player:SetAttribute("SpeedLvl", d.SpeedLvl)
	player:SetAttribute("CarryLvl", d.CarryLvl)
	player:SetAttribute("SlotsLvl", d.SlotLvl)
	player:SetAttribute("FloorsLvl", d.FloorLvl)
	player:SetAttribute("LuckLvl", d.LuckLvl)
	player:SetAttribute("CarryCap", carryCapOf(d))
	player:SetAttribute("LockBuys", d.ShopBuys.BaseLock or 0) -- the Upgrades tab shows the climbing Base Lock price from this
	player:SetAttribute("MutPerks", table.concat(perksOf(d).Names, ",")) -- the client shows these as perk chips
	player:SetAttribute("MaxSlots", Config.MaxSlots(d.SlotLvl, d.FloorLvl))
	player:SetAttribute("UsedSlots", #d.Placed)
	player:SetAttribute("Locked", plot and plot.Locked or false)
	player:SetAttribute("PlayTime", math.floor(d.PlayTime))
	local petCash, petSpeed = petBonus(d)
	player:SetAttribute("Pets", table.concat(d.Pets, ","))
	player:SetAttribute("PetBox", table.concat(d.PetBox, ","))
	do
		local g, p = {}, {}
		for id in pairs(d.Index.G) do
			table.insert(g, id)
		end
		for id in pairs(d.Index.P) do
			table.insert(p, id)
		end
		table.sort(g)
		table.sort(p)
		player:SetAttribute("IndexG", table.concat(g, ","))
		player:SetAttribute("IndexP", table.concat(p, ","))
		player:SetAttribute("IndexGC", d.Index.GC)
		player:SetAttribute("IndexPC", d.Index.PC)
	end
	player:SetAttribute("PetSlots", Config.PetSlots(d.PetSlots))
	player:SetAttribute("PetCash", petCash)
	player:SetAttribute("PetSpeed", petSpeed)
	player:SetAttribute("CarryMax", Config.CarryMaxLevel(d.Rebirths))
	for _, it in ipairs(Config.ShopItems) do
		player:SetAttribute("Price_" .. it.Id, shopPrice(d, it))
	end
	local dReady, dDay, dDone = dailyInfo(d)
	player:SetAttribute("DailyReady", dReady)
	player:SetAttribute("DailyWeeks", d.DailyWeeks)
	player:SetAttribute("DailyDay", dDay)
	player:SetAttribute("DailyDone", dDone)
	player:SetAttribute("TradeOK", d.PlayTime >= Config.TradeUnlockSeconds)
	player:SetAttribute("Traps", d.Traps)
	player:SetAttribute("HasWacker", d.Wacker)
	player:SetAttribute("Spins", d.Spins)
	player:SetAttribute("LastSpinRegen", d.LastSpinRegen)
	for key in pairs(Config.GamePasses) do
		player:SetAttribute("Own_" .. key, (OwnsPass[player] and OwnsPass[player][key]) and true or false)
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = Config.Money(d.Cash) -- "$1.5T" (the Roblox player list would show a plain number as 1000B)
		ls.Rebirths.Value = d.Rebirths
	end
end

local function applySpeed(player)
	local d = Data[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or not d then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local b = Boosts[player]
	local vip = OwnsPass[player] and OwnsPass[player].VIP
	local _, petSpeed = petBonus(d)
	local speed = (Config.WalkSpeed(d.SpeedLvl, vip) + d.Rebirths * Config.MaxWalkSpeedPerRebirth) * (1 + petSpeed) -- rebirths raise the ceiling further, on top of levels
	speed *= perksOf(d).Speed -- Chocolate mutation perk
	local jump = Config.JumpPower
	if b and b.Speed > now then
		speed *= 1.5
	end
	if b and b.Jump > now then
		jump = 85
	end
	speed = math.min(speed, Config.MaxWalkSpeed) -- nobody can outrun the max (it is set so only a maxed runner escapes the last boss)
	if (Stunned[player] or 0) > os.clock() then
		speed = 0
		jump = 0
	end
	hum.WalkSpeed = speed
	hum.UseJumpPower = true
	hum.JumpPower = jump
end

local function refresh(player)
	updateStats(player)
	applySpeed(player)
	renderBase(player)
	local s = Trades[player]
	if s then
		pushTrade(s)
	end
end

----------------------------------------------------------------
-- CARRYING (Goobers floating above your head)
----------------------------------------------------------------
local function setCarryVisual(player)
	local char = player.Character
	if not char then
		return
	end
	local old = char:FindFirstChild("CarryStack")
	if old then
		old:Destroy()
	end
	local list = Carrying[player]
	local head = char:FindFirstChild("Head")
	if not list or #list == 0 or not head then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CarryStack"
	folder.Parent = char
	local gap = math.min(2.4, 14 / math.max(1, #list))
	for i, item in ipairs(list) do
		local cf = head.CFrame * CFrame.new(0, 2.2 + (i - 1) * gap, 0) * CFrame.Angles(0, math.rad(180), 0)
		local ball = buildGoober(item.Id, item.Mut, 2.2, cf, false, folder)
		local w = Instance.new("WeldConstraint")
		w.Part0 = head
		w.Part1 = ball
		w.Parent = ball
	end
end

local function syncCarry(player)
	local list = Carrying[player] or {}
	local ranks = {}
	for i, it in ipairs(list) do
		ranks[i] = Config.Rarities[Config.GooberById[it.Id].Rarity].Rank
	end
	player:SetAttribute("Carrying", #list)
	player:SetAttribute("CarryRanks", table.concat(ranks, ",")) -- the bottom bar colors its dots with these
	setCarryVisual(player)
end

----------------------------------------------------------------
-- DEPOSIT (walk onto your gold pad with Goobers in your hands)
----------------------------------------------------------------
local function deposit(player)
	local d, list = Data[player], Carrying[player]
	if not d or not list or #list == 0 then
		return
	end
	local maxSlots = Config.MaxSlots(d.SlotLvl, d.FloorLvl)
	local placed, sold, cash = 0, 0, 0
	for _, item in ipairs(list) do
		if #d.Placed < maxSlots then
			item.Lvl = item.Lvl or 0
			item.Stored = item.Stored or 0
			table.insert(d.Placed, item)
			placed += 1
		else
			cash += itemIncome(item) * Config.SellMultiplier
			sold += 1
		end
	end
	Carrying[player] = {}
	d.Cash += cash
	syncCarry(player)
	refresh(player)
	if placed > 0 then
		notify(player, "", GREEN, "deposit")
	end
	if sold > 0 then
		notify(player, ("Base full - sold for $%s"):format(Config.Format(cash)), GOLD, "sell")
	end
end

-- Flood hit: lose everything you carry, go back to base
local function sweep(player)
	local now = os.clock()
	if (LastSweep[player] or 0) + 2 > now then
		return
	end
	LastSweep[player] = now
	local lost = #(Carrying[player] or {})
	Carrying[player] = {}
	syncCarry(player)
	local d = Data[player]
	if d then
		d.FloodDeaths = (d.FloodDeaths or 0) + 1
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = 0 -- ragdolls and dies, same as a boss catch - they respawn at their base automatically
	end
	local msg = lost > 0 and ("Swept away! Lost %d"):format(lost) or "Swept away!"
	if d and d.FloodDeaths >= 3 and d.FloodDeaths % 3 == 0 then
		msg ..= "  TIP: buy a Jump Potion from Gus to clear floods easier!"
	end
	notify(player, msg, RED, "stuck")
end

----------------------------------------------------------------
-- PICKUPS (runway Goobers and dropped Goobers). Each one has a countdown timer above it
-- and disappears when the timer runs out (a new one then spawns somewhere in the zone).
-- The server never places one outside a zone; the client walks it in a circle around its "home".
----------------------------------------------------------------
local function fmtClock(sec)
	sec = math.max(0, math.ceil(sec))
	return ("%d:%02d"):format(sec // 60, sec % 60)
end

local function createPickup(item, pos, respawnZone, lifetime)
	if pos.X < RS_START + 12 then
		return -- goobers only ever exist inside the zones (or a player's base), never in the plaza
	end
	local def = Config.GooberById[item.Id]
	local rank = Config.Rarities[def.Rarity].Rank
	local col = rarityColor(item)
	lifetime = lifetime or Config.PickupLifetime[def.Rarity] or 60
	local spec = Creatures.SpecForGoober(item.Id, item.Mut)
	local cy = math.max(3, Creatures.HalfHeight(spec, 3.6) + 1.6)

	-- wrapped in a Model so the client can animate it
	local model = Instance.new("Model")
	model.Name = "Pickup"
	local ball = buildGoober(item.Id, item.Mut, 3.6, CFrame.new(pos.X, cy, pos.Z), true, model)
	model.PrimaryPart = ball
	-- "home" position as attributes: the client places the goober from these, so it can never end up in the wrong place
	model:SetAttribute("HX", pos.X)
	model:SetAttribute("HY", cy)
	model:SetAttribute("HZ", pos.Z)
	model:SetAttribute("ExpireAt", Workspace:GetServerTimeNow() + lifetime)
	model:SetAttribute("Circle", rng:NextNumber(3.5, 6))
	model:SetAttribute("Dir", rng:NextInteger(0, 1) * 2 - 1)
	model:SetAttribute("Rate", rng:NextNumber(0.55, 0.9))
	CollectionService:AddTag(model, "WalkGoober")
	model.Parent = Pickups

	local text = itemName(item) .. "\n$" .. Config.Format(itemIncome(item)) .. "/s"
	local nameGui = billboard(ball, text, col, Vector3.new(0, 3.6, 0), UDim2.fromOffset(200, 56), 90)
	nameGui.Name = "NameGui"
	model:SetAttribute("Zone", Config.ZoneAtX(pos.X))

	-- countdown timer (the client keeps the text updated)
	local tgui = Instance.new("BillboardGui")
	tgui.Name = "TimerGui"
	tgui.Size = UDim2.fromOffset(96, 28)
	tgui.StudsOffset = Vector3.new(0, 6.2, 0)
	tgui.AlwaysOnTop = true
	tgui.MaxDistance = 90
	local tl = Instance.new("TextLabel")
	tl.Name = "Timer"
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	tl.BackgroundTransparency = 0.25
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.TextColor3 = WHITE
	tl.Text = fmtClock(lifetime)
	tl.Parent = tgui
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 8)
	tc.Parent = tl
	local tp = Instance.new("UIPadding")
	tp.PaddingTop = UDim.new(0, 3)
	tp.PaddingBottom = UDim.new(0, 3)
	tp.Parent = tl
	tgui.Parent = ball

	local light = Instance.new("PointLight")
	light.Color = col
	light.Range = 8 + rank * 2
	light.Brightness = 1
	light.Parent = ball

	if rank >= 3 then
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Rate = 6 + rank * 2
		pe.Lifetime = NumberRange.new(1, 1.6)
		pe.Speed = NumberRange.new(2, 4)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Color = ColorSequence.new(col)
		pe.Size = NumberSequence.new(0.7)
		pe.LightEmission = 0.6
		pe.Parent = ball
	end

	-- a mutated Goober looks shinier (not a beam) and shows its mutation name in a little glowing tag above it
	if item.Mut ~= "Normal" then
		local mutDef = Config.Mutations[item.Mut]
		ball.Reflectance = 0.35
		light.Range = 8 + rank * 2 + 8
		light.Brightness = 2.2
		local mutTag = billboard(ball, "✨ " .. item.Mut:upper() .. " ✨", (mutDef and mutDef.Color) or GOLD, Vector3.new(0, 5.1, 0), UDim2.fromOffset(180, 30), 90)
		mutTag.Name = "MutationTag"
	end

	local function grab(player, silent)
		if model:GetAttribute("Taken") or not model.Parent then
			return
		end
		local list, d = Carrying[player], Data[player]
		if not list or not d then
			return
		end
		if (NoGrab[player] or 0) > os.clock() then
			return
		end
		if (Stunned[player] or 0) > os.clock() then
			return
		end
		if #list >= carryCapOf(d) then
			if not silent then
				notify(player, "Hands full!", RED)
			end
			return
		end
		model:SetAttribute("Taken", true)
		PickupInfo[model] = nil
		table.insert(list, item)
		syncCarry(player)
		notify(player, "", col, "grab")
		model:Destroy()
		if respawnZone then
			task.delay(rng:NextNumber(1.5, 4), spawnPickup, respawnZone)
		end
	end
	PickupInfo[model] = { Grab = grab, Rank = rank }
	model.Destroying:Connect(function()
		PickupInfo[model] = nil
	end)

	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Grab"
	pp.ObjectText = itemName(item)
	pp.HoldDuration = 0.25
	pp.MaxActivationDistance = 16
	pp.RequiresLineOfSight = false
	pp.Parent = ball
	pp.Triggered:Connect(function(player)
		grab(player, false)
	end)

	-- the timer ran out: it vanishes and a fresh one spawns
	task.delay(lifetime, function()
		if model.Parent and not model:GetAttribute("Taken") then
			model:Destroy()
			if respawnZone then
				task.delay(rng:NextNumber(0.3, 1.5), spawnPickup, respawnZone)
			end
		end
	end)
end

-- Spill everything a player is carrying onto the floor around them
local function dropCarried(player)
	local list = Carrying[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not list or #list == 0 or not hrp then
		return 0
	end
	local n = #list
	Carrying[player] = {}
	syncCarry(player)
	for i, item in ipairs(list) do
		local a = (i / n) * math.pi * 2
		local pos = hrp.Position + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7)
		createPickup(item, pos, nil, Config.DroppedLifetime)
	end
	return n
end

----------------------------------------------------------------
-- PLAYER vs PLAYER: stun, wacker, bear traps, potions
----------------------------------------------------------------
local function pvpAllowed(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and hrp.Position.X > RS_START + Config.PvpMargin, hrp
end

local function isShielded(player)
	local b = Boosts[player]
	return b ~= nil and b.Shield > Workspace:GetServerTimeNow()
end

-- returns true if the victim was stunned
local function stunPlayer(victim, seconds, kind, attacker)
	local okArea, hrp = pvpAllowed(victim)
	if not okArea or not hrp then
		return false
	end
	if (Stunned[victim] or 0) > os.clock() then
		return false
	end
	if GodMode[victim] then
		return false
	end
	if kind ~= "boss" and isShielded(victim) then -- (a Shield Potion stops wackers and traps, but not bosses)
		if attacker then
			notify(attacker, victim.DisplayName .. " has a SHIELD!", RED)
		end
		return false
	end
	local untilTime = os.clock() + seconds
	Stunned[victim] = untilTime
	local dropped = dropCarried(victim)
	local hum = victim.Character:FindFirstChildOfClass("Humanoid")
	if kind == "trap" then
		hrp.Anchored = true
	elseif hum then
		hum.PlatformStand = true
	end
	applySpeed(victim)
	local bb = billboard(hrp, kind == "trap" and "STUCK IN A TRAP!" or (kind == "boss" and "SMASHED BY A BOSS!" or "WHACKED!"), RED, Vector3.new(0, 4, 0), UDim2.fromOffset(240, 44), 120)
	bb.Name = "StunTag"
	local msg = kind == "trap" and "Stuck!" or (kind == "boss" and "Smashed!" or "Whacked!")
	if dropped > 0 then
		msg ..= (" Dropped %d"):format(dropped)
	end
	notify(victim, msg, RED, "stuck")

	task.delay(seconds, function()
		if Stunned[victim] == untilTime then
			Stunned[victim] = nil
			local c = victim.Character
			local h = c and c:FindFirstChild("HumanoidRootPart")
			local hm = c and c:FindFirstChildOfClass("Humanoid")
			if h then
				h.Anchored = false
				local tag = h:FindFirstChild("StunTag")
				if tag then
					tag:Destroy()
				end
			end
			if hm then
				hm.PlatformStand = false
			end
			applySpeed(victim)
		end
	end)
	return true
end

-- THE WACKER (a tool). It is held UPRIGHT like a real hammer: the shaft points up, the big head is on top.
-- Wrapped in its own do...end: everything here (WACKER_SCALE, REST_GRIP, wack, makeWacker) is only ever used inside
-- this block, so scoping it lets the compiler free these registers afterwards - this file sits right at the 200
-- local-register ceiling for its main chunk, so any new top-level local needs to be scoped like this, not left bare.
local giveWacker -- the one name from this section that's called from far away in the file, so it has to escape
do
	WACKER_SCALE = 0.82 -- a little smaller than before
	REST_GRIP = CFrame.new(0, 0, 0) -- gripped right in the MIDDLE of the handle, held upright and relaxed

	function wack(player)
		local d = Data[player]
		if not d then
			return
		end
		if #(Carrying[player] or {}) > 0 then
			notify(player, "Your hands are full! Drop the Goober first (Q)", RED)
			return
		end
		local now = os.clock()
		if now - (LastWack[player] or 0) < Config.WackCooldown then
			return
		end
		LastWack[player] = now
		player:SetAttribute("WackReadyAt", Workspace:GetServerTimeNow() + Config.WackCooldown) -- the custom Wacker button shows the cooldown
		if (Stunned[player] or 0) > now then
			return
		end
		local okArea, hrp = pvpAllowed(player)
		local char = player.Character
		local tool = char and char:FindFirstChild("Wacker")
		if tool then
			task.spawn(function()
				-- POINT then HIT: from resting upright in the middle, it quickly points forward (like aiming a staff),
				-- then swings sideways (the actual hit) - fast and seamless, glided with CFrame:Lerp (plain Grip
				-- assignment, no TweenService dependency).
				local AIM = CFrame.Angles(math.rad(90), 0, 0) -- tips from upright to pointing straight out in front of you (inverted so it points forward, not back)
				local SIDE_HIT = CFrame.Angles(0, math.rad(75), 0) * AIM -- swings sideways while still pointed out
				local function glide(from, to, steps, delay)
					for i = 1, steps do
						if not tool.Parent then
							return
						end
						tool.Grip = from:Lerp(to, i / steps)
						task.wait(delay)
					end
				end
				glide(REST_GRIP, AIM, 3, 0.02)
				glide(AIM, SIDE_HIT, 4, 0.02)
				local head = tool:FindFirstChild("WackerHead", true)
				local sparks = head and head:FindFirstChild("Sparks")
				if sparks then
					sparks:Emit(28)
				end
				glide(SIDE_HIT, REST_GRIP, 7, 0.03)
				if tool.Parent then
					tool.Grip = REST_GRIP -- make sure it always ends up exactly at rest
				end
			end)
		end
		UIRemote:FireClient(player, "Sfx", "wack")
		if not okArea or not hrp then
			notify(player, "Runway only!", RED)
			return
		end
		local best, bestDist = nil, Config.WackRange
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and Data[other] then
				local oh = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				if oh then
					local offset = oh.Position - hrp.Position
					local dist = offset.Magnitude
					if dist < bestDist and (dist < 4 or hrp.CFrame.LookVector:Dot(offset.Unit) > 0.1) then
						best, bestDist = other, dist
					end
				end
			end
		end
		if best and stunPlayer(best, Config.WackStun, "wack", player) then
			notify(player, "", GREEN, "buy")
		end
	end

	-- a proper mallet: wooden shaft with a striped grip, a big pink head with gold bands, a glowing gem, and a cheeky face
	function makeWacker(player)
		local tool = Instance.new("Tool")
		tool.Name = "Wacker"
		tool.ToolTip = ""
		tool.RequiresHandle = true
		tool.CanBeDropped = false
		tool.Grip = REST_GRIP
		local V = Vector3.new
		local PINK, GOLD2 = Color3.fromRGB(255, 105, 185), Color3.fromRGB(255, 215, 70)

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = V(0.7, 5, 0.7) * WACKER_SCALE -- the long side is UP (Y)
		handle.Color = Color3.fromRGB(160, 100, 60)
		handle.Material = Enum.Material.Wood
		handle.CanCollide = false
		handle.Massless = true
		handle.Parent = tool

		local function add(name, size, x, y, z, color, material, shape)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size * WACKER_SCALE
			p.CFrame = handle.CFrame * CFrame.new(x * WACKER_SCALE, y * WACKER_SCALE, z * WACKER_SCALE)
			p.Color = color
			p.Material = material or Enum.Material.SmoothPlastic
			p.CanCollide = false
			p.Massless = true
			if shape then
				p.Shape = shape
			end
			p.Parent = handle
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
			return p
		end
		for k = 0, 3 do -- striped grip at the bottom
			add("Wrap", V(0.82, 0.32, 0.82), 0, -1.7 + k * 0.62, 0, (k % 2 == 0) and PINK or Color3.fromRGB(255, 255, 255))
		end
		add("Pommel", V(1.05, 1.05, 1.05), 0, -2.7, 0, GOLD2, Enum.Material.Metal, Enum.PartType.Ball)
		local head = add("WackerHead", V(3.6, 2.2, 2.2), 0, 2.7, 0, PINK)
		for _, s in ipairs({ -1, 1 }) do
			add("HeadCap", V(2.2, 2.2, 2.2), s * 1.8, 2.7, 0, PINK, nil, Enum.PartType.Ball)
			add("HeadBand", V(0.35, 2.4, 2.4), s * 1.05, 2.7, 0, GOLD2, Enum.Material.Neon)
		end
		add("Gem", V(1, 1, 1), 0, 4.15, 0, GOLD2, Enum.Material.Neon, Enum.PartType.Ball)
		for _, s in ipairs({ -1, 1 }) do -- eyes on the front (the side facing forward)
			add("Eye", V(0.55, 0.55, 0.3), s * 0.55, 2.95, -1.15, Color3.fromRGB(255, 255, 255), nil, Enum.PartType.Ball)
			add("Pupil", V(0.26, 0.26, 0.2), s * 0.55, 2.95, -1.3, Color3.fromRGB(30, 20, 40), nil, Enum.PartType.Ball)
		end
		add("Smile", V(0.8, 0.14, 0.12), 0, 2.3, -1.15, Color3.fromRGB(120, 30, 80))

		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Sparks"
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Rate = 10
		sparks.Enabled = false
		sparks.Lifetime = NumberRange.new(0.5, 0.9)
		sparks.Speed = NumberRange.new(2, 6)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Color = ColorSequence.new(PINK, GOLD2)
		sparks.Size = NumberSequence.new(0.7)
		sparks.LightEmission = 1
		sparks.Parent = head
		local glow = Instance.new("PointLight")
		glow.Name = "Glow"
		glow.Color = PINK
		glow.Range = 10
		glow.Brightness = 1.2
		glow.Enabled = false
		glow.Parent = head
		tool.Equipped:Connect(function()
			sparks.Enabled = true
			glow.Enabled = true
		end)
		tool.Unequipped:Connect(function()
			sparks.Enabled = false
			glow.Enabled = false
		end)

		tool.Activated:Connect(function()
			wack(player)
		end)
		return tool
	end

	function giveWacker(player)
		local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
		local char = player.Character
		if not backpack then
			return
		end
		if backpack:FindFirstChild("Wacker") or (char and char:FindFirstChild("Wacker")) then
			return
		end
		makeWacker(player).Parent = backpack
	end
end -- closes the Wacker section's do block (see the comment above WACKER_SCALE)

-- BEAR TRAPS
local function buildTrap(owner, pos)
	local model = Instance.new("Model")
	model.Name = "BearTrap"
	model.Parent = TrapFolder
	local y = 0.4
	part({
		Name = "Plate",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 6, 6),
		CFrame = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 70, 85),
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, model)
	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2, 2),
		CFrame = CFrame.new(pos.X, y + 0.1, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		part({
			Name = "Spike",
			Size = Vector3.new(0.5, 1.8, 0.5),
			CFrame = CFrame.new(pos.X + math.cos(a) * 2.4, y + 0.9, pos.Z + math.sin(a) * 2.4) * CFrame.Angles(math.rad(12) * math.sin(a), 0, -math.rad(12) * math.cos(a)),
			Color = (i % 2 == 0) and Color3.fromRGB(240, 240, 250) or Color3.fromRGB(255, 90, 90),
			CanCollide = false,
		}, model)
	end
	billboard(core, "TRAP", RED, Vector3.new(0, 3, 0), UDim2.fromOffset(90, 26), 60)
	table.insert(TrapList, {
		Model = model,
		Owner = owner,
		Pos = pos,
		ArmedAt = os.clock() + 1.5,
		Expires = os.clock() + Config.TrapLife,
	})
end

local function placeTrap(player)
	local d = Data[player]
	local okArea, hrp = pvpAllowed(player)
	if not d or not hrp then
		return
	end
	if d.Traps <= 0 then
		notify(player, "No traps left", RED)
		return
	end
	if not okArea or hrp.Position.X < RS_START + Config.TrapMinX then
		notify(player, "Runway only!", RED)
		return
	end
	local mine = 0
	for _, t in ipairs(TrapList) do
		if t.Owner == player then
			mine += 1
		end
	end
	if mine >= Config.MaxActiveTraps then
		notify(player, ("You already have %d traps out!"):format(Config.MaxActiveTraps), RED)
		return
	end
	d.Traps -= 1
	updateStats(player)
	buildTrap(player, hrp.Position)
	notify(player, "", GREEN, "trap")
end

local function trapLoop()
	while true do
		task.wait(0.1)
		local now = os.clock()
		for i = #TrapList, 1, -1 do
			local t = TrapList[i]
			if now > t.Expires or not t.Model.Parent then
				t.Model:Destroy()
				table.remove(TrapList, i)
			elseif now > t.ArmedAt then
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr ~= t.Owner and Data[plr] then
						local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
						if hrp then
							local dx, dz = hrp.Position.X - t.Pos.X, hrp.Position.Z - t.Pos.Z
							if dx * dx + dz * dz < 13 and hrp.Position.Y < 9 then
								if stunPlayer(plr, Config.TrapStun, "trap", t.Owner) then
									if t.Owner.Parent then
										notify(t.Owner, "", GREEN, "buy")
									end
									t.Model:Destroy()
									table.remove(TrapList, i)
									break
								end
							end
						end
					end
				end
			end
		end
	end
end

-- POTIONS
local BOOST_KINDS = { "Speed", "Jump", "Shield", "Cash", "Magnet", "Guard" }

-- a force field shows while you are protected (Shield or Flood Guard)
local function refreshFF(player)
	local char = player.Character
	if not char then
		return
	end
	local b = Boosts[player]
	local now = Workspace:GetServerTimeNow()
	local want = b ~= nil and ((b.Shield or 0) > now or (b.Guard or 0) > now)
	local ff = char:FindFirstChild("ShieldFF")
	if want and not ff then
		local f = Instance.new("ForceField")
		f.Name = "ShieldFF"
		f.Parent = char
	elseif not want and ff then
		ff:Destroy()
	end
end

local function applyBoost(player, kind, seconds, stack)
	local b = Boosts[player]
	if not b then
		b = {}
		for _, k in ipairs(BOOST_KINDS) do
			b[k] = 0
		end
		Boosts[player] = b
	end
	local now = Workspace:GetServerTimeNow()
	local base = now
	if stack and (b[kind] or 0) > now then
		base = b[kind] -- stacking: the new time is added on top of what is left
	end
	local expire = math.min(base + seconds, now + Config.MaxPotionStack)
	b[kind] = expire
	player:SetAttribute("Boost" .. kind, expire)
	refreshFF(player)
	applySpeed(player)
	task.delay(expire - now, function()
		local bb = Boosts[player]
		if bb and bb[kind] == expire then
			bb[kind] = 0
			player:SetAttribute("Boost" .. kind, 0)
			refreshFF(player)
			applySpeed(player)
		end
	end)
end

-- Magnet filter: which rarities the magnet pulls in. "1,3,5" = ranks 1, 3 and 5. Empty / invalid = everything.
local function parseRanks(str)
	local maxRank = 0
	for _, r in pairs(Config.Rarities) do
		maxRank = math.max(maxRank, r.Rank)
	end
	local set, n = {}, 0
	if typeof(str) == "string" then
		for digits in string.gmatch(str, "%d+") do
			local k = tonumber(digits)
			if k and k >= 1 and k <= maxRank and not set[k] then
				set[k] = true
				n += 1
			end
		end
	end
	if n == 0 then
		for k = 1, maxRank do
			set[k] = true
		end
	end
	return set, maxRank
end

local function setMagnetFilter(player, str)
	local set, maxRank = parseRanks(str)
	MagnetFilter[player] = set
	local list = {}
	for k = 1, maxRank do
		if set[k] then
			table.insert(list, k)
		end
	end
	player:SetAttribute("MagnetFilter", table.concat(list, ","))
end

-- NPC SHOP PURCHASES (every purchase makes that item more expensive; potions stack, except Flood Guard)
local function shopBuy(player, id, extra)
	local d = Data[player]
	local def
	for _, it in ipairs(Config.ShopItems) do
		if it.Id == id then
			def = it
		end
	end
	if not d or not def then
		return
	end
	if def.Id == "Wacker" and d.Wacker then
		notify(player, "You own it already", GOLD)
		return
	end
	if def.Id == "Trap" and d.Traps + Config.TrapPackSize > Config.MaxTraps then
		notify(player, "Trap bag full", RED)
		return
	end
	if def.Duration then
		local now = Workspace:GetServerTimeNow()
		local left = math.max(0, ((Boosts[player] and Boosts[player][def.Id]) or 0) - now)
		if def.Stackable == false and left > 0 then
			notify(player, def.Label .. " is still active", GOLD)
			return
		end
		if left + def.Duration > Config.MaxPotionStack then
			notify(player, "Max time reached", GOLD)
			return
		end
	end
	local price = shopPrice(d, def)
	if d.Cash < price then
		notify(player, "Need $" .. Config.Format(price), RED)
		return
	end
	d.Cash -= price
	d.ShopBuys[def.Id] = (d.ShopBuys[def.Id] or 0) + 1
	if def.Id == "Wacker" then
		d.Wacker = true
		giveWacker(player)
	elseif def.Id == "Trap" then
		d.Traps += Config.TrapPackSize
	else
		applyBoost(player, def.Id, def.Duration, def.Stackable ~= false)
		if def.Filter then
			setMagnetFilter(player, extra)
		end
	end
	notify(player, "", GREEN, "buy")
	refresh(player)
end

----------------------------------------------------------------
-- PETS: 4 eggs (Common / Rare / Legendary / Mythical). Cash opens 1.
-- Robux opens 3 at once: the best pets fill your free slots, the rest are sold for cash.
----------------------------------------------------------------
-- Each egg's Pool lists every pet with its exact chance in percent (the numbers add up to 100).
-- The egg window shows these same numbers, so what you see is what you get.
local function rollPet(egg)
	local r = rng:NextNumber() * 100
	for _, e in ipairs(egg.Pool) do
		r -= e[2]
		if r <= 0 then
			return Config.PetById[e[1]]
		end
	end
	return Config.PetById[egg.Pool[#egg.Pool][1]]
end
local function announcePet(player, pet)
	if Config.Rarities[pet.Rarity].Rank >= 4 then
		notifyAll(("%s hatched %s!"):format(player.DisplayName, pet.Id), Config.Rarities[pet.Rarity].Color)
	end
	if pet.Rarity == "Secret" then
		announceToChat(("✨🎊 %s just opened a SECRET pet: %s!! 🎊✨"):format(player.DisplayName, pet.Id))
	end
end

-- 1 egg for cash
-- a new pet goes into a free pet slot, otherwise into the Pet Storage (it holds hundreds); only if THAT is full is it sold
local function givePet(player, pet)
	-- every new pet goes to the Pet Storage - the player equips it themselves from the Pets window (never automatic)
	local d = Data[player]
	if #d.PetBox < Config.PetBoxMax then
		table.insert(d.PetBox, pet.Id)
		return "stored", 0
	end
	local value = Config.PetSell[pet.Rarity] or 0
	d.Cash += value
	return "sold", value
end

local function hatchEgg(player, eggId)
	local d = Data[player]
	local egg = typeof(eggId) == "string" and Config.EggById[eggId]
	if not d or not egg then
		return
	end
	if d.Cash < egg.Price then
		notify(player, "Need $" .. Config.Format(egg.Price), RED)
		return
	end
	d.Cash -= egg.Price
	local pet = rollPet(egg)
	local where, sold = givePet(player, pet)
	refresh(player)
	UIRemote:FireClient(player, "PetReveal", { { Id = pet.Id, Kept = where ~= "sold", Stored = where == "stored", Sold = sold } }, egg.Id)
	announcePet(player, pet)
	task.spawn(saveData, player)
end

-- a free egg (tutorial wheel, codes): rolls the egg's exact odds. If the pet slots are full the pet is sold instead.
local function freeHatch(player, egg)
	local d = Data[player]
	if not d or not egg then
		return nil
	end
	local pet = rollPet(egg)
	local where, sold = givePet(player, pet)
	refresh(player)
	UIRemote:FireClient(player, "PetReveal", { { Id = pet.Id, Kept = where ~= "sold", Stored = where == "stored", Sold = sold } }, egg.Id)
	announcePet(player, pet)
	task.spawn(saveData, player)
	return pet
end


-- 3 eggs for Robux (called from the developer product receipt)
local function hatchTriple(player, egg)
	local d = Data[player]
	if not d then
		return false
	end
	local results = {}
	for i = 1, 3 do
		results[i] = rollPet(egg)
	end
	table.sort(results, function(a, b)
		return Config.Rarities[a.Rarity].Rank > Config.Rarities[b.Rarity].Rank
	end)
	local out = {}
	for i, pet in ipairs(results) do
		local where, sold = givePet(player, pet)
		out[i] = { Id = pet.Id, Kept = where ~= "sold", Stored = where == "stored", Sold = sold }
		announcePet(player, pet)
	end
	refresh(player)
	UIRemote:FireClient(player, "PetReveal", out, egg.Id)
	task.spawn(saveData, player)
	return true
end

-- the Pet Storage: swap pets between your slots and the storage, or sell them
local PetOps = {}
function PetOps.equip(player, boxIndex) -- storage -> a free slot
	local d = Data[player]
	if not d or typeof(boxIndex) ~= "number" then
		return
	end
	boxIndex = math.floor(boxIndex)
	local id = d.PetBox[boxIndex]
	if not id then
		return
	end
	if #d.Pets >= Config.PetSlots(d.PetSlots) then
		notify(player, "No free slot - swap instead!", RED)
		return
	end
	table.remove(d.PetBox, boxIndex)
	table.insert(d.Pets, id)
	refresh(player)
	notify(player, "", GREEN, "buy")
	task.spawn(saveData, player)
end
function PetOps.unequip(player, petIndex) -- a slot -> the storage
	local d = Data[player]
	if not d or typeof(petIndex) ~= "number" then
		return
	end
	petIndex = math.floor(petIndex)
	local id = d.Pets[petIndex]
	if not id or #d.PetBox >= Config.PetBoxMax then
		return
	end
	table.remove(d.Pets, petIndex)
	table.insert(d.PetBox, id)
	refresh(player)
	notify(player, "", GOLD, "pop")
	task.spawn(saveData, player)
end
function PetOps.swap(player, petIndex, boxIndex) -- a slot <-> a stored pet
	local d = Data[player]
	if not d or typeof(petIndex) ~= "number" or typeof(boxIndex) ~= "number" then
		return
	end
	petIndex, boxIndex = math.floor(petIndex), math.floor(boxIndex)
	if not d.Pets[petIndex] or not d.PetBox[boxIndex] then
		return
	end
	d.Pets[petIndex], d.PetBox[boxIndex] = d.PetBox[boxIndex], d.Pets[petIndex]
	refresh(player)
	notify(player, "", GREEN, "buy")
	task.spawn(saveData, player)
end
function PetOps.sell(player, where, index) -- where = "eq" (a slot) or "box" (the storage)
	local d = Data[player]
	if not d or typeof(index) ~= "number" or (where ~= "eq" and where ~= "box") then
		return
	end
	local list = where == "eq" and d.Pets or d.PetBox
	local id = table.remove(list, math.floor(index))
	local def = id and Config.PetById[id]
	if def then
		local value = Config.PetSell[def.Rarity] or 0
		d.Cash += value
		refresh(player)
		notify(player, ("Sold %s for $%s"):format(def.Id, Config.Format(value)), GOLD, "sell")
		task.spawn(saveData, player)
	end
end

----------------------------------------------------------------
-- ACTIONS (things players can buy / do)
----------------------------------------------------------------
local UPGRADE_KEYS = { Speed = "SpeedLvl", Carry = "CarryLvl", Slots = "SlotLvl", Floors = "FloorLvl", Luck = "LuckLvl" }

-- count = 1, 5 or 10 levels at once (the total price is charged in one go)
local function buyUpgrade(player, name, count)
	local d = Data[player]
	local def = typeof(name) == "string" and Config.Upgrades[name]
	if not d or not def then
		return
	end
	count = (count == 5 or count == 10) and count or 1
	local key = UPGRADE_KEYS[name]
	local lvl = d[key]
	local max = def.Max or math.huge
	if name == "Carry" then
		max = Config.CarryMaxLevel(d.Rebirths) -- more capacity needs Rebirths
	elseif name == "Slots" then
		max = math.min(max, Config.SlotsPerFloor * (1 + d.FloorLvl) - 4)
	end
	local room = max - lvl
	if room <= 0 then
		if name == "Carry" then
			notify(player, "Rebirth to unlock more capacity!", GOLD, "error")
		elseif name == "Slots" then
			notify(player, "Build a new Base Floor first!", RED)
		else
			notify(player, "Maxed out!", GOLD)
		end
		return
	end
	count = math.min(count, room)
	local cost = 0
	for i = 0, count - 1 do
		cost += Config.UpgradeCost(name, lvl + i)
	end
	if d.Cash < cost then
		notify(player, "Need $" .. Config.Format(cost), RED)
		return
	end
	d.Cash -= cost
	d[key] = lvl + count
	refresh(player)
	notify(player, "", GREEN, name == "Floors" and "reveal" or "buy")
end

-- Gives a Goober straight to the player's base (or sells it if the base is full)
local function grantItem(player, item, source, reveal)
	local d = Data[player]
	if not d then
		return
	end
	local def = Config.GooberById[item.Id]
	local text = itemName(item) .. " (" .. def.Rarity .. ")"
	if #d.Placed < Config.MaxSlots(d.SlotLvl, d.FloorLvl) then
		item.Lvl = item.Lvl or 0
		item.Stored = item.Stored or 0
		table.insert(d.Placed, item)
		refresh(player)
		if reveal then
			UIRemote:FireClient(player, "Reveal", item.Id, item.Mut)
		end
		notify(player, "", rarityColor(item), "reveal")
		if def.Rarity == "Mythic" or def.Rarity == "Secret" then
			notifyAll(("%s just got %s from a %s!"):format(player.DisplayName, text, source), rarityColor(item))
		end
		if def.Rarity == "Secret" then
			announceToChat(("✨🎊 %s just found a SECRET Goober: %s!! 🎊✨"):format(player.DisplayName, item.Id))
		end
	else
		local v = itemIncome(item) * Config.SellMultiplier
		d.Cash += v
		refresh(player)
		notify(player, ("Base full - sold for $%s"):format(Config.Format(v)), GOLD, "sell")
	end
end

local function rollLuckyItem(d, premium)
	local def = Config.RollLuckyGoober(d.LuckLvl, premium, perksOf(d).Luck) -- Galaxy mutation perk = better odds
	return { Id = def.Id, Mut = Config.RollMutation(MutationEvent and 3 or 1, MutationEvent or nil) }
end

local function buyLuckyBox(player)
	local d = Data[player]
	if not d then
		return
	end
	if d.Cash < Config.LuckyBoxCost then
		notify(player, "Need $" .. Config.Format(Config.LuckyBoxCost), RED)
		return
	end
	if #d.Placed >= Config.MaxSlots(d.SlotLvl, d.FloorLvl) then
		notify(player, "Base full", RED)
		return
	end
	d.Cash -= Config.LuckyBoxCost
	grantItem(player, rollLuckyItem(d), "Lucky Box", true)
end

-- Locks a base (nobody can steal) for a number of seconds
local function startLock(player, seconds)
	local plot = PlotOf[player]
	if not plot then
		return
	end
	plot.LockId = (plot.LockId or 0) + 1
	local id = plot.LockId
	plot.Locked = true
	player:SetAttribute("LockedUntil", Workspace:GetServerTimeNow() + seconds)
	refresh(player)
	task.delay(seconds, function()
		if plot.Owner == player and plot.LockId == id then
			plot.Locked = false
			if Data[player] then
				refresh(player)
				notify(player, "Lock ended", GOLD)
			end
		end
	end)
end

local function lockBase(player)
	local d, plot = Data[player], PlotOf[player]
	if not d or not plot then
		return
	end
	if plot.Locked then
		notify(player, "Already locked", GOLD)
		return
	end
	local buys = d.ShopBuys.BaseLock or 0
	local price = Config.LockPrice(buys) -- climbs every time you buy one
	if d.Cash < price then
		notify(player, "Need $" .. Config.Format(price), RED)
		return
	end
	d.Cash -= price
	d.ShopBuys.BaseLock = buys + 1
	player:SetAttribute("LockBuys", buys + 1)
	startLock(player, Config.LockSeconds)
	notify(player, "", GREEN, "buy")
end

local function rebirth(player)
	local d = Data[player]
	if not d then
		return
	end
	local needLvl = Config.RebirthSpeedLevel(d.Rebirths)
	if d.SpeedLvl < needLvl then
		notify(player, ("Reach Speed Level %d first, then rebirth to go even faster!"):format(needLvl), RED)
		return
	end
	local cost = Config.RebirthCost(d.Rebirths)
	if d.Cash < cost then
		notify(player, "Need $" .. Config.Format(cost), RED)
		return
	end
	d.Cash = 0
	d.SpeedLvl = 0
	d.LuckLvl = 0
	d.Rebirths += 1
	refresh(player)
	applySpeed(player)
	notifyAll(("%s reached Rebirth %d!"):format(player.DisplayName, d.Rebirths), GOLD, "reveal")
end

-- Teleports: only with empty hands (otherwise it would skip the danger!)
local function teleportTo(player, cf)
	local char = player.Character
	if not char or not PlotOf[player] then
		return
	end
	if #(Carrying[player] or {}) > 0 then
		notify(player, "Drop your Goobers off first!", RED)
		return
	end
	if (Stunned[player] or 0) > os.clock() then
		return
	end
	local now = os.clock()
	if LastTP[player] and now - LastTP[player] < Config.TeleportCooldown then
		return
	end
	LastTP[player] = now
	char:PivotTo(cf)
	notify(player, "", GREEN, "whoosh")
end

local function teleportBase(player)
	local plot = PlotOf[player]
	if plot then
		teleportTo(player, spawnCFrame(plot))
	end
end

-- MARKET: Speed / Capacity stands on either side of the runway entrance, Gus and the Pet Stand further out
local function teleportMarket(player, key)
	local m = Config.Market
	local east = CFrame.Angles(0, -math.pi / 2, 0) -- looking east: towards the stalls on the east wall
	local spots = {
		Speed = CFrame.new(m.StandX - 22, 4, m.SpeedZ) * east,
		Capacity = CFrame.new(m.StandX - 22, 4, m.CapacityZ) * east,
		Gus = CFrame.new(m.GusX - 24, 4, m.SpeedZ - 44) * east,
		Pets = CFrame.new(m.PetX - 22, 4, m.PetZ - 40) * east,
		Boards = CFrame.new(46, 4, m.BoardZ[2]) * east,
	}
	local cf = typeof(key) == "string" and spots[key]
	if cf then
		teleportTo(player, cf)
	end
end

-- Codes
-- CODES. The codes themselves live in Config.Codes (easy to edit). This part gives the rewards.
-- CODE_REWARDS has one small function per kind of reward. To invent a new reward: add a function here (return a short
-- text for the message, or nil if it could not be given), then use its name in a code in Config.Codes.
local redeemCode
do
	local CODE_REWARDS = {
		Cash = function(player, d, v)
			d.Cash += v
			return "$" .. Config.Format(v)
		end,
		Goober = function(player, d, v, def)
			grantItem(player, { Id = v, Mut = def.Mutation or "Normal" }, "Code", true)
			return v
		end,
		Pet = function(player, d, v)
			givePet(player, Config.PetById[v]) -- a free slot, or the Pet Storage
			return v
		end,
		Egg = function(player, d, v)
			local egg = Config.EggById[v]
			return freeHatch(player, egg) and egg.Label or nil
		end,
		Traps = function(player, d, v)
			d.Traps = math.min(Config.MaxTraps, d.Traps + v)
			return v .. " traps"
		end,
		Wacker = function(player, d, v)
			if v then
				d.Wacker = true
				giveWacker(player)
				return "the Wacker"
			end
			return nil
		end,
		Boosts = function(player, d, v)
			for kind, seconds in pairs(v) do
				applyBoost(player, kind, seconds, true)
			end
			return "potions"
		end,
		Spins = function(player, d, v)
			d.Spins = math.min(Config.SpinMax, (d.Spins or 0) + v)
			player:SetAttribute("Spins", d.Spins)
			return v .. " wheel spins"
		end,
	}
	local CODE_ORDER = { "Cash", "Goober", "Pet", "Egg", "Traps", "Wacker", "Boosts", "Spins" }
	local CODE_SETTINGS = { Mutation = true, Enabled = true, Expires = true }

	-- a typo in Config.Codes must never break redeeming: a broken code is refused and explained in the Output window
	local function codeProblem(def)
		for key in pairs(def) do
			if not CODE_REWARDS[key] and not CODE_SETTINGS[key] then
				return "unknown field '" .. tostring(key) .. "'"
			end
		end
		if def.Goober and not Config.GooberById[def.Goober] then
			return "there is no Goober called '" .. def.Goober .. "'"
		end
		if def.Mutation and not Config.Mutations[def.Mutation] then
			return "there is no mutation called '" .. def.Mutation .. "'"
		end
		if def.Pet and not Config.PetById[def.Pet] then
			return "there is no pet called '" .. def.Pet .. "'"
		end
		if def.Egg and not Config.EggById[def.Egg] then
			return "there is no egg called '" .. def.Egg .. "'"
		end
		if def.Boosts then
			for kind in pairs(def.Boosts) do
				if not table.find(BOOST_KINDS, kind) then
					return "there is no potion called '" .. tostring(kind) .. "'"
				end
			end
		end
		return nil
	end

	function redeemCode(player, raw)
		local d = Data[player]
		if not d or typeof(raw) ~= "string" then
			return false
		end
		local code = string.upper((raw:gsub("%s+", "")))
		if #code == 0 or #code > 30 then
			return false
		end
		local def = Config.Codes[code]
		if not def or def.Enabled == false then
			notify(player, "That code doesn't exist!", RED)
			return false
		end
		if def.Expires and os.time() > def.Expires then
			notify(player, "That code has expired", GOLD)
			return false
		end
		if d.Codes[code] then
			notify(player, "You already used that code!", GOLD)
			return false
		end
		local problem = codeProblem(def)
		if problem then
			warn(("[Codes] %s is not set up right: %s"):format(code, problem))
			notify(player, "That code isn't working right now", RED)
			return false
		end
		d.Codes[code] = true -- marked first, so it can never be used twice
		local gave = {}
		for _, key in ipairs(CODE_ORDER) do
			if def[key] ~= nil then
				local text = CODE_REWARDS[key](player, d, def[key], def)
				if text then
					table.insert(gave, tostring(text))
				end
			end
		end
		refresh(player)
		notify(player, "Code redeemed! " .. table.concat(gave, ", "), GOLD, "reveal")
		task.spawn(saveData, player) -- saved right away so a code can't be reused by rejoining
		return true
	end
end


-- The free welcome gift (opened in the first seconds of a new player's game)
local function claimGift(player)
	-- (the welcome gift was replaced by the tutorial wheel: new players start with nothing so the tutorial teaches everything)
end

-- Sell (remove) a Goober from your own base. Hold F on it. You also get the cash stored on its pad.
function sellGoober(player, slot)
	local d = Data[player]
	local item = d and d.Placed[slot]
	if not item then
		return
	end
	table.remove(d.Placed, slot)
	d.Cash += itemIncome(item) * Config.SellMultiplier + math.floor(item.Stored or 0)
	refresh(player)
	notify(player, "", GOLD, "sell")
end

function stealGoober(thief, owner, slot)
	if thief == owner then
		return
	end
	local od, td, plot = Data[owner], Data[thief], PlotOf[owner]
	if not od or not td or not plot then
		return
	end

	-- Stealing is a Robux feature (Thief Pass). Free in Studio for testing only.
	local hasPass = OwnsPass[thief] and OwnsPass[thief].Thief
	local freeTest = Config.StealFreeInStudio and RunService:IsStudio()
	if not hasPass and not freeTest then
		local info = Config.GamePasses.Thief
		notify(thief, "Needs the Thief Pass!", GOLD)
		if info.Id > 0 then
			MarketplaceService:PromptGamePassPurchase(thief, info.Id)
		end
		return
	end

	if plot.Locked then
		notify(thief, "Base locked!", RED)
		return
	end
	local item = od.Placed[slot]
	if not item then
		return
	end
	local list = Carrying[thief]
	if not list or #list >= carryCapOf(td) then
		notify(thief, "Hands full!", RED)
		return
	end
	table.remove(od.Placed, slot)
	od.Cash += math.floor(item.Stored or 0) -- the victim keeps the cash that was waiting on the pad
	item.Stored = 0
	table.insert(list, item)
	refresh(owner)
	syncCarry(thief)
	notify(thief, "", GOLD, "grab")
	notify(owner, ("%s stole your %s!"):format(thief.DisplayName, itemName(item)), RED)
end

-- Walk onto a pad to collect the money that Goober has earned
-- the Auto Collector game pass: one button, every pad's stored cash instantly banked (even pads that are already full)
-- (left as a plain global, not a local - the top-level local budget in this file is already at its ceiling)
function collectAll(player)
	local d, plot = Data[player], PlotOf[player]
	if not d or not plot or not (OwnsPass[player] and OwnsPass[player].AutoCollect) then
		return
	end
	local total = 0
	for slot, item in pairs(d.Placed) do
		local amount = math.floor(item.Stored or 0)
		if amount >= 1 then
			item.Stored -= amount
			total += amount
			refreshPad(plot, slot, item)
		end
	end
	if total > 0 then
		d.Cash += total
		updateStats(player)
		notify(player, "Collected $" .. Config.Format(total) .. " from every Goober!", GOLD, "buy")
		task.spawn(saveData, player)
	end
end

local function collectSlot(player, slot)
	local d, plot = Data[player], PlotOf[player]
	local item = d and d.Placed[slot]
	if not item or not plot or slot > Config.MaxSlots(d.SlotLvl, d.FloorLvl) then
		return
	end
	local amount = math.floor(item.Stored or 0)
	if amount < 1 then
		return
	end
	item.Stored -= amount
	d.Cash += amount
	updateStats(player)
	refreshPad(plot, slot, item)
	local em = plot.PadEmitters[slot]
	if em then
		em:Emit(16)
	end
	player:SetAttribute("Collects", (player:GetAttribute("Collects") or 0) + 1)
	notify(player, "", GOLD, "collect")
end

-- Upgrade button on a pedestal: this Goober earns more $ per second
local function upgradeGoober(player, slot)
	local d = Data[player]
	local item = d and typeof(slot) == "number" and d.Placed[slot]
	if not item or slot > Config.MaxSlots(d.SlotLvl, d.FloorLvl) then
		return
	end
	local lvl = item.Lvl or 0
	if lvl >= Config.GooberMaxLevel then
		notify(player, "Max level!", GOLD)
		return
	end
	local baseInc = Config.GooberById[item.Id].Income * Config.Mutations[item.Mut].Mult
	local cost = Config.GooberUpgradeCost(baseInc, lvl)
	if d.Cash < cost then
		notify(player, "Need $" .. Config.Format(cost), RED)
		return
	end
	d.Cash -= cost
	item.Lvl = lvl + 1
	player:SetAttribute("GooberUpgrades", (player:GetAttribute("GooberUpgrades") or 0) + 1)
	refresh(player)
	notify(player, "", GREEN, "buy")
end

-- DAILY REWARD (7 day streak, day 7 = King Goldie)
local function claimDaily(player)
	local d = Data[player]
	if not d then
		return
	end
	local ready, day, _, today = dailyInfo(d)
	if not ready then
		return
	end
	local reward = Config.DailyRewards[day]
	local week = d.DailyWeeks
	local scale = Config.DailyRewardScale(week)
	d.DailyStreak = day % 7
	d.DailyLast = today
	if day == 7 then
		d.DailyWeeks += 1 -- a full week just completed: next week's rewards get even better
	end
	if reward.Cash then
		d.Cash += math.floor(reward.Cash * scale)
	end
	if reward.Traps then
		local bonus = math.floor(week / Config.DailyWeekTrapGrowth)
		d.Traps = math.min(Config.MaxTraps, d.Traps + reward.Traps + bonus)
	end
	if reward.Goober then
		grantItem(player, { Id = reward.Goober, Mut = Config.DailyMutationForWeek(week) }, "Daily Reward", true)
	else
		refresh(player)
	end
	UIRemote:FireClient(player, "DailyClaimed", day)
	task.spawn(saveData, player)
end

----------------------------------------------------------------
-- TRADING (unlocks after 15 minutes of play time)
----------------------------------------------------------------
pushTrade = function(session)
	for _, p in ipairs({ session.A, session.B }) do
		local other = (p == session.A) and session.B or session.A
		local d = Data[p]
		UIRemote:FireClient(p, "TradeState", {
			Partner = other.DisplayName,
			Mine = session.Offer[p],
			Theirs = session.Offer[other],
			MyReady = session.Ready[p],
			TheirReady = session.Ready[other],
			Base = d and d.Placed or {},
		})
	end
end

local function closeTrade(session, reason)
	for _, p in ipairs({ session.A, session.B }) do
		local d = Data[p]
		if d then
			for _, item in ipairs(session.Offer[p]) do
				table.insert(d.Placed, item) -- give everything back
			end
		end
		session.Offer[p] = {}
	end
	Trades[session.A] = nil
	Trades[session.B] = nil
	for _, p in ipairs({ session.A, session.B }) do
		if p.Parent then
			UIRemote:FireClient(p, "TradeClosed", reason)
			if Data[p] then
				refresh(p)
			end
		end
	end
end

local function tradeCancel(player)
	local s = Trades[player]
	if s then
		closeTrade(s, player.DisplayName .. " cancelled the trade.")
	end
end

local function completeTrade(session)
	local A, B = session.A, session.B
	local dA, dB = Data[A], Data[B]
	if not dA or not dB then
		closeTrade(session, "Trade cancelled.")
		return
	end
	local oA, oB = session.Offer[A], session.Offer[B]
	if #dA.Placed + #oB > Config.MaxSlots(dA.SlotLvl, dA.FloorLvl) then
		notify(A, "You don't have enough free slots for this trade!", RED)
		notify(B, A.DisplayName .. " doesn't have enough free slots.", RED)
		session.Ready[A], session.Ready[B] = false, false
		pushTrade(session)
		return
	end
	if #dB.Placed + #oA > Config.MaxSlots(dB.SlotLvl, dB.FloorLvl) then
		notify(B, "You don't have enough free slots for this trade!", RED)
		notify(A, B.DisplayName .. " doesn't have enough free slots.", RED)
		session.Ready[A], session.Ready[B] = false, false
		pushTrade(session)
		return
	end
	for _, it in ipairs(oB) do
		table.insert(dA.Placed, it)
	end
	for _, it in ipairs(oA) do
		table.insert(dB.Placed, it)
	end
	session.Offer[A], session.Offer[B] = {}, {}
	Trades[A], Trades[B] = nil, nil
	UIRemote:FireClient(A, "TradeClosed", "Trade complete!")
	UIRemote:FireClient(B, "TradeClosed", "Trade complete!")
	refresh(A)
	refresh(B)
	notify(A, "Trade complete with " .. B.DisplayName .. "!", GREEN, "reveal")
	notify(B, "Trade complete with " .. A.DisplayName .. "!", GREEN, "reveal")
	task.spawn(saveData, A)
	task.spawn(saveData, B)
end

local function tradeRequest(player, targetId)
	local d = Data[player]
	local target = typeof(targetId) == "number" and Players:GetPlayerByUserId(targetId)
	if not d or not target or target == player then
		return
	end
	local td = Data[target]
	if not td then
		return
	end
	if d.PlayTime < Config.TradeUnlockSeconds then
		local left = math.ceil((Config.TradeUnlockSeconds - d.PlayTime) / 60)
		notify(player, ("Trading unlocks after %d more minute(s) of playing!"):format(left), RED)
		return
	end
	if td.PlayTime < Config.TradeUnlockSeconds then
		notify(player, target.DisplayName .. " hasn't unlocked trading yet.", RED)
		return
	end
	if Trades[player] or Trades[target] then
		notify(player, "One of you is already in a trade.", RED)
		return
	end
	Invites[target] = { From = player, Time = os.clock() }
	UIRemote:FireClient(target, "TradeInvite", player.DisplayName, player.UserId)
	notify(player, "Trade request sent to " .. target.DisplayName .. "!", GOLD)
end

local function tradeRespond(player, accept)
	local inv = Invites[player]
	Invites[player] = nil
	if not inv or os.clock() - inv.Time > 30 then
		return
	end
	local from = inv.From
	if not accept then
		if from.Parent then
			notify(from, player.DisplayName .. " declined your trade.", RED)
		end
		return
	end
	if not from.Parent or not Data[from] or Trades[from] or Trades[player] then
		return
	end
	local session = {
		A = from,
		B = player,
		Offer = { [from] = {}, [player] = {} },
		Ready = { [from] = false, [player] = false },
	}
	Trades[from] = session
	Trades[player] = session
	UIRemote:FireClient(from, "TradeOpen")
	UIRemote:FireClient(player, "TradeOpen")
	pushTrade(session)
end

local function tradeAdd(player, slot)
	local s, d = Trades[player], Data[player]
	if not s or not d or typeof(slot) ~= "number" then
		return
	end
	local item = d.Placed[math.floor(slot)]
	if not item then
		return
	end
	if #s.Offer[player] >= Config.TradeMaxItems then
		notify(player, ("You can only offer %d Goobers."):format(Config.TradeMaxItems), RED)
		return
	end
	d.Cash += math.floor(item.Stored or 0)
	item.Stored = 0
	table.remove(d.Placed, math.floor(slot))
	table.insert(s.Offer[player], item)
	s.Ready[s.A], s.Ready[s.B] = false, false
	refresh(player) -- also pushes the trade state
end

local function tradeRemove(player, index)
	local s, d = Trades[player], Data[player]
	if not s or not d or typeof(index) ~= "number" then
		return
	end
	local item = table.remove(s.Offer[player], math.floor(index))
	if item then
		table.insert(d.Placed, item)
		s.Ready[s.A], s.Ready[s.B] = false, false
		refresh(player)
	end
end

local function tradeReady(player, flag)
	local s = Trades[player]
	if not s then
		return
	end
	s.Ready[player] = flag == true
	if s.Ready[s.A] and s.Ready[s.B] then
		completeTrade(s)
	else
		pushTrade(s)
	end
end

local function defaultData()
	return {
		Cash = Config.StartCash,
		Rebirths = 0,
		SpeedLvl = 0,
		CarryLvl = 0,
		SlotLvl = 0,
		LuckLvl = 0,
		FloorLvl = 0,
		PlayTime = 0,
		Traps = 0,
		PetSlots = 0,
		Donated = 0,
		MaxZone = 0,
		TutorialDone = false,
		WheelClaimed = false,
		GroupClaimed = false,
		ShopBuys = {},
		DailyLast = 0,
		DailyStreak = 0,
		DailyWeeks = 0, -- how many FULL 7-day streaks completed - each one makes the next week's rewards better
		Deaths = 0, -- how many times a boss has caught you (used to time helpful hints)
		Spins = 1, -- free spins on the Goober Wheel, banked up over time
		LastSpinRegen = os.time(),
		FloodDeaths = 0, -- how many times a normal flood has caught you (for the "buy a Jump Potion" tip)
		LastSeen = 0, -- os.time() of the last save - used to compute offline earnings (0 = brand new player, no offline popup)
		Pets = {},
		PetBox = {}, -- the Pet Storage
		Index = { G = {}, P = {}, GC = 0, PC = 0 }, -- the collection book (found goobers / pets, payouts already given)
		Wacker = false,
		GiftClaimed = false,
		Placed = {},
		Codes = {},
	}
end

----------------------------------------------------------------
-- GROUP REWARD, TUTORIAL, ADMIN
----------------------------------------------------------------
local function claimGroup(player)
	local d = Data[player]
	local G = Config.Group
	if not d then
		return
	end
	if G.Id == 0 then
		notify(player, "Group reward isn't set up yet", RED)
		return
	end
	if d.GroupClaimed then
		notify(player, "Already claimed!", GOLD)
		return
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroup(G.Id)
	end)
	if not ok or not inGroup then
		notify(player, "Join the group first!", RED)
		return
	end
	d.GroupClaimed = true
	player:SetAttribute("GroupClaimed", true)
	d.Cash += G.Cash or 0
	local pet = Config.PetById[G.Pet]
	if pet then
		local where, sold = givePet(player, pet)
		UIRemote:FireClient(player, "PetReveal", { { Id = pet.Id, Kept = where ~= "sold", Stored = where == "stored", Sold = sold } }, Config.PetEgg[pet.Id])
	end
	refresh(player)
	notify(player, ("Group reward: $%s + %s!"):format(Config.Format(G.Cash or 0), pet and pet.Id or "a pet"), GOLD, "reveal")
	task.spawn(saveData, player)
end

-- the HOST: the game's creator (or anyone in Config.Admins, or whoever is testing in Studio). Only the host can hand out admin.
function isHost(player)
	if RunService:IsStudio() then
		return true -- whoever is testing in Studio is the developer
	end
	for _, id in ipairs(Config.Admins) do
		if id == player.UserId then
			return true
		end
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank >= 255
end

-- an admin is the host, or someone the host gave temporary admin to
function isAdmin(player)
	if isHost(player) then
		return true
	end
	local exp = TempAdmins[player.UserId]
	return exp ~= nil and exp > os.clock()
end

local function findPlayerById(id)
	return typeof(id) == "number" and Players:GetPlayerByUserId(id) or nil
end

local function grantAdmin(host, targetId, minutes)
	if not isHost(host) then
		notify(host, "Only the host can do that", RED)
		return
	end
	local target = findPlayerById(targetId)
	if not target or target == host or isHost(target) then
		return
	end
	minutes = typeof(minutes) == "number" and math.clamp(math.floor(minutes), 0, 720) or 0
	TempAdmins[target.UserId] = minutes > 0 and (os.clock() + minutes * 60) or math.huge
	target:SetAttribute("IsAdmin", true)
	notify(target, minutes > 0 and ("You are an admin for " .. minutes .. " min") or "You are an admin until you leave", GOLD, "reveal")
	notify(host, target.DisplayName .. " is now an admin", GREEN)
end

local function revokeAdmin(host, targetId)
	if not isHost(host) then
		notify(host, "Only the host can do that", RED)
		return
	end
	local target = findPlayerById(targetId)
	if not target or isHost(target) then
		return
	end
	TempAdmins[target.UserId] = nil
	GodMode[target] = nil
	target:SetAttribute("IsAdmin", false)
	notify(target, "Your admin was removed", RED)
	notify(host, target.DisplayName .. " is no longer an admin", GOLD)
end

-- every admin command is checked on the server: only admins can use them
local function adminCommand(player, cmd, a, b)
	if typeof(cmd) ~= "string" or not isAdmin(player) then
		return
	end
	local d = Data[player]
	if not d then
		return
	end
	local char = player.Character
	if cmd == "Cash" and typeof(a) == "number" then
		d.Cash = math.max(0, d.Cash + math.clamp(a, -1e300, 1e300))
	elseif cmd == "Rebirth" then
		d.Rebirths += 1
	elseif cmd == "SpeedLevels" and typeof(a) == "number" then
		d.SpeedLvl = math.clamp(d.SpeedLvl + math.floor(a), 0, Config.Upgrades.Speed.Max)
	elseif cmd == "UnlockTrade" then
		d.PlayTime = math.max(d.PlayTime, Config.TradeUnlockSeconds)
	elseif cmd == "Wacker" then
		d.Wacker = true
		giveWacker(player)
	elseif cmd == "Traps" then
		d.Traps = Config.MaxTraps
	elseif cmd == "Boosts" then
		for _, k in ipairs(BOOST_KINDS) do
			applyBoost(player, k, 300)
		end
	elseif cmd == "UnlockBase" then
		d.SlotLvl = Config.Upgrades.Slots.Max
		d.FloorLvl = Config.Upgrades.Floors.Max
	elseif cmd == "MaxCapacity" then
		d.CarryLvl = Config.CarryMaxLevel(d.Rebirths)
	elseif cmd == "Goober" and typeof(a) == "string" and Config.GooberById[a] then
		local mut = (typeof(b) == "string" and Config.Mutations[b]) and b or "Normal"
		grantItem(player, { Id = a, Mut = mut }, "Admin", true)
	elseif cmd == "Pet" and typeof(a) == "string" and Config.PetById[a] then
		givePet(player, Config.PetById[a])
	elseif cmd == "Wave" then
		local wt = triggerWave(typeof(a) == "string" and a or nil)
		AnnounceRemote:FireAllClients(wt.Title, wt.Sub, wt.Color, "horn")
		notify(player, ("Admin: spawned %s %s"):format(wt.Emoji or "", wt.Name), GOLD)
	elseif cmd == "PauseWaves" then
		WavesPaused = not WavesPaused
		notify(player, WavesPaused and "Waves paused" or "Waves resumed", GOLD)
	elseif cmd == "ClearWaves" then
		clearWaves()
	elseif cmd == "God" then
		GodMode[player] = not GodMode[player]
		notify(player, GodMode[player] and "God mode ON" or "God mode OFF", GOLD)
	elseif cmd == "Zone" and typeof(a) == "number" and char then
		local z = math.clamp(math.floor(a), 1, ZONES)
		char:PivotTo(CFrame.new(Config.ZoneStarts[z] + 14, 6, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	elseif cmd == "Home" and char and PlotOf[player] then
		char:PivotTo(spawnCFrame(PlotOf[player]))
	elseif cmd == "NextDay" then
		d.DailyLast = math.max(0, d.DailyLast - 1)
	elseif cmd == "ResetDaily" then
		d.DailyLast = 0
		d.DailyStreak = 0
	elseif cmd == "ResetTutorial" then
		d.TutorialDone = false
		d.WheelClaimed = false
		player:SetAttribute("TutDone", false)
		player:SetAttribute("WheelReady", false)
	elseif cmd == "VIP" then -- test every VIP perk without buying the pass
		OwnsPass[player] = OwnsPass[player] or {}
		OwnsPass[player].VIP = (not OwnsPass[player].VIP) or nil
		applyVipAccess(player)
		applySpeed(player)
		notify(player, OwnsPass[player].VIP and "VIP perks ON (test)" or "VIP perks OFF", GOLD)
	elseif cmd == "Bosses" then
		Config.BossesEnabled = not Config.BossesEnabled
		notify(player, Config.BossesEnabled and "Bosses ON" or "Bosses OFF", GOLD)
	elseif cmd == "ClearPickups" then
		respawnAllPickups()
	elseif cmd == "GrantAdmin" then
		grantAdmin(player, a, b)
	elseif cmd == "RevokeAdmin" then
		revokeAdmin(player, a)
	elseif cmd == "Wipe" then
		-- WIPE EVERYTHING: cash, goobers, pets, upgrades, rebirths, codes, daily streak... back to a brand new player
		tradeCancel(player)
		Data[player] = defaultData()
		d = Data[player]
		Carrying[player] = {}
		syncCarry(player)
		Boosts[player] = { Speed = 0, Jump = 0, Shield = 0, Cash = 0, Magnet = 0, Guard = 0 }
		for _, k in ipairs(BOOST_KINDS) do
			player:SetAttribute("Boost" .. k, 0)
		end
		GodMode[player] = nil
		MagnetFilter[player] = nil
		player:SetAttribute("MagnetFilter", nil)
		for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), char }) do
			local w = holder and holder:FindFirstChild("Wacker")
			if w then
				w:Destroy()
			end
		end
		player:SetAttribute("Collects", 0)
		player:SetAttribute("GooberUpgrades", 0)
		player:SetAttribute("GiftReady", false)
		player:SetAttribute("TutDone", false)
		player:SetAttribute("GroupClaimed", false)
		player:SetAttribute("MaxZone", 0)
		if PlotOf[player] then
			clearPlot(PlotOf[player])
			if char then
				char:PivotTo(spawnCFrame(PlotOf[player]))
			end
		end
		wipeLeaderboards(player)
		task.spawn(saveData, player)
		notify(player, "Everything wiped!", GOLD, "reveal")
	end
	refresh(player)
end

-- pet slots 3 and 4 cost cash (slots 5 and 6 are Robux purchases)
local function buyPetSlot(player)
	local d = Data[player]
	if not d then
		return
	end
	local slots = Config.PetSlots(d.PetSlots)
	if slots >= Config.MaxPetSlots then
		notify(player, "All slots unlocked!", GOLD)
		return
	end
	local cost = Config.PetSlotCost(slots + 1)
	if not cost then
		notify(player, "This slot costs Robux", GOLD)
		return
	end
	if d.Cash < cost then
		notify(player, "Need $" .. Config.Format(cost), RED)
		return
	end
	d.Cash -= cost
	d.PetSlots += 1
	notify(player, ("%d pet slots!"):format(Config.PetSlots(d.PetSlots)), GREEN, "reveal")
	refresh(player)
	task.spawn(saveData, player)
end

-- TUTORIAL WHEEL: the prize for finishing (or skipping) the tutorial. The SERVER picks the egg, the client just animates the wheel.
local spinWheel, useBankedSpin -- these two are called from the Action dispatcher far below, so they have to escape
do -- scoped: rollWheelIndex and grantWheelResult are only used by spinWheel/useBankedSpin right here
	local function rollWheelIndex()
		local total = 0
		for _, w in ipairs(Config.TutorialWheel) do
			total += w.Weight
		end
		local r, index = rng:NextNumber() * total, 1
		for i, w in ipairs(Config.TutorialWheel) do
			r -= w.Weight
			if r <= 0 then
				index = i
				break
			end
		end
		return index
	end

	local function grantWheelResult(player, index)
		local rarity = Config.TutorialWheel[index].Rarity
		local def -- a goober of the rolled rarity from the first zone
		for _, g in ipairs(Config.Goobers) do
			if g.Zone == Config.WheelGooberZone and g.Rarity == rarity then
				def = g
				break
			end
		end
		def = def or Config.RollGoober(Config.WheelGooberZone, 0)
		UIRemote:FireClient(player, "WheelResult", index)
		task.spawn(saveData, player)
		task.delay(Config.WheelSpinSeconds, function()
			if Data[player] then
				grantItem(player, { Id = def.Id, Mut = "Normal" }, "the wheel", true)
				task.spawn(saveData, player)
			end
		end)
	end

	function spinWheel(player)
		local d = Data[player]
		if not d or not d.TutorialDone or d.WheelClaimed then
			return
		end
		d.WheelClaimed = true
		player:SetAttribute("WheelReady", false)
		grantWheelResult(player, rollWheelIndex())
	end

	-- the repeatable spin bank: free spins from waiting (Config.SpinRegenSeconds) or from codes, up to Config.SpinMax
	function useBankedSpin(player)
		local d = Data[player]
		if not d or d.Spins <= 0 then
			return
		end
		d.Spins -= 1
		player:SetAttribute("Spins", d.Spins)
		grantWheelResult(player, rollWheelIndex())
	end
end

-- Drop the goober you picked up LAST (key Q). It lands in front of you and can't be grabbed again for 2 seconds.
local function dropOne(player)
	local list, d = Carrying[player], Data[player]
	if not list or not d or #list == 0 or (Stunned[player] or 0) > os.clock() then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local look = hrp.CFrame.LookVector
	local x = hrp.Position.X + look.X * 5
	local z = math.clamp(hrp.Position.Z + look.Z * 5, -RW / 2 + 6, RW / 2 - 6)
	if x < RS_START + 14 or x > RUNWAY_END - 4 then
		notify(player, "Drop it out on the runway", GOLD)
		return
	end
	local item = table.remove(list)
	NoGrab[player] = os.clock() + 2
	syncCarry(player)
	createPickup(item, Vector3.new(x, 0, z), nil, 60)
	notify(player, "", GOLD, "pop")
end

----------------------------------------------------------------
-- REMOTE HANDLER
----------------------------------------------------------------
ActionRemote.OnServerEvent:Connect(function(player, action, arg, arg2, arg3)
	if typeof(action) ~= "string" then
		return
	end
	local now = os.clock()
	if LastAction[player] and now - LastAction[player] < 0.12 then
		return
	end
	LastAction[player] = now
	if not Data[player] then
		return
	end
	if action == "Upgrade" then
		buyUpgrade(player, arg, arg2)
	elseif action == "Hatch" then
		hatchEgg(player, arg)
	elseif action == "ClaimDaily" then
		claimDaily(player)
	elseif action == "ClaimGroup" then
		claimGroup(player)
	elseif action == "TutorialDone" then
		local d = Data[player]
		if d then
			d.TutorialDone = true
			player:SetAttribute("TutDone", true)
			if not d.WheelClaimed then -- finished OR skipped: time to spin the wheel for a free egg
				player:SetAttribute("WheelReady", true)
				UIRemote:FireClient(player, "WheelStart")
			end
			task.spawn(saveData, player)
		end
	elseif action == "SpinWheel" then
		spinWheel(player)
	elseif action == "UseSpin" then
		useBankedSpin(player)
	elseif action == "ClaimOffline" then
		local d = Data[player]
		if d and d.PendingOffline and d.PendingOffline > 0 then
			d.Cash += d.PendingOffline
			d.PendingOffline = nil
			refresh(player)
			task.spawn(saveData, player)
		end
	elseif action == "Drop" then
		dropOne(player)
	elseif action == "Admin" then
		adminCommand(player, arg, arg2, arg3)
	elseif action == "TeleportMarket" then
		teleportMarket(player, arg)
	elseif action == "LuckyBox" then
		buyLuckyBox(player)
	elseif action == "LockBase" then
		lockBase(player)
	elseif action == "Rebirth" then
		rebirth(player)
	elseif action == "Teleport" then
		teleportBase(player)
	elseif action == "Redeem" then
		redeemCode(player, arg)
	elseif action == "ShopBuy" then
		shopBuy(player, arg, arg2)
	elseif action == "MagnetFilter" then
		local bm = Boosts[player]
		if bm and (bm.Magnet or 0) > Workspace:GetServerTimeNow() then
			setMagnetFilter(player, arg) -- free: change what the running magnet pulls in
		end
	elseif action == "BuyPetSlot" then
		buyPetSlot(player)
	elseif action == "CollectAll" then
		collectAll(player)
	elseif action == "PlaceTrap" then
		placeTrap(player)
	elseif action == "ClaimGift" then
		claimGift(player)
	elseif action == "PetRelease" then
		PetOps.sell(player, "eq", arg)
	elseif action == "PetEquip" then
		PetOps.equip(player, arg)
	elseif action == "PetUnequip" then
		PetOps.unequip(player, arg)
	elseif action == "PetSwap" then
		PetOps.swap(player, arg, arg2)
	elseif action == "PetSell" then
		PetOps.sell(player, arg, arg2)
	elseif action == "TradeRequest" then
		tradeRequest(player, arg)
	elseif action == "TradeRespond" then
		tradeRespond(player, arg == true)
	elseif action == "TradeAdd" then
		tradeAdd(player, arg)
	elseif action == "TradeRemove" then
		tradeRemove(player, arg)
	elseif action == "TradeReady" then
		tradeReady(player, arg)
	elseif action == "TradeCancel" then
		tradeCancel(player)
	end
end)

----------------------------------------------------------------
-- SAVING / LOADING
----------------------------------------------------------------
local NUMBER_KEYS = { "Cash", "Rebirths", "SpeedLvl", "CarryLvl", "SlotLvl", "LuckLvl", "FloorLvl", "PlayTime", "Traps", "PetSlots", "Donated", "DailyLast", "DailyStreak", "DailyWeeks", "Deaths", "MaxZone", "Spins", "LastSpinRegen", "FloodDeaths", "LastSeen" }


local function loadData(player)
	local d = defaultData()
	if not Store then
		SaveAllowed[player] = false
		warn("[Goober] DataStore unavailable - progress will not save (enable API access in Studio).")
		return d
	end
	local key = "P_" .. player.UserId
	local ok, result = false, nil
	for _ = 1, 3 do
		ok, result = pcall(function()
			return Store:GetAsync(key)
		end)
		if ok then
			break
		end
		task.wait(1)
	end
	SaveAllowed[player] = ok
	if not ok then
		warn("[Goober] Could not load data for " .. player.Name .. ": " .. tostring(result))
		return d
	end
	if type(result) == "table" then
		for _, k in ipairs(NUMBER_KEYS) do
			if type(result[k]) == "number" then
				d[k] = result[k]
			end
		end
		d.Wacker = result.Wacker == true
		-- v11 cut the runway from 28 zones to 14: an older save gets its zone progress halved, and (below) goobers / pets that no
		-- longer exist are swapped for ones of the same tier, so nobody loses anything
		local ver = tonumber(result.DataVersion) or 0
		local legacy = ver < 12 -- (v12 = the 5 new eggs and their pets)
		if ver < 11 then
			d.MaxZone = math.ceil(d.MaxZone / 2) -- (v11 = 14 zones instead of 28)
		end
		if ver < 13 and table.find(Config.Admins, player.UserId) then
			-- v13: admin cash gets halved once, so testing/admin commands don't leave admins
			-- permanently ahead of everyone else. Applies to the owner too - nobody is exempted.
			d.Cash = math.floor(d.Cash / 2)
		end
		if ver < 14 and table.find(Config.Admins, player.UserId) then
			-- v14 (this release): halved again for the same reason - a big batch of admin testing happened
			d.Cash = math.floor(d.Cash / 2)
		end
		d.Spins = math.clamp(math.floor(tonumber(result.Spins) or 1), 0, Config.SpinMax)
		d.LastSpinRegen = tonumber(result.LastSpinRegen) or os.time()
		d.FloodDeaths = math.max(0, math.floor(tonumber(result.FloodDeaths) or 0))
		d.MaxZone = math.clamp(math.floor(d.MaxZone), 0, Config.ZoneCount)
		d.TutorialDone = result.TutorialDone == true
		d.WheelClaimed = result.WheelClaimed == true or (result.TutorialDone == true and result.WheelClaimed == nil) -- (old saves already did the tutorial)
		d.GroupClaimed = result.GroupClaimed == true
		if type(result.ShopBuys) == "table" then
			for id, n in pairs(result.ShopBuys) do
				if type(id) == "string" and type(n) == "number" then
					d.ShopBuys[id] = math.clamp(math.floor(n), 0, 200)
				end
			end
		end
		d.GiftClaimed = result.GiftClaimed == true
		d.Pets = {}
		if type(result.Pets) == "table" then
			for _, id in ipairs(result.Pets) do
				if type(id) == "string" and #d.Pets < Config.MaxPetSlots then
					if Config.PetById[id] then
						table.insert(d.Pets, id)
					elseif legacy then -- an old pet that was replaced: a new pet from an egg of about the same tier
						local egg = Config.Eggs[math.clamp(math.ceil(#Config.Eggs * d.MaxZone / Config.ZoneCount), 1, #Config.Eggs)]
						table.insert(d.Pets, rollPet(egg).Id)
					end
				end
			end
		end
		d.PetBox = {}
		if type(result.PetBox) == "table" then
			for _, id in ipairs(result.PetBox) do
				if type(id) == "string" and Config.PetById[id] and #d.PetBox < Config.PetBoxMax then
					table.insert(d.PetBox, id)
				end
			end
		end
		if type(result.Index) == "table" then
			for _, kind in ipairs({ "G", "P" }) do
				local src = result.Index[kind]
				if type(src) == "table" then
					for _, id in ipairs(src) do
						if type(id) == "string" and ((kind == "G" and Config.GooberById[id]) or (kind == "P" and Config.PetById[id])) then
							d.Index[kind][id] = true
						end
					end
				end
			end
			d.Index.GC = math.clamp(math.floor(tonumber(result.Index.GC) or 0), 0, 1000)
			d.Index.PC = math.clamp(math.floor(tonumber(result.Index.PC) or 0), 0, 1000)
		end
		d.Placed = {}
		if type(result.Placed) == "table" then
			for _, item in ipairs(result.Placed) do
				if type(item) == "table" and Config.GooberById[item.Id] and Config.Mutations[item.Mut] then
					table.insert(d.Placed, {
						Id = item.Id,
						Mut = item.Mut,
						Lvl = math.clamp(math.floor(tonumber(item.Lvl) or 0), 0, Config.GooberMaxLevel),
						Stored = math.max(0, tonumber(item.Stored) or 0),
					})
				elseif legacy and type(item) == "table" and Config.Mutations[item.Mut] and type(item.Id) == "string" then
					local def = Config.RollGoober(math.max(1, d.MaxZone), 0) -- an old goober that was replaced: a new one of the same tier
					table.insert(d.Placed, { Id = def.Id, Mut = item.Mut, Lvl = 0, Stored = 0 })
				end
			end
		end
		if type(result.Codes) == "table" then
			for code, used in pairs(result.Codes) do
				if type(code) == "string" and used == true then
					d.Codes[code] = true
				end
			end
		end
	end
	d.SpeedLvl = math.clamp(math.floor(d.SpeedLvl), 0, Config.Upgrades.Speed.Max)
	d.CarryLvl = math.max(0, math.floor(d.CarryLvl)) -- capped below by your Rebirths
	d.SlotLvl = math.clamp(math.floor(d.SlotLvl), 0, Config.Upgrades.Slots.Max)
	d.LuckLvl = math.clamp(math.floor(d.LuckLvl), 0, Config.Upgrades.Luck.Max)
	d.FloorLvl = math.clamp(math.floor(d.FloorLvl), 0, Config.Upgrades.Floors.Max)
	d.Traps = math.clamp(math.floor(d.Traps), 0, Config.MaxTraps)
	d.PetSlots = math.clamp(math.floor(d.PetSlots), 0, Config.MaxPetSlots - Config.PetSlotsFree)
	d.CarryLvl = math.clamp(d.CarryLvl, 0, Config.CarryMaxLevel(d.Rebirths))
	d.DailyStreak = math.clamp(math.floor(d.DailyStreak), 0, 6)
	d.DailyWeeks = math.clamp(math.floor(d.DailyWeeks), 0, 2000)
	d.Deaths = math.clamp(math.floor(d.Deaths), 0, 1e6)
	d.DailyLast = math.max(0, math.floor(d.DailyLast))
	while #d.Placed > Config.TotalSlots do -- more goobers than the base can hold (the max is 5 floors now): they are SOLD, not deleted
		local item = table.remove(d.Placed)
		d.Cash += itemIncome(item) * Config.SellMultiplier
	end
	return d
end

function saveData(player)
	local d = Data[player]
	if not d or not Store or not SaveAllowed[player] then
		return
	end
	d.LastSeen = os.time()
	-- Goobers sitting in an open trade window are saved too, so nothing is ever lost
	local placed = table.clone(d.Placed)
	local s = Trades[player]
	if s then
		for _, item in ipairs(s.Offer[player]) do
			table.insert(placed, item)
		end
	end
	local idxG, idxP = {}, {}
	for id in pairs(d.Index.G) do
		table.insert(idxG, id)
	end
	for id in pairs(d.Index.P) do
		table.insert(idxP, id)
	end
	local payload = { PetBox = d.PetBox, Index = { G = idxG, P = idxP, GC = d.Index.GC, PC = d.Index.PC }, Placed = placed, Codes = d.Codes, Wacker = d.Wacker, GiftClaimed = d.GiftClaimed, Pets = d.Pets, TutorialDone = d.TutorialDone, WheelClaimed = d.WheelClaimed, DataVersion = 14, GroupClaimed = d.GroupClaimed, ShopBuys = d.ShopBuys }
	for _, k in ipairs(NUMBER_KEYS) do
		payload[k] = d[k]
	end
	for _ = 1, 3 do
		local ok, err = pcall(function()
			Store:SetAsync("P_" .. player.UserId, payload)
		end)
		if ok then
			return
		end
		warn("[Goober] Save failed: " .. tostring(err))
		task.wait(1)
	end
end

----------------------------------------------------------------
-- ROBUX ITEMS (Gamepasses + Developer Products)
----------------------------------------------------------------
local function checkPasses(player)
	OwnsPass[player] = {}
	for key, info in pairs(Config.GamePasses) do
		if info.Id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.Id)
			end)
			if ok and owns then
				OwnsPass[player][key] = true
			end
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	for key, info in pairs(Config.GamePasses) do
		if info.Id == passId and info.Id > 0 then
			OwnsPass[player] = OwnsPass[player] or {}
			OwnsPass[player][key] = true
			applyVipAccess(player)
			applySpeed(player)
			refresh(player)
			notify(player, "Purchase successful: " .. info.Label .. "!", GOLD, "reveal")
		end
	end
end)

local function processReceiptInner(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local d = player and Data[player]
	if not player or not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local P = Config.Products
	if P.LuckyBox.Id > 0 and receipt.ProductId == P.LuckyBox.Id then
		grantItem(player, rollLuckyItem(d, true), "Robux Lucky Box", true)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	elseif (P.PetSlot5.Id > 0 and receipt.ProductId == P.PetSlot5.Id) or (P.PetSlot6.Id > 0 and receipt.ProductId == P.PetSlot6.Id) then
		if Config.PetSlots(d.PetSlots) >= Config.MaxPetSlots then
			d.Cash += 250000 -- already at the max: compensate with cash
			notify(player, "Purchase successful! Max slots already - +$250K instead", GOLD, "reveal")
		else
			d.PetSlots += 1
			notify(player, ("Purchase successful! %d pet slots now"):format(Config.PetSlots(d.PetSlots)), GREEN, "reveal")
		end
		refresh(player)
		task.spawn(saveData, player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	elseif P.SuperLock.Id > 0 and receipt.ProductId == P.SuperLock.Id then
		startLock(player, Config.SuperLockSeconds)
		notify(player, "Purchase successful: Super Lock active!", GREEN, "reveal")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- DONATIONS: pure support, no gameplay reward - but the in-game Top Donators board updates right away
	for _, key in ipairs(Config.DonationTiers) do
		local prod = P[key]
		if prod.Id > 0 and receipt.ProductId == prod.Id then
			d.Donated += prod.Price
			notify(player, Config.ThankYouFor(player.DisplayName, math.floor(d.Donated)), GOLD, "reveal")
			announceToChat(("💖 %s just donated R$%d! Thank you! 💖"):format(player.DisplayName, prod.Price))
			AnnounceRemote:FireAllClients("💖 THANK YOU! 💖", ("%s just donated R$%d!"):format(player.DisplayName, prod.Price), GOLD, "reveal")
			task.spawn(function()
				pushLeaderboards(player)
				refreshBoards()
			end)
			task.spawn(saveData, player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	-- 3x egg opening (one Developer Product per egg)
	for _, egg in ipairs(Config.Eggs) do
		if egg.Product3.Id > 0 and receipt.ProductId == egg.Product3.Id then
			if hatchTriple(player, egg) then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = function(receipt)
	local pl = Players:GetPlayerByUserId(receipt.PlayerId)
	local buyerName = pl and pl.Name or ("UserId " .. tostring(receipt.PlayerId))
	print(("[ROBUX] %s is buying product %d (spent %s Robux)"):format(buyerName, receipt.ProductId, tostring(receipt.CurrencySpent)))
	local ok, decision = pcall(processReceiptInner, receipt)
	if not ok then
		-- something errored INSIDE the purchase logic - never silently eat a real payment: log it loudly and tell
		-- Roblox to retry later (NotProcessedYet), so the player still gets their item once this is fixed
		warn(("[ROBUX] ERROR while granting product %d to %s: %s - Roblox WILL retry automatically"):format(receipt.ProductId, buyerName, tostring(decision)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
		print(("[ROBUX] granted product %d to %s"):format(receipt.ProductId, buyerName))
		local dd = pl and Data[pl]
		if dd then
			-- (Top Donators only counts DONATION products - that's added in processReceiptInner, not here)
			updateStats(pl)
			task.spawn(saveData, pl)
		end
	else
		-- NOTHING in Config.GamePasses/Products/Eggs matched this ProductId. Almost always this means the id in
		-- Config doesn't match what's live on the Creator Dashboard (a typo, or the place wasn't republished after
		-- the id was set) - check the Product ID column on the Dashboard against Config.Products / egg.Product3.
		warn(("[ROBUX] product %d from %s matched NOTHING in Config - check the ids in Config.GamePasses/Config.Products against the Creator Dashboard. Roblox will keep retrying until this is fixed, so republishing with the correct id still grants it."):format(receipt.ProductId, buyerName))
	end
	return decision
end

----------------------------------------------------------------
-- LIGHTING (pretty sky, glow and colors)
----------------------------------------------------------------
local function setupLighting()
	-- the plaza's calm daytime look. Every zone has its own sky: the client fades to it when you enter (Config.SkyFor)
	local sky = Config.SkyFor(0)
	Lighting.ClockTime = sky.Clock
	Lighting.Brightness = sky.Brightness
	Lighting.Ambient = sky.Ambient
	Lighting.OutdoorAmbient = sky.Outdoor
	Lighting.ExposureCompensation = sky.Exposure
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	local function ensure(class, props)
		local o = Lighting:FindFirstChildOfClass(class) or Instance.new(class)
		for k, v in pairs(props) do
			o[k] = v
		end
		o.Parent = Lighting
	end
	ensure("Atmosphere", { Density = sky.Density, Offset = 0.25, Color = sky.Atmo, Decay = sky.Decay, Glare = 0.2, Haze = sky.Haze })
	ensure("BloomEffect", { Intensity = sky.Bloom, Size = 24, Threshold = 1.2 })
	ensure("ColorCorrectionEffect", { Saturation = sky.Saturation, Contrast = 0.06, Brightness = 0, TintColor = sky.Tint })
	ensure("SunRaysEffect", { Intensity = 0.08, Spread = 0.7 })
end

local DECOR, decorTree, lampPost, fountain, wall
do
	----------------------------------------------------------------
	-- SCENERY (all built by code, one style per zone)
	----------------------------------------------------------------
	local LEAF_COLORS = {
		Color3.fromRGB(90, 210, 90),
		Color3.fromRGB(255, 150, 200),
		Color3.fromRGB(255, 205, 90),
	}

	function decorTree(x, z, scale)
		scale = scale or 1
		part({
			Name = "Trunk",
			Size = Vector3.new(2 * scale, 7 * scale, 2 * scale),
			Position = Vector3.new(x, 3.5 * scale, z),
			Color = Color3.fromRGB(150, 100, 60),
			CanCollide = false,
		}, Decor)
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(9 * scale, 9 * scale, 9 * scale),
			Position = Vector3.new(x, 10 * scale, z),
			Color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)],
			CanCollide = false,
		}, Decor)
	end

	local function decorCrystal(x, z)
		local h = rng:NextNumber(6, 18)
		part({
			Name = "Crystal",
			Size = Vector3.new(3, h, 3),
			CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-12, 12))),
			Color = Color3.fromRGB(150, 230, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.25,
			CanCollide = false,
		}, Decor)
	end

	local function decorLava(x, z)
		local s = rng:NextNumber(6, 14)
		part({
			Name = "Rock",
			Size = Vector3.new(s, s * 0.8, s),
			CFrame = CFrame.new(x, s * 0.4, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Color = Color3.fromRGB(60, 45, 50),
			Material = Enum.Material.Slate,
			CanCollide = false,
		}, Decor)
		part({
			Name = "LavaPool",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 16, 16),
			CFrame = CFrame.new(x + 13, 0.1, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 110, 30),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, Decor)
	end

	local function decorPlanet(x, z)
		local s = rng:NextNumber(6, 20)
		part({
			Name = "Planet",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, s, s),
			Position = Vector3.new(x, rng:NextNumber(10, 60), z),
			Color = Color3.fromHSV(rng:NextNumber(), 0.6, 1),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, Decor)
	end

	local function decorCandy(x, z)
		local h = rng:NextNumber(8, 16)
		local s = rng:NextNumber(7, 11)
		part({ Name = "LollipopStick", Size = Vector3.new(1.2, h, 1.2), Position = Vector3.new(x, h / 2, z), Color = WHITE, CanCollide = false }, Decor)
		part({
			Name = "Lollipop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, s, s),
			Position = Vector3.new(x, h + s / 2 - 1, z),
			Color = Color3.fromHSV(rng:NextNumber(), 0.5, 1),
			CanCollide = false,
		}, Decor)
	end

	local function decorOcean(x, z)
		local h = rng:NextNumber(6, 14)
		part({
			Name = "Coral",
			Size = Vector3.new(2.5, h, 2.5),
			CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-10, 10))),
			Color = Color3.fromHSV((rng:NextNumber(0.9, 1.1)) % 1, 0.55, 1),
			CanCollide = false,
		}, Decor)
		local b = rng:NextNumber(4, 9)
		part({
			Name = "Bubble",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(b, b, b),
			Position = Vector3.new(x + rng:NextNumber(-8, 8), rng:NextNumber(12, 40), z + rng:NextNumber(-8, 8)),
			Color = Color3.fromRGB(190, 240, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.5,
			CanCollide = false,
		}, Decor)
	end

	local NEON_HUES = { 0.5, 0.83, 0.33 }
	local function decorCyber(x, z)
		local h = rng:NextNumber(10, 45)
		part({
			Name = "NeonTower",
			Size = Vector3.new(3, h, 3),
			Position = Vector3.new(x, h / 2, z),
			Color = Color3.fromHSV(NEON_HUES[rng:NextInteger(1, #NEON_HUES)], 1, 1),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, Decor)
	end

	local function decorCloud(x, z)
		local y = rng:NextNumber(18, 45)
		for _ = 1, 3 do
			local s = rng:NextNumber(8, 16)
			part({
				Name = "Cloud",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(s, s, s),
				Position = Vector3.new(x + rng:NextNumber(-8, 8), y + rng:NextNumber(-2, 2), z + rng:NextNumber(-8, 8)),
				Color = Color3.fromRGB(255, 255, 255),
				Transparency = 0.1,
				CanCollide = false,
			}, Decor)
		end
	end

	local function decorPalm(x, z)
		local h = rng:NextNumber(12, 20)
		part({
			Name = "PalmTrunk",
			Size = Vector3.new(2, h, 2),
			CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
			Color = Color3.fromRGB(150, 105, 60),
			CanCollide = false,
		}, Decor)
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2
			part({
				Name = "Frond",
				Size = Vector3.new(9, 0.6, 2.5),
				CFrame = CFrame.new(x + math.cos(a) * 4, h + 1, z + math.sin(a) * 4) * CFrame.Angles(0, -a, math.rad(-20)),
				Color = Color3.fromRGB(70, 200, 90),
				CanCollide = false,
			}, Decor)
		end
	end

	local function decorCactus(x, z)
		local h = rng:NextNumber(8, 16)
		local col = Color3.fromRGB(80, 180, 90)
		part({ Name = "Cactus", Size = Vector3.new(3, h, 3), Position = Vector3.new(x, h / 2, z), Color = col, CanCollide = false }, Decor)
		part({ Name = "CactusArm", Size = Vector3.new(6, 1.8, 1.8), Position = Vector3.new(x + 3, h * 0.55, z), Color = col, CanCollide = false }, Decor)
		part({ Name = "CactusArmUp", Size = Vector3.new(1.8, 4, 1.8), Position = Vector3.new(x + 5.4, h * 0.55 + 2, z), Color = col, CanCollide = false }, Decor)
	end

	local function decorBlock(x, z)
		local s = rng:NextNumber(6, 12)
		part({
			Name = "ToyBlock",
			Size = Vector3.new(s, s, s),
			CFrame = CFrame.new(x, s / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Color = Color3.fromHSV(rng:NextNumber(), 0.7, 1),
			CanCollide = false,
		}, Decor)
		part({
			Name = "ToyBlockTop",
			Size = Vector3.new(s * 0.6, s * 0.6, s * 0.6),
			CFrame = CFrame.new(x, s + s * 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Color = Color3.fromHSV(rng:NextNumber(), 0.7, 1),
			CanCollide = false,
		}, Decor)
	end

	local function decorRainbow(x, z)
		local segH = rng:NextNumber(3, 6)
		for i = 1, 6 do
			part({
				Name = "RainbowSegment",
				Size = Vector3.new(4, segH, 4),
				Position = Vector3.new(x, segH * (i - 0.5), z),
				Color = Color3.fromHSV((i - 1) / 6, 0.8, 1),
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, Decor)
		end
	end

	local function decorMushroom(x, z)
		local h = rng:NextNumber(5, 11)
		part({ Name = "Stem", Size = Vector3.new(2.6, h, 2.6), Position = Vector3.new(x, h / 2, z), Color = Color3.fromRGB(240, 230, 215), CanCollide = false }, Decor)
		local d = rng:NextNumber(7, 13)
		local capCol = Color3.fromHSV(rng:NextNumber(0.75, 1.0) % 1, 0.65, 1)
		part({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), Position = Vector3.new(x, h + d * 0.15, z), Color = capCol, CanCollide = false }, Decor)
		for i = 1, 4 do
			local a = (i / 4) * math.pi * 2
			part({ Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Position = Vector3.new(x + math.cos(a) * d * 0.32, h + d * 0.55, z + math.sin(a) * d * 0.32), Color = WHITE, CanCollide = false }, Decor)
		end
	end

	local function decorGrave(x, z)
		local h = rng:NextNumber(4, 7)
		part({ Name = "Tombstone", Size = Vector3.new(3.4, h, 1.2), CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), math.rad(rng:NextNumber(-6, 6))), Color = Color3.fromRGB(120, 124, 140), CanCollide = false }, Decor)
		if rng:NextNumber() < 0.5 then
			part({ Name = "Wisp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Position = Vector3.new(x, h + rng:NextNumber(2, 6), z), Color = Color3.fromRGB(120, 255, 150), Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false }, Decor)
		end
	end

	local function decorGear(x, z)
		local d = rng:NextNumber(8, 16)
		part({ Name = "Gear", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, d, d), CFrame = CFrame.new(x, d / 2, z) * CFrame.Angles(math.rad(rng:NextNumber(0, 180)), 0, 0), Color = Color3.fromRGB(176, 118, 74), Material = Enum.Material.Metal, CanCollide = false }, Decor)
		part({ Name = "GearHub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, d * 0.3, d * 0.3), CFrame = CFrame.new(x, d / 2, z), Color = Color3.fromRGB(230, 190, 120), Material = Enum.Material.Metal, CanCollide = false }, Decor)
	end

	local function decorBarrel(x, z)
		local h = rng:NextNumber(4, 6)
		local UP = CFrame.Angles(0, 0, math.rad(90))
		part({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 4.4, 4.4), CFrame = CFrame.new(x, h / 2, z) * UP, Color = Color3.fromRGB(150, 100, 60), CanCollide = false }, Decor)
		part({ Name = "BarrelBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 4.6, 4.6), CFrame = CFrame.new(x, h * 0.3, z) * UP, Color = Color3.fromRGB(60, 60, 70), CanCollide = false }, Decor)
		part({ Name = "BarrelBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 4.6, 4.6), CFrame = CFrame.new(x, h * 0.75, z) * UP, Color = Color3.fromRGB(60, 60, 70), CanCollide = false }, Decor)
	end

	local function decorGem(x, z)
		local h = rng:NextNumber(6, 16)
		part({ Name = "Gem", Size = Vector3.new(3.5, h, 3.5), CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-10, 10))), Color = Color3.fromHSV(rng:NextNumber(0.72, 0.85), 0.7, 1), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false }, Decor)
	end

	local function decorPixel(x, z)
		local n = rng:NextInteger(1, 3)
		local hue = (rng:NextNumber() < 0.5) and 0.47 or 0.9
		for i = 1, n do
			part({ Name = "Pixel", Size = Vector3.new(4, 4, 4), Position = Vector3.new(x + rng:NextNumber(-1, 1), 2 + (i - 1) * 4, z + rng:NextNumber(-1, 1)), Color = Color3.fromHSV(hue, 0.8, 1), Material = Enum.Material.Neon, CanCollide = false }, Decor)
		end
	end

	local function decorStar(x, z)
		local s = rng:NextNumber(2, 6)
		local star = part({ Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), Position = Vector3.new(x, rng:NextNumber(14, 70), z), Color = Color3.fromRGB(255, 250, 180), Material = Enum.Material.Neon, CanCollide = false }, Decor)
		if s > 4.5 then
			local l = Instance.new("PointLight")
			l.Range = 30
			l.Color = Color3.fromRGB(255, 245, 190)
			l.Parent = star
		end
	end

	local function decorGold(x, z)
		local h = rng:NextNumber(8, 18)
		part({ Name = "GoldPillar", Size = Vector3.new(3, h, 3), Position = Vector3.new(x, h / 2, z), Color = Color3.fromRGB(240, 190, 60), Material = Enum.Material.Metal, CanCollide = false }, Decor)
		part({ Name = "GoldOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), Position = Vector3.new(x, h + 2, z), Color = Color3.fromRGB(255, 225, 110), Material = Enum.Material.Neon, CanCollide = false }, Decor)
	end

	local function decorNeon(x, z)
		local h = rng:NextNumber(18, 50)
		local hue = (rng:NextNumber() < 0.5) and 0.88 or 0.5
		part({ Name = "NeonBase", Size = Vector3.new(6, h * 0.35, 6), Position = Vector3.new(x, h * 0.175, z), Color = Color3.fromRGB(28, 26, 50), CanCollide = false }, Decor)
		part({ Name = "NeonTube", Size = Vector3.new(2.4, h, 2.4), Position = Vector3.new(x, h / 2, z), Color = Color3.fromHSV(hue, 0.85, 1), Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false }, Decor)
	end

	local function decorCoral(x, z)
		local hue = rng:NextNumber(0.0, 0.12)
		for i = 1, rng:NextInteger(3, 5) do
			local h = rng:NextNumber(5, 14)
			local ox, oz = rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)
			local col = Color3.fromHSV(hue + i * 0.02, 0.6, 1)
			part({ Name = "Coral", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.6, 1.6), CFrame = CFrame.new(x + ox, h / 2, z + oz) * CFrame.Angles(0, 0, math.rad(90 + rng:NextNumber(-14, 14))), Color = col, CanCollide = false }, Decor)
			part({ Name = "CoralTip", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), Position = Vector3.new(x + ox, h + 0.6, z + oz), Color = col:Lerp(WHITE, 0.3), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false }, Decor)
		end
	end

	local function decorRuins(x, z)
		local h = rng:NextNumber(6, 16)
		part({ Name = "RuinPillar", Size = Vector3.new(3.4, h, 3.4), CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), rng:NextNumber(0, 3), math.rad(rng:NextNumber(-4, 4))), Color = Color3.fromRGB(128, 136, 118), Material = Enum.Material.Slate, CanCollide = false }, Decor)
		part({ Name = "RuinBlock", Size = Vector3.new(4.5, 2.2, 3.5), CFrame = CFrame.new(x + rng:NextNumber(3, 6), 1.1, z + rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = Color3.fromRGB(110, 118, 100), Material = Enum.Material.Slate, CanCollide = false }, Decor)
		part({ Name = "Moss", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 2.4, 4), Position = Vector3.new(x, h + 0.6, z), Color = Color3.fromRGB(70, 160, 80), CanCollide = false }, Decor)
	end

	local function decorToy(x, z)
		local hue = rng:NextNumber()
		for i = 1, rng:NextInteger(1, 3) do
			part({ Name = "ToyBlock", Size = Vector3.new(4.2, 4.2, 4.2), CFrame = CFrame.new(x + rng:NextNumber(-0.8, 0.8), 2.1 + (i - 1) * 4.2, z + rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), Color = Color3.fromHSV((hue + i * 0.18) % 1, 0.7, 1), CanCollide = false }, Decor)
		end
		part({ Name = "ToyBall", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3.4, 3.4), Position = Vector3.new(x + 5, 1.7, z + rng:NextNumber(-3, 3)), Color = Color3.fromHSV((hue + 0.5) % 1, 0.7, 1), CanCollide = false }, Decor)
	end

	local function decorSpire(x, z)
		local h = rng:NextNumber(14, 44)
		part({ Name = "Spire", Size = Vector3.new(6, h, 6), CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(rng:NextNumber(-5, 5))), Color = Color3.fromRGB(62, 46, 46), Material = Enum.Material.Basalt, CanCollide = false }, Decor)
		part({ Name = "SpireMagma", Size = Vector3.new(3.2, 1.2, 3.2), Position = Vector3.new(x, h * 0.6, z), Color = Color3.fromRGB(255, 110, 40), Material = Enum.Material.Neon, CanCollide = false }, Decor)
		part({ Name = "SpireGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Position = Vector3.new(x, h + 1.5, z), Color = Color3.fromRGB(255, 140, 50), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false }, Decor)
	end

	local function decorStorm(x, z)
		local y = rng:NextNumber(26, 48)
		for i = 1, 3 do
			local d = rng:NextNumber(9, 16)
			part({ Name = "StormCloud", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d * 0.6, d), Position = Vector3.new(x + (i - 2) * 7, y + rng:NextNumber(-2, 2), z + rng:NextNumber(-4, 4)), Color = Color3.fromRGB(88, 96, 126), Material = Enum.Material.SmoothPlastic, CanCollide = false }, Decor)
		end
		if rng:NextNumber() < 0.5 then
			part({ Name = "Bolt", Size = Vector3.new(0.7, y - 6, 0.7), CFrame = CFrame.new(x, (y - 6) / 2, z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))), Color = Color3.fromRGB(230, 240, 255), Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false }, Decor)
		end
	end

	local function decorRift(x, z)
		local d = rng:NextNumber(10, 22)
		part({ Name = "RiftRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, d, d), CFrame = CFrame.new(x, d / 2 + 6, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = Color3.fromHSV(rng:NextNumber(0.75, 0.92), 0.8, 1), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false }, Decor)
		part({ Name = "RiftCore", Shape = Enum.PartType.Ball, Size = Vector3.new(d * 0.25, d * 0.25, d * 0.25), Position = Vector3.new(x, d / 2 + 6, z), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, CanCollide = false }, Decor)
	end

	local function decorThrone(x, z)
		local h = rng:NextNumber(12, 26)
		part({ Name = "MarblePillar", Size = Vector3.new(4.2, h, 4.2), Position = Vector3.new(x, h / 2, z), Color = Color3.fromRGB(246, 242, 234), Material = Enum.Material.Marble, CanCollide = false }, Decor)
		part({ Name = "GoldCap", Size = Vector3.new(6, 1.2, 6), Position = Vector3.new(x, h + 0.6, z), Color = Color3.fromRGB(255, 208, 70), Material = Enum.Material.Metal, CanCollide = false }, Decor)
		part({ Name = "GoldOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3.4, 3.4), Position = Vector3.new(x, h + 3, z), Color = Color3.fromRGB(255, 232, 130), Material = Enum.Material.Neon, CanCollide = false }, Decor)
	end

	DECOR = {
		tree = decorTree,
		crystal = decorCrystal,
		lava = decorLava,
		planet = decorPlanet,
		candy = decorCandy,
		ocean = decorOcean,
		cyber = decorCyber,
		cloud = decorCloud,
		palm = decorPalm,
		cactus = decorCactus,
		block = decorBlock,
		rainbow = decorRainbow,
		mushroom = decorMushroom,
		grave = decorGrave,
		gear = decorGear,
		barrel = decorBarrel,
		gem = decorGem,
		pixel = decorPixel,
		star = decorStar,
		gold = decorGold,
		neon = decorNeon,
		coral = decorCoral,
		ruins = decorRuins,
		toy = decorToy,
		spire = decorSpire,
		storm = decorStorm,
		rift = decorRift,
		throne = decorThrone,
	}

	function lampPost(x, z)
		part({ Name = "LampPole", Size = Vector3.new(0.8, 10, 0.8), Position = Vector3.new(x, 5, z), Color = Color3.fromRGB(50, 50, 70) }, Decor)
		local bulb = part({
			Name = "LampBulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			Position = Vector3.new(x, 11, z),
			Color = Color3.fromRGB(255, 240, 170),
			Material = Enum.Material.Neon,
		}, Decor)
		local l = Instance.new("PointLight")
		l.Range = 34
		l.Brightness = 1.6
		l.Color = Color3.fromRGB(255, 235, 180)
		l.Parent = bulb
	end

	-- A proper fountain: stone basin, two tiers, a centre column and REAL water: every jet is a particle stream that follows real gravity
	-- (Workspace.Gravity), so the water shoots up, arcs over and falls back into the basin. Rings ripple on the surface (moved by the client).
	function fountain(x, z)
		local STONE, STONE2 = Color3.fromRGB(198, 196, 210), Color3.fromRGB(160, 158, 178)
		local WATER = Color3.fromRGB(96, 200, 245)
		local function cyl(name, h, d, y, color, material, transparency)
			return part({
				Name = name,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(h, d, d),
				CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = color,
				Material = material or Enum.Material.Slate,
				Transparency = transparency or 0,
				CanCollide = name ~= "FountainWater",
			}, Decor)
		end
		cyl("FountainBase", 1.6, 32, 0.8, STONE2)
		cyl("FountainBasin", 3.4, 30, 2.5, STONE)
		local pool = cyl("FountainWater", 0.5, 26.6, 3.9, WATER, Enum.Material.Glass, 0.35)
		for i = 1, 18 do -- a rim of stone blocks around the basin
			local a = (i / 18) * math.pi * 2
			part({ Name = "FountainRim", Size = Vector3.new(4.2, 1.6, 2.4), CFrame = CFrame.new(x + math.cos(a) * 14.6, 4.6, z + math.sin(a) * 14.6) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = (i % 2 == 0) and STONE or STONE2, Material = Enum.Material.Slate }, Decor)
		end
		cyl("FountainPillar", 6, 5, 6.5, STONE)
		cyl("FountainBowl", 1.6, 15, 9.3, STONE2)
		cyl("FountainBowlWater", 0.4, 13, 10.2, WATER, Enum.Material.Glass, 0.35)
		cyl("FountainColumn", 5, 2.6, 12.6, STONE)
		local top = part({ Name = "FountainOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3.4, 3.4), Position = Vector3.new(x, 15.6, z), Color = STONE, Material = Enum.Material.Slate }, Decor)

		local g = Vector3.new(0, -Workspace.Gravity, 0)
		local function jet(parent, dirNormalId, speedMin, speedMax, spread, rate, life, size)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.EmissionDirection = dirNormalId
			e.Speed = NumberRange.new(speedMin, speedMax)
			e.SpreadAngle = Vector2.new(spread, spread)
			e.Acceleration = g -- REAL gravity: the drops follow true arcs
			e.Rate = rate
			e.Lifetime = NumberRange.new(life * 0.9, life * 1.1)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.5) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.85) })
			e.Color = ColorSequence.new(Color3.fromRGB(215, 245, 255), Color3.fromRGB(120, 205, 250))
			e.LightEmission = 0.6
			e.Parent = parent
			return e
		end
		-- the tall centre jet
		local upAtt = Instance.new("Attachment")
		upAtt.Position = Vector3.new(0, 1.7, 0)
		upAtt.Parent = top
		jet(upAtt, Enum.NormalId.Top, 50, 58, 4, 90, 0.75, 0.7)
		-- 10 arcing jets thrown outwards from the upper bowl: they land in the basin
		for i = 1, 10 do
			local a = (i / 10) * math.pi * 2
			local att = Instance.new("Attachment")
			att.Position = Vector3.new(math.cos(a) * 6.4, 0.6, math.sin(a) * 6.4)
			local out = Vector3.new(math.cos(a), 0.95, math.sin(a))
			att.CFrame = CFrame.lookAt(att.Position, att.Position + out)
			att.Parent = part({ Name = "FountainNozzle", Size = Vector3.new(0.4, 0.4, 0.4), Position = Vector3.new(x + math.cos(a) * 6.4, 10.6, z + math.sin(a) * 6.4), Transparency = 1, CanCollide = false }, Decor)
			jet(att, Enum.NormalId.Front, 27, 31, 3, 55, 0.62, 0.55)
		end
		-- the water falling from the upper bowl's rim into the basin
		for i = 1, 6 do
			local a = (i / 6) * math.pi * 2 + 0.3
			local p = part({ Name = "FountainDrip", Size = Vector3.new(0.3, 0.3, 0.3), Position = Vector3.new(x + math.cos(a) * 7.4, 9.9, z + math.sin(a) * 7.4), Transparency = 1, CanCollide = false }, Decor)
			jet(p, Enum.NormalId.Bottom, 1, 3, 6, 22, 0.55, 0.5)
		end
		-- splash + mist where the water lands
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
		mist.Rate = 10
		mist.Lifetime = NumberRange.new(2, 3.2)
		mist.Speed = NumberRange.new(1, 3)
		mist.SpreadAngle = Vector2.new(180, 180)
		mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 7) })
		mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 1) })
		mist.Color = ColorSequence.new(WHITE)
		mist.Parent = pool
		local foam = jet(pool, Enum.NormalId.Top, 3, 7, 60, 26, 0.5, 0.5)
		foam.Acceleration = g * 0.25
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(150, 225, 255)
		light.Range = 34
		light.Brightness = 1.2
		light.Parent = top
		-- ripples on the water (CollectionService "FountainRipple": the client makes them grow and fade)
		for i = 1, 3 do
			local r = part({ Name = "FountainRipple", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 10, 10), CFrame = CFrame.new(x, 4.2, z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 250, 255), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false }, Decor)
			r:SetAttribute("Phase", (i - 1) / 3)
			r:SetAttribute("MaxSize", 25)
			CollectionService:AddTag(r, "FountainRipple")
		end
	end

	function wall(name, size, pos, color)
		part({
			Name = name,
			Size = size,
			Position = pos,
			Color = color or Config.PlazaWallColor,
			Material = Enum.Material.SmoothPlastic,
		}, Walls)
	end

end

----------------------------------------------------------------
-- PLAYER BASES (multiple floors, glowing pedestals, lamps!)
----------------------------------------------------------------
local buildPlot -- the one name from this section that's called from buildWorld() far below, so it has to escape
do -- scoped: FLOOR_H, SPF and useElevator are only used inside buildPlot, so freeing their registers once this section ends
	local FLOOR_H = Config.FloorHeight
	local SPF = Config.SlotsPerFloor

	local function useElevator(player, plot, floorNumber)
		if plot.Locked and plot.Owner ~= player then
			notify(player, "Locked!", RED)
			return
		end
		local char = player.Character
		if char then
			char:PivotTo(CFrame.new(-28, (floorNumber - 1) * FLOOR_H + 4, plot.Zc) * CFrame.Angles(0, -math.pi / 2, 0))
			notify(player, "", GREEN, "lift")
		end
	end

	function buildPlot(i)
		local S = Config.PlotSpacing
		local zc = -((Config.PlotCount - 1) * S) / 2 + (i - 1) * S
		local model = Instance.new("Model")
		model.Name = "Plot" .. i
		model.Parent = World
		local color = Color3.fromHSV((i - 1) / Config.PlotCount, 0.4, 1)

		local plot = {
			Index = i,
			Model = model,
			Zc = zc,
			Pedestals = {},
			Rings = {},
			Pads = {},
			PadGuis = {},
			PadLabels = {},
			PadOn = {},
			PadEmitters = {},
			Buttons = {},
			ButtonGuis = {},
			ButtonLabels = {},
			ButtonPrompts = {},
			Models = {},
			FloorModels = {},
			UpPrompts = {},
			DownPrompts = {},
			Owner = nil,
			Locked = false,
			LockId = 0,
		}

		-- ground level extras: deposit pad + gate arch, spawn, sign
		local dep = part({
			Name = "DepositPad",
			Size = Vector3.new(10, 0.6, 16),
			Position = Vector3.new(-14, 0.3, zc),
			Color = Color3.fromRGB(255, 205, 60),
			Material = Enum.Material.Neon,
		}, model)
		local depBB = billboard(dep, "DEPOSIT HERE", GOLD, Vector3.new(0, 9, 0), UDim2.fromOffset(220, 36), 90)
		depBB:SetAttribute("OwnerId", 0)
		CollectionService:AddTag(depBB, "DepositGui")
		plot.DepositGui = depBB

		for _, sz in ipairs({ -1, 1 }) do
			part({ Name = "GatePost", Size = Vector3.new(1.2, 10, 1.2), Position = Vector3.new(-14, 5, zc + sz * 8.6), Color = color:Lerp(WHITE, 0.3) }, model)
			-- a small potted plant at the base of each gate post - a little welcoming touch
			part({ Name = "GatePlanter", Size = Vector3.new(2.2, 1.6, 2.2), Position = Vector3.new(-11, 0.8, zc + sz * 8.6), Color = Color3.fromRGB(140, 96, 62) }, model)
			part({ Name = "GateBush", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), Position = Vector3.new(-11, 2.6, zc + sz * 8.6), Color = Color3.fromRGB(75, 185, 95), CanCollide = false }, model)
		end
		part({ Name = "GateBar", Size = Vector3.new(1.6, 1.6, 19), Position = Vector3.new(-14, 10.6, zc), Color = color, Material = Enum.Material.Neon }, model)

		local spawnPart = Instance.new("SpawnLocation")
		spawnPart.Name = "Spawn"
		spawnPart.Size = Vector3.new(6, 1, 6)
		spawnPart.CFrame = CFrame.new(-28, 1.5, zc) * CFrame.Angles(0, -math.pi / 2, 0) -- players spawn facing forward (+X)
		spawnPart.Anchored = true
		spawnPart.Neutral = true
		spawnPart.Duration = 0
		spawnPart.Transparency = 0.6
		spawnPart.Color = Color3.fromRGB(255, 255, 255)
		spawnPart.Parent = model
		plot.Spawn = spawnPart

		-- the name sign stands up on two posts (raised off the floor so it reads from across the plaza)
		local sign = part({
			Name = "Sign",
			Size = Vector3.new(1, 7, 34),
			Position = Vector3.new(-60.5, 14.5, zc),
			Color = Color3.fromRGB(30, 30, 45),
		}, model)
		for _, sz in ipairs({ -1, 1 }) do
			part({ Name = "SignPost", Size = Vector3.new(1, 11, 1), Position = Vector3.new(-60.5, 5.5, zc + sz * 15), Color = Color3.fromRGB(30, 30, 45) }, model)
		end
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Right
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 25
		sg.Parent = sign
		local signLabel = Instance.new("TextLabel")
		signLabel.Size = UDim2.fromScale(1, 1)
		signLabel.BackgroundTransparency = 1
		signLabel.TextScaled = true
		signLabel.Font = Enum.Font.FredokaOne
		signLabel.TextColor3 = color
		signLabel.Text = "Unclaimed"
		signLabel.Parent = sg
		local signStroke = Instance.new("UIStroke")
		signStroke.Thickness = 3
		signStroke.Color = Color3.new(0, 0, 0)
		signStroke.Parent = signLabel
		plot.SignLabel = signLabel
		do
			-- the owner's avatar face: on the left of the name sign, and floating above the entrance gate
			signLabel.Position = UDim2.fromScale(0.2, 0)
			signLabel.Size = UDim2.fromScale(0.78, 1)
			local signFace = Instance.new("ImageLabel")
			signFace.Name = "OwnerFace"
			signFace.SizeConstraint = Enum.SizeConstraint.RelativeYY
			signFace.Size = UDim2.fromScale(0.9, 0.9)
			signFace.Position = UDim2.fromScale(0.05, 0.05)
			signFace.BackgroundColor3 = color
			signFace.Visible = false
			signFace.Parent = sg
			Instance.new("UICorner", signFace).CornerRadius = UDim.new(0.5, 0)
			plot.SignFace = signFace

			local faceBB = Instance.new("BillboardGui")
			faceBB.Name = "OwnerFaceGui"
			faceBB.Size = UDim2.fromOffset(90, 90)
			faceBB.StudsOffset = Vector3.new(0, 5.5, 0)
			faceBB.MaxDistance = 220
			faceBB.Enabled = false
			faceBB.Parent = model:FindFirstChild("GateBar")
			local gateFace = Instance.new("ImageLabel")
			gateFace.Size = UDim2.fromScale(1, 1)
			gateFace.BackgroundColor3 = color
			gateFace.Parent = faceBB
			Instance.new("UICorner", gateFace).CornerRadius = UDim.new(0.5, 0)
			local ring = Instance.new("UIStroke")
			ring.Thickness = 4
			ring.Color = color
			ring.Parent = gateFace
			plot.FaceGui = faceBB
			plot.GateFace = gateFace
		end

		local function makePad(fm, pos, padColor, text, actionText, callback)
			local pad = part({
				Name = "ElevatorPad",
				Size = Vector3.new(5, 0.6, 5),
				Position = pos,
				Color = padColor,
				Material = Enum.Material.Neon,
			}, fm)
			billboard(pad, text, WHITE, Vector3.new(0, 4, 0), UDim2.fromOffset(110, 30), 40)
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = actionText
			pp.ObjectText = "Elevator"
			pp.HoldDuration = 0.3
			pp.MaxActivationDistance = 8
			pp.RequiresLineOfSight = false
			pp.Enabled = false
			pp.Parent = pad
			pp.Triggered:Connect(callback)
			return pp
		end

		for k = 1, Config.MaxFloors do
			local y0 = (k - 1) * FLOOR_H
			local fm = Instance.new("Model")
			fm.Name = "Floor" .. k

			part({ Name = "Slab", Size = Vector3.new(40, 1, 40), Position = Vector3.new(-40, y0 + 0.5, zc), Color = color }, fm)
			part({ Name = "Inlay", Size = Vector3.new(36, 0.2, 36), Position = Vector3.new(-40, y0 + 1.1, zc), Color = color:Lerp(WHITE, 0.6) }, fm)
			-- glowing neon trim around the edge
			part({ Name = "Trim", Size = Vector3.new(40, 0.3, 0.7), Position = Vector3.new(-40, y0 + 1.1, zc - 19.65), Color = color, Material = Enum.Material.Neon }, fm)
			part({ Name = "Trim", Size = Vector3.new(40, 0.3, 0.7), Position = Vector3.new(-40, y0 + 1.1, zc + 19.65), Color = color, Material = Enum.Material.Neon }, fm)
			part({ Name = "Trim", Size = Vector3.new(0.7, 0.3, 38.6), Position = Vector3.new(-59.65, y0 + 1.1, zc), Color = color, Material = Enum.Material.Neon }, fm)
			part({ Name = "Trim", Size = Vector3.new(0.7, 0.3, 38.6), Position = Vector3.new(-20.35, y0 + 1.1, zc), Color = color, Material = Enum.Material.Neon }, fm)

			for s = 1, SPF do
				local idx = (k - 1) * SPF + s
				local row = math.floor((s - 1) / 5)
				local col = (s - 1) % 5
				local px, pz = -54 + row * 14, zc - 16 + col * 8
				plot.Pedestals[idx] = part({
					Name = "Pedestal" .. idx,
					Size = Vector3.new(6, 2, 6),
					Position = Vector3.new(px, y0 + 2, pz),
					Color = Color3.fromRGB(50, 50, 50),
					Transparency = 0.6,
				}, fm)
				plot.Rings[idx] = part({
					Name = "Ring" .. idx,
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.25, 8, 8),
					CFrame = CFrame.new(px, y0 + 1.3, pz) * CFrame.Angles(0, 0, math.rad(90)),
					Color = WHITE,
					Material = Enum.Material.Neon,
					Transparency = 1,
					CanCollide = false,
				}, fm)

				-- COLLECT PAD in front of the pedestal: walk on it to pick up the money this Goober earned
				local pad = part({
					Name = "CollectPad" .. idx,
					Size = Vector3.new(4, 0.3, 5),
					Position = Vector3.new(px + 6.4, y0 + 1.32, pz),
					Color = Color3.fromRGB(80, 86, 110),
					Material = Enum.Material.Neon,
					Transparency = 1,
					CanCollide = false,
					CanTouch = false,
				}, fm)
				local pgui, plabel = billboard(pad, "$0", Color3.fromRGB(170, 175, 200), Vector3.new(0, 2.4, 0), UDim2.fromOffset(120, 32), 38)
				pgui.Enabled = false
				local em = Instance.new("ParticleEmitter")
				em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				em.Rate = 0
				em.Lifetime = NumberRange.new(0.8, 1.3)
				em.Speed = NumberRange.new(8, 16)
				em.SpreadAngle = Vector2.new(60, 60)
				em.EmissionDirection = Enum.NormalId.Top
				em.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
				em.Size = NumberSequence.new(0.9)
				em.LightEmission = 1
				em.Parent = pad
				pad.Touched:Connect(function(hit)
					local plr = Players:GetPlayerFromCharacter(hit.Parent)
					if plr and plot.Owner == plr then
						collectSlot(plr, idx)
					end
				end)
				plot.Pads[idx], plot.PadGuis[idx], plot.PadLabels[idx], plot.PadEmitters[idx] = pad, pgui, plabel, em

				-- UPGRADE BUTTON on the front of the pedestal (hold E / tap): this Goober earns more per second
				local btn = part({
					Name = "UpgradeButton" .. idx,
					Size = Vector3.new(0.4, 1.2, 3.6),
					Position = Vector3.new(px + 3.2, y0 + 2, pz),
					Color = Color3.fromRGB(70, 230, 120),
					Material = Enum.Material.Neon,
					Transparency = 1,
					CanCollide = false,
				}, fm)
				local bgui, blabel = billboard(btn, "", WHITE, Vector3.new(0, 1.9, 0), UDim2.fromOffset(100, 46), 30)
				bgui.Enabled = false
				local bp = Instance.new("ProximityPrompt")
				bp.Name = "UpgradePrompt"
				bp.ActionText = "Upgrade"
				bp.ObjectText = "Goober"
				bp.HoldDuration = 0.2
				bp.MaxActivationDistance = 7
				bp.RequiresLineOfSight = false
				bp.Enabled = false
				bp:SetAttribute("OwnerId", 0)
				bp.Parent = btn
				CollectionService:AddTag(bp, "UpgradePrompt")
				bp.Triggered:Connect(function(who)
					if plot.Owner == who then
						upgradeGoober(who, idx)
					end
				end)
				plot.Buttons[idx], plot.ButtonGuis[idx], plot.ButtonLabels[idx], plot.ButtonPrompts[idx] = btn, bgui, blabel, bp
			end

			if k == 1 then -- lamp posts + planters on the ground floor
				for _, lz in ipairs({ -17, 17 }) do
					part({ Name = "LampPole", Size = Vector3.new(0.7, 9, 0.7), Position = Vector3.new(-22, 5.5, zc + lz), Color = Color3.fromRGB(50, 50, 70) }, fm)
					local bulb = part({
						Name = "LampBulb",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(2.6, 2.6, 2.6),
						Position = Vector3.new(-22, 10.4, zc + lz),
						Color = Color3.fromRGB(255, 240, 170),
						Material = Enum.Material.Neon,
					}, fm)
					local l = Instance.new("PointLight")
					l.Range = 26
					l.Brightness = 1.4
					l.Color = Color3.fromRGB(255, 235, 180)
					l.Parent = bulb
					part({ Name = "Planter", Size = Vector3.new(3.4, 1.6, 3.4), Position = Vector3.new(-58, 1.8, zc + lz), Color = Color3.fromRGB(140, 96, 62) }, fm)
					part({ Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.new(3.6, 3.6, 3.6), Position = Vector3.new(-58, 3.9, zc + lz), Color = Color3.fromRGB(70, 180, 90), CanCollide = false }, fm)
				end
			end

			if k > 1 then
				for _, px in ipairs({ -59, -21 }) do
					for _, pz in ipairs({ -19, 19 }) do
						part({
							Name = "Pillar",
							Size = Vector3.new(2, FLOOR_H, 2),
							Position = Vector3.new(px, y0 - FLOOR_H / 2 + 0.5, zc + pz),
							Color = color:Lerp(WHITE, 0.3),
						}, fm)
					end
				end
				local function rail(size, pos)
					part({
						Name = "Rail",
						Size = size,
						Position = pos,
						Color = Color3.fromRGB(170, 225, 255),
						Material = Enum.Material.Glass,
						Transparency = 0.6,
					}, fm)
				end
				rail(Vector3.new(40, 6, 1), Vector3.new(-40, y0 + 4, zc - 19.5))
				rail(Vector3.new(40, 6, 1), Vector3.new(-40, y0 + 4, zc + 19.5))
				rail(Vector3.new(1, 6, 40), Vector3.new(-59.5, y0 + 4, zc))
				rail(Vector3.new(1, 6, 40), Vector3.new(-20.5, y0 + 4, zc))
			end

			if k < Config.MaxFloors then
				plot.UpPrompts[k] = makePad(fm, Vector3.new(-24, y0 + 1.3, zc - 12), Color3.fromRGB(80, 255, 130), "UP", "Go Up", function(player)
					useElevator(player, plot, k + 1)
				end)
			end
			if k > 1 then
				plot.DownPrompts[k] = makePad(fm, Vector3.new(-24, y0 + 1.3, zc + 12), Color3.fromRGB(255, 170, 60), "DOWN", "Go Down", function(player)
					useElevator(player, plot, k - 1)
				end)
			end

			plot.FloorModels[k] = fm
			fm.Parent = (k == 1) and model or nil
		end

		-- a tree in the gap between this base and the next one
		if i < Config.PlotCount then
			realTree(-40, zc + S / 2, 1.05)
		end

		dep.Touched:Connect(function(hit)
			local plr = Players:GetPlayerFromCharacter(hit.Parent)
			if plr and plot.Owner == plr then
				deposit(plr)
			end
		end)

		table.insert(Plots, plot)
	end
end

local LB, LB_INFO, renderBoard, buildShop
do
	----------------------------------------------------------------
	-- NPCs + STANDS: Gus (gadget shop), Speed stand, Capacity stand, Pet egg stand
	----------------------------------------------------------------
	-- A classic blocky Roblox character (Torso/Head/Arms/Legs + face), built from parts so it always works. Every NPC gets its own look
	-- and personality. look = { Persona, Skin, Shirt, Sleeve, Pants, Hat, HatColor, Hair, HairColor, Glasses, Brows, Mustache,
	--   Freckles, Apron, Emblem, Scarf, Backpack }
	local function makeNPC(displayName, pos, yaw, look)
		local model = Instance.new("Model")
		model.Name = displayName
		local base = CFrame.new(pos.X, pos.Y + 3, pos.Z) * CFrame.Angles(0, math.rad(yaw), 0)
		local V, CF = Vector3.new, CFrame.new
		local NEON = Enum.Material.Neon
		local UP = CFrame.Angles(0, 0, math.rad(90))
		local function rz(deg)
			return CFrame.Angles(0, 0, math.rad(deg))
		end
		local function bp(name, size, off, color, material)
			return part({
				Name = name,
				Size = size,
				CFrame = base * off,
				Color = color,
				Material = material or Enum.Material.SmoothPlastic,
				CanCollide = false,
			}, model)
		end
		local function ball(name, d, off, color, material)
			local p = bp(name, V(d, d, d), off, color, material)
			p.Shape = Enum.PartType.Ball
			return p
		end
		local function cyl(name, len, d, off, color, material) -- stands upright when off has UP
			local p = bp(name, V(len, d, d), off, color, material)
			p.Shape = Enum.PartType.Cylinder
			return p
		end
		local dark = Color3.fromRGB(35, 30, 45)
		local hair = look.HairColor or Color3.fromRGB(70, 45, 30)

		local torso = bp("Torso", V(2, 2, 1), CF(0, 0, 0), look.Shirt)
		local head = bp("Head", V(2, 1, 1), CF(0, 1.5, 0), look.Skin)
		local hm = Instance.new("SpecialMesh")
		hm.MeshType = Enum.MeshType.Head
		hm.Scale = V(1.25, 1.25, 1.25)
		hm.Parent = head
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = Enum.NormalId.Front
		face.Parent = head
		bp("Left Arm", V(1, 2, 1), CF(-1.5, 0, 0), look.Sleeve or look.Skin)
		bp("Right Arm", V(1, 2, 1), CF(1.5, 0, 0), look.Sleeve or look.Skin)
		bp("Left Leg", V(1, 2, 1), CF(-0.5, -2, 0), look.Pants)
		bp("Right Leg", V(1, 2, 1), CF(0.5, -2, 0), look.Pants)

		-- ===== hair =====
		if look.Hair == "wild" then -- big untidy puffs at the sides and back (mad inventor)
			ball("Hair", 0.95, CF(-1.0, 1.75, 0.05), hair)
			ball("Hair", 0.95, CF(1.0, 1.75, 0.05), hair)
			ball("Hair", 0.85, CF(-0.85, 1.25, 0.25), hair)
			ball("Hair", 0.85, CF(0.85, 1.25, 0.25), hair)
			ball("Hair", 1.0, CF(0, 1.9, 0.55), hair)
		elseif look.Hair == "pigtails" then
			for _, s in ipairs({ -1, 1 }) do
				ball("Hairband", 0.42, CF(s * 0.95, 1.85, 0.15), look.HatColor or hair)
				bp("Pigtail", V(0.45, 1.3, 0.45), CF(s * 1.02, 1.15, 0.2), hair)
				ball("PigtailTip", 0.62, CF(s * 1.02, 0.45, 0.2), hair)
			end
		end

		-- ===== hats =====
		local hc = look.HatColor or Color3.fromRGB(150, 70, 255)
		if look.Hat == "top" then
			cyl("HatBrim", 0.2, 2.8, CF(0, 2.05, 0) * UP, hc)
			cyl("HatCrown", 1.6, 1.9, CF(0, 2.85, 0) * UP, hc)
			cyl("HatBand", 0.35, 1.95, CF(0, 2.35, 0) * UP, Color3.fromRGB(255, 215, 60), NEON)
		elseif look.Hat == "cap" then
			local dome = bp("Cap", V(2.2, 1.1, 2.2), CF(0, 2.15, 0), hc)
			dome.Shape = Enum.PartType.Ball
			bp("CapBill", V(1.6, 0.2, 1.2), CF(0, 2.0, -1.2), hc)
		elseif look.Hat == "backcap" then -- sporty: cap on backwards
			local dome = bp("Cap", V(2.2, 1.1, 2.2), CF(0, 2.15, 0), hc)
			dome.Shape = Enum.PartType.Ball
			bp("CapBill", V(1.6, 0.2, 1.2), CF(0, 2.0, 1.2), hc)
			bp("CapStripe", V(0.3, 0.12, 2.2), CF(0, 2.6, 0), Color3.fromRGB(255, 255, 255))
		elseif look.Hat == "safari" then -- explorer hat with a feather
			cyl("HatBrim", 0.15, 3.4, CF(0, 2.05, 0) * UP, hc)
			cyl("HatCrown", 1.2, 2.2, CF(0, 2.6, 0) * UP, hc)
			cyl("HatBand", 0.3, 2.25, CF(0, 2.28, 0) * UP, Color3.fromRGB(120, 70, 40))
			bp("Feather", V(0.14, 1.0, 0.34), CF(1.0, 2.75, -0.2) * rz(-18), Color3.fromRGB(230, 70, 80))
		elseif look.Hat == "bunny" then -- soft headband with bunny ears
			bp("Headband", V(2.0, 0.22, 1.25), CF(0, 1.95, 0), hc)
			for _, s in ipairs({ -1, 1 }) do
				bp("BunnyEar", V(0.5, 1.7, 0.25), CF(s * 0.5, 2.95, 0) * rz(-s * 9), Color3.fromRGB(255, 245, 250))
				bp("BunnyEarInner", V(0.26, 1.3, 0.06), CF(s * 0.5, 2.95, -0.12) * rz(-s * 9), Color3.fromRGB(255, 160, 195))
			end
		elseif look.Hat == "crown" then
			for i = -1, 1 do
				bp("CrownSpike", V(0.4, 0.9, 0.4), CF(i * 0.6, 2.4, 0), Color3.fromRGB(255, 215, 60), NEON)
			end
			bp("CrownBand", V(2.0, 0.4, 1.2), CF(0, 2.05, 0), Color3.fromRGB(255, 215, 60), NEON)
		end

		-- ===== face =====
		if look.Glasses == "goggles" then -- big round lenses over the eyes (inventor)
			bp("GoggleStrap", V(1.7, 0.2, 1.3), CF(0, 1.56, 0.02), Color3.fromRGB(90, 60, 40))
			for _, s in ipairs({ -1, 1 }) do
				ball("GoggleRim", 0.78, CF(s * 0.4, 1.56, -0.62), Color3.fromRGB(200, 150, 60), Enum.Material.Metal)
				local lens = ball("GoggleLens", 0.6, CF(s * 0.4, 1.56, -0.7), Color3.fromRGB(130, 245, 255), NEON)
				lens.Transparency = 0.3
			end
		elseif look.Glasses == "shades" then -- cool racing shades
			bp("ShadeBar", V(1.5, 0.12, 0.14), CF(0, 1.66, -0.66), dark)
			for _, s in ipairs({ -1, 1 }) do
				bp("ShadeLens", V(0.62, 0.36, 0.16), CF(s * 0.4, 1.58, -0.67), Color3.fromRGB(20, 25, 45), Enum.Material.Glass)
				bp("ShadeGlint", V(0.16, 0.05, 0.18), CF(s * 0.3, 1.66, -0.68), Color3.fromRGB(120, 200, 255), NEON)
			end
		end
		if look.Brows then
			for _, s in ipairs({ -1, 1 }) do
				bp("Brow", V(0.45, 0.1, 0.1), CF(s * 0.34, 1.9, -0.64) * rz(s * (look.BrowTilt or 12)), hair)
			end
		end
		if look.Mustache then
			bp("Mustache", V(0.8, 0.16, 0.12), CF(0, 1.26, -0.64), hair)
			for _, s in ipairs({ -1, 1 }) do
				ball("MustacheCurl", 0.24, CF(s * 0.46, 1.2, -0.62), hair)
			end
		end
		if look.Freckles then
			for k = 1, 7 do
				local s = (k % 2 == 0) and 1 or -1
				ball("Freckle", 0.08, CF(s * (0.3 + (k % 3) * 0.1), 1.4 + (k % 2) * 0.08, -0.63), Color3.fromRGB(190, 110, 80))
			end
		end

		-- ===== clothes and gear =====
		if look.Apron then -- (a lab coat or an apron)
			bp("Apron", V(1.6, 1.7, 0.12), CF(0, -0.15, -0.56), look.Apron)
			bp("ApronPocket", V(0.7, 0.5, 0.14), CF(0.35, -0.5, -0.6), look.Apron:Lerp(dark, 0.12))
			if look.Gadgets then -- tools sticking out of the pocket
				for k, col in ipairs({ Color3.fromRGB(255, 110, 190), Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 220, 70) }) do
					bp("Gadget", V(0.12, 0.55 + k * 0.08, 0.1), CF(0.12 + k * 0.2, -0.12, -0.62) * rz(-8 + k * 8), col, NEON)
				end
			end
		end
		if look.Emblem == "bolt" then
			local y = Color3.fromRGB(255, 235, 60)
			bp("Bolt", V(0.32, 0.75, 0.1), CF(0.15, 0.45, -0.55) * rz(20), y, NEON)
			bp("Bolt", V(0.6, 0.22, 0.1), CF(0, 0.1, -0.55), y, NEON)
			bp("Bolt", V(0.32, 0.75, 0.1), CF(-0.15, -0.28, -0.55) * rz(20), y, NEON)
		elseif look.Emblem == "heart" then
			local p = Color3.fromRGB(255, 120, 170)
			ball("Heart", 0.36, CF(-0.16, 0.45, -0.55), p, NEON)
			ball("Heart", 0.36, CF(0.16, 0.45, -0.55), p, NEON)
			bp("Heart", V(0.36, 0.36, 0.1), CF(0, 0.3, -0.55) * rz(45), p, NEON)
		end
		if look.Scarf then
			bp("Scarf", V(2.15, 0.4, 1.25), CF(0, 0.98, 0), look.Scarf)
			bp("ScarfTail", V(0.45, 1.3, 0.16), CF(0.7, 0.3, -0.6) * rz(-6), look.Scarf)
		end
		if look.Backpack then
			bp("Backpack", V(1.6, 2.2, 0.9), CF(0, 0.1, 0.95), look.Backpack)
			bp("BackpackPocket", V(1.2, 0.9, 0.3), CF(0, -0.5, 1.5), look.Backpack:Lerp(WHITE, 0.25))
			if look.Bedroll then -- a rolled-up sleeping bag on top, with patches on the back
				cyl("Bedroll", 1.9, 0.85, CF(0, 1.4, 0.95), look.Bedroll)
				cyl("BedrollStrap", 0.2, 0.9, CF(-0.5, 1.4, 0.95) * CFrame.Angles(0, 0, 0), dark)
				cyl("BedrollStrap", 0.2, 0.9, CF(0.5, 1.4, 0.95), dark)
				bp("Patch", V(0.4, 0.4, 0.06), CF(-0.4, 0.5, 1.42), Color3.fromRGB(255, 110, 130))
				bp("Patch", V(0.36, 0.36, 0.06), CF(0.35, 0.05, 1.42) * rz(15), Color3.fromRGB(110, 200, 255))
			end
		end

		model.PrimaryPart = torso
		model:SetAttribute("Persona", look.Persona or "")
		CollectionService:AddTag(model, "NPC")
		model.Parent = World
		return model, torso, head
	end

	-- every stall stands with its back against the east wall and faces WEST (-X), towards the players.
	local function makeCounter(sx, zc, width, accent)
		part({ Name = "Counter", Size = Vector3.new(3, 3.5, width), Position = Vector3.new(sx, 2.75, zc), Color = Color3.fromRGB(190, 130, 80) }, World)
		part({ Name = "CounterFront", Size = Vector3.new(0.3, 2.4, width - 1.2), Position = Vector3.new(sx - 1.6, 2.6, zc), Color = Color3.fromRGB(150, 100, 60) }, World)
		return part({
			Name = "CounterTop",
			Size = Vector3.new(4, 0.5, width + 1),
			Position = Vector3.new(sx, 4.7, zc),
			Color = accent,
			Material = Enum.Material.Neon,
		}, World)
	end

	-- a row of little glowing bulbs along the front edge of a roof
	local function stringLights(x, y, z0, z1, accent)
		local n = math.floor((z1 - z0) / 3)
		for i = 0, n do
			local z = z0 + (z1 - z0) * i / math.max(n, 1)
			part({
				Name = "Bulb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.9, 0.9, 0.9),
				Position = Vector3.new(x, y - math.abs(math.sin(i * 1.3)) * 0.8, z),
				Color = (i % 2 == 0) and accent:Lerp(WHITE, 0.4) or Color3.fromRGB(255, 240, 170),
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, World)
		end
	end

	-- Gus: off to the side of the plaza, front facing east. Sells the Wacker, traps and potions.
	local function buildGus()
		local sx, zc = Config.Market.GusX, Config.Market.GusZ
		local accent = Color3.fromRGB(255, 110, 190)
		part({ Name = "ShopFloor", Size = Vector3.new(26, 1, 34), Position = Vector3.new(sx, 0.5, zc), Color = Color3.fromRGB(255, 235, 250) }, World)
		part({ Name = "ShopTrim", Size = Vector3.new(26.6, 0.3, 34.6), Position = Vector3.new(sx, 0.9, zc), Color = accent, Material = Enum.Material.Neon }, World)
		for _, cx in ipairs({ -11.5, 11.5 }) do
			for _, cz in ipairs({ -15.5, 15.5 }) do
				part({ Name = "ShopPillar", Size = Vector3.new(2, 17, 2), Position = Vector3.new(sx + cx, 9.5, zc + cz), Color = WHITE }, World)
			end
		end
		part({ Name = "ShopRoof", Size = Vector3.new(30, 2, 38), Position = Vector3.new(sx, 18.5, zc), Color = accent }, World)
		-- striped awning over the front
		for i = 0, 8 do
			part({
				Name = "Awning",
				Size = Vector3.new(4, 0.6, 3.8),
				CFrame = CFrame.new(sx - 14, 16.6, zc - 15.2 + i * 3.8) * CFrame.Angles(0, 0, math.rad(12)),
				Color = (i % 2 == 0) and WHITE or Color3.fromRGB(255, 90, 150),
				CanCollide = false,
			}, World)
		end
		stringLights(sx - 15.4, 15.6, zc - 16, zc + 16, accent)
		-- back wall with shelves full of potion bottles
		part({ Name = "ShopBackWall", Size = Vector3.new(1, 15, 34), Position = Vector3.new(sx + 12.5, 8.5, zc), Color = Color3.fromRGB(255, 220, 245) }, World)
		for row = 1, 3 do
			part({ Name = "Shelf", Size = Vector3.new(2.4, 0.5, 30), Position = Vector3.new(sx + 11.2, 3 + row * 3.4, zc), Color = Color3.fromRGB(190, 130, 80), CanCollide = false }, World)
			for k = 1, 9 do
				local item = Config.ShopItems[((row * 3 + k) % #Config.ShopItems) + 1]
				part({
					Name = "Bottle",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.5, 1.5, 1.5),
					Position = Vector3.new(sx + 11.2, 4.4 + row * 3.4, zc - 14 + k * 3.1),
					Color = item.Color,
					Material = Enum.Material.Neon,
					Transparency = 0.15,
					CanCollide = false,
				}, World)
			end
		end
		local signPart = part({ Name = "ShopSign", Size = Vector3.new(1, 6, 26), Position = Vector3.new(sx - 14.6, 22.5, zc), Color = Color3.fromRGB(35, 30, 60) }, World)
		billboard(signPart, "GUS'S GADGETS", Color3.fromRGB(255, 220, 90), Vector3.new(0, 0, 0), UDim2.fromOffset(400, 80), 220)
		local top = makeCounter(sx - 9, zc, 20, accent)

		local model, torso = makeNPC("Gus", Vector3.new(sx - 3.5, 1, zc), 90, { -- yaw 90 = looking west, at his customers
			Persona = "gus",
			Skin = Color3.fromRGB(255, 204, 153),
			Shirt = Color3.fromRGB(255, 110, 190),
			Pants = Color3.fromRGB(70, 90, 210),
			Hat = "top",
			HatColor = Color3.fromRGB(150, 70, 255),
			Hair = "wild",
			HairColor = Color3.fromRGB(235, 235, 245),
			Glasses = "goggles",
			Mustache = true,
			Brows = true,
			BrowTilt = 16,
			Apron = Color3.fromRGB(246, 246, 255),
			Gadgets = true,
		})
		billboard(torso, "Gus", Color3.fromRGB(255, 230, 120), Vector3.new(0, 4.5, 0), UDim2.fromOffset(120, 34), 26)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Shop"
		pp.ObjectText = "Gus"
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 16
		pp.RequiresLineOfSight = false
		pp.Parent = top
		pp.Triggered:Connect(function(player)
			UIRemote:FireClient(player, "OpenShop")
		end)
	end

	-- a kiosk on either side of the runway entrance, front facing east. Step on the glowing pad in front (or press the prompt).
	local function buildStand(zc, title, tagline, accent, upgradeName, look)
		local sx = Config.Market.StandX
		part({ Name = title .. "Floor", Size = Vector3.new(20, 1, 24), Position = Vector3.new(sx, 0.5, zc), Color = Color3.fromRGB(240, 240, 250) }, World)
		part({ Name = title .. "Trim", Size = Vector3.new(20.6, 0.3, 24.6), Position = Vector3.new(sx, 0.9, zc), Color = accent, Material = Enum.Material.Neon }, World)
		for _, cx in ipairs({ -9, 9 }) do
			for _, cz in ipairs({ -11, 11 }) do
				part({ Name = "StandPillar", Size = Vector3.new(1.6, 13, 1.6), Position = Vector3.new(sx + cx, 7.5, zc + cz), Color = WHITE }, World)
			end
		end
		part({ Name = "StandRoof", Size = Vector3.new(22, 1.6, 26), Position = Vector3.new(sx, 14.3, zc), Color = accent }, World)
		part({ Name = "StandBackWall", Size = Vector3.new(1, 12, 24), Position = Vector3.new(sx + 9.5, 7, zc), Color = accent:Lerp(WHITE, 0.7) }, World)
		stringLights(sx - 11.2, 13.3, zc - 12, zc + 12, accent)
		local sign = part({ Name = title .. "Sign", Size = Vector3.new(1, 5, 14), Position = Vector3.new(sx - 11.6, 18.6, zc), Color = Color3.fromRGB(35, 30, 60) }, World)
		billboard(sign, title, accent:Lerp(WHITE, 0.45), Vector3.new(0, 0, 0), UDim2.fromOffset(380, 84), 220)
		local top = makeCounter(sx - 6, zc, 16, accent)

		local model, torso = makeNPC(title .. " NPC", Vector3.new(sx - 1.5, 1, zc), 90, look)
		billboard(torso, tagline, WHITE, Vector3.new(0, 4.5, 0), UDim2.fromOffset(200, 32), 26)

		-- the entry pad in front of the stall: walking onto it opens the upgrade window
		local entry = part({
			Name = "StandPad",
			Size = Vector3.new(5, 0.4, 12),
			Position = Vector3.new(sx - 14, 0.25, zc),
			Color = accent,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, World)
		entry:SetAttribute("Upgrade", upgradeName)
		CollectionService:AddTag(entry, "StandPad")
		for i = -1, 1 do -- little arrows pointing at the stall
			part({ Name = "PadArrow", Size = Vector3.new(0.8, 0.45, 2.4), CFrame = CFrame.new(sx - 14, 0.28, zc + i * 3.6) * CFrame.Angles(0, math.rad(90), 0), Color = WHITE, Material = Enum.Material.Neon, CanCollide = false }, World)
		end

		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Upgrade"
		pp.ObjectText = title
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 14
		pp.RequiresLineOfSight = false
		pp.Parent = top
		pp.Triggered:Connect(function(player)
			UIRemote:FireClient(player, "OpenStand", upgradeName)
		end)
	end

	-- Pet stage: ALL the eggs in ONE row against the east wall, from the Common Egg (nearest the entrance) to the best egg at the far end.
	-- The stage rises a little with every egg, so it is obvious which way is "better". Interact = open the egg window.
	-- every egg has its own look (Config.Eggs[..].Pattern): spots, stripes, stars, hearts, zigzag, rings, gems, flames, swirl, crown, wings, halo
	local function decorateEgg(model, body, egg, grow)
		local p0 = body.Position
		local light = egg.Color:Lerp(WHITE, 0.7)
		local gold = Color3.fromRGB(255, 215, 70)
		local hh = 3.3 * grow -- half the egg's height
		local function radiusAt(y) -- the egg is an ellipsoid: how wide is it at height y?
			return 2.5 * grow * math.sqrt(math.max(0.05, 1 - (y / hh) ^ 2)) + 0.1
		end
		local function bit(name, d, off, color, material)
			local p = part({ Name = name, Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), Position = p0 + off, Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false }, model)
			return p
		end
		local function block(name, size, off, rot, color, material)
			return part({ Name = name, Size = size, CFrame = CFrame.new(p0 + off) * rot, Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false }, model)
		end
		local function around(count, y, fn)
			local r = radiusAt(y)
			for k = 1, count do
				local a = (k / count) * math.pi * 2
				fn(k, Vector3.new(math.cos(a) * r, y, math.sin(a) * r), a)
			end
		end
		local pat = egg.Pattern
		if pat == "stripes" then
			for _, y in ipairs({ -1.7 * grow, 0, 1.7 * grow }) do
				around(10, y, function(_, off) bit("Stripe", 0.85 * grow, off, light) end)
			end
		elseif pat == "stars" then
			for k = 1, 8 do
				local y = math.sin(k * 2.3) * 2.2 * grow
				local a = k * 2.4
				local r = radiusAt(y)
				bit("Star", 0.7 * grow, Vector3.new(math.cos(a) * r, y, math.sin(a) * r), gold, Enum.Material.Neon)
			end
		elseif pat == "hearts" then
			for k = 1, 4 do
				local a, y = k * 1.6, (k - 2.5) * 1.3 * grow
				local r = radiusAt(y)
				local c = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
				local side = Vector3.new(-math.sin(a), 0, math.cos(a)) * 0.28 * grow
				bit("Heart", 0.55 * grow, c + side, Color3.fromRGB(255, 120, 170), Enum.Material.Neon)
				bit("Heart", 0.55 * grow, c - side, Color3.fromRGB(255, 120, 170), Enum.Material.Neon)
			end
		elseif pat == "zigzag" then
			around(12, 0, function(k, off) bit("Zig", 0.8 * grow, off + Vector3.new(0, (k % 2 == 0) and 0.9 * grow or -0.9 * grow, 0), light) end)
		elseif pat == "rings" then
			for _, y in ipairs({ -1.2 * grow, 1.2 * grow }) do
				local r = radiusAt(y)
				part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, r * 2 + 0.4, r * 2 + 0.4), CFrame = CFrame.new(p0 + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = gold, Material = Enum.Material.Neon, CanCollide = false }, model)
			end
		elseif pat == "gems" then
			around(6, 0.6 * grow, function(_, off, a) block("Gem", Vector3.new(0.9, 0.9, 0.4) * grow, off, CFrame.Angles(0, -a + math.pi / 2, math.rad(45)), light, Enum.Material.Neon) end)
		elseif pat == "flames" then
			around(8, -1.9 * grow, function(k, off, a)
				block("Flame", Vector3.new(0.6, 2.2, 0.5) * grow, off + Vector3.new(0, 0.6 * grow, 0), CFrame.Angles(0, -a + math.pi / 2, math.rad(k % 2 == 0 and 8 or -8)), (k % 2 == 0) and Color3.fromRGB(255, 130, 30) or Color3.fromRGB(255, 220, 70), Enum.Material.Neon)
			end)
		elseif pat == "swirl" then
			for k = 1, 14 do
				local y = -2.6 * grow + k * 0.38 * grow
				local r = radiusAt(y)
				bit("Swirl", 0.7 * grow, Vector3.new(math.cos(k * 0.95) * r, y, math.sin(k * 0.95) * r), light, Enum.Material.Neon)
			end
		elseif pat == "crown" then
			for k = 1, 5 do
				local a = (k / 5) * math.pi * 2
				block("CrownSpike", Vector3.new(0.5, 1.4, 0.5) * grow, Vector3.new(math.cos(a) * 0.9 * grow, hh + 0.3 * grow, math.sin(a) * 0.9 * grow), CFrame.Angles(0, 0, 0), gold, Enum.Material.Neon)
			end
			bit("CrownGem", 0.9 * grow, Vector3.new(0, hh + 0.2 * grow, 0), light, Enum.Material.Neon)
		elseif pat == "wings" then
			for _, s in ipairs({ -1, 1 }) do
				block("Wing", Vector3.new(0.35, 2.8 * grow, 1.7 * grow), Vector3.new(0, 0.4 * grow, s * (2.6 * grow)), CFrame.Angles(math.rad(s * 22), 0, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
			end
		elseif pat == "halo" then
			part({ Name = "Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.4 * grow, 3.4 * grow), CFrame = CFrame.new(p0 + Vector3.new(0, hh + 1.2 * grow, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = gold, Material = Enum.Material.Neon, CanCollide = false }, model)
		else -- "spots"
			for k = 1, 5 do
				local a = (k / 5) * math.pi * 2
				bit("EggSpot", 1 * grow, Vector3.new(math.cos(a) * 2.3 * grow, math.sin(k * 2) * 1.6, math.sin(a) * 2.3 * grow), light)
			end
		end
	end

	local function buildEggStand(zc)
		local sx = Config.Market.PetX
		local UP = CFrame.Angles(0, 0, math.rad(90))
		local n = #Config.Eggs
		local step = 13
		local span = (n - 1) * step
		part({ Name = "PetStage", Size = Vector3.new(34, 1, span + 18), Position = Vector3.new(sx, 0.5, zc), Color = Color3.fromRGB(245, 240, 250) }, World)
		part({ Name = "PetStageTrim", Size = Vector3.new(34.8, 0.3, span + 18.8), Position = Vector3.new(sx, 0.95, zc), Color = Color3.fromRGB(255, 150, 220), Material = Enum.Material.Neon }, World)
		-- a backdrop pushed against the wall, and a sign facing the players
		part({ Name = "PetBackWall", Size = Vector3.new(1, 22, span + 18), Position = Vector3.new(sx + 16.5, 11.5, zc), Color = Color3.fromRGB(70, 48, 110) }, World)
		local sign = part({ Name = "PetSign", Size = Vector3.new(1.5, 7, 54), Position = Vector3.new(sx + 15.6, 21, zc), Color = Color3.fromRGB(35, 30, 60) }, World)
		billboard(sign, "PET EGGS", Color3.fromRGB(255, 190, 235), Vector3.new(0, 0.6, 0), UDim2.fromOffset(520, 90), 220)
		billboard(sign, "COMMON  >>  BEST", Color3.fromRGB(215, 225, 255), Vector3.new(0, -2.4, 0), UDim2.fromOffset(420, 34), 220)

		for i, egg in ipairs(Config.Eggs) do
			local ez = zc - span / 2 + (i - 1) * step
			local ex = sx + 6
			local h = 3 + (i - 1) * 0.45 -- the pedestals climb, egg by egg
			local grow = 1 + (i - 1) * 0.12
			part({ Name = "EggPedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 8, 8), CFrame = CFrame.new(ex, 1 + h / 2, ez) * UP, Color = Color3.fromRGB(220, 220, 235) }, World)
			part({ Name = "EggRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 9.6, 9.6), CFrame = CFrame.new(ex, 1.15, ez) * UP, Color = egg.Color, Material = Enum.Material.Neon, CanCollide = false }, World)
			local model = Instance.new("Model")
			model.Name = egg.Id .. "Egg"
			local body = part({
				Name = "EggBody",
				Size = Vector3.new(5 * grow, 6.6 * grow, 5 * grow),
				Position = Vector3.new(ex, 1 + h + 3.3 * grow + 1, ez),
				Color = egg.Color,
				CanCollide = false,
			}, model)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = body
			decorateEgg(model, body, egg, grow)
			model.PrimaryPart = body
			model:SetAttribute("HX", body.Position.X)
			model:SetAttribute("HY", body.Position.Y)
			model:SetAttribute("HZ", body.Position.Z)
			model:SetAttribute("Yaw", 0)
			CollectionService:AddTag(model, "BobModel")
			model.Parent = World
			billboard(body, egg.Label .. "\n$" .. Config.Format(egg.Price), egg.Color:Lerp(WHITE, 0.4), Vector3.new(0, 5.2 * grow, 0), UDim2.fromOffset(200, 60), 28)
			local light = Instance.new("PointLight")
			light.Color = egg.Color
			light.Range = 12 + i
			light.Brightness = 1.1
			light.Parent = body
			if i >= 4 then -- the best eggs sparkle
				local pe = Instance.new("ParticleEmitter")
				pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				pe.Rate = 6 + i
				pe.Lifetime = NumberRange.new(1.5, 2.5)
				pe.Speed = NumberRange.new(1, 3)
				pe.SpreadAngle = Vector2.new(180, 180)
				pe.Color = ColorSequence.new(egg.Color)
				pe.Size = NumberSequence.new(0.8)
				pe.LightEmission = 0.8
				pe.Parent = body
			end
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Open"
			pp.ObjectText = egg.Label
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 11
			pp.RequiresLineOfSight = false
			pp.Parent = body
			pp.Triggered:Connect(function(player)
				UIRemote:FireClient(player, "OpenEgg", egg.Id)
			end)
		end

		-- Cuddles Cleo looks after the pets, at the start of the row
		local cleo, ctorso = makeNPC("Cuddles Cleo", Vector3.new(sx - 13, 1, zc - span / 2 - 4), 90, {
			Persona = "cleo",
			Skin = Color3.fromRGB(255, 214, 178),
			Shirt = Color3.fromRGB(255, 170, 215),
			Pants = Color3.fromRGB(150, 110, 220),
			Hat = "bunny",
			HatColor = Color3.fromRGB(255, 140, 190),
			Hair = "pigtails",
			HairColor = Color3.fromRGB(255, 190, 120),
			Apron = Color3.fromRGB(255, 246, 250),
			Emblem = "heart",
			Freckles = true,
			Brows = true,
			BrowTilt = -8,
		})
		billboard(ctorso, "Cuddles Cleo", Color3.fromRGB(255, 200, 235), Vector3.new(0, 4.5, 0), UDim2.fromOffset(200, 32), 26)
		local cp = Instance.new("ProximityPrompt")
		cp.ActionText = "My Pets"
		cp.ObjectText = "Cleo"
		cp.HoldDuration = 0
		cp.MaxActivationDistance = 12
		cp.RequiresLineOfSight = false
		cp.Parent = ctorso
		cp.Triggered:Connect(function(player)
			UIRemote:FireClient(player, "OpenPets")
		end)
	end

	----------------------------------------------------------------
	-- LEADERBOARDS: most money, biggest donator, most rebirths (saved across all servers)
	----------------------------------------------------------------
	LB = {}
	LB_INFO = {
		{ Key = "Cash", Title = "MOST MONEY", Color = Color3.fromRGB(255, 205, 60), Fmt = function(v) return "$" .. Config.Format(v) end },
		{ Key = "Donated", Title = "TOP DONATORS", Color = Color3.fromRGB(255, 110, 190), Fmt = function(v) return "R$ " .. Config.Format(v) end },
		{ Key = "Rebirths", Title = "MOST REBIRTHS", Color = Color3.fromRGB(150, 110, 255), Fmt = function(v) return tostring(math.floor(v)) end },
	}

	-- the boards hang against the east wall (north end), facing the plaza
	local function buildBoard(z, info)
		local bx = Config.Market.BoardX
		part({ Name = "BoardBack", Size = Vector3.new(0.6, 28, 26), Position = Vector3.new(bx + 0.6, 14.5, z), Color = info.Color, Material = Enum.Material.Neon }, World)
		local board = part({ Name = "Board_" .. info.Key, Size = Vector3.new(1, 26, 24), Position = Vector3.new(bx, 14.5, z), Color = Color3.fromRGB(22, 24, 46) }, World)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Left
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 20
		sg.Parent = board
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 78)
		title.BackgroundColor3 = info.Color
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = WHITE
		title.Text = info.Title
		title.Parent = sg
		local tstroke = Instance.new("UIStroke")
		tstroke.Thickness = 3
		tstroke.Parent = title
		local tpad = Instance.new("UIPadding")
		tpad.PaddingTop = UDim.new(0, 10)
		tpad.PaddingBottom = UDim.new(0, 10)
		tpad.Parent = title
		local rows = {}
		for r = 1, Config.Leaderboards.Size do
			local row = Instance.new("Frame")
			row.Position = UDim2.new(0, 8, 0, 84 + (r - 1) * 43)
			row.Size = UDim2.new(1, -16, 0, 39)
			row.BackgroundColor3 = (r % 2 == 0) and Color3.fromRGB(40, 44, 82) or Color3.fromRGB(32, 35, 68)
			row.Parent = sg
			local rc = Instance.new("UICorner")
			rc.CornerRadius = UDim.new(0, 8)
			rc.Parent = row
			local function cell(x, w, align, color)
				local t = Instance.new("TextLabel")
				t.Position = UDim2.new(0, x, 0, 0)
				t.Size = UDim2.new(0, w, 1, 0)
				t.BackgroundTransparency = 1
				t.Font = Enum.Font.FredokaOne
				t.TextSize = 24
				t.TextColor3 = color
				t.TextXAlignment = align
				t.Text = ""
				t.Parent = row
				return t
			end
			local rankColors = { Color3.fromRGB(255, 215, 60), Color3.fromRGB(215, 220, 235), Color3.fromRGB(230, 150, 90) }
			local rank = cell(4, 44, Enum.TextXAlignment.Center, rankColors[r] or Color3.fromRGB(170, 180, 230))
			rank.Text = tostring(r)
			local nameL = cell(52, 250, Enum.TextXAlignment.Left, WHITE)
			local valueL = cell(302, 150, Enum.TextXAlignment.Right, info.Color:Lerp(WHITE, 0.4))
			rows[r] = { Name = nameL, Value = valueL }
		end
		rows[1].Name.Text = "Loading..."
		LB[info.Key] = { Rows = rows, Fmt = info.Fmt }
	end

	function renderBoard(key, entries)
		local b = LB[key]
		for r, row in ipairs(b.Rows) do
			local e = entries[r]
			row.Name.Text = e and e.Name or ""
			row.Value.Text = e and b.Fmt(e.Value) or ""
		end
		if #entries == 0 then
			b.Rows[1].Name.Text = "No data yet"
		end
	end

	function buildShop()
		local m = Config.Market
		buildGus()
		buildStand(m.SpeedZ, "SPEED", "Speedy Pete", Color3.fromRGB(70, 210, 255), "Speed", {
			Persona = "pete",
			Skin = Color3.fromRGB(255, 204, 153),
			Shirt = Color3.fromRGB(70, 170, 255),
			Pants = Color3.fromRGB(40, 50, 120),
			Hat = "backcap",
			HatColor = Color3.fromRGB(230, 60, 70),
			Glasses = "shades",
			Emblem = "bolt",
			Brows = true,
			BrowTilt = -14,
			HairColor = Color3.fromRGB(60, 40, 30),
		})
		buildStand(m.CapacityZ, "CAPACITY", "Bagsy Bea", Color3.fromRGB(255, 170, 60), "Carry", {
			Persona = "bea",
			Skin = Color3.fromRGB(234, 184, 146),
			Shirt = Color3.fromRGB(255, 160, 50),
			Pants = Color3.fromRGB(90, 60, 40),
			Hat = "safari",
			HatColor = Color3.fromRGB(205, 170, 110),
			Hair = "pigtails",
			HairColor = Color3.fromRGB(120, 70, 40),
			Freckles = true,
			Brows = true,
			Scarf = Color3.fromRGB(230, 90, 90),
			Backpack = Color3.fromRGB(70, 150, 90),
			Bedroll = Color3.fromRGB(210, 180, 120),
		})
		buildEggStand(m.PetZ)
		for i, info in ipairs(LB_INFO) do
			buildBoard(m.BoardZ[i], info)
		end
	end

end

----------------------------------------------------------------
-- WORLD GENERATION (no manual building needed!)
----------------------------------------------------------------
-- Walls: a visible glass pane plus a very thick invisible blocker behind it. Nobody can jump over it,
-- and even a player running at 300 studs/second cannot tunnel through.
local function solidWall(name, size, pos, outward, color)
	wall(name, size, pos, color)
	local T = 16
	local bsize, center
	if outward.X ~= 0 then
		bsize = Vector3.new(T, 400, size.Z)
		center = Vector3.new(pos.X + outward.X * (T / 2 - size.X / 2), 200, pos.Z)
	else
		bsize = Vector3.new(size.X, 400, T)
		center = Vector3.new(pos.X, 200, pos.Z + outward.Z * (T / 2 - size.Z / 2))
	end
	part({ Name = name .. "Blocker", Size = bsize, Position = center, Transparency = 1, CanCollide = true, CanTouch = false }, Walls)
end

-- A SAFE GAP: an alcove cut into the side wall. Floods only cover the runway itself, so anyone standing in a gap is safe.
-- (It is fully closed on the other three sides, so it is no way out of the map either.)
----------------------------------------------------------------
-- VIP: the safe gaps in the walls are closed by a gold gate that only VIPs can walk through (VIPs are put in their own
-- collision group that ignores the gates). VIPs also get a gold tag over their head.
----------------------------------------------------------------
do
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		PhysicsService:RegisterCollisionGroup("VIPGate")
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup("VIPPlayers")
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("VIPPlayers", "VIPGate", false)
	end)
	local watchers = {}
	function applyVipAccess(player)
		local vip = OwnsPass[player] ~= nil and OwnsPass[player].VIP == true
		player:SetAttribute("IsVIP", vip)
		if watchers[player] then
			watchers[player]:Disconnect()
			watchers[player] = nil
		end
		local char = player.Character
		if not char then
			return
		end
		local group = (vip and Config.VIP.SafeZones) and "VIPPlayers" or "Default"
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CollisionGroup = group
			end
		end
		watchers[player] = char.DescendantAdded:Connect(function(d) -- tools and accessories join the same group
			if d:IsA("BasePart") then
				d.CollisionGroup = group
			end
		end)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local old = hrp and hrp:FindFirstChild("VipTag")
		if old then
			old:Destroy()
		end
		if vip and hrp and Config.VIP.Tag ~= "" then
			local tag = billboard(hrp, Config.VIP.Tag, GOLD, Vector3.new(0, 3.6, 0), UDim2.fromOffset(90, 30), 80)
			tag.Name = "VipTag"
		end
	end
end

local function buildShelter(sh, zone)
	local side, cx = sh.Side, sh.X
	local W, D, H = Config.ShelterWidth, Config.ShelterDepth, 60
	local zMid = side * (RW / 2 + D / 2)
	local zBack = side * (RW / 2 + D)
	local SAFE = Color3.fromRGB(80, 255, 140)
	-- floor level with the runway, with a glowing safe pad
	part({ Name = "ShelterFloor", Size = Vector3.new(W, 1, D), Position = Vector3.new(cx, -0.5, zMid), Color = zone.Color2, Material = Enum.Material.SmoothPlastic }, World)
	part({ Name = "ShelterPad", Size = Vector3.new(W - 3, 0.3, D - 3), Position = Vector3.new(cx, 0.15, zMid), Color = SAFE, Material = Enum.Material.Neon, Transparency = 0.45, CanCollide = false }, World)
	-- walls: two sides + the back (each with its own thick invisible blocker)
	for _, dx in ipairs({ -1, 1 }) do
		solidWall("ShelterSide", Vector3.new(2, H, D), Vector3.new(cx + dx * (W / 2 + 1), H / 2, zMid), Vector3.new(dx, 0, 0), zone.Color:Lerp(Color3.new(0, 0, 0), 0.12))
	end
	solidWall("ShelterBack", Vector3.new(W + 4, H, 2), Vector3.new(cx, H / 2, zBack + side), Vector3.new(0, 0, side), zone.Color:Lerp(Color3.new(0, 0, 0), 0.12))
	-- a glowing frame around the opening + SAFE sign so you can spot it while running
	local edgeZ = side * (RW / 2 + 1)
	for _, dx in ipairs({ -1, 1 }) do
		part({ Name = "ShelterPost", Size = Vector3.new(1.6, 26, 1.6), Position = Vector3.new(cx + dx * (W / 2 + 0.2), 13, edgeZ), Color = SAFE, Material = Enum.Material.Neon }, World)
	end
	local bar = part({ Name = "ShelterBar", Size = Vector3.new(W + 3, 2.4, 1.6), Position = Vector3.new(cx, 26.2, edgeZ), Color = SAFE, Material = Enum.Material.Neon }, World)
	billboard(bar, sh.Free and "SAFE" or "VIP SAFE", WHITE, Vector3.new(0, 0, 0), UDim2.fromOffset(200, 44), 110)
	local l = Instance.new("PointLight")
	l.Color = SAFE
	l.Range = 26
	l.Brightness = 1.5
	l.Parent = bar
	if not sh.Free then -- a gold gate across the opening: only VIPs can walk through it (tall enough that jump boosts can't clear it)
		local gate = part({ Name = "VipGate", Size = Vector3.new(W, 24, 1), Position = Vector3.new(cx, 12, edgeZ), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = true }, World)
		gate.CollisionGroup = "VIPGate"
		billboard(gate, "VIP ONLY", GOLD, Vector3.new(0, 0, 0), UDim2.fromOffset(160, 40), 60)
		local promptCooldown = {}
		gate.Touched:Connect(function(hit)
			local plr = Players:GetPlayerFromCharacter(hit.Parent)
			if not plr or (OwnsPass[plr] and OwnsPass[plr].VIP) then
				return
			end
			local last = promptCooldown[plr]
			if last and os.clock() - last < 10 then
				return
			end
			promptCooldown[plr] = os.clock()
			local id = Config.GamePasses.VIP.Id
			if id > 0 then
				MarketplaceService:PromptGamePassPurchase(plr, id)
			end
		end)
	end
end

----------------------------------------------------------------
-- EXTRAS: details INSIDE every zone (each biome has its own little props), a park with realistic trees + a big fountain at the
-- plaza entrance, the Group Reward booth and the Pet Storage shelves.
----------------------------------------------------------------
local function buildExtras()
	local function bit(size, pos, color, material, shape, rot)
		return part({ Name = "Detail", Shape = shape or Enum.PartType.Block, Size = size, CFrame = CFrame.new(pos) * (rot or CFrame.new()), Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = false }, Decor)
	end
	local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
	local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing up
	local function pick(list)
		return list[rng:NextInteger(1, #list)]
	end
	local function rgb(r, g, b)
		return Color3.fromRGB(r, g, b)
	end
	local function spin()
		return CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	end

	-- ONE little prop for every biome (Config.Zones[..].Decor decides which one a zone uses)
	for z = 1, ZONES do
		local zone = Config.Zones[z]
		local x0, L = Config.ZoneStarts[z], zone.Length
		-- the SAME decoration the player already sees through the walls outside, brought onto the floor too, so the
		-- zone feels like one consistent biome inside and out instead of two different looks
		local fn = DECOR[zone.Decor] or decorTree
		for _ = 1, math.floor(L / 30) do -- scattered over the whole floor
			fn(rng:NextNumber(x0 + 10, x0 + L - 10), rng:NextNumber(-RW / 2 + 12, RW / 2 - 12))
		end
		for _, side in ipairs({ -1, 1 }) do -- a thicker band along the walls
			for _ = 1, math.floor(L / 40) do
				fn(rng:NextNumber(x0 + 10, x0 + L - 10), side * rng:NextNumber(RW / 2 - 14, RW / 2 - 5))
			end
		end
	end

	-- REALISTIC TREE: roots, a leaning tapered trunk in segments, branches, and a canopy of many leaf clusters in 3 greens that sways in the wind
	-- (deliberately left as an implicit global, not added to the local-forward-declare line above: this file is already
	-- at its 200-top-level-local ceiling, and realTree only needs to exist by the time buildPlot() runs, which it does)
	function realTree(x, z, s)
		s = s or 1
		local bark = rgb(104, 72, 48)
		local lean = rng:NextNumber(-0.1, 0.1)
		for i = 1, 5 do -- roots
			local a = i * 1.257 + rng:NextNumber(-0.25, 0.25)
			part({ Name = "Root", Size = Vector3.new(3.2 * s, 0.9 * s, 1 * s), CFrame = CFrame.new(x + math.cos(a) * 1.6 * s, 0.35 * s, z + math.sin(a) * 1.6 * s) * CFrame.Angles(0, -a, math.rad(-12)), Color = bark, Material = Enum.Material.Wood, CanCollide = false }, Decor)
		end
		local top = 0
		for i = 1, 6 do -- trunk: 6 stacked segments that taper and lean
			local h, r = 3 * s, (1.9 - i * 0.22) * s
			local cx = x + lean * top
			part({ Name = "Trunk", Shape = CYL, Size = Vector3.new(h + 0.3, r * 2, r * 2), CFrame = CFrame.new(cx, top + h / 2, z) * CFrame.Angles(0, 0, math.rad(90) - lean), Color = bark:Lerp(rgb(70, 50, 34), i / 9), Material = Enum.Material.Wood, CanCollide = i == 1 }, Decor)
			top += h
		end
		local cx = x + lean * top
		for i = 1, 4 do -- branches
			local a, el = i * 1.57 + rng:NextNumber(-0.3, 0.3), rng:NextNumber(0.55, 0.9)
			local from = Vector3.new(cx, top - rng:NextNumber(2, 5) * s, z)
			local d = Vector3.new(math.cos(a) * math.cos(el), math.sin(el), math.sin(a) * math.cos(el))
			local len = rng:NextNumber(5, 7.5) * s
			part({ Name = "Branch", Shape = CYL, Size = Vector3.new(len, 0.9 * s, 0.9 * s), CFrame = CFrame.lookAt(from + d * len / 2, from + d * len) * CFrame.Angles(0, math.pi / 2, 0), Color = bark, Material = Enum.Material.Wood, CanCollide = false }, Decor)
		end
		local canopy = Instance.new("Model")
		canopy.Name = "Canopy"
		local greens = { rgb(72, 150, 66), rgb(96, 176, 78), rgb(52, 120, 58) }
		for i = 1, 13 do
			local a, up = rng:NextNumber(0, 6.28), rng:NextNumber(0, 1)
			local rad = (1 - up * 0.6) * 5.6 * s
			local d = rng:NextNumber(5, 9) * s
			part({ Name = "Leaves", Shape = BALL, Size = Vector3.new(d, d * 0.85, d), Position = Vector3.new(cx + math.cos(a) * rad * rng:NextNumber(0.3, 1), top + 1 * s + up * 6.5 * s, z + math.sin(a) * rad * rng:NextNumber(0.3, 1)), Color = greens[(up < 0.35) and 3 or rng:NextInteger(1, 2)], Material = Enum.Material.SmoothPlastic, CanCollide = false }, canopy)
		end
		local drift = part({ Name = "LeafDrift", Size = Vector3.new(6 * s, 1, 6 * s), Position = Vector3.new(cx, top + 1 * s, z), Transparency = 1, CanCollide = false }, canopy)
		local pe = Instance.new("ParticleEmitter") -- a few leaves drifting down
		pe.Rate = 1.5
		pe.Lifetime = NumberRange.new(5, 7)
		pe.Speed = NumberRange.new(0.5, 2)
		pe.SpreadAngle = Vector2.new(60, 60)
		pe.EmissionDirection = Enum.NormalId.Bottom
		pe.Acceleration = Vector3.new(0.6, -3, 0.4)
		pe.RotSpeed = NumberRange.new(-120, 120)
		pe.Size = NumberSequence.new(0.45)
		pe.Color = ColorSequence.new(rgb(110, 190, 80), rgb(226, 190, 70))
		pe.Parent = drift
		canopy:SetAttribute("Phase", rng:NextNumber(0, 6.28))
		canopy.Parent = Decor
		canopy:SetAttribute("BaseCF", canopy:GetPivot())
		CollectionService:AddTag(canopy, "SwayTree")
	end

	-- the entrance: kept clear on purpose - no fountain and no trees here any more (the only trees left are the ones
	-- planted between the bases, built in buildPlot() below via realTree)

	-- (the Group Reward booth was removed - the "GROUP GIFT" side button now just says "Coming soon...")

	-- PET STORAGE: shelves full of eggs next to Cleo; keep, swap and sell as many pets as you like
	do
		local sx, sz = Config.Market.PetX + 12, 134
		part({ Name = "StorageBack", Size = Vector3.new(1, 14, 22), Position = Vector3.new(sx + 4, 8, sz), Color = rgb(96, 70, 150) }, World)
		local eggColors = { rgb(255, 170, 225), rgb(140, 200, 255), rgb(190, 140, 255), rgb(255, 210, 100), rgb(140, 240, 190), rgb(255, 130, 130) }
		for row = 1, 3 do
			part({ Name = "StorageShelf", Size = Vector3.new(3.4, 0.8, 22), Position = Vector3.new(sx + 2.4, 1 + row * 3.6, sz), Color = rgb(240, 225, 250) }, World)
			for k = 1, 5 do
				part({ Name = "StorageEgg", Shape = BALL, Size = Vector3.new(2.2, 2.8, 2.2), Position = Vector3.new(sx + 2.4, 3 + row * 3.6, sz - 10 + k * 3.6), Color = eggColors[(row * 2 + k) % #eggColors + 1], CanCollide = false }, World)
			end
		end
		local board = part({ Name = "StorageSign", Size = Vector3.new(1, 4, 20), Position = Vector3.new(sx + 3.5, 17.5, sz), Color = rgb(40, 30, 90) }, World)
		billboard(board, "PET STORAGE", Color3.fromRGB(255, 190, 235), Vector3.new(0, 0.6, 0), UDim2.fromOffset(420, 56), 220)
		billboard(board, "keep, swap or sell your pets", Color3.fromRGB(215, 225, 255), Vector3.new(0, -1.3, 0), UDim2.fromOffset(360, 28), 120)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Open Pet Storage"
		pp.ObjectText = "Pets"
		pp.HoldDuration = 0.2
		pp.MaxActivationDistance = 16
		pp.RequiresLineOfSight = false
		pp.Parent = board
		pp.Triggered:Connect(function(player)
			UIRemote:FireClient(player, "OpenPets")
		end)
	end
end

local function buildWorld()
	local old = Workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end
	setupLighting()

	-- ground far below so the outside of the map is never an empty void.
	-- (Roblox parts can't be longer than 2048 studs, so it is laid in chunks.)
	do
		local x = -800
		while x < RUNWAY_END + 1500 do
			part({ Name = "OuterGround", Size = Vector3.new(2000, 4, 2000), Position = Vector3.new(x + 1000, -4.6, 0), Color = Color3.fromRGB(140, 130, 205) }, World)
			x += 2000
		end
	end

	-- base area + big open plaza (no walls anywhere near the bases!)
	part({
		Name = "HubGround",
		Size = Vector3.new(HUB_BACK + RS_START, 4, HUB_HALF_Z * 2),
		Position = Vector3.new((RS_START - HUB_BACK) / 2, -2, 0),
		Color = Color3.fromRGB(232, 214, 247),
		Material = Enum.Material.SmoothPlastic,
	}, World)
	part({
		Name = "Plaza",
		Size = Vector3.new(RS_START + 20, 0.4, HUB_HALF_Z * 2),
		Position = Vector3.new((RS_START - 20) / 2, 0.2, 0),
		Color = Color3.fromRGB(235, 222, 200),
		Material = Enum.Material.Cobblestone,
	}, World)
	part({
		Name = "Carpet",
		Size = Vector3.new(RS_START + 20, 0.5, 30),
		Position = Vector3.new((RS_START - 20) / 2, 0.25, 0),
		Color = Color3.fromRGB(255, 120, 190),
	}, World)

	-- plaza decorations (the walking path to the runway, z from -90 to 90, stays completely clear)
	for zz = -240, 240, 60 do
		if math.abs(zz) >= 100 then
			lampPost(10, zz)
		end
	end
	-- (both plaza fountains removed - they kept blocking market stall visibility)
	buildShop()

	-- giant welcome arch over the runway entrance
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "WelcomePillar", Size = Vector3.new(6, 50, 6), Position = Vector3.new(RS_START - 6, 25, s * (RW / 2 - 6)), Color = Color3.fromRGB(255, 120, 190) }, World)
	end
	local welcome = part({
		Name = "WelcomeBar",
		Size = Vector3.new(6, 12, RW),
		Position = Vector3.new(RS_START - 6, 55, 0),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Neon,
	}, World)
	billboard(welcome, "GRAB A GOOBER!", Color3.fromRGB(255, 255, 255), Vector3.new(0, 0, 0), UDim2.fromOffset(700, 130), 700)

	-- zones (all different lengths!): checkerboard floor, themed ground, gate arch, scenery, drifting particles
	local ZONE_MATERIAL = { -- the ground material of each of the 14 zones (a local inside buildWorld, not top-level - only used right here)
		Enum.Material.Grass, Enum.Material.Basalt, Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.LeafyGrass,
		Enum.Material.SmoothPlastic, Enum.Material.Grass, Enum.Material.DiamondPlate, Enum.Material.SmoothPlastic, Enum.Material.Slate,
		Enum.Material.SmoothPlastic, Enum.Material.Marble, Enum.Material.Slate, Enum.Material.Concrete,
	}
	for z = 1, ZONES do
		local zone = Config.Zones[z]
		local x0, L = Config.ZoneStarts[z], zone.Length
		local mat = ZONE_MATERIAL[z] or Enum.Material.SmoothPlastic

		part({
			Name = "ZoneGround" .. z,
			Size = Vector3.new(L, 4, 1500),
			Position = Vector3.new(x0 + L / 2, -2.6, 0),
			Color = zone.Ground,
			Material = mat,
		}, World)

		local tileX, tileZ = L / 10, RW / 5
		for cx = 0, 9 do
			for cz = 0, 4 do
				local alt = (cx + cz) % 2 == 0
				part({
					Name = "Tile",
					Size = Vector3.new(tileX, 1, tileZ),
					Position = Vector3.new(x0 + tileX * (cx + 0.5), -0.5, -RW / 2 + tileZ * (cz + 0.5)),
					Color = alt and zone.Color or zone.Color2,
					Material = mat,
				}, FloorFolder)
			end
		end

		-- gate arch at the start of the zone
		local ax = x0 + 2
		for _, s in ipairs({ -1, 1 }) do
			part({
				Name = "ArchPillar",
				Size = Vector3.new(4, 26, 4),
				Position = Vector3.new(ax, 13, s * (RW / 2 - 3)),
				Color = zone.Accent,
				Material = Enum.Material.Neon,
			}, World)
		end
		local bar = part({
			Name = "ArchBar",
			Size = Vector3.new(5, 7, RW),
			Position = Vector3.new(ax, 29, 0),
			Color = zone.Accent,
			Material = Enum.Material.Neon,
		}, World)
		local zsign = billboard(bar, zone.Name, WHITE, Vector3.new(0, 0, 0), UDim2.fromOffset(520, 100), 260)
		zsign.Name = "ZoneSign"
		zsign:SetAttribute("Zone", z)
		CollectionService:AddTag(zsign, "ZoneSign")

		-- scenery outside the walls, themed per zone (kept clear of the safe gaps)
		local fn = DECOR[zone.Decor] or decorTree
		for _, side in ipairs({ -1, 1 }) do
			for _ = 1, math.floor(L / 17) do
				local x = rng:NextNumber(x0 + 8, x0 + L - 20)
				local zz = side * rng:NextNumber(RW / 2 + Config.ShelterDepth + 10, RW / 2 + 140)
				fn(x, zz, rng:NextNumber(0.9, 1.5))
			end
		end

		-- slowly drifting glow in the air, in the zone's color
		local amb = part({
			Name = "Ambient" .. z,
			Size = Vector3.new(L, 1, RW),
			Position = Vector3.new(x0 + L / 2, 34, 0),
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
		}, World)
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.EmissionDirection = Enum.NormalId.Bottom
		pe.Rate = math.floor(L / 20)
		pe.Lifetime = NumberRange.new(9, 13)
		pe.Speed = NumberRange.new(0.5, 2)
		pe.Acceleration = Vector3.new(0, -1.5, 0)
		pe.Color = ColorSequence.new(zone.Accent:Lerp(WHITE, 0.4))
		pe.Size = NumberSequence.new(0.7)
		pe.Transparency = NumberSequence.new(0.45)
		pe.LightEmission = 0.5
		pe.Parent = amb
	end

	-- WALLS: the map is fully enclosed, far away from the bases. Thick invisible blockers make it impossible to leave.
	local H = 60
	solidWall("BackWall", Vector3.new(2, H, HUB_HALF_Z * 2 + 4), Vector3.new(-HUB_BACK - 1, H / 2, 0), Vector3.new(-1, 0, 0))
	for _, s in ipairs({ -1, 1 }) do
		solidWall("HubSide", Vector3.new(HUB_BACK + RS_START + 2, H, 2), Vector3.new((RS_START - HUB_BACK) / 2, H / 2, s * (HUB_HALF_Z + 1)), Vector3.new(0, 0, s))
		solidWall("HubEast", Vector3.new(2, H, HUB_HALF_Z - RW / 2), Vector3.new(RS_START, H / 2, s * ((HUB_HALF_Z + RW / 2) / 2)), Vector3.new(1, 0, 0))
	end
	solidWall("RunwayEnd", Vector3.new(2, H, RW + 4), Vector3.new(RUNWAY_END + 1, H / 2, 0), Vector3.new(1, 0, 0), Config.WallColorFor(ZONES))

	-- the long side walls: cut into pieces (a part can't be longer than 2048 studs) with a gap at every safe alcove
	local halfW = Config.ShelterWidth / 2 + 2
	for _, s in ipairs({ -1, 1 }) do
		local cursor = RS_START
		local function run(x0, x1)
			for z = 1, ZONES do -- every zone has its own wall colour, so the pieces are cut at the zone borders
				local zs = Config.ZoneStarts[z]
				local x = math.max(x0, zs)
				local zend = math.min(x1, zs + Config.Zones[z].Length)
				while x < zend - 0.01 do
					local len = math.min(800, zend - x)
					solidWall("RunwaySide", Vector3.new(len, H, 2), Vector3.new(x + len / 2, H / 2, s * (RW / 2 + 1)), Vector3.new(0, 0, s), Config.WallColorFor(z))
					x += len
				end
			end
		end
		for _, sh in ipairs(Config.Shelters) do
			if sh.Side == s then
				run(cursor, sh.X - halfW)
				cursor = sh.X + halfW
			end
		end
		run(cursor, RUNWAY_END)
	end
	for _, sh in ipairs(Config.Shelters) do
		local zi = ZONES
		for z = 1, ZONES do
			if sh.X < Config.ZoneStarts[z] + Config.Zones[z].Length then
				zi = z
				break
			end
		end
		buildShelter(sh, Config.Zones[zi])
	end

	buildExtras()
	for i = 1, Config.PlotCount do
		buildPlot(i)
	end
end

----------------------------------------------------------------
-- GOOBER PICKUPS: only inside the zones (never in the plaza) - each zone has its own length
-- Pity system: if a zone hasn't shown an Epic / Legendary / Mythic for a while, the next spawn is guaranteed to be one.
----------------------------------------------------------------
do -- scoped: Pity and chooseGoober are only used by spawnPickup right below, which is already forward-declared as its own global
	local Pity = {}

	local function chooseGoober(zone)
		local p = Pity[zone]
		if not p then
			p = { Epic = 0, Legendary = 0, Mythic = 0 }
			Pity[zone] = p
		end
		local chosen
		for _, rar in ipairs({ "Mythic", "Legendary", "Epic" }) do
			if p[rar] >= Config.Pity[rar] then
				local pool = {}
				for _, g in ipairs(Config.Goobers) do
					if g.Zone == zone and g.Rarity == rar then
						table.insert(pool, g)
					end
				end
				if #pool > 0 then
					chosen = pool[rng:NextInteger(1, #pool)]
					break
				end
			end
		end
		chosen = chosen or Config.RollGoober(zone, 0)
		local rank = Config.Rarities[chosen.Rarity].Rank
		for rar in pairs(p) do
			p[rar] += 1
			if rank >= Config.Rarities[rar].Rank then
				p[rar] = 0
			end
		end
		return chosen
	end

	function spawnPickup(zone)
		local x0, L = Config.ZoneStarts[zone], Config.Zones[zone].Length
		local x = rng:NextNumber(x0 + 16, x0 + L - 16)
		local z = rng:NextNumber(-RW / 2 + 10, RW / 2 - 10)
		local def = chooseGoober(zone)
		local item = { Id = def.Id, Mut = Config.RollMutation(MutationEvent and 3 or 1, MutationEvent or nil), Zone = zone } -- (the zone decides which boss hunts you)
		createPickup(item, Vector3.new(x, 0, z), zone, nil)
	end
end

function respawnAllPickups()
	for _, m in ipairs(Pickups:GetChildren()) do
		m:Destroy()
	end
	for z = 1, ZONES do
		for _ = 1, Config.PickupsForZone(z) do
			spawnPickup(z)
		end
	end
end

----------------------------------------------------------------
-- THE FLOODS (random types: fast, slow, triple, tidal, impossible...)
-- The runway is very long, so each flood starts at a random point along it (rarely the very end).
-- The server only keeps one tiny invisible marker per flood (its start and speed as attributes). Every player's
-- screen draws the wavy water itself from those numbers, which is smooth and costs no network traffic.
-- The tall ones can't be jumped: hide in one of the SAFE gaps in the side walls.
----------------------------------------------------------------
local Waves = {}

local function spawnWave(wt, startX)
	-- the flood itself is a real, visible slab: it can be seen from anywhere on the map. Players close to it also get the wavy
	-- water drawn on top by their own screen (and their screen hides this plain slab while that is showing).
	local width = wt.HalfWidth and RW * 0.5 or RW
	local marker = part({
		Name = "Flood",
		Size = Vector3.new(wt.Thickness, wt.Height, width),
		Position = Vector3.new(startX, wt.Height / 2, 0),
		Color = wt.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	}, World)
	local t0 = Workspace:GetServerTimeNow()
	marker:SetAttribute("StartX", startX)
	marker:SetAttribute("StartTime", t0)
	marker:SetAttribute("Speed", wt.Speed)
	marker:SetAttribute("Height", wt.Height)
	marker:SetAttribute("Thickness", wt.Thickness)
	marker:SetAttribute("Width", width)
	marker:SetAttribute("WaveColor", wt.Color)
	marker:SetAttribute("Rainbow", wt.Rainbow == true)
	marker:SetAttribute("SideToSide", wt.SideToSide == true)
	marker:SetAttribute("OscAmp", (RW - width) / 2) -- how far it swings from the centre - just enough to still reach both walls
	marker:SetAttribute("OscFreq", Config.WaveOscFreq)
	CollectionService:AddTag(marker, "FloodWave")
	table.insert(Waves, { Body = marker, X0 = startX, T0 = t0, X = startX, Z = 0, Speed = wt.Speed, Height = wt.Height, Half = wt.Thickness / 2 + 0.5, Width = width, SideToSide = wt.SideToSide == true, OscAmp = (RW - width) / 2, OscFreq = Config.WaveOscFreq })
end

function clearWaves()
	for i = #Waves, 1, -1 do
		Waves[i].Body:Destroy()
		table.remove(Waves, i)
	end
end

do -- scoped: lastSlabDraw is only needed by this one Heartbeat connection, and the connection itself never needs to be referenced elsewhere
	local lastSlabDraw = 0
	RunService.Heartbeat:Connect(function()
		if #Waves == 0 then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local drawSlabs = now - lastSlabDraw >= 0.08 -- the plain slab moves ~12 times a second (the detailed water on each screen is smooth)
		if drawSlabs then
			lastSlabDraw = now
		end
		for i = #Waves, 1, -1 do
			local w = Waves[i]
			w.X = w.X0 - w.Speed * (now - w.T0)
			if w.SideToSide then
				w.Z = math.sin((now - w.T0) * w.OscFreq) * w.OscAmp
			end
			if w.X - w.Half < RS_START then -- never let it reach past the very start of zone 1 - checked from the LEADING edge, not the center, so thick waves can't spill into the plaza
				w.Body:Destroy()
				table.remove(Waves, i)
			elseif drawSlabs then
				w.Body.Position = Vector3.new(w.X, w.Height / 2, w.Z)
			end
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local b = Boosts[plr]
			local guarded = GodMode[plr] or (b ~= nil and (b.Guard or 0) > now)
			if hrp and Data[plr] and not guarded then
				local p = hrp.Position
				-- the plaza is always safe, and so is every SAFE gap (they are beyond the edge of the runway).
				-- (p.Y - 3) = height of the player's feet.
				if p.X > RS_START + 2 and math.abs(p.Z) <= RW / 2 + 1 then
					for _, w in ipairs(Waves) do
						if math.abs(p.X - w.X) <= w.Half and math.abs(p.Z - w.Z) <= w.Width / 2 and (p.Y - 3) < w.Height then
							sweep(plr)
							break
						end
					end
				end
			end
		end
	end)
end

do
	-- ADMIN CHAT COMMAND: "!wave rainbow" spawns that wave type right now ("!wave" lists them). Handy for testing each wave.
	local function onChat(player, msg)
		local arg = msg:lower():match("^!wave%s*(.*)$")
		if not arg or not isAdmin(player) then
			return
		end
		arg = arg:gsub("%s+$", "")
		if arg ~= "" then
			for _, wt in ipairs(Config.WaveTypes) do
				if wt.Name:lower():find(arg, 1, true) then
					adminCommand(player, "Wave", wt.Name)
					return
				end
			end
		end
		local names = {}
		for _, wt in ipairs(Config.WaveTypes) do
			table.insert(names, (wt.Emoji or "") .. " " .. wt.Name:lower())
		end
		notify(player, "!wave <name>:  " .. table.concat(names, ",  "), GOLD)
	end
	local function hook(player)
		player.Chatted:Connect(function(msg)
			onChat(player, msg)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
end

local function pickWaveType(name)
	if name then
		for _, wt in ipairs(Config.WaveTypes) do
			if wt.Name == name then
				return wt
			end
		end
	end
	local total = 0
	for _, wt in ipairs(Config.WaveTypes) do
		total += wt.Weight
	end
	local r = rng:NextNumber() * total
	for _, wt in ipairs(Config.WaveTypes) do
		r -= wt.Weight
		if r <= 0 then
			return wt
		end
	end
	return Config.WaveTypes[1]
end

-- releases one flood right now (the timer loop uses this, and so does the admin menu)
function triggerWave(name)
	local wt = pickWaveType(name)
	local startX
	if wt.Local then
		startX = math.min(RUNWAY_END + 20, RS_START + wt.Speed * wt.Travel)
	else
		local front = RS_START -- the front-most player on the runway
		for _, plr in ipairs(Players:GetPlayers()) do
			local hrp = Data[plr] and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				front = math.max(front, hrp.Position.X)
			end
		end
		startX = math.clamp(front + rng:NextNumber(Config.WaveSpawnAhead[1], Config.WaveSpawnAhead[2]), RS_START + Config.WaveSpawnAhead[1], RUNWAY_END + 20)
	end
	for n = 1, wt.Count or 1 do
		spawnWave(wt, startX + (n - 1) * (wt.Gap or 0))
	end
	return wt
end

local WaveNumber = 0
task.spawn(function()
	while true do
		Workspace:SetAttribute("WaveState", "Idle")
		Workspace:SetAttribute("NextWave", Config.WaveInterval)
		while true do -- don't even start the flood countdown (it shows a full timer meanwhile) until somebody has actually stepped into zone 1
			local anyoneIn = false
			for _, plr in ipairs(Players:GetPlayers()) do
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if hrp and hrp.Position.X > RS_START then
					anyoneIn = true
					break
				end
			end
			if anyoneIn then
				break
			end
			task.wait(1)
		end
		for t = Config.WaveInterval, 1, -1 do
			Workspace:SetAttribute("NextWave", t)
			task.wait(1)
		end
		while WavesPaused do
			task.wait(1)
		end
		local wt = pickWaveType()
		Workspace:SetAttribute("WaveState", "Warning")
		Workspace:SetAttribute("WaveName", wt.Name)
		Workspace:SetAttribute("WaveJumpable", wt.Jumpable)
		AnnounceRemote:FireAllClients(wt.Title, wt.Sub, wt.Color, "horn")
		for t = Config.WaveWarning, 1, -1 do
			Workspace:SetAttribute("NextWave", t)
			task.wait(1)
		end
		if #Waves < 12 and not WavesPaused then
			triggerWave(wt.Name)
			WaveNumber += 1
			Workspace:SetAttribute("WaveNumber", WaveNumber)
		end
		Workspace:SetAttribute("WaveState", "Active")
		Workspace:SetAttribute("NextWave", 0)
		task.wait(Config.WaveAfter)
	end
end)

-- Mutation Hour event
task.spawn(function()
	Workspace:SetAttribute("Event", "")
	Workspace:SetAttribute("MutationEventName", "")
	while true do
		task.wait(Config.EventEvery)
		local mut = Config.EventMutations[rng:NextInteger(1, #Config.EventMutations)]
		local def = Config.Mutations[mut]
		MutationEvent = mut
		Workspace:SetAttribute("Event", ("%s MUTATION HOUR - %s Goobers give %s!"):format(mut:upper(), mut, def.PerkText))
		Workspace:SetAttribute("MutationEventName", mut) -- the client's pulsing event icon reads this
		notifyAll(("%s MUTATION HOUR!"):format(mut:upper()), def.Color, "reveal")
		task.wait(Config.EventLength)
		MutationEvent = false
		Workspace:SetAttribute("Event", "")
		Workspace:SetAttribute("MutationEventName", "")
	end
end)

----------------------------------------------------------------
-- BOUNDS: nobody can leave the map, however they got there. Anyone outside is put back where they were safe.
----------------------------------------------------------------
local LastSafe = {}
do -- scoped: inBounds and trackZone are only used by the task.spawn loop right below (LastSafe stays outside - onPlayerRemoving needs it too)
	function inBounds(p)
		if p.Y < -15 or p.Y > 450 then
			return false
		end
		if p.X < -HUB_BACK - 1.5 or p.X > RUNWAY_END + 1.5 then
			return false
		end
		if p.X < RS_START then
			return math.abs(p.Z) <= HUB_HALF_Z + 1.5
		end
		local az = math.abs(p.Z)
		if az <= RW / 2 + 1.5 then
			return true
		end
		-- inside one of the safe gaps in the side walls?
		if az <= RW / 2 + Config.ShelterDepth + 1.5 then
			local side = (p.Z > 0) and 1 or -1
			for _, sh in ipairs(Config.Shelters) do
				if sh.Side == side and math.abs(p.X - sh.X) <= Config.ShelterWidth / 2 + 1.5 then
					return true
				end
			end
		end
		return false
	end

	-- remembers the furthest zone a player has reached (it decides which texts they get to see)
	function trackZone(plr, x)
		local dd = Data[plr]
		local zn = Config.ZoneAtX(x)
		if dd and zn > dd.MaxZone then
			dd.MaxZone = zn
			plr:SetAttribute("MaxZone", zn)
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp and Data[plr] then
					if inBounds(hrp.Position) then
						LastSafe[plr] = hrp.CFrame
						trackZone(plr, hrp.Position.X)
					else
						local plot = PlotOf[plr]
						hrp.AssemblyLinearVelocity = Vector3.zero
						char:PivotTo(LastSafe[plr] or (plot and spawnCFrame(plot)) or CFrame.new(0, 10, 0))
					end
				end
			end
		end
	end)
end

----------------------------------------------------------------
-- BOSSES: one big boss per zone with a "!" over its head. It SLEEPS until a player picks up a Goober from ITS zone: then that boss
-- (and only that boss) hunts that player all the way to the plaza entrance. If the player drops the Goober, deposits it or reaches
-- the plaza, the boss lets go. If it catches the player, the player DIES and loses everything they carry.
----------------------------------------------------------------
local BossSystem = { List = {} }
do
	local Bosses = BossSystem.List
	local IDLE, HUNT = Color3.fromRGB(255, 200, 70), Color3.fromRGB(255, 50, 60)

	local function carriesFrom(plr, zone)
		for _, item in ipairs(Carrying[plr] or {}) do
			if item.Zone == zone then
				return true
			end
		end
		return false
	end

	local function kill(boss, plr)
		if GodMode[plr] then
			return
		end
		local lost = #(Carrying[plr] or {})
		Carrying[plr] = {}
		syncCarry(plr)
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
		end
		notify(plr, boss.Cfg.Name .. " got you!" .. (lost > 0 and (" You lost " .. lost .. " Goober" .. (lost > 1 and "s" or "")) or ""), RED, "stuck")
	end

	local function buildBoss(zone)
		local cfg = Config.BossFor(zone)
		local x0, L = Config.ZoneStarts[zone], Config.Zones[zone].Length
		local home = Vector3.new(x0 + L * 0.6, 0, 0)
		local spec = Creatures.SpecForBoss(cfg)
		local half = Creatures.HalfHeight(spec, cfg.Size)
		local model = Instance.new("Model")
		model.Name = "Boss_" .. zone
		local body = Creatures.Build(spec, cfg.Size, CFrame.new(home.X, half, home.Z) * CFrame.Angles(0, math.pi, 0), false, model)
		body.Anchored = true -- everything else is welded to this part, so the boss moves as one piece
		model.PrimaryPart = body
		if not spec.Custom then -- angry red brows
			for _, s in ipairs({ -1, 1 }) do
				local brow = Instance.new("Part")
				brow.Name = "BossBrow"
				brow.Size = Vector3.new(cfg.Size * 0.28, cfg.Size * 0.07, cfg.Size * 0.06)
				brow.CFrame = body.CFrame * CFrame.new(s * cfg.Size * 0.2, cfg.Size * 0.3, -cfg.Size * 0.46) * CFrame.Angles(0, 0, math.rad(-s * 24))
				brow.Color = Color3.fromRGB(200, 20, 30)
				brow.Material = Enum.Material.Neon
				brow.CanCollide = false
				brow.Massless = true
				brow.Parent = body
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = brow
				w.Parent = brow
			end
		end
		-- the big "!"
		local alert = Instance.new("BillboardGui")
		alert.Name = "BossAlert"
		alert.Size = UDim2.fromOffset(80, 100)
		alert.StudsOffset = Vector3.new(0, half + cfg.Size * 0.7, 0)
		alert.AlwaysOnTop = true
		alert.MaxDistance = 450
		alert.Adornee = body
		local mark = Instance.new("TextLabel")
		mark.Size = UDim2.fromScale(1, 1)
		mark.BackgroundTransparency = 1
		mark.Font = Enum.Font.FredokaOne
		mark.TextScaled = true
		mark.Text = "!"
		mark.TextColor3 = Color3.fromRGB(255, 200, 70) -- yellow while it sleeps, red while it hunts
		mark.Parent = alert
		local st = Instance.new("UIStroke")
		st.Thickness = 5
		st.Color = WHITE
		st.Parent = mark
		alert.Parent = body
		billboard(body, cfg.Name, WHITE, Vector3.new(0, half + cfg.Size * 0.3, 0), UDim2.fromOffset(200, 34), 70)
		CollectionService:AddTag(body, "BossBody")
		model.Parent = World
		table.insert(Bosses, { Zone = zone, Cfg = cfg, Body = body, Pos = home, Home = home, Half = half, Facing = Vector3.new(-1, 0, 0), Bob = 0, Mark = mark, Hunting = false })
	end

	-- moves every boss a little. A boss only wakes up for a player carrying a Goober from its own zone.
	function BossSystem.Tick(dt)
		local players = Players:GetPlayers()
		for _, b in ipairs(Bosses) do
			local cfg = b.Cfg
			local target, targetDist, targetHrp
			local watched = false
			for _, plr in ipairs(players) do
				local hrp = Data[plr] and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local p = hrp.Position
					local dx, dz = p.X - b.Pos.X, p.Z - b.Pos.Z
					local dist = math.sqrt(dx * dx + dz * dz)
					if dist < 600 then
						watched = true
					end
					-- it hunts somebody who carries a Goober from ITS zone and has not reached the plaza yet
					if p.X >= RS_START and not GodMode[plr] and carriesFrom(plr, b.Zone) then
						if not targetDist or dist < targetDist then
							target, targetDist, targetHrp = plr, dist, hrp
						end
					end
				end
			end
			local hunting = target ~= nil
			if hunting ~= b.Hunting then
				b.Hunting = hunting
				b.Mark.TextColor3 = hunting and HUNT or IDLE
				b.Body:SetAttribute("Hunting", hunting)
				if hunting then
					notify(target, cfg.Name .. " is hunting you! Drop the Goober or run for the entrance!", RED, "alarm")
				end
			end
			if watched or hunting then
				local goal = hunting and Vector3.new(targetHrp.Position.X, 0, targetHrp.Position.Z) or b.Home
				local speed = hunting and cfg.Speed or cfg.Speed * 0.6
				local to = goal - b.Pos
				local len = to.Magnitude
				if len > 0.5 then
					local dir = to.Unit
					b.Pos = b.Pos + dir * math.min(len, speed * dt)
					b.Facing = dir
				end
				b.Pos = Vector3.new(math.clamp(b.Pos.X, RS_START + 8, RUNWAY_END - 3), 0, math.clamp(b.Pos.Z, -RW / 2 + 4, RW / 2 - 4))
				b.Bob += dt * (hunting and 9 or 3)
				local y = b.Half + math.abs(math.sin(b.Bob)) * (hunting and 1.4 or 0.3)
				local here = Vector3.new(b.Pos.X, y, b.Pos.Z)
				b.Body.CFrame = CFrame.lookAt(here, here + b.Facing)
				if hunting and math.abs(targetHrp.Position.Z) <= RW / 2 and targetDist <= cfg.Size * 0.5 + 2.5 then
					kill(b, target)
				end
			end
		end
	end

	for z = 1, ZONES do
		buildBoss(z)
	end
	RunService.Heartbeat:Connect(function(dt)
		if Config.BossesEnabled then
			BossSystem.Tick(dt)
		end
	end)
end

----------------------------------------------------------------
-- PLAYERS
----------------------------------------------------------------
local function onCharacter(player, char)
	Carrying[player] = {}
	Stunned[player] = nil
	syncCarry(player)
	local waited = 0
	while not Data[player] and waited < 30 and player.Parent do
		task.wait(0.1)
		waited += 0.1
	end
	local d = Data[player]
	if not d then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function() -- only bosses can actually kill you - see if this death has a helpful hint due
			if not Data[player] then
				return
			end
			local dd = Data[player]
			dd.Deaths += 1
			local hint = Config.HintForDeaths(dd.Deaths)
			if hint then
				notify(player, hint, GOLD, "reveal")
			end
			task.spawn(saveData, player)
		end)
	end
	local plot = PlotOf[player]
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if hrp and plot then
		char:PivotTo(spawnCFrame(plot)) -- facing forward, towards the plaza
	end
	if d.Wacker then
		giveWacker(player)
	end
	refreshFF(player)
	applySpeed(player)
	applyVipAccess(player)
end

-- players fill the bases from the MIDDLE (next to the runway entrance) out to the far ends, so nobody has a long walk to the first zone
function Plots.pick()
	local order = table.clone(Plots)
	table.sort(order, function(a, b)
		local da, db = math.abs(a.Zc), math.abs(b.Zc)
		if da ~= db then
			return da < db
		end
		return a.Index < b.Index
	end)
	for _, p in ipairs(order) do
		if not p.Owner then
			return p
		end
	end
	return nil
end

local function onPlayerAdded(player)
	local plot = Plots.pick()
	if not plot then
		player:Kick("Server is full - please rejoin another server.")
		return
	end
	plot.Owner = player
	plot.DepositGui:SetAttribute("OwnerId", player.UserId)
	PlotOf[player] = plot
	player:SetAttribute("PlotIndex", plot.Index)
	player.RespawnLocation = plot.Spawn
	Carrying[player] = {}
	Boosts[player] = { Speed = 0, Jump = 0, Shield = 0, Cash = 0, Magnet = 0, Guard = 0 }

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in ipairs({ "Rebirths", "Cash" }) do -- (the list is ranked by the FIRST stat, which has to be a number) - Donated used to be here too, but it's donation-only now, so it no longer shows on Roblox's own player list (the in-game Top Donators board still has it)
		local v = Instance.new(n == "Cash" and "StringValue" or "IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.Parent = player

	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end

	checkPasses(player)
	local d = loadData(player)
	if not player.Parent then
		return
	end
	Data[player] = d
	-- OFFLINE EARNINGS: a returning player (LastSeen > 0) gets a claim popup for what they missed, at a reduced rate, capped at 24h
	if d.LastSeen > 0 then
		local elapsed = math.clamp(os.time() - d.LastSeen, 0, Config.OfflineEarnMaxSeconds)
		if elapsed > 30 then
			local rate = computeIncome(player, d)
			local amount = math.floor(rate * Config.OfflineEarnRate * elapsed)
			if amount > 0 then
				d.PendingOffline = amount
				task.delay(1.5, function()
					if player.Parent and Data[player] == d then
						UIRemote:FireClient(player, "OfflineEarnings", amount, elapsed)
					end
				end)
			end
		end
	end
	player:SetAttribute("GiftReady", false)
	player:SetAttribute("WheelReady", d.TutorialDone and not d.WheelClaimed)
	applyVipAccess(player)
	player:SetAttribute("TutDone", d.TutorialDone)
	player:SetAttribute("GroupClaimed", d.GroupClaimed)
	player:SetAttribute("GroupSetup", Config.Group.Id ~= 0)
	player:SetAttribute("IsAdmin", isAdmin(player))
	player:SetAttribute("AdminHost", isHost(player))
	player:SetAttribute("MaxZone", d.MaxZone)
	refresh(player)
	if d.Donated > 0 then
		task.spawn(pushLeaderboards, player) -- a returning donor's spot reappears on the board right away, not after a few seconds
	end
end

-- pushLeaderboards is defined further below via `function pushLeaderboards(player) ... end`, deliberately left as a
-- plain global (not a local) since sb.lua's Robux receipt handler calls it too, and a local here wouldn't reach that far

local function onPlayerRemoving(player)
	tradeCancel(player)
	Invites[player] = nil
	pushLeaderboards(player)
	saveData(player)
	local plot = PlotOf[player]
	if plot then
		plot.Owner = nil
		plot.Locked = false
		plot.DepositGui:SetAttribute("OwnerId", 0)
		clearPlot(plot)
	end
	for _, t in ipairs(TrapList) do
		if t.Owner == player then
			t.Expires = 0 -- the trap loop cleans these up
		end
	end
	Data[player] = nil
	Carrying[player] = nil
	PlotOf[player] = nil
	OwnsPass[player] = nil
	SaveAllowed[player] = nil
	LastAction[player] = nil
	LastSweep[player] = nil
	LastTP[player] = nil
	LastWack[player] = nil
	LastSafe[player] = nil
	Stunned[player] = nil
	Boosts[player] = nil
	GodMode[player] = nil
	MagnetFilter[player] = nil
	TempAdmins[player.UserId] = nil
end

-- refreshBoards is defined further below (same reasoning as pushLeaderboards above: left as a plain global)
do
	----------------------------------------------------------------
	-- LEADERBOARD DATA (OrderedDataStores: shared by every server)
	----------------------------------------------------------------
	local lbStores = {}
	for _, info in ipairs(LB_INFO) do
		local ok, st = pcall(function()
			return DataStoreService:GetOrderedDataStore("GAG_LB_" .. info.Key .. "_" .. Config.Leaderboards.Version)
		end)
		if ok then
			lbStores[info.Key] = st
		end
	end

	local nameCache = {}
	local function userName(uid)
		if nameCache[uid] then
			return nameCache[uid]
		end
		local online = Players:GetPlayerByUserId(uid)
		if online then
			nameCache[uid] = online.Name
			return online.Name
		end
		local ok, n = pcall(function()
			return Players:GetNameFromUserIdAsync(uid)
		end)
		nameCache[uid] = ok and n or "Player"
		return nameCache[uid]
	end

	local function lbValue(d, key)
		if key == "Cash" then
			return math.floor(math.min(d.Cash, 9e18))
		elseif key == "Donated" then
			return math.floor(d.Donated)
		end
		return d.Rebirths
	end

	function pushLeaderboards(player)
		local d = Data[player]
		if not d or not SaveAllowed[player] then
			return
		end
		for key, st in pairs(lbStores) do
			local v = lbValue(d, key)
			if v > 0 then
				pcall(function()
					st:SetAsync(tostring(player.UserId), v)
				end)
			end
		end
	end

	function wipeLeaderboards(player)
		for _, st in pairs(lbStores) do
			pcall(function()
				st:RemoveAsync(tostring(player.UserId))
			end)
		end
	end

	function refreshBoards()
		for key in pairs(LB) do
			local st = lbStores[key]
			local entries = {}
			if st then
				local ok, pages = pcall(function()
					return st:GetSortedAsync(false, Config.Leaderboards.Size)
				end)
				if ok and pages then
					local ok2, top = pcall(function()
						return pages:GetCurrentPage()
					end)
					if ok2 then
						for _, e in ipairs(top) do
							table.insert(entries, { Name = userName(tonumber(e.key) or 0), Value = e.value })
						end
					end
				end
			end
			renderBoard(key, entries)
			if not st then
				LB[key].Rows[1].Name.Text = "Enable API access"
			end
		end
	end

end

----------------------------------------------------------------
-- START EVERYTHING
----------------------------------------------------------------
buildWorld()
for z = 1, ZONES do
	for _ = 1, Config.PickupsForZone(z) do
		spawnPickup(z)
	end
end
-- (each pickup expires on its own timer, so they naturally rotate out at different times)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

task.spawn(trapLoop)

-- Passive income: each Goober earns onto its own pad. Walk on the pad to collect it.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local d = Data[player]
			if d then
				local mult = computeMult(player, d)
				local plot = PlotOf[player]
				local maxSlots = Config.MaxSlots(d.SlotLvl, d.FloorLvl)
				for i, item in ipairs(d.Placed) do
					if i <= maxSlots then
						item.Stored = (item.Stored or 0) + itemIncome(item) * mult
						if plot then
							refreshPad(plot, i, item)
						end
					end
				end
				d.PlayTime += 1
				if d.Spins < Config.SpinMax and os.time() - d.LastSpinRegen >= Config.SpinRegenSeconds then
					d.Spins += 1
					d.LastSpinRegen = os.time()
					notify(player, "You have a free spin! 🎡", GOLD, "pop")
				end
				updateStats(player)
			end
		end
	end
end)

-- Magnet Potion: Goobers of the rarities you picked fly into your hands
do -- scoped: magnetTick is only used by the task.spawn loop right below, which never needs to be referenced elsewhere
	function magnetTick()
		local now = Workspace:GetServerTimeNow()
		for _, plr in ipairs(Players:GetPlayers()) do
			local b = Boosts[plr]
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if b and b.Magnet > now and hrp and Data[plr] then
				local filter = MagnetFilter[plr]
				for model, info in pairs(PickupInfo) do
					local ball = model.PrimaryPart
					if ball and (not filter or filter[info.Rank or 1]) and (ball.Position - hrp.Position).Magnitude < 30 then
						info.Grab(plr, true)
					end
				end
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.35)
			magnetTick()
		end
	end)
end

-- temporary admins run out
task.spawn(function()
	while true do
		task.wait(5)
		local now = os.clock()
		for uid, exp in pairs(TempAdmins) do
			if exp <= now then
				TempAdmins[uid] = nil
				local p = Players:GetPlayerByUserId(uid)
				if p then
					GodMode[p] = nil
					p:SetAttribute("IsAdmin", false)
					notify(p, "Your admin time ran out", GOLD)
				end
			end
		end
	end
end)

-- Auto Collector: every 5 minutes, silently bank the stored cash for anyone who owns the pass and has it turned on
task.spawn(function()
	while true do
		task.wait(300)
		for _, player in ipairs(Players:GetPlayers()) do
			local d = Data[player]
			if d and OwnsPass[player] and OwnsPass[player].AutoCollect then
				collectAll(player)
			end
		end
	end
end)

-- Autosave + leaderboard upload every 60 seconds, boards refresh
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveData, player)
		end
	end
end)
task.spawn(function()
	task.wait(6)
	while true do
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(pushLeaderboards, p)
		end
		task.wait(4)
		refreshBoards()
		task.wait(Config.Leaderboards.Refresh)
	end
end)

game:BindToClose(function()
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		pending += 1
		task.spawn(function()
			pushLeaderboards(player)
			saveData(player)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 25 do
		task.wait(0.25)
		waited += 0.25
	end
end)

-- everything is built: tell the loading screen
-- Studio: print a checklist of every Robux item and whether its Id is set
if RunService:IsStudio() then
	local lines, missing = Config.RobuxReport()
	print(("=== ROBUX SETUP CHECKLIST: %d of %d Ids still missing (see the top of the Config script) ==="):format(missing, #lines))
	for _, l in ipairs(lines) do
		print(l)
	end
end

Workspace:SetAttribute("WorldReady", true)
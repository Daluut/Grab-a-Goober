
--[[
	GRAB A GOOBER: ESCAPE THE FLOOD  -  CONFIG  (v11)
	Script type : ModuleScript
	Name        : Config          (must be exactly "Config")
	Location    : ReplicatedStorage
]]

local Config = {}

----------------------------------------------------------------
-- ROBUX SETUP  -  every Robux item in the game is listed in this file. To turn them on:
--   1. Game passes:  Creator Hub > your game > Monetization > Passes > "Create a Pass". Give it the Name from the
--      list below, set the price, save, then copy its number (the Id) into Config.GamePasses.
--   2. Developer products:  Monetization > Developer Products > "Create". Same thing, paste the Id into
--      Config.Products (and Product3.Id for each egg in Config.Eggs - those are the "open 3 eggs" buttons).
--   3. Press Play in Studio: the Output window prints a checklist of every Robux item and whether its Id is set.
-- Id = 0 means "not set up yet" (the button just shows a reminder).
-- The Price here is only the label shown in game - set the SAME price on the Creator Hub page.
----------------------------------------------------------------
Config.GamePasses = {
	Thief = { Id = 1990250273, Price = 299, Label = "Thief Pass", Desc = "Steal Goobers from other bases!" },
	DoubleCash = { Id = 1983321911, Price = 199, Label = "2x Cash", Desc = "Double ALL income forever" },
	VIP = { Id = 1989278278, Price = 299, Label = "VIP", Desc = "+8 run speed, +25% income, VIP-only safe zones, gold VIP tag" },
	AutoCollect = { Id = 1989596677, Price = 250, Label = "Auto Collector", Desc = "One button instantly collects every Goober's cash - even if their pads are full! Auto-collects every 5 min too." },
}

Config.Products = { -- Developer Products (can be bought again and again)
	LuckyBox = { Id = 3714073402, Price = 59, Label = "Lucky Box", Desc = "Instant Legendary or Mythic Goober!" },
	-- CashPack was removed from the shop
	SuperLock = { Id = 3714073379, Price = 59, Label = "Super Lock", Desc = "Base locked for 5 minutes" },
	PetSlot5 = { Id = 3714119502, Price = 59, Label = "Extra Pet Slot 5", Desc = "Unlocks pet slot 5" },
	PetSlot6 = { Id = 3714119521, Price = 59, Label = "Extra Pet Slot 6", Desc = "Unlocks pet slot 6" },
	-- DONATIONS: pure support - no in-game reward, just Robux for Robux.
	Donate1 = { Id = 3714208951, Price = 1, Label = "Donate 1", Desc = "Just because!" },
	Donate2 = { Id = 3714208977, Price = 2, Label = "Donate 2", Desc = "A little support" },
	Donate10 = { Id = 3714209274, Price = 10, Label = "Donate 10", Desc = "Thank you!" },
	Donate20 = { Id = 3714209294, Price = 20, Label = "Donate 20", Desc = "You're awesome!" },
	Donate50 = { Id = 3714209327, Price = 50, Label = "Donate 50", Desc = "Big support!" },
	Donate100 = { Id = 3714209422, Price = 100, Label = "Donate 100", Desc = "Huge thanks!" },
	Donate1000 = { Id = 3714209443, Price = 1000, Label = "Donate 1,000", Desc = "Incredible generosity!" },
	Donate10000 = { Id = 3714209611, Price = 10000, Label = "Donate 10,000", Desc = "LEGENDARY supporter!!" },
}
Config.DonationTiers = { "Donate1", "Donate2", "Donate10", "Donate20", "Donate50", "Donate100", "Donate1000", "Donate10000" } -- shown in this order
-- you sent TWO different ids for "Cash Pack" (3714073392, then later 3714119629 as "Cash pack 1"). The shop button now
-- uses the newer one above, but a purchase through the older id still works too (it's listed here so nobody who buys
-- through it loses their Robux) - delete this line once you're sure only one Cash Pack product should exist.
-- (Config.CashPackAltIds removed along with the Cash Pack product)

-- Order of the Robux shop cards

Config.RobuxOrder = {
	{ Kind = "pass", Key = "Thief" },
	{ Kind = "pass", Key = "DoubleCash" },
	{ Kind = "pass", Key = "VIP" },
	{ Kind = "pass", Key = "AutoCollect" },
	{ Kind = "prod", Key = "LuckyBox" },
	{ Kind = "prod", Key = "SuperLock" },
}

-- The "50% OFF" star badges. Was = the price it used to be. Keep this TRUTHFUL:
-- set the real (lower) price in Creator Hub and put the old price here.
Config.Deals = {
	Thief = { Was = 598 },
	DoubleCash = { Was = 398 },
}

-- true  = stealing is FREE while testing inside Roblox Studio (so you can try it)
-- In the real published game stealing ALWAYS needs the Thief Pass.
Config.StealFreeInStudio = true

----------------------------------------------------------------
-- CODES  (players type these in the CODES menu)
-- HOW TO ADD A CODE: add ONE line inside Config.Codes. The name is what the player types (not case sensitive).
-- Every field is optional - mix any of these:
--   Cash = 5000                               money
--   Goober = "Blobbo", Mutation = "Golden"    a Goober (Mutation is optional: Normal / Golden / Neon / ...)
--   Pet = "Pip"                               a pet (goes in a free pet slot)
--   Egg = "Rare"                              a FREE egg of that tier, opened right away
--   Traps = 3                                 bear traps
--   Wacker = true                             the Wacker
--   Boosts = { Speed = 300 }                  potion time in seconds (Speed, Jump, Shield, Cash, Magnet, Guard)
--   Enabled = false                           switch the code off without deleting it
--   Expires = 1767225600                      last moment it works (unix seconds, UTC). Leave it out = never expires
-- Each player can use each code once. (The code is checked and given by the server: server script > CODE REWARDS.)
----------------------------------------------------------------
Config.Codes = {
	OG = { Cash = 20000, Goober = "OG Goober" },
	THANKYOU = { Cash = 100000, Goober = "Molten Max" }, -- a Mythic Goober + $100K
	RELEASED2026 = { Spins = 3 }, -- 3 free spins on the Goober Wheel
	-- WELCOME = { Cash = 5000, Egg = "Common" },
	-- SPEEDY = { Boosts = { Speed = 600, Cash = 300 } },
	-- SUMMER = { Cash = 250000, Pet = "Pip", Expires = 1782864000 },
}

----------------------------------------------------------------
-- FREE SPINS: everyone gets a free spin on the Goober Wheel every SpinRegenSeconds, stacking up to SpinMax.
----------------------------------------------------------------
Config.SpinRegenSeconds = 900 -- 15 minutes
Config.SpinMax = 10

----------------------------------------------------------------
-- GROUP REWARD: players who join your Roblox group can claim a free Epic Goober.
-- Put your group's id here (find it in the group page URL). Id = 0 hides the button.
----------------------------------------------------------------
Config.Group = { Id = 0, Name = "Your Group Name", Pet = "Waffles", Cash = 10000 } -- Pet must be an EPIC pet (Waffles is one)

-- ADMIN MENU (press U): only the game owner can open it. Add extra UserIds here for co-developers.
-- In Roblox Studio the person testing is always allowed.
Config.Admins = {}

----------------------------------------------------------------
-- WORLD / GAMEPLAY TUNING
----------------------------------------------------------------
Config.ZoneLength = 170 -- studs per zone (bigger!)
Config.RunwayWidth = 180 -- much wider runway
Config.RunwayStart = 70 -- the plaza in front of the bases is 70+ studs deep (no walls near your base)
Config.PlotCount = 8 -- player bases (set Max Players to this number)
Config.PlotSpacing = 60 -- distance between base centers (bases are 40 wide, so 20 stud gap)
Config.HubBack = 75 -- how far behind the road the base area extends
Config.PickupsPerZone = 10 -- Goobers lying around per zone
Config.DimAmount = 0.1 -- makes the whole world less bright (0 = original colors, 0.4 = quite dark)
-- Seconds a Goober stays on the runway before it disappears (then a new one spawns). Rarer = shorter!
Config.PickupLifetime = { Common = 70, Rare = 55, Epic = 45, Legendary = 35, Mythic = 28, Secret = 22 }
Config.DroppedLifetime = 30 -- Goobers dropped by wackers / traps
-- "Pity": if a zone hasn't spawned this rarity for this many spawns, the next spawn is guaranteed to be one
Config.Pity = { Epic = 10, Legendary = 26, Mythic = 60 }

-- BASE FLOORS: every floor has 10 pedestals. Floors are bought in the shop.
-- VIP PERKS (everything the VIP game pass gives). Change the numbers or turn a perk off here.
Config.VIP = {
	SpeedBonus = 8, -- extra run speed
	IncomeMult = 1.25, -- +25% cash from every Goober
	SafeZones = true, -- only VIPs can walk into the safe gaps in the walls (see Config.Shelter)
	Tag = "VIP", -- gold tag over their head ("" = no tag)
}

Config.MaxFloors = 5
Config.SlotsPerFloor = 10
Config.FloorHeight = 26
Config.TotalSlots = Config.MaxFloors * Config.SlotsPerFloor

Config.SellMultiplier = 8 -- selling a Goober gives (its income x this) in cash

-- Each Goober in your base can be upgraded (button on its pedestal). More levels = more $ per second.
Config.GooberMaxLevel = 25
Config.GooberLevelBonus = 0.4 -- +40% of base income per level
function Config.GooberUpgradeCost(baseIncome, level)
	return math.floor(baseIncome * 25 * 1.5 ^ level)
end
Config.DataStoreName = "GrabAGoober_v2" -- change the name to wipe EVERYONE'S saves (handy while testing)

-- THE FLOODS (no safe zones!)  Random types every cycle. Jumpable ones can be hopped over.
Config.WaveInterval = 8 -- seconds between floods (the next countdown starts as soon as a flood is released)
Config.WaveWarning = 4 -- warning seconds (horn!) before the flood appears
Config.WaveAfter = 3 -- seconds the banner shows what to do after a flood is released
Config.JumpPower = 56
-- Speed = studs/sec, Height = how high (feet must be above this to jump over it), Travel = seconds the flood should
-- take to cross the map. The start point is capped at the far end, so big Travel = the flood covers ALL zones,
-- small Travel = it starts closer (only threatens the first zones). Floods can overlap on the map.
Config.WaveTypes = {
	{ Name = "FLOOD", Weight = 30, Speed = 30, Height = 3.5, Thickness = 3, Travel = 70, Color = Color3.fromRGB(60, 255, 90), Title = "FLOOD INCOMING!", Sub = "Jump it!", Jumpable = true, Emoji = "🌊" },
	{ Name = "FAST FLOOD", Weight = 20, Speed = 55, Height = 3.5, Thickness = 3, Travel = 60, Color = Color3.fromRGB(255, 220, 40), Title = "FAST FLOOD INCOMING!", Sub = "Time your jump!", Jumpable = true, Emoji = "🌊⚡" },
	{ Name = "SLOW FLOOD", Weight = 6, Speed = 14, Height = 3, Thickness = 3, Travel = 60, Local = true, Color = Color3.fromRGB(90, 200, 255), Title = "SLOW FLOOD INCOMING", Sub = "Easy jump", Jumpable = true, Emoji = "🌊🐌" },
	{ Name = "TRIPLE FLOOD", Weight = 14, Speed = 32, Height = 3.5, Thickness = 3, Travel = 70, Count = 3, Gap = 55, Color = Color3.fromRGB(255, 110, 220), Title = "TRIPLE FLOOD INCOMING!", Sub = "Jump 3 times!", Jumpable = true, Emoji = "🌊🌊🌊" },
	{ Name = "TIDAL WAVE", Weight = 18, Speed = 24, Height = 16, Thickness = 8, Travel = 100, Color = Color3.fromRGB(40, 130, 255), Title = "TIDAL WAVE INCOMING!", Sub = "Too tall - hide in a gap!", Jumpable = false, Emoji = "🌊⚠️" },
	{ Name = "RAINBOW WAVE", Weight = 10, Speed = 26, Height = 4, Thickness = 6, Travel = 85, Rainbow = true, Color = Color3.fromRGB(230, 230, 255), Title = "RAINBOW WAVE INCOMING!", Sub = "Pretty AND dangerous - jump it!", Jumpable = true, Emoji = "🌈" },
	{ Name = "WACKY WAVE", Weight = 12, Speed = 22, Height = 20, Thickness = 3, Travel = 45, HalfWidth = true, SideToSide = true, Color = Color3.fromRGB(255, 140, 220), Title = "WACKY WAVE INCOMING!", Sub = "Too tall to jump - run to the open side!", Jumpable = false, Emoji = "🤪" },
	{ Name = "IMPOSSIBLE FLOOD", Weight = 12, Speed = 34, Height = 60, Thickness = 12, Travel = 110, Color = Color3.fromRGB(255, 40, 40), Title = "IMPOSSIBLE FLOOD INCOMING!!!", Sub = "HIDE IN A GAP!!!", Jumpable = false, Emoji = "🔥👿" },
}

Config.LuckyBoxCost = 2000
Config.LockCost = 25000 -- (was 1000)

----------------------------------------------------------------
-- NPC OUTFITS: dress the shop NPCs in REAL Roblox items. For each NPC, EITHER:
--   UserId = <any Roblox user id>      -> the NPC wears that player's whole avatar (clothes, accessories, skin, face)
--                                         (the id is the number in a profile link: roblox.com/users/<id>/profile)
--   OR pick items yourself (the number in a catalog link: roblox.com/catalog/<id>/...):
--      Shirt = <id>, Pants = <id>, Accessories = { <hat id>, <hair id>, ... }, Face = <face id>
-- Leave everything at 0 / empty to keep the NPC's built-in cartoon look. A wrong or unavailable id just keeps that look.
----------------------------------------------------------------
Config.NPCOutfits = {
	["Gus"] = { UserId = 0, Shirt = 0, Pants = 0, Accessories = {}, Face = 0 },
	["Cuddles Cleo"] = { UserId = 0, Shirt = 0, Pants = 0, Accessories = {}, Face = 0 },
}

----------------------------------------------------------------
-- TRAILS: a glowing trail behind you + a permanent speed boost while it's equipped. Each one costs ~100x the last.
-- Colors = the trail's colour stops (more than one = a gradient). Speed = +run speed while equipped (0.10 = +10%).
----------------------------------------------------------------
Config.Trails = {
	{ Id = "White", Label = "White Trail", Price = 25000, Speed = 0.03, Colors = { Color3.fromRGB(255, 255, 255) }, Glow = 0.4 },
	{ Id = "Blue", Label = "Blue Trail", Price = 2.5e6, Speed = 0.06, Colors = { Color3.fromRGB(80, 170, 255), Color3.fromRGB(160, 220, 255) }, Glow = 0.6 },
	{ Id = "Pink", Label = "Bubblegum Trail", Price = 2.5e8, Speed = 0.10, Colors = { Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 200, 235) }, Glow = 0.6 },
	{ Id = "Toxic", Label = "Toxic Trail", Price = 2.5e10, Speed = 0.14, Colors = { Color3.fromRGB(140, 255, 60), Color3.fromRGB(40, 160, 40) }, Glow = 0.8 },
	{ Id = "Golden", Label = "Golden Trail", Price = 2.5e12, Speed = 0.19, Colors = { Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 190, 40), Color3.fromRGB(255, 240, 150) }, Glow = 0.9 },
	{ Id = "Fire", Label = "Fire Trail", Price = 2.5e14, Speed = 0.25, Colors = { Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 130, 30), Color3.fromRGB(220, 30, 30) }, Glow = 1 },
	{ Id = "Rainbow", Label = "Rainbow Trail", Price = 2.5e16, Speed = 0.32, Colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 240, 60), Color3.fromRGB(70, 230, 90), Color3.fromRGB(60, 160, 255), Color3.fromRGB(170, 90, 255) }, Glow = 1 },
	{ Id = "Galaxy", Label = "Galaxy Trail", Price = 2.5e18, Speed = 0.40, Colors = { Color3.fromRGB(40, 20, 90), Color3.fromRGB(140, 80, 255), Color3.fromRGB(255, 150, 240), Color3.fromRGB(120, 220, 255) }, Glow = 1 },
	{ Id = "Glitched", Label = "Glitched Trail", Price = 2.5e20, Speed = 0.50, Colors = { Color3.fromRGB(255, 40, 255), Color3.fromRGB(20, 20, 30), Color3.fromRGB(60, 255, 255), Color3.fromRGB(20, 20, 30), Color3.fromRGB(255, 40, 255) }, Glow = 1 },
	{ Id = "Void", Label = "Void Trail", Price = 2.5e22, Speed = 0.62, Colors = { Color3.fromRGB(10, 0, 20), Color3.fromRGB(120, 0, 200), Color3.fromRGB(10, 0, 20) }, Glow = 0.7 },
}
Config.TrailById = {}
for _, t in ipairs(Config.Trails) do
	Config.TrailById[t.Id] = t
end
Config.SpeedHardCap = 450 -- absolute top run speed, whatever you stack (keeps physics sane)
Config.LockSeconds = 30 -- 30 seconds (was 30 minutes)
Config.LockGrowth = 1.5 -- every Base Lock you buy makes your next one 50% pricier
function Config.LockPrice(buys) -- buys = how many Base Locks this player has bought before
	return math.floor(Config.LockCost * Config.LockGrowth ^ (buys or 0))
end
Config.SuperLockSeconds = 300
-- (Config.CashPackMin removed along with the Cash Pack product)
-- DONATION THANK-YOUS: the message gets more excited the more someone has donated in TOTAL (not just this purchase).
-- Checked top-down, first match wins - keep the biggest Min at the top.
Config.DonationThankYou = {
	{ Min = 1000, Text = "🌟 LEGENDARY SUPPORTER! %s has now donated R$%d in total - you're incredible!! 🌟" },
	{ Min = 200, Text = "💎 WOW! %s has donated R$%d in total - amazing generosity!! 💎" },
	{ Min = 50, Text = "🎉 Thank you so much, %s! R$%d donated in total - you're awesome!" },
	{ Min = 10, Text = "💖 Thanks for the support, %s! (R$%d total)" },
	{ Min = 0, Text = "Thank you for donating, %s!" },
}
Config.EventEvery = 480 -- seconds between Mutation Hours
Config.EventLength = 90
Config.EventMutations = { "Galaxy", "Chocolate", "Toxic" } -- each Mutation Hour picks ONE of these
Config.EventMutationBoost = 60 -- how much likelier the picked event mutation gets during its Mutation Hour
Config.PerkLuck = 1.15 -- Galaxy perk: luck x1.15
Config.PerkSpeed = 1.08 -- Chocolate perk: run speed x1.08
Config.PerkCarry = 1 -- Toxic perk: +1 carry
Config.TeleportCooldown = 3

Config.StartCash = 100
-- TUTORIAL: after the 4 steps (or if the player skips) they spin a wheel and win a FREE GOOBER of a random rarity.
-- (Pets are never free: players buy those at the egg stage.) Weight = how likely (bigger = more often). Edit freely.
Config.WheelSpinSeconds = 6 -- how long the wheel spins before the egg opens
Config.WheelGooberZone = 1 -- the free goober comes from this zone (its roster has every rarity)
Config.TutorialWheel = {
	{ Rarity = "Common", Weight = 45 },
	{ Rarity = "Rare", Weight = 30 },
	{ Rarity = "Epic", Weight = 17 },
	{ Rarity = "Legendary", Weight = 7 },
	{ Rarity = "Mythic", Weight = 1 },
}

-- PLAYER vs PLAYER (only on the runway - the plaza and bases are always safe)
Config.PvpMargin = 8 -- studs past the runway start where PvP begins
Config.WackRange = 11
-- DEATH HINTS: only bosses can actually kill you. After enough deaths, a helpful tip pops up so new players
-- aren't left guessing why they keep losing their Goobers.
Config.DeathHints = {
	[3] = "Tip: press Q to drop your Goober BEFORE a boss catches you - it can't hurt you once you've let go!",
	[5] = "Tip: a Shield Potion from Gus's shop makes you immune to bosses (and wackers and traps too)!",
	[8] = "Tip: run for a glowing safe zone gate when a boss starts hunting you - it can't follow you in!",
	[12] = "Tip: only the boss in the SAME zone as your egg can catch you - it gives up once you drop it or reach the plaza!",
}
function Config.HintForDeaths(count)
	local hint = Config.DeathHints[count]
	if hint then
		return hint
	end
	if count > 12 and count % 8 == 0 then
		return Config.DeathHints[12]
	end
	return nil
end
Config.WackCooldown = 1.6
Config.WackStun = 2.5
Config.WaveSpawnAhead = { 500, 1800 } -- a flood starts this many studs ahead of the front-most player (so you always see it coming)
Config.WaveOscFreq = 1.1 -- how fast a "side to side" wave (the Wacky Wave) swings across the runway, in radians/sec
Config.TrapStun = 4
Config.TrapLife = 45
Config.MaxTraps = 20 -- traps a player can hold
Config.MaxActiveTraps = 3 -- traps a player can have on the floor
Config.TrapPackSize = 3
Config.TrapMinX = 25 -- traps can't be placed within this many studs of the runway start

-- TRADING unlocks after this many seconds of total play time (900 = 15 minutes)
Config.TradeUnlockSeconds = 900
Config.TradeMaxItems = 4

-- Plaza layout. The runway entrance (z from -90 to 90) is kept completely clear.
Config.ShopX = 34
Config.Market = {
	-- every stall stands with its BACK against the plaza's east wall (x = WallX) and its front facing the players (west)
	WallX = 69,
	X = 56,
	StandX = 58, -- Speed and Capacity stands
	GusX = 54, -- Gus's shop (a bit deeper)
	PetX = 52, -- the pet stage
	SpeedZ = -108, -- Speed stand: left of the entrance
	CapacityZ = 108, -- Capacity stand: right of the entrance
	GusZ = -152, -- Gus's Gadget Shop
	PetZ = 184, -- Pet stage: one long row of eggs, Common -> best
	BoardX = 66, -- leaderboards hang on the east wall (north end)
	BoardZ = { -185, -213, -241 },
	GroupX = 58, -- Group Reward booth: right of the entrance (positive Z, like Capacity), back to the east wall
	GroupZ = 224,
}

-- Leaderboards (need "Enable Studio Access to API Services" in Game Settings > Security)
Config.Leaderboards = { Version = "v1", Refresh = 60, Size = 10 }

----------------------------------------------------------------
-- ZONES
----------------------------------------------------------------
Config.Zones = {
	{ Name = "Grass Zone", Length = 300, Decor = "tree", Color = Color3.fromRGB(110, 215, 110), Color2 = Color3.fromRGB(140, 235, 130), Ground = Color3.fromRGB(100, 190, 110), Accent = Color3.fromRGB(255, 120, 190) },
	{ Name = "Lava Zone", Length = 360, Decor = "lava", Color = Color3.fromRGB(95, 62, 62), Color2 = Color3.fromRGB(120, 78, 72), Ground = Color3.fromRGB(50, 38, 40), Accent = Color3.fromRGB(255, 150, 50) },
	{ Name = "Candy Zone", Length = 420, Decor = "candy", Color = Color3.fromRGB(255, 190, 215), Color2 = Color3.fromRGB(255, 226, 238), Ground = Color3.fromRGB(255, 170, 200), Accent = Color3.fromRGB(255, 90, 150) },
	{ Name = "Cyber Zone", Length = 400, Decor = "cyber", Color = Color3.fromRGB(35, 35, 62), Color2 = Color3.fromRGB(52, 52, 88), Ground = Color3.fromRGB(15, 15, 32), Accent = Color3.fromRGB(255, 50, 200) },
	{ Name = "Jungle Zone", Length = 480, Decor = "palm", Color = Color3.fromRGB(60, 170, 80), Color2 = Color3.fromRGB(88, 200, 96), Ground = Color3.fromRGB(35, 110, 55), Accent = Color3.fromRGB(255, 210, 50) },
	{ Name = "Toy Zone", Length = 460, Decor = "block", Color = Color3.fromRGB(255, 232, 110), Color2 = Color3.fromRGB(120, 200, 255), Ground = Color3.fromRGB(255, 140, 140), Accent = Color3.fromRGB(255, 80, 80) },
	{ Name = "Mushroom Forest", Length = 540, Decor = "mushroom", Color = Color3.fromRGB(150, 100, 200), Color2 = Color3.fromRGB(186, 140, 230), Ground = Color3.fromRGB(60, 36, 92), Accent = Color3.fromRGB(255, 120, 220) },
	{ Name = "Steam City", Length = 520, Decor = "gear", Color = Color3.fromRGB(150, 104, 70), Color2 = Color3.fromRGB(182, 132, 92), Ground = Color3.fromRGB(58, 42, 30), Accent = Color3.fromRGB(255, 170, 60) },
	{ Name = "Crystal Cavern", Length = 600, Decor = "gem", Color = Color3.fromRGB(80, 56, 140), Color2 = Color3.fromRGB(116, 84, 176), Ground = Color3.fromRGB(26, 18, 54), Accent = Color3.fromRGB(200, 120, 255) },
	{ Name = "Cosmic Void", Length = 580, Decor = "star", Color = Color3.fromRGB(28, 22, 64), Color2 = Color3.fromRGB(46, 36, 96), Ground = Color3.fromRGB(8, 6, 24), Accent = Color3.fromRGB(255, 255, 150) },
	{ Name = "Neon City", Length = 660, Decor = "neon", Color = Color3.fromRGB(36, 30, 70), Color2 = Color3.fromRGB(56, 46, 104), Ground = Color3.fromRGB(14, 10, 34), Accent = Color3.fromRGB(255, 60, 200) },
	{ Name = "Jungle Ruins", Length = 640, Decor = "ruins", Color = Color3.fromRGB(80, 120, 70), Color2 = Color3.fromRGB(110, 150, 90), Ground = Color3.fromRGB(36, 60, 34), Accent = Color3.fromRGB(255, 220, 80) },
	{ Name = "Dragon Peak", Length = 720, Decor = "spire", Color = Color3.fromRGB(70, 50, 50), Color2 = Color3.fromRGB(100, 70, 60), Ground = Color3.fromRGB(34, 24, 24), Accent = Color3.fromRGB(255, 110, 40) },
	{ Name = "Dimension Rift", Length = 760, Decor = "rift", Color = Color3.fromRGB(60, 20, 100), Color2 = Color3.fromRGB(90, 40, 140), Ground = Color3.fromRGB(20, 8, 40), Accent = Color3.fromRGB(255, 90, 255) },
}

Config.ZoneCount = #Config.Zones
-- zones have different lengths: this is where each one starts (x) and where the runway ends
Config.ZoneStarts = {}
do
	local x = Config.RunwayStart
	for i, z in ipairs(Config.Zones) do
		Config.ZoneStarts[i] = x
		x += z.Length
	end
	Config.RunwayEnd = x
end
-- SAFE GAPS: alcoves in the side walls. Floods only cover the runway itself, so anyone standing inside a gap is safe.
Config.ShelterWidth = 34 -- how long each safe spot is (along the runway)
Config.ShelterDepth = 24 -- how far into the wall it goes
Config.ShelterEvery = 220 -- one safe spot for every 220 studs of a zone (at least 1 per zone)
Config.FreeShelterZones = { 2, 6, 11 } -- these zones get ONE safe spot that is free for everybody. All the others are VIP only.
Config.Shelters = {}
do
	local n = 0
	for z, zone in ipairs(Config.Zones) do
		local x0, L = Config.ZoneStarts[z], zone.Length
		local count = math.max(1, math.floor(L / Config.ShelterEvery))
		for i = 1, count do
			n += 1
			table.insert(Config.Shelters, { X = x0 + L * (i - 0.5) / count, Side = (n % 2 == 0) and 1 or -1, Free = i == 1 and table.find(Config.FreeShelterZones, z) ~= nil })
		end
	end
end
----------------------------------------------------------------
-- BOSSES: every zone has one big boss (a "!" over its head). It sleeps until a player picks up a Goober FROM ITS ZONE - then that boss,
-- and only that boss, hunts that player all the way to the plaza entrance. Drop the Goober and it lets go. If it catches you, you die and
-- lose what you carry. Bosses get bigger and faster with every zone. Change the numbers here - nothing else needs to be touched.
--   Speed / Aggro / Stun are worked out from the Tuning table (zone 1 = the base value, +PerZone for each zone after).
--   BossOverrides[zone] can change ANY field of that one boss (Name, Style, Color, Speed, Size, Aggro, Stun, SendBack...).
--   Style = one of Config.Styles.  Custom 3D model: put a Model called exactly the boss's Name in ReplicatedStorage > BossModels.
----------------------------------------------------------------
Config.BossesEnabled = true
Config.BossTuning = {
	SpeedBase = 12, SpeedPerZone = 6, -- studs per second: zone 1 = 12 (slower than you), zone 14 = 90 (needs a maxed-out runner)
	Zone2PlusBoost = 3, -- zones 2 onward are a little faster than that on top (zone 1 stays exactly as it was - it's the intro)
	Zone3PlusScale = 0.04, Zone3PlusFlat = 4, -- zones 3+: another +4% per zone past 2, +4 flat (zone 14 ~ 142): you need Speed + pets + a trail
	CatchUpDistance = 70, CatchUpBehind = 45, CatchUpCooldown = 4, -- a hunting boss left far behind jumps back to 45 studs behind you (no drop-and-regrab exploit)
	SizeBase = 11, SizePerZone = 1, -- body size in studs
	Cooldown = 3.5, -- (kept for old settings)
}
Config.BossOverrides = {
	[1] = { Name = "Grumbo", Style = "blob", Color = Color3.fromRGB(110, 200, 90) },
	[2] = { Name = "Magma Maw", Style = "dragon", Color = Color3.fromRGB(255, 110, 50) },
	[3] = { Name = "Sugar Smasher", Style = "cupcake", Color = Color3.fromRGB(255, 140, 190) },
	[4] = { Name = "Byte Brute", Style = "robot", Color = Color3.fromRGB(90, 200, 255) },
	[5] = { Name = "Coco Crusher", Style = "bear", Color = Color3.fromRGB(150, 100, 60) },
	[6] = { Name = "Blockhead", Style = "cube", Color = Color3.fromRGB(255, 200, 60) },
	[7] = { Name = "Spore King", Style = "mushroom", Color = Color3.fromRGB(200, 80, 160) },
	[8] = { Name = "Cog Colossus", Style = "robot", Color = Color3.fromRGB(190, 140, 90) },
	[9] = { Name = "Crystal Crusher", Style = "tower", Color = Color3.fromRGB(170, 110, 255) },
	[10] = { Name = "Star Devourer", Style = "ufo", Color = Color3.fromRGB(255, 240, 150) },
	[11] = { Name = "Neon Nightmare", Style = "ghost", Color = Color3.fromRGB(60, 255, 200) },
	[12] = { Name = "Ruin Raider", Style = "imp", Color = Color3.fromRGB(200, 170, 90) },
	[13] = { Name = "Spire Serpent", Style = "dragon", Color = Color3.fromRGB(110, 200, 255) },
	[14] = { Name = "Rift Overlord", Style = "king", Color = Color3.fromRGB(255, 60, 90) },
}
function Config.BossFor(z)
	local t = Config.BossTuning
	local o = Config.BossOverrides[z] or {}
	local k = z - 1
	local boss = {
		Name = "Boss " .. z,
		Style = "dragon",
		Color = Config.Zones[z].Accent,
		Speed = (t.SpeedBase + k * t.SpeedPerZone + (z >= 2 and t.Zone2PlusBoost or 0)) * (z >= 3 and (1 + (z - 2) * t.Zone3PlusScale) or 1) + (z >= 3 and t.Zone3PlusFlat or 0),
		Size = t.SizeBase + k * t.SizePerZone,
		Cooldown = t.Cooldown,
	}
	for key, v in pairs(o) do
		boss[key] = v
	end
	return boss
end

----------------------------------------------------------------
-- COLOURS OF THE WORLD. Every zone has its own sky: when a player runs into a new zone the lighting fades to that zone's look
-- (Config.SkyFade seconds). The plaza (where you start) has its own calm daytime look, and every zone's walls take the zone's colour.
-- A zone's sky is worked out from its own colours. To hand-tune one, add it to Config.ZoneSkyTweaks, e.g.
--   [4] = { Clock = 21, Brightness = 1.4, Atmo = Color3.fromRGB(...), Decay = Color3.fromRGB(...), Tint = Color3.fromRGB(...), Haze = 1 }
----------------------------------------------------------------
Config.SkyFade = 2.5
Config.PlazaSky = {
	Clock = 14.2, Brightness = 2, Exposure = 0,
	Ambient = Color3.fromRGB(128, 138, 172), Outdoor = Color3.fromRGB(150, 160, 195),
	Atmo = Color3.fromRGB(170, 200, 248), Decay = Color3.fromRGB(240, 195, 215),
	Haze = 0.6, Density = 0.3, Tint = Color3.fromRGB(255, 248, 250), Saturation = 0.22, Bloom = 0.22, -- a touch more candy colour + glow
}
Config.PlazaWallColor = Color3.fromRGB(150, 158, 236)
Config.ZoneClock = { 13.5, 17.6, 12, 22, 11, 14.5, 19.8, 16.5, 21, 23.5, 22.5, 10, 18, 0.8 } -- time of day in each zone (0-24)
Config.ZoneSkyTweaks = {}
function Config.SkyFor(z)
	if not z or z < 1 then
		return Config.PlazaSky
	end
	local zn = Config.Zones[z]
	local tw = Config.ZoneSkyTweaks[z] or {}
	local white, dark = Color3.new(1, 1, 1), Color3.fromRGB(28, 26, 52)
	local clock = tw.Clock or Config.ZoneClock[z] or 14
	local night = clock >= 20 or clock <= 5
	local atmo = tw.Atmo or zn.Color2:Lerp(white, 0.35)
	return {
		Clock = clock,
		Brightness = tw.Brightness or (night and 1.3 or 2),
		Exposure = night and 0.15 or 0,
		Ambient = tw.Ambient or atmo:Lerp(dark, night and 0.45 or 0.55),
		Outdoor = tw.Outdoor or atmo:Lerp(dark, night and 0.35 or 0.4),
		Atmo = atmo,
		Decay = tw.Decay or zn.Accent:Lerp(zn.Color, 0.35),
		Haze = tw.Haze or (night and 1.4 or 0.8),
		Density = tw.Density or 0.32,
		Tint = tw.Tint or white:Lerp(zn.Accent, 0.12),
		Saturation = tw.Saturation or 0.24,
		Bloom = night and 0.34 or 0.22,
	}
end
function Config.WallColorFor(z) -- z = 0 -> the plaza
	if not z or z < 1 then
		return Config.PlazaWallColor
	end
	return Config.Zones[z].Color:Lerp(Color3.new(0, 0, 0), 0.12)
end

-- which zone is this x position in? (0 = still in the plaza)
function Config.ZoneAtX(x)
	if x < Config.RunwayStart then
		return 0
	end
	for i = Config.ZoneCount, 1, -1 do
		if x >= Config.ZoneStarts[i] then
			return i
		end
	end
	return 0
end
function Config.PickupsForZone(z)
	return math.max(8, math.floor(Config.Zones[z].Length / 20))
end

----------------------------------------------------------------
-- RARITIES + MUTATIONS
----------------------------------------------------------------
Config.Rarities = {
	Common = { Rank = 1, Color = Color3.fromRGB(215, 215, 215) },
	Rare = { Rank = 2, Color = Color3.fromRGB(80, 150, 255) },
	Epic = { Rank = 3, Color = Color3.fromRGB(175, 90, 255) },
	Legendary = { Rank = 4, Color = Color3.fromRGB(255, 175, 40) },
	Mythic = { Rank = 5, Color = Color3.fromRGB(255, 70, 70) },
	Secret = { Rank = 6, Color = Color3.fromRGB(255, 100, 225) },
}

Config.MutationList = { "Normal", "Golden", "Neon", "Glitched", "Galaxy", "Chocolate", "Toxic" }
Config.Mutations = {
	Normal = { Mult = 1, Weight = 85, Color = nil, Material = nil },
	Golden = { Mult = 2, Weight = 10, Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Metal },
	Neon = { Mult = 5, Weight = 4, Color = Color3.fromRGB(60, 255, 255), Material = Enum.Material.Neon },
	Glitched = { Mult = 10, Weight = 1, Color = Color3.fromRGB(255, 40, 255), Material = Enum.Material.Neon },
	-- EVENT mutations: very rare normally, MUCH more common during a Mutation Hour that picks them. Each gives its owner a real
	-- perk while at least one Goober with it is placed in their base (see Config.MutationPerks).
	Galaxy = { Mult = 12, Weight = 0.1, Color = Color3.fromRGB(110, 70, 230), Material = Enum.Material.Neon, Event = true, Perk = "Luck", PerkText = "+15% Luck (better Lucky Box odds)" },
	Chocolate = { Mult = 6, Weight = 0.1, Color = Color3.fromRGB(120, 70, 40), Material = Enum.Material.SmoothPlastic, Event = true, Perk = "Speed", PerkText = "+8% run speed" },
	Toxic = { Mult = 8, Weight = 0.1, Color = Color3.fromRGB(140, 255, 60), Material = Enum.Material.Neon, Event = true, Perk = "Carry", PerkText = "+1 Carry Capacity" },
}

----------------------------------------------------------------
-- CREATURE STYLES (shared by Goobers and Pets). Each style is a list of body parts the builder adds.
----------------------------------------------------------------
Config.Styles = {
	blob = {},
	-- Shape = body shape: "egg" (taller), "wide" (squashed), "tall" (tower). Everything else is a ball.
	cat = { Ears = "point", Whiskers = true, Tail = true },
	bunny = { Ears = "long", Tail = true },
	bear = { Ears = "round", Belly = true },
	penguin = { Belly = true, Beak = true, Flippers = true, Shape = "egg" },
	bird = { Beak = true, Wings = true, Tail = true, Shape = "egg" },
	robot = { Boxy = true, Antenna = true, Visor = true },
	dragon = { Horns = true, Wings = true, Spikes = true, Tail = true },
	imp = { Horns = true, Tail = true },
	alien = { Antennae = true },
	fish = { Fins = true, Tail = true, Shape = "wide" },
	unicorn = { Horn = true, Ears = "point" },
	ghost = { Ghost = true, Shape = "tall" },
	crab = { Claws = true, Antennae = true, Shape = "wide" },
	snowman = { Nose = true, HatTop = true, Shape = "tall" },
	sprout = { Sprout = true },
	cupcake = { Frosting = true },
	jelly = { Tentacles = true, Shape = "wide" },
	cloud = { Puffs = true, Shape = "wide" },
	angel = { Wings = true, Halo = true },
	cactus = { Arms = true, Sprout = true, Shape = "tall" },
	king = { Crown = true, Ears = "round", Belly = true },
	mushroom = { Cap = true },
	egg = { Shape = "egg", Beak = true, Wings = true },
	slime = { Shape = "wide", Sprout = true },
	tower = { Shape = "tall", Ears = "round", Belly = true },
	cube = { Boxy = true, Ears = "round" },
	ufo = { Shape = "wide", Antennae = true, Halo = true },
}

-- Goober size by rarity (rarer = bigger). Each Goober also gets a small size variation so they are not all the same.
Config.RarityScale = { Common = 0.85, Rare = 1.0, Epic = 1.15, Legendary = 1.3, Mythic = 1.5, Secret = 1.75 }

----------------------------------------------------------------
-- THE GOOBERS  (Income = $ per second, Weight = spawn chance in its zone)
-- Zone = 0 means it never spawns on the runway (codes / special only).
----------------------------------------------------------------
Config.Goobers = {
	-- Zone 1: Grass
	{ Id = "Blobbo", Rarity = "Common", Income = 1, Zone = 1, Weight = 50, Style = "slime", Color = Color3.fromRGB(120, 220, 100) },
	{ Id = "Sprouty", Rarity = "Common", Income = 2, Zone = 1, Weight = 50, Style = "sprout", Color = Color3.fromRGB(180, 240, 90) },
	{ Id = "Bean Bounce", Rarity = "Rare", Income = 6, Zone = 1, Weight = 28, Style = "bunny", Color = Color3.fromRGB(80, 150, 255) },
	{ Id = "Mossy Moe", Rarity = "Epic", Income = 20, Zone = 1, Weight = 14, Style = "bear", Color = Color3.fromRGB(150, 90, 230) },
	-- Zone 2: Lava
	{ Id = "Emberoo", Rarity = "Common", Income = 60, Zone = 2, Weight = 50, Style = "bunny", Color = Color3.fromRGB(255, 130, 60) },
	{ Id = "Cinder Sam", Rarity = "Rare", Income = 180, Zone = 2, Weight = 28, Style = "cat", Color = Color3.fromRGB(255, 90, 60) },
	{ Id = "Lava Lou", Rarity = "Epic", Income = 600, Zone = 2, Weight = 14, Style = "imp", Color = Color3.fromRGB(200, 60, 120) },
	{ Id = "Volcano Vic", Rarity = "Legendary", Income = 2000, Zone = 2, Weight = 5, Style = "dragon", Color = Color3.fromRGB(255, 160, 20) },
	{ Id = "Molten Max", Rarity = "Mythic", Income = 8000, Zone = 2, Weight = 1.5, Style = "dragon", Color = Color3.fromRGB(255, 50, 50) },
	-- Zone 3: Candy
	{ Id = "Gummy Gary", Rarity = "Common", Income = 1500, Zone = 3, Weight = 50, Style = "bear", Color = Color3.fromRGB(255, 120, 150) },
	{ Id = "Lolli Lea", Rarity = "Rare", Income = 4000, Zone = 3, Weight = 28, Style = "cat", Color = Color3.fromRGB(255, 170, 220) },
	{ Id = "Cupcake Cal", Rarity = "Epic", Income = 14000, Zone = 3, Weight = 14, Style = "cupcake", Color = Color3.fromRGB(200, 140, 255) },
	{ Id = "Sundae Sue", Rarity = "Legendary", Income = 50000, Zone = 3, Weight = 5, Style = "cupcake", Color = Color3.fromRGB(255, 200, 120) },
	{ Id = "Choco Chad", Rarity = "Mythic", Income = 200000, Zone = 3, Weight = 1.5, Style = "bear", Color = Color3.fromRGB(110, 60, 40) },
	-- Zone 4: Cyber
	{ Id = "Pixel Pete", Rarity = "Common", Income = 35000, Zone = 4, Weight = 50, Style = "robot", Color = Color3.fromRGB(90, 255, 180) },
	{ Id = "Glitch Gina", Rarity = "Rare", Income = 100000, Zone = 4, Weight = 28, Style = "alien", Color = Color3.fromRGB(255, 70, 200) },
	{ Id = "Robo Rex", Rarity = "Epic", Income = 350000, Zone = 4, Weight = 14, Style = "robot", Color = Color3.fromRGB(150, 160, 190) },
	{ Id = "Hologram Hank", Rarity = "Legendary", Income = 1200000, Zone = 4, Weight = 5, Style = "ghost", Color = Color3.fromRGB(80, 255, 255) },
	{ Id = "Mecha Mia", Rarity = "Mythic", Income = 5000000, Zone = 4, Weight = 1.5, Style = "robot", Color = Color3.fromRGB(255, 60, 90) },
	-- Zone 5: Jungle
	{ Id = "Vine Vic", Rarity = "Common", Income = 600000, Zone = 5, Weight = 50, Style = "sprout", Color = Color3.fromRGB(90, 200, 90) },
	{ Id = "Toucan Tom", Rarity = "Rare", Income = 2000000, Zone = 5, Weight = 28, Style = "bird", Color = Color3.fromRGB(255, 160, 40) },
	{ Id = "Parrot Pia", Rarity = "Epic", Income = 7000000, Zone = 5, Weight = 14, Style = "bird", Color = Color3.fromRGB(255, 70, 90) },
	{ Id = "Jaguar Jax", Rarity = "Legendary", Income = 25000000, Zone = 5, Weight = 5, Style = "cat", Color = Color3.fromRGB(255, 200, 60) },
	{ Id = "Tiki Tank", Rarity = "Mythic", Income = 100000000, Zone = 5, Weight = 1.5, Style = "bear", Color = Color3.fromRGB(150, 90, 50) },
	-- Zone 6: Toy
	{ Id = "Block Buddy", Rarity = "Common", Income = 10000000, Zone = 6, Weight = 50, Style = "robot", Color = Color3.fromRGB(255, 90, 90) },
	{ Id = "Yoyo Yan", Rarity = "Rare", Income = 35000000, Zone = 6, Weight = 28, Style = "egg", Color = Color3.fromRGB(90, 160, 255) },
	{ Id = "Robo Toy Ray", Rarity = "Epic", Income = 120000000, Zone = 6, Weight = 14, Style = "robot", Color = Color3.fromRGB(180, 190, 210) },
	{ Id = "Kite Kai", Rarity = "Legendary", Income = 450000000, Zone = 6, Weight = 5, Style = "bird", Color = Color3.fromRGB(255, 220, 60) },
	{ Id = "Teddy Titan", Rarity = "Mythic", Income = 1800000000, Zone = 6, Weight = 1.5, Style = "bear", Color = Color3.fromRGB(200, 140, 90) },
	-- Zone 7: Mushroom Forest
	{ Id = "Shroomy Sam", Rarity = "Common", Income = 150000000, Zone = 7, Weight = 50, Style = "mushroom", Color = Color3.fromRGB(230, 90, 110) },
	{ Id = "Fungi Fay", Rarity = "Rare", Income = 500000000, Zone = 7, Weight = 28, Style = "mushroom", Color = Color3.fromRGB(190, 130, 240) },
	{ Id = "Spore Spike", Rarity = "Epic", Income = 1600000000, Zone = 7, Weight = 14, Style = "alien", Color = Color3.fromRGB(150, 230, 120) },
	{ Id = "Glow Gia", Rarity = "Legendary", Income = 6000000000, Zone = 7, Weight = 5, Style = "unicorn", Color = Color3.fromRGB(120, 255, 220) },
	{ Id = "Amanita King", Rarity = "Mythic", Income = 25000000000, Zone = 7, Weight = 1.5, Style = "dragon", Color = Color3.fromRGB(255, 70, 90) },
	-- Zone 8: Steam City
	{ Id = "Gear Gus", Rarity = "Common", Income = 1700000000, Zone = 8, Weight = 50, Style = "robot", Color = Color3.fromRGB(190, 140, 90) },
	{ Id = "Piston Pete", Rarity = "Rare", Income = 6000000000, Zone = 8, Weight = 28, Style = "cube", Color = Color3.fromRGB(170, 120, 80) },
	{ Id = "Copper Cleo", Rarity = "Epic", Income = 20000000000, Zone = 8, Weight = 14, Style = "robot", Color = Color3.fromRGB(230, 140, 90) },
	{ Id = "Zeppelin Zed", Rarity = "Legendary", Income = 70000000000, Zone = 8, Weight = 5, Style = "ufo", Color = Color3.fromRGB(230, 200, 160) },
	{ Id = "Steam Titan", Rarity = "Mythic", Income = 280000000000, Zone = 8, Weight = 1.5, Style = "dragon", Color = Color3.fromRGB(200, 120, 60) },
	-- Zone 9: Crystal Cavern
	{ Id = "Gem Gil", Rarity = "Common", Income = 20000000000, Zone = 9, Weight = 50, Style = "cube", Color = Color3.fromRGB(140, 100, 220) },
	{ Id = "Quartz Quinn", Rarity = "Rare", Income = 70000000000, Zone = 9, Weight = 28, Style = "unicorn", Color = Color3.fromRGB(240, 230, 255) },
	{ Id = "Amethyst Amy", Rarity = "Epic", Income = 250000000000, Zone = 9, Weight = 14, Style = "tower", Color = Color3.fromRGB(190, 110, 250) },
	{ Id = "Prism Pax", Rarity = "Legendary", Income = 900000000000, Zone = 9, Weight = 5, Style = "angel", Color = Color3.fromRGB(200, 240, 255) },
	{ Id = "Diamond Dex", Rarity = "Mythic", Income = 3500000000000, Zone = 9, Weight = 1.5, Style = "dragon", Color = Color3.fromRGB(150, 230, 255) },
	-- Zone 10: Cosmic Void
	{ Id = "Star Sam", Rarity = "Common", Income = 250000000000, Zone = 10, Weight = 50, Style = "tower", Color = Color3.fromRGB(255, 240, 140) },
	{ Id = "Moon Mia", Rarity = "Rare", Income = 900000000000, Zone = 10, Weight = 28, Style = "ufo", Color = Color3.fromRGB(210, 215, 240) },
	{ Id = "Galaxy Gil", Rarity = "Epic", Income = 3000000000000, Zone = 10, Weight = 14, Style = "alien", Color = Color3.fromRGB(140, 110, 255) },
	{ Id = "Black Hole Hal", Rarity = "Legendary", Income = 11000000000000, Zone = 10, Weight = 5, Style = "ghost", Color = Color3.fromRGB(40, 30, 90) },
	{ Id = "Universe Uma", Rarity = "Mythic", Income = 40000000000000, Zone = 10, Weight = 1.5, Style = "angel", Color = Color3.fromRGB(255, 190, 255) },
	-- Zone 11: Neon City
	{ Id = "Neon Ned", Rarity = "Common", Income = 3e12, Zone = 11, Weight = 50, Style = "cube", Color = Color3.fromRGB(255, 80, 210) },
	{ Id = "Laser Lou", Rarity = "Rare", Income = 1e13, Zone = 11, Weight = 28, Style = "alien", Color = Color3.fromRGB(80, 255, 255) },
	{ Id = "Synth Sia", Rarity = "Epic", Income = 4e13, Zone = 11, Weight = 14, Style = "cat", Color = Color3.fromRGB(190, 90, 255) },
	{ Id = "Disco Dax", Rarity = "Legendary", Income = 1.4e14, Zone = 11, Weight = 5, Style = "ufo", Color = Color3.fromRGB(255, 220, 90) },
	{ Id = "Hologram Hal", Rarity = "Mythic", Income = 5e14, Zone = 11, Weight = 1.5, Style = "ghost", Color = Color3.fromRGB(120, 255, 230) },
	-- Zone 12: Jungle Ruins
	{ Id = "Moss Mo", Rarity = "Common", Income = 3.5e13, Zone = 12, Weight = 50, Style = "slime", Color = Color3.fromRGB(110, 200, 90) },
	{ Id = "Vine Vin", Rarity = "Rare", Income = 1.2e14, Zone = 12, Weight = 28, Style = "sprout", Color = Color3.fromRGB(80, 190, 100) },
	{ Id = "Idol Ida", Rarity = "Epic", Income = 5e14, Zone = 12, Weight = 14, Style = "tower", Color = Color3.fromRGB(200, 180, 110) },
	{ Id = "Panther Pax", Rarity = "Legendary", Income = 1.8e15, Zone = 12, Weight = 5, Style = "cat", Color = Color3.fromRGB(255, 190, 60) },
	{ Id = "Temple Tom", Rarity = "Mythic", Income = 6e15, Zone = 12, Weight = 1.5, Style = "king", Color = Color3.fromRGB(120, 220, 130) },
	-- Zone 13: Dragon Peak
	{ Id = "Ashling Ash", Rarity = "Common", Income = 4e14, Zone = 13, Weight = 50, Style = "imp", Color = Color3.fromRGB(180, 110, 90) },
	{ Id = "Magma Mia", Rarity = "Rare", Income = 1.4e15, Zone = 13, Weight = 28, Style = "slime", Color = Color3.fromRGB(255, 130, 50) },
	{ Id = "Drake Dan", Rarity = "Epic", Income = 6e15, Zone = 13, Weight = 14, Style = "dragon", Color = Color3.fromRGB(230, 90, 60) },
	{ Id = "Wyrm Wyn", Rarity = "Legendary", Income = 2.2e16, Zone = 13, Weight = 5, Style = "dragon", Color = Color3.fromRGB(255, 170, 60) },
	{ Id = "Inferno Ike", Rarity = "Mythic", Income = 8e16, Zone = 13, Weight = 1.5, Style = "dragon", Color = Color3.fromRGB(255, 70, 30) },
	-- Zone 14: Dimension Rift
	{ Id = "Rift Ray", Rarity = "Common", Income = 5e15, Zone = 14, Weight = 50, Style = "egg", Color = Color3.fromRGB(190, 120, 255) },
	{ Id = "Warp Wes", Rarity = "Rare", Income = 1.8e16, Zone = 14, Weight = 28, Style = "ufo", Color = Color3.fromRGB(255, 120, 255) },
	{ Id = "Portal Pia", Rarity = "Epic", Income = 8e16, Zone = 14, Weight = 14, Style = "alien", Color = Color3.fromRGB(120, 255, 190) },
	{ Id = "Void Vex", Rarity = "Legendary", Income = 2.8e17, Zone = 14, Weight = 5, Style = "ghost", Color = Color3.fromRGB(90, 60, 160) },
	{ Id = "Paradox Pax", Rarity = "Mythic", Income = 1e18, Zone = 14, Weight = 1.5, Style = "unicorn", Color = Color3.fromRGB(255, 160, 255) },
	{ Id = "Goober God", Rarity = "Secret", Income = 1e18, Zone = 14, Weight = 0.1, Style = "king", Color = Color3.fromRGB(255, 255, 255) },
	-- Special (never spawns on the runway)
	{ Id = "King Goldie", Rarity = "Secret", Income = 40000, Zone = 0, Weight = 0, Style = "king", Color = Color3.fromRGB(255, 215, 70) },
	{ Id = "OG Goober", Rarity = "Rare", Income = 40, Zone = 0, Weight = 0, Style = "blob", Color = Color3.fromRGB(255, 150, 40) },
}

Config.GooberById = {}
for _, g in ipairs(Config.Goobers) do
	Config.GooberById[g.Id] = g
end

----------------------------------------------------------------
-- UPGRADES (bought with cash)
----------------------------------------------------------------
Config.Upgrades = {
	Speed = { Label = "Speed", Desc = "Run faster", Base = 150, Growth = 1.65 }, -- Max is set below from Config.MaxWalkSpeed
	Carry = { Label = "Capacity", Desc = "Carry +1 Goober at once", Base = 400, Growth = 3.5 }, -- limit comes from Rebirths
	Slots = { Label = "Base Slots", Desc = "+1 pedestal in your base", Max = 46, Base = 2500, Growth = 1.65 }, -- (was 800 x1.4) limit also comes from Rebirths (Config.SlotsMaxLevel)
	Floors = { Label = "Base Floors", Desc = "Build a new floor (+10 slots)", Max = 4, Base = 250000, Growth = 12 }, -- (was 25K x6.5)
	Luck = { Label = "Luck", Desc = "Chance a Goober you grab turns MUTATED (+ better Lucky Boxes)", Max = 30, Base = 10000, Growth = 2.25 }, -- limit comes from Rebirths (Config.LuckMaxLevel)
}
-- Speed and Capacity are bought at the physical stands in the plaza, so they are not in the shop window.
Config.UpgradeOrder = { "Slots", "Floors", "Luck" }

function Config.UpgradeCost(name, level)
	local u = Config.Upgrades[name]
	return math.floor(u.Base * u.Growth ^ level)
end

function Config.RebirthCost(rebirths)
	return math.floor(250000 * 6 ^ rebirths)
end

----------------------------------------------------------------
-- OFFLINE EARNINGS: while you're away, your Goobers keep earning at a reduced rate, up to a daily cap.
----------------------------------------------------------------
Config.OfflineEarnRate = 0.5 -- 50% of your normal income rate while offline
Config.OfflineEarnMaxSeconds = 86400 -- capped at 24 hours worth

function Config.Multiplier(rebirths)
	return 1 + 0.25 * rebirths
end

-- +2 speed per level for the first 30 levels, then +1 per level forever.
-- MaxWalkSpeed is the fastest anyone can ever run (speed upgrades, VIP, pets and potions all stop here).
-- It is set so the LAST boss (about 90 studs/s) can only be outrun by a fully upgraded player. Lower = harder.
Config.MaxWalkSpeed = 150 -- the base top speed
Config.MaxWalkSpeedPerRebirth = 20 -- every rebirth raises the ceiling further (on top of the base) - rebirthing is what makes you FASTER long-term
function Config.WalkSpeed(speedLvl, vip)
	local s = 16 + math.min(speedLvl, 30) * 2 + math.max(0, speedLvl - 30) + (vip and Config.VIP.SpeedBonus or 0)
	return math.min(s, Config.MaxWalkSpeed)
end
-- the speed upgrade stops at the level where you reach the top speed (no point selling levels that do nothing)
function Config.MaxSpeedLevel()
	for lvl = 0, 1000 do
		if Config.WalkSpeed(lvl, false) >= Config.MaxWalkSpeed then
			return lvl
		end
	end
	return 1000
end
Config.Upgrades.Speed.Max = Config.MaxSpeedLevel()
function Config.RebirthSpeedLevel(rebirths) -- the Speed Level needed for your NEXT rebirth - climbs each time, capping at the true max (that's "beating" Rebirth until the next update)
	return math.min(Config.Upgrades.Speed.Max, 30 + rebirths * 12)
end
Config.Upgrades.Speed.Desc = "Run faster - up to the top speed"

-- Capacity levels you can reach: 3 to start (carry 4). Every Rebirth unlocks 2 more levels.
function Config.CarryMaxLevel(rebirths)
	return 3 + (rebirths or 0) * 2
end

-- LUCK: every level gives a chance that a normal Goober you grab turns into a random mutation.
-- Level 1 = 1%, rising slowly (the curve is steep at the end) up to 50% at level 30. More levels unlock with Rebirths.
-- BASE SLOTS need Rebirths too: 6 slot upgrades to start (10 slots = one full floor), +8 per Rebirth (all 50 after 5 Rebirths)
function Config.SlotsMaxLevel(rebirths)
	return math.min(Config.Upgrades.Slots.Max, 6 + (rebirths or 0) * 8)
end
function Config.LuckMaxLevel(rebirths)
	return math.min(Config.Upgrades.Luck.Max, 5 + (rebirths or 0) * 5) -- 5 levels to start, +5 per Rebirth (level 30 needs 5 Rebirths)
end
Config.LuckChanceCap = 0.5
function Config.LuckMutateChance(luckLvl, luckMult)
	if not luckLvl or luckLvl <= 0 then
		return 0
	end
	local k = (math.min(luckLvl, Config.Upgrades.Luck.Max) - 1) / (Config.Upgrades.Luck.Max - 1)
	return math.min(Config.LuckChanceCap, (0.01 + 0.49 * k * k) * (luckMult or 1))
end
-- which mutation a lucky grab becomes (never Normal); the current Mutation Hour's mutation is much likelier
function Config.RollLuckyMutation(eventMut)
	local total, weights = 0, {}
	for _, name in ipairs(Config.MutationList) do
		if name ~= "Normal" then
			local w = Config.Mutations[name].Weight * (name == eventMut and Config.EventMutationBoost or 1)
			weights[name] = w
			total += w
		end
	end
	local r = math.random() * total
	for _, name in ipairs(Config.MutationList) do
		if weights[name] then
			r -= weights[name]
			if r <= 0 then
				return name
			end
		end
	end
	return "Golden"
end

function Config.CarryCap(carryLvl)
	return 1 + carryLvl
end

-- slots unlocked = 4 + Slots upgrades, but never more than the floors you built can hold
function Config.MaxSlots(slotLvl, floorLvl)
	return math.min(4 + slotLvl, Config.SlotsPerFloor * (1 + (floorLvl or 0)))
end

----------------------------------------------------------------
-- PETS: follow you around and give buffs. You can only hold 2 at first - more slots cost Robux.
-- Cash / Speed = bonus (0.05 = +5%). Pets are hatched from eggs at the Pet Stand.
----------------------------------------------------------------
Config.PetSlotsFree = 2
Config.MaxPetSlots = 6
function Config.PetSlots(bought)
	return math.min(Config.PetSlotsFree + (bought or 0), Config.MaxPetSlots)
end
-- You start with 2 slots. Slot 3 and slot 4 are bought with CASH (in the Pets window), slots 5 and 6 with Robux.
Config.PetSlotCash = { 1e9, 1e13 } -- slot 3 costs $1B, slot 4 costs $10T
-- INDEX (the collection book): every new Goober / pet you own for the first time is written into it. Every `Every` discoveries the
-- index pays cash, and each payout is bigger than the last (5 found, 10 found, 15 found ...).
Config.Index = {
	GooberReward = { Common = 200, Rare = 800, Epic = 3000, Legendary = 12000, Mythic = 50000, Secret = 250000 }, -- paid ONCE, the instant you discover a new Goober
	PetReward = { Common = 500, Rare = 3000, Epic = 15000, Legendary = 80000, Mythic = 400000, Secret = 2000000 }, -- paid ONCE, the instant you discover a new Pet
}
Config.PetBoxMax = 300 -- how many pets fit in the Pet Storage (pets that don't fit in your slots go here instead of being sold)
Config.PetCashCap = 3 -- pets can never add more than +300% cash in total (so nobody gets rich too fast)
-- Magnet filter helpers (shared by the shop window and the tests): flip a rarity on/off, but never let the list become empty.
function Config.ToggleRankSet(set, rank)
	local count = 0
	for _, on in pairs(set) do
		if on then
			count += 1
		end
	end
	if set[rank] and count <= 1 then
		return false
	end
	set[rank] = not set[rank]
	return true
end
function Config.RankSetCsv(set)
	local ranks = {}
	for rank, on in pairs(set) do
		if on then
			table.insert(ranks, rank)
		end
	end
	table.sort(ranks)
	return table.concat(ranks, ",")
end
function Config.PetSlotCost(slotNumber) -- cash price of that slot number, or nil when it costs Robux
	return Config.PetSlotCash[slotNumber - Config.PetSlotsFree]
end
-- GRIND: every Goober earns less than the numbers in the list below say, so getting rich takes real grinding.
-- Change Config.IncomeScale (1 = the full listed incomes, 0.2 = very slow).
Config.IncomeScale = 0.4
for _, g in ipairs(Config.Goobers) do
	g.Income = math.max(1, math.floor(g.Income * Config.IncomeScale + 0.5))
end

Config.Pets = { -- 5 eggs x 5 pets. Every pet lives in exactly ONE egg. An egg's first 3 pets have the PREVIOUS egg's rarity (but stronger), its last 2 have a NEW rarity.
	{ Id = "Pip", Rarity = "Common", Style = "bird", Color = Color3.fromRGB(255, 230, 114), Cash = 0.021, Speed = 0.005 },
	{ Id = "Sprout", Rarity = "Common", Style = "fish", Color = Color3.fromRGB(148, 255, 89), Cash = 0.025, Speed = 0.006 },
	{ Id = "Bloop", Rarity = "Common", Style = "sprout", Color = Color3.fromRGB(63, 255, 152), Cash = 0.03, Speed = 0.007 },
	{ Id = "Buttons", Rarity = "Rare", Style = "cactus", Color = Color3.fromRGB(114, 214, 255), Cash = 0.045, Speed = 0.011 },
	{ Id = "Noodle", Rarity = "Rare", Style = "tower", Color = Color3.fromRGB(107, 89, 255), Cash = 0.06, Speed = 0.015 },
	{ Id = "Whiskers", Rarity = "Rare", Style = "bunny", Color = Color3.fromRGB(245, 114, 255), Cash = 0.063, Speed = 0.016 },
	{ Id = "Dot", Rarity = "Rare", Style = "dragon", Color = Color3.fromRGB(255, 89, 130), Cash = 0.076, Speed = 0.019 },
	{ Id = "Mochi", Rarity = "Rare", Style = "ghost", Color = Color3.fromRGB(255, 173, 63), Cash = 0.09, Speed = 0.022 },
	{ Id = "Pebble", Rarity = "Epic", Style = "jelly", Color = Color3.fromRGB(199, 255, 114), Cash = 0.135, Speed = 0.034 },
	{ Id = "Waffles", Rarity = "Epic", Style = "mushroom", Color = Color3.fromRGB(89, 255, 125), Cash = 0.18, Speed = 0.045 },
	{ Id = "Zippy", Rarity = "Epic", Style = "ufo", Color = Color3.fromRGB(114, 249, 255), Cash = 0.189, Speed = 0.047 },
	{ Id = "Nibbles", Rarity = "Epic", Style = "penguin", Color = Color3.fromRGB(89, 111, 255), Cash = 0.23, Speed = 0.058 },
	{ Id = "Truffle", Rarity = "Epic", Style = "alien", Color = Color3.fromRGB(194, 63, 255), Cash = 0.27, Speed = 0.068 },
	{ Id = "Peanut", Rarity = "Legendary", Style = "snowman", Color = Color3.fromRGB(255, 114, 183), Cash = 0.405, Speed = 0.101 },
	{ Id = "Biscuit", Rarity = "Legendary", Style = "angel", Color = Color3.fromRGB(255, 143, 89), Cash = 0.54, Speed = 0.135 },
	{ Id = "Griffin", Rarity = "Legendary", Style = "slime", Color = Color3.fromRGB(233, 255, 114), Cash = 0.56, Speed = 0.14 },
	{ Id = "Kraken", Rarity = "Legendary", Style = "cat", Color = Color3.fromRGB(93, 255, 89), Cash = 0.68, Speed = 0.17 },
	{ Id = "Hydra", Rarity = "Legendary", Style = "robot", Color = Color3.fromRGB(63, 255, 215), Cash = 0.8, Speed = 0.2 },
	{ Id = "Chimera", Rarity = "Mythic", Style = "unicorn", Color = Color3.fromRGB(114, 168, 255), Cash = 1.2, Speed = 0.3 },
	{ Id = "Phoenix", Rarity = "Mythic", Style = "cupcake", Color = Color3.fromRGB(162, 89, 255), Cash = 1.6, Speed = 0.4 },
	{ Id = "Nova", Rarity = "Mythic", Style = "king", Color = Color3.fromRGB(255, 114, 218), Cash = 1.68, Speed = 0.42 },
	{ Id = "Eclipse", Rarity = "Mythic", Style = "cube", Color = Color3.fromRGB(255, 103, 89), Cash = 2.04, Speed = 0.51 },
	{ Id = "Zenith", Rarity = "Mythic", Style = "bear", Color = Color3.fromRGB(255, 237, 63), Cash = 2.4, Speed = 0.6 },
	{ Id = "Paradox", Rarity = "Secret", Style = "imp", Color = Color3.fromRGB(152, 255, 114), Cash = 3.6, Speed = 0.9 },
	{ Id = "Infinity", Rarity = "Secret", Style = "crab", Color = Color3.fromRGB(89, 255, 180), Cash = 4.8, Speed = 1.2 },
}
Config.PetById = {}
for _, p in ipairs(Config.Pets) do
	Config.PetById[p.Id] = p
end

-- Eggs: cash opens 1. Robux (Product3) opens 3 at once. If you don't have room for all 3 the extras are sold for cash.
-- Create the 4 Developer Products in Creator Hub and paste their ids into Product3.Id.
-- EGGS. Each egg lists every pet it can hatch and its EXACT chance in percent (each Pool adds up to 100).
-- What the egg window shows is exactly what the server rolls.
Config.Eggs = {
	{ Id = "Common", Label = "Common Egg", Pattern = "spots", Tiers = { Previous = "Common", New = "Rare" }, Price = 2000, Color = Color3.fromRGB(205, 205, 220), Product3 = { Id = 3714073360, Price = 25 },
		Pool = { { "Pip", 38 }, { "Sprout", 28 }, { "Bloop", 20 }, { "Buttons", 11 }, { "Noodle", 3 } } },
	{ Id = "Rare", Label = "Rare Egg", Pattern = "stripes", Tiers = { Previous = "Rare", New = "Epic" }, Price = 25000, Color = Color3.fromRGB(80, 150, 255), Product3 = { Id = 3714073351, Price = 49 },
		Pool = { { "Whiskers", 38 }, { "Dot", 28 }, { "Mochi", 20 }, { "Pebble", 11 }, { "Waffles", 3 } } },
	{ Id = "Epic", Label = "Epic Egg", Pattern = "stars", Tiers = { Previous = "Epic", New = "Legendary" }, Price = 300000, Color = Color3.fromRGB(175, 90, 255), Product3 = { Id = 3714073329, Price = 99 },
		Pool = { { "Zippy", 38 }, { "Nibbles", 28 }, { "Truffle", 20 }, { "Peanut", 11 }, { "Biscuit", 3 } } },
	{ Id = "Legendary", Label = "Legendary Egg", Pattern = "crown", Tiers = { Previous = "Legendary", New = "Mythic" }, Price = 4000000, Color = Color3.fromRGB(255, 175, 40), Product3 = { Id = 3714073313, Price = 149 },
		Pool = { { "Griffin", 38 }, { "Kraken", 28 }, { "Hydra", 20 }, { "Chimera", 11 }, { "Phoenix", 3 } } },
	{ Id = "Mythical", Label = "Mythical Egg", Pattern = "halo", Tiers = { Previous = "Mythic", New = "Secret" }, Price = 60000000, Color = Color3.fromRGB(255, 70, 70), Product3 = { Id = 3714073281, Price = 249 },
		Pool = { { "Nova", 38 }, { "Eclipse", 28 }, { "Zenith", 20 }, { "Paradox", 11 }, { "Infinity", 3 } } },
}
Config.EggById = {}
for _, e in ipairs(Config.Eggs) do
	Config.EggById[e.Id] = e
end
Config.PetEgg = {} -- pet id -> the egg it comes from
for _, e in ipairs(Config.Eggs) do
	for _, p in ipairs(e.Pool) do
		Config.PetEgg[p[1]] = e.Id
	end
end
Config.PetSell = { Common = 5000, Rare = 40000, Epic = 400000, Legendary = 5000000, Mythic = 60000000, Secret = 2000000000 } -- cash for pets that don't fit

-- DAILY LOGIN REWARDS (7-day streak; miss a day and it starts over). Day 7 = the ultra rare King Goldie.
Config.DayLength = 86400 -- seconds in a "day" (lower it to test the rewards in Studio)
Config.DailyRewards = {
	{ Cash = 5000 },
	{ Traps = 3 },
	{ Cash = 50000 },
	{ Goober = "Lava Lou", Mutation = "Golden" },
	{ Cash = 500000 },
	{ Goober = "Jaguar Jax", Mutation = "Golden" },
	{ Goober = "King Goldie", Mutation = "Normal" }, -- the ultra rare King Goldie
}
-- WEEK-OVER-WEEK GROWTH: every 7-day streak you fully complete makes the NEXT week's rewards better - more cash,
-- and the reward Goobers come with a stronger mutation. Week 0 = the numbers above, exactly as written.
Config.DailyWeekCashGrowth = 1.35 -- +35% cash per completed week (compounding)
Config.DailyWeekTrapGrowth = 1 -- +1 extra trap for every this-many completed weeks
function Config.DailyRewardScale(week) -- the cash multiplier for a given completed-week count
	return Config.DailyWeekCashGrowth ^ math.max(0, week)
end
function Config.DailyMutationForWeek(week) -- Golden -> Neon -> Glitched as the weeks add up
	if week >= 2 then
		return "Glitched"
	elseif week >= 1 then
		return "Neon"
	end
	return "Golden"
end

----------------------------------------------------------------
-- NPC SHOP (Gus's Gadget Shop) - bought with cash
----------------------------------------------------------------
Config.MaxPotionStack = 3600 -- potions stack, but never more than this many seconds in total
Config.ShopPriceGrowth = 1.3 -- every time you buy an item its price goes up (per item: Growth)
Config.ShopItems = {
	{ Id = "Wacker", Label = "The Wacker", Desc = "Whack players on the runway. They drop their Goobers!", Price = 100000, Symbol = "WHAM", Color = Color3.fromRGB(255, 110, 190) },
	{ Id = "Trap", Label = "Bear Traps x3", Desc = "Press T on the runway. Stuck players drop their Goobers!", Price = 25000, Growth = 1.35, Symbol = "SNAP", Color = Color3.fromRGB(255, 90, 90) },
	{ Id = "Speed", Label = "Speed Potion", Desc = "+50% run speed. Buy more to stack the time!", Price = 50000, Duration = 60, Growth = 1.3, Symbol = ">>", Color = Color3.fromRGB(70, 210, 255) },
	{ Id = "Jump", Label = "Jump Potion", Desc = "Super jump. Buy more to stack the time!", Price = 45000, Duration = 60, Growth = 1.3, Symbol = "UP", Color = Color3.fromRGB(120, 255, 130) },
	{ Id = "Shield", Label = "Shield Potion", Desc = "Immune to wackers and traps. Stacks!", Price = 70000, Duration = 45, Growth = 1.3, Symbol = "SAFE", Color = Color3.fromRGB(255, 220, 70) },
	{ Id = "Cash", Label = "Cash Potion", Desc = "Double income. Buy more to stack the time!", Price = 150000, Duration = 90, Growth = 1.35, Symbol = "2x", Color = Color3.fromRGB(90, 230, 120) },
	{ Id = "Magnet", Label = "Magnet Potion", Desc = "Pulls only the rarities you pick. Stacks!", Price = 90000, Duration = 60, Growth = 1.3, Filter = true, Symbol = "MAG", Color = Color3.fromRGB(190, 120, 255) },
	{ Id = "Guard", Label = "Flood Guard", Desc = "Floods can't hurt you for 30s. Does NOT stack.", Price = 200000, Duration = 30, Stackable = false, Growth = 1.45, Symbol = "WAVE", Color = Color3.fromRGB(80, 150, 255) },
}

----------------------------------------------------------------
-- SOUNDS. Leave "" to use the built-in fallback sound, or paste a Roblox
-- audio id like "rbxassetid://1234567890" (find free ones in Toolbox > Audio).
-- MusicIds: a playlist of calm songs. If it's empty a built-in calm generative soundtrack plays
-- (soft chimes with reverb that changes mood every minute or so).
----------------------------------------------------------------
Config.Sounds = {
	MusicIds = {}, -- add 3+ Roblox audio ids here (e.g. "rbxassetid://1234567890") for a shuffled playlist of real songs
	MusicVolume = 0.9, -- (was 0.45: the music was drowned out by the sound effects)
	MusicSwitchSeconds = 90, -- how often the music changes to a new song / mood
	SfxVolume = 0.5,
	Horn = "", -- the blaring flood horn
	Pop = "", Grab = "", Deposit = "", Sell = "", Buy = "", Error = "", Click = "",
	Trap = "", Wack = "", Stuck = "", Reveal = "", Whoosh = "", Alarm = "", -- Alarm: warns you a boss woke up
}

----------------------------------------------------------------
-- 3D MODELS (optional). Want your OWN 3D model for a Goober, pet or boss? Put a Model (or MeshPart) in ReplicatedStorage inside a
-- folder named below, and give it EXACTLY the same name as the Goober / pet / boss. The game uses it instead of the built-in shape
-- (scaled to size; its FRONT should face -Z, the "forward" of a Roblox part). Mutations recolour it. Nothing else to change.
--   ReplicatedStorage > GooberModels > Blobbo      (a Goober called "Blobbo")
--   ReplicatedStorage > PetModels    > Pip
--   ReplicatedStorage > BossModels   > Grumbo
Config.CustomModels = { Goobers = "GooberModels", Pets = "PetModels", Bosses = "BossModels" }
Config.Icons3D = true -- true = Goober / pet pictures in menus are real 3D models (spin-free viewports). false = the flat drawn ones.

-- IMAGES (optional). Upload images to Roblox (Creator Hub > Assets > Decals),
-- then paste the id here as "rbxassetid://123". Goober images show on UI cards.
----------------------------------------------------------------
Config.Images = {
	Logo = "",
	Goober = {
		-- ["Blobbo"] = "rbxassetid://0",
	},
	-- Pictures for the shop cards (Gus's shop + the Robux shop). Leave empty to use the drawn ones. Ids you can use:
	-- Wacker, Trap, Speed, Jump, Shield, Cash, Magnet, Guard, Thief, DoubleCash, VIP, LuckyBox, SuperLock, PetSlot
	Shop = {
		-- ["Wacker"] = "rbxassetid://0",
	},
}

----------------------------------------------------------------
-- ROBUX LIST: every game pass + developer product in one list (used by the Studio checklist)
function Config.RobuxItems()
	local list = {}
	for key, p in pairs(Config.GamePasses) do
		table.insert(list, { Kind = "Game Pass", Key = key, Name = p.Label, Price = p.Price, Id = p.Id, Desc = p.Desc })
	end
	for key, p in pairs(Config.Products) do
		table.insert(list, { Kind = "Developer Product", Key = key, Name = p.Label, Price = p.Price, Id = p.Id, Desc = p.Desc })
	end
	for _, e in ipairs(Config.Eggs) do
		table.insert(list, { Kind = "Developer Product", Key = "Egg3_" .. e.Id, Name = e.Label .. " x3", Price = e.Product3.Price, Id = e.Product3.Id, Desc = "Opens 3 " .. e.Label .. "s at once" })
	end
	table.sort(list, function(a, b)
		if a.Kind ~= b.Kind then
			return a.Kind < b.Kind
		end
		return a.Key < b.Key
	end)
	return list
end
function Config.RobuxReport()
	local lines, missing = {}, 0
	for _, it in ipairs(Config.RobuxItems()) do
		if it.Id == 0 then
			missing += 1
		end
		table.insert(lines, ("%-17s %-20s R$%-5d %s"):format(it.Kind, it.Name, it.Price, it.Id == 0 and "<-- Id NOT SET" or ("Id " .. it.Id)))
	end
	return lines, missing
end

-- SHARED HELPERS
----------------------------------------------------------------
local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Config.Money(n) -- "$1.5T"
	return "$" .. Config.Format(n)
end
function Config.Format(n)
	n = math.floor(n or 0)
	if n < 1000 then
		return tostring(n)
	end
	if n >= 1e36 then -- past the named suffixes: short scientific form, e.g. "4.2e51"
		if n == math.huge then
			return "INFINITE"
		end
		return (string.format("%.2e", n):gsub("%.?0+e", "e"):gsub("e%+", "e"))
	end
	local idx = math.min(math.floor(math.log10(n) / 3), #suffixes - 1)
	local v = n / 10 ^ (idx * 3)
	if string.format("%.2f", v) == "1000.00" and idx < #suffixes - 1 then
		idx += 1
		v = n / 10 ^ (idx * 3)
	end
	local s = string.format("%.2f", v)
	s = s:gsub("%.?0+$", "")
	return s .. suffixes[idx + 1]
end

-- Picks a Goober from a zone. Luck makes rarer ones more likely.
function Config.RollGoober(zone, luckLvl)
	luckLvl = luckLvl or 0
	local pool, total = {}, 0
	for _, g in ipairs(Config.Goobers) do
		if g.Zone == zone then
			local w = g.Weight * (1 + luckLvl * 0.15 * (Config.Rarities[g.Rarity].Rank - 1))
			total += w
			table.insert(pool, { g, w })
		end
	end
	local r = math.random() * total
	for _, e in ipairs(pool) do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return pool[#pool][1]
end

function Config.RollMutation(boost, eventMut) -- eventMut = the event mutation the current Mutation Hour picked (or nil)
	boost = boost or 1
	local weights, total = {}, 0
	for _, name in ipairs(Config.MutationList) do
		local w = Config.Mutations[name].Weight
		if name == eventMut then
			w *= Config.EventMutationBoost
		elseif name ~= "Normal" then
			w *= boost
		end
		weights[name] = w
		total += w
	end
	local r = math.random() * total
	for _, name in ipairs(Config.MutationList) do
		r -= weights[name]
		if r <= 0 then
			return name
		end
	end
	return "Normal"
end

function Config.ThankYouFor(name, total) -- picks the right escalating thank-you line for this donor's lifetime total
	for _, tier in ipairs(Config.DonationThankYou) do
		if total >= tier.Min then
			return tier.Text:format(name, total)
		end
	end
	return "Thank you for donating!"
end

function Config.RollLuckyGoober(luckLvl, premium, luckMult) -- the Lucky Box: ALWAYS a Legendary or Mythic Goober
	luckLvl = luckLvl or 0
	local mythicBias = premium and 0.85 or 0.4 -- the Robux Lucky Box has much better odds at a Mythic
	-- luck only boosts the MYTHIC weights (boosting every entry equally would cancel out and do nothing)
	local luck = (1 + math.min(luckLvl, 30) * 0.05) * (luckMult or 1) -- (same max boost as before: x2.5 at the top level)
	local pool, total = {}, 0
	for _, g in ipairs(Config.Goobers) do
		if g.Rarity == "Legendary" or g.Rarity == "Mythic" then
			local bias = (g.Rarity == "Mythic") and mythicBias * luck or 1
			local w = g.Weight * bias
			total += w
			table.insert(pool, { g, w })
		end
	end
	local r = math.random() * total
	for _, e in ipairs(pool) do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return pool[#pool][1]
end

-- Event-mutation perks from the Goobers placed in a base. Returns { Luck = mult, Speed = mult, Carry = bonus, Names = { "Galaxy", ... } }
function Config.MutationPerks(placed, maxSlots)
	local have = {}
	for s, item in ipairs(placed or {}) do
		if maxSlots and s > maxSlots then
			break
		end
		local def = type(item) == "table" and Config.Mutations[item.Mut]
		if def and def.Perk then
			have[def.Perk] = item.Mut
		end
	end
	local names = {}
	for _, name in ipairs(Config.EventMutations) do
		if have[Config.Mutations[name].Perk] then
			table.insert(names, name)
		end
	end
	return {
		Luck = have.Luck and Config.PerkLuck or 1,
		Speed = have.Speed and Config.PerkSpeed or 1,
		Carry = have.Carry and Config.PerkCarry or 0,
		Names = names,
	}
end

return Config
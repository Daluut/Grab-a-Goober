--!nocheck
-- Boots the real Config + Creatures + GameServer inside mock.luau, joins a player, and pushes Robux receipts through.
local HERE = "/tmp/claude-0/-home-user-Grab-a-Goober/98851ced-a0ab-5fe5-90f2-eebea07ec1fc/scratchpad/harness/"
local REPO = "/home/user/Grab-a-Goober/"
local function readfile(p)
	local f = assert(io and io.open or nil, "no io")
end
local E = loadstring(SRC_MOCK, "mock")()
local env = setmetatable({}, { __index = function(_, k)
	local v = E[k]
	if v ~= nil then
		return v
	end
	return _G[k]
end })
for k, v in pairs(E) do
	env[k] = v
end
local RS = E.__service("ReplicatedStorage")
local modules = {}
local function addModule(name, src)
	local m = E.__inst("ModuleScript")
	m.Name = name
	m.Parent = RS
	modules[m] = { src = src }
end
env.require = function(m)
	local rec = modules[m]
	if not rec.value then
		local f = assert(loadstring(rec.src, m.Name))
		setfenv(f, env)
		rec.value = f()
	end
	return rec.value
end
addModule("Config", SRC_CONFIG)
addModule("Creatures", SRC_CREATURES)
env.script = E.__inst("Script")
env.script.Parent = E.__service("ServerScriptService")

local server = assert(loadstring(SRC_SERVER, "GameServer"))
setfenv(server, env)
local co = coroutine.create(server)
local ok, err = coroutine.resume(co)
if not ok then
	print("SERVER LOAD ERROR:", err)
	print(debug.traceback(co))
end
E.__STEP(3)
print("---- after boot: status", coroutine.status(co), "errors:", #E.__shared.ERRORS)
for _, e in ipairs(E.__shared.ERRORS) do
	print("ERR", e)
end

-- a player joins
local Players = E.__service("Players")
local plr = E.__inst("Player")
plr.Name = "Donor"
plr.DisplayName = "Donor"
plr.UserId = 4242
plr.AccountAge = 100
plr.MembershipType = E.Enum.MembershipType.None
plr.Parent = Players
table.insert(E.__players, plr)
E.__shared.spawnCharacter = function(p)
	local char = E.__inst("Model")
	char.Name = p.Name
	local hrp = E.__inst("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Parent = char
	for _, n in ipairs({ "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local x = E.__inst("Part")
		x.Name = n
		x.Parent = char
	end
	local hum = E.__inst("Humanoid")
	hum.Parent = char
	hum.RootPart = hrp
	char.PrimaryPart = hrp
	char.Parent = E.workspace
	p.Character = char
	p.CharacterAdded:Fire(char)
end
Players.PlayerAdded:Fire(plr)
E.__STEP(1)
E.__shared.spawnCharacter(plr)
E.__STEP(5)
print("---- after join: errors:", #E.__shared.ERRORS, " cash attr:", plr:GetAttribute("Cash"))
for _, e in ipairs(E.__shared.ERRORS) do
	print("ERR", e)
end

-- a donation receipt
local MPS = E.__service("MarketplaceService")
local Config = env.require(RS.Config)
local n0 = #E.__shared.LOG
local result
local rco = coroutine.create(function()
	result = MPS.ProcessReceipt({ PlayerId = 4242, ProductId = Config.Products.Donate50.Id, CurrencySpent = 50, PurchaseId = "p1", PlaceIdWherePurchased = 1 })
end)
local ok2, e2 = coroutine.resume(rco)
if not ok2 then
	print("RECEIPT ERROR:", e2)
end
E.__STEP(3)
print("---- donation result:", result)
for i = n0 + 1, #E.__shared.LOG do
	local l = E.__shared.LOG[i]
	if l:find("Notify") or l:find("Announce") or l:find("ROBUX") or l:find("Donat") or l:find("LB_") or l:find("UI") or l:find("WARN") then
		print("  LOG", l:sub(1, 220))
	end
end
print("---- errors total:", #E.__shared.ERRORS)
for _, e in ipairs(E.__shared.ERRORS) do
	print("ERR", e:sub(1, 600))
end

-- ===== extra scenarios =====
local function receipt(uid, pid, spent)
	local r
	local c = coroutine.create(function()
		r = MPS.ProcessReceipt({ PlayerId = uid, ProductId = pid, CurrencySpent = spent, PurchaseId = tostring(math.random()), PlaceIdWherePurchased = 1 })
	end)
	coroutine.resume(c)
	E.__STEP(2)
	return r
end
local board = E.__shared.STORES["GAG_LB_Donated_v1"]
print("---- donation where Dashboard price (400) differs from Config price (100):", receipt(4242, Config.Products.Donate100.Id, 400))
print("     board value for Donor:", board.data["4242"])
-- host is the admin in Config.Admins? make our player the host for the command test
plr.UserId = 4242
local Chat = plr.Chatted
local n1 = #E.__shared.LOG
-- offline credit for user 999 (never joined)
Chat:Fire("!donor 999 400")
E.__STEP(3)
print("---- !donor offline -> board 999 =", board.data["999"], " pending credit =", E.__shared.STORES[Config.DataStoreName] and E.__shared.STORES[Config.DataStoreName].data["DonationCredit_999"])
for i = n1 + 1, #E.__shared.LOG do
	local l = E.__shared.LOG[i]
	if l:find("Notify") then
		print("  LOG", l:sub(1, 200))
	end
end
-- user 999 joins: credit applied
local p2 = E.__inst("Player")
p2.Name = "LateDonor"
p2.DisplayName = "LateDonor"
p2.UserId = 999
p2.Parent = Players
table.insert(E.__players, p2)
Players.PlayerAdded:Fire(p2)
E.__STEP(4)
print("---- after LateDonor joins: board 999 =", board.data["999"], " pending credit now =", E.__shared.STORES[Config.DataStoreName].data["DonationCredit_999"])
print("---- errors total:", #E.__shared.ERRORS)
for _, e in ipairs(E.__shared.ERRORS) do
	print("ERR", e:sub(1, 600))
end

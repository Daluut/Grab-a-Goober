--!nocheck
-- Minimal Roblox engine stand-in, enough to boot the Grab a Goober server and push purchases through it.
local SHARED = {}
local LOG = {}
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do
		t[i] = tostring((select(i, ...)))
	end
	table.insert(LOG, table.concat(t, " "))
end
SHARED.LOG = LOG

-- ===== math types =====
local Vector3 = {}
Vector3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return Vector3.new(0, 0, 0)
		end
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return rawget(Vector3, k)
end
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)
local function isV(v)
	return type(v) == "table" and getmetatable(v) == Vector3
end
Vector3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__div = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
Vector3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3.__tostring = function(v)
	return ("%g, %g, %g"):format(v.X, v.Y, v.Z)
end
function Vector3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function Vector3.Cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function Vector3.Lerp(a, b, t)
	return a + (b - a) * t
end
function Vector3.Min(a, b)
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function Vector3.Max(a, b)
	return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function Vector3.Abs(a)
	return Vector3.new(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function Vector3.FuzzyEq(a, b, e)
	return (a - b).Magnitude <= (e or 1e-5)
end

-- CFrame: position p + rotation columns (right r, up u, back b) stored as a 3x3 row-major matrix m
local CFrame = {}
local function mk(px, py, pz, m)
	return setmetatable({ p = Vector3.new(px, py, pz), m = m }, CFrame)
end
local I3 = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
CFrame.__index = function(c, k)
	local m = c.m
	if k == "Position" or k == "p" then
		return rawget(c, "p")
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "LookVector" then
		return Vector3.new(-m[3], -m[6], -m[9])
	elseif k == "RightVector" then
		return Vector3.new(m[1], m[4], m[7])
	elseif k == "UpVector" then
		return Vector3.new(m[2], m[5], m[8])
	elseif k == "Rotation" then
		return mk(0, 0, 0, m)
	end
	return rawget(CFrame, k)
end
local function mmul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function mvec(m, v)
	return Vector3.new(m[1] * v.X + m[2] * v.Y + m[3] * v.Z, m[4] * v.X + m[5] * v.Y + m[6] * v.Z, m[7] * v.X + m[8] * v.Y + m[9] * v.Z)
end
local function mT(m)
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end
function CFrame.new(a, b, c, ...)
	if a == nil then
		return mk(0, 0, 0, I3)
	end
	if isV(a) then
		if isV(b) then
			return CFrame.lookAt(a, b)
		end
		return mk(a.X, a.Y, a.Z, I3)
	end
	local rest = { ... }
	if #rest == 9 then
		return mk(a, b, c, rest)
	end
	return mk(a, b, c, I3)
end
local function rotX(t)
	local c, s = math.cos(t), math.sin(t)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function rotY(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rotZ(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
function CFrame.Angles(x, y, z)
	return mk(0, 0, 0, mmul(mmul(rotX(x or 0), rotY(y or 0)), rotZ(z or 0)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromOrientation(x, y, z)
	return mk(0, 0, 0, mmul(mmul(rotY(y or 0), rotX(x or 0)), rotZ(z or 0)))
end
function CFrame.fromAxisAngle(axis, a)
	return CFrame.Angles(0, a, 0)
end
function CFrame.lookAt(pos, target, up)
	up = up or Vector3.new(0, 1, 0)
	local look = (target - pos)
	if look.Magnitude < 1e-9 then
		return mk(pos.X, pos.Y, pos.Z, I3)
	end
	look = look.Unit
	local back = -look
	local right = up:Cross(back)
	if right.Magnitude < 1e-6 then
		right = Vector3.new(1, 0, 0)
	end
	right = right.Unit
	local u = back:Cross(right).Unit
	return mk(pos.X, pos.Y, pos.Z, { right.X, u.X, back.X, right.Y, u.Y, back.Y, right.Z, u.Z, back.Z })
end
function CFrame.fromMatrix(pos, rx, ry, rz)
	rz = rz or rx:Cross(ry)
	return mk(pos.X, pos.Y, pos.Z, { rx.X, ry.X, rz.X, rx.Y, ry.Y, rz.Y, rx.Z, ry.Z, rz.Z })
end
CFrame.__mul = function(a, b)
	if isV(b) then
		return a.p + mvec(a.m, b)
	end
	local p = a.p + mvec(a.m, b.p)
	return mk(p.X, p.Y, p.Z, mmul(a.m, b.m))
end
CFrame.__add = function(a, v)
	local p = a.p + v
	return mk(p.X, p.Y, p.Z, a.m)
end
CFrame.__sub = function(a, v)
	local p = a.p - v
	return mk(p.X, p.Y, p.Z, a.m)
end
CFrame.__tostring = function(c)
	return "CFrame(" .. tostring(c.p) .. ")"
end
function CFrame.Inverse(c)
	local t = mT(c.m)
	local p = -mvec(t, c.p)
	return mk(p.X, p.Y, p.Z, t)
end
function CFrame.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function CFrame.ToWorldSpace(a, b)
	return a * b
end
function CFrame.PointToWorldSpace(a, v)
	return a * v
end
function CFrame.PointToObjectSpace(a, v)
	return a:Inverse() * v
end
function CFrame.VectorToWorldSpace(a, v)
	return mvec(a.m, v)
end
function CFrame.VectorToObjectSpace(a, v)
	return mvec(mT(a.m), v)
end
function CFrame.Lerp(a, b, t)
	local p = a.p:Lerp(b.p, t)
	return mk(p.X, p.Y, p.Z, t < 0.5 and a.m or b.m)
end
function CFrame.GetComponents(c)
	local m = c.m
	return c.p.X, c.p.Y, c.p.Z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
end
function CFrame.ToEulerAnglesXYZ(c)
	return 0, math.atan2(c.m[3], c.m[1]), 0
end
CFrame.ToOrientation = CFrame.ToEulerAnglesXYZ
CFrame.identity = mk(0, 0, 0, I3)

local Color3 = {}
Color3.__index = Color3
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	local r, g, b
	if i == 0 then
		r, g, b = v, t, p
	elseif i == 1 then
		r, g, b = q, v, p
	elseif i == 2 then
		r, g, b = p, v, t
	elseif i == 3 then
		r, g, b = p, q, v
	elseif i == 4 then
		r, g, b = t, p, v
	else
		r, g, b = v, p, q
	end
	return Color3.new(r, g, b)
end
function Color3.fromHex()
	return Color3.new(1, 1, 1)
end
function Color3.Lerp(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function Color3.ToHSV(c)
	return 0, 0, math.max(c.R, c.G, c.B)
end
Color3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end

local function simple(name, fields)
	local T = {}
	T.__index = T
	T.__tostring = function()
		return name
	end
	T.new = function(...)
		local o = { ... }
		local r = setmetatable({}, T)
		for i, f in ipairs(fields) do
			r[f] = o[i]
		end
		r._args = o
		return r
	end
	return T
end
local UDim = simple("UDim", { "Scale", "Offset" })
local UDim2 = {}
UDim2.__index = UDim2
function UDim2.new(xs, xo, ys, yo)
	return setmetatable({ X = UDim.new(xs or 0, xo or 0), Y = UDim.new(ys or 0, yo or 0), Width = UDim.new(xs or 0, xo or 0), Height = UDim.new(ys or 0, yo or 0) }, UDim2)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
UDim2.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UDim2.__sub = function(a, b)
	return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
local Vector2 = simple("Vector2", { "X", "Y" })
Vector2.zero = Vector2.new(0, 0)
Vector2.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
Vector2.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
Vector2.__mul = function(a, b)
	return type(b) == "number" and Vector2.new(a.X * b, a.Y * b) or Vector2.new(a * b.X, a * b.Y)
end
Vector2.__div = function(a, b)
	return Vector2.new(a.X / b, a.Y / b)
end
local NumberRange = simple("NumberRange", { "Min", "Max" })
local NumberSequence = simple("NumberSequence", { "Keypoints" })
local ColorSequence = simple("ColorSequence", { "Keypoints" })
local NumberSequenceKeypoint = simple("NSK", { "Time", "Value" })
local ColorSequenceKeypoint = simple("CSK", { "Time", "Value" })
local TweenInfo = simple("TweenInfo", { "Time" })
local PhysicalProperties = simple("PhysicalProperties", {})
local Rect = simple("Rect", {})
local Ray = simple("Ray", { "Origin", "Direction" })
local Region3 = simple("Region3", {})
local OverlapParams = simple("OverlapParams", {})
local RaycastParams = simple("RaycastParams", {})
local Font = simple("Font", {})
Font.fromEnum = function()
	return Font.new()
end

-- Enum: any Enum.X.Y works
local EnumItemMT = { __tostring = function(e)
	return "Enum." .. e.EnumType .. "." .. e.Name
end }
local Enum = setmetatable({}, {
	__index = function(t, k)
		local list = setmetatable({}, {
			__index = function(t2, k2)
				local e = setmetatable({ Name = k2, EnumType = k, Value = 0 }, EnumItemMT)
				rawset(t2, k2, e)
				return e
			end,
		})
		list.GetEnumItems = function()
			return {}
		end
		rawset(t, k, list)
		return list
	end,
})

local Random = {}
Random.__index = Random
local seed = 1
function Random.new(s)
	return setmetatable({ s = s or seed }, Random)
end
function Random.NextNumber(self, a, b)
	a, b = a or 0, b or 1
	return a + math.random() * (b - a)
end
function Random.NextInteger(self, a, b)
	return math.random(a, b)
end

-- ===== scheduler =====
local now = 0
local queue = {} -- { at = time, co = coroutine, args }
local function schedule(at, co, ...)
	table.insert(queue, { at = at, co = co, args = table.pack(...) })
end
local errors = {}
SHARED.ERRORS = errors
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(errors, tostring(err) .. "\n" .. debug.traceback(co))
	end
end
local task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	schedule(now, co, ...)
	return co
end
function task.delay(t, f, ...)
	local co = coroutine.create(f)
	schedule(now + (t or 0), co, ...)
	return co
end
function task.wait(t)
	local co = coroutine.running()
	schedule(now + math.max(t or 0.03, 0.03), co)
	coroutine.yield()
	return t or 0.03, now
end
function task.cancel(co)
	for i = #queue, 1, -1 do
		if queue[i].co == co then
			table.remove(queue, i)
		end
	end
end
function task.synchronize() end
function task.desynchronize() end
local function wait(t)
	return task.wait(t)
end
local function delay(t, f)
	return task.delay(t, f)
end
local function spawn(f)
	return task.defer(f)
end

-- ===== signals =====
local Signal = {}
Signal.__index = Signal
local function newSignal(name)
	return setmetatable({ handlers = {}, name = name }, Signal)
end
function Signal:Connect(fn)
	local h = { fn = fn, connected = true }
	table.insert(self.handlers, h)
	return { Disconnect = function()
		h.connected = false
	end, Connected = true }
end
Signal.connect = Signal.Connect
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c.Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Fire(...)
	for _, h in ipairs(self.handlers) do
		if h.connected then
			task.spawn(h.fn, ...)
		end
	end
end
function Signal:Wait()
	local co = coroutine.running()
	local c
	c = self:Connect(function(...)
		c.Disconnect()
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end

-- ===== instances =====
local Instance = {}
local BASEPART = { Part = true, WedgePart = true, MeshPart = true, TrussPart = true, SpawnLocation = true, UnionOperation = true, CornerWedgePart = true, Seat = true }
local GUIOBJ = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true, TextBox = true, ViewportFrame = true, CanvasGroup = true }
local ISA = {
	BasePart = function(c)
		return BASEPART[c]
	end,
	PVInstance = function(c)
		return BASEPART[c] or c == "Model"
	end,
	GuiObject = function(c)
		return GUIOBJ[c]
	end,
	GuiBase2d = function(c)
		return GUIOBJ[c]
	end,
	LayerCollector = function(c)
		return c == "ScreenGui" or c == "BillboardGui" or c == "SurfaceGui"
	end,
	JointInstance = function(c)
		return c == "Weld" or c == "Motor6D" or c == "ManualWeld"
	end,
	Constraint = function(c)
		return c:find("Constraint") ~= nil
	end,
	LuaSourceContainer = function(c)
		return c == "Script" or c == "LocalScript" or c == "ModuleScript"
	end,
	ValueBase = function(c)
		return c:find("Value") ~= nil
	end,
	Clothing = function(c)
		return c == "Shirt" or c == "Pants"
	end,
	Light = function(c)
		return c:find("Light") ~= nil
	end,
	PostEffect = function(c)
		return c:find("Effect") ~= nil
	end,
	Instance = function()
		return true
	end,
}
local EVENTS = {
	Touched = true, TouchEnded = true, Triggered = true, TriggerEnded = true, PromptButtonHoldBegan = true, Activated = true, MouseButton1Click = true,
	MouseButton1Down = true, MouseButton1Up = true, MouseEnter = true, MouseLeave = true, Destroying = true, ChildAdded = true, ChildRemoved = true,
	DescendantAdded = true, DescendantRemoving = true, AncestryChanged = true, Changed = true, OnServerEvent = true, OnClientEvent = true,
	Event = true, Died = true, StateChanged = true, Running = true, HealthChanged = true, CharacterAdded = true, CharacterRemoving = true,
	Chatted = true, Equipped = true, Unequipped = true, FocusLost = true, MoveToFinished = true, Ended = true, Completed = true,
	OnServerInvoke = false, AttributeChanged = true, Seated = true, Jumping = true, Died2 = true, CharacterAppearanceLoaded = true,
	Idled = true, InputBegan = true, DidLoop = true, Played = true, Stopped = true, Loaded = true,
}
local DEFAULTS = {
	BasePart = function(o)
		return { Size = Vector3.new(4, 1, 2), CFrame = CFrame.new(), Anchored = false, CanCollide = true, CanTouch = true, CanQuery = true, Transparency = 0, Reflectance = 0, Color = Color3.new(0.6, 0.6, 0.6), Material = Enum.Material.Plastic, Shape = Enum.PartType.Block, Massless = false, CastShadow = true, AssemblyLinearVelocity = Vector3.new(), Velocity = Vector3.new(), LocalTransparencyModifier = 0, CollisionGroup = "Default", Locked = false, BrickColor = { Name = "Medium stone grey" } }
	end,
	Humanoid = function()
		return { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, UseJumpPower = true, HipHeight = 2, AutoRotate = true, PlatformStand = false, Sit = false, RigType = Enum.HumanoidRigType.R6, DisplayName = "", MoveDirection = Vector3.new(), RootPart = nil, FloorMaterial = Enum.Material.Air }
	end,
	Model = function()
		return { WorldPivot = CFrame.new() }
	end,
	GuiObject = function()
		return { Size = UDim2.new(), Position = UDim2.new(), AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(100, 100), Visible = true, Text = "", TextSize = 14, Rotation = 0, BackgroundTransparency = 0, ZIndex = 1 }
	end,
	Attachment = function()
		return { Position = Vector3.new(), CFrame = CFrame.new(), WorldPosition = Vector3.new() }
	end,
	Sound = function()
		return { Volume = 0.5, IsPlaying = false, TimeLength = 1, PlaybackSpeed = 1, SoundId = "" }
	end,
}
local InstMT = {}
local ALL = {}
local function inst(class, props)
	local o = setmetatable({ __props = {}, __children = {}, __attrs = {}, __signals = {}, __attrSignals = {}, __propSignals = {}, ClassName = class }, InstMT)
	local p = o.__props
	p.Name = class
	p.Archivable = true
	for k, f in pairs(DEFAULTS) do
		if k == class or (ISA[k] and ISA[k](class)) then
			for kk, vv in pairs(f(o)) do
				p[kk] = vv
			end
		end
	end
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	table.insert(ALL, o)
	return o
end
local methods = {}
function methods:IsA(c)
	if self.ClassName == c then
		return true
	end
	local f = ISA[c]
	return f and f(self.ClassName) or false
end
function methods:GetChildren()
	local t = {}
	for _, c in ipairs(self.__children) do
		table.insert(t, c)
	end
	return t
end
function methods:GetDescendants()
	local t = {}
	local function rec(o)
		for _, c in ipairs(o.__children) do
			table.insert(t, c)
			rec(c)
		end
	end
	rec(self)
	return t
end
function methods:FindFirstChild(name, recursive)
	for _, c in ipairs(self.__children) do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(self.__children) do
			local r = c:FindFirstChild(name, true)
			if r then
				return r
			end
		end
	end
	return nil
end
function methods:FindFirstChildOfClass(cn)
	for _, c in ipairs(self.__children) do
		if c.ClassName == cn then
			return c
		end
	end
end
function methods:FindFirstChildWhichIsA(cn, rec)
	for _, c in ipairs(rec and self:GetDescendants() or self.__children) do
		if c:IsA(cn) then
			return c
		end
	end
end
function methods:FindFirstAncestorOfClass(cn)
	local p = self.Parent
	while p do
		if p.ClassName == cn then
			return p
		end
		p = p.Parent
	end
end
function methods:FindFirstAncestorWhichIsA(cn)
	local p = self.Parent
	while p do
		if p:IsA(cn) then
			return p
		end
		p = p.Parent
	end
end
function methods:FindFirstAncestor(n)
	local p = self.Parent
	while p do
		if p.Name == n then
			return p
		end
		p = p.Parent
	end
end
function methods:IsDescendantOf(a)
	local p = self.Parent
	while p do
		if p == a then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods:IsAncestorOf(d)
	return d:IsDescendantOf(self)
end
function methods:WaitForChild(name, t)
	local c = self:FindFirstChild(name)
	if c then
		return c
	end
	for _ = 1, 50 do
		task.wait(0.1)
		c = self:FindFirstChild(name)
		if c then
			return c
		end
	end
	return nil
end
function methods:Destroy()
	if self.__destroyed then
		return
	end
	self.__destroyed = true
	local s = rawget(self, "__signals").Destroying
	if s then
		s:Fire()
	end
	for _, c in ipairs(self:GetChildren()) do
		c:Destroy()
	end
	self.Parent = nil
end
methods.Remove = methods.Destroy
function methods:ClearAllChildren()
	for _, c in ipairs(self:GetChildren()) do
		c:Destroy()
	end
end
function methods:Clone()
	local c = inst(self.ClassName)
	for k, v in pairs(self.__props) do
		if k ~= "Parent" then
			c.__props[k] = v
		end
	end
	for k, v in pairs(self.__attrs) do
		c.__attrs[k] = v
	end
	for _, ch in ipairs(self.__children) do
		ch:Clone().Parent = c
	end
	return c
end
function methods:GetAttribute(k)
	return self.__attrs[k]
end
function methods:GetAttributes()
	return self.__attrs
end
function methods:SetAttribute(k, v)
	self.__attrs[k] = v
	local s = self.__attrSignals[k]
	if s then
		s:Fire()
	end
end
function methods:GetAttributeChangedSignal(k)
	self.__attrSignals[k] = self.__attrSignals[k] or newSignal()
	return self.__attrSignals[k]
end
function methods:GetPropertyChangedSignal(k)
	self.__propSignals[k] = self.__propSignals[k] or newSignal()
	return self.__propSignals[k]
end
function methods:GetFullName()
	return self.Name
end
-- parts / models
function methods:GetPivot()
	if BASEPART[self.ClassName] then
		return self.CFrame
	end
	local pp = self.PrimaryPart
	if pp then
		return pp.CFrame
	end
	return self.WorldPivot
end
function methods:PivotTo(cf)
	local old = self:GetPivot()
	local delta = cf * old:Inverse()
	if BASEPART[self.ClassName] then
		self.CFrame = cf
		return
	end
	for _, d in ipairs(self:GetDescendants()) do
		if BASEPART[d.ClassName] then
			d.CFrame = delta * d.CFrame
		end
	end
	self.WorldPivot = cf
end
function methods:SetPrimaryPartCFrame(cf)
	self:PivotTo(cf)
end
function methods:GetExtentsSize()
	return Vector3.new(4, 4, 4)
end
function methods:GetBoundingBox()
	return self:GetPivot(), Vector3.new(4, 4, 4)
end
function methods:ScaleTo() end
function methods:GetScale()
	return 1
end
function methods:MoveTo() end
function methods:BreakJoints() end
function methods:GetMass()
	return 1
end
function methods:SetNetworkOwner() end
function methods:GetNetworkOwner() end
function methods:ApplyImpulse() end
function methods:GetConnectedParts()
	return {}
end
function methods:GetTouchingParts()
	return {}
end
-- humanoid
function methods:TakeDamage(n)
	self.Health = self.Health - n
end
function methods:ChangeState() end
function methods:SetStateEnabled() end
function methods:GetState()
	return Enum.HumanoidStateType.Running
end
function methods:AddAccessory(a)
	a.Parent = self.Parent
end
function methods:ApplyDescription() end
function methods:GetAppliedDescription()
	return inst("HumanoidDescription")
end
function methods:EquipTool(t)
	t.Parent = self.Parent
end
function methods:UnequipTools() end
function methods:LoadAnimation()
	return { Play = function() end, Stop = function() end, AdjustSpeed = function() end }
end
-- sounds / fx / tweens
function methods:Play() end
function methods:Stop() end
function methods:Pause() end
function methods:Resume() end
function methods:Cancel() end
function methods:Emit() end
function methods:Clear() end
-- remotes
function methods:FireClient(plr, ...)
	log("FireClient", self.Name, plr and plr.Name, ...)
end
function methods:FireAllClients(...)
	log("FireAllClients", self.Name, ...)
end
function methods:Fire(...)
	local s = self.Event
	s:Fire(...)
end
function methods:InvokeClient() end
-- player
function methods:Kick(msg)
	log("Kick", self.Name, msg)
end
function methods:LoadCharacter()
	SHARED.spawnCharacter(self)
end
function methods:GetRankInGroup()
	return 0
end
function methods:IsInGroup()
	return false
end
function methods:GetFriendsOnline()
	return {}
end
function methods:GetJoinData()
	return {}
end
function methods:DistanceFromCharacter()
	return 0
end
function methods:GetMouse()
	return {}
end
function methods:GetNetworkPing()
	return 0
end
-- gui
function methods:TweenSize() end
function methods:TweenPosition() end
function methods:TweenSizeAndPosition() end
function methods:CaptureFocus() end
function methods:ReleaseFocus() end

InstMT.__index = function(o, k)
	local m = methods[k]
	if m then
		return m
	end
	local p = rawget(o, "__props")
	if k == "Parent" then
		return p.Parent
	end
	if k == "Position" and BASEPART[o.ClassName] then
		return p.CFrame.Position
	end
	if k == "Orientation" and BASEPART[o.ClassName] then
		return Vector3.new()
	end
	if k == "Rotation" and BASEPART[o.ClassName] then
		return Vector3.new()
	end
	if k == "PrimaryPart" or k == "Character" then
		return p[k]
	end
	local v = p[k]
	if v ~= nil then
		return v
	end
	if EVENTS[k] or (type(k) == "string" and (k:match("Added$") or k:match("Removing$") or k:match("Removed$") or k:match("Finished$") or k:match("Changed$") or k:match("Stepped$") or k == "Heartbeat" or k:match("Simulation$") or k:match("Began$") or k:match("Ended$") or k:match("Released$") or k:match("Close$") or k:match("Fired$"))) then
		local s = rawget(o, "__signals")
		s[k] = s[k] or newSignal(k)
		return s[k]
	end
	-- a child with that name?
	for _, c in ipairs(rawget(o, "__children")) do
		if c.Name == k then
			return c
		end
	end
	return nil
end
InstMT.__newindex = function(o, k, v)
	local p = rawget(o, "__props")
	if k == "Parent" then
		local old = p.Parent
		if old == v then
			return
		end
		if old then
			local ch = rawget(old, "__children")
			for i, c in ipairs(ch) do
				if c == o then
					table.remove(ch, i)
					break
				end
			end
		end
		p.Parent = v
		if v then
			table.insert(rawget(v, "__children"), o)
			local a = v
			while a do
				local s = rawget(a, "__signals").DescendantAdded
				if s then
					s:Fire(o)
				end
				a = a.Parent
			end
			local s = rawget(v, "__signals").ChildAdded
			if s then
				s:Fire(o)
			end
		end
		return
	end
	if k == "Position" and BASEPART[o.ClassName] then
		local cf = p.CFrame
		p.CFrame = CFrame.new(v.X, v.Y, v.Z) * cf.Rotation
		return
	end
	if k == "Orientation" and BASEPART[o.ClassName] then
		return
	end
	if type(k) == "string" and k:sub(1, 2) ~= "__" then
		p[k] = v
		local s = rawget(o, "__propSignals")[k]
		if s then
			s:Fire()
		end
	else
		rawset(o, k, v)
	end
end
InstMT.__tostring = function(o)
	return o.Name
end
function Instance.new(class, parent)
	local o = inst(class)
	if parent then
		o.Parent = parent
	end
	return o
end

-- ===== services =====
local game = inst("DataModel")
game.Name = "Game"
local services = {}
local function service(name)
	if not services[name] then
		local s = inst(name)
		s.Name = name
		s.Parent = game
		services[name] = s
	end
	return services[name]
end
function methods:GetService(name)
	return service(name)
end
game.PlaceId = 1
game.GameId = 1
game.JobId = "test"
game.CreatorId = 1
game.CreatorType = Enum.CreatorType.User
function methods:BindToClose() end

local Workspace = service("Workspace")
Workspace.Gravity = 196.2
Workspace.CurrentCamera = inst("Camera")
function methods:GetServerTimeNow()
	return 1700000000 + now
end
function methods:Raycast()
	return nil
end
function methods:GetPartBoundsInBox()
	return {}
end
function methods:GetPartBoundsInRadius()
	return {}
end
function methods:GetPartsInPart()
	return {}
end

-- Players
local Players = service("Players")
local plist = {}
function methods:GetPlayers()
	local t = {}
	for _, p in ipairs(plist) do
		table.insert(t, p)
	end
	return t
end
function methods:GetPlayerByUserId(id)
	for _, p in ipairs(plist) do
		if p.UserId == id then
			return p
		end
	end
end
function methods:GetPlayerFromCharacter(c)
	for _, p in ipairs(plist) do
		if p.Character == c then
			return p
		end
	end
end
function methods:GetNameFromUserIdAsync(id)
	return "User" .. id
end
function methods:GetUserThumbnailAsync()
	return "rbxthumb://", true
end
function methods:GetHumanoidDescriptionFromUserId()
	return inst("HumanoidDescription")
end
function methods:CreateHumanoidModelFromDescription()
	return inst("Model")
end
function methods:GetUserIdFromNameAsync()
	return 1
end
Players.RespawnTime = 5
Players.CharacterAutoLoads = true

-- RunService
local RunService = service("RunService")
function methods:IsStudio()
	return true
end
function methods:IsServer()
	return true
end
function methods:IsClient()
	return false
end
function methods:IsRunning()
	return true
end
function methods:BindToRenderStep() end
function methods:UnbindFromRenderStep() end

-- CollectionService
local tags = {}
function methods:AddTag(o, t)
	tags[t] = tags[t] or {}
	tags[t][o] = true
	local s = rawget(service("CollectionService"), "__signals")["Added_" .. t]
	if s then
		s:Fire(o)
	end
end
function methods:RemoveTag(o, t)
	if tags[t] then
		tags[t][o] = nil
	end
end
function methods:HasTag(o, t)
	return tags[t] ~= nil and tags[t][o] == true
end
function methods:GetTagged(t)
	local r = {}
	for o in pairs(tags[t] or {}) do
		if not o.__destroyed then
			table.insert(r, o)
		end
	end
	return r
end
function methods:GetInstanceAddedSignal(t)
	local s = rawget(service("CollectionService"), "__signals")
	s["Added_" .. t] = s["Added_" .. t] or newSignal()
	return s["Added_" .. t]
end
function methods:GetInstanceRemovedSignal()
	return newSignal()
end

-- DataStores (in memory)
local stores = {}
SHARED.STORES = stores
local function newStore(name, ordered)
	local st = { name = name, data = {} }
	function st:GetAsync(k)
		return self.data[k]
	end
	function st:SetAsync(k, v)
		self.data[k] = v
		log("SetAsync", name, k, type(v) == "table" and "{table}" or v)
	end
	function st:UpdateAsync(k, fn)
		local v = fn(self.data[k])
		if v ~= nil then
			self.data[k] = v
		end
		return v
	end
	function st:RemoveAsync(k)
		self.data[k] = nil
	end
	function st:IncrementAsync(k, d)
		self.data[k] = (self.data[k] or 0) + (d or 1)
		return self.data[k]
	end
	function st:GetSortedAsync(asc, n)
		local list = {}
		for k, v in pairs(self.data) do
			table.insert(list, { key = k, value = v })
		end
		table.sort(list, function(a, b)
			if asc then
				return a.value < b.value
			end
			return a.value > b.value
		end)
		local page = {}
		for i = 1, math.min(n, #list) do
			page[i] = list[i]
		end
		return { GetCurrentPage = function()
			return page
		end, IsFinished = true, AdvanceToNextPageAsync = function() end }
	end
	stores[name] = st
	return st
end
function methods:GetDataStore(name, scope)
	return stores[name] or newStore(name)
end
function methods:GetOrderedDataStore(name)
	return stores[name] or newStore(name, true)
end
function methods:GetRequestBudgetForRequestType()
	return 100
end

-- Marketplace
local MPS = service("MarketplaceService")
function methods:UserOwnsGamePassAsync()
	return false
end
function methods:PlayerOwnsAsset()
	return false
end
function methods:GetProductInfo()
	return { PriceInRobux = 10, Name = "x" }
end
function methods:PromptGamePassPurchase(p, id)
	log("PromptGamePassPurchase", p.Name, id)
end
function methods:PromptProductPurchase(p, id)
	log("PromptProductPurchase", p.Name, id)
end

-- misc services
function methods:Create(obj, info, props)
	return { Play = function()
		for k, v in pairs(props) do
			obj[k] = v
		end
	end, Cancel = function() end, Pause = function() end, Completed = newSignal() }
end
function methods:AddItem(o, t)
	task.delay(t or 10, function()
		o:Destroy()
	end)
end
function methods:JSONEncode()
	return "{}"
end
function methods:JSONDecode()
	return {}
end
function methods:GenerateGUID()
	return "guid"
end
function methods:RegisterCollisionGroup() end
function methods:CollisionGroupSetCollidable() end
function methods:CollisionGroupsAreCollidable()
	return true
end
function methods:IsCollisionGroupRegistered()
	return false
end
function methods:CreateCollisionGroup() end
function methods:SetPartCollisionGroup() end
function methods:SubscribeAsync()
	return { Disconnect = function() end }
end
function methods:PublishAsync() end
function methods:UserHasBadgeAsync()
	return false
end
function methods:AwardBadge() end
function methods:LoadAsset()
	return inst("Model")
end
function methods:FilterStringAsync(s)
	return { GetNonChatStringForBroadcastAsync = function()
		return s
	end }
end
function methods:DisplaySystemMessage() end
function methods:GetAsync()
	return nil
end

local env = {
	Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, UDim = UDim, UDim2 = UDim2, Vector2 = Vector2,
	NumberRange = NumberRange, NumberSequence = NumberSequence, ColorSequence = ColorSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint, ColorSequenceKeypoint = ColorSequenceKeypoint,
	TweenInfo = TweenInfo, PhysicalProperties = PhysicalProperties, Rect = Rect, Ray = Ray, Region3 = Region3,
	OverlapParams = OverlapParams, RaycastParams = RaycastParams, Font = Font, BrickColor = { new = function() return {} end, Random = function() return {} end },
	Enum = Enum, Random = Random, Instance = Instance, game = game, workspace = Workspace, task = task, wait = wait, delay = delay, spawn = spawn,
	tick = function() return now end, time = function() return now end, os = setmetatable({ clock = function() return now end, time = function() return 1700000000 + math.floor(now) end }, { __index = os }),
	warn = function(...) log("WARN", ...) end, print = function(...) log("PRINT", ...) end,
	typeof = function(v)
		local mt = type(v) == "table" and getmetatable(v)
		if mt == Vector3 then return "Vector3" elseif mt == CFrame then return "CFrame" elseif mt == Color3 then return "Color3"
		elseif mt == InstMT then return "Instance" elseif mt == EnumItemMT then return "EnumItem" end
		return type(v)
	end,
	DateTime = { now = function() return { UnixTimestamp = 1700000000 + math.floor(now), ToUniversalTime = function() return { Year = 2026, Month = 1, Day = 1, Hour = 0 } end } end },
}
env.__STEP = function(seconds)
	local target = now + seconds
	local hb = rawget(RunService, "__signals")
	while now < target do
		now = now + 1 / 30
		local s = hb.Heartbeat
		if s then
			s:Fire(1 / 30)
		end
		local st = hb.Stepped
		if st then
			st:Fire(now, 1 / 30)
		end
		local ran = true
		local guard = 0
		while ran and guard < 20 do
			ran = false
			guard += 1
			table.sort(queue, function(a, b)
				return a.at < b.at
			end)
			local due = {}
			for i = #queue, 1, -1 do
				if queue[i].at <= now then
					table.insert(due, 1, table.remove(queue, i))
				end
			end
			for _, q in ipairs(due) do
				if coroutine.status(q.co) == "suspended" then
					ran = true
					resume(q.co, table.unpack(q.args, 1, q.args.n))
				end
			end
		end
	end
end
env.__service = service
env.__shared = SHARED
env.__inst = inst
env.__players = plist
env.__signal = newSignal
env.__now = function()
	return now
end
return env

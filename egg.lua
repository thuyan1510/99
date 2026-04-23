-- ==========================================
-- 🌸 EASTER EVENT - V87 (TICKET & SCANNER PERFECTED) 🌸
-- (Khôi phục hàm Ticket gốc + UI Your/Total % + Portal Scanner)
-- ==========================================
repeat task.wait() until game:IsLoaded()
if _G.SpringStarted then return end
_G.SpringStarted = true

local UserSettings = getgenv().Settings or {}
local function SafeNumber(val, default)
    if val == nil then return default end
    local n = tonumber(val)
    return n or default
end

local rawMode = SafeNumber(UserSettings.Mode, 3)
local Mode, ModeDisplay = "Combine", "Combine (3)"
if rawMode == 1 then Mode, ModeDisplay = "HatchOnly", "Hatch Only (1)"
elseif rawMode == 2 then Mode, ModeDisplay = "FarmOnly", "Farm Only (2)" end

local FarmTimeMinutes = SafeNumber(UserSettings.FarmTimeMinutes, 20)
local HatchTimeMinutes = SafeNumber(UserSettings.HatchTimeMinutes, 10)
local AutoUpgrade = UserSettings.AutoUpgrade ~= false
local AutoHatch = UserSettings.AutoHatch ~= false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local Library = ReplicatedStorage:WaitForChild("Library")
local Network = require(Library.Client.Network)
local Save = require(Library.Client.Save)
local CurrencyCmds = require(Library.Client.CurrencyCmds)
local PlayerPet = require(Library.Client.PlayerPet)
local EventUpgradeCmds = require(Library.Client.EventUpgradeCmds)
local EventUpgradesDir = require(Library.Directory.EventUpgrades)
local Items = require(Library.Items)
local InstancingCmds = require(Library.Client.InstancingCmds)
local UltimateCmds = require(Library.Client.UltimateCmds)
local FreeGiftsDirectory = require(Library.Directory.FreeGifts)

-- ==========================================
-- 🧲 MÁY QUÉT RAM AN TOÀN (BYPASS COOLDOWN)
-- ==========================================
print("🚀 Đang khởi động Máy Quét RAM an toàn...")
local foundCooldowns, bypassedMods = 0, 0

for _, v in pairs(getgc(true)) do
    if type(v) == "table" then
        local isHatchMod = false
        pcall(function()
            if rawget(v, "HatchDelay") and type(rawget(v, "HatchDelay")) == "number" then rawset(v, "HatchDelay", 0); isHatchMod = true; foundCooldowns = foundCooldowns + 1 end
            if rawget(v, "Cooldown") and type(rawget(v, "Cooldown")) == "number" then rawset(v, "Cooldown", 0); isHatchMod = true; foundCooldowns = foundCooldowns + 1 end
            if rawget(v, "AnimationDelay") and type(rawget(v, "AnimationDelay")) == "number" then rawset(v, "AnimationDelay", 0); isHatchMod = true; foundCooldowns = foundCooldowns + 1 end
            if rawget(v, "OpenSpeed") and type(rawget(v, "OpenSpeed")) == "number" then rawset(v, "OpenSpeed", 0); isHatchMod = true; foundCooldowns = foundCooldowns + 1 end
            if rawget(v, "WaitTime") and type(rawget(v, "WaitTime")) == "number" then rawset(v, "WaitTime", 0); isHatchMod = true; foundCooldowns = foundCooldowns + 1 end
        end)
        if isHatchMod then bypassedMods = bypassedMods + 1 end
    end
end
print("🎯 Đã bẻ khóa an toàn " .. foundCooldowns .. " biến Cooldown!")

local oldTaskWait
oldTaskWait = hookfunction(task.wait, function(time)
    if time and type(time) == "number" and time > 0 and time < 3 then
        local callStack = debug.traceback()
        if callStack:lower():match("egg") or callStack:lower():match("hatch") then
            return oldTaskWait(0.01) 
        end
    end
    return oldTaskWait(time)
end)

-- ==========================================
-- 🛡️ ANTI AFK & EXTREME OPTIMIZE
-- ==========================================
pcall(function()
    local UserInputService = game:GetService("UserInputService")
    if getconnections then
        for _, v in pairs(getconnections(Player.Idled)) do pcall(function() v:Disable() end) end
    end
end)

local function ExtremeOptimize(v)
    pcall(function()
        if v:IsA("BasePart") then v.Material = Enum.Material.Plastic; v.Reflectance = 0; v.CastShadow = false
        elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
            if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 else v.Enabled = false end
        end
    end)
end
for _, v in ipairs(Workspace:GetDescendants()) do ExtremeOptimize(v) end

-- ==========================================
-- 📍 TỌA ĐỘ TUYỆT ĐỐI
-- ==========================================
_G.DynamicHubCF = CFrame.new(-18581.56, 17.03, -29110.16)
local FarmOffset = Vector3.new(53.53, 0, 0.62)
local HatchZoneCF = CFrame.new(-18514.40, 16.24, -29111.44) -- Tọa độ zone hatch bạn yêu cầu

local StartTime = os.time()
local StartEggs = 0
pcall(function() StartEggs = Save.Get().Easter2026EggsHatched or 0 end)

local function FormatValue(Value)
    local n = tonumber(Value)
    if not n then return tostring(Value) end
    local suffixes, index, absNumber = {"", "k", "m", "b", "t"}, 1, math.abs(n)
    while absNumber >= 1000 and index < #suffixes do absNumber = absNumber / 1000; index = index + 1 end
    return (absNumber >= 1 and index > 1) and string.format("%.2f", absNumber):gsub("%.00$", "") .. suffixes[index] or tostring(math.floor(absNumber)) .. suffixes[index]
end

-- ==========================================
-- 🎨 CUSTOM UI V87
-- ==========================================
local FarmUI = {}
FarmUI.__index = FarmUI
function FarmUI.new(UIConfig)
	local Self = setmetatable({}, FarmUI)
	Self.GuiName = "EasterEventGuiV87"
	Self.Elements = {}
	Self.Parent = game:GetService("CoreGui")
    if Self.Parent:FindFirstChild(Self.GuiName) then Self.Parent[Self.GuiName]:Destroy() end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = Self.GuiName; ScreenGui.IgnoreGuiInset = true; ScreenGui.Parent = Self.Parent; ScreenGui.ResetOnSpawn = false
	Self.ScreenGui = ScreenGui

	local Background = Instance.new("Frame", ScreenGui)
	Background.BackgroundColor3 = Color3.fromRGB(15, 15, 15); Background.BorderColor3 = Color3.fromRGB(0, 255, 150)
	Background.BorderMode = Enum.BorderMode.Inset; Background.Size = UDim2.new(1, 0, 1, 0); Background.Position = UDim2.new(0.5, 0, 0.5, 0); Background.AnchorPoint = Vector2.new(0.5, 0.5)

	local Container = Instance.new("Frame", Background)
	Container.Size = UDim2.new(1, 0, 1, 0); Container.BackgroundTransparency = 1; Self.Container = Container

	local Layout = Instance.new("UIListLayout", Container)
	Layout.Padding = UDim.new(0.015, 0); Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; Layout.VerticalAlignment = Enum.VerticalAlignment.Center; Layout.SortOrder = Enum.SortOrder.LayoutOrder

	for Name, Data in pairs(UIConfig.UI) do
		local Label = Instance.new("TextLabel", Self.Container)
		Label.Name = Name; Label.LayoutOrder = Data[1]; Label.Size = Data[3] and UDim2.new(unpack(Data[3])) or UDim2.new(0.7, 0, 0.055, 0)
		Label.BackgroundTransparency = 1; Label.Font = Enum.Font.FredokaOne; Label.Text = Data[2]; Label.TextColor3 = Color3.fromRGB(255, 255, 255); Label.TextScaled = true
		Self.Elements[Name] = Label
	end
	return Self
end

function FarmUI:SetText(Name, Text) if self.Elements[Name] then task.defer(function() self.Elements[Name].Text = Text end) end end

local UI = FarmUI.new({
    UI = {
        ["Title"]           = {1, "🐰 EASTER V87 (TICKET FIX)", {0.8, 0, 0.08, 0}},
        ["ModeInfo"]        = {2, "Mode: " .. ModeDisplay},
        ["Time"]            = {3, "Time: 00:00:00 | Time Left: 00:00"},
        ["EggsHatched"]     = {4, "Total Eggs Hatched: 0"},
        ["Speed"]           = {5, "⚡ Speed: 0 Eggs/sec"},
        ["Tokens"]          = {6, "Token B/R/S/T: 0/0/0/0"},
        ["Tickets"]         = {8, "Tickets: 0/0 (0%)"}
    }
})

-- ==========================================
-- 🚀 DATA UPDATER (HÀM TICKET GỐC + UI MỚI)
-- ==========================================
local lastEggs = StartEggs
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local save = Save.Get()
            local yourTickets = 0
            local globalTickets = 1 -- Tránh chia cho 0
            
            -- 1. HÀM TICKET NHƯ CŨ (Cộng dồn từ save data)
            if save and save.Easter2026ZoneTickets then
                for _, val in pairs(save.Easter2026ZoneTickets) do 
                    yourTickets = yourTickets + val 
                end
            end

            -- 2. Lấy Total Ticket từ Máy chủ (Global Raffle)
            pcall(function()
                local status = Network.Invoke("EasterHatchEvent: GetStatus")
                if status and status.TotalTickets then 
                    globalTickets = status.TotalTickets 
                end
            end)

            local percent = (yourTickets / globalTickets) * 100
            UI:SetText("Tickets", string.format("Tickets: %s/%s (%.4f%%)", FormatValue(yourTickets), FormatValue(globalTickets), percent))

            local currentEggs = save.Easter2026EggsHatched or StartEggs
            local hatchedThisSession = math.max(0, currentEggs - StartEggs)
            local speed = currentEggs - lastEggs
            lastEggs = currentEggs
            
            UI:SetText("EggsHatched", "Total Eggs Hatched: " .. FormatValue(hatchedThisSession))
            UI:SetText("Speed", "⚡ Speed: " .. tostring(speed) .. " Eggs/sec")
            
            local b, r, s, t = 0, 0, 0, 0
            if save and save.Inventory then
                for _, item in pairs(save.Inventory.Currency or {}) do
                    local id = (item.id or ""):lower()
                    if id:match("bluebell") then b = b + (item._am or 1)
                    elseif id:match("rose") then r = r + (item._am or 1)
                    elseif id:match("sunflower") then s = s + (item._am or 1)
                    elseif id:match("tulip") then t = t + (item._am or 1) end
                end
            end
            UI:SetText("Tokens", string.format("Token B/R/S/T: %s/%s/%s/%s", FormatValue(b), FormatValue(r), FormatValue(s), FormatValue(t)))
        end)
    end
end)

-- ==========================================
-- 🚀 ĐỘNG CƠ HATCH TRỨNG (8 EGGS/S)
-- ==========================================
task.spawn(function()
    while true do
        if _G.CurrentPhase == "HATCHING" and AutoHatch then
            task.spawn(function() pcall(function() Network.Invoke("EasterHatchEvent", "HatchRequest") end) end)
            task.wait(0.05) 
        else task.wait(0.5) end
    end
end)

-- ==========================================
-- 🚀 PORTAL SCANNER LOGIC (CHỐNG KẸT CỔNG)
-- ==========================================
local function EnterZoneNetwork()
    _G.FarmReady = false
    local max_portals = 4 
    for portalIndex = 1, max_portals do
        local serverZoneID = portalIndex + 1 
        pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ZonePortal", serverZoneID) end)
        
        local waitTime = 0
        local success = false
        while waitTime < 2 do
            if (HumanoidRootPart.Position - _G.DynamicHubCF.Position).Magnitude > 50 then
                success = true
                break
            end
            task.wait(0.25)
            waitTime = waitTime + 0.25
        end
        
        if success then
            task.wait(1) 
            local farmCF = CFrame.new(HumanoidRootPart.Position + FarmOffset)
            HumanoidRootPart.CFrame = farmCF
            task.wait(0.5)
            _G.FarmReady = true
            State.CurrentPortal = portalIndex
            return true
        end
    end
    return false
end

-- ==========================================
-- 🚀 CHU KỲ CHÍNH (Combine/Hatch/Farm)
-- ==========================================
local function ReturnToHubNetwork()
    _G.FarmReady = false
    pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ReturnToHub") end)
    task.wait(1.5)
    HumanoidRootPart.CFrame = HatchZoneCF
end

task.spawn(function()
    while task.wait(1) do
        State.TimeLeft = State.TimeLeft - 1
        if State.TimeLeft <= 0 then
            State.IsReady = false; _G.FarmReady = false
            if Mode == "Combine" then 
                if State.Phase == "FARMING" then State.Phase = "HATCHING"; State.TimeLeft = HatchTimeMinutes * 60 
                else State.Phase = "FARMING"; State.TimeLeft = math.max(20, FarmTimeMinutes) * 60 end
            end
            _G.CurrentPhase = State.Phase
        end

        if not State.IsReady then
            if State.Phase == "FARMING" then 
                if EnterZoneNetwork() then State.IsReady = true 
                else State.Phase = "HATCHING"; _G.CurrentPhase = "HATCHING"; State.TimeLeft = 60; ReturnToHubNetwork(); State.IsReady = true end
            else ReturnToHubNetwork(); State.IsReady = true end
        end

        if State.IsReady then
            if State.Phase == "HATCHING" and (HumanoidRootPart.Position - HatchZoneCF.Position).Magnitude > 30 then HumanoidRootPart.CFrame = HatchZoneCF end
        end
        
        local elapsed = os.time() - StartTime
        UI:SetText("Time", string.format("Time: %02d:%02d:%02d | Left: %02d:%02d", math.floor(elapsed/3600), math.floor((elapsed%3600)/60), elapsed%60, math.floor(State.TimeLeft/60), State.TimeLeft%60))
    end
end)

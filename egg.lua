-- ==========================================
-- 🌸 EASTER EVENT - V75 (THE PERFECT COMPLETION) 🌸
-- (Sửa lỗi Ticket UI + Auto Purchase + 100x Hatch Exploit)
-- ==========================================
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

-- ==========================================
-- 🛡️ ANTI AFK (HỆ THỐNG BẤT TỬ V4)
-- ==========================================
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local args = {...}
        if tostring(args[1]) == "Idle Tracking: Update Timer" or tostring(args[1]) == "AFK_Ping" then return end
    end
    return oldNamecall(self, ...)
end)

task.spawn(function()
    while task.wait(60) do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            local cam = workspace.CurrentCamera
            if cam then
                local currentCFrame = cam.CFrame
                cam.CFrame = currentCFrame * CFrame.Angles(0, math.rad(5), 0)
                task.wait(0.5)
                cam.CFrame = currentCFrame
            end
        end)
    end
end)

-- ==========================================
-- 🚀 TỐI ƯU HÓA ĐỒ HỌA
-- ==========================================
local function Optimize(v)
    pcall(function()
        if v:IsA("BasePart") then v.Material = Enum.Material.Plastic; v.Reflectance = 0
        elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") then 
            if v:IsA("ParticleEmitter") then v.Enabled = false else v.Transparency = 1 end
        end
    end)
end
for _, v in ipairs(Workspace:GetDescendants()) do Optimize(v) end

-- ==========================================
-- 📊 FORMAT & UI
-- ==========================================
_G.DynamicHubCF = CFrame.new(-18581.56, 17.03, -29110.16)
local FarmOffset = Vector3.new(53.53, 0, 0.62)
local HatchOffset = Vector3.new(62.53, 0, -12.60) 

local function FormatValue(Value)
    local n = tonumber(Value) or 0
    local suffixes, index, absNumber = {"", "k", "m", "b", "t"}, 1, math.abs(n)
    while absNumber >= 1000 and index < #suffixes do absNumber = absNumber / 1000; index = index + 1 end
    return (absNumber >= 1 and index > 1) and string.format("%.2f", absNumber):gsub("%.00$", "") .. suffixes[index] or tostring(math.floor(absNumber)) .. suffixes[index]
end

local FarmUI = {}
FarmUI.__index = FarmUI
function FarmUI.new()
	local Self = setmetatable({}, FarmUI)
	Self.GuiName = "EasterEventGuiV75"
	Self.Elements = {}
    if game:GetService("CoreGui"):FindFirstChild(Self.GuiName) then game:GetService("CoreGui")[Self.GuiName]:Destroy() end

	local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
	ScreenGui.Name = Self.GuiName; ScreenGui.IgnoreGuiInset = true
	
	local Background = Instance.new("Frame", ScreenGui)
	Background.BackgroundColor3 = Color3.fromRGB(15, 15, 15); Background.Size = UDim2.new(1, 0, 1, 0)

	local Container = Instance.new("Frame", Background)
	Container.Size = UDim2.new(0.8, 0, 0.8, 0); Container.Position = UDim2.new(0.1, 0, 0.1, 0); Container.BackgroundTransparency = 1
	Instance.new("UIListLayout", Container).HorizontalAlignment = Enum.HorizontalAlignment.Center

    local labels = {"Title", "Mode", "Time", "Eggs", "Tokens", "SpringToken", "Tickets", "FPS"}
    for i, name in ipairs(labels) do
        local lbl = Instance.new("TextLabel", Container)
        lbl.Name = name; lbl.Size = UDim2.new(1, 0, 0.1, 0); lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.FredokaOne; lbl.TextColor3 = Color3.new(1, 1, 1); lbl.TextScaled = true
        Self.Elements[name] = lbl
    end
    Self.Elements.Title.Text = "🐰 EASTER V75 (PRO EDITION)"
	return Self
end
function FarmUI:SetText(Name, Text) if self.Elements[Name] then self.Elements[Name].Text = Text end end
local UI = FarmUI.new()

-- ==========================================
-- 🚀 DATA UPDATER (FIX TICKET) 
-- ==========================================
task.spawn(function()
    local StartTime = os.time()
    while task.wait(1.5) do
        pcall(function()
            local save = Save.Get()
            local b, r, s, t, eggToken, totalTickets = 0, 0, 0, 0, 0, 0
            
            -- Lấy Ticket từ Save Data 
            if save.Easter2026ZoneTickets then
                for _, val in pairs(save.Easter2026ZoneTickets) do totalTickets = totalTickets + val end
            end

            -- Lấy Token chính xác
            local function scan(cat)
                if not cat then return end
                for _, item in pairs(cat) do
                    local id = tostring(item.id or ""):lower()
                    if id:match("bluebell") then b = b + (item._am or 1)
                    elseif id:match("rose") then r = r + (item._am or 1)
                    elseif id:match("sunflower") then s = s + (item._am or 1)
                    elseif id:match("tulip") then t = t + (item._am or 1)
                    elseif id:match("spring") and id:match("egg") then eggToken = eggToken + (item._am or 1) end
                end
            end
            scan(save.Inventory.Currency); scan(save.Inventory.Misc)

            local elapsed = os.time() - StartTime
            UI:SetText("Time", string.format("Time: %02d:%02d:%02d", math.floor(elapsed/3600), math.floor((elapsed%3600)/60), elapsed%60))
            UI:SetText("Tokens", string.format("B/R/S/T: %s/%s/%s/%s", FormatValue(b), FormatValue(r), FormatValue(s), FormatValue(t)))
            UI:SetText("SpringToken", "Spring Egg Token: " .. FormatValue(eggToken))
            UI:SetText("Tickets", "Total Tickets (Save): " .. FormatValue(totalTickets))
            UI:SetText("Eggs", "Hatched: " .. FormatValue(save.Easter2026EggsHatched))
        end)
    end
end)

-- ==========================================
-- 🚀 CỖ MÁY MỞ TRỨNG 100X (EXPLOIT) 
-- ==========================================
local CurrentTargetEgg = nil
task.spawn(function()
    while true do
        if _G.CurrentPhase == "HATCHING" and AutoHatch then
            local nearest, dist = nil, math.huge
            pcall(function()
                for _, v in pairs(Workspace.__THINGS.CustomEggs:GetChildren()) do
                    if v:IsA("Model") and v.PrimaryPart then
                        local d = (HumanoidRootPart.Position - v.PrimaryPart.Position).Magnitude
                        if d < dist then nearest = v.Name; dist = d end
                    end
                end
            end)
            CurrentTargetEgg = nearest
        end
        task.wait(1)
    end
end)

task.spawn(function()
    local HatchRemote = ReplicatedStorage:WaitForChild("Network"):WaitForChild("CustomEggs_Hatch")
    while true do
        if _G.CurrentPhase == "HATCHING" and AutoHatch and CurrentTargetEgg then
            pcall(function() HatchRemote:InvokeServer(CurrentTargetEgg, 100) end) -- [cite: 14]
            task.wait(0.1)
        else task.wait(1) end
    end
end)

-- ==========================================
-- 🚀 AUTO PURCHASE & SELECT (NETWORK) 
-- ==========================================
local EggCosts = { [2]=300, [3]=1500, [4]=6000, [5]=20000 }
task.spawn(function()
    while task.wait(5) do
        if AutoUpgrade then
            pcall(function()
                local save = Save.Get()
                local currentUnlocked = save.Easter2026UnlockedEggs or 1 -- 
                local activeEgg = save.Easter2026ActiveEgg or 1
                
                local token = CurrencyCmds.Get("SpringEggTokens") or 0
                
                for i = 2, 5 do
                    -- Nếu chưa mở khóa và đủ tiền -> Bắn lệnh Mua 
                    if i > currentUnlocked and token >= EggCosts[i] then
                        Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "PurchaseEgg", i)
                        task.wait(0.5)
                        Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "SelectEgg", i)
                        break
                    -- Nếu đã mở rồi nhưng chưa trang bị -> Bắn lệnh Chọn
                    elseif i == currentUnlocked and activeEgg ~= i then
                        Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "SelectEgg", i)
                    end
                end
                -- Auto Nâng cấp Bảng Kỹ Năng
                for id, data in pairs(EventUpgradesDir) do
                    if id:find("Easter") then EventUpgradeCmds.Purchase(id) end
                end
            end)
        end
    end
end)

-- ==========================================
-- 🚀 PORTAL LOGIC (ZERO-TELEPORT)
-- ==========================================
local function Teleport(cf) HumanoidRootPart.CFrame = cf + Vector3.new(0,2,0) end

local State = { Phase = (Mode == "HatchOnly") and "HATCHING" or "FARMING", TimeLeft = 1200, CurrentPortal = 1, IsReady = false }
_G.CurrentPhase = State.Phase

task.spawn(function()
    while task.wait(1) do
        State.TimeLeft = State.TimeLeft - 1
        if State.TimeLeft <= 0 then
            State.IsReady = false
            if Mode == "Combine" then
                if State.Phase == "FARMING" then State.Phase = "HATCHING"; State.TimeLeft = 600
                else State.Phase = "FARMING"; State.TimeLeft = 1200; State.CurrentPortal = (State.CurrentPortal % 4) + 1 end
            end
            _G.CurrentPhase = State.Phase
        end

        if not State.IsReady then
            if State.Phase == "FARMING" then
                Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ZonePortal", State.CurrentPortal + 1)
                task.wait(1.5)
                if (HumanoidRootPart.Position - _G.DynamicHubCF.Position).Magnitude > 400 then
                    _G.CurrentFarmCF = CFrame.new(HumanoidRootPart.Position + FarmOffset)
                    Teleport(_G.CurrentFarmCF); State.IsReady = true; _G.FarmReady = true
                else State.CurrentPortal = math.max(1, State.CurrentPortal - 1) end
            else
                Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ReturnToHub")
                task.wait(1.5)
                Teleport(CFrame.new(_G.DynamicHubCF.Position + HatchOffset))
                State.IsReady = true; _G.FarmReady = false
            end
        end
    end
end)

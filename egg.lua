-- ==========================================
-- 🌸 EASTER EVENT - V40 (THE ULTIMATE VERSION) 🌸
-- ==========================================
if _G.SpringStarted then return end
_G.SpringStarted = true

local UserSettings = getgenv().Settings or {}
local Mode = UserSettings.Mode or "Combine"
local FarmTimeMinutes = tonumber(UserSettings.FarmTimeMinutes) or 20
local HatchTimeMinutes = tonumber(UserSettings.HatchTimeMinutes) or 10
local AutoUpgrade = UserSettings.AutoUpgrade ~= false
local AutoHatch = UserSettings.AutoHatch ~= false
local WEBHOOK_URL = (UserSettings.Webhook and UserSettings.Webhook.url) or ""
local DISCORD_ID = (UserSettings.Webhook and UserSettings.Webhook["Discord Id to ping"]) or ""

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Player = Players.LocalPlayer
local HumanoidRootPart = Player.Character:WaitForChild("HumanoidRootPart")

local Library = ReplicatedStorage:WaitForChild("Library")
local Network = require(Library.Client.Network)
local Save = require(Library.Client.Save)
local CurrencyCmds = require(Library.Client.CurrencyCmds)
local PlayerPet = require(Library.Client.PlayerPet)

-- ==========================================
-- 📊 TRACKER & MATH UTILS
-- ==========================================
local Stats = { Eggs = 0, Huges = 0, Titanics = 0 }
local function ParseValue(str)
    if not str then return 0 end
    str = str:lower():gsub(",", "")
    local suffix = str:sub(-1)
    local num = tonumber(str:sub(1, -2)) or tonumber(str) or 0
    if suffix == "k" then return num * 1000
    elseif suffix == "m" then return num * 1000000
    elseif suffix == "b" then return num * 1000000000
    elseif suffix == "t" then return num * 1000000000000
    end
    return tonumber(str) or 0
end

local function FormatValue(Value)
    local n = tonumber(Value)
    if not n then return tostring(Value) end
    local suffixes = {"", "k", "m", "b", "t"}
    local index = 1
    local absNumber = math.abs(n)
    while absNumber >= 1000 and index < #suffixes do absNumber = absNumber / 1000; index = index + 1 end
    return (absNumber >= 1 and index > 1) and string.format("%.2f", absNumber):gsub("%.00$", "") .. suffixes[index] or tostring(math.floor(absNumber)) .. suffixes[index]
end

-- ==========================================
-- 🚀 1. EXTREME OPTIMIZE (CLEAN VERSION)
-- ==========================================
for _, v in ipairs(Workspace:GetDescendants()) do
    pcall(function() if v:IsA("BasePart") then v.CastShadow = false elseif v:IsA("Decal") then v.Transparency = 1 end end)
end
Lighting.GlobalShadows = false

-- ==========================================
-- 🎨 2. CUSTOM UI (EASTER EVENT DESIGN)
-- ==========================================
local FarmUI = {}
FarmUI.__index = FarmUI
function FarmUI.new()
    local Self = setmetatable({}, FarmUI)
    local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
    ScreenGui.Name = "EasterV40"
    
    local Main = Instance.new("Frame", ScreenGui)
    Main.Size = UDim2.new(0, 320, 0, 420); Main.Position = UDim2.new(0.5, -160, 0.5, -210)
    Main.BackgroundColor3 = Color3.fromRGB(10, 10, 15); Main.BorderSizePixel = 2; Main.BorderColor3 = Color3.fromRGB(0, 255, 150)
    
    local List = Instance.new("UIListLayout", Main)
    List.Padding = UDim.new(0, 5); List.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local function AddLabel(name, text, color)
        local l = Instance.new("TextLabel", Main)
        l.Name = name; l.Size = UDim2.new(0.9, 0, 0, 30); l.BackgroundTransparency = 1
        l.TextColor3 = color or Color3.new(1,1,1); l.Text = text; l.Font = Enum.Font.FredokaOne; l.TextScaled = true
        Self[name] = l
    end
    
    AddLabel("Title", "🐰 EASTER EVENT V40", Color3.fromRGB(0, 255, 150))
    AddLabel("Mode", "Mode: " .. Mode)
    AddLabel("Time", "Time | Time Left: 00:00 | 00:00")
    AddLabel("TotalEggs", "Total Eggs Hatched: 0", Color3.fromRGB(255, 200, 50))
    AddLabel("Rares", "Huge: 0 | Titanic: 0", Color3.fromRGB(255, 100, 255))
    AddLabel("TokenBRST", "Token B/R/S/T: 0/0/0/0")
    AddLabel("SpringToken", "Spring Egg Token: 0")
    AddLabel("TicketChance", "Ticket: 0 / 0 (Chance: 0%)", Color3.fromRGB(80, 200, 255))
    AddLabel("FPS", "FPS: 60")
    
    return Self
end
local UI = FarmUI.new()

-- ==========================================
-- 🛠️ 3. CORE LOGIC (FAST FARM & TICKET SCRAPER)
-- ==========================================
task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            local save = Save.Get()
            local b, r, s, t, st = 0, 0, 0, 0, 0
            for _, item in pairs(save.Inventory.Misc) do
                local id = item.id or ""
                if id:find("Bluebell") then b = b + (item._am or 1)
                elseif id:find("Rose") then r = r + (item._am or 1)
                elseif id:find("Sunflower") then s = s + (item._am or 1)
                elseif id:find("Tulip") then t = t + (item._am or 1)
                elseif id:find("Spring Egg Token") then st = st + (item._am or 1)
                end
            end
            UI.TokenBRST.Text = string.format("Token B/R/S/T: %s/%s/%s/%s", FormatValue(b), FormatValue(r), FormatValue(s), FormatValue(t))
            UI.SpringToken.Text = "Spring Egg Token: " .. FormatValue(st)
            
            -- TICKET & CHANCE CALCULATION [cite: 21, 39]
            local yourTickets, totalTickets = 0, 1
            local active = Workspace.__THINGS.__INSTANCE_CONTAINER.Active:FindFirstChild("EasterHatchEvent", true)
            if active then
                local board = active:FindFirstChild("RaffleBoard", true)
                if board then
                    local clientText = board:FindFirstChild("ClientTickets", true)
                    local totalText = board:FindFirstChild("TotalTickets", true)
                    if clientText and clientText:FindFirstChild("Amount") then yourTickets = ParseValue(clientText.Amount.Text) end
                    if totalText and totalText:FindFirstChild("Amount") then totalTickets = ParseValue(totalText.Amount.Text) end
                end
            end
            local chance = (yourTickets / math.max(1, totalTickets)) * 100
            UI.TicketChance.Text = string.format("Ticket: %s / %s (Chance: %.5f%%)", FormatValue(yourTickets), FormatValue(totalTickets), chance)
        end)
    end
end)

-- ==========================================
-- ⚔️ VRT FAST FARM ENGINE (1:1 SPEED)
-- ==========================================
local u55 = {}
task.spawn(function()
    while task.wait(0.15) do
        if _G.CurrentPhase ~= "FARMING" or not _G.FarmReady then continue end
        table.clear(u55)
        local pos = HumanoidRootPart.Position
        local breakables = {}
        for _, v in pairs(Workspace.__THINGS.Breakables:GetChildren()) do
            if v:IsA("Model") and (v.WorldPivot.Position - pos).Magnitude < 100 then table.insert(breakables, v.Name) end
        end
        local pets = {}
        for _, p in pairs(PlayerPet.GetAll()) do if p.owner == Player then table.insert(pets, p) end end
        
        if #breakables > 0 and #pets > 0 then
            local v90, v91, v95 = math.floor(#pets / #breakables), #pets % #breakables, 1
            for v94, v96 in ipairs(breakables) do
                local v97 = (v94 <= v91) and (v90 + 1) or v90
                for _ = 1, v97 do if pets[v95] then u55[pets[v95].euid] = v96; v95 = v95 + 1 end end
            end
            if next(u55) then pcall(function() Network.Fire("Breakables_JoinPetBulk", unpack({u55})) end) end
        end
    end
end)

-- ==========================================
-- 🚀 VÒNG LẶP DI CHUYỂN & CHẾ ĐỘ (Ground Level Fix) 
-- ==========================================
local StartTime = os.time()
local State = { Phase = (Mode == "HatchOnly") and "HATCHING" or "FARMING", TimeLeft = FarmTimeMinutes * 60, CurrentPortal = 1, IsReady = false }
_G.CurrentPhase = State.Phase
_G.FarmReady = false

local PortalOffsets = { Vector3.new(187.92, 12.48, -73.25), Vector3.new(200.18, 10.73, -24.80), Vector3.new(198.20, 12.98, 44.73), Vector3.new(170.03, 12.48, 86.75) }
local FarmOffset = Vector3.new(53.53, 0, 0.62)
local HatchOffset = Vector3.new(62.53, 0, -12.60) -- Không cộng thêm Y 

task.spawn(function()
    while task.wait(1) do
        local elapsed = os.time() - StartTime
        UI.Time.Text = string.format("Time: %02d:%02d:%02d | Left: %02d:%02d", math.floor(elapsed/3600), math.floor((elapsed%3600)/60), elapsed%60, math.floor(State.TimeLeft/60), State.TimeLeft%60)
        UI.FPS.Text = "FPS: " .. math.floor(Workspace:GetRealPhysicsFPS())
        
        State.TimeLeft = State.TimeLeft - 1
        if State.TimeLeft <= 0 and Mode ~= "HatchOnly" then
            State.IsReady = false; _G.FarmReady = false
            if Mode == "Combine" then
                if State.Phase == "FARMING" then State.Phase = "HATCHING"; State.TimeLeft = HatchTimeMinutes * 60
                else State.Phase = "FARMING"; State.TimeLeft = FarmTimeMinutes * 60; State.CurrentPortal = (State.CurrentPortal % 4) + 1 end
            else State.TimeLeft = FarmTimeMinutes * 60; State.CurrentPortal = (State.CurrentPortal % 4) + 1 end
            _G.CurrentPhase = State.Phase
        end

        if not State.IsReady then
            if not _G.DynamicHubCF then 
                HumanoidRootPart.Anchored = true; task.wait(1); _G.DynamicHubCF = HumanoidRootPart.CFrame; HumanoidRootPart.Anchored = false 
                for i=1,4 do _G.DynamicPortals[i] = CFrame.new(_G.DynamicHubCF.Position + PortalOffsets[i]) end
            end
            if State.Phase == "FARMING" then
                HumanoidRootPart.CFrame = _G.DynamicPortals[State.CurrentPortal]; task.wait(0.5)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                local waitT = 0; while (HumanoidRootPart.Position - _G.DynamicHubCF.Position).Magnitude < 400 and waitT < 10 do task.wait(0.5); waitT = waitT + 0.5 end
                task.wait(1.5); HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position + FarmOffset); _G.FarmReady = true
            else
                HumanoidRootPart.CFrame = CFrame.new(_G.DynamicHubCF.Position + HatchOffset); _G.FarmReady = false
            end
            State.IsReady = true
        end
    end
end)

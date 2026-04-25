-- ===================================================================
-- 🌸 TẦNG 2: SPRING EVENT V92 LOGIC (SỬ DỤNG FRAMEWORK) - FINAL 100%
-- ===================================================================
repeat task.wait() until game:IsLoaded()
if _G.SpringStarted then return end
_G.SpringStarted = true

local UserSettings = getgenv().Settings or {}
local function SafeNumber(val, default) local n = tonumber(val); return n or default end

local Mode = "Combine"
if UserSettings.Mode == 1 then Mode = "HatchOnly" elseif UserSettings.Mode == 2 then Mode = "FarmOnly" end

local FarmTimeMinutes = SafeNumber(UserSettings.FarmTimeMinutes, 20)
local HatchTimeMinutes = SafeNumber(UserSettings.HatchTimeMinutes, 10)
local AutoHatch = UserSettings.AutoHatch ~= false

-- 1. LOAD FRAMEWORK (TẦNG 3) TỪ GITHUB
local FrameworkURL = "https://raw.githubusercontent.com/thuyan1510/99/refs/heads/main/PS99_Framework.lua"
local PS99 = loadstring(game:HttpGet(FrameworkURL))()

-- KHỞI ĐỘNG CÁC TÍNH NĂNG CHUNG TỪ FRAMEWORK
PS99.EnableInfPet()
PS99.EnableAntiAFK(UserSettings.DEBUG == true)
PS99.StartWebhook(UserSettings.Webhook and UserSettings.Webhook.url, UserSettings.Webhook and UserSettings.Webhook["Discord Id to ping"])
PS99.StartBackgroundTasks({
    AutoFruit = UserSettings.EatFruit ~= false,
    AutoUpgrade = UserSettings.AutoUpgrade ~= false,
    EventKeyword = "Easter" -- Tự động tìm nâng cấp có chữ Easter (Bằng Token B/R/S/T)
})

-- 2. KHAI BÁO CÁC BIẾN & THƯ VIỆN RIÊNG CỦA SỰ KIỆN SPRING
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local Library = ReplicatedStorage:WaitForChild("Library")
local Save = require(Library.Client.Save)
local Network = require(Library.Client.Network)
local InstancingCmds = require(Library.Client.InstancingCmds)
local CurrencyCmds = require(Library.Client.CurrencyCmds)

-- ==========================================
-- 3. GIAO DIỆN UI TÙY CHỈNH CHO SPRING (Có Ticket & Token)
-- ==========================================
local FarmUI = {}
FarmUI.__index = FarmUI
function FarmUI.new(UIConfig)
	local Self = setmetatable({}, FarmUI)
	Self.GuiName = "EasterEventGuiV92"
	Self.Elements = {}
	Self.Parent = game:GetService("CoreGui")
    if Self.Parent:FindFirstChild(Self.GuiName) then Self.Parent[Self.GuiName]:Destroy() end

	local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = Self.GuiName; ScreenGui.IgnoreGuiInset = true; ScreenGui.Parent = Self.Parent; ScreenGui.ResetOnSpawn = false
	local Background = Instance.new("Frame", ScreenGui); Background.BackgroundColor3 = Color3.fromRGB(15, 15, 15); Background.BorderColor3 = Color3.fromRGB(0, 255, 150); Background.BorderMode = Enum.BorderMode.Inset; Background.Size = UDim2.new(1, 0, 1, 0); Background.Position = UDim2.new(0.5, 0, 0.5, 0); Background.AnchorPoint = Vector2.new(0.5, 0.5)
	local Container = Instance.new("Frame", Background); Container.Size = UDim2.new(1, 0, 1, 0); Container.BackgroundTransparency = 1; Self.Container = Container
	local Layout = Instance.new("UIListLayout", Container); Layout.Padding = UDim.new(0.015, 0); Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; Layout.VerticalAlignment = Enum.VerticalAlignment.Center; Layout.SortOrder = Enum.SortOrder.LayoutOrder

    local ToggleBtn = Instance.new("TextButton", ScreenGui); ToggleBtn.Size = UDim2.new(0, 45, 0, 45); ToggleBtn.Position = UDim2.new(1, -20, 1, -20); ToggleBtn.AnchorPoint = Vector2.new(1, 1); ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15); ToggleBtn.Text = "👁"; ToggleBtn.TextSize = 22; Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
    ToggleBtn.MouseButton1Click:Connect(function() Background.Visible = not Background.Visible; ToggleBtn.Text = Background.Visible and "👁" or "🙈" end)

	local Sorted = {}
	for Name, Data in pairs(UIConfig.UI) do table.insert(Sorted, {Name = Name, Order = Data[1], Text = Data[2], Size = Data[3]}) end
	table.sort(Sorted, function(A, B) return A.Order < B.Order end)

	for Index, Item in ipairs(Sorted) do
		local Label = Instance.new("TextLabel", Self.Container)
		Label.Name = Item.Name; Label.LayoutOrder = Item.Order; Label.Size = Item.Size and UDim2.new(unpack(Item.Size)) or UDim2.new(0.7, 0, 0.055, 0)
		Label.BackgroundTransparency = 1; Label.Font = Enum.Font.FredokaOne; Label.Text = Item.Text; Label.TextColor3 = Color3.fromRGB(255, 255, 255); Label.TextScaled = true; Label.RichText = true
		Self.Elements[Item.Name] = Label
		if Index < #Sorted then
			local Spacer = Instance.new("Frame", Self.Container); Spacer.LayoutOrder = Item.Order + 0.5; Spacer.BackgroundColor3 = Color3.fromRGB(0, 255, 150); Spacer.Size = UDim2.new(0.6, 0, 0, 2)
		end
	end
	return Self
end

function FarmUI:SetText(Name, Text) if self.Elements[Name] then task.defer(function() self.Elements[Name].Text = Text end) end end

local UI = FarmUI.new({
    UI = {
        ["Title"]           = {1, "🐰 EASTER EVENT V92 🐰", {0.8, 0, 0.08, 0}},
        ["ModeInfo"]        = {2, "Mode: " .. Mode},
        ["Time"]            = {3, "Time: 00:00:00 | Time Left: 00:00"},
        ["EggsHatched"]     = {4, "Total Eggs: 0 | ⚡ Speed: 0/sec"},
        ["Tokens"]          = {5, "Token B/R/S/T: 0/0/0/0"},
        ["EggTokens"]       = {6, "Spring Egg Token: 0"},
        ["Tickets"]         = {7, "Tickets: 0 / 0 (0%)"},
        ["FPS"]             = {8, "FPS: 60"}
    }
})

-- ==========================================
-- 4. LUỒNG XỬ LÝ DỮ LIỆU SỰ KIỆN (DATA UPDATER & AUTO LUCK)
-- ==========================================
local TrueFPS = 60
RunService.RenderStepped:Connect(function(deltaTime) TrueFPS = math.floor(1 / deltaTime) end)

local StartTime = os.time()
local StartEggs = 0
pcall(function() StartEggs = Save.Get().Easter2026EggsHatched or 0 end)

local function ParseValue(str)
    if not str then return 0 end
    str = tostring(str):lower():gsub("<[^>]+>", ""):gsub(",", ""):gsub("%s+", "")    
    local numStr, suffix = str:match("[%d%.]+"), str:match("[%a]+")
    local num = tonumber(numStr) or 0
    if suffix == "k" then return num * 1000 elseif suffix == "m" then return num * 1000000 elseif suffix == "b" then return num * 1000000000 elseif suffix == "t" then return num * 1000000000000 end
    return num
end

local function FormatValue(Value)
    local n = tonumber(Value)
    if not n then return tostring(Value) end
    local suffixes, index, absNumber = {"", "k", "m", "b", "t"}, 1, math.abs(n)
    while absNumber >= 1000 and index < #suffixes do absNumber = absNumber / 1000; index = index + 1 end
    return (absNumber >= 1 and index > 1) and string.format("%.2f", absNumber):gsub("%.00$", "") .. suffixes[index] or tostring(math.floor(absNumber)) .. suffixes[index]
end

local lastEggs = StartEggs
task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            local save = Save.Get()
            local realClientTickets, realTotalTickets = 0, 1
            
            pcall(function()
                local easterGui = Player.PlayerGui:FindFirstChild("EasterEggZoneMain")
                if easterGui and easterGui:FindFirstChild("SideInfo") and easterGui.SideInfo:FindFirstChild("Tickets") then
                    for _, lbl in pairs(easterGui.SideInfo.Tickets:GetChildren()) do
                        if lbl:IsA("TextLabel") and not lbl.Text:lower():find("earned") then realClientTickets = ParseValue(lbl.Text) end
                    end
                end
            end)

            pcall(function()
                local container = Workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER")
                local closestBoard = container and container:FindFirstChild("Active") and container.Active:FindFirstChild("RaffleBoard", true)
                if closestBoard then
                    local totalText = closestBoard:FindFirstChild("TotalTickets", true)
                    if totalText and totalText:FindFirstChild("Amount") then
                        local parsed = ParseValue(totalText.Amount.Text)
                        if parsed > 0 and parsed ~= 999000 then realTotalTickets = parsed end
                    end
                    if realClientTickets == 0 then
                        local clientText = closestBoard:FindFirstChild("ClientTickets", true)
                        if clientText and clientText:FindFirstChild("Amount") then
                            local parsedClient = ParseValue(clientText.Amount.Text)
                            if parsedClient > 0 and parsedClient ~= 999000 then realClientTickets = parsedClient end
                        end
                    end
                end
            end)
            
            local chance = realTotalTickets > 0 and (realClientTickets / realTotalTickets) * 100 or 0
            UI:SetText("Tickets", string.format("Ticket: %s / %s (%.6f%%)", FormatValue(realClientTickets), FormatValue(realTotalTickets), chance))
            
            local currentEggs = save.Easter2026EggsHatched or StartEggs
            local hatchedThisSession = math.max(0, currentEggs - StartEggs)
            local speed = currentEggs - lastEggs + 1
            lastEggs = currentEggs
            UI:SetText("EggsHatched", string.format("Total Eggs: %s | <font color='%s'>⚡ Speed: %d/s</font>", FormatValue(hatchedThisSession), (speed > 5) and "#ff3232" or "#ffff00", speed))

            local b, r, s, t, eggToken = 0, 0, 0, 0, 0
            if save and save.Inventory then 
                local function countItem(k1, k2)
                    local total = 0
                    for _, catName in ipairs({"Currency", "Misc"}) do
                        local cat = save.Inventory[catName]
                        if type(cat) == "table" then
                            for _, item in pairs(cat) do
                                if type(item.id) == "string" then
                                    local idStr = item.id:lower()
                                    if idStr:match(k1) and (not k2 or idStr:match(k2)) then total = total + (item._am or 1) end
                                end
                            end
                        end
                    end
                    return total
                end
                b = countItem("bluebell"); r = countItem("rose"); s = countItem("sunflower"); t = countItem("tulip"); eggToken = countItem("spring", "egg")
            end

            UI:SetText("Tokens", string.format("Token B/R/S/T: %s/%s/%s/%s", FormatValue(b), FormatValue(r), FormatValue(s), FormatValue(t)))
            UI:SetText("EggTokens", "Spring Egg Token: " .. FormatValue(eggToken))
            UI:SetText("FPS", "FPS: " .. tostring(TrueFPS))
        end)
    end
end)

-- 🎰 SMART EVENT LUCK (DRIP-FEED)
if UserSettings.AutoEventLuck and UserSettings.AutoEventLuck.Enabled then
    task.spawn(function()
        while task.wait(5) do
            pcall(function()
                local save = Save.Get()
                if not save then return end
                local tracks = save.Easter2026ChanceMachineTracks or {}
                
                for _, typeKey in ipairs(UserSettings.AutoEventLuck.Type) do
                    local expireTime = tracks[typeKey] or 0
                    if (expireTime - os.time()) < 19800 then
                        local b, r, s, t = 0, 0, 0, 0
                        if save.Inventory then
                            for _, catName in ipairs({"Currency", "Misc"}) do
                                if type(save.Inventory[catName]) == "table" then
                                    for _, item in pairs(save.Inventory[catName]) do
                                        local idStr = (item.id or ""):lower()
                                        if idStr:match("bluebell") then b = b + (item._am or 1)
                                        elseif idStr:match("rose") then r = r + (item._am or 1)
                                        elseif idStr:match("sunflower") then s = s + (item._am or 1)
                                        elseif idStr:match("tulip") then t = t + (item._am or 1) end
                                    end
                                end
                            end
                        end
                        local tokens = { {name="Bluebell", amt=b}, {name="Rose", amt=r}, {name="Sunflower", amt=s}, {name="Tulip", amt=t} }
                        table.sort(tokens, function(x, y) return x.amt > y.amt end)
                        
                        local bestToken = tokens[1]
                        local amt = math.min(1000, bestToken.amt)
                        if amt > 0 then
                            Network.Invoke("Easter2026ChanceMachine_AddTime", typeKey, bestToken.name, amt)
                            Network.Invoke("Instancing_InvokeCustomFromClient", "EasterHatchEvent", "Easter2026ChanceMachine_AddTime", typeKey, bestToken.name, amt)
                            task.wait(3) 
                        end
                    end
                end
            end)
        end
    end)
end

-- ==========================================
-- 5. BỔ SUNG: MỞ KHÓA TRỨNG BẰNG SPRING EGG TOKEN (SPRING CUSTOM LOGIC)
-- ==========================================
local SpringEggUnlocks = { { number = 2, cost = 300 }, { number = 3, cost = 1500 }, { number = 4, cost = 6000 }, { number = 5, cost = 20000 } }

if UserSettings.AutoUpgrade ~= false then
    task.spawn(function()
        while task.wait(5) do
            pcall(function()
                local save = Save.Get()
                if save then
                    local eggToken = 0
                    if save.Inventory and save.Inventory.Misc then 
                        for _, item in pairs(save.Inventory.Misc) do 
                            local idStr = (item.id or ""):lower()
                            if idStr:match("spring") and idStr:match("egg") then eggToken = eggToken + (item._am or 1) end 
                        end 
                    end
                    if eggToken == 0 then eggToken = type(CurrencyCmds.Get("SpringEggTokens")) == "number" and CurrencyCmds.Get("SpringEggTokens") or 0 end
                    
                    local currentUnlocked = save.Easter2026UnlockedEggs or 1
                    local activeEgg = save.Easter2026ActiveEgg or 1
                    
                    for _, egg in ipairs(SpringEggUnlocks) do
                        if egg.number > currentUnlocked and eggToken >= egg.cost then 
                            Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "PurchaseEgg", egg.number)
                            task.wait(0.5)
                            Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "SelectEgg", egg.number)
                            break 
                        elseif egg.number == currentUnlocked and activeEgg ~= currentUnlocked then
                            Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "SelectEgg", currentUnlocked)
                        end
                    end
                end
            end)
        end
    end)
end

-- ==========================================
-- 6. BẺ KHÓA COOLDOWN TRỨNG (Chỉ dùng cho Hatch Event)
-- ==========================================
task.spawn(function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            pcall(function()
                if rawget(v, "HatchDelay") and type(rawget(v, "HatchDelay")) == "number" then rawset(v, "HatchDelay", 0) end
                if rawget(v, "OpenSpeed") and type(rawget(v, "OpenSpeed")) == "number" then rawset(v, "OpenSpeed", 0) end
            end)
        end
    end
end)
local oldTaskWait
oldTaskWait = hookfunction(task.wait, function(time)
    if time and type(time) == "number" and time > 0 and time < 3 then
        local callStack = debug.traceback()
        if callStack:lower():match("egg") or callStack:lower():match("hatch") then return oldTaskWait(0.01) end
    end
    return oldTaskWait(time)
end)

-- ==========================================
-- 7. VÒNG LẶP SỰ KIỆN CHÍNH (FARM & HATCH LOGIC)
-- ==========================================
local _G_DynamicHubCF = CFrame.new(-18581.56, 17.03, -29110.16)
local FarmOffset = Vector3.new(53.53, 0, 0.62)
local HatchZoneCF = CFrame.new(-18514.40, 16.24, -29111.44)

local SafePart = Instance.new("Part", Workspace)
SafePart.Size = Vector3.new(25, 1, 25); SafePart.Anchored = true; SafePart.Transparency = 0.8; SafePart.Material = Enum.Material.Glass; SafePart.BrickColor = BrickColor.new("Toothpaste")
local function TeleportPlayer(cf)
    local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if root and cf then
        root.Anchored = false; root.CFrame = cf + Vector3.new(0, 1.5, 0)
        SafePart.CFrame = cf - Vector3.new(0, 1.5, 0); root.Velocity = Vector3.new(0,0,0)
    end
end

local State = { Phase = (Mode == "HatchOnly") and "HATCHING" or "FARMING", TimeLeft = (Mode == "HatchOnly") and math.huge or (math.max(20, FarmTimeMinutes) * 60), CurrentPortal = 1, IsReady = false }
_G.CurrentPhase = State.Phase
_G.FarmReady = false

-- Luồng Hatch
task.spawn(function()
    while true do
        if _G.CurrentPhase == "HATCHING" and AutoHatch then
            task.spawn(function() pcall(function() Network.Invoke("Instancing_InvokeCustomFromClient", "EasterHatchEvent", "HatchRequest") end) end)
            task.spawn(function() pcall(function() Network.Invoke("EasterHatchEvent", "HatchRequest") end) end)
            task.wait(0.1) 
        else task.wait(0.5) end
    end
end)

-- Luồng Farm (Gọi Tầng 3 - Framework)
task.spawn(function()
    while task.wait(0.05) do
        if _G.CurrentPhase == "FARMING" and _G.FarmReady then
            pcall(function() PS99.FastFarm(85) end)
            pcall(function() PS99.ClickAura(75) end)
            pcall(function() PS99.CollectDrops() end)
        end
    end
end)

-- Vòng lặp State Machine & Portal
task.spawn(function()
    local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if root then root.Anchored = true end
    local retries = 0
    while InstancingCmds.GetInstanceID() ~= "EasterHatchEvent" and retries < 5 do pcall(function() setthreadidentity(2); InstancingCmds.Enter("EasterHatchEvent"); setthreadidentity(8) end); task.wait(1.5); retries = retries + 1 end
    root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if root then root.Anchored = false end
    
    local currentEnchantPhase = ""

    while task.wait(1) do
        State.TimeLeft = State.TimeLeft - 1
        if State.TimeLeft <= 0 then
            State.IsReady = false; _G.FarmReady = false
            if Mode == "Combine" then 
                if State.Phase == "FARMING" then State.Phase = "HATCHING"; State.TimeLeft = HatchTimeMinutes * 60; State.CurrentPortal = (State.CurrentPortal % 4) + 1 
                else State.Phase = "FARMING"; State.TimeLeft = math.max(20, FarmTimeMinutes) * 60 end
            elseif Mode == "FarmOnly" then State.Phase = "FARMING"; State.TimeLeft = math.max(20, FarmTimeMinutes) * 60; State.CurrentPortal = (State.CurrentPortal % 4) + 1
            elseif Mode == "HatchOnly" then State.Phase = "HATCHING"; State.TimeLeft = math.huge end
            _G.CurrentPhase = State.Phase
        end

        if currentEnchantPhase ~= State.Phase then
            currentEnchantPhase = State.Phase
            if State.Phase == "FARMING" and UserSettings.EquipEnchants and UserSettings.EquipEnchants.Farm then PS99.EquipEnchants(UserSettings.EquipEnchants.Farm)
            elseif State.Phase == "HATCHING" and UserSettings.EquipEnchants and UserSettings.EquipEnchants.Hatch then PS99.EquipEnchants(UserSettings.EquipEnchants.Hatch) end
        end

        if not State.IsReady then
            if State.Phase == "FARMING" then 
                _G.FarmReady = false; _G.CurrentFarmCF = nil
                local serverZoneID = State.CurrentPortal + 1 
                pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ZonePortal", serverZoneID) end)
                task.wait(1.5)
                local r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if r and (r.Position - _G_DynamicHubCF.Position).Magnitude > 50 then
                    _G.CurrentFarmCF = CFrame.new(r.Position + FarmOffset)
                    TeleportPlayer(_G.CurrentFarmCF); task.wait(0.5); _G.FarmReady = true; State.IsReady = true
                else
                    State.CurrentPortal = 1; pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ZonePortal", 2) end); task.wait(1.5)
                    local r2 = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    if r2 and (r2.Position - _G_DynamicHubCF.Position).Magnitude > 50 then
                        _G.CurrentFarmCF = CFrame.new(r2.Position + FarmOffset)
                        TeleportPlayer(_G.CurrentFarmCF); task.wait(0.5); _G.FarmReady = true; State.IsReady = true
                    else
                        UI:SetText("ModeInfo", "Portals Locked! Force Hatching..."); State.Phase = "HATCHING"; _G.CurrentPhase = State.Phase; State.TimeLeft = 60
                        pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ReturnToHub") end); task.wait(1.5); TeleportPlayer(HatchZoneCF); State.IsReady = true
                    end
                end
            else 
                _G.FarmReady = false
                pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ReturnToHub") end)
                task.wait(2); TeleportPlayer(HatchZoneCF); State.IsReady = true 
            end
        end

        if State.IsReady then
            local rPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if rPart then
                if State.Phase == "FARMING" and _G.FarmReady and _G.CurrentFarmCF and (rPart.Position - _G.CurrentFarmCF.Position).Magnitude > 30 then TeleportPlayer(_G.CurrentFarmCF)
                elseif State.Phase == "HATCHING" and (rPart.Position - HatchZoneCF.Position).Magnitude > 30 then TeleportPlayer(HatchZoneCF) end
            end
        end
        
        local elapsed = os.time() - StartTime
        local timeStr = State.TimeLeft == math.huge and "Unlimited" or string.format("%02d:%02d", math.floor(State.TimeLeft/60), State.TimeLeft%60)
        UI:SetText("Time", string.format("Time: %02d:%02d:%02d | Time Left: %s", math.floor(elapsed/3600), math.floor((elapsed%3600)/60), elapsed%60, timeStr))
    end
end)

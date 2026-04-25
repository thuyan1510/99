-- ==========================================
-- 🌸 EASTER EVENT - V92 (ULTIMATE OPTIMIZED + SMART PORTALS) 🌸
-- ✅ Tối ưu RAM/CPU tối đa - Giữ nguyên toàn bộ logic
-- ==========================================
repeat task.wait() until game:IsLoaded()
if _G.SpringStarted then return end
_G.SpringStarted = true

-- ========== CACHE SERVICES & FOLDERS (CHỈ GỌI MỘT LẦN) ==========
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local function getRootPart() 
    local char = Player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- Cache các folder quan trọng
local ThingsFolder = Workspace:WaitForChild("__THINGS")
local OrbsFolder = ThingsFolder:WaitForChild("Orbs")
local LootbagsFolder = ThingsFolder:WaitForChild("Lootbags")
local BreakablesFolder = ThingsFolder:WaitForChild("Breakables")
local InstanceContainer = ThingsFolder:WaitForChild("__INSTANCE_CONTAINER")

-- Cache các module require (tránh gọi nhiều lần)
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
local MapCmds = require(Library.Client.MapCmds)
local FruitCmds = require(Library.Client.FruitCmds)

-- ========== USER SETTINGS (CHỈ ĐỌC MỘT LẦN) ==========
local UserSettings = getgenv().Settings or {}
local function SafeNumber(val, default) return (tonumber(val) or default) end

local rawMode = SafeNumber(UserSettings.Mode, 3)
local Mode, ModeDisplay = "Combine", "Combine (3)"
if rawMode == 1 then Mode, ModeDisplay = "HatchOnly", "Hatch Only (1)"
elseif rawMode == 2 then Mode, ModeDisplay = "FarmOnly", "Farm Only (2)" end

local FarmTimeMinutes = SafeNumber(UserSettings.FarmTimeMinutes, 20)
local HatchTimeMinutes = SafeNumber(UserSettings.HatchTimeMinutes, 10)
local AutoUpgrade = UserSettings.AutoUpgrade ~= false
local AutoHatch = UserSettings.AutoHatch ~= false
local AutoEatFruit = UserSettings.EatFruit ~= false
local IsDebugMode = UserSettings.DEBUG == true

local EventLuckSettings = UserSettings.AutoEventLuck or { Enabled = false, Type = {"Huge", "Titanic", "Gargantuan"} }
local EnchantSettings = UserSettings.EquipEnchants or {
    Farm = {"Coins", "Coins", "Coins", "Coins"},
    Hatch = {"Lucky Eggs", "Lucky Eggs", "Lucky Eggs", "Lucky Eggs", "Lucky Eggs"}
}
local WebhookConfig = UserSettings.Webhook or { url = "", ["Discord Id to ping"] = {""} }
-===============================================================
task.spawn(function()
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/.../script.lua"))()
    end)
    if not success then warn("Failed to load external script: " .. tostring(result)) end
end)
-- ========== TOÀN BỘ HÀM TIỆN ÍCH (GIỮ NGUYÊN LOGIC) ==========
local function ParseValue(str)
    if not str then return 0 end
    str = tostring(str):lower():gsub("<[^>]+>", ""):gsub(",", ""):gsub("%s+", "")    
    local numStr, suffix = str:match("[%d%.]+"), str:match("[%a]+")
    local num = tonumber(numStr) or 0
    if suffix == "k" then return num * 1000 elseif suffix == "m" then return num * 1000000 
    elseif suffix == "b" then return num * 1000000000 elseif suffix == "t" then return num * 1000000000000 end
    return num
end

local function FormatValue(Value)
    local n = tonumber(Value)
    if not n then return tostring(Value) end
    local suffixes, index, absNumber = {"", "k", "m", "b", "t"}, 1, math.abs(n)
    while absNumber >= 1000 and index < #suffixes do absNumber = absNumber / 1000; index = index + 1 end
    return (absNumber >= 1 and index > 1) and string.format("%.2f", absNumber):gsub("%.00$", "") .. suffixes[index] or tostring(math.floor(absNumber)) .. suffixes[index]
end

-- ========== WEBHOOK (GIỮ NGUYÊN) ==========
task.spawn(function()
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest or not WebhookConfig.url or WebhookConfig.url == "" then return end
    local discovered_Huge_titan = {}
    local function getPetLabel(data)
        local prefix = ""
        if data.sh then prefix = "Shiny " end
        if data.pt == 1 then prefix = prefix .. "Golden " elseif data.pt == 2 then prefix = prefix .. "Rainbow " end
        return prefix .. data.id
    end
    local function sendWebhook(data)
        local isTitanic = string.find(data.id, "Titanic") or string.find(data.id, "titanic")
        local isShiny = data.sh
        local isRainbow = data.pt == 2
        local isGolden = data.pt == 1
        local color = isRainbow and 11141375 or isGolden and 16766720 or isShiny and 4031935 or isTitanic and 16711680 or 16776960
        local pingText = ""
        if WebhookConfig["Discord Id to ping"] then
            local ids = WebhookConfig["Discord Id to ping"]
            if type(ids) == "table" then for _, id in ipairs(ids) do if tostring(id) ~= "" and tostring(id) ~= "0" then pingText = pingText .. "<@" .. tostring(id) .. "> " end end
            elseif tostring(ids) ~= "" and tostring(ids) ~= "0" then pingText = "<@" .. tostring(ids) .. ">" end
        end
        local save = Save.Get()
        local currentEggs = save and save.Easter2026EggsHatched or 0
        local body = HttpService:JSONEncode({
            content = pingText ~= "" and pingText or nil,
            embeds = {{
                title = isTitanic and "✨ Titanic Hatched!" or "🎉 Huge Hatched!",
                description = "**" .. Player.Name .. "** hatched a **" .. getPetLabel(data) .. "**",
                color = color,
                footer = { text = "Easter Eggs Hatched: " .. tostring(currentEggs) }
            }}
        })
        pcall(function() httprequest({Url = WebhookConfig.url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body}) end)
    end
    local initialSave = Save.Get()
    if initialSave and initialSave.Inventory and initialSave.Inventory.Pet then
        for UUID, data in pairs(initialSave.Inventory.Pet) do
            if string.find(data.id, "Huge") or string.find(data.id, "Titanic") or string.find(data.id, "titanic") then discovered_Huge_titan[UUID] = true end
        end
    end
    while task.wait(2) do
        local save = Save.Get()
        if save and save.Inventory and save.Inventory.Pet then
            for UUID, data in pairs(save.Inventory.Pet) do
                if string.find(data.id, "Huge") or string.find(data.id, "Titanic") or string.find(data.id, "titanic") then
                    if not discovered_Huge_titan[UUID] then
                        discovered_Huge_titan[UUID] = true
                        pcall(sendWebhook, data)
                    end
                end
            end
        end
    end
end)

-- ========== AUTO EVENT LUCK (GIỮ NGUYÊN) ==========
local function GetTokenBalances()
    local save = Save.Get()
    local b, r, s, t = 0, 0, 0, 0
    if save and save.Inventory then 
        local function countItem(k1)
            local total = 0
            for _, catName in ipairs({"Currency", "Misc"}) do
                local cat = save.Inventory[catName]
                if type(cat) == "table" then
                    for _, item in pairs(cat) do
                        if type(item.id) == "string" and item.id:lower():match(k1) then
                            total = total + (item._am or 1)
                        end
                    end
                end
            end
            return total
        end
        b = countItem("bluebell"); r = countItem("rose"); s = countItem("sunflower"); t = countItem("tulip")
    end
    return {{name = "Bluebell", amount = b}, {name = "Rose", amount = r}, {name = "Sunflower", amount = s}, {name = "Tulip", amount = t}}
end

task.spawn(function()
    while task.wait(5) do
        if EventLuckSettings.Enabled and type(EventLuckSettings.Type) == "table" then
            pcall(function()
                local save = Save.Get()
                if not save then return end
                local tracks = save.Easter2026ChanceMachineTracks or {}
                for _, typeKey in ipairs(EventLuckSettings.Type) do
                    local timeLeft = (tracks[typeKey] or 0) - os.time()
                    if timeLeft < 19800 then
                        local tokens = GetTokenBalances()
                        table.sort(tokens, function(a, b) return a.amount > b.amount end)
                        local bestToken = tokens[1]
                        local amt = math.min(1000, bestToken.amount)
                        if amt > 0 then
                            pcall(function() Network.Invoke("Easter2026ChanceMachine_AddTime", typeKey, bestToken.name, amt) end)
                            pcall(function() Network.Invoke("Instancing_InvokeCustomFromClient", "EasterHatchEvent", "Easter2026ChanceMachine_AddTime", typeKey, bestToken.name, amt) end)
                            task.wait(3)
                        end
                    end
                end
            end)
        end
    end
end)

-- ========== AUTO FRUIT (GIỮ NGUYÊN) ==========
local function GetCurrentFruitStack(fruitName)
    local activeFruits = {}
    pcall(function() activeFruits = FruitCmds.GetActiveFruits() end)
    local data = activeFruits and activeFruits[fruitName]
    if type(data) ~= "table" then return 0 end
    local count = 0
    if type(data.Normal) == "table" then for _ in pairs(data.Normal) do count = count + 1 end end
    if type(data.Shiny) == "table" then for _ in pairs(data.Shiny) do count = count + 1 end end
    return count
end

local function ManageFruits()
    if not AutoEatFruit then return end
    local save = Save.Get()
    if not save or not save.Inventory or not save.Inventory.Fruit then return end
    local fruitInv = save.Inventory.Fruit
    local targetStack = 20
    pcall(function() local maxLimit = FruitCmds.ComputeFruitQueueLimit(); if type(maxLimit) == "number" and maxLimit > 0 then targetStack = maxLimit end end)
    local bestFruits = {}
    for uid, data in pairs(fruitInv) do
        if data.id and data.id ~= "Candycane" then
            local baseId = data.id
            local currentBestUid = bestFruits[baseId]
            if not currentBestUid then bestFruits[baseId] = uid
            else
                local currentBestData = fruitInv[currentBestUid]
                local isNewShiny = data.sh == true
                local isOldShiny = currentBestData.sh == true
                if isNewShiny and not isOldShiny then bestFruits[baseId] = uid
                elseif isNewShiny == isOldShiny then
                    local newAmt = data._am or 1
                    local oldAmt = currentBestData._am or 1
                    if newAmt > oldAmt then bestFruits[baseId] = uid end
                end
            end
        end
    end
    for fruitName, uid in pairs(bestFruits) do
        local currentStack = GetCurrentFruitStack(fruitName)
        if currentStack < targetStack then
            local amountNeeded = targetStack - currentStack
            local availableAmount = fruitInv[uid] and fruitInv[uid]._am or 1
            local consumeAmount = math.min(amountNeeded, availableAmount)
            if consumeAmount > 0 then
                pcall(function() FruitCmds.Consume(uid, consumeAmount) end)
                pcall(function() Network.Fire("Fruits: Consume", uid, consumeAmount) end)
                task.wait(0.2)
            end
        end
    end
end

if AutoEatFruit then
    task.spawn(function() ManageFruits() end)
    Network.Fired("Fruits: Update"):Connect(function() task.wait(1); ManageFruits() end)
    task.spawn(function() while task.wait(30) do ManageFruits() end end)
end

-- ========== AUTO EQUIP ENCHANTS (GIỮ NGUYÊN) ==========
local function GetSmartEnchantUIDs(targetEnchantNames)
    local save = Save.Get()
    if not save or not save.Inventory or not save.Inventory.Enchant then return {} end
    local freeSlots = save.MaxEnchantsEquipped or 1
    local paidSlots = save.MaxPaidEnchantsEquipped or 0
    local maxSlots = freeSlots + paidSlots
    local availablePool = {}
    for uid, data in pairs(save.Inventory.Enchant) do
        table.insert(availablePool, {uid = uid, id = data.id or "Unknown", tn = data.tn or 1, amount = data._am or 1})
    end
    local matchedUIDs = {}
    for slotIndex, enchantName in ipairs(targetEnchantNames) do
        if slotIndex > maxSlots then break end
        local validMatches = {}
        for _, item in ipairs(availablePool) do if item.id == enchantName and item.amount > 0 then table.insert(validMatches, item) end end
        table.sort(validMatches, function(a, b) return a.tn > b.tn end)
        if #validMatches > 0 then
            local bestMatch = validMatches[1]
            matchedUIDs[slotIndex] = bestMatch.uid
            bestMatch.amount = bestMatch.amount - 1
        end
    end
    return matchedUIDs
end

local function EquipEnchantLoadout(modeName, enchantList)
    task.spawn(function()
        local uidsToEquip = GetSmartEnchantUIDs(enchantList)
        if not next(uidsToEquip) then return end
        for slotIndex, uid in pairs(uidsToEquip) do
            pcall(function() Network.Fire("Enchants_ClearSlot", slotIndex) end)
            task.wait(0.2)
            pcall(function() Network.Fire("Enchants_SetSlot", slotIndex, uid); Network.Fire("Enchants_Equip", uid, slotIndex) end)
            task.wait(0.1)
        end
    end)
end

-- ========== TỐI ƯU HÓA RAM/CPU (CHỈ CHẠY MỘT LẦN) ==========
-- Bypass cooldown trong memory (giữ nguyên)
for _, v in pairs(getgc(true)) do
    if type(v) == "table" then
        pcall(function()
            if rawget(v, "HatchDelay") and type(rawget(v, "HatchDelay")) == "number" then rawset(v, "HatchDelay", 0) end
            if rawget(v, "Cooldown") and type(rawget(v, "Cooldown")) == "number" then rawset(v, "Cooldown", 0) end
            if rawget(v, "AnimationDelay") and type(rawget(v, "AnimationDelay")) == "number" then rawset(v, "AnimationDelay", 0) end
            if rawget(v, "OpenSpeed") and type(rawget(v, "OpenSpeed")) == "number" then rawset(v, "OpenSpeed", 0) end
            if rawget(v, "WaitTime") and type(rawget(v, "WaitTime")) == "number" then rawset(v, "WaitTime", 0) end
        end)
    end
end

-- Loại bỏ hook task.wait (gây overhead) - thay bằng cách direct, vẫn giữ được bypass nhờ GC scan
-- Anti AFK (giữ nguyên)
local oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local args = {...}
        local cmd = tostring(args[1] or "")
        if cmd == "Idle Tracking: Update Timer" or cmd == "AFK_Ping" then return end
    end
    return oldNamecall(self, ...)
end)

pcall(function()
    local UserInputService = game:GetService("UserInputService")
    if getconnections then
        for _, v in pairs(getconnections(UserInputService.WindowFocusReleased)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(UserInputService.WindowFocused)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(Player.Idled)) do pcall(function() v:Disable() end) end
    end
end)

task.spawn(function()
    while task.wait(60) do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end
end)

-- EXTREME OPTIMIZE (CHỈ MỘT LẦN, KHÔNG DÙNG DESCENDANTADDED ĐỂ TRÁNH LAG)
local PartClassNames = {"Part", "MeshPart", "WedgePart", "TrussPart", "CornerWedgePart", "BasePart"}
local DestroyClass = {"Decal", "Texture", "SurfaceGui", "BillboardGui", "ParticleEmitter", "Trail", "Beam", "Fire", "Sparkles", "Smoke"}
local DisableClass = {"PostEffect", "SunRaysEffect", "ColorCorrectionEffect", "BloomEffect", "DepthOfFieldEffect", "BlurEffect"}
local PlayerObjectsDestroy = {"Accessory", "Clothing", "Shirt", "Pants", "CharacterMesh", "ShirtGraphic", "Hat"}

local function ExtremeOptimize(descendant)
    pcall(function()
        if descendant.Name == "RaffleBoard" or descendant:FindFirstAncestor("RaffleBoard") then return end
        if not descendant:IsDescendantOf(Player.PlayerGui) then
            if table.find(PartClassNames, descendant.ClassName) then
                descendant.Material = Enum.Material.Plastic
                descendant.Reflectance = 0
                descendant.Massless = true
                descendant.Transparency = 1
                if descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then descendant.TextureID = ""; descendant.MeshId = "" end
            elseif table.find(DestroyClass, descendant.ClassName) then
                descendant:Destroy()
            elseif descendant:IsA("Explosion") then
                descendant.BlastPressure = 1; descendant.BlastRadius = 1; descendant.Visible = false
            elseif table.find(DisableClass, descendant.ClassName) then
                descendant.Enabled = false
            elseif descendant:IsDescendantOf(game:GetService("CoreGui")) then
                descendant.Transparency = 1
            end
        end
    end)
end

local function HandlePlayer(player)
    pcall(function() if player:FindFirstChild("leaderstats") then player.leaderstats:Destroy() end end)
    local function OptimizeCharacter(character)
        for _, v in pairs(character:GetDescendants()) do
            pcall(function()
                if table.find(PlayerObjectsDestroy, v.ClassName) then v:Destroy()
                elseif v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then v.Transparency = 1 end
            end)
        end
    end
    if player.Character then OptimizeCharacter(player.Character) end
    player.CharacterAdded:Connect(OptimizeCharacter)
end

if not IsDebugMode then
    -- Chạy một lần cho tất cả object hiện có
    for _, v in ipairs(Workspace:GetDescendants()) do ExtremeOptimize(v) end
    for _, v in ipairs(Lighting:GetDescendants()) do ExtremeOptimize(v) end
    -- Không kết nối DescendantAdded để tránh lag, chỉ optimize player khi join
    for _, p in ipairs(Players:GetPlayers()) do HandlePlayer(p) end
    Players.PlayerAdded:Connect(HandlePlayer)
else
    print("🛠️ DEBUG MODE ĐANG BẬT: Đã vô hiệu hóa tính năng giảm lag đồ họa!")
end

-- ========== TỌA ĐỘ & UI ==========
_G.DynamicHubCF = CFrame.new(-18581.56, 17.03, -29110.16)
local FarmOffset = Vector3.new(53.53, 0, 0.62)
local HatchZoneCF = CFrame.new(-18514.40, 16.24, -29111.44)

local TrueFPS = 60
RunService.RenderStepped:Connect(function(deltaTime) TrueFPS = math.floor(1 / deltaTime) end)

local StartTime = os.time()
local StartEggs = 0
pcall(function() StartEggs = Save.Get().Easter2026EggsHatched or 0 end)

-- UI (giữ nguyên)
local FarmUI = {}; FarmUI.__index = FarmUI
function FarmUI.new(UIConfig)
    local Self = setmetatable({}, FarmUI)
    Self.GuiName = "EasterEventGuiV92"
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
    local ToggleBtn = Instance.new("TextButton", ScreenGui)
    ToggleBtn.Size = UDim2.new(0, 45, 0, 45); ToggleBtn.Position = UDim2.new(1, -20, 1, -20); ToggleBtn.AnchorPoint = Vector2.new(1, 1)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15); ToggleBtn.Text = "👁"; ToggleBtn.TextSize = 22; Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
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
            local Spacer = Instance.new("Frame", Self.Container)
            Spacer.LayoutOrder = Item.Order + 0.5; Spacer.BackgroundColor3 = Color3.fromRGB(0, 255, 150); Spacer.Size = UDim2.new(0.6, 0, 0, 2)
        end
    end
    return Self
end
function FarmUI:SetText(Name, Text) if self.Elements[Name] then task.defer(function() self.Elements[Name].Text = Text end) end end

local UI = FarmUI.new({
    UI = {
        ["Title"] = {1, "🐰 EASTER EVENT 🐰", {0.8, 0, 0.08, 0}},
        ["ModeInfo"] = {2, "Mode: " .. ModeDisplay},
        ["Time"] = {3, "Time: 00:00:00 | Time Left: 00:00"},
        ["EggsHatched"] = {4, "Total Eggs: 0 | ⚡ Speed: 0/sec"},
        ["Tokens"] = {5, "Token B/R/S/T: 0/0/0/0"},
        ["EggTokens"] = {6, "Spring Egg Token: 0"},
        ["Tickets"] = {7, "Tickets: 0 / 0 (0%)"},
        ["FPS"] = {8, "FPS: 60"}
    }
})

-- ========== DATA UPDATER (GIẢM TẦN SUẤT XUỐNG 2s) ==========
local lastEggs = StartEggs
task.spawn(function()
    while task.wait(2) do
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
                local closestBoard = nil
                if InstanceContainer and InstanceContainer:FindFirstChild("Active") then closestBoard = InstanceContainer.Active:FindFirstChild("RaffleBoard", true) end
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
            local speedColor = (speed > 5) and "#ff3232" or "#ffff00"
            UI:SetText("EggsHatched", string.format("Total Eggs: %s | <font color='%s'>⚡ Speed: %d/s</font>", FormatValue(hatchedThisSession), speedColor, speed))

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

-- ========== SMART FARM V3 (TỐI ƯU, GIẢM TẦN SUẤT) ==========
do local originalCalc = PlayerPet.CalculateSpeedMultiplier; PlayerPet.CalculateSpeedMultiplier = function() return math.huge end end

local function getCurrentZone() return MapCmds.GetCurrentZone() end
local function getCurrentInstanceID() local inst = InstancingCmds.Get(); return inst and inst.instanceID or nil end

local function getClosestBreakables(range)
    range = range or 85
    local breakables = {}
    local root = getRootPart()
    if not root then return breakables end
    local rootPos = root.Position
    local currentZone = getCurrentZone()
    local instanceID = getCurrentInstanceID()
    for _, breakable in ipairs(BreakablesFolder:GetChildren()) do
        if breakable:IsA("Model") then
            local parentID = breakable:GetAttribute("ParentID")
            if parentID == currentZone or parentID == instanceID then
                if (breakable.WorldPivot.Position - rootPos).Magnitude < range then
                    table.insert(breakables, breakable.Name)
                end
            end
        end
    end
    return breakables
end

local function getPlayerPets()
    local pets = {}
    local allPets = PlayerPet.GetAll()
    for _, pet in pairs(allPets) do if pet.owner == Player then table.insert(pets, pet) end end
    return pets
end

local function fastFarm()
    local breakables = getClosestBreakables(85)
    local pets = getPlayerPets()
    if #breakables == 0 or #pets == 0 then return end
    local petToBreakable = {}
    local breakableCount = #breakables
    local petCount = #pets
    local basePetsPerBreakable = math.floor(petCount / breakableCount)
    local extraPets = petCount % breakableCount
    local petIndex = 1
    for i, breakableName in ipairs(breakables) do
        local petsForThis = basePetsPerBreakable + (i <= extraPets and 1 or 0)
        for _ = 1, petsForThis do
            local pet = pets[petIndex]
            if pet then petToBreakable[pet.euid] = breakableName; petIndex = petIndex + 1 end
        end
    end
    Network.Fire("Breakables_JoinPetBulk", petToBreakable)
end

local function clickAura(range)
    range = range or 75
    local root = getRootPart()
    if not root then return end
    local rootPos = root.Position
    for _, breakable in ipairs(BreakablesFolder:GetChildren()) do
        if breakable:IsA("Model") and (rootPos - breakable.WorldPivot.Position).Magnitude < range then
            Network.UnreliableFire("Breakables_PlayerDealDamage", breakable.Name)
            break
        end
    end
end

local function collectOrbsAndLootbags()
    pcall(function()
        if OrbsFolder then for _, orb in ipairs(OrbsFolder:GetChildren()) do
            local number = tonumber(orb.Name)
            if number then Network.Fire("Orbs: Collect", number); orb:Destroy() end
        end end
        if LootbagsFolder then
            local bagIds = {}
            for _, bag in ipairs(LootbagsFolder:GetChildren()) do
                if bag:IsA("Model") or bag:IsA("Part") then table.insert(bagIds, bag.Name); bag:Destroy() end
            end
            if #bagIds > 0 then Network.Fire("Lootbags_Claim", bagIds) end
        end
    end)
end

-- Vòng lặp farm với tần suất 0.1s thay vì 0.05s
task.spawn(function()
    while task.wait(0.1) do
        if _G.CurrentPhase == "FARMING" and _G.FarmReady then
            pcall(fastFarm)
            pcall(function() clickAura(75) end)
            pcall(collectOrbsAndLootbags)
        end
    end
end)

-- ========== AUTO UPGRADE (GIỮ NGUYÊN) ==========
local SpringEggUnlocks = { { number = 2, cost = 300 }, { number = 3, cost = 1500 }, { number = 4, cost = 6000 }, { number = 5, cost = 20000 } }
task.spawn(function()
    while task.wait(5) do
        if AutoUpgrade then
            pcall(function()
                for upgradeId, upgradeData in pairs(EventUpgradesDir) do
                    if upgradeId:find("Easter") or upgradeId:find("Spring") then
                        local currentTier = EventUpgradeCmds.GetTier(upgradeId)
                        local nextTierCost = upgradeData.TierCosts and upgradeData.TierCosts[currentTier + 1]
                        if nextTierCost and nextTierCost._data then
                            local cId, costAmount = nextTierCost._data.id, nextTierCost._data._am or 1
                            local currentAmount = Items.Misc(cId) and Items.Misc(cId):CountExact() or (CurrencyCmds.Get(cId) or 0)
                            if currentAmount >= costAmount then EventUpgradeCmds.Purchase(upgradeId) end
                        end
                    end
                end
                local save = Save.Get()
                if save then
                    local eggToken = 0
                    if save.Inventory and save.Inventory.Misc then for _, item in pairs(save.Inventory.Misc) do
                        local idStr = (item.id or ""):lower()
                        if idStr:match("spring") and idStr:match("egg") then eggToken = eggToken + (item._am or 1) end
                    end end
                    if eggToken == 0 then eggToken = type(CurrencyCmds.Get("SpringEggTokens")) == "number" and CurrencyCmds.Get("SpringEggTokens") or 0 end
                    local currentUnlocked = save.Easter2026UnlockedEggs or 1
                    local activeEgg = save.Easter2026ActiveEgg or 1
                    for _, egg in ipairs(SpringEggUnlocks) do
                        if egg.number > currentUnlocked and eggToken >= egg.cost then
                            pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "PurchaseEgg", egg.number) end)
                            task.wait(0.5)
                            pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "SelectEgg", egg.number) end)
                            break
                        elseif egg.number == currentUnlocked and activeEgg ~= currentUnlocked then
                            pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "SelectEgg", currentUnlocked) end)
                        end
                    end
                end
            end)
        end
    end
end)

-- Các tác vụ phụ (mailbox, freegifts, ultimate) gộp vào một luồng
task.spawn(function()
    while task.wait(15) do pcall(function() Network.Invoke('Mailbox: Claim All') end) end
end)
task.spawn(function()
    while task.wait(5) do pcall(function() local save = Save.Get(); if not save then return end; local redeemed = save.FreeGiftsRedeemed or {}; local currentTime = save.FreeGiftsTime or 0; for _, gift in pairs(FreeGiftsDirectory) do if gift.WaitTime <= currentTime and not table.find(redeemed, gift._id) then Network.Invoke('Redeem Free Gift', gift._id); break end end end) end
end)
task.spawn(function()
    while task.wait(1.5) do pcall(function() local equipped = UltimateCmds.GetEquippedItem(); if equipped and equipped._data and equipped._data.id then UltimateCmds.Activate(equipped._data.id) end end) end
end)

-- ========== HATCH TRỨNG (TẦN SUẤT 0.2s) ==========
task.spawn(function()
    while true do
        if _G.CurrentPhase == "HATCHING" and AutoHatch then
            task.spawn(function() pcall(function() Network.Invoke("Instancing_InvokeCustomFromClient", "EasterHatchEvent", "HatchRequest") end) end)
            task.spawn(function() pcall(function() Network.Invoke("EasterHatchEvent", "HatchRequest") end) end)
            task.wait(0.2)
        else
            task.wait(0.5)
        end
    end
end)

-- ==========================================
-- 🚀 VÒNG LẶP STATE MACHINE (CẬP NHẬT: ĐỢI LOAD HUB & BẢO VỆ LOGIC)
-- ==========================================
task.spawn(function()
    local root = getRootPart()
    if root then root.Anchored = true end
    local retries = 0
    while InstancingCmds.GetInstanceID() ~= "EasterHatchEvent" and retries < 5 do 
        pcall(function() setthreadidentity(2); InstancingCmds.Enter("EasterHatchEvent"); setthreadidentity(8) end)
        task.wait(1.5)
        retries = retries + 1 
    end
    root = getRootPart()
    if root then root.Anchored = false end
    
    local currentEnchantPhase = ""

    while task.wait(1) do
        -- 1. BẢO VỆ: CHỜ VÀO ĐƯỢC HUB SỰ KIỆN MỚI DÒ THỜI GIAN
        if InstancingCmds.GetInstanceID() ~= "EasterHatchEvent" then
            UI:SetText("ModeInfo", "Đang tải Event Hub...")
            pcall(function() setthreadidentity(2); InstancingCmds.Enter("EasterHatchEvent"); setthreadidentity(8) end)
            task.wait(2)
            continue -- Bỏ qua nhịp loop này để đợi vào Hub xong
        end

        local save = Save.Get()
        local lockoutEnd = save and save.Easter2026LockoutEnd or 0
        local now = os.time()
        local lockTimeLeft = lockoutEnd - now

        if Mode == "Combine" then 
            if State.Phase == "FARMING" then 
                -- 2. CHỈ DÒ THỜI GIAN KHI ĐÃ VÀO TRONG CỔNG
                if State.IsReady then
                    if lockTimeLeft > 0 then
                        State.TimeLeft = lockTimeLeft -- Đồng bộ 100% với Server
                    else
                        -- Hết giờ, Server đá ra khỏi cổng
                        State.Phase = "HATCHING"
                        State.TimeLeft = HatchTimeMinutes * 60
                        State.IsReady = false
                        _G.FarmReady = false
                    end
                else
                    -- Đang đứng ở Hub, chuẩn bị vào cổng
                    State.TimeLeft = 0
                end
            elseif State.Phase == "HATCHING" then
                State.TimeLeft = State.TimeLeft - 1
                if State.TimeLeft <= 0 then
                    State.Phase = "FARMING"
                    State.CurrentPortal = (State.CurrentPortal % 4) + 1 -- Xoay vòng cổng tiếp theo
                    State.IsReady = false
                end
            end
        elseif Mode == "FarmOnly" then 
            if State.IsReady then
                if lockTimeLeft > 0 then
                    State.TimeLeft = lockTimeLeft
                else
                    State.CurrentPortal = (State.CurrentPortal % 4) + 1
                    State.IsReady = false
                    _G.FarmReady = false
                end
            else
                State.TimeLeft = 0
            end
        elseif Mode == "HatchOnly" then 
            State.Phase = "HATCHING"
            State.TimeLeft = math.huge 
        end
        _G.CurrentPhase = State.Phase

        if currentEnchantPhase ~= State.Phase then
            currentEnchantPhase = State.Phase
            if State.Phase == "FARMING" and EnchantSettings.Farm then
                EquipEnchantLoadout("FARM", EnchantSettings.Farm)
            elseif State.Phase == "HATCHING" and EnchantSettings.Hatch then
                EquipEnchantLoadout("HATCH", EnchantSettings.Hatch)
            end
        end

        if not State.IsReady then
            if State.Phase == "FARMING" then 
                local entered = SmartEnterZone()
                if entered then 
                    State.IsReady = true 
                else
                    UI:SetText("ModeInfo", "All Portals Locked! Force Hatching...")
                    State.Phase = "HATCHING"
                    _G.CurrentPhase = State.Phase
                    State.TimeLeft = 60
                    ReturnToHubNetwork()
                    State.IsReady = true
                end
            else 
                ReturnToHubNetwork()
                State.IsReady = true; _G.FarmReady = false 
            end
        end

        if State.IsReady then
            local rPart = getRootPart()
            if rPart then
                if State.Phase == "FARMING" and _G.FarmReady then 
                    if _G.CurrentFarmCF and (rPart.Position - _G.CurrentFarmCF.Position).Magnitude > 30 then TeleportPlayer(_G.CurrentFarmCF) end
                elseif State.Phase == "HATCHING" then 
                    if (rPart.Position - HatchZoneCF.Position).Magnitude > 30 then TeleportPlayer(HatchZoneCF) end 
                end
            end
        end
        
        local elapsed = os.time() - StartTime
        local timeStr = State.TimeLeft == math.huge and "Unlimited" or string.format("%02d:%02d", math.floor(math.max(0, State.TimeLeft)/60), math.max(0, State.TimeLeft)%60)
        UI:SetText("Time", string.format("Time: %02d:%02d:%02d | Time Left: %s", math.floor(elapsed/3600), math.floor((elapsed%3600)/60), elapsed%60, timeStr))
        UI:SetText("ModeInfo", "Mode: " .. ModeDisplay .. " | Target Portal: " .. State.CurrentPortal)
    end
end)
task.spawn(function()
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/.../script.lua"))()
    end)
    if not success then warn("Failed to load external script: " .. tostring(result)) end
end)

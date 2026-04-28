-- ==========================================
-- EASTER EVENT - V93 (ZONE SELECTOR & PRO UI)
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
elseif rawMode == 2 then Mode, ModeDisplay = "FarmOnly", "Farm Only (2)" 
elseif rawMode == 4 then Mode, ModeDisplay = "Nest", "The Nest (4)"
end

-- BIEN LUU TRUNG VA CONG MUC TIEU
_G.CurrentTargetEgg = SafeNumber(UserSettings.TargetEgg, 8)
_G.CurrentTargetZone = SafeNumber(UserSettings.TargetZone, 0) -- 0 la tat ca cac cong, 1-4 la cong cu the

local FarmTimeMinutes = SafeNumber(UserSettings.FarmTimeMinutes, 20)
local HatchTimeMinutes = SafeNumber(UserSettings.HatchTimeMinutes, 10)
local AutoUpgrade = UserSettings.AutoUpgrade ~= false
local AutoHatch = UserSettings.AutoHatch ~= false
local AutoEatFruit = UserSettings.EatFruit ~= false
local IsDebugMode = UserSettings.DEBUG == true

local EventLuckSettings = UserSettings.AutoEventLuck or { Enabled = false, Type = {"Huge", "Titanic", "Gargantuan"} }
local EnchantSettings = UserSettings.EquipEnchants or { Farm = {"Coins", "Coins", "Coins", "Coins"}, Hatch = {"Lucky Eggs", "Lucky Eggs", "Lucky Eggs", "Lucky Eggs", "Lucky Eggs"} }
local WebhookConfig = UserSettings.Webhook or { url = "", ["Discord Id to ping"] = {""} }

-- CACHE CÁC DỊCH VỤ CỦA GAME
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local function getRootPart()
    local char = Player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- THƯ MỤC LƯU TRỮ VẬT THỂ
local ThingsFolder = Workspace:WaitForChild("__THINGS")
local OrbsFolder = ThingsFolder:WaitForChild("Orbs")
local LootbagsFolder = ThingsFolder:WaitForChild("Lootbags")
local BreakablesFolder = ThingsFolder:WaitForChild("Breakables")
local InstanceContainer = ThingsFolder:WaitForChild("__INSTANCE_CONTAINER")

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

-- ==========================================
-- WEBHOOK DISCORD
-- ==========================================
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
                    if not discovered_Huge_titan[UUID] then discovered_Huge_titan[UUID] = true; pcall(sendWebhook, data) end
                end
            end
        end
    end
end)

-- ==========================================
-- DONG CO AUTO EVENT LUCK
-- ==========================================
local function GetTokenBalances()
    local save = Save.Get()
    local b, r, s, t, bc = 0, 0, 0, 0, 0
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
        b = countItem("bluebell"); r = countItem("rose"); s = countItem("sunflower"); t = countItem("tulip"); bc = countItem("boss", "chest")
    end
    return { {name = "Bluebell", amount = b}, {name = "Rose", amount = r}, {name = "Sunflower", amount = s}, {name = "Tulip", amount = t}, {name = "Spring Boss Chest", amount = bc} }
end

task.spawn(function()
    while task.wait(5) do
        if EventLuckSettings.Enabled and type(EventLuckSettings.Type) == "table" then
            pcall(function()
                local save = Save.Get()
                if not save then return end
                local tracks = save.Easter2026ChanceMachineTracks or {}
                for _, typeKey in ipairs(EventLuckSettings.Type) do
                    local expireTime = tracks[typeKey] or 0
                    local timeLeft = expireTime - os.time()
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

-- ==========================================
-- SMART AUTO FRUIT
-- ==========================================
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
    pcall(function() 
        local maxLimit = FruitCmds.ComputeFruitQueueLimit()
        if type(maxLimit) == "number" and maxLimit > 0 then targetStack = maxLimit end
    end)
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
            if consumeAmount > 0 then pcall(function() FruitCmds.Consume(uid, consumeAmount) end); pcall(function() Network.Fire("Fruits: Consume", uid, consumeAmount) end); task.wait(0.2) end
        end
    end
end
if AutoEatFruit then task.spawn(function() ManageFruits() end); Network.Fired("Fruits: Update"):Connect(function() task.wait(1); ManageFruits() end); task.spawn(function() while task.wait(30) do ManageFruits() end end) end

-- ==========================================
-- DONG CO SMART AUTO EQUIP ENCHANTS
-- ==========================================
local function GetSmartEnchantUIDs(targetEnchantNames)
    local save = Save.Get()
    if not save or not save.Inventory or not save.Inventory.Enchant then return {} end
    local freeSlots = save.MaxEnchantsEquipped or 1
    local paidSlots = save.MaxPaidEnchantsEquipped or 0
    local maxSlots = freeSlots + paidSlots
    local availablePool = {}
    for uid, data in pairs(save.Inventory.Enchant) do table.insert(availablePool, {uid = uid, id = data.id or "Unknown", tn = data.tn or 1, amount = data._am or 1}) end
    local matchedUIDs = {}
    for slotIndex, enchantName in ipairs(targetEnchantNames) do
        if slotIndex > maxSlots then break end
        local validMatches = {}
        for _, item in ipairs(availablePool) do if item.id == enchantName and item.amount > 0 then table.insert(validMatches, item) end end
        table.sort(validMatches, function(a, b) return a.tn > b.tn end)
        if #validMatches > 0 then local bestMatch = validMatches[1]; matchedUIDs[slotIndex] = bestMatch.uid; bestMatch.amount = bestMatch.amount - 1 end
    end
    return matchedUIDs
end
local function EquipEnchantLoadout(modeName, enchantList)
    task.spawn(function()
        local uidsToEquip = GetSmartEnchantUIDs(enchantList)
        if not next(uidsToEquip) then return end
        for slotIndex, uid in pairs(uidsToEquip) do pcall(function() Network.Fire("Enchants_ClearSlot", slotIndex) end); task.wait(0.2); pcall(function() Network.Fire("Enchants_SetSlot", slotIndex, uid); Network.Fire("Enchants_Equip", uid, slotIndex) end); task.wait(0.1) end
    end)
end

-- ==========================================
-- MAY QUET RAM AN TOAN & CHONG LAG DO HOA
-- ==========================================
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
local oldTaskWait; oldTaskWait = hookfunction(task.wait, function(time)
    if time and type(time) == "number" and time > 0 and time < 3 then
        local callStack = debug.traceback()
        if callStack:lower():match("egg") or callStack:lower():match("hatch") then return oldTaskWait(0.01) end
    end
    return oldTaskWait(time)
end)
local oldNamecall; oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local args = {...}; local cmd = tostring(args[1] or "")
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
task.spawn(function() while task.wait(60) do pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end) end end)

local PartClassNames = {"Part", "MeshPart", "WedgePart", "TrussPart", "CornerWedgePart", "BasePart"}
local DestroyClass = {"Decal", "Texture", "SurfaceGui", "BillboardGui", "ParticleEmitter", "Trail", "Beam", "Fire", "Sparkles", "Smoke"}
local DisableClass = {"PostEffect", "SunRaysEffect", "ColorCorrectionEffect", "BloomEffect", "DepthOfFieldEffect", "BlurEffect"}
local PlayerObjectsDestroy = {"Accessory", "Clothing", "Shirt", "Pants", "CharacterMesh", "ShirtGraphic", "Hat"}
local function ExtremeOptimize(descendant)
    pcall(function()
        if descendant.Name == "RaffleBoard" or descendant:FindFirstAncestor("RaffleBoard") then return end
        if not descendant:IsDescendantOf(Player.PlayerGui) then
            if table.find(PartClassNames, descendant.ClassName) then
                descendant.Material = Enum.Material.Plastic; descendant.Reflectance = 0; descendant.Massless = true; descendant.Transparency = 1
                if descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then descendant.TextureID = ""; descendant.MeshId = "" end
            elseif table.find(DestroyClass, descendant.ClassName) then descendant:Destroy()
            elseif descendant:IsA("Explosion") then descendant.BlastPressure = 1; descendant.BlastRadius = 1; descendant.Visible = false
            elseif table.find(DisableClass, descendant.ClassName) then descendant.Enabled = false
            elseif descendant:IsDescendantOf(game:GetService("CoreGui")) then descendant.Transparency = 1 end
        end
    end)
end
local function HandlePlayer(player)
    pcall(function() if player:FindFirstChild("leaderstats") then player.leaderstats:Destroy() end end)
    local function OptimizeCharacter(character)
        for _, v in pairs(character:GetDescendants()) do
            pcall(function() if table.find(PlayerObjectsDestroy, v.ClassName) then v:Destroy() elseif v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then v.Transparency = 1 end end)
        end
    end
    if player.Character then OptimizeCharacter(player.Character) end
    player.CharacterAdded:Connect(OptimizeCharacter)
end
if not IsDebugMode then
    for _, v in ipairs(Workspace:GetDescendants()) do ExtremeOptimize(v) end; for _, v in ipairs(Lighting:GetDescendants()) do ExtremeOptimize(v) end
    Workspace.DescendantAdded:Connect(ExtremeOptimize); Lighting.DescendantAdded:Connect(ExtremeOptimize)
    for _, p in ipairs(Players:GetPlayers()) do HandlePlayer(p) end; Players.PlayerAdded:Connect(HandlePlayer)
end

-- ==========================================
-- TOA DO & HAM CHUYEN DOI CHU SO
-- ==========================================
_G.DynamicHubCF = CFrame.new(-18581.56, 17.03, -29110.16)
local FarmOffset = Vector3.new(53.53, 0, 0.62)
local HatchZoneCF = CFrame.new(-18514.40, 16.24, -29111.44)
local TrueFPS = 60
RunService.RenderStepped:Connect(function(deltaTime) TrueFPS = math.floor(1 / deltaTime) end)
local StartTime = os.time()
local StartEggs = 0; pcall(function() StartEggs = Save.Get().Easter2026EggsHatched or 0 end)

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

-- ==========================================
-- DYNAMIC UI (GOC PHAI MAN HINH, THU NHO 30%)
-- ==========================================
local FarmUI = {}
FarmUI.__index = FarmUI
function FarmUI.new(UIConfig)
	local Self = setmetatable({}, FarmUI)
	Self.GuiName = "EasterEventGuiV93"
	Self.Elements = {}
	Self.Parent = game:GetService("CoreGui")
    if Self.Parent:FindFirstChild(Self.GuiName) then Self.Parent[Self.GuiName]:Destroy() end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = Self.GuiName; ScreenGui.IgnoreGuiInset = true; ScreenGui.Parent = Self.Parent; ScreenGui.ResetOnSpawn = false
	Self.ScreenGui = ScreenGui

    -- Nen giao dien thu nho 30% va nam o goc phai
	local Background = Instance.new("Frame", ScreenGui)
	Background.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Background.BorderSizePixel = 0
	Background.Size = UDim2.new(0.35, 0, 0.5, 0)
    Background.Position = UDim2.new(0.99, 0, 0.01, 0)
    Background.AnchorPoint = Vector2.new(1, 0)
    
    local bgCorner = Instance.new("UICorner", Background); bgCorner.CornerRadius = UDim.new(0.05, 0)
    local bgStroke = Instance.new("UIStroke", Background); bgStroke.Color = Color3.fromRGB(0, 255, 150); bgStroke.Thickness = 2.5

	local Page1 = Instance.new("Frame", Background)
	Page1.Size = UDim2.new(1, 0, 1, 0); Page1.BackgroundTransparency = 1; Self.Container = Page1
	local Layout1 = Instance.new("UIListLayout", Page1)
	Layout1.Padding = UDim.new(0.02, 0); Layout1.HorizontalAlignment = Enum.HorizontalAlignment.Center; Layout1.VerticalAlignment = Enum.VerticalAlignment.Center; Layout1.SortOrder = Enum.SortOrder.LayoutOrder

    local Page2 = Instance.new("Frame", Background)
	Page2.Size = UDim2.new(1, 0, 1, 0); Page2.BackgroundTransparency = 1; Page2.Visible = false
	local Layout2 = Instance.new("UIListLayout", Page2)
	Layout2.Padding = UDim.new(0.02, 0); Layout2.HorizontalAlignment = Enum.HorizontalAlignment.Center; Layout2.VerticalAlignment = Enum.VerticalAlignment.Center

    -- Nut bat tat o goc phai
    local ToggleState = 1
    local ToggleBtn = Instance.new("TextButton", ScreenGui)
    ToggleBtn.Size = UDim2.new(0, 40, 0, 40)
    ToggleBtn.Position = UDim2.new(1, -10, 0, 10)
    ToggleBtn.AnchorPoint = Vector2.new(1, 0)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25); ToggleBtn.Text = "👁"; ToggleBtn.TextSize = 20; ToggleBtn.BorderSizePixel = 0
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
    local btnStroke = Instance.new("UIStroke", ToggleBtn); btnStroke.Color = Color3.fromRGB(0, 255, 150); btnStroke.Thickness = 2
    
    ToggleBtn.MouseEnter:Connect(function() ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45) end)
    ToggleBtn.MouseLeave:Connect(function() ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25) end)

    ToggleBtn.MouseButton1Click:Connect(function()
        ToggleState = ToggleState + 1
        if ToggleState > 3 then ToggleState = 1 end
        if ToggleState == 1 then Background.Visible = true; Page1.Visible = true; Page2.Visible = false; ToggleBtn.Text = "👁"
        elseif ToggleState == 2 then Background.Visible = true; Page1.Visible = false; Page2.Visible = true; ToggleBtn.Text = "⚙️"
        else Background.Visible = false; ToggleBtn.Text = "🙈" end
    end)

	local Sorted = {}
	for Name, Data in pairs(UIConfig.UI) do table.insert(Sorted, {Name = Name, Order = Data[1], Text = Data[2], Size = Data[3]}) end
	table.sort(Sorted, function(A, B) return A.Order < B.Order end)

	for Index, Item in ipairs(Sorted) do
		local Label = Instance.new("TextLabel", Page1)
		Label.Name = Item.Name; Label.LayoutOrder = Item.Order; Label.Size = Item.Size and UDim2.new(unpack(Item.Size)) or UDim2.new(0.8, 0, 0.055, 0)
		Label.BackgroundTransparency = 1; Label.Font = Enum.Font.FredokaOne; Label.Text = Item.Text; Label.TextColor3 = Color3.fromRGB(255, 255, 255); Label.TextScaled = true; Label.RichText = true
        local textStroke = Instance.new("UIStroke", Label); textStroke.Color = Color3.fromRGB(0, 0, 0); textStroke.Thickness = 1.5
        Self.Elements[Item.Name] = Label
		if Index < #Sorted then
			local Spacer = Instance.new("Frame", Page1); Spacer.LayoutOrder = Item.Order + 0.5; Spacer.BackgroundColor3 = Color3.fromRGB(0, 255, 150); Spacer.Size = UDim2.new(0.7, 0, 0, 2); Spacer.BorderSizePixel = 0
		end
	end

    -- CHON MODE
    local TitleMode = Instance.new("TextLabel", Page2)
    TitleMode.Size = UDim2.new(0.9, 0, 0, 20); TitleMode.BackgroundTransparency = 1; TitleMode.Font = Enum.Font.FredokaOne; TitleMode.Text = "⚙️ SELECT MODE"
    TitleMode.TextColor3 = Color3.fromRGB(0, 255, 150); TitleMode.TextScaled = true; TitleMode.LayoutOrder = 1
    Instance.new("UIStroke", TitleMode).Color = Color3.fromRGB(0,0,0); Instance.new("UIStroke", TitleMode).Thickness = 2
    local Sp1 = Instance.new("Frame", Page2); Sp1.BackgroundColor3 = Color3.fromRGB(0, 255, 150); Sp1.Size = UDim2.new(0.7, 0, 0, 2); Sp1.BorderSizePixel = 0; Sp1.LayoutOrder = 2

    local ModeFrame = Instance.new("Frame", Page2)
    ModeFrame.Size = UDim2.new(0.95, 0, 0, 75); ModeFrame.BackgroundTransparency = 1; ModeFrame.LayoutOrder = 3
    local ModeGrid = Instance.new("UIGridLayout", ModeFrame)
    ModeGrid.CellSize = UDim2.new(0.46, 0, 0, 30); ModeGrid.CellPadding = UDim2.new(0.04, 0, 0, 8); ModeGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center; ModeGrid.SortOrder = Enum.SortOrder.LayoutOrder

    local ModesData = { {id = "HatchOnly", name = "Hatch Only (1)"}, {id = "FarmOnly", name = "Farm Only (2)"}, {id = "Combine", name = "Combine (3)"}, {id = "Nest", name = "The Nest (4)"} }
    for i, m in ipairs(ModesData) do
        local Btn = Instance.new("TextButton", ModeFrame)
        Btn.LayoutOrder = i; Btn.BackgroundColor3 = (m.id == Mode) and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(35, 35, 40); Btn.BorderSizePixel = 0
        Btn.Font = Enum.Font.FredokaOne; Btn.Text = m.name; Btn.TextColor3 = Color3.fromRGB(255, 255, 255); Btn.TextScaled = true
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0.2, 0)
        local modeStroke = Instance.new("UIStroke", Btn); modeStroke.Color = Color3.fromRGB(0, 255, 150); modeStroke.Thickness = 1.5; modeStroke.Transparency = (m.id == Mode) and 0 or 0.6
        Instance.new("UIStroke", Btn).Color = Color3.fromRGB(0, 0, 0); Instance.new("UIStroke", Btn).Thickness = 1

        Btn.MouseEnter:Connect(function() if Mode ~= m.id then Btn.BackgroundColor3 = Color3.fromRGB(55, 55, 60) end end)
        Btn.MouseLeave:Connect(function() if Mode ~= m.id then Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40) end end)
        Btn.MouseButton1Click:Connect(function()
            if _G.ChangeScriptMode then
                _G.ChangeScriptMode(m.id, m.name)
                for _, sib in ipairs(ModeFrame:GetChildren()) do 
                    if sib:IsA("TextButton") then 
                        sib.BackgroundColor3 = Color3.fromRGB(35, 35, 40) 
                        local s = sib:FindFirstChildOfClass("UIStroke")
                        if s and s.Color ~= Color3.fromRGB(0,0,0) then s.Transparency = 0.6 end
                    end 
                end
                Btn.BackgroundColor3 = Color3.fromRGB(0, 180, 80); modeStroke.Transparency = 0
            end
        end)
    end

    -- CHON CONG (ZONE)
    local TitleZone = Instance.new("TextLabel", Page2)
    TitleZone.Size = UDim2.new(0.9, 0, 0, 20); TitleZone.BackgroundTransparency = 1; TitleZone.Font = Enum.Font.FredokaOne; TitleZone.Text = "🚪 SELECT ZONE"
    TitleZone.TextColor3 = Color3.fromRGB(0, 255, 150); TitleZone.TextScaled = true; TitleZone.LayoutOrder = 4
    Instance.new("UIStroke", TitleZone).Color = Color3.fromRGB(0,0,0); Instance.new("UIStroke", TitleZone).Thickness = 2
    local SpZone = Instance.new("Frame", Page2); SpZone.BackgroundColor3 = Color3.fromRGB(0, 255, 150); SpZone.Size = UDim2.new(0.7, 0, 0, 2); SpZone.BorderSizePixel = 0; SpZone.LayoutOrder = 5

    local ZoneFrame = Instance.new("Frame", Page2)
    ZoneFrame.Size = UDim2.new(0.95, 0, 0, 75); ZoneFrame.BackgroundTransparency = 1; ZoneFrame.LayoutOrder = 6
    local ZoneGrid = Instance.new("UIGridLayout", ZoneFrame)
    ZoneGrid.CellSize = UDim2.new(0.3, 0, 0, 30); ZoneGrid.CellPadding = UDim2.new(0.03, 0, 0, 8); ZoneGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center; ZoneGrid.SortOrder = Enum.SortOrder.LayoutOrder

    local ZonesData = { {id = 1, name = "Zone 1"}, {id = 2, name = "Zone 2"}, {id = 3, name = "Zone 3"}, {id = 4, name = "Zone 4"}, {id = 0, name = "All Zones"} }
    for i, z in ipairs(ZonesData) do
        local Btn = Instance.new("TextButton", ZoneFrame)
        Btn.LayoutOrder = i; Btn.BackgroundColor3 = (_G.CurrentTargetZone == z.id) and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(35, 35, 40); Btn.BorderSizePixel = 0
        Btn.Font = Enum.Font.FredokaOne; Btn.Text = z.name; Btn.TextColor3 = Color3.fromRGB(255, 255, 255); Btn.TextScaled = true
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0.2, 0)
        local zStroke = Instance.new("UIStroke", Btn); zStroke.Color = Color3.fromRGB(0, 255, 150); zStroke.Thickness = 1.5; zStroke.Transparency = (_G.CurrentTargetZone == z.id) and 0 or 0.6
        Instance.new("UIStroke", Btn).Color = Color3.fromRGB(0, 0, 0); Instance.new("UIStroke", Btn).Thickness = 1

        Btn.MouseEnter:Connect(function() if _G.CurrentTargetZone ~= z.id then Btn.BackgroundColor3 = Color3.fromRGB(55, 55, 60) end end)
        Btn.MouseLeave:Connect(function() if _G.CurrentTargetZone ~= z.id then Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40) end end)
        Btn.MouseButton1Click:Connect(function()
            if _G.ChangeTargetZone then
                _G.ChangeTargetZone(z.id)
                for _, sib in ipairs(ZoneFrame:GetChildren()) do 
                    if sib:IsA("TextButton") then 
                        sib.BackgroundColor3 = Color3.fromRGB(35, 35, 40) 
                        local s = sib:FindFirstChildOfClass("UIStroke")
                        if s and s.Color ~= Color3.fromRGB(0,0,0) then s.Transparency = 0.6 end
                    end 
                end
                Btn.BackgroundColor3 = Color3.fromRGB(0, 180, 80); zStroke.Transparency = 0
            end
        end)
    end

    -- CHON TRUNG
    local TitleEgg = Instance.new("TextLabel", Page2)
    TitleEgg.Size = UDim2.new(0.9, 0, 0, 20); TitleEgg.BackgroundTransparency = 1; TitleEgg.Font = Enum.Font.FredokaOne; TitleEgg.Text = "🥚 SELECT EGGS"
    TitleEgg.TextColor3 = Color3.fromRGB(0, 255, 150); TitleEgg.TextScaled = true; TitleEgg.LayoutOrder = 7
    Instance.new("UIStroke", TitleEgg).Color = Color3.fromRGB(0,0,0); Instance.new("UIStroke", TitleEgg).Thickness = 2
    local Sp2 = Instance.new("Frame", Page2); Sp2.BackgroundColor3 = Color3.fromRGB(0, 255, 150); Sp2.Size = UDim2.new(0.7, 0, 0, 2); Sp2.BorderSizePixel = 0; Sp2.LayoutOrder = 8

    local EggFrame = Instance.new("Frame", Page2)
    EggFrame.Size = UDim2.new(0.95, 0, 0, 75); EggFrame.BackgroundTransparency = 1; EggFrame.LayoutOrder = 9
    local EggGrid = Instance.new("UIGridLayout", EggFrame)
    EggGrid.CellSize = UDim2.new(0.22, 0, 0, 30); EggGrid.CellPadding = UDim2.new(0.03, 0, 0, 8); EggGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center; EggGrid.SortOrder = Enum.SortOrder.LayoutOrder

    for i = 1, 8 do
        local Btn = Instance.new("TextButton", EggFrame)
        Btn.LayoutOrder = i; Btn.BackgroundColor3 = (_G.CurrentTargetEgg == i) and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(35, 35, 40); Btn.BorderSizePixel = 0
        Btn.Font = Enum.Font.FredokaOne; Btn.Text = "Egg " .. i; Btn.TextColor3 = Color3.fromRGB(255, 255, 255); Btn.TextScaled = true
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0.2, 0)
        local modeStroke = Instance.new("UIStroke", Btn); modeStroke.Color = Color3.fromRGB(0, 255, 150); modeStroke.Thickness = 1.5; modeStroke.Transparency = (_G.CurrentTargetEgg == i) and 0 or 0.6
        Instance.new("UIStroke", Btn).Color = Color3.fromRGB(0, 0, 0); Instance.new("UIStroke", Btn).Thickness = 1

        Btn.MouseEnter:Connect(function() if _G.CurrentTargetEgg ~= i then Btn.BackgroundColor3 = Color3.fromRGB(55, 55, 60) end end)
        Btn.MouseLeave:Connect(function() if _G.CurrentTargetEgg ~= i then Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40) end end)
        Btn.MouseButton1Click:Connect(function()
            if _G.ChangeTargetEgg then
                _G.ChangeTargetEgg(i)
                for _, sib in ipairs(EggFrame:GetChildren()) do 
                    if sib:IsA("TextButton") then 
                        sib.BackgroundColor3 = Color3.fromRGB(35, 35, 40) 
                        local s = sib:FindFirstChildOfClass("UIStroke")
                        if s and s.Color ~= Color3.fromRGB(0,0,0) then s.Transparency = 0.6 end
                    end 
                end
                Btn.BackgroundColor3 = Color3.fromRGB(0, 180, 80); modeStroke.Transparency = 0
            end
        end)
    end

	return Self
end

function FarmUI:SetText(Name, Text) if self.Elements[Name] then task.defer(function() self.Elements[Name].Text = Text end) end end

local UI = FarmUI.new({
    UI = {
        ["Title"]           = {1, "🐰 EASTER EVENT 🐰", {0.9, 0, 0.1, 0}},
        ["ModeInfo"]        = {2, "Mode: " .. ModeDisplay},
        ["Time"]            = {3, "Time: 00:00:00 | Time Left: 00:00"},
        ["EggsHatched"]     = {4, "Total Eggs: 0 | ⚡ Speed: 0/sec"},
        ["Tokens"]          = {5, "Token B/R/S/T/Boss: 0/0/0/0/0"},
        ["EggTokens"]       = {6, "Spring Egg Token: 0"},
        ["Tickets"]         = {7, "Tickets: 0 / 0 (0%)"},
        ["FPS"]             = {8, "FPS: 60"}
    }
})

-- ==========================================
-- DATA UPDATER UI
-- ==========================================
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

            local b, r, s, t, bc, eggToken = 0, 0, 0, 0, 0, 0
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
                b = countItem("bluebell"); r = countItem("rose"); s = countItem("sunflower"); t = countItem("tulip"); bc = countItem("boss", "chest"); eggToken = countItem("spring", "egg")
            end
            UI:SetText("Tokens", string.format("Token B/R/S/T/Boss: %s/%s/%s/%s/%s", FormatValue(b), FormatValue(r), FormatValue(s), FormatValue(t), FormatValue(bc)))
            UI:SetText("EggTokens", "Spring Egg Token: " .. FormatValue(eggToken))
            UI:SetText("FPS", "FPS: " .. tostring(TrueFPS))
        end)
    end
end)

-- ==========================================
-- DONG CO SMART FARM V3
-- ==========================================
pcall(function()
    local orig = PlayerPet.CalculateSpeedMultiplier
    PlayerPet.CalculateSpeedMultiplier = function() return math.huge end
end)

local function getCurrentZone() return MapCmds.GetCurrentZone() end
local function getCurrentInstanceID() return InstancingCmds.Get() and InstancingCmds.Get().instanceID or nil end

local function getClosestBreakables(range)
    range = range or 150
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
                if (breakable.WorldPivot.Position - rootPos).Magnitude < range then table.insert(breakables, breakable.Name) end
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
    local breakables = getClosestBreakables(150)
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
    range = range or 100
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
        if OrbsFolder then 
            for _, orb in ipairs(OrbsFolder:GetChildren()) do
                local number = tonumber(orb.Name)
                if number then Network.Fire("Orbs: Collect", number); orb:Destroy() end
            end
        end
        if LootbagsFolder then
            local bagIds = {}
            for _, bag in ipairs(LootbagsFolder:GetChildren()) do
                if bag:IsA("Model") or bag:IsA("Part") then table.insert(bagIds, bag.Name); bag:Destroy() end 
            end
            if #bagIds > 0 then Network.Fire("Lootbags_Claim", bagIds) end
        end
    end)
end

task.spawn(function()
    while task.wait(0.05) do
        if _G.CurrentPhase == "FARMING" and _G.FarmReady then pcall(fastFarm); pcall(function() clickAura(100) end); pcall(collectOrbsAndLootbags) end
    end
end)

-- ==========================================
-- NETWORK AUTO UPGRADE & TARGET EGG
-- ==========================================
local SpringEggUnlocks = { 
    { number = 2, cost = 300 }, { number = 3, cost = 1500 }, { number = 4, cost = 6000 }, { number = 5, cost = 20000 },
    { number = 6, cost = 3000000 }, { number = 7, cost = 100000000 }, { number = 8, cost = 280000000 }
}
task.spawn(function()
    while task.wait(3) do
        -- MUA NANG CAP SUC MANH
        if AutoUpgrade then
            pcall(function()
                for upgradeId, upgradeData in pairs(EventUpgradesDir) do
                    if upgradeId:find("Easter") or upgradeId:find("Spring") then
                        local currentTier = EventUpgradeCmds.GetTier(upgradeId)
                        local nextTierCost = upgradeData.TierCosts and upgradeData.TierCosts[currentTier + 1]
                        if nextTierCost and nextTierCost._data then
                            local cId, costAmount = nextTierCost._data.id, nextTierCost._data._am or 1
                            local currentAmount = 0
                            pcall(function() currentAmount = Items.Misc(cId) and Items.Misc(cId):CountExact() or 0 end)
                            if currentAmount == 0 then pcall(function() currentAmount = CurrencyCmds.Get(cId) or 0 end) end
                            
                            if currentAmount >= costAmount then EventUpgradeCmds.Purchase(upgradeId) end
                        end
                    end
                end
            end)
        end
        
        -- MUA VA CHON TRUNG
        pcall(function()
            local save = Save.Get()
            if not save then return end
            
            local eggToken = 0
            if save.Inventory and save.Inventory.Misc then 
                for _, item in pairs(save.Inventory.Misc) do 
                    local idStr = (item.id or ""):lower()
                    if idStr:match("spring") and idStr:match("egg") then eggToken = eggToken + (item._am or 1) end 
                end 
            end
            if eggToken == 0 then pcall(function() eggToken = CurrencyCmds.Get("SpringEggTokens") or 0 end) end
            if eggToken == 0 then pcall(function() eggToken = CurrencyCmds.Get("Easter2026EggTokens") or 0 end) end
            
            local currentUnlocked = save.Easter2026UnlockedEggs or 1
            local activeEgg = save.Easter2026ActiveEgg or 1
            local target = _G.CurrentTargetEgg or 8
            
            for _, egg in ipairs(SpringEggUnlocks) do
                if egg.number > currentUnlocked and eggToken >= egg.cost then 
                    pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "PurchaseEgg", egg.number) end)
                    task.wait(0.5) 
                    
                    if egg.number <= target then
                        pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "SelectEgg", egg.number) end)
                    else
                        pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "SelectEgg", target) end)
                    end
                    break 
                elseif egg.number == currentUnlocked then
                    local desiredEgg = math.min(currentUnlocked, target)
                    if activeEgg ~= desiredEgg then
                        pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "SelectEgg", desiredEgg) end)
                    end
                end
            end
        end)
    end
end)
task.spawn(function() while task.wait(15) do pcall(function() Network.Invoke('Mailbox: Claim All') end) end end)
task.spawn(function() while task.wait(5) do pcall(function() local save = Save.Get(); if not save then return end; local redeemed = save.FreeGiftsRedeemed or {}; local currentTime = save.FreeGiftsTime or 0; for _, gift in pairs(FreeGiftsDirectory) do if gift.WaitTime <= currentTime and not table.find(redeemed, gift._id) then Network.Invoke('Redeem Free Gift', gift._id); break end end end) end end)
task.spawn(function() while task.wait(1.5) do pcall(function() local equipped = UltimateCmds.GetEquippedItem(); if equipped and equipped._data and equipped._data.id then UltimateCmds.Activate(equipped._data.id) end end) end end)

-- ==========================================
-- DONG CO HATCH TRUNG SIEU TOC
-- ==========================================
task.spawn(function()
    while true do
        if _G.CurrentPhase == "HATCHING" and AutoHatch then
            task.spawn(function() pcall(function() Network.Invoke("Instancing_InvokeCustomFromClient", "EasterHatchEvent", "HatchRequest") end) end)
            task.spawn(function() pcall(function() Network.Invoke("EasterHatchEvent", "HatchRequest") end) end)
            task.wait(0.1) 
        else task.wait(0.5) end
    end
end)

-- ==========================================
-- SMART ROUND-ROBIN PORTALS & STATE MACHINE
-- ==========================================
local SafePart = Instance.new("Part", Workspace)
SafePart.Size = Vector3.new(25, 1, 25); SafePart.Anchored = true; SafePart.Transparency = 0.8; SafePart.Material = Enum.Material.Glass; SafePart.BrickColor = BrickColor.new("Toothpaste")

local function TeleportPlayer(cf)
    if not cf then return end
    local root = getRootPart()
    if root then root.Anchored = false; root.CFrame = cf + Vector3.new(0, 1.5, 0); SafePart.CFrame = cf - Vector3.new(0, 1.5, 0); root.Velocity = Vector3.new(0,0,0) end
end

local State = { Phase = (Mode == "HatchOnly") and "HATCHING" or "FARMING", TimeLeft = 0, CurrentPortal = (_G.CurrentTargetZone == 0 and 1 or _G.CurrentTargetZone), IsReady = false }
_G.CurrentPhase = State.Phase

-- HAM API CHUYEN MODE
_G.ChangeScriptMode = function(newMode, newDisplay)
    Mode = newMode
    ModeDisplay = newDisplay
    State.IsReady = false
    _G.FarmReady = false
    _G.ModeChanging = true
    
    task.spawn(function()
        pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ReturnToHub") end)
        TeleportPlayer(CFrame.new(0, 10, 0))
        task.wait(3)
        if Mode == "HatchOnly" then 
            State.Phase = "HATCHING"; State.TimeLeft = math.huge
        else 
            State.Phase = "FARMING"; State.TimeLeft = 0
            if Mode == "Nest" then 
                State.CurrentPortal = 5 
            else 
                State.CurrentPortal = (_G.CurrentTargetZone == 0 and 1 or _G.CurrentTargetZone)
            end
        end
        _G.CurrentPhase = State.Phase
        _G.ModeChanging = false
    end)
end

-- HAM API CHUYEN EGG
_G.ChangeTargetEgg = function(eggNum)
    _G.CurrentTargetEgg = eggNum
end

-- HAM API CHUYEN ZONE
_G.ChangeTargetZone = function(zoneNum)
    _G.CurrentTargetZone = zoneNum
    if Mode ~= "Nest" and Mode ~= "HatchOnly" then
        State.CurrentPortal = (zoneNum == 0) and 1 or zoneNum
        State.IsReady = false
        _G.FarmReady = false
    end
end

local function SmartEnterZone()
    _G.FarmReady = false; _G.CurrentFarmCF = nil; local success = false
    
    -- Xac dinh cac cong can vao phu thuoc vao setting
    local portalsToTry = {}
    if _G.CurrentTargetZone == 0 then
        for i = 0, 3 do table.insert(portalsToTry, ((State.CurrentPortal - 1 + i) % 4) + 1) end
    else
        table.insert(portalsToTry, _G.CurrentTargetZone)
        State.CurrentPortal = _G.CurrentTargetZone -- Dong bo State
    end

    for _, tryPortal in ipairs(portalsToTry) do
        local serverZoneID = tryPortal + 1 
        local root = getRootPart()
        local startPos = root and root.Position or Vector3.new(0,0,0)
        
        pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ZonePortal", serverZoneID) end)
        
        local waitTime = 0
        while waitTime < 2 do
            local r = getRootPart()
            if r then
                local distMoved = (r.Position - startPos).Magnitude
                local distFromHub = (r.Position - _G.DynamicHubCF.Position).Magnitude
                local distFromHatch = (r.Position - HatchZoneCF.Position).Magnitude
                if distMoved > 50 and distFromHub > 300 and distFromHatch > 300 then 
                    success = true; State.CurrentPortal = tryPortal; break 
                end
            end
            task.wait(0.2); waitTime = waitTime + 0.2
        end
        if success then break end
        
        pcall(function()
            for _, gui in pairs(Player.PlayerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and (gui.Name:find("Error") or gui.Name:find("Message") or gui.Name:find("Warning")) then gui.Enabled = false end
            end
        end)
    end
    
    if success then
        task.wait(1)
        local r = getRootPart()
        if r then _G.CurrentFarmCF = CFrame.new(r.Position + FarmOffset); TeleportPlayer(_G.CurrentFarmCF); task.wait(0.5); _G.FarmReady = true; return true end
    end
    return false
end

local function EnterNestZone()
    _G.FarmReady = false; _G.CurrentFarmCF = nil; local success = false
    local root = getRootPart()
    local startPos = root and root.Position or Vector3.new(0,0,0)
    
    pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ZonePortal", 6) end)
    local waitTime = 0
    while waitTime < 2 do
        local r = getRootPart()
        if r then
            local distMoved = (r.Position - startPos).Magnitude
            local distFromHub = (r.Position - _G.DynamicHubCF.Position).Magnitude
            local distFromHatch = (r.Position - HatchZoneCF.Position).Magnitude
            if distMoved > 50 and distFromHub > 300 and distFromHatch > 300 then 
                success = true; State.CurrentPortal = 5; break 
            end
        end
        task.wait(0.2); waitTime = waitTime + 0.2
    end
    pcall(function()
        for _, gui in pairs(Player.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name:find("Error") or gui.Name:find("Message") or gui.Name:find("Warning")) then gui.Enabled = false end
        end
    end)
    
    if success then
        task.wait(1)
        local r = getRootPart()
        if r then _G.CurrentFarmCF = CFrame.new(r.Position + FarmOffset); TeleportPlayer(_G.CurrentFarmCF); task.wait(0.5); _G.FarmReady = true; return true end
    end
    return false
end

local function ReturnToHubNetwork()
    _G.FarmReady = false
    pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "ReturnToHub") end)
    local waitTime = 0
    while waitTime < 3 do
        local root = getRootPart()
        if root and (root.Position - _G.DynamicHubCF.Position).Magnitude <= 400 then break end
        task.wait(0.5); waitTime = waitTime + 0.5
    end
    task.wait(1); TeleportPlayer(HatchZoneCF)
end

-- Ham noi bo quet bang thoi gian trong Game
local function GetGameTimerText()
    local textToReturn = nil
    pcall(function()
        if InstanceContainer and InstanceContainer:FindFirstChild("Active") then
            for _, desc in ipairs(InstanceContainer.Active:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible then
                    local txt = desc.Text
                    if txt:match("%d+:%d+") or txt:match("^%d+s$") then textToReturn = txt; break end
                end
            end
        end
    end)
    return textToReturn
end

task.spawn(function()
    local root = getRootPart()
    if root then root.Anchored = true end
    local retries = 0
    while InstancingCmds.GetInstanceID() ~= "EasterHatchEvent" and retries < 5 do 
        pcall(function() setthreadidentity(2); InstancingCmds.Enter("EasterHatchEvent"); setthreadidentity(8) end)
        task.wait(1.5); retries = retries + 1 
    end
    root = getRootPart()
    if root then root.Anchored = false end
    
    local currentEnchantPhase = ""
    local NestEntryTime = 0
    local HasKilledBoss = false

    while task.wait(1) do
        if _G.ModeChanging then
            UI:SetText("ModeInfo", "Mode: " .. ModeDisplay .. " | Dang chuyen doi...")
            continue
        end

        if InstancingCmds.GetInstanceID() ~= "EasterHatchEvent" then
            UI:SetText("ModeInfo", "Dang tai Event Hub...")
            pcall(function() setthreadidentity(2); InstancingCmds.Enter("EasterHatchEvent"); setthreadidentity(8) end)
            task.wait(2); continue
        end

        if not State.IsReady then
            if State.Phase == "FARMING" then 
                if Mode == "Nest" then
                    local entered = EnterNestZone()
                    if entered then
                        State.IsReady = true; HasKilledBoss = false; NestEntryTime = os.time()
                    else
                        State.Phase = "HATCHING"; _G.CurrentPhase = State.Phase; State.TimeLeft = 60 
                        ReturnToHubNetwork(); State.IsReady = true
                    end
                else
                    local entered = SmartEnterZone()
                    if entered then 
                        State.IsReady = true; State.TimeLeft = FarmTimeMinutes * 60
                    else
                        State.Phase = "HATCHING"; _G.CurrentPhase = State.Phase; State.TimeLeft = 60 
                        ReturnToHubNetwork(); State.IsReady = true
                    end
                end
            else 
                ReturnToHubNetwork(); State.IsReady = true; _G.FarmReady = false 
                if Mode ~= "Nest" then State.TimeLeft = (Mode == "HatchOnly") and math.huge or (HatchTimeMinutes * 60) end
            end
        end

        if State.IsReady then
            if State.TimeLeft ~= math.huge then State.TimeLeft = State.TimeLeft - 1 end

            if Mode == "Nest" then
                if State.Phase == "FARMING" then
                    local breakables = getClosestBreakables(150)
                    local gameTimer = GetGameTimerText()
                    
                    if #breakables > 0 then
                        HasKilledBoss = true
                        UI:SetText("ModeInfo", "Mode: " .. ModeDisplay .. " | ⚔️ Dang dap Boss Chest!")
                        NestEntryTime = os.time()
                    else
                        if not HasKilledBoss then
                            local waitMsg = gameTimer and ("⏳ Doi ruong: " .. gameTimer) or "⏳ Doi ruong xuat hien..."
                            UI:SetText("ModeInfo", "Mode: " .. ModeDisplay .. " | " .. waitMsg)
                            
                            -- Failsafe: Neu ket trong phong qua 5 phut thi reset
                            if os.time() - NestEntryTime > 300 then
                                State.Phase = "HATCHING"; State.IsReady = false; _G.FarmReady = false; State.TimeLeft = 30; HasKilledBoss = false
                            end
                        else
                            -- DA DAP XONG: Rut ra ngoai sanh
                            State.Phase = "HATCHING"; State.IsReady = false; _G.FarmReady = false; State.TimeLeft = 30; HasKilledBoss = false
                        end
                    end
                elseif State.Phase == "HATCHING" and State.TimeLeft <= 0 then
                    State.Phase = "FARMING"; State.IsReady = false
                end
                
            elseif Mode == "Combine" then 
                if State.Phase == "FARMING" and State.TimeLeft <= 0 then
                    State.Phase = "HATCHING"; State.IsReady = false; _G.FarmReady = false
                elseif State.Phase == "HATCHING" and State.TimeLeft <= 0 then
                    State.Phase = "FARMING"; 
                    if _G.CurrentTargetZone == 0 then
                        State.CurrentPortal = (State.CurrentPortal % 4) + 1
                    else
                        State.CurrentPortal = _G.CurrentTargetZone
                    end
                    State.IsReady = false
                end
            elseif Mode == "FarmOnly" then 
                if State.Phase == "FARMING" and State.TimeLeft <= 0 then
                    if _G.CurrentTargetZone == 0 then
                        State.CurrentPortal = (State.CurrentPortal % 4) + 1
                    else
                        State.CurrentPortal = _G.CurrentTargetZone
                    end
                    State.IsReady = false; _G.FarmReady = false
                end
            end
        end

        _G.CurrentPhase = State.Phase

        if currentEnchantPhase ~= State.Phase then
            currentEnchantPhase = State.Phase
            if State.Phase == "FARMING" and EnchantSettings.Farm then EquipEnchantLoadout("FARM", EnchantSettings.Farm)
            elseif State.Phase == "HATCHING" and EnchantSettings.Hatch then EquipEnchantLoadout("HATCH", EnchantSettings.Hatch) end
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
        
        if Mode ~= "Nest" then
            local zoneStr = _G.CurrentTargetZone == 0 and "All" or tostring(_G.CurrentTargetZone)
            UI:SetText("ModeInfo", "Mode: " .. ModeDisplay .. " (Egg " .. _G.CurrentTargetEgg .. ") | Zone: " .. zoneStr .. " | Portal: " .. State.CurrentPortal)
        end
    end
end)

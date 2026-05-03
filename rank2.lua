if _G.AutoRankStarted then
    -- Tự động dọn dẹp các connection cũ nếu chạy lại script (Chống rò rỉ bộ nhớ)
    if _G.AutoRankConnections then
        for _, conn in pairs(_G.AutoRankConnections) do pcall(function() conn:Disconnect() end) end
    end
end
_G.AutoRankStarted = true
_G.AutoRankConnections = {}
_G.StuckCooldown = _G.StuckCooldown or {}

local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local Library = ReplicatedStorage:WaitForChild("Library")
local Save = require(Library.Client.Save)
local Network = require(Library.Client.Network)
local ZoneCmds = require(Library.Client.ZoneCmds)
local RebirthCmds = require(Library.Client.RebirthCmds)
local PetNetworking = require(Library.Client.PetNetworking)
local RankCmds = require(Library.Client.RankCmds)
local RanksDirectory = require(Library.Directory.Ranks)
local QuestsGoals = require(Library.Types.Quests).Goals
local WorldsUtil = require(Library.Util.WorldsUtil)
local DirectoryZones = require(Library.Directory.Zones)
local CalcGatePrice = require(ReplicatedStorage.Library.Balancing.CalcGatePrice)
local CurrencyCmds = require(ReplicatedStorage.Library.Client.CurrencyCmds)
local UltimateCmds = require(Library.Client.UltimateCmds)
local FreeGiftsDirectory = require(Library.Directory.FreeGifts)
local EggCmds = require(Library.Client.EggCmds)
local CalcEggPricePlayer = require(Library.Balancing.CalcEggPricePlayer)
local CalcPotion = require(ReplicatedStorage.Library.Balancing.CalcPotionsPerTierRequired)
local CalcEnchant = require(ReplicatedStorage.Library.Balancing.CalcEnchantsPerTierRequired)
local FlexibleFlagCmds = require(Library.Client.FlexibleFlagCmds)
local DirectoryEggs = require(Library.Directory.Eggs)
local ZoneFlagsDir = require(Library.Directory.ZoneFlags) 
local DaycareCmds = require(Library.Client.DaycareCmds)
local DaycareLoot = require(Library.Modules.DaycareLoot)
local PetItem = require(Library.Items.PetItem)
local FruitCmds = require(Library.Client.FruitCmds)

local config = getgenv().AutoRankConfig or {}
local WEBHOOK_URL = config.WebhookURL or ""
local PING_ID = config.PingID or ""
local NOTIFY_SHORTAGE = config.NotifyOnMaterialShortage or false

local lastRank = 1
pcall(function() lastRank = Save.Get().Rank or 1 end)

local function SendRankUpWebhook(newRank, newTitle)
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest or WEBHOOK_URL == "" then return end
    local data = {
        ["content"] = "<@" .. PING_ID .. "> Level up notification!",
        ["embeds"] = {{
            ["title"] = "🎉 LEVEL UP NOTIFICATION 🎉",
            ["description"] = "**Account:** ||" .. LocalPlayer.Name .. "||\n**Ranked Up To:** Rank " .. tostring(newRank) .. " - " .. tostring(newTitle),
            ["type"] = "rich",
            ["color"] = tonumber(0x00FF00),
            ["footer"] = { ["text"] = "Poodle Auto Rank System" },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }
    pcall(function() httprequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) }) end)
end

local function SendMaterialShortageWebhook(questName)
    if not NOTIFY_SHORTAGE or WEBHOOK_URL == "" then return end
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest then return end
    local data = {
        ["content"] = "⚠️ Alert: More ingredients are needed!",
        ["embeds"] = {{
            ["title"] = "Out of Quest Materials!",
            ["description"] = "**Account:** ||" .. LocalPlayer.Name .. "||\n**The mission is stuck.:** " .. tostring(questName) .. "\n*The system automatically skipped this task for 5 minutes.*",
            ["type"] = "rich",
            ["color"] = tonumber(0xFF5500),
            ["footer"] = { ["text"] = "Poodle Auto Rank System" },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }
    pcall(function() httprequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) }) end)
end

-- ==========================================
-- EXTREME OPTIMIZATION & DUMMY CAMERA (TỐI ƯU HÓA CPU)
-- ==========================================
local THINGS = Workspace:WaitForChild("__THINGS")
local DummyPlatformPos = Vector3.new(0, 15000, 0)
local ActiveDummy = nil
local Cam = Workspace.CurrentCamera

local function CreateOptimizationAndPlatforms()
    local mainPlat = Instance.new("Part", Workspace)
    mainPlat.Size = Vector3.new(50, 1, 50); mainPlat.Position = DummyPlatformPos - Vector3.new(0, 3, 0); mainPlat.Anchored = true
    mainPlat.Material = Enum.Material.Neon; mainPlat.BrickColor = BrickColor.new("Toothpaste"); mainPlat.Name = "DummyPlatform"

    Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9
    for _, v in pairs(Lighting:GetDescendants()) do if v:IsA("PostEffect") then v.Enabled = false end end

    local function optimizePart(v)
        pcall(function()
            if v:IsDescendantOf(THINGS) or v == mainPlat or (ActiveDummy and v:IsDescendantOf(ActiveDummy)) then return end
            if v:IsA("BasePart") and not (v.Parent and v.Parent:FindFirstChild("Humanoid")) then
                v.Material = Enum.Material.Plastic; v.Reflectance = 0; v.CastShadow = false; v.Transparency = 1
                if v:IsA("MeshPart") or v:IsA("SpecialMesh") then v.TextureID = "" end
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("PostEffect") then v.Enabled = false
            elseif v:IsA("Explosion") then v.Visible = false end
        end)
    end
    for _, v in pairs(Workspace:GetDescendants()) do optimizePart(v) end
    table.insert(_G.AutoRankConnections, Workspace.DescendantAdded:Connect(optimizePart))
end

-- Tối ưu tàng hình nhân vật thật: Chỉ xử lý lúc CharacterAdded, không ném vào RenderStepped
local function makeCharInvisible(char)
    for _, v in pairs(char:GetDescendants()) do if v:IsA("BasePart") or v:IsA("Decal") then v.Transparency = 1 end end
    table.insert(_G.AutoRankConnections, char.DescendantAdded:Connect(function(v)
        if v:IsA("BasePart") or v:IsA("Decal") then v.Transparency = 1 end
    end))
end

local function SetupDummyAndCamera(char)
    if not char then return end
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    char.Archivable = true
    makeCharInvisible(char)
    
    -- Cài đặt neo nhân vật thật trên không (Tránh rơi khi map load chậm)
    local bg = Instance.new("BodyGyro"); bg.P = 9e4; bg.maxTorque = Vector3.new(9e9, 9e9, 9e9); bg.cframe = hrp.CFrame; bg.Parent = hrp
    local bv = Instance.new("BodyVelocity"); bv.velocity = Vector3.new(0, 0, 0); bv.maxForce = Vector3.new(9e9, 9e9, 9e9); bv.Parent = hrp
    hum.PlatformStand = true
    
    if ActiveDummy then ActiveDummy:Destroy() end
    ActiveDummy = char:Clone(); ActiveDummy.Name = "AFK_Dummy"; ActiveDummy.Parent = Workspace
    ActiveDummy:SetPrimaryPartCFrame(CFrame.new(DummyPlatformPos))
    for _, v in pairs(ActiveDummy:GetDescendants()) do if v:IsA("BasePart") then v.Anchored = true end end
end

local function HandleCharacter(char)
    task.wait(1) 
    SetupDummyAndCamera(char)
end

if LocalPlayer.Character then HandleCharacter(LocalPlayer.Character) end
table.insert(_G.AutoRankConnections, LocalPlayer.CharacterAdded:Connect(HandleCharacter))

CreateOptimizationAndPlatforms()

table.insert(_G.AutoRankConnections, RunService.RenderStepped:Connect(function()
    if Cam and ActiveDummy and ActiveDummy:FindFirstChild("Humanoid") then
        Cam.CameraSubject = ActiveDummy.Humanoid
    end
end))
-- ==========================================

local function loadUtils(url, file)
    local path = "Poodle-Utils/" .. file
    local ok, res = pcall(function() return game:HttpGet(url) end) 
    if ok and res then
        if not isfolder("Poodle-Utils") then makefolder("Poodle-Utils") end
        writefile(path, res)
        return loadstring(res)()
    end
    return loadstring(readfile(path))()
end

local vm = loadUtils("https://raw.githubusercontent.com/thuyan1510/99/refs/heads/main/VariablesManager.lua", "VariablesManager.lua")
vm = vm:new()
vm:Add("AllBreakables", {}, "table"); vm:Add("Euids", {}, "table"); vm:Add("PetIDs", {}, "table")
vm:Add("current_zone", nil, "string"); vm:Add("IsReadyToFarm", false, "boolean"); vm:Add("OutZoneTime", 0, "number") 
vm:Add("TargetZoneId", nil, "string"); vm:Add("FlagZoneOffset", 0, "number"); vm:Add("IsPetQuestActive", false, "boolean") 

pcall(function() 
    local PetModule = require(Library.Client.PlayerPet)
    PetModule.CalculateSpeedMultiplier = function() return math.huge end 
end)

-- ==========================================
-- 🛡️ HỆ THỐNG ANTI-AFK (TỐI ƯU HOÁ HOOK)
-- ==========================================
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local oldNamecall;
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local args = {...}; local cmd = args[1]
        -- Kiểm tra type để tránh gọi tostring làm nặng client
        if type(cmd) == "string" and (cmd == "Idle Tracking: Update Timer" or cmd == "AFK_Ping") then return end
    end
    return oldNamecall(self, ...)
end)

pcall(function()
    if getconnections then
        for _, v in pairs(getconnections(UserInputService.WindowFocusReleased)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(UserInputService.WindowFocused)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(LocalPlayer.Idled)) do pcall(function() v:Disable() end) end
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
-- ==========================================

-- ==========================================
-- 🍎 SMART AUTO FRUIT
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
            if not currentBestUid then bestFruits[baseId] = uid else
                local currentBestData = fruitInv[currentBestUid]
                local isNewShiny = data.sh == true
                local isOldShiny = currentBestData.sh == true
                if isNewShiny and not isOldShiny then bestFruits[baseId] = uid
                elseif isNewShiny == isOldShiny then
                    if (data._am or 1) > (currentBestData._am or 1) then bestFruits[baseId] = uid end
                end
            end
        end
    end
    for fruitName, uid in pairs(bestFruits) do
        local currentStack = GetCurrentFruitStack(fruitName)
        if currentStack < targetStack then
            local consumeAmount = math.min(targetStack - currentStack, fruitInv[uid] and fruitInv[uid]._am or 1)
            if consumeAmount > 0 then
                pcall(function() FruitCmds.Consume(uid, consumeAmount); Network.Fire("Fruits: Consume", uid, consumeAmount) end); task.wait(0.2) 
            end
        end
    end
end
task.spawn(function() ManageFruits() end)
table.insert(_G.AutoRankConnections, Network.Fired("Fruits: Update"):Connect(function() task.wait(1); ManageFruits() end))

getgenv().HideEggAnimation = true
local EggFrontend = nil
pcall(function() EggFrontend = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"]) end)
local OriginalPlayEggAnimation = EggFrontend and EggFrontend.PlayEggAnimation or nil
local function ToggleEggAnimation()
    if not EggFrontend then return end
    if getgenv().HideEggAnimation then
        EggFrontend.PlayEggAnimation = function() return end
        EggFrontend.PlayCustom = function() return end
    else
        EggFrontend.PlayEggAnimation = OriginalPlayEggAnimation
    end
end

local function GetCurrentWorldNumber() return WorldsUtil.GetWorld() and WorldsUtil.GetWorld().WorldNumber or 1 end
local function getcurrency()
    local worldNum = GetCurrentWorldNumber()
    local currencies = { [1] = "Coins", [2] = "TechCoins", [3] = "VoidCoins", [4] = "FantasyCoins" }
    return CurrencyCmds.Get(currencies[worldNum] or "Coins") or 0
end

-- Tối ưu hoá tìm Zone: Sử dụng Cache
local CachedZoneFolders = {}
local function GetZoneFolderByOffset(offset)
    local maxZoneId, maxZoneData = ZoneCmds.GetMaxOwnedZone()
    if not maxZoneData then return nil, 1 end
    local targetNum = math.max(1, maxZoneData.ZoneNumber - offset)
    
    if CachedZoneFolders[targetNum] and CachedZoneFolders[targetNum].Parent then return CachedZoneFolders[targetNum], targetNum end
    
    local searchPattern = "^" .. tostring(targetNum) .. " |"
    for _, folderName in ipairs({"Map", "Map2", "Map3", "Map4", "Map5", "Map6"}) do
        local mapFolder = Workspace:FindFirstChild(folderName)
        if mapFolder then 
            for _, zoneFolder in pairs(mapFolder:GetChildren()) do 
                if string.find(zoneFolder.Name, searchPattern) then 
                    CachedZoneFolders[targetNum] = zoneFolder
                    return zoneFolder, targetNum 
                end 
            end 
        end
    end
    return nil, targetNum
end

local function GetBestEggModule()
    local maxAvailableEgg = ZoneCmds.GetMaximumOverallZone().MaximumAvailableEgg
    for _, egg in pairs(DirectoryEggs) do if egg.eggNumber == maxAvailableEgg then return egg end end
    return nil
end
local function HatchBestEgg()
    local maxHatch = EggCmds.GetMaxHatch(); local bestEgg = GetBestEggModule()
    if bestEgg and bestEgg._id then Network.Invoke('Eggs_RequestPurchase', bestEgg._id, maxHatch) end
end
local function GetPetsFromEgg()
    local v35 = {}; local eggMod = GetBestEggModule()
    if not eggMod or type(eggMod.pets) ~= "table" then return v35 end
    for _, v36 in pairs(eggMod.pets) do if type(v36) == "table" and v36[1] and not v36[1]:match('Huge') then table.insert(v35, v36[1]) end end
    return v35
end
local function GetBestNormalPetsUID()
    local inv = Save.Get().Inventory; if not inv or type(inv.Pet) ~= "table" then return {} end
    local v52 = GetPetsFromEgg(); local v56 = {}
    for uid, v57 in pairs(inv.Pet) do
        if table.find(v52, v57.id) and not (v57.pt or v57.sh) then v56[uid] = { PetName = v57.id, Rarity = v57.pt or 0, UID = uid, Amount = v57._am or 1 } end
    end
    return v56
end
local function GetBestGoldenPetsUID()
    local inv = Save.Get().Inventory; if not inv or type(inv.Pet) ~= "table" then return {} end
    local v59 = GetPetsFromEgg(); local v63 = {}
    for uid, v64 in pairs(inv.Pet) do
        if table.find(v59, v64.id) and (v64.pt == 1 and not v64.sh) then v63[uid] = { PetName = v64.id, Rarity = v64.pt, UID = uid, Amount = v64._am or 1 } end
    end
    return v63
end

if CoreGui:FindFirstChild("AutoRankUI") then CoreGui.AutoRankUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "AutoRankUI"; ScreenGui.Parent = CoreGui; ScreenGui.ResetOnSpawn = false; ScreenGui.IgnoreGuiInset = true
local FullscreenBG = Instance.new("Frame"); FullscreenBG.Size = UDim2.new(1, 0, 1, 0); FullscreenBG.BackgroundColor3 = Color3.fromRGB(14, 19, 30); FullscreenBG.BorderSizePixel = 0; FullscreenBG.Parent = ScreenGui
local ToggleBtn = Instance.new("ImageButton"); ToggleBtn.Size = UDim2.new(0, 50, 0, 50); ToggleBtn.Position = UDim2.new(1, -20, 1, -20); ToggleBtn.AnchorPoint = Vector2.new(1, 1); ToggleBtn.BackgroundTransparency = 1; ToggleBtn.Image = "rbxassetid://139164748850995"; ToggleBtn.Parent = ScreenGui
local MainContainer = Instance.new("Frame"); MainContainer.Size = UDim2.new(0, 720, 0.85, 0); MainContainer.Position = UDim2.new(0.5, 0, 0.5, 0); MainContainer.AnchorPoint = Vector2.new(0.5, 0.5); MainContainer.BackgroundTransparency = 1; MainContainer.Parent = FullscreenBG
local MainLayout = Instance.new("UIListLayout"); MainLayout.FillDirection = Enum.FillDirection.Horizontal; MainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; MainLayout.VerticalAlignment = Enum.VerticalAlignment.Center; MainLayout.Padding = UDim.new(0, 15); MainLayout.Parent = MainContainer
local LeftColumn = Instance.new("Frame"); LeftColumn.Size = UDim2.new(0, 280, 1, 0); LeftColumn.BackgroundTransparency = 1; LeftColumn.Parent = MainContainer
local LeftList = Instance.new("UIListLayout"); LeftList.SortOrder = Enum.SortOrder.LayoutOrder; LeftList.Padding = UDim.new(0, 12); LeftList.Parent = LeftColumn
local PlayerInfo = Instance.new("Frame"); PlayerInfo.Size = UDim2.new(1, 0, 0, 90); PlayerInfo.BackgroundTransparency = 1; PlayerInfo.Parent = LeftColumn
local Avatar = Instance.new("ImageLabel"); Avatar.Size = UDim2.new(0, 70, 0, 70); Avatar.Position = UDim2.new(0, 10, 0.5, -35); Avatar.BackgroundTransparency = 1; Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=420&h=420"; Avatar.Parent = PlayerInfo
local UsernameLabel = Instance.new("TextLabel"); UsernameLabel.Size = UDim2.new(1, -90, 0, 35); UsernameLabel.Position = UDim2.new(0, 90, 0, 10); UsernameLabel.BackgroundTransparency = 1; UsernameLabel.Font = Enum.Font.FredokaOne; UsernameLabel.Text = LocalPlayer.DisplayName; UsernameLabel.TextColor3 = Color3.fromRGB(255, 255, 255); UsernameLabel.TextSize = 24; UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left; UsernameLabel.Parent = PlayerInfo
local RankLabel = Instance.new("TextLabel"); RankLabel.Size = UDim2.new(1, -90, 0, 25); RankLabel.Position = UDim2.new(0, 90, 0, 48); RankLabel.BackgroundTransparency = 1; RankLabel.Font = Enum.Font.GothamBold; RankLabel.Text = "Rank: Loading..."; RankLabel.TextColor3 = Color3.fromRGB(80, 200, 255); RankLabel.TextSize = 18; RankLabel.TextXAlignment = Enum.TextXAlignment.Left; RankLabel.Parent = PlayerInfo
local StarsFrame = Instance.new("Frame"); StarsFrame.Size = UDim2.new(1, 0, 0, 30); StarsFrame.BackgroundTransparency = 1; StarsFrame.Parent = LeftColumn
local StarsLabel = Instance.new("TextLabel"); StarsLabel.Size = UDim2.new(1, 0, 1, 0); StarsLabel.BackgroundTransparency = 1; StarsLabel.Font = Enum.Font.GothamBold; StarsLabel.Text = "Stars: 0"; StarsLabel.TextColor3 = Color3.fromRGB(255, 215, 0); StarsLabel.TextSize = 18; StarsLabel.TextXAlignment = Enum.TextXAlignment.Left; StarsLabel.Parent = StarsFrame
local UptimeLabel = Instance.new("TextLabel"); UptimeLabel.Size = UDim2.new(1, 0, 0, 30); UptimeLabel.BackgroundTransparency = 1; UptimeLabel.Font = Enum.Font.Gotham; UptimeLabel.Text = "Uptime: 00:00:00"; UptimeLabel.TextColor3 = Color3.fromRGB(180, 180, 180); UptimeLabel.TextSize = 16; UptimeLabel.TextXAlignment = Enum.TextXAlignment.Left; UptimeLabel.Parent = LeftColumn
local FPSLabel = Instance.new("TextLabel"); FPSLabel.Size = UDim2.new(1, 0, 0, 30); FPSLabel.BackgroundTransparency = 1; FPSLabel.Font = Enum.Font.Gotham; FPSLabel.Text = "FPS: 0"; FPSLabel.TextColor3 = Color3.fromRGB(180, 180, 180); FPSLabel.TextSize = 16; FPSLabel.TextXAlignment = Enum.TextXAlignment.Left; FPSLabel.Parent = LeftColumn
local Watermark1 = Instance.new("TextLabel"); Watermark1.Size = UDim2.new(1, 0, 0, 25); Watermark1.BackgroundTransparency = 1; Watermark1.Font = Enum.Font.GothamBold; Watermark1.Text = "Poodle Auto Rank"; Watermark1.TextColor3 = Color3.fromRGB(30, 255, 180); Watermark1.TextSize = 18; Watermark1.TextXAlignment = Enum.TextXAlignment.Left; Watermark1.Parent = LeftColumn
local Watermark2 = Instance.new("TextLabel"); Watermark2.Size = UDim2.new(1, 0, 0, 20); Watermark2.BackgroundTransparency = 1; Watermark2.Font = Enum.Font.Gotham; Watermark2.Text = "https://discord.gg/hRumkfeMcM"; Watermark2.TextColor3 = Color3.fromRGB(150, 150, 255); Watermark2.TextSize = 14; Watermark2.TextXAlignment = Enum.TextXAlignment.Left; Watermark2.Parent = LeftColumn
local RightColumn = Instance.new("Frame"); RightColumn.Size = UDim2.new(0, 400, 1, 0); RightColumn.BackgroundTransparency = 1; RightColumn.Parent = MainContainer
local RightTitle = Instance.new("TextLabel"); RightTitle.Size = UDim2.new(1, 0, 0, 40); RightTitle.BackgroundTransparency = 1; RightTitle.Font = Enum.Font.FredokaOne; RightTitle.Text = "📋 ACTIVE QUESTS"; RightTitle.TextColor3 = Color3.fromRGB(30, 255, 180); RightTitle.TextSize = 22; RightTitle.TextXAlignment = Enum.TextXAlignment.Left; RightTitle.Parent = RightColumn
local QuestsFrame = Instance.new("Frame"); QuestsFrame.Size = UDim2.new(1, 0, 0, 220); QuestsFrame.Position = UDim2.new(0, 0, 0, 45); QuestsFrame.BackgroundTransparency = 1; QuestsFrame.Parent = RightColumn
local QuestsLayout = Instance.new("UIListLayout"); QuestsLayout.Padding = UDim.new(0, 8); QuestsLayout.SortOrder = Enum.SortOrder.LayoutOrder; QuestsLayout.Parent = QuestsFrame

local QuestLabels = {}
for i = 1, 6 do
    local QLabel = Instance.new("TextLabel")
    QLabel.Size = UDim2.new(1, 0, 0, 32); QLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35); QLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    QLabel.TextSize = 14; QLabel.Font = Enum.Font.Gotham; QLabel.TextXAlignment = Enum.TextXAlignment.Left; QLabel.Visible = false; QLabel.Parent = QuestsFrame
    local Corner = Instance.new("UICorner"); Corner.CornerRadius = UDim.new(0, 6); Corner.Parent = QLabel
    local Padding = Instance.new("UIPadding"); Padding.PaddingLeft = UDim.new(0, 12); Padding.Parent = QLabel
    QuestLabels[i] = QLabel
end

local uiVisible = true
ToggleBtn.MouseButton1Click:Connect(function() uiVisible = not uiVisible; FullscreenBG.Visible = uiVisible end)

local startTime = os.time()
local frames = 0
table.insert(_G.AutoRankConnections, RunService.RenderStepped:Connect(function() frames = frames + 1 end))

task.spawn(function()
    while task.wait(1) do
        local diff = os.time() - startTime
        UptimeLabel.Text = string.format("Uptime: %02d:%02d:%02d", math.floor(diff / 3600), math.floor((diff % 3600) / 60), diff % 60)
        FPSLabel.Text = "FPS: " .. tostring(frames)
        frames = 0
    end
end)

local QuestNames = {
    ["BEST_EGG"] = "Hatch Best Eggs", ["EGG"] = "Hatch Eggs", ["BREAKABLE"] = "Break Breakables", ["CURRENT_BREAKABLE"] = "Break in Current Area",
    ["BEST_COIN_JAR"] = "Break Coin Jars", ["COMET"] = "Break Comets", ["COIN_JAR"] = "Break Coin Jars", ["BEST_COMET"] = "Break Comets",
    ["BEST_MINI_CHEST"] = "Break Mini Chests", ["BEST_SUPERIOR_MINI_CHEST"] = "Break Superior Chests", ["BEST_LUCKYBLOCK"] = "Break Lucky Blocks",
    ["BEST_PINATA"] = "Break Piñatas", ["LUCKYBLOCK"] = "Break Lucky Blocks", ["PINATA"] = "Break Piñatas", ["BEST_GOLD_PET"] = "Craft Gold Pets",
    ["BEST_RAINBOW_PET"] = "Craft Rainbow Pets", ["USE_POTION"] = "Use Potions", ["COLLECT_POTION"] = "Upgrade Potions", ["COLLECT_ENCHANT"] = "Upgrade Enchants",
    ["USE_FLAG"] = "Place Flags", ["DIAMOND_BREAKABLE"] = "Break Diamond Objects", ["HATCH_RARE_PET"] = "Hatch Rare Pets", ["CURRENCY"] = "Collect Currency"
}

local function onBreakablesDestroyed(data)
    local tbl = vm:Get("AllBreakables")
    if type(data) == "string" then tbl[data] = nil
    elseif type(data) == "table" then for _, v in pairs(data) do tbl[tostring(v[1])] = nil end end
end

local function onBreakablesCreated(data)
    local tbl = vm:Get("AllBreakables")
    for _, v in pairs(data) do if v[1] and v[1].u then tbl[tostring(v[1].u)] = v[1] end end
end

table.insert(_G.AutoRankConnections, Network.Fired("Breakables_Created"):Connect(onBreakablesCreated))
table.insert(_G.AutoRankConnections, Network.Fired("Breakables_Ping"):Connect(onBreakablesCreated))
table.insert(_G.AutoRankConnections, Network.Fired("Breakables_Destroyed"):Connect(onBreakablesDestroyed))
table.insert(_G.AutoRankConnections, Network.Fired("Breakables_DestroyDueToReplicationFail"):Connect(onBreakablesDestroyed))
table.insert(_G.AutoRankConnections, Network.Fired("Breakables_Cleanup"):Connect(function(data) 
    local tbl = vm:Get("AllBreakables"); for _, v in pairs(data) do tbl[tostring(v[1])] = nil end 
end))

local function updateEuids()
    if type(PetNetworking.EquippedPets()) ~= "table" then return end
    local euids = vm:Get("Euids"); local petids = vm:Get("PetIDs")
    for k in pairs(euids) do euids[k] = nil end
    for k in pairs(petids) do petids[k] = nil end
    for petID, petData in pairs(PetNetworking.EquippedPets()) do euids[petID] = petData; table.insert(petids, petID) end
end
updateEuids()
table.insert(_G.AutoRankConnections, Network.Fired("Pets_LocalPetsUpdated"):Connect(updateEuids))
table.insert(_G.AutoRankConnections, Network.Fired("Pets_LocalPetsUnequipped"):Connect(updateEuids))

local LootbagsFolder = THINGS:FindFirstChild("Lootbags")
if LootbagsFolder then 
    table.insert(_G.AutoRankConnections, LootbagsFolder.ChildAdded:Connect(function(bag) 
        pcall(function() bag.Transparency = 1 end)
        task.wait(); if bag then Network.Fire("Lootbags_Claim", { bag.Name }); bag:Destroy() end 
    end)) 
end
local OrbsFolder = THINGS:FindFirstChild("Orbs")
if OrbsFolder then 
    table.insert(_G.AutoRankConnections, OrbsFolder.ChildAdded:Connect(function(orb) 
        pcall(function() orb.Transparency = 1 end)
        task.wait(); if orb then Network.Fire("Orbs: Collect", { tonumber(orb.Name) }); orb:Destroy() end 
    end)) 
end

task.spawn(function()
    while task.wait(1) do
        local currentWorldNum = GetCurrentWorldNumber()
        local nextZoneId, nextZoneData = ZoneCmds.GetNextZone()
        local maxZoneId, maxZoneData = ZoneCmds.GetMaxOwnedZone()
        if not maxZoneData then continue end
        local nextRebirthData = nil
        pcall(function() nextRebirthData = RebirthCmds.GetNextRebirth() end)
        if nextRebirthData and maxZoneData.ZoneNumber >= nextRebirthData.ZoneNumberRequired then
            vm:Set("IsReadyToFarm", false); vm:Set("OutZoneTime", 0)
            Network.Invoke("Rebirth_Request", tostring(nextRebirthData.RebirthNumber))
            task.wait(10); continue
        end
        if nextZoneData and nextZoneData.WorldNumber and nextZoneData.WorldNumber ~= currentWorldNum then
            vm:Set("IsReadyToFarm", false); vm:Set("OutZoneTime", 0)
            pcall(function() Network.Invoke("World" .. nextZoneData.WorldNumber .. "Teleport") end)
            task.wait(8); continue
        end
        if nextZoneData and nextZoneData.WorldNumber == currentWorldNum then
            local coins = getcurrency(); local gatePrice = 0
            pcall(function() gatePrice = CalcGatePrice(nextZoneData) end)
            if gatePrice and coins and gatePrice <= coins and not vm:Get("IsPetQuestActive") then
                vm:Set("IsReadyToFarm", false)
                if Network.Invoke("Zones_RequestPurchase", nextZoneId) then task.wait(0.5); continue end
            end
        end
        local zoneFolder = GetZoneFolderByOffset(0)
        if zoneFolder and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetPart = nil
            if zoneFolder:FindFirstChild("INTERACT") and zoneFolder.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then targetPart = zoneFolder.INTERACT.BREAKABLE_SPAWNS:FindFirstChild("Main") or zoneFolder.INTERACT.BREAKABLE_SPAWNS:GetChildren()[1] end
            if not targetPart and zoneFolder:FindFirstChild("PERSISTENT") and zoneFolder.PERSISTENT:FindFirstChild("Teleport") then targetPart = zoneFolder.PERSISTENT.Teleport end
            if targetPart then
                local hrp = LocalPlayer.Character.HumanoidRootPart
                local dist = (hrp.Position - targetPart.Position).Magnitude
                local previousZone = vm:Get("TargetZoneId")
                if previousZone ~= maxZoneId then
                    vm:Set("IsReadyToFarm", false); hrp.CFrame = targetPart.CFrame + Vector3.new(0, 2, 0); task.wait(0.5); vm:Set("TargetZoneId", maxZoneId); vm:Set("OutZoneTime", 0)
                else
                    if dist > 45 then
                        if vm:Get("IsPetQuestActive") then vm:Set("OutZoneTime", 0); vm:Set("IsReadyToFarm", false)
                        else
                            local outTime = vm:Get("OutZoneTime")
                            if outTime == 0 then vm:Set("OutZoneTime", os.clock())
                            elseif os.clock() - outTime >= 5 then vm:Set("IsReadyToFarm", false); hrp.CFrame = targetPart.CFrame + Vector3.new(0, 2, 0); task.wait(0.5); vm:Set("OutZoneTime", 0) end
                        end
                    else vm:Set("OutZoneTime", 0); vm:Set("IsReadyToFarm", true); vm:Set("current_zone", maxZoneId) end
                end
            else vm:Set("IsReadyToFarm", false) end
        else vm:Set("IsReadyToFarm", false) end
    end
end)

-- TỐI ƯU HÓA: Gộp vòng lặp đập rương và gán Pet lại để chạy đồng bộ, giảm số lượng gói tin rác
task.spawn(function()
    while task.wait(0.3) do 
        if not vm:Get("IsReadyToFarm") then continue end
        local zone = vm:Get("current_zone")
        if not zone then continue end
        
        -- Copy danh sách Breakables (Chống xung đột)
        local availableBreakables = {}
        for key, info in pairs(vm:Get("AllBreakables")) do 
            if info.pid == zone then table.insert(availableBreakables, key) end 
        end
        
        local numB = #availableBreakables
        if numB > 0 then
            -- 1. Xử lý Gửi Damage (Gửi Bulk, giảm rác)
            pcall(function()
                local maxDamageSend = math.min(numB, 5) -- Chỉ spam tối đa 5 rương 1 nhịp
                for i = 1, maxDamageSend do Network.UnreliableFire("Breakables_PlayerDealDamage", availableBreakables[i]) end
            end)

            -- 2. Xử lý Gán Pet (Chỉ xử lý khi có Pet)
            local petIDs = vm:Get("PetIDs"); local numP = #petIDs
            if numP > 0 then
                local bulkAssignments = {}; local euids = vm:Get("Euids")
                for i, petID in ipairs(petIDs) do
                    if euids[petID] then bulkAssignments[petID] = availableBreakables[(i % numB) + 1] end
                end
                if next(bulkAssignments) then pcall(function() Network.Fire("Breakables_JoinPetBulk", bulkAssignments) end) end
            end
        end
    end
end)

task.spawn(function() while task.wait(15) do pcall(function() Network.Invoke('Mailbox: Claim All') end) end end)

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local data = Save.Get()
            if not data then return end
            local maxSlots = DaycareCmds.GetMaxSlots(); local usedSlots = DaycareCmds.GetUsedSlots(); local freeSlots = maxSlots - usedSlots
            local daycareActive = data.DaycareActive or {}
            for uid, petData in pairs(daycareActive) do
                if DaycareCmds.ComputeRemainingTime(petData, workspace:GetServerTimeNow()) <= 0 then Network.Invoke("Daycare: Claim", uid); task.wait(0.5) end
            end
            if freeSlots > 0 then
                local invPets = data.Inventory.Pet or {}; local equippedPets = {}
                pcall(function() equippedPets = PetNetworking.EquippedPets() or {} end)
                local validPetsList = {}
                for uid, pet in pairs(invPets) do
                    if equippedPets[uid] then continue end
                    if not pet.id:match("Huge") and not pet.id:match("Titanic") and not pet.l then
                        local score = 0
                        pcall(function()
                            local _, lootMultiplier = DaycareLoot.ComputePetLootPool(LocalPlayer, PetItem(pet.id))
                            score = (lootMultiplier or 0) + ((pet.pt == 2 and 50) or (pet.pt == 1 and 20) or 0) + (pet.sh and 30 or 0)
                        end)
                        table.insert(validPetsList, { uid = uid, amount = pet._am or 1, score = score, name = pet.id })
                    end
                end
                table.sort(validPetsList, function(a, b) return a.score > b.score end)
                local petsToEnroll = {}; local slotsFilled = 0
                for _, petData in ipairs(validPetsList) do
                    if slotsFilled >= freeSlots then break end
                    local takeAmount = math.min(petData.amount, freeSlots - slotsFilled)
                    if takeAmount > 0 then petsToEnroll[petData.uid] = takeAmount; slotsFilled = slotsFilled + takeAmount end
                end
                if slotsFilled > 0 then Network.Invoke("Daycare: Enroll", petsToEnroll) end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(10) do
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
    while task.wait(5) do
        pcall(function()
            local currentEquips = Save.Get()["PetSlotsPurchased"] or 0
            if currentEquips < RankCmds.GetMaxPurchasableEquipSlots() then Network.Invoke("EquipSlotsMachine_RequestPurchase", currentEquips + 1) end
        end)
    end
end)

task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            local equipped = UltimateCmds.GetEquippedItem()
            if equipped and equipped._data and equipped._data.id then UltimateCmds.Activate(equipped._data.id) end
        end)
    end
end)

local config = getgenv().AutoRankConfig or {}
local QuestPriority = {}
local UserPriority = config.QuestPriority or {}
for questName, defaultPrio in pairs({
	ZONE_GATE = 0, EGG = 1, BEST_EGG = 1, USE_POTION = 1, USE_FLAG = 1,
	BEST_RAINBOW_PET = 2, BEST_GOLD_PET = 2, COLLECT_POTION = 2, COLLECT_ENCHANT = 2,
	COMET = 3, BEST_COMET = 3, COIN_JAR = 4, BEST_COIN_JAR = 4,
	PINATA = 5, BEST_PINATA = 5, LUCKYBLOCK = 6, BEST_LUCKYBLOCK = 6,
	CURRENT_BREAKABLE = 7, BEST_SUPERIOR_MINI_CHEST = 7, DIAMOND_BREAKABLE = 7,
    BEST_MINI_CHEST = 7, HATCH_RARE_PET = 7, CURRENCY = 7,	
}) do QuestPriority[questName] = UserPriority[questName] ~= nil and UserPriority[questName] or defaultPrio end

local function GetQuestNameByID(id)
    for name, val in pairs(QuestsGoals) do if val == id then return name end end
    return "UNKNOWN_"..tostring(id)
end

local function CheckItemExact(itemName)
    local inv = Save.Get().Inventory.Misc; if not inv then return false, nil end
    for uid, item in pairs(inv) do if type(item.id) == "string" and item.id == itemName then return true, uid end end
    return false, nil
end

local function CheckPotion(tier, needed)
    local inv = Save.Get().Inventory.Potion; if not inv then return false, nil, 0 end
    for uid, item in pairs(inv) do if tier <= (item.tn or 1) and needed <= (item._am or 1) then return true, uid, (item._am or 1) end end
    return false, nil, 0
end

local function FormatValue(Value)
    local n = tonumber(Value); if not n then return tostring(Value) end
    local suffixes = {"", "k", "m", "b", "t"}; local index = 1; local absNumber = math.abs(n)
    while absNumber >= 1000 and index < #suffixes do absNumber = absNumber / 1000; index = index + 1 end
    return (absNumber >= 1 and index > 1) and string.format("%.2f", absNumber):gsub("%.00$", "") .. suffixes[index] or tostring(math.floor(absNumber)) .. suffixes[index]
end

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local currentSave = Save.Get(); local totalStars = 0; local currentTitle = RankCmds.GetTitle()
            
            -- Tối ưu: Dọn dẹp Cooldown rác cũ hơn 10 phút
            for qName, timestamp in pairs(_G.StuckCooldown) do
                if os.time() - timestamp > 600 then _G.StuckCooldown[qName] = nil end
            end

            -- Update webhook UI + Claim rank
            if currentSave.Rank > lastRank then SendRankUpWebhook(currentSave.Rank, currentTitle); lastRank = currentSave.Rank end
            if RanksDirectory[currentTitle] and RanksDirectory[currentTitle].Rewards then
                for i, v in pairs(RanksDirectory[currentTitle].Rewards) do
                    totalStars = totalStars + v.StarsRequired
                    if currentSave.RankStars >= totalStars and not currentSave.RedeemedRankRewards[tostring(i)] then Network.Fire("Ranks_ClaimReward", i); task.wait(0.5) end
                end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local save = Save.Get()
            if save then RankLabel.Text = "Rank: " .. tostring(save.Rank or 1); StarsLabel.Text = "Stars: " .. FormatValue(save.RankStars or 0) end
        end)
    end
end)

-- Main Quest Loop
task.spawn(function()
    while task.wait(1) do
        if not vm:Get("IsReadyToFarm") and not vm:Get("IsPetQuestActive") then continue end
        local data = Save.Get(); if not data then continue end
        local activeQuests = {}
        if data.ZoneGateQuest then
            local q = data.ZoneGateQuest
            table.insert(activeQuests, { goalId = "ZoneGate", name = GetQuestNameByID(q.Type), priority = QuestPriority.ZONE_GATE, progress = q.Progress or 0, target = q.Amount or 1, tier = q.PotionTier or q.Tier or 1 })
        end
        for goalId, goalData in pairs(data.Goals or {}) do
            local qName = GetQuestNameByID(goalData.Type)
            table.insert(activeQuests, { goalId = goalId, name = qName, priority = QuestPriority[qName] or 99, progress = goalData.Progress or 0, target = goalData.Amount or 1, tier = goalData.PotionTier or goalData.Tier or 1 })
        end
        
        local isPetQuestActive = false
        for _, q in ipairs(activeQuests) do
            if not (_G.StuckCooldown[q.name] and (os.time() - _G.StuckCooldown[q.name] < 300)) and (q.target - q.progress > 0) then
                if string.find(q.name, "PET") or string.find(q.name, "FLAG") or string.find(q.name, "COMET") or string.find(q.name, "PINATA") or string.find(q.name, "COIN_JAR") or string.find(q.name, "LUCKYBLOCK") then
                    isPetQuestActive = true; break
                end
            end
        end
        vm:Set("IsPetQuestActive", isPetQuestActive)
        table.sort(activeQuests, function(a, b) return a.priority < b.priority end)
        
        local actionTakenThisLoop = false; local currentActiveQuestName = nil 
        
        for index, quest in ipairs(activeQuests) do
            local needed = quest.target - quest.progress
            local isCooldown = _G.StuckCooldown[quest.name] and (os.time() - _G.StuckCooldown[quest.name] < 300)
            
            if needed > 0 and not isCooldown then
                -- 1. Vật phẩm
                if string.find(quest.name, "COMET") or string.find(quest.name, "PINATA") or string.find(quest.name, "COIN_JAR") or string.find(quest.name, "LUCKYBLOCK") then
                    local itemName, remoteName = "", ""
                    if quest.name:find("COMET") then itemName = "Comet"; remoteName = "Comet_Spawn"
                    elseif quest.name:find("PINATA") then itemName = "Mini Pinata"; remoteName = "MiniPinata_Consume"
                    elseif quest.name:find("COIN_JAR") then itemName = "Basic Coin Jar"; remoteName = "CoinJar_Spawn"
                    elseif quest.name:find("LUCKYBLOCK") then itemName = "Mini Lucky Block"; remoteName = "MiniLuckyBlock_Consume" end

                    if not actionTakenThisLoop then 
                        if os.clock() - (vm:Get("ActionTime_" .. quest.goalId) or 0) > 15 then 
                            local hasItem, uid = CheckItemExact(itemName)
                            if hasItem then
                                if vm:Get("IsReadyToFarm") then vm:Set("ActionTime_" .. quest.goalId, os.clock()); task.spawn(function() pcall(function() Network.Invoke(remoteName, uid) end) end) end
                                actionTakenThisLoop = true; currentActiveQuestName = quest.name
                            else _G.StuckCooldown[quest.name] = os.time(); SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name) end
                        else if not currentActiveQuestName then currentActiveQuestName = quest.name end end
                    end
                end
                
                -- 2. Thuốc
                if quest.name == "USE_POTION" then
                    if not actionTakenThisLoop then
                        if not vm:Get("IsDrinking_" .. quest.goalId) then
                            local hasPot, uid, availableAmt = CheckPotion(quest.tier, needed)
                            if hasPot then
                                local drinkAmt = math.min(needed, availableAmt)
                                vm:Set("IsDrinking_" .. quest.goalId, true)
                                task.spawn(function() pcall(function() Network.Fire("Potions: Consume", uid, drinkAmt) end); task.wait(1.5); vm:Set("IsDrinking_" .. quest.goalId, false) end)
                                actionTakenThisLoop = true; currentActiveQuestName = quest.name
                            else _G.StuckCooldown[quest.name] = os.time(); SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name) end
                        else if not currentActiveQuestName then currentActiveQuestName = quest.name end end
                    end
                end
                
                -- 3. Cờ
                if quest.name == "USE_FLAG" then
                    if not actionTakenThisLoop then
                        if os.clock() - (vm:Get("ActionTime_" .. quest.goalId) or 0) > 4 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            local bestFlagId, bestFlagUid, maxAmt = nil, nil, 0
                            for uid, item in pairs(Save.Get().Inventory.Misc or {}) do
                                if type(item.id) == "string" and item.id:find("Flag") and rawget(ZoneFlagsDir, item.id) and (item._am or 1) > maxAmt then maxAmt = item._am or 1; bestFlagId = item.id; bestFlagUid = uid end
                            end
                            if maxAmt > 0 then
                                actionTakenThisLoop = true; currentActiveQuestName = quest.name
                                task.spawn(function()
                                    local craftAmt = math.min(maxAmt, needed, 24); local zoneOffset = vm:Get("FlagZoneOffset") or 0
                                    local zoneFolder, targetZoneNum = GetZoneFolderByOffset(zoneOffset)
                                    if zoneFolder then
                                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                        if hrp then
                                            if not zoneFolder:FindFirstChild("INTERACT") or (hrp.Position - zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.Position).Magnitude > 50 then
                                                if zoneFolder:FindFirstChild("PERSISTENT") then hrp.CFrame = zoneFolder.PERSISTENT.Teleport.CFrame; task.wait(0.6) end
                                            end
                                            if zoneFolder:FindFirstChild("INTERACT") and zoneFolder.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then hrp.CFrame = zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.CFrame + Vector3.new(0, 2, 0) end
                                            task.wait(0.5); pcall(function() FlexibleFlagCmds.Consume(bestFlagId, bestFlagUid, craftAmt) end); task.wait(2.8)
                                            local newInv = Save.Get().Inventory.Misc or {}
                                            if maxAmt - (newInv[bestFlagUid] and (newInv[bestFlagUid]._am or 1) or 0) > 0 then vm:Set("FlagZoneOffset", 0) 
                                            else vm:Set("FlagZoneOffset", (zoneOffset + 1 > 20) and 0 or (zoneOffset + 1)); task.wait(1) end
                                        end
                                    end
                                end)
                            else _G.StuckCooldown[quest.name] = os.time(); SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name) end
                        else if not currentActiveQuestName then currentActiveQuestName = quest.name end end
                    end
                end
                
               -- 4. Ép Thuốc / Sách (Tối ưu setthreadidentity)
                if quest.name == "COLLECT_POTION" or quest.name == "COLLECT_ENCHANT" then
                    if not actionTakenThisLoop then
                        local isPotion = (quest.name == "COLLECT_POTION")
                        if os.clock() - (vm:Get("ActionTime_" .. quest.goalId) or 0) > 4 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            local bestUid, bestCraftAmt, bestTier = nil, 0, 999
                            local AllowedEnchants = { "Treasure Hunter", "Tap Power", "Strong Pets", "Lucky Eggs", "Diamonds", "Criticals", "Coins" }
                            local AllowedPotions = { "Coins", "Damage", "Diamonds", "Lucky Eggs", "Treasure Hunter" }
                            
                            setthreadidentity(4) -- Đưa ra ngoài vòng lặp
                            for uid, dat in pairs(Save.Get().Inventory[isPotion and "Potion" or "Enchant"] or {}) do
                                local tier = dat.tn or 1; local baseName = dat.id or ""
                                local isAllowed = isPotion and table.find(AllowedPotions, baseName) or table.find(AllowedEnchants, baseName)

                                if tier >= 1 and tier <= (isPotion and 4 or 3) and isAllowed then
                                    local possibleCraft = math.floor((dat._am or 1) / (isPotion and CalcPotion(tier) or CalcEnchant(tier)))
                                    if possibleCraft > 0 and (tier < bestTier or (tier == bestTier and possibleCraft > bestCraftAmt)) then
                                        bestTier = tier; bestCraftAmt = possibleCraft; bestUid = uid
                                    end
                                end
                            end
                            
                            if bestCraftAmt > 0 and bestUid then
                                actionTakenThisLoop = true; currentActiveQuestName = quest.name
                                task.spawn(function()
                                    local craftAmt = math.min(bestCraftAmt, needed or 1)
                                    setthreadidentity(4); pcall(function() Network.Invoke(isPotion and "UpgradePotionsMachine_Activate" or "UpgradeEnchantsMachine_Activate", bestUid, craftAmt) end); task.wait(3.5)  
                                end)
                            else _G.StuckCooldown[quest.name] = os.time(); SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name) end
                        else if not currentActiveQuestName then currentActiveQuestName = quest.name end end
                    end
                end
                
                -- 5. Trứng
                if quest.name == "BEST_EGG" or quest.name == "HATCH_RARE_PET" or quest.name == "EGG" then
                    if not actionTakenThisLoop then
                        if os.clock() - (vm:Get("ActionTime_" .. quest.goalId) or 0) > 2.5 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            actionTakenThisLoop = true; currentActiveQuestName = quest.name
                            task.spawn(function() ToggleEggAnimation(); HatchBestEgg() end)
                        else if not currentActiveQuestName then currentActiveQuestName = quest.name end end
                    end
                end
                
                -- 6. Pet
                if quest.name == "BEST_GOLD_PET" or quest.name == "BEST_RAINBOW_PET" then
                    if not actionTakenThisLoop then
                        if os.clock() - (vm:Get("ActionTime_" .. quest.goalId) or 0) > 3 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            actionTakenThisLoop = true; currentActiveQuestName = quest.name
                            task.spawn(function()
                                ToggleEggAnimation()
                                local isRainbow = (quest.name == "BEST_RAINBOW_PET"); local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                if not hrp then return end
                                local maxGoldUid, maxGoldAmt, maxNormalUid, maxNormalAmt = nil, 0, nil, 0
                                for uid, data in pairs(GetBestGoldenPetsUID()) do if data.Amount > maxGoldAmt then maxGoldUid = uid; maxGoldAmt = data.Amount end end
                                for uid, data in pairs(GetBestNormalPetsUID()) do if data.Amount > maxNormalAmt then maxNormalUid = uid; maxNormalAmt = data.Amount end end
                                
                                local reqEquiv = isRainbow and (needed * 100) or (needed * 10)
                                local deficitNormals = 0; local requiredEquivNormals = isRainbow and (needed * 100) or (needed * 10)
                                if isRainbow then
                                    local totalEquivNormals = maxNormalAmt + (maxGoldAmt * 10); deficitNormals = requiredEquivNormals - totalEquivNormals
                                    if maxNormalAmt >= 2000 and totalEquivNormals < requiredEquivNormals then Network.Invoke('GoldMachine_Activate', maxNormalUid, math.floor(maxNormalAmt / 10)); return end
                                    if totalEquivNormals >= requiredEquivNormals then
                                        if maxNormalAmt >= 10 then Network.Invoke('GoldMachine_Activate', maxNormalUid, math.floor(maxNormalAmt / 10)); return
                                        elseif maxGoldAmt >= 10 then Network.Invoke('RainbowMachine_Activate', maxGoldUid, math.min(math.floor(maxGoldAmt / 10), needed)); return end
                                    end
                                else
                                    deficitNormals = requiredEquivNormals - maxNormalAmt
                                    if maxNormalAmt >= 2000 and maxNormalAmt < requiredEquivNormals then Network.Invoke('GoldMachine_Activate', maxNormalUid, math.floor(maxNormalAmt / 10)); return end
                                    if maxNormalAmt >= requiredEquivNormals then Network.Invoke('GoldMachine_Activate', maxNormalUid, needed); return end
                                end
                                
                                if deficitNormals > 0 then
                                    local bestEggModule = GetBestEggModule(); if not bestEggModule then return end
                                    local zoneFolder = ZoneCmds.GetMaximumZone().ZoneFolder
                                    if zoneFolder then
                                        if not zoneFolder:FindFirstChild('INTERACT') or (hrp.Position - zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.Position).Magnitude > 50 then
                                            if zoneFolder:FindFirstChild('PERSISTENT') then hrp.CFrame = zoneFolder.PERSISTENT.Teleport.CFrame end
                                            local t = 0; while not zoneFolder:FindFirstChild('INTERACT') and t < 30 do task.wait(0.1); t = t + 1 end
                                        end
                                        if zoneFolder:FindFirstChild('INTERACT') and zoneFolder.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then
                                            if (hrp.Position - zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.Position).Magnitude > 15 then hrp.CFrame = zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.CFrame + Vector3.new(0, 2, 0) end
                                        end
                                    end
                                    if getcurrency() >= CalcEggPricePlayer(bestEggModule) * EggCmds.GetMaxHatch() then HatchBestEgg() end
                                end
                            end)
                        else if not currentActiveQuestName then currentActiveQuestName = quest.name end end
                    end
                end
            end
            
            -- Cập nhật UI
            if index <= 6 then
                local percent = math.min(math.floor((quest.progress / quest.target) * 100), 100)
                local prefix = (quest.goalId == "ZoneGate") and "[🔥 GATE]" or string.format("[P%d]", quest.priority)
                if currentActiveQuestName == quest.name then prefix = "➔ " .. prefix elseif isCooldown then prefix = "[⏳ 5M] " .. prefix end
                local displayName = QuestNames[quest.name] or quest.name
                
                if quest.progress >= quest.target then
                    QuestLabels[index].TextColor3 = Color3.fromRGB(50, 255, 50)
                    QuestLabels[index].Text = "✅ " .. displayName .. " - DONE!"
                else
                    QuestLabels[index].TextColor3 = isCooldown and Color3.fromRGB(255, 100, 100) or ((quest.goalId == "ZoneGate") and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(200, 200, 255))
                    QuestLabels[index].Text = string.format("%s %s: %s / %s (%d%%)", prefix, displayName, FormatValue(quest.progress), FormatValue(quest.target), percent)
                end
                QuestLabels[index].Visible = true
            end
        end
        for i = #activeQuests + 1, 6 do QuestLabels[i].Visible = false end
    end
end)

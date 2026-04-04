if _G.AutoRankStarted then return end
_G.AutoRankStarted = true

_G.StuckCooldown = _G.StuckCooldown or {}

local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
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
        ["embeds"] = {
            {
                ["title"] = "🎉 LEVEL UP NOTIFICATION 🎉",
                ["description"] = "**Account:** ||" .. LocalPlayer.Name .. "||\n**Ranked Up To:** Rank " .. tostring(newRank) .. " - " .. tostring(newTitle),
                ["type"] = "rich",
                ["color"] = tonumber(0x00FF00),
                ["footer"] = { ["text"] = "Poodle Auto Rank System" },
                ["timestamp"] = DateTime.now():ToIsoDate()
            }
        }
    }
    pcall(function()
        httprequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) })
    end)
end

local function SendMaterialShortageWebhook(questName)
    if not NOTIFY_SHORTAGE or WEBHOOK_URL == "" then return end
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest then return end
    local data = {
        ["content"] = "⚠️ Alert: More ingredients are needed!",
        ["embeds"] = {
            {
                ["title"] = "Out of Quest Materials!",
                ["description"] = "**Account:** ||" .. LocalPlayer.Name .. "||\n**The mission is stuck.:** " .. tostring(questName) .. "\n*The system automatically skipped this task for 5 minutes.*",
                ["type"] = "rich",
                ["color"] = tonumber(0xFF5500),
                ["footer"] = { ["text"] = "Poodle Auto Rank System" },
                ["timestamp"] = DateTime.now():ToIsoDate()
            }
        }
    }
    pcall(function()
        httprequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) })
    end)
end

task.spawn(function()
    pcall(function()
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")
        local hum = character:WaitForChild("Humanoid")
        local bg = Instance.new("BodyGyro")
        local bv = Instance.new("BodyVelocity")
        bg.P = 9e4
        bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.cframe = hrp.CFrame
        bg.Parent = hrp
        bv.velocity = Vector3.new(0, 0, 0)
        bv.maxForce = Vector3.new(9e9, 9e9, 9e9)
        bv.Parent = hrp
        task.spawn(function()
            while task.wait() do
                pcall(function()
                    hum.PlatformStand = true
                    bv.velocity = Vector3.new(0, 0, 0)
                    bg.cframe = hrp.CFrame
                end)
            end
        end)
    end)
end)

local function ExtremeOptimize(v)
    pcall(function()
        if v:IsA("BasePart") then
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0
            v.CastShadow = false
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("Smoke") then
            v.Enabled = false
        elseif v:IsA("Explosion") then
            v.Visible = false
        elseif v:IsA("PostEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("BlurEffect") then
            v.Enabled = false
        end
    end)
end

for _, v in ipairs(Workspace:GetDescendants()) do ExtremeOptimize(v) end
for _, v in ipairs(Lighting:GetDescendants()) do ExtremeOptimize(v) end

Workspace.DescendantAdded:Connect(function(v) ExtremeOptimize(v) end)
Lighting.DescendantAdded:Connect(function(v) ExtremeOptimize(v) end)

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
vm:Add("AllBreakables", {}, "table")
vm:Add("Euids", {}, "table")
vm:Add("PetIDs", {}, "table")
vm:Add("current_zone", nil, "string")
vm:Add("IsReadyToFarm", false, "boolean") 
vm:Add("OutZoneTime", 0, "number") 
vm:Add("TargetZoneId", nil, "string")
vm:Add("FlagZoneOffset", 0, "number")
vm:Add("IsPetQuestActive", false, "boolean") 

pcall(function() 
    local PetModule = require(Library.Client.PlayerPet)
    PetModule.CalculateSpeedMultiplier = function() return math.huge end 
end)

LocalPlayer.Idled:Connect(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)

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
local function GetZoneFolderByOffset(offset)
    local maxZoneId, maxZoneData = ZoneCmds.GetMaxOwnedZone()
    if not maxZoneData then return nil, 1 end
    local targetNum = maxZoneData.ZoneNumber - offset
    if targetNum < 1 then targetNum = 1 end
    local searchPattern = "^" .. tostring(targetNum) .. " |"
    for _, folderName in ipairs({"Map", "Map2", "Map3", "Map4", "Map5", "Map6"}) do
        local mapFolder = Workspace:FindFirstChild(folderName)
        if mapFolder then 
            for _, zoneFolder in pairs(mapFolder:GetChildren()) do 
                if string.find(zoneFolder.Name, searchPattern) then 
                    return zoneFolder, targetNum 
                end 
            end 
        end
    end
    return nil, targetNum
end
local function GetBestEggModule()
    local maxAvailableEgg = ZoneCmds.GetMaximumOverallZone().MaximumAvailableEgg
    for _, egg in pairs(DirectoryEggs) do
        if egg.eggNumber == maxAvailableEgg then return egg end
    end
    return nil
end
local function HatchBestEgg()
    local maxHatch = EggCmds.GetMaxHatch()
    local bestEgg = GetBestEggModule()
    if bestEgg and bestEgg._id then
        Network.Invoke('Eggs_RequestPurchase', bestEgg._id, maxHatch)
    end
end
local function GetPetsFromEgg()
    local v35 = {}
    local eggMod = GetBestEggModule()
    if not eggMod or type(eggMod.pets) ~= "table" then return v35 end
    for _, v36 in pairs(eggMod.pets) do
        if type(v36) == "table" and v36[1] and not v36[1]:match('Huge') then table.insert(v35, v36[1]) end
    end
    return v35
end
local function GetBestNormalPetsUID()
    local inv = Save.Get().Inventory
    if not inv or type(inv.Pet) ~= "table" then return {} end
    local v52 = GetPetsFromEgg()
    local v56 = {}
    for uid, v57 in pairs(inv.Pet) do
        if table.find(v52, v57.id) and not (v57.pt or v57.sh) then
            v56[uid] = { PetName = v57.id, Rarity = v57.pt or 0, UID = uid, Amount = v57._am or 1 }
        end
    end
    return v56
end
local function GetBestGoldenPetsUID()
    local inv = Save.Get().Inventory
    if not inv or type(inv.Pet) ~= "table" then return {} end
    local v59 = GetPetsFromEgg()
    local v63 = {}
    for uid, v64 in pairs(inv.Pet) do
        if table.find(v59, v64.id) and (v64.pt == 1 and not v64.sh) then
            v63[uid] = { PetName = v64.id, Rarity = v64.pt, UID = uid, Amount = v64._am or 1 }
        end
    end
    return v63
end

if CoreGui:FindFirstChild("AutoRankUI") then
    CoreGui.AutoRankUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoRankUI"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local FullscreenBG = Instance.new("Frame")
FullscreenBG.Size = UDim2.new(1, 0, 1, 0)
FullscreenBG.BackgroundColor3 = Color3.fromRGB(14, 19, 30)
FullscreenBG.BorderSizePixel = 0
FullscreenBG.Parent = ScreenGui

local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(1, -20, 1, -20)
ToggleBtn.AnchorPoint = Vector2.new(1, 1)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Image = "rbxassetid://139164748850995"
ToggleBtn.Parent = ScreenGui

local MainContainer = Instance.new("Frame")
MainContainer.Size = UDim2.new(0, 720, 0.85, 0)
MainContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
MainContainer.AnchorPoint = Vector2.new(0.5, 0.5)
MainContainer.BackgroundTransparency = 1
MainContainer.Parent = FullscreenBG

local MainLayout = Instance.new("UIListLayout")
MainLayout.FillDirection = Enum.FillDirection.Horizontal
MainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
MainLayout.VerticalAlignment = Enum.VerticalAlignment.Center
MainLayout.Padding = UDim.new(0, 15)
MainLayout.Parent = MainContainer

local LeftColumn = Instance.new("Frame")
LeftColumn.Size = UDim2.new(0, 280, 1, 0)
LeftColumn.BackgroundTransparency = 1
LeftColumn.Parent = MainContainer

local LeftList = Instance.new("UIListLayout")
LeftList.SortOrder = Enum.SortOrder.LayoutOrder
LeftList.Padding = UDim.new(0, 12)
LeftList.Parent = LeftColumn

local PlayerInfo = Instance.new("Frame")
PlayerInfo.Size = UDim2.new(1, 0, 0, 90)
PlayerInfo.BackgroundTransparency = 1
PlayerInfo.Parent = LeftColumn

local Avatar = Instance.new("ImageLabel")
Avatar.Size = UDim2.new(0, 70, 0, 70)
Avatar.Position = UDim2.new(0, 10, 0.5, -35)
Avatar.BackgroundTransparency = 1
Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=420&h=420"
Avatar.Parent = PlayerInfo

local UsernameLabel = Instance.new("TextLabel")
UsernameLabel.Size = UDim2.new(1, -90, 0, 35)
UsernameLabel.Position = UDim2.new(0, 90, 0, 10)
UsernameLabel.BackgroundTransparency = 1
UsernameLabel.Font = Enum.Font.FredokaOne
UsernameLabel.Text = LocalPlayer.DisplayName
UsernameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
UsernameLabel.TextSize = 24
UsernameLabel.TextXAlignment = Enum.TextXAlignment.Left
UsernameLabel.Parent = PlayerInfo

local RankLabel = Instance.new("TextLabel")
RankLabel.Size = UDim2.new(1, -90, 0, 25)
RankLabel.Position = UDim2.new(0, 90, 0, 48)
RankLabel.BackgroundTransparency = 1
RankLabel.Font = Enum.Font.GothamBold
RankLabel.Text = "Rank: Loading..."
RankLabel.TextColor3 = Color3.fromRGB(80, 200, 255)
RankLabel.TextSize = 18
RankLabel.TextXAlignment = Enum.TextXAlignment.Left
RankLabel.Parent = PlayerInfo

local StarsFrame = Instance.new("Frame")
StarsFrame.Size = UDim2.new(1, 0, 0, 30)
StarsFrame.BackgroundTransparency = 1
StarsFrame.Parent = LeftColumn

local StarsLabel = Instance.new("TextLabel")
StarsLabel.Size = UDim2.new(1, 0, 1, 0)
StarsLabel.BackgroundTransparency = 1
StarsLabel.Font = Enum.Font.GothamBold
StarsLabel.Text = "Stars: 0"
StarsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
StarsLabel.TextSize = 18
StarsLabel.TextXAlignment = Enum.TextXAlignment.Left
StarsLabel.Parent = StarsFrame

local UptimeLabel = Instance.new("TextLabel")
UptimeLabel.Size = UDim2.new(1, 0, 0, 30)
UptimeLabel.BackgroundTransparency = 1
UptimeLabel.Font = Enum.Font.Gotham
UptimeLabel.Text = "Uptime: 00:00:00"
UptimeLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
UptimeLabel.TextSize = 16
UptimeLabel.TextXAlignment = Enum.TextXAlignment.Left
UptimeLabel.Parent = LeftColumn

local FPSLabel = Instance.new("TextLabel")
FPSLabel.Size = UDim2.new(1, 0, 0, 30)
FPSLabel.BackgroundTransparency = 1
FPSLabel.Font = Enum.Font.Gotham
FPSLabel.Text = "FPS: 0"
FPSLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
FPSLabel.TextSize = 16
FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
FPSLabel.Parent = LeftColumn

local Watermark1 = Instance.new("TextLabel")
Watermark1.Size = UDim2.new(1, 0, 0, 25)
Watermark1.BackgroundTransparency = 1
Watermark1.Font = Enum.Font.GothamBold
Watermark1.Text = "Poodle Auto Rank"
Watermark1.TextColor3 = Color3.fromRGB(30, 255, 180) 
Watermark1.TextSize = 18
Watermark1.TextXAlignment = Enum.TextXAlignment.Left
Watermark1.Parent = LeftColumn

local Watermark2 = Instance.new("TextLabel")
Watermark2.Size = UDim2.new(1, 0, 0, 20)
Watermark2.BackgroundTransparency = 1
Watermark2.Font = Enum.Font.Gotham
Watermark2.Text = "https://discord.gg/hRumkfeMcM"
Watermark2.TextColor3 = Color3.fromRGB(150, 150, 255) 
Watermark2.TextSize = 14
Watermark2.TextXAlignment = Enum.TextXAlignment.Left
Watermark2.Parent = LeftColumn

local RightColumn = Instance.new("Frame")
RightColumn.Size = UDim2.new(0, 400, 1, 0)
RightColumn.BackgroundTransparency = 1
RightColumn.Parent = MainContainer

local RightTitle = Instance.new("TextLabel")
RightTitle.Size = UDim2.new(1, 0, 0, 40)
RightTitle.BackgroundTransparency = 1
RightTitle.Font = Enum.Font.FredokaOne
RightTitle.Text = "📋 ACTIVE QUESTS"
RightTitle.TextColor3 = Color3.fromRGB(30, 255, 180)
RightTitle.TextSize = 22
RightTitle.TextXAlignment = Enum.TextXAlignment.Left
RightTitle.Parent = RightColumn

local QuestsFrame = Instance.new("Frame")
QuestsFrame.Size = UDim2.new(1, 0, 0, 220) 
QuestsFrame.Position = UDim2.new(0, 0, 0, 45)
QuestsFrame.BackgroundTransparency = 1
QuestsFrame.Parent = RightColumn

local QuestsLayout = Instance.new("UIListLayout")
QuestsLayout.Padding = UDim.new(0, 8)
QuestsLayout.SortOrder = Enum.SortOrder.LayoutOrder
QuestsLayout.Parent = QuestsFrame

local QuestLabels = {}
for i = 1, 6 do
    local QLabel = Instance.new("TextLabel")
    QLabel.Size = UDim2.new(1, 0, 0, 32)
    QLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    QLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    QLabel.TextSize = 14
    QLabel.Font = Enum.Font.Gotham
    QLabel.TextXAlignment = Enum.TextXAlignment.Left
    QLabel.Visible = false
    QLabel.Parent = QuestsFrame
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = QLabel
    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 12)
    Padding.Parent = QLabel
    QuestLabels[i] = QLabel
end

-- ================= KHUNG HIỂN THỊ LOG HOÀN TOÀN MỚI =================
local LogFrame = Instance.new("Frame")
LogFrame.Size = UDim2.new(1, 0, 1, -280)
LogFrame.Position = UDim2.new(0, 0, 0, 275)
LogFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
LogFrame.BorderSizePixel = 0
LogFrame.Parent = RightColumn

local LogCorner = Instance.new("UICorner")
LogCorner.CornerRadius = UDim.new(0, 8)
LogCorner.Parent = LogFrame

local LogPadding = Instance.new("UIPadding")
LogPadding.PaddingLeft = UDim.new(0, 10)
LogPadding.PaddingRight = UDim.new(0, 10)
LogPadding.PaddingTop = UDim.new(0, 10)
LogPadding.PaddingBottom = UDim.new(0, 10)
LogPadding.Parent = LogFrame

local LogLayout = Instance.new("UIListLayout")
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
LogLayout.Padding = UDim.new(0, 4)
LogLayout.Parent = LogFrame

local LogLines = {}
for i = 1, 6 do
    local line = Instance.new("TextLabel")
    line.Size = UDim2.new(1, 0, 0, 18)
    line.BackgroundTransparency = 1
    line.Font = Enum.Font.GothamMedium
    line.TextColor3 = Color3.fromRGB(200, 200, 200)
    line.TextSize = 13
    line.TextXAlignment = Enum.TextXAlignment.Left
    line.Text = ""
    line.LayoutOrder = i
    line.Parent = LogFrame
    LogLines[i] = line
end

local MAX_LOG_LINES = 6
local statusHistory = {}
local lastUpdateId = nil

-- CƠ CHẾ UPDATE LOG TUYỆT ĐỐI CHÍNH XÁC (6 DÒNG)
local function UpdateStatus(msg, updateId)
    if updateId and updateId == lastUpdateId and #statusHistory > 0 then
        if statusHistory[#statusHistory] ~= msg then
            statusHistory[#statusHistory] = msg
        end
    else
        if #statusHistory > 0 and statusHistory[#statusHistory] == msg then return end
        table.insert(statusHistory, msg)
        lastUpdateId = updateId
    end
    
    while #statusHistory > MAX_LOG_LINES do 
        table.remove(statusHistory, 1) 
    end
    
    for i = 1, MAX_LOG_LINES do 
        LogLines[i].Text = ""
        LogLines[i].Visible = false 
    end
    
    for i, textMsg in ipairs(statusHistory) do
        LogLines[i].Text = textMsg
        LogLines[i].Visible = true
    end
end

local uiVisible = true
ToggleBtn.MouseButton1Click:Connect(function()
    uiVisible = not uiVisible
    FullscreenBG.Visible = uiVisible
end)

local startTime = os.time()
local frames = 0
RunService.RenderStepped:Connect(function()
    frames = frames + 1
end)
task.spawn(function()
    while task.wait(1) do
        local diff = os.time() - startTime
        local h = math.floor(diff / 3600)
        local m = math.floor((diff % 3600) / 60)
        local s = diff % 60
        UptimeLabel.Text = string.format("Uptime: %02d:%02d:%02d", h, m, s)
        FPSLabel.Text = "FPS: " .. tostring(frames)
        frames = 0
    end
end)

local QuestNames = {
    ["BEST_EGG"] = "Hatch Best Eggs",
    ["EGG"] = "Hatch Eggs",
    ["BREAKABLE"] = "Break Breakables",
    ["CURRENT_BREAKABLE"] = "Break in Current Area",
    ["BEST_COIN_JAR"] = "Break Coin Jars",
    ["COMET"] = "Break Comets",
    ["COIN_JAR"] = "Break Coin Jars",
    ["BEST_COMET"] = "Break Comets",
    ["BEST_MINI_CHEST"] = "Break Mini Chests",
    ["BEST_SUPERIOR_MINI_CHEST"] = "Break Superior Chests",
    ["BEST_LUCKYBLOCK"] = "Break Lucky Blocks",
    ["BEST_PINATA"] = "Break Piñatas",
    ["LUCKYBLOCK"] = "Break Lucky Blocks",
    ["PINATA"] = "Break Piñatas",
    ["BEST_GOLD_PET"] = "Craft Gold Pets",
    ["BEST_RAINBOW_PET"] = "Craft Rainbow Pets",
    ["USE_POTION"] = "Use Potions",
    ["COLLECT_POTION"] = "Upgrade Potions",
    ["COLLECT_ENCHANT"] = "Upgrade Enchants",
    ["USE_FLAG"] = "Place Flags",
    ["DIAMOND_BREAKABLE"] = "Break Diamond Objects",
    ["HATCH_RARE_PET"] = "Hatch Rare Pets",
    ["CURRENCY"] = "Collect Currency"
}

local function onBreakablesDestroyed(data)
    local tbl = vm:Get("AllBreakables")
    if type(data) == "string" then 
        tbl[data] = nil
    elseif type(data) == "table" then 
        for _, v in pairs(data) do 
            tbl[tostring(v[1])] = nil 
        end 
    end
end

local function onBreakablesCreated(data)
    local tbl = vm:Get("AllBreakables")
    for _, v in pairs(data) do 
        if v[1] and v[1].u then 
            tbl[tostring(v[1].u)] = v[1] 
        end 
    end
end

Network.Fired("Breakables_Created"):Connect(onBreakablesCreated)
Network.Fired("Breakables_Ping"):Connect(onBreakablesCreated)
Network.Fired("Breakables_Destroyed"):Connect(onBreakablesDestroyed)
Network.Fired("Breakables_DestroyDueToReplicationFail"):Connect(onBreakablesDestroyed)
Network.Fired("Breakables_Cleanup"):Connect(function(data) 
    local tbl = vm:Get("AllBreakables")
    for _, v in pairs(data) do tbl[tostring(v[1])] = nil end 
end)

local function updateEuids()
    if type(PetNetworking.EquippedPets()) ~= "table" then return end
    local euids = vm:Get("Euids")
    local petids = vm:Get("PetIDs")
    for k in pairs(euids) do euids[k] = nil end
    for k in pairs(petids) do petids[k] = nil end
    for petID, petData in pairs(PetNetworking.EquippedPets()) do
        euids[petID] = petData
        table.insert(petids, petID)
    end
end

updateEuids()
Network.Fired("Pets_LocalPetsUpdated"):Connect(updateEuids)
Network.Fired("Pets_LocalPetsUnequipped"):Connect(updateEuids)

local THINGS = Workspace:WaitForChild("__THINGS")
local LootbagsFolder = THINGS:FindFirstChild("Lootbags")
if LootbagsFolder then 
    LootbagsFolder.ChildAdded:Connect(function(bag) 
        pcall(function() bag.Transparency = 1 end)
        task.wait() 
        if bag then Network.Fire("Lootbags_Claim", { bag.Name }); bag:Destroy() end 
    end) 
end
local OrbsFolder = THINGS:FindFirstChild("Orbs")
if OrbsFolder then 
    OrbsFolder.ChildAdded:Connect(function(orb) 
        pcall(function() orb.Transparency = 1 end)
        task.wait() 
        if orb then Network.Fire("Orbs: Collect", { tonumber(orb.Name) }); orb:Destroy() end 
    end) 
end

local function GetZonePath(zoneNumber, zoneId)
    local searchPattern = "^" .. tostring(zoneNumber) .. " |"
    for _, folderName in ipairs({"Map", "Map2", "Map3", "Map4", "Map5", "Map6"}) do
        local mapFolder = Workspace:FindFirstChild(folderName)
        if mapFolder then for _, zoneFolder in pairs(mapFolder:GetChildren()) do if string.find(zoneFolder.Name, searchPattern) then return zoneFolder end end end
    end
    return nil
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
            vm:Set("IsReadyToFarm", false) 
            vm:Set("OutZoneTime", 0)
            UpdateStatus("Chờ thực hiện Rebirth...", "WAIT_REBIRTH")
            Network.Invoke("Rebirth_Request", tostring(nextRebirthData.RebirthNumber))
            task.wait(10)
            continue
        end
        if nextZoneData and nextZoneData.WorldNumber and nextZoneData.WorldNumber ~= currentWorldNum then
            vm:Set("IsReadyToFarm", false)
            vm:Set("OutZoneTime", 0)
            UpdateStatus("Đang chuyển sang World " .. nextZoneData.WorldNumber .. "...", "WORLD_SWITCH")
            pcall(function() Network.Invoke("World" .. nextZoneData.WorldNumber .. "Teleport") end)
            task.wait(8) 
            continue
        end
        if nextZoneData and nextZoneData.WorldNumber == currentWorldNum then
            local coins = getcurrency()
            local gatePrice = 0
            pcall(function() gatePrice = CalcGatePrice(nextZoneData) end)
            if gatePrice and coins and gatePrice <= coins and not vm:Get("IsPetQuestActive") then
                vm:Set("IsReadyToFarm", false)
                local success = Network.Invoke("Zones_RequestPurchase", nextZoneId)
                if success then 
                    task.wait(0.5); continue 
                end
            end
        end
        local zoneFolder = GetZonePath(maxZoneData.ZoneNumber, maxZoneId)
        if zoneFolder and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetPart = nil
            if zoneFolder:FindFirstChild("INTERACT") and zoneFolder.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then targetPart = zoneFolder.INTERACT.BREAKABLE_SPAWNS:FindFirstChild("Main") or zoneFolder.INTERACT.BREAKABLE_SPAWNS:GetChildren()[1] end
            if not targetPart and zoneFolder:FindFirstChild("PERSISTENT") and zoneFolder.PERSISTENT:FindFirstChild("Teleport") then targetPart = zoneFolder.PERSISTENT.Teleport end
            if targetPart then
                local hrp = LocalPlayer.Character.HumanoidRootPart
                local dist = (hrp.Position - targetPart.Position).Magnitude
                local previousZone = vm:Get("TargetZoneId")
                if previousZone ~= maxZoneId then
                    vm:Set("IsReadyToFarm", false)
                    hrp.CFrame = targetPart.CFrame + Vector3.new(0, 2, 0)
                    task.wait(0.5)
                    vm:Set("TargetZoneId", maxZoneId); vm:Set("OutZoneTime", 0)
                else
                    if dist > 45 then
                        if vm:Get("IsPetQuestActive") then
                            vm:Set("OutZoneTime", 0)
                            vm:Set("IsReadyToFarm", false)
                        else
                            local outTime = vm:Get("OutZoneTime")
                            if outTime == 0 then vm:Set("OutZoneTime", os.clock())
                            elseif os.clock() - outTime >= 5 then
                                vm:Set("IsReadyToFarm", false)
                                hrp.CFrame = targetPart.CFrame + Vector3.new(0, 2, 0)
                                task.wait(0.5)
                                vm:Set("OutZoneTime", 0)
                            end
                        end
                    else
                        vm:Set("OutZoneTime", 0); vm:Set("IsReadyToFarm", true); vm:Set("current_zone", maxZoneId)
                    end
                end
            else vm:Set("IsReadyToFarm", false) end
        else vm:Set("IsReadyToFarm", false) end
    end
end)

task.spawn(function()
    while task.wait(0.15) do 
        if not vm:Get("IsReadyToFarm") then continue end
        local zone = vm:Get("current_zone")
        if not zone then continue end
        local availableBreakables = {}
        for key, info in pairs(vm:Get("AllBreakables")) do if info.pid == zone then table.insert(availableBreakables, key) end end
        local petIDs = vm:Get("PetIDs")
        if #availableBreakables > 0 and #petIDs > 0 then
            local bulkAssignments = {}
            local petsPerBreakable = math.floor(#petIDs / #availableBreakables)
            local extraPets = #petIDs % #availableBreakables
            local currentPetIndex = 1
            for i, breakKey in ipairs(availableBreakables) do
                local countForThisBreakable = petsPerBreakable + (i <= extraPets and 1 or 0)
                for j = 1, countForThisBreakable do
                    if currentPetIndex <= #petIDs then
                        local petID = petIDs[currentPetIndex]
                        if vm:Get("Euids")[petID] then bulkAssignments[petID] = breakKey end
                        currentPetIndex = currentPetIndex + 1
                    end
                end
            end
            if next(bulkAssignments) then pcall(function() Network.Fire("Breakables_JoinPetBulk", bulkAssignments) end) end
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if not vm:Get("IsReadyToFarm") then continue end
        local zone = vm:Get("current_zone")
        if not zone then continue end
        local count = 0
        pcall(function()
            for key, info in pairs(vm:Get("AllBreakables")) do
                if info.pid == zone then
                    Network.UnreliableFire("Breakables_PlayerDealDamage", key)
                    count = count + 1
                    if count >= 15 then break end 
                end
            end
        end)
    end
end)

task.spawn(function() while task.wait(15) do pcall(function() Network.Invoke('Mailbox: Claim All') end) end end)

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local data = Save.Get()
            if not data then return end
            local maxSlots = DaycareCmds.GetMaxSlots()
            local usedSlots = DaycareCmds.GetUsedSlots()
            local freeSlots = maxSlots - usedSlots
            local daycareActive = data.DaycareActive or {}
            for uid, petData in pairs(daycareActive) do
                if DaycareCmds.ComputeRemainingTime(petData, workspace:GetServerTimeNow()) <= 0 then
                    Network.Invoke("Daycare: Claim", uid)
                    task.wait(0.5)
                end
            end
            if freeSlots > 0 then
                local invPets = data.Inventory.Pet or {}
                local equippedPets = {}
                pcall(function() equippedPets = PetNetworking.EquippedPets() or {} end)
                local validPetsList = {}
                for uid, pet in pairs(invPets) do
                    if equippedPets[uid] then continue end
                    if not pet.id:match("Huge") and not pet.id:match("Titanic") and not pet.l then
                        local score = 0
                        pcall(function()
                            local petObj = PetItem(pet.id)
                            local _, lootMultiplier = DaycareLoot.ComputePetLootPool(LocalPlayer, petObj)
                            local rarityBonus = (pet.pt == 2 and 50) or (pet.pt == 1 and 20) or 0
                            local shinyBonus = pet.sh and 30 or 0
                            score = (lootMultiplier or 0) + rarityBonus + shinyBonus
                        end)
                        table.insert(validPetsList, { uid = uid, amount = pet._am or 1, score = score, name = pet.id })
                    end
                end
                table.sort(validPetsList, function(a, b) return a.score > b.score end)
                local petsToEnroll = {}
                local slotsFilled = 0
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
    while task.wait(5) do
        pcall(function()
            local save = Save.Get()
            if not save then return end
            local redeemed = save.FreeGiftsRedeemed or {}
            local currentTime = save.FreeGiftsTime or 0
            for _, gift in pairs(FreeGiftsDirectory) do
                if gift.WaitTime <= currentTime and not table.find(redeemed, gift._id) then
                    Network.Invoke('Redeem Free Gift', gift._id)
                    break 
                end
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(3) do
        pcall(function()
            local currentEquips = Save.Get()["PetSlotsPurchased"] or 0
            local MaxPetSlots = RankCmds.GetMaxPurchasableEquipSlots()
            if currentEquips < MaxPetSlots then
                Network.Invoke("EquipSlotsMachine_RequestPurchase", currentEquips + 1)
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            local equipped = UltimateCmds.GetEquippedItem()
            if equipped and equipped._data and equipped._data.id then
                UltimateCmds.Activate(equipped._data.id)
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local currentRank = Save.Get().Rank or 1
            if currentRank > lastRank then
                local currentTitle = RankCmds.GetTitle() or "Unknown"
                SendRankUpWebhook(currentRank, currentTitle)
                lastRank = currentRank
            end
        end)
    end
end)

local config = getgenv().AutoRankConfig or {}
local DefaultQuestPriority = {
	ZONE_GATE = 0, EGG = 1, BEST_EGG = 1, USE_POTION = 1, USE_FLAG = 1,
	BEST_RAINBOW_PET = 2, BEST_GOLD_PET = 2, COLLECT_POTION = 2, COLLECT_ENCHANT = 2,
	COMET = 3, BEST_COMET = 3, COIN_JAR = 4, BEST_COIN_JAR = 4,
	PINATA = 5, BEST_PINATA = 5, LUCKYBLOCK = 6, BEST_LUCKYBLOCK = 6,
	CURRENT_BREAKABLE = 7, BEST_SUPERIOR_MINI_CHEST = 7, DIAMOND_BREAKABLE = 7,
    BEST_MINI_CHEST = 7, HATCH_RARE_PET = 7, CURRENCY = 7,	
}
local QuestPriority = {}
local UserPriority = config.QuestPriority or {}
for questName, defaultPrio in pairs(DefaultQuestPriority) do
    if UserPriority[questName] ~= nil then
        QuestPriority[questName] = UserPriority[questName]
    else
        QuestPriority[questName] = defaultPrio
    end
end

local function GetQuestNameByID(id)
    for name, val in pairs(QuestsGoals) do if val == id then return name end end
    return "UNKNOWN_"..tostring(id)
end

local function CheckItemExact(itemName)
    local inv = Save.Get().Inventory.Misc
    if not inv then return false, nil end
    for uid, item in pairs(inv) do
        if type(item.id) == "string" and item.id == itemName then return true, uid end
    end
    return false, nil
end

local function CheckPotion(tier, needed)
    local inv = Save.Get().Inventory.Potion
    if not inv then return false, nil, 0 end
    for uid, item in pairs(inv) do
        if tier <= (item.tn or 1) and needed <= (item._am or 1) then
            return true, uid, (item._am or 1)
        end
    end
    return false, nil, 0
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

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local currentSave = Save.Get()
            local totalStars = 0
            local currentTitle = RankCmds.GetTitle()
            if RanksDirectory[currentTitle] and RanksDirectory[currentTitle].Rewards then
                for i, v in pairs(RanksDirectory[currentTitle].Rewards) do
                    totalStars = totalStars + v.StarsRequired
                    if currentSave.RankStars >= totalStars and not currentSave.RedeemedRankRewards[tostring(i)] then
                        Network.Fire("Ranks_ClaimReward", i)
                        task.wait(0.5)
                    end
                end
            end
        end)
    end
end)

local startTime = os.clock()
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local save = Save.Get()
            if save then
                RankLabel.Text = "Rank: " .. tostring(save.Rank or 1)
                StarsLabel.Text = "Stars: " .. FormatValue(save.RankStars or 0)
            end
        end)
    end
end)

task.spawn(function()
    while task.wait(1) do
        if not vm:Get("IsReadyToFarm") and not vm:Get("IsPetQuestActive") then continue end
        local data = Save.Get()
        if not data then continue end
        local activeQuests = {}
        if data.ZoneGateQuest then
            local q = data.ZoneGateQuest
            local qName = GetQuestNameByID(q.Type)
            table.insert(activeQuests, { goalId = "ZoneGate", name = qName, priority = QuestPriority.ZONE_GATE, progress = q.Progress or 0, target = q.Amount or 1, tier = q.PotionTier or q.Tier or 1 })
        end
        for goalId, goalData in pairs(data.Goals or {}) do
            local qName = GetQuestNameByID(goalData.Type)
            local priority = QuestPriority[qName] or 99
            table.insert(activeQuests, { goalId = goalId, name = qName, priority = priority, progress = goalData.Progress or 0, target = goalData.Amount or 1, tier = goalData.PotionTier or goalData.Tier or 1 })
        end
        
        local isPetQuestActive = false
        for _, q in ipairs(activeQuests) do
            local isCooldown = _G.StuckCooldown[q.name] and (os.time() - _G.StuckCooldown[q.name] < 300)
            if not isCooldown and (q.target - q.progress > 0) then
                if q.name == "BEST_GOLD_PET" or q.name == "BEST_RAINBOW_PET" or q.name == "USE_FLAG" 
                or q.name == "BEST_COMET" or q.name == "BEST_PINATA" or q.name == "BEST_COIN_JAR" or q.name == "BEST_LUCKYBLOCK"
                or q.name == "COMET" or q.name == "PINATA" or q.name == "COIN_JAR" or q.name == "LUCKYBLOCK" then
                    isPetQuestActive = true
                    break
                end
            end
        end
        vm:Set("IsPetQuestActive", isPetQuestActive)
        
        table.sort(activeQuests, function(a, b) return a.priority < b.priority end)
        
        local actionTakenThisLoop = false 
        local currentActiveQuestName = nil 
        local waitingQuestLogText = nil
        local waitingQuestLogId = nil
        
        for index, quest in ipairs(activeQuests) do
            local needed = quest.target - quest.progress
            local isCooldown = _G.StuckCooldown[quest.name] and (os.time() - _G.StuckCooldown[quest.name] < 300)
            
            if needed > 0 and not isCooldown then
                -- 1. Vật phẩm: Comet, Coin Jar, Pinata, Lucky Block
                if quest.name == "BEST_COMET" or quest.name == "BEST_PINATA" or quest.name == "BEST_COIN_JAR" or quest.name == "BEST_LUCKYBLOCK"
                or quest.name == "COMET" or quest.name == "PINATA" or quest.name == "COIN_JAR" or quest.name == "LUCKYBLOCK" then
                    local itemName, remoteName
                    if quest.name == "BEST_COMET" then itemName = "Comet"; remoteName = "Comet_Spawn"
                    elseif quest.name == "BEST_PINATA" then itemName = "Mini Pinata"; remoteName = "MiniPinata_Consume"
                    elseif quest.name == "BEST_COIN_JAR" then itemName = "Basic Coin Jar"; remoteName = "CoinJar_Spawn"
                    elseif quest.name == "BEST_LUCKYBLOCK" then itemName = "Mini Lucky Block"; remoteName = "MiniLuckyBlock_Consume"
                    elseif quest.name == "COMET" then itemName = "Comet"; remoteName = "Comet_Spawn"
                    elseif quest.name == "PINATA" then itemName = "Mini Pinata"; remoteName = "MiniPinata_Consume"
                    elseif quest.name == "COIN_JAR" then itemName = "Basic Coin Jar"; remoteName = "CoinJar_Spawn"
                    elseif quest.name == "LUCKYBLOCK" then itemName = "Mini Lucky Block"; remoteName = "MiniLuckyBlock_Consume" end

                    if not actionTakenThisLoop then 
                        local lastTime = vm:Get("ActionTime_" .. quest.goalId) or 0
                        if os.clock() - lastTime > 15 then 
                            local hasItem, uid = CheckItemExact(itemName)
                            if hasItem then
                                if vm:Get("IsReadyToFarm") then
                                    UpdateStatus(string.format("Đang tiến hành thả %s (%s/%s)...", itemName, FormatValue(quest.progress), FormatValue(quest.target)), "LOG_ITEM_" .. quest.goalId)
                                    vm:Set("ActionTime_" .. quest.goalId, os.clock())
                                    task.spawn(function() pcall(function() Network.Invoke(remoteName, uid) end) end)
                                else
                                    UpdateStatus(string.format("Đang chờ vào map để thả %s...", itemName), "LOG_ITEM_" .. quest.goalId)
                                end
                                actionTakenThisLoop = true
                                currentActiveQuestName = quest.name
                            else
                                _G.StuckCooldown[quest.name] = os.time()
                                SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name)
                                UpdateStatus("Thiếu vật phẩm " .. itemName .. "! Bỏ qua 5 phút.", "COOLDOWN_" .. quest.name)
                            end
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Đang tập trung đập %s (%s/%s)...", itemName, FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_ITEM_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end
                
                -- 2. Dùng Thuốc (Potion)
                if quest.name == "USE_POTION" then
                    if not actionTakenThisLoop then
                        if not vm:Get("IsDrinking_" .. quest.goalId) then
                            local hasPot, uid, availableAmt = CheckPotion(quest.tier, needed)
                            if hasPot then
                                local drinkAmt = math.min(needed, availableAmt)
                                UpdateStatus(string.format("Đang sử dụng %d bình Potion (Tier %d)...", drinkAmt, quest.tier), "LOG_POTION_" .. quest.goalId)
                                vm:Set("IsDrinking_" .. quest.goalId, true)
                                task.spawn(function()
                                    pcall(function() Network.Fire("Potions: Consume", uid, drinkAmt) end)
                                    task.wait(1.5)
                                    vm:Set("IsDrinking_" .. quest.goalId, false)
                                end)
                                actionTakenThisLoop = true
                                currentActiveQuestName = quest.name
                            else
                                _G.StuckCooldown[quest.name] = os.time()
                                SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name)
                                UpdateStatus(string.format("Hết Potion (Tier %d)! Bỏ qua 5 phút.", quest.tier), "COOLDOWN_POTION")
                            end
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Đang uống Potion (%s/%s)...", FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_POTION_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end
                
                -- 3. Cắm Cờ (Flag)
                if quest.name == "USE_FLAG" then
                    if not actionTakenThisLoop then
                        local lastTime = vm:Get("ActionTime_" .. quest.goalId) or 0
                        if os.clock() - lastTime > 4 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            local inv = Save.Get().Inventory.Misc or {}
                            local bestFlagId = nil
                            local bestFlagUid = nil
                            local maxAmt = 0
                            for uid, item in pairs(inv) do
                                if item.id and type(item.id) == "string" and item.id:find("Flag") and rawget(ZoneFlagsDir, item.id) then
                                    local amt = item._am or 1
                                    if amt > maxAmt then
                                        maxAmt = amt
                                        bestFlagId = item.id
                                        bestFlagUid = uid
                                    end
                                end
                            end
                            
                            if maxAmt > 0 then
                                actionTakenThisLoop = true
                                currentActiveQuestName = quest.name
                                task.spawn(function()
                                    local craftAmt = math.min(maxAmt, needed, 24)
                                    local zoneOffset = vm:Get("FlagZoneOffset") or 0
                                    local zoneFolder, targetZoneNum = GetZoneFolderByOffset(zoneOffset)
                                    if zoneFolder then
                                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                        if hrp then
                                            UpdateStatus(string.format("Đang cắm %d %s tại Zone %d...", craftAmt, bestFlagId, targetZoneNum), "LOG_FLAG_" .. quest.goalId)
                                            if not zoneFolder:FindFirstChild("INTERACT") or (hrp.Position - zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.Position).Magnitude > 50 then
                                                if zoneFolder:FindFirstChild("PERSISTENT") then
                                                    hrp.CFrame = zoneFolder.PERSISTENT.Teleport.CFrame
                                                    task.wait(0.6)
                                                end
                                            end
                                            if zoneFolder:FindFirstChild("INTERACT") and zoneFolder.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then
                                                hrp.CFrame = zoneFolder.INTERACT.BREAKABLE_SPAWNS.Main.CFrame + Vector3.new(0, 2, 0)
                                            end
                                            task.wait(0.5)
                                            pcall(function() FlexibleFlagCmds.Consume(bestFlagId, bestFlagUid, craftAmt) end)
                                            task.wait(2.8)
                                            local newInv = Save.Get().Inventory.Misc or {}
                                            local newAmt = newInv[bestFlagUid] and (newInv[bestFlagUid]._am or 1) or 0
                                            local consumed = maxAmt - newAmt
                                            if consumed > 0 then
                                                vm:Set("FlagZoneOffset", 0) 
                                            else
                                                local nextOffset = zoneOffset + 1
                                                if nextOffset > 20 then nextOffset = 0 end
                                                vm:Set("FlagZoneOffset", nextOffset)
                                                UpdateStatus("Zone đầy cờ, chuyển sang Zone " .. tostring(targetZoneNum - 1), "LOG_FLAG_" .. quest.goalId)
                                                task.wait(1)
                                            end
                                        end
                                    end
                                end)
                            else
                                _G.StuckCooldown[quest.name] = os.time()
                                SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name)
                                UpdateStatus("Hết cờ! Bỏ qua nhiệm vụ cắm cờ 5 phút.", "COOLDOWN_FLAG")
                            end
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Đang cắm cờ (%s/%s)...", FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_FLAG_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end
                
                -- 4. Ép Thuốc / Ép Sách
                if quest.name == "COLLECT_POTION" or quest.name == "COLLECT_ENCHANT" then
                    if not actionTakenThisLoop then
                        local lastTime = vm:Get("ActionTime_" .. quest.goalId) or 0
                        local isPotion = (quest.name == "COLLECT_POTION")
                        if os.clock() - lastTime > 4 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            local invType = isPotion and "Potion" or "Enchant"
                            local remoteName = isPotion and "UpgradePotionsMachine_Activate" or "UpgradeEnchantsMachine_Activate"
                            local inv = Save.Get().Inventory[invType] or {}
                            
                            local bestUid, bestCraftAmt, bestTier, bestName = nil, 0, 999, ""
                            local IgnoreEnchants = { "" }   

                            for uid, dat in pairs(inv) do
                                local tier = dat.tn or 1
                                local nameTier = (dat.id or "") .. " " .. tier
                                local maxTierAllowed = isPotion and 4 or 3

                                if tier >= 1 and tier <= maxTierAllowed and (isPotion or not table.find(IgnoreEnchants, nameTier)) then
                                    setthreadidentity(4)
                                    local reqPerUpgrade = isPotion and CalcPotion(tier) or CalcEnchant(tier)
                                    local amt = dat._am or 1
                                    local possibleCraft = math.floor(amt / reqPerUpgrade)

                                    if possibleCraft > 0 then
                                        if tier < bestTier then
                                            bestTier = tier
                                            bestCraftAmt = possibleCraft
                                            bestUid = uid
                                            bestName = dat.id or "Unknown"
                                        elseif tier == bestTier and possibleCraft > bestCraftAmt then
                                            bestCraftAmt = possibleCraft
                                            bestUid = uid
                                            bestName = dat.id or "Unknown"
                                        end
                                    end
                                end
                            end
                            
                            if bestCraftAmt > 0 and bestUid then
                                actionTakenThisLoop = true
                                currentActiveQuestName = quest.name
                                task.spawn(function()
                                    local craftAmt = math.min(bestCraftAmt, needed or 1)
                                    UpdateStatus(string.format("Đang nâng cấp %s (Tier %d -> %d) x%d...", bestName, bestTier, bestTier + 1, craftAmt), "LOG_UPGRADE_" .. quest.goalId)

                                    setthreadidentity(4)
                                    local success = pcall(function()
                                        Network.Invoke(remoteName, bestUid, craftAmt)
                                    end)
                                    task.wait(3.5)  
                                    if success then
                                        UpdateStatus("✅ Nâng cấp " .. bestName .. " thành công!", "LOG_UPGRADE_" .. quest.goalId)
                                    end
                                end)
                            else
                                _G.StuckCooldown[quest.name] = os.time()
                                SendMaterialShortageWebhook(QuestNames[quest.name] or quest.name)
                                UpdateStatus("Hết nguyên liệu ép " .. (isPotion and "Thuốc" or "Sách") .. "! Bỏ qua 5 phút.", "COOLDOWN_UPGRADE")
                            end
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Đang chờ hệ thống xử lý ép %s (%s/%s)...", isPotion and "Thuốc" or "Sách", FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_UPGRADE_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end

                -- 5. Ấp Trứng
                if quest.name == "BEST_EGG" or quest.name == "HATCH_RARE_PET" or quest.name == "EGG" then
                    if not actionTakenThisLoop then
                        local lastTime = vm:Get("ActionTime_" .. quest.goalId) or 0
                        if os.clock() - lastTime > 2.5 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            UpdateStatus(string.format("Đang Auto-Hatch trứng (%s/%s)...", FormatValue(quest.progress), FormatValue(quest.target)), "LOG_EGG_" .. quest.goalId)
                            actionTakenThisLoop = true 
                            currentActiveQuestName = quest.name
                            task.spawn(function()
                                ToggleEggAnimation()
                                HatchBestEgg()
                            end)
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Đang ấp trứng (%s/%s)...", FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_EGG_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end
                
                -- 6. Gold Pet / Rainbow Pet
                if quest.name == "BEST_GOLD_PET" or quest.name == "BEST_RAINBOW_PET" then
                    if not actionTakenThisLoop then
                        local lastTime = vm:Get("ActionTime_" .. quest.goalId) or 0
                        if os.clock() - lastTime > 3 then 
                            vm:Set("ActionTime_" .. quest.goalId, os.clock())
                            actionTakenThisLoop = true 
                            currentActiveQuestName = quest.name
                            task.spawn(function()
                                ToggleEggAnimation()
                                local isRainbow = (quest.name == "BEST_RAINBOW_PET")
                                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                if not hrp then return end
                                local bestGolds = GetBestGoldenPetsUID()
                                local bestNormals = GetBestNormalPetsUID()
                                local maxGoldUid, maxGoldAmt = nil, 0
                                for uid, data in pairs(bestGolds) do
                                    if data.Amount > maxGoldAmt then maxGoldUid = uid; maxGoldAmt = data.Amount end
                                end
                                local maxNormalUid, maxNormalAmt = nil, 0
                                for uid, data in pairs(bestNormals) do
                                    if data.Amount > maxNormalAmt then maxNormalUid = uid; maxNormalAmt = data.Amount end
                                end
                                
                                local reqEquiv = isRainbow and (needed * 100) or (needed * 10)
                                local logKey = "LogCalc_" .. quest.goalId
                                if not vm:Get(logKey) then
                                    if isRainbow then UpdateStatus(string.format("Tính toán: Cần %d Rainbow = %d Gold = %d Normal", needed, needed * 10, reqEquiv), "LOG_PET_CALC_" .. quest.goalId)
                                    else UpdateStatus(string.format("Tính toán: Cần %d Gold = %d Normal", needed, reqEquiv), "LOG_PET_CALC_" .. quest.goalId) end
                                    vm:Set(logKey, true)
                                end
                                
                                local deficitNormals = 0; local requiredEquivNormals = 0
                                if isRainbow then
                                    local totalEquivNormals = maxNormalAmt + (maxGoldAmt * 10)
                                    requiredEquivNormals = needed * 100
                                    deficitNormals = requiredEquivNormals - totalEquivNormals
                                    if maxNormalAmt >= 2000 and totalEquivNormals < requiredEquivNormals then
                                        UpdateStatus("Túi đồ đầy, đang ép Gold để dọn dẹp...", "LOG_PET_WAIT_" .. quest.goalId)
                                        Network.Invoke('GoldMachine_Activate', maxNormalUid, math.floor(maxNormalAmt / 10))
                                        return
                                    end
                                    if totalEquivNormals >= requiredEquivNormals then
                                        if maxNormalAmt >= 10 then
                                            UpdateStatus(string.format("Đã đủ phôi (%d/%d). Đang dồn Normal thành Gold...", totalEquivNormals, requiredEquivNormals), "LOG_PET_WAIT_" .. quest.goalId)
                                            Network.Invoke('GoldMachine_Activate', maxNormalUid, math.floor(maxNormalAmt / 10))
                                            return
                                        elseif maxGoldAmt >= 10 then
                                            local craftAmt = math.min(math.floor(maxGoldAmt / 10), needed)
                                            UpdateStatus(string.format("Đã đủ Gold! Bắt đầu ghép %d Rainbow...", craftAmt), "LOG_PET_WAIT_" .. quest.goalId)
                                            Network.Invoke('RainbowMachine_Activate', maxGoldUid, craftAmt)
                                            return
                                        end
                                    end
                                else
                                    requiredEquivNormals = needed * 10
                                    deficitNormals = requiredEquivNormals - maxNormalAmt
                                    if maxNormalAmt >= 2000 and maxNormalAmt < requiredEquivNormals then
                                        UpdateStatus("Túi đồ đầy, đang ép Gold để dọn dẹp...", "LOG_PET_WAIT_" .. quest.goalId)
                                        Network.Invoke('GoldMachine_Activate', maxNormalUid, math.floor(maxNormalAmt / 10))
                                        return
                                    end
                                    if maxNormalAmt >= requiredEquivNormals then
                                        UpdateStatus(string.format("Bắt đầu ép %d Gold hoàn thành nhiệm vụ!", needed), "LOG_PET_WAIT_" .. quest.goalId)
                                        Network.Invoke('GoldMachine_Activate', maxNormalUid, needed)
                                        return
                                    end
                                end
                                
                                if deficitNormals > 0 then
                                    local maxHatch = EggCmds.GetMaxHatch()
                                    local bestEggModule = GetBestEggModule()
                                    if not bestEggModule then return end
                                    local singleHatchCost = CalcEggPricePlayer(bestEggModule) * maxHatch
                                    local currentMoney = getcurrency()
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
                                    if currentMoney >= singleHatchCost then
                                        local currentEquiv = isRainbow and (maxNormalAmt + (maxGoldAmt * 10)) or maxNormalAmt
                                        UpdateStatus(string.format("Thiếu phôi (Mới có %d/%d). Đang Auto-Hatch trứng...", currentEquiv, requiredEquivNormals), "LOG_PET_WAIT_" .. quest.goalId)
                                        HatchBestEgg()
                                    else
                                        UpdateStatus(string.format("Hết xu ấp trứng! Đang cố farm thêm... (%s/%s)", FormatValue(currentMoney), FormatValue(singleHatchCost)), "LOG_PET_WAIT_" .. quest.goalId)
                                    end
                                end
                            end)
                        else
                            if not waitingQuestLogText then
                                waitingQuestLogText = string.format("Đang xử lý nhiệm vụ %s (%s/%s)...", isRainbow and "Rainbow" or "Gold", FormatValue(quest.progress), FormatValue(quest.target))
                                waitingQuestLogId = "LOG_PET_WAIT_" .. quest.goalId
                                if not currentActiveQuestName then currentActiveQuestName = quest.name end
                            end
                        end
                    end
                end
            end
            
            -- UI Render: Mũi tên & Phần trăm
            if index <= 6 then
                local percent = math.floor((quest.progress / quest.target) * 100)
                if percent > 100 then percent = 100 end
                
                local prefix = (quest.goalId == "ZoneGate") and "[🔥 GATE]" or string.format("[P%d]", quest.priority)
                
                if currentActiveQuestName == quest.name then
                    prefix = "➔ " .. prefix
                elseif isCooldown then
                    prefix = "[⏳ 5M] " .. prefix
                end
                
                local displayName = QuestNames[quest.name] or quest.name
                local textStr = string.format("%s %s: %s / %s (%d%%)", prefix, displayName, FormatValue(quest.progress), FormatValue(quest.target), percent)
                
                if quest.progress >= quest.target then
                    QuestLabels[index].TextColor3 = Color3.fromRGB(50, 255, 50)
                    textStr = "✅ " .. displayName .. " - DONE!"
                else
                    if isCooldown then
                        QuestLabels[index].TextColor3 = Color3.fromRGB(255, 100, 100) 
                    else
                        QuestLabels[index].TextColor3 = (quest.goalId == "ZoneGate") and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(200, 200, 255)
                    end
                end
                
                QuestLabels[index].Text = textStr
                QuestLabels[index].Visible = true
            end
        end
        
        for i = #activeQuests + 1, 6 do 
            QuestLabels[i].Text = ""
            QuestLabels[i].Visible = false 
        end
        
        -- Logic Bù đắp (Fallback) khi các nhiệm vụ đều nằm trong thời gian chờ
        if not actionTakenThisLoop then
            if waitingQuestLogText then
                -- Nếu có nhiệm vụ đang trong 15s chờ -> Đẩy Log tiến độ ra
                UpdateStatus(waitingQuestLogText, waitingQuestLogId)
            elseif vm:Get("IsReadyToFarm") then
                -- Nếu không rảnh và không chờ -> Báo Farm tự do
                local maxZoneId, maxZoneData = ZoneCmds.GetMaxOwnedZone()
                UpdateStatus("Đang farm tự do tại " .. (maxZoneData.Name or maxZoneId), "FARMING_ZONE")
            end
        end
    end
end)

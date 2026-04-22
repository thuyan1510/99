-- ==========================================
-- 🌸 EASTER EVENT - V59 (PERFECT ANTI-AFK & UPGRADE FIX) 🌸
-- (Tích hợp Anti-AFK 3 Lớp & Sửa lỗi nhảy cấp mở khóa trứng)
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

local WebhookCfg = UserSettings.Webhook or {}
local WEBHOOK_URL = type(WebhookCfg) == "table" and WebhookCfg.url or ""
local rawDiscordId = type(WebhookCfg) == "table" and WebhookCfg["Discord Id to ping"] or ""
local DISCORD_USER_ID = type(rawDiscordId) == "table" and (rawDiscordId[1] or "") or tostring(rawDiscordId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")

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
-- 🛡️ ANTI AFK (NÂNG CẤP TỐI THƯỢNG V3 - PHÒNG THỦ 3 LỚP)
-- ==========================================
-- [Lớp 1]: Chặn gói tin báo cáo AFK gửi lên server của Pet Simulator 99
pcall(function()
    local v3 = require(ReplicatedStorage.Library.Client.Network)
    local _Fire = v3.Fire
    setreadonly(v3, false)
    v3.Fire = function(...)
        local args = {...}
        if args[1] == 'Idle Tracking: Update Timer' then
            return -- Hủy gói tin AFK của game
        end
        return _Fire(...)
    end
    setreadonly(v3, true)
end)

-- [Lớp 2]: Che mắt game khi bạn Alt-Tab hoặc thu nhỏ cửa sổ (Bypass Window Focus)
pcall(function()
    local UserInputService = game:GetService("UserInputService")
    if getconnections then
        for _, v in pairs(getconnections(UserInputService.WindowFocusReleased)) do
            if v.Disable then v:Disable() end
        end
        for _, v in pairs(getconnections(UserInputService.WindowFocused)) do
            if v.Disable then v:Disable() end
        end
    end
end)

-- [Lớp 3]: Vô hiệu hóa hệ thống kick 20 phút mặc định của Roblox Engine
pcall(function()
    if getconnections then
        for _, v in pairs(getconnections(Player.Idled)) do
            if v.Disable then v:Disable() end
        end
    end
end)

-- Backup Layer: Giả lập click chuột và nhảy định kỳ để chắc chắn 100%
pcall(function()
    local vu = game:GetService("VirtualUser")
    task.spawn(function()
        while task.wait(300) do
            pcall(function()
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
                local hum = Player.Character and Player.Character:FindFirstChild("Humanoid")
                if hum then hum.Jump = true end
            end)
        end
    end)
end)

-- ==========================================
-- 🚀 EXTREME OPTIMIZE (GIẢM LAG)
-- ==========================================
local function ExtremeOptimize(v)
    pcall(function()
        if v:IsA("BasePart") then v.Material = Enum.Material.Plastic; v.Reflectance = 0; v.CastShadow = false
        elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("Smoke") then
            if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 else v.Enabled = false end
        elseif v:IsA("Explosion") then v.Visible = false
        elseif v:IsA("PostEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("BlurEffect") then v.Enabled = false end
    end)
end
for _, v in ipairs(Workspace:GetDescendants()) do ExtremeOptimize(v) end
for _, v in ipairs(Lighting:GetDescendants()) do ExtremeOptimize(v) end
Workspace.DescendantAdded:Connect(ExtremeOptimize)
Lighting.DescendantAdded:Connect(ExtremeOptimize)

-- ==========================================
-- TỌA ĐỘ TUYỆT ĐỐI & TRUE FPS TRACKER
-- ==========================================
_G.DynamicHubCF = CFrame.new(-18581.56, 17.03, -29110.16)
_G.DynamicPortals = {}
local ZoneNames = { "Dewdrop Falls", "Tulip Hollow", "Blossom Vale", "Sunstone Heights" }
local PortalOffsets = { Vector3.new(187.92, 12.48, -73.25), Vector3.new(200.18, 10.73, -24.80), Vector3.new(198.20, 12.98, 44.73), Vector3.new(170.03, 12.48, 86.75) }
for i = 1, 4 do _G.DynamicPortals[i] = CFrame.new(_G.DynamicHubCF.Position + PortalOffsets[i]) end

local FarmOffset = Vector3.new(53.53, 0, 0.62)
local HatchOffset = Vector3.new(62.53, 0, -12.60) 

local TrueFPS = 60
RunService.RenderStepped:Connect(function(deltaTime) TrueFPS = math.floor(1 / deltaTime) end)

local StartTime = os.time()
local StartEggs = 0
pcall(function() StartEggs = Save.Get().Easter2026EggsHatched or 0 end)
local SessionHuges, SessionTitanics = 0, 0

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
-- 🎨 CUSTOM UI
-- ==========================================
local FarmUI = {}
FarmUI.__index = FarmUI
function FarmUI.new(UIConfig)
	local Self = setmetatable({}, FarmUI)
	Self.GuiName = "EasterEventGuiV59"
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
		Label.BackgroundTransparency = 1; Label.Font = Enum.Font.FredokaOne; Label.Text = Item.Text; Label.TextColor3 = Color3.fromRGB(255, 255, 255); Label.TextScaled = true
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
        ["Title"]           = {1, "🐰 EASTER EVENT V59", {0.8, 0, 0.08, 0}},
        ["ModeInfo"]        = {2, "Mode: " .. ModeDisplay},
        ["Time"]            = {3, "Time: 00:00:00 | Time Left: 00:00"},
        ["EggsHatched"]     = {4, "Total Eggs Hatched: 0"},
        ["Rares"]           = {5, "Huge: 0 | Titanic: 0"},
        ["Tokens"]          = {6, "Token B/R/S/T: 0/0/0/0"},
        ["EggTokens"]       = {7, "Spring Egg Token: 0"},
        ["Tickets"]         = {8, "Ticket: 0 / 0 (Chance: 0%)"},
        ["FPS"]             = {9, "FPS: 60"}
    }
})

-- ==========================================
-- 🚀 DATA UPDATER (TICKETS, TOKENS, EGGS)
-- ==========================================
task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            local save = Save.Get()
            local b, r, s, t, eggToken = 0, 0, 0, 0, 0
            if save and save.Inventory and save.Inventory.Misc then
                for _, item in pairs(save.Inventory.Misc) do
                    local id = item.id or ""
                    if id:find("Bluebell Token") then b = b + (item._am or 1)
                    elseif id:find("Rose Token") then r = r + (item._am or 1)
                    elseif id:find("Sunflower Token") then s = s + (item._am or 1)
                    elseif id:find("Tulip Token") then t = t + (item._am or 1)
                    elseif id:find("Spring Egg Token") then eggToken = eggToken + (item._am or 1) end
                end
            end
            
            if eggToken == 0 then
                pcall(function() local c = CurrencyCmds.Get("SpringEggTokens") or CurrencyCmds.Get("Spring Egg Token"); if c and type(c) == "number" and c > 0 then eggToken = c end end)
            end
            
            local realClientTickets, realTotalTickets, pos = 0, 1, HumanoidRootPart.Position
            pcall(function()
                local easterGui = Player.PlayerGui:FindFirstChild("EasterEggZoneMain")
                if easterGui and easterGui:FindFirstChild("SideInfo") and easterGui.SideInfo:FindFirstChild("Tickets") then
                    for _, lbl in pairs(easterGui.SideInfo.Tickets:GetChildren()) do
                        if lbl:IsA("TextLabel") and not lbl.Text:lower():find("earned") then realClientTickets = ParseValue(lbl.Text) end
                    end
                end
            end)
            
            pcall(function()
                local closestBoard, minDist = nil, math.huge
                local container = Workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER")
                if container and container:FindFirstChild("Active") then
                    for _, v in ipairs(container.Active:GetDescendants()) do
                        if v.Name == "RaffleBoard" and v:IsA("Model") then
                            local dist = (v:GetPivot().Position - pos).Magnitude
                            if dist < minDist then minDist = dist; closestBoard = v end
                        end
                    end
                end
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
            
            local currentEggs = save.Easter2026EggsHatched or StartEggs
            local hatchedThisSession = math.max(0, currentEggs - StartEggs)
            local chance = realTotalTickets > 0 and (realClientTickets / realTotalTickets) * 100 or 0
            
            UI:SetText("EggsHatched", "Total Eggs Hatched: " .. FormatValue(hatchedThisSession))
            UI:SetText("Rares", string.format("Huge: %d | Titanic: %d", SessionHuges, SessionTitanics))
            UI:SetText("Tokens", string.format("Token B/R/S/T: %s/%s/%s/%s", FormatValue(b), FormatValue(r), FormatValue(s), FormatValue(t)))
            UI:SetText("EggTokens", "Spring Egg Token: " .. FormatValue(eggToken))
            UI:SetText("Tickets", string.format("Ticket: %s / %s (Chance: %.6f%%)", FormatValue(realClientTickets), FormatValue(realTotalTickets), chance))
            UI:SetText("FPS", "FPS: " .. tostring(TrueFPS))
        end)
    end
end)

-- WEBHOOK TRACKER
local foundHuges, firstWebhookCheck = {}, true
task.spawn(function()
    while task.wait(10) do
        pcall(function()
            local save = Save.Get()
            if not save or not save.Inventory or not save.Inventory.Pet then return end
            local currentHuges = {}
            for uid, pet in pairs(save.Inventory.Pet) do
                if pet.id:match("Huge") or pet.id:match("Titanic") then
                    currentHuges[uid] = pet
                    if not firstWebhookCheck and not foundHuges[uid] then
                        if pet.id:match("Titanic") then SessionTitanics = SessionTitanics + 1 else SessionHuges = SessionHuges + 1 end
                        if WEBHOOK_URL ~= "" then
                            local httprequest = (request or http_request or syn and syn.request)
                            local data = {
                                ["content"] = "<@" .. DISCORD_USER_ID .. "> 🎉 HATCHED A RARE PET!",
                                ["embeds"] = {{ ["title"] = "Hatched: " .. pet.id, ["color"] = 16737996, ["fields"] = { {["name"] = "Account", ["value"] = "||" .. Player.Name .. "||"} }, ["footer"] = { ["text"] = "Eggs hatched: " .. tostring((save.Easter2026EggsHatched or StartEggs) - StartEggs) } }}
                            }
                            pcall(function() httprequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = game.HttpService:JSONEncode(data) }) end)
                        end
                    end
                end
            end
            foundHuges = currentHuges; firstWebhookCheck = false
        end)
    end
end)

-- ==========================================
-- 🚀 ĐỘNG CƠ SMART FARM V2 (TỐI ƯU HÓA THEO YÊU CẦU)
-- ==========================================
pcall(function() PlayerPet.CalculateSpeedMultiplier = function() return 200 end end)

local FARM_RADIUS = 50 -- Chỉ quét trong phạm vi 50
local MAX_PETS_PER_TARGET = 3 -- Tối đa 3 thú cưng vây đánh 1 cục

local function GetMyPets()
    local pets = {}
    pcall(function() 
        for _, pet in ipairs(PlayerPet.GetAll()) do 
            if pet.owner == Player then table.insert(pets, pet) end 
        end 
    end)
    return pets
end

local function GetBreakables()
    local breakables = {}
    local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return breakables end
    local pos = root.Position

    local function ScanFolder(folder)
        if not folder then return end
        for _, b in ipairs(folder:GetChildren()) do
            if b:IsA("Model") and b.PrimaryPart then
                local dist = (b.PrimaryPart.Position - pos).Magnitude
                if dist <= FARM_RADIUS then
                    table.insert(breakables, { name = b.Name, dist = dist, obj = b })
                end
            end
        end
    end

    pcall(function() ScanFolder(Workspace.__THINGS:FindFirstChild("Breakables")) end)
    pcall(function()
        local container = Workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER")
        if container and container:FindFirstChild("Active") then
            for _, inst in ipairs(container.Active:GetChildren()) do
                ScanFolder(inst:FindFirstChild("Breakables") or inst)
            end
        end
    end)

    table.sort(breakables, function(a, b) return a.dist < b.dist end)
    return breakables
end

local function MagneticLoot()
    pcall(function()
        local orbs = Workspace.__THINGS:FindFirstChild("Orbs")
        if orbs then
            local orbIds = {}
            for _, orb in ipairs(orbs:GetChildren()) do
                if orb:IsA("Part") or orb:IsA("MeshPart") then table.insert(orbIds, tonumber(orb.Name)); orb:Destroy() end
            end
            if #orbIds > 0 then Network.Fire("Orbs: Collect", orbIds) end
        end

        local bags = Workspace.__THINGS:FindFirstChild("Lootbags")
        if bags then
            local bagIds = {}
            for _, bag in ipairs(bags:GetChildren()) do
                if bag:IsA("Model") or bag:IsA("Part") then table.insert(bagIds, bag.Name); bag:Destroy() end
            end
            if #bagIds > 0 then Network.Fire("Lootbags_Claim", bagIds) end
        end
    end)
end

task.spawn(function()
    while true do
        if _G.CurrentPhase == "FARMING" and _G.FarmReady then 
            pcall(function()
                local myPets = GetMyPets()
                local targets = GetBreakables()
                
                if #myPets > 0 and #targets > 0 then
                    local petMapping = {}
                    local petIndex = 1
                    
                    for _, target in ipairs(targets) do
                        for i = 1, MAX_PETS_PER_TARGET do
                            if petIndex <= #myPets then
                                petMapping[myPets[petIndex].euid] = target.name
                                petIndex = petIndex + 1
                            else
                                break
                            end
                        end
                        if petIndex > #myPets then break end
                    end
                    
                    if next(petMapping) then Network.Fire("Breakables_JoinPetBulk", petMapping) end
                end
                
                MagneticLoot()
            end)
        end
        task.wait(0.12)
    end
end)

RunService.Heartbeat:Connect(function()
    if _G.CurrentPhase ~= "FARMING" or not _G.FarmReady then return end
    pcall(function()
        local targets = GetBreakables()
        for i = 1, math.min(5, #targets) do Network.UnreliableFire("Breakables_PlayerDealDamage", targets[i].name) end
    end)
end)

-- ==========================================
-- 🚀 CÁC TÍNH NĂNG PHỤ (MAIL, GIFTS, ULTIMATE, UPGRADE, HATCH)
-- ==========================================
-- Sắp xếp Mở khóa Trứng từ thấp lên cao để mở khóa tuần tự (Không nhảy cóc)
local SpringEggUnlocks = { 
    { number = 2, cost = 300 }, 
    { number = 3, cost = 1500 }, 
    { number = 4, cost = 6000 }, 
    { number = 5, cost = 20000 } 
}

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
                
                local eggToken = 0
                local save = Save.Get()
                if save.Inventory and save.Inventory.Misc then 
                    for _, item in pairs(save.Inventory.Misc) do 
                        if item.id and item.id:find("Spring Egg Token") then 
                            eggToken = eggToken + (item._am or 1) 
                        end 
                    end 
                end
                if eggToken == 0 then 
                    local c = CurrencyCmds.Get("SpringEggTokens") or CurrencyCmds.Get("Spring Egg Token"); 
                    if type(c) == "number" then eggToken = c end 
                end
                
                -- Bắn lệnh tuần tự: Quả 2 -> 3 -> 4 -> 5 (Server sẽ tự kiểm tra điều kiện và bỏ qua nếu đã mua hoặc không đủ tiền)
                for _, egg in ipairs(SpringEggUnlocks) do
                    if eggToken >= egg.cost then 
                        pcall(function() Network.Fire("Instancing_FireCustomFromClient", "EasterHatchEvent", "SelectEgg", egg.number) end)
                        task.wait(0.5) -- Đợi server xử lý xong 1 quả trước khi gửi lệnh nâng cấp quả tiếp theo
                    end
                end
            end)
        end
    end
end)

task.spawn(function() while task.wait(15) do pcall(function() Network.Invoke('Mailbox: Claim All') end) end end)
task.spawn(function() while task.wait(5) do pcall(function() local save = Save.Get(); if not save then return end; local redeemed = save.FreeGiftsRedeemed or {}; local currentTime = save.FreeGiftsTime or 0; for _, gift in pairs(FreeGiftsDirectory) do if gift.WaitTime <= currentTime and not table.find(redeemed, gift._id) then Network.Invoke('Redeem Free Gift', gift._id); break end end end) end end)
task.spawn(function() while task.wait(1.5) do pcall(function() local equipped = UltimateCmds.GetEquippedItem(); if equipped and equipped._data and equipped._data.id then UltimateCmds.Activate(equipped._data.id) end end) end end)
task.spawn(function() if AutoHatch then pcall(function() local EggFrontend = getsenv(Players.LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"]); if EggFrontend then EggFrontend.PlayEggAnimation = function() return end; EggFrontend.PlayCustom = function() return end end end) end end)

-- ==========================================
-- 🚀 SIÊU TỐC ĐỘ ẤP TRỨNG (FAST HATCH SPAMMER)
-- ==========================================
task.spawn(function()
    while true do
        if _G.CurrentPhase == "HATCHING" then
            pcall(function() Network.Invoke("EasterHatchEvent", "HatchRequest") end)
            task.wait(0.1) 
        else
            task.wait(1)
        end
    end
end)

-- ==========================================
-- 🚀 VÒNG LẶP ĐIỀU HƯỚNG CHẾ ĐỘ
-- ==========================================
local State = { Phase = (Mode == "HatchOnly") and "HATCHING" or "FARMING", TimeLeft = (Mode == "HatchOnly") and math.huge or (math.max(20, FarmTimeMinutes) * 60), CurrentPortal = 1, IsReady = false }
_G.CurrentPhase = State.Phase; _G.FarmReady = false

local SafePart = Instance.new("Part", Workspace)
SafePart.Size = Vector3.new(25, 1, 25); SafePart.Anchored = true; SafePart.Transparency = 0.8; SafePart.Material = Enum.Material.Glass; SafePart.BrickColor = BrickColor.new("Toothpaste")
local function TeleportPlayer(cf)
    if not cf then return end
    HumanoidRootPart.Anchored = false; HumanoidRootPart.CFrame = cf + Vector3.new(0, 1.5, 0); SafePart.CFrame = cf - Vector3.new(0, 1.5, 0); HumanoidRootPart.Velocity = Vector3.new(0,0,0)
end

local function EnterZonePhysically(portalIndex)
    _G.FarmReady = false; _G.CurrentFarmCF = nil
    TeleportPlayer(_G.DynamicPortals[portalIndex]); task.wait(0.5) 
    pcall(function()
        for _, prompt in pairs(Workspace:GetDescendants()) do if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart") then if (prompt.Parent.Position - HumanoidRootPart.Position).Magnitude <= 50 then fireproximityprompt(prompt) end end end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.5); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    task.spawn(function()
        for i = 1, 30 do 
            pcall(function()
                for _, obj in pairs(Player.PlayerGui:GetDescendants()) do
                    if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Visible and obj.Text:match("Yes!") then
                        local btn = obj:IsA("TextButton") and obj or obj.Parent
                        if btn:IsA("GuiButton") then if getconnections then for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end end; local center = btn.AbsolutePosition + (btn.AbsoluteSize / 2); VirtualInputManager:SendMouseButtonEvent(center.X, center.Y + 36, 0, true, game, 1); task.wait(0.05); VirtualInputManager:SendMouseButtonEvent(center.X, center.Y + 36, 0, false, game, 1); return end
                    end
                end
            end)
            task.wait(0.1)
        end
    end)
    local waitTime = 0
    while (HumanoidRootPart.Position - _G.DynamicHubCF.Position).Magnitude < 400 and waitTime < 10 do task.wait(0.5); waitTime = waitTime + 0.5 end
    if waitTime >= 10 then return end
    task.wait(1.5); _G.CurrentFarmCF = CFrame.new(HumanoidRootPart.Position + FarmOffset); TeleportPlayer(_G.CurrentFarmCF); task.wait(0.5); _G.FarmReady = true
end

task.spawn(function()
    HumanoidRootPart.Anchored = true
    local retries = 0
    while InstancingCmds.GetInstanceID() ~= "EasterHatchEvent" and retries < 5 do pcall(function() setthreadidentity(2); InstancingCmds.Enter("EasterHatchEvent"); setthreadidentity(8) end); task.wait(1.5); retries = retries + 1 end
    HumanoidRootPart.Anchored = false
    
    while task.wait(1) do
        State.TimeLeft = State.TimeLeft - 1
        if State.TimeLeft <= 0 then
            State.IsReady = false; _G.FarmReady = false
            if Mode == "Combine" then if State.Phase == "FARMING" then State.Phase = "HATCHING"; State.TimeLeft = HatchTimeMinutes * 60 else State.Phase = "FARMING"; State.TimeLeft = math.max(20, FarmTimeMinutes) * 60; State.CurrentPortal = (State.CurrentPortal % 4) + 1 end
            elseif Mode == "FarmOnly" then State.Phase = "FARMING"; State.TimeLeft = math.max(20, FarmTimeMinutes) * 60; State.CurrentPortal = (State.CurrentPortal % 4) + 1
            elseif Mode == "HatchOnly" then State.Phase = "HATCHING"; State.TimeLeft = math.huge end
            _G.CurrentPhase = State.Phase
        end

        if not State.IsReady then
            if State.Phase == "FARMING" then EnterZonePhysically(State.CurrentPortal); State.IsReady = true
            else local targetCF = CFrame.new(_G.DynamicHubCF.Position + HatchOffset); TeleportPlayer(targetCF); State.IsReady = true; _G.FarmReady = false end
        end

        if State.IsReady then
            if State.Phase == "FARMING" and _G.FarmReady then if _G.CurrentFarmCF and (HumanoidRootPart.Position - _G.CurrentFarmCF.Position).Magnitude > 30 then TeleportPlayer(_G.CurrentFarmCF) end
            elseif State.Phase == "HATCHING" then local targetCF = CFrame.new(_G.DynamicHubCF.Position + HatchOffset); if (HumanoidRootPart.Position - targetCF.Position).Magnitude > 30 then TeleportPlayer(targetCF) end end
        end
        
        local elapsed = os.time() - StartTime
        local timeStr = State.TimeLeft == math.huge and "Unlimited" or string.format("%02d:%02d", math.floor(State.TimeLeft/60), State.TimeLeft%60)
        UI:SetText("Time", string.format("Time: %02d:%02d:%02d | Time Left: %s", math.floor(elapsed/3600), math.floor((elapsed%3600)/60), elapsed%60, timeStr))
    end
end)

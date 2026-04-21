-- ==========================================
-- 🌸 EASTER AUTO - V37 (ABSOLUTE HATCH VECTOR & TICKET UI) 🌸
-- (Dịch chuyển bằng tọa độ tuyệt đối + UI cập nhật Tickets)
-- ==========================================
if _G.SpringStarted then return end
_G.SpringStarted = true

-- ==========================================
-- ⚙️ ĐỌC CẤU HÌNH TỪ GETGENV().SETTINGS
-- ==========================================
local UserSettings = getgenv().Settings or {}

local Mode = UserSettings.Mode or "Combine"
local FarmTimeMinutes = tonumber(UserSettings.FarmTimeMinutes) or 20
local HatchTimeMinutes = tonumber(UserSettings.HatchTimeMinutes) or 10

local AutoUpgrade = UserSettings.AutoUpgrade
if AutoUpgrade == nil then AutoUpgrade = true end

local AutoHatch = UserSettings.AutoHatch
if AutoHatch == nil then AutoHatch = true end

local WEBHOOK_URL = ""
local DISCORD_USER_ID = ""
if type(UserSettings["Webhook"]) == "table" then
    WEBHOOK_URL = UserSettings["Webhook"].url or ""
    DISCORD_USER_ID = UserSettings["Webhook"]["Discord Id to ping"] or ""
end

-- ==========================================
-- KHỞI TẠO CÁC SERVICE CỦA GAME
-- ==========================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local Library = ReplicatedStorage:WaitForChild("Library")
local Network = require(Library.Client.Network)
local InstancingCmds = require(Library.Client.InstancingCmds)
local PetNetworking = require(Library.Client.PetNetworking)
local Save = require(Library.Client.Save)
local CurrencyCmds = require(Library.Client.CurrencyCmds)
local PlayerPet = require(Library.Client.PlayerPet)

-- ==========================================
-- 🚀 1. EXTREME OPTIMIZE (GIẢM LAG TỐI ĐA)
-- ==========================================
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
Workspace.DescendantAdded:Connect(ExtremeOptimize)
Lighting.DescendantAdded:Connect(ExtremeOptimize)

-- ==========================================
-- 🚀 2. HACK TỐC ĐỘ PET & AUTO ORBS/LOOTBAGS
-- ==========================================
pcall(function() 
    PlayerPet.CalculateSpeedMultiplier = function() return math.huge end 
end)

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

-- ==========================================
-- 🚀 3. WEBHOOK THÔNG BÁO HUGE / TITANIC
-- ==========================================
local foundHuges = {}
local firstWebhookCheck = true

task.spawn(function()
    while task.wait(15) do
        pcall(function()
            local save = Save.Get()
            if not save or not save.Inventory or not save.Inventory.Pet then return end
            
            local currentHuges = {}
            for uid, pet in pairs(save.Inventory.Pet) do
                if pet.id:match("Huge") or pet.id:match("Titanic") then
                    currentHuges[uid] = pet
                    if not firstWebhookCheck and not foundHuges[uid] then
                        local httprequest = (request or http_request or syn and syn.request)
                        if httprequest and WEBHOOK_URL ~= "" then
                            local data = {
                                ["content"] = "<@" .. DISCORD_USER_ID .. "> 🎉 HATCHED A RARE PET!",
                                ["embeds"] = {{
                                    ["title"] = "Hatched: " .. pet.id,
                                    ["color"] = 16737996,
                                    ["fields"] = { {["name"] = "Account", ["value"] = "||" .. Player.Name .. "||"} }
                                }}
                            }
                            httprequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = game.HttpService:JSONEncode(data) })
                        end
                    end
                end
            end
            foundHuges = currentHuges
            firstWebhookCheck = false
        end)
    end
end)

-- ==========================================
-- HỆ THỐNG BIẾN QUẢN LÝ & TỌA ĐỘ VECTOR CHUẨN XÁC
-- ==========================================
_G.DynamicHubCF = nil
_G.DynamicPortals = {}
local ZoneNames = { "Dewdrop Falls", "Tulip Hollow", "Blossom Vale", "Sunstone Heights" }

-- Vector tính từ Bệ rơi Hub (Zero Point)
local PortalOffsets = {
    [1] = Vector3.new(187.92, 12.48, -73.25), 
    [2] = Vector3.new(200.18, 10.73, -24.80), 
    [3] = Vector3.new(198.20, 12.98, 44.73),  
    [4] = Vector3.new(170.03, 12.48, 86.75)   
}

-- Vector tính từ Cửa Cổng đến Giữa Bãi Farm (Tính toán của bạn)
local FarmOffset = Vector3.new(53.53, 0, 0.62)

-- Vector tính từ Bệ rơi Hub (Zero Point) đến Khu Ấp Trứng (Tính toán của bạn)
-- Dựa trên: (-18519.03) - (-18581.56) = 62.53 | (-29122.76) - (-29110.16) = -12.60
local HatchOffset = Vector3.new(62.53, 0, -12.60)

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
-- BỆ ĐỠ VÀ GIAO DIỆN UI
-- ==========================================
local SafePart = Instance.new("Part", Workspace)
SafePart.Size = Vector3.new(25, 1, 25)
SafePart.Anchored = true; SafePart.Transparency = 0.8; SafePart.Material = Enum.Material.Glass
SafePart.BrickColor = BrickColor.new("Toothpaste")
SafePart.CFrame = HumanoidRootPart.CFrame - Vector3.new(0, 3, 0)

local function TeleportPlayer(cf)
    if not cf then return end
    HumanoidRootPart.Anchored = false
    HumanoidRootPart.CFrame = cf + Vector3.new(0, 3, 0)
    SafePart.CFrame = cf - Vector3.new(0, 1, 0)
    HumanoidRootPart.Velocity = Vector3.new(0,0,0)
end

local FarmUI = {}
FarmUI.__index = FarmUI
function FarmUI.new(UIConfig)
	local Self = setmetatable({}, FarmUI)
	Self.GuiName = "SpringEventGui"
	Self.Elements = {}
	Self.Parent = game:GetService("CoreGui")
    if Self.Parent:FindFirstChild(Self.GuiName) then Self.Parent[Self.GuiName]:Destroy() end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = Self.GuiName
	ScreenGui.IgnoreGuiInset = true; ScreenGui.Parent = Self.Parent; ScreenGui.ResetOnSpawn = false
	Self.ScreenGui = ScreenGui

	local Background = Instance.new("Frame")
	Background.BackgroundColor3 = Color3.fromRGB(15, 15, 15); Background.BorderColor3 = Color3.fromRGB(0, 255, 150)
	Background.BorderMode = Enum.BorderMode.Inset; Background.Parent = ScreenGui
	Background.Size = UDim2.new(1, 0, 1, 0); Background.Position = UDim2.new(0.5, 0, 0.5, 0); Background.AnchorPoint = Vector2.new(0.5, 0.5)

	local Container = Instance.new("Frame")
	Container.Size = UDim2.new(1, 0, 1, 0); Container.BackgroundTransparency = 1; Container.Parent = Background
	Self.Container = Container

	local Layout = Instance.new("UIListLayout")
	Layout.Padding = UDim.new(0.015, 0); Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center; Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Parent = Container

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 45, 0, 45); ToggleBtn.Position = UDim2.new(1, -20, 1, -20); ToggleBtn.AnchorPoint = Vector2.new(1, 1)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15); ToggleBtn.Text = "👁"; ToggleBtn.TextSize = 22; ToggleBtn.Parent = ScreenGui
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
    
    ToggleBtn.MouseButton1Click:Connect(function()
        Background.Visible = not Background.Visible
        ToggleBtn.Text = Background.Visible and "👁" or "🙈"
    end)

	local Sorted = {}
	for Name, Data in pairs(UIConfig.UI) do table.insert(Sorted, {Name = Name, Order = Data[1], Text = Data[2], Size = Data[3]}) end
	table.sort(Sorted, function(A, B) return A.Order < B.Order end)

	for Index, Item in ipairs(Sorted) do
		local Label = Instance.new("TextLabel")
		Label.Name = Item.Name; Label.LayoutOrder = Item.Order
		Label.Size = Item.Size and UDim2.new(unpack(Item.Size)) or UDim2.new(0.6, 0, 0.045, 0)
		Label.BackgroundTransparency = 1; Label.Font = Enum.Font.FredokaOne
		Label.Text = Item.Text; Label.TextColor3 = Color3.fromRGB(255, 255, 255); Label.TextScaled = true; Label.Parent = Self.Container
		Self.Elements[Item.Name] = Label

		if Index < #Sorted then
			local Spacer = Instance.new("Frame")
			Spacer.LayoutOrder = Item.Order + 0.5; Spacer.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
			Spacer.Size = UDim2.new(0.4, 0, 0, 2); Spacer.Parent = Self.Container
		end
	end
	return Self
end

function FarmUI:SetText(Name, Text) 
    if self.Elements[Name] then task.defer(function() self.Elements[Name].Text = Text end) end 
end

local UI = FarmUI.new({
    UI = {
        ["Title"]           = {1, "🐰 EASTER HATCH V37", {0.8, 0, 0.08, 0}},
        ["ModeInfo"]        = {2, "Mode: " .. Mode .. " | Hatch: " .. (AutoHatch and "ON" or "OFF")},
        ["Status"]          = {3, "Status: Starting..."},
        ["Phase"]           = {4, "Phase: Initializing"},
        ["TimeLeft"]        = {5, "Time Left: 00:00"},
        ["Zone"]            = {6, "Current Zone: None"},
        ["BreakablesLeft"]  = {7, "Breakables in range: 0"},
        ["Tokens"]          = {8, "Token B/R/S/T: 0/0/0/0"},
        ["EggTokens"]       = {9, "Spring Egg Token: 0"},
        ["Tickets"]         = {10, "Tickets: 0"}, -- Hiển thị Tickets mới thêm vào
        ["FPS"]             = {11, "FPS: 60"}
    }
})

task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            local save = Save.Get()
            local b, r, s, t, eggToken, tickets = 0, 0, 0, 0, 0, 0
            
            if save and save.Inventory then
                if save.Inventory.Misc then
                    for _, item in pairs(save.Inventory.Misc) do
                        local id = item.id or ""
                        if id:find("Bluebell Token") then b = b + (item._am or 1)
                        elseif id:find("Rose Token") then r = r + (item._am or 1)
                        elseif id:find("Sunflower Token") then s = s + (item._am or 1)
                        elseif id:find("Tulip Token") then t = t + (item._am or 1)
                        elseif id:find("Spring Egg Token") then eggToken = eggToken + (item._am or 1)
                        elseif id:lower():find("ticket") then tickets = tickets + (item._am or 1) end
                    end
                end
                
                -- Tìm Tickets trong khu vực Currency (nếu có)
                if save.Inventory.Currency then
                    for _, item in pairs(save.Inventory.Currency) do
                        local id = item.id or ""
                        if id:lower():find("ticket") then tickets = tickets + (item._am or 1) end
                    end
                end
            end
            
            if eggToken == 0 then
                pcall(function()
                    local c = CurrencyCmds.Get("SpringEggTokens") or CurrencyCmds.Get("Spring Egg Token")
                    if c and type(c) == "number" and c > 0 then eggToken = c end
                end)
            end
            
            UI:SetText("Tokens", string.format("Token B/R/S/T: %s/%s/%s/%s", FormatValue(b), FormatValue(r), FormatValue(s), FormatValue(t)))
            UI:SetText("EggTokens", "Spring Egg Token: " .. FormatValue(eggToken))
            UI:SetText("Tickets", "🎟️ Tickets: " .. FormatValue(tickets))
            UI:SetText("FPS", "FPS: " .. math.floor(Workspace:GetRealPhysicsFPS()))
        end)
    end
end)

-- ==========================================
-- HÀM QUA CỔNG ĐỒNG BỘ
-- ==========================================
_G.FarmReady = false
_G.CurrentFarmCF = nil

local function EnterZonePhysically(portalIndex)
    _G.FarmReady = false 
    _G.CurrentFarmCF = nil
    local portalCF = _G.DynamicPortals[portalIndex]
    
    HumanoidRootPart.Anchored = false
    TeleportPlayer(portalCF)
    task.wait(0.5) 
    
    pcall(function()
        for _, prompt in pairs(Workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart") then
                if (prompt.Parent.Position - HumanoidRootPart.Position).Magnitude <= 50 then fireproximityprompt(prompt) end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.5)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    
    task.spawn(function()
        for i = 1, 30 do 
            pcall(function()
                for _, obj in pairs(Player.PlayerGui:GetDescendants()) do
                    if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Visible and obj.Text:match("Yes!") then
                        local btn = obj:IsA("TextButton") and obj or obj.Parent
                        if btn:IsA("GuiButton") then
                            if getconnections then for _, c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() end end
                            local center = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
                            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y + 36, 0, true, game, 1)
                            task.wait(0.05)
                            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y + 36, 0, false, game, 1)
                            return 
                        end
                    end
                end
            end)
            task.wait(0.1)
        end
    end)

    local waitTime = 0
    while (HumanoidRootPart.Position - _G.DynamicHubCF.Position).Magnitude < 400 and waitTime < 10 do
        task.wait(0.5); waitTime = waitTime + 0.5
    end

    if waitTime >= 10 then return end
    task.wait(1.5) 

    _G.CurrentFarmCF = CFrame.new(HumanoidRootPart.Position + FarmOffset) + Vector3.new(0, 3, 0)
    TeleportPlayer(_G.CurrentFarmCF)
    task.wait(0.5)
    _G.FarmReady = true
end

-- ==========================================
-- 🚀 4. ĐỘNG CƠ FAST FARM CHUẨN VRT
-- ==========================================
local u53 = {}
local u54 = {}
local u55 = {}

local function GetClosestBreakablesVRT()
    table.clear(u53)
    if not HumanoidRootPart then return u53 end
    local pos = HumanoidRootPart.Position
    pcall(function()
        local breakables = Workspace.__THINGS:WaitForChild("Breakables"):GetChildren()
        for _, v in ipairs(breakables) do
            if v:IsA("Model") and (v.WorldPivot.Position - pos).Magnitude < 120 then
                table.insert(u53, v.Name)
            end
        end
    end)
    return u53
end

local function PlayerPetsVRT()
    table.clear(u54)
    pcall(function()
        local allPets = PlayerPet.GetAll()
        for _, pet in pairs(allPets) do
            if pet.owner == Player then table.insert(u54, pet) end
        end
    end)
    return u54
end

task.spawn(function()
    while task.wait(0.15) do
        if _G.CurrentPhase ~= "FARMING" or not _G.FarmReady then continue end
        
        table.clear(u55)
        local v88 = GetClosestBreakablesVRT()
        local v89 = PlayerPetsVRT()
        
        UI:SetText("BreakablesLeft", "Breakables in range: " .. #v88)

        if #v88 > 0 and #v89 > 0 then
            local v90 = math.floor(#v89 / #v88)
            local v91 = #v89 % #v88
            local v95 = 1
            
            for v94, v96 in ipairs(v88) do
                local v97 = (v94 <= v91) and (v90 + 1) or v90
                for _ = 1, v97 do
                    if v89[v95] and v89[v95].euid then
                        u55[v89[v95].euid] = v96
                        v95 = v95 + 1
                    end
                end
            end
            
            if next(u55) then 
                pcall(function() Network.Fire("Breakables_JoinPetBulk", unpack({u55})) end) 
            end
        end
    end
end)

-- 💥 TAP AURA (CLICK AURA)
task.spawn(function()
    while task.wait(0.05) do
        if _G.CurrentPhase ~= "FARMING" or not _G.FarmReady then continue end
        local v88 = GetClosestBreakablesVRT()
        if #v88 > 0 then
            pcall(function() 
                for i = 1, math.min(15, #v88) do 
                    Network.UnreliableFire("Breakables_PlayerDealDamage", v88[i]) 
                end 
            end)
        end
    end
end)

Workspace:WaitForChild("__DEBRIS").ChildAdded:Connect(function(child)
    pcall(function() game.Debris:AddItem(child, 0) end)
end)

-- ==========================================
-- 🚀 5. TỰ ĐỘNG NÂNG CẤP SỰ KIỆN (AUTO UPGRADE)
-- ==========================================
task.spawn(function()
    while task.wait(5) do
        if not AutoUpgrade then continue end
        pcall(function()
            local dir = ReplicatedStorage:FindFirstChild("__DIRECTORY")
            local eventUpgradesDir = dir and dir:FindFirstChild("EventUpgrades")
            local eventDir = eventUpgradesDir and eventUpgradesDir:FindFirstChild("Event")
            local targetFolder = eventDir and (eventDir:FindFirstChild("EasterUpgrades") or eventDir:FindFirstChild("Easter2026Upgrades") or eventDir:FindFirstChild("SpringUpgrades"))
            
            if not targetFolder then return end
            local save = Save.Get()
            local currentUpgrades = save.EventUpgrades or {}
            
            for _, upgradeMod in ipairs(targetFolder:GetChildren()) do
                if upgradeMod:IsA("ModuleScript") then
                    local upgradeData = require(upgradeMod)
                    local currentTier = currentUpgrades[upgradeData._id] or 0
                    local nextTierCost = upgradeData.TierCosts and upgradeData.TierCosts[currentTier + 1]
                    
                    if nextTierCost and nextTierCost._data then
                        local currencyId = nextTierCost._data.id
                        local costAmount = nextTierCost._data._am or 1
                        
                        local function GetAmt(cId)
                            if save.Inventory and save.Inventory.Misc then
                                for _, item in pairs(save.Inventory.Misc) do
                                    if item.id == cId then return item._am or 1 end
                                end
                            end
                            local c = CurrencyCmds.Get(cId)
                            return type(c) == "number" and c or 0
                        end
                        
                        if GetAmt(currencyId) >= costAmount then
                            Network.Invoke("EventUpgrades: Purchase", upgradeData._id)
                        end
                    end
                end
            end
        end)
    end
end)

-- ==========================================
-- 🚀 6. TẮT HIỆU ỨNG TRỨNG (CHỜ NỞ TỰ ĐỘNG)
-- ==========================================
task.spawn(function()
    if AutoHatch then
        pcall(function()
            local EggFrontend = getsenv(Players.LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])
            if EggFrontend then
                EggFrontend.PlayEggAnimation = function() return end
                EggFrontend.PlayCustom = function() return end
            end
        end)
    end
end)

-- ==========================================
-- 🚀 7. VÒNG LẶP CHÍNH (QUẢN LÝ CHẾ ĐỘ)
-- ==========================================
local State = { 
    Phase = (Mode == "HatchOnly") and "HATCHING" or "FARMING", 
    TimeLeft = (Mode == "HatchOnly") and math.huge or (math.max(20, FarmTimeMinutes) * 60), 
    CurrentPortal = 1, 
    IsReady = false 
}

_G.CurrentPhase = State.Phase

task.spawn(function()
    HumanoidRootPart.Anchored = true
    local retries = 0
    while InstancingCmds.GetInstanceID() ~= "EasterHatchEvent" and retries < 5 do
        pcall(function() setthreadidentity(2); InstancingCmds.Enter("EasterHatchEvent"); setthreadidentity(8) end)
        task.wait(1.5); retries = retries + 1
    end
    HumanoidRootPart.Anchored = false
    
    if not _G.DynamicHubCF then 
        HumanoidRootPart.Anchored = true
        task.wait(1) 
        _G.DynamicHubCF = HumanoidRootPart.CFrame 
        for i = 1, 4 do
            _G.DynamicPortals[i] = CFrame.new(_G.DynamicHubCF.Position + PortalOffsets[i])
        end
        HumanoidRootPart.Anchored = false
    end
    
    while task.wait(1) do
        State.TimeLeft = State.TimeLeft - 1
        
        if State.TimeLeft <= 0 then
            State.IsReady = false
            _G.FarmReady = false
            
            if Mode == "Combine" then
                if State.Phase == "FARMING" then
                    State.Phase = "HATCHING"
                    State.TimeLeft = HatchTimeMinutes * 60
                else
                    State.Phase = "FARMING"
                    State.TimeLeft = math.max(20, FarmTimeMinutes) * 60
                    State.CurrentPortal = State.CurrentPortal + 1
                    if State.CurrentPortal > 4 then State.CurrentPortal = 1 end
                end
            elseif Mode == "FarmOnly" then
                State.Phase = "FARMING"
                State.TimeLeft = math.max(20, FarmTimeMinutes) * 60
                State.CurrentPortal = State.CurrentPortal + 1
                if State.CurrentPortal > 4 then State.CurrentPortal = 1 end
            elseif Mode == "HatchOnly" then
                State.Phase = "HATCHING"
                State.TimeLeft = math.huge
            end
            
            _G.CurrentPhase = State.Phase
        end

        if not State.IsReady then
            if State.Phase == "FARMING" then
                EnterZonePhysically(State.CurrentPortal)
                State.IsReady = true
            else
                -- SỬ DỤNG TỌA ĐỘ VECTOR TUYỆT ĐỐI TÍNH TỪ HUB ĐỂ ĐẾN BÃI ẤP TRỨNG
                local targetCF = CFrame.new(_G.DynamicHubCF.Position + HatchOffset) + Vector3.new(0, 3, 0)
                TeleportPlayer(targetCF)
                
                State.IsReady = true
                _G.FarmReady = false
            end
        end

        if State.IsReady then
            if State.Phase == "FARMING" and _G.FarmReady then
                local currentTarget = _G.CurrentFarmCF
                if currentTarget and (HumanoidRootPart.Position - currentTarget.Position).Magnitude > 30 then
                    TeleportPlayer(currentTarget)
                end
            elseif State.Phase == "HATCHING" then
                -- KIỂM TRA VỊ TRÍ HATCH
                local targetCF = CFrame.new(_G.DynamicHubCF.Position + HatchOffset) + Vector3.new(0, 3, 0)
                if (HumanoidRootPart.Position - targetCF.Position).Magnitude > 30 then
                    TeleportPlayer(targetCF)
                end
            end
        end
        
        local timeString = ""
        if State.TimeLeft == math.huge then
            timeString = "Unlimited"
        else
            local m = math.floor(State.TimeLeft / 60)
            local s = State.TimeLeft % 60
            timeString = string.format("%02d:%02d", m, s)
        end
        
        UI:SetText("TimeLeft", "Time Left: " .. timeString)
        UI:SetText("Phase", "Phase: " .. State.Phase)
        UI:SetText("Zone", "Zone: " .. (State.Phase == "FARMING" and ZoneNames[State.CurrentPortal] or "Hub"))
        if State.Phase == "FARMING" then UI:SetText("Status", "Status: Farm Zone " .. ZoneNames[State.CurrentPortal])
        else UI:SetText("Status", "Status: Hatching in Hub...") end
    end
end)

-- ==========================================
-- 🌸 EASTER EVENT - V42 (BALANCED FAST FARM & UI FIXED) 🌸
-- (Dựa trên eggevent.txt + fast farm.txt + Tỷ lệ Ticket)
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
local Save = require(Library.Client.Save)
local CurrencyCmds = require(Library.Client.CurrencyCmds)
local PlayerPet = require(Library.Client.PlayerPet)
local EggCmds = require(Library.Client.EggCmds)
local EventUpgradeCmds = require(Library.Client.EventUpgradeCmds)
local EventUpgradesDir = require(Library.Directory.EventUpgrades)
local Items = require(Library.Items)

-- Biến Trackers
local StartTime = os.time()
local StartEggs = 0
pcall(function() StartEggs = Save.Get().EggsHatched or 0 end)
local SessionHuges = 0
local SessionTitanics = 0

-- Hàm chuyển đổi text sang số (1.03k -> 1030)
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
-- 🚀 1. EXTREME OPTIMIZE
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

-- Hack Tốc độ Pet & Dọn Orb/Lootbag
pcall(function() PlayerPet.CalculateSpeedMultiplier = function() return math.huge end end)

local THINGS = Workspace:WaitForChild("__THINGS")
local LootbagsFolder = THINGS:FindFirstChild("Lootbags")
if LootbagsFolder then 
    LootbagsFolder.ChildAdded:Connect(function(bag) 
        pcall(function() bag.Transparency = 1 end); task.wait() 
        if bag then Network.Fire("Lootbags_Claim", { bag.Name }); bag:Destroy() end 
    end) 
end

-- ==========================================
-- 🚀 2. WEBHOOK & RARE TRACKER
-- ==========================================
local foundHuges = {}
local firstWebhookCheck = true

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
                        -- Update Counters
                        if pet.id:match("Titanic") then SessionTitanics = SessionTitanics + 1 else SessionHuges = SessionHuges + 1 end
                        
                        -- Webhook
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
-- 🚀 3. BỆ ĐỠ VÀ GIAO DIỆN UI GỐC
-- ==========================================
local SafePart = Instance.new("Part", Workspace)
SafePart.Size = Vector3.new(25, 1, 25)
SafePart.Anchored = true; SafePart.Transparency = 0.8; SafePart.Material = Enum.Material.Glass
SafePart.BrickColor = BrickColor.new("Toothpaste")
SafePart.CFrame = HumanoidRootPart.CFrame - Vector3.new(0, 3, 0)

local function TeleportPlayer(cf)
    if not cf then return end
    HumanoidRootPart.Anchored = false
    HumanoidRootPart.CFrame = cf + Vector3.new(0, 1.5, 0) -- Ground fix
    SafePart.CFrame = cf - Vector3.new(0, 1.5, 0)
    HumanoidRootPart.Velocity = Vector3.new(0,0,0)
end

local FarmUI = {}
FarmUI.__index = FarmUI
function FarmUI.new(UIConfig)
	local Self = setmetatable({}, FarmUI)
	Self.GuiName = "EasterEventGuiV42"
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
		Label.Size = Item.Size and UDim2.new(unpack(Item.Size)) or UDim2.new(0.7, 0, 0.05, 0)
		Label.BackgroundTransparency = 1; Label.Font = Enum.Font.FredokaOne
		Label.Text = Item.Text; Label.TextColor3 = Color3.fromRGB(255, 255, 255); Label.TextScaled = true; Label.Parent = Self.Container
		Self.Elements[Item.Name] = Label

		if Index < #Sorted then
			local Spacer = Instance.new("Frame")
			Spacer.LayoutOrder = Item.Order + 0.5; Spacer.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
			Spacer.Size = UDim2.new(0.5, 0, 0, 2); Spacer.Parent = Self.Container
		end
	end
	return Self
end

function FarmUI:SetText(Name, Text) 
    if self.Elements[Name] then task.defer(function() self.Elements[Name].Text = Text end) end 
end

-- THIẾT LẬP ĐÚNG CẤU TRÚC YÊU CẦU CỦA BẠN
local UI = FarmUI.new({
    UI = {
        ["Title"]           = {1, "🐰 EASTER EVENT V42", {0.8, 0, 0.08, 0}},
        ["ModeInfo"]        = {2, "Mode: " .. Mode},
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
-- 🚀 4. CẬP NHẬT UI LIÊN TỤC
-- ==========================================
task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            local save = Save.Get()
            local b, r, s, t, eggToken = 0, 0, 0, 0, 0
            
            -- Đọc Tokens
            if save and save.Inventory and save.Inventory.Misc then
                for _, item in pairs(save.Inventory.Misc) do
                    local id = item.id or ""
                    if id:find("Bluebell Token") then b = b + (item._am or 1)
                    elseif id:find("Rose Token") then r = r + (item._am or 1)
                    elseif id:find("Sunflower Token") then s = s + (item._am or 1)
                    elseif id:find("Tulip Token") then t = t + (item._am or 1)
                    elseif id:find("Spring Egg Token") then eggToken = eggToken + (item._am or 1)
                    end
                end
            end
            
            if eggToken == 0 then
                pcall(function()
                    local c = CurrencyCmds.Get("SpringEggTokens") or CurrencyCmds.Get("Spring Egg Token")
                    if c and type(c) == "number" and c > 0 then eggToken = c end
                end)
            end
            
            -- Tính toán số trứng nở
            local currentEggs = save.EggsHatched or StartEggs
            local hatchedThisSession = currentEggs - StartEggs
            if hatchedThisSession < 0 then hatchedThisSession = 0 end

            -- Cập nhật Tickets & Chance
            local ticketsStr = "0"
            local totalTicketsStr = "1"
            local chance = 0
            
            local activeInstance = Workspace:FindFirstChild("__THINGS") and Workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER") and Workspace.__THINGS.__INSTANCE_CONTAINER:FindFirstChild("Active")
            if activeInstance then
                for _, v in pairs(activeInstance:GetDescendants()) do
                    if v.Name == "ClientTickets" and v:FindFirstChild("Amount") then
                        ticketsStr = v.Amount.Text
                    elseif v.Name == "TotalTickets" and v:FindFirstChild("Amount") then
                        totalTicketsStr = v.Amount.Text
                    end
                end
            end
            
            local parsedYours = ParseValue(ticketsStr)
            local parsedTotal = ParseValue(totalTicketsStr)
            if parsedTotal > 0 then chance = (parsedYours / parsedTotal) * 100 end
            
            -- Đẩy lên giao diện
            UI:SetText("EggsHatched", "Total Eggs Hatched: " .. FormatValue(hatchedThisSession))
            UI:SetText("Rares", string.format("Huge: %d | Titanic: %d", SessionHuges, SessionTitanics))
            UI:SetText("Tokens", string.format("Token B/R/S/T: %s/%s/%s/%s", FormatValue(b), FormatValue(r), FormatValue(s), FormatValue(t)))
            UI:SetText("EggTokens", "Spring Egg Token: " .. FormatValue(eggToken))
            UI:SetText("Tickets", string.format("Ticket: %s / %s (Chance: %.5f%%)", ticketsStr, totalTicketsStr, chance))
            UI:SetText("FPS", "FPS: " .. math.floor(Workspace:GetRealPhysicsFPS()))
        end)
    end
end)

-- ==========================================
-- HỆ THỐNG VECTOR KHÔNG GIAN CỔNG
-- ==========================================
_G.DynamicHubCF = nil
_G.DynamicPortals = {}
local ZoneNames = { "Dewdrop Falls", "Tulip Hollow", "Blossom Vale", "Sunstone Heights" }
local PortalOffsets = {
    [1] = Vector3.new(187.92, 12.48, -73.25), 
    [2] = Vector3.new(200.18, 10.73, -24.80), 
    [3] = Vector3.new(198.20, 12.98, 44.73),  
    [4] = Vector3.new(170.03, 12.48, 86.75)   
}
local FarmOffset = Vector3.new(53.53, 0, 0.62)
local HatchOffset = Vector3.new(62.53, 0, -12.60) 

-- ==========================================
-- HÀM QUA CỔNG ĐỒNG BỘ
-- ==========================================
_G.FarmReady = false
_G.CurrentFarmCF = nil

local function EnterZonePhysically(portalIndex)
    _G.FarmReady = false 
    _G.CurrentFarmCF = nil
    local portalCF = _G.DynamicPortals[portalIndex]
    
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
-- 🚀 5. BALANCED FAST FARM & AUTO ORB (TỪ FILE CỦA BẠN)
-- ==========================================
local function GetMyPets()
    local myPets = {}
    pcall(function()
        for _, pet in ipairs(PlayerPet.GetAll()) do
            if pet.owner == Player then table.insert(myPets, pet) end
        end
    end)
    return myPets
end

local function GetNearbyBreakables()
    local breakables = {}
    local rootPos = HumanoidRootPart.Position
    pcall(function()
        -- Breakables trong Instance (Event, Raid, v.v.)
        local instanceContainer = Workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER")
        if instanceContainer and instanceContainer:FindFirstChild("Active") then
            for _, instance in ipairs(instanceContainer.Active:GetChildren()) do
                local instFolder = instance:FindFirstChild("Breakables") or instance
                if instFolder then
                    for _, breakable in ipairs(instFolder:GetChildren()) do
                        if breakable:IsA("Model") then
                            local dist = (breakable.WorldPivot.Position - rootPos).Magnitude
                            if dist <= 100 then -- Sử dụng 100 studs cho khu Event cho an toàn
                                table.insert(breakables, breakable.Name)
                            end
                        end
                    end
                end
            end
        end
    end)
    return breakables
end

local function CollectNearbyOrbs()
    local orbsFolder = Workspace.__THINGS:FindFirstChild("Orbs")
    if not orbsFolder then return end
    for _, orb in ipairs(orbsFolder:GetChildren()) do
        if orb:IsA("Part") or orb:IsA("MeshPart") then
            Network.Fire("Orbs: Collect", { tonumber(orb.Name) })
            orb:Destroy()
        end
    end
end

-- LUỒNG FAST FARM CÂN BẰNG TỪ FILE TEXT CỦA BẠN
task.spawn(function()
    while task.wait(0.12) do
        if _G.CurrentPhase ~= "FARMING" or not _G.FarmReady then continue end
        
        local pets       = GetMyPets()
        local breakables = GetNearbyBreakables()

        if #pets > 0 and #breakables > 0 then
            local petToBreakable = {}
            local petsPerBreakable = math.floor(#pets / #breakables)
            local extraPets = #pets % #breakables
            local petIndex = 1

            for i, breakableName in ipairs(breakables) do
                local assignCount = petsPerBreakable
                if i <= extraPets then assignCount = assignCount + 1 end

                for _ = 1, assignCount do
                    if petIndex <= #pets then
                        local pet = pets[petIndex]
                        if pet.euid then petToBreakable[pet.euid] = breakableName end
                        petIndex = petIndex + 1
                    end
                end
            end

            if next(petToBreakable) then
                pcall(function() Network.Fire("Breakables_JoinPetBulk", petToBreakable) end)
            end
        end
        CollectNearbyOrbs()
    end
end)

-- LUỒNG AUTO TAP AURA BỔ SUNG
task.spawn(function()
    while task.wait(0.05) do
        if _G.CurrentPhase ~= "FARMING" or not _G.FarmReady then continue end
        local breakables = GetNearbyBreakables()
        if #breakables > 0 then
            pcall(function() 
                for i = 1, math.min(15, #breakables) do 
                    Network.UnreliableFire("Breakables_PlayerDealDamage", breakables[i]) 
                end 
            end)
        end
    end
end)

-- ==========================================
-- 🚀 6. TỰ ĐỘNG NÂNG CẤP & TẮT ANIMATION
-- ==========================================
task.spawn(function()
    while task.wait(5) do
        if not AutoUpgrade then continue end
        pcall(function()
            for upgradeId, upgradeData in pairs(EventUpgradesDir) do
                if upgradeId:find("Easter") or upgradeId:find("Spring") then
                    local currentTier = EventUpgradeCmds.GetTier(upgradeId)
                    local nextTierCost = upgradeData.TierCosts and upgradeData.TierCosts[currentTier + 1]
                    if nextTierCost and nextTierCost._data then
                        local cId = nextTierCost._data.id
                        local costAmount = nextTierCost._data._am or 1
                        
                        local currentAmount = 0
                        if Items.Misc(cId) then currentAmount = Items.Misc(cId):CountExact()
                        else currentAmount = CurrencyCmds.Get(cId) or 0 end
                        
                        if currentAmount >= costAmount then EventUpgradeCmds.Purchase(upgradeId) end
                    end
                end
            end
        end)
    end
end)

task.spawn(function()
    if AutoHatch then
        pcall(function()
            local EggFrontend = getsenv(Players.LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])
            if EggFrontend then EggFrontend.PlayEggAnimation = function() return end; EggFrontend.PlayCustom = function() return end end
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
        for i = 1, 4 do _G.DynamicPortals[i] = CFrame.new(_G.DynamicHubCF.Position + PortalOffsets[i]) end
        HumanoidRootPart.Anchored = false
    end
    
    while task.wait(1) do
        State.TimeLeft = State.TimeLeft - 1
        
        if State.TimeLeft <= 0 then
            State.IsReady = false; _G.FarmReady = false
            if Mode == "Combine" then
                if State.Phase == "FARMING" then State.Phase = "HATCHING"; State.TimeLeft = HatchTimeMinutes * 60
                else State.Phase = "FARMING"; State.TimeLeft = math.max(20, FarmTimeMinutes) * 60; State.CurrentPortal = (State.CurrentPortal % 4) + 1 end
            elseif Mode == "FarmOnly" then
                State.Phase = "FARMING"; State.TimeLeft = math.max(20, FarmTimeMinutes) * 60; State.CurrentPortal = (State.CurrentPortal % 4) + 1
            elseif Mode == "HatchOnly" then
                State.Phase = "HATCHING"; State.TimeLeft = math.huge
            end
            _G.CurrentPhase = State.Phase
        end

        if not State.IsReady then
            if State.Phase == "FARMING" then
                EnterZonePhysically(State.CurrentPortal)
                State.IsReady = true
            else
                local targetCF = CFrame.new(_G.DynamicHubCF.Position + HatchOffset)
                TeleportPlayer(targetCF)
                State.IsReady = true; _G.FarmReady = false
            end
        end

        if State.IsReady then
            if State.Phase == "FARMING" and _G.FarmReady then
                if _G.CurrentFarmCF and (HumanoidRootPart.Position - _G.CurrentFarmCF.Position).Magnitude > 30 then TeleportPlayer(_G.CurrentFarmCF) end
            elseif State.Phase == "HATCHING" then
                local targetCF = CFrame.new(_G.DynamicHubCF.Position + HatchOffset)
                if (HumanoidRootPart.Position - targetCF.Position).Magnitude > 30 then TeleportPlayer(targetCF) end
            end
        end
        
        local elapsed = os.time() - StartTime
        local timeStr = State.TimeLeft == math.huge and "Unlimited" or string.format("%02d:%02d", math.floor(State.TimeLeft/60), State.TimeLeft%60)
        UI:SetText("Time", string.format("Time: %02d:%02d:%02d | Time Left: %s", math.floor(elapsed/3600), math.floor((elapsed%3600)/60), elapsed%60, timeStr))
    end
end)

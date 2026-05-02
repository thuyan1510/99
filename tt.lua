-- ==========================================
-- AUTO TIME TRIAL - SUPER LITE (PATCHED MEMORY LEAK)
-- ==========================================
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Player = Players.LocalPlayer

-- ==========================================
-- CÁC BIẾN CẤU HÌNH THÔNG SỐ
-- ==========================================
local INSTANCE_NAME = "TimeTrial"
local TILE_RADIUS = 70 

local tiles = {
    Vector3.new(-18358.97, 16.49, -557.41),
    Vector3.new(-18302.69, 16.49, -699.98),
    Vector3.new(-18219.80, 16.49, -601.27),
    Vector3.new(-18213.07, 16.49, -453.58),
    Vector3.new(-18081.36, 16.49, -482.34)
}
local bossCoords = Vector3.new(-18097.52, 16.49, -659.96)
local TargetEnchants = {"Tap Power", "Criticals", "Damage", "Treasure Hunter", "Coins"}

local Stats = {
    CurrentTileScanning = 0, TotalRunsCompleted = 0, CurrentRunTilesCleared = 0,
    ScriptStartTime = os.time(), CurrentRunStart = 0, BestTime = math.huge,
    FPS = 60, IsBoss = false
}

-- ==========================================
-- CACHE DỊCH VỤ & THƯ MỤC
-- ==========================================
local ThingsFolder = Workspace:WaitForChild("__THINGS")
local BreakablesFolder = ThingsFolder:WaitForChild("Breakables")
local OrbsFolder = ThingsFolder:WaitForChild("Orbs")
local LootbagsFolder = ThingsFolder:WaitForChild("Lootbags")

local Library = ReplicatedStorage:WaitForChild("Library")
local Network = require(Library.Client.Network)
local Save = require(Library.Client.Save)
local PlayerPet = require(Library.Client.PlayerPet)
local InstancingCmds = require(Library.Client.InstancingCmds)
local FruitCmds = require(Library.Client.FruitCmds)

local function getRootPart()
    local char = Player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ==========================================
-- EXTREME OPTIMIZATION (ĐÃ VÁ LỖI MEMORY LEAK)
-- ==========================================
local DummyPlatformPos = Vector3.new(0, 15000, 0)
local ActiveDummy = nil
local Cam = Workspace.CurrentCamera

local function CreateOptimizationAndPlatforms()
    -- 1. Tạo bệ đứng cho Dummy
    local mainPlat = Instance.new("Part", Workspace)
    mainPlat.Size = Vector3.new(20, 1, 20)
    mainPlat.Position = DummyPlatformPos - Vector3.new(0, 3, 0)
    mainPlat.Anchored = true
    mainPlat.Material = Enum.Material.Neon
    mainPlat.BrickColor = BrickColor.new("Toothpaste")
    
    -- 2. Tạo các bệ đỡ tàng hình dưới các Tile
    for _, pos in ipairs(tiles) do
        local p = Instance.new("Part", Workspace)
        p.Size = Vector3.new(50, 1, 50)
        p.Position = pos - Vector3.new(0, 4, 0)
        p.Anchored = true; p.Transparency = 1
    end
    local bp = Instance.new("Part", Workspace)
    bp.Size = Vector3.new(80, 1, 80)
    bp.Position = bossCoords - Vector3.new(0, 4, 0)
    bp.Anchored = true; bp.Transparency = 1

    -- 3. Tối ưu hóa an toàn (Chỉ ẩn, không xóa ép buộc)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    for _, v in pairs(Lighting:GetDescendants()) do if v:IsA("PostEffect") then v.Enabled = false end end
    
    local function optimizePart(v)
        pcall(function()
            -- BỎ QUA HOÀN TOÀN thư mục __THINGS (Tránh can thiệp vào hiệu ứng rớt tiền, rương, pet gây lỗi cảnh báo vàng)
            if v:IsDescendantOf(ThingsFolder) then return end
            
            if v:IsA("BasePart") and not v.Parent:FindFirstChild("Humanoid") and v ~= mainPlat then
                v.Material = Enum.Material.Plastic
                v.Reflectance = 0
                v.Transparency = 1 
                if v:IsA("MeshPart") or v:IsA("SpecialMesh") then v.TextureID = "" end
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1 -- Ẩn đi thay vì xóa
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                v.Enabled = false -- Tắt hiệu ứng thay vì xóa
            end
        end)
    end

    for _, v in pairs(Workspace:GetDescendants()) do optimizePart(v) end
    Workspace.DescendantAdded:Connect(optimizePart) 
end

local function SetupDummyAndCamera()
    local char = Player.Character or Player.CharacterAdded:Wait()
    char.Archivable = true
    
    if ActiveDummy then ActiveDummy:Destroy() end
    ActiveDummy = char:Clone()
    ActiveDummy.Name = "AFK_Dummy"
    ActiveDummy.Parent = Workspace
    ActiveDummy:SetPrimaryPartCFrame(CFrame.new(DummyPlatformPos))
    
    for _, v in pairs(ActiveDummy:GetDescendants()) do
        if v:IsA("BasePart") then v.Anchored = true end
    end
    
    RunService.RenderStepped:Connect(function()
        if Cam and ActiveDummy and ActiveDummy:FindFirstChild("Humanoid") then
            Cam.CameraSubject = ActiveDummy.Humanoid
        end
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("Decal") then v.Transparency = 1 end
        end
    end)
end

-- ==========================================
-- GIAO DIỆN HIỂN THỊ (COMPACT UI)
-- ==========================================
local FarmUI = {}
FarmUI.__index = FarmUI
function FarmUI.new()
	local Self = setmetatable({}, FarmUI)
	Self.GuiName = "TimeTrialProUI"
	Self.Elements = {}
	Self.Parent = game:GetService("CoreGui")
    if Self.Parent:FindFirstChild(Self.GuiName) then Self.Parent[Self.GuiName]:Destroy() end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = Self.GuiName; ScreenGui.IgnoreGuiInset = true; ScreenGui.Parent = Self.Parent; ScreenGui.ResetOnSpawn = false
    
	local Background = Instance.new("Frame", ScreenGui)
	Background.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Background.BorderSizePixel = 0
	Background.Size = UDim2.new(0, 320, 0, 180)
    Background.Position = UDim2.new(1, -75, 0, 20) 
    Background.AnchorPoint = Vector2.new(1, 0); Background.BackgroundTransparency = 0.15
    local bgStroke = Instance.new("UIStroke", Background); bgStroke.Color = Color3.fromRGB(0, 255, 150); bgStroke.Thickness = 2
    Instance.new("UICorner", Background).CornerRadius = UDim.new(0, 8)

	local Page1 = Instance.new("Frame", Background)
	Page1.Size = UDim2.new(1, 0, 1, 0); Page1.BackgroundTransparency = 1
	local Layout1 = Instance.new("UIListLayout", Page1)
	Layout1.Padding = UDim.new(0, 5); Layout1.HorizontalAlignment = Enum.HorizontalAlignment.Center; Layout1.VerticalAlignment = Enum.VerticalAlignment.Center; Layout1.SortOrder = Enum.SortOrder.LayoutOrder

    local UIConfig = {
        {"Title",      1, "⚡ OPTIMIZED TIME TRIAL"},
        {"Status",     2, "Đang tải..."},
        {"TileProg",   3, "Tiến độ: --"},
        {"RunTime",    4, "Thời gian chạy: 00:00:00"},
        {"BestTime",   5, "Kỷ lục nhanh nhất: --:--"},
        {"FPS",        6, "FPS: 60"}
    }

	for _, Item in ipairs(UIConfig) do
		local Label = Instance.new("TextLabel", Page1)
		Label.Name = Item[1]; Label.LayoutOrder = Item[2]; Label.Size = UDim2.new(1, -20, 0, 22)
		Label.BackgroundTransparency = 1; Label.Font = Enum.Font.GothamBold; Label.Text = Item[3]
        Label.TextColor3 = Color3.fromRGB(240, 240, 240); Label.TextScaled = false; Label.TextSize = 12; Label.RichText = true
        Label.TextXAlignment = (Item[1] == "Title") and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
        Self.Elements[Item[1]] = Label
        
		if Item[2] == 1 then
			local Spacer = Instance.new("Frame", Page1); Spacer.LayoutOrder = 1.5; Spacer.BackgroundColor3 = Color3.fromRGB(0, 255, 150); Spacer.Size = UDim2.new(1, -30, 0, 1.5); Spacer.BorderSizePixel = 0
		end
	end

    local ToggleBtn = Instance.new("TextButton", ScreenGui)
    ToggleBtn.Size = UDim2.new(0, 40, 0, 40); ToggleBtn.Position = UDim2.new(1, -15, 0, 20); ToggleBtn.AnchorPoint = Vector2.new(1, 0)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30); ToggleBtn.Text = "👁"; ToggleBtn.TextSize = 20; ToggleBtn.BorderSizePixel = 0
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", ToggleBtn).Color = Color3.fromRGB(0, 255, 150); Instance.new("UIStroke", ToggleBtn).Thickness = 1.5
    
    local isVisible = true
    ToggleBtn.MouseButton1Click:Connect(function()
        isVisible = not isVisible; Background.Visible = isVisible; ToggleBtn.Text = isVisible and "👁" or "🙈"
    end)
	return Self
end

function FarmUI:SetText(Name, Text) 
    if self.Elements[Name] then task.defer(function() self.Elements[Name].Text = Text end) end 
end
local UI = FarmUI.new()

-- ==========================================
-- ĐỘNG CƠ HỖ TRỢ (FRUITS & ENCHANTS & SMART FARM)
-- ==========================================
local function ManageFruits()
    local save = Save.Get()
    if not save or not save.Inventory or not save.Inventory.Fruit then return end
    local fruitInv = save.Inventory.Fruit
    local bestFruits = {}
    for uid, data in pairs(fruitInv) do
        if data.id and data.id ~= "Candycane" then
            local baseId = data.id
            if not bestFruits[baseId] then bestFruits[baseId] = uid else
                if (data.sh == true) and not (fruitInv[bestFruits[baseId]].sh == true) then bestFruits[baseId] = uid end
            end
        end
    end
    for fruitName, uid in pairs(bestFruits) do
        local activeFruits = {}; pcall(function() activeFruits = FruitCmds.GetActiveFruits() end)
        local data = activeFruits and activeFruits[fruitName]
        local currentStack = 0
        if type(data) == "table" then
            if type(data.Normal) == "table" then for _ in pairs(data.Normal) do currentStack = currentStack + 1 end end
            if type(data.Shiny) == "table" then for _ in pairs(data.Shiny) do currentStack = currentStack + 1 end end
        end
        if currentStack < 20 then
            local amt = math.min(20 - currentStack, fruitInv[uid] and fruitInv[uid]._am or 1)
            if amt > 0 then pcall(function() FruitCmds.Consume(uid, amt); Network.Fire("Fruits: Consume", uid, amt) end); task.wait(0.1) end
        end
    end
end
task.spawn(function() while task.wait(20) do ManageFruits() end end)

local function EquipEnchantLoadout(targetNames)
    task.spawn(function()
        local save = Save.Get()
        if not save or not save.Inventory or not save.Inventory.Enchant then return end
        local maxSlots = (save.MaxEnchantsEquipped or 1) + (save.MaxPaidEnchantsEquipped or 0)
        local pool = {}
        for uid, data in pairs(save.Inventory.Enchant) do table.insert(pool, {uid = uid, id = data.id or "Unknown", tn = data.tn or 1, amount = data._am or 1}) end
        
        local matched = {}
        for slotIndex, enchantName in ipairs(targetNames) do
            if slotIndex > maxSlots then break end
            local valid = {}
            for _, item in ipairs(pool) do if string.find(item.id, enchantName) and item.amount > 0 then table.insert(valid, item) end end
            table.sort(valid, function(a, b) return a.tn > b.tn end)
            if #valid > 0 then matched[slotIndex] = valid[1].uid; valid[1].amount = valid[1].amount - 1 end
        end

        for slotIndex, uid in pairs(matched) do 
            pcall(function() Network.Fire("Enchants_ClearSlot", slotIndex) end); task.wait(0.1)
            pcall(function() Network.Fire("Enchants_SetSlot", slotIndex, uid); Network.Fire("Enchants_Equip", uid, slotIndex) end)
        end
    end)
end

pcall(function()
    PlayerPet.CalculateSpeedMultiplier = function() return math.huge end
end)

local function fastFarm()
    local breakables, root = {}, getRootPart()
    if not root then return end
    for _, b in ipairs(BreakablesFolder:GetChildren()) do
        if b:IsA("Model") and (b.WorldPivot.Position - root.Position).Magnitude < 120 then table.insert(breakables, b.Name) end
    end
    
    local myPets = {}
    for _, pet in pairs(PlayerPet.GetAll()) do if pet.owner == Player then table.insert(myPets, pet) end end
    if #breakables == 0 or #myPets == 0 then return end
    
    local petToBreakable, petIndex = {}, 1
    for i, bName in ipairs(breakables) do
        local petsForThis = math.floor(#myPets / #breakables) + (i <= (#myPets % #breakables) and 1 or 0)
        for _ = 1, petsForThis do if myPets[petIndex] then petToBreakable[myPets[petIndex].euid] = bName; petIndex = petIndex + 1 end end
    end
    Network.Fire("Breakables_JoinPetBulk", petToBreakable)
end

_G.IsTimeTrialFarming = false
task.spawn(function()
    while task.wait(0.05) do
        if _G.IsTimeTrialFarming then 
            pcall(fastFarm)
            pcall(function()
                local root = getRootPart()
                if root then
                    for _, b in ipairs(BreakablesFolder:GetChildren()) do
                        if b:IsA("Model") and (root.Position - b.WorldPivot.Position).Magnitude < 100 then
                            Network.UnreliableFire("Breakables_PlayerDealDamage", b.Name); break
                        end
                    end
                end
            end)
            pcall(function()
                for _, orb in ipairs(OrbsFolder:GetChildren()) do local num = tonumber(orb.Name); if num then Network.Fire("Orbs: Collect", num); orb:Destroy() end end
                local bagIds = {}; for _, bag in ipairs(LootbagsFolder:GetChildren()) do table.insert(bagIds, bag.Name); bag:Destroy() end 
                if #bagIds > 0 then Network.Fire("Lootbags_Claim", bagIds) end
            end) 
        end
    end
end)

-- ==========================================
-- LOGIC CỐT LÕI
-- ==========================================
local function formatTime(seconds)
    if seconds == math.huge then return "--:--" end
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

RunService.RenderStepped:Connect(function(deltaTime) Stats.FPS = math.floor(1 / deltaTime) end)

task.spawn(function()
    while task.wait(1) do
        local elapsedTotal = os.time() - Stats.ScriptStartTime
        local runElapsed = os.time() - Stats.CurrentRunStart
        
        UI:SetText("TileProg", string.format("Đã dọn: %d Tile (Tổng win: <font color='#00ff96'>%d</font>)", Stats.CurrentRunTilesCleared, Stats.TotalRunsCompleted))
        UI:SetText("RunTime", string.format("Thời gian chạy script: %02d:%02d:%02d", math.floor(elapsedTotal/3600), math.floor((elapsedTotal%3600)/60), elapsedTotal%60))
        UI:SetText("BestTime", "Kỷ lục: <font color='#ffff00'>" .. formatTime(Stats.BestTime) .. "</font> (Vòng này: " .. formatTime(runElapsed) .. ")")
        UI:SetText("FPS", "FPS: " .. Stats.FPS)
    end
end)

local function teleportTo(position)
    local char = Player.Character or Player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    hrp.CFrame = CFrame.new(position)
    hrp.Velocity = Vector3.new(0,0,0)
    task.wait(0.2)
end

local function getBreakablesInTile(tilePos, radius)
    local count = 0
    if BreakablesFolder then
        for _, b in pairs(BreakablesFolder:GetChildren()) do
            pcall(function() if (b:GetPivot().Position - tilePos).Magnitude <= radius then count = count + 1 end end)
        end
    end
    return count 
end

local function getNextActiveTile()
    for i, tilePos in ipairs(tiles) do
        if getBreakablesInTile(tilePos, TILE_RADIUS) > 0 then return i end
    end
    return nil 
end

local function autoTimeTrial()
    print("Khởi chạy tối ưu hóa môi trường...")
    CreateOptimizationAndPlatforms()
    SetupDummyAndCamera()
    EquipEnchantLoadout(TargetEnchants)
    
    while true do
        UI:SetText("Status", "⏳ Đang di chuyển vào Map Time Trial...")
        while InstancingCmds.GetInstanceID() ~= INSTANCE_NAME do
            pcall(function() InstancingCmds.Enter(INSTANCE_NAME) end)
            task.wait(2)
        end
        
        task.wait(3) 
        _G.IsTimeTrialFarming = true
        Stats.CurrentRunStart = os.time()
        Stats.CurrentRunTilesCleared = 0
        Stats.IsBoss = false

        while true do
            if getBreakablesInTile(bossCoords, TILE_RADIUS) > 0 then break end

            local nextTileIndex = getNextActiveTile()
            if nextTileIndex then
                Stats.CurrentTileScanning = nextTileIndex
                UI:SetText("Status", "📍 Đang dọn rương vô hình tại Tile: " .. nextTileIndex)
                teleportTo(tiles[nextTileIndex])
                task.wait(0.5) 
                
                while getBreakablesInTile(tiles[nextTileIndex], TILE_RADIUS) > 0 do
                    if getBreakablesInTile(bossCoords, TILE_RADIUS) > 0 then break end
                    task.wait(0.2) 
                end
                
                if getBreakablesInTile(bossCoords, TILE_RADIUS) == 0 then
                    Stats.CurrentRunTilesCleared = Stats.CurrentRunTilesCleared + 1
                end
            else
                Stats.CurrentTileScanning = 0
                UI:SetText("Status", "🔍 Đang đợi Cooldown Rương...")
                task.wait(0.5) 
            end
        end

        Stats.IsBoss = true
        UI:SetText("Status", "⚔️ Đang đập Boss Chest (Background)!")
        teleportTo(bossCoords)
        
        while getBreakablesInTile(bossCoords, TILE_RADIUS) > 0 do task.wait(0.5) end
        
        UI:SetText("Status", "✅ Đã đập xong Boss! Đang tự động thoát map...")
        _G.IsTimeTrialFarming = false 
        
        while InstancingCmds.GetInstanceID() == INSTANCE_NAME do
            pcall(function()
                for _, gui in pairs(Player.PlayerGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled then
                        for _, desc in pairs(gui:GetDescendants()) do
                            if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                                local text = desc:IsA("TextButton") and desc.Text:lower() or ""
                                local name = desc.Name:lower()
                                if text:match("leave") or text:match("confirm") or text:match("continue") or text:match("ok") or text:match("claim") or name:match("leave") or name:match("confirm") or name:match("claim") then
                                    if getconnections then
                                        for _, conn in pairs(getconnections(desc.MouseButton1Click)) do conn:Fire() end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            pcall(function() InstancingCmds.Leave() end)
            task.wait(1)
        end
        
        local completionTime = os.time() - Stats.CurrentRunStart
        if completionTime < Stats.BestTime then Stats.BestTime = completionTime end
        Stats.TotalRunsCompleted = Stats.TotalRunsCompleted + 1
        
        task.wait(2) 
    end
end

task.spawn(autoTimeTrial)

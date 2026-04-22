-- ==========================================
-- 🌸 EASTER EVENT - V60 (PHYSICAL MACRO UPGRADE) 🌸
-- Tích hợp PetSimModule để tối ưu & farm
-- ==========================================
if _G.SpringStarted then return end
_G.SpringStarted = true

-- ========== TẢI MODULE TỪ GITHUB ==========
local Module
if not _G.PetSimModule then
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/thuyan1510/99/refs/heads/main/PetSimModule.lua"))()
    end)
    if success then
        _G.PetSimModule = result
        Module = result
    else
        warn("Không thể tải module từ GitHub: " .. tostring(result))
        return
    end
else
    Module = _G.PetSimModule
end

-- ========== CẤU HÌNH ==========
local UserSettings = getgenv().Settings or {}
local function SafeNumber(val, default) return tonumber(val) or default end

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
local DISCORD_USER_ID = type(WebhookCfg) == "table" and (type(WebhookCfg["Discord Id to ping"]) == "table" and WebhookCfg["Discord Id to ping"][1] or "") or tostring(WebhookCfg["Discord Id to ping"])

-- ========== DỊCH VỤ ==========
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
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
local InstancingCmds = require(Library.Client.InstancingCmds)

-- ========== TỐI ƯU HÓA BẰNG MODULE ==========
Module.Optimize(60)                -- Giới hạn 15 FPS, tắt hiệu ứng
Module.SetPetSpeed(200)            -- Tăng tốc pet

-- ========== CHỐNG AFK (GIỮ LẠI LỚP RIÊNG VÌ MẠNH HƠN) ==========
pcall(function()
    local v3 = require(ReplicatedStorage.Library.Client.Network)
    local _Fire = v3.Fire
    setreadonly(v3, false)
    v3.Fire = function(...)
        local args = {...}
        if args[1] == 'Idle Tracking: Update Timer' then return end
        return _Fire(...)
    end
    setreadonly(v3, true)
end)

pcall(function()
    local UserInputService = game:GetService("UserInputService")
    if getconnections then
        for _, v in pairs(getconnections(UserInputService.WindowFocusReleased)) do if v.Disable then v:Disable() end end
        for _, v in pairs(getconnections(UserInputService.WindowFocused)) do if v.Disable then v:Disable() end end
        for _, v in pairs(getconnections(Player.Idled)) do if v.Disable then v:Disable() end end
    end
end)

task.spawn(function()
    while task.wait(300) do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            local hum = Player.Character and Player.Character:FindFirstChild("Humanoid")
            if hum then hum.Jump = true end
        end)
    end
end)

-- ========== TỌA ĐỘ & THEO DÕI FPS ==========
_G.DynamicHubCF = CFrame.new(-18581.56, 17.03, -29110.16)
_G.DynamicPortals = {}
local PortalOffsets = { Vector3.new(187.92, 12.48, -73.25), Vector3.new(200.18, 10.73, -24.80), Vector3.new(198.20, 12.98, 44.73), Vector3.new(170.03, 12.48, 86.75) }
for i = 1, 4 do _G.DynamicPortals[i] = CFrame.new(_G.DynamicHubCF.Position + PortalOffsets[i]) end

local FarmOffset = Vector3.new(53.53, 0, 0.62)
local HatchOffset = Vector3.new(62.53, 0, -12.60)

local TrueFPS = 60
RunService.RenderStepped:Connect(function(delta) TrueFPS = math.floor(1 / delta) end)

-- ========== BIẾN THEO DÕI ==========
local StartTime = os.time()
local StartEggs = 0
pcall(function() StartEggs = Save.Get().Easter2026EggsHatched or 0 end)
local SessionHuges, SessionTitanics = 0, 0

-- Hàm tiện ích (dùng lại của module hoặc viết thêm)
local function ParseValue(str)
    if not str then return 0 end
    str = tostring(str):lower():gsub("<[^>]+>", ""):gsub(",", ""):gsub("%s+", "")
    return Module.RemoveSuffix(str)  -- Dùng hàm module
end
local FormatValue = Module.AddSuffix

-- ========== UI ==========
local FarmUI = {}
FarmUI.__index = FarmUI
function FarmUI.new(UIConfig)
    local Self = setmetatable({}, FarmUI)
    Self.GuiName = "EasterEventGuiV60"
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
        ["Title"]           = {1, "🐰 EASTER EVENT V60", {0.8, 0, 0.08, 0}},
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

-- ========== CẬP NHẬT DỮ LIỆU UI ==========
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
                local container = Workspace.__THINGS:FindFirstChild("__INSTANCE_CONTAINER")
                if container and container:FindFirstChild("Active") then
                    local pos = HumanoidRootPart.Position
                    local closestBoard, minDist = nil, math.huge
                    for _, v in ipairs(container.Active:GetDescendants()) do
                        if v.Name == "RaffleBoard" and v:IsA("Model") then
                            local dist = (v:GetPivot().Position - pos).Magnitude
                            if dist < minDist then minDist = dist; closestBoard = v end
                        end
                    end
                    if closestBoard then
                        local totalText = closestBoard:FindFirstChild("TotalTickets", true)
                        if totalText and totalText:FindFirstChild("Amount") then realTotalTickets = ParseValue(totalText.Amount.Text) end
                        if realClientTickets == 0 then
                            local clientText = closestBoard:FindFirstChild("ClientTickets", true)
                            if clientText and clientText:FindFirstChild("Amount") then realClientTickets = ParseValue(clientText.Amount.Text) end
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

-- ========== WEBHOOK TRACKER (DÙNG LẠI) ==========
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

-- ========== LOGIC DI CHUYỂN & FARM ==========
local currentZone = 1
local farmingActive = true

local function moveToCFrame(cf)
    local hrp = HumanoidRootPart
    local distance = (hrp.Position - cf.Position).Magnitude
    if distance > 100 then
        -- Teleport nếu quá xa (dùng noclip của module)
        Module.Noclip(true)
        hrp.CFrame = cf
        task.wait(0.2)
        Module.Noclip(false)
    else
        -- Tween
        local tween = TweenService:Create(hrp, TweenInfo.new(distance/50, Enum.EasingStyle.Linear), {CFrame = cf})
        tween:Play()
        tween.Completed:Wait()
    end
end

local function farmLoop()
    while farmingActive do
        if Mode == "FarmOnly" or Mode == "Combine" then
            -- Sử dụng Module.FarmBreakables với cài đặt (bỏ qua nếu cần)
            Module.FarmBreakables({ IgnoreIDs = {}, IgnoreZones = {} })
            task.wait(0.5)
        else
            task.wait(1)
        end
    end
end

local function hatchLoop()
    while farmingActive do
        if Mode == "HatchOnly" or Mode == "Combine" then
            -- Logic mở trứng tự động (giả lập click)
            pcall(function()
                local hatchGui = Player.PlayerGui:FindFirstChild("HatchScreen")
                if hatchGui and hatchGui.Enabled then
                    local button = hatchGui:FindFirstChild("HatchButton", true)
                    if button and button:IsA("TextButton") then
                        firesignal(button.MouseButton1Click)
                    end
                end
            end)
            task.wait(0.2)
        else
            task.wait(1)
        end
    end
end

local function zoneSwitcher()
    while farmingActive do
        local cycleTime = (Mode == "FarmOnly" and FarmTimeMinutes or HatchTimeMinutes) * 60
        task.wait(cycleTime)
        if not farmingActive then break end
        currentZone = currentZone % 4 + 1
        local targetCF = _G.DynamicPortals[currentZone]
        moveToCFrame(targetCF)
        task.wait(1)
        -- Vào instance nếu cần (sử dụng module)
        local zoneName = ({"Dewdrop Falls", "Tulip Hollow", "Blossom Vale", "Sunstone Heights"})[currentZone]
        Module.EnterInstance(zoneName)
    end
end

-- ========== KHỞI ĐỘNG ==========
task.spawn(farmLoop)
task.spawn(hatchLoop)
task.spawn(zoneSwitcher)

-- Di chuyển đến zone đầu tiên
moveToCFrame(_G.DynamicPortals[1])
Module.EnterInstance("Dewdrop Falls")

-- Giữ script chạy
while _G.SpringStarted do task.wait(10) end

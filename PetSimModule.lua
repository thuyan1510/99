-- ==========================================
-- PET SIMULATOR X - UTILITY MODULE V2
-- (Tối ưu cho sự kiện Easter V60)
-- ==========================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildOfClass("Terrain")

local LocalPlayer = Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end
repeat task.wait() until LocalPlayer and LocalPlayer:GetAttribute("__LOADED")
if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end

local Character = LocalPlayer.Character
local HumanoidRootPart = Character.HumanoidRootPart
local NLibrary = ReplicatedStorage:FindFirstChild("Library")

-- Tải các module của game (nếu chưa có)
if not getgenv().Library then
    getgenv().Library = {}
    local function LoadModules(path, isOne, loadItself)
        if isOne then
            local s, m = pcall(require, path)
            if s then getgenv().Library[path.Name] = m end
            return
        end
        if loadItself then
            local s, m = pcall(require, path)
            if s then getgenv().Library[path.Name] = m end
        end
        for _, v in ipairs(path:GetChildren()) do
            if v:IsA("ModuleScript") and not v:GetAttribute("NOLOAD") and v.Name ~= "ToRomanNum" then
                local s, m = pcall(require, v)
                if s then getgenv().Library[v.Name] = m end
            end
        end
    end

    for _, folder in ipairs({NLibrary, NLibrary.Directory, NLibrary.Client, NLibrary.Util, NLibrary.Types, NLibrary.Items, NLibrary.Functions, NLibrary.Modules, NLibrary.Balancing}) do
        LoadModules(folder)
    end
    LoadModules(NLibrary.Shared.Variables, true)
    LoadModules(NLibrary.Client.OrbCmds.Orb, true)
    LoadModules(NLibrary.Client.MiningCmds.BlockWorldClient, true)
end

local Library = getgenv().Library

-- Xử lý Breakables
local Breakables = {}
local function CreateBreakable(data)
    pcall(function()
        Breakables[data.u] = {
            UID = data.u,
            CFrame = data.cf,
            ID = data.id,
            Zone = data.pid,
        }
    end)
end
local function CleanBreakable(uid) pcall(function() Breakables[uid] = nil end) end

local Events = { Created = CreateBreakable, Ping = CreateBreakable, Destroyed = CleanBreakable, Cleanup = CleanBreakable }
for action, func in pairs(Events) do
    Library.Network.Fired("Breakables_" .. action):Connect(function(data)
        for i = 1, #data do func(unpack(data[i])) end
    end)
end
for _, v in ipairs(workspace.__THINGS.Breakables:GetChildren()) do
    if v:IsA("Model") then
        Breakables[v:GetAttribute("BreakableUID")] = {
            UID = v:GetAttribute("BreakableUID"),
            CFrame = v:GetPivot(),
            ID = v:GetAttribute("BreakableID"),
            Zone = v:GetAttribute("ParentID")
        }
    end
end

-- Pet Equip Handling
local Pets = {}
for _, v in pairs(Library.PetNetworking.EquippedPets()) do Pets[v.euid] = true end
Library.Network.Fired("Pets_LocalPetsUpdated"):Connect(function(petList)
    for _, v in pairs(petList) do Pets[v.ePet.euid] = true end
end)
Library.Network.Fired("Pets_LocalPetsUnequipped"):Connect(function(petList)
    for _, v in pairs(petList) do Pets[v] = nil end
end)

-- Orb Auto-Collect
Library.Orb.new = function() end
Library.Orb.ComputeInitialCFrame = function() return CFrame.new() end
Library.Network.Fired("Orbs: Create"):Connect(function(orbs)
    local ids = {}
    for _, v in ipairs(orbs) do table.insert(ids, tonumber(v.id)) end
    Library.Network.Fire("Orbs: Collect", ids)
end)
workspace.__THINGS.Orbs.ChildAdded:Connect(function(orb) if orb then orb:Destroy() end end)

-- ========== MODULE EXPORT ==========
local Module = {}

function Module.GetBreakables() return Breakables end

function Module.GetEquippedPets()
    local list = {}
    for uid in pairs(Pets) do table.insert(list, uid) end
    return list
end

function Module.SetPetSpeed(speed)
    Library.PlayerPet.CalculateSpeedMultiplier = function() return tonumber(speed) or 200 end
end

function Module.Noclip(enable)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if enable then
        if not hrp:FindFirstChild("LinearVelocity") then
            local att = Instance.new("Attachment", hrp)
            local lv = Instance.new("LinearVelocity", hrp)
            lv.MaxForce = math.huge
            lv.VectorVelocity = Vector3.zero
            lv.Attachment0 = att
        end
        task.spawn(function()
            while enable do
                for _, v in ipairs(LocalPlayer.Character:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
                task.wait()
            end
        end)
    else
        local lv = hrp:FindFirstChild("LinearVelocity")
        if lv then lv:Destroy() end
    end
end

function Module.FarmBreakables(settings)
    settings = settings or {}
    local ignoreIDs = settings.IgnoreIDs or {}
    local ignoreZones = settings.IgnoreZones or {}
    local pets = Module.GetEquippedPets()
    if #pets == 0 then return end

    local validBreakables = {}
    for uid, data in pairs(Breakables) do
        if not table.find(ignoreIDs, data.ID) and not table.find(ignoreZones, data.Zone) then
            table.insert(validBreakables, uid)
        end
    end
    if #validBreakables == 0 then return end

    local assignments = {}
    local petIndex, breakableIndex = 1, 1
    while petIndex <= #pets do
        assignments[pets[petIndex]] = validBreakables[breakableIndex]
        petIndex = petIndex + 1
        breakableIndex = breakableIndex % #validBreakables + 1
    end

    if next(assignments) then
        Library.Network.UnreliableFire("Breakables_PlayerDealDamage", validBreakables[1])
        Library.Network.Fire("Breakables_JoinPetBulk", assignments)
    end
end

function Module.Optimize(fpsCap)
    local UserSettings = UserSettings()
    local GameSettings = UserSettings:GetService("UserGameSettings")
    GameSettings.GraphicsQualityLevel = 1
    GameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    GameSettings.MasterVolume = 0
    settings().Rendering.QualityLevel = 1
    settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
    sethiddenproperty(Terrain, "Decoration", false)
    sethiddenproperty(Lighting, "Technology", 2)

    for _, v in ipairs(Lighting:GetChildren()) do v:Destroy() end
    Lighting.GlobalShadows = false
    Lighting.Brightness = 0
    Lighting.Ambient = Color3.new(0, 0, 0)
    Lighting.FogEnd = 0
    Lighting.Technology = Enum.Technology.Voxel

    if Terrain then
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 1
    end

    local function ClearItem(v)
        if v.Name == "SystemExodus" then return end
        if v:IsA("Model") and v.Parent == workspace and v.Name ~= LocalPlayer.Name then v:Destroy()
        elseif v:IsA("Workspace") then
            v.Terrain.WaterWaveSize = 0
            v.Terrain.WaterWaveSpeed = 0
            sethiddenproperty(v, "StreamingTargetRadius", 64)
            sethiddenproperty(v, "StreamingPauseMode", 2)
            sethiddenproperty(v.Terrain, "Decoration", false)
        elseif v:IsA("Model") then sethiddenproperty(v, "LevelOfDetail", 1)
        elseif v:IsA("TextButton") or v:IsA("TextLabel") or v:IsA("ImageLabel") then v.Visible = false
        elseif v:IsA("BasePart") then v.Material = Enum.Material.Plastic; v.Reflectance = 0
        elseif v:IsA("Texture") or v:IsA("Decal") then v.Texture = ""; v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false
        elseif v:IsA("Sound") then v.Playing = false; v.Volume = 0
        end
    end

    for _, v in ipairs(workspace:GetDescendants()) do ClearItem(v) end
    workspace.DescendantAdded:Connect(ClearItem)

    if fpsCap then setfpscap(fpsCap) end
end

-- Tiện ích chuyển đổi số
function Module.AddSuffix(amount)
    local suffixes = {"", "k", "m", "b", "t"}
    local index = 1
    local n = math.abs(amount)
    while n >= 1000 and index < #suffixes do n = n / 1000; index = index + 1 end
    return string.format("%.2f", n):gsub("%.00$", "") .. suffixes[index]
end

function Module.RemoveSuffix(str)
    local num = tonumber(str:match("[%d%.]+")) or 0
    local suffix = str:match("%a+")
    local mult = ({k=1e3, m=1e6, b=1e9, t=1e12})[suffix:lower()] or 1
    return num * mult
end

function Module.ConvertTime(sec)
    local d = math.floor(sec / 86400); sec = sec % 86400
    local h = math.floor(sec / 3600); sec = sec % 3600
    local m = math.floor(sec / 60); sec = sec % 60
    return string.format("%dd %dh %dm %ds", d, h, m, sec)
end

function Module.EnterInstance(name)
    if Library.InstancingCmds.GetInstanceID() == name then return end
    setthreadidentity(2)
    Library.InstancingCmds.Enter(name)
    setthreadidentity(8)
    task.wait(0.25)
    if Library.InstancingCmds.GetInstanceID() ~= name then Module.EnterInstance(name) end
end

return Module

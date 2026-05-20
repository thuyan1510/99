if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

local Lib = ReplicatedStorage:WaitForChild("Library")
local Network = require(Lib.Client.Network)
local Save = require(Lib.Client.Save)
local ZoneCmds = require(Lib.Client.ZoneCmds)
local EggCmds = require(Lib.Client.EggCmds)
local RankCmds = require(Lib.Client.RankCmds)
local PlayerPet = require(Lib.Client.PlayerPet)
local InstancingCmds = require(Lib.Client.InstancingCmds)
local UltimateCmds = require(Lib.Client.UltimateCmds)
local NotificationCmds = require(Lib.Client.NotificationCmds)
local FruitCmds = require(Lib.Client.FruitCmds)
local DaycareCmds = require(Lib.Client.DaycareCmds)
local InventorySelect = require(Lib.Client.UI.InventorySelect)
local WorldsUtil = require(Lib.Util.WorldsUtil)
local EggsDirectory = require(Lib.Directory.Eggs)
local FreeGiftsDirectory = require(Lib.Directory.FreeGifts)
local RanksDirectory = require(Lib.Directory.Ranks)

local Items = require(Lib.Items)
local LootboxCmds = require(Lib.Client.LootboxCmds)

local THINGS = Workspace:WaitForChild("__THINGS")
local DEBRIS_FOLDER = Workspace:WaitForChild("__DEBRIS")

local EggFrontend = nil
pcall(function() EggFrontend = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"]) end)
local OriginalPlayEggAnimation = EggFrontend and EggFrontend.PlayEggAnimation or nil

local OriginalPetSpeed = PlayerPet.CalculateSpeedMultiplier
local OriginalSetTarget = PlayerPet.SetTarget

-- ==============================================================
-- 💾 HỆ THỐNG LƯU CONFIG
-- ==============================================================
local configFileName = "PoodleHub.json"

local defaultToggles = {
    FastFarm = false, AutoTimeTrial = false, AutoUnlock = false, BestZone = false, AutoLoot = false,
    AutoHatch = false, HideEgg = false, HookEgg = false, AutoGold = false, AutoRainbow = false,
    AutoFruit = false, AutoCombine = false, AutoFlag = false, AutoUltimate = false, AutoMisc = false, ClaimRank = false,
    Blackout = false, AntiAFK = false, AutoOpenLootbox = false, AutoOpenGift = false,
    OptimizeBreakables = false, OptimizePets = false, AutoSpinWheel = false, AutoCombineKeys = false,
    AutoDaycare = false, AutoFuse = false
}

local savedConfig = { Toggles = {}, Dropdowns = { SelectedLootbox = "None", SelectedGift = "None", SelectedFlag = "None", SelectedWheel = "No Wheel Tickets Found", SelectedKey = "All" } }

for k, v in pairs(defaultToggles) do savedConfig.Toggles[k] = v end

if isfile and isfile(configFileName) and readfile then
    pcall(function()
        local parsed = HttpService:JSONDecode(readfile(configFileName))
        if parsed then
            if parsed.Toggles then for k,v in pairs(parsed.Toggles) do savedConfig.Toggles[k] = v end end
            if parsed.Dropdowns then for k,v in pairs(parsed.Dropdowns) do savedConfig.Dropdowns[k] = v end end
        end
    end)
end

local function SaveCurrentConfig()
    local dataToSave = {
        Toggles = getgenv().v_settings.functionToggles,
        Dropdowns = {
            SelectedLootbox = getgenv().v_settings.functionToggles.SelectedLootbox or "None",
            SelectedGift = getgenv().v_settings.functionToggles.SelectedGift or "None",
            SelectedFlag = getgenv().v_settings.functionToggles.SelectedFlag or "None",
            SelectedWheel = getgenv().v_settings.functionToggles.SelectedWheel or "No Wheel Tickets Found",
            SelectedKey = getgenv().v_settings.functionToggles.SelectedKey or "All"
        }
    }
    if writefile then pcall(function() writefile(configFileName, HttpService:JSONEncode(dataToSave)) end) end
end

-- ==============================================================
-- 🛠️ HÀM TỐI ƯU HÓA ĐỆ QUY
-- ==============================================================
local function OptimizeVisual(child)
    task.spawn(function()
        task.wait(0.05)
        pcall(function()
            for _, v in ipairs(child:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.Transparency = 1
                    v.CanCollide = false
                    v.CastShadow = false
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Fire") or v:IsA("Smoke") then
                    v.Enabled = false
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    v.Transparency = 1
                end
            end
        end)
    end)
end

-- ==============================================================
-- 🔍 INVENTORY SCANNERS
-- ==============================================================
local function GetAvailableFlags()
    local flags = {}
    local inv = Save.Get().Inventory.Misc or {}
    for uid, item in pairs(inv) do if item.id and item.id:match("Flag") and not table.find(flags, item.id) then table.insert(flags, item.id) end end
    return #flags > 0 and flags or {"No Flags Found"}
end

local function GetAvailableLootboxes()
    local list = {}
    local inv = Save.Get().Inventory.Lootbox or {}
    for _, item in pairs(inv) do if item.id and not item.id:match("Gift") and not item.id:match("Bundle") and not item.id:match("Bag") then if not table.find(list, item.id) then table.insert(list, item.id) end end end
    return #list > 0 and list or {"No Lootboxes Found"}
end

local function GetAvailableGifts()
    local list = {}
    local invL = Save.Get().Inventory.Lootbox or {}
    local invM = Save.Get().Inventory.Misc or {}
    local function Scan(inventory) for _, item in pairs(inventory) do if item.id and (item.id:match("Gift") or item.id:match("Bundle") or item.id:match("Bag") or item.id:match("Present")) then if not table.find(list, item.id) then table.insert(list, item.id) end end end end
    Scan(invL)
    Scan(invM)
    return #list > 0 and list or {"No Gifts/Bundles Found"}
end

local function GetAvailableWheels()
    local list = {}
    local inv = Save.Get().Inventory.Misc or {}
    for _, item in pairs(inv) do
        if item.id and type(item.id) == "string" and item.id:match("Wheel Ticket") then
            if not table.find(list, item.id) then table.insert(list, item.id) end
        end
    end
    return #list > 0 and list or {"No Wheel Tickets Found"}
end

local function GetAvailableKeys()
    local list = {"All"}
    local inv = Save.Get().Inventory.Misc or {}
    for _, item in pairs(inv) do
        if item.id and type(item.id) == "string" and item.id:match("Half") then
            local baseName = item.id:gsub(" Lower Half", ""):gsub(" Upper Half", "")
            if not table.find(list, baseName) then table.insert(list, baseName) end
        end
    end
    return #list > 1 and list or {"No Keys Found"}
end

local function GetKeyCraftAmount(baseKeyName)
    local inv = Save.Get().Inventory.Misc or {}
    local lowerCount = 0
    local upperCount = 0
    for _, item in pairs(inv) do
        if item.id == baseKeyName .. " Lower Half" then
            lowerCount = lowerCount + (item._am or 1)
        elseif item.id == baseKeyName .. " Upper Half" then
            upperCount = upperCount + (item._am or 1)
        end
    end
    return math.min(lowerCount, upperCount)
end

-- ==============================================================
-- 🏫 HỆ THỐNG LOGIC DAYCARE CORE
-- ==============================================================
local function FakeMachineInteraction()
    pcall(function()
        Network.Fire("Machines: Mark Approached", "SuperMachine")
        task.wait(0.1)
        Network.Fire("EventLog_Once", "OpenTab", "SuperMachine")
        task.wait(0.1)
        Network.Fire("EventLog_Once", "CloseTab", "SuperMachine")
        task.wait(0.1)
        Network.Fire("EventLog_Once", "OpenTab", "DaycareMachine")
        task.wait(0.2)
    end)
end

local function CloseFakeMachine()
    pcall(function()
        Network.Fire("EventLog_Once", "CloseTab", "DaycareMachine")
    end)
end

local function ClaimAllReadyPets()
    local data = Save.Get()
    if not data then return end
    
    local daycareActive = data.DaycareActive or {}
    local hasPets = false
    for _, _ in pairs(daycareActive) do 
        hasPets = true 
        break 
    end

    if hasPets then
        pcall(function()
            FakeMachineInteraction()
            Network.Invoke("Daycare: Claim")
            CloseFakeMachine()
        end)
    end
end

local function EnrollBestPets()
    local data = Save.Get()
    if not data then return end
    
    local maxSlots = DaycareCmds.GetMaxSlots()
    local usedSlots = DaycareCmds.GetUsedSlots()
    local freeSlots = maxSlots - usedSlots

    if freeSlots <= 0 then return end

    local invPets = data.Inventory.Pet or {}
    local equippedPets = {}
    pcall(function()
        local savedEquip = data.EquippedPets or {}
        for _, uid in ipairs(savedEquip) do equippedPets[uid] = true end
    end)
    
    local validPetsList = {}
    for uid, pet in pairs(invPets) do
        if not equippedPets[uid] and not pet.id:match("Huge") and not pet.id:match("Titanic") and not pet.l then
            local score = 0
            local hasRealMultiplier = false
            
            pcall(function()
                local petObj = require(Lib.Directory.Pets)(pet.id)
                local _, lootMultiplier = require(Lib.Balancing.DaycareLoot).ComputePetLootPool(game.Players.LocalPlayer, petObj)
                if lootMultiplier then
                    score = lootMultiplier
                    hasRealMultiplier = true
                end
            end)
            
            if not hasRealMultiplier then
                local rarityBonus = (pet.pt == 2 and 50) or (pet.pt == 1 and 20) or 0
                local shinyBonus = pet.sh and 30 or 0
                score = rarityBonus + shinyBonus + (pet.dmg or 0)
            end
            
            table.insert(validPetsList, { uid = uid, amount = pet._am or 1, score = score })
        end
    end

    table.sort(validPetsList, function(a, b) return a.score > b.score end)

    local petsToEnroll = {}
    local slotsFilled = 0

    for _, petData in ipairs(validPetsList) do
        if slotsFilled >= freeSlots then break end
        local takeAmount = math.min(petData.amount, freeSlots - slotsFilled)
        if takeAmount > 0 then
            petsToEnroll[petData.uid] = takeAmount
            slotsFilled = slotsFilled + takeAmount
        end
    end

    if slotsFilled > 0 then
        pcall(function()
            FakeMachineInteraction()
            Network.Invoke("Daycare: Enroll", petsToEnroll)
            CloseFakeMachine()
        end)
    end
end

-- ==============================================================
-- ⚙️ GLOBAL SETTINGS & FUNCTIONS
-- ==============================================================
getgenv().v_settings = {
    functionToggles = savedConfig.Toggles,
    SelectedPetsForFuse = {},
    OptimizeBreakablesConn = nil,
    functions = {
        OptimizePets = function()
            pcall(function()
                PlayerPet.CalculateSpeedMultiplier = function() return math.huge end
                if PlayerPet.SetTarget then PlayerPet.SetTarget = function() return end end
                for _, pet in pairs(PlayerPet.GetAll()) do
                    if pet.owner == LocalPlayer then pet.target = nil end
                end
            end)
        end,

        BuyPetSlots = function() local purchased = Save.Get().PetSlotsPurchased; Network.Invoke("PetSlots_RequestPurchase", purchased + 1) end,
        BuyEggSlots = function() local purchased = Save.Get().EggSlotsPurchased; Network.Invoke("EggSlots_RequestPurchase", purchased + 1) end,

        AutoHatch = function()
            local mz = ZoneCmds.GetMaximumOverallZone()
            if not mz then return end
            local be = nil
            for _,e in pairs(EggsDirectory) do if e.eggNumber == mz.MaximumAvailableEgg then be = e._id break end end
            if be then Network.Invoke('Eggs_RequestPurchase', be, EggCmds.GetMaxHatch()) end
        end,
        
        HandleEggAnimation = function()
            if not EggFrontend then return end
            if getgenv().v_settings.functionToggles.HideEgg then EggFrontend.PlayEggAnimation = function() end
            elseif getgenv().v_settings.functionToggles.HookEgg then EggFrontend.PlayEggAnimation = function(en) NotificationCmds.Message.Bottom({Message="Still Openin "..tostring(en).." x"..tostring(EggCmds.GetMaxHatch()), Color=Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))}) end
            else EggFrontend.PlayEggAnimation = OriginalPlayEggAnimation end
        end,

        AutoFruit = function()
            local sv = Save.Get()
            if not sv or not sv.Inventory.Fruit then return end
            local ts = 20
            pcall(function() local ml=FruitCmds.ComputeFruitQueueLimit(); if ml>0 then ts=ml end end)
            local bf = {}
            for u,d in pairs(sv.Inventory.Fruit) do if d.id and d.id~="Candycane" then local bi=d.id; if not bf[bi] then bf[bi]=u else local cd=sv.Inventory.Fruit[bf[bi]] if d.sh and not cd.sh then bf[bi]=u elseif d.sh==cd.sh and (d._am or 1)>(cd._am or 1) then bf[bi]=u end end end end
            local af = {}
            pcall(function() af=FruitCmds.GetActiveFruits() end)
            for fn,u in pairs(bf) do local c=0; local d=af and af[fn] if type(d)=="table" then if type(d.Normal)=="table" then for _ in pairs(d.Normal) do c=c+1 end end if type(d.Shiny)=="table" then for _ in pairs(d.Shiny) do c=c+1 end end end if c<ts then local ca=math.min(ts-c, sv.Inventory.Fruit[u]._am or 1) if ca>0 then pcall(function() Network.Fire("Fruits: Consume",u,ca) end); task.wait(0.2) end end end
        end,

        FastFarm = function()
            if InstancingCmds.GetInstanceID()=="TimeTrial" then return end
            local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not r then return end
            local t={}
            for _,b in ipairs(THINGS.Breakables:GetChildren()) do if b:IsA("Model") and b.PrimaryPart and (b.PrimaryPart.Position-r.Position).Magnitude<100 then table.insert(t,b.Name); if #t>=25 then break end end end
            if #t>0 then for i=1,math.min(#t,8) do Network.UnreliableFire("Breakables_PlayerDealDamage",t[i]) end local m={} for e,p in pairs(PlayerPet.GetAll()) do if p.owner==LocalPlayer then table.insert(m,e) end end if #m>0 then local bk={} for i=1,#m do bk[m[i]]=t[((i-1)%#t)+1] end; Network.Fire("Breakables_JoinPetBulk",bk) end end
        end,
        
        AutoTimeTrial = function()
            if InstancingCmds.GetInstanceID() ~= "TimeTrial" then InstancingCmds.Enter("TimeTrial") else
                local tiles = {Vector3.new(-18358.97,16.49,-557.41), Vector3.new(-18302.69,16.49,-699.98), Vector3.new(-18219.80,16.49,-601.27), Vector3.new(-18213.07,16.49,-453.58), Vector3.new(-18081.36,16.49,-482.34)}
                local boss = Vector3.new(-18097.52,16.49,-659.96)
                local hrp = LocalPlayer.Character.HumanoidRootPart
                local cTile = 1
                for i, pos in ipairs(tiles) do local c = 0; for _, b in ipairs(THINGS.Breakables:GetChildren()) do if b.PrimaryPart and (b.PrimaryPart.Position - pos).Magnitude <= 70 then c = c + 1 end end if c > 0 then cTile = i; break end end
                if cTile <= #tiles then hrp.CFrame = CFrame.new(tiles[cTile]) + Vector3.new(0,3,0) else hrp.CFrame = CFrame.new(boss) + Vector3.new(0,3,0) end
            end
        end,
        
        AutoUnlock = function() local nx, _ = ZoneCmds.GetNextZone(); if nx then Network.Invoke("Zones_RequestPurchase", nx) end end,
        
        BestZone = function()
            local _, mx = ZoneCmds.GetMaxOwnedZone()
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not mx or not hrp then return end
            local currentWorld = WorldsUtil.GetWorld()
            if mx.WorldNumber and currentWorld and mx.WorldNumber ~= currentWorld.WorldNumber then
                pcall(function() Network.Invoke("World" .. mx.WorldNumber .. "Teleport") end)
                task.wait(4)
                return
            end
            local zf = mx.ZoneFolder; local tp = nil
            if zf and zf:FindFirstChild("INTERACT") and zf.INTERACT:FindFirstChild("BREAKABLE_SPAWNS") then
                local ms = zf.INTERACT.BREAKABLE_SPAWNS:FindFirstChild("Main") or zf.INTERACT.BREAKABLE_SPAWNS:GetChildren()[1]
                if ms then tp = ms.CFrame end
            end
            if not tp and zf and zf:FindFirstChild("PERSISTENT") then tp = zf.PERSISTENT.Teleport.CFrame end
            if tp and (hrp.Position - tp.Position).Magnitude > 20 then hrp.CFrame = tp + Vector3.new(0, 3, 0) end
        end,

        AutoLoot = function()
            local bags = {}
            for _,v in ipairs(THINGS.Lootbags:GetChildren()) do table.insert(bags, v.Name); v:Destroy() end
            if #bags > 0 then Network.Fire("Lootbags_Claim", bags) end
            for _,v in ipairs(THINGS.Orbs:GetChildren()) do Network.Fire("Orbs: Collect", {tonumber(v.Name)}); v:Destroy() end
        end,
        
        AutoGold = function() local inv = Save.Get().Inventory.Pet or {}; for u, d in pairs(inv) do if not d.pt and (d._am or 1) >= 10 then Network.Invoke("GoldMachine_Activate", u, 1); break end end end,
        AutoRainbow = function() local inv = Save.Get().Inventory.Pet or {}; for u, d in pairs(inv) do if d.pt == 1 and (d._am or 1) >= 10 then Network.Invoke("RainbowMachine_Activate", u, 1); break end end end,
        AutoCombine = function() local inv = Save.Get().Inventory.Lootboxes; if not inv then return end local pt = {"Small Fantasy Present", "Medium Fantasy Present", "Large Fantasy Present", "X-Large Fantasy Present"} for t = 1, 4 do for u, d in pairs(inv) do if d.id == pt[t] and (d._am or 1) >= 10 then Network.Invoke("FantasyCombineOMatic_Activate", u, math.floor(d._am/10)) end end end end,
        AutoFlag = function() local sf=getgenv().v_settings.functionToggles.SelectedFlag; if not sf or sf=="None" then return end local i=Save.Get().Inventory.Misc or {}; for u,it in pairs(i) do if it.id==sf then require(Lib.Client.FlexibleFlagCmds).Consume(it.id,u,1); break end end end,
        AutoUltimate = function() local u = UltimateCmds.GetEquippedItem(); if u and u._data and u._data.id then UltimateCmds.Activate(u._data.id) end end,
        AutoMisc = function() Network.Invoke('Mailbox: Claim All'); local red = Save.Get().FreeGiftsRedeemed or {}; local cT = Save.Get().FreeGiftsTime or 0; for _, g in pairs(FreeGiftsDirectory) do if g.WaitTime <= cT and not table.find(red, g._id) then Network.Invoke('Redeem Free Gift', g._id); break end end end,
        ClaimRank = function() local s = Save.Get(); local rw = RanksDirectory[RankCmds.GetTitle()].Rewards; local ts = 0; for i, v in pairs(rw) do ts = ts + v.StarsRequired; if s.RankStars >= ts and not s.RedeemedRankRewards[tostring(i)] then Network.Fire("Ranks_ClaimReward", i) end end end,
        Blackout = function() game:GetService("Lighting").GlobalShadows = false; for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("BasePart") and not v:IsDescendantOf(THINGS) then v.Material = Enum.Material.Plastic; v.CastShadow = false end end end,
        AntiAFK = function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end
    }
}

getgenv().v_settings.functionToggles.SelectedLootbox = savedConfig.Dropdowns.SelectedLootbox
getgenv().v_settings.functionToggles.SelectedGift = savedConfig.Dropdowns.SelectedGift
getgenv().v_settings.functionToggles.SelectedFlag = savedConfig.Dropdowns.SelectedFlag
getgenv().v_settings.functionToggles.SelectedWheel = savedConfig.Dropdowns.SelectedWheel or "No Wheel Tickets Found"
getgenv().v_settings.functionToggles.SelectedKey = savedConfig.Dropdowns.SelectedKey or "All"

-- ==============================================================
-- 🔄 KHỞI CHẠY VÒNG LẶP CHẠY NGẦM
-- ==============================================================
local LoopsToStart = {
    {Flag = "AutoTimeTrial", Func = getgenv().v_settings.functions.AutoTimeTrial, Wait = 1},
    {Flag = "AutoUnlock", Func = getgenv().v_settings.functions.AutoUnlock, Wait = 2},
    {Flag = "BestZone", Func = getgenv().v_settings.functions.BestZone, Wait = 2},
    {Flag = "AutoLoot", Func = getgenv().v_settings.functions.AutoLoot, Wait = 0.5},
    {Flag = "AutoHatch", Func = getgenv().v_settings.functions.AutoHatch, Wait = 2.5},
    {Flag = "AutoGold", Func = getgenv().v_settings.functions.AutoGold, Wait = 5},
    {Flag = "AutoRainbow", Func = getgenv().v_settings.functions.AutoRainbow, Wait = 5},
    {Flag = "AutoFruit", Func = getgenv().v_settings.functions.AutoFruit, Wait = 5},
    {Flag = "AutoCombine", Func = getgenv().v_settings.functions.AutoCombine, Wait = 3},
    {Flag = "AutoFlag", Func = getgenv().v_settings.functions.AutoFlag, Wait = 5},
    {Flag = "AutoUltimate", Func = getgenv().v_settings.functions.AutoUltimate, Wait = 1},
    {Flag = "AutoMisc", Func = getgenv().v_settings.functions.AutoMisc, Wait = 15},
    {Flag = "ClaimRank", Func = getgenv().v_settings.functions.ClaimRank, Wait = 5},
    {Flag = "Blackout", Func = getgenv().v_settings.functions.Blackout, Wait = 10},
    {Flag = "AntiAFK", Func = getgenv().v_settings.functions.AntiAFK, Wait = 60},
    {Flag = "OptimizePets", Func = getgenv().v_settings.functions.OptimizePets, Wait = 0.5}
}

for _, lData in ipairs(LoopsToStart) do
    task.spawn(function()
        while task.wait(lData.Wait) do
            if getgenv().v_settings.functionToggles[lData.Flag] then pcall(lData.Func) end
        end
    end)
end

-- Khởi động VRT Optimize Breakables
if getgenv().v_settings.functionToggles.OptimizeBreakables then
    getgenv().v_settings.OptimizeBreakablesConn = DEBRIS_FOLDER.ChildAdded:Connect(OptimizeVisual)
end

-- Vòng lặp FastFarm
local lastFastFarm = 0
RunService.Heartbeat:Connect(function()
    if getgenv().v_settings.functionToggles.FastFarm then
        local now = os.clock()
        if now - lastFastFarm > 0.15 then
            lastFastFarm = now
            pcall(getgenv().v_settings.functions.FastFarm)
        end
    end
end)

-- Vòng lặp Mở Hộp
task.spawn(function()
    while task.wait(1.5) do
        if getgenv().v_settings.functionToggles.AutoOpenLootbox then
            local sL = getgenv().v_settings.functionToggles.SelectedLootbox
            if sL ~= "None" and sL ~= "No Lootboxes Found" then
                local i=Save.Get().Inventory.Lootbox; local tU,tA=nil,0
                for u,it in pairs(i) do if it.id==sL then tU=u; tA=it._am or 1; break end end
                if tU then pcall(function() local am=math.min(tA,8); local bO=Items.Lootbox(sL); bO._uid=tU; LootboxCmds.Open(bO,am) end) 
                else getgenv().v_settings.functionToggles.AutoOpenLootbox=false end
            end
        end
    end
end)

-- Vòng lặp mở Quà
task.spawn(function()
    while task.wait(1.5) do
        if getgenv().v_settings.functionToggles.AutoOpenGift then
            local sG = getgenv().v_settings.functionToggles.SelectedGift
            if sG ~= "None" and sG ~= "No Gifts/Bundles Found" then
                local iL=Save.Get().Inventory.Lootbox; local iM=Save.Get().Inventory.Misc; local tU,tA=nil,0
                for u,it in pairs(iL) do if it.id==sG then tU=u; tA=it._am or 1; break end end
                if not tU then for u,it in pairs(iM) do if it.id==sG then tU=u; tA=it._am or 1; break end end end
                if tU then pcall(function() Network.Invoke("GiftBag_Open",sG,math.min(tA,100)) end) 
                else getgenv().v_settings.functionToggles.AutoOpenGift=false end
            end
        end
    end
end)

-- Vòng lặp Spin Wheel
local WheelMap = { ["Spinny Wheel Ticket"] = "StarterWheel", ["Tech Spinny Wheel Ticket"] = "TechWheel", ["Void Spinny Wheel Ticket"] = "VoidWheel" }
task.spawn(function()
    while task.wait(3) do
        if getgenv().v_settings.functionToggles.AutoSpinWheel then
            local sW = getgenv().v_settings.functionToggles.SelectedWheel
            if sW and sW ~= "No Wheel Tickets Found" then
                local wheelID = WheelMap[sW] or "StarterWheel"
                pcall(function() Network.Invoke("Spinny Wheel: Request Spin", wheelID) end)
            end
        end
    end
end)

-- Vòng lặp Combine Key
task.spawn(function()
    while task.wait(0.5) do
        if getgenv().v_settings.functionToggles.AutoCombineKeys then
            local sK = getgenv().v_settings.functionToggles.SelectedKey
            if sK and sK ~= "No Keys Found" then
                local keysToProcess = {}
                if sK == "All" then
                    local availKeys = GetAvailableKeys()
                    for _, k in ipairs(availKeys) do if k ~= "All" and k ~= "No Keys Found" then table.insert(keysToProcess, k) end end
                else
                    table.insert(keysToProcess, sK)
                end
                for _, keyName in ipairs(keysToProcess) do
                    local craftAmount = GetKeyCraftAmount(keyName)
                    if craftAmount > 0 then
                        local remoteName = keyName:gsub(" ", "") .. "_Combine"
                        local loops = math.min(craftAmount, 25) 
                        for i = 1, loops do pcall(function() Network.Invoke(remoteName, 1) end) end
                    end
                end
            end
        end
    end
end)

-- Vòng lặp Auto Daycare Ngầm
task.spawn(function()
    while task.wait(5) do
        if getgenv().v_settings.functionToggles.AutoDaycare then
            pcall(ClaimAllReadyPets)
            task.wait(1)
            pcall(EnrollBestPets)
        end
    end
end)

if getgenv().v_settings.functionToggles.HideEgg or getgenv().v_settings.functionToggles.HookEgg then
    pcall(getgenv().v_settings.functions.HandleEggAnimation)
end
-- ==============================================================
-- 🎨 CASSERUS UI SETUP - PHIÊN BẢN MOBILE (TỰ ĐỘNG CO GIÃN)
-- ==============================================================
local Casserus = loadstring(game:HttpGet("https://raw.githubusercontent.com/vaxtalastus-web/Casserus-UI-Library-RBX/refs/heads/main/source.lua"))()
local Window = Casserus:CreateWindow("Poodle Hub V3")

-- Chờ UI được tạo, sau đó tự động điều chỉnh kích thước vừa màn hình
task.wait(0.2)
local screenGui = game:GetService("CoreGui"):FindFirstChild("UILibWindow")
if screenGui then
    local mainFrame = screenGui:FindFirstChild("MainFrame")
    if mainFrame then
        local viewportSize = workspace.CurrentCamera.ViewportSize
        local desiredWidth = viewportSize.X * 0.9
        local desiredHeight = viewportSize.Y * 0.8
        mainFrame.Size = UDim2.new(0, desiredWidth, 0, desiredHeight)
        mainFrame.Position = UDim2.new(0.5, -desiredWidth/2, 0.5, -desiredHeight/2)
        
        -- Điều chỉnh kích thước các thành phần bên trong cho phù hợp
        local topBar = mainFrame:FindFirstChild("TopBar")
        if topBar then topBar.Size = UDim2.new(1, 0, 0, 50) end -- giảm chiều cao topbar
        
        local tabContainer = mainFrame:FindFirstChild("TabContainer")
        if tabContainer then
            tabContainer.Size = UDim2.new(0, 150, 1, -50) -- thu hẹp tab container
            for _, btn in ipairs(tabContainer:GetChildren()) do
                if btn:IsA("TextButton") then
                    btn.Size = UDim2.new(1, -10, 0, 40)
                    btn.TextSize = 14
                end
            end
        end
        
        local contentFrame = mainFrame:FindFirstChild("ContentFrame")
        if contentFrame then
            contentFrame.Position = UDim2.new(0, 160, 0, 60)
            contentFrame.Size = UDim2.new(1, -170, 1, -70)
        end
    end
end

-- Hàm tạo Section (chỉ là một label, nhưng với font nhỏ hơn)
local function CreateSection(tab, text)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 25)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = #tab.Page:GetChildren()
    local label = Instance.new("TextLabel")
    label.Text = text
    label.TextColor3 = Color3.fromRGB(0, 200, 255)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Parent = frame
    frame.Parent = tab.Page
    return frame
end

-- Hàm tạo Label thường (font nhỏ)
local function CreateLabel(tab, text)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 20)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = #tab.Page:GetChildren()
    local label = Instance.new("TextLabel")
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Parent = frame
    frame.Parent = tab.Page
    return frame
end

-- Hàm tạo Paragraph (co giãn theo mobile)
local function CreateParagraph(tab, title, initialContent)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 120)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = #tab.Page:GetChildren()
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -15, 0, 25)
    titleLabel.Position = UDim2.new(0, 8, 0, 5)
    titleLabel.Parent = frame
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -15, 1, -40)
    scroll.Position = UDim2.new(0, 8, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.Parent = frame
    
    local contentLabel = Instance.new("TextLabel")
    contentLabel.Text = initialContent
    contentLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    contentLabel.TextSize = 12
    contentLabel.Font = Enum.Font.Gotham
    contentLabel.BackgroundTransparency = 1
    contentLabel.Size = UDim2.new(1, 0, 1, 0)
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.TextYAlignment = Enum.TextYAlignment.Top
    contentLabel.TextWrapped = true
    contentLabel.Parent = scroll
    
    scroll.CanvasSize = UDim2.new(0, 0, 0, contentLabel.TextBounds.Y + 10)
    
    frame.Parent = tab.Page
    
    local function updateContent(newContent)
        contentLabel.Text = newContent
        scroll.CanvasSize = UDim2.new(0, 0, 0, contentLabel.TextBounds.Y + 10)
    end
    
    return { Set = function(_, data) updateContent(data.Content) end }
end

-- Hàm tạo Dropdown tùy chỉnh (gọn nhẹ cho mobile)
local function CreateDropdown(tab, name, optionsList, defaultOption, callback)
    local currentOption = defaultOption
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 60)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = #tab.Page:GetChildren()
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    
    local label = Instance.new("TextLabel")
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -15, 0, 25)
    label.Position = UDim2.new(0, 8, 0, 5)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -15, 0, 28)
    button.Position = UDim2.new(0, 8, 0, 30)
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.BorderSizePixel = 0
    button.Text = currentOption
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
    button.Parent = frame
    
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Size = UDim2.new(1, -15, 0, 0)
    dropdownFrame.Position = UDim2.new(0, 8, 0, 58)
    dropdownFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    dropdownFrame.BorderSizePixel = 0
    dropdownFrame.ClipsDescendants = true
    dropdownFrame.Visible = false
    Instance.new("UICorner", dropdownFrame).CornerRadius = UDim.new(0, 6)
    dropdownFrame.Parent = frame
    
    local listLayout = Instance.new("UIListLayout", dropdownFrame)
    listLayout.Padding = UDim.new(0, 2)
    
    local function refreshDropdown()
        for _, child in ipairs(dropdownFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, opt in ipairs(optionsList) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 28)
            optBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            optBtn.BorderSizePixel = 0
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 12
            Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 5)
            optBtn.Parent = dropdownFrame
            optBtn.MouseButton1Click:Connect(function()
                currentOption = opt
                button.Text = currentOption
                dropdownFrame.Visible = false
                frame.Size = UDim2.new(1, -10, 0, 60)
                pcall(callback, currentOption)
            end)
        end
        dropdownFrame.Size = UDim2.new(1, -15, 0, #optionsList * 30)
    end
    
    button.MouseButton1Click:Connect(function()
        dropdownFrame.Visible = not dropdownFrame.Visible
        if dropdownFrame.Visible then
            frame.Size = UDim2.new(1, -10, 0, 60 + dropdownFrame.Size.Y.Offset)
        else
            frame.Size = UDim2.new(1, -10, 0, 60)
        end
    end)
    
    frame.Parent = tab.Page
    refreshDropdown()
    
    return {
        Refresh = function(_, newOptions)
            optionsList = newOptions
            currentOption = optionsList[1] or "None"
            button.Text = currentOption
            pcall(callback, currentOption)
            refreshDropdown()
        end,
        SetOptions = function(_, newOptions)
            optionsList = newOptions
            currentOption = optionsList[1] or "None"
            button.Text = currentOption
            pcall(callback, currentOption)
            refreshDropdown()
        end
    }
end

-- ==============================================================
-- ⚔️ Tab 1: Main Farm (giữ nguyên logic, chỉ thay đổi tạo UI)
-- ==============================================================
local TabFarm = Window:CreateTab("Main")
CreateSection(TabFarm, "Farming Controls")
TabFarm:CreateToggle("Fast Farm", function(state) getgenv().v_settings.functionToggles.FastFarm = state end)
TabFarm:CreateToggle("Auto Time Trial", function(state) getgenv().v_settings.functionToggles.AutoTimeTrial = state end)
TabFarm:CreateToggle("Auto Unlock Zone", function(state) getgenv().v_settings.functionToggles.AutoUnlock = state end)
TabFarm:CreateToggle("Go To Best Zone", function(state) getgenv().v_settings.functionToggles.BestZone = state end)
TabFarm:CreateToggle("Auto Loot", function(state) getgenv().v_settings.functionToggles.AutoLoot = state end)

CreateSection(TabFarm, "Optimization")
TabFarm:CreateToggle("Optimize Breakables", function(state)
    getgenv().v_settings.functionToggles.OptimizeBreakables = state
    if state then
        if not getgenv().v_settings.OptimizeBreakablesConn then
            getgenv().v_settings.OptimizeBreakablesConn = DEBRIS_FOLDER.ChildAdded:Connect(OptimizeVisual)
            for _, v in pairs(DEBRIS_FOLDER:GetChildren()) do OptimizeVisual(v) end
        end
    else
        if getgenv().v_settings.OptimizeBreakablesConn then
            getgenv().v_settings.OptimizeBreakablesConn:Disconnect()
            getgenv().v_settings.OptimizeBreakablesConn = nil
        end
    end
end)
TabFarm:CreateToggle("Optimize Pets", function(state)
    getgenv().v_settings.functionToggles.OptimizePets = state
    if not state then
        pcall(function()
            PlayerPet.CalculateSpeedMultiplier = OriginalPetSpeed
            if OriginalSetTarget then PlayerPet.SetTarget = OriginalSetTarget end
        end)
    end
end)

CreateSection(TabFarm, "Auto Rewards")
TabFarm:CreateToggle("Auto Ultimate", function(state) getgenv().v_settings.functionToggles.AutoUltimate = state end)
TabFarm:CreateToggle("Auto Gifts & Mail", function(state) getgenv().v_settings.functionToggles.AutoMisc = state end)
TabFarm:CreateToggle("Auto Rank Rewards", function(state) getgenv().v_settings.functionToggles.ClaimRank = state end)

-- ==============================================================
-- 🐾 Tab 2: Pets & Eggs
-- ==============================================================
local TabPet = Window:CreateTab("Pets/Eggs")
CreateSection(TabPet, "Hatching & Crafting")
TabPet:CreateToggle("Auto Hatch", function(state) getgenv().v_settings.functionToggles.AutoHatch = state end)
TabPet:CreateToggle("Hide Egg Anim", function(state)
    getgenv().v_settings.functionToggles.HideEgg = state
    pcall(getgenv().v_settings.functions.HandleEggAnimation)
end)
TabPet:CreateToggle("Hook Egg Anim", function(state)
    getgenv().v_settings.functionToggles.HookEgg = state
    pcall(getgenv().v_settings.functions.HandleEggAnimation)
end)
TabPet:CreateToggle("Auto Gold Pet", function(state) getgenv().v_settings.functionToggles.AutoGold = state end)
TabPet:CreateToggle("Auto Rainbow Pet", function(state) getgenv().v_settings.functionToggles.AutoRainbow = state end)

CreateSection(TabPet, "Slots")
TabPet:CreateButton("Buy Pet Slot", function() getgenv().v_settings.functions.BuyPetSlots() end)
TabPet:CreateButton("Buy Egg Slot", function() getgenv().v_settings.functions.BuyEggSlots() end)

-- ==============================================================
-- 📦 Tab 3: Open Lootboxes
-- ==============================================================
local TabOpen = Window:CreateTab("Open")
CreateSection(TabOpen, "Lootboxes")
local DL = CreateDropdown(TabOpen, "Select Lootbox", {"Loading..."}, getgenv().v_settings.functionToggles.SelectedLootbox, function(opt) getgenv().v_settings.functionToggles.SelectedLootbox = opt end)
TabOpen:CreateToggle("Auto Open Lootbox", function(state) getgenv().v_settings.functionToggles.AutoOpenLootbox = state end)

CreateSection(TabOpen, "GiftBags")
local DG = CreateDropdown(TabOpen, "Select Gift", {"Loading..."}, getgenv().v_settings.functionToggles.SelectedGift, function(opt) getgenv().v_settings.functionToggles.SelectedGift = opt end)
TabOpen:CreateToggle("Auto Open Gift", function(state) getgenv().v_settings.functionToggles.AutoOpenGift = state end)

CreateSection(TabOpen, "Wheels")
local DW = CreateDropdown(TabOpen, "Select Wheel", {"Loading..."}, getgenv().v_settings.functionToggles.SelectedWheel, function(opt) getgenv().v_settings.functionToggles.SelectedWheel = opt end)
TabOpen:CreateToggle("Auto Spin", function(state) getgenv().v_settings.functionToggles.AutoSpinWheel = state end)

TabOpen:CreateButton("Refresh Lists", function()
    pcall(function() DL:Refresh(GetAvailableLootboxes()) end)
    pcall(function() DG:Refresh(GetAvailableGifts()) end)
    pcall(function() DW:Refresh(GetAvailableWheels()) end)
end)

CreateSection(TabOpen, "Combine Keys")
local DK = CreateDropdown(TabOpen, "Select Key", {"Loading..."}, getgenv().v_settings.functionToggles.SelectedKey, function(opt) getgenv().v_settings.functionToggles.SelectedKey = opt end)
TabOpen:CreateToggle("Auto Combine Keys", function(state) getgenv().v_settings.functionToggles.AutoCombineKeys = state end)
TabOpen:CreateButton("Refresh Keys", function() pcall(function() DK:Refresh(GetAvailableKeys()) end) end)

-- ==============================================================
-- 🎒 Tab 4: Items & Events
-- ==============================================================
local TabItem = Window:CreateTab("Items")
CreateSection(TabItem, "Auto Items")
TabItem:CreateToggle("Auto Fruit", function(state) getgenv().v_settings.functionToggles.AutoFruit = state end)
TabItem:CreateToggle("Auto Combine Presents", function(state) getgenv().v_settings.functionToggles.AutoCombine = state end)

CreateSection(TabItem, "Flags")
local DF = CreateDropdown(TabItem, "Select Flag", {"Loading..."}, getgenv().v_settings.functionToggles.SelectedFlag, function(opt) getgenv().v_settings.functionToggles.SelectedFlag = opt end)
TabItem:CreateButton("Refresh Flags", function() pcall(function() DF:Refresh(GetAvailableFlags()) end) end)
TabItem:CreateToggle("Auto Flag", function(state) getgenv().v_settings.functionToggles.AutoFlag = state end)

CreateSection(TabItem, "Daycare")
TabItem:CreateButton("Claim Ready Pets", function() ClaimAllReadyPets() end)
TabItem:CreateButton("Enroll Best Pets", function() EnrollBestPets() end)
TabItem:CreateToggle("Auto Daycare", function(state) getgenv().v_settings.functionToggles.AutoDaycare = state end)

-- ==============================================================
-- 🔥 Tab 5: Auto Fuse
-- ==============================================================
local TabFuse = Window:CreateTab("Fuse")
local fuseParagraph = CreateParagraph(TabFuse, "Selected Pets", "Waiting...")

TabFuse:CreateButton("Select Pets", function()
    getgenv().v_settings.functionToggles.AutoFuse = false
    local config = { SelectionMode = 3, QuantityMode = 1, MaxQuantity = 100, ClassWhitelist = {"Pet"} }
    local success, resultTable = pcall(function() return { InventorySelect.Select(config) } end)
    if success and resultTable then
        local isConfirmed = resultTable[1]
        local selections = resultTable[2]
        if isConfirmed == true and type(selections) == "table" then
            getgenv().v_settings.SelectedPetsForFuse = selections
            local displayString = ""
            local count = 0
            for uid, amount in pairs(selections) do
                local petInfo = Save.Get().Inventory.Pet[uid]
                if petInfo then
                    local pName = petInfo.id
                    local prefix = ""
                    if petInfo.pt == 1 then prefix = "Golden "
                    elseif petInfo.pt == 2 then prefix = "Rainbow " end
                    if petInfo.sh then prefix = "Shiny " .. prefix end
                    displayString = displayString .. "• " .. prefix .. pName .. " x" .. tostring(amount) .. "\n"
                    count = count + 1
                end
            end
            if count > 0 then
                fuseParagraph:Set({ Title = "Selected Pets", Content = displayString })
            else
                fuseParagraph:Set({ Title = "Selected Pets", Content = "No valid pets." })
                getgenv().v_settings.SelectedPetsForFuse = {}
            end
        end
    end
end)

local fuseToggle = nil
fuseToggle = TabFuse:CreateToggle("Auto Fuse", function(state)
    local hasSelection = false
    for _, _ in pairs(getgenv().v_settings.SelectedPetsForFuse) do hasSelection = true break end
    if state and not hasSelection then
        task.spawn(function() task.wait(0.1); if fuseToggle then fuseToggle(false) end end)
        return
    end
    getgenv().v_settings.functionToggles.AutoFuse = state
end)

-- Vòng lặp Fuse (giữ nguyên)
task.spawn(function()
    while task.wait(1.5) do
        if getgenv().v_settings.functionToggles.AutoFuse then
            local payload = {}
            local totalValidPets = 0
            local inventory = Save.Get().Inventory.Pet or {}
            for uid, targetAmount in pairs(getgenv().v_settings.SelectedPetsForFuse) do
                local curInv = inventory[uid]
                if curInv and (curInv._am or 1) > 0 then
                    local take = math.min(curInv._am or 1, targetAmount)
                    payload[uid] = take
                    totalValidPets = totalValidPets + take
                end
            end
            if totalValidPets >= 3 then
                pcall(function() Network.Invoke("FuseMachine_Activate", payload) end)
            else
                getgenv().v_settings.functionToggles.AutoFuse = false
                if fuseToggle then fuseToggle(false) end
            end
        end
    end
end)

-- ==============================================================
-- ⚙️ Tab 6: Settings
-- ==============================================================
local TabSet = Window:CreateTab("Settings")
CreateSection(TabSet, "Config")
TabSet:CreateButton("Save Config", function()
    SaveCurrentConfig()
    print("Saved!")
end)
CreateLabel(TabSet, "Auto-load saved features on start.")

CreateSection(TabSet, "Player")
TabSet:CreateSlider("Walk Speed", 16, 150, 16, function(v)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = v end
end)

local noclipConn = nil
TabSet:CreateToggle("Noclip", function(state)
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    end
end)

CreateSection(TabSet, "System")
TabSet:CreateButton("Rejoin", function()
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)
TabSet:CreateToggle("Blackout", function(state) getgenv().v_settings.functionToggles.Blackout = state end)
TabSet:CreateToggle("Anti-AFK", function(state) getgenv().v_settings.functionToggles.AntiAFK = state end)

-- ==============================================================
-- 🔄 TỰ ĐỘNG REFRESH DROPDOWN
-- ==============================================================
task.delay(2.5, function()
    pcall(function() if DL then DL:Refresh(GetAvailableLootboxes()) end end)
    pcall(function() if DG then DG:Refresh(GetAvailableGifts()) end end)
    pcall(function() if DF then DF:Refresh(GetAvailableFlags()) end end)
    pcall(function() if DK then DK:Refresh(GetAvailableKeys()) end end)
    pcall(function() if DW then DW:Refresh(GetAvailableWheels()) end end)
end)

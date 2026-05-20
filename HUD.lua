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
    SelectedPetsForFuse = {}, -- Bảng lưu trữ riêng cho hệ thống Fuse
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
-- 🎨 ORION UI SETUP 
-- ==============================================================
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/refs/heads/main/source')))()

local Window = OrionLib:MakeWindow({
    Name = "Poodle Main Hub",
    HidePremium = false,
    SaveConfig =  true,
    ConfigFolder = "PoodleHub",
    IntroEnabled = true
})

local function CreateSmartToggle(TabObj, ToggleName, FlagName)
    TabObj:AddToggle({
        Name = ToggleName,
        Default = getgenv().v_settings.functionToggles[FlagName] or false,
        Callback = function(state)
            getgenv().v_settings.functionToggles[FlagName] = state
            if FlagName=="HideEgg" or FlagName=="HookEgg" then pcall(getgenv().v_settings.functions.HandleEggAnimation) end
            if FlagName=="OptimizePets" and not state then
                pcall(function()
                    PlayerPet.CalculateSpeedMultiplier = OriginalPetSpeed
                    if OriginalSetTarget then PlayerPet.SetTarget = OriginalSetTarget end
                end)
            end
        end
    })
end

-- ==============================================================
-- ⚔️ Tab 1: Main Farm
-- ==============================================================
local TabFarm = Window:MakeTab({Name = "Main Farm", Icon = "rbxassetid://4483345998", PremiumOnly = false})

TabFarm:AddLabel("--- Farming Controls ---")
TabFarm:AddToggle({
    Name = "Fast Farm (V8 Async)",
    Default = getgenv().v_settings.functionToggles["FastFarm"] or false,
    Callback = function(state) getgenv().v_settings.functionToggles.FastFarm = state end
})
CreateSmartToggle(TabFarm, "Auto Time Trial (Per Tile)", "AutoTimeTrial")
CreateSmartToggle(TabFarm, "Auto Unlock Zone", "AutoUnlock")
CreateSmartToggle(TabFarm, "Go To Best Zone (Center Map)", "BestZone")
CreateSmartToggle(TabFarm, "Auto Collect Lootbags & Orbs", "AutoLoot")

TabFarm:AddLabel("--- Optimization ---")
TabFarm:AddToggle({
    Name = "Optimize Breakables (Safe Mode)",
    Default = getgenv().v_settings.functionToggles["OptimizeBreakables"] or false,
    Callback = function(state)
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
    end
})
CreateSmartToggle(TabFarm, "Optimize Pets (Static/No Render)", "OptimizePets")

TabFarm:AddLabel("--- Auto Rewards & Ultimate ---")
CreateSmartToggle(TabFarm, "Auto Use Ultimate", "AutoUltimate")
CreateSmartToggle(TabFarm, "Auto Claim Free Gifts & Mailbox", "AutoMisc")
CreateSmartToggle(TabFarm, "Auto Claim Rank Rewards", "ClaimRank")

-- ==============================================================
-- 🐾 Tab 2: Pets & Eggs
-- ==============================================================
local TabPet = Window:MakeTab({Name = "Pets & Eggs", Icon = "rbxassetid://4483345998", PremiumOnly = false})

TabPet:AddLabel("--- Hatching & Crafting ---")
CreateSmartToggle(TabPet, "Auto Hatch Best Egg (Remote)", "AutoHatch")
CreateSmartToggle(TabPet, "Hide Egg Animation", "HideEgg")
CreateSmartToggle(TabPet, "Hook Egg Animation (Notify)", "HookEgg")
CreateSmartToggle(TabPet, "Auto Craft Gold Pets", "AutoGold")
CreateSmartToggle(TabPet, "Auto Craft Rainbow Pets", "AutoRainbow")

TabPet:AddLabel("--- Mastery & Slots ---")
TabPet:AddButton({ Name = "Buy Pet Slots (Auto Detection)", Callback = function() getgenv().v_settings.functions.BuyPetSlots() end })
TabPet:AddButton({ Name = "Buy Egg Slots (Auto Detection)", Callback = function() getgenv().v_settings.functions.BuyEggSlots() end })

-- ==============================================================
-- 📦 Tab 3: Open Lootboxes
-- ==============================================================
local TabOpen = Window:MakeTab({Name = "Open Lootboxes", Icon = "rbxassetid://4483345998", PremiumOnly = false})

TabOpen:AddLabel("--- Lootboxes (Max 8/tick) ---")
local DL = TabOpen:AddDropdown({
    Name = "Select Lootbox",
    Default = getgenv().v_settings.functionToggles.SelectedLootbox or "Loading...",
    Options = {"Loading..."},
    Callback = function(Value) getgenv().v_settings.functionToggles.SelectedLootbox = Value end
})

TabOpen:AddToggle({
    Name = "Auto Open Lootbox",
    Default = getgenv().v_settings.functionToggles.AutoOpenLootbox,
    Callback = function(state) getgenv().v_settings.functionToggles.AutoOpenLootbox = state end
})

TabOpen:AddLabel("--- GiftBags & Bundles (Max 100/tick) ---")
local DG = TabOpen:AddDropdown({
    Name = "Select GiftBag/Bundle",
    Default = getgenv().v_settings.functionToggles.SelectedGift or "Loading...",
    Options = {"Loading..."},
    Callback = function(Value) getgenv().v_settings.functionToggles.SelectedGift = Value end
})

TabOpen:AddToggle({
    Name = "Auto Open GiftBag/Bundle",
    Default = getgenv().v_settings.functionToggles.AutoOpenGift,
    Callback = function(state) getgenv().v_settings.functionToggles.AutoOpenGift = state end
})

TabOpen:AddLabel("--- Spinny Wheels ---")
local DW = TabOpen:AddDropdown({
    Name = "Select Wheel Ticket",
    Default = getgenv().v_settings.functionToggles.SelectedWheel or "Loading...",
    Options = {"Loading..."},
    Callback = function(Value) getgenv().v_settings.functionToggles.SelectedWheel = Value end
})

TabOpen:AddToggle({
    Name = "Auto Spin Wheel",
    Default = getgenv().v_settings.functionToggles.AutoSpinWheel,
    Callback = function(state) getgenv().v_settings.functionToggles.AutoSpinWheel = state end
})

TabOpen:AddButton({
    Name = "Refresh Wheel/Lootbox Inventory",
    Callback = function() 
        pcall(function() DL:Refresh(GetAvailableLootboxes(), true) end)
        pcall(function() DG:Refresh(GetAvailableGifts(), true) end) 
        pcall(function() DW:Refresh(GetAvailableWheels(), true) end)
    end
})

TabOpen:AddLabel("--- Auto Combine Keys (Batch Mode) ---")
local DK = TabOpen:AddDropdown({
    Name = "Select Key to Combine",
    Default = getgenv().v_settings.functionToggles.SelectedKey or "Loading...",
    Options = {"Loading..."},
    Callback = function(Value) getgenv().v_settings.functionToggles.SelectedKey = Value end
})

TabOpen:AddToggle({
    Name = "Auto Combine Keys (Max Speed)",
    Default = getgenv().v_settings.functionToggles.AutoCombineKeys,
    Callback = function(state) getgenv().v_settings.functionToggles.AutoCombineKeys = state end
})

TabOpen:AddButton({
    Name = "Refresh Keys",
    Callback = function() 
        pcall(function() DK:Refresh(GetAvailableKeys(), true) end) 
    end
})

-- ==============================================================
-- 🎒 Tab 4: Items & Events
-- ==============================================================
local TabItem = Window:MakeTab({Name = "Items & Events", Icon = "rbxassetid://4483345998", PremiumOnly = false})

TabItem:AddLabel("--- Auto Items ---")
CreateSmartToggle(TabItem, "Smart Auto Fruit (Maintain Max Buffs)", "AutoFruit")
CreateSmartToggle(TabItem, "Auto Combine Fantasy Presents", "AutoCombine")

TabItem:AddLabel("--- Flags & Events ---")
local DF = TabItem:AddDropdown({
    Name = "Select Flag",
    Default = getgenv().v_settings.functionToggles.SelectedFlag or "Loading...",
    Options = {"Loading..."},
    Callback = function(Value) getgenv().v_settings.functionToggles.SelectedFlag = Value end
})

TabItem:AddButton({
    Name = "Refresh Flags",
    Callback = function() 
        pcall(function() DF:Refresh(GetAvailableFlags(), true) end) 
    end
})
CreateSmartToggle(TabItem, "Auto Place Flag", "AutoFlag")

TabItem:AddLabel("--- Auto Daycare (Smart Selection) ---")
TabItem:AddButton({
    Name = "Claim All Ready Pets",
    Callback = function() ClaimAllReadyPets() end
})
TabItem:AddButton({
    Name = "Enroll Best Pets",
    Callback = function() EnrollBestPets() end
})
TabItem:AddToggle({
    Name = "Auto Daycare System",
    Default = getgenv().v_settings.functionToggles.AutoDaycare,
    Callback = function(state) getgenv().v_settings.functionToggles.AutoDaycare = state end
})

-- ==============================================================
-- 🔥 Tab 5: Auto Fuse (TÍCH HỢP MỚI)
-- ==============================================================
local TabFuse = Window:MakeTab({Name = "Auto Fuse", Icon = "rbxassetid://4483345998", PremiumOnly = false})

local SelectedPetsParagraph = TabFuse:AddParagraph("Selected Pets List", "Waiting for your pet selection...")

TabFuse:AddButton({
    Name = "Select Pets To Fuse",
    Callback = function()
        getgenv().v_settings.functionToggles.AutoFuse = false 
        
        local config = {
            SelectionMode = 3,
            QuantityMode = 1,
            MaxQuantity = 100,
            ClassWhitelist = {"Pet"}
        }
        
        local success, resultTable = pcall(function()
            return { InventorySelect.Select(config) }
        end)
        
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
                        
                        displayString = displayString .. "- [" .. prefix .. pName .. "] x" .. tostring(amount) .. "\n"
                        count = count + 1
                    end
                end
                
                if count > 0 then
                    SelectedPetsParagraph:Set(displayString)
                else
                    SelectedPetsParagraph:Set("No valid pets selected.")
                    getgenv().v_settings.SelectedPetsForFuse = {}
                end
            end
        end
    end
})

local ToggleAutoFuse = TabFuse:AddToggle({
    Name = "Auto Fuse Selected Pets",
    Default = getgenv().v_settings.functionToggles.AutoFuse,
    Callback = function(state) 
        local hasSelection = false
        for _, _ in pairs(getgenv().v_settings.SelectedPetsForFuse) do hasSelection = true break end
        
        if state and not hasSelection then
            task.spawn(function()
                task.wait(0.1)
                ToggleAutoFuse:Set(false)
            end)
            return
        end
        getgenv().v_settings.functionToggles.AutoFuse = state
    end
})

-- Vòng lặp chạy ngầm hệ thống Fuse (CƠ CHẾ TUẦN TỰ & CHỜ PET)
task.spawn(function()
    while task.wait(1) do
        if getgenv().v_settings.functionToggles.AutoFuse then
            local inventory = Save.Get().Inventory.Pet or {}
            local payload = nil
            
            for uid, targetAmount in pairs(getgenv().v_settings.SelectedPetsForFuse) do
                local curInv = inventory[uid]
                local currentAmount = curInv and (curInv._am or 1) or 0
                
                if currentAmount >= targetAmount and targetAmount >= 3 then
                    payload = {[uid] = targetAmount}
                    break 
                end
            end
            
            if payload then
                pcall(function()
                    Network.Invoke("FuseMachine_Activate", payload)
                end)
            end
        end
    end
end)

-- ==============================================================
-- ⚙️ Tab 6: Settings
-- ==============================================================
local TabSet = Window:MakeTab({Name = "Settings", Icon = "rbxassetid://4483345998", PremiumOnly = false})

TabSet:AddLabel("--- Config Management ---")
TabSet:AddButton({
    Name = "Save File",
    Callback = function() 
        SaveCurrentConfig()
        OrionLib:MakeNotification({Name = "System", Content = "Configuration saved to Phone Storage!", Time = 3})
    end
})
TabSet:AddLabel("The system will automatically start the saved features upon runtime..")

TabSet:AddLabel("--- Player Controls ---")
TabSet:AddSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 150,
    Default = 16,
    Color = Color3.fromRGB(255,255,255),
    Increment = 1,
    ValueName = "Speed",
    Callback = function(Value)
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = Value end
    end
})

local NoclipConnection = nil
TabSet:AddToggle({
    Name = "Ghost Noclip",
    Default = false,
    Callback = function(state)
        if state then
            NoclipConnection = RunService.Stepped:Connect(function()
                local char = LocalPlayer.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                    end
                end
            end)
        else
            if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil end
        end
    end
})

TabSet:AddLabel("--- System ---")
TabSet:AddButton({
    Name = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
})
CreateSmartToggle(TabSet, "Blackout Mode (FPS Boost)", "Blackout")
CreateSmartToggle(TabSet, "Anti-AFK", "AntiAFK")

-- ==============================================================
-- 📱 NÚT BẤM NATIVE MOBILE (PHIÊN BẢN TỐI ƯU: CHÈN NGAY KHI UI SẴN SÀNG)
-- ==============================================================
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

task.spawn(function()
    local targetButtonName = "FreeGifts" -- Dùng nút FreeGifts làm mốc
    local parentContainer = nil
    
    -- Hàm thực thi việc chèn nút
    local function InjectButton(templateButton)
        parentContainer = templateButton.Parent
        
        if parentContainer:FindFirstChild("PoodleHubNative") then return end
        
        local newBtn = templateButton:Clone()
        newBtn.Name = "PoodleHubNative"
        newBtn.LayoutOrder = -9999
        newBtn.Visible = true
        
        for _, child in ipairs(newBtn:GetChildren()) do
            if child.Name == "Timer" or child.Name == "Notification" or child.Name == "Lock" or child.Name == "Count" then
                child:Destroy()
            end
        end
        
        local iconTarget = newBtn:FindFirstChild("Thumbnail") or newBtn:FindFirstChild("Icon")
        if iconTarget and iconTarget:IsA("ImageLabel") then
            iconTarget.Image = "rbxassetid://111923365293773" -- ID mới của bạn
            iconTarget.ImageColor3 = Color3.fromRGB(255, 255, 255)
            iconTarget.ImageRectOffset = Vector2.new(0, 0)
            iconTarget.ImageRectSize = Vector2.new(0, 0)
            iconTarget.ScaleType = Enum.ScaleType.Fit
        end
        
        newBtn.MouseButton1Click:Connect(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
        end)
        
        newBtn.Parent = parentContainer
    end

    -- THEO DÕI VÀ CHÈN NGAY KHI NÚT GỐC XUẤT HIỆN
    local function WatchForUI()
        for _, gui in ipairs(PlayerGui:GetDescendants()) do
            if gui.Name == targetButtonName and gui:IsA("TextButton") and gui.Visible then
                InjectButton(gui)
                return true
            end
        end
        return false
    end

    -- Nếu chưa có nút, thì theo dõi khi nào nó xuất hiện
    if not WatchForUI() then
        PlayerGui.DescendantAdded:Connect(function(descendant)
            if descendant.Name == targetButtonName and descendant:IsA("TextButton") then
                task.wait(0.5) -- Đợi 1 chút cho game layout xong
                InjectButton(descendant)
            end
        end)
    end
end)

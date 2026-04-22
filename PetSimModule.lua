-- ==========================================
-- PET SIMULATOR 99 - UTILITY MODULE
-- (Chỉ chứa các hàm hỗ trợ, không can thiệp sâu vào game)
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildOfClass("Terrain")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end

local Module = {}

-- ========== TỐI ƯU HÓA ĐỒ HỌA (GIẢM LAG) ==========
function Module.Optimize(fpsCap)
    pcall(function()
        local UserSettings = UserSettings()
        local GameSettings = UserSettings:GetService("UserGameSettings")
        GameSettings.GraphicsQualityLevel = 1
        GameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        GameSettings.MasterVolume = 0
        settings().Rendering.QualityLevel = 1
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
        if Terrain then sethiddenproperty(Terrain, "Decoration", false) end
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
    end)

    if fpsCap then setfpscap(fpsCap) end
end

-- ========== NOCLIP (XUYÊN TƯỜNG) ==========
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

-- ========== TIỆN ÍCH CHUYỂN ĐỔI SỐ ==========
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
    local mult = ({k=1e3, m=1e6, b=1e9, t=1e12})[suffix and suffix:lower() or ""] or 1
    return num * mult
end

function Module.ConvertTime(sec)
    local d = math.floor(sec / 86400); sec = sec % 86400
    local h = math.floor(sec / 3600); sec = sec % 3600
    local m = math.floor(sec / 60); sec = sec % 60
    return string.format("%dd %dh %dm %ds", d, h, m, sec)
end

-- ========== DI CHUYỂN MƯỢT MÀ (DÙNG TWEEN) ==========
local TweenService = game:GetService("TweenService")
function Module.MoveTo(targetCF, speed)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local distance = (hrp.Position - targetCF.Position).Magnitude
    speed = speed or 50
    local tween = TweenService:Create(hrp, TweenInfo.new(distance/speed, Enum.EasingStyle.Linear), {CFrame = targetCF})
    tween:Play()
    tween.Completed:Wait()
end

-- ========== FARM BREAKABLES (ĐƠN GIẢN) ==========
-- Lưu ý: Đây là logic farm cơ bản, có thể cần chỉnh sửa để khớp với PS99.
function Module.FarmBreakables(petList, networkLib)
    -- Trong PS99, việc gửi pet đi farm có thể khác. Hàm này chỉ là placeholder.
    -- Bạn có thể tự mở rộng dựa trên script chính.
    warn("FarmBreakables trong PS99 chưa được triển khai đầy đủ. Hãy tự viết logic.")
end

return Module

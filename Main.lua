-- Minimal Rivals menu: Silent Aim only, English
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local LocalPlayer = Players.LocalPlayer

local Window = Library:CreateWindow({
    Title = 'Rivals',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0,
})

local Tab = Window:AddTab('Main')
local Box = Tab:AddLeftGroupbox('Silent Aim')

local SA = {
    Enabled = false,
    AutoShoot = false,
    KeyHeld = false,
    FOV = 100,
    HitPart = 'Head',
    TeamCheck = true,
}

Box:AddToggle('SAEnabled', {
    Text = 'Enable Silent Aim',
    Default = false,
    Callback = function(v) SA.Enabled = v end,
})

Box:AddToggle('SAAutoShoot', {
    Text = 'Auto Shoot',
    Default = false,
    Callback = function(v) SA.AutoShoot = v end,
})

Box:AddLabel('Aim Key'):AddKeyPicker('SAKey', {
    Default = 'E',
    Text = 'Aim Key (hold to aim)',
    Mode = 'Hold',
})

Box:AddSlider('SAFOV', {
    Text = 'FOV (px)',
    Default = 100, Min = 10, Max = 800, Rounding = 0,
    Callback = function(v) SA.FOV = v end,
})

Box:AddDropdown('SAHitPart', {
    Values = { 'Head', 'HumanoidRootPart', 'UpperTorso', 'LowerTorso', 'Torso' },
    Default = 1, Multi = false,
    Text = 'Hit Part',
    Callback = function(v) SA.HitPart = v end,
})

Box:AddToggle('SATeam', {
    Text = 'Team Check',
    Default = true,
    Callback = function(v) SA.TeamCheck = v end,
})

-- Key detection
local function getKeyCode()
    local picker = Options and Options.SAKey
    if picker and type(picker.Value) == 'string' then
        local ok, code = pcall(function() return Enum.KeyCode[picker.Value] end)
        if ok and code then return code end
    end
    return Enum.KeyCode.E
end

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == getKeyCode() then SA.KeyHeld = true end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == getKeyCode() then SA.KeyHeld = false end
end)

if Options and Options.SAKey then
    Options.SAKey:OnChanged(function() SA.KeyHeld = false end)
end

-- Lazy module loading
local Utility, EnumLibrary, LocalFighter
local function ensureModules()
    if not Utility then
        local m = ReplicatedStorage:FindFirstChild('Modules')
        local u = m and m:FindFirstChild('Utility')
        if u then
            local ok, res = pcall(require, u)
            if ok then Utility = res end
        end
    end
    if not EnumLibrary then
        local m = ReplicatedStorage:FindFirstChild('Modules')
        local e = m and m:FindFirstChild('EnumLibrary')
        if e then
            local ok, res = pcall(require, e)
            if ok then EnumLibrary = res end
        end
    end
    if not LocalFighter then
        local ps = LocalPlayer:FindFirstChild('PlayerScripts')
        local c = ps and ps:FindFirstChild('Controllers')
        local f = c and c:FindFirstChild('FighterController')
        if f then
            local ok, res = pcall(require, f)
            if ok and res and res.LocalFighter then LocalFighter = res.LocalFighter end
        end
    end
    return Utility and EnumLibrary and LocalFighter
end

local function isActive()
    if not SA.Enabled then return false end
    if SA.AutoShoot then return true end
    return SA.KeyHeld
end

local function getTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local origin = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local best, bestDist = nil, SA.FOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChildOfClass('Humanoid')
                if hum and hum.Health > 0 then
                    local skip = false
                    if SA.TeamCheck and plr.Team and LocalPlayer.Team
                       and plr.Team == LocalPlayer.Team then skip = true end
                    if not skip then
                        local part = char:FindFirstChild('Head') or char:FindFirstChild('HumanoidRootPart')
                        if part then
                            local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local d = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
                                if d <= bestDist then
                                    best, bestDist = char, d
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function getHitPart(char, partName)
    local names = {
        Head = {'Head'},
        HumanoidRootPart = {'HumanoidRootPart'},
        UpperTorso = {'UpperTorso', 'Torso'},
        LowerTorso = {'LowerTorso', 'Torso'},
        Torso = {'Torso', 'UpperTorso'},
    }
    for _, n in ipairs(names[partName] or {partName}) do
        local p = char:FindFirstChild(n)
        if p and p:IsA('BasePart') then return p end
    end
    return char:FindFirstChildWhichIsA('BasePart')
end

local lastFire = 0
local function fire()
    if not SA.Enabled then return end
    local now = tick()
    if now - lastFire < 0.05 then return end
    if not ensureModules() then return end

    local target = getTarget()
    if not target then return end
    local part = getHitPart(target, SA.HitPart)
    if not part then return end

    local myChar = LocalPlayer.Character
    local root = myChar and myChar:FindFirstChild('HumanoidRootPart')
    if not root then return end

    local objId = LocalFighter.EquippedItem and LocalFighter.EquippedItem:Get('ObjectID')
    if not objId then return end

    lastFire = now
    local data = {
        [utf8.char(1)] = {
            [utf8.char(0)] = Utility:EncodeCFrame(CFrame.new(root.Position, part.Position)),
            [utf8.char(1)] = Utility:EncodeCFrame(CFrame.new(root.Position, part.Position)),
            [utf8.char(2)] = part,
            [utf8.char(3)] = Utility:EncodeCFrame(CFrame.new(0.43, 0.25, 0.42)),
        },
    }
    pcall(function()
        ReplicatedStorage.Remotes.Replication.Fighter.UseItem:FireServer(
            objId, EnumLibrary:ToEnum('StartShooting'), data, nil
        )
    end)
end

RunService.Heartbeat:Connect(function()
    if isActive() then pcall(fire) end
end)

print('[Rivals] Silent Aim loaded.')

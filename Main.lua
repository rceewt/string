-- LinoriaLib menu: Main | Visuals | Misc | Settings
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local env = getgenv and getgenv() or _G
if env.__MenuLibrary then
    pcall(function() env.__MenuLibrary:Unload() end)
    env.__MenuLibrary = nil
    task.wait(0.2)
end

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
env.__MenuLibrary = Library

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local Stats = game:GetService('Stats')
local UIS = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local LocalPlayer = Players.LocalPlayer

local Window = Library:CreateWindow({
    Title = 'Rivals Menu', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0,
})

local Tabs = {}
Tabs.Main     = Window:AddTab('Main')
Tabs.Visuals  = Window:AddTab('Visuals')
Tabs.Misc     = Window:AddTab('Misc')
Tabs.Settings = Window:AddTab('Settings')

local function safe(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn('[menu] Chyba "' .. name .. '": ' .. tostring(err))
        pcall(function() Library:Notify('Chyba "' .. name .. '"', 5) end)
    end
end

----------------------------------------------------------------
-- MODULY PRO SILENT AIM
----------------------------------------------------------------
local Utility, EnumLibrary
pcall(function() Utility = require(ReplicatedStorage.Modules.Utility) end)
pcall(function() EnumLibrary = require(ReplicatedStorage.Modules.EnumLibrary) end)

local function getLocalFighter()
    local ok, fc = pcall(function()
        return require(LocalPlayer.PlayerScripts.Controllers.FighterController)
    end)
    if ok and fc and fc.LocalFighter then return fc.LocalFighter end
    return nil
end

----------------------------------------------------------------
-- MAIN TAB – SILENT AIM + ANTI KATANA
----------------------------------------------------------------
local silentAim = {
    Enabled = false, AlwaysOn = false, KeyHeld = false,
    FOV = 100, HitPart = 'Head', HitChance = 100,
    TeamCheck = true, WallCheck = false, AutoShoot = false, ShowFOV = true,
}
local aimKey = Enum.KeyCode.E
local antikatana = false

-- FOV kruh (bezpečné vytvoření)
local fovContainer, fovStroke
safe('FOV GUI', function()
    local parent = (gethui and gethui()) or game:GetService('CoreGui')
    local gui = Instance.new('ScreenGui')
    gui.Name = 'SilentAimFOV'
    gui.DisplayOrder = 10
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = parent
    fovContainer = Instance.new('Frame')
    fovContainer.BackgroundTransparency = 1
    fovContainer.BorderSizePixel = 0
    fovContainer.Visible = false
    fovContainer.Parent = gui
    local outline = Instance.new('Frame')
    outline.BackgroundTransparency = 1
    outline.Size = UDim2.new(1, 0, 1, 0)
    outline.Parent = fovContainer
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = outline
    fovStroke = Instance.new('UIStroke')
    fovStroke.Color = Color3.fromRGB(255, 255, 255)
    fovStroke.Thickness = 1.5
    fovStroke.Transparency = 0
    fovStroke.Parent = outline
end)

local SA = Tabs.Main:AddLeftGroupbox('Silent Aim')

safe('SA toggles', function()
    SA:AddToggle('SAEnabled', { Text = 'Enable Silent Aim', Default = false })
        :OnChanged(function(v) silentAim.Enabled = v end)
    SA:AddToggle('SAAlways', { Text = 'Always On (ignore key)', Default = false })
        :OnChanged(function(v) silentAim.AlwaysOn = v end)
    SA:AddToggle('SAAutoShoot', { Text = 'Auto Shoot', Default = false })
        :OnChanged(function(v) silentAim.AutoShoot = v end)
end)

safe('SA key', function()
    SA:AddLabel('Aim key'):AddKeyPicker('SAKey', {
        Default = 'E', NoUI = false, Text = 'Aim key', Mode = 'Hold',
    })
end)

safe('SA FOV slider', function()
    SA:AddSlider('SAFOV', { Text = 'FOV (px)', Default = 100, Min = 10, Max = 800, Rounding = 0 })
        :OnChanged(function(v) silentAim.FOV = v end)
end)

safe('SA hit part', function()
    SA:AddDropdown('SAHitPart', {
        Values = { 'Head', 'HumanoidRootPart', 'UpperTorso', 'LowerTorso', 'Torso' },
        Default = 1, Multi = false, Text = 'Hit part',
    }):OnChanged(function(v) silentAim.HitPart = v end)
end)

safe('SA hit chance', function()
    SA:AddSlider('SAHitChance', { Text = 'Hit chance (%)', Default = 100, Min = 0, Max = 100, Rounding = 0 })
        :OnChanged(function(v) silentAim.HitChance = v end)
end)

safe('SA team check', function()
    SA:AddToggle('SATeam', { Text = 'Team check', Default = true })
        :OnChanged(function(v) silentAim.TeamCheck = v end)
end)

safe('SA wall check', function()
    SA:AddToggle('SAWall', { Text = 'Wall check', Default = false })
        :OnChanged(function(v) silentAim.WallCheck = v end)
end)

safe('SA FOV circle', function()
    SA:AddToggle('SAFovDraw', { Text = 'Draw FOV circle', Default = true })
        :OnChanged(function(v)
            silentAim.ShowFOV = v
            if not v and fovContainer then fovContainer.Visible = false end
        end)
        :AddColorPicker('SAFovColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'FOV color' })
        :OnChanged(function(c) if fovStroke then fovStroke.Color = c end end)
end)

safe('Anti Katana', function()
    SA:AddDivider()
    SA:AddToggle('AntiKatana', { Text = 'Anti Katana', Default = false })
        :OnChanged(function(v) antikatana = v end)
end)

----------------------------------------------------------------
-- ANTI KATANA DETEKCE
----------------------------------------------------------------
local katanausers = {}
task.spawn(function()
    local katana, attempts = nil, 0
    while attempts < 15 do
        pcall(function()
            local m = LocalPlayer.PlayerScripts.Modules.Items:FindFirstChild('Katana', true)
            if m then katana = require(m) end
        end)
        if katana and type(katana) == 'table' and katana.StartAiming then break end
        attempts += 1
        task.wait(1)
    end
    if katana and type(katana) == 'table' and katana.StartAiming then
        local old = katana.StartAiming
        katana.StartAiming = function(self, force)
            local fighter = self.ClientFighter
            local plr = fighter and fighter.Player
            if plr then
                katanausers[plr] = true
                local dur = (self.Info and self.Info.DeflectDuration) or 0.6
                task.delay(dur, function() katanausers[plr] = nil end)
            end
            return old(self, force)
        end
    end
end)

----------------------------------------------------------------
-- SILENT AIM LOGIKA
----------------------------------------------------------------
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == aimKey then silentAim.KeyHeld = true end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == aimKey then silentAim.KeyHeld = false end
end)

if Options and Options.SAKey then
    Options.SAKey:OnChanged(function()
        local v = Options.SAKey.Value
        if type(v) == 'string' then
            local ok, code = pcall(function() return Enum.KeyCode[v] end)
            if ok and code then aimKey = code end
        end
    end)
end

local function isSilentActive()
    if not silentAim.Enabled then return false end
    if silentAim.AlwaysOn then return true end
    return silentAim.KeyHeld
end

local function getClosestInFOV()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local origin = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local camPos = cam.CFrame.Position
    local best, bestDist = nil, silentAim.FOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChildOfClass('Humanoid')
                if hum and hum.Health > 0 then
                    local skip = false
                    if silentAim.TeamCheck and plr.Team and LocalPlayer.Team
                       and plr.Team == LocalPlayer.Team then skip = true end
                    if not skip then
                        local part = char:FindFirstChild('Head') or char:FindFirstChild('HumanoidRootPart')
                        if part then
                            local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local d = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
                                if d <= bestDist then
                                    if silentAim.WallCheck then
                                        local params = RaycastParams.new()
                                        params.FilterType = Enum.RaycastFilterType.Exclude
                                        params.FilterDescendantsInstances = { LocalPlayer.Character, cam }
                                        local res = workspace:Raycast(camPos, part.Position - camPos, params)
                                        if res and not res.Instance:IsDescendantOf(char) then skip = true end
                                    end
                                    if not skip then best, bestDist = char, d end
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

local function hitPartFromName(char, partName)
    if not char then return nil end
    local aliases = {
        Head = {'Head'},
        HumanoidRootPart = {'HumanoidRootPart'},
        UpperTorso = {'UpperTorso', 'Torso'},
        LowerTorso = {'LowerTorso', 'Torso'},
        Torso = {'Torso', 'UpperTorso'},
    }
    for _, name in ipairs(aliases[partName] or {partName}) do
        local p = char:FindFirstChild(name)
        if p and p:IsA('BasePart') then return p end
    end
    return char:FindFirstChildWhichIsA('BasePart')
end

local function shouldHit()
    if silentAim.HitChance >= 100 then return true end
    if silentAim.HitChance <= 0 then return false end
    return math.random(1, 100) <= silentAim.HitChance
end

local lastFireTime = 0

local function fireSilent()
    if not silentAim.Enabled or not Utility or not EnumLibrary then return end
    local lf = getLocalFighter()
    if not lf or not lf.EquippedItem then return end
    local now = tick()
    if now - lastFireTime < 0.05 then return end
    if not shouldHit() then return end

    local target = getClosestInFOV()
    if not target then return end
    local tp = Players:GetPlayerFromCharacter(target)
    if antikatana and tp and katanausers[tp] then return end

    local part = hitPartFromName(target, silentAim.HitPart)
    if not part then return end
    local myChar = LocalPlayer.Character
    local root = myChar and myChar:FindFirstChild('HumanoidRootPart')
    if not root then return end

    local equipped = lf.EquippedItem
    local objId = equipped:Get('ObjectID')
    if not objId then return end

    lastFireTime = now
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

RunService.RenderStepped:Connect(function()
    if fovContainer then
        local cam = workspace.CurrentCamera
        if silentAim.Enabled and silentAim.ShowFOV and cam then
            local vp = cam.ViewportSize
            local r = silentAim.FOV
            fovContainer.Size = UDim2.fromOffset(r * 2, r * 2)
            fovContainer.Position = UDim2.fromOffset(vp.X * 0.5 - r, vp.Y * 0.5 - r)
            fovContainer.Visible = true
        else
            fovContainer.Visible = false
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if silentAim.Enabled and (silentAim.AutoShoot or isSilentActive()) then
        pcall(fireSilent)
    end
end)

----------------------------------------------------------------
-- VISUALS TAB – ESP
----------------------------------------------------------------
local HAS_DRAWING = (Drawing ~= nil)

safe('ESP UI', function()
    local ESPGroup = Tabs.Visuals:AddLeftGroupbox('ESP')
    local ESPSettings = Tabs.Visuals:AddRightGroupbox('ESP Settings')

    ESPGroup:AddToggle('ESPEnabled', { Text = 'Enable ESP', Default = false })
    ESPGroup:AddDivider()
    ESPGroup:AddToggle('ESPBox', { Text = 'Box', Default = true })
        :AddColorPicker('ESPBoxColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Box color' })
    ESPGroup:AddToggle('ESPSkeleton', { Text = 'Skeleton', Default = true })
        :AddColorPicker('ESPSkeletonColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Skeleton color' })
    ESPGroup:AddToggle('ESPName', { Text = 'Name', Default = true })
        :AddColorPicker('ESPNameColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Name color' })
    ESPGroup:AddToggle('ESPDist', { Text = 'Distance', Default = true })
        :AddColorPicker('ESPDistColor', { Default = Color3.fromRGB(200, 200, 200), Title = 'Distance color' })
    ESPGroup:AddToggle('ESPHealth', { Text = 'Health bar', Default = true })
    ESPGroup:AddToggle('ESPHealthText', { Text = 'Health number', Default = true })
        :AddColorPicker('ESPHealthTextColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Health color' })
    ESPGroup:AddToggle('ESPWeapon', { Text = 'Held weapon', Default = true })
        :AddColorPicker('ESPWeaponColor', { Default = Color3.fromRGB(255, 220, 120), Title = 'Weapon color' })
    ESPSettings:AddToggle('ESPTeamCheck', { Text = 'Hide teammates', Default = false })
end)

local ESP_TOGGLES = { 'ESPBox', 'ESPSkeleton', 'ESPName', 'ESPDist', 'ESPHealth', 'ESPHealthText', 'ESPWeapon' }
local R15_BONES = {
    { 'Head', 'UpperTorso' }, { 'UpperTorso', 'LowerTorso' },
    { 'UpperTorso', 'LeftUpperArm' }, { 'LeftUpperArm', 'LeftLowerArm' }, { 'LeftLowerArm', 'LeftHand' },
    { 'UpperTorso', 'RightUpperArm' }, { 'RightUpperArm', 'RightLowerArm' }, { 'RightLowerArm', 'RightHand' },
    { 'LowerTorso', 'LeftUpperLeg' }, { 'LeftUpperLeg', 'LeftLowerLeg' }, { 'LeftLowerLeg', 'LeftFoot' },
    { 'LowerTorso', 'RightUpperLeg' }, { 'RightUpperLeg', 'RightLowerLeg' }, { 'RightLowerLeg', 'RightFoot' },
}
local R6_BONES = {
    { 'Head', 'Torso' }, { 'Torso', 'Left Arm' }, { 'Torso', 'Right Arm' },
    { 'Torso', 'Left Leg' }, { 'Torso', 'Right Leg' },
}
local WEAPON_ATTRS = { 'EquippedWeapon', 'CurrentWeapon', 'Weapon', 'Equipped' }
local ESP = {}
local espConn

local function safeRemove(d) pcall(function() d:Remove() end) end
local function newText(size)
    local t = Drawing.new('Text')
    t.Size = size; t.Center = true; t.Outline = true; t.Visible = false
    return t
end
local function createESP(player)
    local obj = {
        boxOutline = Drawing.new('Square'), box = Drawing.new('Square'),
        hpOutline = Drawing.new('Square'), hpBar = Drawing.new('Square'),
        name = newText(13), dist = newText(12), weapon = newText(12), hpText = newText(11),
        bones = {},
    }
    obj.boxOutline.Thickness = 3; obj.boxOutline.Filled = false; obj.boxOutline.Color = Color3.new(0, 0, 0)
    obj.box.Thickness = 1; obj.box.Filled = false
    obj.hpOutline.Filled = true; obj.hpOutline.Color = Color3.new(0, 0, 0)
    obj.hpBar.Filled = true
    for i = 1, #R15_BONES do
        local line = Drawing.new('Line')
        line.Thickness = 1; line.Visible = false
        obj.bones[i] = line
    end
    ESP[player] = obj
    return obj
end
local function hideESP(obj)
    obj.box.Visible = false; obj.boxOutline.Visible = false
    obj.hpOutline.Visible = false; obj.hpBar.Visible = false
    obj.hpText.Visible = false; obj.name.Visible = false
    obj.dist.Visible = false; obj.weapon.Visible = false
    for i = 1, #obj.bones do obj.bones[i].Visible = false end
end
local function removeESP(player)
    local obj = ESP[player]
    if not obj then return end
    for key, d in next, obj do
        if key == 'bones' then
            for i = 1, #d do safeRemove(d[i]) end
        else safeRemove(d) end
    end
    ESP[player] = nil
end
local function removeAllESP()
    for p in next, ESP do removeESP(p) end
end
local function getWeaponName(player, char)
    local tool = char:FindFirstChildOfClass('Tool')
    if tool then return tool.Name end
    for i = 1, #WEAPON_ATTRS do
        local v = char:GetAttribute(WEAPON_ATTRS[i]) or player:GetAttribute(WEAPON_ATTRS[i])
        if type(v) == 'string' and v ~= '' then return v end
    end
    return nil
end
local function updateESP()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position
    local showBox = Toggles.ESPBox and Toggles.ESPBox.Value
    local showSkel = Toggles.ESPSkeleton and Toggles.ESPSkeleton.Value
    local showName = Toggles.ESPName and Toggles.ESPName.Value
    local showDist = Toggles.ESPDist and Toggles.ESPDist.Value
    local showHP = Toggles.ESPHealth and Toggles.ESPHealth.Value
    local showHPText = Toggles.ESPHealthText and Toggles.ESPHealthText.Value
    local showWeapon = Toggles.ESPWeapon and Toggles.ESPWeapon.Value
    local teamCheck = Toggles.ESPTeamCheck and Toggles.ESPTeamCheck.Value
    local boxColor = (Options.ESPBoxColor and Options.ESPBoxColor.Value) or Color3.fromRGB(255, 255, 255)
    local skelColor = (Options.ESPSkeletonColor and Options.ESPSkeletonColor.Value) or Color3.fromRGB(255, 255, 255)
    local nameColor = (Options.ESPNameColor and Options.ESPNameColor.Value) or Color3.fromRGB(255, 255, 255)
    local distColor = (Options.ESPDistColor and Options.ESPDistColor.Value) or Color3.fromRGB(200, 200, 200)
    local hpTextColor = (Options.ESPHealthTextColor and Options.ESPHealthTextColor.Value) or Color3.fromRGB(255, 255, 255)
    local weaponColor = (Options.ESPWeaponColor and Options.ESPWeaponColor.Value) or Color3.fromRGB(255, 220, 120)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local obj = ESP[player] or createESP(player)
            local char = player.Character
            local root = char and char:FindFirstChild('HumanoidRootPart')
            local hum = char and char:FindFirstChildOfClass('Humanoid')
            local ok = root and hum and hum.Health > 0
            if ok and teamCheck and player.Team ~= nil and player.Team == LocalPlayer.Team then ok = false end
            local pos, onScreen
            if ok then
                pos, onScreen = cam:WorldToViewportPoint(root.Position)
                if not onScreen then ok = false end
            end
            if not ok then
                hideESP(obj)
            else
                local top = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 2.7, 0))
                local bottom = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3.2, 0))
                local h = math.abs(top.Y - bottom.Y)
                local w = h / 1.8
                local x, y = pos.X - w / 2, top.Y
                if showBox then
                    obj.boxOutline.Size = Vector2.new(w, h); obj.boxOutline.Position = Vector2.new(x, y); obj.boxOutline.Visible = true
                    obj.box.Size = Vector2.new(w, h); obj.box.Position = Vector2.new(x, y); obj.box.Color = boxColor; obj.box.Visible = true
                else
                    obj.box.Visible = false; obj.boxOutline.Visible = false
                end
                if showName then
                    obj.name.Text = player.DisplayName
                    obj.name.Position = Vector2.new(pos.X, y - 16)
                    obj.name.Color = nameColor; obj.name.Visible = true
                else obj.name.Visible = false end
                local frac = 0
                if showHP or showHPText then
                    local maxHP = hum.MaxHealth > 0 and hum.MaxHealth or 100
                    frac = math.clamp(hum.Health / maxHP, 0, 1)
                end
                if showHP then
                    local fillH = math.max(h * frac, 1)
                    obj.hpOutline.Size = Vector2.new(4, h + 2); obj.hpOutline.Position = Vector2.new(x - 7, y - 1); obj.hpOutline.Visible = true
                    obj.hpBar.Size = Vector2.new(2, fillH); obj.hpBar.Position = Vector2.new(x - 6, y + h - fillH)
                    obj.hpBar.Color = Color3.fromRGB(255 * (1 - frac), 255 * frac, 0); obj.hpBar.Visible = true
                else obj.hpOutline.Visible = false; obj.hpBar.Visible = false end
                if showHPText then
                    local fillH = h * frac
                    obj.hpText.Text = tostring(math.floor(hum.Health))
                    obj.hpText.Position = Vector2.new(x - 16, y + h - fillH - 6)
                    obj.hpText.Color = hpTextColor; obj.hpText.Visible = true
                else obj.hpText.Visible = false end
                local by = y + h + 1
                local weaponName = showWeapon and getWeaponName(player, char) or nil
                if weaponName then
                    obj.weapon.Text = weaponName; obj.weapon.Position = Vector2.new(pos.X, by); obj.weapon.Color = weaponColor; obj.weapon.Visible = true
                    by = by + 13
                else obj.weapon.Visible = false end
                if showDist then
                    obj.dist.Text = ('%dm'):format(math.floor((root.Position - camPos).Magnitude))
                    obj.dist.Position = Vector2.new(pos.X, by); obj.dist.Color = distColor; obj.dist.Visible = true
                else obj.dist.Visible = false end
                if showSkel then
                    local list = hum.RigType == Enum.HumanoidRigType.R15 and R15_BONES or R6_BONES
                    for i = 1, #list do
                        local line = obj.bones[i]
                        local a, b = char:FindFirstChild(list[i][1]), char:FindFirstChild(list[i][2])
                        if a and b then
                            local pa, va = cam:WorldToViewportPoint(a.Position)
                            local pb, vb = cam:WorldToViewportPoint(b.Position)
                            if va and vb then
                                line.From = Vector2.new(pa.X, pa.Y); line.To = Vector2.new(pb.X, pb.Y); line.Color = skelColor; line.Visible = true
                            else line.Visible = false end
                        else line.Visible = false end
                    end
                    for i = #list + 1, #obj.bones do obj.bones[i].Visible = false end
                else
                    for i = 1, #obj.bones do obj.bones[i].Visible = false end
                end
            end
        end
    end
end

local function refreshESP()
    local anyFeature = false
    for i = 1, #ESP_TOGGLES do
        local t = Toggles[ESP_TOGGLES[i]]
        if t and t.Value then anyFeature = true break end
    end
    local enabled = Toggles.ESPEnabled and Toggles.ESPEnabled.Value
    local active = enabled and anyFeature
    if active and not espConn then
        if not HAS_DRAWING then
            Library:Notify('Drawing library neni dostupna.', 5)
            Toggles.ESPEnabled:SetValue(false)
            return
        end
        espConn = RunService.RenderStepped:Connect(function()
            pcall(updateESP)
        end)
    elseif not active and espConn then
        espConn:Disconnect(); espConn = nil; removeAllESP()
    end
end

if Toggles.ESPEnabled then Toggles.ESPEnabled:OnChanged(refreshESP) end
for i = 1, #ESP_TOGGLES do
    if Toggles[ESP_TOGGLES[i]] then Toggles[ESP_TOGGLES[i]]:OnChanged(refreshESP) end
end
Players.PlayerRemoving:Connect(removeESP)

----------------------------------------------------------------
-- MISC TAB – UNLOCK ALL + HIT SOUNDS
----------------------------------------------------------------
safe('Unlock All', function()
    local G = Tabs.Misc:AddLeftGroupbox('Unlock')
    local ran = false
    G:AddToggle('ENABLE_UNLOCK_ALL', {
        Text = 'Unlock All', Default = false,
        Callback = function(v)
            if v and not ran then
                ran = true
                pcall(function()
                    loadstring(game:HttpGet('https://pastefy.app/6ElsMLeb/raw', true))()
                end)
                Library:Notify('Unlock All spusten.', 5)
            end
        end,
    })
end)

local hitSounds = { Enabled = false, Style = 'Rust HS', Volume = 0.5, Pitch = 1.0 }
local folderName = 'Hitsounds'
local soundFolder = folderName .. '/sounds'

local allSounds = { 'Among Us', 'Bonk', 'Bruh', 'Fart', 'Minecraft', 'Neverlose', 'Osu', 'Stars', 'Rust HS', 'Vine' }
local soundFiles = {
    ['Among Us'] = 'amongus.mp3', ['Bonk'] = 'bonk.mp3', ['Bruh'] = 'bruh.mp3', ['Fart'] = 'fart.mp3',
    ['Minecraft'] = 'minecraft.mp3', ['Neverlose'] = 'neverlose.mp3', ['Osu'] = 'osu.mp3',
    ['Stars'] = 'Stars.mp3', ['Rust HS'] = 'rust hs.mp3', ['Vine'] = 'vine.mp3',
}

safe('Hit Sounds', function()
    local G = Tabs.Misc:AddRightGroupbox('Hit Sounds')

    task.spawn(function()
        if not isfolder(folderName) then makefolder(folderName) end
        if not isfolder(soundFolder) then makefolder(soundFolder) end
        local links = {
            ['amongus.mp3']    = 'https://www.myinstants.com/media/sounds/roblox-death-sound_ytkBL7X.mp3',
            ['minecraft.mp3']  = 'https://www.myinstants.com/media/sounds/steve-old-hurt-sound_XKZxUk4.mp3',
            ['bruh.mp3']       = 'https://www.myinstants.com/media/sounds/discord-notification.mp3',
            ['fart.mp3']       = 'https://www.myinstants.com/media/sounds/fart-moan3.mp3',
            ['neverlose.mp3']  = 'https://www.myinstants.com/media/sounds/neverlose-s.mp3',
            ['rust hs.mp3']    = 'https://www.myinstants.com/media/sounds/eaolwpzhgsba.mp3',
            ['osu.mp3']        = 'https://www.myinstants.com/media/sounds/osu-hit-sound.mp3',
            ['Stars.mp3']      = 'https://www.myinstants.com/media/sounds/starshitsound.mp3',
            ['bonk.mp3']       = 'https://www.myinstants.com/media/sounds/bonk.mp3',
            ['vine.mp3']       = 'https://www.myinstants.com/media/sounds/vine-boom.mp3',
        }
        for filename, link in pairs(links) do
            local fullPath = soundFolder .. '/' .. filename
            if not isfile(fullPath) then
                pcall(function() writefile(fullPath, game:HttpGet(link, true)) end)
                task.wait(0.5)
            end
        end
    end)

    local function playHitSound()
        if not hitSounds.Enabled then return end
        local filename = soundFiles[hitSounds.Style] or soundFiles['Rust HS']
        local fullPath = soundFolder .. '/' .. filename
        if not isfile(fullPath) then return end
        local asset
        pcall(function()
            asset = (getsynasset and getsynasset(fullPath)) or getcustomasset(fullPath)
        end)
        if not asset then return end
        local sound = Instance.new('Sound')
        sound.SoundId = asset
        sound.Volume = hitSounds.Volume
        sound.PlaybackSpeed = hitSounds.Pitch
        sound.Parent = workspace
        sound:Play()
        task.delay(5, function() if sound and sound.Parent then sound:Destroy() end end)
    end

    G:AddToggle('HitSoundsEnabled', { Text = 'Enable', Default = false })
        :OnChanged(function(v) hitSounds.Enabled = v end)
    G:AddDropdown('HitSoundsStyle', { Text = 'Sound', Default = 'Rust HS', Values = allSounds, Multi = false })
        :OnChanged(function(v) hitSounds.Style = v end)
    G:AddSlider('HitSoundsVolume', { Text = 'Volume', Default = 50, Min = 1, Max = 100, Rounding = 0, Compact = true })
        :OnChanged(function(v) hitSounds.Volume = v / 100 end)
    G:AddSlider('HitSoundsPitch', { Text = 'Pitch', Default = 100, Min = 50, Max = 200, Rounding = 0, Compact = true })
        :OnChanged(function(v) hitSounds.Pitch = v / 100 end)

    workspace.DescendantAdded:Connect(function(obj)
        if not hitSounds.Enabled then return end
        if not obj:IsA('BillboardGui') then return end
        if obj.Name == 'FortniteDamageNumber' then return end
        task.defer(function()
            local lbl = obj:FindFirstChildWhichIsA('TextLabel', true)
            if lbl and tonumber(lbl.Text) and tonumber(lbl.Text) > 0 then
                playHitSound()
            end
        end)
    end)
end)

----------------------------------------------------------------
-- SETTINGS
----------------------------------------------------------------
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')

safe('Settings', function()
    MenuGroup:AddButton({ Text = 'Unload', Func = function() Library:Unload() end })

    local WatermarkEnabled = false
    local lastText = ''

    MenuGroup:AddToggle('WatermarkToggle', { Text = 'Show watermark', Default = false })
        :OnChanged(function()
            WatermarkEnabled = Toggles.WatermarkToggle.Value
            Library:SetWatermarkVisibility(WatermarkEnabled)
        end)

    MenuGroup:AddToggle('KeybindListToggle', { Text = 'Show keybind list', Default = false })
        :OnChanged(function()
            Library.KeybindFrame.Visible = Toggles.KeybindListToggle.Value
        end)

    MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
        Default = 'RightShift', NoUI = true, Text = 'Menu keybind',
    })
    Library.ToggleKeybind = Options.MenuKeybind

    task.spawn(function()
        while not Library.Unloaded do
            task.wait(2)
            if WatermarkEnabled then
                local fps = math.floor(1 / RunService.RenderStepped:Wait())
                local ping = 0
                pcall(function() ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue() end)
                local text = ('Rivals | %d fps | %d ms'):format(fps, math.floor(ping))
                if text ~= lastText then
                    lastText = text
                    Library:SetWatermark(text)
                end
            end
        end
    end)
end)

Library:SetWatermarkVisibility(false)
Library.KeybindFrame.Visible = false

Library:OnUnload(function()
    removeAllESP()
    if fovContainer then pcall(function() fovContainer.Parent:Destroy() end) end
    Library.Unloaded = true
end)

----------------------------------------------------------------
-- ADD-ONS
----------------------------------------------------------------
task.spawn(function()
    task.wait(1)
    if Library.Unloaded then return end
    local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
    task.wait()
    if Library.Unloaded then return end
    local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()
    task.wait()
    if Library.Unloaded then return end

    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
    ThemeManager:SetFolder('MyScriptHub')
    SaveManager:SetFolder('MyScriptHub/specific-game')
    task.wait()
    SaveManager:BuildConfigSection(Tabs.Settings)
    task.wait()
    ThemeManager:ApplyToTab(Tabs.Settings)
    task.wait()
    SaveManager:LoadAutoloadConfig()
end)

print('[menu] Nacteno. Menu = RightShift.')

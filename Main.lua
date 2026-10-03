-- ============================================================
-- RIVALS MENU – Main (Silent Aim) | Visuals (ESP) | Settings
-- Bez zombie smyček, bez task.spawn while-loop, vše v getgenv cleanupu.
-- ============================================================

-- === KILL PŘEDCHOZÍ INSTANCE ===
local genv = getgenv and getgenv() or _G

if genv.__RIVALS_KILL then
    pcall(genv.__RIVALS_KILL)
    genv.__RIVALS_KILL = nil
    task.wait(0.3)
end

-- === SLUŽBY ===
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local Stats = game:GetService('Stats')
local UIS = game:GetService('UserInputService')
local LocalPlayer = Players.LocalPlayer

-- === CLEANUP REGISTR ===
local conns = {}
local drawings = {}

genv.__RIVALS_KILL = function()
    for i = #conns, 1, -1 do
        pcall(function() conns[i]:Disconnect() end)
    end
    table.clear(conns)
    for i = #drawings, 1, -1 do
        pcall(function() drawings[i]:Remove() end)
    end
    table.clear(drawings)
    if genv.__RIVALS_LIB then
        pcall(function() genv.__RIVALS_LIB:Unload() end)
        genv.__RIVALS_LIB = nil
    end
end

-- === KNIHOVNA ===
local ok, Library = pcall(function()
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua'))()
end)

if not ok or not Library then
    warn('[menu] Nepodarilo se nacist LinoriaLib')
    return
end

genv.__RIVALS_LIB = Library

local Window = Library:CreateWindow({
    Title = 'Rivals Menu',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0,
})

local Tabs = {}
Tabs.Main = Window:AddTab('Main')
Tabs.Visuals = Window:AddTab('Visuals')
Tabs.Settings = Window:AddTab('Settings')

----------------------------------------------------------------
-- MAIN TAB – SILENT AIM
----------------------------------------------------------------
local SABox = Tabs.Main:AddLeftGroupbox('Silent Aim')

local SA = {
    Enabled = false, AlwaysOn = false, KeyHeld = false,
    FOV = 150, Part = 'Head', TeamCheck = true,
    Target = nil, FovCircle = nil,
}

SABox:AddToggle('SAEnabled', { Text = 'Enable Silent Aim', Default = false })
    :OnChanged(function(v) SA.Enabled = v end)

SABox:AddToggle('SAAlways', { Text = 'Always On (ignore key)', Default = false })
    :OnChanged(function(v) SA.AlwaysOn = v end)

SABox:AddLabel('Aim key'):AddKeyPicker('SAKey', {
    Default = 'E', NoUI = false, Text = 'Aim key', Mode = 'Hold',
})

SABox:AddSlider('SAFOV', { Text = 'FOV (px)', Default = 150, Min = 10, Max = 800, Rounding = 1 })
    :OnChanged(function(v)
        SA.FOV = v
        if SA.FovCircle then SA.FovCircle.Radius = v end
    end)

SABox:AddDropdown('SAPart', {
    Values = { 'Head', 'UpperTorso', 'LowerTorso', 'HumanoidRootPart', 'Torso' },
    Default = 1, Multi = false, Text = 'Target part',
}):OnChanged(function(v) SA.Part = v end)

SABox:AddToggle('SATeam', { Text = 'Team check', Default = true })
    :OnChanged(function(v) SA.TeamCheck = v end)

local fovToggle = SABox:AddToggle('SAFovDraw', { Text = 'Draw FOV circle', Default = true })
fovToggle:OnChanged(function(v)
    if SA.FovCircle then SA.FovCircle.Visible = v and SA.Enabled end
end)
fovToggle:AddColorPicker('SAFovColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'FOV color' })
    :OnChanged(function(c) if SA.FovCircle then SA.FovCircle.Color = c end end)

-- FOV kruh
if Drawing then
    pcall(function()
        SA.FovCircle = Drawing.new('Circle')
        SA.FovCircle.Thickness = 1
        SA.FovCircle.Color = Color3.fromRGB(255, 255, 255)
        SA.FovCircle.Filled = false
        SA.FovCircle.Transparency = 0.7
        SA.FovCircle.NumSides = 64
        SA.FovCircle.Radius = SA.FOV
        SA.FovCircle.Visible = false
        table.insert(drawings, SA.FovCircle)
    end)
end

-- Keybind
local aimKey = Enum.KeyCode.E

table.insert(conns, UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == aimKey then SA.KeyHeld = true end
end))

table.insert(conns, UIS.InputEnded:Connect(function(input)
    if input.KeyCode == aimKey then SA.KeyHeld = false end
end))

if Options and Options.SAKey then
    Options.SAKey:OnChanged(function()
        local v = Options.SAKey.Value
        if type(v) == 'string' then
            local ok2, code = pcall(function() return Enum.KeyCode[v] end)
            if ok2 and code then aimKey = code end
        end
    end)
end

local function isActive()
    if not SA.Enabled then return false end
    if SA.AlwaysOn then return true end
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
                        local part = char:FindFirstChild(SA.Part)
                        if part then
                            local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local d = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
                                if d <= bestDist then
                                    best, bestDist = part, d
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

table.insert(conns, RunService.RenderStepped:Connect(function()
    if SA.FovCircle then
        local cam = workspace.CurrentCamera
        if SA.Enabled and cam then
            local vp = cam.ViewportSize
            SA.FovCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
            SA.FovCircle.Radius = SA.FOV
            SA.FovCircle.Visible = true
        else
            SA.FovCircle.Visible = false
        end
    end

    if isActive() then
        SA.Target = getTarget()
    else
        SA.Target = nil
    end
end))

-- Namecall hook
local oldNamecall
oldNamecall = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
    if SA.Target == nil then
        return oldNamecall(self, ...)
    end

    local method = getnamecallmethod()
    local target = SA.Target

    if not target or not target.Parent then
        return oldNamecall(self, ...)
    end

    local cam = workspace.CurrentCamera
    if not cam then return oldNamecall(self, ...) end

    local camPos = cam.CFrame.Position
    local targetPos = target.Position

    if method == 'ScreenPointToRay' or method == 'ViewportPointToRay' then
        local args = table.pack(...)
        local depth = tonumber(args[3]) or 5000
        return Ray.new(camPos, (targetPos - camPos).Unit * depth)
    end

    if method == 'FindPartOnRay' or method == 'FindPartOnRayWithIgnoreList'
       or method == 'FindPartOnRayWithWhitelist' then
        local args = table.pack(...)
        if typeof(args[1]) == 'Ray' then
            return oldNamecall(self, Ray.new(camPos, targetPos - camPos), table.unpack(args, 2, args.n))
        end
    end

    if method == 'Raycast' or method == 'RaycastAll' then
        local args = table.pack(...)
        if typeof(args[1]) == 'Vector3' and typeof(args[2]) == 'Vector3' then
            return oldNamecall(self, args[1], (targetPos - args[1]).Unit * args[2].Magnitude,
                table.unpack(args, 3, args.n))
        elseif typeof(args[1]) == 'Ray' then
            return oldNamecall(self, Ray.new(args[1].Origin, targetPos - args[1].Origin),
                table.unpack(args, 2, args.n))
        end
    end

    return oldNamecall(self, ...)
end))

-- Obnovení hooku při unloadu
table.insert(conns, { Disconnect = function()
    pcall(function() hookmetamethod(game, '__namecall', oldNamecall) end)
end })

----------------------------------------------------------------
-- VISUALS TAB – ESP
----------------------------------------------------------------
local ESPBox = Tabs.Visuals:AddLeftGroupbox('ESP')
local ESPSettings = Tabs.Visuals:AddRightGroupbox('ESP Settings')

ESPBox:AddToggle('ESPEnabled', { Text = 'Enable ESP', Default = false })
ESPBox:AddDivider()
ESPBox:AddToggle('ESPBox', { Text = 'Box', Default = true })
    :AddColorPicker('ESPBoxColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Box color' })
ESPBox:AddToggle('ESPSkeleton', { Text = 'Skeleton', Default = true })
    :AddColorPicker('ESPSkeletonColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Skeleton color' })
ESPBox:AddToggle('ESPName', { Text = 'Name', Default = true })
    :AddColorPicker('ESPNameColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Name color' })
ESPBox:AddToggle('ESPDist', { Text = 'Distance', Default = true })
    :AddColorPicker('ESPDistColor', { Default = Color3.fromRGB(200, 200, 200), Title = 'Distance color' })
ESPBox:AddToggle('ESPHealth', { Text = 'Health bar', Default = true })
ESPBox:AddToggle('ESPHealthText', { Text = 'Health number', Default = true })
    :AddColorPicker('ESPHealthTextColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Health number color' })
ESPBox:AddToggle('ESPWeapon', { Text = 'Held weapon', Default = true })
    :AddColorPicker('ESPWeaponColor', { Default = Color3.fromRGB(255, 220, 120), Title = 'Weapon color' })

ESPSettings:AddToggle('ESPTeamCheck', { Text = 'Hide teammates', Default = false })

-- ESP logika
local ESP_TOGGLES = { 'ESPBox', 'ESPSkeleton', 'ESPName', 'ESPDist', 'ESPHealth', 'ESPHealthText', 'ESPWeapon' }
local HAS_DRAWING = (Drawing ~= nil)

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

local function newText(size)
    local t = Drawing.new('Text')
    t.Size = size
    t.Center = true
    t.Outline = true
    t.Visible = false
    table.insert(drawings, t)
    return t
end

local function createESP(player)
    local obj = {
        boxOutline = Drawing.new('Square'),
        box = Drawing.new('Square'),
        hpOutline = Drawing.new('Square'),
        hpBar = Drawing.new('Square'),
        name = newText(13),
        dist = newText(12),
        weapon = newText(12),
        hpText = newText(11),
        bones = {},
    }
    for _, d in pairs({ obj.boxOutline, obj.box, obj.hpOutline, obj.hpBar }) do
        table.insert(drawings, d)
    end
    obj.boxOutline.Thickness = 3
    obj.boxOutline.Filled = false
    obj.boxOutline.Color = Color3.new(0, 0, 0)
    obj.box.Thickness = 1
    obj.box.Filled = false
    obj.hpOutline.Filled = true
    obj.hpOutline.Color = Color3.new(0, 0, 0)
    obj.hpBar.Filled = true
    for i = 1, #R15_BONES do
        local line = Drawing.new('Line')
        line.Thickness = 1
        line.Visible = false
        obj.bones[i] = line
        table.insert(drawings, line)
    end
    ESP[player] = obj
    return obj
end

local function hideESP(obj)
    obj.box.Visible = false
    obj.boxOutline.Visible = false
    obj.hpOutline.Visible = false
    obj.hpBar.Visible = false
    obj.hpText.Visible = false
    obj.name.Visible = false
    obj.dist.Visible = false
    obj.weapon.Visible = false
    for i = 1, #obj.bones do obj.bones[i].Visible = false end
end

local function removeESP(player)
    local obj = ESP[player]
    if not obj then return end
    for key, d in next, obj do
        if key == 'bones' then
            for i = 1, #d do pcall(function() d[i]:Remove() end) end
        else
            pcall(function() d:Remove() end)
        end
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
    local showBox, showSkel = Toggles.ESPBox.Value, Toggles.ESPSkeleton.Value
    local showName, showDist = Toggles.ESPName.Value, Toggles.ESPDist.Value
    local showHP, showHPText = Toggles.ESPHealth.Value, Toggles.ESPHealthText.Value
    local showWeapon = Toggles.ESPWeapon.Value
    local teamCheck = Toggles.ESPTeamCheck.Value
    local boxColor, skelColor = Options.ESPBoxColor.Value, Options.ESPSkeletonColor.Value
    local nameColor, distColor = Options.ESPNameColor.Value, Options.ESPDistColor.Value
    local hpTextColor, weaponColor = Options.ESPHealthTextColor.Value, Options.ESPWeaponColor.Value

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
                    obj.boxOutline.Size = Vector2.new(w, h)
                    obj.boxOutline.Position = Vector2.new(x, y)
                    obj.boxOutline.Visible = true
                    obj.box.Size = Vector2.new(w, h)
                    obj.box.Position = Vector2.new(x, y)
                    obj.box.Color = boxColor
                    obj.box.Visible = true
                else
                    obj.box.Visible = false
                    obj.boxOutline.Visible = false
                end

                if showName then
                    obj.name.Text = player.DisplayName
                    obj.name.Position = Vector2.new(pos.X, y - 16)
                    obj.name.Color = nameColor
                    obj.name.Visible = true
                else
                    obj.name.Visible = false
                end

                local frac = 0
                if showHP or showHPText then
                    local maxHP = hum.MaxHealth > 0 and hum.MaxHealth or 100
                    frac = math.clamp(hum.Health / maxHP, 0, 1)
                end
                if showHP then
                    local fillH = math.max(h * frac, 1)
                    obj.hpOutline.Size = Vector2.new(4, h + 2)
                    obj.hpOutline.Position = Vector2.new(x - 7, y - 1)
                    obj.hpOutline.Visible = true
                    obj.hpBar.Size = Vector2.new(2, fillH)
                    obj.hpBar.Position = Vector2.new(x - 6, y + h - fillH)
                    obj.hpBar.Color = Color3.fromRGB(255 * (1 - frac), 255 * frac, 0)
                    obj.hpBar.Visible = true
                else
                    obj.hpOutline.Visible = false
                    obj.hpBar.Visible = false
                end
                if showHPText then
                    local fillH = h * frac
                    obj.hpText.Text = tostring(math.floor(hum.Health))
                    obj.hpText.Position = Vector2.new(x - 16, y + h - fillH - 6)
                    obj.hpText.Color = hpTextColor
                    obj.hpText.Visible = true
                else
                    obj.hpText.Visible = false
                end

                local by = y + h + 1
                local weaponName = showWeapon and getWeaponName(player, char) or nil
                if weaponName then
                    obj.weapon.Text = weaponName
                    obj.weapon.Position = Vector2.new(pos.X, by)
                    obj.weapon.Color = weaponColor
                    obj.weapon.Visible = true
                    by = by + 13
                else
                    obj.weapon.Visible = false
                end
                if showDist then
                    obj.dist.Text = ('%dm'):format(math.floor((root.Position - camPos).Magnitude))
                    obj.dist.Position = Vector2.new(pos.X, by)
                    obj.dist.Color = distColor
                    obj.dist.Visible = true
                else
                    obj.dist.Visible = false
                end

                if showSkel then
                    local list = hum.RigType == Enum.HumanoidRigType.R15 and R15_BONES or R6_BONES
                    for i = 1, #list do
                        local line = obj.bones[i]
                        local a, b = char:FindFirstChild(list[i][1]), char:FindFirstChild(list[i][2])
                        if a and b then
                            local pa, va = cam:WorldToViewportPoint(a.Position)
                            local pb, vb = cam:WorldToViewportPoint(b.Position)
                            if va and vb then
                                line.From = Vector2.new(pa.X, pa.Y)
                                line.To = Vector2.new(pb.X, pb.Y)
                                line.Color = skelColor
                                line.Visible = true
                            else
                                line.Visible = false
                            end
                        else
                            line.Visible = false
                        end
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
        if Toggles[ESP_TOGGLES[i]].Value then anyFeature = true break end
    end
    local active = Toggles.ESPEnabled.Value and anyFeature

    if active and not espConn then
        if not HAS_DRAWING then
            Library:Notify('Drawing library neni dostupna.', 5)
            Toggles.ESPEnabled:SetValue(false)
            return
        end
        local lastErr
        espConn = RunService.RenderStepped:Connect(function()
            local ok, err = pcall(updateESP)
            if not ok and err ~= lastErr then
                lastErr = err
                warn('[menu] ESP error: ' .. tostring(err))
            end
        end)
        table.insert(conns, espConn)
    elseif not active and espConn then
        pcall(function() espConn:Disconnect() end)
        espConn = nil
        removeAllESP()
    end
end

Toggles.ESPEnabled:OnChanged(refreshESP)
for i = 1, #ESP_TOGGLES do
    Toggles[ESP_TOGGLES[i]]:OnChanged(refreshESP)
end

table.insert(conns, Players.PlayerRemoving:Connect(removeESP))

----------------------------------------------------------------
-- SETTINGS
----------------------------------------------------------------
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')

MenuGroup:AddButton({
    Text = 'Unload',
    Func = function() Library:Unload() end,
})

local WatermarkEnabled = false
local lastText = ''

MenuGroup:AddToggle('WatermarkToggle', { Text = 'Show watermark', Default = false })
Toggles.WatermarkToggle:OnChanged(function()
    WatermarkEnabled = Toggles.WatermarkToggle.Value
    Library:SetWatermarkVisibility(WatermarkEnabled)
end)

MenuGroup:AddToggle('KeybindListToggle', { Text = 'Show keybind list', Default = false })
Toggles.KeybindListToggle:OnChanged(function()
    Library.KeybindFrame.Visible = Toggles.KeybindListToggle.Value
end)

MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'RightShift', NoUI = true, Text = 'Menu keybind',
})

Library.ToggleKeybind = Options.MenuKeybind

-- Watermark updater (bez task.spawn while – přes Heartbeat s kontrolou)
local wmAcc = 0
table.insert(conns, RunService.Heartbeat:Connect(function(dt)
    if not WatermarkEnabled then return end
    wmAcc = wmAcc + dt
    if wmAcc < 2 then return end
    wmAcc = 0
    local ok, fps = pcall(function() return math.floor(1 / RunService.RenderStepped:Wait()) end)
    local ping = 0
    pcall(function() ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue() end)
    local text = ('LinoriaLib | %d fps | %d ms'):format(fps or 0, math.floor(ping))
    if text ~= lastText then
        lastText = text
        Library:SetWatermark(text)
    end
end))

Library:SetWatermarkVisibility(false)
Library.KeybindFrame.Visible = false

Library:OnUnload(function()
    pcall(genv.__RIVALS_KILL)
end)

print('[menu] Nacteno. Menu = RightShift.')

----------------------------------------------------------------
-- MAIN TAB – SILENT AIM (vložit za log('Main tab built'))
----------------------------------------------------------------
local UIS = game:GetService('UserInputService')

-- Konfigurační tabulka silent aimu
local SilentAim = {
    Enabled   = false,   -- hlavní vypínač
    AlwaysOn  = false,   -- ignorovat klávesu a mířit neustále
    KeyHeld   = false,   -- je klávesa právě stisknutá?
    Key       = 'E',     -- výchozí klávesa (záložní, primárně se čte z KeyPickeru)
    FOV       = 150,     -- poloměr FOV v pixelech od středu obrazovky
    Part      = 'Head',  -- cílová část těla
    TeamCheck = true,    -- ignorovat spoluhráče
    WallCheck = false,   -- ignorovat hráče za zdí
    ShowFOV   = true,    -- kreslit kruh FOV
    Target    = nil,     -- cachovaný cíl aktuálního framu
}

-- Převede název klávesy ("E") na Enum.KeyCode
local function keyCodeFromName(name)
    local ok, code = pcall(function() return Enum.KeyCode[name] end)
    if ok then return code end
    return nil
end

-- Vrátí aktuálně nastavenou klávesu z KeyPickeru (fallback na výchozí)
local function currentKey()
    local opt = Options and Options.SAKey
    if opt and type(opt.Value) == 'string' then return opt.Value end
    return SilentAim.Key
end

-- Sledování stisku / uvolnění klávesy
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if Library and Library.Open then return end -- ignorovat psaní do menu
    local code = keyCodeFromName(currentKey())
    if code and input.KeyCode == code then
        SilentAim.KeyHeld = true
    end
end)

UIS.InputEnded:Connect(function(input, gp)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local code = keyCodeFromName(currentKey())
    if code and input.KeyCode == code then
        SilentAim.KeyHeld = false
    end
end)

-- Je silent aim právě aktivní?
local function isActive()
    if not SilentAim.Enabled then return false end
    if SilentAim.AlwaysOn then return true end
    return SilentAim.KeyHeld
end

-- Vybere nejbližší platný cíl v rámci FOV (střed obrazovky)
local function getTargetPart()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local origin = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local camPos = cam.CFrame.Position
    local bestPart, bestDist = nil, SilentAim.FOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChildOfClass('Humanoid')
                if hum and hum.Health > 0 then
                    local skip = false
                    -- Kontrola týmu
                    if SilentAim.TeamCheck and plr.Team and LocalPlayer.Team
                       and plr.Team == LocalPlayer.Team then
                        skip = true
                    end
                    if not skip then
                        local part = char:FindFirstChild(SilentAim.Part)
                        if part then
                            local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local d = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
                                if d <= bestDist then
                                    -- Kontrola zdí
                                    if SilentAim.WallCheck then
                                        local params = RaycastParams.new()
                                        params.FilterType = Enum.RaycastFilterType.Exclude
                                        params.FilterDescendantsInstances = { LocalPlayer.Character, cam }
                                        local res = workspace:Raycast(camPos, part.Position - camPos, params)
                                        if res and not res.Instance:IsDescendantOf(char) then
                                            skip = true
                                        end
                                    end
                                    if not skip then
                                        bestPart, bestDist = part, d
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestPart
end

----------------------------------------------------------------
-- UI PRO SILENT AIM (přidáno do pravého sloupce záložky Main)
----------------------------------------------------------------
local SAGroup = Tabs.Main:AddRightGroupbox('Silent Aim')

SAGroup:AddToggle('SAEnabled', {
    Text = 'Zapnout silent aim',
    Default = false,
    Tooltip = 'Hlavní vypínač silent aimu',
}):OnChanged(function(v) SilentAim.Enabled = v end)

SAGroup:AddToggle('SAAlways', {
    Text = 'Vždy aktivní (ignorovat klávesu)',
    Default = false,
}):OnChanged(function(v) SilentAim.AlwaysOn = v end)

SAGroup:AddKeyPicker('SAKey', {
    Default = 'E',
    NoUI = false,
    Text = 'Klávesa míření',
    Mode = 'Hold',
})

SAGroup:AddSlider('SAFOV', {
    Text = 'FOV (px)',
    Default = 150,
    Min = 10,
    Max = 800,
    Rounding = 0,
    Compact = false,
}):OnChanged(function(v) SilentAim.FOV = v end)

SAGroup:AddDropdown('SAPart', {
    Values = { 'Head', 'UpperTorso', 'LowerTorso', 'HumanoidRootPart', 'Torso' },
    Default = 1,
    Multi = false,
    Text = 'Cílová část',
}):OnChanged(function(v) SilentAim.Part = v end)

SAGroup:AddToggle('SATeam', {
    Text = 'Kontrola týmu',
    Default = true,
}):OnChanged(function(v) SilentAim.TeamCheck = v end)

SAGroup:AddToggle('SAWall', {
    Text = 'Kontrola zdí (viditelnost)',
    Default = false,
}):OnChanged(function(v) SilentAim.WallCheck = v end)

SAGroup:AddToggle('SAFovDraw', {
    Text = 'Kreslit FOV kruh',
    Default = true,
}):OnChanged(function(v) SilentAim.ShowFOV = v end)

----------------------------------------------------------------
-- FOV KRUH (Drawing)
----------------------------------------------------------------
local fovCircle
if Drawing then
    fovCircle = Drawing.new('Circle')
    fovCircle.Thickness = 1
    fovCircle.Color = Color3.fromRGB(255, 255, 255)
    fovCircle.Filled = false
    fovCircle.Transparency = 0.7
    fovCircle.NumSides = 64
    fovCircle.Radius = SilentAim.FOV
    fovCircle.Visible = false
end

local fovConn = RunService.RenderStepped:Connect(function()
    -- Cachování cíle pro aktuální frame (aby se nevolalo při každém raycastu)
    if isActive() then
        SilentAim.Target = getTargetPart()
    else
        SilentAim.Target = nil
    end

    -- Vykreslení FOV kruhu
    if fovCircle then
        local cam = workspace.CurrentCamera
        if SilentAim.Enabled and SilentAim.ShowFOV and cam then
            local vp = cam.ViewportSize
            fovCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
            fovCircle.Radius = SilentAim.FOV
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end
end)

----------------------------------------------------------------
-- METATABLE HOOK – přesměrování paprsků na cachovaný cíl
----------------------------------------------------------------
local oldNamecall
oldNamecall = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if SilentAim.Target ~= nil then
        local target = SilentAim.Target

        -- 1) Paprsek z kamery (ScreenPointToRay / ViewportPointToRay)
        if method == 'ScreenPointToRay' or method == 'ViewportPointToRay' then
            local cam = workspace.CurrentCamera
            if cam then
                local camPos = cam.CFrame.Position
                local dir = target.Position - camPos
                if dir.Magnitude > 0 then
                    local args = { ... }
                    local depth = tonumber(args[3]) or 5000
                    return Ray.new(camPos, dir.Unit * depth)
                end
            end
        end

        -- 2) Přímé raycasty (Raycast / FindPartOnRay*)
        if method == 'Raycast'
           or method == 'FindPartOnRay'
           or method == 'FindPartOnRayWithIgnoreList'
           or method == 'FindPartOnRayWithWhitelist' then
            local cam = workspace.CurrentCamera
            if cam then
                local camPos = cam.CFrame.Position
                local args = { ... }
                if typeof(args[1]) == 'Ray' then
                    args[1] = Ray.new(camPos, target.Position - camPos)
                    return oldNamecall(self, table.unpack(args))
                end
            end
        end
    end

    return oldNamecall(self, ...)
end))

log('Silent aim ready')

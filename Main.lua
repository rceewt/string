-- OPRAVA: Debug vypis byl POUZE uvnitř RenderStepped a aktivoval se jen když
-- bylo zapnuté Debug toggle. Přidávám okamžitý debug print při startu skriptu
-- a externí heartbeat smyčku, která vypisuje stav každou sekundu bez ohledu na
-- to, jestli běží RenderStepped.

-- NAHRAĎ v předchozím skriptu tuto sekci:

-- ============================================================
-- NAJDI V SKRIPTU TENTO BLOK:
-- ============================================================
-- local lastDbg = 0
-- local silentAimConn = RunService.RenderStepped:Connect(function()
--     ...
--     if SilentAim.Debug and tick() - lastDbg > 1 then
--         lastDbg = tick()
--         ...
--     end
-- end)
-- addCleanup(function() silentAimConn:Disconnect() end)

-- ============================================================
-- A NAHRAĎ HO TÍMTO:
-- ============================================================

-- Okamžitý testovací výpis při spuštění
print('[SA] === Silent Aim nacten ===')
print('[SA] Executor ma Drawing:', tostring(Drawing ~= nil))
print('[SA] Executor ma hookmetamethod:', tostring(hookmetamethod ~= nil))
print('[SA] Executor ma getnamecallmethod:', tostring(getnamecallmethod ~= nil))
print('[SA] Executor ma hookfunction:', tostring(hookfunction ~= nil))
print('[SA] LocalPlayer:', LocalPlayer and LocalPlayer.Name or 'NIL')
print('[SA] CurrentCamera:', tostring(workspace.CurrentCamera ~= nil))

local lastDbg = 0
local silentAimConn = RunService.RenderStepped:Connect(function()
    if fovCircle then
        local cam = workspace.CurrentCamera
        if SilentAim.Enabled and SilentAim.ShowFOV and cam then
            local vp = cam.ViewportSize
            fovCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
            fovCircle.Radius = SilentAim.FOV
            if Options.SAFovColor then fovCircle.Color = Options.SAFovColor.Value end
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end

    if isActive() then
        SilentAim.Target = getTargetPart()
    else
        SilentAim.Target = nil
    end
end)
addCleanup(function() silentAimConn:Disconnect() end)

-- ============================================================
-- NEZÁVISLÁ DEBUG SMYČKA – běží vždy, nezávisle na RenderStepped
-- ============================================================
task.spawn(function()
    while not Library.Unloaded do
        task.wait(1)
        if SilentAim.Debug then
            local status = SilentAim.Enabled and 'ON' or 'OFF'
            local tgt = SilentAim.Target and SilentAim.Target:GetFullName() or 'zadny'
            local active = isActive() and 'ANO' or 'NE'
            print(('[SA] Enabled=%s | KeyHeld=%s | Aktivni=%s | Target=%s'):format(
                status, tostring(SilentAim.KeyHeld), active, tgt))
        end
    end
end)

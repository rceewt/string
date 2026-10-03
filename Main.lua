-- ============================================================
-- BEZPEČNÁ VERZE – kompletní přepis silent aim bloku
-- Příčina crashe: namecall hook volal getnamecallmethod() a table.unpack()
-- na každé volání ve hře. Při velkém args došlo k přetečení.
-- OPRAVA: vše v pcall, žádný getnamecallmethod mimo pcall, žádný unpack velkých tabulek.
-- ============================================================

-- NAHRAĎ CELÝ BLOK od "local oldNamecall" až po "log('Silent aim ready')" TÍMTO:

local oldNamecall
oldNamecall = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
    -- Pokud silent aim nemá cíl, okamžitě se vrať bez jakékoliv práce
    if SilentAim.Target == nil then
        return oldNamecall(self, ...)
    end

    -- Vše v pcall, aby jakákoliv chyba nezpůsobila crash
    local ok, result = pcall(function()
        local method = getnamecallmethod()
        local target = SilentAim.Target

        -- Cíl mohl být mezitím zničen
        if not target or not target.Parent then
            return nil
        end

        local targetPos = target.Position

        -- 1) ScreenPointToRay / ViewportPointToRay
        if method == 'ScreenPointToRay' or method == 'ViewportPointToRay' then
            local cam = workspace.CurrentCamera
            if cam then
                local camPos = cam.CFrame.Position
                local dir = targetPos - camPos
                if dir.Magnitude > 0 then
                    local args = table.pack(...)
                    local depth = tonumber(args[3]) or 5000
                    return Ray.new(camPos, dir.Unit * depth)
                end
            end
        end

        -- 2) FindPartOnRay* – pouze pokud args[1] je Ray
        if method == 'FindPartOnRay' or method == 'FindPartOnRayWithIgnoreList'
           or method == 'FindPartOnRayWithWhitelist' then
            local cam = workspace.CurrentCamera
            if cam then
                local args = table.pack(...)
                if typeof(args[1]) == 'Ray' then
                    local newRay = Ray.new(cam.CFrame.Position, targetPos - cam.CFrame.Position)
                    return oldNamecall(self, newRay, table.unpack(args, 2, args.n))
                end
            end
        end

        -- 3) Raycast / RaycastAll – Vector3 origin, Vector3 direction
        if method == 'Raycast' or method == 'RaycastAll' then
            local args = table.pack(...)
            if typeof(args[1]) == 'Vector3' and typeof(args[2]) == 'Vector3' then
                local newDir = targetPos - args[1]
                if newDir.Magnitude > 0 and args[2].Magnitude > 0 then
                    local finalDir = newDir.Unit * args[2].Magnitude
                    return oldNamecall(self, args[1], finalDir, table.unpack(args, 3, args.n))
                end
            elseif typeof(args[1]) == 'Ray' then
                local newRay = Ray.new(args[1].Origin, targetPos - args[1].Origin)
                return oldNamecall(self, newRay, table.unpack(args, 2, args.n))
            end
        end

        return nil
    end)

    -- Pokud pcall uspěl a vrátil hodnotu, použij ji
    if ok and result ~= nil then
        return result
    end

    -- Jinak zavolej původní metodu beze změny
    return oldNamecall(self, ...)
end))

addCleanup(function()
    pcall(function()
        hookmetamethod(game, '__namecall', oldNamecall)
    end)
end)

log('Silent aim ready')

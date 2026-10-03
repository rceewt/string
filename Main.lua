-- LinoriaLib menu: Main | Visuals (ESP) | Settings
-- Startup-optimized: add-ons load in the background, UI built in stages

local t0 = tick()
local function log(step) print(('[menu] %-28s %.2fs'):format(step, tick() - t0)) end

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local env = getgenv and getgenv() or _G
if env.__MenuLibrary then
	pcall(function() env.__MenuLibrary:Unload() end) -- remove the previous instance first
end

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
env.__MenuLibrary = Library
log('Library loaded')

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local Stats = game:GetService('Stats')
local LocalPlayer = Players.LocalPlayer

local Window = Library:CreateWindow({
	Title = 'Example menu',
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
-- MAIN TAB (kept light on purpose: fewer UI objects = faster startup)
----------------------------------------------------------------
local LeftGroupBox = Tabs.Main:AddLeftGroupbox('Groupbox')

LeftGroupBox:AddToggle('MyToggle', { Text = 'This is a toggle', Default = true, Tooltip = 'This is a tooltip' })

LeftGroupBox:AddButton({
	Text = 'Button',
	Func = function() print('You clicked a button!') end,
	Tooltip = 'This is the main button',
})

LeftGroupBox:AddLabel('This is a label')
LeftGroupBox:AddDivider()
LeftGroupBox:AddSlider('MySlider', { Text = 'This is my slider!', Default = 0, Min = 0, Max = 5, Rounding = 1, Compact = false })
LeftGroupBox:AddDropdown('MyDropdown', { Values = { 'This', 'is', 'a', 'dropdown' }, Default = 1, Multi = false, Text = 'A dropdown' })

log('Main tab built')
task.wait() -- let the game render a frame

local ESPCleanup = function() end
local espOk, espErr = pcall(function()
	----------------------------------------------------------------
	-- VISUALS TAB (ESP UI)
	----------------------------------------------------------------
	local ESPGroup = Tabs.Visuals:AddLeftGroupbox('ESP')
	local ESPSettings = Tabs.Visuals:AddRightGroupbox('ESP Settings')

	ESPGroup:AddToggle('ESPEnabled', { Text = 'Enable ESP', Default = false, Tooltip = 'Master switch' })
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
		:AddColorPicker('ESPHealthTextColor', { Default = Color3.fromRGB(255, 255, 255), Title = 'Health number color' })
	ESPGroup:AddToggle('ESPWeapon', { Text = 'Held weapon', Default = true })
		:AddColorPicker('ESPWeaponColor', { Default = Color3.fromRGB(255, 220, 120), Title = 'Weapon color' })

	ESPSettings:AddToggle('ESPTeamCheck', { Text = 'Hide teammates', Default = false })

	log('Visuals tab built')
	task.wait()

	----------------------------------------------------------------
	-- ESP LOGIC (unlimited distance)
	----------------------------------------------------------------
	local HAS_DRAWING = (Drawing ~= nil)

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

	-- Where games commonly store the equipped weapon name (Tool first, then attributes)
	local WEAPON_ATTRS = { 'EquippedWeapon', 'CurrentWeapon', 'Weapon', 'Equipped' }

	local ESP = {} -- [player] = drawing objects, created lazily
	local espConn

	local function safeRemove(d)
		pcall(function() d:Remove() end)
	end

	local function newText(size)
		local t = Drawing.new('Text')
		t.Size = size
		t.Center = true
		t.Outline = true
		t.Visible = false
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
				for i = 1, #d do safeRemove(d[i]) end
			else
				safeRemove(d)
			end
		end
		ESP[player] = nil
	end

	local function removeAllESP()
		for player in next, ESP do removeESP(player) end
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

					-- Box
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

					-- Name (above the box)
					if showName then
						obj.name.Text = player.DisplayName
						obj.name.Position = Vector2.new(pos.X, y - 16)
						obj.name.Color = nameColor
						obj.name.Visible = true
					else
						obj.name.Visible = false
					end

					-- Health bar (left of the box) + number
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

					-- Text under the box: weapon, then distance
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

					-- Skeleton
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

	-- Only runs while ESP is on; frees all drawings when off
	local function refreshESP()
		local anyFeature = false
		for i = 1, #ESP_TOGGLES do
			if Toggles[ESP_TOGGLES[i]].Value then anyFeature = true break end
		end
		local active = Toggles.ESPEnabled.Value and anyFeature

		if active and not espConn then
			if not HAS_DRAWING then
				Library:Notify('Your executor does not support the Drawing library, ESP unavailable.', 5)
				Toggles.ESPEnabled:SetValue(false)
				return
			end
			local lastErr
			espConn = RunService.RenderStepped:Connect(function()
				local ok, err = pcall(updateESP)
				if not ok and err ~= lastErr then
					lastErr = err
					warn('[menu] ESP error: ' .. tostring(err))
					Library:Notify('ESP error: ' .. tostring(err), 10)
				end
			end)
		elseif not active and espConn then
			espConn:Disconnect()
			espConn = nil
			removeAllESP()
		end
	end

	Toggles.ESPEnabled:OnChanged(refreshESP)
	for i = 1, #ESP_TOGGLES do
		Toggles[ESP_TOGGLES[i]]:OnChanged(refreshESP)
	end

	local removingConn = Players.PlayerRemoving:Connect(removeESP)


	ESPCleanup = function()
		if espConn then espConn:Disconnect() espConn = nil end
		removingConn:Disconnect()
		removeAllESP()
	end
end)
if not espOk then
	warn('[menu] ESP failed to load: ' .. tostring(espErr))
	Library:Notify('ESP failed to load: ' .. tostring(espErr), 15)
end

----------------------------------------------------------------
-- WATERMARK (no per-frame connection, off by default)
----------------------------------------------------------------
Library:SetWatermarkVisibility(false)
Library.KeybindFrame.Visible = false

local WatermarkEnabled = false
local lastText = ''

task.spawn(function()
	while not Library.Unloaded do
		task.wait(2)
		if WatermarkEnabled then
			local fps = math.floor(1 / RunService.RenderStepped:Wait())
			local ping = 0
			pcall(function() ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue() end)
			local text = ('LinoriaLib | %d fps | %d ms'):format(fps, math.floor(ping))
			if text ~= lastText then
				lastText = text
				Library:SetWatermark(text)
			end
		end
	end
end)

Library:OnUnload(function()
	ESPCleanup()
	Library.Unloaded = true
end)

----------------------------------------------------------------
-- SETTINGS
----------------------------------------------------------------
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')

MenuGroup:AddButton({
	Text = 'Unload',
	Func = function() Library:Unload() end,
	Tooltip = 'Fully removes the script',
})

MenuGroup:AddToggle('WatermarkToggle', { Text = 'Show watermark', Default = false })
Toggles.WatermarkToggle:OnChanged(function()
	WatermarkEnabled = Toggles.WatermarkToggle.Value
	Library:SetWatermarkVisibility(WatermarkEnabled)
end)

MenuGroup:AddToggle('KeybindListToggle', { Text = 'Show keybind list', Default = false })
Toggles.KeybindListToggle:OnChanged(function()
	Library.KeybindFrame.Visible = Toggles.KeybindListToggle.Value
end)

MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind

log('Menu ready')

-- Heavy add-ons load AFTER the menu is visible, one step per frame
task.spawn(function()
	task.wait(1)
	local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
	log('ThemeManager loaded')
	task.wait()
	local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()
	log('SaveManager loaded')
	task.wait()

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
	log('Add-ons ready')
end)

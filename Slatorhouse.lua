-- ROCKET — ESP Roles + Speed + FOV + No Fog + Menu + Icon
-- Команда Rocket Way | 20.05.2026
-- Delta / Arceus X / Fluxus Mobile / Hydrogen

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ВСТАВЬ ASSET ID СВОЕЙ КАРТИНКИ. Если 0 — фиолетовый круг с R
local ICON_ID = "rbxassetid://0"

-- ================== КОНФИГ ==================
local Config = {
    ESP = {
        Enabled = true, Box = true, Name = true,
        Distance = true, Health = true, Tracer = false,
        Colors = {
            Killer   = Color3.fromRGB(255, 50, 50),   -- маньяк — красный
            Survivor = Color3.fromRGB(0, 255, 80),    -- выживший — зелёный
            Unknown  = Color3.fromRGB(255, 255, 255), -- неизвестно — белый
            Local    = Color3.fromRGB(80, 180, 255),  -- ты — голубой
        },
    },
    Speed = { Enabled = false, Speed = 40, Default = 16, InfJump = false },
    FOV = { Enabled = false, FOV = 110, Default = 70 },
    Fog = {
        Enabled = false, FullBright = false, _saved = false,
        _origFogEnd=nil,_origFogStart=nil,_origFogColor=nil,
        _origBrightness=nil,_origOutdoorAmbient=nil,_origAtmos={},
    },
}

-- ================== ОПРЕДЕЛЕНИЕ РОЛИ ==================
local KILLER_KW = {
    "killer","murderer","murder","assassin","slasher","zombie",
    "monster","beast","hunter","mafia","impostor","traitor",
    "infected","enemy","serial",
}
local SURVIVOR_KW = {
    "survivor","innocent","crewmate","hider","civilian","runner",
    "human","hero","sheriff","runner",
}

local function hasAny(s, list)
    if not s then return false end
    s = string.lower(s)
    for _, k in ipairs(list) do
        if string.find(s, k, 1, true) then return true end
    end
    return false
end

local function roleOf(plr)
    if plr == LocalPlayer then return "Local" end

    -- 1. Attributes игрока
    for _, a in ipairs({"Role","role","Team","team","Class","class","Type","type"}) do
        local ok, v = pcall(function() return plr:GetAttribute(a) end)
        if ok and typeof(v) == "string" then
            if hasAny(v, KILLER_KW) then return "Killer" end
            if hasAny(v, SURVIVOR_KW) then return "Survivor" end
        end
    end

    -- 2. Attributes персонажа
    local ch = plr.Character
    if ch then
        for _, a in ipairs({"Role","role","Team","team"}) do
            local ok, v = pcall(function() return ch:GetAttribute(a) end)
            if ok and typeof(v) == "string" then
                if hasAny(v, KILLER_KW) then return "Killer" end
                if hasAny(v, SURVIVOR_KW) then return "Survivor" end
            end
        end
    end

    -- 3. Team
    if plr.Team then
        local n = plr.Team.Name
        if hasAny(n, KILLER_KW) then return "Killer" end
        if hasAny(n, SURVIVOR_KW) then return "Survivor" end
    end

    -- 4. leaderstats
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        for _, st in ipairs(ls:GetChildren()) do
            if typeof(st.Value) == "string" then
                if hasAny(st.Value, KILLER_KW) then return "Killer" end
                if hasAny(st.Value, SURVIVOR_KW) then return "Survivor" end
            end
            if hasAny(st.Name, {"Role","Team","Class"}) then
                local sv = tostring(st.Value)
                if hasAny(sv, KILLER_KW) then return "Killer" end
                if hasAny(sv, SURVIVOR_KW) then return "Survivor" end
            end
        end
    end

    -- 5. Tool в руках
    if ch then
        local t = ch:FindFirstChildOfClass("Tool")
        if t then
            if hasAny(t.Name, KILLER_KW) then return "Killer" end
            if hasAny(t.Name, {"knife","sword","blade"}) then return "Killer" end
        end
    end

    return "Unknown"
end

local function colorOf(plr)
    local r = roleOf(plr)
    return Config.ESP.Colors[r] or Config.ESP.Colors.Unknown
end

-- ================== SPEED (легит) ==================
local function getHum()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
    local h = getHum()
    if h then
        h.WalkSpeed = Config.Speed.Enabled and Config.Speed.Speed or Config.Speed.Default
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    applySpeed()
end)

UserInputService.JumpRequest:Connect(function()
    if Config.Speed.InfJump then
        local h = getHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

RunService.Heartbeat:Connect(function()
    if Config.Speed.Enabled then
        local h = getHum()
        if h and h.WalkSpeed ~= Config.Speed.Speed then
            h.WalkSpeed = Config.Speed.Speed
        end
    end
end)

-- ================== FOV / FOG ==================
local function applyFOV()
    if Camera then
        Camera.FieldOfView = Config.FOV.Enabled and Config.FOV.FOV or Config.FOV.Default
    end
end

local function saveOrigFog()
    if Config.Fog._saved then return end
    Config.Fog._origFogEnd = Lighting.FogEnd
    Config.Fog._origFogStart = Lighting.FogStart
    Config.Fog._origFogColor = Lighting.FogColor
    Config.Fog._origBrightness = Lighting.Brightness
    Config.Fog._origOutdoorAmbient = Lighting.OutdoorAmbient
    for _, o in ipairs(Lighting:GetChildren()) do
        if o:IsA("Atmosphere") then
            table.insert(Config.Fog._origAtmos, {obj=o,Density=o.Density,Haze=o.Haze,Glare=o.Glare,Color=o.Color})
        end
    end
    Config.Fog._saved = true
end

local function killFog()
    saveOrigFog()
    Lighting.FogEnd = 100000
    Lighting.FogStart = 100000
    Lighting.FogColor = Color3.fromRGB(255,255,255)
    Lighting.Brightness = math.max(Lighting.Brightness, 2)
    Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
    for _, o in ipairs(Lighting:GetChildren()) do
        if o:IsA("Atmosphere") then
            o.Density=0; o.Haze=0; o.Glare=0; o.Color=Color3.fromRGB(255,255,255)
        end
        if o:IsA("DepthOfFieldEffect") then o.Enabled=false end
        if o:IsA("BlurEffect") then o.Enabled=false end
        if o:IsA("SunRaysEffect") then o.Intensity=0 end
    end
end

local function restoreFog()
    if not Config.Fog._saved then return end
    Lighting.FogEnd = Config.Fog._origFogEnd or 100000
    Lighting.FogStart = Config.Fog._origFogStart or 0
    Lighting.FogColor = Config.Fog._origFogColor or Color3.fromRGB(192,192,192)
    Lighting.Brightness = Config.Fog._origBrightness or 2
    Lighting.OutdoorAmbient = Config.Fog._origOutdoorAmbient or Color3.fromRGB(128,128,128)
    for _, d in ipairs(Config.Fog._origAtmos) do
        if d.obj and d.obj.Parent then
            d.obj.Density=d.Density; d.obj.Haze=d.Haze; d.obj.Glare=d.Glare; d.obj.Color=d.Color
        end
    end
end

RunService.RenderStepped:Connect(function()
    if Config.FOV.Enabled and Camera and Camera.FieldOfView ~= Config.FOV.FOV then
        Camera.FieldOfView = Config.FOV.FOV
    end
    if Config.Fog.Enabled then
        if Lighting.FogEnd ~= 100000 then
            Lighting.FogEnd = 100000
            Lighting.FogStart = 100000
        end
        for _, o in ipairs(Lighting:GetChildren()) do
            if o:IsA("Atmosphere") and o.Density ~= 0 then
                o.Density = 0; o.Haze = 0
            end
        end
    end
end)

-- ================== ESP ==================
local espObjs = {}
local function createESP(p)
    if p == LocalPlayer then return end
    local box = Drawing.new("Square")
    box.Thickness = 1.5; box.Filled = false; box.Transparency = 1; box.Visible = false
    local nm = Drawing.new("Text")
    nm.Size = 13; nm.Center = true; nm.Outline = true; nm.Visible = false
    local rl = Drawing.new("Text")
    rl.Size = 11; rl.Center = true; rl.Outline = true; rl.Visible = false
    local ds = Drawing.new("Text")
    ds.Size = 11; ds.Center = true; ds.Outline = true
    ds.Color = Color3.fromRGB(220,220,220); ds.Visible = false
    local hp = Drawing.new("Text")
    hp.Size = 11; hp.Center = true; hp.Outline = true; hp.Visible = false
    local tr = Drawing.new("Line")
    tr.Thickness = 1; tr.Visible = false
    espObjs[p] = {box=box, name=nm, role=rl, dist=ds, hp=hp, tracer=tr}
end
local function removeESP(p)
    local o = espObjs[p]
    if not o then return end
    for _, v in pairs(o) do pcall(function() v:Remove() end) end
    espObjs[p] = nil
end
for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

RunService.RenderStepped:Connect(function()
    if not Config.ESP.Enabled then
        for _, o in pairs(espObjs) do
            for _, v in pairs(o) do v.Visible = false end
        end
        return
    end
    for p, o in pairs(espObjs) do
        local ch = p.Character
        local h = ch and ch:FindFirstChildOfClass("Humanoid")
        local rt = ch and ch:FindFirstChild("HumanoidRootPart")
        local hd = ch and ch:FindFirstChild("Head")
        if not ch or not h or not rt or h.Health <= 0 then
            for _, v in pairs(o) do v.Visible = false end
        else
            local pos, on = Camera:WorldToViewportPoint(rt.Position)
            if not on then
                for _, v in pairs(o) do v.Visible = false end
            else
                local roleName = roleOf(p)
                local col = colorOf(p)
                local hp2 = Camera:WorldToViewportPoint((hd or rt).Position + Vector3.new(0,0.5,0))
                local lp = Camera:WorldToViewportPoint(rt.Position - Vector3.new(0,3,0))
                if Config.ESP.Box and hp2 then
                    local hh = math.abs(hp2.Y - lp.Y)
                    local ww = hh / 2
                    o.box.Size = Vector2.new(ww, hh)
                    o.box.Position = Vector2.new(pos.X - ww/2, pos.Y - hh/2)
                    o.box.Color = col
                    o.box.Visible = true
                else o.box.Visible = false end
                if Config.ESP.Name then
                    o.name.Text = p.Name
                    o.name.Position = Vector2.new(pos.X, pos.Y - 46)
                    o.name.Color = col
                    o.name.Visible = true
                    o.role.Text = "[" .. roleName .. "]"
                    o.role.Position = Vector2.new(pos.X, pos.Y - 32)
                    o.role.Color = col
                    o.role.Visible = true
                else
                    o.name.Visible = false
                    o.role.Visible = false
                end
                if Config.ESP.Distance then
                    local d = (Camera.CFrame.Position - rt.Position).Magnitude
                    o.dist.Text = string.format("%dm", math.floor(d))
                    o.dist.Position = Vector2.new(pos.X, pos.Y + 20)
                    o.dist.Visible = true
                else o.dist.Visible = false end
                if Config.ESP.Health then
                    o.hp.Text = string.format("%d HP", math.floor(h.Health))
                    o.hp.Color = Color3.fromRGB(255 - h.Health*2.55, h.Health*2.55, 0)
                    o.hp.Position = Vector2.new(pos.X, pos.Y + 34)
                    o.hp.Visible = true
                else o.hp.Visible = false end
                if Config.ESP.Tracer then
                    o.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                    o.tracer.To = Vector2.new(pos.X, pos.Y)
                    o.tracer.Color = col
                    o.tracer.Visible = true
                else o.tracer.Visible = false end
            end
        end
    end
end)

-- ================== GUI ==================
local parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui")
sg.Name = "ROCKET_Menu"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999
sg.Parent = parent

-- ================== ИКОНКА ==================
local iconBtn = Instance.new("ImageButton")
iconBtn.Size = UDim2.new(0, 38, 0, 38)
iconBtn.Position = UDim2.new(0, 12, 0.5, -19)
iconBtn.BackgroundColor3 = Color3.fromRGB(80, 0, 140)
iconBtn.BackgroundTransparency = (ICON_ID ~= "rbxassetid://0") and 1 or 0.1
iconBtn.Image = (ICON_ID ~= "rbxassetid://0") and ICON_ID or ""
iconBtn.ImageTransparency = (ICON_ID ~= "rbxassetid://0") and 0 or 1
iconBtn.Parent = sg
Instance.new("UICorner", iconBtn).CornerRadius = UDim.new(0, 10)

local iconStroke = Instance.new("UIStroke")
iconStroke.Color = Color3.fromRGB(180, 80, 255)
iconStroke.Thickness = 1.5
iconStroke.Transparency = 0.2
iconStroke.Parent = iconBtn

if ICON_ID == "rbxassetid://0" then
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "R"
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 16
    lbl.Parent = iconBtn
end

task.spawn(function()
    while iconBtn.Parent do
        TweenService:Create(iconStroke, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Transparency = 0.05, Thickness = 2.5 }):Play()
        task.wait(1.3)
        TweenService:Create(iconStroke, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { Transparency = 0.4, Thickness = 1.5 }):Play()
        task.wait(1.3)
    end
end)

-- ================== ОКНО ==================
local win = Instance.new("Frame")
win.Size = UDim2.new(0, 320, 0, 320)
win.Position = UDim2.new(0.5, -160, 0.5, -160)
win.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
win.BackgroundTransparency = 0.05
win.Visible = false
win.Active = true
win.Parent = sg
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)

local winStroke = Instance.new("UIStroke")
winStroke.Color = Color3.fromRGB(70, 60, 100)
winStroke.Thickness = 1.5
winStroke.Transparency = 0.2
winStroke.Parent = win

-- Перетаскивание иконки + тап = открыть
local iconDragging = false
local iconDragStart, iconStartPos
local iconMoved = false
local iconDownTime = 0

iconBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        iconDragging = true; iconMoved = false; iconDownTime = tick()
        iconDragStart = i.Position; iconStartPos = iconBtn.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if not iconDragging then return end
    if i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch then
        local d = i.Position - iconDragStart
        if math.abs(d.X) > 5 or math.abs(d.Y) > 5 then iconMoved = true end
        iconBtn.Position = UDim2.new(
            iconStartPos.X.Scale, iconStartPos.X.Offset + d.X,
            iconStartPos.Y.Scale, iconStartPos.Y.Offset + d.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if not iconDragging then return end
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        iconDragging = false
        if not iconMoved and tick() - iconDownTime < 0.4 then
            win.Visible = not win.Visible
            if win.Visible then
                win.Size = UDim2.new(0, 270, 0, 270)
                TweenService:Create(win,
                    TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    { Size = UDim2.new(0, 320, 0, 320) }):Play()
            end
        end
    end
end)

-- ================== ЗАГОЛОВОК ==================
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = Color3.fromRGB(24, 22, 32)
header.BorderSizePixel = 0
header.Active = true
header.Parent = win
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 17)
headerFix.Position = UDim2.new(0, 0, 1, -17)
headerFix.BackgroundColor3 = Color3.fromRGB(24, 22, 32)
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "ROCKET  |  v1"
title.TextColor3 = Color3.fromRGB(0, 255, 200)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = false
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -28, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(45, 25, 25)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)

local dragZone = Instance.new("TextButton")
dragZone.Size = UDim2.new(1, -40, 1, 0)
dragZone.BackgroundTransparency = 1
dragZone.Text = ""
dragZone.AutoButtonColor = false
dragZone.ZIndex = 10
dragZone.Parent = header

local dragging, dragStart, startPos
dragZone.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = i.Position; startPos = win.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        win.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ================== ВКЛАДКИ ==================
local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -20, 0, 30)
tabsFrame.Position = UDim2.new(0, 10, 0, 42)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = win

local tabsLay = Instance.new("UIListLayout")
tabsLay.FillDirection = Enum.FillDirection.Horizontal
tabsLay.Padding = UDim.new(0, 6)
tabsLay.SortOrder = Enum.SortOrder.LayoutOrder
tabsLay.Parent = tabsFrame

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -90)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1
content.Parent = win

local pages = {}
local function makePage(name)
    local p = Instance.new("ScrollingFrame")
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
    p.Visible = false
    p.Parent = content
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = p
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = p
    pages[name] = p
end

local TAB_ORDER = {"ESP","Speed","Visual"}
for _, n in ipairs(TAB_ORDER) do makePage(n) end

local tabButtons = {}
local currentPage = nil
local function showPage(name)
    if currentPage == name then return end
    local newPage = pages[name]
    if not newPage then return end
    for n, p in pairs(pages) do
        if n ~= name then p.Visible = false end
    end
    newPage.Visible = true
    newPage.Position = UDim2.new(0, 30, 0, 0)
    TweenService:Create(newPage,
        TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 0, 0, 0) }):Play()
    for n, b in pairs(tabButtons) do
        local active = (n == name)
        TweenService:Create(b,
            TweenInfo.new(0.22, Enum.EasingStyle.Quad),
            {
                BackgroundColor3 = active and Color3.fromRGB(40, 35, 60) or Color3.fromRGB(35, 35, 42),
                TextColor3 = active and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(190, 190, 200),
            }):Play()
    end
    currentPage = name
end

for i, n in ipairs(TAB_ORDER) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 90, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    b.TextColor3 = Color3.fromRGB(190, 190, 200)
    b.Text = n
    b.Font = Enum.Font.Gotham
    b.TextSize = 12
    b.LayoutOrder = i
    b.Parent = tabsFrame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    tabButtons[n] = b
    b.MouseButton1Click:Connect(function() showPage(n) end)
end
showPage("ESP")

-- ================== UI ЭЛЕМЕНТЫ ==================
local function makeCheck(parent, text, default, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 14, 0, 14)
    circle.Position = UDim2.new(0, 4, 0, 7)
    circle.BackgroundColor3 = default and Color3.fromRGB(0, 230, 120) or Color3.fromRGB(255, 80, 90)
    circle.BorderSizePixel = 0
    circle.Parent = row
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local stroke = Instance.new("UIStroke")
    stroke.Color = default and Color3.fromRGB(0, 180, 90) or Color3.fromRGB(180, 50, 60)
    stroke.Thickness = 1
    stroke.Parent = circle

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -30, 1, 0)
    lbl.Position = UDim2.new(0, 26, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 225)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        circle.BackgroundColor3 = state and Color3.fromRGB(0, 230, 120) or Color3.fromRGB(255, 80, 90)
        stroke.Color = state and Color3.fromRGB(0, 180, 90) or Color3.fromRGB(180, 50, 60)
        cb(state)
    end)
end

local function makeSlider(parent, name, min, max, default, cb)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 46)
    wrap.BackgroundTransparency = 1
    wrap.Parent = parent

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(0.55, 0, 0, 18)
    bar.Position = UDim2.new(0, 4, 0, 4)
    bar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.Parent = wrap
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local numLbl = Instance.new("TextLabel")
    numLbl.Size = UDim2.new(0.15, 0, 0, 18)
    numLbl.Position = UDim2.new(0.57, 4, 0, 4)
    numLbl.BackgroundTransparency = 1
    numLbl.Text = tostring(default)
    numLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
    numLbl.Font = Enum.Font.Gotham
    numLbl.TextSize = 12
    numLbl.TextXAlignment = Enum.TextXAlignment.Left
    numLbl.Parent = wrap

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.3, -8, 0, 18)
    nameLbl.Position = UDim2.new(0.7, 0, 0, 4)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = name
    nameLbl.TextColor3 = Color3.fromRGB(160, 160, 170)
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextSize = 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = wrap

    local dragging = false
    local function upd(i)
        local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        local v = math.floor(min + (max - min) * rel)
        numLbl.Text = tostring(v)
        cb(v)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            upd(i)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            upd(i)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ================== ESP PAGE ==================
do
    local p = pages.ESP
    makeCheck(p, "ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
    makeCheck(p, "Box", Config.ESP.Box, function(v) Config.ESP.Box = v end)
    makeCheck(p, "Name + Role", Config.ESP.Name, function(v) Config.ESP.Name = v end)
    makeCheck(p, "Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
    makeCheck(p, "Health", Config.ESP.Health, function(v) Config.ESP.Health = v end)
    makeCheck(p, "Tracer", Config.ESP.Tracer, function(v) Config.ESP.Tracer = v end)

    local legend = Instance.new("Frame")
    legend.Size = UDim2.new(1, 0, 0, 62)
    legend.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    legend.BorderSizePixel = 0
    legend.Parent = p
    Instance.new("UICorner", legend).CornerRadius = UDim.new(0, 8)

    local function lr(color, txt, y)
        local d = Instance.new("Frame")
        d.Size = UDim2.new(0, 10, 0, 10)
        d.Position = UDim2.new(0, 10, 0, y)
        d.BackgroundColor3 = color
        d.BorderSizePixel = 0
        d.Parent = legend
        Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -30, 0, 14)
        l.Position = UDim2.new(0, 26, 0, y - 2)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = Color3.fromRGB(200, 200, 210)
        l.Font = Enum.Font.Gotham
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = legend
    end
    lr(Config.ESP.Colors.Killer, "Маньяк — красный", 6)
    lr(Config.ESP.Colors.Survivor, "Выживший — зелёный", 24)
    lr(Config.ESP.Colors.Unknown, "Неизвестно — белый", 42)
end

-- ================== SPEED PAGE ==================
do
    local p = pages.Speed
    makeCheck(p, "Speed Hack (Legit)", Config.Speed.Enabled, function(v)
        Config.Speed.Enabled = v
        applySpeed()
    end)
    makeSlider(p, "Speed", 16, 120, Config.Speed.Speed, function(v)
        Config.Speed.Speed = v
        applySpeed()
    end)
    makeCheck(p, "Inf Jump", Config.Speed.InfJump, function(v) Config.Speed.InfJump = v end)
end

-- ================== VISUAL PAGE ==================
do
    local p = pages.Visual
    makeCheck(p, "FOV (растяг)", Config.FOV.Enabled, function(v)
        Config.FOV.Enabled = v
        applyFOV()
    end)
    makeSlider(p, "FOV Value", 70, 140, Config.FOV.FOV, function(v)
        Config.FOV.FOV = v
        applyFOV()
    end)
    makeCheck(p, "No Fog (без дыма)", Config.Fog.Enabled, function(v)
        Config.Fog.Enabled = v
        if v then killFog() else restoreFog() end
    end)
    makeCheck(p, "Full Bright", Config.Fog.FullBright, function(v)
        Config.Fog.FullBright = v
        if v then
            Lighting.Brightness = 3
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.ClockTime = 14
        else
            if Config.Fog._saved then
                Lighting.Brightness = Config.Fog._origBrightness or 2
                Lighting.OutdoorAmbient = Config.Fog._origOutdoorAmbient or Color3.fromRGB(128, 128, 128)
            end
        end
    end)
end

applyFOV()
applySpeed()

print("[ROCKET] Загружено. Иконка 'R' слева — тапни.")

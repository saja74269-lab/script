--[[
    ╔══════════════════════════════════════════════════════╗
    ║              PRIME VAULT — v3.1                      ║
    ║          Aimbot  ·  ESP  ·  Settings                 ║
    ║              made by lowkeyy                         ║
    ╚══════════════════════════════════════════════════════════╝
    
    Features:
      • Aimbot with configurable FOV, smoothing, bone, team/wall check
      • Keybind selector for aimbot activation
      • ESP with boxes, names, health bars, distance, tracers, chams
      • Modern dark glass UI with smooth animations
      • Proper minimize/maximize with animation
      • Draggable, clean, easy to use
    
    Usage: Execute with any Roblox executor.
    Toggle Menu: Right Shift
]]

-- ══════════════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════════════
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local Camera             = workspace.CurrentCamera
local LocalPlayer        = Players.LocalPlayer
local Mouse              = LocalPlayer:GetMouse()

-- ══════════════════════════════════════════════════
-- CONFIGURATION
-- ══════════════════════════════════════════════════
local Config = {
    MenuToggleKey    = Enum.KeyCode.RightShift,

    -- Aimbot
    AimbotEnabled    = false,
    AimbotKeyType    = "MouseButton2",
    AimbotFOV        = 120,
    AimbotSmoothing  = 5,
    AimbotBone       = "Head",
    AimbotTeamCheck  = true,
    AimbotWallCheck  = true,
    AimbotShowFOV    = true,
    AimbotFOVColor   = Color3.fromRGB(160, 120, 255),
    AimbotPrediction = false,

    -- ESP
    ESPEnabled       = false,
    ESPBoxes         = true,
    ESPBoxColor      = Color3.fromRGB(160, 120, 255),
    ESPNames         = true,
    ESPNameColor     = Color3.fromRGB(255, 255, 255),
    ESPHealth        = true,
    ESPDistance      = true,
    ESPTracers       = false,
    ESPTracerColor   = Color3.fromRGB(160, 120, 255),
    ESPTracerOrigin  = "Bottom",
    ESPChams         = false,
    ESPChamsFillColor        = Color3.fromRGB(160, 120, 255),
    ESPChamsFillTransparency = 0.7,
    ESPChamsOutlineColor     = Color3.fromRGB(255, 255, 255),
    ESPMaxDistance   = 1500,
    ESPTeamCheck     = true,
    ESPShowTeamColor = false,
}

local KeybindOptions = {
    "MouseButton2",
    "MouseButton1",
    "Q", "E", "R", "F", "X", "C", "V", "Z",
    "LeftShift", "LeftControl", "LeftAlt",
    "CapsLock", "Tab",
}

local function ResolveKeybind(name)
    if name == "MouseButton1" then return "MouseButton", Enum.UserInputType.MouseButton1 end
    if name == "MouseButton2" then return "MouseButton", Enum.UserInputType.MouseButton2 end
    local ok, key = pcall(function() return Enum.KeyCode[name] end)
    if ok and key then return "KeyCode", key end
    return "MouseButton", Enum.UserInputType.MouseButton2
end

-- ══════════════════════════════════════════════════
-- UTILITY
-- ══════════════════════════════════════════════════
local function IsAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return char:FindFirstChild("HumanoidRootPart") ~= nil
end

local function GetBone(character, boneName)
    return character:FindFirstChild(boneName) or character:FindFirstChild("HumanoidRootPart")
end

local function IsTeammate(player)
    if not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function WorldToScreen(position)
    local sp, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(sp.X, sp.Y), onScreen, sp.Z
end

local function IsVisible(origin, target)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LocalPlayer.Character}
    return workspace:Raycast(origin, target - origin, rp) == nil
end

local function Tween(obj, props, duration, style, dir)
    local ti = TweenInfo.new(duration or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
    return TweenService:Create(obj, ti, props)
end

-- ══════════════════════════════════════════════════
-- SCREEN GUI
-- ══════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PrimeVault"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999

if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = game:GetService("CoreGui")
elseif gethui then
    ScreenGui.Parent = gethui()
else
    ScreenGui.Parent = game:GetService("CoreGui")
end

-- ══════════════════════════════════════════════════
-- THEME
-- ══════════════════════════════════════════════════
local T = {
    Bg          = Color3.fromRGB(12, 12, 18),
    BgSecondary = Color3.fromRGB(16, 16, 24),
    Card        = Color3.fromRGB(20, 20, 30),
    CardHover   = Color3.fromRGB(28, 28, 42),
    Accent      = Color3.fromRGB(140, 100, 255),
    AccentSoft  = Color3.fromRGB(100, 70, 200),
    AccentGlow  = Color3.fromRGB(160, 130, 255),
    Text        = Color3.fromRGB(230, 230, 240),
    TextDim     = Color3.fromRGB(110, 110, 135),
    TextMuted   = Color3.fromRGB(70, 70, 90),
    ToggleOn    = Color3.fromRGB(140, 100, 255),
    ToggleOff   = Color3.fromRGB(40, 40, 55),
    SliderBg    = Color3.fromRGB(35, 35, 50),
    SliderFill  = Color3.fromRGB(140, 100, 255),
    Border      = Color3.fromRGB(35, 35, 50),
    Red         = Color3.fromRGB(255, 60, 80),
    Green       = Color3.fromRGB(60, 255, 130),
    White       = Color3.fromRGB(255, 255, 255),
}

-- ══════════════════════════════════════════════════
-- MAIN FRAME
-- ══════════════════════════════════════════════════
local EXPANDED_SIZE  = UDim2.new(0, 520, 0, 420)
local COLLAPSED_SIZE = UDim2.new(0, 520, 0, 44)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = T.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
MainFrame.Size = EXPANDED_SIZE
MainFrame.ClipsDescendants = true
MainFrame.Active = true

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = T.Border
MainStroke.Thickness = 1
MainStroke.Transparency = 0.3

-- Dragging
local dragging, dragStart, startPos, dragInput

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local relY = input.Position.Y - MainFrame.AbsolutePosition.Y
        if relY <= 44 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- ═══════════════════════════
-- TITLE BAR
-- ═══════════════════════════
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Parent = MainFrame
TitleBar.BackgroundColor3 = T.BgSecondary
TitleBar.BorderSizePixel = 0
TitleBar.Size = UDim2.new(1, 0, 0, 44)
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local tbFix = Instance.new("Frame", TitleBar)
tbFix.BackgroundColor3 = T.BgSecondary
tbFix.BorderSizePixel = 0
tbFix.Position = UDim2.new(0, 0, 0.5, 0)
tbFix.Size = UDim2.new(1, 0, 0.5, 0)

local accentLine = Instance.new("Frame")
accentLine.Parent = MainFrame
accentLine.BackgroundColor3 = T.Accent
accentLine.BorderSizePixel = 0
accentLine.Position = UDim2.new(0, 0, 0, 44)
accentLine.Size = UDim2.new(1, 0, 0, 2)
accentLine.ZIndex = 5

local logoDot = Instance.new("Frame")
logoDot.Parent = TitleBar
logoDot.BackgroundColor3 = T.Accent
logoDot.Size = UDim2.new(0, 8, 0, 8)
logoDot.Position = UDim2.new(0, 16, 0.5, -4)
logoDot.BorderSizePixel = 0
Instance.new("UICorner", logoDot).CornerRadius = UDim.new(1, 0)

local titleText = Instance.new("TextLabel")
titleText.Parent = TitleBar
titleText.BackgroundTransparency = 1
titleText.Position = UDim2.new(0, 30, 0, 0)
titleText.Size = UDim2.new(0.4, 0, 1, 0)
titleText.Font = Enum.Font.GothamBold
titleText.Text = "PRIME VAULT"
titleText.TextColor3 = T.Text
titleText.TextSize = 15
titleText.TextXAlignment = Enum.TextXAlignment.Left

local subtitleText = Instance.new("TextLabel")
subtitleText.Parent = TitleBar
subtitleText.BackgroundTransparency = 1
subtitleText.Position = UDim2.new(0.4, 0, 0, 0)
subtitleText.Size = UDim2.new(0.35, 0, 1, 0)
subtitleText.Font = Enum.Font.Gotham
subtitleText.Text = "v3.0 · by lowkeyy"
subtitleText.TextColor3 = T.TextMuted
subtitleText.TextSize = 11
subtitleText.TextXAlignment = Enum.TextXAlignment.Right

local minBtn = Instance.new("TextButton")
minBtn.Parent = TitleBar
minBtn.BackgroundColor3 = T.Card
minBtn.Position = UDim2.new(1, -74, 0.5, -12)
minBtn.Size = UDim2.new(0, 24, 0, 24)
minBtn.Font = Enum.Font.GothamBold
minBtn.Text = "—"
minBtn.TextColor3 = T.TextDim
minBtn.TextSize = 14
minBtn.BorderSizePixel = 0
minBtn.AutoButtonColor = false
minBtn.ZIndex = 10
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Parent = TitleBar
closeBtn.BackgroundColor3 = T.Card
closeBtn.Position = UDim2.new(1, -42, 0.5, -12)
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "✕"
closeBtn.TextColor3 = T.Red
closeBtn.TextSize = 12
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 10
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local isMinimized = false
local tweening = false

minBtn.MouseButton1Click:Connect(function()
    if tweening then return end
    tweening = true
    isMinimized = not isMinimized
    if isMinimized then
        minBtn.Text = "+"
        local tw = Tween(MainFrame, {Size = COLLAPSED_SIZE}, 0.3)
        tw:Play()
        tw.Completed:Connect(function() tweening = false end)
    else
        minBtn.Text = "—"
        local tw = Tween(MainFrame, {Size = EXPANDED_SIZE}, 0.3)
        tw:Play()
        tw.Completed:Connect(function() tweening = false end)
    end
end)

-- ═══════════════════════════
-- TAB BAR
-- ═══════════════════════════
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Parent = MainFrame
TabBar.BackgroundTransparency = 1
TabBar.Position = UDim2.new(0, 0, 0, 50)
TabBar.Size = UDim2.new(1, 0, 0, 36)

local tabPad = Instance.new("UIPadding", TabBar)
tabPad.PaddingLeft = UDim.new(0, 12)
tabPad.PaddingRight = UDim.new(0, 12)

local tabLayout = Instance.new("UIListLayout", TabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 6)
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local ContentArea = Instance.new("Frame")
ContentArea.Name = "Content"
ContentArea.Parent = MainFrame
ContentArea.BackgroundTransparency = 1
ContentArea.Position = UDim2.new(0, 0, 0, 90)
ContentArea.Size = UDim2.new(1, 0, 1, -90)
ContentArea.ClipsDescendants = true

-- ═══════════════════════════
-- UI BUILDER
-- ═══════════════════════════
local Pages = {}
local TabButtons = {}

local function CreatePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Parent = ContentArea
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Size = UDim2.new(1, 0, 1, 0)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = T.Accent
    page.ScrollBarImageTransparency = 0.4
    page.Visible = false
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y

    Instance.new("UIPadding", page).PaddingLeft = UDim.new(0, 14)
    local pad = page:FindFirstChildOfClass("UIPadding")
    pad.PaddingRight = UDim.new(0, 14)
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 10)

    local layout = Instance.new("UIListLayout", page)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)

    Pages[name] = page
    return page
end

local function SwitchTab(name)
    for n, page in pairs(Pages) do
        page.Visible = (n == name)
    end
    for n, btn in pairs(TabButtons) do
        local indicator = btn:FindFirstChild("Indicator")
        if n == name then
            Tween(btn, {BackgroundColor3 = T.Card}, 0.2):Play()
            btn.TextColor3 = T.AccentGlow
            if indicator then Tween(indicator, {BackgroundTransparency = 0}, 0.2):Play() end
        else
            Tween(btn, {BackgroundColor3 = T.Bg}, 0.2):Play()
            btn.TextColor3 = T.TextDim
            if indicator then Tween(indicator, {BackgroundTransparency = 1}, 0.2):Play() end
        end
    end
end

local function CreateTab(name, icon, order)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Parent = TabBar
    btn.BackgroundColor3 = T.Bg
    btn.BorderSizePixel = 0
    btn.Size = UDim2.new(0, 155, 0, 30)
    btn.Font = Enum.Font.GothamSemibold
    btn.Text = icon .. "  " .. name
    btn.TextColor3 = T.TextDim
    btn.TextSize = 12
    btn.LayoutOrder = order
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local indicator = Instance.new("Frame")
    indicator.Name = "Indicator"
    indicator.Parent = btn
    indicator.BackgroundColor3 = T.Accent
    indicator.BorderSizePixel = 0
    indicator.Position = UDim2.new(0.2, 0, 1, -2)
    indicator.Size = UDim2.new(0.6, 0, 0, 2)
    indicator.BackgroundTransparency = 1
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

    btn.MouseEnter:Connect(function()
        if not Pages[name] or not Pages[name].Visible then
            Tween(btn, {BackgroundColor3 = T.CardHover}, 0.15):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if not Pages[name] or not Pages[name].Visible then
            Tween(btn, {BackgroundColor3 = T.Bg}, 0.15):Play()
        end
    end)
    btn.MouseButton1Click:Connect(function() SwitchTab(name) end)

    TabButtons[name] = btn
    return btn
end

local function Section(parent, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = parent
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = string.upper(text)
    lbl.TextColor3 = T.Accent
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order or 0

    local bar = Instance.new("Frame", lbl)
    bar.BackgroundColor3 = T.Accent
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(0, 3, 0.6, 0)
    bar.Position = UDim2.new(0, -1, 0.2, 0)
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local pad = Instance.new("UIPadding", lbl)
    pad.PaddingLeft = UDim.new(0, 10)
end

local function Toggle(parent, text, default, order, callback)
    local holder = Instance.new("Frame")
    holder.Parent = parent
    holder.BackgroundColor3 = T.Card
    holder.BorderSizePixel = 0
    holder.Size = UDim2.new(1, 0, 0, 36)
    holder.LayoutOrder = order or 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", holder)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.Size = UDim2.new(1, -65, 1, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.Text = text
    lbl.TextColor3 = T.Text
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local tBg = Instance.new("Frame", holder)
    tBg.BackgroundColor3 = default and T.ToggleOn or T.ToggleOff
    tBg.Position = UDim2.new(1, -52, 0.5, -10)
    tBg.Size = UDim2.new(0, 40, 0, 20)
    tBg.BorderSizePixel = 0
    Instance.new("UICorner", tBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", tBg)
    knob.BackgroundColor3 = T.White
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = default
    local btn = Instance.new("TextButton", holder)
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Text = ""
    btn.ZIndex = 5

    btn.MouseButton1Click:Connect(function()
        state = not state
        Tween(tBg, {BackgroundColor3 = state and T.ToggleOn or T.ToggleOff}, 0.2):Play()
        Tween(knob, {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.2):Play()
        if callback then callback(state) end
    end)

    btn.MouseEnter:Connect(function() Tween(holder, {BackgroundColor3 = T.CardHover}, 0.15):Play() end)
    btn.MouseLeave:Connect(function() Tween(holder, {BackgroundColor3 = T.Card}, 0.15):Play() end)

    return holder
end

local function Slider(parent, text, min, max, default, order, callback)
    local holder = Instance.new("Frame")
    holder.Parent = parent
    holder.BackgroundColor3 = T.Card
    holder.BorderSizePixel = 0
    holder.Size = UDim2.new(1, 0, 0, 52)
    holder.LayoutOrder = order or 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", holder)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 14, 0, 2)
    lbl.Size = UDim2.new(1, -75, 0, 22)
    lbl.Font = Enum.Font.Gotham
    lbl.Text = text
    lbl.TextColor3 = T.Text
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", holder)
    valLbl.BackgroundTransparency = 1
    valLbl.Position = UDim2.new(1, -65, 0, 2)
    valLbl.Size = UDim2.new(0, 55, 0, 22)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.Text = tostring(default)
    valLbl.TextColor3 = T.AccentGlow
    valLbl.TextSize = 12
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local bar = Instance.new("Frame", holder)
    bar.BackgroundColor3 = T.SliderBg
    bar.Position = UDim2.new(0, 14, 0, 32)
    bar.Size = UDim2.new(1, -28, 0, 6)
    bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", bar)
    fill.BackgroundColor3 = T.SliderFill
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", bar)
    knob.BackgroundColor3 = T.White
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new((default - min) / (max - min), -6, 0.5, -6)
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local knobStroke = Instance.new("UIStroke", knob)
    knobStroke.Color = T.Accent
    knobStroke.Thickness = 1.5
    knobStroke.Transparency = 0.5

    local isDragging = false
    local inputBtn = Instance.new("TextButton", bar)
    inputBtn.BackgroundTransparency = 1
    inputBtn.Size = UDim2.new(1, 0, 1, 14)
    inputBtn.Position = UDim2.new(0, 0, 0, -7)
    inputBtn.Text = ""
    inputBtn.ZIndex = 5

    local function update(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * rel)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -6, 0.5, -6)
        valLbl.Text = tostring(val)
        if callback then callback(val) end
    end

    inputBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            update(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    return holder
end

local function Dropdown(parent, text, options, default, order, callback)
    local holder = Instance.new("Frame")
    holder.Parent = parent
    holder.BackgroundColor3 = T.Card
    holder.BorderSizePixel = 0
    holder.Size = UDim2.new(1, 0, 0, 36)
    holder.ClipsDescendants = true
    holder.LayoutOrder = order or 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", holder)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.Size = UDim2.new(0.5, -14, 0, 36)
    lbl.Font = Enum.Font.Gotham
    lbl.Text = text
    lbl.TextColor3 = T.Text
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local selBtn = Instance.new("TextButton", holder)
    selBtn.BackgroundColor3 = T.BgSecondary
    selBtn.Position = UDim2.new(0.5, 4, 0, 6)
    selBtn.Size = UDim2.new(0.5, -18, 0, 24)
    selBtn.Font = Enum.Font.GothamSemibold
    selBtn.Text = default .. "  ▾"
    selBtn.TextColor3 = T.AccentGlow
    selBtn.TextSize = 11
    selBtn.BorderSizePixel = 0
    selBtn.AutoButtonColor = false
    Instance.new("UICorner", selBtn).CornerRadius = UDim.new(0, 6)

    local expanded = false

    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton", holder)
        optBtn.BackgroundColor3 = T.BgSecondary
        optBtn.Position = UDim2.new(0.5, 4, 0, 36 + (i - 1) * 28)
        optBtn.Size = UDim2.new(0.5, -18, 0, 26)
        optBtn.Font = Enum.Font.Gotham
        optBtn.Text = opt
        optBtn.TextColor3 = T.Text
        optBtn.TextSize = 11
        optBtn.BorderSizePixel = 0
        optBtn.AutoButtonColor = false
        optBtn.ZIndex = 10
        Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 6)

        optBtn.MouseEnter:Connect(function() Tween(optBtn, {BackgroundColor3 = T.CardHover}, 0.1):Play() end)
        optBtn.MouseLeave:Connect(function() Tween(optBtn, {BackgroundColor3 = T.BgSecondary}, 0.1):Play() end)

        optBtn.MouseButton1Click:Connect(function()
            selBtn.Text = opt .. "  ▾"
            expanded = false
            Tween(holder, {Size = UDim2.new(1, 0, 0, 36)}, 0.2):Play()
            if callback then callback(opt) end
        end)
    end

    selBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        local targetH = expanded and (36 + #options * 28 + 6) or 36
        Tween(holder, {Size = UDim2.new(1, 0, 0, targetH)}, 0.2):Play()
    end)

    return holder
end

-- ══════════════════════════════════════════════════
-- BUILD TABS & PAGES
-- ══════════════════════════════════════════════════
CreateTab("Aimbot", "◎", 1)
CreateTab("ESP", "◉", 2)
CreateTab("Settings", "⚙", 3)

local AimbotPage   = CreatePage("Aimbot")
local ESPPage      = CreatePage("ESP")
local SettingsPage = CreatePage("Settings")

-- ═══════════════════════════
-- AIMBOT PAGE
-- ═══════════════════════════
Section(AimbotPage, "Core", 1)
Toggle(AimbotPage, "Enable Aimbot", Config.AimbotEnabled, 2, function(v) Config.AimbotEnabled = v end)
Toggle(AimbotPage, "Show FOV Circle", Config.AimbotShowFOV, 3, function(v) Config.AimbotShowFOV = v end)
Toggle(AimbotPage, "Team Check", Config.AimbotTeamCheck, 4, function(v) Config.AimbotTeamCheck = v end)
Toggle(AimbotPage, "Wall Check", Config.AimbotWallCheck, 5, function(v) Config.AimbotWallCheck = v end)
Toggle(AimbotPage, "Prediction", Config.AimbotPrediction, 6, function(v) Config.AimbotPrediction = v end)
Section(AimbotPage, "Tuning", 10)
Slider(AimbotPage, "FOV Radius", 10, 500, Config.AimbotFOV, 11, function(v) Config.AimbotFOV = v end)
Slider(AimbotPage, "Smoothing", 1, 30, Config.AimbotSmoothing, 12, function(v) Config.AimbotSmoothing = v end)
Section(AimbotPage, "Target", 20)
Dropdown(AimbotPage, "Target Bone", {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}, Config.AimbotBone, 21, function(v) Config.AimbotBone = v end)
Section(AimbotPage, "Keybind", 30)
Dropdown(AimbotPage, "Aimbot Key", KeybindOptions, Config.AimbotKeyType, 31, function(v) Config.AimbotKeyType = v end)

-- ═══════════════════════════
-- ESP PAGE
-- ═══════════════════════════
Section(ESPPage, "Core", 1)
Toggle(ESPPage, "Enable ESP", Config.ESPEnabled, 2, function(v) Config.ESPEnabled = v end)
Toggle(ESPPage, "Team Check", Config.ESPTeamCheck, 3, function(v) Config.ESPTeamCheck = v end)
Toggle(ESPPage, "Use Team Colors", Config.ESPShowTeamColor, 4, function(v) Config.ESPShowTeamColor = v end)
Section(ESPPage, "Visuals", 10)
Toggle(ESPPage, "Boxes", Config.ESPBoxes, 11, function(v) Config.ESPBoxes = v end)
Toggle(ESPPage, "Names", Config.ESPNames, 12, function(v) Config.ESPNames = v end)
Toggle(ESPPage, "Health Bars", Config.ESPHealth, 13, function(v) Config.ESPHealth = v end)
Toggle(ESPPage, "Distance Tags", Config.ESPDistance, 14, function(v) Config.ESPDistance = v end)
Toggle(ESPPage, "Tracers", Config.ESPTracers, 15, function(v) Config.ESPTracers = v end)
Toggle(ESPPage, "Chams (Highlight)", Config.ESPChams, 16, function(v) Config.ESPChams = v end)
Section(ESPPage, "Tuning", 20)
Slider(ESPPage, "Max Distance", 100, 5000, Config.ESPMaxDistance, 21, function(v) Config.ESPMaxDistance = v end)
Slider(ESPPage, "Chams Opacity", 0, 100, math.floor((1 - Config.ESPChamsFillTransparency) * 100), 22, function(v) Config.ESPChamsFillTransparency = 1 - (v / 100) end)
Dropdown(ESPPage, "Tracer Origin", {"Bottom", "Center", "Mouse"}, Config.ESPTracerOrigin, 23, function(v) Config.ESPTracerOrigin = v end)

-- ═══════════════════════════
-- SETTINGS PAGE
-- ═══════════════════════════
Section(SettingsPage, "Information", 1)

local infoCard = Instance.new("Frame")
infoCard.Parent = SettingsPage
infoCard.BackgroundColor3 = T.Card
infoCard.BorderSizePixel = 0
infoCard.Size = UDim2.new(1, 0, 0, 80)
infoCard.LayoutOrder = 2
Instance.new("UICorner", infoCard).CornerRadius = UDim.new(0, 8)

local infoText = Instance.new("TextLabel", infoCard)
infoText.BackgroundTransparency = 1
infoText.Position = UDim2.new(0, 14, 0, 0)
infoText.Size = UDim2.new(1, -28, 1, 0)
infoText.Font = Enum.Font.Gotham
infoText.Text = "Toggle Menu: Right Shift\nAimbot Key: Configurable in Aimbot tab\nDrag: Hold from title bar\nMinimize: — button"
infoText.TextColor3 = T.TextDim
infoText.TextSize = 11
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextYAlignment.Center
infoText.LineHeight = 1.5

Section(SettingsPage, "About", 10)

local creditsCard = Instance.new("Frame")
creditsCard.Parent = SettingsPage
creditsCard.BackgroundColor3 = T.Card
creditsCard.BorderSizePixel = 0
creditsCard.Size = UDim2.new(1, 0, 0, 55)
creditsCard.LayoutOrder = 11
Instance.new("UICorner", creditsCard).CornerRadius = UDim.new(0, 8)

local creditsText = Instance.new("TextLabel", creditsCard)
creditsText.BackgroundTransparency = 1
creditsText.Position = UDim2.new(0, 14, 0, 0)
creditsText.Size = UDim2.new(1, -28, 1, 0)
creditsText.Font = Enum.Font.Gotham
creditsText.RichText = true
creditsText.Text = '<font color="#A064FF"><b>PRIME VAULT</b></font>  v3.0\nMade with 💜 by <font color="#A064FF"><b>lowkeyy</b></font>'
creditsText.TextColor3 = T.TextDim
creditsText.TextSize = 12
creditsText.TextXAlignment = Enum.TextXAlignment.Left
creditsText.TextYAlignment = Enum.TextYAlignment.Center
creditsText.LineHeight = 1.4

Section(SettingsPage, "Danger Zone", 20)

local destroyBtn = Instance.new("TextButton")
destroyBtn.Parent = SettingsPage
destroyBtn.BackgroundColor3 = T.Red
destroyBtn.Size = UDim2.new(1, 0, 0, 36)
destroyBtn.Font = Enum.Font.GothamBold
destroyBtn.Text = "🗑  DESTROY SCRIPT"
destroyBtn.TextColor3 = T.White
destroyBtn.TextSize = 13
destroyBtn.BorderSizePixel = 0
destroyBtn.LayoutOrder = 21
destroyBtn.AutoButtonColor = false
Instance.new("UICorner", destroyBtn).CornerRadius = UDim.new(0, 8)

destroyBtn.MouseEnter:Connect(function() Tween(destroyBtn, {BackgroundColor3 = Color3.fromRGB(220, 40, 60)}, 0.15):Play() end)
destroyBtn.MouseLeave:Connect(function() Tween(destroyBtn, {BackgroundColor3 = T.Red}, 0.15):Play() end)

SwitchTab("Aimbot")

-- ══════════════════════════════════════════════════
-- FOV CIRCLE
-- ══════════════════════════════════════════════════
local FOVCircle = nil
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1.5
    FOVCircle.Filled = false
    FOVCircle.Transparency = 0.7
    FOVCircle.Color = Config.AimbotFOVColor
    FOVCircle.Radius = Config.AimbotFOV
    FOVCircle.Visible = false
    FOVCircle.NumSides = 64
end)

-- ══════════════════════════════════════════════════
-- ESP DRAWING CACHE
-- ══════════════════════════════════════════════════
local ESPObjects  = {}
local ChamsObjects = {}

local function CreateESPForPlayer(player)
    if ESPObjects[player] then return end
    local ok, obj = pcall(function()
        return {
            box         = Drawing.new("Square"),
            nameTag     = Drawing.new("Text"),
            healthBarBg = Drawing.new("Square"),
            healthBar   = Drawing.new("Square"),
            distTag     = Drawing.new("Text"),
            tracer      = Drawing.new("Line"),
        }
    end)
    if not ok then return end

    obj.box.Thickness = 1.2; obj.box.Filled = false; obj.box.Visible = false; obj.box.Transparency = 1
    obj.nameTag.Size = 13; obj.nameTag.Center = true; obj.nameTag.Outline = true; obj.nameTag.Visible = false; obj.nameTag.Font = 2
    obj.healthBarBg.Filled = true; obj.healthBarBg.Visible = false; obj.healthBarBg.Transparency = 0.5; obj.healthBarBg.Color = Color3.fromRGB(0,0,0)
    obj.healthBar.Filled = true; obj.healthBar.Visible = false
    obj.distTag.Size = 11; obj.distTag.Center = true; obj.distTag.Outline = true; obj.distTag.Visible = false; obj.distTag.Font = 2; obj.distTag.Color = T.TextDim
    obj.tracer.Thickness = 1.2; obj.tracer.Visible = false; obj.tracer.Transparency = 0.8

    ESPObjects[player] = obj
end

local function RemoveESPForPlayer(player)
    local obj = ESPObjects[player]
    if obj then pcall(function() for _,v in pairs(obj) do v:Remove() end end) end
    ESPObjects[player] = nil
end

local function HideESPForPlayer(player)
    local obj = ESPObjects[player]
    if obj then pcall(function() for _,v in pairs(obj) do v.Visible = false end end) end
end

local function CreateChamsForPlayer(player)
    if ChamsObjects[player] then return end
    local char = player.Character
    if not char then return end
    local hl = Instance.new("Highlight")
    hl.Name = "PV_Chams"
    hl.FillColor = Config.ESPChamsFillColor
    hl.FillTransparency = Config.ESPChamsFillTransparency
    hl.OutlineColor = Config.ESPChamsOutlineColor
    hl.OutlineTransparency = 0
    hl.Adornee = char
    hl.Parent = char
    ChamsObjects[player] = hl
end

local function RemoveChamsForPlayer(player)
    local hl = ChamsObjects[player]
    if hl then pcall(function() hl:Destroy() end) end
    ChamsObjects[player] = nil
end

-- ══════════════════════════════════════════════════
-- AIMBOT LOGIC
-- ══════════════════════════════════════════════════
local IsAiming = false

local function GetClosestTarget()
    local closest, closestDist = nil, Config.AimbotFOV
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not IsAlive(player) or not IsAlive(LocalPlayer) then continue end
        if Config.AimbotTeamCheck and IsTeammate(player) then continue end
        local bone = GetBone(player.Character, Config.AimbotBone)
        if not bone then continue end
        local sp, onScreen = WorldToScreen(bone.Position)
        if not onScreen then continue end
        local dist = (sp - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
        if dist < closestDist then
            if Config.AimbotWallCheck then
                local lr = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if lr and not IsVisible(lr.Position, bone.Position) then continue end
            end
            closestDist = dist
            closest = player
        end
    end
    return closest
end

-- ══════════════════════════════════════════════════
-- INPUT  (FIXED — keybind check BEFORE gp filter)
-- ══════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
    -- Aimbot keybind resolved BEFORE the game-processed guard
    -- so MouseButton1 doesn't get swallowed
    local bindType, bindValue = ResolveKeybind(Config.AimbotKeyType)
    if bindType == "MouseButton" and input.UserInputType == bindValue then
        IsAiming = true
    elseif bindType == "KeyCode" and input.KeyCode == bindValue then
        IsAiming = true
    end

    if gp then return end  -- UI / menu toggles still respect the filter

    if input.KeyCode == Config.MenuToggleKey then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

UserInputService.InputEnded:Connect(function(input)
    local bindType, bindValue = ResolveKeybind(Config.AimbotKeyType)
    if bindType == "MouseButton" and input.UserInputType == bindValue then
        IsAiming = false
    elseif bindType == "KeyCode" and input.KeyCode == bindValue then
        IsAiming = false
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

destroyBtn.MouseButton1Click:Connect(function()
    if FOVCircle then pcall(function() FOVCircle:Remove() end) end
    for p in pairs(ESPObjects) do RemoveESPForPlayer(p) end
    for p in pairs(ChamsObjects) do RemoveChamsForPlayer(p) end
    ScreenGui:Destroy()
end)

-- ══════════════════════════════════════════════════
-- MAIN RENDER LOOP
-- ══════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    -- FOV circle
    if FOVCircle then
        FOVCircle.Visible = Config.AimbotEnabled and Config.AimbotShowFOV
        FOVCircle.Radius = Config.AimbotFOV
        FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
        FOVCircle.Color = Config.AimbotFOVColor
    end

    -- Aimbot
    if Config.AimbotEnabled and IsAiming and IsAlive(LocalPlayer) then
        local target = GetClosestTarget()
        if target and IsAlive(target) then
            local bone = GetBone(target.Character, Config.AimbotBone)
            if bone then
                local pos = bone.Position
                if Config.AimbotPrediction then
                    local rp = target.Character:FindFirstChild("HumanoidRootPart")
                    if rp then pos = pos + rp.AssemblyLinearVelocity * 0.065 end
                end
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, pos), 1 / Config.AimbotSmoothing)
            end
        end
    end

    -- ESP
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then HideESPForPlayer(player); continue end
        if not Config.ESPEnabled then HideESPForPlayer(player); RemoveChamsForPlayer(player); continue end
        if not IsAlive(player) or not IsAlive(LocalPlayer) then HideESPForPlayer(player); RemoveChamsForPlayer(player); continue end
        if Config.ESPTeamCheck and IsTeammate(player) then HideESPForPlayer(player); RemoveChamsForPlayer(player); continue end

        local char  = player.Character
        local root  = char:FindFirstChild("HumanoidRootPart")
        local hum   = char:FindFirstChildOfClass("Humanoid")
        local head  = char:FindFirstChild("Head")
        local lRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root or not hum or not head or not lRoot then HideESPForPlayer(player); continue end

        local dist = (root.Position - lRoot.Position).Magnitude
        if dist > Config.ESPMaxDistance then HideESPForPlayer(player); RemoveChamsForPlayer(player); continue end

        local rootSp, onScreen = WorldToScreen(root.Position)
        local headSp = WorldToScreen(head.Position + Vector3.new(0, 0.5, 0))
        if not onScreen then HideESPForPlayer(player); continue end

        CreateESPForPlayer(player)
        local obj = ESPObjects[player]
        if not obj then continue end

        local bH   = math.abs(headSp.Y - rootSp.Y) * 1.4
        local bW   = bH * 0.55
        local bPos = Vector2.new(rootSp.X - bW/2, headSp.Y - bH*0.1)
        local col  = Config.ESPBoxColor
        if Config.ESPShowTeamColor and player.Team then col = player.TeamColor.Color end

        obj.box.Visible = Config.ESPBoxes; obj.box.Size = Vector2.new(bW, bH); obj.box.Position = bPos; obj.box.Color = col
        obj.nameTag.Visible = Config.ESPNames; obj.nameTag.Text = player.DisplayName; obj.nameTag.Position = Vector2.new(rootSp.X, bPos.Y - 16); obj.nameTag.Color = Config.ESPNameColor

        local hFrac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        obj.healthBarBg.Visible = Config.ESPHealth; obj.healthBarBg.Size = Vector2.new(3, bH); obj.healthBarBg.Position = Vector2.new(bPos.X - 6, bPos.Y)
        local hbH = bH * hFrac
        obj.healthBar.Visible = Config.ESPHealth; obj.healthBar.Size = Vector2.new(3, hbH); obj.healthBar.Position = Vector2.new(bPos.X - 6, bPos.Y + (bH - hbH))
        obj.healthBar.Color = Color3.fromRGB(255*(1-hFrac), 255*hFrac, 0)

        obj.distTag.Visible = Config.ESPDistance; obj.distTag.Text = math.floor(dist).." studs"; obj.distTag.Position = Vector2.new(rootSp.X, bPos.Y + bH + 3)

        obj.tracer.Visible = Config.ESPTracers; obj.tracer.Color = Config.ESPTracerColor
        local tFrom
        if Config.ESPTracerOrigin == "Bottom" then tFrom = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        elseif Config.ESPTracerOrigin == "Center" then tFrom = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        elseif Config.ESPTracerOrigin == "Mouse" then tFrom = Vector2.new(Mouse.X, Mouse.Y)
        else tFrom = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y) end
        obj.tracer.From = tFrom; obj.tracer.To = Vector2.new(rootSp.X, bPos.Y + bH)

        if Config.ESPChams then
            if not ChamsObjects[player] then
                CreateChamsForPlayer(player)
            else
                local hl = ChamsObjects[player]
                if hl and hl.Parent then
                    hl.FillColor = Config.ESPChamsFillColor
                    hl.FillTransparency = Config.ESPChamsFillTransparency
                    hl.OutlineColor = Config.ESPChamsOutlineColor
                    if hl.Adornee ~= char then hl.Adornee = char end
                else
                    ChamsObjects[player] = nil; CreateChamsForPlayer(player)
                end
            end
        else
            RemoveChamsForPlayer(player)
        end
    end
end)

-- ══════════════════════════════════════════════════
-- CLEANUP
-- ══════════════════════════════════════════════════
Players.PlayerRemoving:Connect(function(p) RemoveESPForPlayer(p); RemoveChamsForPlayer(p) end)

local function hookCharacter(player)
    player.CharacterAdded:Connect(function()
        RemoveChamsForPlayer(player)
        task.wait(0.5)
        if Config.ESPChams and Config.ESPEnabled then CreateChamsForPlayer(player) end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then hookCharacter(p) end end
Players.PlayerAdded:Connect(function(p) hookCharacter(p) end)

-- ══════════════════════════════════════════════════
-- LOAD NOTIFICATION
-- ══════════════════════════════════════════════════
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "PRIME VAULT",
        Text  = "Loaded! Press RShift to toggle. Made by lowkeyy",
        Duration = 5,
    })
end)

print("[PRIME VAULT] v3.0 — Loaded successfully")
print("[PRIME VAULT] Press Right Shift to toggle menu")
print("[PRIME VAULT] Made by lowkeyy")

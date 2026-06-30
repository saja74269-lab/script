--[[
    Rivals Fun 3D  —  LocalScript (HP Version + Silent Aim)
    Place in: StarterPlayerScripts   OR   StarterGui > ScreenGui > LocalScript
    F9  →  open / close menu
    Drag the top bar to move the window
]]

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local Workspace    = game:GetService("Workspace")

local LP   = Players.LocalPlayer
local PGui = LP:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════
--  SILENT AIM CORE (HP OPTIMIZED)
-- ═══════════════════════════════════════════════════════
local SilentAim = {
    Enabled = false,
    TargetPart = "Head",
    FOV = 120,
    Smoothness = 35,
    TeamCheck = true,
    Prediction = 50,
    VisibleCheck = true,
}

local silentAimTarget = nil
local silentAimConnection = nil

-- Fungsi untuk mendapatkan posisi target dengan prediksi
local function getPredictedPosition(part)
    if not part then return nil end
    local pos = part.Position
    local vel = part.AssemblyLinearVelocity
    if vel.Magnitude > 0.5 and SilentAim.Prediction > 0 then
        local cam = Workspace.CurrentCamera
        if cam then
            local dist = (cam.CFrame.Position - pos).Magnitude
            local predTime = (dist / 500) * (SilentAim.Prediction / 100)
            pos = pos + vel * predTime
        end
    end
    return pos
end

-- Cek apakah target terlihat
local function isVisible(targetPart)
    if not SilentAim.VisibleCheck then return true end
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local origin = cam.CFrame.Position
    local targetPos = targetPart.Position
    local ray = Ray.new(origin, (targetPos - origin).Unit * 1000)
    local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {LP.Character, targetPart.Parent})
    return not hit or hit:IsDescendantOf(targetPart.Parent)
end

-- Mendapatkan target terbaik untuk Silent Aim
local function getSilentTarget()
    local center = UIS:GetMouseLocation()
    local bestTarget = nil
    local bestDist = SilentAim.FOV
    local bestPos = nil
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            -- Team check
            if SilentAim.TeamCheck and LP.Team and player.Team and player.Team == LP.Team then
                continue
            end
            
            local char = player.Character
            if not char then continue end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            
            local targetPart = char:FindFirstChild(SilentAim.TargetPart) or char:FindFirstChild("HumanoidRootPart")
            if not targetPart then continue end
            
            -- Cek visibility
            if not isVisible(targetPart) then continue end
            
            local predPos = getPredictedPosition(targetPart)
            if not predPos then continue end
            
            -- Konversi ke layar
            local screenPos, onScreen = Camera:WorldToViewportPoint(predPos)
            if not onScreen then continue end
            
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            
            if dist < bestDist then
                bestDist = dist
                bestTarget = targetPart
                bestPos = predPos
            end
        end
    end
    
    return bestTarget, bestPos
end

-- Fungsi Silent Aim utama (berjalan di RenderStepped)
local function onRenderStep()
    if not SilentAim.Enabled then 
        silentAimTarget = nil
        return 
    end
    
    local target, targetPos = getSilentTarget()
    if not target or not targetPos then 
        silentAimTarget = nil
        return 
    end
    
    silentAimTarget = target
    
    -- Silent Aim: Mengarahkan kamera tanpa menggerakkan mouse
    local smooth = math.clamp(SilentAim.Smoothness / 100, 0.01, 0.99)
    local currentCF = Camera.CFrame
    local targetCF = CFrame.new(currentCF.Position, targetPos)
    
    -- Lerp untuk smoothness
    Camera.CFrame = currentCF:Lerp(targetCF, 1 - smooth)
end

-- Fungsi untuk toggle Silent Aim
local function setSilentAim(enabled)
    SilentAim.Enabled = enabled
    if enabled then
        if not silentAimConnection then
            silentAimConnection = RunService.RenderStepped:Connect(onRenderStep)
        end
    else
        if silentAimConnection then
            silentAimConnection:Disconnect()
            silentAimConnection = nil
        end
        silentAimTarget = nil
    end
end

-- ═══════════════════════════════════════════════════════
--  INFINITE JUMP (SAME)
-- ═══════════════════════════════════════════════════════
local Features = {}
Features.infiniteJumpEnabled = false
local jumpConn = nil

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function stopIJ() if jumpConn then jumpConn:Disconnect(); jumpConn = nil end end
local function startIJ()
    stopIJ()
    jumpConn = UIS.JumpRequest:Connect(function()
        if not Features.infiniteJumpEnabled then return end
        local h = getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

function Features.setInfiniteJump(on)
    Features.infiniteJumpEnabled = on
    if on then startIJ() else stopIJ() end
end

LP.CharacterAdded:Connect(function()
    task.wait(0.2)
    if Features.infiniteJumpEnabled then startIJ() end
end)

-- ═══════════════════════════════════════════════════════
--  ESP (SAME)
-- ═══════════════════════════════════════════════════════
Features.espEnabled  = false
Features.espSettings = { Box=true, BoxFilled=false, Name=true, Distance=true, TeamCheck=true }

local espObjects = {}
local espLoop    = nil

local function teamCol(p) return p.Team and p.Team.TeamColor.Color or Color3.fromRGB(255,60,60) end
local function isEnemy(p)
    if not Features.espSettings.TeamCheck then return true end
    if not LP.Team or not p.Team        then return true end
    return p.Team ~= LP.Team
end

local function removeESP(p)
    local d = espObjects[p]; if not d then return end
    if d.hl  and d.hl.Parent  then d.hl:Destroy()  end
    if d.bb  and d.bb.Parent  then d.bb:Destroy()  end
    espObjects[p] = nil
end
local function removeAllESP() for p in pairs(espObjects) do removeESP(p) end end

local function updateESP(p)
    if p == LP then return end
    local char = p.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not Features.espEnabled or not char or not hrp or not hum or hum.Health <= 0 then removeESP(p); return end
    if not isEnemy(p) then removeESP(p); return end

    local d = espObjects[p] or {}; espObjects[p] = d
    local col = teamCol(p)

    if Features.espSettings.Box or Features.espSettings.BoxFilled then
        if not d.hl or not d.hl.Parent then
            local h = Instance.new("Highlight"); h.Name="RFunESP"; h.Adornee=char; h.Parent=char; d.hl=h
        end
        d.hl.OutlineColor        = col
        d.hl.FillColor           = col
        d.hl.OutlineTransparency = Features.espSettings.Box       and 0    or 1
        d.hl.FillTransparency    = Features.espSettings.BoxFilled and 0.55 or 1
        d.hl.Enabled             = true
    elseif d.hl then d.hl:Destroy(); d.hl=nil end

    if Features.espSettings.Name or Features.espSettings.Distance then
        if not d.bb or not d.bb.Parent then
            local bb = Instance.new("BillboardGui"); bb.Name="RFunBB"; bb.AlwaysOnTop=true
            bb.Size=UDim2.fromOffset(130,44); bb.StudsOffset=Vector3.new(0,3.5,0); bb.Adornee=hrp; bb.Parent=hrp
            local ul = Instance.new("UIListLayout"); ul.HorizontalAlignment=Enum.HorizontalAlignment.Center
            ul.SortOrder=Enum.SortOrder.LayoutOrder; ul.Parent=bb
            local nl = Instance.new("TextLabel"); nl.Name="NL"; nl.BackgroundTransparency=1
            nl.Size=UDim2.new(1,0,0,18); nl.Font=Enum.Font.GothamBold; nl.TextSize=13
            nl.TextStrokeTransparency=0.4; nl.LayoutOrder=1; nl.Parent=bb
            local dl = Instance.new("TextLabel"); dl.Name="DL"; dl.BackgroundTransparency=1
            dl.Size=UDim2.new(1,0,0,16); dl.Font=Enum.Font.Gotham; dl.TextSize=11
            dl.TextStrokeTransparency=0.4; dl.LayoutOrder=2; dl.Parent=bb
            d.bb = bb
        end
        local bb=d.bb; bb.Adornee=hrp; bb.Enabled=true
        local cam = workspace.CurrentCamera
        local nl=bb:FindFirstChild("NL"); if nl then nl.Visible=Features.espSettings.Name; if Features.espSettings.Name then nl.Text=p.DisplayName~="" and p.DisplayName or p.Name; nl.TextColor3=col end end
        local dl=bb:FindFirstChild("DL"); if dl then dl.Visible=Features.espSettings.Distance; if Features.espSettings.Distance and cam then dl.Text=math.floor((cam.CFrame.Position-hrp.Position).Magnitude).." studs"; dl.TextColor3=Color3.fromRGB(220,220,220) end end
    elseif d.bb then d.bb:Destroy(); d.bb=nil end
end

local function startESPLoop()
    if espLoop then return end
    espLoop = RunService.RenderStepped:Connect(function()
        if not Features.espEnabled then return end
        for _,p in ipairs(Players:GetPlayers()) do updateESP(p) end
    end)
end
local function stopESPLoop() if espLoop then espLoop:Disconnect(); espLoop=nil end end

function Features.setESP(on)
    Features.espEnabled = on
    if on then startESPLoop() else stopESPLoop(); removeAllESP() end
end
function Features.setESPSetting(k,v)
    Features.espSettings[k]=v
    if not Features.espEnabled then return end
    for _,p in ipairs(Players:GetPlayers()) do updateESP(p) end
end

Players.PlayerRemoving:Connect(removeESP)
LP.CharacterAdded:Connect(function() task.wait(0.2); if Features.espEnabled then removeAllESP() end end)

-- ═══════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════
local State = {
    autoLoadConfig=false, infiniteJump=false, esp=false, 
    silentAim=false,  -- Ganti aimbot jadi silent aim
    espSettings     = { Box=true, BoxFilled=false, Name=true, Distance=true, TeamCheck=true },
    silentAimSettings  = { 
        FOV=120, Smoothness=35, TeamCheck=true, 
        TargetPart="Head", Prediction=50, VisibleCheck=true 
    },
}

-- ═══════════════════════════════════════════════════════
--  KEYBINDS
-- ═══════════════════════════════════════════════════════
local Keybinds = {
    silentAim    = { key=Enum.KeyCode.Q, holdMode=false, label="Silent Aim" },
    esp          = { key=Enum.KeyCode.Z, holdMode=false, label="ESP" },
    infiniteJump = { key=Enum.KeyCode.X, holdMode=false, label="Inf Jump" },
}
local function keyName(kc)
    if typeof(kc) == "EnumItem" then return kc.Name end
    return tostring(kc):gsub("Enum%.KeyCode%.",""):gsub("Enum%.UserInputType%.","")
end

-- ═══════════════════════════════════════════════════════
--  UI  ── RED × BLACK THEME (HP OPTIMIZED)
-- ═══════════════════════════════════════════════════════
for _,c in ipairs(PGui:GetChildren()) do
    if c.Name=="RivalsFun3D" and not script:IsDescendantOf(c) then c:Destroy() end
end

local C = {
    bg          = Color3.fromRGB(6,   0,  0),
    panel       = Color3.fromRGB(14,  2,  2),
    row         = Color3.fromRGB(22,  4,  4),
    sidebarBg   = Color3.fromRGB(10,  0,  0),
    topBar      = Color3.fromRGB(14,  0,  0),
    accent      = Color3.fromRGB(210, 30, 30),
    accentBrt   = Color3.fromRGB(255, 55, 55),
    activeDim   = Color3.fromRGB(65,  8,  8),
    sep         = Color3.fromRGB(150, 18, 18),
    text        = Color3.fromRGB(255,255,255),
    textDim     = Color3.fromRGB(185,115,115),
    sliderTrack = Color3.fromRGB(40,   5,  5),
    toggleOff   = Color3.fromRGB(50,   8,  8),
    danger      = Color3.fromRGB(255, 80, 80),
}

local FONT     = Enum.Font.Gotham
local FONT_MED = Enum.Font.GothamMedium
local FONT_BOL = Enum.Font.GothamBold
local CR       = UDim.new(0,5)
local CR_SM    = UDim.new(0,4)

local function mkCorner(p,r)  local c=Instance.new("UICorner"); c.CornerRadius=r or CR; c.Parent=p; return c end
local function mkStroke(p,col,tr,th) local s=Instance.new("UIStroke"); s.Color=col or C.sep; s.Transparency=tr or 0.5; s.Thickness=th or 1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s end
local function mkPad(p,t,r,b,l) local x=Instance.new("UIPadding"); x.PaddingTop=UDim.new(0,t or 12); x.PaddingRight=UDim.new(0,r or 12); x.PaddingBottom=UDim.new(0,b or 12); x.PaddingLeft=UDim.new(0,l or 12); x.Parent=p; return x end

local function mkLabel(props)
    local l=Instance.new("TextLabel"); l.Name=props.Name or "Lbl"; l.BackgroundTransparency=1
    l.Font=props.Font or FONT; l.TextSize=props.TextSize or 13; l.TextColor3=props.TextColor or C.text
    l.Text=props.Text or ""; l.TextXAlignment=props.TextXAlignment or Enum.TextXAlignment.Left
    l.TextYAlignment=Enum.TextYAlignment.Center
    if props.Size        then l.Size=props.Size end
    if props.Position    then l.Position=props.Position end
    if props.LayoutOrder then l.LayoutOrder=props.LayoutOrder end
    l.Parent=props.Parent; return l
end

local function mkSep(parent,lo)
    local l=Instance.new("Frame"); l.Name="Sep"; l.Size=UDim2.new(1,0,0,1)
    l.BackgroundColor3=C.sep; l.BackgroundTransparency=0.4; l.BorderSizePixel=0
    l.LayoutOrder=lo or 0; l.Parent=parent; return l
end

-- ── GUI ROOT ───────────────────────────────────────────
local gui=Instance.new("ScreenGui"); gui.Name="RivalsFun3D"; gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.IgnoreGuiInset=true; gui.Parent=PGui

local function showToast(msg)
    local t=gui:FindFirstChild("Toast"); if t then t:Destroy() end
    local toast=Instance.new("Frame"); toast.Name="Toast"; toast.BackgroundColor3=Color3.fromRGB(12,0,0)
    toast.BorderSizePixel=0; toast.Size=UDim2.fromOffset(320,34)
    toast.Position=UDim2.new(0.5,0,1,-55); toast.AnchorPoint=Vector2.new(0.5,1); toast.ZIndex=200; toast.Parent=gui
    mkCorner(toast,CR); mkStroke(toast,C.accent,0,1)
    mkLabel({Parent=toast, Text=msg, TextSize=11, TextXAlignment=Enum.TextXAlignment.Center, Size=UDim2.fromScale(1,1)})
    task.delay(2.5,function() if toast.Parent then toast:Destroy() end end)
end

-- ROOT
local root=Instance.new("Frame"); root.Name="Root"; root.BackgroundColor3=C.bg
root.BorderSizePixel=0; root.Size=UDim2.new(0,560,0,400)
root.Position=UDim2.new(0.5,0,0.5,0); root.AnchorPoint=Vector2.new(0.5,0.5)
root.ClipsDescendants=true; root.ZIndex=1; root.Visible=false; root.Parent=gui
mkCorner(root,CR); mkStroke(root,C.accent,0,1)

-- ── PARTICLE LAYER ────────────────────────────────────
local ptLayer=Instance.new("Frame"); ptLayer.BackgroundTransparency=1
ptLayer.Size=UDim2.fromScale(1,1); ptLayer.ZIndex=2; ptLayer.Parent=root

local ptPool={}
local function spawnParticle()
    if #ptPool>=28 then return end
    local p=Instance.new("Frame")
    local sz=math.random(2,5)
    p.Size=UDim2.fromOffset(sz,sz)
    local xs=math.random()
    p.Position=UDim2.fromScale(xs,1.02)
    p.BackgroundColor3=math.random()<0.6 and C.accent or C.accentBrt
    p.BackgroundTransparency=math.random()*0.4+0.3
    p.BorderSizePixel=0; p.ZIndex=3
    mkCorner(p,UDim.new(1,0))
    p.Parent=ptLayer
    table.insert(ptPool,p)
    local life=math.random(35,75)/10
    local xDrift=(math.random()-0.5)*0.12
    TweenService:Create(p,TweenInfo.new(life,Enum.EasingStyle.Linear),{
        Position=UDim2.fromScale(xs+xDrift,-0.04),
        BackgroundTransparency=1,
    }):Play()
    task.delay(life,function()
        for i,v in ipairs(ptPool) do if v==p then table.remove(ptPool,i); break end end
        if p.Parent then p:Destroy() end
    end)
end

RunService.RenderStepped:Connect(function()
    if root.Visible and math.random()<0.045 then spawnParticle() end
end)

-- ── TOP BAR ──────────────────────────────────────────
local topBar=Instance.new("Frame"); topBar.Name="TopBar"; topBar.BackgroundColor3=C.topBar
topBar.BorderSizePixel=0; topBar.Size=UDim2.new(1,0,0,34)
topBar.ZIndex=10; topBar.Parent=root
local tbBorder=Instance.new("Frame"); tbBorder.Size=UDim2.new(1,0,0,1)
tbBorder.Position=UDim2.new(0,0,1,-1); tbBorder.BackgroundColor3=C.accent
tbBorder.BackgroundTransparency=0; tbBorder.BorderSizePixel=0; tbBorder.ZIndex=11; tbBorder.Parent=topBar

local tbLayout=Instance.new("UIListLayout"); tbLayout.FillDirection=Enum.FillDirection.Horizontal
tbLayout.VerticalAlignment=Enum.VerticalAlignment.Center; tbLayout.Padding=UDim.new(0,6)
tbLayout.SortOrder=Enum.SortOrder.LayoutOrder; tbLayout.Parent=topBar
mkPad(topBar,0,10,0,10)

-- Drag
local dragging,dragStart,dragOrigin=false,nil,nil
topBar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=i.Position; dragOrigin=root.Position
        i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local d=i.Position-dragStart
        root.Position=UDim2.new(dragOrigin.X.Scale,dragOrigin.X.Offset+d.X,dragOrigin.Y.Scale,dragOrigin.Y.Offset+d.Y)
    end
end)

-- Window dots
local wCtrl=Instance.new("Frame"); wCtrl.BackgroundTransparency=1
wCtrl.Size=UDim2.fromOffset(42,12)
wCtrl.LayoutOrder=1; wCtrl.Parent=topBar
local wl=Instance.new("UIListLayout"); wl.FillDirection=Enum.FillDirection.Horizontal
wl.Padding=UDim.new(0,4); wl.VerticalAlignment=Enum.VerticalAlignment.Center; wl.Parent=wCtrl

local winClose,winMin,winMax
for i,col in ipairs({Color3.fromRGB(255,75,55),Color3.fromRGB(255,185,55),Color3.fromRGB(55,200,75)}) do
    local d=Instance.new("TextButton"); d.Size=UDim2.fromOffset(10,10)
    d.BackgroundColor3=col
    d.Text=""; d.AutoButtonColor=false; mkCorner(d,UDim.new(1,0)); d.Parent=wCtrl
    if i==1 then winClose=d elseif i==2 then winMin=d else winMax=d end
end

mkLabel({Parent=topBar, Name="Title", Text="RIVALS FUN 3D", Font=FONT_BOL, TextSize=11, TextColor=C.accentBrt, LayoutOrder=3, Size=UDim2.fromOffset(120,22)})
mkLabel({Parent=topBar, Name="Hint",  Text="F9", Font=FONT, TextSize=9, TextColor=C.textDim, LayoutOrder=4, Size=UDim2.fromOffset(80,22)})

-- Brand
local brandLbl = Instance.new("TextLabel")
brandLbl.Name                = "Brand"
brandLbl.BackgroundTransparency = 1
brandLbl.Text                = "@strictlytech"
brandLbl.Font                = FONT_MED
brandLbl.TextSize            = 9
brandLbl.TextColor3          = Color3.fromRGB(255, 255, 255)
brandLbl.TextXAlignment      = Enum.TextXAlignment.Right
brandLbl.Size                = UDim2.fromOffset(100, 34)
brandLbl.Position            = UDim2.new(1, -10, 0, 0)
brandLbl.AnchorPoint         = Vector2.new(1, 0)
brandLbl.ZIndex              = 15
brandLbl.Parent              = topBar

-- ── BODY ─────────────────────────────────────────────
local body=Instance.new("Frame"); body.BackgroundTransparency=1; body.Name="Body"
body.Size=UDim2.new(1,0,1,-34)
body.Position=UDim2.fromOffset(0,34)
body.ZIndex=4; body.Parent=root

local SW=140

local sidebar=Instance.new("Frame"); sidebar.Name="Sidebar"; sidebar.BackgroundColor3=C.sidebarBg
sidebar.BorderSizePixel=0; sidebar.Size=UDim2.new(0,SW,1,0); sidebar.ZIndex=5; sidebar.Parent=body
local sbLine=Instance.new("Frame"); sbLine.Size=UDim2.new(0,1,1,0); sbLine.Position=UDim2.new(1,-1,0,0)
sbLine.BackgroundColor3=C.accent; sbLine.BackgroundTransparency=0.2; sbLine.BorderSizePixel=0; sbLine.Parent=sidebar

local sbScroll=Instance.new("ScrollingFrame"); sbScroll.BackgroundTransparency=1; sbScroll.BorderSizePixel=0
sbScroll.Size=UDim2.fromScale(1,1); sbScroll.CanvasSize=UDim2.new(0,0,0,0)
sbScroll.ScrollBarThickness=2; sbScroll.ScrollBarImageColor3=C.accent
sbScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; sbScroll.Parent=sidebar
mkPad(sbScroll,6,6,6,6)
local sbLL=Instance.new("UIListLayout"); sbLL.Padding=UDim.new(0,2); sbLL.SortOrder=Enum.SortOrder.LayoutOrder; sbLL.Parent=sbScroll

local brandBlock = Instance.new("Frame")
brandBlock.Name = "BrandBlock"
brandBlock.BackgroundTransparency = 1
brandBlock.Size = UDim2.new(1, 0, 0, 44)
brandBlock.LayoutOrder = 0
brandBlock.Parent = sbScroll

local brandLL = Instance.new("UIListLayout")
brandLL.Padding = UDim.new(0, 2)
brandLL.SortOrder = Enum.SortOrder.LayoutOrder
brandLL.Parent = brandBlock

local versionLbl = Instance.new("TextLabel")
versionLbl.Name = "Version"
versionLbl.BackgroundTransparency = 1
versionLbl.Text = "ISLAND V2"
versionLbl.Font = FONT_BOL
versionLbl.TextSize = 14
versionLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
versionLbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
versionLbl.TextStrokeTransparency = 0.35
versionLbl.TextXAlignment = Enum.TextXAlignment.Left
versionLbl.Size = UDim2.new(1, 0, 0, 20)
versionLbl.LayoutOrder = 1
versionLbl.Parent = brandBlock

mkLabel({
    Parent=brandBlock, Name="Credit",
    Text='@strictlytech',
    Font=FONT, TextSize=8,
    TextColor=Color3.fromRGB(255, 255, 255),
    LayoutOrder=2,
    Size=UDim2.new(1, 0, 0, 20),
})

local navBtns={} local activeNav=nil

local function setNavActive(btn)
    if activeNav then
        activeNav.BackgroundColor3=Color3.fromRGB(0,0,0); activeNav.BackgroundTransparency=1
        activeNav.TextColor3=C.textDim
        local s=activeNav:FindFirstChildOfClass("UIStroke"); if s then s.Color=C.sep; s.Transparency=0.6 end
    end
    activeNav=btn; btn.BackgroundColor3=C.activeDim; btn.BackgroundTransparency=0; btn.TextColor3=C.accentBrt
    local s=btn:FindFirstChildOfClass("UIStroke"); if s then s.Color=C.accentBrt; s.Transparency=0 end
end

local function mkNav(text,lo,onClick)
    local btn=Instance.new("TextButton"); btn.Name=text:gsub(" ",""); btn.LayoutOrder=lo
    btn.Size=UDim2.new(1,0,0,24)
    btn.BackgroundColor3=Color3.fromRGB(0,0,0); btn.BackgroundTransparency=1
    btn.Font=FONT_MED; btn.TextSize=10
    btn.Text="  "..text; btn.TextColor3=C.textDim
    btn.TextXAlignment=Enum.TextXAlignment.Left; btn.AutoButtonColor=false
    mkCorner(btn,CR_SM); mkStroke(btn,C.sep,0.6,1); btn.Parent=sbScroll
    navBtns[text]=btn
    btn.MouseButton1Click:Connect(function() setNavActive(btn); if onClick then onClick() end end)
    return btn
end

local function mkNavHdr(text,lo)
    mkLabel({Parent=sbScroll,Text=text,Font=FONT_BOL,TextSize=8,TextColor=C.accent,LayoutOrder=lo,Size=UDim2.new(1,0,0,16)})
end

mkNavHdr("COMBAT",    1); mkNav("Silent Aim",   2)
mkSep(sbScroll,3)
mkNavHdr("MOVEMENT",  4); mkNav("Infinite Jump",  5)
mkSep(sbScroll,6)
mkNavHdr("VISUALS",   7); mkNav("ESP",            8)
mkSep(sbScroll,9)
mkNavHdr("SETTINGS",  10); mkNav("Config",      11); mkNav("Keybinds",      12)

-- Main panel
local main=Instance.new("Frame"); main.Name="Main"; main.BackgroundColor3=C.panel
main.BorderSizePixel=0; main.Size=UDim2.new(1,-SW,1,0); main.Position=UDim2.fromOffset(SW,0); main.ZIndex=4; main.Parent=body

local mainScroll=Instance.new("ScrollingFrame"); mainScroll.BackgroundTransparency=1; mainScroll.BorderSizePixel=0
mainScroll.Size=UDim2.fromScale(1,1); mainScroll.CanvasSize=UDim2.new(0,0,0,0)
mainScroll.ScrollBarThickness=2; mainScroll.ScrollBarImageColor3=C.accent
mainScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; mainScroll.Parent=main
mkPad(mainScroll,10,10,10,10)
local mainLL=Instance.new("UIListLayout"); mainLL.Padding=UDim.new(0,8); mainLL.SortOrder=Enum.SortOrder.LayoutOrder; mainLL.Parent=mainScroll

local function secHead(text,order)
    return mkLabel({Parent=mainScroll,Text=text:upper(),Font=FONT_BOL,TextSize=9,TextColor=C.accent,LayoutOrder=order,Size=UDim2.new(1,0,0,14)})
end

local function mkRow(title,lo,h)
    local f=Instance.new("Frame"); f.Name=title; f.BackgroundColor3=C.row; f.BorderSizePixel=0
    f.Size=UDim2.new(1,0,0,h or 42)
    f.LayoutOrder=lo; f.Parent=mainScroll
    mkCorner(f,CR); mkStroke(f,C.sep,0.45,1); mkPad(f,8,8,8,8)
    return f
end

local function createToggle(props)
    local row=mkRow(props.title,props.layoutOrder,42)
    local info=Instance.new("Frame"); info.BackgroundTransparency=1; info.Size=UDim2.new(1,-44,1,0); info.Parent=row
    mkLabel({Parent=info,Text=props.title,Font=FONT_MED,TextSize=11,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,16)})
    mkLabel({Parent=info,Text=props.desc or "",TextSize=9,TextColor=C.textDim,Position=UDim2.fromOffset(0,16),Size=UDim2.new(1,0,0,14)})
    local track=Instance.new("TextButton"); track.AnchorPoint=Vector2.new(1,0.5); track.Position=UDim2.new(1,0,0.5,0)
    track.Size=UDim2.fromOffset(36,18)
    track.Text=""; track.AutoButtonColor=false; mkCorner(track,UDim.new(1,0)); track.Parent=row
    local knob=Instance.new("Frame"); knob.Size=UDim2.fromOffset(14,14)
    knob.BorderSizePixel=0; mkCorner(knob,UDim.new(1,0)); knob.Parent=track
    local on=props.default==true
    local function paint()
        track.BackgroundColor3=on and C.accent or C.toggleOff
        knob.Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,2,0.5,-7)
        knob.BackgroundColor3=C.text
    end
    paint()
    track.MouseButton1Click:Connect(function()
        on=not on; paint()
        TweenService:Create(knob,TweenInfo.new(0.12,Enum.EasingStyle.Quad),{Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
        if props.onChange then props.onChange(on) end
    end)
    return row
end

local function createSlider(props)
    local row=mkRow(props.title,props.layoutOrder,52)
    mkLabel({Parent=row,Text=props.title,Font=FONT_MED,TextSize=11,Position=UDim2.fromOffset(0,0),Size=UDim2.new(0.65,0,0,16)})
    local vl=mkLabel({Parent=row,Name="Val",Text=tostring(props.default),Font=FONT_MED,TextSize=10,TextColor=C.accentBrt,TextXAlignment=Enum.TextXAlignment.Right,Position=UDim2.new(1,-32,0,0),Size=UDim2.fromOffset(32,16)})
    mkLabel({Parent=row,Text=props.desc or "",TextSize=9,TextColor=C.textDim,Position=UDim2.fromOffset(0,17),Size=UDim2.new(1,0,0,12)})
    local trk=Instance.new("Frame"); trk.BackgroundColor3=C.sliderTrack; trk.BorderSizePixel=0
    trk.Position=UDim2.fromOffset(0,34); trk.Size=UDim2.new(1,0,0,4); mkCorner(trk,UDim.new(1,0)); trk.Parent=row
    local fill=Instance.new("Frame"); fill.BackgroundColor3=C.accent; fill.BorderSizePixel=0
    fill.Size=UDim2.fromScale(0.5,1); mkCorner(fill,UDim.new(1,0)); fill.Parent=trk
    local hit=Instance.new("TextButton"); hit.BackgroundTransparency=1; hit.Text=""
    hit.Size=UDim2.new(1,0,0,16); hit.Position=UDim2.fromOffset(0,28); hit.ZIndex=2; hit.Parent=row
    local drag=false
    local function setV(a)
        a=math.clamp(a,0,1); local v=math.floor(props.min+(props.max-props.min)*a+0.5)
        fill.Size=UDim2.fromScale(a,1); vl.Text=tostring(v); if props.onChange then props.onChange(v) end
    end
    setV((props.default-props.min)/(props.max-props.min))
    local function fromI(i) setV((i.Position.X-trk.AbsolutePosition.X)/trk.AbsoluteSize.X) end
    hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true; fromI(i) end end)
    UIS.InputChanged:Connect(function(i) if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then fromI(i) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end)
    return row
end

local function createDropdown(props)
    local row=mkRow(props.title,props.layoutOrder,52)
    mkLabel({Parent=row,Text=props.title,Font=FONT_MED,TextSize=11,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,-110,0,16)})
    mkLabel({Parent=row,Text=props.desc or "",TextSize=9,TextColor=C.textDim,Position=UDim2.fromOffset(0,17),Size=UDim2.new(1,-110,0,12)})
    local btn=Instance.new("TextButton"); btn.AnchorPoint=Vector2.new(1,0.5); btn.Position=UDim2.new(1,0,0.5,4)
    btn.Size=UDim2.fromOffset(100,22)
    btn.BackgroundColor3=C.activeDim; btn.Font=FONT; btn.TextSize=10
    btn.Text="  "..tostring(props.default).."  ▾"; btn.TextColor3=C.text; btn.TextXAlignment=Enum.TextXAlignment.Left
    btn.AutoButtonColor=false; mkCorner(btn,CR_SM); mkStroke(btn,C.accent,0,1); btn.Parent=row
    local open=false; local mr
    local function closeM() open=false; if mr then mr:Destroy(); mr=nil end end
    local function openM()
        closeM(); open=true
        local opts=props.options or {}; local iH,pV=22,3
        local cnt=#opts
        local cH=cnt*iH+math.max(0,cnt-1)*2+pV*2; local mH=math.min(cH,150)
        local ap=btn.AbsolutePosition; local as=btn.AbsoluteSize; local ga=gui.AbsolutePosition
        mr=Instance.new("Frame"); mr.BackgroundTransparency=1; mr.Size=UDim2.fromOffset(as.X,mH+4)
        mr.Position=UDim2.fromOffset(ap.X-ga.X,ap.Y-ga.Y+as.Y+3); mr.ZIndex=220; mr.Parent=gui
        local menu=Instance.new("ScrollingFrame"); menu.BackgroundColor3=Color3.fromRGB(16,2,2); menu.BorderSizePixel=0
        menu.Size=UDim2.new(1,0,1,0); menu.CanvasSize=UDim2.fromOffset(0,cH); menu.ScrollBarThickness=2
        menu.ScrollBarImageColor3=C.accent; menu.ZIndex=221; menu.ClipsDescendants=true; menu.Parent=mr
        mkCorner(menu,CR_SM); mkStroke(menu,C.accent,0,1); mkPad(menu,pV,3,pV,3)
        local ml=Instance.new("UIListLayout"); ml.Padding=UDim.new(0,2); ml.SortOrder=Enum.SortOrder.LayoutOrder; ml.Parent=menu
        for i,o in ipairs(opts) do
            local ob=Instance.new("TextButton"); ob.LayoutOrder=i; ob.Size=UDim2.new(1,0,0,iH)
            ob.BackgroundTransparency=1; ob.BackgroundColor3=C.activeDim; ob.Font=FONT; ob.TextSize=10
            ob.Text="  "..tostring(o); ob.TextColor3=C.text; ob.TextXAlignment=Enum.TextXAlignment.Left
            ob.AutoButtonColor=false; ob.ZIndex=222; ob.Parent=menu
            ob.MouseButton1Click:Connect(function() btn.Text="  "..tostring(o).."  ▾"; closeM(); if props.onSelect then props.onSelect(o) end end)
        end
    end
    btn.MouseButton1Click:Connect(function() if open then closeM() else openM() end end)
    return {Close=closeM}
end

local dropdowns={}
local function clearContent()
    for _,d in ipairs(dropdowns) do if d and d.Close then d.Close() end end; dropdowns={}
    for _,ch in ipairs(mainScroll:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
    end
    mainScroll.CanvasPosition=Vector2.zero
end

-- ═══════════════════════════════════════════════════════
--  CONFIG SYSTEM
-- ═══════════════════════════════════════════════════════
local listeningFor=nil
local kbBtns={}

local function createKeybindRow(props)
    local id = props.id
    local bind = Keybinds[id]
    local row = mkRow(bind.label, props.layoutOrder, 44)
    row.Name = id
    local info=Instance.new("Frame"); info.BackgroundTransparency=1; info.Size=UDim2.new(1,-150,1,0); info.Parent=row
    mkLabel({Parent=info,Text=props.title or bind.label,Font=FONT_MED,TextSize=11,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,16)})
    mkLabel({Parent=info,Name="CK",Text="Key: "..keyName(bind.key),TextSize=9,TextColor=C.textDim,Position=UDim2.fromOffset(0,16),Size=UDim2.new(1,0,0,14)})

    local hb=Instance.new("TextButton"); hb.AnchorPoint=Vector2.new(1,0.5); hb.Position=UDim2.new(1,0,0.5,0)
    hb.Size=UDim2.fromOffset(58,20)
    hb.Font=FONT; hb.TextSize=9
    hb.Text=bind.holdMode and "HOLD" or "TOGGLE"; hb.BackgroundColor3=bind.holdMode and C.accent or Color3.fromRGB(38,8,8)
    hb.TextColor3=C.text; hb.AutoButtonColor=false; mkCorner(hb,CR_SM); hb.Parent=row
    hb.MouseButton1Click:Connect(function()
        bind.holdMode=not bind.holdMode
        hb.Text=bind.holdMode and "HOLD" or "TOGGLE"; hb.BackgroundColor3=bind.holdMode and C.accent or Color3.fromRGB(38,8,8)
    end)

    local kb=Instance.new("TextButton"); kb.AnchorPoint=Vector2.new(1,0.5); kb.Position=UDim2.new(1,-65,0.5,0)
    kb.Size=UDim2.fromOffset(58,20)
    kb.Font=FONT_MED; kb.TextSize=10
    kb.Text=keyName(bind.key); kb.BackgroundColor3=Color3.fromRGB(28,4,4); kb.TextColor3=C.text; kb.AutoButtonColor=false
    mkCorner(kb,CR_SM); mkStroke(kb,C.accent,0,1); kb.Parent=row; kbBtns[id]=kb
    kb.MouseButton1Click:Connect(function()
        if listeningFor==id then
            listeningFor=nil; kb.Text=keyName(bind.key); kb.BackgroundColor3=Color3.fromRGB(28,4,4)
        else
            if listeningFor and kbBtns[listeningFor] then
                kbBtns[listeningFor].Text=keyName(Keybinds[listeningFor].key)
                kbBtns[listeningFor].BackgroundColor3=Color3.fromRGB(28,4,4)
            end
            listeningFor=id; kb.Text="[press]"; kb.BackgroundColor3=C.activeDim
        end
    end)
    return row
end

local function createActionRow(props)
    local row=mkRow(props.title,props.layoutOrder,44)
    local info=Instance.new("Frame"); info.BackgroundTransparency=1; info.Size=UDim2.new(1,-76,1,0); info.Parent=row
    mkLabel({Parent=info,Text=props.title,Font=FONT_MED,TextSize=11,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,16)})
    mkLabel({Parent=info,Text=props.desc or "",TextSize=9,TextColor=C.textDim,Position=UDim2.fromOffset(0,16),Size=UDim2.new(1,0,0,14)})
    local btn=Instance.new("TextButton"); btn.AnchorPoint=Vector2.new(1,0.5); btn.Position=UDim2.new(1,0,0.5,0)
    btn.Size=UDim2.fromOffset(66,22)
    btn.BackgroundColor3=C.activeDim; btn.Font=FONT_MED; btn.TextSize=10
    btn.Text=props.buttonText; btn.TextColor3=C.text; btn.AutoButtonColor=false
    mkCorner(btn,CR_SM); mkStroke(btn,C.accent,0,1); btn.Parent=row
    btn.MouseButton1Click:Connect(function() if props.onClick then props.onClick() end end)
    return row
end

local configName = "RivalsFun3D_Config.json"

local function saveConfig()
    local data = { State = State, Keybinds = {} }
    for k,v in pairs(Keybinds) do
        data.Keybinds[k] = { keyName = v.key.Name, keyType = tostring(v.key.EnumType), holdMode = v.holdMode }
    end
    if writefile then
        local s,e = pcall(function() writefile(configName, HttpService:JSONEncode(data)) end)
        if s then showToast("Config saved!") else showToast("Error saving config!") end
    else
        showToast("Executor does not support writefile!")
    end
end

local function loadConfig(silent)
    if readfile and isfile and isfile(configName) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(configName)) end)
        if success and data then
            if data.State then
                for k,v in pairs(data.State) do
                    if type(v)=="table" and type(State[k])=="table" then
                        for k2,v2 in pairs(v) do State[k][k2] = v2 end
                    else
                        State[k] = v
                    end
                end
                Features.setInfiniteJump(State.infiniteJump)
                Features.setESP(State.esp)
                for k,v in pairs(State.espSettings) do Features.setESPSetting(k,v) end
                setSilentAim(State.silentAim)
                for k,v in pairs(State.silentAimSettings) do SilentAim[k] = v end
            end
            if data.Keybinds then
                for k,v in pairs(data.Keybinds) do
                    if Keybinds[k] then
                        Keybinds[k].holdMode = v.holdMode
                        if v.keyType == tostring(Enum.KeyCode) and Enum.KeyCode[v.keyName] then
                            Keybinds[k].key = Enum.KeyCode[v.keyName]
                        elseif v.keyType == tostring(Enum.UserInputType) and Enum.UserInputType[v.keyName] then
                            Keybinds[k].key = Enum.UserInputType[v.keyName]
                        end
                    end
                end
            end
            if not silent then showToast("Config loaded!") end
        else
            if not silent then showToast("Failed to parse config file!") end
        end
    else
        if not silent then showToast("No config file found or executor unsupported!") end
    end
end

local function renderConfig()
    clearContent(); local lo=1
    secHead("Config",lo); lo+=1
    createToggle({title="Auto Load Config",desc="Load automatically when script starts",layoutOrder=lo,default=State.autoLoadConfig,onChange=function(on) State.autoLoadConfig=on end}); lo+=1
    createActionRow({title="Save Configuration", desc="Saves your settings to " .. configName, buttonText="SAVE", layoutOrder=lo, onClick=saveConfig}); lo+=1
    createActionRow({title="Load Configuration", desc="Loads your settings from " .. configName, buttonText="LOAD", layoutOrder=lo, onClick=function() loadConfig(false) end}); lo+=1
end

-- ═══════════════════════════════════════════════════════
--  PAGE RENDERERS (UPDATED)
-- ═══════════════════════════════════════════════════════
local function renderKeybinds()
    clearContent(); local lo=1
    secHead("Keybinds",lo); lo+=1
    mkLabel({Parent=mainScroll,Text="Click key to reassign",TextSize=9,TextColor=C.textDim,LayoutOrder=lo,Size=UDim2.new(1,0,0,14)}); lo+=1
    mkSep(mainScroll,lo); lo+=1
    createKeybindRow({id="silentAim", layoutOrder=lo}); lo+=1
    createKeybindRow({id="esp", layoutOrder=lo}); lo+=1
    createKeybindRow({id="infiniteJump", layoutOrder=lo}); lo+=1
end

local function renderInfiniteJump()
    clearContent(); local lo=1
    secHead("Movement",lo); lo+=1
    createToggle({title="Infinite Jump",desc="Jump again while in the air",layoutOrder=lo,default=State.infiniteJump,
        onChange=function(on) State.infiniteJump=on; Features.setInfiniteJump(on); showToast("Infinite Jump: "..(on and "ON" or "OFF")) end})
end

local function renderESP()
    clearContent(); local lo=1
    secHead("Visuals",lo); lo+=1
    createToggle({title="ESP",desc="See enemies through walls",layoutOrder=lo,default=State.esp,
        onChange=function(on) State.esp=on; Features.setESP(on); showToast("ESP: "..(on and "ON" or "OFF")) end}); lo+=1
    mkSep(mainScroll,lo); lo+=1; secHead("ESP Settings",lo); lo+=1
    createToggle({title="Box",desc="Outline around enemy model",layoutOrder=lo,default=State.espSettings.Box,onChange=function(on) State.espSettings.Box=on; Features.setESPSetting("Box",on) end}); lo+=1
    createToggle({title="Box Filled",desc="Fill highlight over player model",layoutOrder=lo,default=State.espSettings.BoxFilled,onChange=function(on) State.espSettings.BoxFilled=on; Features.setESPSetting("BoxFilled",on) end}); lo+=1
    createToggle({title="Name",desc="Show name tag above player",layoutOrder=lo,default=State.espSettings.Name,onChange=function(on) State.espSettings.Name=on; Features.setESPSetting("Name",on) end}); lo+=1
    createToggle({title="Distance",desc="Show distance in studs",layoutOrder=lo,default=State.espSettings.Distance,onChange=function(on) State.espSettings.Distance=on; Features.setESPSetting("Distance",on) end}); lo+=1
    createToggle({title="Team Check",desc="Skip teammates",layoutOrder=lo,default=State.espSettings.TeamCheck,onChange=function(on) State.espSettings.TeamCheck=on; Features.setESPSetting("TeamCheck",on) end})
end

local function renderSilentAim()
    clearContent(); local lo=1
    secHead("Silent Aim",lo); lo+=1
    createToggle({title="Silent Aim",desc="Auto-aim without moving mouse cursor",layoutOrder=lo,default=State.silentAim,
        onChange=function(on) 
            State.silentAim=on; 
            setSilentAim(on); 
            showToast("Silent Aim: "..(on and "ON" or "OFF")) 
        end}); lo+=1
    mkSep(mainScroll,lo); lo+=1; secHead("Silent Aim Settings",lo); lo+=1
    createSlider({title="FOV",desc="Detection radius (pixels from mouse cursor)",layoutOrder=lo,min=20,max=400,default=State.silentAimSettings.FOV,
        onChange=function(v) State.silentAimSettings.FOV=v; SilentAim.FOV=v end}); lo+=1
    createSlider({title="Smoothness",desc="0 = instant  ·  99 = gradual",layoutOrder=lo,min=0,max=99,default=State.silentAimSettings.Smoothness,
        onChange=function(v) State.silentAimSettings.Smoothness=v; SilentAim.Smoothness=v end}); lo+=1
    createSlider({title="Prediction",desc="Lead moving targets  ·  0 = off",layoutOrder=lo,min=0,max=100,default=State.silentAimSettings.Prediction,
        onChange=function(v) State.silentAimSettings.Prediction=v; SilentAim.Prediction=v end}); lo+=1
    createToggle({title="Team Check",desc="Skip teammates when targeting",layoutOrder=lo,default=State.silentAimSettings.TeamCheck,
        onChange=function(on) State.silentAimSettings.TeamCheck=on; SilentAim.TeamCheck=on end}); lo+=1
    createToggle({title="Visible Check",desc="Only target visible enemies",layoutOrder=lo,default=State.silentAimSettings.VisibleCheck,
        onChange=function(on) State.silentAimSettings.VisibleCheck=on; SilentAim.VisibleCheck=on end}); lo+=1
    local dd=createDropdown({title="Target Part",desc="Which body part to aim at",layoutOrder=lo,default=State.silentAimSettings.TargetPart,
        options={"Head","HumanoidRootPart","UpperTorso"},
        onSelect=function(o) State.silentAimSettings.TargetPart=o; SilentAim.TargetPart=o end})
    table.insert(dropdowns,dd)
end

-- ═══════════════════════════════════════════════════════
--  WIRE NAV BUTTONS
-- ═══════════════════════════════════════════════════════
navBtns["Silent Aim"].MouseButton1Click:Connect(renderSilentAim)
navBtns["Infinite Jump"].MouseButton1Click:Connect(renderInfiniteJump)
navBtns["ESP"].MouseButton1Click:Connect(renderESP)
navBtns["Config"].MouseButton1Click:Connect(renderConfig)
navBtns["Keybinds"].MouseButton1Click:Connect(renderKeybinds)

task.defer(function()
    setNavActive(navBtns["Silent Aim"])
    renderSilentAim()
end)

-- ═══════════════════════════════════════════════════════
--  PANEL OPEN / CLOSE
-- ═══════════════════════════════════════════════════════
local savedMouseBehavior = Enum.MouseBehavior.LockCenter

local function openPanel()
    savedMouseBehavior = UIS.MouseBehavior
    UIS.MouseBehavior  = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
    root.Visible = true
end

local function closePanel()
    root.Visible = false
    UIS.MouseBehavior    = savedMouseBehavior
    UIS.MouseIconEnabled = false
end

local function togglePanel()
    if root.Visible then closePanel() else openPanel() end
end

-- FLOAT BUTTON
local floatBtn = Instance.new("TextButton")
floatBtn.Name = "RFunFloat"
floatBtn.Size = UDim2.fromOffset(34, 34)
floatBtn.Position = UDim2.new(0, 12, 0.5, -17)
floatBtn.BackgroundColor3 = C.panel
floatBtn.Text = "SA"
floatBtn.Font = FONT_BOL
floatBtn.TextSize = 12
floatBtn.TextColor3 = C.accentBrt
floatBtn.BorderSizePixel = 0
floatBtn.ZIndex = 100
floatBtn.Parent = gui
mkCorner(floatBtn, UDim.new(1,0))
mkStroke(floatBtn, C.accent, 0, 1.5)

local floatDrag, floatStartPos, floatStartInput = false, nil, nil
floatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        floatDrag = true
        floatStartPos = floatBtn.Position
        floatStartInput = input.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                floatDrag = false
                if (input.Position - floatStartInput).Magnitude < 5 then
                    togglePanel()
                end
            end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if floatDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - floatStartInput
        floatBtn.Position = UDim2.new(floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X, floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y)
    end
end)

-- ═══════════════════════════════════════════════════════
--  WINDOW CONTROLS
-- ═══════════════════════════════════════════════════════
if winClose then winClose.MouseButton1Click:Connect(closePanel) end
if winMin   then winMin.MouseButton1Click:Connect(closePanel)   end
if winMax   then winMax.MouseButton1Click:Connect(openPanel)    end

-- ═══════════════════════════════════════════════════════
--  GLOBAL INPUT (UPDATED)
-- ═══════════════════════════════════════════════════════
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end

    if listeningFor then
        local isKey = input.UserInputType == Enum.UserInputType.Keyboard
        local isMouse = input.UserInputType.Name:match("MouseButton")
        if isKey or isMouse then
            local id=listeningFor; local bind=Keybinds[id]
            bind.key = isKey and input.KeyCode or input.UserInputType; listeningFor=nil
            local kb=kbBtns[id]
            if kb then kb.Text=keyName(bind.key); kb.BackgroundColor3=Color3.fromRGB(28,4,4) end
            local row=mainScroll:FindFirstChild(id)
            if row then local inf=row:FindFirstChildOfClass("Frame"); if inf then local lbl=inf:FindFirstChild("CK"); if lbl then lbl.Text="Key: "..keyName(bind.key) end end end
            showToast(bind.label.." → "..keyName(bind.key))
            return
        end
    end

    for id,bind in pairs(Keybinds) do
        local match = false
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind.key then match = true end
        if input.UserInputType.Name:match("MouseButton") and input.UserInputType == bind.key then match = true end

        if match then
            if bind.holdMode then
                if id=="silentAim" then setSilentAim(true)
                elseif id=="esp" then Features.setESP(true)
                elseif id=="infiniteJump" then Features.setInfiniteJump(true) end
            else
                if id=="silentAim" then 
                    State.silentAim=not State.silentAim
                    setSilentAim(State.silentAim)
                    showToast("Silent Aim: "..(State.silentAim and "ON" or "OFF"))
                elseif id=="esp" then 
                    State.esp=not State.esp
                    Features.setESP(State.esp)
                    showToast("ESP: "..(State.esp and "ON" or "OFF"))
                elseif id=="infiniteJump" then 
                    State.infiniteJump=not State.infiniteJump
                    Features.setInfiniteJump(State.infiniteJump)
                    showToast("Inf Jump: "..(State.infiniteJump and "ON" or "OFF")) 
                end
            end
        end
    end

    if input.KeyCode==Enum.KeyCode.RightShift or input.KeyCode==Enum.KeyCode.F9 then
        togglePanel()
    end
end)

UIS.InputEnded:Connect(function(input)
    for id,bind in pairs(Keybinds) do
        local match = false
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind.key then match = true end
        if input.UserInputType.Name:match("MouseButton") and input.UserInputType == bind.key then match = true end

        if bind.holdMode and match then
            if id=="silentAim" then setSilentAim(false)
            elseif id=="esp" then Features.setESP(false)
            elseif id=="infiniteJump" then Features.setInfiniteJump(false) end
        end
    end
end)

task.delay(1.5,function()
    showToast("Rivals Fun 3D  ·  Press F9  ·  Silent Aim Ready!")
end)

print("[Rivals Fun 3D] Loaded — RightShift / F9 to open menu")

if readfile and isfile and isfile(configName) then
    local success, data = pcall(function() return HttpService:JSONDecode(readfile(configName)) end)
    if success and data and data.State and data.State.autoLoadConfig then
        loadConfig(true)
    end
end
function Features.setInfiniteJump(on)
	Features.infiniteJumpEnabled = on
	if on then startIJ() else stopIJ() end
end

LP.CharacterAdded:Connect(function()
	task.wait(0.2)
	if Features.infiniteJumpEnabled then startIJ() end
end)

-- ═══════════════════════════════════════════════════════
--  ESP
-- ═══════════════════════════════════════════════════════
Features.espEnabled  = false
Features.espSettings = { Box=true, BoxFilled=false, Name=true, Distance=true, TeamCheck=true }

local espObjects = {}
local espLoop    = nil

local function teamCol(p) return p.Team and p.Team.TeamColor.Color or Color3.fromRGB(255,60,60) end
local function isEnemy(p)
	if not Features.espSettings.TeamCheck then return true end
	if not LP.Team or not p.Team        then return true end
	return p.Team ~= LP.Team
end

local function removeESP(p)
	local d = espObjects[p]; if not d then return end
	if d.hl  and d.hl.Parent  then d.hl:Destroy()  end
	if d.bb  and d.bb.Parent  then d.bb:Destroy()  end
	espObjects[p] = nil
end
local function removeAllESP() for p in pairs(espObjects) do removeESP(p) end end

local function updateESP(p)
	if p == LP then return end
	local char = p.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not Features.espEnabled or not char or not hrp or not hum or hum.Health <= 0 then removeESP(p); return end
	if not isEnemy(p) then removeESP(p); return end

	local d = espObjects[p] or {}; espObjects[p] = d
	local col = teamCol(p)

	if Features.espSettings.Box or Features.espSettings.BoxFilled then
		if not d.hl or not d.hl.Parent then
			local h = Instance.new("Highlight"); h.Name="RFunESP"; h.Adornee=char; h.Parent=char; d.hl=h
		end
		d.hl.OutlineColor        = col
		d.hl.FillColor           = col
		d.hl.OutlineTransparency = Features.espSettings.Box       and 0    or 1
		d.hl.FillTransparency    = Features.espSettings.BoxFilled and 0.55 or 1
		d.hl.Enabled             = true
	elseif d.hl then d.hl:Destroy(); d.hl=nil end

	if Features.espSettings.Name or Features.espSettings.Distance then
		if not d.bb or not d.bb.Parent then
			local bb = Instance.new("BillboardGui"); bb.Name="RFunBB"; bb.AlwaysOnTop=true
			bb.Size=UDim2.fromOffset(130,44); bb.StudsOffset=Vector3.new(0,3.5,0); bb.Adornee=hrp; bb.Parent=hrp
			local ul = Instance.new("UIListLayout"); ul.HorizontalAlignment=Enum.HorizontalAlignment.Center
			ul.SortOrder=Enum.SortOrder.LayoutOrder; ul.Parent=bb
			local nl = Instance.new("TextLabel"); nl.Name="NL"; nl.BackgroundTransparency=1
			nl.Size=UDim2.new(1,0,0,18); nl.Font=Enum.Font.GothamBold; nl.TextSize=13
			nl.TextStrokeTransparency=0.4; nl.LayoutOrder=1; nl.Parent=bb
			local dl = Instance.new("TextLabel"); dl.Name="DL"; dl.BackgroundTransparency=1
			dl.Size=UDim2.new(1,0,0,16); dl.Font=Enum.Font.Gotham; dl.TextSize=11
			dl.TextStrokeTransparency=0.4; dl.LayoutOrder=2; dl.Parent=bb
			d.bb = bb
		end
		local bb=d.bb; bb.Adornee=hrp; bb.Enabled=true
		local cam = workspace.CurrentCamera
		local nl=bb:FindFirstChild("NL"); if nl then nl.Visible=Features.espSettings.Name; if Features.espSettings.Name then nl.Text=p.DisplayName~="" and p.DisplayName or p.Name; nl.TextColor3=col end end
		local dl=bb:FindFirstChild("DL"); if dl then dl.Visible=Features.espSettings.Distance; if Features.espSettings.Distance and cam then dl.Text=math.floor((cam.CFrame.Position-hrp.Position).Magnitude).." studs"; dl.TextColor3=Color3.fromRGB(220,220,220) end end
	elseif d.bb then d.bb:Destroy(); d.bb=nil end
end

local function startESPLoop()
	if espLoop then return end
	espLoop = RunService.RenderStepped:Connect(function()
		if not Features.espEnabled then return end
		for _,p in ipairs(Players:GetPlayers()) do updateESP(p) end
	end)
end
local function stopESPLoop() if espLoop then espLoop:Disconnect(); espLoop=nil end end

function Features.setESP(on)
	Features.espEnabled = on
	if on then startESPLoop() else stopESPLoop(); removeAllESP() end
end
function Features.setESPSetting(k,v)
	Features.espSettings[k]=v
	if not Features.espEnabled then return end
	for _,p in ipairs(Players:GetPlayers()) do updateESP(p) end
end

Players.PlayerRemoving:Connect(removeESP)
LP.CharacterAdded:Connect(function() task.wait(0.2); if Features.espEnabled then removeAllESP() end end)

-- ═══════════════════════════════════════════════════════
--  AIMBOT  (mouse-tracked FOV, prediction, lock-on)
-- ═══════════════════════════════════════════════════════
Features.aimbotEnabled  = false
Features.aimbotSettings = {
	FOV=120, Smoothness=35, TeamCheck=true,
	TargetPart="Head", ShowFOV=true, Prediction=50,
}

local aimbotLoop   = nil
local lockedTarget = nil
local fovGui, fovFrame, fovStroke = nil, nil, nil

local function getMouseCenter()
	local m = UIS:GetMouseLocation(); return Vector2.new(m.X, m.Y)
end

local function updateFOVCircle()
	local s = Features.aimbotSettings
	if not s.ShowFOV or not Features.aimbotEnabled then
		if fovGui then fovGui.Enabled=false end; return
	end
	if not fovGui then
		fovGui = Instance.new("ScreenGui"); fovGui.Name="RFunFOV"; fovGui.ResetOnSpawn=false
		fovGui.IgnoreGuiInset=true; fovGui.Parent=PGui
		fovFrame = Instance.new("Frame"); fovFrame.BackgroundTransparency=1; fovFrame.BorderSizePixel=0
		fovFrame.AnchorPoint=Vector2.new(0.5,0.5); fovFrame.Parent=fovGui
		local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=fovFrame
		fovStroke=Instance.new("UIStroke"); fovStroke.Transparency=0.25; fovStroke.Thickness=1.5; fovStroke.Parent=fovFrame
	end
	fovGui.Enabled=true
	local fov=s.FOV; fovFrame.Size=UDim2.fromOffset(fov*2,fov*2)
	local m=getMouseCenter(); fovFrame.Position=UDim2.fromOffset(m.X,m.Y)
	if fovStroke then
		fovStroke.Color = lockedTarget and Color3.fromRGB(255,40,40) or Color3.fromRGB(255,255,255)
	end
end

local function isValidTarget(part)
	if not part or not part.Parent then return false end
	local h=part.Parent:FindFirstChildOfClass("Humanoid"); return h and h.Health>0
end

local function screenDist(part, center)
	local cam=workspace.CurrentCamera; if not cam then return nil,nil end
	local aimPos=part.Position
	local vel=part.AssemblyLinearVelocity
	if vel.Magnitude>0.5 then
		local d3=(cam.CFrame.Position-aimPos).Magnitude
		local pt=(d3/500)*(Features.aimbotSettings.Prediction/100)
		aimPos=aimPos+vel*pt
	end
	local sp,onScreen=cam:WorldToViewportPoint(aimPos)
	if not onScreen or sp.Z<=0 then return nil,nil end
	return (Vector2.new(sp.X,sp.Y)-center).Magnitude, aimPos
end

local function getClosestTarget()
	local cam=workspace.CurrentCamera; if not cam then return nil,nil end
	local center=getMouseCenter(); local fov=Features.aimbotSettings.FOV; local s=Features.aimbotSettings

	if lockedTarget and isValidTarget(lockedTarget) then
		local d,ap=screenDist(lockedTarget,center)
		if d and d<fov then return lockedTarget,ap end
		lockedTarget=nil
	end

	local best,bestD,bestP=nil,math.huge,nil
	for _,p in ipairs(Players:GetPlayers()) do
		if p==LP then continue end
		if s.TeamCheck and LP.Team and p.Team and p.Team==LP.Team then continue end
		local char=p.Character; if not char then continue end
		local part=char:FindFirstChild(s.TargetPart) or char:FindFirstChild("HumanoidRootPart"); if not part then continue end
		local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then continue end
		local d,ap=screenDist(part,center)
		if d and d<fov and d<bestD then bestD=d; best=part; bestP=ap end
	end
	lockedTarget=best; return best,bestP
end

local function startAimbotLoop()
	if aimbotLoop then return end
	aimbotLoop=RunService.RenderStepped:Connect(function()
		updateFOVCircle()
		if not Features.aimbotEnabled then lockedTarget=nil; return end
		local target,targetPos=getClosestTarget()
		if not target or not targetPos then return end
		local cam=workspace.CurrentCamera; if not cam then return end
		local smooth=math.clamp(Features.aimbotSettings.Smoothness/100,0.01,0.99)
		local cur=cam.CFrame
		local tgt=CFrame.new(cur.Position,targetPos)
		cam.CFrame=cur:Lerp(tgt, 1-smooth)
	end)
end

local function stopAimbotLoop()
	if aimbotLoop then aimbotLoop:Disconnect(); aimbotLoop=nil end
	lockedTarget=nil; if fovGui then fovGui.Enabled=false end
end

function Features.setAimbot(on)
	Features.aimbotEnabled=on
	if on then startAimbotLoop() else stopAimbotLoop() end
end

-- ═══════════════════════════════════════════════════════
--  KEYBINDS
-- ═══════════════════════════════════════════════════════
local Keybinds = {
	aimbot       = { key=Enum.KeyCode.Q, holdMode=false, label="Aimbot"    },
	esp          = { key=Enum.KeyCode.Z, holdMode=false, label="ESP"       },
	infiniteJump = { key=Enum.KeyCode.X, holdMode=false, label="Inf Jump"  },
}
local function keyName(kc)
	if typeof(kc) == "EnumItem" then return kc.Name end
	return tostring(kc):gsub("Enum%.KeyCode%.",""):gsub("Enum%.UserInputType%.","")
end

-- ═══════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════
local State = {
	autoLoadConfig=false, infiniteJump=false, esp=false, aimbot=false,
	espSettings     = { Box=true, BoxFilled=false, Name=true, Distance=true, TeamCheck=true },
	aimbotSettings  = { FOV=120, Smoothness=35, TeamCheck=true, TargetPart="Head", ShowFOV=true, Prediction=50 },
}

-- ═══════════════════════════════════════════════════════
--  UI  ── RED × BLACK THEME (HP OPTIMIZED)
-- ═══════════════════════════════════════════════════════
for _,c in ipairs(PGui:GetChildren()) do
	if c.Name=="RivalsFun3D" and not script:IsDescendantOf(c) then c:Destroy() end
end

local C = {
	bg          = Color3.fromRGB(6,   0,  0),
	panel       = Color3.fromRGB(14,  2,  2),
	row         = Color3.fromRGB(22,  4,  4),
	sidebarBg   = Color3.fromRGB(10,  0,  0),
	topBar      = Color3.fromRGB(14,  0,  0),
	accent      = Color3.fromRGB(210, 30, 30),
	accentBrt   = Color3.fromRGB(255, 55, 55),
	activeDim   = Color3.fromRGB(65,  8,  8),
	sep         = Color3.fromRGB(150, 18, 18),
	text        = Color3.fromRGB(255,255,255),
	textDim     = Color3.fromRGB(185,115,115),
	sliderTrack = Color3.fromRGB(40,   5,  5),
	toggleOff   = Color3.fromRGB(50,   8,  8),
	danger      = Color3.fromRGB(255, 80, 80),
}

local FONT     = Enum.Font.Gotham
local FONT_MED = Enum.Font.GothamMedium
local FONT_BOL = Enum.Font.GothamBold
local CR       = UDim.new(0,5)
local CR_SM    = UDim.new(0,4)

local function mkCorner(p,r)  local c=Instance.new("UICorner"); c.CornerRadius=r or CR; c.Parent=p; return c end
local function mkStroke(p,col,tr,th) local s=Instance.new("UIStroke"); s.Color=col or C.sep; s.Transparency=tr or 0.5; s.Thickness=th or 1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s end
local function mkPad(p,t,r,b,l) local x=Instance.new("UIPadding"); x.PaddingTop=UDim.new(0,t or 12); x.PaddingRight=UDim.new(0,r or 12); x.PaddingBottom=UDim.new(0,b or 12); x.PaddingLeft=UDim.new(0,l or 12); x.Parent=p; return x end

local function mkLabel(props)
	local l=Instance.new("TextLabel"); l.Name=props.Name or "Lbl"; l.BackgroundTransparency=1
	l.Font=props.Font or FONT; l.TextSize=props.TextSize or 13; l.TextColor3=props.TextColor or C.text
	l.Text=props.Text or ""; l.TextXAlignment=props.TextXAlignment or Enum.TextXAlignment.Left
	l.TextYAlignment=Enum.TextYAlignment.Center
	if props.Size        then l.Size=props.Size end
	if props.Position    then l.Position=props.Position end
	if props.LayoutOrder then l.LayoutOrder=props.LayoutOrder end
	l.Parent=props.Parent; return l
end

local function mkSep(parent,lo)
	local l=Instance.new("Frame"); l.Name="Sep"; l.Size=UDim2.new(1,0,0,1)
	l.BackgroundColor3=C.sep; l.BackgroundTransparency=0.4; l.BorderSizePixel=0
	l.LayoutOrder=lo or 0; l.Parent=parent; return l
end

-- ── GUI ROOT ───────────────────────────────────────────
local gui=Instance.new("ScreenGui"); gui.Name="RivalsFun3D"; gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.IgnoreGuiInset=true; gui.Parent=PGui

local function showToast(msg)
	local t=gui:FindFirstChild("Toast"); if t then t:Destroy() end
	local toast=Instance.new("Frame"); toast.Name="Toast"; toast.BackgroundColor3=Color3.fromRGB(12,0,0)
	toast.BorderSizePixel=0; toast.Size=UDim2.fromOffset(320,34)  -- LEBIH KECIL
	toast.Position=UDim2.new(0.5,0,1,-55); toast.AnchorPoint=Vector2.new(0.5,1); toast.ZIndex=200; toast.Parent=gui
	mkCorner(toast,CR); mkStroke(toast,C.accent,0,1)
	mkLabel({Parent=toast, Text=msg, TextSize=11, TextXAlignment=Enum.TextXAlignment.Center, Size=UDim2.fromScale(1,1)})
	task.delay(2.5,function() if toast.Parent then toast:Destroy() end end)
end

-- ROOT DIKECILKAN UNTUK HP
local root=Instance.new("Frame"); root.Name="Root"; root.BackgroundColor3=C.bg
root.BorderSizePixel=0; root.Size=UDim2.new(0,560,0,400)  -- DARI 860x520 -> 560x400
root.Position=UDim2.new(0.5,0,0.5,0); root.AnchorPoint=Vector2.new(0.5,0.5)
root.ClipsDescendants=true; root.ZIndex=1; root.Visible=false; root.Parent=gui
mkCorner(root,CR); mkStroke(root,C.accent,0,1)

-- ── PARTICLE LAYER ────────────────────────────────────
local ptLayer=Instance.new("Frame"); ptLayer.BackgroundTransparency=1
ptLayer.Size=UDim2.fromScale(1,1); ptLayer.ZIndex=2; ptLayer.Parent=root

local ptPool={}
local function spawnParticle()
	if #ptPool>=28 then return end
	local p=Instance.new("Frame")
	local sz=math.random(2,5)
	p.Size=UDim2.fromOffset(sz,sz)
	local xs=math.random()
	p.Position=UDim2.fromScale(xs,1.02)
	p.BackgroundColor3=math.random()<0.6 and C.accent or C.accentBrt
	p.BackgroundTransparency=math.random()*0.4+0.3
	p.BorderSizePixel=0; p.ZIndex=3
	mkCorner(p,UDim.new(1,0))
	p.Parent=ptLayer
	table.insert(ptPool,p)
	local life=math.random(35,75)/10
	local xDrift=(math.random()-0.5)*0.12
	TweenService:Create(p,TweenInfo.new(life,Enum.EasingStyle.Linear),{
		Position=UDim2.fromScale(xs+xDrift,-0.04),
		BackgroundTransparency=1,
	}):Play()
	task.delay(life,function()
		for i,v in ipairs(ptPool) do if v==p then table.remove(ptPool,i); break end end
		if p.Parent then p:Destroy() end
	end)
end

RunService.RenderStepped:Connect(function()
	if root.Visible and math.random()<0.045 then spawnParticle() end
end)

-- ── TOP BAR ──────────────────────────────────────────
local topBar=Instance.new("Frame"); topBar.Name="TopBar"; topBar.BackgroundColor3=C.topBar
topBar.BorderSizePixel=0; topBar.Size=UDim2.new(1,0,0,34)  -- TINGGI DARI 44 -> 34
topBar.ZIndex=10; topBar.Parent=root
local tbBorder=Instance.new("Frame"); tbBorder.Size=UDim2.new(1,0,0,1)
tbBorder.Position=UDim2.new(0,0,1,-1); tbBorder.BackgroundColor3=C.accent
tbBorder.BackgroundTransparency=0; tbBorder.BorderSizePixel=0; tbBorder.ZIndex=11; tbBorder.Parent=topBar

local tbLayout=Instance.new("UIListLayout"); tbLayout.FillDirection=Enum.FillDirection.Horizontal
tbLayout.VerticalAlignment=Enum.VerticalAlignment.Center; tbLayout.Padding=UDim.new(0,6)  -- PADDING DIKECILKAN
tbLayout.SortOrder=Enum.SortOrder.LayoutOrder; tbLayout.Parent=topBar
mkPad(topBar,0,10,0,10)  -- PADDING DIKECILKAN

-- Drag
local dragging,dragStart,dragOrigin=false,nil,nil
topBar.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		dragging=true; dragStart=i.Position; dragOrigin=root.Position
		i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
	end
end)
UIS.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
		local d=i.Position-dragStart
		root.Position=UDim2.new(dragOrigin.X.Scale,dragOrigin.X.Offset+d.X,dragOrigin.Y.Scale,dragOrigin.Y.Offset+d.Y)
	end
end)

-- Window dots
local wCtrl=Instance.new("Frame"); wCtrl.BackgroundTransparency=1
wCtrl.Size=UDim2.fromOffset(42,12)  -- DARI 56x14 -> 42x12
wCtrl.LayoutOrder=1; wCtrl.Parent=topBar
local wl=Instance.new("UIListLayout"); wl.FillDirection=Enum.FillDirection.Horizontal
wl.Padding=UDim.new(0,4); wl.VerticalAlignment=Enum.VerticalAlignment.Center; wl.Parent=wCtrl

local winClose,winMin,winMax
for i,col in ipairs({Color3.fromRGB(255,75,55),Color3.fromRGB(255,185,55),Color3.fromRGB(55,200,75)}) do
	local d=Instance.new("TextButton"); d.Size=UDim2.fromOffset(10,10)  -- DARI 12x12 -> 10x10
	d.BackgroundColor3=col
	d.Text=""; d.AutoButtonColor=false; mkCorner(d,UDim.new(1,0)); d.Parent=wCtrl
	if i==1 then winClose=d elseif i==2 then winMin=d else winMax=d end
end

mkLabel({Parent=topBar, Name="Title", Text="RIVALS FUN 3D", Font=FONT_BOL, TextSize=11, TextColor=C.accentBrt, LayoutOrder=3, Size=UDim2.fromOffset(120,22)})  -- DIKECILKAN
mkLabel({Parent=topBar, Name="Hint",  Text="F9", Font=FONT, TextSize=9, TextColor=C.textDim, LayoutOrder=4, Size=UDim2.fromOffset(80,22)})  -- DIKECILKAN

-- Brand pinned to top-right
local brandLbl = Instance.new("TextLabel")
brandLbl.Name                = "Brand"
brandLbl.BackgroundTransparency = 1
brandLbl.Text                = "@strictlytech"
brandLbl.Font                = FONT_MED
brandLbl.TextSize            = 9  -- DARI 12 -> 9
brandLbl.TextColor3          = Color3.fromRGB(255, 255, 255)
brandLbl.TextXAlignment      = Enum.TextXAlignment.Right
brandLbl.Size                = UDim2.fromOffset(100, 34)  -- DARI 130x44 -> 100x34
brandLbl.Position            = UDim2.new(1, -10, 0, 0)  -- DARI -14 -> -10
brandLbl.AnchorPoint         = Vector2.new(1, 0)
brandLbl.ZIndex              = 15
brandLbl.Parent              = topBar

-- ── BODY ─────────────────────────────────────────────
local body=Instance.new("Frame"); body.BackgroundTransparency=1; body.Name="Body"
body.Size=UDim2.new(1,0,1,-34)  -- DARI -44 -> -34
body.Position=UDim2.fromOffset(0,34)  -- DARI 44 -> 34
body.ZIndex=4; body.Parent=root

local SW=140  -- SIDEBAR LEBIH KECIL DARI 195 -> 140

local sidebar=Instance.new("Frame"); sidebar.Name="Sidebar"; sidebar.BackgroundColor3=C.sidebarBg
sidebar.BorderSizePixel=0; sidebar.Size=UDim2.new(0,SW,1,0); sidebar.ZIndex=5; sidebar.Parent=body
local sbLine=Instance.new("Frame"); sbLine.Size=UDim2.new(0,1,1,0); sbLine.Position=UDim2.new(1,-1,0,0)
sbLine.BackgroundColor3=C.accent; sbLine.BackgroundTransparency=0.2; sbLine.BorderSizePixel=0; sbLine.Parent=sidebar

local sbScroll=Instance.new("ScrollingFrame"); sbScroll.BackgroundTransparency=1; sbScroll.BorderSizePixel=0
sbScroll.Size=UDim2.fromScale(1,1); sbScroll.CanvasSize=UDim2.new(0,0,0,0)
sbScroll.ScrollBarThickness=2; sbScroll.ScrollBarImageColor3=C.accent
sbScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; sbScroll.Parent=sidebar
mkPad(sbScroll,6,6,6,6)  -- PADDING DIKECILKAN
local sbLL=Instance.new("UIListLayout"); sbLL.Padding=UDim.new(0,2); sbLL.SortOrder=Enum.SortOrder.LayoutOrder; sbLL.Parent=sbScroll

local brandBlock = Instance.new("Frame")
brandBlock.Name = "BrandBlock"
brandBlock.BackgroundTransparency = 1
brandBlock.Size = UDim2.new(1, 0, 0, 44)  -- DARI 58 -> 44
brandBlock.LayoutOrder = 0
brandBlock.Parent = sbScroll

local brandLL = Instance.new("UIListLayout")
brandLL.Padding = UDim.new(0, 2)
brandLL.SortOrder = Enum.SortOrder.LayoutOrder
brandLL.Parent = brandBlock

local versionLbl = Instance.new("TextLabel")
versionLbl.Name = "Version"
versionLbl.BackgroundTransparency = 1
versionLbl.Text = "ISLAND V1"
versionLbl.Font = FONT_BOL
versionLbl.TextSize = 14  -- DARI 20 -> 14
versionLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
versionLbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
versionLbl.TextStrokeTransparency = 0.35
versionLbl.TextXAlignment = Enum.TextXAlignment.Left
versionLbl.Size = UDim2.new(1, 0, 0, 20)  -- DARI 26 -> 20
versionLbl.LayoutOrder = 1
versionLbl.Parent = brandBlock

mkLabel({
	Parent=brandBlock, Name="Credit",
	Text='@strictlytech',
	Font=FONT, TextSize=8,  -- DARI 10 -> 8
	TextColor=Color3.fromRGB(255, 255, 255),
	LayoutOrder=2,
	Size=UDim2.new(1, 0, 0, 20),  -- DARI 28 -> 20
})

local navBtns={} local activeNav=nil

local function setNavActive(btn)
	if activeNav then
		activeNav.BackgroundColor3=Color3.fromRGB(0,0,0); activeNav.BackgroundTransparency=1
		activeNav.TextColor3=C.textDim
		local s=activeNav:FindFirstChildOfClass("UIStroke"); if s then s.Color=C.sep; s.Transparency=0.6 end
	end
	activeNav=btn; btn.BackgroundColor3=C.activeDim; btn.BackgroundTransparency=0; btn.TextColor3=C.accentBrt
	local s=btn:FindFirstChildOfClass("UIStroke"); if s then s.Color=C.accentBrt; s.Transparency=0 end
end

local function mkNav(text,lo,onClick)
	local btn=Instance.new("TextButton"); btn.Name=text:gsub(" ",""); btn.LayoutOrder=lo
	btn.Size=UDim2.new(1,0,0,24)  -- DARI 30 -> 24
	btn.BackgroundColor3=Color3.fromRGB(0,0,0); btn.BackgroundTransparency=1
	btn.Font=FONT_MED; btn.TextSize=10  -- DARI 12 -> 10
	btn.Text="  "..text; btn.TextColor3=C.textDim
	btn.TextXAlignment=Enum.TextXAlignment.Left; btn.AutoButtonColor=false
	mkCorner(btn,CR_SM); mkStroke(btn,C.sep,0.6,1); btn.Parent=sbScroll
	navBtns[text]=btn
	btn.MouseButton1Click:Connect(function() setNavActive(btn); if onClick then onClick() end end)
	return btn
end

local function mkNavHdr(text,lo)
	mkLabel({Parent=sbScroll,Text=text,Font=FONT_BOL,TextSize=8,TextColor=C.accent,LayoutOrder=lo,Size=UDim2.new(1,0,0,16)})  -- DIKECILKAN
end

mkNavHdr("COMBAT",    1); mkNav("Aimbot",        2)
mkSep(sbScroll,3)
mkNavHdr("MOVEMENT",  4); mkNav("Infinite Jump",  5)
mkSep(sbScroll,6)
mkNavHdr("VISUALS",   7); mkNav("ESP",            8)
mkSep(sbScroll,9)
mkNavHdr("SETTINGS",  10); mkNav("Config",      11); mkNav("Keybinds",      12)

-- Main panel
local main=Instance.new("Frame"); main.Name="Main"; main.BackgroundColor3=C.panel
main.BorderSizePixel=0; main.Size=UDim2.new(1,-SW,1,0); main.Position=UDim2.fromOffset(SW,0); main.ZIndex=4; main.Parent=body

local mainScroll=Instance.new("ScrollingFrame"); mainScroll.BackgroundTransparency=1; mainScroll.BorderSizePixel=0
mainScroll.Size=UDim2.fromScale(1,1); mainScroll.CanvasSize=UDim2.new(0,0,0,0)
mainScroll.ScrollBarThickness=2; mainScroll.ScrollBarImageColor3=C.accent
mainScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; mainScroll.Parent=main
mkPad(mainScroll,10,10,10,10)  -- PADDING DIKECILKAN
local mainLL=Instance.new("UIListLayout"); mainLL.Padding=UDim.new(0,8); mainLL.SortOrder=Enum.SortOrder.LayoutOrder; mainLL.Parent=mainScroll

local function secHead(text,order)
	return mkLabel({Parent=mainScroll,Text=text:upper(),Font=FONT_BOL,TextSize=9,TextColor=C.accent,LayoutOrder=order,Size=UDim2.new(1,0,0,14)})  -- DIKECILKAN
end

local function mkRow(title,lo,h)
	local f=Instance.new("Frame"); f.Name=title; f.BackgroundColor3=C.row; f.BorderSizePixel=0
	f.Size=UDim2.new(1,0,0,h or 42)  -- DARI 52 -> 42
	f.LayoutOrder=lo; f.Parent=mainScroll
	mkCorner(f,CR); mkStroke(f,C.sep,0.45,1); mkPad(f,8,8,8,8)  -- PADDING DIKECILKAN
	return f
end

local function createToggle(props)
	local row=mkRow(props.title,props.layoutOrder,42)  -- TINGGI 42
	local info=Instance.new("Frame"); info.BackgroundTransparency=1; info.Size=UDim2.new(1,-44,1,0); info.Parent=row
	mkLabel({Parent=info,Text=props.title,Font=FONT_MED,TextSize=11,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,16)})  -- DIKECILKAN
	mkLabel({Parent=info,Text=props.desc or "",TextSize=9,TextColor=C.textDim,Position=UDim2.fromOffset(0,16),Size=UDim2.new(1,0,0,14)})  -- DIKECILKAN
	local track=Instance.new("TextButton"); track.AnchorPoint=Vector2.new(1,0.5); track.Position=UDim2.new(1,0,0.5,0)
	track.Size=UDim2.fromOffset(36,18)  -- DARI 44x22 -> 36x18
	track.Text=""; track.AutoButtonColor=false; mkCorner(track,UDim.new(1,0)); track.Parent=row
	local knob=Instance.new("Frame"); knob.Size=UDim2.fromOffset(14,14)  -- DARI 17x17 -> 14x14
	knob.BorderSizePixel=0; mkCorner(knob,UDim.new(1,0)); knob.Parent=track
	local on=props.default==true
	local function paint()
		track.BackgroundColor3=on and C.accent or C.toggleOff
		knob.Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,2,0.5,-7)  -- DISESUAIKAN
		knob.BackgroundColor3=C.text
	end
	paint()
	track.MouseButton1Click:Connect(function()
		on=not on; paint()
		TweenService:Create(knob,TweenInfo.new(0.12,Enum.EasingStyle.Quad),{Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
		if props.onChange then props.onChange(on) end
	end)
	return row
end

local function createSlider(props)
	local row=mkRow(props.title,props.layoutOrder,52)  -- TINGGI 52
	mkLabel({Parent=row,Text=props.title,Font=FONT_MED,TextSize=11,Position=UDim2.fromOffset(0,0),Size=UDim2.new(0.65,0,0,16)})  -- DIKECILKAN
	local vl=mkLabel({Parent=row,Name="Val",Text=tostring(props.default),Font=FONT_MED,TextSize=10,TextColor=C.accentBrt,TextXAlignment=Enum.TextXAlignment.Right,Position=UDim2.new(1,-32,0,0),Size=UDim2.fromOffset(32,16)})  -- DIKECILKAN
	mkLabel({Parent=row,Text=props.desc or "",TextSize=9,TextColor=C.textDim,Position=UDim2.fromOffset(0,17),Size=UDim2.new(1,0,0,12)})  -- DIKECILKAN
	local trk=Instance.new("Frame"); trk.BackgroundColor3=C.sliderTrack; trk.BorderSizePixel=0
	trk.Position=UDim2.fromOffset(0,34); trk.Size=UDim2.new(1,0,0,4); mkCorner(trk,UDim.new(1,0)); trk.Parent=row
	local fill=Instance.new("Frame"); fill.BackgroundColor3=C.accent; fill.BorderSizePixel=0
	fill.Size=UDim2.fromScale(0.5,1); mkCorner(fill,UDim.new(1,0)); fill.Parent=trk
	local hit=Instance.new("TextButton"); hit.BackgroundTransparency=1; hit.Text=""
	hit.Size=UDim2.new(1,0,0,16); hit.Position=UDim2.fromOffset(0,28); hit.ZIndex=2; hit.Parent=row
	local drag=false
	local function setV(a)
		a=math.clamp(a,0,1); local v=math.floor(props.min+(props.max-props.min)*a+0.5)
		fill.Size=UDim2.fromScale(a,1); vl.Text=tostring(v); if props.onChange then props.onChange(v) end
	end
	setV((props.default-props.min)/(props.max-props.min))
	local function fromI(i) setV((i.Position.X-trk.AbsolutePosition.X)/trk.AbsoluteSize.X) end
	hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true; fromI(i) end end)
	UIS.InputChanged:Connect(function(i) if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then fromI(i) end end)
	UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end)
	return row
end

local function createDropdown(props)
	local row=mkRow(props.title,props.layoutOrder,52)  -- TINGGI 52
	mkLabel({Parent=row,Text=props.title,Font=FONT_MED,TextSize=11,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,-110,0,16)})  -- DIKECILKAN
	mkLabel({Parent=row,Text=props.desc or "",TextSize=9,TextColor=C.textDim,Position=UDim2.fromOffset(0,17),Size=UDim2.new(1,-110,0,12)})  -- DIKECILKAN
	local btn=Instance.new("TextButton"); btn.AnchorPoint=Vector2.new(1,0.5); btn.Position=UDim2.new(1,0,0.5,4)
	btn.Size=UDim2.fromOffset(100,22)  -- DARI 118x26 -> 100x22
	btn.BackgroundColor3=C.activeDim; btn.Font=FONT; btn.TextSize=10  -- DARI 12 -> 10
	btn.Text="  "..tostring(props.default).."  ▾"; btn.TextColor3=C.text; btn.TextXAlignment=Enum.TextXAlignment.Left
	btn.AutoButtonColor=false; mkCorner(btn,CR_SM); mkStroke(btn,C.accent,0,1); btn.Parent=row
	local open=false; local mr
	local function closeM() open=false; if mr then mr:Destroy(); mr=nil end end
	local function openM()
		closeM(); open=true
		local opts=props.options or {}; local iH,pV=22,3  -- DARI 25,4 -> 22,3
		local cnt=#opts
		local cH=cnt*iH+math.max(0,cnt-1)*2+pV*2; local mH=math.min(cH,150)  -- DARI 175 -> 150
		local ap=btn.AbsolutePosition; local as=btn.AbsoluteSize; local ga=gui.AbsolutePosition
		mr=Instance.new("Frame"); mr.BackgroundTransparency=1; mr.Size=UDim2.fromOffset(as.X,mH+4)
		mr.Position=UDim2.fromOffset(ap.X-ga.X,ap.Y-ga.Y+as.Y+3); mr.ZIndex=220; mr.Parent=gui
		local menu=Instance.new("ScrollingFrame"); menu.BackgroundColor3=Color3.fromRGB(16,2,2); menu.BorderSizePixel=0
		menu.Size=UDim2.new(1,0,1,0); menu.CanvasSize=UDim2.fromOffset(0,cH); menu.ScrollBarThickness=2
		menu.ScrollBarImageColor3=C.accent; menu.ZIndex=221; menu.ClipsDescendants=true; menu.Parent=mr
		mkCorner(menu,CR_SM); mkStroke(menu,C.accent,0,1); mkPad(menu,pV,3,pV,3)  -- PADDING DIKECILKAN
		local ml=Instance.new("UIListLayout"); ml.Padding=UDim.new(0,2); ml.SortOrder=Enum.SortOrder.LayoutOrder; ml.Parent=menu
		for i,o in ipairs(opts) do
			local ob=Instance.new("TextButton"); ob.LayoutOrder=i; ob.Size=UDim2.new(1,0,0,iH)
			ob.BackgroundTransparency=1; ob.BackgroundColor3=C.activeDim; ob.Font=FONT; ob.TextSize=10  -- DARI 12 -> 10
			ob.Text="  "..tostring(o); ob.TextColor3=C.text; ob.TextXAlignment=Enum.TextXAlignment.Left
			ob.AutoButtonColor=false; ob.ZIndex=222; ob.Parent=menu
			ob.MouseButton1Click:Connect(function() btn.Text="  "..tostring(o).."  ▾"; closeM(); if props.onSelect then props.onSelect(o) end end)
		end
	end
	btn.MouseButton1Click:Connect(function() if open then closeM() else openM() end end)
	return {Close=closeM}
end

local dropdowns={}
local function clearContent()
	for _,d in ipairs(dropdowns) do if d and d.Close then d.Close() end end; dropdowns={}
	for _,ch in ipairs(mainScroll:GetChildren()) do
		if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
	end
	mainScroll.CanvasPosition=Vector2.zero
end

-- ═══════════════════════════════════════════════════════
--  CONFIG SYSTEM & REUSABLE ROWS
-- ═══════════════════════════════════════════════════════
local listeningFor=nil
local kbBtns={}

local function createKeybindRow(props)
	local id = props.id
	local bind = Keybinds[id]
	local row = mkRow(bind.label, props.layoutOrder, 44)  -- TINGGI 44
	row.Name = id
	local info=Instance.new("Frame"); info.BackgroundTransparency=1; info.Size=UDim2.new(1,-150,1,0); info.Parent=row
	mkLabel({Parent=info,Text=props.title or bind.label,Font=FONT_MED,TextSize=11,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,16)})
	mkLabel({Parent=info,Name="CK",Text="Key: "..keyName(bind.key),TextSize=9,TextColor=C.textDim,Position=UDim2.fromOffset(0,16),Size=UDim2.new(1,0,0,14)})

	local hb=Instance.new("TextButton"); hb.AnchorPoint=Vector2.new(1,0.5); hb.Position=UDim2.new(1,0,0.5,0)
	hb.Size=UDim2.fromOffset(58,20)  -- DARI 70x24 -> 58x20
	hb.Font=FONT; hb.TextSize=9  -- DARI 11 -> 9
	hb.Text=bind.holdMode and "HOLD" or "TOGGLE"; hb.BackgroundColor3=bind.holdMode and C.accent or Color3.fromRGB(38,8,8)
	hb.TextColor3=C.text; hb.AutoButtonColor=false; mkCorner(hb,CR_SM); hb.Parent=row
	hb.MouseButton1Click:Connect(function()
		bind.holdMode=not bind.holdMode
		hb.Text=bind.holdMode and "HOLD" or "TOGGLE"; hb.BackgroundColor3=bind.holdMode and C.accent or Color3.fromRGB(38,8,8)
	end)

	local kb=Instance.new("TextButton"); kb.AnchorPoint=Vector2.new(1,0.5); kb.Position=UDim2.new(1,-65,0.5,0)
	kb.Size=UDim2.fromOffset(58,20)  -- DARI 70x24 -> 58x20
	kb.Font=FONT_MED; kb.TextSize=10  -- DARI 12 -> 10
	kb.Text=keyName(bind.key); kb.BackgroundColor3=Color3.fromRGB(28,4,4); kb.TextColor3=C.text; kb.AutoButtonColor=false
	mkCorner(kb,CR_SM); mkStroke(kb,C.accent,0,1); kb.Parent=row; kbBtns[id]=kb
	kb.MouseButton1Click:Connect(function()
		if listeningFor==id then
			listeningFor=nil; kb.Text=keyName(bind.key); kb.BackgroundColor3=Color3.fromRGB(28,4,4)
		else
			if listeningFor and kbBtns[listeningFor] then
				kbBtns[listeningFor].Text=keyName(Keybinds[listeningFor].key)
				kbBtns[listeningFor].BackgroundColor3=Color3.fromRGB(28,4,4)
			end
			listeningFor=id; kb.Text="[press]"; kb.BackgroundColor3=C.activeDim
		end
	end)
	return row
end

local function createActionRow(props)
	local row=mkRow(props.title,props.layoutOrder,44)  -- TINGGI 44
	local info=Instance.new("Frame"); info.BackgroundTransparency=1; info.Size=UDim2.new(1,-76,1,0); info.Parent=row
	mkLabel({Parent=info,Text=props.title,Font=FONT_MED,TextSize=11,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,16)})
	mkLabel({Parent=info,Text=props.desc or "",TextSize=9,TextColor=C.textDim,Position=UDim2.fromOffset(0,16),Size=UDim2.new(1,0,0,14)})
	local btn=Instance.new("TextButton"); btn.AnchorPoint=Vector2.new(1,0.5); btn.Position=UDim2.new(1,0,0.5,0)
	btn.Size=UDim2.fromOffset(66,22)  -- DARI 80x26 -> 66x22
	btn.BackgroundColor3=C.activeDim; btn.Font=FONT_MED; btn.TextSize=10  -- DARI 12 -> 10
	btn.Text=props.buttonText; btn.TextColor3=C.text; btn.AutoButtonColor=false
	mkCorner(btn,CR_SM); mkStroke(btn,C.accent,0,1); btn.Parent=row
	btn.MouseButton1Click:Connect(function() if props.onClick then props.onClick() end end)
	return row
end

local configName = "RivalsFun3D_Config.json"

local function saveConfig()
	local data = { State = State, Keybinds = {} }
	for k,v in pairs(Keybinds) do
		data.Keybinds[k] = { keyName = v.key.Name, keyType = tostring(v.key.EnumType), holdMode = v.holdMode }
	end
	if writefile then
		local s,e = pcall(function() writefile(configName, HttpService:JSONEncode(data)) end)
		if s then showToast("Config saved!") else showToast("Error saving config!") end
	else
		showToast("Executor does not support writefile!")
	end
end

local function loadConfig(silent)
	if readfile and isfile and isfile(configName) then
		local success, data = pcall(function() return HttpService:JSONDecode(readfile(configName)) end)
		if success and data then
			if data.State then
				for k,v in pairs(data.State) do
					if type(v)=="table" and type(State[k])=="table" then
						for k2,v2 in pairs(v) do State[k][k2] = v2 end
					else
						State[k] = v
					end
				end
				Features.setInfiniteJump(State.infiniteJump)
				Features.setESP(State.esp)
				for k,v in pairs(State.espSettings) do Features.setESPSetting(k,v) end
				Features.setAimbot(State.aimbot)
				for k,v in pairs(State.aimbotSettings) do Features.aimbotSettings[k] = v end
			end
			if data.Keybinds then
				for k,v in pairs(data.Keybinds) do
					if Keybinds[k] then
						Keybinds[k].holdMode = v.holdMode
						if v.keyType == tostring(Enum.KeyCode) and Enum.KeyCode[v.keyName] then
							Keybinds[k].key = Enum.KeyCode[v.keyName]
						elseif v.keyType == tostring(Enum.UserInputType) and Enum.UserInputType[v.keyName] then
							Keybinds[k].key = Enum.UserInputType[v.keyName]
						end
					end
				end
			end
			if not silent then showToast("Config loaded!") end
		else
			if not silent then showToast("Failed to parse config file!") end
		end
	else
		if not silent then showToast("No config file found or executor unsupported!") end
	end
end

local function renderConfig()
	clearContent(); local lo=1
	secHead("Config",lo); lo+=1
	createToggle({title="Auto Load Config",desc="Load automatically when script starts",layoutOrder=lo,default=State.autoLoadConfig,onChange=function(on) State.autoLoadConfig=on end}); lo+=1
	createActionRow({title="Save Configuration", desc="Saves your settings to " .. configName, buttonText="SAVE", layoutOrder=lo, onClick=saveConfig}); lo+=1
	createActionRow({title="Load Configuration", desc="Loads your settings from " .. configName, buttonText="LOAD", layoutOrder=lo, onClick=function() loadConfig(false) end}); lo+=1
end

-- ═══════════════════════════════════════════════════════
--  PAGE RENDERERS
-- ═══════════════════════════════════════════════════════
local function renderKeybinds()
	clearContent(); local lo=1
	secHead("Keybinds",lo); lo+=1
	mkLabel({Parent=mainScroll,Text="Click key to reassign",TextSize=9,TextColor=C.textDim,LayoutOrder=lo,Size=UDim2.new(1,0,0,14)}); lo+=1
	mkSep(mainScroll,lo); lo+=1
	createKeybindRow({id="aimbot", layoutOrder=lo}); lo+=1
	createKeybindRow({id="esp", layoutOrder=lo}); lo+=1
	createKeybindRow({id="infiniteJump", layoutOrder=lo}); lo+=1
end

local function renderInfiniteJump()
	clearContent(); local lo=1
	secHead("Movement",lo); lo+=1
	createToggle({title="Infinite Jump",desc="Jump again while in the air",layoutOrder=lo,default=State.infiniteJump,
		onChange=function(on) State.infiniteJump=on; Features.setInfiniteJump(on); showToast("Infinite Jump: "..(on and "ON" or "OFF")) end})
end

local function renderESP()
	clearContent(); local lo=1
	secHead("Visuals",lo); lo+=1
	createToggle({title="ESP",desc="See enemies through walls",layoutOrder=lo,default=State.esp,
		onChange=function(on) State.esp=on; Features.setESP(on); showToast("ESP: "..(on and "ON" or "OFF")) end}); lo+=1
	mkSep(mainScroll,lo); lo+=1; secHead("ESP Settings",lo); lo+=1
	createToggle({title="Box",desc="Outline around enemy model",layoutOrder=lo,default=State.espSettings.Box,onChange=function(on) State.espSettings.Box=on; Features.setESPSetting("Box",on) end}); lo+=1
	createToggle({title="Box Filled",desc="Fill highlight over player model",layoutOrder=lo,default=State.espSettings.BoxFilled,onChange=function(on) State.espSettings.BoxFilled=on; Features.setESPSetting("BoxFilled",on) end}); lo+=1
	createToggle({title="Name",desc="Show name tag above player",layoutOrder=lo,default=State.espSettings.Name,onChange=function(on) State.espSettings.Name=on; Features.setESPSetting("Name",on) end}); lo+=1
	createToggle({title="Distance",desc="Show distance in studs",layoutOrder=lo,default=State.espSettings.Distance,onChange=function(on) State.espSettings.Distance=on; Features.setESPSetting("Distance",on) end}); lo+=1
	createToggle({title="Team Check",desc="Skip teammates",layoutOrder=lo,default=State.espSettings.TeamCheck,onChange=function(on) State.espSettings.TeamCheck=on; Features.setESPSetting("TeamCheck",on) end})
end

local function renderAimbot()
	clearContent(); local lo=1
	secHead("Combat",lo); lo+=1
	createToggle({title="Aimbot",desc="Auto-aim at nearest enemy in FOV",layoutOrder=lo,default=State.aimbot,
		onChange=function(on) State.aimbot=on; Features.setAimbot(on); showToast("Aimbot: "..(on and "ON" or "OFF")) end}); lo+=1
	mkSep(mainScroll,lo); lo+=1; secHead("Aimbot Settings",lo); lo+=1
	createSlider({title="FOV",desc="Detection radius (pixels from mouse cursor)",layoutOrder=lo,min=20,max=400,default=State.aimbotSettings.FOV,
		onChange=function(v) State.aimbotSettings.FOV=v; Features.aimbotSettings.FOV=v end}); lo+=1
	createSlider({title="Smoothness",desc="0 = instant  ·  99 = gradual",layoutOrder=lo,min=0,max=99,default=State.aimbotSettings.Smoothness,
		onChange=function(v) State.aimbotSettings.Smoothness=v; Features.aimbotSettings.Smoothness=v end}); lo+=1
	createSlider({title="Prediction",desc="Lead moving targets  ·  0 = off",layoutOrder=lo,min=0,max=100,default=State.aimbotSettings.Prediction,
		onChange=function(v) State.aimbotSettings.Prediction=v; Features.aimbotSettings.Prediction=v end}); lo+=1
	createToggle({title="Show FOV Circle",desc="Circle follows your mouse cursor  ·  red = locked",layoutOrder=lo,default=State.aimbotSettings.ShowFOV,
		onChange=function(on) State.aimbotSettings.ShowFOV=on; Features.aimbotSettings.ShowFOV=on; updateFOVCircle() end}); lo+=1
	createToggle({title="Team Check",desc="Skip teammates when targeting",layoutOrder=lo,default=State.aimbotSettings.TeamCheck,
		onChange=function(on) State.aimbotSettings.TeamCheck=on; Features.aimbotSettings.TeamCheck=on end}); lo+=1
	local dd=createDropdown({title="Target Part",desc="Which body part to aim at",layoutOrder=lo,default=State.aimbotSettings.TargetPart,
		options={"Head","HumanoidRootPart","UpperTorso"},
		onSelect=function(o) State.aimbotSettings.TargetPart=o; Features.aimbotSettings.TargetPart=o end})
	table.insert(dropdowns,dd)
end

-- ═══════════════════════════════════════════════════════
--  WIRE NAV BUTTONS
-- ═══════════════════════════════════════════════════════
navBtns["Aimbot"].MouseButton1Click:Connect(renderAimbot)
navBtns["Infinite Jump"].MouseButton1Click:Connect(renderInfiniteJump)
navBtns["ESP"].MouseButton1Click:Connect(renderESP)
navBtns["Config"].MouseButton1Click:Connect(renderConfig)
navBtns["Keybinds"].MouseButton1Click:Connect(renderKeybinds)

task.defer(function()
	setNavActive(navBtns["Aimbot"])
	renderAimbot()
end)

-- ═══════════════════════════════════════════════════════
--  PANEL OPEN / CLOSE  (mouse unlock / relock)
-- ═══════════════════════════════════════════════════════
local savedMouseBehavior = Enum.MouseBehavior.LockCenter

local function openPanel()
	savedMouseBehavior = UIS.MouseBehavior
	UIS.MouseBehavior  = Enum.MouseBehavior.Default
	UIS.MouseIconEnabled = true
	root.Visible = true
end

local function closePanel()
	root.Visible = false
	UIS.MouseBehavior    = savedMouseBehavior
	UIS.MouseIconEnabled = false
end

local function togglePanel()
	if root.Visible then closePanel() else openPanel() end
end

-- FLOAT BUTTON LEBIH KECIL
local floatBtn = Instance.new("TextButton")
floatBtn.Name = "RFunFloat"
floatBtn.Size = UDim2.fromOffset(34, 34)  -- DARI 44x44 -> 34x34
floatBtn.Position = UDim2.new(0, 12, 0.5, -17)
floatBtn.BackgroundColor3 = C.panel
floatBtn.Text = "IS"
floatBtn.Font = FONT_BOL
floatBtn.TextSize = 12  -- DARI 16 -> 12
floatBtn.TextColor3 = C.accentBrt
floatBtn.BorderSizePixel = 0
floatBtn.ZIndex = 100
floatBtn.Parent = gui
mkCorner(floatBtn, UDim.new(1,0))
mkStroke(floatBtn, C.accent, 0, 1.5)

local floatDrag, floatStartPos, floatStartInput = false, nil, nil
floatBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		floatDrag = true
		floatStartPos = floatBtn.Position
		floatStartInput = input.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				floatDrag = false
				if (input.Position - floatStartInput).Magnitude < 5 then
					togglePanel()
				end
			end
		end)
	end
end)
UIS.InputChanged:Connect(function(input)
	if floatDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - floatStartInput
		floatBtn.Position = UDim2.new(floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X, floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y)
	end
end)

-- ═══════════════════════════════════════════════════════
--  WINDOW CONTROLS
-- ═══════════════════════════════════════════════════════
if winClose then winClose.MouseButton1Click:Connect(closePanel) end
if winMin   then winMin.MouseButton1Click:Connect(closePanel)   end
if winMax   then winMax.MouseButton1Click:Connect(openPanel)    end

-- ═══════════════════════════════════════════════════════
--  GLOBAL INPUT
-- ═══════════════════════════════════════════════════════
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end

	if listeningFor then
		local isKey = input.UserInputType == Enum.UserInputType.Keyboard
		local isMouse = input.UserInputType.Name:match("MouseButton")
		if isKey or isMouse then
			local id=listeningFor; local bind=Keybinds[id]
			bind.key = isKey and input.KeyCode or input.UserInputType; listeningFor=nil
			local kb=kbBtns[id]
			if kb then kb.Text=keyName(bind.key); kb.BackgroundColor3=Color3.fromRGB(28,4,4) end
			local row=mainScroll:FindFirstChild(id)
			if row then local inf=row:FindFirstChildOfClass("Frame"); if inf then local lbl=inf:FindFirstChild("CK"); if lbl then lbl.Text="Key: "..keyName(bind.key) end end end
			showToast(bind.label.." → "..keyName(bind.key))
			return
		end
	end

	for id,bind in pairs(Keybinds) do
		local match = false
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind.key then match = true end
		if input.UserInputType.Name:match("MouseButton") and input.UserInputType == bind.key then match = true end
		
		if match then
			if bind.holdMode then
				if id=="aimbot" then Features.setAimbot(true)
				elseif id=="esp" then Features.setESP(true)
				elseif id=="infiniteJump" then Features.setInfiniteJump(true) end
			else
				if id=="aimbot" then State.aimbot=not State.aimbot; Features.setAimbot(State.aimbot); showToast("Aimbot: "..(State.aimbot and "ON" or "OFF"))
				elseif id=="esp" then State.esp=not State.esp; Features.setESP(State.esp); showToast("ESP: "..(State.esp and "ON" or "OFF"))
				elseif id=="infiniteJump" then State.infiniteJump=not State.infiniteJump; Features.setInfiniteJump(State.infiniteJump); showToast("Inf Jump: "..(State.infiniteJump and "ON" or "OFF")) end
			end
		end
	end

	if input.KeyCode==Enum.KeyCode.RightShift or input.KeyCode==Enum.KeyCode.F9 then
		togglePanel()
	end
end)

UIS.InputEnded:Connect(function(input)
	for id,bind in pairs(Keybinds) do
		local match = false
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind.key then match = true end
		if input.UserInputType.Name:match("MouseButton") and input.UserInputType == bind.key then match = true end

		if bind.holdMode and match then
			if id=="aimbot" then Features.setAimbot(false)
			elseif id=="esp" then Features.setESP(false)
			elseif id=="infiniteJump" then Features.setInfiniteJump(false) end
		end
	end
end)

task.delay(1.5,function()
	showToast("Rivals Fun 3D  ·  Press F9")
end)

print("[Rivals Fun 3D] Loaded — RightShift / F9 to open menu")

if readfile and isfile and isfile(configName) then
	local success, data = pcall(function() return HttpService:JSONDecode(readfile(configName)) end)
	if success and data and data.State and data.State.autoLoadConfig then
		loadConfig(true)
	end
end

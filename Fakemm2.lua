-- encoded by kimito

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")
local Workspace         = game:GetService("Workspace")

local LP                = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

-- ─── STEP 2: CONFIGURATION ───────────────────────────────────────────────────
local CONFIG = {
    -- Combat / Ballistics
    BulletSpeed         = 300,
    PredictionLead      = 1.02,
    FallbackPing        = 0.045,
    MaxRange            = 900,
    
    -- Aimlock Configuration
    AimlockKey          = Enum.KeyCode.X,
    AimlockTargetPart   = "Head",     
    CompensateVelocity  = true,        
    
    -- Crosshair UI
    CrossThick          = 1,
    CrossLen            = 6,
    CrossAlpha          = 0.30,
    CrossShadowAlpha    = 0.55,
    
    -- ESP Styling
    TagColor            = Color3.fromRGB(0, 255, 153),
    TagFont             = Enum.Font.GothamBold,
    TagSize             = 15,
    TagOffset           = Vector3.new(0, 2.6, 0),
    MaxTagDist          = 500
}

-- ─── STEP 3: GLOBAL STATE ─────────────────────────────────────────────────────
local State = {
    SilentAimEnabled    = false,
    AimlockEnabled      = true,
    AimlockActive       = false,
    EspEnabled          = true,
    
    Roles               = {},
    MurdererName        = nil,
    SheriffName         = nil,
    HeroName            = nil,
    
    HighlightMap        = {},
    TagMap              = {},
    TargetVelocities    = {},
    HookedRemotes       = {}
}

-- ─── STEP 4: NETWORK & ROLE REPLICATION ──────────────────────────────────────
local function getPing()
    local ok, pingVal = pcall(function()
        local net = Stats:FindFirstChild("Network")
        local ssi = net and net:FindFirstChild("ServerStatsItem")
        local pingItem = ssi and ssi:FindFirstChild("Data Ping")
        return pingItem and (pingItem:GetValue() / 1000) or CONFIG.FallbackPing
    end)
    return (ok and type(pingVal) == "number") and math.clamp(pingVal, 0.01, 0.4) or CONFIG.FallbackPing
end

local function isPlayerAlive(playerName)
    local data = State.Roles[playerName]
    return data ~= nil and not data.Killed and not data.Dead
end

local function updateRoles()
    local getPlayerDataRemote = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
    if getPlayerDataRemote and getPlayerDataRemote:IsA("RemoteFunction") then
        local success, result = pcall(function()
            return getPlayerDataRemote:InvokeServer()
        end)
        
        if success and type(result) == "table" then
            State.Roles = result
            State.MurdererName = nil
            State.SheriffName  = nil
            State.HeroName     = nil
            
            for name, info in pairs(result) do
                if type(info) == "table" then
                    if info.Role == "Murderer" then
                        State.MurdererName = name
                    elseif info.Role == "Sheriff" then
                        State.SheriffName = name
                    elseif info.Role == "Hero" then
                        State.HeroName = name
                    end
                end
            end
        end
    end
end

-- Refresh roles on a throttled loop to keep client ping low and prevent desync
task.spawn(function()
    while true do
        updateRoles()
        task.wait(1.5)
    end
end)

-- ─── STEP 5: TARGET SELECTION & PREDICTION ───────────────────────────────────
local function getMurdererPlayer()
    if not State.MurdererName then return nil end
    local target = Players:FindFirstChild(State.MurdererName)
    if target and target ~= LP and target.Character and isPlayerAlive(State.MurdererName) then
        return target
    end
    return nil
end

local function getTargetVelocity(character, rootPart)
    local rawVelocity = rootPart.AssemblyLinearVelocity
    if rawVelocity.Magnitude > 0.05 then
        return rawVelocity
    end
    
    local stored = State.TargetVelocities[character]
    if stored and stored.Velocity then
        return stored.Velocity
    end
    
    return Vector3.zero
end

local function calculatePredictedPosition(originPos, targetCharacter)
    local root = targetCharacter:FindFirstChild("HumanoidRootPart")
    local head = targetCharacter:FindFirstChild("Head")
    local primaryPart = (CONFIG.AimlockTargetPart == "Head" and head) or root
    if not primaryPart or not root then return nil end
    
    local ping = getPing()
    local distance = (primaryPart.Position - originPos).Magnitude
    local timeToImpact = distance / CONFIG.BulletSpeed
    local totalLeadTime = (timeToImpact + ping) * CONFIG.PredictionLead
    
    local velocity = getTargetVelocity(targetCharacter, root)
    
    local isAirborne = math.abs(velocity.Y) > 2.5
    local verticalLead = isAirborne and (velocity.Y * totalLeadTime) or 0
    local horizontalLead = Vector3.new(velocity.X, 0, velocity.Z) * totalLeadTime
    
    local predicted = primaryPart.Position + horizontalLead + Vector3.new(0, verticalLead, 0)
    
    if (predicted - originPos).Magnitude > CONFIG.MaxRange then
        return nil
    end
    
    return predicted
end

-- ─── STEP 6: INSTANT HARD-LOCK ENGINE (KEYBIND X) ────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CONFIG.AimlockKey then
        if State.AimlockEnabled then
            State.AimlockActive = not State.AimlockActive
        else
            State.AimlockActive = false
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if State.AimlockEnabled and State.AimlockActive then
        local murderer = getMurdererPlayer()
        if murderer and murderer.Character then
            local targetPart = murderer.Character:FindFirstChild(CONFIG.AimlockTargetPart) or murderer.Character:FindFirstChild("HumanoidRootPart")
            local root = murderer.Character:FindFirstChild("HumanoidRootPart")
            
            if targetPart and root then
                local camPos = Camera.CFrame.Position
                local targetPos = targetPart.Position
                
                -- Compensate for target velocity during fast motion so crosshair stays dead centered
                if CONFIG.CompensateVelocity then
                    local vel = root.AssemblyLinearVelocity
                    if vel.Magnitude > 0.5 then
                        targetPos = targetPos + (vel * 0.035)
                    end
                end
                
                -- Instant direct lock (Zero smoothing delay)
                Camera.CFrame = CFrame.lookAt(camPos, targetPos)
            end
        else
            State.AimlockActive = false
        end
    end
end)

-- ─── STEP 7: SILENT AIM & HOOKS ──────────────────────────────────────────────
local function getMurdererTargetPosition(barrelPos)
    local myChar = LP.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    
    local murderer = getMurdererPlayer()
    if not murderer or not murderer.Character then return nil end
    
    local origin = barrelPos or myRoot.Position
    return calculatePredictedPosition(origin, murderer.Character)
end

local function hookToolRemote(tool)
    if not tool then return end
    local remote = tool:FindFirstChild("Shoot") or tool:FindFirstChildWhichIsA("RemoteEvent")
    if not remote or State.HookedRemotes[remote] then return end
    
    State.HookedRemotes[remote] = true
    local originalFireServer = remote.FireServer
    
    remote.FireServer = function(self, barrelCF, targetCF, ...)
        if State.SilentAimEnabled then
            local origin = barrelCF and barrelCF.Position or nil
            local ok, predictedPos = pcall(getMurdererTargetPosition, origin)
            
            if ok and predictedPos then
                targetCF = CFrame.new(predictedPos)
                if barrelCF then
                    local direction = (predictedPos - barrelCF.Position).Unit
                    barrelCF = CFrame.lookAt(barrelCF.Position, barrelCF.Position + direction)
                end
            end
        end
        return originalFireServer(self, barrelCF, targetCF, ...)
    end
end

local function scanAndHookInventory()
    local char = LP.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then hookToolRemote(child) end
        end
    end
    if LP:FindFirstChild("Backpack") then
        for _, tool in ipairs(LP.Backpack:GetChildren()) do
            if tool:IsA("Tool") then hookToolRemote(tool) end
        end
    end
end

-- Metamethod namecall hook for game raycasts
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if not checkcaller() and (State.SilentAimEnabled or (State.AimlockEnabled and State.AimlockActive)) then
        if method == "FindPartOnRayWithIgnoreList" or method == "findPartOnRayWithIgnoreList" then
            local murderer = getMurdererPlayer()
            if murderer and murderer.Character then
                local predictedAim = calculatePredictedPosition(Camera.CFrame.Position, murderer.Character)
                if predictedAim then
                    args[1] = Ray.new(Camera.CFrame.Position, (predictedAim - Camera.CFrame.Position).Unit * 1000)
                    return oldNamecall(self, unpack(args))
                end
            end
        end
    end
    
    return oldNamecall(self, ...)
end)

-- Hook WeaponService module client methods
task.spawn(function()
    local clientServices = ReplicatedStorage:WaitForChild("ClientServices", 10)
    if not clientServices then return end
    local weaponService = clientServices:WaitForChild("WeaponService", 10)
    if not weaponService then return end
    
    local weaponModule = require(weaponService)
    if type(weaponModule) == "table" then
        if weaponModule.GetMouseTargetCFrame then
            local oldTargetCFrame = weaponModule.GetMouseTargetCFrame
            weaponModule.GetMouseTargetCFrame = function(...)
                if State.SilentAimEnabled then
                    local target = getMurdererTargetPosition()
                    if target then return CFrame.new(target) end
                end
                return oldTargetCFrame(...)
            end
        end
        
        if weaponModule.GetTargetPosition then
            local oldTargetPosition = weaponModule.GetTargetPosition
            weaponModule.GetTargetPosition = function(self, x, y)
                if State.SilentAimEnabled then
                    local target = getMurdererTargetPosition()
                    if target then return target end
                end
                return oldTargetPosition(self, x, y)
            end
        end
    end
end)

-- ─── STEP 8: VISUALS (ESP & CROSSHAIR) ────────────────────────────────────────
local function getRoleColor(playerName)
    local data = State.Roles[playerName]
    if not data then return Color3.fromRGB(0, 225, 0) end
    
    if data.Role == "Murderer" and isPlayerAlive(playerName) then
        return Color3.fromRGB(255, 30, 30)
    elseif data.Role == "Sheriff" and isPlayerAlive(playerName) then
        return Color3.fromRGB(30, 100, 255)
    elseif data.Role == "Hero" and isPlayerAlive(playerName) then
        return Color3.fromRGB(255, 230, 0)
    end
    return Color3.fromRGB(0, 225, 0)
end

local function createESP(player, character)
    if not character then return end
    local head = character:FindFirstChild("Head")
    if not head then return end
    
    if not character:FindFirstChild("ESP_Highlight") then
        local hl = Instance.new("Highlight")
        hl.Name = "ESP_Highlight"
        hl.FillColor = getRoleColor(player.Name)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.OutlineTransparency = 0.4
        hl.FillTransparency = 0.45
        hl.Enabled = State.EspEnabled
        hl.Parent = character
        State.HighlightMap[player] = hl
    end
    
    if not head:FindFirstChild("ESP_Tag") then
        local bb = Instance.new("BillboardGui")
        bb.Name = "ESP_Tag"
        bb.Size = UDim2.fromOffset(200, 30)
        bb.StudsOffset = CONFIG.TagOffset
        bb.AlwaysOnTop = true
        bb.MaxDistance = CONFIG.MaxTagDist
        bb.Enabled = State.EspEnabled
        bb.Parent = head
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = player.DisplayName
        label.TextColor3 = CONFIG.TagColor
        label.Font = CONFIG.TagFont
        label.TextSize = CONFIG.TagSize
        label.TextStrokeTransparency = 0.2
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Parent = bb
        
        State.TagMap[player] = bb
    end
end

local function setESPEnabled(enabled)
    State.EspEnabled = enabled
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP and player.Character then
            if enabled then
                createESP(player, player.Character)
            else
                if State.HighlightMap[player] then
                    State.HighlightMap[player]:Destroy()
                    State.HighlightMap[player] = nil
                end
                if State.TagMap[player] then
                    State.TagMap[player]:Destroy()
                    State.TagMap[player] = nil
                end
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    if State.EspEnabled then
        for player, hl in pairs(State.HighlightMap) do
            if hl and hl.Parent then
                hl.FillColor = getRoleColor(player.Name)
            end
        end
    end
end)

-- Minecraft-style Crosshair
local crossGui = Instance.new("ScreenGui")
crossGui.Name = "MM2_Crosshair"
crossGui.ResetOnSpawn = false
crossGui.IgnoreGuiInset = true
crossGui.Parent = LP:WaitForChild("PlayerGui")

local crossContainer = Instance.new("Frame")
crossContainer.Size = UDim2.fromOffset(0, 0)
crossContainer.Position = UDim2.fromScale(0.5, 0.5)
crossContainer.AnchorPoint = Vector2.new(0.5, 0.5)
crossContainer.BackgroundTransparency = 1
crossContainer.BorderSizePixel = 0
crossContainer.Parent = crossGui

local function drawCrosshairBar(size, color, transparency)
    local bar = Instance.new("Frame")
    bar.Size = size
    bar.Position = UDim2.fromScale(0.5, 0.5)
    bar.AnchorPoint = Vector2.new(0.5, 0.5)
    bar.BackgroundColor3 = color
    bar.BackgroundTransparency = transparency
    bar.BorderSizePixel = 0
    bar.Parent = crossContainer
end

local totalLen = CONFIG.CrossLen * 2 + CONFIG.CrossThick
local shadowLen = totalLen + 2

drawCrosshairBar(UDim2.fromOffset(shadowLen, CONFIG.CrossThick + 2), Color3.fromRGB(0, 0, 0), CONFIG.CrossShadowAlpha)
drawCrosshairBar(UDim2.fromOffset(CONFIG.CrossThick + 2, shadowLen), Color3.fromRGB(0, 0, 0), CONFIG.CrossShadowAlpha)
drawCrosshairBar(UDim2.fromOffset(totalLen, CONFIG.CrossThick), Color3.fromRGB(255, 255, 255), CONFIG.CrossAlpha)
drawCrosshairBar(UDim2.fromOffset(CONFIG.CrossThick, totalLen), Color3.fromRGB(255, 255, 255), CONFIG.CrossAlpha)
drawCrosshairBar(UDim2.fromOffset(CONFIG.CrossThick, CONFIG.CrossThick), Color3.fromRGB(0, 0, 0), 0.25)

-- ─── STEP 9: VELOCITY SAMPLING ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP and player.Character then
            local char = player.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local record = State.TargetVelocities[char]
                if not record then
                    record = { LastPos = root.Position, Velocity = Vector3.zero }
                    State.TargetVelocities[char] = record
                else
                    local currentPos = root.Position
                    local delta = (currentPos - record.LastPos)
                    if dt > 0.001 then
                        record.Velocity = delta / dt
                    end
                    record.LastPos = currentPos
                end
            end
        end
    end
end)

-- ─── STEP 10: WINDUI INTERFACE ────────────────────────────────────────────────
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua"))()

local Window = WindUI:CreateWindow({
    Title     = "Encoded by @realkimito",
    Icon      = "crosshair",
    Author    = "Beta Testing",
    ToggleKey = Enum.KeyCode.G,
    Size      = UDim2.fromOffset(580, 440),
})

local CombatTab = Window:Tab({
    Title = "Combat",
    Icon  = "sword",
})

local AimSection = CombatTab:Section({
    Title  = "Aimbot",
    Icon   = "crosshair",
    Opened = true,
})

AimSection:Toggle({
    Title    = "SilentAim (Murderer)",
    Desc     = "67aim",
    Icon     = "zap",
    Value    = false,
    Callback = function(state)
        State.SilentAimEnabled = state
    end,
})

AimSection:Toggle({
    Title    = "Aimlock (Murderer)",
    Desc     = " [Keybind: X]",
    Icon     = "target",
    Value    = true,
    Callback = function(state)
        State.AimlockEnabled = state
        if not state then
            State.AimlockActive = false
        end
    end,
})

local VisSection = CombatTab:Section({
    Title  = "Visuals",
    Icon   = "eye",
    Opened = true,
})

VisSection:Toggle({
    Title    = "ESP",
    Desc     = "Color Chams+Names",
    Icon     = "eye",
    Value    = true,
    Callback = function(state)
        setESPEnabled(state)
    end,
})

-- ─── STEP 11: INITIALIZATION & CLEANUP ────────────────────────────────────────
local function setupPlayer(player)
    player.CharacterAdded:Connect(function(char)
        if State.EspEnabled then
            task.wait(0.2)
            createESP(player, char)
        end
    end)
    if player.Character and State.EspEnabled then
        createESP(player, player.Character)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LP then
        setupPlayer(player)
    end
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
    if State.HighlightMap[player] then
        State.HighlightMap[player]:Destroy()
        State.HighlightMap[player] = nil
    end
    if State.TagMap[player] then
        State.TagMap[player]:Destroy()
        State.TagMap[player] = nil
    end
    if player.Character then
        State.TargetVelocities[player.Character] = nil
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    scanAndHookInventory()
end)

if LP:FindFirstChild("Backpack") then
    LP.Backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.2)
            hookToolRemote(child)
        end
    end)
end

scanAndHookInventory()
setESPEnabled(true)

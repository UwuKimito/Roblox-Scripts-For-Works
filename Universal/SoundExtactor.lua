local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local results = {}
local seen = {}

local function cleanId(raw)
    if not raw or raw == "" then return nil end
    return string.match(raw, "%d+")
end

local function addSound(id, name, class, fullPath)
    if not id or seen[id] then return end
    seen[id] = true
    table.insert(results, { id = id, name = name or "?", class = class or "?", path = fullPath or name })
end

for _, obj in ipairs(game:GetDescendants()) do
    local ok, soundId = pcall(function()
        if obj:IsA("Sound") then return obj.SoundId end
    end)
    if ok and soundId then
        addSound(cleanId(soundId), obj.Name, obj.ClassName, obj:GetFullName())
    end
end

for _, obj in ipairs(game:GetDescendants()) do
    if obj:IsA("LocalScript") or obj:IsA("ModuleScript") or obj:IsA("Script") then
        local ok, src = pcall(function() return obj.Source end)
        if ok and src then
            for id in string.gmatch(src, "rbxassetid://(%d+)") do
                addSound(id, obj.Name .. " [script]", obj.ClassName, obj:GetFullName())
            end
        end
    end
end

print(("[AnyGame Sound Grabber] Found %d unique sound assets."):format(#results))

local function copyToClipboard(text)
    if setclipboard then setclipboard(text); return true end
    if toclipboard then toclipboard(text); return true end
    if writeclipboard then writeclipboard(text); return true end
    return false
end

pcall(function()
    local old = CoreGui:FindFirstChild("AnyGame_SoundGrabber")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "AnyGame_SoundGrabber"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 520, 0, 620)
frame.Position = UDim2.new(0.5, -260, 0.5, -310)
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.Active = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 220, 220)
stroke.Thickness = 1.5
stroke.Transparency = 0.35
stroke.Parent = frame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
titleBar.BorderSizePixel = 0
titleBar.Parent = frame
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = ("AnyGame Sound Grabber  •  %d found"):format(#results)
title.TextColor3 = Color3.fromRGB(0, 235, 235)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
local ccCorner = Instance.new("UICorner")
ccCorner.CornerRadius = UDim.new(0, 6)
ccCorner.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local searchBar = Instance.new("Frame")
searchBar.Size = UDim2.new(1, -20, 0, 36)
searchBar.Position = UDim2.new(0, 10, 0, 50)
searchBar.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
searchBar.BorderSizePixel = 0
searchBar.Parent = frame
local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 8)
sbCorner.Parent = searchBar

local searchIcon = Instance.new("TextLabel")
searchIcon.Size = UDim2.new(0, 30, 1, 0)
searchIcon.Position = UDim2.new(0, 6, 0, 0)
searchIcon.BackgroundTransparency = 1
searchIcon.Text = "🔍"
searchIcon.TextSize = 16
searchIcon.Parent = searchBar

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -90, 1, 0)
searchBox.Position = UDim2.new(0, 36, 0, 0)
searchBox.BackgroundTransparency = 1
searchBox.Text = ""
searchBox.PlaceholderText = "Search sound name, class, or ID..."
searchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
searchBox.TextColor3 = Color3.fromRGB(230, 230, 235)
searchBox.TextSize = 14
searchBox.Font = Enum.Font.Gotham
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent = searchBar

local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0, 28, 0, 28)
clearBtn.Position = UDim2.new(1, -34, 0.5, -14)
clearBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
clearBtn.Text = "✕"
clearBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
clearBtn.TextSize = 12
clearBtn.Font = Enum.Font.GothamBold
clearBtn.BorderSizePixel = 0
clearBtn.Visible = false
clearBtn.Parent = searchBar
local clbCorner = Instance.new("UICorner")
clbCorner.CornerRadius = UDim.new(0, 5)
clbCorner.Parent = clearBtn
clearBtn.MouseButton1Click:Connect(function() searchBox.Text = "" end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -142)
scroll.Position = UDim2.new(0, 10, 0, 94)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 200)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = frame

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll

local emptyMsg = Instance.new("TextLabel")
emptyMsg.Size = UDim2.new(1, -20, 0, 80)
emptyMsg.Position = UDim2.new(0, 10, 0, 250)
emptyMsg.BackgroundTransparency = 1
emptyMsg.Text = "No results match your search."
emptyMsg.TextColor3 = Color3.fromRGB(150, 150, 160)
emptyMsg.TextSize = 14
emptyMsg.Font = Enum.Font.Gotham
emptyMsg.Visible = false
emptyMsg.ZIndex = 2
emptyMsg.Parent = frame

local ROW_HEIGHT = 62
local ROW_PADDING = 4
local rows = {}
local activePreviewSound = nil

local function stopActivePreview()
    if activePreviewSound then
        pcall(function()
            activePreviewSound:Stop()
            activePreviewSound:Destroy()
        end)
        activePreviewSound = nil
    end
end

for i, a in ipairs(results) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
    row.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    row.BorderSizePixel = 0
    row.LayoutOrder = i
    row.Parent = scroll
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 6)
    rc.Parent = row

    local playBtn = Instance.new("TextButton")
    playBtn.Size = UDim2.new(0, 50, 0, 50)
    playBtn.Position = UDim2.new(0, 6, 0.5, -25)
    playBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 100)
    playBtn.Text = "▶"
    playBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    playBtn.TextSize = 18
    playBtn.Font = Enum.Font.GothamBold
    playBtn.BorderSizePixel = 0
    playBtn.AutoButtonColor = true
    playBtn.Parent = row
    local pbCorner = Instance.new("UICorner")
    pbCorner.CornerRadius = UDim.new(0, 8)
    pbCorner.Parent = playBtn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -190, 0.55, 0)
    label.Position = UDim2.new(0, 64, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = a.name
    label.TextColor3 = Color3.fromRGB(220, 220, 230)
    label.TextSize = 13
    label.Font = Enum.Font.Code
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = row

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, -190, 0.45, 0)
    subLabel.Position = UDim2.new(0, 64, 0.55, 0)
    subLabel.BackgroundTransparency = 1
    subLabel.Text = ("%s  •  rbxassetid://%s"):format(a.class, a.id)
    subLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
    subLabel.TextSize = 11
    subLabel.Font = Enum.Font.Code
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.TextYAlignment = Enum.TextYAlignment.Center
    subLabel.TextTruncate = Enum.TextTruncate.AtEnd
    subLabel.Parent = row

    local copy = Instance.new("TextButton")
    copy.Size = UDim2.new(0, 50, 0, 22)
    copy.Position = UDim2.new(1, -56, 0.5, -11)
    copy.BackgroundColor3 = Color3.fromRGB(0, 130, 130)
    copy.Text = "Copy"
    copy.TextColor3 = Color3.fromRGB(255, 255, 255)
    copy.TextSize = 12
    copy.Font = Enum.Font.GothamBold
    copy.BorderSizePixel = 0
    copy.Parent = row
    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 5)
    cbCorner.Parent = copy

    copy.MouseButton1Click:Connect(function()
        copyToClipboard(a.id)
        copy.Text = "✓"
        task.wait(0.8)
        copy.Text = "Copy"
    end)

    local previewSound = nil

    playBtn.MouseButton1Click:Connect(function()
        if previewSound and previewSound.IsPlaying then
            previewSound:Pause()
            playBtn.Text = "▶"
            playBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 100)
            return
        end

        if previewSound and previewSound.IsPaused then
            previewSound:Resume()
            playBtn.Text = "⏸"
            playBtn.BackgroundColor3 = Color3.fromRGB(0, 60, 60)
            return
        end

        stopActivePreview()

        previewSound = Instance.new("Sound")
        previewSound.SoundId = "rbxassetid://" .. a.id
        previewSound.Volume = 1
        previewSound.Parent = SoundService

        previewSound.Loaded:Wait()
        previewSound:Play()

        activePreviewSound = previewSound
        playBtn.Text = "⏸"
        playBtn.BackgroundColor3 = Color3.fromRGB(0, 60, 60)

        previewSound.Ended:Connect(function()
            if playBtn and playBtn.Parent then
                playBtn.Text = "▶"
                playBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 100)
            end
        end)
    end)

    rows[i] = { instance = row, data = a, playBtn = playBtn }
end

local function updateCanvasSize()
    local count = 0
    for _, r in ipairs(rows) do
        if r.instance.Visible then count = count + 1 end
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, count * (ROW_HEIGHT + ROW_PADDING) + 8)
end

local function applyFilter(query)
    query = (query or ""):lower()
    local visible = 0
    for _, r in ipairs(rows) do
        local a = r.data
        local match = query == ""
            or a.name:lower():find(query, 1, true)
            or a.class:lower():find(query, 1, true)
            or a.id:find(query, 1, true)
            or a.path:lower():find(query, 1, true)
        r.instance.Visible = match
        if match then visible = visible + 1 end
    end
    emptyMsg.Visible = (visible == 0 and #rows > 0)
    updateCanvasSize()
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    applyFilter(searchBox.Text)
    clearBtn.Visible = searchBox.Text ~= ""
end)

updateCanvasSize()

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Visible = false
overlay.ZIndex = 100
overlay.Parent = gui
overlay.MouseButton1Click:Connect(function() overlay.Visible = false end)

local content = Instance.new("Frame")
content.Size = UDim2.new(0, 440, 0, 420)
content.Position = UDim2.new(0.5, -220, 0.5, -210)
content.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
content.BorderSizePixel = 0
content.Active = true
content.ZIndex = 101
content.Parent = overlay
local ctCorner = Instance.new("UICorner")
ctCorner.CornerRadius = UDim.new(0, 10)
ctCorner.Parent = content
local ctStroke = Instance.new("UIStroke")
ctStroke.Color = Color3.fromRGB(0, 220, 220)
ctStroke.Thickness = 1.5
ctStroke.Transparency = 0.4
ctStroke.Parent = content

local waveFrame = Instance.new("Frame")
waveFrame.Size = UDim2.new(1, -40, 0, 140)
waveFrame.Position = UDim2.new(0, 20, 0, 20)
waveFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
waveFrame.BorderSizePixel = 0
waveFrame.ZIndex = 102
waveFrame.Parent = content
local wfCorner = Instance.new("UICorner")
wfCorner.CornerRadius = UDim.new(0, 8)
wfCorner.Parent = waveFrame

local waveIcon = Instance.new("TextLabel")
waveIcon.Size = UDim2.new(1, 0, 1, 0)
waveIcon.BackgroundTransparency = 1
waveIcon.Text = "🎵"
waveIcon.TextSize = 48
waveIcon.TextColor3 = Color3.fromRGB(0, 200, 200)
waveIcon.ZIndex = 103
waveIcon.Parent = waveFrame

local previewName = Instance.new("TextLabel")
previewName.Size = UDim2.new(1, -40, 0, 28)
previewName.Position = UDim2.new(0, 20, 0, 170)
previewName.BackgroundTransparency = 1
previewName.Text = ""
previewName.TextColor3 = Color3.fromRGB(0, 235, 235)
previewName.TextSize = 16
previewName.Font = Enum.Font.GothamBold
previewName.TextXAlignment = Enum.TextXAlignment.Left
previewName.TextTruncate = Enum.TextTruncate.AtEnd
previewName.ZIndex = 102
previewName.Parent = content

local previewInfo = Instance.new("TextLabel")
previewInfo.Size = UDim2.new(1, -40, 0, 40)
previewInfo.Position = UDim2.new(0, 20, 0, 200)
previewInfo.BackgroundTransparency = 1
previewInfo.Text = ""
previewInfo.TextColor3 = Color3.fromRGB(200, 200, 210)
previewInfo.TextSize = 12
previewInfo.Font = Enum.Font.Code
previewInfo.TextXAlignment = Enum.TextXAlignment.Left
previewInfo.TextYAlignment = Enum.TextYAlignment.Top
previewInfo.TextWrapped = true
previewInfo.ZIndex = 102
previewInfo.Parent = content

local seekBack = Instance.new("Frame")
seekBack.Size = UDim2.new(1, -40, 0, 6)
seekBack.Position = UDim2.new(0, 20, 0, 250)
seekBack.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
seekBack.BorderSizePixel = 0
seekBack.ZIndex = 102
seekBack.Parent = content
local seekCorner = Instance.new("UICorner")
seekCorner.CornerRadius = UDim.new(0, 3)
seekCorner.Parent = seekBack

local seekFill = Instance.new("Frame")
seekFill.Size = UDim2.new(0, 0, 1, 0)
seekFill.BackgroundColor3 = Color3.fromRGB(0, 220, 220)
seekFill.BorderSizePixel = 0
seekFill.ZIndex = 103
seekFill.Parent = seekBack
local sfCorner = Instance.new("UICorner")
sfCorner.CornerRadius = UDim.new(0, 3)
sfCorner.Parent = seekFill

local timeCurrent = Instance.new("TextLabel")
timeCurrent.Size = UDim2.new(0, 60, 0, 20)
timeCurrent.Position = UDim2.new(0, 20, 0, 260)
timeCurrent.BackgroundTransparency = 1
timeCurrent.Text = "0:00"
timeCurrent.TextColor3 = Color3.fromRGB(160, 160, 170)
timeCurrent.TextSize = 11
timeCurrent.Font = Enum.Font.Code
timeCurrent.TextXAlignment = Enum.TextXAlignment.Left
timeCurrent.ZIndex = 102
timeCurrent.Parent = content

local timeTotal = Instance.new("TextLabel")
timeTotal.Size = UDim2.new(0, 60, 0, 20)
timeTotal.Position = UDim2.new(1, -80, 0, 260)
timeTotal.BackgroundTransparency = 1
timeTotal.Text = "0:00"
timeTotal.TextColor3 = Color3.fromRGB(160, 160, 170)
timeTotal.TextSize = 11
timeTotal.Font = Enum.Font.Code
timeTotal.TextXAlignment = Enum.TextXAlignment.Right
timeTotal.ZIndex = 102
timeTotal.Parent = content

local modalPlay = Instance.new("TextButton")
modalPlay.Size = UDim2.new(0, 50, 0, 50)
modalPlay.Position = UDim2.new(0.5, -75, 0, 300)
modalPlay.BackgroundColor3 = Color3.fromRGB(0, 100, 100)
modalPlay.Text = "▶"
modalPlay.TextColor3 = Color3.fromRGB(255, 255, 255)
modalPlay.TextSize = 20
modalPlay.Font = Enum.Font.GothamBold
modalPlay.BorderSizePixel = 0
modalPlay.ZIndex = 102
modalPlay.Parent = content
local mpCorner = Instance.new("UICorner")
mpCorner.CornerRadius = UDim.new(0, 25)
mpCorner.Parent = modalPlay

local modalStop = Instance.new("TextButton")
modalStop.Size = UDim2.new(0, 50, 0, 50)
modalStop.Position = UDim2.new(0.5, 25, 0, 300)
modalStop.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
modalStop.Text = "■"
modalStop.TextColor3 = Color3.fromRGB(255, 255, 255)
modalStop.TextSize = 18
modalStop.Font = Enum.Font.GothamBold
modalStop.BorderSizePixel = 0
modalStop.ZIndex = 102
modalStop.Parent = content
local msCorner = Instance.new("UICorner")
msCorner.CornerRadius = UDim.new(0, 25)
msCorner.Parent = modalStop

local previewCopy = Instance.new("TextButton")
previewCopy.Size = UDim2.new(0, 140, 0, 36)
previewCopy.Position = UDim2.new(0.5, -70, 1, -52)
previewCopy.BackgroundColor3 = Color3.fromRGB(0, 130, 130)
previewCopy.Text = "Copy ID"
previewCopy.TextColor3 = Color3.fromRGB(255, 255, 255)
previewCopy.TextSize = 14
previewCopy.Font = Enum.Font.GothamBold
previewCopy.BorderSizePixel = 0
previewCopy.ZIndex = 102
previewCopy.Parent = content
local pcCorner = Instance.new("UICorner")
pcCorner.CornerRadius = UDim.new(0, 6)
pcCorner.Parent = previewCopy

local previewClose = Instance.new("TextButton")
previewClose.Size = UDim2.new(0, 30, 0, 30)
previewClose.Position = UDim2.new(1, -38, 0, 8)
previewClose.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
previewClose.Text = "✕"
previewClose.TextColor3 = Color3.fromRGB(255, 180, 180)
previewClose.TextSize = 16
previewClose.Font = Enum.Font.GothamBold
previewClose.BorderSizePixel = 0
previewClose.ZIndex = 103
previewClose.Parent = content
local pclCorner = Instance.new("UICorner")
pclCorner.CornerRadius = UDim.new(0, 6)
pclCorner.Parent = previewClose

local modalSound = nil
local modalConnection = nil
local currentPreviewId = nil
local modalPlaying = false

local function formatTime(seconds)
    if not seconds or seconds ~= seconds then return "0:00" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end

local function stopModalSound()
    if modalConnection then
        modalConnection:Disconnect()
        modalConnection = nil
    end
    if modalSound then
        pcall(function()
            modalSound:Stop()
            modalSound:Destroy()
        end)
        modalSound = nil
    end
    modalPlaying = false
    modalPlay.Text = "▶"
    modalPlay.BackgroundColor3 = Color3.fromRGB(0, 100, 100)
    seekFill.Size = UDim2.new(0, 0, 1, 0)
    timeCurrent.Text = "0:00"
    timeTotal.Text = "0:00"
end

local function openPreview(a)
    stopActivePreview()
    stopModalSound()
    currentPreviewId = a.id
    previewName.Text = a.name
    previewInfo.Text = ("Class: %s\nPath: %s\nID: rbxassetid://%s"):format(a.class, a.path, a.id)
    overlay.Visible = true

    modalSound = Instance.new("Sound")
    modalSound.SoundId = "rbxassetid://" .. a.id
    modalSound.Volume = 1
    modalSound.Parent = SoundService

    modalSound.Loaded:Wait()
    timeTotal.Text = formatTime(modalSound.TimeLength)

    modalConnection = RunService.RenderStepped:Connect(function()
        if modalSound and modalSound.IsPlaying then
            local dur = modalSound.TimeLength
            if dur > 0 then
                local progress = math.clamp(modalSound.TimePosition / dur, 0, 1)
                seekFill.Size = UDim2.new(progress, 0, 1, 0)
                timeCurrent.Text = formatTime(modalSound.TimePosition)
            end
        end
    end)

    modalSound.Ended:Connect(function()
        modalPlaying = false
        modalPlay.Text = "▶"
        modalPlay.BackgroundColor3 = Color3.fromRGB(0, 100, 100)
        seekFill.Size = UDim2.new(0, 0, 1, 0)
        timeCurrent.Text = "0:00"
    end)
end

modalPlay.MouseButton1Click:Connect(function()
    if not modalSound then return end
    if modalSound.IsPlaying then
        modalSound:Pause()
        modalPlaying = false
        modalPlay.Text = "▶"
        modalPlay.BackgroundColor3 = Color3.fromRGB(0, 100, 100)
    else
        modalSound:Resume()
        modalPlaying = true
        modalPlay.Text = "⏸"
        modalPlay.BackgroundColor3 = Color3.fromRGB(0, 60, 60)
    end
end)

modalStop.MouseButton1Click:Connect(function()
    stopModalSound()
end)

previewCopy.MouseButton1Click:Connect(function()
    if not currentPreviewId then return end
    copyToClipboard(currentPreviewId)
    previewCopy.Text = "Copied!"
    task.wait(1)
    previewCopy.Text = "Copy ID"
end)

local function closeModal()
    stopModalSound()
    overlay.Visible = false
end
previewClose.MouseButton1Click:Connect(closeModal)
overlay.MouseButton1Click:Connect(closeModal)

for i, r in ipairs(rows) do
    local holdTime = 0.4
    local holding = false
    local holdStart = 0

    r.playBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            holding = true
            holdStart = tick()
            task.delay(holdTime, function()
                if holding and tick() - holdStart >= holdTime then
                    holding = false
                    openPreview(r.data)
                end
            end)
        end
    end)

    r.playBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            holding = false
        end
    end)
end

local dragging, dragStart, startPos

local function beginDrag(input)
    dragging = true
    dragStart = input.Position
    startPos = frame.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
        end
    end)
end

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        beginDrag(input)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

print("[AnyGame Sound Grabber] Ready.")

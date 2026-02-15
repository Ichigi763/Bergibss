-- BSS Delta-style local script with modular UI, JSON configs and remote helpers

if getgenv().BSS_LOCAL_DELTA and getgenv().BSS_LOCAL_DELTA.Shutdown then
    getgenv().BSS_LOCAL_DELTA.Shutdown()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ScriptCore = {
    Running = true,
    Loops = {},
    Connections = {},
    Remotes = {},
    ConfigPath = "BSS_Delta_Config",
    ConfigFile = nil,
}

ScriptCore.ConfigFile = string.format("%s/%s.json", ScriptCore.ConfigPath, LocalPlayer.UserId)

local DefaultConfig = {
    enabled = true,
    autoFarm = false,
    autoConvert = false,
    autoToken = false,
    autoQuest = false,
    autoBoosters = false,
    field = "Sunflower Field",
    walkSpeed = 28,
    jumpPower = 60,
    convertAtPercent = 85,
    selectedSprinkler = "Basic",
    customTextTag = "DeltaUser",
    useRemoteProbe = true,
}

local Config = table.clone(DefaultConfig)

local function canFileIO()
    return typeof(writefile) == "function"
        and typeof(readfile) == "function"
        and typeof(isfile) == "function"
        and typeof(isfolder) == "function"
        and typeof(makefolder) == "function"
end

local function saveConfig()
    if not canFileIO() then
        return
    end

    if not isfolder(ScriptCore.ConfigPath) then
        makefolder(ScriptCore.ConfigPath)
    end

    writefile(ScriptCore.ConfigFile, HttpService:JSONEncode(Config))
end

local function loadConfig()
    if not canFileIO() then
        return
    end

    if not isfolder(ScriptCore.ConfigPath) then
        makefolder(ScriptCore.ConfigPath)
    end

    if not isfile(ScriptCore.ConfigFile) then
        saveConfig()
        return
    end

    local ok, parsed = pcall(function()
        return HttpService:JSONDecode(readfile(ScriptCore.ConfigFile))
    end)

    if ok and type(parsed) == "table" then
        for k, v in pairs(DefaultConfig) do
            if parsed[k] == nil then
                parsed[k] = v
            end
        end
        Config = parsed
    else
        saveConfig()
    end
end

loadConfig()

local function registerConnection(conn)
    table.insert(ScriptCore.Connections, conn)
    return conn
end

local function bindLoop(name, fn)
    if ScriptCore.Loops[name] then
        ScriptCore.Loops[name]:Disconnect()
    end
    ScriptCore.Loops[name] = RunService.Heartbeat:Connect(fn)
end

local function stopLoop(name)
    local loop = ScriptCore.Loops[name]
    if loop then
        loop:Disconnect()
        ScriptCore.Loops[name] = nil
    end
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRoot()
    local character = getCharacter()
    return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local character = getCharacter()
    return character:FindFirstChildOfClass("Humanoid")
end

local function tweenTo(position, speed)
    local root = getRoot()
    if not root then
        return
    end
    local distance = (root.Position - position).Magnitude
    local duration = math.max(distance / speed, 0.12)
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(position)})
    tween:Play()
    tween.Completed:Wait()
end

local function collectRemotes()
    ScriptCore.Remotes = {}
    for _, item in ipairs(ReplicatedStorage:GetDescendants()) do
        if item:IsA("RemoteEvent") or item:IsA("RemoteFunction") then
            ScriptCore.Remotes[item.Name] = item
        end
    end
end

collectRemotes()
registerConnection(ReplicatedStorage.DescendantAdded:Connect(function(item)
    if item:IsA("RemoteEvent") or item:IsA("RemoteFunction") then
        ScriptCore.Remotes[item.Name] = item
    end
end))

local function callRemote(name, ...)
    local remote = ScriptCore.Remotes[name]
    if not remote then
        return false, "missing"
    end

    local ok, result = pcall(function()
        if remote:IsA("RemoteFunction") then
            return remote:InvokeServer(...)
        end
        remote:FireServer(...)
        return true
    end)

    if not ok then
        return false, result
    end

    return true, result
end

local function findFieldBase(fieldName)
    local fields = workspace:FindFirstChild("FlowerZones") or workspace:FindFirstChild("Fields")
    if not fields then
        return nil
    end

    for _, zone in ipairs(fields:GetChildren()) do
        if zone.Name == fieldName then
            local base = zone:FindFirstChild("FieldBox") or zone:FindFirstChild("Plane") or zone:FindFirstChildWhichIsA("BasePart")
            return base
        end
    end

    return nil
end

local function findHiveBase()
    local hives = workspace:FindFirstChild("Hives") or workspace:FindFirstChild("Honeycombs")
    if not hives then
        return nil
    end

    for _, hive in ipairs(hives:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and owner.Value == LocalPlayer then
            return hive:FindFirstChild("Platform") or hive:FindFirstChildWhichIsA("BasePart")
        end
    end

    return nil
end

local function convertAtHive()
    local hive = findHiveBase()
    if hive then
        tweenTo(hive.Position + Vector3.new(0, 3, 0), 38)
    end
    callRemote("PlayerHiveCommand", "Convert")
    callRemote("HoneyMachineCollect")
end

local function collectClosestToken()
    local root = getRoot()
    if not root then
        return
    end

    local tokensFolder = workspace:FindFirstChild("Collectibles") or workspace:FindFirstChild("Tokens")
    if not tokensFolder then
        return
    end

    local closest, dist = nil, math.huge
    for _, token in ipairs(tokensFolder:GetChildren()) do
        local part = token:IsA("BasePart") and token or token:FindFirstChildWhichIsA("BasePart")
        if part then
            local d = (root.Position - part.Position).Magnitude
            if d < dist then
                dist = d
                closest = part
            end
        end
    end

    if closest and dist < 120 then
        root.CFrame = CFrame.new(closest.Position + Vector3.new(0, 2.5, 0))
    end
end

local function runRemoteProbe()
    if not Config.useRemoteProbe then
        return
    end
    callRemote("ToyEvent", "GlueDispenser")
    callRemote("ToyEvent", "Stockings")
    callRemote("SprinklerBuilder_Player", Config.selectedSprinkler)
end

local function getBackpackPercent()
    local stats = LocalPlayer:FindFirstChild("CoreStats") or LocalPlayer:FindFirstChild("leaderstats")
    if not stats then
        return 0
    end

    local pollen = stats:FindFirstChild("Pollen")
    local capacity = stats:FindFirstChild("Capacity")
    if not pollen or not capacity or capacity.Value == 0 then
        return 0
    end

    return math.floor((pollen.Value / capacity.Value) * 100)
end

local function setMovement()
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.WalkSpeed = Config.walkSpeed
        humanoid.JumpPower = Config.jumpPower
    end
end

bindLoop("MovementLoop", function()
    if not Config.enabled then
        return
    end
    setMovement()
end)

bindLoop("FarmLoop", function()
    if not Config.enabled or not Config.autoFarm then
        return
    end

    local field = findFieldBase(Config.field)
    if field then
        local root = getRoot()
        if root and (root.Position - field.Position).Magnitude > 18 then
            tweenTo(field.Position + Vector3.new(0, 3, 0), 45)
        end
    end

    runRemoteProbe()

    if Config.autoToken then
        collectClosestToken()
    end

    if Config.autoConvert and getBackpackPercent() >= Config.convertAtPercent then
        convertAtHive()
    end
end)

bindLoop("QuestLoop", function()
    if not Config.enabled or not Config.autoQuest then
        return
    end
    callRemote("CompleteQuest")
    callRemote("AcceptQuest")
end)

bindLoop("BoosterLoop", function()
    if not Config.enabled or not Config.autoBoosters then
        return
    end
    callRemote("ToyEvent", "BlueberryDispenser")
    callRemote("ToyEvent", "TreatDispenser")
end)

local gui = Instance.new("ScreenGui")
gui.Name = "BSS_Delta_UI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(530, 390)
main.Position = UDim2.fromScale(0.08, 0.2)
main.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner", main)
corner.CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 36)
title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(240, 240, 240)
title.Text = "BSS Delta Local"
title.Parent = main

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -16, 1, -50)
body.Position = UDim2.fromOffset(8, 44)
body.BackgroundTransparency = 1
body.Parent = main

local left = Instance.new("Frame")
left.Size = UDim2.new(0.48, -4, 1, 0)
left.BackgroundTransparency = 1
left.Parent = body

local right = Instance.new("Frame")
right.Size = UDim2.new(0.52, -4, 1, 0)
right.Position = UDim2.new(0.48, 8, 0, 0)
right.BackgroundTransparency = 1
right.Parent = body

local function addLayout(target)
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = target
end

addLayout(left)
addLayout(right)

local function makeSection(parent, text)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 108)
    section.BackgroundColor3 = Color3.fromRGB(33, 36, 46)
    section.BorderSizePixel = 0
    section.Parent = parent
    Instance.new("UICorner", section).CornerRadius = UDim.new(0, 8)

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -12, 0, 22)
    header.Position = UDim2.fromOffset(8, 6)
    header.BackgroundTransparency = 1
    header.Text = text
    header.TextColor3 = Color3.fromRGB(255, 209, 102)
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Font = Enum.Font.GothamBold
    header.TextSize = 14
    header.Parent = section

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -12, 1, -32)
    content.Position = UDim2.fromOffset(6, 26)
    content.BackgroundTransparency = 1
    content.Parent = section
    addLayout(content)

    return content
end

local function makeToggle(parent, label, key)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 24)
    row.Text = ""
    row.AutoButtonColor = false
    row.BackgroundColor3 = Color3.fromRGB(43, 48, 63)
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -44, 1, 0)
    txt.Position = UDim2.fromOffset(8, 0)
    txt.BackgroundTransparency = 1
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextColor3 = Color3.fromRGB(224, 224, 224)
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 13
    txt.Text = label
    txt.Parent = row

    local check = Instance.new("TextLabel")
    check.Size = UDim2.fromOffset(20, 20)
    check.Position = UDim2.new(1, -26, 0.5, -10)
    check.BackgroundColor3 = Config[key] and Color3.fromRGB(69, 201, 109) or Color3.fromRGB(92, 97, 110)
    check.Text = Config[key] and "✓" or ""
    check.TextColor3 = Color3.new(1, 1, 1)
    check.Font = Enum.Font.GothamBold
    check.TextSize = 14
    check.Parent = row
    Instance.new("UICorner", check).CornerRadius = UDim.new(0, 4)

    registerConnection(row.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        check.BackgroundColor3 = Config[key] and Color3.fromRGB(69, 201, 109) or Color3.fromRGB(92, 97, 110)
        check.Text = Config[key] and "✓" or ""
        saveConfig()
    end))
end

local function makeSlider(parent, label, key, minValue, maxValue)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, 0, 0, 14)
    txt.BackgroundTransparency = 1
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextColor3 = Color3.fromRGB(224, 224, 224)
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 12
    txt.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 14)
    bar.Position = UDim2.fromOffset(0, 20)
    bar.BackgroundColor3 = Color3.fromRGB(43, 48, 63)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(120, 156, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local function render()
        local alpha = math.clamp((Config[key] - minValue) / (maxValue - minValue), 0, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        txt.Text = string.format("%s: %d", label, Config[key])
    end

    render()
    local dragging = false

    local function setByMouse(x)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(minValue + (maxValue - minValue) * alpha + 0.5)
        Config[key] = value
        render()
        saveConfig()
    end

    registerConnection(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setByMouse(input.Position.X)
        end
    end))

    registerConnection(bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    registerConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setByMouse(input.Position.X)
        end
    end))
end

local function makeDropdown(parent, label, key, values)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 26)
    button.BackgroundColor3 = Color3.fromRGB(43, 48, 63)
    button.TextColor3 = Color3.fromRGB(224, 224, 224)
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.TextSize = 12
    button.Font = Enum.Font.Gotham
    button.BorderSizePixel = 0
    button.Parent = parent
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)

    local index = table.find(values, Config[key]) or 1
    local function render()
        button.Text = string.format("   %s: %s", label, tostring(values[index]))
    end

    render()
    registerConnection(button.MouseButton1Click:Connect(function()
        index += 1
        if index > #values then
            index = 1
        end
        Config[key] = values[index]
        render()
        saveConfig()
    end))
end

local function makeTextbox(parent, label, key, placeholder)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 28)
    box.BackgroundColor3 = Color3.fromRGB(43, 48, 63)
    box.TextColor3 = Color3.fromRGB(235, 235, 235)
    box.PlaceholderText = placeholder
    box.Text = tostring(Config[key] or "")
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 0
    box.Parent = parent
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    box.FocusLost:Connect(function(enter)
        if enter then
            Config[key] = box.Text
            saveConfig()
        end
    end)

    local labelObj = Instance.new("TextLabel")
    labelObj.Size = UDim2.new(1, 0, 0, 14)
    labelObj.Position = UDim2.fromOffset(0, -14)
    labelObj.BackgroundTransparency = 1
    labelObj.TextXAlignment = Enum.TextXAlignment.Left
    labelObj.TextColor3 = Color3.fromRGB(180, 184, 196)
    labelObj.Font = Enum.Font.Gotham
    labelObj.TextSize = 11
    labelObj.Text = label
    labelObj.Parent = box
end

local sectionMain = makeSection(left, "Авто функции")
makeToggle(sectionMain, "Включить скрипт", "enabled")
makeToggle(sectionMain, "Авто фарм поля", "autoFarm")
makeToggle(sectionMain, "Авто сбор токенов", "autoToken")
makeToggle(sectionMain, "Авто конвертация на улье", "autoConvert")

local sectionStats = makeSection(left, "Статы и лимиты")
makeSlider(sectionStats, "Скорость (20-100)", "walkSpeed", 20, 100)
makeSlider(sectionStats, "Прыжок (20-100)", "jumpPower", 20, 100)
makeSlider(sectionStats, "Конверт при %", "convertAtPercent", 20, 100)

local sectionField = makeSection(right, "Поля и ремоуты")
makeDropdown(sectionField, "Поле", "field", {
    "Sunflower Field", "Dandelion Field", "Mushroom Field", "Blue Flower Field",
    "Clover Field", "Bamboo Field", "Pineapple Patch", "Pumpkin Patch", "Rose Field",
})
makeDropdown(sectionField, "Спринклер", "selectedSprinkler", {"Basic", "Silver", "Golden", "Diamond", "Supreme"})
makeToggle(sectionField, "Remote probe", "useRemoteProbe")
makeToggle(sectionField, "Авто квесты", "autoQuest")
makeToggle(sectionField, "Авто бустеры", "autoBoosters")

local sectionCustom = makeSection(right, "Кастом")
makeTextbox(sectionCustom, "Текстовый тег", "customTextTag", "Введите тег")

local dragData = {active = false, start = Vector2.zero, original = UDim2.new()}
registerConnection(title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragData.active = true
        dragData.start = input.Position
        dragData.original = main.Position
    end
end))

registerConnection(title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragData.active = false
    end
end))

registerConnection(UserInputService.InputChanged:Connect(function(input)
    if dragData.active and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragData.start
        main.Position = UDim2.new(
            dragData.original.X.Scale,
            dragData.original.X.Offset + delta.X,
            dragData.original.Y.Scale,
            dragData.original.Y.Offset + delta.Y
        )
    end
end))

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -16, 0, 18)
hint.Position = UDim2.new(0, 8, 1, -22)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.fromRGB(150, 155, 172)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = "Tag: " .. tostring(Config.customTextTag) .. " | JSON: " .. ScriptCore.ConfigFile
hint.Parent = main

bindLoop("HintLoop", function()
    if hint then
        hint.Text = string.format("Tag: %s | Backpack: %d%% | Field: %s", tostring(Config.customTextTag), getBackpackPercent(), tostring(Config.field))
    end
end)

function ScriptCore.Shutdown()
    ScriptCore.Running = false

    for name in pairs(ScriptCore.Loops) do
        stopLoop(name)
    end

    for _, conn in ipairs(ScriptCore.Connections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end

    saveConfig()

    if gui and gui.Parent then
        gui:Destroy()
    end
end

getgenv().BSS_LOCAL_DELTA = ScriptCore

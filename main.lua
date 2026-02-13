--[[
  Safe Roblox helper UI template (Rayfield)
  -------------------------------------------------
  This script is intentionally written for legitimate use in your own place/test server.
  It does NOT use injector-only APIs, remote spying, or exploit-only hooks.
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("LocalPlayer not found")
    return
end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Root = Character:WaitForChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = Character:WaitForChild("Humanoid")
    Root = Character:WaitForChild("HumanoidRootPart")
end)

local settings = {
    selectedField = "",
    playerSpeed = 16,
    flyToField = true,
    autoFarm = false,
    autoDig = false,
    autoConvert = false,
    tokenRange = 90,
    walkRadius = 30,
}

local state = {
    currentFieldPart = nil,
}

local function getCharacterParts()
    if not Character or not Character.Parent then return nil, nil end
    return Character:FindFirstChildOfClass("Humanoid"), Character:FindFirstChild("HumanoidRootPart")
end

local function getFieldFolder()
    return workspace:FindFirstChild("Fields") or workspace:FindFirstChild("FlowerZones")
end

local function getFieldNames()
    local names = {}
    local folder = getFieldFolder()
    if not folder then return names end

    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            table.insert(names, obj.Name)
        end
    end
    table.sort(names)
    return names
end

local function resolveField(name)
    local folder = getFieldFolder()
    if not folder or name == "" then return nil end

    local obj = folder:FindFirstChild(name)
    if not obj then return nil end

    if obj:IsA("BasePart") then
        return obj
    elseif obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end

    return nil
end

local function moveToPoint(targetPos)
    local hum, root = getCharacterParts()
    if not hum or not root then return false end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
    })

    local ok = pcall(function()
        path:ComputeAsync(root.Position, targetPos)
    end)

    if ok and path.Status == Enum.PathStatus.Success then
        for _, waypoint in ipairs(path:GetWaypoints()) do
            hum:MoveTo(waypoint.Position)
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                hum.Jump = true
            end
            local reached = hum.MoveToFinished:Wait()
            if not reached then
                return false
            end
        end
        return true
    else
        hum:MoveTo(targetPos)
        return hum.MoveToFinished:Wait()
    end
end

local function getRandomPointOnField(fieldPart)
    if not fieldPart then return nil end
    local halfX = math.max(4, fieldPart.Size.X * 0.45)
    local halfZ = math.max(4, fieldPart.Size.Z * 0.45)

    local rx = (math.random() * 2 - 1) * math.min(halfX, settings.walkRadius)
    local rz = (math.random() * 2 - 1) * math.min(halfZ, settings.walkRadius)

    local pos = fieldPart.Position + Vector3.new(rx, 2.5, rz)
    return pos
end

local function findNearestToken(maxDistance)
    local _, root = getCharacterParts()
    if not root then return nil end

    local closest, closestDist
    local origin = root.Position

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "token") then
            local dist = (obj.Position - origin).Magnitude
            if dist <= maxDistance and (not closestDist or dist < closestDist) then
                closest = obj
                closestDist = dist
            end
        end
    end

    return closest
end

local function touchToken(token)
    local _, root = getCharacterParts()
    if not root or not token then return end

    moveToPoint(token.Position + Vector3.new(0, 2, 0))
end

local function getTool()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if Character then
        local equipped = Character:FindFirstChildWhichIsA("Tool")
        if equipped then return equipped end
    end
    if backpack then
        local tool = backpack:FindFirstChildWhichIsA("Tool")
        if tool then
            tool.Parent = Character
            return tool
        end
    end
    return nil
end

local function doDigStep()
    local tool = getTool()
    if not tool then return end

    pcall(function()
        tool:Activate()
    end)
end

local function findPlayerHive()
    local hives = workspace:FindFirstChild("Hives")
    if not hives then return nil end

    for _, hive in ipairs(hives:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and owner:IsA("ObjectValue") and owner.Value == LocalPlayer then
            return hive.PrimaryPart or hive:FindFirstChildWhichIsA("BasePart")
        end
    end

    return nil
end

local function convertAtHive()
    local hivePart = findPlayerHive()
    if not hivePart then return end

    local hum = getCharacterParts()
    if not hum then return end

    moveToPoint(hivePart.Position + Vector3.new(0, 2, 0))
    task.wait(1.5)
end

local function softFlyTo(position)
    local hum, root = getCharacterParts()
    if not hum or not root then return end

    if settings.flyToField then
        local start = root.Position
        local mid = (start + position) / 2 + Vector3.new(0, 40, 0)
        root.CFrame = CFrame.new(mid)
        task.wait(0.1)
        root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    else
        moveToPoint(position)
    end
end

local function applyWalkSpeed()
    local hum = getCharacterParts()
    if hum then
        hum.WalkSpeed = settings.playerSpeed
    end
end

RunService.Stepped:Connect(function()
    applyWalkSpeed()
end)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "BSS Helper (Safe Template)",
    LoadingTitle = "Helper UI",
    LoadingSubtitle = "Rayfield",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BSSHelper",
        FileName = "Config"
    },
    KeySystem = false,
})

local FarmTab = Window:CreateTab("Farm", 4483362458)
local MoveTab = Window:CreateTab("Movement", 4483362458)
local UtilTab = Window:CreateTab("Utilities", 4483362458)

local fieldOptions = getFieldNames()
if #fieldOptions > 0 then
    settings.selectedField = fieldOptions[1]
    state.currentFieldPart = resolveField(settings.selectedField)
end

FarmTab:CreateDropdown({
    Name = "Field",
    Options = fieldOptions,
    CurrentOption = settings.selectedField ~= "" and { settings.selectedField } or nil,
    Callback = function(option)
        local value = type(option) == "table" and option[1] or option
        settings.selectedField = value or ""
        state.currentFieldPart = resolveField(settings.selectedField)
    end,
})

FarmTab:CreateSlider({
    Name = "Token range",
    Range = {30, 200},
    Increment = 5,
    Suffix = "studs",
    CurrentValue = settings.tokenRange,
    Callback = function(v)
        settings.tokenRange = v
    end,
})

FarmTab:CreateSlider({
    Name = "Field walk radius",
    Range = {8, 80},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = settings.walkRadius,
    Callback = function(v)
        settings.walkRadius = v
    end,
})

FarmTab:CreateToggle({
    Name = "Auto dig",
    CurrentValue = false,
    Callback = function(v)
        settings.autoDig = v
    end,
})

FarmTab:CreateToggle({
    Name = "Auto convert (hive)",
    CurrentValue = false,
    Callback = function(v)
        settings.autoConvert = v
    end,
})

FarmTab:CreateToggle({
    Name = "Auto farm",
    CurrentValue = false,
    Callback = function(v)
        settings.autoFarm = v
        if v then
            task.spawn(function()
                while settings.autoFarm do
                    state.currentFieldPart = resolveField(settings.selectedField)
                    if state.currentFieldPart then
                        softFlyTo(state.currentFieldPart.Position)

                        for _ = 1, 8 do
                            if not settings.autoFarm then break end

                            local token = findNearestToken(settings.tokenRange)
                            if token then
                                touchToken(token)
                            else
                                local p = getRandomPointOnField(state.currentFieldPart)
                                if p then
                                    moveToPoint(p)
                                end
                            end

                            if settings.autoDig then
                                doDigStep()
                            end

                            task.wait(0.2)
                        end

                        if settings.autoConvert then
                            convertAtHive()
                        end
                    else
                        task.wait(0.75)
                    end
                end
            end)
        end
    end,
})

MoveTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 80},
    Increment = 1,
    CurrentValue = settings.playerSpeed,
    Callback = function(v)
        settings.playerSpeed = v
        applyWalkSpeed()
    end,
})

MoveTab:CreateToggle({
    Name = "Fly to field (only travel)",
    CurrentValue = settings.flyToField,
    Callback = function(v)
        settings.flyToField = v
    end,
})

UtilTab:CreateButton({
    Name = "Refresh fields",
    Callback = function()
        fieldOptions = getFieldNames()
        Rayfield:Notify({
            Title = "Fields refreshed",
            Content = "Found " .. tostring(#fieldOptions) .. " fields. Reopen UI to reload dropdown options.",
            Duration = 4,
        })
    end,
})

UtilTab:CreateParagraph({
    Title = "Notice",
    Content = "This template avoids injector-specific abuse and remote tampering. Use in your own game/test place.",
})

Rayfield:Notify({
    Title = "Loaded",
    Content = "Safe helper UI is ready.",
    Duration = 4,
})

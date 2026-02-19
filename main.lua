-- ICHIGER | BSS Macro
-- Hand-tuned build for Berg
local LIBRARY_URL = "https://raw.githubusercontent.com/bloodball/UI-Librarys/main/Elerium"

local function loadUiLibrary()
    local okFetch, source = pcall(function()
        return game:HttpGet(LIBRARY_URL)
    end)
    if not okFetch or type(source) ~= "string" or source == "" then
        return nil, "HttpGet failed"
    end

    local exampleMarker = string.find(source, "do -- Example UI", 1, true)
    if exampleMarker then
        source = string.sub(source, 1, exampleMarker - 1)
    end

    source = source .. "\nreturn library\n"

    local chunk, loadErr = loadstring(source)
    if type(chunk) ~= "function" then
        return nil, loadErr or "loadstring failed"
    end

    local okRun, library = pcall(chunk)
    if not okRun or type(library) ~= "table" then
        return nil, "library runtime failed"
    end

    return library
end

local Library, libraryError = loadUiLibrary()
if not Library then
    warn("[ICHIGER] UI load failed: " .. tostring(libraryError))
    return
end

do
    local eleriumLibrary = Library
    local compat = {}
    local liveWindows = {}
    local UserInputService = game:GetService("UserInputService")

    local function trimText(value)
        local s = tostring(value or "")
        s = s:gsub("^%s+", "")
        s = s:gsub("%s+$", "")
        return s
    end

    local function makeSectionApi(target)
        local section = {}

        function section:NewLabel(text)
            local labelObj = nil
            pcall(function()
                labelObj = target:AddLabel(tostring(text or ""))
            end)

            local handle = {}
            function handle:UpdateLabel(newText)
                if labelObj then
                    pcall(function()
                        labelObj.Text = tostring(newText or "")
                    end)
                end
            end
            return handle
        end

        function section:NewButton(text, _, callback)
            pcall(function()
                target:AddButton(tostring(text or "Button"), function()
                    if type(callback) == "function" then
                        pcall(callback)
                    end
                end)
            end)
        end

        function section:NewToggle(text, _, callback)
            local switchData = nil
            pcall(function()
                switchData = target:AddSwitch(tostring(text or "Toggle"), function(state)
                    if type(callback) == "function" then
                        pcall(callback, state)
                    end
                end)
            end)
            return switchData
        end

        function section:NewSlider(text, _, maxValue, minValue, callback)
            local sliderData = nil
            local minV = tonumber(minValue) or 0
            local maxV = tonumber(maxValue) or 100
            if maxV < minV then
                minV, maxV = maxV, minV
            end

            local ignoreFirst = true
            pcall(function()
                sliderData = target:AddSlider(tostring(text or "Slider"), function(value)
                    if ignoreFirst then
                        ignoreFirst = false
                        return
                    end
                    if type(callback) == "function" then
                        pcall(callback, value)
                    end
                end, {
                    min = minV,
                    max = maxV,
                    readonly = false,
                })
            end)
            return sliderData
        end

        function section:NewDropdown(text, _, options, callback)
            local dropdownData = nil
            pcall(function()
                dropdownData = target:AddDropdown(tostring(text or "Dropdown"), function(object)
                    local value = object
                    if typeof(object) == "Instance" and object:IsA("TextButton") then
                        value = trimText(object.Text)
                    end
                    if type(callback) == "function" then
                        pcall(callback, value)
                    end
                end)
            end)

            if dropdownData and type(options) == "table" then
                for _, opt in ipairs(options) do
                    pcall(function()
                        dropdownData:Add(tostring(opt))
                    end)
                end
            end

            return dropdownData
        end

        function section:NewTextBox(text, _, callback)
            local textBoxObj = nil
            pcall(function()
                textBoxObj = target:AddTextBox(tostring(text or "TextBox"), function(value)
                    if type(callback) == "function" then
                        pcall(callback, value)
                    end
                end, {
                    clear = false,
                })
            end)
            return textBoxObj
        end

        function section:NewColorPicker(text, _, defaultColor, callback)
            pcall(function()
                target:AddLabel(tostring(text or "Color"))
            end)

            local colorData = nil
            pcall(function()
                colorData = target:AddColorPicker(function(color)
                    if type(callback) == "function" then
                        pcall(callback, color)
                    end
                end)
            end)

            if colorData and colorData.Set and typeof(defaultColor) == "Color3" then
                pcall(function()
                    colorData:Set(defaultColor)
                end)
            end
            return colorData
        end

        function section:NewKeybind(text, _, defaultKey, callback)
            local keybindData = nil
            local standardKey = (typeof(defaultKey) == "EnumItem" and defaultKey) or Enum.KeyCode.RightControl
            pcall(function()
                keybindData = target:AddKeybind(tostring(text or "Keybind"), function(key)
                    if type(callback) == "function" then
                        pcall(callback, key)
                    end
                end, {
                    standard = standardKey,
                })
            end)
            return keybindData
        end

        return section
    end

    local function isPointInFrame(point, frame)
        if not frame then
            return false
        end
        local p = frame.AbsolutePosition
        local s = frame.AbsoluteSize
        return point.X >= p.X and point.X <= (p.X + s.X) and point.Y >= p.Y and point.Y <= (p.Y + s.Y)
    end

    local function applyLeftTabLayout(windowFrame)
        if not windowFrame or not windowFrame.Parent then
            return
        end

        local tabSelection = windowFrame:FindFirstChild("TabSelection")
        local tabs = windowFrame:FindFirstChild("Tabs")
        if not tabSelection or not tabs then
            return
        end

        pcall(function()
            tabSelection.Position = UDim2.new(0, 15, 0, 30)
            tabSelection.Size = UDim2.new(0, 170, 1, -45)
        end)

        local tabButtons = tabSelection:FindFirstChild("TabButtons")
        if tabButtons then
            pcall(function()
                tabButtons.Position = UDim2.new(0, 4, 0, 4)
                tabButtons.Size = UDim2.new(1, -8, 1, -8)
            end)

            local list = tabButtons:FindFirstChildOfClass("UIListLayout")
            if list then
                pcall(function()
                    list.FillDirection = Enum.FillDirection.Vertical
                    list.Padding = UDim.new(0, 4)
                end)
            end
        end

        local splitLine = tabSelection:FindFirstChild("Frame")
        if splitLine then
            pcall(function()
                splitLine.Position = UDim2.new(1, 0, 0, 0)
                splitLine.Size = UDim2.new(0, 2, 1, 0)
            end)
        end

        pcall(function()
            tabs.Position = UDim2.new(0, 195, 0, 30)
            tabs.Size = UDim2.new(1, -210, 1, -40)
            tabs.ClipsDescendants = true
        end)
    end

    local function attachTabScroll(windowFrame, tabFrame)
        if not windowFrame or not tabFrame or not tabFrame.Parent then
            return
        end

        local tabsHost = windowFrame:FindFirstChild("Tabs")
        local layout = tabFrame:FindFirstChildOfClass("UIListLayout")
        if not tabsHost or not layout then
            return
        end

        local scrollY = 0

        local function maxScroll()
            local contentHeight = layout.AbsoluteContentSize.Y
            local viewHeight = tabsHost.AbsoluteSize.Y
            return math.max(0, contentHeight - viewHeight + 8)
        end

        local function applyScroll()
            if not tabFrame or not tabFrame.Parent then
                return
            end
            local limit = maxScroll()
            scrollY = math.clamp(scrollY, 0, limit)
            tabFrame.Position = UDim2.new(0, 0, 0, -math.floor(scrollY + 0.5))
        end

        pcall(function()
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                task.defer(applyScroll)
            end)
        end)
        pcall(function()
            tabsHost:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                task.defer(applyScroll)
            end)
        end)

        UserInputService.InputChanged:Connect(function(input, gameProcessed)
            if gameProcessed or not tabFrame.Visible then
                return
            end
            if input.UserInputType ~= Enum.UserInputType.MouseWheel then
                return
            end
            if not isPointInFrame(UserInputService:GetMouseLocation(), tabsHost) then
                return
            end

            scrollY = scrollY - (input.Position.Z * 34)
            applyScroll()
        end)

        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or UserInputService:GetFocusedTextBox() or not tabFrame.Visible then
                return
            end
            if not isPointInFrame(UserInputService:GetMouseLocation(), tabsHost) then
                return
            end

            if input.KeyCode == Enum.KeyCode.Up then
                scrollY = scrollY - 36
                applyScroll()
            elseif input.KeyCode == Enum.KeyCode.Down then
                scrollY = scrollY + 36
                applyScroll()
            elseif input.KeyCode == Enum.KeyCode.PageUp then
                scrollY = scrollY - 140
                applyScroll()
            elseif input.KeyCode == Enum.KeyCode.PageDown then
                scrollY = scrollY + 140
                applyScroll()
            end
        end)

        applyScroll()
    end

    function compat.CreateLib(title, theme)
        local options = {
            main_color = (theme and theme.SchemeColor) or Color3.fromRGB(41, 74, 122),
            min_size = Vector2.new(560, 460),
            toggle_key = Enum.KeyCode.RightControl,
            can_resize = true,
        }

        local windowData, windowObject = eleriumLibrary:AddWindow(tostring(title or "Window"), options)
        local state = {
            options = options,
            object = windowObject,
            firstTabShown = false,
        }
        table.insert(liveWindows, state)
        applyLeftTabLayout(windowObject)

        local window = {}
        function window:NewTab(tabName)
            local tabData = nil
            local tabObject = nil
            pcall(function()
                tabData, tabObject = windowData:AddTab(tostring(tabName or "Tab"))
            end)
            applyLeftTabLayout(state.object)
            if tabObject then
                attachTabScroll(state.object, tabObject)
            end

            if tabData and tabData.Show and not state.firstTabShown then
                pcall(function()
                    tabData:Show()
                end)
                state.firstTabShown = true
            end

            local tab = {}
            function tab:NewSection(sectionName)
                if tabData and tabData.AddLabel then
                    pcall(function()
                        tabData:AddLabel("[" .. tostring(sectionName or "Section") .. "]")
                    end)
                end
                return makeSectionApi(tabData)
            end

            return tab
        end

        return window
    end

    function compat:ChangeColor(themeKey, color)
        local key = tostring(themeKey or "")
        if key ~= "SchemeColor" or typeof(color) ~= "Color3" then
            return
        end
        for _, state in ipairs(liveWindows) do
            state.options.main_color = color
        end
    end

    function compat:ToggleUI()
        local coreGui = game:GetService("CoreGui")
        local gui = coreGui:FindFirstChild("imgui")
        if gui and gui:IsA("ScreenGui") then
            gui.Enabled = not gui.Enabled
        end
    end

    Library = compat
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

math.randomseed(tick())

local LocalPlayer = Players.LocalPlayer

local FIELDS = {
    "Sunflower Field", "Dandelion Field", "Mushroom Field", "Blue Flower Field", "Clover Field",
    "Spider Field", "Strawberry Field", "Bamboo Field", "Pineapple Patch", "Pumpkin Patch",
    "Cactus Field", "Rose Field", "Pine Tree Forest", "Stump Field", "Coconut Field",
    "Mountain Top Field", "Pepper Patch",
}

local TOYS = {
    { key = "HoneyDispenser", label = "Honey Dispenser", aliases = { "honeydispenser", "honey dispenser" } },
    { key = "BlueberryDispenser", label = "Blueberry Dispenser", aliases = { "blueberrydispenser", "blueberry dispenser" } },
    { key = "StrawberryDispenser", label = "Strawberry Dispenser", aliases = { "strawberrydispenser", "strawberry dispenser" } },
    { key = "TreatDispenser", label = "Treat Dispenser", aliases = { "treatdispenser", "treat dispenser" } },
    { key = "RoyalJellyDispenser", label = "Royal Jelly Dispenser", aliases = { "royaljellydispenser", "royal jelly dispenser" } },
    { key = "GlueDispenser", label = "Glue Dispenser", aliases = { "gluedispenser", "glue dispenser" } },
    { key = "CoconutDispenser", label = "Coconut Dispenser", aliases = { "coconutdispenser", "coconut dispenser" } },
    { key = "WealthClock", label = "Wealth Clock", aliases = { "wealthclock", "wealth clock" } },
    { key = "BlueBooster", label = "Blue Field Booster", aliases = { "bluefieldbooster", "blue field booster", "blue booster" } },
    { key = "RedBooster", label = "Red Field Booster", aliases = { "redfieldbooster", "red field booster", "red booster" } },
    { key = "MountainBooster", label = "Mountain Top Booster", aliases = { "mountaintopfieldbooster", "mountain top booster", "mountain booster" } },
}

local TOY_NAMES = {}
for _, toy in ipairs(TOYS) do
    table.insert(TOY_NAMES, toy.label)
end

FACE_METHODS = { "BodyGyro", "Shift Lock" }
SHIFT_DIRECTIONS = { "North", "South", "East", "West" }
FIELD_POSITIONS = { "Center", "North", "South", "East", "West" }
INSTANT_CONVERT_TYPES = { "Remote", "Tap", "Prompt" }
MOVEMENT_METHODS = { "Tween", "WalkTo", "Hybrid" }
SPRINKLER_TYPES = { "The Supreme Saturator", "Saturator", "Golden Gushers", "Silver Soakers", "Basic Sprinkler" }
DIG_METHODS = { "Remote", "ActivateTool", "Both" }
PLANTER_FIELDS = FIELDS
MASK_NAMES = {
    "None",
    "Gummy Mask",
    "Honey Mask",
    "Demon Mask",
    "Bubble Mask",
}
RARES_LIST = { "None", "Mythic Meteors", "Precise Mark", "Guiding Star", "Sparkles" }
CONFIG_PROFILE_PRESETS = { "main", "preset1", "preset2", "preset3", "alt" }
MATERIALS = {
    { key = "Enzymes", label = "Enzymes", aliases = { "enzyme", "enzymes" } },
    { key = "Oil", label = "Oil", aliases = { "oil" } },
    { key = "Glitter", label = "Glitter", aliases = { "glitter" } },
    { key = "Gumdrops", label = "Gumdrops", aliases = { "gumdrop", "gumdrops" } },
    { key = "TropicalDrink", label = "Tropical Drink", aliases = { "tropicaldrink", "tropical drink" } },
    { key = "BlueExtract", label = "Blue Extract", aliases = { "blueextract", "blue extract" } },
    { key = "RedExtract", label = "Red Extract", aliases = { "redextract", "red extract" } },
    { key = "PurplePotion", label = "Purple Potion", aliases = { "purplepotion", "purple potion" } },
}

ATLAS_TOY_CATEGORY_ALIASES = {
    AutoToyBoosters = { "booster", "fieldbooster" },
    AutoToyDispensers = { "dispenser", "honeydispenser", "blueberrydispenser", "strawberrydispenser" },
    AutoToyMemoryMatch = { "memorymatch", "memory", "match" },
    AutoToyWindShrine = { "windshrine", "shrine", "donate" },
    AutoToyMaterials = { "enzyme", "oil", "glitter", "gumdrop" },
    AutoToyStickers = { "sticker" },
    AutoToyProgression = { "stump", "tunnel", "mondo", "quest" },
    AutoToyBeesmas = { "beesmas", "giftbox", "samovar", "candles" },
    AutoToyGummyBeacon = { "gummybeacon", "beacon", "gummy" },
    AutoToyMisc = { "clock", "wealth", "treatdispenser", "royaljellydispenser" },
    AutoToyDapperBearShop = { "dapper", "bearshop", "dappershop" },
    AutoToyNectarCondenser = { "nectar", "condenser" },
    AutoMoonAmulet = { "moonamulet", "moon" },
    AutoStarAmulet = { "staramulet", "starhall" },
    AutoHiveTasks = { "hive", "convert", "balloon" },
}

local DEFAULT = {
    AutoFarm = false,
    FieldName = "Sunflower Field",
    ReturnToHive = true,
    HiveBagPercent = 95,
    HiveWaitSeconds = 15,

    CollectAllTokens = true,
    TokenHoney = true,
    TokenPollen = true,
    TokenBoost = true,
    TokenAbility = true,
    TokenTicket = true,
    TokenTreat = true,
    TokenPrecise = true,
    TokenMarks = true,
    TokenPopStar = true,
    TokenLink = true,
    TokenBomb = true,
    TokenBubble = true,
    TokenFlame = true,

    PlayerSpeed = 70,
    TweenSpeed = 80,
    TweenSoftness = 70,
    EnableWalkSpeed = true,

    AutoUseToys = false,
    ToyLoopDelay = 120,
    ToyTweenToTarget = true,
    SelectedToy = TOY_NAMES[1],
    AutoUseMaterials = false,
    MaterialsLoopDelay = 120,
    Material_Enzymes = false,
    Material_Oil = false,
    Material_Glitter = false,
    Material_Gumdrops = false,
    Material_TropicalDrink = false,
    Material_BlueExtract = false,
    Material_RedExtract = false,
    Material_PurplePotion = false,

    AntiLagEnabled = false,
    AntiLagParticles = true,
    AntiLagTextures = true,
    AntiLagShadows = true,
    AntiLagLighting = true,
    AntiLagRefreshSeconds = 4,

    ConfigAutoSave = true,
    ConfigAutoSaveDelay = 10,
    ConfigAutoLoad = true,
    ConfigSaveBackup = true,
    ConfigOnlyIfChanged = true,
    ConfigProfile = "main",

    ScriptStopped = false,
    AutoSprinkler = false,
    AutoDig = false,
    SprinklerInterval = 12,

    AutoPopStar = false,
    AutoScorchingStar = false,
    AutoGummyStar = false,
    FarmBubbles = true,
    FarmCoconuts = false,
    FarmComboCoconuts = false,
    ChangeFieldDuringCombo = false,
    FarmDupedTokens = true,
    FarmMeteorShowers = true,
    FarmFire = true,
    FarmFireflies = true,
    FarmFuzzBombs = true,
    FarmLeaves = true,
    FarmPuppyBall = true,
    FarmShower = true,
    FarmTriangulate = true,
    FarmUnderClouds = true,
    FarmUnderBalloons = true,
    IgnoreHoneyTokens = false,
    FarmNearPosition = false,
    FieldPosition = "Center",
    FaceMethod = "BodyGyro",
    ShiftLockDirection = "North",
    FaceCenter = true,
    FaceBubbles = true,
    FaceFires = true,
    FarmWithShiftLock = false,

    ConvertBalloonAtMinutes = 15,
    WaitBeforeConverting = 2,
    StandInPreciseCrosshair = false,
    StandInPreciseCrosshairAt = 80,
    UseCoconutToConvert = false,
    UseCoconutAtPercentage = 92,
    InstantConvert = false,
    InstantConvertType = "Remote",
    AutoHoneyMaskForBalloon = false,
    DefaultMask = "Gummy Mask",
    CollectFestiveBlessing = true,
    ConvertOnlyWhenInField = false,
    ConvertBalloonWhenBagFull = false,
    ConvertBalloonWhenBagFullBubble = false,
    UseEnzymesForConvertingBalloon = false,
    ResetWhenConverting = false,

    EnableCombat = false,
    CombatRadius = 220,
    AutoDemonMask = false,
    AutoStingers = false,
    AutoStarSaw = false,
    AutoAvoidMobs = false,
    AutoKillAphid = false,
    AutoKillLadybug = false,
    AutoKillRhinoBeetle = false,
    AutoKillSpider = false,
    AutoKillMantis = false,
    AutoKillScorpion = false,
    AutoKillWerewolf = false,
    AutoKillTunnelBear = false,
    AutoKillKingBeetle = false,
    AutoKillCoconutCrab = false,
    AutoKillMondoChick = false,
    AutoKillCommando = false,
    AutoKillViciousBee = false,
    GiftedViciousOnly = false,
    ViciousMinLevel = 1,
    ViciousMaxLevel = 20,
    AutoKillWindyBee = false,
    WindyMinLevel = 1,
    WindyMaxLevel = 20,

    AutoQuest = false,
    AutoClaimQuests = true,
    AutoQuestBlackBear = false,
    AutoQuestMotherBear = false,
    AutoQuestPandaBear = false,
    AutoQuestScienceBear = false,
    AutoQuestDapperBear = false,
    AutoQuestOnett = false,
    AutoQuestSpiritBear = false,
    AutoQuestBrownBearRepeat = false,
    AutoQuestBuckoRepeat = false,
    AutoQuestRileyRepeat = false,
    AutoQuestHoneyBeeRepeat = false,
    AutoQuestPolarBearRepeat = false,
    QuestFarmPollen = true,
    QuestFarmGoo = true,
    QuestFarmMobs = true,
    QuestFarmAnts = false,
    QuestFarmRageTokens = true,
    QuestFarmPuffshrooms = false,
    QuestDoDupedTokens = true,
    QuestDoWindShrine = false,
    QuestDoMemoryMatch = false,
    QuestShareJellyBeans = false,
    QuestCraftItems = false,
    QuestUseToys = true,
    FeedBees = false,
    LevelUpBees = false,
    PurchaseTreatsToLevelUp = false,
    UseRoyalJelly = false,

    AllowGatherInterrupt = true,
    AutoToyBoosters = false,
    AutoToyDispensers = false,
    AutoToyMemoryMatch = false,
    AutoToyWindShrine = false,
    AutoToyMaterials = false,
    AutoToyStickers = false,
    AutoToyProgression = false,
    AutoToyBeesmas = false,
    AutoToyGummyBeacon = false,
    AutoToyMisc = false,
    AutoToyDapperBearShop = false,
    AutoToyNectarCondenser = false,
    AutoMoonAmulet = false,
    AutoStarAmulet = false,
    AutoHiveTasks = false,

    EnablePlanters = false,
    PlanterAutoPlant = false,
    PlanterAutoHarvest = true,
    PlanterDuringDayOnly = false,
    PlanterDuringNightOnly = false,
    PlanterAllowedField = "Sunflower Field",
    PlanterLoopDelay = 60,
    PlanterTriggerFallback = true,

    EnableRBC = false,
    RBCAutoStart = true,
    RBCAutoBuyPass = false,
    RBCAutoCollectLoot = true,
    RBCTweenCircle = false,
    RBCAutoSpawn = false,
    RBCUseTickets = false,
    RBCLoopDelay = 8,

    EnableWebhook = false,
    WebhookUrl = "",
    WebhookIntervalMinutes = 5,
    WebhookSendBalloonPollen = true,
    WebhookSendNectars = true,
    WebhookSendPlanters = true,
    WebhookSendItems = true,
    WebhookSendConsole = false,
    WebhookSendStickers = false,
    WebhookSendBeequips = false,
    WebhookSendQuestDone = false,
    WebhookSendDigitalBeeDrives = false,
    WebhookSendDapperBearShop = false,
    WebhookSendDisconnect = true,
    GraphEnabled = false,
    GraphUseBranding = false,
    GraphWebhookUrl = "",
    DashboardEnabled = false,

    UseRemotes = true,
    MovementMethod = "Tween",
    SprinklerType = "The Supreme Saturator",
    AutoDigMethod = "Remote",
    DynamicWalkSpeed = false,
    AutoloadForUsername = "",

    AnonymousMode = false,
    FarmMultipleFields = false,
    MobileToggleButton = true,
    ShowAtlasConsole = true,
    AutoRejoin = false,
    RunWithoutAutofarm = false,
    FastShowerTween = false,
    FastCoconutTween = false,
    FastTweenToRares = false,
    RaresList = "None",
    HideTokens = true,
    HidePreciseTargets = true,
    HideDupedTokens = true,
    HideMarks = true,
    HideBees = false,
    HideFlowers = false,
    DestroyBalloons = false,
    DestroyDecorations = false,
    Disable3DRendering = false,
    HideOtherPlayers = false,
    HideBssUI = false,
    AutoRejoinDelay = 6,

    NoSafeMode = true,
}

local Settings = getgenv().ICHIGERSettings or getgenv().IchigisssSettings or getgenv().BergBSSSettings or {}
for k, v in pairs(DEFAULT) do
    if Settings[k] == nil then
        Settings[k] = v
    end
end
for _, toy in ipairs(TOYS) do
    local key = "Toy_" .. toy.key
    if Settings[key] == nil then
        Settings[key] = false
    end
end
for _, material in ipairs(MATERIALS) do
    local key = "Material_" .. material.key
    if Settings[key] == nil then
        Settings[key] = false
    end
end
getgenv().ICHIGERSettings = Settings
getgenv().IchigisssSettings = Settings

local UITheme = {
    SchemeColor = Color3.fromRGB(166, 73, 255),
    Background = Color3.fromRGB(8, 8, 8),
    Header = Color3.fromRGB(0, 0, 0),
    TextColor = Color3.fromRGB(235, 235, 235),
    ElementColor = Color3.fromRGB(0, 0, 0),
}

local TOKEN_PATTERNS = {
    Honey = { "honey" },
    Pollen = { "pollen" },
    Boost = { "boost", "focus", "haste", "melody" },
    Ability = { "ability", "token", "rage", "stinger" },
    Ticket = { "ticket" },
    Treat = { "treat" },
    Precise = { "precise", "precision" },
    Marks = { "mark", "target" },
    PopStar = { "popstar", "pop star", "guiding star", "starsaw", "star saw", "star" },
    Link = { "link" },
    Bomb = { "bomb" },
    Bubble = { "bubble" },
    Flame = { "flame" },
}

local EFFECT_CLASSES = {
    ParticleEmitter = true,
    Trail = true,
    Beam = true,
    Smoke = true,
    Fire = true,
    Sparkles = true,
}

local HIVE_PART_HINTS = { "spawn", "platform", "pad", "circle", "base", "convert", "hive" }
local CONFIG_FOLDER_NAME = "ICHIGERConfigs"
local CONFIG_PLACE_BASENAME = tostring(LocalPlayer.UserId) .. "_" .. tostring(game.PlaceId)
local CONFIG_UNIVERSE_BASENAME = tostring(LocalPlayer.UserId) .. "_u" .. tostring(game.GameId)
local CONFIG_PRIMARY_BASENAME = CONFIG_UNIVERSE_BASENAME ~= "" and CONFIG_UNIVERSE_BASENAME or CONFIG_PLACE_BASENAME
local CONFIG_LEGACY_PATHS = {
    CONFIG_FOLDER_NAME .. "/" .. CONFIG_PRIMARY_BASENAME .. ".json",
}
if CONFIG_PLACE_BASENAME ~= CONFIG_PRIMARY_BASENAME then
    table.insert(CONFIG_LEGACY_PATHS, CONFIG_FOLDER_NAME .. "/" .. CONFIG_PLACE_BASENAME .. ".json")
end
local CONFIG_META_PATHS = {
    CONFIG_FOLDER_NAME .. "/meta_" .. CONFIG_PRIMARY_BASENAME .. ".json",
}
if CONFIG_PLACE_BASENAME ~= CONFIG_PRIMARY_BASENAME then
    table.insert(CONFIG_META_PATHS, CONFIG_FOLDER_NAME .. "/meta_" .. CONFIG_PLACE_BASENAME .. ".json")
end
local FIELD_FALLBACK_SIZE = Vector3.new(72, 20, 72)
local SAFE_HIVE_ACTION_INTERVAL = 0.45
local AGGRESSIVE_HIVE_ACTION_INTERVAL = 0.06

local currentTween = nil
local farmLoopRunning = false
local toyLoopRunning = false
local antiLagLoopRunning = false
local combatLoopRunning = false
local questLoopRunning = false
local supportLoopRunning = false
local planterLoopRunning = false
local webhookLoopRunning = false

local setToyStatus
local setCombatStatus
local setQuestStatus
local setPlanterStatus
local setWebhookStatus
local setConfigStatus
local setDebugStatus

local fieldCache = {}
local toyCache = {}
local toyUseTracker = {}
local atlasToyTracker = {}
local materialUseTracker = {}
local antiLagBackups = setmetatable({}, { __mode = "k" })
antiLagConnections = {}
antiLagDirty = false
antiLagOneTimeApplied = false
local convertRemoteCache = nil
local remoteAliasCache = {}
local configWriteCache = {}
local lastSprinklerUse = 0
local lastWebhookSend = 0
tokenNearestCache = {
    at = 0,
    field = nil,
    pos = nil,
    rootPos = nil,
}
TOKEN_NEAREST_CACHE_WINDOW = 0.05
local VirtualInputManager = nil
local VirtualUser = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)
pcall(function()
    VirtualUser = game:GetService("VirtualUser")
end)

triggerFromInstance = nil
useMaterialOnce = nil
tryPlanterAction = nil
materialSettingKey = nil

local function normalizeText(value)
    local s = string.lower(tostring(value or ""))
    s = s:gsub("[%s_%-%.%[%]%(%)]+", "")
    s = s:gsub("[^%w]", "")
    return s
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootAndHumanoid()
    local character = getCharacter()
    if not character then
        return nil, nil
    end
    return character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

local function getPart(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
    end
    if instance:IsA("Attachment") and instance.Parent and instance.Parent:IsA("BasePart") then
        return instance.Parent
    end
    return nil
end

local function getCFrame(instance)
    local part = getPart(instance)
    if part then
        return part.CFrame
    end
    return nil
end

local function applyWalkSpeed()
    local _, humanoid = getRootAndHumanoid()
    if humanoid then
        if not Settings.EnableWalkSpeed then
            humanoid.WalkSpeed = 16
            return
        end
        local targetSpeed = math.clamp(Settings.PlayerSpeed, 40, 120)
        if Settings.DynamicWalkSpeed then
            local bag = 0
            local stats = LocalPlayer:FindFirstChild("CoreStats")
            if stats then
                local pollen = stats:FindFirstChild("Pollen")
                local capacity = stats:FindFirstChild("Capacity")
                if pollen and capacity and capacity.Value > 0 then
                    bag = (pollen.Value / capacity.Value) * 100
                end
            end
            if bag >= 95 then
                targetSpeed = math.clamp(targetSpeed + 12, 40, 120)
            elseif bag <= 30 then
                targetSpeed = math.clamp(targetSpeed - 8, 40, 120)
            end
        end
        humanoid.WalkSpeed = targetSpeed
    end
end

local function stopTween()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

local function stopWalk()
    local root, humanoid = getRootAndHumanoid()
    if root and humanoid then
        humanoid:MoveTo(root.Position)
    end
end

local function stopMovement()
    stopTween()
    stopWalk()
end

local function walkTo(targetPos, stopDistance, timeout, cancelFn)
    local root, humanoid = getRootAndHumanoid()
    if not root or not humanoid then
        return false
    end

    stopDistance = stopDistance or 5
    timeout = timeout or 3

    local timeoutAt = os.clock() + timeout
    local lastMove = 0
    while os.clock() < timeoutAt do
        if cancelFn and cancelFn() then
            return false
        end

        if os.clock() - lastMove >= 0.7 then
            humanoid:MoveTo(targetPos)
            lastMove = os.clock()
        end

        if (root.Position - targetPos).Magnitude <= stopDistance then
            return true
        end
        task.wait(0.05)
    end

    return false
end

local function moveToPosition(targetPos, stopDistance, timeout, cancelFn)
    local method = tostring(Settings.MovementMethod or "Tween")
    if method == "WalkTo" then
        return walkTo(targetPos, stopDistance, timeout, cancelFn)
    end

    local function tweenMove()
        local root = select(1, getRootAndHumanoid())
        if not root then
            return false
        end
        local y = root.Position.Y
        local finalPos = Vector3.new(targetPos.X, y, targetPos.Z)
        local dist = (root.Position - finalPos).Magnitude
        local tweenSpeed = math.clamp(tonumber(Settings.TweenSpeed) or 80, 40, 120)
        local duration = math.clamp(dist / tweenSpeed, 0.08, 8)
        stopTween()
        local rotationOnly = root.CFrame - root.Position
        local tweenGoal = CFrame.new(finalPos) * rotationOnly
        local tween = TweenService:Create(
            root,
            TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            { CFrame = tweenGoal }
        )
        currentTween = tween
        tween:Play()
        while tween.PlaybackState == Enum.PlaybackState.Playing do
            if cancelFn and cancelFn() then
                tween:Cancel()
                if currentTween == tween then
                    currentTween = nil
                end
                return false
            end
            task.wait(0.03)
        end
        if currentTween == tween then
            currentTween = nil
        end
        return true
    end

    if method == "Tween" then
        return tweenMove()
    end

    local walked = walkTo(targetPos, stopDistance, timeout, cancelFn)
    if walked then
        return true
    end
    return tweenMove()
end

local function moveToToken(targetPos, cancelFn)
    local root = select(1, getRootAndHumanoid())
    if not root then
        return false
    end

    local y = root.Position.Y
    local finalPos = Vector3.new(targetPos.X, y, targetPos.Z)
    local dist = (root.Position - finalPos).Magnitude
    if dist <= 2.2 then
        return true
    end

    local method = tostring(Settings.MovementMethod or "Tween")
    if method == "WalkTo" then
        return walkTo(finalPos, 2.6, 0.8, cancelFn)
    end

    local chaseSpeed = math.clamp((tonumber(Settings.TweenSpeed) or 80) * 1.55, 70, 180)
    local duration = math.clamp(dist / chaseSpeed, 0.04, 0.42)

    stopTween()
    local rotationOnly = root.CFrame - root.Position
    local tweenGoal = CFrame.new(finalPos) * rotationOnly
    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = tweenGoal }
    )
    currentTween = tween
    tween:Play()

    while tween.PlaybackState == Enum.PlaybackState.Playing do
        if cancelFn and cancelFn() then
            tween:Cancel()
            if currentTween == tween then
                currentTween = nil
            end
            return false
        end
        task.wait(0.02)
    end

    if currentTween == tween then
        currentTween = nil
    end
    return true
end

local function getActiveTweenSpeed()
    return math.clamp(Settings.TweenSpeed, 40, 120)
end

local function tweenTo(targetCFrame, speed)
    local root = select(1, getRootAndHumanoid())
    if not root then
        return
    end

    local targetPos = targetCFrame.Position
    local dist = (root.Position - targetPos).Magnitude
    local tweenSpeed = math.clamp(speed, 40, 120)
    local softness = math.clamp(tonumber(Settings.TweenSoftness) or 70, 0, 100)
    local duration = (dist / tweenSpeed) * (1 + softness / 180)
    duration = math.clamp(duration, 0.08, 10)
    local rotationOnly = root.CFrame - root.Position
    local tweenGoal = CFrame.new(targetPos) * rotationOnly

    if duration <= 0.06 then
        root.CFrame = tweenGoal
        return
    end

    stopTween()
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(root, tweenInfo, { CFrame = tweenGoal })
    currentTween = tween
    tween:Play()
    tween.Completed:Wait()
    if currentTween == tween then
        currentTween = nil
    end
end

local function findFieldInstance(fieldName)
    local cached = fieldCache[fieldName]
    if cached and cached.Parent then
        return cached
    end

    for _, containerName in ipairs({ "FlowerZones", "Flowers", "Fields" }) do
        local container = workspace:FindFirstChild(containerName)
        if container then
            for _, item in ipairs(container:GetDescendants()) do
                if item.Name == fieldName then
                    fieldCache[fieldName] = item
                    return item
                end
            end
        end
    end

    local fallback = workspace:FindFirstChild(fieldName, true)
    if fallback then
        fieldCache[fieldName] = fallback
        return fallback
    end

    return nil
end

local function getFieldData(fieldName)
    local instance = findFieldInstance(fieldName)
    if not instance then
        return nil, nil
    end

    local part = getPart(instance)
    if part then
        return part.CFrame, part.Size
    end

    local cf = getCFrame(instance)
    if cf then
        return cf, FIELD_FALLBACK_SIZE
    end

    return nil, nil
end

local function getFieldCFrame(fieldName)
    local cf = getFieldData(fieldName)
    return cf
end

local function isPositionInsideField(position, fieldName, margin)
    local fieldCFrame, fieldSize = getFieldData(fieldName)
    if not fieldCFrame or not fieldSize then
        return false
    end

    margin = margin or 4
    local localPos = fieldCFrame:PointToObjectSpace(position)
    local halfX = (fieldSize.X * 0.5) + margin
    local halfZ = (fieldSize.Z * 0.5) + margin
    return math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ
end

local function getRandomPointInField(fieldName)
    local fieldCFrame, fieldSize = getFieldData(fieldName)
    if not fieldCFrame or not fieldSize then
        return nil
    end

    local xRadius = math.max(4, math.floor((fieldSize.X * 0.5) - 4))
    local zRadius = math.max(4, math.floor((fieldSize.Z * 0.5) - 4))
    local x = math.random(-xRadius, xRadius)
    local z = math.random(-zRadius, zRadius)

    local biasX, biasZ = 0, 0
    if Settings.FieldPosition == "North" then
        biasZ = -math.floor(zRadius * 0.65)
    elseif Settings.FieldPosition == "South" then
        biasZ = math.floor(zRadius * 0.65)
    elseif Settings.FieldPosition == "East" then
        biasX = math.floor(xRadius * 0.65)
    elseif Settings.FieldPosition == "West" then
        biasX = -math.floor(xRadius * 0.65)
    end

    x = math.clamp(math.floor((x * 0.35) + biasX), -xRadius, xRadius)
    z = math.clamp(math.floor((z * 0.35) + biasZ), -zRadius, zRadius)
    local point = (fieldCFrame * CFrame.new(x, 0, z)).Position

    local root = select(1, getRootAndHumanoid())
    if root then
        point = Vector3.new(point.X, root.Position.Y, point.Z)
    end
    return point
end

local function getCollectiblesFolder()
    return workspace:FindFirstChild("Collectibles")
        or workspace:FindFirstChild("Particles")
        or workspace:FindFirstChild("Tokens")
end

local function tokenMatches(tokenName, patterns)
    local normalizedName = normalizeText(tokenName)
    for _, pattern in ipairs(patterns) do
        local normalizedPattern = normalizeText(pattern)
        if normalizedPattern ~= "" and string.find(normalizedName, normalizedPattern, 1, true) then
            return true
        end
    end
    return false
end

local function isTokenAllowed(tokenName)
    if Settings.CollectAllTokens then
        if Settings.IgnoreHoneyTokens and tokenMatches(tokenName, TOKEN_PATTERNS.Honey) then
            return false
        end
        return true
    end

    if Settings.IgnoreHoneyTokens and tokenMatches(tokenName, TOKEN_PATTERNS.Honey) then
        return false
    end

    if Settings.TokenHoney and tokenMatches(tokenName, TOKEN_PATTERNS.Honey) then return true end
    if Settings.TokenPollen and tokenMatches(tokenName, TOKEN_PATTERNS.Pollen) then return true end
    if Settings.TokenBoost and tokenMatches(tokenName, TOKEN_PATTERNS.Boost) then return true end
    if Settings.TokenAbility and tokenMatches(tokenName, TOKEN_PATTERNS.Ability) then return true end
    if Settings.TokenTicket and tokenMatches(tokenName, TOKEN_PATTERNS.Ticket) then return true end
    if Settings.TokenTreat and tokenMatches(tokenName, TOKEN_PATTERNS.Treat) then return true end
    if Settings.TokenPrecise and tokenMatches(tokenName, TOKEN_PATTERNS.Precise) then return true end
    if Settings.TokenMarks and tokenMatches(tokenName, TOKEN_PATTERNS.Marks) then return true end
    if Settings.TokenPopStar and tokenMatches(tokenName, TOKEN_PATTERNS.PopStar) then return true end
    if Settings.TokenLink and tokenMatches(tokenName, TOKEN_PATTERNS.Link) then return true end
    if Settings.TokenBomb and tokenMatches(tokenName, TOKEN_PATTERNS.Bomb) then return true end
    if Settings.TokenBubble and tokenMatches(tokenName, TOKEN_PATTERNS.Bubble) then return true end
    if Settings.TokenFlame and tokenMatches(tokenName, TOKEN_PATTERNS.Flame) then return true end

    return false
end

local function isTokenSupportedByMacroName(tokenName)
    for _, patterns in pairs(TOKEN_PATTERNS) do
        if tokenMatches(tokenName, patterns) then
            return true
        end
    end
    return false
end

local function getTokenPos(token)
    if token:IsA("BasePart") then
        return token.Position
    end
    if token:IsA("Model") then
        local part = token.PrimaryPart or token:FindFirstChildWhichIsA("BasePart")
        if part then
            return part.Position
        end
    end
    if token:IsA("Attachment") and token.Parent and token.Parent:IsA("BasePart") then
        return token.Parent.Position
    end
    return nil
end

local function getNearestTokenInField(fieldName)
    local root = select(1, getRootAndHumanoid())
    if not root then
        return nil
    end

    local now = os.clock()
    if tokenNearestCache.pos
        and tokenNearestCache.field == fieldName
        and (now - tokenNearestCache.at) <= TOKEN_NEAREST_CACHE_WINDOW
        and tokenNearestCache.rootPos
        and (root.Position - tokenNearestCache.rootPos).Magnitude <= 6
    then
        return tokenNearestCache.pos
    end

    local collectibles = getCollectiblesFolder()
    if not collectibles then
        return nil
    end

    local bestPos, bestDist = nil, math.huge
    for _, item in ipairs(collectibles:GetDescendants()) do
        local valid = item:IsA("BasePart") or item:IsA("Model") or item:IsA("Attachment")
        if valid and isTokenAllowed(item.Name) then
            local pos = getTokenPos(item)
            if pos and isPositionInsideField(pos, fieldName, 5) then
                local dist = (root.Position - pos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPos = pos
                end
            end
        end
    end

    tokenNearestCache.at = now
    tokenNearestCache.field = fieldName
    tokenNearestCache.pos = bestPos
    tokenNearestCache.rootPos = root.Position

    return bestPos
end

local function getBagPercent()
    local stats = LocalPlayer:FindFirstChild("CoreStats")
    if not stats then
        return 0
    end

    local pollen = stats:FindFirstChild("Pollen")
    local capacity = stats:FindFirstChild("Capacity")
    if pollen and capacity and capacity.Value > 0 then
        return (pollen.Value / capacity.Value) * 100
    end

    return 0
end

local function getHiveCenterFromInstance(instance)
    if not instance then
        return nil
    end

    if instance:IsA("Model") then
        local bestPart, bestScore = nil, -math.huge
        for _, desc in ipairs(instance:GetDescendants()) do
            if desc:IsA("BasePart") then
                local score = (desc.Size.X * desc.Size.Z) * 0.02
                if desc.Size.Y <= 8 then
                    score = score + 5
                else
                    score = score - 4
                end

                local normalizedName = normalizeText(desc.Name)
                for _, hint in ipairs(HIVE_PART_HINTS) do
                    if string.find(normalizedName, hint, 1, true) then
                        score = score + 10
                    end
                end

                if desc.Transparency > 0.85 then
                    score = score - 1
                end

                if score > bestScore then
                    bestScore = score
                    bestPart = desc
                end
            end
        end

        if bestPart then
            return CFrame.new(bestPart.Position + Vector3.new(0, 3, 0))
        end
    end

    local part = getPart(instance)
    if part then
        return CFrame.new(part.Position + Vector3.new(0, 3, 0))
    end

    return nil
end

local function getHiveConvertTargets(hiveCFrame)
    local p = hiveCFrame.Position
    return {
        p,
        p + Vector3.new(2.6, 0, 0),
        p + Vector3.new(-2.6, 0, 0),
        p + Vector3.new(0, 0, 2.6),
        p + Vector3.new(0, 0, -2.6),
        p + Vector3.new(2, 0, 2),
        p + Vector3.new(-2, 0, -2),
    }
end

local function getSpawnPadCFrame()
    local spawnPosRef = LocalPlayer:FindFirstChild("SpawnPos")
    if spawnPosRef and spawnPosRef:IsA("ObjectValue") and spawnPosRef.Value then
        local part = getPart(spawnPosRef.Value)
        if part then
            return CFrame.new(part.Position + Vector3.new(0, 2.4, 0))
        end
        local cf = getCFrame(spawnPosRef.Value)
        if cf then
            return CFrame.new(cf.Position + Vector3.new(0, 2.4, 0))
        end
    end
    return nil
end

local function getHiveCFrame()
    local spawnPosRef = LocalPlayer:FindFirstChild("SpawnPos")
    if spawnPosRef and spawnPosRef:IsA("ObjectValue") and spawnPosRef.Value then
        local spawnCenter = getHiveCenterFromInstance(spawnPosRef.Value)
        if spawnCenter then
            return spawnCenter
        end
    end

    for _, refName in ipairs({ "Hive", "HiveModel", "HivePart", "Honeycomb", "HiveBase" }) do
        local ref = LocalPlayer:FindFirstChild(refName)
        if ref and ref:IsA("ObjectValue") and ref.Value then
            local hiveCenter = getHiveCenterFromInstance(ref.Value)
            if hiveCenter then
                return hiveCenter
            end
        end
    end

    local hives = workspace:FindFirstChild("Honeycombs") or workspace:FindFirstChild("Hives")
    if not hives then
        return nil
    end

    local playerName = string.lower(LocalPlayer.Name)

    for _, obj in ipairs(hives:GetDescendants()) do
        if obj:IsA("StringValue") then
            local name = string.lower(obj.Name)
            if (name == "owner" or name == "playername" or name == "ownername") and string.lower(obj.Value) == playerName then
                local ancestor = obj.Parent
                while ancestor and ancestor ~= hives do
                    local hiveCenter = getHiveCenterFromInstance(ancestor)
                    if hiveCenter then
                        return hiveCenter
                    end
                    ancestor = ancestor.Parent
                end
            end
        end
    end

    for _, obj in ipairs(hives:GetDescendants()) do
        local itemName = string.lower(obj.Name)
        if string.find(itemName, playerName, 1, true) then
            local hiveCenter = getHiveCenterFromInstance(obj)
            if hiveCenter then
                return hiveCenter
            end
        end
    end

    local referencePos = nil
    if spawnPosRef and spawnPosRef:IsA("ObjectValue") and spawnPosRef.Value and spawnPosRef.Value:IsA("BasePart") then
        referencePos = spawnPosRef.Value.Position
    else
        local root = select(1, getRootAndHumanoid())
        referencePos = root and root.Position or Vector3.new(0, 0, 0)
    end

    local nearestCFrame, nearestDist = nil, math.huge
    for _, child in ipairs(hives:GetChildren()) do
        local hiveCenter = getHiveCenterFromInstance(child)
        if hiveCenter then
            local dist = (hiveCenter.Position - referencePos).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearestCFrame = hiveCenter
            end
        end
    end

    return nearestCFrame
end

local function isConvertRemoteName(remoteName)
    local name = normalizeText(remoteName)
    return string.find(name, "convert", 1, true)
        or string.find(name, "makehoney", 1, true)
        or string.find(name, "hive", 1, true)
        or string.find(name, "honey", 1, true)
end

local function fireRemoteNoArgs(remote)
    if remote:IsA("RemoteEvent") then
        local attempts = {
            {},
            { "Convert" },
            { "MakeHoney" },
            { "ConvertHoney" },
            { "StartConverting" },
            { "StartHoneyMaking" },
            { LocalPlayer },
            { LocalPlayer, "Convert" },
            { LocalPlayer, "MakeHoney" },
            { "Hive", "Convert" },
            { "Hive", "MakeHoney" },
            { "Honey", "Convert" },
        }
        for _, args in ipairs(attempts) do
            local ok = pcall(function()
                remote:FireServer(table.unpack(args))
            end)
            if ok then
                return true
            end
        end
        return false
    elseif remote:IsA("RemoteFunction") then
        local attempts = {
            {},
            { "Convert" },
            { "MakeHoney" },
            { "ConvertHoney" },
            { LocalPlayer },
            { LocalPlayer, "Convert" },
            { LocalPlayer, "MakeHoney" },
        }
        for _, args in ipairs(attempts) do
            local ok = pcall(function()
                remote:InvokeServer(table.unpack(args))
            end)
            if ok then
                return true
            end
        end
        return false
    elseif remote:IsA("BindableEvent") then
        return pcall(function()
            remote:Fire()
        end)
    elseif remote:IsA("BindableFunction") then
        return pcall(function()
            remote:Invoke()
        end)
    end
    return false
end

local function getConvertRemotes()
    if convertRemoteCache then
        local valid = {}
        for _, remote in ipairs(convertRemoteCache) do
            if remote and remote.Parent then
                table.insert(valid, remote)
            end
        end
        if #valid > 0 then
            convertRemoteCache = valid
            return valid
        end
    end

    local found = {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        local isRemote = obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") or obj:IsA("BindableFunction")
        if isRemote and isConvertRemoteName(obj.Name) then
            table.insert(found, obj)
        end
    end
    convertRemoteCache = found
    return found
end

local function tryTapMakeHoneyUI()
    local activated = false
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return false
    end

    local sawMakeHoneyText = false
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local text = normalizeText(obj.Text)
            if string.find(text, "makehoney", 1, true) then
                sawMakeHoneyText = true
            end
        end
    end

    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextButton") then
            local text = normalizeText(obj.Text)
            if string.find(text, "makehoney", 1, true) or string.find(text, "tap", 1, true) then
                if type(firesignal) == "function" then
                    pcall(function()
                        firesignal(obj.MouseButton1Click)
                    end)
                    pcall(function()
                        firesignal(obj.Activated)
                    end)
                    activated = true
                end
            end
        end
    end

    if sawMakeHoneyText and VirtualInputManager and workspace.CurrentCamera then
        local viewport = workspace.CurrentCamera.ViewportSize
        local x = math.floor(viewport.X * 0.5)
        local y = math.floor(viewport.Y * 0.5)

        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
            activated = true
        end)
    end

    return activated
end

local function tryKeyboardOrTapInput()
    local activated = false

    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            activated = true
        end)
    end

    if VirtualUser and workspace.CurrentCamera then
        local viewport = workspace.CurrentCamera.ViewportSize
        local v = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button1Down(v)
            task.wait(0.03)
            VirtualUser:Button1Up(v)
            activated = true
        end)
    end

    return activated
end

local function tryAggressiveInputSpam()
    if not Settings.NoSafeMode then
        return false
    end

    local activated = false

    if type(keypress) == "function" and type(keyrelease) == "function" then
        pcall(function()
            keypress(0x45)
            keyrelease(0x45)
            activated = true
        end)
    end

    if type(mouse1click) == "function" then
        pcall(function()
            mouse1click()
            activated = true
        end)
    elseif type(mouse1press) == "function" and type(mouse1release) == "function" then
        pcall(function()
            mouse1press()
            task.wait(0.01)
            mouse1release()
            activated = true
        end)
    end

    if VirtualInputManager and workspace.CurrentCamera then
        local viewport = workspace.CurrentCamera.ViewportSize
        local cx = math.floor(viewport.X * 0.5)
        local cy = math.floor(viewport.Y * 0.5)
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            activated = true
        end)
    end

    return activated
end

local function tryTouchHiveParts(center)
    if type(firetouchinterest) ~= "function" then
        return false
    end

    local root = select(1, getRootAndHumanoid())
    if not root then
        return false
    end

    local activated = false
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and (part.Position - center).Magnitude <= 13 then
            local n = normalizeText(part.Name)
            if string.find(n, "hive", 1, true)
                or string.find(n, "convert", 1, true)
                or string.find(n, "spawn", 1, true)
                or string.find(n, "pad", 1, true)
                or string.find(n, "platform", 1, true)
            then
                pcall(function()
                    firetouchinterest(root, part, 0)
                    firetouchinterest(root, part, 1)
                    activated = true
                end)
            end
        end
    end

    return activated
end

local function tryActivateHiveConversion(hiveCFrame)
    local activated = false
    local center = hiveCFrame.Position
    local searchRoot = workspace

    if tryTapMakeHoneyUI() then
        activated = true
    end

    if tryKeyboardOrTapInput() then
        activated = true
    end

    if tryAggressiveInputSpam() then
        activated = true
    end

    if type(fireproximityprompt) == "function" then
        for _, obj in ipairs(searchRoot:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Parent then
                local part = getPart(obj.Parent)
                if part and (part.Position - center).Magnitude <= 14 then
                    local ok = pcall(function()
                        fireproximityprompt(obj)
                    end)
                    activated = activated or ok
                end
            end
        end
    end

    if type(fireclickdetector) == "function" then
        for _, obj in ipairs(searchRoot:GetDescendants()) do
            if obj:IsA("ClickDetector") and obj.Parent then
                local part = getPart(obj.Parent)
                if part and (part.Position - center).Magnitude <= 14 then
                    local ok = pcall(function()
                        fireclickdetector(obj)
                    end)
                    activated = activated or ok
                end
            end
        end
    end

    for _, remote in ipairs(getConvertRemotes()) do
        local ok = fireRemoteNoArgs(remote)
        activated = activated or ok
    end

    if Settings.NoSafeMode and tryTouchHiveParts(center) then
        activated = true
    end

    return activated
end

local function isAtlasPaused()
    return Settings.ScriptStopped == true
end

local function getSearchRoots()
    local roots = { workspace, ReplicatedStorage }
    local wEvents = workspace:FindFirstChild("Events")
    local rEvents = ReplicatedStorage:FindFirstChild("Events")
    if wEvents then
        table.insert(roots, wEvents)
    end
    if rEvents then
        table.insert(roots, rEvents)
    end
    return roots
end

local function isRemoteAction(instance)
    return instance
        and (instance:IsA("RemoteEvent")
        or instance:IsA("RemoteFunction")
        or instance:IsA("BindableEvent")
        or instance:IsA("BindableFunction"))
end

local function normalizeAliases(aliases)
    local out = {}
    for _, alias in ipairs(aliases or {}) do
        local normalized = normalizeText(alias)
        if normalized ~= "" then
            table.insert(out, normalized)
        end
    end
    return out
end

local function buildAliasCacheKey(normalizedAliases)
    local copy = {}
    for i, alias in ipairs(normalizedAliases) do
        copy[i] = alias
    end
    table.sort(copy)
    return table.concat(copy, "|")
end

local function gatherRemotesByAliases(normalizedAliases)
    local found = {}
    for _, root in ipairs(getSearchRoots()) do
        for _, obj in ipairs(root:GetDescendants()) do
            if isRemoteAction(obj) then
                local normalizedName = normalizeText(obj.Name)
                for _, alias in ipairs(normalizedAliases) do
                    if string.find(normalizedName, alias, 1, true) then
                        table.insert(found, obj)
                        break
                    end
                end
            end
        end
    end
    return found
end

local function getCachedRemotesByAliases(normalizedAliases)
    local cacheKey = buildAliasCacheKey(normalizedAliases)
    local cached = remoteAliasCache[cacheKey]
    if cached then
        local valid = {}
        for _, remote in ipairs(cached) do
            if remote and remote.Parent and isRemoteAction(remote) then
                table.insert(valid, remote)
            end
        end
        if #valid > 0 then
            remoteAliasCache[cacheKey] = valid
            return valid
        end
    end

    local found = gatherRemotesByAliases(normalizedAliases)
    remoteAliasCache[cacheKey] = found
    return found
end

local function buildRemoteArgAttempts(baseArgs)
    local attempts = {}
    local function push(args)
        local packed = {}
        for i, v in ipairs(args) do
            packed[i] = v
        end
        table.insert(attempts, packed)
    end

    push(baseArgs)
    push({})
    if #baseArgs > 0 then
        push({ "Use", table.unpack(baseArgs) })
        push({ "Activate", table.unpack(baseArgs) })
        push({ "Collect", table.unpack(baseArgs) })
        push({ "Start", table.unpack(baseArgs) })
        push({ LocalPlayer, table.unpack(baseArgs) })
        push({ LocalPlayer, "Use", table.unpack(baseArgs) })
    end
    return attempts
end

local function tryCallRemoteWithArgs(remote, args)
    if remote:IsA("RemoteEvent") then
        return pcall(function()
            remote:FireServer(table.unpack(args))
        end)
    elseif remote:IsA("RemoteFunction") then
        return pcall(function()
            remote:InvokeServer(table.unpack(args))
        end)
    elseif remote:IsA("BindableEvent") then
        return pcall(function()
            remote:Fire(table.unpack(args))
        end)
    elseif remote:IsA("BindableFunction") then
        return pcall(function()
            remote:Invoke(table.unpack(args))
        end)
    end
    return false
end

local function callRemoteByAliases(aliases, ...)
    local normalizedAliases = normalizeAliases(aliases)
    if #normalizedAliases == 0 then
        return false
    end

    local baseArgs = { ... }
    local argAttempts = buildRemoteArgAttempts(baseArgs)
    local remotes = getCachedRemotesByAliases(normalizedAliases)
    for _, remote in ipairs(remotes) do
        for _, args in ipairs(argAttempts) do
            if tryCallRemoteWithArgs(remote, args) then
                return true
            end
        end
    end
    return false
end

local function activateCurrentTool()
    local character = getCharacter()
    if not character then
        return false
    end
    local tool = character:FindFirstChildWhichIsA("Tool")
    if not tool then
        return false
    end

    local ok = pcall(function()
        tool:Activate()
    end)
    return ok
end

local function tryAutoSprinklerTick()
    if not Settings.AutoSprinkler then
        return false
    end
    local interval = math.clamp(tonumber(Settings.SprinklerInterval) or 12, 3, 60)
    if (os.clock() - lastSprinklerUse) < interval then
        return false
    end

    local ok = false
    if Settings.UseRemotes then
        ok = callRemoteByAliases({ "sprinkler", "sprinklerbuilder", "sprinklerbuilderactor", "place sprinklers" }, Settings.SprinklerType)
    end
    if not ok then
        ok = callRemoteByAliases({ "sprinkler" }, Settings.SprinklerType)
    end
    if ok then
        lastSprinklerUse = os.clock()
    end
    return ok
end

local function tryAutoDigTick()
    if not Settings.AutoDig then
        return false
    end
    local method = tostring(Settings.AutoDigMethod or "Remote")
    if method == "Remote" then
        if Settings.UseRemotes then
            return callRemoteByAliases({ "dig", "tool", "collectpollen" }) or activateCurrentTool()
        end
        return activateCurrentTool()
    end
    if method == "ActivateTool" then
        return activateCurrentTool()
    end
    local remoteOk = false
    if Settings.UseRemotes then
        remoteOk = callRemoteByAliases({ "dig", "tool", "collectpollen" })
    end
    return remoteOk or activateCurrentTool()
end

local function getFieldCenterPosition()
    local field = getFieldCFrame(Settings.FieldName)
    if not field then
        return nil
    end
    local root = select(1, getRootAndHumanoid())
    if root then
        return Vector3.new(field.Position.X, root.Position.Y, field.Position.Z)
    end
    return field.Position
end

local function getFaceTargetPosition()
    if Settings.FaceCenter then
        return getFieldCenterPosition()
    end

    if Settings.FaceBubbles then
        local bubble = getNearestTokenInField(Settings.FieldName)
        if bubble then
            return bubble
        end
    end

    return getFieldCenterPosition()
end

local function applyFaceDirection()
    local root = select(1, getRootAndHumanoid())
    if not root then
        return
    end

    local targetPos = getFaceTargetPosition()
    if not targetPos then
        return
    end

    local look = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
    if (look - root.Position).Magnitude < 1 then
        return
    end

    root.CFrame = CFrame.lookAt(root.Position, look)
end

local function shouldFightByName(rawName)
    local name = normalizeText(rawName)
    if Settings.AutoKillAphid and string.find(name, "aphid", 1, true) then return true end
    if Settings.AutoKillLadybug and string.find(name, "ladybug", 1, true) then return true end
    if Settings.AutoKillRhinoBeetle and string.find(name, "rhinobeetle", 1, true) then return true end
    if Settings.AutoKillSpider and string.find(name, "spider", 1, true) then return true end
    if Settings.AutoKillMantis and string.find(name, "mantis", 1, true) then return true end
    if Settings.AutoKillScorpion and string.find(name, "scorpion", 1, true) then return true end
    if Settings.AutoKillWerewolf and string.find(name, "werewolf", 1, true) then return true end
    if Settings.AutoKillTunnelBear and string.find(name, "tunnelbear", 1, true) then return true end
    if Settings.AutoKillKingBeetle and string.find(name, "kingbeetle", 1, true) then return true end
    if Settings.AutoKillCoconutCrab and string.find(name, "coconutcrab", 1, true) then return true end
    if Settings.AutoKillMondoChick and string.find(name, "mondochick", 1, true) then return true end
    if Settings.AutoKillCommando and string.find(name, "commandochick", 1, true) then return true end
    if Settings.AutoKillViciousBee and string.find(name, "vicious", 1, true) then return true end
    if Settings.AutoKillWindyBee and string.find(name, "windy", 1, true) then return true end
    return false
end

local function isHostileName(rawName)
    local name = normalizeText(rawName)
    return string.find(name, "aphid", 1, true)
        or string.find(name, "ladybug", 1, true)
        or string.find(name, "rhinobeetle", 1, true)
        or string.find(name, "spider", 1, true)
        or string.find(name, "mantis", 1, true)
        or string.find(name, "scorpion", 1, true)
        or string.find(name, "werewolf", 1, true)
        or string.find(name, "vicious", 1, true)
        or string.find(name, "windy", 1, true)
end

local function getNearestHostile(maxDistance)
    local root = select(1, getRootAndHumanoid())
    if not root then
        return nil
    end

    local nearestPos = nil
    local nearestDist = math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and isHostileName(obj.Name) then
            local part = getPart(obj)
            if part then
                local dist = (root.Position - part.Position).Magnitude
                if dist < nearestDist and dist <= maxDistance then
                    nearestDist = dist
                    nearestPos = part.Position
                end
            end
        end
    end
    return nearestPos
end

local function extractLevelFromModel(model)
    if not model then
        return nil
    end

    local direct = model:FindFirstChild("Level")
    if direct and direct:IsA("NumberValue") then
        return tonumber(direct.Value)
    end

    local fromName = string.match(model.Name, "%d+")
    if fromName then
        return tonumber(fromName)
    end
    return nil
end

local function isModelAlive(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if hum then
        return hum.Health > 0
    end
    return true
end

local function getNearestCombatTarget(maxDistance)
    local root = select(1, getRootAndHumanoid())
    if not root then
        return nil, nil
    end

    local nearestModel = nil
    local nearestPos = nil
    local nearestDist = math.huge

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and shouldFightByName(obj.Name) and isModelAlive(obj) then
            local modelLevel = extractLevelFromModel(obj)
            local normalizedName = normalizeText(obj.Name)
            local shouldSkip = false
            if Settings.AutoKillViciousBee and string.find(normalizedName, "vicious", 1, true) and modelLevel then
                if modelLevel < Settings.ViciousMinLevel or modelLevel > Settings.ViciousMaxLevel then
                    shouldSkip = true
                end
            end
            if not shouldSkip and Settings.AutoKillWindyBee and string.find(normalizedName, "windy", 1, true) and modelLevel then
                if modelLevel < Settings.WindyMinLevel or modelLevel > Settings.WindyMaxLevel then
                    shouldSkip = true
                end
            end
            if shouldSkip then
                continue
            end

            local part = getPart(obj)
            if part then
                local dist = (root.Position - part.Position).Magnitude
                if dist <= maxDistance and dist < nearestDist then
                    nearestDist = dist
                    nearestModel = obj
                    nearestPos = part.Position
                end
            end
        end
    end

    return nearestModel, nearestPos
end

local function tryCombatSupport()
    if Settings.AutoStingers then
        callRemoteByAliases({ "stinger" }, "Use")
    end
    if Settings.AutoStarSaw then
        callRemoteByAliases({ "starsaw", "star saw" }, "Use")
    end
    if Settings.AutoDemonMask then
        callRemoteByAliases({ "mask", "equipmask" }, "Demon Mask")
    end
end

local function runCombatLoop(updateStatus)
    if combatLoopRunning then
        return
    end
    combatLoopRunning = true

    while Settings.EnableCombat do
        if isAtlasPaused() then
            task.wait(0.2)
            continue
        end

        applyWalkSpeed()
        local _, enemyPos = getNearestCombatTarget(math.clamp(tonumber(Settings.CombatRadius) or 220, 40, 600))
        if enemyPos then
            local root = select(1, getRootAndHumanoid())
            local targetPos = enemyPos
            if root then
                targetPos = Vector3.new(enemyPos.X, root.Position.Y, enemyPos.Z)
            end

            walkTo(targetPos, 4, 2, function()
                return not Settings.EnableCombat
            end)

            for _ = 1, 7 do
                activateCurrentTool()
                task.wait(0.08)
            end
            tryCombatSupport()
            if updateStatus then
                updateStatus("Combat: engaging")
            end
        else
            if updateStatus then
                updateStatus("Combat: idle")
            end
            task.wait(0.2)
        end
    end

    combatLoopRunning = false
end

local function runQuestLoop(updateStatus)
    if questLoopRunning then
        return
    end
    questLoopRunning = true

    while Settings.AutoQuest do
        if isAtlasPaused() then
            task.wait(0.4)
            continue
        end

        local didAny = false
        local questNpcs = {
            { toggle = Settings.AutoQuestBlackBear, name = "Black Bear" },
            { toggle = Settings.AutoQuestMotherBear, name = "Mother Bear" },
            { toggle = Settings.AutoQuestPandaBear, name = "Panda Bear" },
            { toggle = Settings.AutoQuestScienceBear, name = "Science Bear" },
            { toggle = Settings.AutoQuestDapperBear, name = "Dapper Bear" },
            { toggle = Settings.AutoQuestOnett, name = "Onett" },
            { toggle = Settings.AutoQuestSpiritBear, name = "Spirit Bear" },
            { toggle = Settings.AutoQuestBrownBearRepeat, name = "Brown Bear" },
            { toggle = Settings.AutoQuestBuckoRepeat, name = "Bucko Bee" },
            { toggle = Settings.AutoQuestRileyRepeat, name = "Riley Bee" },
            { toggle = Settings.AutoQuestHoneyBeeRepeat, name = "Honey Bee" },
            { toggle = Settings.AutoQuestPolarBearRepeat, name = "Polar Bear" },
        }

        for _, npc in ipairs(questNpcs) do
            if npc.toggle then
                local okClaim = callRemoteByAliases({ npc.name, "quest", "claim" }, npc.name)
                local okTalk = callRemoteByAliases({ npc.name, "talk", "npc" }, npc.name)
                didAny = didAny or okClaim or okTalk
                task.wait(0.08)
            end
        end

        if Settings.AutoClaimQuests then
            didAny = callRemoteByAliases({ "quest", "claim", "reward" }) or didAny
        end

        if Settings.QuestFarmAnts then
            didAny = callRemoteByAliases({ "ant", "challenge", "token" }) or didAny
        end
        if Settings.QuestFarmRageTokens then
            didAny = callRemoteByAliases({ "rage", "token" }) or didAny
        end
        if Settings.QuestDoWindShrine then
            didAny = callRemoteByAliases({ "windshrine", "donate", "wind shrine" }) or didAny
        end
        if Settings.QuestDoMemoryMatch then
            didAny = callRemoteByAliases({ "memorymatch", "memory", "match" }) or didAny
        end
        if Settings.QuestShareJellyBeans then
            didAny = callRemoteByAliases({ "jellybean", "share" }) or didAny
        end
        if Settings.QuestCraftItems then
            didAny = callRemoteByAliases({ "craft", "blender" }) or didAny
        end

        if Settings.QuestUseToys then
            for _, toy in ipairs(TOYS) do
                local key = "Toy_" .. toy.key
                if Settings[key] then
                    callRemoteByAliases(toy.aliases)
                    task.wait(0.05)
                end
            end
            didAny = true
        end

        if Settings.FeedBees then
            didAny = callRemoteByAliases({ "feed", "bee" }) or didAny
        end
        if Settings.LevelUpBees then
            didAny = callRemoteByAliases({ "level", "bee", "treat" }) or didAny
        end
        if Settings.PurchaseTreatsToLevelUp then
            didAny = callRemoteByAliases({ "purchase", "treat" }, 1000) or didAny
        end
        if Settings.UseRoyalJelly then
            didAny = callRemoteByAliases({ "royaljelly", "use" }, "Auto") or didAny
        end

        if updateStatus then
            updateStatus(didAny and "Quests: working" or "Quests: idle")
        end

        task.wait(1.4)
    end

    questLoopRunning = false
end

local function isDaytime()
    local hour = tonumber(Lighting.ClockTime) or 12
    return hour >= 6 and hour < 18
end

local function runAtlasToyCategoryTick()
    if not Settings.AllowGatherInterrupt and Settings.AutoFarm then
        return
    end
    local now = os.clock()
    local perCategoryDelay = math.max(20, tonumber(Settings.ToyLoopDelay) or 120)
    for settingKey, aliases in pairs(ATLAS_TOY_CATEGORY_ALIASES) do
        if settingKey == "AutoToyMaterials" and Settings.AutoUseMaterials then
            continue
        end
        if Settings[settingKey] then
            local lastUse = atlasToyTracker[settingKey] or 0
            if (now - lastUse) >= perCategoryDelay then
                callRemoteByAliases(aliases, Settings.FieldName)
                atlasToyTracker[settingKey] = now
            end
        end
    end
end

local function runAutoMaterialsTick()
    if not Settings.AutoUseMaterials then
        return
    end

    local now = os.clock()
    local delay = math.clamp(tonumber(Settings.MaterialsLoopDelay) or 120, 10, 900)
    for _, material in ipairs(MATERIALS) do
        local key = materialSettingKey(material)
        if Settings[key] then
            local lastUse = materialUseTracker[material.key] or 0
            if (now - lastUse) >= delay then
                if useMaterialOnce then
                    useMaterialOnce(material)
                end
                materialUseTracker[material.key] = os.clock()
            end
        end
    end
end

local function safePlantFieldName()
    if Settings.PlanterAllowedField and Settings.PlanterAllowedField ~= "" then
        return Settings.PlanterAllowedField
    end
    return Settings.FieldName
end

local function runPlanterLoop(updateStatus)
    if planterLoopRunning then
        return
    end
    planterLoopRunning = true

    while Settings.EnablePlanters do
        if isAtlasPaused() then
            task.wait(0.3)
            continue
        end

        local allowedByTime = true
        if Settings.PlanterDuringDayOnly and not isDaytime() then
            allowedByTime = false
        end
        if Settings.PlanterDuringNightOnly and isDaytime() then
            allowedByTime = false
        end

        local didAny = false
        if allowedByTime then
            local targetField = safePlantFieldName()
            if Settings.PlanterAutoHarvest then
                if tryPlanterAction then
                    local okHarvest = tryPlanterAction("Harvest", targetField)
                    didAny = okHarvest or didAny
                else
                    didAny = callRemoteByAliases({ "planter", "harvest", "collectplanter" }, targetField) or didAny
                end
            end
            if Settings.PlanterAutoPlant then
                if tryPlanterAction then
                    local okPlant = tryPlanterAction("Plant", targetField)
                    didAny = okPlant or didAny
                else
                    didAny = callRemoteByAliases({ "planter", "plant", "placeplanter" }, targetField) or didAny
                end
            end
        end

        if updateStatus then
            if not allowedByTime then
                updateStatus("Planters: waiting time")
            else
                updateStatus(didAny and "Planters: active" or "Planters: idle")
            end
        end

        task.wait(math.clamp(tonumber(Settings.PlanterLoopDelay) or 60, 8, 300))
    end

    planterLoopRunning = false
end

local function isWebhookUrlValid(url)
    local s = tostring(url or "")
    return s ~= "" and (
        string.find(s, "https://discord.com/api/webhooks/", 1, true)
        or string.find(s, "https://discordapp.com/api/webhooks/", 1, true)
    )
end

local function sendDiscordWebhook(url, title, description, color)
    if not isWebhookUrlValid(url) then
        return false, "Webhook URL invalid"
    end

    local payload = {
        username = "ICHIGER",
        embeds = {
            {
                title = title,
                description = description,
                color = color or 3447003,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "ICHIGER macro" },
            },
        },
    }

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        return false, "Webhook encode failed"
    end

    local okPost, err = pcall(function()
        HttpService:PostAsync(url, encoded, Enum.HttpContentType.ApplicationJson, false)
    end)
    if not okPost then
        return false, tostring(err)
    end

    return true, "Sent"
end

local function buildWebhookSummary(reason)
    local lines = {
        "**" .. tostring(reason or "Status") .. "**",
        "Field: `" .. tostring(Settings.FieldName) .. "`",
        "Bag: `" .. string.format("%.1f%%", getBagPercent()) .. "`",
    }

    if Settings.WebhookSendBalloonPollen then
        table.insert(lines, "Balloon pollen: enabled")
    end
    if Settings.WebhookSendNectars then
        table.insert(lines, "Nectar scan: enabled")
    end
    if Settings.WebhookSendPlanters then
        table.insert(lines, "Planter scan: enabled")
    end
    if Settings.WebhookSendItems then
        table.insert(lines, "Items scan: enabled")
    end
    if Settings.WebhookSendQuestDone and Settings.AutoQuest then
        table.insert(lines, "Quests: auto")
    end

    return table.concat(lines, "\n")
end

local function sendWebhookSnapshot(reason, graphMode)
    local url = graphMode and Settings.GraphWebhookUrl or Settings.WebhookUrl
    if not isWebhookUrlValid(url) then
        return false, "Webhook URL invalid"
    end

    local title
    if graphMode then
        title = Settings.GraphUseBranding and "Natro Macro Graph" or "ICHIGER Graph"
    else
        title = "ICHIGER Webhook"
    end

    local color = graphMode and 10181046 or 3447003
    return sendDiscordWebhook(url, title, buildWebhookSummary(reason), color)
end

local function shouldAutoRejoinNow()
    local coreGui = game:GetService("CoreGui")
    local promptGui = coreGui:FindFirstChild("RobloxPromptGui")
    local promptOverlay = promptGui and promptGui:FindFirstChild("promptOverlay")
    local errorPrompt = promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt")
    return errorPrompt and errorPrompt.Visible
end

local lastRejoinAttempt = 0
local function tryAutoRejoin()
    if not Settings.AutoRejoin then
        return
    end

    local delaySeconds = math.clamp(tonumber(Settings.AutoRejoinDelay) or 6, 2, 30)
    if not shouldAutoRejoinNow() then
        return
    end
    if (os.clock() - lastRejoinAttempt) < delaySeconds then
        return
    end

    lastRejoinAttempt = os.clock()
    if Settings.EnableWebhook and Settings.WebhookSendDisconnect then
        pcall(function()
            sendWebhookSnapshot("Disconnect detected, rejoining", false)
        end)
    end
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function runWebhookLoop(updateStatus)
    if webhookLoopRunning then
        return
    end
    webhookLoopRunning = true

    while true do
        local intervalMinutes = math.clamp(tonumber(Settings.WebhookIntervalMinutes) or 5, 1, 120)
        local intervalSeconds = intervalMinutes * 60
        if Settings.EnableWebhook then
            if os.clock() - lastWebhookSend >= intervalSeconds then
                local ok, msg = sendWebhookSnapshot("Interval update", false)
                if Settings.GraphEnabled and isWebhookUrlValid(Settings.GraphWebhookUrl) then
                    sendWebhookSnapshot("Graph update", true)
                end
                lastWebhookSend = os.clock()
                if updateStatus then
                    updateStatus(ok and "Webhook: sent" or ("Webhook: " .. tostring(msg)))
                end
            end
        end
        task.wait(2)
    end
end

local function runSupportLoop()
    if supportLoopRunning then
        return
    end
    supportLoopRunning = true

    while true do
        if not isAtlasPaused() then
            local shouldRunBackground = Settings.AutoFarm or Settings.RunWithoutAutofarm
            if shouldRunBackground then
                if Settings.AutoDig or Settings.AutoSprinkler then
                    tryAutoDigTick()
                    tryAutoSprinklerTick()
                end
                runAtlasToyCategoryTick()
                runAutoMaterialsTick()
            end
        end
        tryAutoRejoin()
        task.wait(0.1)
    end
end

local function runAutoFarm()
    if farmLoopRunning then
        return
    end
    farmLoopRunning = true

    local lastRootPos = nil
    local lastMoveAt = os.clock()

    while Settings.AutoFarm do
        if isAtlasPaused() then
            stopMovement()
            task.wait(0.2)
            continue
        end

        applyWalkSpeed()
        tryAutoDigTick()
        tryAutoSprinklerTick()
        applyFaceDirection()
        local inHivePhase = false
        local shouldConvert = Settings.ReturnToHive and getBagPercent() >= Settings.HiveBagPercent

        if shouldConvert and Settings.ConvertOnlyWhenInField then
            local root = select(1, getRootAndHumanoid())
            if root then
                shouldConvert = isPositionInsideField(root.Position, Settings.FieldName, 6)
            else
                shouldConvert = false
            end
        end

        if shouldConvert then
            inHivePhase = true
            local hiveCFrame = getSpawnPadCFrame() or getHiveCFrame()
            if hiveCFrame then
                if Settings.ResetWhenConverting then
                    local _, humanoid = getRootAndHumanoid()
                    if humanoid and humanoid.Health > 0 then
                        humanoid.Health = 0
                        task.wait(1.1)
                    end
                end
                tweenTo(hiveCFrame, getActiveTweenSpeed())
                local rootAtHive = select(1, getRootAndHumanoid())
                if rootAtHive then
                    local exactCenter = Vector3.new(hiveCFrame.Position.X, rootAtHive.Position.Y, hiveCFrame.Position.Z)
                    walkTo(exactCenter, 1.9, 1.8, function()
                        return not Settings.AutoFarm
                    end)
                end

                local waitBefore = math.clamp(tonumber(Settings.WaitBeforeConverting) or 0, 0, 25)
                if waitBefore > 0 then
                    task.wait(waitBefore)
                end

                if Settings.UseEnzymesForConvertingBalloon then
                    callRemoteByAliases({ "enzyme", "useitem", "consume" }, "Enzymes")
                end

                if Settings.AutoHoneyMaskForBalloon then
                    callRemoteByAliases({ "equipmask", "mask" }, "Honey Mask")
                end

                local convertTargets = getHiveConvertTargets(hiveCFrame)
                local convertIndex = 1
                local previousBagPercent = getBagPercent()
                local nextNudgeAt = os.clock() + (Settings.NoSafeMode and 2 or 6)
                local nextActionAt = os.clock()
                local timeoutAt = os.clock() + Settings.HiveWaitSeconds
                local lastDecreaseAt = os.clock()
                local actionInterval = Settings.NoSafeMode and AGGRESSIVE_HIVE_ACTION_INTERVAL or SAFE_HIVE_ACTION_INTERVAL

                while Settings.AutoFarm and os.clock() < timeoutAt do
                    local currentBagPercent = getBagPercent()
                    if currentBagPercent <= 10 then
                        break
                    end

                    if currentBagPercent + 0.2 < previousBagPercent then
                        previousBagPercent = currentBagPercent
                        lastDecreaseAt = os.clock()
                        nextNudgeAt = os.clock() + (Settings.NoSafeMode and 2.5 or 6)
                    end

                    if os.clock() >= nextActionAt then
                        tryActivateHiveConversion(hiveCFrame)
                        if Settings.NoSafeMode then
                            tryActivateHiveConversion(hiveCFrame)
                        end
                        if Settings.UseCoconutToConvert and getBagPercent() >= Settings.UseCoconutAtPercentage then
                            callRemoteByAliases({ "coconut", "belt", "convert" }, "Use")
                        end
                        nextActionAt = os.clock() + actionInterval
                    end

                    local root = select(1, getRootAndHumanoid())
                    if root and (root.Position - hiveCFrame.Position).Magnitude > (Settings.NoSafeMode and 3.6 or 5.5) then
                        tweenTo(hiveCFrame, getActiveTweenSpeed())
                    end

                    if os.clock() >= nextNudgeAt and (os.clock() - lastDecreaseAt) >= (Settings.NoSafeMode and 2 or 5) then
                        convertIndex = (convertIndex % #convertTargets) + 1
                        if root then
                            local target = convertTargets[convertIndex]
                            local walkTarget = Vector3.new(target.X, root.Position.Y, target.Z)
                            walkTo(walkTarget, Settings.NoSafeMode and 1.2 or 2.5, Settings.NoSafeMode and 0.9 or 1.4, function()
                                return not Settings.AutoFarm
                            end)
                        end
                        nextNudgeAt = os.clock() + (Settings.NoSafeMode and 1.2 or 4)
                    end

                    task.wait(Settings.NoSafeMode and 0.05 or 0.2)
                end

                if Settings.AutoHoneyMaskForBalloon and Settings.DefaultMask ~= "None" then
                    callRemoteByAliases({ "equipmask", "mask" }, Settings.DefaultMask)
                end

                if Settings.AutoFarm and getBagPercent() >= (Settings.HiveBagPercent - 1) then
                    local fieldReset = getFieldCFrame(Settings.FieldName)
                    if fieldReset then
                        local root = select(1, getRootAndHumanoid())
                        local y = root and root.Position.Y or fieldReset.Position.Y
                        tweenTo(CFrame.new(fieldReset.Position.X, y, fieldReset.Position.Z), getActiveTweenSpeed())
                    end
                end
            else
                task.wait(0.2)
            end
        else
            stopTween()

            if Settings.AutoAvoidMobs then
                local hostilePos = getNearestHostile(18)
                local root = select(1, getRootAndHumanoid())
                if hostilePos and root then
                    local awayDir = (root.Position - hostilePos)
                    if awayDir.Magnitude > 0 then
                        awayDir = awayDir.Unit
                        local awayTarget = root.Position + (awayDir * 16)
                        moveToPosition(Vector3.new(awayTarget.X, root.Position.Y, awayTarget.Z), 6, 1.1, function()
                            return not Settings.AutoFarm
                        end)
                    end
                end
            end

            local tokenPos = getNearestTokenInField(Settings.FieldName)
            if tokenPos then
                local root = select(1, getRootAndHumanoid())
                local walkTarget = tokenPos
                if root then
                    walkTarget = Vector3.new(tokenPos.X, root.Position.Y, tokenPos.Z)
                end
                local tokenAnchor = tokenPos
                moveToToken(walkTarget, function()
                    if not Settings.AutoFarm or isAtlasPaused() then
                        return true
                    end

                    local currentToken = getNearestTokenInField(Settings.FieldName)
                    if not currentToken then
                        return true
                    end

                    return (currentToken - tokenAnchor).Magnitude > 6
                end)
            else
                local walkPos = getRandomPointInField(Settings.FieldName)
                if walkPos then
                    moveToPosition(walkPos, 5, 3, function()
                        return not Settings.AutoFarm
                    end)
                else
                    task.wait(0.2)
                end
            end
        end

        if not inHivePhase then
            local root = select(1, getRootAndHumanoid())
            if root then
                if not lastRootPos then
                    lastRootPos = root.Position
                    lastMoveAt = os.clock()
                else
                    local moved = (root.Position - lastRootPos).Magnitude
                    if moved >= 1.5 then
                        lastRootPos = root.Position
                        lastMoveAt = os.clock()
                    elseif os.clock() - lastMoveAt >= 6 then
                        local fieldReset = getFieldCFrame(Settings.FieldName)
                        if fieldReset then
                            local y = root.Position.Y
                            tweenTo(CFrame.new(fieldReset.Position.X, y, fieldReset.Position.Z), getActiveTweenSpeed())
                        end
                        lastRootPos = root.Position
                        lastMoveAt = os.clock()
                    end
                end
            end
        end

        task.wait(0.05)
    end

    stopMovement()
    farmLoopRunning = false
end

local function getToyByLabel(label)
    for _, toy in ipairs(TOYS) do
        if toy.label == label then
            return toy
        end
    end
    return TOYS[1]
end

local function toySettingKey(toy)
    return "Toy_" .. toy.key
end

materialSettingKey = function(material)
    return "Material_" .. material.key
end

local function nameMatchesAliases(rawName, aliases)
    local normalizedName = normalizeText(rawName)
    for _, alias in ipairs(aliases) do
        local normalizedAlias = normalizeText(alias)
        if normalizedAlias ~= "" and string.find(normalizedName, normalizedAlias, 1, true) then
            return true
        end
    end
    return false
end

local function isRemoteLike(instance)
    return instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("BindableEvent") or instance:IsA("BindableFunction")
end

local function triggerRemote(instance)
    if instance:IsA("RemoteEvent") then
        local ok = pcall(function() instance:FireServer() end)
        if ok then return true, "RemoteEvent" end
    elseif instance:IsA("RemoteFunction") then
        local ok = pcall(function() instance:InvokeServer() end)
        if ok then return true, "RemoteFunction" end
    elseif instance:IsA("BindableEvent") then
        local ok = pcall(function() instance:Fire() end)
        if ok then return true, "BindableEvent" end
    elseif instance:IsA("BindableFunction") then
        local ok = pcall(function() instance:Invoke() end)
        if ok then return true, "BindableFunction" end
    end
    return false, "none"
end

local function triggerPrompt(instance)
    if type(fireproximityprompt) ~= "function" then
        return false
    end

    local prompt = instance:IsA("ProximityPrompt") and instance or instance:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then
        return false
    end

    local ok = pcall(function()
        fireproximityprompt(prompt)
    end)
    return ok
end

local function triggerClick(instance)
    if type(fireclickdetector) ~= "function" then
        return false
    end

    local click = instance:IsA("ClickDetector") and instance or instance:FindFirstChildWhichIsA("ClickDetector", true)
    if not click then
        return false
    end

    local ok = pcall(function()
        fireclickdetector(click)
    end)
    return ok
end

local function triggerTouch(instance)
    if type(firetouchinterest) ~= "function" then
        return false
    end

    local root = select(1, getRootAndHumanoid())
    local part = getPart(instance)
    if not root or not part then
        return false
    end

    local ok = pcall(function()
        firetouchinterest(root, part, 0)
        task.wait(0.05)
        firetouchinterest(root, part, 1)
    end)
    return ok
end

triggerFromInstance = function(instance)
    if not instance then
        return false, "none"
    end

    if isRemoteLike(instance) then
        local ok, method = triggerRemote(instance)
        if ok then
            return true, method
        end
    end

    for _, d in ipairs(instance:GetDescendants()) do
        if isRemoteLike(d) then
            local ok, method = triggerRemote(d)
            if ok then
                return true, method
            end
        end
    end

    if triggerPrompt(instance) then
        return true, "ProximityPrompt"
    end

    if triggerClick(instance) then
        return true, "ClickDetector"
    end

    if triggerTouch(instance) then
        return true, "Touch"
    end

    return false, "none"
end

local function getNearestAliasObject(aliases, maxDistance)
    local normalizedAliases = normalizeAliases(aliases)
    if #normalizedAliases == 0 then
        return nil
    end

    local root = select(1, getRootAndHumanoid())
    local rootPos = root and root.Position or nil
    local bestObj = nil
    local bestDist = math.huge

    local function considerObject(obj)
        local part = getPart(obj)
        if not part then
            return
        end

        local dist = 0
        if rootPos then
            dist = (rootPos - part.Position).Magnitude
            if maxDistance and dist > maxDistance then
                return
            end
        end

        if dist < bestDist then
            bestDist = dist
            bestObj = obj
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local normalizedName = normalizeText(obj.Name)
            for _, alias in ipairs(normalizedAliases) do
                if string.find(normalizedName, alias, 1, true) then
                    considerObject(obj)
                    break
                end
            end
        elseif (obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector")) and obj.Parent then
            local normalizedName = normalizeText(obj.Parent.Name)
            for _, alias in ipairs(normalizedAliases) do
                if string.find(normalizedName, alias, 1, true) then
                    considerObject(obj.Parent)
                    break
                end
            end
        end
    end

    return bestObj
end

local function tryTriggerByAliases(aliases, maxDistance)
    local obj = getNearestAliasObject(aliases, maxDistance)
    if not obj then
        return false, "not found"
    end
    return triggerFromInstance(obj)
end

local function findToolInInventoryByAliases(aliases)
    local containers = {}
    local character = getCharacter()
    if character then
        table.insert(containers, character)
    end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        table.insert(containers, backpack)
    end

    for _, container in ipairs(containers) do
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") and nameMatchesAliases(child.Name, aliases) then
                return child
            end
        end
    end
    return nil
end

useMaterialOnce = function(material)
    if not material then
        return false, "invalid"
    end

    local aliases = material.aliases or {}
    local itemLabel = material.label or material.key

    if Settings.UseRemotes then
        if callRemoteByAliases(aliases, itemLabel) then
            return true, "remote:item"
        end
        if callRemoteByAliases({ "useitem", "consume", "inventoryitem", "itemuse" }, itemLabel) then
            return true, "remote:useitem"
        end
        if callRemoteByAliases({ "use", "consume" }, itemLabel, 1) then
            return true, "remote:consume"
        end
    end

    local tool = findToolInInventoryByAliases(aliases)
    if tool then
        local ok = pcall(function()
            if tool.Parent ~= getCharacter() then
                tool.Parent = getCharacter()
            end
            tool:Activate()
        end)
        if ok then
            return true, "tool:activate"
        end
    end

    local okTrigger, method = tryTriggerByAliases(aliases, 45)
    if okTrigger then
        return true, "trigger:" .. tostring(method)
    end

    return false, "not found/blocked"
end

tryPlanterAction = function(mode, targetField)
    mode = tostring(mode or "Plant")
    targetField = tostring(targetField or safePlantFieldName())

    local didRemote = false
    if Settings.UseRemotes then
        if mode == "Harvest" then
            didRemote = callRemoteByAliases({ "planter", "harvest", "collectplanter", "plantercollect" }, targetField)
                or callRemoteByAliases({ "planter", "harvest", "collectplanter", "plantercollect" }, "All")
        else
            didRemote = callRemoteByAliases({ "planter", "plant", "placeplanter", "spawnplanter" }, targetField)
                or callRemoteByAliases({ "planter", "plant", "placeplanter", "spawnplanter" }, "Paper Planter", targetField)
                or callRemoteByAliases({ "planter", "plant", "placeplanter", "spawnplanter" }, "Plastic Planter", targetField)
                or callRemoteByAliases({ "planter", "plant", "placeplanter", "spawnplanter" }, targetField, "Paper Planter")
        end
    end

    if didRemote then
        return true, "remote"
    end

    if Settings.PlanterTriggerFallback then
        local aliases = mode == "Harvest"
            and { "planter", "harvest", "collect", "sprout" }
            or { "planter", "plant", "place", "shop" }
        local okTrigger, method = tryTriggerByAliases(aliases, 65)
        if okTrigger then
            return true, tostring(method)
        end
    end

    return false, "not found"
end

local function toyRoots()
    local roots = {}
    local wEvents = workspace:FindFirstChild("Events")
    local rEvents = ReplicatedStorage:FindFirstChild("Events")
    if wEvents then table.insert(roots, wEvents) end
    if rEvents then table.insert(roots, rEvents) end
    table.insert(roots, workspace)
    table.insert(roots, ReplicatedStorage)
    return roots
end

local function findToyRemote(toy)
    local cached = toyCache[toy.key]
    if cached and cached.remote and cached.remote.Parent then
        return cached.remote
    end

    for _, root in ipairs(toyRoots()) do
        for _, d in ipairs(root:GetDescendants()) do
            if isRemoteLike(d) and nameMatchesAliases(d.Name, toy.aliases) then
                toyCache[toy.key] = toyCache[toy.key] or {}
                toyCache[toy.key].remote = d
                return d
            end
        end
    end

    return nil
end

local function findToyObject(toy)
    local cached = toyCache[toy.key]
    if cached and cached.obj and cached.obj.Parent then
        return cached.obj
    end

    for _, d in ipairs(workspace:GetDescendants()) do
        local valid = d:IsA("Model") or d:IsA("BasePart")
        if valid and nameMatchesAliases(d.Name, toy.aliases) then
            toyCache[toy.key] = toyCache[toy.key] or {}
            toyCache[toy.key].obj = d
            return d
        end
    end

    for _, d in ipairs(workspace:GetDescendants()) do
        if (d:IsA("ProximityPrompt") or d:IsA("ClickDetector")) and d.Parent then
            if nameMatchesAliases(d.Parent.Name, toy.aliases) then
                toyCache[toy.key] = toyCache[toy.key] or {}
                toyCache[toy.key].obj = d.Parent
                return d.Parent
            end
        end
    end

    return nil
end

local function useToy(toy)
    if Settings.UseRemotes then
        if callRemoteByAliases(toy.aliases, "Use") or callRemoteByAliases(toy.aliases) then
            return true, "remote:aliases"
        end
    end

    local remote = findToyRemote(toy)
    if remote then
        local ok, method = triggerRemote(remote)
        if ok then
            return true, "remote:" .. method
        end
    end

    local obj = findToyObject(toy)
    if obj then
        if Settings.ToyTweenToTarget then
            local cf = getCFrame(obj)
            if cf then
                tweenTo(cf * CFrame.new(0, 3, 0), getActiveTweenSpeed())
            end
        end

        local ok, method = triggerFromInstance(obj)
        if ok then
            return true, method
        end
    end

    return false, "not found/blocked"
end

local function runToyLoop(updateStatus)
    if toyLoopRunning then
        return
    end
    toyLoopRunning = true

    while Settings.AutoUseToys do
        if isAtlasPaused() then
            task.wait(0.2)
            continue
        end

        local now = os.clock()
        local usedAny = false

        for _, toy in ipairs(TOYS) do
            if not Settings.AutoUseToys then
                break
            end

            local enabledKey = toySettingKey(toy)
            if Settings[enabledKey] then
                local lastUse = toyUseTracker[toy.key] or 0
                if (now - lastUse) >= math.max(20, Settings.ToyLoopDelay) then
                    local ok, method = useToy(toy)
                    toyUseTracker[toy.key] = os.clock()
                    usedAny = true
                    if updateStatus then
                        if ok then
                            updateStatus("Toy: " .. toy.label .. " via " .. method)
                        else
                            updateStatus("Toy failed: " .. toy.label .. " (" .. method .. ")")
                        end
                    end
                    task.wait(0.5)
                end
            end
        end

        if not usedAny and updateStatus then
            updateStatus("Toy loop idle")
        end

        task.wait(1)
    end

    toyLoopRunning = false
end

local function backupAndSet(instance, prop, newValue)
    local okGet, oldValue = pcall(function()
        return instance[prop]
    end)
    if not okGet then
        return false
    end

    antiLagBackups[instance] = antiLagBackups[instance] or {}
    if antiLagBackups[instance][prop] == nil then
        antiLagBackups[instance][prop] = oldValue
    end

    local okSet = pcall(function()
        instance[prop] = newValue
    end)
    return okSet
end

local function clearAntiLagConnections()
    for i = #antiLagConnections, 1, -1 do
        local connection = antiLagConnections[i]
        antiLagConnections[i] = nil
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
    end
end

local function trackAntiLagConnection(connection)
    if connection then
        table.insert(antiLagConnections, connection)
    end
end

local function shouldHideBssGui(gui)
    local n = normalizeText(gui.Name)
    return not string.find(n, "kavo", 1, true) and not string.find(n, "ichiger", 1, true)
end

local function applyAntiLagToInstance(d)
    if not d or not d.Parent then
        return
    end

    if Settings.AntiLagParticles and EFFECT_CLASSES[d.ClassName] then
        backupAndSet(d, "Enabled", false)
    end

    if Settings.AntiLagTextures and (d:IsA("Decal") or d:IsA("Texture")) then
        backupAndSet(d, "Transparency", 1)
    end

    if d:IsA("ScreenGui") and Settings.HideBssUI and shouldHideBssGui(d) then
        backupAndSet(d, "Enabled", false)
    end

    if not d:IsA("BasePart") then
        return
    end

    if Settings.AntiLagShadows then
        backupAndSet(d, "CastShadow", false)
    end

    local normalizedName = normalizeText(d.Name)
    if Settings.HidePreciseTargets and string.find(normalizedName, "precise", 1, true) then
        backupAndSet(d, "Transparency", 1)
    end
    if Settings.HideMarks and string.find(normalizedName, "mark", 1, true) then
        backupAndSet(d, "Transparency", 1)
    end
    if Settings.HideDupedTokens and string.find(normalizedName, "dupe", 1, true) then
        backupAndSet(d, "Transparency", 1)
    end
    if Settings.DestroyBalloons and string.find(normalizedName, "balloon", 1, true) then
        backupAndSet(d, "Transparency", 1)
        backupAndSet(d, "CanCollide", false)
    end
    if Settings.DestroyDecorations then
        if string.find(normalizedName, "tree", 1, true)
            or string.find(normalizedName, "bush", 1, true)
            or string.find(normalizedName, "rock", 1, true)
            or string.find(normalizedName, "deco", 1, true)
        then
            backupAndSet(d, "Transparency", 1)
            backupAndSet(d, "CanCollide", false)
        end
    end

    if Settings.HideTokens then
        local collectibles = getCollectiblesFolder()
        if collectibles and d:IsDescendantOf(collectibles) then
            backupAndSet(d, "Transparency", 1)
            backupAndSet(d, "CanCollide", false)
        end
    end

    if Settings.HideFlowers then
        local flowers = workspace:FindFirstChild("Flowers") or workspace:FindFirstChild("FlowerZones")
        if flowers and d:IsDescendantOf(flowers) then
            backupAndSet(d, "Transparency", 1)
        end
    end

    if Settings.HideBees then
        local model = d:FindFirstAncestorOfClass("Model")
        if model and string.find(normalizeText(model.Name), "bee", 1, true) then
            backupAndSet(d, "Transparency", 1)
        end
    end

    if Settings.HideOtherPlayers then
        local characterModel = d:FindFirstAncestorOfClass("Model")
        local owner = characterModel and Players:GetPlayerFromCharacter(characterModel)
        if owner and owner ~= LocalPlayer then
            backupAndSet(d, "LocalTransparencyModifier", 1)
        end
    end
end

local function applyAntiLagGlobalState()
    if Settings.Disable3DRendering then
        pcall(function()
            RunService:Set3dRenderingEnabled(false)
        end)
    else
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
    end

    if Settings.AntiLagLighting then
        backupAndSet(Lighting, "GlobalShadows", false)
        backupAndSet(Lighting, "FogEnd", 100000)
        backupAndSet(Lighting, "Brightness", 1)

        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            backupAndSet(terrain, "WaterWaveSize", 0)
            backupAndSet(terrain, "WaterWaveSpeed", 0)
            backupAndSet(terrain, "WaterReflectance", 0)
            backupAndSet(terrain, "WaterTransparency", 1)
        end
    end
end

local function applyAntiLagPass()
    applyAntiLagGlobalState()

    for _, d in ipairs(workspace:GetDescendants()) do
        applyAntiLagToInstance(d)
    end

    if Settings.HideBssUI then
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, gui in ipairs(playerGui:GetDescendants()) do
                applyAntiLagToInstance(gui)
            end
        end
    end
end

local function requestAntiLagReapply()
    if Settings.AntiLagEnabled then
        antiLagDirty = true
    end
end

local function restoreAntiLag()
    clearAntiLagConnections()
    for instance, props in pairs(antiLagBackups) do
        if instance and instance.Parent then
            for prop, oldValue in pairs(props) do
                pcall(function()
                    instance[prop] = oldValue
                end)
            end
        end
    end
    antiLagBackups = setmetatable({}, { __mode = "k" })
    pcall(function()
        RunService:Set3dRenderingEnabled(true)
    end)
    antiLagDirty = false
    antiLagOneTimeApplied = false
end

local function setupAntiLagEventHooks()
    clearAntiLagConnections()

    trackAntiLagConnection(workspace.DescendantAdded:Connect(function(descendant)
        if not Settings.AntiLagEnabled then
            return
        end
        task.defer(function()
            applyAntiLagToInstance(descendant)
        end)
    end))

    local function hookCharacter(character)
        if not character or not Settings.AntiLagEnabled then
            return
        end
        task.defer(function()
            for _, d in ipairs(character:GetDescendants()) do
                applyAntiLagToInstance(d)
            end
        end)
    end

    local function hookPlayer(player)
        if not player or player == LocalPlayer then
            return
        end
        if player.Character then
            hookCharacter(player.Character)
        end
        trackAntiLagConnection(player.CharacterAdded:Connect(hookCharacter))
    end

    for _, player in ipairs(Players:GetPlayers()) do
        hookPlayer(player)
    end
    trackAntiLagConnection(Players.PlayerAdded:Connect(hookPlayer))

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        trackAntiLagConnection(playerGui.DescendantAdded:Connect(function(descendant)
            if not Settings.AntiLagEnabled then
                return
            end
            task.defer(function()
                applyAntiLagToInstance(descendant)
            end)
        end))
    end
end

local function runAntiLagLoop(updateStatus)
    if antiLagLoopRunning then
        return
    end
    antiLagLoopRunning = true

    setupAntiLagEventHooks()
    antiLagDirty = true

    while Settings.AntiLagEnabled do
        if isAtlasPaused() then
            task.wait(0.3)
            continue
        end

        if antiLagDirty or not antiLagOneTimeApplied then
            applyAntiLagPass()
            antiLagDirty = false
            antiLagOneTimeApplied = true
            if updateStatus then
                updateStatus("AntiLag applied (event mode)")
            end
        end

        task.wait(0.4)
    end

    clearAntiLagConnections()
    antiLagDirty = false
    antiLagOneTimeApplied = false
    antiLagLoopRunning = false
end

local function collectTokenNames()
    local collectibles = getCollectiblesFolder()
    local map = {}

    if collectibles then
        for _, d in ipairs(collectibles:GetDescendants()) do
            local valid = d:IsA("BasePart") or d:IsA("Model") or d:IsA("Attachment")
            if valid then
                map[d.Name] = true
            end
        end
    end

    local names = {}
    for name in pairs(map) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

local function scanTokenNames()
    local names = collectTokenNames()

    print("[ICHIGER] Token scan found " .. tostring(#names) .. " names")
    for _, name in ipairs(names) do
        print(" - " .. name)
    end

    if type(setclipboard) == "function" then
        pcall(function()
            setclipboard(table.concat(names, "\n"))
        end)
    end

    return names
end

local function hasConfigFileApi()
    return type(isfolder) == "function"
        and type(makefolder) == "function"
        and type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"
end

local function cloneConfigValue(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for k, v in pairs(value) do
        out[k] = cloneConfigValue(v)
    end
    return out
end

local function configValuesEqual(a, b)
    if type(a) ~= type(b) then
        return false
    end

    if type(a) ~= "table" then
        return a == b
    end

    for k, v in pairs(a) do
        if not configValuesEqual(v, b[k]) then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

local function normalizeProfileName(profileName)
    local raw = tostring(profileName or "main")
    raw = string.lower(raw)
    raw = raw:gsub("%s+", "_")
    raw = raw:gsub("[^%w_%-]", "")
    raw = raw:gsub("_+", "_")
    if raw == "" then
        raw = "main"
    end
    return string.sub(raw, 1, 32)
end

local function appendUniquePath(paths, path)
    for _, existing in ipairs(paths) do
        if existing == path then
            return
        end
    end
    table.insert(paths, path)
end

local function getConfigFilePathCandidates(profileName)
    local normalized = normalizeProfileName(profileName)
    local paths = {}
    appendUniquePath(paths, CONFIG_FOLDER_NAME .. "/" .. CONFIG_PRIMARY_BASENAME .. "_" .. normalized .. ".json")
    appendUniquePath(paths, CONFIG_FOLDER_NAME .. "/" .. CONFIG_PLACE_BASENAME .. "_" .. normalized .. ".json")
    return paths, normalized
end

local function getConfigFilePath(profileName)
    local paths, normalized = getConfigFilePathCandidates(profileName)
    return paths[1], normalized
end

local function ensureConfigFolder()
    if not hasConfigFileApi() then
        return false, "Executor has no file API"
    end

    local okFolder = pcall(function()
        if not isfolder(CONFIG_FOLDER_NAME) then
            makefolder(CONFIG_FOLDER_NAME)
        end
    end)
    if not okFolder then
        return false, "Cannot access config folder"
    end
    return true
end

local function saveConfigMetaProfile(profileName)
    local okFolder, msg = ensureConfigFolder()
    if not okFolder then
        return false, msg
    end

    local payload = {
        version = 1,
        profile = normalizeProfileName(profileName),
    }

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        return false, "Meta encode failed"
    end

    local wroteAny = false
    for _, metaPath in ipairs(CONFIG_META_PATHS) do
        local okWrite = pcall(function()
            writefile(metaPath, encoded)
        end)
        wroteAny = wroteAny or okWrite
    end
    if not wroteAny then
        return false, "Meta write failed"
    end

    return true
end

local function loadConfigMetaProfile()
    local okFolder = ensureConfigFolder()
    if not okFolder then
        return false
    end

    for _, metaPath in ipairs(CONFIG_META_PATHS) do
        if isfile(metaPath) then
            local okRead, raw = pcall(function()
                return readfile(metaPath)
            end)
            if okRead then
                local okDecode, payload = pcall(function()
                    return HttpService:JSONDecode(raw)
                end)
                if okDecode and type(payload) == "table" and payload.profile ~= nil then
                    Settings.ConfigProfile = normalizeProfileName(payload.profile)
                    return true
                end
            end
        end
    end

    return false
end

local function colorToArray(color)
    return {
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5),
    }
end

local function arrayToColor(value)
    if type(value) ~= "table" then
        return nil
    end
    local r = tonumber(value[1])
    local g = tonumber(value[2])
    local b = tonumber(value[3])
    if not r or not g or not b then
        return nil
    end
    return Color3.fromRGB(
        math.clamp(math.floor(r + 0.5), 0, 255),
        math.clamp(math.floor(g + 0.5), 0, 255),
        math.clamp(math.floor(b + 0.5), 0, 255)
    )
end

local function captureConfigData(includeMeta)
    local payload = {
        version = 2,
        userId = LocalPlayer.UserId,
        placeId = game.PlaceId,
        gameId = game.GameId,
        profile = normalizeProfileName(Settings.ConfigProfile),
        script = "ICHIGER",
        settings = {},
        toys = {},
        theme = {},
    }

    if includeMeta ~= false then
        payload.savedAtUnix = os.time()
        payload.savedAtISO = os.date("!%Y-%m-%dT%H:%M:%SZ")
    end

    for key in pairs(DEFAULT) do
        payload.settings[key] = Settings[key]
    end

    for _, toy in ipairs(TOYS) do
        local key = toySettingKey(toy)
        payload.toys[key] = Settings[key] and true or false
    end

    for themeKey, color in pairs(UITheme) do
        payload.theme[themeKey] = colorToArray(color)
    end

    return payload
end

local function normalizeConfigValues()
    Settings.TweenSoftness = math.clamp(tonumber(Settings.TweenSoftness) or 70, 0, 100)
    Settings.ConfigAutoSaveDelay = math.clamp(tonumber(Settings.ConfigAutoSaveDelay) or 10, 5, 120)
    Settings.SprinklerInterval = math.clamp(tonumber(Settings.SprinklerInterval) or 12, 3, 60)
    Settings.MaterialsLoopDelay = math.clamp(tonumber(Settings.MaterialsLoopDelay) or 120, 10, 900)
    Settings.WaitBeforeConverting = math.clamp(tonumber(Settings.WaitBeforeConverting) or 0, 0, 25)
    Settings.CombatRadius = math.clamp(tonumber(Settings.CombatRadius) or 220, 40, 600)
    Settings.ViciousMinLevel = math.clamp(tonumber(Settings.ViciousMinLevel) or 1, 1, 20)
    Settings.ViciousMaxLevel = math.clamp(tonumber(Settings.ViciousMaxLevel) or 20, 1, 20)
    Settings.WindyMinLevel = math.clamp(tonumber(Settings.WindyMinLevel) or 1, 1, 20)
    Settings.WindyMaxLevel = math.clamp(tonumber(Settings.WindyMaxLevel) or 20, 1, 20)
    Settings.WebhookIntervalMinutes = math.clamp(tonumber(Settings.WebhookIntervalMinutes) or 5, 1, 120)
    Settings.PlanterLoopDelay = math.clamp(tonumber(Settings.PlanterLoopDelay) or 60, 8, 300)
    Settings.RBCLoopDelay = math.clamp(tonumber(Settings.RBCLoopDelay) or 8, 3, 90)
    Settings.AutoRejoinDelay = math.clamp(tonumber(Settings.AutoRejoinDelay) or 6, 2, 30)
    Settings.ConfigProfile = normalizeProfileName(Settings.ConfigProfile)
    if not table.find(MOVEMENT_METHODS, Settings.MovementMethod) then
        Settings.MovementMethod = MOVEMENT_METHODS[1]
    end
    if not table.find(SPRINKLER_TYPES, Settings.SprinklerType) then
        Settings.SprinklerType = SPRINKLER_TYPES[1]
    end
    if not table.find(DIG_METHODS, Settings.AutoDigMethod) then
        Settings.AutoDigMethod = DIG_METHODS[1]
    end
    if not table.find(PLANTER_FIELDS, Settings.PlanterAllowedField) then
        Settings.PlanterAllowedField = PLANTER_FIELDS[1]
    end
    if not table.find(RARES_LIST, Settings.RaresList) then
        Settings.RaresList = RARES_LIST[1]
    end
    if not table.find(FACE_METHODS, Settings.FaceMethod) then
        Settings.FaceMethod = FACE_METHODS[1]
    end
    if not table.find(SHIFT_DIRECTIONS, Settings.ShiftLockDirection) then
        Settings.ShiftLockDirection = SHIFT_DIRECTIONS[1]
    end
    if not table.find(FIELD_POSITIONS, Settings.FieldPosition) then
        Settings.FieldPosition = FIELD_POSITIONS[1]
    end
    if not table.find(INSTANT_CONVERT_TYPES, Settings.InstantConvertType) then
        Settings.InstantConvertType = INSTANT_CONVERT_TYPES[1]
    end
    if not table.find(MASK_NAMES, Settings.DefaultMask) then
        Settings.DefaultMask = MASK_NAMES[2]
    end
    if not table.find(TOY_NAMES, Settings.SelectedToy) then
        Settings.SelectedToy = TOY_NAMES[1]
    end
end

local function applyConfigData(payload)
    if type(payload) ~= "table" then
        return false, "Invalid config payload"
    end

    if type(payload.settings) == "table" then
        for key in pairs(DEFAULT) do
            if payload.settings[key] ~= nil then
                Settings[key] = payload.settings[key]
            end
        end
    end

    if type(payload.toys) == "table" then
        for _, toy in ipairs(TOYS) do
            local key = toySettingKey(toy)
            if payload.toys[key] ~= nil then
                Settings[key] = payload.toys[key]
            end
        end
    end

    if type(payload.theme) == "table" then
        for themeKey in pairs(UITheme) do
            local converted = arrayToColor(payload.theme[themeKey])
            if converted then
                UITheme[themeKey] = converted
            end
        end
    end

    normalizeConfigValues()
    return true, "Config applied"
end

local function saveConfigToFile(profileName, forceWrite)
    local okFolder, msg = ensureConfigFolder()
    if not okFolder then
        return false, msg
    end

    local paths, normalizedProfile = getConfigFilePathCandidates(profileName or Settings.ConfigProfile)
    local path = paths[1]
    Settings.ConfigProfile = normalizedProfile

    local comparePayload = captureConfigData(false)
    comparePayload.profile = normalizedProfile

    if Settings.ConfigOnlyIfChanged and not forceWrite and configValuesEqual(configWriteCache[path], comparePayload) then
        return true, "No changes"
    end

    local payload = captureConfigData(true)
    payload.profile = normalizedProfile

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        return false, "JSON encode failed"
    end

    local wroteAny = false
    for _, writePath in ipairs(paths) do
        if Settings.ConfigSaveBackup and isfile(writePath) then
            pcall(function()
                local oldRaw = readfile(writePath)
                writefile(writePath .. ".bak", oldRaw)
            end)
        end

        local okWrite = pcall(function()
            writefile(writePath, encoded)
        end)
        if okWrite then
            configWriteCache[writePath] = cloneConfigValue(comparePayload)
            wroteAny = true
        end
    end

    if not wroteAny then
        return false, "Write failed"
    end

    pcall(function()
        saveConfigMetaProfile(normalizedProfile)
    end)

    return true, "Saved (" .. normalizedProfile .. ")"
end

local function loadConfigFromFile(profileName)
    local okFolder, msg = ensureConfigFolder()
    if not okFolder then
        return false, msg
    end

    local paths, normalizedProfile = getConfigFilePathCandidates(profileName or Settings.ConfigProfile)
    local path = nil
    local sourceWasFallback = false

    for _, candidatePath in ipairs(paths) do
        if isfile(candidatePath) then
            path = candidatePath
            break
        end
    end

    if not path and normalizedProfile == "main" then
        for _, legacyPath in ipairs(CONFIG_LEGACY_PATHS) do
            if isfile(legacyPath) then
                path = legacyPath
                sourceWasFallback = true
                break
            end
        end
    end

    if not path then
        return false, "No config for profile: " .. normalizedProfile
    end

    if path ~= paths[1] then
        sourceWasFallback = true
    end

    local okRead, raw = pcall(function()
        return readfile(path)
    end)
    if not okRead then
        return false, "Read failed"
    end

    local okDecode, payload = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode then
        if isfile(path .. ".bak") then
            local okBakRead, bakRaw = pcall(function()
                return readfile(path .. ".bak")
            end)
            if okBakRead then
                okDecode, payload = pcall(function()
                    return HttpService:JSONDecode(bakRaw)
                end)
                if okDecode then
                    raw = bakRaw
                end
            end
        end
    end
    if not okDecode then
        return false, "JSON decode failed"
    end

    local okApply, applyMsg = applyConfigData(payload)
    if not okApply then
        return false, applyMsg
    end

    Settings.ConfigProfile = normalizedProfile
    local comparePayload = captureConfigData(false)
    comparePayload.profile = normalizedProfile
    for _, cachePath in ipairs(paths) do
        configWriteCache[cachePath] = cloneConfigValue(comparePayload)
    end
    pcall(function()
        saveConfigMetaProfile(normalizedProfile)
    end)
    if sourceWasFallback then
        pcall(function()
            saveConfigToFile(normalizedProfile, true)
        end)
    end

    return true, "Loaded (" .. normalizedProfile .. ")"
end

local function loadBackupConfigFromFile(profileName)
    local okFolder, msg = ensureConfigFolder()
    if not okFolder then
        return false, msg
    end

    local paths, normalizedProfile = getConfigFilePathCandidates(profileName or Settings.ConfigProfile)
    local backupPath = nil
    local sourcePath = nil

    for _, candidatePath in ipairs(paths) do
        local candidateBackup = candidatePath .. ".bak"
        if isfile(candidateBackup) then
            backupPath = candidateBackup
            sourcePath = candidatePath
            break
        end
    end

    if not backupPath and normalizedProfile == "main" then
        for _, legacyPath in ipairs(CONFIG_LEGACY_PATHS) do
            local legacyBackup = legacyPath .. ".bak"
            if isfile(legacyBackup) then
                backupPath = legacyBackup
                sourcePath = legacyPath
                break
            end
        end
    end

    if not backupPath then
        return false, "No backup for profile: " .. normalizedProfile
    end

    local okRead, raw = pcall(function()
        return readfile(backupPath)
    end)
    if not okRead then
        return false, "Backup read failed"
    end

    local okDecode, payload = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode then
        return false, "Backup JSON decode failed"
    end

    local okApply, applyMsg = applyConfigData(payload)
    if not okApply then
        return false, applyMsg
    end

    Settings.ConfigProfile = normalizedProfile
    local comparePayload = captureConfigData(false)
    comparePayload.profile = normalizedProfile
    for _, cachePath in ipairs(paths) do
        configWriteCache[cachePath] = cloneConfigValue(comparePayload)
    end
    pcall(function()
        saveConfigMetaProfile(normalizedProfile)
    end)
    if sourcePath and sourcePath ~= paths[1] then
        pcall(function()
            saveConfigToFile(normalizedProfile, true)
        end)
    end
    return true, "Backup loaded (" .. normalizedProfile .. ")"
end

local function deleteConfigFile(profileName)
    local okFolder, msg = ensureConfigFolder()
    if not okFolder then
        return false, msg
    end

    if type(delfile) ~= "function" then
        return false, "Executor has no delfile"
    end

    local paths, normalizedProfile = getConfigFilePathCandidates(profileName or Settings.ConfigProfile)
    local deleteTargets = {}
    for _, path in ipairs(paths) do
        appendUniquePath(deleteTargets, path)
    end
    if normalizedProfile == "main" then
        for _, legacyPath in ipairs(CONFIG_LEGACY_PATHS) do
            appendUniquePath(deleteTargets, legacyPath)
        end
    end

    local deletedAny = false
    for _, path in ipairs(deleteTargets) do
        if isfile(path) then
            local okDel = pcall(function()
                delfile(path)
            end)
            deletedAny = deletedAny or okDel
        end
        if isfile(path .. ".bak") then
            local okBakDel = pcall(function()
                delfile(path .. ".bak")
            end)
            deletedAny = deletedAny or okBakDel
        end
        configWriteCache[path] = nil
    end

    if deletedAny then
        return true, "Deleted (" .. normalizedProfile .. ")"
    end
    return false, "No file to delete"
end

local function exportConfigToClipboard()
    if type(setclipboard) ~= "function" then
        return false, "Clipboard export not supported"
    end

    local payload = captureConfigData()
    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        return false, "JSON encode failed"
    end

    local okSet = pcall(function()
        setclipboard(encoded)
    end)
    if not okSet then
        return false, "Clipboard write failed"
    end

    return true, "Exported to clipboard"
end

local function importConfigFromClipboard()
    if type(getclipboard) ~= "function" then
        return false, "Clipboard import not supported"
    end

    local okGet, raw = pcall(function()
        return getclipboard()
    end)
    if not okGet or type(raw) ~= "string" or raw == "" then
        return false, "Clipboard empty"
    end

    local okDecode, payload = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode then
        return false, "Clipboard JSON invalid"
    end

    local okApply, msg = applyConfigData(payload)
    if not okApply then
        return false, msg
    end

    if payload.profile ~= nil then
        Settings.ConfigProfile = normalizeProfileName(payload.profile)
    end

    normalizeConfigValues()
    return true, "Imported from clipboard"
end

normalizeConfigValues()
Settings.ConfigAutoSave = false
Settings.ConfigAutoLoad = false
local initialConfigMessage = "Config system disabled"

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    applyWalkSpeed()
end)

local Window = Library.CreateLib("ICHIGER v1.0", UITheme)

do
local MainTab = Window:NewTab("Home")
local MainControl = MainTab:NewSection("Home")
local MainTravel = MainTab:NewSection("Navigation")
local MainUI = MainTab:NewSection("UI")
local MainPerf = MainTab:NewSection("Anti Lag Quick")

MainControl:NewLabel("Stop Macro = ON, everything pauses")

MainControl:NewToggle("Stop Macro", "Pause all loops immediately", function(state)
    Settings.ScriptStopped = state
    if state then
        stopMovement()
    end
end)

MainControl:NewButton("Stop Now", "Stop autofarm and movement", function()
    Settings.AutoFarm = false
    stopMovement()
end)

MainTravel:NewButton("Go To Hive", "Move to hive once", function()
    local hive = getHiveCFrame()
    if hive then
        tweenTo(hive, getActiveTweenSpeed())
    end
end)

MainTravel:NewButton("Force Convert", "Try all hive convert triggers now", function()
    local hive = getSpawnPadCFrame() or getHiveCFrame()
    if hive then
        tweenTo(hive, getActiveTweenSpeed())
        tryActivateHiveConversion(hive)
    end
end)

MainTravel:NewButton("Go To Field", "Walk to selected field once", function()
    local field = getFieldCFrame(Settings.FieldName)
    if field then
        local root = select(1, getRootAndHumanoid())
        local target = field.Position
        if root then
            target = Vector3.new(field.Position.X, root.Position.Y, field.Position.Z)
        end
        applyWalkSpeed()
        walkTo(target, 6, 8)
    end
end)

MainUI:NewKeybind("Toggle UI", "Show/hide the UI", Enum.KeyCode.RightControl, function()
    Library:ToggleUI()
end)

MainPerf:NewToggle("Anti Lag", "Enable or disable anti-lag", function(state)
    Settings.AntiLagEnabled = state
    if state then
        task.spawn(function()
            runAntiLagLoop(setDebugStatus)
        end)
    else
        restoreAntiLag()
    end
end)

MainPerf:NewToggle("Hide Tokens", "Hide token visuals for FPS", function(state)
    Settings.HideTokens = state
    requestAntiLagReapply()
end)

MainPerf:NewToggle("Disable 3D Rendering", "Max FPS mode", function(state)
    Settings.Disable3DRendering = state
    requestAntiLagReapply()
end)

MainPerf:NewButton("Apply Anti Lag Now", "Run anti-lag pass instantly", function()
    applyAntiLagPass()
    antiLagOneTimeApplied = true
    antiLagDirty = false
end)

MainPerf:NewButton("Restore Visuals", "Restore visual changes", function()
    Settings.AntiLagEnabled = false
    restoreAntiLag()
end)

end

do
local FarmTab = Window:NewTab("Farming")
local FarmSection = FarmTab:NewSection("Field + Hive")

FarmSection:NewLabel("Farming is locked to selected field only")

FarmSection:NewDropdown("Field", "Select farming field", FIELDS, function(value)
    Settings.FieldName = value
end)

FarmSection:NewToggle("Autofarm", "Main farming loop", function(state)
    Settings.AutoFarm = state
    if state then
        task.spawn(runAutoFarm)
    end
end)

FarmSection:NewToggle("Auto Sprinkler", "Auto place sprinklers", function(state)
    Settings.AutoSprinkler = state
end)

FarmSection:NewToggle("Auto Dig", "Auto tool activate", function(state)
    Settings.AutoDig = state
end)

FarmSection:NewToggle("Return To Hive", "Return to hive when bag is full", function(state)
    Settings.ReturnToHive = state
end)

FarmSection:NewSlider("Bag Percent", "Hive threshold", 100, 70, function(value)
    Settings.HiveBagPercent = value
end)

FarmSection:NewSlider("Hive Wait Seconds", "Time waiting at hive", 90, 5, function(value)
    Settings.HiveWaitSeconds = value
end)

FarmSection:NewSlider("Sprinkler Interval", "Seconds between auto sprinkler", 60, 3, function(value)
    Settings.SprinklerInterval = value
end)

local FarmAdvanced = FarmTab:NewSection("Farm Settings")
local ConvertSection = FarmTab:NewSection("Convert Settings")
local FaceSection = FarmTab:NewSection("Face Settings")

FarmAdvanced:NewToggle("Auto Pop Star", "Prioritize Pop Star logic", function(state)
    Settings.AutoPopStar = state
    Settings.TokenPopStar = state
end)

FarmAdvanced:NewToggle("Auto Scorching Star", "Support Scorching Star", function(state)
    Settings.AutoScorchingStar = state
end)

FarmAdvanced:NewToggle("Auto Gummy Star", "Support Gummy Star", function(state)
    Settings.AutoGummyStar = state
end)

FarmAdvanced:NewToggle("Farm Bubbles", "Prioritize bubble-style tokens", function(state)
    Settings.FarmBubbles = state
    Settings.TokenBubble = state
end)

FarmAdvanced:NewToggle("Farm Marks", "Prioritize marks and target tokens", function(state)
    Settings.TokenMarks = state
end)

FarmAdvanced:NewToggle("Farm Precise", "Prioritize precise tokens", function(state)
    Settings.TokenPrecise = state
end)

FarmAdvanced:NewToggle("Farm Under Balloons", "Prioritize balloon nearby tokens", function(state)
    Settings.FarmUnderBalloons = state
end)

FarmAdvanced:NewToggle("Ignore Honey Tokens", "Skip honey tokens in collection", function(state)
    Settings.IgnoreHoneyTokens = state
    if state then
        Settings.TokenHoney = false
    end
end)

ConvertSection:NewSlider("Convert Honey %", "Backpack percent to convert", 100, 70, function(value)
    Settings.HiveBagPercent = value
end)

ConvertSection:NewSlider("Wait Before Convert", "Seconds to wait before conversion", 20, 0, function(value)
    Settings.WaitBeforeConverting = value
end)

ConvertSection:NewToggle("Instant Convert", "Use aggressive convert triggers", function(state)
    Settings.InstantConvert = state
    if state then
        Settings.NoSafeMode = true
    end
end)

ConvertSection:NewDropdown("Instant Convert Type", "How to trigger convert", INSTANT_CONVERT_TYPES, function(value)
    Settings.InstantConvertType = value
end)

ConvertSection:NewToggle("Convert Only In Field", "Convert only when filled in field", function(state)
    Settings.ConvertOnlyWhenInField = state
end)

ConvertSection:NewToggle("Reset When Converting", "Reset position at convert start", function(state)
    Settings.ResetWhenConverting = state
end)

ConvertSection:NewSlider("Convert Balloon At (min)", "Balloon blessing minute threshold", 60, 1, function(value)
    Settings.ConvertBalloonAtMinutes = value
end)

ConvertSection:NewToggle("Use Coconut To Convert", "Use coconut convert logic", function(state)
    Settings.UseCoconutToConvert = state
end)

ConvertSection:NewSlider("Use Coconut At %", "Bag percent to use coconut convert", 100, 70, function(value)
    Settings.UseCoconutAtPercentage = value
end)

ConvertSection:NewToggle("Auto Honey Mask For Balloon", "Swap to Honey Mask while converting", function(state)
    Settings.AutoHoneyMaskForBalloon = state
end)

ConvertSection:NewDropdown("Default Mask", "Mask to return after conversion", MASK_NAMES, function(value)
    Settings.DefaultMask = value
end)

ConvertSection:NewToggle("Collect Festive Blessing", "Collect Festive Blessing if nearby", function(state)
    Settings.CollectFestiveBlessing = state
end)

ConvertSection:NewToggle("Convert Balloon When Bag Full", "Convert balloon at full bag", function(state)
    Settings.ConvertBalloonWhenBagFull = state
end)

ConvertSection:NewToggle("Convert BagFull + Bubble", "Convert with Bubble Bloat condition", function(state)
    Settings.ConvertBalloonWhenBagFullBubble = state
end)

ConvertSection:NewToggle("Use Enzymes For Balloon", "Use enzymes before balloon convert", function(state)
    Settings.UseEnzymesForConvertingBalloon = state
end)

FaceSection:NewDropdown("Face Method", "BodyGyro / Shift Lock", FACE_METHODS, function(value)
    Settings.FaceMethod = value
end)

FaceSection:NewDropdown("Shift Direction", "Direction for Shift Lock mode", SHIFT_DIRECTIONS, function(value)
    Settings.ShiftLockDirection = value
end)

FaceSection:NewDropdown("Field Position", "Farm position in selected field", FIELD_POSITIONS, function(value)
    Settings.FieldPosition = value
end)

FaceSection:NewToggle("Face Center", "Face field center while farming", function(state)
    Settings.FaceCenter = state
end)

FaceSection:NewToggle("Face Bubbles", "Face bubbles/tokens while farming", function(state)
    Settings.FaceBubbles = state
end)

FaceSection:NewToggle("Farm With Shift Lock", "Use shift-lock style movement", function(state)
    Settings.FarmWithShiftLock = state
end)

end

do
local ToysTab = Window:NewTab("Toys")
local ToyControl = ToysTab:NewSection("Toys")
local ToyAtlas = ToysTab:NewSection("Auto Categories")
local ToyMaterials = ToysTab:NewSection("Materials + Inventory")
local ToyList = ToysTab:NewSection("Manual Toy List")

local toyStatusLabel = ToyControl:NewLabel("Toy: idle")
setToyStatus = function(text)
    if toyStatusLabel and toyStatusLabel.UpdateLabel then
        toyStatusLabel:UpdateLabel(text)
    end
end

ToyControl:NewToggle("Auto Use Toys", "Auto use enabled toys", function(state)
    Settings.AutoUseToys = state
    if state then
        task.spawn(function()
            runToyLoop(setToyStatus)
        end)
    else
        setToyStatus("Toy loop stopped")
    end
end)

ToyControl:NewToggle("Allow Gather Interrupt", "Allow toys while gathering", function(state)
    Settings.AllowGatherInterrupt = state
end)

ToyControl:NewButton("Reset Timers", "Reset toy/category cooldown trackers", function()
    toyUseTracker = {}
    atlasToyTracker = {}
    setToyStatus("Toy timers reset")
end)

ToyControl:NewSlider("Toy Loop Delay", "Seconds between toy attempts", 600, 20, function(value)
    Settings.ToyLoopDelay = value
end)

ToyControl:NewToggle("Tween To Toy", "Move to toy if remote fails", function(state)
    Settings.ToyTweenToTarget = state
end)

ToyControl:NewDropdown("Selected Toy", "Choose toy to use now", TOY_NAMES, function(value)
    Settings.SelectedToy = value
end)

ToyControl:NewButton("Use Selected Toy", "Try remote then prompt/click/touch", function()
    local toy = getToyByLabel(Settings.SelectedToy)
    if toy then
        local ok, method = useToy(toy)
        if ok then
            setToyStatus("Toy: " .. toy.label .. " via " .. method)
        else
            setToyStatus("Toy failed: " .. toy.label .. " (" .. method .. ")")
        end
    end
end)

ToyControl:NewButton("Use Enabled Toys Once", "Run one pass over enabled toys", function()
    for _, toy in ipairs(TOYS) do
        if Settings[toySettingKey(toy)] then
            local ok, method = useToy(toy)
            if ok then
                setToyStatus("Toy: " .. toy.label .. " via " .. method)
            else
                setToyStatus("Toy failed: " .. toy.label .. " (" .. method .. ")")
            end
            task.wait(0.2)
        end
    end
end)

ToyAtlas:NewToggle("Boosters", "Auto boosters", function(state)
    Settings.AutoToyBoosters = state
end)
ToyAtlas:NewToggle("Dispensers", "Auto dispensers", function(state)
    Settings.AutoToyDispensers = state
end)
ToyAtlas:NewToggle("Memory Match", "Auto memory match", function(state)
    Settings.AutoToyMemoryMatch = state
end)
ToyAtlas:NewToggle("Wind Shrine", "Auto wind shrine", function(state)
    Settings.AutoToyWindShrine = state
end)
ToyAtlas:NewToggle("Materials", "Auto materials", function(state)
    Settings.AutoToyMaterials = state
end)
ToyAtlas:NewToggle("Stickers", "Auto stickers", function(state)
    Settings.AutoToyStickers = state
end)
ToyAtlas:NewToggle("Progression", "Auto progression", function(state)
    Settings.AutoToyProgression = state
end)
ToyAtlas:NewToggle("Beesmas", "Auto Beesmas actions", function(state)
    Settings.AutoToyBeesmas = state
end)
ToyAtlas:NewToggle("Gummy Beacon", "Auto gummy beacon", function(state)
    Settings.AutoToyGummyBeacon = state
end)
ToyAtlas:NewToggle("Miscellaneous", "Auto misc actions", function(state)
    Settings.AutoToyMisc = state
end)
ToyAtlas:NewToggle("Dapper Bear Shop", "Auto Dapper shop", function(state)
    Settings.AutoToyDapperBearShop = state
end)
ToyAtlas:NewToggle("Nectar Condenser", "Auto nectar condenser", function(state)
    Settings.AutoToyNectarCondenser = state
end)
ToyAtlas:NewToggle("Auto Moon Amulet", "Auto moon amulet", function(state)
    Settings.AutoMoonAmulet = state
end)
ToyAtlas:NewToggle("Auto Star Amulet", "Auto star amulet", function(state)
    Settings.AutoStarAmulet = state
end)
ToyAtlas:NewToggle("Hive", "Auto hive-side actions", function(state)
    Settings.AutoHiveTasks = state
end)

ToyMaterials:NewToggle("Auto Use Materials", "Use enabled inventory materials", function(state)
    Settings.AutoUseMaterials = state
end)

ToyMaterials:NewSlider("Materials Delay", "Seconds between material uses", 900, 10, function(value)
    Settings.MaterialsLoopDelay = value
end)

ToyMaterials:NewButton("Use Materials Once", "Run one pass over enabled materials", function()
    local used = 0
    for _, material in ipairs(MATERIALS) do
        if Settings[materialSettingKey(material)] then
            local ok, method = useMaterialOnce(material)
            if ok then
                used = used + 1
                setToyStatus("Material: " .. material.label .. " via " .. tostring(method))
            else
                setToyStatus("Material fail: " .. material.label .. " (" .. tostring(method) .. ")")
            end
            task.wait(0.15)
        end
    end
    if used == 0 then
        setToyStatus("No materials enabled")
    end
end)

local function createMaterialToggle(material)
    ToyMaterials:NewToggle(material.label, "Enable material auto use", function(state)
        Settings["Material_" .. material.key] = state
    end)
end

for _, material in ipairs(MATERIALS) do
    createMaterialToggle(material)
end

local function createToyToggle(toy)
    ToyList:NewToggle(toy.label, "Enable this toy in loop", function(state)
        Settings[toySettingKey(toy)] = state
    end)
end

for _, toy in ipairs(TOYS) do
    createToyToggle(toy)
end

end

do
local QuestsTab = Window:NewTab("Quests")
local QuestMain = QuestsTab:NewSection("Quest Core")
local QuestMainToggles = QuestsTab:NewSection("Main Quest Toggles")
local QuestRepeatToggles = QuestsTab:NewSection("Repeatable Toggles")
local QuestTaskToggles = QuestsTab:NewSection("Quest Task Settings")
local FeedSection = QuestsTab:NewSection("Feed Settings")

local questStatusLabel = QuestMain:NewLabel("Quests: idle")
setQuestStatus = function(text)
    if questStatusLabel and questStatusLabel.UpdateLabel then
        questStatusLabel:UpdateLabel(text)
    end
end

QuestMain:NewToggle("Auto Quest", "Run quest loop", function(state)
    Settings.AutoQuest = state
    if state then
        task.spawn(function()
            runQuestLoop(setQuestStatus)
        end)
    else
        setQuestStatus("Quests: stopped")
    end
end)

QuestMain:NewToggle("Auto Claim Quests", "Try claim quest rewards", function(state)
    Settings.AutoClaimQuests = state
end)

QuestMainToggles:NewToggle("Auto Black Bear", "Main Black Bear quests", function(state)
    Settings.AutoQuestBlackBear = state
end)

QuestMainToggles:NewToggle("Auto Mother Bear", "Main Mother Bear quests", function(state)
    Settings.AutoQuestMotherBear = state
end)

QuestMainToggles:NewToggle("Auto Panda Bear", "Main Panda Bear quests", function(state)
    Settings.AutoQuestPandaBear = state
end)

QuestMainToggles:NewToggle("Auto Science Bear", "Main Science Bear quests", function(state)
    Settings.AutoQuestScienceBear = state
end)

QuestMainToggles:NewToggle("Auto Dapper Bear", "Main Dapper Bear quests", function(state)
    Settings.AutoQuestDapperBear = state
end)

QuestMainToggles:NewToggle("Auto Onett", "Main Onett quests", function(state)
    Settings.AutoQuestOnett = state
end)

QuestMainToggles:NewToggle("Auto Spirit Bear", "Main Spirit Bear quests", function(state)
    Settings.AutoQuestSpiritBear = state
end)

QuestRepeatToggles:NewToggle("Auto Brown Bear", "Repeatable Brown Bear", function(state)
    Settings.AutoQuestBrownBearRepeat = state
end)

QuestRepeatToggles:NewToggle("Auto Bucko Bee", "Repeatable Bucko Bee", function(state)
    Settings.AutoQuestBuckoRepeat = state
end)

QuestRepeatToggles:NewToggle("Auto Riley Bee", "Repeatable Riley Bee", function(state)
    Settings.AutoQuestRileyRepeat = state
end)

QuestRepeatToggles:NewToggle("Auto Honey Bee", "Repeatable Honey Bee", function(state)
    Settings.AutoQuestHoneyBeeRepeat = state
end)

QuestRepeatToggles:NewToggle("Auto Polar Bear", "Repeatable Polar Bear", function(state)
    Settings.AutoQuestPolarBearRepeat = state
end)

QuestTaskToggles:NewToggle("Farm Pollen", "Quest pollen tasks", function(state)
    Settings.QuestFarmPollen = state
end)

QuestTaskToggles:NewToggle("Farm Goo", "Quest goo tasks", function(state)
    Settings.QuestFarmGoo = state
end)

QuestTaskToggles:NewToggle("Farm Mobs", "Quest mob tasks", function(state)
    Settings.QuestFarmMobs = state
end)

QuestTaskToggles:NewToggle("Farm Ants", "Quest ant tasks", function(state)
    Settings.QuestFarmAnts = state
end)

QuestTaskToggles:NewToggle("Farm Rage Tokens", "Quest rage token tasks", function(state)
    Settings.QuestFarmRageTokens = state
end)

QuestTaskToggles:NewToggle("Farm Puffshrooms", "Quest puffshroom tasks", function(state)
    Settings.QuestFarmPuffshrooms = state
end)

QuestTaskToggles:NewToggle("Do Duped Tokens", "Quest duplicated token tasks", function(state)
    Settings.QuestDoDupedTokens = state
end)

QuestTaskToggles:NewToggle("Do Wind Shrine", "Quest wind shrine tasks", function(state)
    Settings.QuestDoWindShrine = state
end)

QuestTaskToggles:NewToggle("Do Memory Match", "Quest memory match tasks", function(state)
    Settings.QuestDoMemoryMatch = state
end)

QuestTaskToggles:NewToggle("Share Jelly Beans", "Quest jelly bean tasks", function(state)
    Settings.QuestShareJellyBeans = state
end)

QuestTaskToggles:NewToggle("Craft Items", "Quest crafting tasks", function(state)
    Settings.QuestCraftItems = state
end)

QuestTaskToggles:NewToggle("Use Toys", "Allow toy usage in quests", function(state)
    Settings.QuestUseToys = state
end)

FeedSection:NewToggle("Feed Bees", "Feed bees automatically", function(state)
    Settings.FeedBees = state
end)

FeedSection:NewToggle("Level Up Bees", "Level bees automatically", function(state)
    Settings.LevelUpBees = state
end)

FeedSection:NewToggle("Purchase Treats To Level", "Auto buy treats for leveling", function(state)
    Settings.PurchaseTreatsToLevelUp = state
end)

FeedSection:NewToggle("Use Royal Jelly", "Auto use royal jelly", function(state)
    Settings.UseRoyalJelly = state
end)

end

do
local PlantersTab = Window:NewTab("Planters")
local PlanterMain = PlantersTab:NewSection("Planter Settings")

local planterStatusLabel = PlanterMain:NewLabel("Planters: idle")
setPlanterStatus = function(text)
    if planterStatusLabel and planterStatusLabel.UpdateLabel then
        planterStatusLabel:UpdateLabel(text)
    end
end

PlanterMain:NewToggle("Farm Planters", "Enable planter automation", function(state)
    Settings.EnablePlanters = state
    if state then
        task.spawn(function()
            runPlanterLoop(setPlanterStatus)
        end)
    else
        setPlanterStatus("Planters: stopped")
    end
end)

PlanterMain:NewToggle("Auto Plant Planters", "Plant planters automatically", function(state)
    Settings.PlanterAutoPlant = state
end)

PlanterMain:NewToggle("Auto Harvest Planters", "Harvest completed planters", function(state)
    Settings.PlanterAutoHarvest = state
end)

PlanterMain:NewToggle("Plant During Day Only", "Only run at daytime", function(state)
    Settings.PlanterDuringDayOnly = state
    if state then
        Settings.PlanterDuringNightOnly = false
    end
end)

PlanterMain:NewToggle("Plant During Night Only", "Only run at night", function(state)
    Settings.PlanterDuringNightOnly = state
    if state then
        Settings.PlanterDuringDayOnly = false
    end
end)

PlanterMain:NewDropdown("Allowed Fields", "Field for planter logic", PLANTER_FIELDS, function(value)
    Settings.PlanterAllowedField = value
end)

PlanterMain:NewSlider("Planter Loop Delay", "Seconds between planter checks", 300, 8, function(value)
    Settings.PlanterLoopDelay = value
end)

PlanterMain:NewToggle("Trigger Fallback", "If remotes fail, use prompt/click/touch", function(state)
    Settings.PlanterTriggerFallback = state
end)

PlanterMain:NewButton("Plant Now", "Force one planter plant attempt", function()
    local targetField = safePlantFieldName()
    local ok, method = tryPlanterAction("Plant", targetField)
    if ok then
        setPlanterStatus("Planters: planted via " .. tostring(method))
    else
        setPlanterStatus("Planters: plant failed (" .. tostring(method) .. ")")
    end
end)

PlanterMain:NewButton("Harvest Now", "Force one planter harvest attempt", function()
    local targetField = safePlantFieldName()
    local ok, method = tryPlanterAction("Harvest", targetField)
    if ok then
        setPlanterStatus("Planters: harvested via " .. tostring(method))
    else
        setPlanterStatus("Planters: harvest failed (" .. tostring(method) .. ")")
    end
end)

end

do
local WebhookTab = Window:NewTab("Webhook")
local WebhookMain = WebhookTab:NewSection("Webhook")
local WebhookSettings = WebhookTab:NewSection("Webhook Settings")
local GraphSettings = WebhookTab:NewSection("Graph Settings")
local DashboardSettings = WebhookTab:NewSection("Dashboard Settings")

local webhookStatusLabel = WebhookMain:NewLabel("Webhook: idle")
setWebhookStatus = function(text)
    if webhookStatusLabel and webhookStatusLabel.UpdateLabel then
        webhookStatusLabel:UpdateLabel(text)
    end
end

WebhookMain:NewToggle("Enable Webhook", "Send periodic Discord updates", function(state)
    Settings.EnableWebhook = state
    if state then
        if not webhookLoopRunning then
            task.spawn(function()
                runWebhookLoop(setWebhookStatus)
            end)
        end
    else
        setWebhookStatus("Webhook: disabled")
    end
end)

WebhookMain:NewTextBox("Webhook URL", "https://discord.com/api/webhooks/...", function(value)
    Settings.WebhookUrl = tostring(value or "")
end)

WebhookMain:NewSlider("Webhook Interval (minutes)", "Send interval", 120, 1, function(value)
    Settings.WebhookIntervalMinutes = value
end)

WebhookMain:NewButton("Send Test", "Send test to main webhook", function()
    local ok, msg = sendWebhookSnapshot("Manual test", false)
    setWebhookStatus(ok and "Webhook: test sent" or ("Webhook: " .. tostring(msg)))
end)

WebhookSettings:NewToggle("Send Balloon Pollen", "Include balloon info", function(state)
    Settings.WebhookSendBalloonPollen = state
end)
WebhookSettings:NewToggle("Send Nectars", "Include nectar info", function(state)
    Settings.WebhookSendNectars = state
end)
WebhookSettings:NewToggle("Send Planters", "Include planter info", function(state)
    Settings.WebhookSendPlanters = state
end)
WebhookSettings:NewToggle("Send Items", "Include item usage info", function(state)
    Settings.WebhookSendItems = state
end)
WebhookSettings:NewToggle("Send Console", "Include console snippets", function(state)
    Settings.WebhookSendConsole = state
end)
WebhookSettings:NewToggle("Send Stickers", "Include sticker info", function(state)
    Settings.WebhookSendStickers = state
end)
WebhookSettings:NewToggle("Send Beequips", "Include beequip info", function(state)
    Settings.WebhookSendBeequips = state
end)
WebhookSettings:NewToggle("Send Quest Done", "Send quest completion", function(state)
    Settings.WebhookSendQuestDone = state
end)
WebhookSettings:NewToggle("Send Digital Bee Drives", "Include drive info", function(state)
    Settings.WebhookSendDigitalBeeDrives = state
end)
WebhookSettings:NewToggle("Send Dapper Bear Shop", "Include dapper shop info", function(state)
    Settings.WebhookSendDapperBearShop = state
end)
WebhookSettings:NewToggle("Send Disconnect", "Send message before auto rejoin", function(state)
    Settings.WebhookSendDisconnect = state
end)

GraphSettings:NewToggle("Enabled", "Enable graph webhook stream", function(state)
    Settings.GraphEnabled = state
end)
GraphSettings:NewToggle("Natro Macro Branding", "Use natro-like title", function(state)
    Settings.GraphUseBranding = state
end)
GraphSettings:NewTextBox("Graph Webhook URL", "Secondary webhook URL", function(value)
    Settings.GraphWebhookUrl = tostring(value or "")
end)
GraphSettings:NewButton("Send Test (Graph)", "Send test graph embed", function()
    local ok, msg = sendWebhookSnapshot("Manual graph test", true)
    setWebhookStatus(ok and "Webhook: graph test sent" or ("Webhook: " .. tostring(msg)))
end)

DashboardSettings:NewToggle("Dashboard Enabled", "Store dashboard-like stream state", function(state)
    Settings.DashboardEnabled = state
end)

end

do
local ThemeTab = Window:NewTab("Theme")
local ThemeSection = ThemeTab:NewSection("Customize Colors")

ThemeSection:NewLabel("Tabs and background are black in default preset")

ThemeSection:NewColorPicker("SchemeColor", "Purple accent", UITheme.SchemeColor, function(color)
    UITheme.SchemeColor = color
    if Library.ChangeColor then
        Library:ChangeColor("SchemeColor", color)
    end
end)

ThemeSection:NewColorPicker("Background", "Background color", UITheme.Background, function(color)
    UITheme.Background = color
    if Library.ChangeColor then
        Library:ChangeColor("Background", color)
    end
end)

ThemeSection:NewColorPicker("Header", "Tab/header color", UITheme.Header, function(color)
    UITheme.Header = color
    if Library.ChangeColor then
        Library:ChangeColor("Header", color)
    end
end)

ThemeSection:NewColorPicker("ElementColor", "Section/button color", UITheme.ElementColor, function(color)
    UITheme.ElementColor = color
    if Library.ChangeColor then
        Library:ChangeColor("ElementColor", color)
    end
end)

ThemeSection:NewColorPicker("TextColor", "Text color", UITheme.TextColor, function(color)
    UITheme.TextColor = color
    if Library.ChangeColor then
        Library:ChangeColor("TextColor", color)
    end
end)

ThemeSection:NewButton("Preset: Purple Black", "Apply purple + black style", function()
    local preset = {
        SchemeColor = Color3.fromRGB(166, 73, 255),
        Background = Color3.fromRGB(8, 8, 8),
        Header = Color3.fromRGB(0, 0, 0),
        TextColor = Color3.fromRGB(235, 235, 235),
        ElementColor = Color3.fromRGB(0, 0, 0),
    }
    for key, color in pairs(preset) do
        UITheme[key] = color
        if Library.ChangeColor then
            Library:ChangeColor(key, color)
        end
    end
end)

end

local okDebugUi, debugUiErr = pcall(function()
    local DebugTab = Window:NewTab("Debug + AntiLag")
    local DebugMain = DebugTab:NewSection("Debug")
    local DebugDetected = DebugTab:NewSection("Detected Features")
    local DebugPerfCore = DebugTab:NewSection("Anti Lag Core")
    local DebugPerfVisual = DebugTab:NewSection("Visual Filters")
    local DebugPerfWorld = DebugTab:NewSection("World / Render")
    local DebugTools = DebugTab:NewSection("Tools")

    local debugStatusLabel = DebugMain:NewLabel("Debug: idle")
    setDebugStatus = function(text)
        if debugStatusLabel and debugStatusLabel.UpdateLabel then
            debugStatusLabel:UpdateLabel(text)
        end
    end

    DebugMain:NewToggle("Anonymous Mode", "Hide display identity in logs", function(state)
        Settings.AnonymousMode = state
    end)
    DebugMain:NewToggle("Farm Multiple Fields", "Allow multi-field selection logic", function(state)
        Settings.FarmMultipleFields = state
    end)
    DebugMain:NewToggle("Mobile Toggle Button", "Enable mobile helper toggle", function(state)
        Settings.MobileToggleButton = state
    end)
    DebugMain:NewToggle("Show Console", "Enable verbose console logs", function(state)
        Settings.ShowAtlasConsole = state
    end)
    DebugMain:NewToggle("Auto Rejoin", "Rejoin when disconnect prompt appears", function(state)
        Settings.AutoRejoin = state
    end)
    DebugMain:NewSlider("Auto Rejoin Delay", "Seconds between rejoin attempts", 30, 2, function(value)
        Settings.AutoRejoinDelay = value
    end)

    DebugDetected:NewLabel("Use this at your own risk")
    DebugDetected:NewToggle("Run without autofarm", "Allow background routines without autofarm", function(state)
        Settings.RunWithoutAutofarm = state
    end)
    DebugDetected:NewToggle("Fast Shower Tween", "Enable faster shower movement", function(state)
        Settings.FastShowerTween = state
    end)
    DebugDetected:NewToggle("Fast Coconut Tween", "Enable faster coconut movement", function(state)
        Settings.FastCoconutTween = state
    end)
    DebugDetected:NewToggle("Fast Tween To Rares", "Enable faster rare movement", function(state)
        Settings.FastTweenToRares = state
    end)
    DebugDetected:NewDropdown("Rares List", "Select rare priority profile", RARES_LIST, function(value)
        Settings.RaresList = value
    end)

    DebugPerfCore:NewLabel("Event mode: one full pass + new objects")

    DebugPerfCore:NewToggle("Anti Lag", "Enable/disable anti lag", function(state)
        Settings.AntiLagEnabled = state
        if state then
            task.spawn(function()
                runAntiLagLoop(setDebugStatus)
            end)
        else
            restoreAntiLag()
            setDebugStatus("AntiLag restored")
        end
    end)
    DebugPerfCore:NewToggle("Hide Particles", "Turn off particles/trails/beams", function(state)
        Settings.AntiLagParticles = state
        requestAntiLagReapply()
    end)
    DebugPerfCore:NewToggle("Destroy Textures", "Hide decals and textures", function(state)
        Settings.AntiLagTextures = state
        requestAntiLagReapply()
    end)
    DebugPerfCore:NewToggle("Disable Shadows", "Disable part cast shadows", function(state)
        Settings.AntiLagShadows = state
        requestAntiLagReapply()
    end)
    DebugPerfCore:NewToggle("Low Lighting", "Lower lighting effects", function(state)
        Settings.AntiLagLighting = state
        requestAntiLagReapply()
    end)

    DebugPerfVisual:NewToggle("Hide Tokens", "Hide token parts", function(state)
        Settings.HideTokens = state
        requestAntiLagReapply()
    end)
    DebugPerfVisual:NewToggle("Hide Precise Targets", "Hide precise-related visuals", function(state)
        Settings.HidePreciseTargets = state
        requestAntiLagReapply()
    end)
    DebugPerfVisual:NewToggle("Hide Duped Tokens", "Hide duplicated token visuals", function(state)
        Settings.HideDupedTokens = state
        requestAntiLagReapply()
    end)
    DebugPerfVisual:NewToggle("Hide Marks", "Hide mark/target visuals", function(state)
        Settings.HideMarks = state
        requestAntiLagReapply()
    end)
    DebugPerfVisual:NewToggle("Hide Bees", "Hide bee models", function(state)
        Settings.HideBees = state
        requestAntiLagReapply()
    end)
    DebugPerfVisual:NewToggle("Hide Flowers", "Hide flower visuals", function(state)
        Settings.HideFlowers = state
        requestAntiLagReapply()
    end)
    DebugPerfVisual:NewToggle("Destroy Balloons", "Hide balloon visuals/collision", function(state)
        Settings.DestroyBalloons = state
        requestAntiLagReapply()
    end)
    DebugPerfVisual:NewToggle("Destroy Decorations", "Hide decoration meshes/parts", function(state)
        Settings.DestroyDecorations = state
        requestAntiLagReapply()
    end)

    DebugPerfWorld:NewToggle("Disable 3D Rendering", "Disable world rendering for FPS", function(state)
        Settings.Disable3DRendering = state
        requestAntiLagReapply()
    end)
    DebugPerfWorld:NewToggle("Hide Other Players", "Hide other player characters", function(state)
        Settings.HideOtherPlayers = state
        requestAntiLagReapply()
    end)
    DebugPerfWorld:NewToggle("Hide BSS UI", "Disable most game UIs", function(state)
        Settings.HideBssUI = state
        requestAntiLagReapply()
    end)

    local function rejoinNow(reason)
        if Settings.EnableWebhook and Settings.WebhookSendDisconnect then
            pcall(function()
                sendWebhookSnapshot(reason or "Manual rejoin", false)
            end)
        end
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end

    DebugTools:NewButton("Apply Anti Lag Now", "Run anti-lag pass instantly", function()
        applyAntiLagPass()
        antiLagOneTimeApplied = true
        antiLagDirty = false
        setDebugStatus("AntiLag pass applied")
    end)
    DebugTools:NewButton("Restore Visuals", "Restore visual changes", function()
        Settings.AntiLagEnabled = false
        restoreAntiLag()
        setDebugStatus("Visuals restored")
    end)
    DebugTools:NewButton("Rejoin Now", "Teleport back to this server type", function()
        rejoinNow("Manual rejoin")
    end)

    local tokenScanLabel = DebugTools:NewLabel("Token scan: not run")
    DebugTools:NewButton("Scan Token Names", "List token names to console", function()
        local names = scanTokenNames()
        local text = "Token scan: " .. tostring(#names) .. " names"
        if tokenScanLabel and tokenScanLabel.UpdateLabel then
            tokenScanLabel:UpdateLabel(text)
        end
        setDebugStatus(text)
    end)
end)
if not okDebugUi then
    warn("[ICHIGER] Debug UI failed: " .. tostring(debugUiErr))
end

task.spawn(function()
    runSupportLoop()
end)

task.spawn(function()
    applyWalkSpeed()
    if Settings.AutoFarm then
        runAutoFarm()
    end
    if Settings.AutoUseToys then
        runToyLoop(setToyStatus)
    end
    if Settings.AutoQuest then
        runQuestLoop(setQuestStatus)
    end
    if Settings.EnablePlanters then
        runPlanterLoop(setPlanterStatus)
    end
    if Settings.EnableWebhook then
        runWebhookLoop(setWebhookStatus)
    end
    if Settings.AntiLagEnabled then
        runAntiLagLoop(setDebugStatus)
    end
end)

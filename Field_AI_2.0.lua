-- FIELD AI 2.0 | Delta Executor
-- RU / EN | Mobile interface
-- Route Recorder | Loot Scanner | World Memory
-- Route Optimizer | AFK Monitor

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local CFG = {
    ScanRadius = 120,
    ScanInterval = 3,
    RecordInterval = 0.8,
    MinDistance = 3,
    MaxPoints = 800,
    MaxObjects = 150,
    AFKSeconds = 60
}

local S = {
    Lang = "RU",
    Recording = false,
    Replaying = false,
    Radar = false,
    AFK = false,
    Route = {},
    Memory = {},
    Loot = {},
    LastInput = os.clock(),
    LastRecord = 0,
    LastAFKWarning = 0
}

local TEXT = {
    RU = {
        title = "FIELD AI 2.0", ready = "Готов к работе",
        record = "Записать маршрут", stopRecord = "Остановить запись",
        replay = "Повторить маршрут", stopReplay = "Остановить автопилот",
        radar = "Поиск предметов", radarOn = "Выключить поиск",
        save = "Сохранить координаты", memory = "Мои точки",
        optimize = "Оптимизировать маршрут",
        afk = "Контроль бездействия", afkOn = "Выключить контроль",
        lang = "Язык: RU / EN", hide = "Свернуть меню",
        show = "Открыть Field AI", close = "Закрыть",
        emptyRoute = "Сначала запиши маршрут",
        recording = "Запись маршрута...", recorded = "Точек записано: ",
        replaying = "Повтор маршрута запущен", stopped = "Автопилот остановлен",
        radarStart = "Поиск объектов включён", radarStop = "Поиск объектов выключен",
        found = "Найдено объектов: ", saved = "Точка сохранена. Всего: ",
        emptyMemory = "Сохранённых точек пока нет",
        optimized = "После оптимизации точек: ",
        afkStart = "Контроль бездействия включён",
        afkStop = "Контроль бездействия выключен",
        afkWarn = "Вы давно не взаимодействовали с игрой",
        character = "Персонаж не готов", noLoot = "Объекты поблизости не найдены",
        error = "Ошибка операции: ", distance = "Расстояние: ",
        clear = "Очистить данные", cleared = "Данные очищены"
    },
    EN = {
        title = "FIELD AI 2.0", ready = "Ready",
        record = "Record route", stopRecord = "Stop recording",
        replay = "Replay route", stopReplay = "Stop autopilot",
        radar = "Find nearby items", radarOn = "Disable radar",
        save = "Save coordinates", memory = "Saved points",
        optimize = "Optimize route", afk = "Idle monitor",
        afkOn = "Disable monitor", lang = "Language: RU / EN",
        hide = "Minimize menu", show = "Open Field AI", close = "Close",
        emptyRoute = "Record a route first", recording = "Recording route...",
        recorded = "Waypoints recorded: ", replaying = "Route replay started",
        stopped = "Autopilot stopped", radarStart = "Object scan enabled",
        radarStop = "Object scan disabled", found = "Objects found: ",
        saved = "Point saved. Total: ", emptyMemory = "No saved points yet",
        optimized = "Waypoints after optimization: ",
        afkStart = "Idle monitor enabled", afkStop = "Idle monitor disabled",
        afkWarn = "You have been inactive for a while",
        character = "Character not ready", noLoot = "No nearby objects found",
        error = "Operation error: ", distance = "Distance: ",
        clear = "Clear data", cleared = "Data cleared"
    }
}

local function tr(key)
    return TEXT[S.Lang][key] or key
end

local function safe(callback)
    local ok, result = pcall(callback)
    if not ok then
        warn("[Field AI] " .. tostring(result))
        return false, result
    end
    return true, result
end

local function characterData()
    local char = LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil end
    return char, hum, root
end

local function rootPart()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local old = PlayerGui:FindFirstChild("FieldAI2")
if old then old:Destroy() end

local GUI = Instance.new("ScreenGui")
GUI.Name = "FieldAI2"
GUI.ResetOnSpawn = false
GUI.DisplayOrder = 50
GUI.Parent = PlayerGui

local Open = Instance.new("TextButton")
Open.Size = UDim2.fromOffset(125, 42)
Open.Position = UDim2.new(0, 12, 0.4, 0)
Open.BackgroundColor3 = Color3.fromRGB(35, 40, 47)
Open.TextColor3 = Color3.new(1, 1, 1)
Open.TextSize = 13
Open.Visible = false
Open.Parent = GUI

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(300, 430)
Main.Position = UDim2.new(0, 12, 0.18, 0)
Main.BackgroundColor3 = Color3.fromRGB(28, 31, 36)
Main.BorderSizePixel = 1
Main.BorderColor3 = Color3.fromRGB(90, 100, 110)
Main.ClipsDescendants = true
Main.Parent = GUI

local Header = Instance.new("TextButton")
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(44, 49, 56)
Header.TextColor3 = Color3.new(1, 1, 1)
Header.Font = Enum.Font.GothamBold
Header.TextSize = 15
Header.Parent = Main

local Status = Instance.new("TextLabel")
Status.Position = UDim2.fromOffset(8, 44)
Status.Size = UDim2.new(1, -16, 0, 36)
Status.BackgroundTransparency = 1
Status.TextColor3 = Color3.fromRGB(190, 220, 205)
Status.TextSize = 12
Status.TextWrapped = true
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Main

local Scroll = Instance.new("ScrollingFrame")
Scroll.Position = UDim2.fromOffset(5, 82)
Scroll.Size = UDim2.new(1, -10, 1, -87)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 5
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.CanvasSize = UDim2.new()
Scroll.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 5)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

local function status(message)
    if Status.Parent then Status.Text = message end
end

local function makeButton(key, callback)
    local b = Instance.new("TextButton")
    b.Name = key
    b.Size = UDim2.new(1, -6, 0, 39)
    b.BackgroundColor3 = Color3.fromRGB(52, 58, 66)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    b.TextWrapped = true
    b.Parent = Scroll
    b.Activated:Connect(function()
        local ok, err = safe(callback)
        if not ok then status(tr("error") .. tostring(err)) end
    end)
    return b
end

local Buttons = {}
local function add(key, callback)
    Buttons[key] = makeButton(key, callback)
end

local function refresh()
    Header.Text = tr("title") .. "  |  ↕"
    Open.Text = tr("show")
    for key, b in pairs(Buttons) do
        if key == "record" then
            b.Text = tr(S.Recording and "stopRecord" or "record")
        elseif key == "replay" then
            b.Text = tr(S.Replaying and "stopReplay" or "replay")
        elseif key == "radar" then
            b.Text = tr(S.Radar and "radarOn" or "radar")
        elseif key == "afk" then
            b.Text = tr(S.AFK and "afkOn" or "afk")
        else
            b.Text = tr(key)
        end
    end
end

-- Drag header (touch + mouse)
local dragging = false
local dragStart, frameStart, activeInput

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        frameStart = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then
        activeInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and input == activeInput then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X,
            frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
    end
end)

-- Memory Ghost: record route
local function recordPosition()
    local root = rootPart()
    if not root then return end
    local now = os.clock()
    if now - S.LastRecord < CFG.RecordInterval then return end
    S.LastRecord = now
    local p = root.Position
    local last = S.Route[#S.Route]
    if not last or (p - last).Magnitude >= CFG.MinDistance then
        if #S.Route >= CFG.MaxPoints then table.remove(S.Route, 1) end
        table.insert(S.Route, p)
    end
end

add("record", function()
    if S.Recording then
        S.Recording = false
        status(tr("recorded") .. #S.Route)
    else
        S.Route = {}
        S.LastRecord = 0
        S.Recording = true
        status(tr("recording"))
    end
    refresh()
end)

add("replay", function()
    if S.Replaying then
        S.Replaying = false
        status(tr("stopped"))
        refresh()
        return
    end
    if #S.Route < 2 then status(tr("emptyRoute")); return end

    S.Recording = false
    S.Replaying = true
    refresh()
    status(tr("replaying"))

    task.spawn(function()
        local ok, err = pcall(function()
            for _, position in ipairs(S.Route) do
                if not S.Replaying then break end
                local _, hum = characterData()
                if not hum then break end
                hum:MoveTo(position)

                local reached = false
                local connection = hum.MoveToFinished:Connect(function(result)
                    reached = result
                end)
                local started = os.clock()
                while S.Replaying and not reached
                    and os.clock() - started < 8 do
                    task.wait(0.1)
                end
                connection:Disconnect()
                if not reached then break end
            end
        end)
        S.Replaying = false
        refresh()
        if not ok then status(tr("error") .. tostring(err))
        else status(tr("stopped")) end
    end)
end)

-- World Memory
local function savePoint(name, position, kind)
    table.insert(S.Memory, {
        Name = name, Position = position,
        Kind = kind or "Point", Time = os.time()
    })
    if #S.Memory > 500 then table.remove(S.Memory, 1) end
end

add("save", function()
    local root = rootPart()
    if not root then status(tr("character")); return end
    savePoint("Point " .. (#S.Memory + 1), root.Position, "Manual")
    status(tr("saved") .. #S.Memory)
end)

add("memory", function()
    if #S.Memory == 0 then status(tr("emptyMemory")); return end
    local result = {}
    for i = math.max(1, #S.Memory - 4), #S.Memory do
        local item = S.Memory[i]
        local p = item.Position
        table.insert(result, string.format("%s: %.0f, %.0f, %.0f",
            item.Name, p.X, p.Y, p.Z))
    end
    status(table.concat(result, " | "))
end)

-- Smart Loot Radar: scan available parts and image textures
local function getImage(object)
    local decal = object:FindFirstChildWhichIsA("Decal", true)
    if decal and decal.Texture ~= "" then return decal.Texture end
    local texture = object:FindFirstChildWhichIsA("Texture", true)
    if texture and texture.Texture ~= "" then return texture.Texture end
    if object:IsA("MeshPart") and object.TextureID ~= "" then
        return object.TextureID
    end
    if object:IsA("Decal") and object.Texture ~= "" then return object.Texture end
    return nil
end

local function scanLoot()
    local root = rootPart()
    if not root then status(tr("character")); return end

    local results, visited = {}, 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        visited += 1
        if visited > 30000 then break end

        if obj:IsA("BasePart") and obj ~= root then
            local distance = (obj.Position - root.Position).Magnitude
            if distance <= CFG.ScanRadius and (obj.CanTouch or obj.CanQuery) then
                local model = obj:FindFirstAncestorOfClass("Model")
                local name = model and model.Name or obj.Name
                table.insert(results, {
                    Name = name, Position = obj.Position,
                    Distance = distance, Image = getImage(model or obj)
                })
            end
        end
    end

    table.sort(results, function(a, b) return a.Distance < b.Distance end)
    S.Loot = {}
    for i = 1, math.min(#results, CFG.MaxObjects) do
        table.insert(S.Loot, results[i])
    end

    for _, item in ipairs(S.Loot) do
        savePoint(item.Name, item.Position, "Scanned")
    end

    if #S.Loot == 0 then
        status(tr("noLoot"))
    else
        local first = S.Loot[1]
        status(tr("found") .. #S.Loot .. " | " .. first.Name .. " | "
            .. tr("distance") .. math.floor(first.Distance)
            .. (first.Image and " | Image available" or ""))
    end
end

add("radar", function()
    S.Radar = not S.Radar
    status(tr(S.Radar and "radarStart" or "radarStop"))
    refresh()
    if S.Radar then
        task.spawn(function()
            while S.Radar and GUI.Parent do
                safe(scanLoot)
                task.wait(CFG.ScanInterval)
            end
        end)
    end
end)

-- Adaptive Route AI: line-of-sight shortcut optimization
local function clearLine(a, b)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LP.Character}
    params.IgnoreWater = true
    return Workspace:Raycast(a, b - a, params) == nil
end

add("optimize", function()
    if #S.Route < 3 then status(tr("emptyRoute")); return end
    local optimized = {S.Route[1]}
    local i = 1
    while i < #S.Route do
        local nextIndex = i + 1
        for j = #S.Route, i + 1, -1 do
            if clearLine(S.Route[i], S.Route[j]) then
                nextIndex = j
                break
            end
        end
        table.insert(optimized, S.Route[nextIndex])
        i = nextIndex
    end
    S.Route = optimized
    status(tr("optimized") .. #S.Route)
end)

-- AFK monitor (notifications only)
add("afk", function()
    S.AFK = not S.AFK
    S.LastInput = os.clock()
    S.LastAFKWarning = 0
    status(tr(S.AFK and "afkStart" or "afkStop"))
    refresh()
end)

UIS.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Keyboard then
        S.LastInput = os.clock()
    end
end)

add("lang", function()
    S.Lang = S.Lang == "RU" and "EN" or "RU"
    refresh()
    status(tr("ready"))
end)

add("hide", function()
    Main.Visible = false
    Open.Visible = true
end)

Open.Activated:Connect(function()
    Main.Visible = true
    Open.Visible = false
end)

add("clear", function()
    S.Recording = false
    S.Replaying = false
    S.Radar = false
    S.Route, S.Memory, S.Loot = {}, {}, {}
    status(tr("cleared"))
    refresh()
end)

add("close", function()
    S.Recording, S.Replaying, S.Radar, S.AFK = false, false, false, false
    GUI:Destroy()
end)

local heartbeat
heartbeat = RunService.Heartbeat:Connect(function()
    if not GUI.Parent then
        heartbeat:Disconnect()
        return
    end

    if S.Recording then safe(recordPosition) end

    if S.AFK and os.clock() - S.LastInput >= CFG.AFKSeconds
        and os.clock() - S.LastAFKWarning >= CFG.AFKSeconds then
        S.LastAFKWarning = os.clock()
        status(tr("afkWarn"))
        warn("[Field AI] " .. tr("afkWarn"))
    end
end)

refresh()
status(tr("ready"))
print("[Field AI 2.0] Loaded successfully")

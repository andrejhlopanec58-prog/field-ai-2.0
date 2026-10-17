-- FIELD AI 2.1 | Improved UI & Features
-- Improvements: reorganized menu, tooltips, keyboard shortcuts, export/import memory, auto-open, confirmations

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- Configuration
local CFG = {
    ScanRadius = 120,
    ScanInterval = 3,
    RecordInterval = 0.8,
    MinDistance = 3,
    MaxPoints = 800,
    MaxObjects = 150,
    AFKSeconds = 60,
    AutoOpen = true,       -- open UI on script load
    Hotkeys = true         -- enable keyboard shortcuts
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
        title = "FIELD AI 2.1", ready = "Готов к работе",
        record = "🞄 Запись маршрута (R)", stopRecord = "■ Остановить запись (R)",
        replay = "▶ Повтор маршрута (P)", stopReplay = "■ Остановить автопилот (P)",
        radar = "🔎 Поиск предметов (F)", radarOn = "❌ Выключить поиск (F)",
        save = "💾 Сохранить точку", memory = "🗺️ Мои точки",
        optimize = "⚡ Оптимизировать маршрут",
        afk = "👀 Контроль AFK", afkOn = "❌ Выключить AFK",
        lang = "Язык: RU / EN", hide = "⬇ Свернуть меню", show = "Открыть Field AI", close = "Закрыть",
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
        clear = "Очистить данные", cleared = "Данные очищены",
        export = "Экспортировать память",
        import = "Импортировать память",
        confirmClear = "Подтвердите очистку данных",
        yes = "Да", no = "Нет"
    },
    EN = {
        title = "FIELD AI 2.1", ready = "Ready",
        record = "🞄 Record route (R)", stopRecord = "■ Stop recording (R)",
        replay = "▶ Replay route (P)", stopReplay = "■ Stop autopilot (P)",
        radar = "🔎 Find nearby items (F)", radarOn = "❌ Disable radar (F)",
        save = "💾 Save point", memory = "🗺️ Saved points",
        optimize = "⚡ Optimize route",
        afk = "👀 Idle monitor", afkOn = "❌ Disable monitor",
        lang = "Language: RU / EN", hide = "⬇ Minimize menu", show = "Open Field AI", close = "Close",
        emptyRoute = "Record a route first",
        recording = "Recording route...", recorded = "Waypoints recorded: ",
        replaying = "Route replay started", stopped = "Autopilot stopped",
        radarStart = "Object scan enabled", radarStop = "Object scan disabled",
        found = "Objects found: ", saved = "Point saved. Total: ",
        emptyMemory = "No saved points yet",
        optimized = "Waypoints after optimization: ",
        afkStart = "Idle monitor enabled", afkStop = "Idle monitor disabled",
        afkWarn = "You have been inactive for a while",
        character = "Character not ready", noLoot = "No nearby objects found",
        error = "Operation error: ", distance = "Distance: ",
        clear = "Clear data", cleared = "Data cleared",
        export = "Export memory",
        import = "Import memory",
        confirmClear = "Confirm clearing data",
        yes = "Yes", no = "No"
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

-- Remove previous GUI
local old = PlayerGui:FindFirstChild("FieldAI2")
if old then old:Destroy() end

-- Helper to create instances
local function new(class, props)
    local inst = Instance.new(class)
    for k,v in pairs(props or {}) do
        inst[k] = v
    end
    return inst
end

-- Main GUI
local GUI = new("ScreenGui", {Name = "FieldAI2", ResetOnSpawn = false, DisplayOrder = 50})
GUI.Parent = PlayerGui

local Main = new("Frame", {
    Size = UDim2.fromOffset(360, 430),
    Position = UDim2.new(0, 12, 0.12, 0),
    BackgroundColor3 = Color3.fromRGB(24, 27, 32),
    BorderSizePixel = 1,
    BorderColor3 = Color3.fromRGB(80, 90, 100),
    ClipsDescendants = true,
    Parent = GUI
})

local Header = new("Frame", {Size = UDim2.new(1,0,0,48), BackgroundColor3 = Color3.fromRGB(40,44,50), Parent = Main})
local Title = new("TextLabel", {Parent = Header, Size = UDim2.new(1,-10,1,0), Position = UDim2.new(0,8,0,0), BackgroundTransparency = 1, Text = tr("title"), TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left})

local Status = new("TextLabel", {Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1,-16,0,36), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(185,220,195), TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = Main})

-- status updater (fix: was missing and caused errors)
local function status(message)
    if Status and Status.Parent then
        Status.Text = tostring(message or "")
    end
end

-- connectOnce helper (one-shot connections)
local function connectOnce(event, fn)
    local conn
    conn = event:Connect(function(...)
        if conn then conn:Disconnect() end
        pcall(fn, ...)
    end)
    return conn
end

-- Buttons grid
local ButtonsFrame = new("Frame", {Position = UDim2.fromOffset(8,96), Size = UDim2.new(1,-16,0,320), BackgroundTransparency = 1, Parent = Main})
local Grid = new("UIGridLayout", {CellSize = UDim2.new(0,170,0,48), CellPadding = UDim2.new(0,8,0,8), FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, Parent = ButtonsFrame})

local Buttons = {}
local function makeButton(key)
    local b = new("TextButton", {Name = key, Size = UDim2.fromOffset(170,48), BackgroundColor3 = Color3.fromRGB(50,56,64), TextColor3 = Color3.new(1,1,1), Font = Enum.Font.Gotham, TextSize = 14, Text = tr(key), Parent = ButtonsFrame})
    b.MouseEnter:Connect(function() status(tr(key)) end)
    b.MouseLeave:Connect(function() status(tr("ready")) end)
    return b
end

-- Action helpers
local function updateButtons()
    if Buttons.record then Buttons.record.Text = tr(S.Recording and "stopRecord" or "record") end
    if Buttons.replay then Buttons.replay.Text = tr(S.Replaying and "stopReplay" or "replay") end
    if Buttons.radar then Buttons.radar.Text = tr(S.Radar and "radarOn" or "radar") end
    if Buttons.afk then Buttons.afk.Text = tr(S.AFK and "afkOn" or "afk") end
end

-- Core features (reused from previous)
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

local function savePoint(name, position, kind)
    table.insert(S.Memory, {Name = name, Position = position, Kind = kind or "Point", Time = os.time()})
    if #S.Memory > 1000 then table.remove(S.Memory, 1) end
end

local function getImage(object)
    local decal = object:FindFirstChildWhichIsA("Decal", true)
    if decal and decal.Texture ~= "" then return decal.Texture end
    local texture = object:FindFirstChildWhichIsA("Texture", true)
    if texture and texture.Texture ~= "" then return texture.Texture end
    if object:IsA("MeshPart") and object.TextureID ~= "" then return object.TextureID end
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
            local ok, pos = pcall(function() return obj.Position end)
            if not ok then continue end
            local distance = (pos - root.Position).Magnitude
            if distance <= CFG.ScanRadius and (obj.CanTouch or obj.CanQuery) then
                local model = obj:FindFirstAncestorOfClass("Model")
                local name = model and model.Name or obj.Name
                table.insert(results, {Name = name, Position = pos, Distance = distance, Image = getImage(model or obj)})
            end
        end
    end
    table.sort(results, function(a,b) return a.Distance < b.Distance end)
    S.Loot = {}
    for i = 1, math.min(#results, CFG.MaxObjects) do table.insert(S.Loot, results[i]) end
    for _, item in ipairs(S.Loot) do savePoint(item.Name, item.Position, "Scanned") end
    if #S.Loot == 0 then status(tr("noLoot")) else local first=S.Loot[1]; status(tr("found")..#S.Loot.." | "..first.Name.." | "..tr("distance")..math.floor(first.Distance)..(first.Image and " | Image available" or "")) end
end

local function clearData(reason)
    S.Recording = false; S.Replaying = false; S.Radar = false; S.AFK = false
    S.Route, S.Memory, S.Loot = {}, {}, {}
    status(tr("cleared"))
    updateButtons()
end

-- Buttons implementation
Buttons.record = makeButton("record")
Buttons.replay = makeButton("replay")
Buttons.radar = makeButton("radar")
Buttons.save = makeButton("save")
Buttons.memory = makeButton("memory")
Buttons.optimize = makeButton("optimize")
Buttons.afk = makeButton("afk")
Buttons.lang = makeButton("lang")
Buttons.hide = makeButton("hide")
Buttons.export = makeButton("export")
Buttons.import = makeButton("import")
Buttons.clear = makeButton("clear")
Buttons.close = makeButton("close")

-- Modal for import/export
local Modal = new("Frame", {Size = UDim2.fromOffset(540,300), Position = UDim2.new(0.5,-270,0.5,-150), BackgroundColor3 = Color3.fromRGB(18,18,20), BorderSizePixel = 1, Parent = GUI, Visible = false})
local ModalTitle = new("TextLabel", {Parent = Modal, Size = UDim2.new(1,0,0,36), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 16})
local TextBox = new("TextBox", {Parent = Modal, Position = UDim2.fromOffset(10,46), Size = UDim2.new(1,-20,1,-96), TextWrapped=true, ClearTextOnFocus=false, TextEditable=true, Text = "", Font = Enum.Font.Gotham, TextSize = 14})
local ModalButtons = new("Frame", {Parent = Modal, Size = UDim2.new(1,0,0,40), Position = UDim2.new(0,0,1,-40), BackgroundTransparency = 1})
local BtnImport = new("TextButton", {Parent = ModalButtons, Size = UDim2.fromOffset(120,28), Position = UDim2.new(1,-130,0,6), Text = tr("import"), BackgroundColor3 = Color3.fromRGB(60,120,60), TextColor3 = Color3.new(1,1,1), Font = Enum.Font.Gotham, TextSize = 14})
local BtnCloseModal = new("TextButton", {Parent = ModalButtons, Size = UDim2.fromOffset(80,28), Position = UDim2.fromOffset(10,6), Text = tr("no"), BackgroundColor3 = Color3.fromRGB(140,40,40), TextColor3 = Color3.new(1,1,1), Font = Enum.Font.Gotham, TextSize = 14})

local function openExport()
    ModalTitle.Text = tr("export")
    TextBox.Text = HttpService:JSONEncode(S.Memory)
    BtnImport.Text = tr("yes")
    Modal.Visible = true
end

local function openImport()
    ModalTitle.Text = tr("import")
    TextBox.Text = "" -- user pastes JSON
    BtnImport.Text = tr("import")
    Modal.Visible = true
end

BtnCloseModal.Activated:Connect(function() Modal.Visible=false end)
BtnImport.Activated:Connect(function()
    local t = TextBox.Text
    if not t or t == "" then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(t) end)
    if not ok or type(data) ~= "table" then status(tr("error").." Invalid JSON"); return end
    -- basic validation
    local imported = {}
    for i,v in ipairs(data) do
        if v.Position and v.Name then
            table.insert(imported, v)
        end
    end
    for _,v in ipairs(imported) do table.insert(S.Memory, v) end
    status(tr("saved")..#S.Memory)
    Modal.Visible=false
end)

-- Button callbacks
Buttons.record.Activated:Connect(function()
    if S.Recording then S.Recording=false; status(tr("recorded")..#S.Route) else S.Route={}, S.LastRecord=0, S.Recording=true; status(tr("recording")) end
    updateButtons()
end)

Buttons.replay.Activated:Connect(function()
    if S.Replaying then S.Replaying=false; status(tr("stopped")); updateButtons(); return end
    if #S.Route < 2 then status(tr("emptyRoute")); return end
    S.Recording=false; S.Replaying=true; updateButtons(); status(tr("replaying"))
    task.spawn(function()
        local ok, err = pcall(function()
            for _, position in ipairs(S.Route) do
                if not S.Replaying then break end
                local _, hum = characterData()
                if not hum then break end
                hum:MoveTo(position)
                local reached = false
                local connection = hum.MoveToFinished:Connect(function(result) reached = result end)
                local started = os.clock()
                while S.Replaying and not reached and os.clock() - started < 8 do task.wait(0.1) end
                connection:Disconnect()
                if not reached then break end
            end
        end)
        S.Replaying=false; updateButtons()
        if not ok then status(tr("error")..tostring(err)) else status(tr("stopped")) end
    end)
end)

Buttons.radar.Activated:Connect(function()
    S.Radar = not S.Radar
    status(tr(S.Radar and "radarStart" or "radarStop"))
    updateButtons()
    if S.Radar then task.spawn(function() while S.Radar and GUI.Parent do safe(scanLoot); task.wait(CFG.ScanInterval) end end) end
end)

Buttons.save.Activated:Connect(function()
    local root = rootPart(); if not root then status(tr("character")); return end
    savePoint("Point "..(#S.Memory+1), root.Position, "Manual"); status(tr("saved")..#S.Memory)
end)

Buttons.memory.Activated:Connect(function()
    if #S.Memory == 0 then status(tr("emptyMemory")); return end
    local result = {}
    for i = math.max(1, #S.Memory - 8), #S.Memory do local item=S.Memory[i]; local p=item.Position; table.insert(result, string.format("%s: %.0f, %.0f, %.0f", item.Name, p.X, p.Y, p.Z)) end
    status(table.concat(result, " | "))
end)

Buttons.optimize.Activated:Connect(function()
    if #S.Route < 3 then status(tr("emptyRoute")); return end
    local function clearLine(a,b)
        local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = {LP.Character}; params.IgnoreWater = true; return Workspace:Raycast(a, b - a, params) == nil
    end
    local optimized = {S.Route[1]}; local i=1
    while i < #S.Route do
        local nextIndex = i+1
        for j = #S.Route, i+1, -1 do if clearLine(S.Route[i], S.Route[j]) then nextIndex=j; break end end
        table.insert(optimized, S.Route[nextIndex]); i = nextIndex
    end
    S.Route = optimized; status(tr("optimized")..#S.Route)
end)

Buttons.afk.Activated:Connect(function() S.AFK = not S.AFK; S.LastInput = os.clock(); S.LastAFKWarning = 0; status(tr(S.AFK and "afkStart" or "afkStop")); updateButtons() end)
Buttons.lang.Activated:Connect(function() S.Lang = S.Lang == "RU" and "EN" or "RU"; for k,v in pairs(Buttons) do v.Text = tr(k) end; status(tr("ready")) end)
Buttons.hide.Activated:Connect(function() Main.Visible=false; local openBtn = PlayerGui:FindFirstChild("FieldAI2Open") if not openBtn then local Open = new("TextButton", {Name = "FieldAI2Open", Size = UDim2.fromOffset(120,40), Position = UDim2.new(0,12,0.5,0), BackgroundColor3 = Color3.fromRGB(35,40,47), TextColor3 = Color3.new(1,1,1), Text = tr("show"), Parent = PlayerGui}) Open.Activated:Connect(function() Main.Visible=true; Open:Destroy() end) end end)

Buttons.export.Activated:Connect(function() openExport() end)
Buttons.import.Activated:Connect(function() openImport() end)

Buttons.clear.Activated:Connect(function()
    -- simple confirmation
    ModalTitle.Text = tr("confirmClear")
    TextBox.Text = ""
    BtnImport.Text = tr("yes")
    Modal.Visible = true
    connectOnce(BtnImport.Activated, function()
        clearData()
        Modal.Visible = false
    end)
end)

Buttons.close.Activated:Connect(function() GUI:Destroy() end)

-- Keyboard shortcuts
if CFG.Hotkeys then
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.R then Buttons.record:Activate() end
            if input.KeyCode == Enum.KeyCode.P then Buttons.replay:Activate() end
            if input.KeyCode == Enum.KeyCode.F then Buttons.radar:Activate() end
            if input.KeyCode == Enum.KeyCode.M then Buttons.memory:Activate() end
        end
    end)
end

-- UX: dragging
local dragging = false; local dragStart, frameStart, activeInput
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; frameStart = Main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
Header.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then activeInput = input end end)
UIS.InputChanged:Connect(function(input) if dragging and input == activeInput then local delta = input.Position - dragStart; Main.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y) end end)

-- Heartbeat tasks
local heartbeat
heartbeat = RunService.Heartbeat:Connect(function()
    if not GUI.Parent then heartbeat:Disconnect(); return end
    if S.Recording then safe(recordPosition) end
    if S.AFK and os.clock() - S.LastInput >= CFG.AFKSeconds and os.clock() - S.LastAFKWarning >= CFG.AFKSeconds then
        S.LastAFKWarning = os.clock(); status(tr("afkWarn")); warn("[Field AI] "..tr("afkWarn"))
    end
end)

-- Initial state
updateButtons(); status(tr("ready"))
print("[Field AI 2.1] Loaded successfully")

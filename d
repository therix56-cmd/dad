-- ==============================================================
-- BRAINROT NOTIFY + MULTI-PET ESP + SMART HOPPER + BLACKSCREEN (KOMBINIERT)
-- ==============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local function waitLP()
    local p = Players.LocalPlayer
    while not p do task.wait(); p = Players.LocalPlayer end
    return p
end
local LP = waitLP()

-- ==============================================================
-- BLACKSCREEN KONFIGURATION
-- ==============================================================

local BLACKSCREEN_ENABLED = false
local BLACKSCREEN_KEY = Enum.KeyCode.Delete

-- ==============================================================
-- BRAINROT ESP KONFIGURATION
-- ==============================================================

local WEBHOOK_URL = "https://ptb.discord.com/api/webhooks/1439694792417218754/ZIN_3W5IkQi7PlIjhpgFDYUJXAbU8XFNmX0JEO-7MWQ5Yj6NN4Iv26Gsi9qA4goKud0l"
local WEBHOOK_URL_1M_10M = "https://ptb.discord.com/api/webhooks/1442623003308593252/Q_soe0qt2RqoqzoabdQLpZoh3jynxnayiLZh1Za5lVW3RSnxrus24xZyeu0hRY_CU1Yk"
local hasNotified = false
local hasNotified1M = false

ESP_REFRESH = ESP_REFRESH or 0.40
CURRENT_BRAINROTS = CURRENT_BRAINROTS or {}
ESP_ENABLED = true
MIN_MPS_THRESHOLD = 10000000
MIN_MPS_THRESHOLD_1M = 1000000

local MODEL_SIZE_MAX = 200
local BOX_ALPHA = 0.70
local WHITE = Color3.fromRGB(255, 255, 255)
local PINK = Color3.fromRGB(255, 105, 180)
local YELLOW = Color3.fromRGB(255, 230, 0)

-- ==============================================================
-- SMART HOPPER KONFIGURATION
-- ==============================================================

local WS_BASE = 'ws://127.0.0.1:3001/ws'
local MIN_PLAYERS = 6
local PLACE_ID_OVERRIDE = nil

local RETRY_DELAY = 3.0
local QUICK_RECONNECT = 1.0
local MAX_LOAD_WAIT = 30

-- ==============================================================
-- BLACKSCREEN SYSTEM
-- ==============================================================

local blackscreenGui = nil

local function createBlackscreen()
    local PlayerGui = LP:WaitForChild("PlayerGui")
    
    if PlayerGui:FindFirstChild("BlackscreenGUI") then
        PlayerGui.BlackscreenGUI:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BlackscreenGUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 999999
    
    local blackFrame = Instance.new("Frame")
    blackFrame.Name = "BlackFrame"
    blackFrame.Size = UDim2.new(1, 0, 1, 0)
    blackFrame.Position = UDim2.new(0, 0, 0, 0)
    blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    blackFrame.BorderSizePixel = 0
    blackFrame.ZIndex = 999999
    blackFrame.Parent = screenGui
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(0, 300, 0, 50)
    infoLabel.Position = UDim2.new(0.5, -150, 0.5, -25)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Blackscreen aktiv - CPU gespart"
    infoLabel.TextColor3 = Color3.new(0.5, 0.5, 0.5)
    infoLabel.TextSize = 20
    infoLabel.Font = Enum.Font.SourceSans
    infoLabel.Parent = blackFrame
    
    screenGui.Parent = PlayerGui
    blackscreenGui = screenGui
    
    print("✅ Blackscreen aktiviert!")
end

local function destroyBlackscreen()
    if blackscreenGui then
        pcall(function() blackscreenGui:Destroy() end)
        blackscreenGui = nil
    end
    
    local PlayerGui = LP:WaitForChild("PlayerGui")
    if PlayerGui:FindFirstChild("BlackscreenGUI") then
        PlayerGui.BlackscreenGUI:Destroy()
    end
    
    print("✅ Blackscreen deaktiviert!")
end

local function optimizeGraphics()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100
    Lighting.Brightness = 0
    
    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") then
            effect.Enabled = false
        end
    end
    
    if settings():FindFirstChild("Rendering") then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end
    
    if setfpscap then
        setfpscap(20)
        print("✅ FPS auf 20 begrenzt!")
    end
    
    print("✅ Grafik-Optimierungen aktiviert!")
end

local function restoreGraphics()
    Lighting.GlobalShadows = true
    Lighting.Brightness = 2
    
    if setfpscap then
        setfpscap(0)
    end
    
    print("✅ Grafik-Einstellungen wiederhergestellt!")
end

local function enableBlackscreen()
    createBlackscreen()
    optimizeGraphics()
    BLACKSCREEN_ENABLED = true
end

local function disableBlackscreen()
    destroyBlackscreen()
    restoreGraphics()
    BLACKSCREEN_ENABLED = false
end

-- ==============================================================
-- HELPER FUNKTIONEN (BRAINROT ESP)
-- ==============================================================

local function shortMoney(v)
    v = tonumber(v) or 0
    if v >= 1e9 then return string.format('$%.2fB/s', v / 1e9)
    elseif v >= 1e6 then return string.format('$%.2fM/s', v / 1e6)
    elseif v >= 1e3 then return string.format('$%.0fK/s', v / 1e3)
    else return string.format('$%d/s', math.floor(v)) end
end

local function parseMPS(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub(",", ""):gsub("%s+", "")
    local num, unit = s:match("%$?([%d%.]+)([kKmMbB]?)/[sS]")
    if not num then return nil end
    local value = tonumber(num)
    if not value then return nil end
    local mult = (unit == "k" or unit == "K") and 1e3 or (unit == "m" or unit == "M") and 1e6 or (unit == "b" or unit == "B") and 1e9 or 1
    return value * mult
end

local function insideBase(inst)
    local p = inst
    while p and p ~= Workspace do
        local n = p.Name:lower()
        if n:find("plot") or n:find("base") then return true end
        p = p.Parent
    end
    return false
end

local function firstBasePart(m)
    if m:IsA("Model") and m.PrimaryPart then return m.PrimaryPart end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
end

local function modelFromGui(gui)
    local root = gui.Adornee
    local mdl = root and root:FindFirstAncestorOfClass("Model") or gui:FindFirstAncestorOfClass("Model")
    if not mdl or not insideBase(mdl) then return end
    local ok, _, size = pcall(mdl.GetBoundingBox, mdl)
    if not ok or not size or size.Magnitude > MODEL_SIZE_MAX then return end
    return mdl, (root and root:IsA("BasePart") and root or firstBasePart(mdl))
end

local function lowestPart(mdl)
    local minY, part = math.huge, nil
    if not mdl then return nil end
    for _, d in ipairs(mdl:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then
            if d.Position.Y < minY then minY, part = d.Position.Y, d end
        end
    end
    return part
end

-- ==============================================================
-- NAMEN-ERKENNUNG (ESP LOGIK)
-- ==============================================================

local BAD_TOKENS = {
    "collect","offline","cash","/s","$",
    "gold","silver","bronze",
    "myth","mythic","god",
    "legend","legendary","epic",
    "rare","uncommon","common","secret",
    "diamond","emerald","ruby","amethyst",
}

local function hasBadToken(txt)
    local low = txt:lower()
    for _,w in ipairs(BAD_TOKENS) do 
        if low:find(w, 1, true) then return true end 
    end
    return false
end

local function luminance(c) 
    return c.R*0.299 + c.G*0.587 + c.B*0.114 
end

local function saturation(c)
    local max = math.max(c.R, math.max(c.G, c.B))
    local min = math.min(c.R, math.min(c.G, c.B))
    if max == min then return 0 end
    local l = (max+min)/2
    if l == 0 or l == 1 then return 0 end
    return (max-min) / (1 - math.abs(2*l - 1))
end

local function looksLikeMainTitle(lbl)
    local txt = (lbl.Text or ""):gsub("<.->","")
    if txt == "" then return false end
    if hasBadToken(txt) then return false end
    local bright = luminance(lbl.TextColor3) >= 0.72
    local darkStroke = luminance(lbl.TextStrokeColor3) <= 0.25
    local strongStroke = (tonumber(lbl.TextStrokeTransparency) or 1) <= 0.30
    local lowSat = saturation(lbl.TextColor3) <= 0.20
    return bright and darkStroke and strongStroke and lowSat
end

local function scoreTitleLabel(gui, t)
    local txt = (t.Text or ""):gsub("<.->","")
    if txt == "" then return -1 end
    if hasBadToken(txt) then return -1 end

    local sc = 0
    pcall(function()
        local b = t.TextBounds
        sc = sc + (b.X + 2*b.Y)
        local gy = gui.AbsolutePosition.Y
        local ty = t.AbsolutePosition.Y
        sc = sc + math.max(0, 340 - math.clamp(ty - gy, 0, 340))
    end)

    if looksLikeMainTitle(t) then sc = sc + 10000 end
    sc = sc - math.floor(saturation(t.TextColor3) * 500)
    return sc
end

local function chooseMainTitleInGui(gui)
    local bestTL, bestScore = nil, -1
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") then
            local sc = scoreTitleLabel(gui, d)
            if sc > bestScore then bestScore, bestTL = sc, d end
        end
    end
    return bestTL and (bestTL.Text or ""):gsub("<.->","") or nil
end

-- ==============================================================
-- BRAINROT FINDEN (MIT 1M-10M UNTERSTÜTZUNG)
-- ==============================================================

local function findAllBrainrots()
    local brainrots = {}
    local brainrots1M = {}
    
    for _, gui in ipairs(Workspace:GetDescendants()) do
        if gui:IsA("BillboardGui") then
            local mdl, root = modelFromGui(gui)
            if mdl and root then
                local mps = nil
                
                for _, child in ipairs(gui:GetDescendants()) do
                    if child:IsA("TextLabel") then
                        local parsedMPS = parseMPS(child.Text or "")
                        if parsedMPS and (not mps or parsedMPS > mps) then
                            mps = parsedMPS
                        end
                    end
                end
                
                local name = chooseMainTitleInGui(gui)
                
                if name and mps then
                    local id = tostring(root:GetDebugId())
                    local brainrotData = {
                        id = id,
                        name = name,
                        mps = mps,
                        mpsFormatted = shortMoney(mps),
                        model = mdl,
                        root = root
                    }
                    
                    if mps >= MIN_MPS_THRESHOLD then
                        table.insert(brainrots, brainrotData)
                    elseif mps >= MIN_MPS_THRESHOLD_1M and mps < MIN_MPS_THRESHOLD then
                        table.insert(brainrots1M, brainrotData)
                    end
                end
            end
        end
    end
    
    table.sort(brainrots, function(a, b) return a.mps > b.mps end)
    table.sort(brainrots1M, function(a, b) return a.mps > b.mps end)
    
    return brainrots, brainrots1M
end

-- ==============================================================
-- ESP SYSTEM
-- ==============================================================

local activeESPs = {}

local function destroyESP(id)
    if not activeESPs[id] then return end
    if activeESPs[id].bb then pcall(function() activeESPs[id].bb:Destroy() end) end
    if activeESPs[id].box then pcall(function() activeESPs[id].box:Destroy() end) end
    activeESPs[id] = nil
end

local function destroyAllESPs()
    for id, _ in pairs(activeESPs) do
        destroyESP(id)
    end
end

local function ensurePlatformBox(id, platformPart)
    if not platformPart then return end
    activeESPs[id] = activeESPs[id] or {}
    
    if not activeESPs[id].box or (activeESPs[id].box.Adornee ~= platformPart) or not activeESPs[id].box.Parent then
        if activeESPs[id].box then pcall(function() activeESPs[id].box:Destroy() end) end
        local box = Instance.new("BoxHandleAdornment")
        box.Name = "__ESP_PLATFORM_" .. id .. "__"
        box.AlwaysOnTop = true
        box.ZIndex = 10
        box.Adornee = platformPart
        box.Size = platformPart.Size + Vector3.new(0.02, 0.02, 0.02)
        box.Color3 = YELLOW
        box.Transparency = BOX_ALPHA
        box.Parent = platformPart
        activeESPs[id].box = box
    else
        activeESPs[id].box.Adornee = platformPart
        activeESPs[id].box.Size = platformPart.Size + Vector3.new(0.02, 0.02, 0.02)
    end
end

local function ensureMainBillboard(id, name, amount, targetRoot)
    if not targetRoot then return end
    activeESPs[id] = activeESPs[id] or {}
    
    if (not activeESPs[id].bb) or not activeESPs[id].bb.Parent or (activeESPs[id].bb.Adornee ~= targetRoot) then
        if activeESPs[id].bb then pcall(function() activeESPs[id].bb:Destroy() end) end
        
        local bb = Instance.new("BillboardGui")
        bb.Name = "__ESP_MAIN_" .. id .. "__"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 260, 0, 64)
        bb.StudsOffset = Vector3.new(0, 4.5, 0)
        bb.MaxDistance = 600
        bb.Adornee = targetRoot
        bb.Parent = targetRoot

        local top = Instance.new("TextLabel")
        top.Name = "Name"
        top.BackgroundTransparency = 1
        top.Size = UDim2.new(1,0,0,34)
        top.Position = UDim2.new(0,0,0,-2)
        top.Font = Enum.Font.GothamBlack
        top.TextScaled = true
        top.TextColor3 = PINK
        top.TextStrokeTransparency = 0.15
        top.TextStrokeColor3 = Color3.fromRGB(10,12,16)
        top.Parent = bb

        local bot = Instance.new("TextLabel")
        bot.Name = "Value"
        bot.BackgroundTransparency = 1
        bot.Size = UDim2.new(1,0,0,28)
        bot.Position = UDim2.new(0,0,0,32)
        bot.Font = Enum.Font.GothamBold
        bot.TextScaled = true
        bot.TextColor3 = WHITE
        bot.TextStrokeTransparency = 0.2
        bot.TextStrokeColor3 = Color3.fromRGB(10,12,16)
        bot.Parent = bb

        activeESPs[id].bb = bb
    end
    
    local t1 = activeESPs[id].bb:FindFirstChild("Name")
    if t1 then t1.Text = tostring(name or "Brainrot") end
    local t2 = activeESPs[id].bb:FindFirstChild("Value")
    if t2 then t2.Text = shortMoney(amount or 0) end
end

-- ==============================================================
-- WEBHOOK SYSTEM (MIT 1M-10M SUPPORT)
-- ==============================================================

local function sendWebhook(brainrotData, webhookUrl)
    local realJobId = game.JobId
    local playerCountText = tostring(#Players:GetPlayers()) .. "/" .. tostring(game:GetService("Players").MaxPlayers or 8)

    local embed = {
        {
            title = "Brainrot Notify | Aqua Hub",
            color = 65535,
            fields = {
                { 
                    name = "🏷️ Name", 
                    value = brainrotData.name, 
                    inline = true 
                },
                { 
                    name = "💰 Money per sec", 
                    value = brainrotData.mpsFormatted, 
                    inline = true 
                },
                { 
                    name = "👥 Players", 
                    value = playerCountText, 
                    inline = true 
                }
            },
            footer = { 
                text = "Aqua Hub v1 • " .. os.date("heute um %H:%M Uhr • %d.%m.%Y %H:%M")
            }
        }
    }
    
    if brainrotData.otherBrainrots and #brainrotData.otherBrainrots > 0 then
        local otherText = "🧠 **Other Brainrots**"
        for _, other in ipairs(brainrotData.otherBrainrots) do
            otherText = otherText .. string.format("\n**%s** %s", other.name, other.mps)
        end
        table.insert(embed[1].fields, {
            name = "​",
            value = otherText,
            inline = false
        })
    end
    
    table.insert(embed[1].fields, {
        name = "💎 Job ID (PC)",
        value = "```" .. realJobId .. "```",
        inline = false
    })

    local data = { 
        embeds = embed, 
        username = "Brainrot Notify | Aqua Hub",
        avatar_url = "https://cdn.discordapp.com/attachments/123456789012345678/123456789012345678/aquahub.png"
    }

    local jsonData = HttpService:JSONEncode(data)
    
    local success, result = pcall(function()
        if syn and syn.request then
            return syn.request({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonData
            })
        end
        
        if request then
            return request({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonData
            })
        end
        
        if http_request then
            return http_request({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonData
            })
        end
        
        return HttpService:PostAsync(webhookUrl, jsonData)
    end)

    if success then
        warn("✅ Webhook erfolgreich gesendet!")
    else
        warn("❌ Webhook Fehler: " .. tostring(result))
    end
    
    return success
end

-- ==============================================================
-- ESP LOOP
-- ==============================================================

local wasEnabled = false

task.spawn(function()
    while true do
        if ESP_ENABLED then
            if not wasEnabled then wasEnabled = true end

            local brainrots, brainrots1M = findAllBrainrots()
            local currentIDs = {}
            
            for _, br in ipairs(brainrots) do
                currentIDs[br.id] = true
                
                ensureMainBillboard(br.id, br.name, br.mps, br.root)
                
                local platform = lowestPart(br.model)
                ensurePlatformBox(br.id, platform)
                
                CURRENT_BRAINROTS[br.id] = {
                    name = br.name,
                    mps = br.mps,
                    part = platform or br.root,
                    pos = platform and (platform.CFrame * CFrame.new(0, 6, 0)).Position 
                          or (br.root.Position + Vector3.new(0, 6, 0))
                }
            end
            
            for id, _ in pairs(activeESPs) do
                if not currentIDs[id] then
                    destroyESP(id)
                    CURRENT_BRAINROTS[id] = nil
                end
            end
            
        else
            if wasEnabled then
                destroyAllESPs()
                CURRENT_BRAINROTS = {}
                wasEnabled = false
            end
        end

        task.wait(ESP_REFRESH)
    end
end)

-- ==============================================================
-- TELEPORT SYSTEM
-- ==============================================================

local TELEPORT_KEY = Enum.KeyCode.N

local function tpToHighestBrainrot()
    local highest = nil
    local highestMPS = -1
    
    for id, data in pairs(CURRENT_BRAINROTS) do
        if data.mps and data.mps > highestMPS and data.pos then
            highestMPS = data.mps
            highest = data
        end
    end
    
    if not highest or not highest.pos then 
        print("❌ Kein Pet gefunden!")
        return 
    end
    
    local ch = LP.Character or LP.CharacterAdded:Wait()
    local hrp = ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end
    
    pcall(function() setAntiRagdoll(true) end)
    
    local target = highest.pos
    for i = 1, 2 do
        hrp.CFrame = CFrame.new(target, target + hrp.CFrame.LookVector)
        task.wait(0.02)
    end
    
    print("✅ Teleportiert zu:", highest.name, "-", shortMoney(highest.mps))
end

UIS.InputBegan:Connect(function(io, gp)
    if gp then return end
    if io.KeyCode == TELEPORT_KEY then 
        tpToHighestBrainrot()
    end
    if io.KeyCode == BLACKSCREEN_KEY then
        if BLACKSCREEN_ENABLED then
            disableBlackscreen()
        else
            enableBlackscreen()
        end
    end
end)

-- ==============================================================
-- WEBHOOK EINMAL BEIM START (MIT 1M-10M SUPPORT)
-- ==============================================================

task.spawn(function()
    warn("🧠 Brainrot Notify + ESP GESTARTET!")
    warn("⏳ Warte 3 Sekunden auf Daten...")
    
    task.wait(3)
    
    local allBrainrots, allBrainrots1M = findAllBrainrots()
    
    -- Webhook für 10M+ Pets
    if #allBrainrots > 0 and not hasNotified then
        local best = allBrainrots[1]
        local webhookData = {
            name = best.name,
            mpsFormatted = best.mpsFormatted
        }
        
        if #allBrainrots > 1 then
            webhookData.otherBrainrots = {}
            for i = 2, math.min(#allBrainrots, 5) do
                table.insert(webhookData.otherBrainrots, {
                    name = allBrainrots[i].name,
                    mps = allBrainrots[i].mpsFormatted
                })
            end
        end
        
        local success = sendWebhook(webhookData, WEBHOOK_URL)
        if success then
            hasNotified = true
            warn("✅ 10M+ Webhook gesendet!")
        end
    else
        warn("❌ Keine Brainrots über 10M/s gefunden")
    end
    
    -- Webhook für 1M-10M Pets
    if #allBrainrots1M > 0 and not hasNotified1M then
        local best1M = allBrainrots1M[1]
        local webhookData1M = {
            name = best1M.name,
            mpsFormatted = best1M.mpsFormatted
        }
        
        if #allBrainrots1M > 1 then
            webhookData1M.otherBrainrots = {}
            for i = 2, math.min(#allBrainrots1M, 5) do
                table.insert(webhookData1M.otherBrainrots, {
                    name = allBrainrots1M[i].name,
                    mps = allBrainrots1M[i].mpsFormatted
                })
            end
        end
        
        local success1M = sendWebhook(webhookData1M, WEBHOOK_URL_1M_10M)
        if success1M then
            hasNotified1M = true
            warn("✅ 1M-10M Webhook gesendet!")
        end
    else
        warn("❌ Keine Brainrots zwischen 1M-10M/s gefunden")
    end
end)

-- ==============================================================
-- SMART HOPPER - GAME LOADING
-- ==============================================================

local function waitForFullGameLoad()
    print('[HOP] ⏳ Waiting for full game load...')
    local startTime = tick()
    
    if not game:IsLoaded() then
        pcall(function() game.Loaded:Wait() end)
    end
    
    local lp = LP or waitLP()
    
    local char = lp.Character
    if not char then
        local success = pcall(function()
            char = lp.CharacterAdded:Wait()
        end)
        if not success then
            warn('[HOP] ⚠ Character wait failed!')
            return false
        end
    end
    
    local hrp = char:WaitForChild("HumanoidRootPart", 15)
    if not hrp then
        warn('[HOP] ⚠ HumanoidRootPart timeout!')
        return false
    end
    
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then
        warn('[HOP] ⚠ Humanoid timeout!')
        return false
    end
    
    task.wait(3)
    
    local elapsed = tick() - startTime
    print(string.format('[HOP] ✅ Game fully loaded in %.1fs!', elapsed))
    return true
end

-- Anti-AFK
pcall(function()
    local vu = game:GetService('VirtualUser')
    LP.Idled:Connect(function()
        vu:CaptureController(); vu:ClickButton2(Vector2.new())
    end)
end)

-- ==============================================================
-- SMART HOPPER - WEBSOCKET
-- ==============================================================

local wsConnect = nil
do
    local ok, lib = pcall(function() return (syn and syn.websocket) end)
    if ok and lib and lib.connect then wsConnect = lib.connect end
    if (not wsConnect) and WebSocket and WebSocket.connect then wsConnect = WebSocket.connect end
end

local running = false
local ws = nil
local teleportInProgress = false
local currentJobId = tostring(game.JobId or "")
local connectionAttempts = 0
local lastRequestTime = 0

local function safeTeleport(jobId)
    if not running then 
        warn('[HOP] ⏸ Not running yet - skipping teleport')
        return 
    end
    
    if teleportInProgress then 
        warn('[HOP] ⏸ Teleport already in progress')
        return 
    end
    
    if not jobId or jobId == "" then
        warn('[HOP] ⚠ Invalid jobId received')
        return
    end
    
    print('[HOP] 🚀 TELEPORTING to:', jobId)
    teleportInProgress = true
    
    local success = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            PLACE_ID_OVERRIDE or game.PlaceId,
            jobId,
            LP
        )
    end)
    
    if not success then
        warn('[HOP] ⚠ Teleport call failed!')
        teleportInProgress = false
    end
end

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    warn('[HOP] ⚠ Teleport failed:', teleportResult, errorMessage)
    teleportInProgress = false
    
    if ws then
        pcall(function()
            ws:Send(HttpService:JSONEncode({ 
                type = 'release', 
                id = currentJobId
            }))
        end)
        
        task.delay(RETRY_DELAY, function()
            if ws and running then
                print('[HOP] 🔄 Requesting new server after failure...')
                pcall(function()
                    ws:Send(HttpService:JSONEncode({ 
                        type = 'next',
                        currentJob = tostring(game.JobId)
                    }))
                end)
            end
        end)
    end
end)

task.spawn(function()
    local lastSeen = currentJobId
    while true do
        local jid = tostring(game.JobId or "")
        if jid ~= "" and jid ~= lastSeen then
            lastSeen = jid
            currentJobId = jid
            
            print('[HOP] 🌐 Server changed to:', jid)
            
            if ws then
                pcall(function()
                    ws:Send(HttpService:JSONEncode({ 
                        type = 'joined', 
                        id = jid
                    }))
                end)
            end
            
            teleportInProgress = false
            task.wait(QUICK_RECONNECT)
            
            if ws and running then
                print('[HOP] 🔄 Requesting next server...')
                pcall(function()
                    ws:Send(HttpService:JSONEncode({ 
                        type = 'next',
                        currentJob = jid
                    }))
                end)
            end
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while true do
        task.wait(30)
        
        if running and ws and not teleportInProgress then
            local now = tick()
            if now - lastRequestTime > 30 then
                print('[HOP] ⏰ Watchdog: Requesting server (no activity)')
                pcall(function()
                    ws:Send(HttpService:JSONEncode({ 
                        type = 'next',
                        currentJob = tostring(game.JobId)
                    }))
                end)
                lastRequestTime = now
            end
        end
    end
end)

local function connectWS()
    if not wsConnect then 
        warn('[HOP] ❌ WebSocket not available!')
        return false
    end
    
    connectionAttempts = connectionAttempts + 1
    
    LP = waitLP()
    local who = tostring(LP and LP.UserId or 0)
    local placeParam = tostring(PLACE_ID_OVERRIDE or game.PlaceId)
    
    local url = string.format('%s?placeId=%s&who=%s&minPlayers=%d',
        WS_BASE, placeParam, who, MIN_PLAYERS)

    print(string.format('[HOP] 🔌 Connecting... (attempt #%d)', connectionAttempts))
    
    local success, sock = pcall(function()
        return wsConnect(url)
    end)
    
    if not success or not sock then 
        warn('[HOP] ❌ Connection failed!')
        return false
    end
    
    ws = sock
    print('[HOP] ✅ Connected!')
    connectionAttempts = 0

    if ws.OnMessage then
        ws.OnMessage:Connect(function(msg)
            local ok, data = pcall(function() return HttpService:JSONDecode(msg) end)
            if not ok or type(data) ~= 'table' then 
                warn('[HOP] ⚠ Invalid message received')
                return 
            end

            if data.type == 'next' then
                lastRequestTime = tick()
                
                if data.id and data.id ~= "" then
                    print('[HOP] 📥 Server received:', data.id)
                    safeTeleport(data.id)
                else
                    print('[HOP] ⏳ Waiting for servers...')
                    task.delay(5, function()
                        if ws and running and not teleportInProgress then
                            print('[HOP] 🔄 Re-requesting server...')
                            pcall(function()
                                ws:Send(HttpService:JSONEncode({ 
                                    type = 'next',
                                    currentJob = tostring(game.JobId)
                                }))
                            end)
                        end
                    end)
                end
            end
            
            if data.type == 'error' then
                warn('[HOP] ❌ Error:', data.error or 'unknown')
            end
        end)
    end
    
    if ws.OnClose then
        ws.OnClose:Connect(function()
            warn('[HOP] 🔌 Disconnected!')
            ws = nil
        end)
    end

    task.delay(0.2, function()
        if ws and running then
            lastRequestTime = tick()
            print('[HOP] 👋 Sending hello...')
            pcall(function()
                ws:Send(HttpService:JSONEncode({ 
                    type = 'hello',
                    currentJob = tostring(game.JobId)
                }))
            end)
        end
    end)
    
    return true
end

task.spawn(function()
    while true do
        if running and not ws then
            local success = pcall(connectWS)
            if not success then
                warn('[HOP] ❌ Connection error')
            end
            
            local delay = math.min(30, 3 * math.pow(1.5, math.min(connectionAttempts, 5)))
            task.wait(delay)
        else
            task.wait(3.0)
        end
    end
end)

-- ==============================================================
-- INITIALISIERUNG
-- ==============================================================

print("========================================")
print("✅ Multi-Pet ESP geladen! Zeigt alle Pets über 10M $/s")
print("⌨️ Drücke N zum Teleport zum höchsten Pet")
print("⌨️ Drücke DELETE zum Blackscreen An/Aus")
print("========================================")
print('[HOP] ========================================')
print('[HOP] ⚡ SMART HOPPER v2')
print('[HOP] ========================================')
print('[HOP] 🌐 Backend:', WS_BASE)
print('[HOP] 👥 Min Players:', MIN_PLAYERS)
print('[HOP] ========================================')

local loadSuccess = waitForFullGameLoad()

if not loadSuccess then
    warn('[HOP] ❌ Failed to load game properly!')
    warn('[HOP] ⚠ Hopper may not work correctly')
end

running = true

print('[HOP] ========================================')
print('[HOP] ✅ HOPPER STARTED!')
print('[HOP] 🚀 Auto-hopping enabled')
print('[HOP] ========================================')

task.wait(0.5)
local connSuccess = pcall(connectWS)

if not connSuccess then
    warn('[HOP] ⚠ Initial connection failed, will retry...')
end

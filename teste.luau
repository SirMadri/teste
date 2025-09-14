getgenv().method = "3m" -- seu método de server hop
getgenv().FPSDEVOUR = "aura" -- aura ou slap
--------==================================== VARIÁVEIS ====================================--------
local TPS = game:GetService("TeleportService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local StarterGui=game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Teams = game:GetService("Teams")
local playerGui = lp:WaitForChild('PlayerGui')
local CoreGui = game:GetService('CoreGui')
local UIS = game:GetService('UserInputService')
local player = Players.LocalPlayer
local playerId = tostring(player.UserId)
local settings = { fpsDevour = false, autoLaser = false, xRay = false, espBest = false }
local RunService = game:GetService('RunService')
local id = game.JobId
local character
local backpack

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Packages = ReplicatedStorage:FindFirstChild('Packages')
local Net = ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Net')
local useItemRemote = Net and Net:FindFirstChild('RE/UseItem')
local RequestBuy = Net:WaitForChild('RF/CoinsShopService/RequestBuy')

local placeID = game.PlaceId
local url = "http://join.bloxlabs.com.br:8000/job" -- url
local wsUrl = "ws://join.bloxlabs.com.br:8000/ws" -- WebSocket URL (servidor local)
local methods = getgenv().method
local key = "300m" -- key do script (3m, 5m, 10m, 50m, 100m, 300m)
local timeAPI = "https://worldtimeapi.org/api/timezone/America/Sao_Paulo"
local FPSDEVOURMETHOD = getgenv().FPSDEVOUR

-- Sistema WebSocket real usando Wave
local wsConnection = nil
local isWebSocketConnected = false
local wsReconnectAttempts = 0
local maxWsReconnectAttempts = 5
local useWebSocket = true -- Flag para usar WebSocket quando disponível (HABILITADO - WebSocket funcionando!)
local lastJobCheck = 0
local jobCheckInterval = 1 -- Fallback HTTP a cada 1 segundo

local DevourLoop = false
local AutoLaserLoop = false
local conn
local characterConn
local autoLaserConnection
local espConnection
local character
local slapConnections = {}
local slapLoop = nil

local allowedSlaps = {
    ['Nuclear Slap'] = true,
    ['Flame Slap'] = true,
    ['Glitched Slap'] = true,
    ['Galaxy Slap'] = true,
    ['Dark Matter Slap'] = true,
    ['Quantum Cloner'] = true,
}

--------==================================== SETTINGS ====================================--------

if type(methods) ~= "table" then methods = {methods} end
local avaiblemethods = {"1m","3m","5m","10m","50m","100m","300m"}
if key == "100m" then avaiblemethods = {"1m","3m","5m","10m","50m","100m"}
elseif key == "50m" then avaiblemethods = {"1m","3m","5m","10m","50m"}
elseif key == "10m" then avaiblemethods = {"1m","3m","5m","10m"}
elseif key == "5m" then avaiblemethods = {"1m","3m","5m"}
elseif key == "3m" then avaiblemethods = {"1m","3m"} end

local allValid = true
for _, m in pairs(methods) do
    local methodIsValid = false
    for _, v in pairs(avaiblemethods) do
        if m == v then
            methodIsValid = true
            break
        end
    end
    if not methodIsValid then
        allValid = false
        break
    end
end
if not allValid then lp:Kick("Nenhum método de Hop válido.") end

local settingsFile = 'fpsDevour.json'
local function savesett()
    if writefile then
        pcall(function()
            writefile(settingsFile, HttpService:JSONEncode(settings))
        end)
    end
end
local function loadsett()
    if isfile and isfile(settingsFile) and readfile then
        local success, data = pcall(readfile, settingsFile)
        if success and data then
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, data)
            if ok and type(decoded) == 'table' then
                settings.fpsDevour = decoded.fpsDevour or false
                settings.autoLaser = decoded.autoLaser or false
                settings.xRay = decoded.xRay or false
                settings.espBest = decoded.espBest or false
            end
        end
    end
end

local function updateCharacterRefs()
    character = lp.Character or lp.CharacterAdded:Wait()
    backpack = lp:WaitForChild('Backpack')
end

local function stopEverything()
    DevourLoop = false
    AutoLaserLoop = false
    if conn then
        conn:Disconnect()
        conn = nil
    end
    if autoLaserConnection then
        autoLaserConnection:Disconnect()
        autoLaserConnection = nil
    end
    if espConnection then
        espConnection:Disconnect()
        espConnection = nil
    end
end

--------==================================== X-RAY BASE ====================================--------

local transparency = 0.8
local savedState = Instance.new("BoolValue")
savedState.Name = "BaseInvisibleState"
savedState.Value = false
savedState.Parent = playerGui

local function setBaseInvisible(state)
    local Plots = workspace:FindFirstChild("Plots")
    if Plots then
        if state then
            for _,o in ipairs(Plots:GetDescendants()) do 
                if o:IsA("BasePart") then 
                    pcall(function() o.LocalTransparencyModifier = transparency end) 
                end 
            end
            Plots.DescendantAdded:Connect(function(o) 
                if o:IsA("BasePart") then 
                    pcall(function() o.LocalTransparencyModifier = transparency end) 
                end 
            end)
        else
            for _,o in ipairs(Plots:GetDescendants()) do 
                if o:IsA("BasePart") then 
                    pcall(function() o.LocalTransparencyModifier = 0 end) 
                end 
            end
        end
    end
end

--------==================================== FPS DEVOUR ====================================--------

local function showCompletionLabel()
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    local parentGui = playerGui

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "slaaaa"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = true
    screenGui.IgnoreGuiInset = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parentGui

    if not screenGui.Parent or not screenGui:IsDescendantOf(game) then
        parentGui = game:GetService("CoreGui")
        screenGui.Parent = parentGui
    end

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0, 300, 0, 50)
    textLabel.Position = UDim2.new(0.5, -150, 0.1, 0)
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.TextSize = 24
    textLabel.Font = Enum.Font.FredokaOne
    textLabel.Text = "FPS Devour concluido! Voce pode trocar de posição com seu clone se quiser."
    textLabel.BorderSizePixel = 0
    textLabel.BackgroundTransparency = 1
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.TextStrokeTransparency = 0
    textLabel.ZIndex = 100
    textLabel.Parent = screenGui

    task.spawn(function()
        local colors = {
            Color3.fromRGB(255, 0, 0),
            Color3.fromRGB(0, 255, 0),
            Color3.fromRGB(0, 150, 255),
            Color3.fromRGB(255, 255, 0),
            Color3.fromRGB(0, 0, 0),
            Color3.fromRGB(255, 255, 255)
        }
        local colorIndex = 1
        while textLabel and textLabel.Parent do
            textLabel.TextColor3 = colors[colorIndex]
            colorIndex = colorIndex % #colors + 1
            task.wait(0.1)
        end
    end)

    task.delay(5, function()
        if textLabel and textLabel.Parent then
            textLabel:Destroy()
        end
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end)
end

local function StartAuraLoop()
    if DevourLoop then return end
    
    DevourLoop = true

    updateCharacterRefs()

    if conn then conn:Disconnect() end
    
    conn = RunService.Heartbeat:Connect(function()
        if not DevourLoop then
            if conn then
                conn:Disconnect()
                conn = nil
            end
            return
        end

        if not character or not character.Parent then 
            updateCharacterRefs()
            return 
        end

        for _, obj in ipairs(workspace:GetChildren()) do
            local objName = tostring(obj.Name)

            local isClone = false
            local patterns = {
                '^' .. playerId .. '_Clone$',
                '^Clone_' .. playerId .. '$',
                '^' .. playerId .. 'Clone$',
                'Clone' .. playerId,
                playerId .. 'Clone'
            }
            
            for _, pattern in ipairs(patterns) do
                if objName:match(pattern) then
                    isClone = true
                    break
                end
            end
            
            if objName == playerId .. '_Clone' or objName == 'Clone_' .. playerId then
                isClone = true
            end
            
            if isClone then
                pcall(function()
                    obj:Destroy()
                    if DevourLoop then
                        showCompletionLabel()
                    end
                end)
                stopEverything()
                settings.fpsDevour = false
                savesett()
                return
            end
        end

        if not backpack or not backpack.Parent then
            updateCharacterRefs()
            return
        end

        local equipped = {}
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA('Tool') then
                table.insert(equipped, tool)
            end
        end

        if #equipped > 2 then
            for i = 3, #equipped do
                pcall(function()
                    equipped[i].Parent = backpack
                end)
            end
        end

        local quantum = backpack:FindFirstChild('Quantum Cloner')
        if quantum and not table.find(equipped, quantum) then
            pcall(function()
                quantum.Parent = character
            end)
        end

        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA('Tool') and allowedSlaps[tool.Name] and tool.Name ~= 'Quantum Cloner' then
                if not table.find(equipped, tool) then
                    pcall(function()
                        tool.Parent = character
                    end)
                    break
                end
            end
        end

        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA('Tool') then
                if tool.Name == 'Quantum Cloner' then
                    for i = 1, 6 do
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                else
                    pcall(function()
                        tool:Activate()
                    end)
                end
            end
        end

        if useItemRemote and useItemRemote.Parent then
            for i = 1, 6 do
                pcall(function()
                    useItemRemote:FireServer()
                end)
            end
        end
    end)
end

local function startFpsDevour()
    if settings.fpsDevour then
        return
    end
    settings.fpsDevour = true
    savesett()
    updateCharacterRefs()
    StartAuraLoop()
end

local function stopFpsDevour()
    stopEverything()
    settings.fpsDevour = false
    savesett()
end

local ITEMS = {
    'Flame Slap',
    'Dark Matter Slap',
    'Galaxy Slap',
    'Glitched Slap',
    'Nuclear Slap',
}

local AutoRunning = false
getgenv().REMOVE_VFX = false

local function autoBuy()
    if AutoRunning then
        for _, itemName in ipairs(ITEMS) do
            pcall(function()
                RequestBuy:InvokeServer(itemName)
            end)
        end
    end
end

local function sweep()
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("ParticleEmitter") or inst:IsA("Trail") then
            pcall(function() inst.Enabled = false end)
            pcall(function() inst:Destroy() end)
        end
    end
end

function startFpsDevourSlap()
    if getgenv().StartFpsDevourWithSlaps then return end
    
    getgenv().StartFpsDevourWithSlaps = true
    AutoRunning = true
    settings.fpsDevour = true
    savesett()
    
    if not getgenv().REMOVE_VFX then
        getgenv().REMOVE_VFX = true
    end

    updateCharacterRefs()

    task.spawn(function()
        while getgenv().StartFpsDevourWithSlaps do
            for _, itemName in ipairs(ITEMS) do
                pcall(function()
                    RequestBuy:InvokeServer(itemName)
                end)
            end
            task.wait(0.1)
        end
    end)

    task.spawn(function()
        while getgenv().StartFpsDevourWithSlaps do
            if not character or not character.Parent or not backpack or not backpack.Parent then
                updateCharacterRefs()
                task.wait(0.5)
                continue
            end

            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA('Tool') and string.find(tool.Name:lower(), 'slap') then
                    pcall(function()
                        tool.Parent = character
                    end)
                end
            end

            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA('Tool') and string.find(tool.Name:lower(), 'slap') then
                    pcall(function()
                        tool:Activate()
                    end)
                end
            end
            
            task.wait(0.1)
        end
    end)

    if getgenv().REMOVE_VFX then
        task.spawn(function()
            while getgenv().REMOVE_VFX and getgenv().StartFpsDevourWithSlaps do
                sweep()
                task.wait(1.5)
            end
        end)
    end
end

function stopFpsDevourSlap()
    if not getgenv().StartFpsDevourWithSlaps then return end
    
    getgenv().StartFpsDevourWithSlaps = false
    AutoRunning = false
    getgenv().REMOVE_VFX = false
    settings.fpsDevour = false
    savesett()

    for _, conn in ipairs(slapConnections) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
    end
    slapConnections = {}

    if slapLoop then
        pcall(function() task.cancel(slapLoop) end)
        slapLoop = nil
    end
end

--------==================================== LASER CAPE ====================================--------

local function equipTool(toolName)
    if not character or not character.Parent then
        return nil
    end
    local tool = character:FindFirstChild(toolName)
        or (backpack and backpack:FindFirstChild(toolName))
    if tool and character:FindFirstChild('Humanoid') then
        tool.Parent = character
        character.Humanoid:EquipTool(tool)
        task.wait(0.05)
        return tool
    end
    return nil
end

local function getClosestPlayerHRP()
    if not character or not character:FindFirstChild('HumanoidRootPart') then
        return nil
    end
    local hrp = character.HumanoidRootPart
    local closest, distance = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if
            plr ~= player
            and plr.Character
            and plr.Character:FindFirstChild('HumanoidRootPart')
        then
            local targetHRP = plr.Character.HumanoidRootPart
            local mag = (hrp.Position - targetHRP.Position).Magnitude
            if mag < distance then
                closest, distance = targetHRP, mag
            end
        end
    end
    return closest
end

local function startAutoLaser()
    if AutoLaserLoop then
        return
    end
    AutoLaserLoop = true
    settings.autoLaser = true
    savesett()

    if not character or not character.Parent then
        updateCharacterRefs()
    end

    autoLaserConnection = RunService.RenderStepped:Connect(function()
        if not AutoLaserLoop then
            if autoLaserConnection then
                autoLaserConnection:Disconnect()
                autoLaserConnection = nil
            end
            return
        end

        if not character or not character.Parent then
            return
        end

        if not settings.autoLaser or not AutoLaserLoop then
            return
        end

        local tool = equipTool('Laser Cape')
        local closestHRP = getClosestPlayerHRP()
        if tool and closestHRP and useItemRemote and AutoLaserLoop then
            pcall(function()
                useItemRemote:FireServer(closestHRP.Position, closestHRP)
            end)
        end
    end)
end

local function stopAutoLaser()
    AutoLaserLoop = false
    settings.autoLaser = false
    savesett()
    if autoLaserConnection then
        autoLaserConnection:Disconnect()
        autoLaserConnection = nil
    end
end

local function setupCharacterReset()
    if characterConn then
        characterConn:Disconnect()
    end

    characterConn = player.CharacterAdded:Connect(function(newCharacter)
        task.wait(3) -- ✅ AUMENTADO: Mais tempo para carregar
        
        updateCharacterRefs()

        -- ✅ MELHORADO: Reconexão mais robusta
        if settings.fpsDevour then
            if FPSDEVOURMETHOD == "aura" then
                if conn then
                    conn:Disconnect()
                    conn = nil
                end
                DevourLoop = false
                task.wait(1)
                StartAuraLoop()
            elseif FPSDEVOURMETHOD == "slap" then
                if getgenv().StartFpsDevourWithSlaps then
                    getgenv().StartFpsDevourWithSlaps = false
                    task.wait(0.5)
                end
                task.wait(1)
                startFpsDevourSlap()
            end
        end

        if settings.autoLaser then
            if autoLaserConnection then
                autoLaserConnection:Disconnect()
                autoLaserConnection = nil
            end
            AutoLaserLoop = false
            task.wait(1)
            startAutoLaser()
        end

        if settings.xRay then
            task.wait(1)
            setBaseInvisible(true)
        end
    end)
end

--------==================================== ESP BEST ====================================--------

local espOnBrainrot=false

local currentBillboard=nil
local currentAnimalHighlight=nil
local currentTraitsBillboards={}

local function parseGenerationNumber(text)
    text=text:gsub('[%$%s]','')
    local numberPart,suffix=text:match('([%d%.]+)([KMB]?)')
    numberPart=tonumber(numberPart)or 0
    local multiplier=1
    if suffix=='K'then multiplier=1000 elseif suffix=='M'then multiplier=1000000 elseif suffix=='B'then multiplier=1000000000 end
    return numberPart*multiplier
end

local function applyAnimalHighlight(bestModel,displayName)
    if currentAnimalHighlight then currentAnimalHighlight:Destroy() currentAnimalHighlight=nil end
    if not bestModel or not displayName then return end
    for _,child in pairs(bestModel:GetChildren())do
        if child:IsA("Model")and child.Name==displayName then
            local hasValidParts=false
            for _,descendant in pairs(child:GetDescendants())do
                if descendant:IsA("BasePart")then hasValidParts=true break end
            end
            if not hasValidParts then return end
            local highlight=Instance.new('Highlight')
            highlight.Name="AnimalHighlight_"..displayName
            pcall(function() highlight.Adornee=child end)
            if not highlight.Adornee then
                if child.PrimaryPart then
                    highlight.Adornee=child.PrimaryPart
                else
                    for _,descendant in pairs(child:GetDescendants())do
                        if descendant:IsA("BasePart")then highlight.Adornee=descendant break end
                    end
                end
            end
            if highlight.Adornee then
                highlight.FillColor=Color3.fromRGB(0,191,255)
                highlight.OutlineColor=Color3.fromRGB(0,255,255)
                highlight.FillTransparency=0.3
                highlight.OutlineTransparency=0
                highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent=CoreGui
                currentAnimalHighlight=highlight
                return
            else
                highlight:Destroy()
            end
        end
    end
end

local function createBillboard(basePart,generationText,displayName,rarityText,bestModel)
    if not basePart then return end
    for _,billboard in ipairs(currentTraitsBillboards)do if billboard and billboard.Parent then billboard:Destroy() end end
    currentTraitsBillboards={}
    local billboard=Instance.new('BillboardGui')
    billboard.Size=UDim2.new(0,200,0,160)
    billboard.Adornee=basePart
    billboard.AlwaysOnTop=true
    billboard.StudsOffset=Vector3.new(0,3,0)
    billboard.Parent=CoreGui
    local frame=Instance.new('Frame')
    frame.Size=UDim2.fromScale(1,1)
    frame.BackgroundTransparency=1
    frame.Parent=billboard
    local listLayout=Instance.new('UIListLayout')
    listLayout.SortOrder=Enum.SortOrder.LayoutOrder
    listLayout.FillDirection=Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    listLayout.VerticalAlignment=Enum.VerticalAlignment.Center
    listLayout.Padding=UDim.new(0,4)
    listLayout.Parent=frame
    local displayLabel=Instance.new('TextLabel')
    displayLabel.Size=UDim2.new(1,0,0,35)
    displayLabel.BackgroundTransparency=1
    displayLabel.TextColor3=Color3.new(1,1,1)
    displayLabel.TextScaled=true
    displayLabel.Text=displayName or'N/A'
    displayLabel.Font=Enum.Font.GothamBold
    displayLabel.TextStrokeTransparency=0
    displayLabel.TextStrokeColor3=Color3.new(0,0,0)
    displayLabel.LayoutOrder=1
    displayLabel.Parent=frame
    local generationLabel=Instance.new('TextLabel')
    generationLabel.Size=UDim2.new(1,0,0,25)
    generationLabel.BackgroundTransparency=1
    generationLabel.TextColor3=Color3.fromRGB(255,255,0)
    generationLabel.TextScaled=true
    generationLabel.Text=generationText or'0'
    generationLabel.Font=Enum.Font.GothamBold
    generationLabel.TextStrokeTransparency=0
    generationLabel.TextStrokeColor3=Color3.fromRGB(0,255,128)
    generationLabel.LayoutOrder=2
    generationLabel.Parent=frame
    local rarityLabel=Instance.new('TextLabel')
    rarityLabel.Size=UDim2.new(1,0,0,25)
    rarityLabel.BackgroundTransparency=1
    rarityLabel.TextColor3=Color3.new(1,1,1)
    rarityLabel.TextScaled=true
    rarityLabel.Text=rarityText or'N/A'
    rarityLabel.Font=Enum.Font.GothamBold
    rarityLabel.TextStrokeTransparency=0
    rarityLabel.TextStrokeColor3=Color3.new(0,0,0)
    rarityLabel.LayoutOrder=3
    rarityLabel.Parent=frame
    task.spawn(function()
        local colors={Color3.fromRGB(255,0,0),Color3.fromRGB(255,128,0),Color3.fromRGB(255,255,0),Color3.fromRGB(0,255,0),Color3.fromRGB(0,255,255),Color3.fromRGB(0,0,255),Color3.fromRGB(128,0,255),Color3.fromRGB(255,0,128)}
        local colorIndex=1
        while billboard and billboard.Parent do
            if generationLabel and generationLabel.Parent then generationLabel.TextStrokeColor3=colors[colorIndex] end
            colorIndex=colorIndex%#colors+1
            task.wait(0.2)
        end
    end)
    return billboard
end

local function updateGenerationESP()
    local bestValue=-math.huge
    local bestLabel=nil
    local bestModel=nil
    for _,obj in ipairs(workspace:GetDescendants())do
        if obj:IsA('TextLabel')and obj.Name=='Generation' then
            if string.find(obj.Text:lower(),"fusing")then continue end
            local value=parseGenerationNumber(obj.Text)
            if value>bestValue then
                bestValue=value
                bestLabel=obj
                local parent=obj.Parent
                while parent and parent~=workspace do
                    if parent:IsA('Model')and parent.Parent and parent.Parent.Name=='Plots' then bestModel=parent break end
                    parent=parent.Parent
                end
            end
        end
    end
    if not bestLabel then return end
    local displayNameObj=bestLabel.Parent:FindFirstChild('DisplayName')
    if displayNameObj and string.find(displayNameObj.Text:lower(),"fusing")then return end
    local parent=bestLabel.Parent
    local baseModel=nil
    while parent and parent~=workspace do
        if parent:IsA('Model')and parent:FindFirstChild('Base')then baseModel=parent break end
        parent=parent.Parent
    end
    if not baseModel then return end
    local basePart=baseModel:FindFirstChild('Base')or baseModel.PrimaryPart
    if not basePart then return end
    if currentBillboard then currentBillboard:Destroy() end
    local displayName=displayNameObj and displayNameObj.Text or'N/A'
    local rarityObj=bestLabel.Parent:FindFirstChild('Rarity')
    local rarityText=rarityObj and rarityObj.Text or'N/A'
    currentBillboard=createBillboard(basePart,bestLabel.Text,displayName,rarityText,bestModel)
    applyAnimalHighlight(bestModel,displayName)
end

task.spawn(function()
	while true do
		if espOnBrainrot then updateGenerationESP() else
			if currentBillboard then currentBillboard:Destroy() currentBillboard=nil end
			if currentAnimalHighlight then currentAnimalHighlight:Destroy() currentAnimalHighlight=nil end
		end
		task.wait(2)
	end
end)

function toggleESPBRAINROT(state)
    espOnBrainrot = state
    if not espOnBrainrot then
        if currentBillboard then currentBillboard:Destroy() currentBillboard = nil end
        if currentAnimalHighlight then currentAnimalHighlight:Destroy() currentAnimalHighlight = nil end
    end
end

--------==================================== ESP PLAYER ====================================--------

local espOnPlayer = false
local playerBillboards = {}
local playerHighlights = {}

local function createPlayerBillboard(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end

    if playerBillboards[player] then
        playerBillboards[player]:Destroy()
        playerBillboards[player] = nil
    end

    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0,150,0,40)
    billboard.Adornee = rootPart
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0,3,0)
    billboard.Parent = player:FindFirstChildOfClass("PlayerGui") or Players.LocalPlayer:WaitForChild("PlayerGui")

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = player.Name
    label.TextColor3 = Color3.fromRGB(0,255,255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0,0,0)

    playerBillboards[player] = billboard
end

local function createPlayerHighlight(player)
    if not player.Character then return end

    if playerHighlights[player] then
        playerHighlights[player]:Destroy()
        playerHighlights[player] = nil
    end

    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(0,191,255)
    highlight.OutlineColor = Color3.fromRGB(0,255,255)
    highlight.FillTransparency = 0.3
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = player.Character
    highlight.Parent = workspace

    playerHighlights[player] = highlight
end

RunService.Heartbeat:Connect(function()
    if not espOnPlayer then return end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                if not playerBillboards[player] then createPlayerBillboard(player) end
                if not playerHighlights[player] then createPlayerHighlight(player) end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if playerBillboards[player] then playerBillboards[player]:Destroy() end
    if playerHighlights[player] then playerHighlights[player]:Destroy() end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if espOnPlayer then
            createPlayerBillboard(player)
            createPlayerHighlight(player)
        end
    end)
end)

function toggleESP(state)
    espOnPlayer = state
    if not espOnPlayer then
        for _, billboard in pairs(playerBillboards) do billboard:Destroy() end
        for _, highlight in pairs(playerHighlights) do highlight:Destroy() end
        playerBillboards = {}
        playerHighlights = {}
    end
end

--------==================================== AutoJoiner COM WEBSOCKET REAL ====================================--------
getgenv().AJ = false

-- Função para processar job recebido via WebSocket
local function processWebSocketJob(jobData)
    if not jobData then 
        print("❌ Job data inválido")
        return 
    end
    
    print("📨 Processando job WebSocket:")
    print("   - Nome: " .. (jobData.name or "N/A"))
    print("   - Job ID: " .. (jobData.job_id or "N/A"))
    print("   - Tier: " .. (jobData.tier or "N/A"))
    
    -- Armazenar para processar no loop principal
    getgenv().lastWebSocketJob = jobData
    
    print("✅ Job armazenado para processamento")
end

-- Funções WebSocket usando Wave
local function connectWebSocket()
    print("🔍 Tentando conectar WebSocket...")
    print("🔍 URL: " .. wsUrl)
    print("🔍 WebSocket disponível: " .. tostring(WebSocket ~= nil))
    
    if not WebSocket then
        warn("❌ Biblioteca WebSocket do Wave não disponível")
        print("💡 Dica: Certifique-se de que está usando o Wave e que a biblioteca WebSocket está carregada")
        return false
    end
    
    local success, connection = pcall(function()
        print("🔍 Chamando WebSocket.connect...")
        return WebSocket.connect(wsUrl)
    end)
    
    print("🔍 Sucesso: " .. tostring(success))
    print("🔍 Conexão: " .. tostring(connection))
    
    if success and connection then
        wsConnection = connection
        isWebSocketConnected = true
        wsReconnectAttempts = 0
        
        print("✅ WebSocket conectado via Wave!")
        
        -- Configurar eventos
        connection.OnMessage:Connect(function(message)
            print("📨 Mensagem WebSocket recebida: " .. message)
            
            local ok, data = pcall(function()
                return HttpService:JSONDecode(message)
            end)
            
            if ok and data and data.type == "new_job" then
                print("🆕 Novo job via WebSocket: " .. (data.data.name or "Unknown"))
                
                -- Enviar notificação usando pcall para evitar erro
                pcall(function()
                    StarterGui:SetCore("SendNotification", {
                        Title = "AutoJoiner WebSocket",
                        Text = "🆕 Novo job: " .. (data.data.name or "Unknown"),
                        Duration = 5
                    })
                end)
                
                -- Processar job recebido
                processWebSocketJob(data.data)
            end
        end)
        
        connection.OnClose:Connect(function()
            print("🔌 WebSocket desconectado")
            isWebSocketConnected = false
            wsConnection = nil
        end)
        
        return true
    else
        warn("❌ Falha ao conectar WebSocket")
        print("❌ Erro detalhado: " .. tostring(connection))
        print("💡 Possíveis causas:")
        print("   - Servidor WebSocket não está rodando")
        print("   - URL incorreta")
        print("   - Problema de rede")
        print("   - Biblioteca WebSocket não carregada corretamente")
        return false
    end
end

local function disconnectWebSocket()
    if wsConnection then
        pcall(function()
            wsConnection:Close()
        end)
        wsConnection = nil
    end
    isWebSocketConnected = false
    print("🔌 WebSocket desconectado")
end

-- Função para testar conectividade do servidor
local function testServerConnectivity()
    print("🔍 Testando conectividade do servidor...")
    print("🔍 URL HTTP: " .. url)
    print("🔍 URL WebSocket: " .. wsUrl)
    
    local requestFunc = http_request or request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
    
    if not requestFunc then
        warn("❌ Nenhum método de requisição disponível")
        return false
    end
    
    local success, res = pcall(function()
        return requestFunc({
            Url = url,
            Method = "GET",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/AutoJoiner-Test"
            }
        })
    end)
    
    if success and res then
        print("✅ Servidor HTTP acessível")
        return true
    else
        warn("❌ Servidor HTTP não acessível: " .. tostring(res))
        return false
    end
end

-- Função para obter jobs via HTTP (fallback)
local function getJobsHTTP()
    local requestFunc = http_request or request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
    
    if not requestFunc then
        warn("❌ Nenhum método de requisição disponível")
        return nil
    end
    
    local success, res = pcall(function()
        return requestFunc({
            Url = url,
            Method = "GET",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/AutoJoiner-HTTP"
            }
        })
    end)
    
    if not success or not res then
        return nil
    end
    
    local body = res.Body or res.body or res[1]
    if not body or body == "" then
        return nil
    end
    
    if type(body) ~= "string" then
        body = tostring(body)
    end
    body = body:gsub("[\n\r]", ""):gsub("%s+$", "")
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    
    if ok and data then
        return data
    end
    
    return nil
end

-- Função corrigida para obter horário de Brasília
local function getBrasiliaTime()
    local requestFunc = http_request or request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
    
    if not requestFunc then
        warn("❌ Nenhum método de requisição disponível para hora, usando horário do PC")
        -- Aplicar offset manual de -3 horas para Brasília
        return os.time() - (3 * 3600)
    end
    
    local success, res = pcall(function()
        return requestFunc({
            Url = timeAPI,
            Method = "GET",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/AutoJoiner"
            }
        })
    end)
    
    if not success or not res then
        warn("❌ Falha na requisição da hora: " .. tostring(res))
        -- Fallback com offset manual
        return os.time() - (3 * 3600)
    end
    
    local body = res.Body or res.body or res[1]
    if not body or body == "" then
        warn("❌ Resposta da API vazia")
        return os.time() - (3 * 3600)
    end
    
    -- Limpar o body
    if type(body) ~= "string" then
        body = tostring(body)
    end
    body = body:gsub("[\n\r]", ""):gsub("%s+$", "")
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    
    if not ok or not data then
        warn("❌ Erro ao decodificar JSON da API de tempo: " .. tostring(data))
        return os.time() - (3 * 3600)
    end
    
    -- Tentar diferentes formatos de timestamp
    local timestamp = data.unixtime or data.timestamp or data.unix
    if timestamp then
        print("✅ Timestamp da API (Brasília): " .. timestamp)
        return timestamp
    end
    
    -- Se não tiver timestamp, tentar parsear datetime
    if data.datetime then
        -- Formato: 2025-09-14T14:45:01-03:00 (com timezone)
        local year, month, day, hour, min, sec, tz_sign, tz_hour = data.datetime:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)([%+%-])(%d+)")
        if year then
            local utcTime = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            })
            
            -- Aplicar offset do timezone se disponível
            if tz_sign and tz_hour then
                local offset = tonumber(tz_hour) * 3600
                if tz_sign == "-" then
                    utcTime = utcTime + offset -- Se é -03:00, somar para converter para UTC
                else
                    utcTime = utcTime - offset
                end
            end
            
            print("✅ Timestamp parseado (Brasília): " .. utcTime)
            return utcTime
        end
    end
    
    warn("❌ Formato de tempo não reconhecido, usando horário do PC com offset")
    return os.time() - (3 * 3600)
end

-- Função CORRIGIDA para converter timer da API
local function parseTimer(timerStr)
    if not timerStr or type(timerStr) ~= "string" then
        warn("❌ Timer inválido: " .. tostring(timerStr))
        return 0
    end
    
    -- Formato da API: DD/MM/YYYY HH:MM:SS (exemplo: "14/09/2025 14:45:01")
    local day, month, year, hour, min, sec = timerStr:match("(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)")
    
    if not day then
        warn("❌ Formato de timer não reconhecido: " .. timerStr)
        return 0
    end
    
    -- CORREÇÃO: Usar a data EXATA da API, não apenas o horário
    local jobTimestamp = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    })
    
    print("✅ Timer '" .. timerStr .. "' convertido para: " .. jobTimestamp)
    return jobTimestamp
end

-- Função para enviar notificação
local function sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5
        })
    end)
end

-- Função do AutoJoin OTIMIZADA - 100% WebSocket
local function AutoJoin()
    if not url or url == "" then
        warn("❌ URL da API não configurada!")
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "AutoJoiner - Erro",
                Text = "URL da API não configurada!",
                Duration = 10
            })
        end)
        return
    end
    
    if not placeID or placeID == 0 then
        warn("❌ Place ID não configurado!")
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "AutoJoiner - Erro",
                Text = "Place ID não configurado!",
                Duration = 10
            })
        end)
        return
    end
    
    -- Verificar se Wave está disponível
    print("🔍 Verificando Wave...")
    print("🔍 Wave disponível: " .. tostring(Wave ~= nil))
    print("🔍 WebSocket disponível: " .. tostring(WebSocket ~= nil))
    
    -- Tentar conectar WebSocket
    if useWebSocket then
        print("🔍 Tentando conectar WebSocket...")
        if connectWebSocket() then
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "AutoJoiner WebSocket",
                    Text = "🟢 AutoJoiner WebSocket iniciado!",
                    Duration = 5
                })
            end)
            print("🚀 WebSocket conectado via Wave - Modo tempo real!")
        else
            warn("⚠️ WebSocket falhou, usando modo HTTP")
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "AutoJoiner HTTP",
                    Text = "🟢 AutoJoiner HTTP iniciado!",
                    Duration = 5
                })
            end)
            useWebSocket = false
        end
    else
        print("🔍 WebSocket desabilitado, usando HTTP")
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "AutoJoiner HTTP",
                Text = "🟢 AutoJoiner HTTP iniciado!",
                Duration = 5
            })
        end)
    end
    
    local lastKnownJobId = nil -- Controle do último job conhecido
    local teleportAttempts = 0 -- Contador de tentativas de teleporte
    local maxTeleportAttempts = 45 -- Máximo de tentativas (45 segundos)
    
    -- Se WebSocket está conectado, usar modo OTIMIZADO
    if isWebSocketConnected then
        print("🎯 Modo WebSocket OTIMIZADO - Escutando apenas alterações!")
        
        while getgenv().AJ do
            -- Verificar se há job recebido via WebSocket
            local wsJob = getgenv().lastWebSocketJob
            
            -- Se há um job novo, processar
            if wsJob then
                print("🔍 Job WebSocket encontrado, processando...")
                
                -- Processar job do WebSocket
                getgenv().lastWebSocketJob = nil -- Limpar job processado
                
                local currentJobId = wsJob.job_id
                local playerName = wsJob.name or "Desconhecido"
                
                print("📨 Processando job WebSocket:")
                print("   - Player: " .. playerName)
                print("   - Job ID: " .. currentJobId)
                print("   - Último job conhecido: " .. tostring(lastKnownJobId))
                
                -- Se é um job novo (diferente do último conhecido)
                if currentJobId ~= lastKnownJobId then
                    lastKnownJobId = currentJobId
                    teleportAttempts = 0 -- Resetar contador de tentativas
                    
                    print("🆕 Novo job encontrado! Player: " .. playerName .. " | Job ID: " .. currentJobId)
                    pcall(function()
                        StarterGui:SetCore("SendNotification", {
                            Title = "AutoJoiner WebSocket",
                            Text = "🆕 Novo job: " .. playerName,
                            Duration = 5
                        })
                    end)
                end
            end
            
            -- Se temos um job conhecido, continuar tentando teleporte
            if lastKnownJobId then
                -- Tentar teleporte
                teleportAttempts = teleportAttempts + 1
                
                print("🚀 Tentativa " .. teleportAttempts .. "/" .. maxTeleportAttempts .. " - TP para: " .. (wsJob and wsJob.name or "Job conhecido"))
                pcall(function()
                    StarterGui:SetCore("SendNotification", {
                        Title = "AutoJoiner WebSocket",
                        Text = "🚀 TP " .. teleportAttempts .. "/" .. maxTeleportAttempts,
                        Duration = 3
                    })
                end)
                
                -- Tentar teleporte
                print("🚀 Executando teleporte...")
                print("   - Place ID: " .. placeID)
                print("   - Job ID: " .. lastKnownJobId)
                print("   - Player: " .. lp.Name)
                
                local teleportSuccess = pcall(function()
                    TPS:TeleportToPlaceInstance(placeID, lastKnownJobId, lp)
                end)
                
                print("📊 Resultado do teleporte: " .. tostring(teleportSuccess))
                
                if not teleportSuccess then
                    warn("❌ Falha no teleporte para: " .. lastKnownJobId .. " (tentativa " .. teleportAttempts .. ")")
                    pcall(function()
                        StarterGui:SetCore("SendNotification", {
                            Title = "AutoJoiner WebSocket",
                            Text = "❌ Falha TP " .. teleportAttempts .. "/" .. maxTeleportAttempts,
                            Duration = 3
                        })
                    end)
                else
                    print("✅ Teleporte iniciado para: " .. lastKnownJobId .. " (tentativa " .. teleportAttempts .. ")")
                end
                
                -- Se excedeu o máximo de tentativas (45 segundos), procurar novo job
                if teleportAttempts >= maxTeleportAttempts then
                    print("⚠️ 45 segundos de tentativas atingidos, aguardando novo job...")
                    pcall(function()
                        StarterGui:SetCore("SendNotification", {
                            Title = "AutoJoiner WebSocket",
                            Text = "⚠️ 45s esgotados - Aguardando...",
                            Duration = 5
                        })
                    end)
                    lastKnownJobId = nil -- Resetar para procurar novo job
                    teleportAttempts = 0
                end
                
                -- Cooldown de 1 segundo entre tentativas
                task.wait(1)
            else
                -- Se não há job conhecido, apenas aguardar
                print("⏰ Aguardando novo job via WebSocket...")
                task.wait(0.1)
            end
        end
    else
        -- Modo HTTP (fallback)
        print("🔄 Modo HTTP - Polling a cada 1 segundo")
        
        local consecutiveErrors = 0
        local maxErrors = 5
        local lastJobData = nil
        
        while getgenv().AJ do
            local data = getJobsHTTP()
            
            if data then
                consecutiveErrors = 0
                lastJobData = data
                
                -- CORREÇÃO: Obter horário atual
                local brasiliaNow = getBrasiliaTime()
                
                -- Procurar apenas o último job válido de cada tier
                local bestJob = nil
                local bestJobTime = 0
                local bestJobDiff = math.huge
                
                for _, tier in ipairs(methods) do
                    local jobs = data[tier]
                    
                    if jobs and type(jobs) == "table" and #jobs > 0 then
                        -- Pegar apenas o último job da tier
                        local job = jobs[#jobs]
                        
                        if job and job.timer and job.job_id and job.job_id ~= game.JobId then
                            local jobTime = parseTimer(job.timer)
                            local diff = brasiliaNow - jobTime
                            
                            print("🔍 Último job da tier " .. tier .. ": " .. (job.name or "N/A") .. " | Tempo: " .. job.timer .. " | Diff: " .. diff .. "s")
                            
                            -- Aceitar jobs com até 60 segundos
                            if diff >= 0 and diff <= 60 and diff < bestJobDiff then
                                bestJob = job
                                bestJobTime = jobTime
                                bestJobDiff = diff
                            end
                        end
                    end
                end
                
                -- Verificar se encontrou um novo job ou se deve continuar tentando o último
                if bestJob then
                    local currentJobId = bestJob.job_id
                    
                    -- Se é um job novo (diferente do último conhecido)
                    if currentJobId ~= lastKnownJobId then
                        lastKnownJobId = currentJobId
                        teleportAttempts = 0 -- Resetar contador de tentativas
                        
                        local playerName = bestJob.name or bestJob.player or "Desconhecido"
                        print("🆕 Novo job encontrado! Player: " .. playerName .. " | Job ID: " .. currentJobId)
                        pcall(function()
                            StarterGui:SetCore("SendNotification", {
                                Title = "AutoJoiner HTTP",
                                Text = "🆕 Novo job: " .. playerName,
                                Duration = 5
                            })
                        end)
                    end
                    
                    -- Tentar teleporte (seja job novo ou continuação do último)
                    teleportAttempts = teleportAttempts + 1
                    
                    local playerName = bestJob.name or bestJob.player or "Desconhecido"
                    print("🚀 Tentativa " .. teleportAttempts .. "/" .. maxTeleportAttempts .. " - TP para: " .. playerName .. " (" .. math.floor(bestJobDiff) .. "s)")
                    pcall(function()
                        StarterGui:SetCore("SendNotification", {
                            Title = "AutoJoiner HTTP",
                            Text = "🚀 TP " .. teleportAttempts .. "/" .. maxTeleportAttempts .. " - " .. playerName,
                            Duration = 3
                        })
                    end)
                    
                    -- Tentar teleporte
                    local teleportSuccess = pcall(function()
                        TPS:TeleportToPlaceInstance(placeID, currentJobId, lp)
                    end)
                    
                    if not teleportSuccess then
                        warn("❌ Falha no teleporte para: " .. currentJobId .. " (tentativa " .. teleportAttempts .. ")")
                        pcall(function()
                            StarterGui:SetCore("SendNotification", {
                                Title = "AutoJoiner HTTP",
                                Text = "❌ Falha TP " .. teleportAttempts .. "/" .. maxTeleportAttempts,
                                Duration = 3
                            })
                        end)
                        
                        -- Se excedeu o máximo de tentativas (45 segundos), procurar novo job
                        if teleportAttempts >= maxTeleportAttempts then
                            print("⚠️ 45 segundos de tentativas atingidos, procurando novo job...")
                            pcall(function()
                                StarterGui:SetCore("SendNotification", {
                                    Title = "AutoJoiner HTTP",
                                    Text = "⚠️ 45s esgotados - Novo job...",
                                    Duration = 5
                                })
                            end)
                            lastKnownJobId = nil -- Resetar para procurar novo job
                            teleportAttempts = 0
                        end
                    else
                        print("✅ Teleporte iniciado para: " .. currentJobId .. " (tentativa " .. teleportAttempts .. ")")
                        -- Mesmo com sucesso, continuar tentando até atingir 45 tentativas
                        if teleportAttempts >= maxTeleportAttempts then
                            print("⚠️ 45 segundos de tentativas atingidos, procurando novo job...")
                            pcall(function()
                                StarterGui:SetCore("SendNotification", {
                                    Title = "AutoJoiner HTTP",
                                    Text = "⚠️ 45s esgotados - Novo job...",
                                    Duration = 5
                                })
                            end)
                            lastKnownJobId = nil -- Resetar para procurar novo job
                            teleportAttempts = 0
                        end
                    end
                    
                    -- Cooldown de 1 segundo entre tentativas
                    task.wait(1)
                else
                    print("⏰ Nenhum job válido encontrado (todos muito antigos ou inválidos)")
                    -- Se não encontrou nenhum job, resetar controle
                    if lastKnownJobId then
                        print("🔄 Resetando controle de job...")
                        lastKnownJobId = nil
                        teleportAttempts = 0
                    end
                    
                    -- Aguardar 1 segundo antes de tentar novamente
                    task.wait(1)
                end
            else
                consecutiveErrors = consecutiveErrors + 1
                warn("❌ Falha na requisição HTTP (" .. consecutiveErrors .. "/" .. maxErrors .. ")")
                
                if consecutiveErrors >= maxErrors then
                    warn("❌ Muitos erros consecutivos, parando AutoJoiner")
                    pcall(function()
                        StarterGui:SetCore("SendNotification", {
                            Title = "AutoJoiner HTTP - Erro",
                            Text = "Muitos erros, parando execução",
                            Duration = 10
                        })
                    end)
                    getgenv().AJ = false
                    break
                end
                
                -- Usar dados em cache se disponível
                if lastJobData then
                    print("⚠️ Usando dados em cache devido a erro de conexão")
                end
                
                -- Aguardar 1 segundo antes de tentar novamente
                task.wait(1)
            end
        end
    end
    
    -- Desconectar WebSocket ao parar
    if isWebSocketConnected then
        disconnectWebSocket()
    end
    
    local mode = isWebSocketConnected and "WebSocket" or "HTTP"
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "AutoJoiner " .. mode,
            Text = "🔴 AutoJoiner parado!",
            Duration = 5
        })
    end)
end

--------==================================== UI ====================================--------

local gui=Instance.new("ScreenGui")
gui.Parent=playerGui
gui.ResetOnSpawn=false

local main=Instance.new("Frame",gui)
main.Size=UDim2.new (0, 220, 0, 330)
main.Position=UDim2.new(1,-230,0,10)
main.BackgroundColor3=Color3.fromRGB(15,15,15)
main.BorderSizePixel=0
main.Active=true
main.ZIndex = 1
Instance.new("UICorner",main).CornerRadius=UDim.new(0,10)

local drag=false
local dragInput,dragStart,startPos
main.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true dragStart=i.Position startPos=main.Position i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end) end end)
main.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then dragInput=i end end)
UIS.InputChanged:Connect(function(i) if drag and i==dragInput then local d=i.Position-dragStart main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)

local title=Instance.new("TextLabel",main)
title.Size=UDim2.new(1,0,0,30)
title.Text="Labs Hub - Panel"
title.Font=Enum.Font.GothamBold
title.TextSize=18
title.TextColor3=Color3.new(1,1,1)
title.BackgroundTransparency=1
title.TextXAlignment=Enum.TextXAlignment.Center
title.ZIndex = 2

local close=Instance.new("TextButton",main)
close.Size=UDim2.new(0,25,0,25)
close.Position=UDim2.new(1,-28,0,3)
close.Text="–"
close.TextSize=20
close.Font=Enum.Font.GothamBold
close.BackgroundColor3=Color3.fromRGB(30,30,30)
close.TextColor3=Color3.new(1,1,1)
Instance.new("UICorner",close).CornerRadius=UDim.new(0,6)
close.ZIndex = 2

local container=Instance.new("Frame",main)
container.Size=UDim2.new(1,-20,1,-60)
container.Position=UDim2.new(0,10,0,35)
container.BackgroundTransparency=1
local layout=Instance.new("UIListLayout",container)
layout.Padding=UDim.new(0,6)
layout.SortOrder=Enum.SortOrder.LayoutOrder

local footer = Instance.new('TextLabel', main)
footer.Size = UDim2.new(1, 0, 0, 24)
footer.Position = UDim2.new(0, 0, 1, -24)
footer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
footer.Text = ''
footer.Font = Enum.Font.GothamBold
footer.TextSize = 14
footer.TextColor3 = Color3.new(1, 1, 1)
footer.BorderSizePixel = 0
footer.ZIndex = 2
Instance.new('UICorner', footer).CornerRadius = UDim.new(0, 6)

local bar = Instance.new('TextButton', gui)
bar.Size = UDim2.new(0, 220, 0, 40)
bar.Position = UDim2.new(1, -230, 0, 10)
bar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
bar.Text = 'Labs Hub | Panel (Premium Acess)'
bar.TextColor3 = Color3.new(1, 1, 1)
bar.Font = Enum.Font.GothamBold
bar.TextScaled = true
bar.TextWrapped = true
bar.ZIndex = 2
Instance.new('UICorner', bar).CornerRadius = UDim.new(0, 8)
bar.Visible = false

local function createBtn(txt, callback)
    local btn = Instance.new('TextButton', container)
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    btn.Text = txt
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BorderSizePixel = 0
    btn.ZIndex = 2
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 8)

    local led = Instance.new('Frame', btn)
    led.Size = UDim2.new(0, 14, 0, 14)
    led.Position = UDim2.new(1, -22, 0.5, -7)
    led.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
    led.BorderSizePixel = 0
    led.ZIndex = 2
    Instance.new('UICorner', led).CornerRadius = UDim.new(1, 0)

    local state = false
    local function update()
        led.BackgroundColor3 = state and Color3.fromRGB(50, 255, 60)
            or Color3.fromRGB(255, 40, 40)
    end

    btn.MouseButton1Click:Connect(function()
        state = not state
        callback(state)
        update()
    end)

    update()
    return btn, led
end

local btnFpsDevour, ledFpsDevour
if FPSDEVOURMETHOD == "aura" then
    btnFpsDevour, ledFpsDevour = createBtn('FPS DEVOUR', function(state)
        if state then
            startFpsDevour()
        else
            stopFpsDevour()
        end
    end)
elseif FPSDEVOURMETHOD == "slap" then
    btnFpsDevour, ledFpsDevour = createBtn('FPS DEVOUR', function(state)
        if state then
            startFpsDevourSlap()
        else
            stopFpsDevourSlap()
        end
    end)
end

local btnRX, ledX_Ray = createBtn('X-RAY', function(state)
    if state then
        setBaseInvisible(true)
    else
        setBaseInvisible(false)
    end
end)

local btnlaser, ledLaser = createBtn('Auto Laser Cape', function(state)
    if state then startAutoLaser()
    else stopAutoLaser()
    end
end)

local btnbestesp, ledBEST = createBtn('ESP Best', function(state)
    if state then toggleESPBRAINROT(true)
    else toggleESPBRAINROT(false)
    end
end)

local btnplayeresp, ledPlayerESP = createBtn('ESP Player', function(state)
    if state then toggleESP(true)
    else toggleESP(false)
    end
end)

local spacer = Instance.new("Frame", container)
spacer.Size = UDim2.new(1, 0, 0, 10)
spacer.BackgroundTransparency = 1

local btnaj, ledAJ = createBtn('Auto Join', function(state)
    getgenv().AJ = state
    if state then
        print("🟢 AutoJoiner ativado via botão")
        local mode = useWebSocket and "WebSocket" or "HTTP"
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "AutoJoiner " .. mode,
                Text = "🟢 Ativado!",
                Duration = 3
            })
        end)
        task.spawn(AutoJoin)
    else
        print("🔴 AutoJoiner desativado via botão") 
        local mode = isWebSocketConnected and "WebSocket" or "HTTP"
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "AutoJoiner " .. mode,
                Text = "🔴 Desativado!",
                Duration = 3
            })
        end)
    end
end)

local bar=Instance.new("TextButton",gui)
bar.Size=UDim2.new(0,200,0,30)
bar.Position=UDim2.new(1,-150,0,10)
bar.BackgroundColor3=Color3.fromRGB(35,35,35)
bar.Text="⭐ Labs Hub - Premium Acess"
bar.Font=Enum.Font.GothamBold
bar.TextSize=14
bar.TextColor3=Color3.new(1,1,1)
bar.Visible=false
Instance.new("UICorner",bar).CornerRadius=UDim.new(0,8)

close.MouseButton1Click:Connect(function()
	main.Visible=false
	bar.Visible=true
end)

bar.MouseButton1Click:Connect(function()
	main.Visible=true
	bar.Visible=false
end)

local drag2=false
local dragInput2,dragStart2,startPos2
bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag2=true dragStart2=i.Position startPos2=bar.Position i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag2=false end end) end end)
bar.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then dragInput2=i end end)
UIS.InputChanged:Connect(function(i) if drag2 and i==dragInput2 then local d=i.Position-dragStart2 bar.Position=UDim2.new(startPos2.X.Scale,startPos2.X.Offset+d.X,startPos2.Y.Scale,startPos2.Y.Offset+d.Y) end end)

local function updateLEDs()
    ledFpsDevour.BackgroundColor3 = settings.fpsDevour
            and Color3.fromRGB(50, 255, 60)
        or Color3.fromRGB(255, 40, 40)
    ledX_Ray.BackgroundColor3 = settings.autoLaser
            and Color3.fromRGB(50, 255, 60)
        or Color3.fromRGB(255, 40, 40)
    ledLaser.BackgroundColor3 = settings.xRay and Color3.fromRGB(50, 255, 60)
        or Color3.fromRGB(255, 40, 40)
end

task.spawn(function()
    local colors = {
        Color3.fromRGB(255, 0, 0),
        Color3.fromRGB(0, 255, 0),
        Color3.fromRGB(0, 150, 255),
        Color3.fromRGB(255, 255, 0),
    }
    local i = 1
    while true do
        footer.Text = "Labs Hub - Building your Future."
        footer.TextColor3 = colors[i]
        i = i % #colors + 1
        task.wait(1)
    end
end)

pcall(function() StarterGui:SetCore("SendNotification",{Title="Labs Hub - Building your future.",Text="discord.gg/bloxlabs - WebSocket Ready!",Duration=5}) end)

task.spawn(loadsett)
updateCharacterRefs()
setupCharacterReset()
updateLEDs()

--------==================================== EXTRAS ====================================--------

if settings.fpsDevour then
    task.spawn(startFpsDevour)
end

if settings.autoLaser then
    task.spawn(startAutoLaser)
end

local function removeAllAccessories(char)
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA('Accessory') then
            item:Destroy()
        end
    end
end

local function removeClones()
    for _, obj in ipairs(workspace:GetChildren()) do
        if typeof(obj.Name) == 'string' and obj.Name:find('_Clone') then
            obj:Destroy()
        end
    end
end

local function trackPlayer(plr)
    if plr.Character then
        removeAllAccessories(plr.Character)
    end
    plr.CharacterAdded:Connect(removeAllAccessories)
end

for _, plr in ipairs(Players:GetPlayers()) do
    trackPlayer(plr)
end
Players.PlayerAdded:Connect(trackPlayer)

task.spawn(function()
    while true do
        if DevourLoop then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character then
                    removeAllAccessories(plr.Character)
                end
            end
            removeClones()
        end
        task.wait(0.1)
    end
end)

local CoinsShopRemote = ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Net'):WaitForChild('RF/CoinsShopService/RequestBuy')

local slaps = { 'Dark Matter Slap', 'Flame Slap', 'Nuclear Slap', 'Galaxy Slap', 'Glitched Slap', "Splatter Slap" }

task.spawn(function()
    for i = 1, 2 do
        for _, slapName in ipairs(slaps) do
            local args = { slapName }
            pcall(function()
                CoinsShopRemote:InvokeServer(unpack(args))
            end)
            wait(0.4)
        end
    end
end)

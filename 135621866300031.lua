local Library = loadstring(readfile("UiLibrary.lua"))()
Library.Theme = "Obsidian"

local Services = setmetatable({}, {
    __index = function(_, service)
        return cloneref(game:GetService(service))
    end
})

local Players = Services.Players
local Workspace = Services.Workspace
local VirtualUser = Services.VirtualUser
local ReplicatedStorage = Services.ReplicatedStorage

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local PROMPT_KEY = "0x65" 

local Config = {
    SafeSpot = CFrame.new(-342, 4, 132),

    LootOffset = CFrame.new(0, -5, 0),
    CollectTimeout = .25,

    CodesUrl = "https://urgametips.com/bizarre-codes/",
    CodeDelay = 1.5,
}

local State = {
    WorldLootFarm = false,
    WorldLootThread = nil,
    WorldLootPreLocation = nil,
    CollectedWorldLoot = {}
}

local function getRoot()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getCFrame()
    local root = getRoot()
    return root and root.CFrame
end

local function teleport(position)
    local root = getRoot()
    if root then
        root.CFrame = position
    end
end

local function setupTeleport(v)
    local char = player.Character
    local torso = char and char:FindFirstChild("Torso")
    if not torso then
        return
    end

    if v then
        if torso:FindFirstChild("TeleportThing") then
            return
        end

        local bv = Instance.new("BodyVelocity")
        bv.Name = "TeleportThing"
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = torso
    else
        local bv = torso:FindFirstChild("TeleportThing")
        if bv then
            bv:Destroy()
        end

        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            camera.CameraSubject = humanoid
        end
    end
end

local function fireprompt(proximityPrompt : ProximityPrompt)
    proximityPrompt:InputHoldBegin()
    task.wait(proximityPrompt.HoldDuration + .1)
    proximityPrompt:InputHoldEnd()
end

local function fetchCodes()
    local response = request({
        Url = Config.CodesUrl,
        Method = "GET"
    })

    local codes = {}

    for code in response.Body:gmatch('data%-code="([^"]+)"') do
        table.insert(codes, code)
    end

    return codes
end

local function handleWorldLoot(c)
    if not State.WorldLootFarm or State.CollectedWorldLoot[c] then
        return false
    end

    if not c.Name:lower():find("worldloot") then
        return false
    end

    print(c.Name:lower())

    State.CollectedWorldLoot[c] = true

    local prompt = c:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt then
        return true
    end

    local cf = c.CFrame

    teleport(cf * Config.LootOffset)
    camera.CameraSubject = c
    task.wait(Config.CollectTimeout)
    fireprompt(prompt)
    task.wait(Config.CollectTimeout)

    return true
end

local function startWorldLootFarm()
    State.WorldLootFarm = true
    State.WorldLootPreLocation = getCFrame()
    table.clear(State.CollectedWorldLoot)

    setupTeleport(true)
    teleport(Config.SafeSpot)

    State.WorldLootThread = task.spawn(function()
        local atSafe = true

        while State.WorldLootFarm do
            local found = false

            for _, c in ipairs(Workspace:GetChildren()) do
                if handleWorldLoot(c) then
                    found = true
                    atSafe = false
                end
            end

            if not found and not atSafe then
                teleport(Config.SafeSpot)
                camera.CameraSubject = Players.LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
                atSafe = true
            end

            task.wait()
        end
    end)
end

local function stopWorldLootFarm()
    State.WorldLootFarm = false

    if State.WorldLootThread then
        task.cancel(State.WorldLootThread)
        State.WorldLootThread = nil
    end

    VirtualUser:SetKeyUp(PROMPT_KEY)
    setupTeleport(false)

    if State.WorldLootPreLocation then
        teleport(State.WorldLootPreLocation)
    end
end

local Window = Library:Window({Text = "Bizzare thing"})

local FarmsTab = Window:Tab({Text = "Farms"})
local MiscTab = Window:Tab({Text = "Misc"})

local worldLootSection = FarmsTab:Section({Text = "Worldloot"})
local farmSettingSection = FarmsTab:Section({Text = "Settings"})

worldLootSection:Toggle({
    Text = "Enabled",
    Callback = function(v)
        if v then
            startWorldLootFarm()
        else
            stopWorldLootFarm()
        end
    end
})

farmSettingSection:Button({
    Text = "Set Safe spot",
    Callback = function()
        Config.SafeSpot = getCFrame()
    end
})

local codesSection = MiscTab:Section({Text = "Codes"})

codesSection:Button({
    Text = "Redeem all codes",
    Callback = function()
        for _, code in ipairs(fetchCodes()) do
            local codeRequest : RemoteFunction = ReplicatedStorage.Remotes.CodeRequest
            codeRequest:InvokeServer("Redeem", {Code = code})
            task.wait(Config.CodeDelay)
        end
    end
})

FarmsTab:Select()

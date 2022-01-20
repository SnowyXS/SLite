local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character

local humanoid = Character.Humanoid
local humanoidRootPart = Character.PrimaryPart

local playerData = LocalPlayer:WaitForChild("PlayerData")

local MenuControl, BaseSelection, ValueNames

local Collector = Garbage.new()

repeat
    MenuControl, BaseSelection, ValueNames = Collector:FetchGarbageSearch("QuestModule", "Elements", "Money4")
until task.wait(0.25) and (MenuControl and BaseSelection and ValueNames and MenuControl.DecreaseStamina)

local Settings = Settings.new()

local gameEvent, gameFunction = MenuControl.GameEvent, MenuControl.GameFunction

local Quests = MenuControl.QuestModule
local RefreshNPCs = Quests.RefreshNPCs

local NpcList = debug.getupvalue(RefreshNPCs, 3)
local NpcModel = MenuControl.QuestNPCs

local ATLA = {}

function ATLA.GetGameModule()
    return MenuControl
end

function ATLA.GetQuests()
    return Quests
end

function ATLA.GetSettings()
    return Settings
end

function ATLA.GetValueNames()
    return ValueNames
end

function ATLA:GetLastQuest()
    return self.lastQuest
end

function ATLA:GetPingDelay()
    local previousTick = tick() 
    
    gameFunction:InvokeServer("GetQuestData")
        
    return (tick() - previousTick) * 1.125
end

function ATLA.GetNpcByQuest(quest)
    for NPCName, v in pairs(NpcList) do
        if table.find(v, quest) then
            return NpcModel:FindFirstChild(NPCName)
        end
    end
end

function ATLA:LockToNPC(npc)
    local isContinuable = playerData.PlayerSettings.Continuable.Value
    local menuStatus = getupvalue(MenuControl.SpawnCharacter, 2)

    local teleportCoroutine = coroutine.create(function()
        while Settings:Get("canCompleteQuest") and not MenuControl.Transitioning and isContinuable and menuStatus == 2 and humanoidRootPart do
            humanoidRootPart.CFrame = npc.PrimaryPart.CFrame * CFrame.new(0,-12.5,0) * CFrame.Angles(math.rad(90), 0, 0)

            task.wait() 
        end
    end)

    return coroutine.resume(teleportCoroutine)
end

function ATLA.SpawnCharacter()
    local isContinuable = playerData.PlayerSettings.Continuable.Value
    local menuStatus = getupvalue(MenuControl.SpawnCharacter, 2)

    if isContinuable and menuStatus < 2 then
        MenuControl.MainFrame:TweenPosition(UDim2.new(0.5, -150, 1.5, -150), "Out", "Quad", 1, true)
        MenuControl.SpawnFrame:TweenPosition(UDim2.new(2, -10, 1, -10), "Out", "Quad", 2, true)

        MenuControl.MainFrame.Visible = false
        MenuControl.SpawnFrame.Visible = false

        MenuControl.SpawnCharacter()
    end
end

function ATLA:StopQuest()
    Settings:Set("shouldStopFarm", true)
    Settings:Set("canCompleteQuest", false)

    task.wait(0.5)

    Settings:Set("shouldStopFarm", false)
end

function ATLA:CompleteQuest(quest)
    local npc = self.GetNpcByQuest(quest)
    
    local isContinuable, isTransitioning = playerData.PlayerSettings.Continuable.Value, MenuControl.Transitioning
    local menuStatus = getupvalue(MenuControl.SpawnCharacter, 2)

    self.SpawnCharacter()

    local canCompleteQuest = Settings:Set("canCompleteQuest", 
                                                npc and humanoid.Health > 0 
                                                and humanoid.WalkSpeed > 0
                                                and not Character:FindFirstChild("Down") 
                                                and not (humanoidRootPart:FindFirstChild("DownTimer") and humanoidRootPart.DownTimer.TextLabel.Text ~= "") 
                                                and not Settings:Get("canCompleteQuest")
                                                and menuStatus == 2 
                                                and isContinuable
                                                and not isTransitioning
                                                and not Settings:Get("shouldStopFarm")) 
                                                and self:GetLastQuest() ~= quest 

    if canCompleteQuest then
        local hasChanged = false
        local moneyPropertyChanged = PropertyChanged.new(playerData.Stats.Money1,               
                                                         playerData.Stats.Money2,         
                                                         playerData.Stats.Money3, 
                                                         playerData.Stats.Money4,
                                                         playerData.Stats.Money5)

        moneyPropertyChanged:ConnectAll(function()
            hasChanged = true
        end)
        
        self:LockToNPC(npc)

        task.wait(self:GetPingDelay())

        while not hasChanged and not Settings:Get("shouldStopFarm") and task.wait(self:GetPingDelay()) do
            for step = 1, #Quests[quest].Steps + 1 do 
                task.spawn(function()
                    local distance = (npc.PrimaryPart.CFrame.p - humanoidRootPart.CFrame.p).Magnitude

                    if distance < 25 and not Settings:Get("shouldStopFarm") then
                        gameFunction:InvokeServer("AdvanceStep", {
                            QuestName = quest,
                            Step = step
                        })
                    end
                end)
            end
        end

        if hasChanged then
            Settings:Set("lastQuest", quest)
        end

        Settings:Set("canCompleteQuest", false)

        moneyPropertyChanged:DisconnectAll()
    end
end

function ATLA.ToggleFlight(toggle)
    local startFlying = MenuControl.startRealFlying

    setupvalue(startFlying, 3, toggle)
    setupvalue(startFlying, 4, toggle)

    if toggle then
        startFlying(Character, 0)
    end
end

function ATLA.SetMaxStamina(number)
    local CurrentStamina = MenuControl.CurrentStamina
    local StaminaConnection
    
    for _, v in pairs(getconnections(playerData.Stats.Stamina.Changed)) do
        if v.Function then
            local upvalues = getupvalues(v.Function)

            if typeof(upvalues[3]) == "number" then
                StaminaConnection = v
                break
            end
        end
    end

    setupvalue(CurrentStamina, 1, number)

    StaminaConnection:Fire(number - 25)
end

function ATLA.ToggleStamina(toggle)
    Settings:Set("staminaUsage", toggle)
end

function ATLA.Attack()
    gameFunction:InvokeServer("ProcessKey", {
        Key = "Q"
    })
end

function ATLA.GetPlayerAppearance()
    return playerData.Appearance
end

function ATLA:ChangeElement(element, ...)
    local appearance = self.GetPlayerAppearance()

    local specialAbility = appearance.Special
    local secondSpecialAbility = appearance.Special2

    local specials = {...}

    local selectedSpecial = specials[1]
    local selectedSecondSpecial = specials[2]
    
    BaseSelection.Elements = element

    print("\n--- Element changer ---",
          "\nElement: " .. element, 
          "\n\nCurrent Special: " .. specialAbility.Value, 
          "\n -> Waiting For: " ..  selectedSpecial, 
          "\n -> hasGotSpecial: " ..  tostring(specialAbility.Value == selectedSpecial), 
          "\n\nCurrent Second Special: " .. secondSpecialAbility.Value, 
          "\n -> Waiting For: " ..  selectedSecondSpecial, 
          "\n -> hasGotSecondSpecial: " .. tostring(secondSpecialAbility.Value == selectedSecondSpecial))

    return ((specialAbility.Value ~= selectedSpecial 
             or secondSpecialAbility.Value ~= selectedSecondSpecial) and gameFunction:InvokeServer("NewGame", {Selections = BaseSelection}) and true) 
             or (specialAbility.Value == selectedSpecial and secondSpecialAbility.Value == selectedSecondSpecial and false) 
end

humanoid.Died:Connect(function()
    Settings:Set("shouldStopFarm", true)
end)

LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter

    humanoid = Character:WaitForChild("Humanoid")
    humanoidRootPart = Character.PrimaryPart

    local mainMenu = LocalPlayer.PlayerGui:WaitForChild("MainMenu")
    local menuControlInstance = mainMenu:WaitForChild("MenuControl")

    local MenuControlEnv = getsenv(menuControlInstance)

    repeat task.wait() until MenuControlEnv.DecreaseStamina

    MenuControl = MenuControlEnv

    local OldDecreaseStamina = MenuControl.DecreaseStamina

    MenuControl.DecreaseStamina = function(...)
        local staminaUsage = Settings:Get("staminaUsage")
    
        if staminaUsage == false or Settings:Get("canCompleteQuest") then
            return
        end 
    
        return OldDecreaseStamina(...)
    end

    humanoid.Died:Connect(function()
        Settings:Set("shouldStopFarm", true)
    end)

    Settings:Set("shouldStopFarm", false)
end)

local OldDecreaseStamina = MenuControl.DecreaseStamina

MenuControl.DecreaseStamina = function(...)
    local staminaUsage = Settings:Get("staminaUsage")

    if staminaUsage == false or Settings:Get("canCompleteQuest") then
        return
    end 

    return OldDecreaseStamina(...)
end

getgenv().ATLA = ATLA
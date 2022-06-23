-- EndRoundCondition v2 - ends the round on certain conditions
-- by MassCraxx

-- CONFIG
-- end game X seconds after condition has been checked
local EndGameDelaySeconds = 5
-- check every X seconds
local CheckDelaySeconds = 10

-- sends a message to all players on end round including a reason. 
-- can be set to a string to always send that message.
local EndGameMessage = true
local EndGameMessageIcon = "InfoFrameTabButton.Mission"             

-- minimum amount of players that must have died before any condition can be met. 0 = Disabled
local MinimumDiedCrew = 0
-- minimum amount of players that must have respawned before any condition can be met. 0 = Disabled
local MinimumRespawnedCrew = 1

-- end round if reactor condition reaches 0.
local EndOnReactorMeltdown = true
-- end round if all players are dead simultaneously.
local EndOnAllPlayersDead = false
-- end round if set amount of players died. 0 = Disabled
local EndOnCrewDeaths = 0


EndRound = {}

EndRound.DiedPlayers = 0
EndRound.RespawnedPlayers = 0
EndRound.ReactorItem = nil
EndRound.Spawns = {}

EndRound.Log = function (message)
    Game.Log("[EndRoundCondition] " .. message, 6)
end

EndRound.CheckCondition = function()
    -- if after so many died crew members
    if (not MinimumDiedCrew or MinimumDiedCrew == 0 or EndRound.DiedPlayers >= MinimumDiedCrew)
        -- and so many respawned crew members
        and (not MinimumRespawnedCrew or MinimumRespawnedCrew == 0 or EndRound.RespawnedPlayers >= MinimumRespawnedCrew) then

        -- if reactor exploded
        if EndOnReactorMeltdown then
            local reactor = EndRound.GetReactor()
            if reactor and reactor.Condition == 0 then
                return true, "The Reactor was destroyed"
            end
        end

        -- if all players dead or disconnected
        if EndOnAllPlayersDead then
            local allded = true
            for key, value in pairs(Client.ClientList) do
                if value.Character ~= nil and not value.Character.IsDead and not value.Character.ClientDisconnected then
                    allded = false
                    break
                end
            end
            if allded then
                return true, "All players are dead"
            end
        end

        -- if enough players died
        if EndOnCrewDeaths and EndOnCrewDeaths > 0 and EndRound.DiedPlayers >= EndOnCrewDeaths then
            return true, tostring(EndRound.DiedPlayers) .. " players died"
        end
    end

    return false
end

EndRound.GetReactor = function()
    if Game.RoundStarted and not EndRound.ReactorItem then
        for item in Submarine.MainSub.GetItems(false) do
            local reactor = item.GetComponentString("Reactor")
            if reactor ~= nil then
                EndRound.ReactorItem = item
                return item
            end
        end
    elseif EndRound.ReactorItem then
        return EndRound.ReactorItem
    end
    return nil
end

EndRound.SendMessage = function (client, text, icon)
    if not client or not text or text == "" then
        return
    end

    if icon then
        Game.SendDirectChatMessage("", text, nil, ChatMessageType.ServerMessageBoxInGame, client, icon)
    end

    Game.SendDirectChatMessage("", text, nil, ChatMessageType.Private, client)
end

Hook.Add("roundEnd", "EndRoundCondition.roundEnd", function ()
    EndRound.DiedPlayers = 0
    EndRound.RespawnedPlayers = 0
    EndRound.ReactorItem = nil
    EndRound.Spawns = {}
end)

local checkTime = -1
Hook.Add("think", "EndRoundCondition.think", function ()
    if Game.RoundStarted and checkTime and Timer.GetTime() > checkTime then
        checkTime = Timer.GetTime() + CheckDelaySeconds
        
        local endRound, message = EndRound.CheckCondition()
        if endRound then
            -- send message to players
            if EndGameMessage and message then
                if EndGameMessage ~= true then
                    message = EndGameMessage
                else
                    message = message .. " - Round ends."
                end
                for key, value in pairs(Client.ClientList) do
                    EndRound.SendMessage(value, message, EndGameMessageIcon)
                end
            end

            Timer.Wait(function () 
                if Game.RoundStarted then
                    EndRound.Log("Ending round: " .. message)
                    Game.EndGame()
                end
            end, EndGameDelaySeconds * 1000)
        end
    end
end)

if (MinimumDiedCrew and MinimumDiedCrew > 0) or (EndOnCrewDeaths and EndOnCrewDeaths > 0) then
-- store deaths
    Hook.Add("characterDeath", "Traitormod.characterDeath", function (character, affliction)
        -- if character is valid player
        if  character == nil or 
            character.IsHuman == false or
            character.IsBot == true or
            character.ClientDisconnected == true then
            return
        end

        EndRound.DiedPlayers = (EndRound.DiedPlayers or 0) + 1
    end)
end

if MinimumRespawnedCrew and MinimumRespawnedCrew > 0 then
    Hook.Add("characterCreated", "EndRoundCondition.characterCreated", function (character)
        -- if character is valid player
        if character == nil or 
        character.IsBot == true or
        character.IsHuman == false or
        character.ClientDisconnected == true then
            return
        end

        if EndRound.Spawns[character.Name] == nil then
            -- if first spawn for character, ignore and store
            EndRound.Spawns[character.Name] = 1
        else
            -- else increase RespawnedPlayers
            EndRound.Spawns[character.Name] = EndRound.Spawns[character.Name] + 1
            EndRound.RespawnedPlayers = EndRound.RespawnedPlayers + 1
        end
    end)
end

-- Commands hook
Hook.Add("chatMessage", "EndRoundCondition.ChatMessage", function (message, client)
    if not client.HasPermission(ClientPermissions.All) then return end

    if message == "!meltdown" then
        local reactor = EndRound.GetReactor()
        EndRound.Log("Admin " .. client.Name .. " initiating meltdown.")
        if reactor then
            reactor.Condition = 0
        end
        return true
    end
end)
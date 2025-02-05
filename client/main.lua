local QBCore = exports['qb-core']:GetCoreObject()

local bloodGiveRadius = 5
local thinkAnims = {
    "think", "think2", "think3", "think4", "think6"
}

local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function GetClosestPlayers(radius)
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local closestPlayers = {}

    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= ped then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(pedCoords - targetCoords)
            if distance <= radius then
                table.insert(closestPlayers, {
                    playerId = playerId,
                    distance = distance
                })
            end
        end
    end

    -- Sort the table by distance (ascending)
    table.sort(closestPlayers, function(a, b)
        return a.distance < b.distance
    end)

    return closestPlayers
end

RegisterNetEvent('noted-blooddraw:client:print', function(stuff)
    print(stuff)
end)

RegisterNetEvent('noted-blooddraw:client:bloodTransfusion', function(bloodbagtype, bloodbagname)
    local ped = PlayerPedId()
    QBCore.Functions.Progressbar("transfusingbloodstart", "Preparing Transfusion", 1000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        local p = promise.new() QBCore.Functions.TriggerCallback('noted-blooddraw:server:MakePlayerList', function(cb) p:resolve(cb) end)
		local onlineList = Citizen.Await(p)
		local nearbyList = {}
        local newinputs = {}
        local firstValue
		--Convert list of players nearby into one qb-input understands + add distance info
		for _, v in pairs(QBCore.Functions.GetPlayersFromCoords(GetEntityCoords(PlayerPedId()), bloodGiveRadius)) do
			local dist = #(GetEntityCoords(GetPlayerPed(v)) - GetEntityCoords(PlayerPedId()))
			for i = 1, #onlineList do
				if onlineList[i].value == GetPlayerServerId(v) then
					if v ~= PlayerId() then
						nearbyList[#nearbyList+1] = { value = onlineList[i].value, label = onlineList[i].text..' ('..math.floor(dist+0.05)..'m)', text = onlineList[i].text..' ('..math.floor(dist+0.05)..'m)' }
                        if #nearbyList == 1 then
                            firstValue = onlineList[i].value
                        end
					end
				end
			end
		end
		--If list is empty(no one nearby) show error and stop
		if not nearbyList[1] then triggerNotify(nil, "There is no one nearby to give blood to.", "error") return end
		newinputs[#newinputs+1] = { text = " ", name = "citizen", label ="Targets:", type = "select", options = nearbyList, default = firstValue }
        dialog = exports.ox_lib:inputDialog("Giving "..bloodbagname.." Blood To...", newinputs)

        if dialog then
            local inputs = {
                citizen = dialog.citizen or dialog[1],
            }
            if not inputs.citizen then return end
            QBCore.Functions.Progressbar("transfusingbloodfinish", "Administering Blood", 5000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
                QBCore.Functions.TriggerCallback('noted-blooddraw:server:transfusionact', function(result)
                    if result then
                        QBCore.Functions.Notify("The blood you administered seems to have been the right type, the blood transfusion was administered properly.", 'success', 15000)
                    else
                        QBCore.Functions.Notify("Something seems to have been done wrong...", 'error', 15000)
                    end
                end, inputs.citizen, bloodbagtype)
            end, function()
                
            end)
        end
    end, function() -- cancel

    end)

end)



RegisterNetEvent('noted-blooddraw:client:startDrawingBlood', function()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local otherPlayer = lib.getClosestPlayer(playerCoords, 3.0)
    --print(dump(otherPlayer))
    if otherPlayer then
        local otherPlayerS = GetPlayerServerId(otherPlayer)
        local targetPed = GetPlayerPed(otherPlayer)
        local lockpickBlocker = false
        TaskTurnPedToFaceEntity(ped, targetPed, 1000)
        Wait(1000)
        TriggerEvent('animations:client:EmoteCommandStart', {"clipboard"})
        -- TriggerEvent('animations:client:EmoteCommandStart', {thinkAnims[math.random(1, #thinkAnims)]})
        QBCore.Functions.Progressbar("startblooddraw", "Checking Client Information", 2500, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            -- Clear the welding task
            -- ClearPedTasks(ped)
            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
            TaskGoToEntity(ped, targetPed, 1500, 1.2, 1.0, 1073741824, 0)
            QBCore.Functions.Progressbar("bloodapproach", "Approaching Patient", 1500, false, true, {
            disableMovement = false,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
            }, {}, {}, {}, function() -- Done
                TriggerEvent('animations:client:EmoteCommandStart', {thinkAnims[math.random(1, #thinkAnims)]})
                local attempts = 3
                local success = false
                while not success and attempts > 0 do
                    local playerCoords = GetEntityCoords(ped)
                    local otherCoords = GetEntityCoords(targetPed)
                    if #(playerCoords - otherCoords) < 2.0 then
                        lockpickBlocker = true
                        QBCore.Functions.Progressbar("veinsearch", "Looking For A Vein", 1500, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true,
                        }, {}, {}, {}, function() -- Done
                            success = exports["bd-minigames"]:Lockpick("Lockpick", 3, 25)
                            if not success then
                                QBCore.Functions.Notify("You failed to find a vein", "error")
                                attempts = attempts - 1
                                lockpickBlocker = false
                            else
                                lockpickBlocker = false
                            end
                        end, function()
                            attempts = -1
                            success = false
                            lockpickBlocker = false
                        end)
                    else
                        QBCore.Functions.Notify("Your patient has walked too far away", "error")
                        attempts = -1
                        success = false
                        lockpickBlocker = false
                    end
                    while lockpickBlocker do
                        Wait(100)
                    end
                end
                -- local success = true
                if success then
                    QBCore.Functions.TriggerCallback('noted-blooddraw:server:prebloodcheck', function(result)
                        if result then
                            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                            QBCore.Functions.Notify("You notice the individual looks weak, they've certainly gotten their blood drawn before today and can't until some time has passed.", "error", 15000)
                            return
                        end
                        local playerCoords = GetEntityCoords(ped)
                        local otherCoords = GetEntityCoords(targetPed)
                        if #(playerCoords - otherCoords) < 2.0 then
                            QBCore.Functions.Notify("You struck crimson gold!", "success")
                            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                            Wait(250)
                            TriggerEvent('animations:client:EmoteCommandStart', {"syringe"})
                            QBCore.Functions.Progressbar("drawingblood", "Drawing Blood", 2850, false, true, {
                            disableMovement = false,
                            disableCarMovement = true,
                            disableMouse = false,
                            disableCombat = true,
                            }, {}, {}, {}, function() -- Done
                                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                                print("reached")
                                TriggerServerEvent('noted-blooddraw:server:succeedBloodDraw', otherPlayerS)
                            end, function() -- cancel
                                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                            end)
                        else
                            QBCore.Functions.Notify("Your patient has walked too far away", "error")
                        end
                    end, otherPlayerS)
                else
                    TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                end
            end, function() -- cancel
                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
            end)
        end, function() -- cancel
            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
        end)
    end
end)


-- blood testing portion:


RegisterNetEvent('noted-blooddraw:client:getbloodsample', function()
    QBCore.Functions.Progressbar("removebloodsample", "Checking Client Information", 1000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        local input = lib.inputDialog('Blood Sample Note', {
            {type = "textarea", label = "Insert Description Of Sample Here: ", autosize = true}
        })
        local output
        if input and input[1] ~= '' then
            output = input[1]
        else
            output = "Blood Sample #" .. string.format("%03d", math.random(1, 999))
        end
        TriggerServerEvent('noted-blooddraw:server:getBloodSample', GetPlayerServerId(PlayerId()), output)
    end, function()

    end)
end)

RegisterNetEvent('noted-blooddraw:client:startbloodsampletest', function(data)
    print("entered")
    QBCore.Functions.Progressbar("removebloodsample", "Checking Client Information", 2500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        
        local success = exports["bd-minigames"]:Lockpick("Lockpick", 3, 25)
        if not success then
            QBCore.Functions.Notify("This blood sample is proving to be difficult to analyze...", "error")
            QBCore.Functions.Progressbar("removebloodsample", "Checking Client Information", 2500, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
                success = exports["bd-minigames"]:Lockpick("Lockpick", 3, 25)
                if not success then
                    QBCore.Functions.Notify("You failed to analyze the blood sample, it's been corrupted", "error")
                    TriggerServerEvent('noted-blooddraw:server:failbloodsample', data)
                else
                    TriggerServerEvent('noted-blooddraw:server:finishBloodTesting', data)
                end
            end, function()
                TriggerServerEvent('noted-blooddraw:server:failbloodsample', data)
            end)
        else
            TriggerServerEvent('noted-blooddraw:server:finishBloodTesting', data)
        end
    end, function()

    end)
end)

RegisterNetEvent('noted-blooddraw:client:checkbloodsample', function(inventory)
    local foundBlood = false
    local opt = {}

    for k, v in pairs(inventory) do           
        -- print("v == " .. dump(v))
        if v.name == 'bloodsample' and v.info and v.info.blood then

            opt[#opt+1] = {
                header = 'Blood Sample In Slot: ' .. k,
                text = 'Blood Sample In Slot: ' .. k,
                title = 'Blood Sample In Slot: ' .. k,
                params = {
                    event = 'noted-blooddraw:client:startbloodsampletest',
                    args = {
                        slot = k,
                    },
                },
                event = 'noted-blooddraw:client:startbloodsampletest',
                args = {
                    slot = k,
                },
            }
            if not foundBlood then foundBlood = true end
        end
    end

    if not foundBlood then
        QBCore.Functions.Notify('You have no blood samples to test', 'error')
        return
    end

    opt[#opt+1] = {
        header = "Close (ESC)",
        title = "Close (ESC)",
        params = {
            event = 'qb-menu:client:closeMenu',
        },
        event = 'qb-menu:client:closeMenu',
    }

    local menu = {
        id = 'bloodmenu',
        title = '**Test Blood Sample:**',
        canClose = true,
        options = opt,
    }
    
    lib.registerContext(menu)
    lib.showContext('bloodmenu')
end)


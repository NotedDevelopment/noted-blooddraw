local QBCore = GetResourceState('qb-core') == 'started' and exports['qb-core']:GetCoreObject()
local ESX = GetResourceState('es_extended') == 'started' and exports.es_extended:getSharedObject()
local ox_inventory = GetResourceState('ox_inventory') == 'started' and exports.ox_inventory

local bloodGiveRadius = 5
local bloodCheckpointLabel = "Analyze Blood Samples"
local bloodCheckPoints = {
    {
        startLocation = vector3(315.32, -568.53, 43.16),
        distance = 3,
        id = "sandy",
    },
    {
        startLocation = vector3(323.47, -571.47, 43.13),
        distance = 3,
        id = "sandy",
    },
}
local approvedJobs = {
    ["ambulance"] = 0
}

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
            TriggerServerEvent('noted-blooddraw:server:getBloodSample', GetPlayerServerId(PlayerId()), output)
        elseif input and input[1] == '' then
            output = "Blood Sample #" .. string.format("%03d", math.random(1, 999))
            TriggerServerEvent('noted-blooddraw:server:getBloodSample', GetPlayerServerId(PlayerId()), output)
        end
    end, function()

    end)
end)

RegisterNetEvent('noted-blooddraw:client:startbloodsampletest', function(data)
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
                    print("called prematurely")
                    TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                    TriggerServerEvent('noted-blooddraw:server:finishBloodTesting', data)
                end
            end, function()
                print("called prematurely")
                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                TriggerServerEvent('noted-blooddraw:server:failbloodsample', data)
            end)
        else
            print("called prematurely")
            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
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
                title = v.info.text,
                description = 'Blood Sample In Slot: ' .. k,
                -- params = {
                --     event = 'noted-blooddraw:client:startbloodsampletest',
                --     args = {
                --         slot = k,
                --     },
                -- },
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
    
    TriggerEvent('animations:client:EmoteCommandStart', {"cokecut"})
    opt[#opt+1] = {
        title = "Close (ESC)",
        onSelect = function() TriggerEvent('animations:client:EmoteCommandStart', {"c"}) end,
    }

    local menu = {
        id = 'bloodmenu',
        title = '**Test Blood Sample:**',
        canClose = true,
        options = opt,
        onExit = function() TriggerEvent('animations:client:EmoteCommandStart', {"c"}) end,
    }
    
    lib.registerContext(menu)
    lib.showContext('bloodmenu')
end)

-- {
--     startLocation = vector3(315.32, -568.53, 43.16),
--     distance = 3,
--     DropOffLocations = "sandy",
-- },

CreateThread(function()
    for i, doz in ipairs(bloodCheckPoints) do
        print("called " .. i)
        exports.interact:AddInteraction({
            coords = doz.startLocation,
            distance = doz.distance,
            interactDst = doz.distance,
            id = "bloodcheck" .. doz.id,
            options = {
                {
                    label = bloodCheckpointLabel,
                    canInteract = function()
                        local Player = QBCore.Functions.GetPlayerData()
                        -- print("job name == " .. Player.job.name)
                        -- print("job grade == " .. Player.job.grade.level)
                        return (approvedJobs[Player.job.name] and approvedJobs[Player.job.name] <= Player.job.grade.level)
                    end,
                    action = function(entity, coords, args)
                        TaskTurnPedToFaceCoord(PlayerPedId(), doz.startLocation.x, doz.startLocation.y, doz.startLocation.z, 1200)
                        QBCore.Functions.Progressbar("stoppackingnormal", "Starting Delivery Runs", 1200, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true,
                        }, {
                        }, {}, {}, function()
                            TriggerServerEvent('noted-blooddraw:server:getBloodSamples')
                        end, function()
                        -- Cancel
                        end)
                    end,
                    args = {
                        index = i,
                    },
                },
            } 
        })
    end
end)

RegisterNetEvent('noted-blooddraw:client:printMedicalCard', function(info, slot)
    QBCore.Functions.Progressbar("printmedicalcard", "Checking Client Information", 1000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        local input 
        if info then
            input = lib.inputDialog('Blood Sample Note', {
                {type = "textarea", label = "Name: ", autosize = true, default = info.name},
                {type = "textarea", label = "Alias: ", autosize = true, default = info.alias},
                {type = "textarea", label = "Age: ", autosize = true, default = info.age},
                {type = "textarea", label = "Blood Type: ", autosize = true, default = info.bloodtype},
                {type = "textarea", label = "Allergies: ", autosize = true, default = info.allergies},
                {type = "textarea", label = "Medications: ", autosize = true, default = info.medications},
                {type = "textarea", label = "Emergency Contacts: ", autosize = true, default = info.emergencyContacts},
                {type = "textarea", label = "Details: ", autosize = true, default = info.details},
            })
        else
            input = lib.inputDialog('Blood Sample Note', {
                {type = "textarea", label = "Name: ", autosize = true},
                {type = "textarea", label = "Alias: ", autosize = true},
                {type = "textarea", label = "Age: ", autosize = true},
                {type = "textarea", label = "Blood Type: ", autosize = true},
                {type = "textarea", label = "Allergies: ", autosize = true},
                {type = "textarea", label = "Medications: ", autosize = true},
                {type = "textarea", label = "Emergency Contacts: ", autosize = true},
                {type = "textarea", label = "Details: ", autosize = true},
            })
        end
        if input then
            TriggerServerEvent('noted-blooddraw:server:giveMedCard', input, slot)
        end
    end, function()

    end)
end)

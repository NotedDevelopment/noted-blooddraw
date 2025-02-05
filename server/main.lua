local QBCore = exports['qb-core']:GetCoreObject()
local bloodDrawnPeople = {}

local transfusionItem = 'syringe'
local bloodDrawItem = 'emptybloodbag'
local itemName = "bloodsample"

local recieveableBlood = {
    ["A-"] = {
        translation = "anbloodbag",
        transfusion = {
            ["anbloodbag"] = true,
            ["onbloodbag"] = true
        }
    },
    ["A+"] = {
        translation = "apbloodbag",
        transfusion = {
            ["anbloodbag"] = true,
            ["apbloodbag"] = true,
            ["onbloodbag"] = true,
            ["opbloodbag"] = true
        }
    },
    ["B-"] = {
        translation = "bnbloodbag",
        transfusion = {
            ["bnbloodbag"] = true,
            ["onbloodbag"] = true
        }
    },
    ["B+"] = {
        translation = "bpbloodbag",
        transfusion = {
            ["bnbloodbag"] = true,
            ["bpbloodbag"] = true,
            ["onbloodbag"] = true,
            ["opbloodbag"] = true
        }
    },
    ["AB-"] = {
        translation = "abnbloodbag",
        transfusion = {
            ["abnbloodbag"] = true,
            ["anbloodbag"] = true,
            ["bnbloodbag"] = true,
            ["onbloodbag"] = true
        }
    },
    ["AB+"] = {
        translation = "abpbloodbag",
        transfusion = {
            ["abpbloodbag"] = true,
            ["abnbloodbag"] = true,
            ["anbloodbag"] = true,
            ["apbloodbag"] = true,
            ["bnbloodbag"] = true,
            ["bpbloodbag"] = true,
            ["onbloodbag"] = true,
            ["opbloodbag"] = true
        }
    },
    ["O-"] = {
        translation = "onbloodbag",
        transfusion = {
            ["abnbloodbag"] = true,
            ["anbloodbag"] = true,
            ["bnbloodbag"] = true,
            ["onbloodbag"] = true
        }
    },
    ["O+"] = {
        translation = "opbloodbag",
        transfusion = {
            ["abpbloodbag"] = true,
            ["abnbloodbag"] = true,
            ["anbloodbag"] = true,
            ["apbloodbag"] = true,
            ["bnbloodbag"] = true,
            ["bpbloodbag"] = true,
            ["onbloodbag"] = true,
            ["opbloodbag"] = true
        }
    }
}

local revertName = {
    ["abpbloodbag"] = "AB+",
    ["abnbloodbag"] = "AB-",
    ["apbloodbag"] = "A+",
    ["anbloodbag"] = "A-",
    ["bpbloodbag"] = "B+",
    ["bnbloodbag"] = "B-",
    ["opbloodbag"] = "O+",
    ["onbloodbag"] = "O-"
}

local function AddSuffix(day)
    local suffix = "th"
    if day % 10 == 1 and day ~= 11 then
        suffix = "st"
    elseif day % 10 == 2 and day ~= 12 then
        suffix = "nd"
    elseif day % 10 == 3 and day ~= 13 then
        suffix = "rd"
    end
    return tostring(day) .. suffix
end

for key, value in pairs(revertName) do
    QBCore.Functions.CreateUseableItem(key, function(source, item)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local hasItem
        if transfusionItem then
            hasItem = QBCore.Functions.HasItem(src, transfusionItem)
        else
            hasItem = true
        end
        if hasItem then
            TriggerClientEvent('noted-blooddraw:client:bloodTransfusion', source, key, value)
        else
            TriggerClientEvent('QBCore:Notify', src, "You need something to administer the blood in this bag", 'error')
        end
    end)
end

QBCore.Functions.CreateUseableItem('phlebotomistkit', function(source, item)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    item = player.Functions.GetItemByName(bloodDrawItem)
    if item and item.amount > 0 then
        TriggerClientEvent('noted-blooddraw:client:startDrawingBlood', src)
    else
        TriggerClientEvent('QBCore:Notify', src, "You need something to hold the blood you're trying to draw", 'error')
    end
end)

local function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

RegisterCommand("aw", function(source)
   local src = source
   local player = QBCore.Functions.GetPlayer(src)
   TriggerClientEvent('noted-blooddraw:client:getbloodsample', source)
   -- TriggerClientEvent('noted-blooddraw:client:print', src, player.PlayerData["metadata"]["bloodtype"])
   -- print(dump(player))
end, false)

RegisterNetEvent('noted-blooddraw:server:succeedBloodDraw', function(otherPlayer)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local success
    local message
    if bloodDrawItem then
        success, message = player.Functions.RemoveItem(bloodDrawItem)
    else
        success = true
    end
    if success then
        local op = QBCore.Functions.GetPlayer(otherPlayer)
        bloodDrawnPeople[op["PlayerData"]["citizenid"]] = true
        player.Functions.AddItem(recieveableBlood[op.PlayerData["metadata"]["bloodtype"]].translation)
        if bloodDrawItem then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[bloodDrawItem], 'remove', 1)
        end
        TriggerClientEvent('inventory:client:ItemBox', src,
            QBCore.Shared.Items[recieveableBlood[op.PlayerData["metadata"]["bloodtype"]].translation], 'add', 1)
    end
end)

QBCore.Functions.CreateCallback('noted-blooddraw:server:transfusionact', function(source, cb, otherPlayer, bbt)
    local player = QBCore.Functions.GetPlayer(source)
    local op = QBCore.Functions.GetPlayer(otherPlayer)
    if not op then
        cb(false)
        return
    end
    local opBlood = op.PlayerData["metadata"]["bloodtype"]
    player.Functions.RemoveItem(bbt, 1)
    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[bbt], "remove")
    if transfusionItem then
        player.Functions.RemoveItem(transfusionItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[transfusionItem], "remove")
    end
    if recieveableBlood[opBlood].transfusion[bbt] then
        TriggerClientEvent('QBCore:Notify', otherPlayer, "The blood you recieved is " .. revertName[bbt] ..
            ". The blood is compatible to you and was properly entered into your system.", 'success', 15000)
        cb(true)
    else
        TriggerClientEvent('QBCore:Notify', otherPlayer, "The blood you recieved is " .. revertName[bbt] ..
            ". It is not compatible with your blood type.", 'error', 15000)
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('noted-blooddraw:server:prebloodcheck', function(source, cb, otherPlayer)
    local op = QBCore.Functions.GetPlayer(otherPlayer)
    cb(bloodDrawnPeople[op["PlayerData"]["citizenid"]])
end)

-- grabbed from jim-recipiet
QBCore.Functions.CreateCallback('noted-blooddraw:server:MakePlayerList', function(source, cb)
    local onlineList = {}
    local me = QBCore.Functions.GetPlayer(source)
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(v)
        onlineList[#onlineList + 1] = {
            value = tonumber(v),
            text = "[" .. v .. "] - " .. P.PlayerData.charinfo.firstname .. " " .. P.PlayerData.charinfo.lastname
        }
    end
    cb(onlineList)
end)

-- blood test stuff (pending)



QBCore.Functions.CreateCallback('noted-blooddraw:server:startBloodTest', function(source, cb)
    local onlineList = {}
    local me = QBCore.Functions.GetPlayer(source)
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(v)
        onlineList[#onlineList + 1] = {
            value = tonumber(v),
            text = "[" .. v .. "] - " .. P.PlayerData.charinfo.firstname .. " " .. P.PlayerData.charinfo.lastname
        }
    end
    cb(onlineList)
end)

RegisterNetEvent('noted-blooddraw:server:giveMedCard', function(details)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    local proc = {}
    proc.name = details.name or "NaN"
    proc.alias = details.alias or "None"
    proc.bloodtype = details.bloodtype or "NaN"
    proc.allergies = details.allergies or "Nothing Documented"
    proc.medications = details.medications or "None"
    proc.emergencyContacts = details.emergencyContacts or "None"
    proc.details = details.details or ""

    if dateInput == true then
        local month = os.date("%B")
        local day = os.date("%d")
        local year = os.date("%Y")
        day = AddSuffix(tonumber(day))
        proc.date = month .. " " .. day .. ", " .. year
    end
    
    local info = {}
    info.text = "Name: " .. proc.name .. "<br>Alias/Nickname: " .. proc.alias .. "<br>Blood Type: " .. proc.bloodtype .. "<br>Allergic To: " .. proc.allergies .. "<br>Medications: " .. proc.medications .. "<br>Emergency Contact: " .. proc.emergencyContacts .. "<br>Extra Details: " .. proc.details
    Player.Functions.AddItem("medicalcard", 1, nil, info)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["medicalcard"], 'add', 1)
end)

RegisterNetEvent('noted-blooddraw:server:getBloodSample', function(otherPlayer, data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local op = QBCore.Functions.GetPlayer(otherPlayer)
    if not op then
        return
    end
    local opBlood = recieveableBlood[op.PlayerData["metadata"]["bloodtype"]].translation
    local info = {}
    info.blood =  op.PlayerData["metadata"]["bloodtype"]
    info.text = data
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['bloodsample'], "add")
    player.Functions.AddItem("bloodsample", 1, nil, info)
end)

RegisterCommand("blood", function(source) 
    local Player = QBCore.Functions.GetPlayer(source)
    TriggerClientEvent('noted-blooddraw:client:checkbloodsample', source, Player.PlayerData.items)
end)

RegisterNetEvent('noted-blooddraw:server:failbloodsample', function(data)
    local Player = QBCore.Functions.GetPlayer(source)
    local PlayerItems = Player.PlayerData.items
    local item = table.clone(PlayerItems[data.slot])
    if PlayerItems[data.slot] then
        Player.Functions.RemoveItem(item.name, 1, data.slot)
    end
end)

RegisterNetEvent('noted-blooddraw:server:finishBloodTesting', function(data)
    local Player = QBCore.Functions.GetPlayer(source)
    local PlayerItems = Player.PlayerData.items
    local item = table.clone(PlayerItems[data.slot])

    if PlayerItems[data.slot] then
        if Player.Functions.RemoveItem(item.name, 1, data.slot) then
            local info = {}
            info.text = "<strong>Tested Blood</strong><br>" ..  item.info.text .. "<br>Blood Type Result: " .. item.info.blood
            Player.Functions.AddItem("bloodsample", 1, data.slot, info)
            TriggerClientEvent('QBCore:Notify', source, "You recovered the blood type from this sample, it is: " .. item.info.blood, 'success', 10000)
        end
    end
end)
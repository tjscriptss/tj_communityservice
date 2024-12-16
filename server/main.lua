local activePlayers = {}
local actionCooldown = {}

local Webhooks = {
    ['communityservice'] = 'https://discord.com/api/webhooks/1312014498932195348/Btk3MhuUADu-FwAp8_YllWPm65QRsX6tBgmPlQZXgm2N1XNieISDUk171HELUg782ePl',
}


local function SendToDiscord(webhookName, title, message, color, tagEveryone)
    local webhook = Webhooks[webhookName]
    local datum = os.date("%d-%m-%Y")
    local vreme = os.date('*t')
    if not webhook then
        print('^1[DiscordLogs] Webhook ' .. webhookName .. ' nije pronađen!^7')
        return
    end

    local embed = {
        {
            ["color"] = color or 14423100,
            ["title"] = title or "Poruka",
            ["description"] = message or "Nema opisa.",
            ["footer"] = {
                ["text"] = "Vreme: " .. vreme.hour .. ":" .. vreme.min .. ":" .. vreme.sec .. "\nDatum: " .. datum,
            },
        }
    }

    PerformHttpRequest(webhook, function(err, text, headers)
        if err ~= 200 and err ~= 204 then
            print('^1[DiscordLogs] Greska prilikom slanja poruke: ' .. err .. '^7')
        end
    end, 'POST', json.encode({
        content = tagEveryone and "@everyone" or nil,
        embeds = embed,
    }), { ['Content-Type'] = 'application/json' })
end

local function AddServiceRecord(identifier, adminIdentifier, actionsGiven, reason)
    local historyId = MySQL.insert.await('INSERT INTO community_service_history (identifier, admin_identifier, actions_given, reason) VALUES (?, ?, ?, ?)',
        {identifier, adminIdentifier, actionsGiven, reason})
    
    MySQL.insert.await('INSERT INTO community_service_active (identifier, actions_remaining, total_actions, history_id, reason) VALUES (?, ?, ?, ?, ?)',
        {identifier, actionsGiven, actionsGiven, historyId, reason})
        
    return historyId
end

local function isAuthorized(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local playerGroup = xPlayer.getGroup()    
    local playerJob = xPlayer.job.name
    return Config.AuthorizedGroups[playerGroup] or Config.JobRolesAccess[playerJob] == true or false
end


local function checkAndRestoreCommunityService(source, identifier)
    local activeService = MySQL.single.await('SELECT * FROM community_service_active WHERE identifier = ?', {identifier})
    
    if activeService then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            activePlayers[source] = {
                actions = activeService.total_actions,
                remaining = activeService.actions_remaining,
                reason = activeService.reason
            }
            
            SetTimeout(5000, function()
                TriggerClientEvent('tj_communityservice:inService', source, activeService.actions_remaining)
            end)
        end
    end
end

AddEventHandler('esx:playerLoaded', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local identifier = xPlayer.identifier

        if identifier then
            Wait(5000)
            SetTimeout(10000, function()
                checkAndRestoreCommunityService(source, identifier)
            end)
        else 
        end
    end
end)


AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    local players = ESX.GetPlayers()
    for _, source in ipairs(players) do
        local identifier = ESX.GetPlayerFromId(source)?.identifier
        if identifier then
            checkAndRestoreCommunityService(source, identifier)
        end
    end
end)



local function storePlayerItems(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    local items = {}
    local inventory = xPlayer.inventory

    for _, item in pairs(inventory) do 
        if item.count > 0 then
            table.insert(items, {name = item.name, count = item.count})
            xPlayer.removeInventoryItem(item.name, item.count)
        end
    end

    local weapons = {}
    local loadout = xPlayer.getLoadout()
    
    for _, weapon in ipairs(loadout) do
        table.insert(weapons, {
            name = weapon.name,
            ammo = weapon.ammo,
            components = weapon.components or {}
        })
        xPlayer.removeWeapon(weapon.name)
    end

    local money = xPlayer.getMoney()
    local blackMoney = xPlayer.getAccount('black_money').money
    local bank = xPlayer.getAccount('bank').money

    xPlayer.removeMoney(money)
    xPlayer.removeAccountMoney('black_money', blackMoney)
    xPlayer.setAccountMoney('bank', 0)

    MySQL.insert('INSERT INTO community_service_items (identifier, items, weapons, money, black_money, bank) VALUES (?, ?, ?, ?, ?, ?)',
        {xPlayer.identifier, json.encode(items), json.encode(weapons), money, blackMoney, bank})
end

local function restorePlayerItems(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    local result = MySQL.single.await('SELECT * FROM community_service_items WHERE identifier = ?', {xPlayer.identifier})
    if result then
        local items = json.decode(result.items)
        for _, item in ipairs(items) do
            xPlayer.addInventoryItem(item.name, item.count)
        end

        local weapons = json.decode(result.weapons)
        for _, weapon in ipairs(weapons) do
            xPlayer.addWeapon(weapon.name, weapon.ammo)
            for _, component in ipairs(weapon.components) do
                xPlayer.addWeaponComponent(weapon.name, component)
            end
        end

        xPlayer.addMoney(result.money)
        xPlayer.addAccountMoney('black_money', result.black_money)
        xPlayer.setAccountMoney('bank', result.bank)

        MySQL.query('DELETE FROM community_service_items WHERE identifier = ?', {xPlayer.identifier})
    end
end

RegisterNetEvent('tj_communityservice:completeAction')
AddEventHandler('tj_communityservice:completeAction', function(receivedToken)
    local source = source
    if not activePlayers[source] then return end

    if actionCooldown[source] and os.time() - actionCooldown[source] < 7 then
        print(("[WARNING] Player %s tried to spam the action"):format(GetPlayerName(source)))
        return
    end
    actionCooldown[source] = os.time()

    activePlayers[source].remaining = activePlayers[source].remaining - 1
    
    if activePlayers[source].remaining <= 0 then
        restorePlayerItems(source)
        activePlayers[source] = nil
        TriggerClientEvent('tj_communityservice:finishService', source)
        MySQL.query('DELETE FROM community_service_active WHERE identifier = ?', {ESX.GetPlayerFromId(source).identifier})
        SendToDiscord('communityservice', 'Community Service End', '**Igrac**: ```' .. GetPlayerName(source) .. '```', 16711680, false)
    else
        MySQL.query('UPDATE community_service_active SET actions_remaining = ? WHERE identifier = ?',
            {activePlayers[source].remaining, ESX.GetPlayerFromId(source).identifier})
        TriggerClientEvent('tj_communityservice:updateActions', source, activePlayers[source].remaining)
    end
end)

RegisterNetEvent('tj_communityservice:sendToService')
AddEventHandler('tj_communityservice:sendToService', function(targetId, actions, reason)
    local src = source
    if not isAuthorized(src) then
        lib.notify(src, {
            title = 'Error',
            description = locale('no_perm'),
            type = 'error'
        })
        return
    end

    if not reason or reason == '' then
        TriggerClientEvent('esx:showNotification', src, locale('need_resaon'))
        return
    end

    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    
    activePlayers[targetId] = {
        actions = actions,
        remaining = actions,
        reason = reason
    }

    SendToDiscord('communityservice', 'Community Service Send', '**Admin**: ```' .. GetPlayerName(source) .. '```\n**Player**: ```'.. GetPlayerName(targetId) .. '```\n**Actions**: ```'.. actions ..  '```\n**Reason**: ```'.. reason .. '```', 16711680, false)    
    AddServiceRecord(xTarget.identifier, xPlayer.identifier, actions, reason)
    storePlayerItems(targetId)
    TriggerClientEvent('tj_communityservice:inService', targetId, actions)
end)

lib.callback.register('tj_communityservice:getActivePlayers', function(source)
    if not isAuthorized(source) then return {} end

    local players = {}
    for playerId, data in pairs(activePlayers) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            table.insert(players, {
                id = playerId,
                name = xPlayer.getName(),
                remaining = data.remaining,
                total = data.actions,
                reason = data.reason
            })
        end
    end
    return players
end)

RegisterNetEvent('tj_communityservice:removeFromService')
AddEventHandler('tj_communityservice:removeFromService', function(targetId)
    local source = source
    if not isAuthorized(source) then return end

    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return end

    if activePlayers[targetId] then
        restorePlayerItems(targetId)
        activePlayers[targetId] = nil
        TriggerClientEvent('tj_communityservice:finishService', targetId)
        SendToDiscord('communityservice', 'Community Service End', '**Admin**: ```' .. GetPlayerName(source) .. '```\n**Player**: ```'.. GetPlayerName(targetId) .. '```', 16711680, false)
        MySQL.query('DELETE FROM community_service_active WHERE identifier = ?', {xTarget.identifier})
    end
end)

CreateThread(function()
    while true do
        Wait(Config.HealInterval * 60 * 1000)
        for playerId, _ in pairs(activePlayers) do
            TriggerClientEvent('tj_communityservice:heal', playerId)
        end
    end
end)

RegisterNetEvent('tj_communityservice:addMarkers')
AddEventHandler('tj_communityservice:addMarkers', function(targetId, markerCount)
    local source = source
    if not isAuthorized(source) then
        return
    end

    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return end

    if not activePlayers[targetId] then
        lib.notify(source, {
            title = 'Error',
            description = locale('no_com_service'),
            type = 'error'
        })
        return
    end

    activePlayers[targetId].remaining = activePlayers[targetId].remaining + markerCount
    activePlayers[targetId].actions = activePlayers[targetId].actions + markerCount

    MySQL.query('UPDATE community_service_active SET actions_remaining = actions_remaining + ?, total_actions = total_actions + ? WHERE identifier = ?',
        {markerCount, markerCount, xTarget.identifier})

    TriggerClientEvent('tj_communityservice:updateActions', targetId, activePlayers[targetId].remaining)
    SendToDiscord('communityservice', 'Community Service Add', '**Admin**: ```' .. GetPlayerName(source) .. '```\n**Player**: ```'.. GetPlayerName(targetId) .. '```\n**Actions**: ```'.. markerCount .. '```', 16711680, false)    

    lib.notify(source, {
        title = 'Success',
        description = string.format(locale('added_markers_to'), markerCount, xTarget.getName()),
        type = 'success'
    })
end)

RegisterNetEvent('tj_communityservice:removeMarkers')
AddEventHandler('tj_communityservice:removeMarkers', function(targetId, markerCount)
    local source = source
    if not isAuthorized(source) then
        lib.notify(source, {
            title = 'Error',
            description = locale('no_perm'),
            type = 'error'
        })
        return
    end

    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return end

    if not activePlayers[targetId] then
        return
    end

    local newRemainingActions = math.max(0, activePlayers[targetId].remaining - markerCount)
    local removedMarkers = activePlayers[targetId].remaining - newRemainingActions

    activePlayers[targetId].remaining = newRemainingActions

    MySQL.query('UPDATE community_service_active SET actions_remaining = ? WHERE identifier = ?',
        {newRemainingActions, xTarget.identifier})

    if newRemainingActions <= 0 then
        restorePlayerItems(targetId)
        activePlayers[targetId] = nil
        lib.notify(source, {
            title = 'Success',
            description = string.format(locale('removed_markers_from'), removedMarkers, xTarget.getName()),
            type = 'success'
        })
        TriggerClientEvent('tj_communityservice:finishService', targetId)
        MySQL.query('DELETE FROM community_service_active WHERE identifier = ?', {xTarget.identifier})
    else
        TriggerClientEvent('tj_communityservice:updateActions', targetId, newRemainingActions)
        SendToDiscord('communityservice', 'Community Service Remove', '**Admin**: ```' .. GetPlayerName(source) .. '```\n**Player**: ```'.. GetPlayerName(targetId) .. '```\n**Actions**: ```'.. removedMarkers .. '```', 16711680, false)
    end
end)


ESX.RegisterServerCallback("community_service:checkAdmin", function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local playerRank = xPlayer.getGroup()

    cb(playerRank)
end)

ESX.RegisterServerCallback('community_service:checkJobAccess', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if Config.JobRolesAccess[xPlayer.job.name] then
        cb(true)
    else
        cb(false)
    end
end)

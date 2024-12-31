ESX = exports['es_extended']:getSharedObject()
lib.locale()
local isInService = false
local currentActions = 0
local activeProps = {}
local maxProps = Config.MaxProps


local function DisableCombat()
    DisablePlayerFiring(PlayerId(), true)
    DisableControlAction(0, 24, true) -- Attack
    DisableControlAction(0, 25, true) -- Aim
    DisableControlAction(0, 47, true) -- Weapon
    DisableControlAction(0, 58, true) -- Weapon
    DisableControlAction(0, 140, true) -- Melee Attack 1
    DisableControlAction(0, 141, true) -- Melee Attack 2
    DisableControlAction(0, 142, true) -- Melee Attack 3
    DisableControlAction(0, 143, true) -- Melee Attack 4
    DisableControlAction(0, 263, true) -- Melee Attack 1
    DisableControlAction(0, 264, true) -- Melee Attack 2
    DisableControlAction(0, 257, true) -- Attack 2
end

local function SpawnProps()
    while #activeProps < maxProps do
        local offset = vector3(math.random(-10, 10), math.random(-10, 10), 0)
        local coords = Config.ServiceLocation + offset
        
        local model = Config.Props[math.random(#Config.Props)]
        lib.requestModel(model)
        
        local prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
        PlaceObjectOnGroundProperly(prop)
        FreezeEntityPosition(prop, true)

        exports.ox_target:addLocalEntity(prop, {
            {
                name = 'clean_trash',
                label = locale('clean_trash'),
                icon = 'fas fa-broom',
                onSelect = function()
                    lib.progressCircle({
                        duration = 5000,
                        label = locale('cleaning_trash'),
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = false,
                        disable = {
                            car = true,
                            move = true,
                            combat = true
                        },
                        anim = {
                            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                            clip = 'machinic_loop_mechandplayer'
                        }
                    })
                    
                    DeleteEntity(prop)
                    for k, v in pairs(activeProps) do
                        if v == prop then
                            table.remove(activeProps, k)
                            break
                        end
                    end
                    TriggerServerEvent('tj_communityservice:completeAction')
                    SpawnProps()
                end
            }
        })
        
        table.insert(activeProps, prop)
    end
end

local function ShowRemainingActions()
    if not isInService then return end
    
    local text = string.format(locale('remairing_actions'), currentActions)
    lib.showTextUI(text, {
        position = 'right-center',
        icon = 'broom',
        style = {
            backgroundColor = 'rgba(0, 0, 0, 0.7)',
            color = 'white'
        }
    })
end

RegisterNetEvent('tj_communityservice:inService')
AddEventHandler('tj_communityservice:inService', function(actions)
    isInService = true
    currentActions = actions
    
    SetEntityCoords(PlayerPedId(), Config.ServiceLocation.x, Config.ServiceLocation.y, Config.ServiceLocation.z)
    
    SpawnProps()
    ShowRemainingActions()
    
    CreateThread(function()
        while isInService do
            Wait(0)
            DisableCombat()
            
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - Config.ServiceLocation)
            
            if distance > Config.MaxDistance then
                SetEntityCoords(PlayerPedId(), Config.ServiceLocation.x, Config.ServiceLocation.y, Config.ServiceLocation.z)
            end
            
            ShowRemainingActions()
        end
    end)
end)

RegisterNetEvent('tj_communityservice:updateActions')
AddEventHandler('tj_communityservice:updateActions', function(actions)
    currentActions = actions
    ShowRemainingActions()
end)

RegisterNetEvent('tj_communityservice:finishService')
AddEventHandler('tj_communityservice:finishService', function()
    isInService = false
    currentActions = 0
    
    lib.hideTextUI()
    
    for _, prop in pairs(activeProps) do
        DeleteEntity(prop)
    end
    
    ESX.ShowNotification(locale('finished'))
    Wait(500)
    activeProps = {}
    SetEntityCoords(PlayerPedId(), Config.EndServiceLocation.x, Config.EndServiceLocation.y, Config.EndServiceLocation.z)
end)

RegisterNetEvent('tj_communityservice:heal')
AddEventHandler('tj_communityservice:heal', function()
    SetEntityHealth(PlayerPedId(), GetEntityMaxHealth(PlayerPedId()))
end)

RegisterCommand(Config.Commands.communityservice, function()
ESX.TriggerServerCallback("community_service:checkAdmin", function(playerRank)
        if Config.AuthorizedGroups[playerRank] then
        lib.showContext('community_service_menu')
    else
        return ESX.ShowNotification(locale('no_perm'))
    end 
end)
end)

lib.registerContext({
    id = 'community_service_menu',
    title = locale('send_player'),
    options = {
        {
            title = locale('send_player'),
            description = locale('comm_service_count'),
            onSelect = function()
                local input = lib.inputDialog(locale('send_player'), {
                    {type = 'number', label = locale('player_id'), description = locale('player_id_desc'), required = true},
                    {type = 'number', label = locale('actions'), description = locale('actions_desc'), required = true, min = 1},
                    {type = 'input', label = locale('reason'), description = locale('reason_desc'), required = true}
                })
                
                if input then
                    TriggerServerEvent('tj_communityservice:sendToService', input[1], input[2], input[3])
                end
            end
        },
        {
            title = locale('active_player_wiew'),
            description = locale('active_player_desc'),
            onSelect = function()
                local players = lib.callback.await('tj_communityservice:getActivePlayers')
                local options = {}
                
                for _, player in ipairs(players) do
                    table.insert(options, {
                        title = player.name,
                        description = string.format(locale('remaining_resaon'), player.remaining, player.total, player.reason),
                        onSelect = function()
                            lib.registerContext({
                                id = 'player_actions_menu',
                                title = string.format(locale('actions_for'), player.name),
                                menu = 'active_players_menu',
                                options = {
                                    {
                                        title = locale('remove_service'),
                                        description = locale('remove_service_desc'),
                                        onSelect = function()
                                            TriggerServerEvent('tj_communityservice:removeFromService', player.id)
                                            lib.showContext('community_service_menu')
                                        end
                                    },
                                    {
                                        title = locale('edit_actions'),
                                        description = locale('edit_actions_desc'),
                                        onSelect = function()
                                            lib.registerContext({
                                                id = 'edit_actions_menu',
                                                title = locale('edit_actions'),
                                                menu = 'player_actions_menu',
                                                options = {
                                                    {
                                                        title = locale('add_actions'),
                                                        description = locale('add_actions_desc'),
                                                        onSelect = function()
                                                            local input = lib.inputDialog(locale('add_actions'), {
                                                                {type = 'number', label = locale('number_actions'), description = locale('number_add_description'), required = true, min = 1}
                                                            })
                                                            
                                                            if input then
                                                                TriggerServerEvent('tj_communityservice:addMarkers', player.id, input[1])
                                                                lib.showContext('community_service_menu')
                                                            end
                                                        end
                                                    },
                                                    {
                                                        title = locale('remove_actions'),
                                                        description = locale('remove_actions_desc'),
                                                        onSelect = function()
                                                            local input = lib.inputDialog(locale('remove_actions'), {
                                                                {type = 'number', label = locale('number_actions'), description = locale('number_remove_description'), required = true, min = 1}
                                                            })
                                                            
                                                            if input then
                                                                TriggerServerEvent('tj_communityservice:removeMarkers', player.id, input[1])
                                                                lib.showContext('community_service_menu')
                                                            end
                                                        end
                                                    }
                                                }
                                            })
                                            lib.showContext('edit_actions_menu')
                                        end
                                    }
                                }
                            })
                            lib.showContext('player_actions_menu')
                        end
                    })
                end
                
                lib.registerContext({
                    id = 'active_players_menu',
                    title = locale('active_players'),
                    menu = 'community_service_menu',
                    options = options
                })
                
                lib.showContext('active_players_menu')
            end
        }
    }
})

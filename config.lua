Config = {}

-- Groups that can access the /communityservice command
Config.AuthorizedGroups = {
    ["osnivac"] = true,
    ["developer"] = true,
}

Config.Commands = {
    communityservice = 'communityservice',
}

-- Community service location
Config.ServiceLocation = vector3(3054.2637, -4694.6846, 14.2614)

-- Coordinates where to teleport player when he finished service
Config.EndServiceLocation = vector3(427.2343, -979.8491, 30.7100)

-- Maximum distance player can move from service location
Config.MaxDistance = 30.0

-- How many props will there be at once
Config.MaxProps = 5

-- Prop models for cleaning
Config.Props = {
    'prop_rub_binbag_sd_01',
}

-- Time between automatic healing (in minutes)
Config.HealInterval = 5
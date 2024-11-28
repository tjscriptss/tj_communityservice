CREATE TABLE IF NOT EXISTS `community_service_active` (
    `identifier` varchar(60) NOT NULL,
    `actions_remaining` int NOT NULL,
    `total_actions` int NOT NULL,
    `history_id` int NOT NULL,
    `reason` varchar(255) NOT NULL DEFAULT 'No reason provided',
    PRIMARY KEY (`identifier`)
);

CREATE TABLE IF NOT EXISTS `community_service_history` (
    `id` int NOT NULL AUTO_INCREMENT,
    `identifier` varchar(60) NOT NULL,
    `admin_identifier` varchar(60) NOT NULL,
    `actions_given` int NOT NULL,
    `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `reason` varchar(255) NOT NULL DEFAULT 'No reason provided',
    PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `community_service_items` (
    `identifier` varchar(60) NOT NULL,
    `items` longtext NOT NULL,
    `weapons` longtext NOT NULL,
    `money` int NOT NULL DEFAULT 0,
    `black_money` int NOT NULL DEFAULT 0,
    `bank` int NOT NULL DEFAULT 0,
    PRIMARY KEY (`identifier`)
);
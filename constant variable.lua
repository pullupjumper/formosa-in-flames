-- China variables -------------------------------------------------------------------------
LAND_STRIKE = {}
LAND_STRIKE.IS_LAND_STRIKE_STARTED = false
LAND_STRIKE.LAND_STRIKE_TIMES = 5
LAND_STRIKE.LAST_LAND_STRIKE_TIME = nil
LAND_STRIKE.PERIOD_OF_LAND_STRIKE = 70 * 60
LAND_STRIKE.STRIKE_PACKAGE = {
    {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H5P44', weaponDBID = 2876, num = 12, units = {} },
        escort = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F', weaponDBID = 3413, num = 6, units = {} },
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 6, units = {} },
        seadMissionName = 'SEAD - SOUTH',
        missionName = 'LAND STRIKE - SOUTH',
        area = { 'RP-8016', 'RP-8017', 'RP-8018', 'RP-8019' },
        hasLaunched = false
    },
    {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H5P44', weaponDBID = 2876, num = 12, units = {} },
        escort = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F', weaponDBID = 3413, num = 6, units = {} },
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 6, units = {} },
        seadMissionName = 'SEAD - MIDDLE',
        missionName = 'LAND STRIKE - MIDDLE',
        area = { 'RP-8008', 'RP-8009', 'RP-8010', 'RP-8011' },
        hasLaunched = false
    },
    {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H7VDF', weaponDBID = 2107, num = 12, units = {} },
        escort = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F', weaponDBID = 3413, num = 6, units = {} },
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 6, units = {} },
        seadMissionName = 'SEAD - NORTH',
        missionName = 'LAND STRIKE - NORTH',
        area = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' },
        hasLaunched = false
    },
    {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H7VDF', weaponDBID = 2107, num = 12, units = {} },
        escort = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F', weaponDBID = 3413, num = 6, units = {} },
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 6, units = {} },
        seadMissionName = 'SEAD - NORTH',
        missionName = 'LAND STRIKE - NORTH - 2',
        area = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' },
        hasLaunched = false
    },
}


-- Amphibious landing operation
LANDING_OPERATION = {}
LANDING_OPERATION.IS_LANDING_SHIPS_STARTED_MOVING = true
LANDING_OPERATION.IS_LANDING_SHIPS_ARRIVED = false
LANDING_OPERATION.IS_AMPHIBIOUS_LANDING_ATTACK_LAUNCHED = false
LANDING_OPERATION.AIRLANDING_MISSION_STARTTIME = nil
LANDING_OPERATION.AIR_LANDING_AREA = { 'RP-3819', 'RP-3820', 'RP-3821', 'RP-3822' }
LANDING_OPERATION.HAS_LANDING_MISSION_ACTIVATED = false
LANDING_OPERATION.CONTACT_NUM_IN_AIRLANDING_AREA = 3
LANDING_OPERATION.CARGOLIST = {
    type075 = { { type = 2, num = 60, dbid = 3 }, { type = 3, num = 200, dbid = 2039 } },
    type071 = { { type = 2, num = 20, dbid = 3 }, { type = 3, num = 30, dbid = 2039 } },
    type072iii = { { type = 2, num = 10, dbid = 3 }, { type = 3, num = 6, dbid = 2039 } },
    type072a = { { type = 2, num = 10, dbid = 3 }, { type = 3, num = 6, dbid = 2039 } },
    type073a = { { type = 2, num = 6, dbid = 3 } }
}
LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_1 = { type = 2, num = 2, dbid = 3 }    -- 075/071 726a
LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_2 = { type = 3, num = 2, dbid = 2039 } -- 075/071 Z-18
PLATFORM_DBID_1 = 2149                                                          -- 726a
PLATFORM_DBID_2 = 3708                                                          -- Z-18
PLATFORM_DBID_3 = 2511                                                          -- 724
PLATFORM_DBID_4 = 2930                                                          -- Ka-52k
PLATFORM_DBID_5 = 5856                                                          -- Z-10
PLATFORM_DBID_6 = 3153                                                          -- 075
PLATFORM_DBID_7 = 2006                                                          -- 071
PLATFORM_DBID_8 = 735                                                           -- 072III
PLATFORM_DBID_9 = 1823                                                          -- 072A
PLATFORM_DBID_10 = 2925                                                         -- 073A
PLATFORM_DBID_11 = 3187                                                         -- 002
PLATFORM_DBID_12 = 6642                                                         -- WZ-8
PLATFORM_DBID_13 = 3309                                                         -- BZK-005
PLATFORM_DBID_14 = 123                                                          -- customed sky bow 3
PLATFORM_DBID_15 = 2227                                                         -- pac-3

LOADOUT_DBID_1 = 30568                                                          -- ka-52
LOADOUT_DBID_2 = 31490                                                          -- z-10
LOADOUT_DBID_3 = 18367                                                          -- z-18

LANDING_OPERATION.SHIP_INFO = {
    distanceBetweenLSTAndLPDArea = 13,
    horizontalDistance = 1,
    verticalDistance = 0.5,
    transitDistance = 13,
    shipSpeed = 14,
    heading = {
        north = {
            horizontal = 220 - 90,
            vertical   = 220,
        },
        west = {
            horizontal = 150 - 90,
            vertical = 150,
        },
        south = {
            horizontal = 135 - 90,
            vertical = 135,
        }
    },
    amphibiousVehicleSpeed = 12,
    amphibiousVehicleTransitDistance = 5,
    amphibiousVehicleHorizontalDistance = 0.05,
}
LANDING_OPERATION.IDX_SHIP_LOCATION_INFO = 1
LANDING_OPERATION.SHIP_LOCATION_INFO = {
    {
        name = 'north',
        from = {
            areas = { {
                startingPoints = { type075 = { side = "China", area = { 'RP-11169' } } },
                heading = LANDING_OPERATION.SHIP_INFO.heading.north
            } }
        },
        to = {
            areas = {
                {
                    startingPoints = {
                        type075 = { side = "China", area = { 'RP-4322' } },
                        type071 = { side = "China", area = { 'RP-3915' } },
                    },
                    heading = LANDING_OPERATION.SHIP_INFO.heading.west,
                    num = {
                        type075 = 4,
                        type071 = 2,
                        type072iii = 4,
                        type072a = 4,
                        type073a = 4,
                        type071InLSTArea = 2,
                    }
                },
                {
                    startingPoints = {
                        type075 = { side = "China", area = { 'RP-7827' } },
                        type071 = { side = "China", area = { 'RP-3916' } },
                    },
                    heading = LANDING_OPERATION.SHIP_INFO.heading.west,
                    num = {
                        type075 = 1,
                        type071 = 1,
                        type072iii = 2,
                        type072a = 2,
                        type073a = 2,
                        type071InLSTArea = 1,
                    }
                },
                {
                    startingPoints = {
                        type075 = { side = "China", area = { 'RP-4323' } },
                        type071 = { side = "China", area = { 'RP-3917' } },
                    },
                    heading = LANDING_OPERATION.SHIP_INFO.heading.west,
                    num = {
                        type075 = 2,
                        type071 = 2,
                        type072iii = 3,
                        type072a = 3,
                        type073a = 3,
                        type071InLSTArea = 2,
                    }
                },
                {
                    startingPoints = {
                        type075 = { side = "China", area = { 'RP-4326' } },
                        type071 = { side = "China", area = { 'RP-3953' } },
                    },
                    heading = LANDING_OPERATION.SHIP_INFO.heading.north,
                    num = {
                        type075 = 2,
                        type071 = 2,
                        type072iii = 3,
                        type072a = 3,
                        type073a = 3,
                        type071InLSTArea = 1,
                    }
                },
            },
            result = {
                type075 = { locations = {}, locationIndex = 1, dbid = PLATFORM_DBID_6, },
                type071 = { locations = {}, locationIndex = 1, dbid = PLATFORM_DBID_7, },
                type072iii = { locations = {}, locationIndex = 1, dbid = PLATFORM_DBID_8, },
                type072a = { locations = {}, locationIndex = 1, dbid = PLATFORM_DBID_9, },
                type073a = { locations = {}, locationIndex = 1, dbid = PLATFORM_DBID_10, },
                type071InLSTArea = { locations = {}, locationIndex = 1, dbid = PLATFORM_DBID_7, }
            }
        },
        airLandingZone = { 'RP-3819', 'RP-3820', 'RP-3821', 'RP-3822' },
        numOfContactsInAirLandingZone = 3
    },
}

LANDING_OPERATION.CARGO_INFO_FOR_TRANSFER = {
    {
        anchorageArea = { 'RP-9684', 'RP-9685', 'RP-9686', 'RP-9687' },
        LSTAnchorageArea = { 'RP-9712', 'RP-9713', 'RP-9714', 'RP-9715' },
        boat = { dbid = PLATFORM_DBID_1, missions = { 'LANDING ZONE' }, cargoList = LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_1 },
        tansportHelicopter = {
            dbid = PLATFORM_DBID_2,
            missions = { 'AIRLANDING ZONE', 'AIRLANDING ZONE 2', 'AIRLANDING ZONE 3' },
            cargoList = LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_2
        },
        attackHelicopter1 = { dbid = PLATFORM_DBID_4, missions = { 'CAS EAST 1' } },
        attackHelicopter2 = { dbid = PLATFORM_DBID_5, missions = { 'CAS EAST 1' } },
    },
    {
        anchorageArea = { 'RP-9957', 'RP-9958', 'RP-9959', 'RP-9960' },
        LSTAnchorageArea = { 'RP-9965', 'RP-9966', 'RP-9967', 'RP-9968' },
        boat = { dbid = PLATFORM_DBID_1, missions = { 'LANDING ZONE ZHUWEI' }, cargoList = LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_1 },
        tansportHelicopter = {
            dbid = PLATFORM_DBID_2,
            missions = { 'AIRLANDING ZONE TAIPING 1', 'AIRLANDING ZONE TAIPING 2', 'AIRLANDING ZONE TAIPING 3' },
            cargoList = LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_2
        },
        attackHelicopter1 = { dbid = PLATFORM_DBID_4, missions = { 'CAS EAST 1' } },
        attackHelicopter2 = { dbid = PLATFORM_DBID_5, missions = { 'CAS EAST 1' } },
    },
    {
        anchorageArea = { 'RP-9969', 'RP-9970', 'RP-9971', 'RP-9972' },
        LSTAnchorageArea = { 'RP-9977', 'RP-9978', 'RP-9979', 'RP-9980' },
        boat = { dbid = PLATFORM_DBID_1, missions = { 'LANDING ZONE BAO' }, cargoList = LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_1 },
        tansportHelicopter = {
            dbid = PLATFORM_DBID_2,
            missions = { 'AIRLANDING ZONE PARK 1', 'AIRLANDING ZONE PARK 2', 'AIRLANDING ZONE PARK 3' },
            cargoList = LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_2
        },
        attackHelicopter1 = { dbid = PLATFORM_DBID_4, missions = { 'CAS EAST 2' } },
        attackHelicopter2 = { dbid = PLATFORM_DBID_5, missions = { 'CAS EAST 2' } },
    },
    {
        anchorageArea = { 'RP-9981', 'RP-9982', 'RP-9983', 'RP-9984' },
        LSTAnchorageArea = { 'RP-9989', 'RP-9990', 'RP-9991', 'RP-9992' },
        boat = { dbid = PLATFORM_DBID_1, missions = { 'LANDING ZONE NORTH WAY' }, cargoList = LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_1 },
        tansportHelicopter = {
            dbid = PLATFORM_DBID_2,
            missions = { 'AIRLANDING ZONE NORTH', 'AIRLANDING ZONE NORTH 2', 'AIRLANDING ZONE NORTH 3' },
            cargoList = LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_2
        },
        attackHelicopter1 = { dbid = PLATFORM_DBID_4, missions = { 'CAS NORTH' } },
        attackHelicopter2 = { dbid = PLATFORM_DBID_5, missions = { 'CAS NORTH' } },
    },
    {
        anchorageArea = { 'RP-14290', 'RP-14291', 'RP-14292', 'RP-14293' },
        LSTAnchorageArea = { 'RP-14286', 'RP-14287', 'RP-14288', 'RP-14289' },
        boat = { dbid = PLATFORM_DBID_1, missions = { 'LANDING ZONE JIALUTANG' }, cargoList = LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_1 },
        tansportHelicopter = {
            dbid = PLATFORM_DBID_2,
            missions = { 'AIRLANDING ZONE CHANGLONG', 'AIRLANDING ZONE CHANGLONG 2', 'AIRLANDING ZONE CHANGLONG 3' },
            cargoList = LANDING_OPERATION.CARGOLIST_FOR_TRANSFER_2
        },
        attackHelicopter1 = { dbid = PLATFORM_DBID_4, missions = { 'CAS SOUTH' } },
        attackHelicopter2 = { dbid = PLATFORM_DBID_5, missions = { 'CAS SOUTH' } },
    },
}
LANDING_OPERATION.CARGO_MISSION_LIST = {
    {
        name = 'AIRLANDING ZONE',
        zone = { 'RP-3819', 'RP-3820', 'RP-3821', 'RP-3822' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE 2',
        zone = { 'RP-3819', 'RP-3820', 'RP-3821', 'RP-3822' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE 3',
        zone = { 'RP-3819', 'RP-3820', 'RP-3821', 'RP-3822' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE CHANGLONG',
        zone = { 'RP-11165', 'RP-11166', 'RP-11167', 'RP-11168' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE CHANGLONG 2',
        zone = { 'RP-11165', 'RP-11166', 'RP-11167', 'RP-11168' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE CHANGLONG 3',
        zone = { 'RP-11165', 'RP-11166', 'RP-11167', 'RP-11168' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE NORTH',
        zone = { 'RP-3815', 'RP-3816', 'RP-3817', 'RP-3818' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE NORTH 2',
        zone = { 'RP-3815', 'RP-3816', 'RP-3817', 'RP-3818' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE NORTH 3',
        zone = { 'RP-3815', 'RP-3816', 'RP-3817', 'RP-3818' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE PARK 1',
        zone = { 'RP-7718', 'RP-7719', 'RP-7720', 'RP-7721' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE PARK 2',
        zone = { 'RP-7718', 'RP-7719', 'RP-7720', 'RP-7721' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE PARK 3',
        zone = { 'RP-7718', 'RP-7719', 'RP-7720', 'RP-7721' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE TAIPING 1',
        zone = { 'RP-7714', 'RP-7715', 'RP-7716', 'RP-7717' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE TAIPING 2',
        zone = { 'RP-7714', 'RP-7715', 'RP-7716', 'RP-7717' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'AIRLANDING ZONE TAIPING 3',
        zone = { 'RP-7714', 'RP-7715', 'RP-7716', 'RP-7717' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleAircraft = 'Military',
            TransitAltitudeAircraft = 304,
            StationThrottleAircraft = 'Afterburner',
            StationAltitudeAircraft = 304,
        },
    },
    {
        name = 'LANDING ZONE',
        zone = { 'RP-7702', 'RP-7703', 'RP-7704', 'RP-7705' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleShip = 'Flank',
            StationThrottleShip = 'Flank',
        },
    },
    {
        name = 'LANDING ZONE BAO',
        zone = { 'RP-3742', 'RP-3743', 'RP-3744', 'RP-3745' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleShip = 'Flank',
            StationThrottleShip = 'Flank',
        },
    },
    {
        name = 'LANDING ZONE JIALUTANG',
        zone = { 'RP-11154', 'RP-11155', 'RP-11156', 'RP-11157' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleShip = 'Flank',
            StationThrottleShip = 'Flank',
        },
    },
    {
        name = 'LANDING ZONE NORTH LEO',
        zone = { 'RP-3749', 'RP-3750', 'RP-3751', 'RP-3752' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleShip = 'Flank',
            StationThrottleShip = 'Flank',
        },
    },
    {
        name = 'LANDING ZONE NORTH WAY',
        zone = { 'RP-7706', 'RP-7707', 'RP-7708', 'RP-7709' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleShip = 'Flank',
            StationThrottleShip = 'Flank',
        },
    },
    {
        name = 'LANDING ZONE ZHUWEI',
        zone = { 'RP-7698', 'RP-7699', 'RP-7700', 'RP-7701' },
        setting = {
            Subtype = 'delivery',
            TransitThrottleShip = 'Flank',
            StationThrottleShip = 'Flank',
        },
    },
}

-- ASW
IS_ASW_STARTED = true


-- Strike on SAMs
STRIKE_ON_SAM = {}
STRIKE_ON_SAM.IS_STRIKE_ON_SAM_ACTIVATED = false
STRIKE_ON_SAM.SKY_BOW_III_SENSOR_DBID_1 = 6366
STRIKE_ON_SAM.SKY_BOW_III_SENSOR_DBID_2 = 282
STRIKE_ON_SAM.SKY_BOW_II_SENSOR_DBID_1 = 919
STRIKE_ON_SAM.PAC_3_SENSOR_DBID = 2498
STRIKE_ON_SAM.H6N_BASE_GUID = 'X58F5H-0HMRAQFR07T2V'
STRIKE_ON_SAM.BZK005_BASE_GUID = '6Z8LM5-0HMIJ3QGCRQC4'
STRIKE_ON_SAM.H6N_DBID = 4969
STRIKE_ON_SAM.SRBM_BATTERIES = {
    { name = 'SRBM (613th Brigade)', guid = '6Z8LM5-0HMML05RV29L0' },
}
STRIKE_ON_SAM.CONTACT_AGE = 60
STRIKE_ON_SAM.WZ8_COURSE = {
    { lat = 'N 25.44.14', lon = 'E 121.36.00', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 24.41.37', lon = 'E 121.34.30', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 24.05.04', lon = 'E 121.22.33', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 22.52.27', lon = 'E 121.06.41', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 22.31.53', lon = 'E 120.29.25', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 24.16.15', lon = 'E 120.29.30', desiredAltitude = 30480, desiredSpeed = 3300 },
}
STRIKE_ON_SAM.H6N_COURSE = {
    { lat = 'N 29.47.52', lon = 'E 119.19.47', desiredAltitude = 13716, desiredSpeed = 450 },
    { lat = 'N 25.57.34', lon = 'E 121.32.45', desiredAltitude = 13716, desiredSpeed = 550 },
}
STRIKE_ON_SAM.RECON_WZ8 = {}
STRIKE_ON_SAM.H6N_WITH_WZ8 = {}

-- Strike on mobile targets
MLRS_ON_MOBILE_TARGETS = {}
MLRS_ON_MOBILE_TARGETS.IS_STRIKE_ACTIVATED = false
MLRS_ON_MOBILE_TARGETS.IDX_STRIKE_PACKAGE = 1
MLRS_ON_MOBILE_TARGETS.CONTACT_AGE = 30 * 60
MLRS_ON_MOBILE_TARGETS.WEAPON_DBID = 2123
MLRS_ON_MOBILE_TARGETS.STRIKE_PACKAGE = {
    {
        name = '',
        targetList = {},
        batteries = {
            { name = 'MLRS (73th Artillery Brigade 5th Battalion)', guid = 'X58F5H-0HN0VUJ61V0OE' }
        },
        area = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' }
    }
}



-- Strike on facility
STRIKE_ON_FACILITY = {}
STRIKE_ON_FACILITY.LAST_RECON_TIME = nil
STRIKE_ON_FACILITY.SRBM_LAUNCHER_STATE = {}
STRIKE_ON_FACILITY.SRBM_MAGAZINE_WEAPON_NUM = 3
STRIKE_ON_FACILITY.SRBM_RELOADING_TIME = 45 * 60
STRIKE_ON_FACILITY.SRBM_STRIKE_TIMES = 0
STRIKE_ON_FACILITY.IS_SRBM_RELOADING_ACTIVATED = false
STRIKE_ON_FACILITY.IS_STRIKE_ON_FACILITY_ACTIVATED = false
STRIKE_ON_FACILITY.IDX_SRBM_STRIKE_PACKAGE = 1
STRIKE_ON_FACILITY.FACILITY_CONTACT_AGE = 30 * 60
STRIKE_ON_FACILITY.SRBM_STRIKE_PACKAGE = {
    {
        name = 'RADAR',
        targetList = {},
        batteries = {
            { name = 'SRBM (614th Brigade)', guid = 'X58F5H-0HMSC3K2NOVJC' },
            { name = 'SRBM (613th Brigade)', guid = '6Z8LM5-0HMML05RV29L0' },
        },
        num = 2,
        index = 1,
        hasLaunchedTheFirstStrike = false
    },
    {
        name = 'RUNWAY',
        targetList = {},
        batteries = {
            { name = 'SRBM (636th Brigade)', guid = '6Z8LM5-0HMML05RV0N6N' },
            { name = 'SRBM (617th Brigade)', guid = '6Z8LM5-0HMML05RV30CS' },
        },
        num = 4,
        index = 1,
        hasLaunchedTheFirstStrike = false
    },
    {
        name = 'PORT',
        targetList = {},
        batteries = {
            { name = 'SRBM (613th Brigade)', guid = '6Z8LM5-0HMML05RV29L0' },
            { name = 'SRBM (615th Brigade)', guid = '6Z8LM5-0HMML05RUJ786' },
        },
        num = 4,
        index = 1,
        hasLaunchedTheFirstStrike = false
    },
    {
        name = 'SHELTER',
        targetList = {},
        batteries = {
            { name = 'SRBM (616th Brigade)', guid = 'X58F5H-0HMTNEA68REQQ' },
        },
        num = 2,
        index = 1,
        hasLaunchedTheFirstStrike = false
    },
}

SAG_OBJECT = {
    {
        guid = 'X58F5H-0HMT6MQJ08KJR',
        course = {
            { lat = 'N 25.16.39', lon = 'E 120.52.56', desiredSpeed = 14, },
            { lat = 'N 25.15.03', lon = 'E 120.55.14', desiredSpeed = 14, },
        }
    },
    {
        guid = 'X58F5H-0HMVL9T14L3J4',
        course = {
            { lat = 'N 25.32.37', lon = 'E 121.18.44', desiredSpeed = 14, },
            { lat = 'N 25.30.26', lon = 'E 121.21.04', desiredSpeed = 14, },
        }
    },
}
SUB_OBJECT = {
    {
        guid = 'X58F5H-0HMVKL9MNVV3K',
        course = {
            { lat = 'N 25.07.11', lon = 'E 122.12.20', },
            { lat = 'N 25.07.57', lon = 'E 122.46.06', },
            { lat = 'N 24.33.33', lon = 'E 122.05.57', },
            { lat = 'N 24.30.54', lon = 'E 122.48.02', },
        },
        side = 'China',
        missionName = 'ASW - EAST'
    },
    {
        guid = 'X58F5H-0HMVKL9MNVTIM',
        course = {
            { lat = 'N 24.32.29', lon = 'E 122.47.27', },
            { lat = 'N 25.11.06', lon = 'E 122.42.15', },
            { lat = 'N 24.33.33', lon = 'E 122.08.38', },
            { lat = 'N 25.09.37', lon = 'E 122.06.45', },
        },
        side = 'China',
        missionName = 'ASW - EAST'
    },
    {
        guid = 'X58F5H-0HMVKGABDLDR9',
        course = {
            { lat = 'N 21.45.32', lon = 'E 121.33.54', },
            { lat = 'N 21.49.32', lon = 'E 121.49.21', },
            { lat = 'N 21.14.09', lon = 'E 121.44.26', },
            { lat = 'N 21.20.35', lon = 'E 122.03.05', },
        },
        side = 'China',
        missionName = 'ASW - BASHI'
    },
    {
        guid = 'X58F5H-0HMVKL9MO16Q6',
        course = {
            { lat = 'N 24.38.48', lon = 'E 122.06.01', },
            { lat = 'N 25.04.38', lon = 'E 122.08.21', },
            { lat = 'N 24.25.01', lon = 'E 122.45.13', },
            { lat = 'N 25.04.20', lon = 'E 122.44.05', },
        },
        side = 'Taiwan',
        missionName = 'ASW - EAST'
    },
}
HELICOPTER_BASE = {
    { guid = '6Z8LM5-0HMIJ3QGCRQC4', missionName = 'CAS EAST 2', num = 12 },
    { guid = 'X58F5H-0HN00TRR0Q1JQ', missionName = 'CAS SOUTH',  num = 24 },
    { guid = '6Z8LM5-0HMIJ3QGCRQ5F', missionName = 'CAS MIDDLE', num = 12 }
}

CONTINGENCY_RUNWAYS = {
    { base = { guid = 'X58F5H-0HN0KRS0IJLB4' }, runway = { guid = 'X58F5H-0HMSQ0HJ9MHP8' } },
    { base = { guid = 'X58F5H-0HN0KRS0IJLB2' }, runway = { guid = 'X58F5H-0HN0KRS0IJKDM' } },
    { base = { guid = 'X58F5H-0HN0KRS0IJLB0' }, runway = { guid = 'X58F5H-0HN0KRS0IJKQB' } },
}


-- Taiwan variables ------------------------------------------------------------------
-- LST 47分鐘到達泛水區
-- airlandingMissionStartTime1 = '06/09/2022 11:35 AM'
-- airlandingMissionStartTime2 = '06/09/2022 11:45 AM'
-- airlandingMissionStartTime3 = '06/09/2022 11:55 AM'
-- airlandingMissionStartTime4 = '06/09/2022 11:47 AM'
-- landingMissionStartTime = '06/09/2022 11:14 AM'

ANTI_SHIP = {}
ANTI_SHIP.NAI_1 = { 'RP-7760', 'RP-7761', 'RP-7762', 'RP-7763' }
ANTI_SHIP.NAI_2 = { 'RP-7787', 'RP-7788', 'RP-7789', 'RP-7790' }
-- NAI_3 = { 'RP-6832', 'RP-6833', 'RP-6834', 'RP-6835' }
ANTI_SHIP.SHIP_NUM_IN_NAI_1 = 4
ANTI_SHIP.HELICOPTER_NUM_IN_NAI_2 = 4
ANTI_SHIP.IS_ANTI_SHIP_MISSION_ACTIVATED = false
ANTI_SHIP.ASM_LAUNCHER_STATE = {}
ANTI_SHIP.ASM_LAUNCHER_RELOADING_TIME = 40 * 60
ANTI_SHIP.ASM_MAGAZINE_WEAPON_NUM = 8

IS_SKY_BOW_III_ACTIVATED = false
SKY_BOW_III_RELOADING_TIME = 40 * 60
MIN_WEAPON_QTY = 12
INTERCEPTING_MAX_ALTITUDE = 24384
SAMs_TO_INTERCEPT_UAV = { { guid = 'X58F5H-0HMQV7R60HMLL' } }
SAMs_TO_INTERCEPT_HELICOPTER = { { guid = 'X58F5H-0HMQSS6CKIB8L' }, { guid = 'X58F5H-0HMQVAE9S0A12' } }

-- local u=ScenEdit_GetUnit({guid = 'X58F5H-0HMQSS6CKIB8L'})
-- u.course={
--     { lat = 'N 25.03.35', lon = 'E 121.20.52', desiredSpeed = 30, presetThrottle = 'Flank' },
--     -- { lat = 'N 25.03.14', lon = 'E 121.21.31', desiredSpeed = 30, presetThrottle = 'Flank' },
--     -- { lat = 'N 25.02.26', lon = 'E 121.21.14', desiredSpeed = 30, presetThrottle = 'Flank' },
--     -- { lat = 'N 25.01.55', lon = 'E 121.21.22', desiredSpeed = 30, presetThrottle = 'Flank' },
--     { lat = 'N 24.59.50', lon = 'E 121.20.28', desiredSpeed = 30, presetThrottle = 'Flank' },
-- }
SAMs_STATE = {
    {
        guid = 'X58F5H-0HMQSS6CKIB8L',
        course = {
            { lat = 'N 25.03.35', lon = 'E 121.20.52', desiredSpeed = 30, presetThrottle = 'Flank' },
            { lat = 'N 25.03.14', lon = 'E 121.21.31', desiredSpeed = 30, presetThrottle = 'Flank' },
            { lat = 'N 25.02.26', lon = 'E 121.21.14', desiredSpeed = 30, presetThrottle = 'Flank' },
            { lat = 'N 25.01.55', lon = 'E 121.21.22', desiredSpeed = 30, presetThrottle = 'Flank' },
            { lat = 'N 24.59.50', lon = 'E 121.20.28', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        state = 'static',
        firingPosition = { 'RP-7798', 'RP-7799', 'RP-7800', 'RP-7801' },
        hidingPosition = { 'RP-7802', 'RP-7803', 'RP-7804', 'RP-7805' },
        reloadStartTime = nil,
        heading = 0,
        hasReloaded = false
    },
    {
        guid = 'X58F5H-0HMQV7R60HMLL',
        course = {
            { lat = 'N 25.09.09', lon = 'E 121.28.11', desiredSpeed = 30, presetThrottle = 'Flank' },
            { lat = 'N 25.08.51', lon = 'E 121.29.38', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        state = 'static',
        firingPosition = { 'RP-7806', 'RP-7807', 'RP-7808', 'RP-7809' },
        hidingPosition = { 'RP-7810', 'RP-7811', 'RP-7812', 'RP-7813' },
        reloadStartTime = nil,
        heading = 0,
        hasReloaded = false
    },
    {
        guid = 'X58F5H-0HMQVAE9S0A12',
        course = {
            { lat = 'N 25.15.31', lon = 'E 121.37.15', desiredSpeed = 30, presetThrottle = 'Flank' },
            { lat = 'N 25.14.28', lon = 'E 121.37.02', desiredSpeed = 30, presetThrottle = 'Flank' },
        },
        state = 'static',
        firingPosition = { 'RP-7814', 'RP-7815', 'RP-7816', 'RP-7817' },
        hidingPosition = { 'RP-7821', 'RP-7822', 'RP-7823', 'RP-7824' },
        reloadStartTime = nil,
        heading = 0,
        hasReloaded = false
    }
}
HAROP_STATE = {
    {
        guid = 'X58F5H-0HN0PGJQMCENE',
        courseList = {
            {
                {
                    lat = 'N 25.02.23',
                    lon = 'E 121.13.06'
                },
                {
                    lat = 'N 25.11.09',
                    lon = 'E 121.14.25'
                },
                {
                    lat = 'N 25.22.05',
                    lon = 'E 120.45.21'
                }
            },
            {
                {
                    lat = 'N 25.08.33',
                    lon = 'E 121.26.40'
                },
                {
                    lat = 'N 25.11.09',
                    lon = 'E 121.14.25'
                },
                {
                    lat = 'N 25.22.05',
                    lon = 'E 120.45.21'
                }
            },
        }
    },
    {
        guid = 'X58F5H-0HN0PGJQMCF1C',
        courseList = {
            {
                {
                    lat = 'N 25.12.10',
                    lon = 'E 121.18.22'
                },
                {
                    lat = 'N 25.24.38',
                    lon = 'E 121.26.33'
                },
                {
                    lat = 'N 25.32.48',
                    lon = 'E 121.15.43'
                }
            },
            {
                {
                    lat = 'N 25.21.49',
                    lon = 'E 121.30.20'
                },
                {
                    lat = 'N 25.24.38',
                    lon = 'E 121.26.33'
                },
                {
                    lat = 'N 25.32.48',
                    lon = 'E 121.15.43'
                }
            },
        }
    },
    {
        guid = 'X58F5H-0HN0PGJQMCESU',
        courseList = {
            {
                {
                    lat = 'N 25.12.10',
                    lon = 'E 121.18.22'
                },
                {
                    lat = 'N 25.24.38',
                    lon = 'E 121.26.33'
                },
                {
                    lat = 'N 25.32.48',
                    lon = 'E 121.15.43'
                }
            },
            {
                {
                    lat = 'N 25.21.49',
                    lon = 'E 121.30.20'
                },
                {
                    lat = 'N 25.24.38',
                    lon = 'E 121.26.33'
                },
                {
                    lat = 'N 25.32.48',
                    lon = 'E 121.15.43'
                }
            },
        }
    },
}

WCS = { wcsFree = 0, wcsTight = 1, wcsHold = 2 }
GLCM = {}
GLCM.IS_GLCM_RELOADING_ACTIVATED = true
GLCM.GLCM_LAUNCHER_STATE = {}
GLCM.GLCM_LAUNCHER_RELOADING_TIME = 40 * 60
GLCM.GLCM_MAGAZINE_WEAPON_NUM = 8


SCORE_AC_IS_DESTROYED_ON_THE_GROUND = -10
SCORE_DESTROY_AC_ON_THE_GROUND = 5
SCORE_LHD = 10
SCORE_LST = 10
SCORE_DDG = 10
SCORE_CV = 100
SCORE_IFV = -5
SCORE_INFANTRY = -3
SCORE_SAM_IS_DESTROYED = -20
SCORE_SUB = 15
SCORE_UAV = 20

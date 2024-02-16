CONFIG = {}
CONFIG.isDevMode = true
CONFIG.const = {}
CONFIG.c = {}
CONFIG.c.mlrs = {}
CONFIG.c.mlrs.onMobileUnit = {}
CONFIG.c.mlrs.onMobileUnit.const = {}
CONFIG.c.srbm = {}
CONFIG.c.srbm.onFacility = {}
CONFIG.c.srbm.onFacility.const = {}
CONFIG.c.srbm.onSAM = {}
CONFIG.c.srbm.onSAM.const = {}
CONFIG.c.aircraft = {}
CONFIG.c.aircraft.onMobileUnit = {}
CONFIG.c.aircraft.onMobileUnit.const = {}
CONFIG.c.landingOperation = {}
CONFIG.c.landingOperation.const = {}
CONFIG.c.asw = {}
CONFIG.c.asw.const = {}
CONFIG.t = {}
CONFIG.t.glcm = {}
CONFIG.t.glcm.const = {}
CONFIG.t.asm = {}
CONFIG.t.asm.const = {}
CONFIG.const.platformBDID1 = 2149  -- 726a
CONFIG.const.platformBDID2 = 3708  -- Z-18
CONFIG.const.platformBDID3 = 2511  -- 724
CONFIG.const.platformBDID4 = 2930  -- Ka-52k
CONFIG.const.platformBDID5 = 5856  -- Z-10
CONFIG.const.platformBDID6 = 3153  -- 075
CONFIG.const.platformBDID7 = 2006  -- 071
CONFIG.const.platformBDID8 = 735   -- 072III
CONFIG.const.platformBDID9 = 1823  -- 072A
CONFIG.const.platformBDID10 = 2925 -- 073A
CONFIG.const.platformBDID11 = 3187 -- 002
CONFIG.const.platformBDID12 = 6642 -- WZ-8
CONFIG.const.platformBDID13 = 3309 -- BZK-005
CONFIG.const.platformBDID14 = 123  -- customed sky bow 3
CONFIG.const.platformBDID15 = 2227 -- pac-3
CONFIG.const.platformBDID16 = 2537 -- JY-26
CONFIG.const.platformBDID17 = 2538 -- YLC-8B
CONFIG.const.platformBDID18 = 3281 -- HQ-22
CONFIG.const.platformBDID19 = 386  -- S-300
CONFIG.const.platformBDID20 = 2442 -- S-400
CONFIG.const.platformBDID21 = 1277 -- HQ-12

CONFIG.const.sensorBDID1 = 2788    -- S-300 Tombstone
CONFIG.const.sensorBDID2 = 4155    -- S-400 Grave Stone
CONFIG.const.sensorBDID3 = 3396    -- HQ-12 China H-200
CONFIG.const.sensorBDID4 = 6123    -- HQ-22 China H-200 Improved
CONFIG.const.sensorBDID5 = 3204    -- S-300 Cheese Board
CONFIG.const.sensorBDID6 = 5054    -- S-400 Cheese Board

CONFIG.const.loadoutDBID1 = 30568  -- ka-52
CONFIG.const.loadoutDBID2 = 31490  -- z-10
CONFIG.const.loadoutDBID3 = 18367  -- z-18
CONFIG.const.radarDistance = 70
CONFIG.const.batteryState = {}
CONFIG.const.batteryState.STATIC = 0
CONFIG.const.batteryState.REPOSITIONING = 1
CONFIG.const.batteryState.RESUPPLY = 2



-- MLRS on mobile units
CONFIG.c.mlrs.onMobileUnit.isStrikeActivated = false
CONFIG.c.mlrs.onMobileUnit.idxPackage = 1
CONFIG.c.mlrs.onMobileUnit.package = {
    {
        name = '',
        targetList = {},
        batteries = {
            { name = 'MLRS (73th Artillery Brigade 5th Battalion)', guid = 'X58F5H-0HN1E390V61VB' }
        },
        area = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' }
    }
}
CONFIG.c.mlrs.onMobileUnit.const.position = {
    north = {
        assemblyArea = {
            course = {
                { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
                { lat = 'N 25.30.10', lon = 'E 119.47.13', desiredSpeed = 30, presetThrottle = 'Flank' },
            },
            area = { 'RP-44256', 'RP-44257', 'RP-44258', 'RP-44259' }
        },
        firingpositions = {
            {
                course = {
                    { lat = 'N 25.30.10', lon = 'E 119.47.13', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 25.25.45', lon = 'E 119.44.25', desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-44264', 'RP-44265', 'RP-44266', 'RP-44267' }
            },
            {
                course = {
                    { lat = 'N 25.30.10', lon = 'E 119.47.13', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 25.27.22', lon = 'E 119.45.39', desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-44260', 'RP-44261', 'RP-44262', 'RP-44263' }
            },
        },
        magazineWeapenNum = 80
    }
}
CONFIG.c.mlrs.onMobileUnit.batteries = {
    {
        guid = 'X58F5H-0HN1E390V61VB',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.c.mlrs.onMobileUnit.const.position.north
    }
}
CONFIG.c.mlrs.onMobileUnit.const.contactAge = 30 * 60
CONFIG.c.mlrs.onMobileUnit.const.weaponDBID = 2123
CONFIG.c.mlrs.onMobileUnit.const.reloadTime = 5 * 60



-- SRBM on facility
CONFIG.c.srbm.onFacility.lastReconTime = nil
CONFIG.c.srbm.onFacility.launcherState = {}
CONFIG.c.srbm.onFacility.isStrikeActivated = false
CONFIG.c.srbm.onFacility.isReloadActivated = false
CONFIG.c.srbm.onFacility.strikeTimes = 0
CONFIG.c.srbm.onFacility.idxPackage = 1
CONFIG.c.srbm.onFacility.package = {
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
CONFIG.c.srbm.onFacility.const.contactAge = 30 * 60
CONFIG.c.srbm.onFacility.const.magazineWeaponNum = 3
CONFIG.c.srbm.onFacility.const.reloadTime = 45 * 60
CONFIG.c.srbm.onFacility.const.contingencyRunways = {
    { base = { guid = 'X58F5H-0HN0KRS0IJLB4' }, runway = { guid = 'X58F5H-0HMSQ0HJ9MHP8' } },
    { base = { guid = 'X58F5H-0HN0KRS0IJLB2' }, runway = { guid = 'X58F5H-0HN0KRS0IJKDM' } },
    { base = { guid = 'X58F5H-0HN0KRS0IJLB0' }, runway = { guid = 'X58F5H-0HN0KRS0IJKQB' } },
}


-- SRBM on SAM
CONFIG.c.srbm.onSAM.isStrikeActivated = false
CONFIG.c.srbm.onSAM.h6nTemp = {}
CONFIG.c.srbm.onSAM.wz8Temp = {}
CONFIG.c.srbm.onSAM.const.tk3SensorDBID1 = 6366
CONFIG.c.srbm.onSAM.const.tk3SensorDBID2 = 282
CONFIG.c.srbm.onSAM.const.tk2SensorDBID = 919
CONFIG.c.srbm.onSAM.const.pac3SensorDBID = 2498
CONFIG.c.srbm.onSAM.const.h6nBaseGUID = 'X58F5H-0HMRAQFR07T2V'
CONFIG.c.srbm.onSAM.const.bzk005BaseGUID = '6Z8LM5-0HMIJ3QGCRQC4'
CONFIG.c.srbm.onSAM.const.h6nDBID = 4969
CONFIG.c.srbm.onSAM.const.batteries = {
    { name = 'SRBM (613th Brigade)', guid = '6Z8LM5-0HMML05RV29L0' },
}
CONFIG.c.srbm.onSAM.const.contactAge = 60
CONFIG.c.srbm.onSAM.const.wz8Course = {
    { lat = 'N 25.44.14', lon = 'E 121.36.00', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 24.41.37', lon = 'E 121.34.30', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 24.05.04', lon = 'E 121.22.33', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 22.52.27', lon = 'E 121.06.41', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 22.31.53', lon = 'E 120.29.25', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 24.16.15', lon = 'E 120.29.30', desiredAltitude = 30480, desiredSpeed = 3300 },
}
CONFIG.c.srbm.onSAM.const.h6nCourse = {
    { lat = 'N 29.47.52', lon = 'E 119.19.47', desiredAltitude = 13716, desiredSpeed = 450 },
    { lat = 'N 25.57.34', lon = 'E 121.32.45', desiredAltitude = 13716, desiredSpeed = 550 },
}




-- ac on mobile units
CONFIG.c.aircraft.onMobileUnit.isStrikeActivated = false
CONFIG.c.aircraft.onMobileUnit.maxStrikeTimes = 5
CONFIG.c.aircraft.onMobileUnit.lastStrikeTime = nil
CONFIG.c.aircraft.onMobileUnit.package = {
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
CONFIG.c.aircraft.onMobileUnit.const.periodOfStrike = 70 * 60




-- landing operation
CONFIG.c.landingOperation.isLandingShipsStartedMoving = true
CONFIG.c.landingOperation.isLandingShipsArrived = false
CONFIG.c.landingOperation.amphibiousLandingAttackStartTime = nil
CONFIG.c.landingOperation.isAmphibiousLandingAttackLaunched = false
CONFIG.c.landingOperation.airlandingMissionStartTime = nil
CONFIG.c.landingOperation.idxShipLocationInfo = 1
CONFIG.c.landingOperation.const.periodOfTime = 30 * 60
CONFIG.c.landingOperation.const.airlandingArea = { 'RP-3819', 'RP-3820', 'RP-3821', 'RP-3822' }
CONFIG.c.landingOperation.const.contactNumInAirlandingArea = 3

---@class CargoItem
---@field type number
---@field num number
---@field dbid number

CONFIG.c.landingOperation.const.cargoList = {
    ---@type table<number, CargoItem>
    type075 = { { type = 2, num = 60, dbid = 3 }, { type = 3, num = 200, dbid = 2039 } },
    ---@type table<number, CargoItem>
    type071 = { { type = 2, num = 20, dbid = 3 }, { type = 3, num = 30, dbid = 2039 } },
    ---@type table<number, CargoItem>
    type072iii = { { type = 2, num = 10, dbid = 3 }, { type = 3, num = 6, dbid = 2039 } },
    ---@type table<number, CargoItem>
    type072a = { { type = 2, num = 10, dbid = 3 }, { type = 3, num = 6, dbid = 2039 } },
    ---@type table<number, CargoItem>
    type073a = { { type = 2, num = 6, dbid = 3 } }
}
---@type CargoItem
CONFIG.c.landingOperation.const.cargoItemForTransferForBoat = { type = 2, num = 2, dbid = 3 }          -- 075/071 726a
---@type CargoItem
CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter = { type = 3, num = 2, dbid = 2039 } -- 075/071 Z-18
CONFIG.c.landingOperation.const.shipInfo = {
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
CONFIG.c.landingOperation.const.shipLocationInfo = {
    {
        name = 'north',
        from = {
            areas = { {
                startingPoints = { type075 = { side = "China", area = { 'RP-11169' } } },
                heading = CONFIG.c.landingOperation.const.shipInfo.heading.north
            } }
        },
        to = {
            areas = {
                {
                    startingPoints = {
                        type075 = { side = "China", area = { 'RP-4322' } },
                        type071 = { side = "China", area = { 'RP-3915' } },
                    },
                    heading = CONFIG.c.landingOperation.const.shipInfo.heading.west,
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
                    heading = CONFIG.c.landingOperation.const.shipInfo.heading.west,
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
                    heading = CONFIG.c.landingOperation.const.shipInfo.heading.west,
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
                    heading = CONFIG.c.landingOperation.const.shipInfo.heading.north,
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
                type075 = { locations = {}, locationIndex = 1, dbid = CONFIG.const.platformBDID6, },
                type071 = { locations = {}, locationIndex = 1, dbid = CONFIG.const.platformBDID7, },
                type072iii = { locations = {}, locationIndex = 1, dbid = CONFIG.const.platformBDID8, },
                type072a = { locations = {}, locationIndex = 1, dbid = CONFIG.const.platformBDID9, },
                type073a = { locations = {}, locationIndex = 1, dbid = CONFIG.const.platformBDID10, },
                type071InLSTArea = { locations = {}, locationIndex = 1, dbid = CONFIG.const.platformBDID7, }
            }
        },
        airLandingZone = { 'RP-3819', 'RP-3820', 'RP-3821', 'RP-3822' },
        numOfContactsInAirLandingZone = 3
    },
}
CONFIG.c.landingOperation.const.cargoInfoForTransfer = {
    {
        anchorageArea = { 'RP-9684', 'RP-9685', 'RP-9686', 'RP-9687' },
        LSTAnchorageArea = { 'RP-9712', 'RP-9713', 'RP-9714', 'RP-9715' },
        boat = {
            dbid = CONFIG.const.platformBDID1,
            missions = { 'LANDING ZONE' },
            cargoItem = CONFIG.c.landingOperation.const.cargoItemForTransferForBoat
        },
        tansportHelicopter = {
            dbid = CONFIG.const.platformBDID2,
            missions = { 'AIRLANDING ZONE', 'AIRLANDING ZONE 2', 'AIRLANDING ZONE 3' },
            cargoItem = CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter
        },
        attackHelicopter1 = { dbid = CONFIG.const.platformBDID4, missions = { 'CAS EAST 1' } },
        attackHelicopter2 = { dbid = CONFIG.const.platformBDID5, missions = { 'CAS EAST 1' } },
    },
    {
        anchorageArea = { 'RP-9957', 'RP-9958', 'RP-9959', 'RP-9960' },
        LSTAnchorageArea = { 'RP-9965', 'RP-9966', 'RP-9967', 'RP-9968' },
        boat = {
            dbid = CONFIG.const.platformBDID1,
            missions = { 'LANDING ZONE ZHUWEI' },
            cargoItem = CONFIG.c.landingOperation.const.cargoItemForTransferForBoat
        },
        tansportHelicopter = {
            dbid = CONFIG.const.platformBDID2,
            missions = { 'AIRLANDING ZONE TAIPING 1', 'AIRLANDING ZONE TAIPING 2', 'AIRLANDING ZONE TAIPING 3' },
            cargoItem = CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter
        },
        attackHelicopter1 = { dbid = CONFIG.const.platformBDID4, missions = { 'CAS EAST 1' } },
        attackHelicopter2 = { dbid = CONFIG.const.platformBDID5, missions = { 'CAS EAST 1' } },
    },
    {
        anchorageArea = { 'RP-9969', 'RP-9970', 'RP-9971', 'RP-9972' },
        LSTAnchorageArea = { 'RP-9977', 'RP-9978', 'RP-9979', 'RP-9980' },
        boat = {
            dbid = CONFIG.const.platformBDID1,
            missions = { 'LANDING ZONE BAO' },
            cargoItem = CONFIG.c.landingOperation.const.cargoItemForTransferForBoat
        },
        tansportHelicopter = {
            dbid = CONFIG.const.platformBDID2,
            missions = { 'AIRLANDING ZONE PARK 1', 'AIRLANDING ZONE PARK 2', 'AIRLANDING ZONE PARK 3' },
            cargoItem = CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter
        },
        attackHelicopter1 = { dbid = CONFIG.const.platformBDID4, missions = { 'CAS EAST 2' } },
        attackHelicopter2 = { dbid = CONFIG.const.platformBDID5, missions = { 'CAS EAST 2' } },
    },
    {
        anchorageArea = { 'RP-9981', 'RP-9982', 'RP-9983', 'RP-9984' },
        LSTAnchorageArea = { 'RP-9989', 'RP-9990', 'RP-9991', 'RP-9992' },
        boat = {
            dbid = CONFIG.const.platformBDID1,
            missions = { 'LANDING ZONE NORTH WAY' },
            cargoItem = CONFIG.c.landingOperation.const.cargoItemForTransferForBoat
        },
        tansportHelicopter = {
            dbid = CONFIG.const.platformBDID2,
            missions = { 'AIRLANDING ZONE NORTH', 'AIRLANDING ZONE NORTH 2', 'AIRLANDING ZONE NORTH 3' },
            cargoItem = CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter
        },
        attackHelicopter1 = { dbid = CONFIG.const.platformBDID4, missions = { 'CAS NORTH' } },
        attackHelicopter2 = { dbid = CONFIG.const.platformBDID5, missions = { 'CAS NORTH' } },
    },
    {
        anchorageArea = { 'RP-14290', 'RP-14291', 'RP-14292', 'RP-14293' },
        LSTAnchorageArea = { 'RP-14286', 'RP-14287', 'RP-14288', 'RP-14289' },
        boat = {
            dbid = CONFIG.const.platformBDID1,
            missions = { 'LANDING ZONE JIALUTANG' },
            cargoItem = CONFIG.c.landingOperation.const.cargoItemForTransferForBoat
        },
        tansportHelicopter = {
            dbid = CONFIG.const.platformBDID2,
            missions = { 'AIRLANDING ZONE CHANGLONG', 'AIRLANDING ZONE CHANGLONG 2', 'AIRLANDING ZONE CHANGLONG 3' },
            cargoItem = CONFIG.c.landingOperation.const.cargoItemForTransferForHelicapter
        },
        attackHelicopter1 = { dbid = CONFIG.const.platformBDID4, missions = { 'CAS SOUTH' } },
        attackHelicopter2 = { dbid = CONFIG.const.platformBDID5, missions = { 'CAS SOUTH' } },
    },
}
CONFIG.c.landingOperation.const.cargoMissionList = {
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
CONFIG.c.landingOperation.const.helicopterInBase = {
    { guid = '6Z8LM5-0HMIJ3QGCRQC4', missionName = 'CAS EAST 2', num = 12 },
    { guid = 'X58F5H-0HN00TRR0Q1JQ', missionName = 'CAS SOUTH',  num = 24 },
    { guid = '6Z8LM5-0HMIJ3QGCRQ5F', missionName = 'CAS MIDDLE', num = 12 }
}
CONFIG.c.landingOperation.const.sag = {
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

-- ASW
CONFIG.c.asw.const.submarine = {
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



-- GLCM
CONFIG.t.glcm.isReloadActivated = true
CONFIG.t.glcm.launcherState = {}
CONFIG.t.glcm.const.reloadTime = 40 * 60
CONFIG.t.glcm.const.magazineWeaponNum = 8


-- ASM
CONFIG.t.asm.isAntishipMissionActivated = false
CONFIG.t.asm.launcherState = {}
CONFIG.t.asm.const.reloadTime = 40 * 60
CONFIG.t.asm.const.magazineWeaponNum = 8
CONFIG.t.asm.const.nai1 = { 'RP-7760', 'RP-7761', 'RP-7762', 'RP-7763' }
CONFIG.t.asm.const.nai2 = { 'RP-7787', 'RP-7788', 'RP-7789', 'RP-7790' }
CONFIG.t.asm.const.shipNumInNai1 = 4
CONFIG.t.asm.const.helicopterNumInNai2 = 4

-- LST 47分鐘到達泛水區
-- airlandingMissionStartTime1 = '06/09/2022 11:35 AM'
-- airlandingMissionStartTime2 = '06/09/2022 11:45 AM'
-- airlandingMissionStartTime3 = '06/09/2022 11:55 AM'
-- airlandingMissionStartTime4 = '06/09/2022 11:47 AM'
-- landingMissionStartTime = '06/09/2022 11:14 AM'




---Old variables-----------------------------------------------------------------------------------
IS_ASW_STARTED = true


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

--{ [1] = { mag_weapons = { [1] = { wpn_dbid = 3021, wpn_maxcap = 5, wpn_current = 0, wpn_default = 5, wpn_guid = 'X58F5H-0HN1BN6784FTC', wpn_name = 'BP-12A' }, [2] = { wpn_dbid = 2123, wpn_maxcap = 20, wpn_current = 0, wpn_default = 20, wpn_guid = 'X58F5H-0HN1BN6784FTD', wpn_name = 'SY-400 MLRS [Unitary]' } }, mag_dbid = 1795, mag_guid = 'X58F5H-0HN1BN6784FTB', mag_capacity = 25, mag_name = 'SY-400' } }

CONFIG = {}
CONFIG.isDevMode = true
CONFIG.isSaved = true
CONFIG.difficulty = 'normal'
CONFIG.const = {}
CONFIG.c = {}
CONFIG.c.mlrs = {}
CONFIG.c.mlrs.const = {}
CONFIG.c.glcm = {}
CONFIG.c.glcm.const = {}
CONFIG.c.srbm = {}
CONFIG.c.srbm.const = {}
CONFIG.c.srbm.onSAM = {}
CONFIG.c.srbm.onSAM.const = {}
CONFIG.c.aircraft = {}
CONFIG.c.aircraft.const = {}
CONFIG.c.antiShip = {}
CONFIG.c.antiShip.const = {}
CONFIG.c.airIntercept = {}
CONFIG.c.airIntercept.const = {}
CONFIG.c.landingOperation = {}
CONFIG.c.landingOperation.const = {}
CONFIG.c.slcm = {}
CONFIG.c.slcm.const = {}
CONFIG.t = {}
CONFIG.t.glcm = {}
CONFIG.t.glcm.const = {}
CONFIG.t.srbm = {}
CONFIG.t.srbm.const = {}
CONFIG.t.asm = {}
CONFIG.t.asm.const = {}
CONFIG.s = {}
CONFIG.s.const = {}
CONFIG.const.platformBDID1 = 2149  -- 726a
CONFIG.const.platformBDID2 = 3708  -- Z-18
CONFIG.const.platformBDID3 = 2511  -- 724
CONFIG.const.platformBDID4 = 2930  -- Ka-52k
CONFIG.const.platformBDID5 = 5856  -- Z-10
CONFIG.const.platformBDID6 = 3153  -- 075
CONFIG.const.platformBDID7 = 2006  -- 071
CONFIG.const.platformBDID8 = 4683  -- 072III
CONFIG.const.platformBDID9 = 4602  -- 072A
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
CONFIG.const.platformBDID22 = 1679 -- SY-400
CONFIG.const.platformBDID23 = 624  -- supply
CONFIG.const.platformBDID24 = 3126 -- PHL-03


CONFIG.const.sensorBDID1 = 2788   -- S-300 Tombstone
CONFIG.const.sensorBDID2 = 4155   -- S-400 Grave Stone
CONFIG.const.sensorBDID3 = 3396   -- HQ-12 China H-200
CONFIG.const.sensorBDID4 = 6123   -- HQ-22 China H-200 Improved
CONFIG.const.sensorBDID5 = 3204   -- S-300 Cheese Board
CONFIG.const.sensorBDID6 = 5054   -- S-400 Cheese Board
CONFIG.const.sensorBDID7 = 6847   -- P-3C SeaVue
CONFIG.const.sensorBDID8 = 2938   -- E-2K

CONFIG.const.loadoutDBID1 = 30568 -- ka-52
CONFIG.const.loadoutDBID2 = 31490 -- z-10
CONFIG.const.loadoutDBID3 = 18367 -- z-18
CONFIG.const.radarDistance = 70
CONFIG.const.batteryState = {}
CONFIG.const.batteryState.STATIC = 0
CONFIG.const.batteryState.REPOSITIONING = 1
CONFIG.const.batteryState.RESUPPLY = 2
CONFIG.const.amountOfWeaponsInMagazinesForSRBM = 36
CONFIG.const.amountOfWeaponsInMagazinesForMLRS = 120

if CONFIG.difficulty == 'normal' then
    CONFIG.const.amountOfWeaponsInMagazinesForSRBM = 72
    CONFIG.const.amountOfWeaponsInMagazinesForMLRS = 240
end



-- MLRS on mobile units
CONFIG.c.mlrs.isStrikeActivated = false
CONFIG.c.mlrs.idxPackage = 1
CONFIG.c.mlrs.packages = {
    {
        name = '',
        targetList = {},
        batteries = {
            { name = 'MLRS (73th Artillery Brigade 5th Battalion)', guid = 'X58F5H-0HN20R8KSKH7A' }
        },
        area = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' }
    }
}
CONFIG.c.mlrs.const.position = {
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
                    -- { lat = 'N 25.30.10', lon = 'E 119.47.13', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 25.25.45', lon = 'E 119.44.25', desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-44264', 'RP-44265', 'RP-44266', 'RP-44267' }
            },
            {
                course = {
                    -- { lat = 'N 25.30.10', lon = 'E 119.47.13', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 25.30.20', lon = 'E 119.46.50', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 25.27.22', lon = 'E 119.45.39', desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-44260', 'RP-44261', 'RP-44262', 'RP-44263' }
            },
        },
        magazineWeapenNum = CONFIG.const.amountOfWeaponsInMagazinesForMLRS
    },
    penghu = {
        assemblyArea = {
            course = {
                { lat = 'N 23.30.52', lon = 'E 119.34.10', desiredSpeed = 30, presetThrottle = 'Flank' },
            },
            area = { 'RP-46290', 'RP-46291', 'RP-46292', 'RP-46293' }
        },
        firingpositions = {
            {
                course = {
                    { lat = 'N 23.30.58', lon = 'E 119.34.33', desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-46296', 'RP-46297', 'RP-46298', 'RP-46299' }
            },
        },
        magazineWeapenNum = 0
    },
}
CONFIG.c.mlrs.batteries = {
    {
        name = 'MLRS (73th Artillery Brigade 5th Battalion)',
        guid = 'X58F5H-0HN20R8KSKH7A',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.c.mlrs.const.position.north,
        weaponDBID = 2123
    }
}
CONFIG.c.mlrs.const.contactAge = 30 * 60
CONFIG.c.mlrs.const.reloadTime = 40 * 60

-- GLCM
CONFIG.c.glcm.lastReconTime = nil
CONFIG.c.glcm.isStrikeActivated = false
CONFIG.c.glcm.strikeTimes = 0
CONFIG.c.glcm.idxPackage = 1
CONFIG.c.glcm.const.position = {
    brigade635 = {
        assemblyArea = {
            course = {
                { lat = 'N 24.46.44', lon = 'E 118.40.37', desiredSpeed = 30, presetThrottle = 'Flank' },
                { lat = 'N 24.46.34', lon = 'E 118.41.50', desiredSpeed = 30, presetThrottle = 'Flank' },
            },
            area = { 'RP-46386', 'RP-46387', 'RP-46388', 'RP-46389' }
        },
        firingpositions = {
            {
                course = {
                    { lat = 'N 24.46.44', lon = 'E 118.40.37', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 24.41.45', lon = 'E 118.43.18', desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-46390', 'RP-46391', 'RP-46392', 'RP-46393' }
            },
        },
        magazineWeapenNum = 48
    },

}
CONFIG.c.glcm.batteries = {
    {
        guid = '6Z8LM5-0HMN97ERAUODK',
        name = 'GLCM (635th Brigade)',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.c.glcm.const.position.brigade635,
        weaponDBID = 2122
    },
}
CONFIG.c.glcm.packages = {
    {
        name = 'HELIPAD',
        targetList = {},
        batteries = {
            { name = 'GLCM (635th Brigade)', guid = '6Z8LM5-0HMN97ERAUODK', batteryIdx = 2 },
        },
        num = 2,
        index = 1,
        hasLaunchedTheFirstStrike = false
    },
    {
        name = 'CONTINGENCY RUNWAY',
        targetList = {},
        batteries = {
            { name = 'GLCM (635th Brigade)', guid = '6Z8LM5-0HMN97ERAUODK', batteryIdx = 2 },
        },
        num = 4,
        index = 1,
        hasLaunchedTheFirstStrike = false
    },
}
CONFIG.c.glcm.const.contactAge = 30 * 60
CONFIG.c.glcm.const.reloadTime = 40 * 60


-- SRBM on facility
CONFIG.c.srbm.lastReconTime = nil
CONFIG.c.srbm.isStrikeActivated = false
CONFIG.c.srbm.strikeTimes = 0
CONFIG.c.srbm.idxPackage = 1
CONFIG.c.srbm.const.position = {
    brigade615 = {
        assemblyArea = {
            course = {
                -- { lat = 'N 24.17.02', lon = 'E 115.57.23', desiredSpeed = 30, presetThrottle = 'Flank' },
                { lat = 'N 24.17.32', lon = 'E 115.58.09', desiredSpeed = 30, presetThrottle = 'Flank' },
                { lat = 'N 24.17.05', lon = 'E 115.58.35', desiredSpeed = 30, presetThrottle = 'Flank' },
            },
            area = { 'RP-44316', 'RP-44317', 'RP-44318', 'RP-44319' }
        },
        firingpositions = {
            {
                course = {
                    { lat = 'N 24.17.32', lon = 'E 115.58.09', desiredSpeed = 30, presetThrottle = 'Flank' },
                    -- { lat = 'N 24.17.02', lon = 'E 115.57.23', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 24.17.05', lon = 'E 115.59.41', desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-44322', 'RP-44323', 'RP-44324', 'RP-44325' }
            },
        },
        magazineWeapenNum = CONFIG.const.amountOfWeaponsInMagazinesForSRBM
    },
    brigade614 = {
        assemblyArea = {
            course = {
                { lat = 'N 26.04.01', lon = 'E 117.18.55', desiredSpeed = 30, presetThrottle = 'Flank' },
                { lat = 'N 26.03.47', lon = 'E 117.19.12', desiredSpeed = 30, presetThrottle = 'Flank' },
            },
            area = { 'RP-44330', 'RP-44331', 'RP-44332', 'RP-44333' }
        },
        firingpositions = {
            {
                course = {
                    { lat = 'N 26.04.18', lon = 'E 117.18.51', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 26.03.49', lon = 'E 117.20.05', desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-44335', 'RP-44336', 'RP-44337', 'RP-44338' }
            },
        },
        magazineWeapenNum = CONFIG.const.amountOfWeaponsInMagazinesForSRBM
    },
    brigade636 = {
        assemblyArea = {
            course = {
                { lat = 'N 24.45.52', lon = 'E 113.40.52', desiredSpeed = 30, presetThrottle = 'Flank' },
                { lat = 'N 24.45.34', lon = 'E 113.40.52', desiredSpeed = 30, presetThrottle = 'Flank' },
            },
            area = { 'RP-44342', 'RP-44343', 'RP-44344', 'RP-44345' }
        },
        firingpositions = {
            {
                course = {
                    { lat = 'N 24.45.52', lon = 'E 113.40.52', desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 'N 24.45.52', lon = 'E 113.41.35', desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-44357', 'RP-44358', 'RP-44359', 'RP-44360' }
            },
        },
        magazineWeapenNum = CONFIG.const.amountOfWeaponsInMagazinesForSRBM
    },
    brigade616 = {
        assemblyArea = {
            course = {
                { lat = 'N 25.54.38', lon = 'E 114.57.35', desiredSpeed = 30, presetThrottle = 'Flank' },
            },
            area = { 'RP-44364', 'RP-44365', 'RP-44366', 'RP-44367' }
        },
        firingpositions = {
            {
                course = {
                    { lat = 'N 25.55.32', lon = 'E 114.58.18', desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-44369', 'RP-44370', 'RP-44371', 'RP-44372' }
            },
        },
        magazineWeapenNum = CONFIG.const.amountOfWeaponsInMagazinesForSRBM
    },
    brigade613 = {
        assemblyArea = {
            course = {
                { lat = 28.455941652975, lon = 117.86516402324, desiredSpeed = 30, presetThrottle = 'Flank' },
                { lat = 28.455760146701, lon = 117.85790803852, desiredSpeed = 30, presetThrottle = 'Flank' },
                { lat = 'N 28.27.12',    lon = 'E 117.51.17',   desiredSpeed = 30, presetThrottle = 'Flank' },
            },
            area = { 'RP-44386', 'RP-44387', 'RP-44388', 'RP-44389' }
        },
        firingpositions = {
            {
                course = {
                    { lat = 28.455760146701, lon = 117.85790803852, desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 28.455941652975, lon = 117.86516402324, desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 28.443410902986, lon = 117.86719441616, desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-44391', 'RP-44392', 'RP-44393', 'RP-44394' }
            },
        },
        magazineWeapenNum = CONFIG.const.amountOfWeaponsInMagazinesForSRBM
    },
    brigade617 = {
        assemblyArea = {
            course = {
                { lat = 29.158533243915, lon = 119.61541712539, desiredSpeed = 30, presetThrottle = 'Flank' },
                { lat = 'N 29.09.01',    lon = 'E 119.36.44',   desiredSpeed = 30, presetThrottle = 'Flank' },
            },
            area = { 'RP-44408', 'RP-44409', 'RP-44410', 'RP-44411' }
        },
        firingpositions = {
            {
                course = {
                    { lat = 29.158533243915, lon = 119.61541712539, desiredSpeed = 30, presetThrottle = 'Flank' },
                    { lat = 29.158295428459, lon = 119.62849131226, desiredSpeed = 30, presetThrottle = 'Flank' },
                },
                area = { 'RP-44413', 'RP-44414', 'RP-44415', 'RP-44416' }
            },
        },
        magazineWeapenNum = CONFIG.const.amountOfWeaponsInMagazinesForSRBM
    },
}
CONFIG.c.srbm.batteries = {
    {
        guid = 'X58F5H-0HN1G2IFLNKG9',
        name = 'SRBM (615th Brigade)',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.c.srbm.const.position.brigade615,
        weaponDBID = 2142
    },
    {
        guid = 'X58F5H-0HN1LQGRV8HNQ',
        name = 'SRBM (614th Brigade)',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.c.srbm.const.position.brigade614,
        weaponDBID = 2142
    },
    {
        guid = 'X58F5H-0HN1FI7IOAS9J',
        name = 'SRBM (636th Brigade)',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.c.srbm.const.position.brigade636,
        weaponDBID = 3381
    },
    {
        guid = 'X58F5H-0HN1G2IFLF6QE',
        name = 'SRBM (616th Brigade)',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.c.srbm.const.position.brigade616,
        weaponDBID = 2145
    },
    {
        guid = 'X58F5H-0HN1G2DEBC7O8',
        name = 'SRBM (613th Brigade)',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.c.srbm.const.position.brigade613,
        weaponDBID = 40
    },
    {
        guid = 'X58F5H-0HN1G2IFMBPJD',
        name = 'SRBM (617th Brigade)',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.c.srbm.const.position.brigade617,
        weaponDBID = 3381
    },
}
CONFIG.c.srbm.packages = {
    {
        name = 'RADAR',
        targetList = {},
        batteries = {
            { name = 'SRBM (614th Brigade)', guid = 'X58F5H-0HN1LQGRV8HNQ', batteryIdx = 2 },
            { name = 'SRBM (613th Brigade)', guid = 'X58F5H-0HN1G2DEBC7O8', batteryIdx = 5 }
            -- CONFIG.c.srbm.batteries[2],
            -- CONFIG.c.srbm.batteries[5]
        },
        num = 2,
        index = 1,
        hasLaunchedTheFirstStrike = false
    },
    {
        name = 'RUNWAY',
        targetList = {},
        batteries = {
            { name = 'SRBM (636th Brigade)', guid = 'X58F5H-0HN1FI7IOAS9J', batteryIdx = 3 },
            { name = 'SRBM (617th Brigade)', guid = 'X58F5H-0HN1G2IFMBPJD', batteryIdx = 6 }
            -- CONFIG.c.srbm.batteries[3],
            -- CONFIG.c.srbm.batteries[6],
        },
        num = 4,
        index = 1,
        hasLaunchedTheFirstStrike = false
    },
    {
        name = 'PORT',
        targetList = {},
        batteries = {
            { name = 'SRBM (613th Brigade)', guid = 'X58F5H-0HN1G2DEBC7O8', batteryIdx = 5 },
            { name = 'SRBM (615th Brigade)', guid = 'X58F5H-0HN1G2IFLNKG9', batteryIdx = 1 }
            -- CONFIG.c.srbm.batteries[1],
            -- CONFIG.c.srbm.batteries[5],
        },
        num = 4,
        index = 1,
        hasLaunchedTheFirstStrike = false
    },
    {
        name = 'SHELTER',
        targetList = {},
        batteries = {
            { name = 'SRBM (616th Brigade)', guid = 'X58F5H-0HN1G2IFLF6QE', batteryIdx = 4 }
            -- CONFIG.c.srbm.batteries[4],
        },
        num = 2,
        index = 1,
        hasLaunchedTheFirstStrike = false
    },
}
CONFIG.c.srbm.const.contactAge = 30 * 60
CONFIG.c.srbm.const.reloadTime = 40 * 60
CONFIG.c.srbm.const.contingencyRunways = {
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
    { name = 'SRBM (613th Brigade)', guid = 'X58F5H-0HN1G2DEBC7O8', },
}
CONFIG.c.srbm.onSAM.const.contactAge = 2 * 60
CONFIG.c.srbm.onSAM.const.wz8Course = {
    -- { lat = 'N 24.58.57', lon = 'E 121.29.47', desiredAltitude = 30480, desiredSpeed = 3300 },
    -- { lat = 'N 24.41.37', lon = 'E 121.34.30', desiredAltitude = 30480, desiredSpeed = 3300 },
    -- { lat = 'N 24.05.04', lon = 'E 121.22.33', desiredAltitude = 30480, desiredSpeed = 3300 },
    -- { lat = 'N 22.52.27', lon = 'E 121.06.41', desiredAltitude = 30480, desiredSpeed = 3300 },
    -- { lat = 'N 22.31.53', lon = 'E 120.29.25', desiredAltitude = 30480, desiredSpeed = 3300 },
    -- { lat = 'N 24.16.15', lon = 'E 120.29.30', desiredAltitude = 30480, desiredSpeed = 3300 },
    { lat = 'N 22.15.14', lon = 'E 120.54.52', },
    { lat = 'N 23.44.15', lon = 'E 120.09.50', },
}
CONFIG.c.srbm.onSAM.const.h6nCourse = {
    { lat = 'N 29.47.52', lon = 'E 119.19.47', desiredAltitude = 13716, desiredSpeed = 450 },
    { lat = 'N 25.57.34', lon = 'E 121.32.45', desiredAltitude = 13716, desiredSpeed = 550 },
}




-- ac on mobile units
CONFIG.c.aircraft.isStrikeActivated = false
CONFIG.c.aircraft.maxStrikeTimes = 5
CONFIG.c.aircraft.lastStrikeTime = nil
CONFIG.c.aircraft.packages = {
    {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H5P44', weaponDBID = 2876, num = 12, units = {} },
        escort = nil,
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 6, units = {} },
        missionName = 'LAND STRIKE - SOUTH',
        area = { 'RP-8016', 'RP-8017', 'RP-8018', 'RP-8019' },
        hasLaunched = false,
        course = nil,
        tanker = nil
    },
    {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H5P44', weaponDBID = 2876, num = 12, units = {} },
        escort = nil,
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 6, units = {} },
        missionName = 'LAND STRIKE - MIDDLE',
        area = { 'RP-8008', 'RP-8009', 'RP-8010', 'RP-8011' },
        hasLaunched = false,
        course = nil,
        tanker = nil
    },
    {
        striker = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ5F', weaponDBID = 2876, num = 12, units = {} },
        escort = nil,
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQC4', weaponDBID = 2875, num = 6, units = {} },
        missionName = 'LAND STRIKE - NORTH',
        area = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' },
        hasLaunched = false,
        course = nil,
        tanker = nil
    },
    {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H5P44', weaponDBID = 2876, num = 12, units = {} },
        escort = nil,
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 6, units = {} },
        missionName = 'LAND STRIKE - SOUTH - 2',
        area = { 'RP-8016', 'RP-8017', 'RP-8018', 'RP-8019' },
        hasLaunched = false,
        course = nil,
        tanker = nil
    },
    {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H5P44', weaponDBID = 2876, num = 12, units = {} },
        escort = nil,
        wildWeasel = { baseGUID = '6Z8LM5-0HMIJ3QGCRQ2G', weaponDBID = 2875, num = 6, units = {} },
        missionName = 'LAND STRIKE - MIDDLE - 2',
        area = { 'RP-8008', 'RP-8009', 'RP-8010', 'RP-8011' },
        hasLaunched = false,
        course = nil,
        tanker = nil
    },
    {
        striker = { baseGUID = '6Z8LM5-0HMLLEF9H7VDF', weaponDBID = 2107, num = 12, units = {} },
        escort = nil,
        wildWeasel = nil,
        missionName = 'LAND STRIKE - NORTH - 2',
        area = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' },
        hasLaunched = false,
        course = nil,
        tanker = nil
    },
    -- {
    --     -- striker = { baseGUID = '6Z8LM5-0HMITKFQH25Q8', weaponDBID = 2876, num = 6, units = {} },
    --     striker = { baseGUID = 'X58F5H-0HN201E9DHM1C', weaponDBID = 2876, num = 6, units = {} },
    --     escort = nil,
    --     -- wildWeasel = { baseGUID = '6Z8LM5-0HMITKFQH25Q8', weaponDBID = 276, num = 6, units = {} },
    --     wildWeasel = { baseGUID = 'X58F5H-0HN201E9DHM1C', weaponDBID = 276, num = 6, units = {} },

    --     missionName = 'LAND STRIKE - NORTH - 3',
    --     area = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' },
    --     hasLaunched = false,
    --     course = nil,
    --     tanker = { baseGUID = '', num = 3, units = {}, missionName = 'AAR' }
    -- },
    {
        striker = { baseGUID = '6Z8LM5-0HMIJ7B8971MA', weaponDBID = 2107, num = 12, units = {} },
        escort = nil,
        wildWeasel = nil,
        missionName = 'LAND STRIKE - NORTH - 4',
        area = { 'RP-8012', 'RP-8013', 'RP-8014', 'RP-8015' },
        hasLaunched = true,
        course = nil,
        tanker = nil
    },
}
CONFIG.c.aircraft.const.periodOfStrike = 40 * 60

if CONFIG.difficulty == 'normal' then
    CONFIG.c.aircraft.packages[5].hasLaunched = false
end


-- anti-ship
CONFIG.c.antiShip.isStrikeActivated = false
CONFIG.c.antiShip.packages = {
    {
        striker = { baseGUID = '6Z8LM5-0HMMJDEFRFJ4V', weaponDBID = 2137, num = 6, units = {} },
        -- escort = { baseGUID = '6Z8LM5-0HMMJDEFRFJ4V', weaponDBID = 3413, num = 6, units = {} },
        escort = nil,
        wildWeasel = { baseGUID = '6Z8LM5-0HMMJDEFRFJ4V', weaponDBID = 2875, num = 6, units = {} },
        missionName = 'NAVAL STRIKE - NORTH',
        area = { 'RP-44505', 'RP-44506', 'RP-44507', 'RP-44508' },
        hasLaunched = false,
        course = nil,
        tanker = nil
    }
}

-- air intercept
CONFIG.c.airIntercept.isStrikeActivated = false
CONFIG.c.airIntercept.packages = {
    {
        striker = { baseGUID = '6Z8LM5-0HMIJ7B896RA9', weaponDBID = 3413, num = 6, units = {} },
        escort = nil,
        wildWeasel = nil,
        missionName = 'AIR INTERCEPT - EAST',
        area = { 'RP-8008', 'RP-42688', 'RP-42687', 'RP-8011' },
        hasLaunched = false,
        -- course = {
        --     { lat = 'N 26.35.39', lon = 'E 119.51.22', desiredAltitude = 10668, desiredSpeed = 480 },
        --     { lat = 'N 25.36.59', lon = 'E 123.33.36', desiredAltitude = 200,   desiredSpeed = 480 },
        --     { lat = 'N 23.29.11', lon = 'E 123.11.14', desiredAltitude = 200,   desiredSpeed = 480 },
        -- },
        tanker = { baseGUID = '', num = 3, units = {}, missionName = 'AAR' }
    }
}


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
        },
        penghu = {
            horizontal = 80 - 90,
            vertical = 80,
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

-- SLCM
CONFIG.c.slcm.isStrikeActivated = false
CONFIG.c.slcm.const.submarines = {
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
        guid = 'IC8B0X-0HN2SEQ1UMG1U',
    },
    {
        guid = 'IC8B0X-0HN2SEQ1UMGC5',
    },
    -- {
    --     guid = 'X58F5H-0HMVKGABDLDR9',
    --     course = {
    --         { lat = 'N 21.45.32', lon = 'E 121.33.54', },
    --         { lat = 'N 21.49.32', lon = 'E 121.49.21', },
    --         { lat = 'N 21.14.09', lon = 'E 121.44.26', },
    --         { lat = 'N 21.20.35', lon = 'E 122.03.05', },
    --     },
    --     side = 'China',
    --     missionName = 'ASW - BASHI'
    -- },
    -- {
    --     guid = 'X58F5H-0HMVKL9MO16Q6',
    --     course = {
    --         { lat = 'N 24.38.48', lon = 'E 122.06.01', },
    --         { lat = 'N 25.04.38', lon = 'E 122.08.21', },
    --         { lat = 'N 24.25.01', lon = 'E 122.45.13', },
    --         { lat = 'N 25.04.20', lon = 'E 122.44.05', },
    --     },
    --     side = 'Taiwan',
    --     missionName = 'ASW - EAST'
    -- },
}
CONFIG.c.slcm.const.weaponDBID = 3716
CONFIG.c.slcm.const.baseGUID = '6Z8LM5-0HMIJ3QGCI783'
CONFIG.c.slcm.const.targetGUID = '6Z8LM5-0HMIJ7B89BCF3'

-- SRBM
CONFIG.t.srbm.isReloadActivated = true
CONFIG.t.srbm.const.position = {
    north = {
        assemblyArea = {
            area = { 'RP-44718', 'RP-44719', 'RP-44720', 'RP-44721' }
        },
        firingpositions = {
            {
                area = { 'RP-44300', 'RP-44301', 'RP-44302', 'RP-44303' }
            },
        },
        magazineWeapenNum = 18
    },
}
CONFIG.t.srbm.batteries = {
    {
        guid = 'X58F5H-0HMU9T3M6UVMN',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.t.srbm.const.position.north,
        weaponDBID = 779
    },
}
CONFIG.t.srbm.const.reloadTime = 40 * 60

-- GLCM
CONFIG.t.glcm.isReloadActivated = true
CONFIG.t.glcm.const.position = {
    north = {
        assemblyArea = {
            area = { 'RP-44294', 'RP-44295', 'RP-44296', 'RP-44297' }
        },
        firingpositions = {
            {
                area = { 'RP-44300', 'RP-44301', 'RP-44302', 'RP-44303' }
            },
        },
        magazineWeapenNum = 72
    },
    south = {
        assemblyArea = {
            area = { 'RP-44278', 'RP-44279', 'RP-44280', 'RP-44281' }
        },
        firingpositions = {
            {
                area = { 'RP-44288', 'RP-44289', 'RP-44290', 'RP-44291' }
            },
        },
        magazineWeapenNum = 72
    }
}
CONFIG.t.glcm.batteries = {
    {
        guid = 'X58F5H-0HN1ESDRTUULO',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.t.glcm.const.position.north,
        weaponDBID = 3228
    },
    {
        guid = 'X58F5H-0HN1ESDRTLGU7',
        reloadStartTime = nil,
        state = CONFIG.const.batteryState.RESUPPLY,
        position = CONFIG.t.glcm.const.position.south,
        weaponDBID = 3228
    }
}
CONFIG.t.glcm.const.reloadTime = 40 * 60


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





WCS = { wcsFree = 0, wcsTight = 1, wcsHold = 2 }

CONFIG.s.const.aircraftIsDestroyedOnTheGround = -10
CONFIG.s.const.destroyingAircraftOnTheGround = 5
CONFIG.s.const.aircraftIsDestroyedInHangar = -50
CONFIG.s.const.destroyingSupply = 100
CONFIG.s.const.lhd = 10
CONFIG.s.const.lst = 10
CONFIG.s.const.ddg = 10
CONFIG.s.const.cv = 100
CONFIG.s.const.ifv = -5
CONFIG.s.const.infantry = -3
CONFIG.s.const.samIsDestroyed = -20
CONFIG.s.const.sub = 15
CONFIG.s.const.uav = 20
CONFIG.s.const.mlrs = 20
CONFIG.s.const.weaponDBID = 905
CONFIG.s.const.attackBeforeTheHHour = -1000
CONFIG.s.const.msg = {
    tipForStart =
    '<h3>The initial blockade phase:</h3><ul><li>Use a submarine equipped with MK48s to sink the Chinese CSG entering Bachi Channel in order to break theblockade of the eastern waters of Taiwan.</li><li>Conduct an ASW mission in the northeastern waters of Taiwan.</li></ul><h3>ROE in this phase:</h3><ul><li>Any attacks on Chinese assets are not allowed.</li><li> Only submarines with MK-48s are allowed to attack Chinese surface ships or submarines, or ASW assets are allowed to attack Chinese submarines.</li></ul><p>(Victory Points will be subtracted if breaking the ROE.)</p>',
    attackBeforeTheHHour = '<p style="font-family:Microsoft JhengHei;">由於違反命令，在共軍對台灣發動總攻擊前攻擊共軍，造成了局勢升級。(扣1000分)</p>',
    tipForStartOfInvasion =
    '<h3>The Chinese air and land strike phase:</h3><ul><li>Disperse some air assets from airbases to contingency runways.</li><li>Break the kill chain of the Chinese ballistic missile strike by destroying UAVs such as WZ-8s or BZK-005s.</li><li>Find and destroy MLRS launchers on Pingtang Island.</li><li>Destroy helicopters such as Z-10s at army air bases.</li><li>Conserve SAMs and anti-ship missile launchers as much as possible to counter the subsequent Chinese amphibious landing.</li><li>Attempt to attack SAMs along the Chinese coast for further cruise missile attacks against enemy’s air assets at airfields.</li><li>Ground-launched cruise missile launchers can move into the assembly area and wait 40 minutes for reloading missiles if running out of munitions.</li></ul><h3>The Chinese amphibious landing phase:</h3><ul><li>Execute an anti-ship missile strike against Chinese amphibious ships.</li><li>Use LT-2000, HIMARS and AH-64 to destroy amphibious vehicles.</li><li>Use SAM and SHORAD systems to deal with air assault.</li></ul>'
}

--{ [1] = { mag_weapons = { [1] = { wpn_dbid = 3021, wpn_maxcap = 5, wpn_current = 0, wpn_default = 5, wpn_guid = 'X58F5H-0HN1BN6784FTC', wpn_name = 'BP-12A' }, [2] = { wpn_dbid = 2123, wpn_maxcap = 20, wpn_current = 0, wpn_default = 20, wpn_guid = 'X58F5H-0HN1BN6784FTD', wpn_name = 'SY-400 MLRS [Unitary]' } }, mag_dbid = 1795, mag_guid = 'X58F5H-0HN1BN6784FTB', mag_capacity = 25, mag_name = 'SY-400' } }

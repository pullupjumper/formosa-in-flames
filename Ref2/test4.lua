ScenEdit_RunScript('DeveloperMode.lua')

math.randomseed(os.time())
math.random()

-- =====================================
-- Set and Restore Scenario Variables --
-- =====================================

-- =========================
-- Set Variables on Scenario Load
-- =========================

function InitializeScenarioVariables()
    local variablesList = {
        { variable = 'PlayerNumbeOfUnitsDestroyed',          value = 0,                        persist = true, key = 'PlayerNumbeOfUnitsDestroyedKey' },
        { variable = 'PlayerCyberChance',                    value = 70,                       persist = true, key = 'PlayerCyberChanceKey' },
        { variable = 'PlayerCyberIncrement',                 value = 20,                       persist = true, key = 'PlayerCyberIncrementKey' },
        { variable = 'PlayerMissileDBID',                    value = 377,                      persist = true, key = 'PlayerMissileDBIDKey' }, -- UGM-109E Tomahawk Blk IV TACTOM
        { variable = 'PlayerNumberOfSSGNmissiles',           value = 48,                       persist = true, key = 'PlayerNumberOfSSGNmissilesKey' },
        { variable = 'PlayerNumberOfSSNmissiles',            value = 12,                       persist = true, key = 'PlayerNumberOfSSNmissilesKey' },

        { variable = 'IranNumberOfAircraftDetected',         value = 0,                        persist = true, key = 'IranNumberOfAircraftDetectedKey' },
        { variable = 'IranResetCommandAndControlCounter',    value = 0,                        persist = true, key = 'IranResetCommandAndControlCounter' },
        { variable = 'IranResetCommandAndControlChance',     value = 30,                       persist = true, key = 'IranResetCommandAndControlChanceKey' },
        { variable = 'IranResetCommandAndControlTime',       value = 60,                       persist = true, key = 'IranResetCommandAndControlTimeKey' },
        { variable = 'IranResetCommunicationsCounter',       value = 0,                        persist = true, key = 'IranResetCommunicationsCounterKey' },
        { variable = 'IranResetCommunicationsChance',        value = 30,                       persist = true, key = 'IranResetCommunicationsChanceKey' },
        { variable = 'IranResetCommunicationsTime',          value = 60,                       persist = true, key = 'IranResetCommunicationsTimeKey' },
        { variable = 'IranResetSensorsCounter',              value = 0,                        persist = true, key = 'IranResetSensorsCounterKey' },
        { variable = 'IranResetSensorsChance',               value = 30,                       persist = true, key = 'IranResetSensorsChanceKey' },
        { variable = 'IranResetSensorsTime',                 value = 60,                       persist = true, key = 'IranResetSensorsTimeKey' },

        { variable = 'SyriaNumberOfAircraftDetected',        value = 0,                        persist = true, key = 'SyriaNumberOfAircraftDetectedKey' },

        -- Variables only needed upon scenario initialization
        { variable = 'IranUnitPlacementOrUpgradeChance',     value = 60,                       persist = false },

        { variable = 'PlayerJordanOverflightChance',         value = 60,                       persist = false },
        { variable = 'PlayerTurkeyOverflightChance',         value = 30,                       persist = false },
        { variable = 'PlayerTurkeyWarnsIranChance',          value = 40,                       persist = false },
        { variable = 'PlayerEarlyPegasusDeliveryChance',     value = 40,                       persist = false },
        { variable = 'PlayerUSTankerSupportChance',          value = 60,                       persist = false },
        { variable = 'PlayerUSMissileSupportChance',         value = 60,                       persist = false },

        { variable = 'PlayerNumberOfTankers_1',              value = 11,                       persist = false },
        { variable = 'PlayerNumberOfTankers_2',              value = 14,                       persist = false },
        { variable = 'PlayerTankerDBID',                     value = 214,                      persist = false },
        { variable = 'PlayerTankerLoadoutID',                value = 8989,                     persist = false }, -- KC-10A Extender, 1982
        { variable = 'PlayerTankerBase',                     value = 'Al Dhafra AB',           persist = false },
        { variable = 'PlayerNumberOfTankersString',          value = 'FOUR',                   persist = false },
        { variable = 'PlayerTankerString',                   value = 'KC-10 TANKERS',          persist = false },
        { variable = 'PlayerTankerBaseString',               value = 'AL DHAFRA AIR BASE',     persist = false },
        { variable = 'PlayerTankerCountryString',            value = 'THE UNITED ARAB EMIRATES', persist = false },

        { variable = 'PlayerAdditionUnitsChance',            value = 70,                       persist = false },
        { variable = 'PlayerQatarBasingChance',              value = 70,                       persist = false },
        { variable = 'PlayerMuwaffaqSaltiBasingChance',      value = 70,                       persist = false },

        { variable = 'PlayerAlUdeidBomberCapacity',          value = 0,                        persist = false },
        { variable = 'PlayerAlUdeidFighterCapacity',         value = 0,                        persist = false },
        { variable = 'PlayerDiegoGarciaCapacity',            value = 24,                       persist = false },
        { variable = 'PlayerMuwaffaqSaltiFighterCapacity',   value = 0,                        persist = false },
        { variable = 'PlayerMuwaffaqSaltiRescueCapacity',    value = 0,                        persist = false },
        { variable = 'PlayerNumberOfEARSDeployed',           value = 0,                        persist = false },
        { variable = 'PlayerEARSDeployLimit',                value = 0,                        persist = false },
        { variable = 'PlayerNumberOfEBSDeployed',            value = 0,                        persist = false },
        { variable = 'PlayerEBSDeployLimit',                 value = 4,                        persist = false },
        { variable = 'PlayerNumberOfEFSDeployed',            value = 0,                        persist = false },
        { variable = 'PlayerEFSDeployLimit',                 value = 8,                        persist = false },
        { variable = 'PlayerNumberOfB2Deployed',             value = 0,                        persist = false },
        { variable = 'PlayerNumberOfF22Deployed',            value = 0,                        persist = false },
        { variable = 'PlayerNumberOfF35Deployed',            value = 0,                        persist = false },
        { variable = 'PlayerF35DeployLimit',                 value = 4,                        persist = false },
        { variable = 'PlayerDiegoGarciaTankerCallsignNumber1', value = 51,                     persist = false },
        { variable = 'PlayerDiegoGarciaTankerCallsignNumber2', value = 56,                     persist = false },
    }

    for _, v in ipairs(variablesList) do
        _G[v.variable] = v.value
        if v.persist then
            ScenEdit_SetKeyValue(v.key, tostring(v.value))
        end
    end

    -- =========================
    -- -- Initialize Tables
    -- =========================

    IranDisruptedCommandAndControlUnitList = {}
    IranDisruptedCommunicationsUnitList = {}
    IranFalseContactsList = {}

    storeData(IranDisruptedCommandAndControlUnitList, 'IranDisruptedCommandAndControlUnitListKey')
    storeData(IranDisruptedCommunicationsUnitList, 'IranDisruptedCommunicationsUnitListKey')
    storeData(IranFalseContactsList, 'IranFalseContactsListKey')

    -- =========================
    -- -- Tables that are only needed during scenario setup
    -- =========================

    baseStatus = {}

    overflight = {}

    IranAircraftToUpgrade_1 = {
        { num1 = 1, num2 = 12, name = '31 TFS #' }, -- F-4E Phantom II
        { num1 = 1, num2 = 12, name = '41 TFS #' }, -- F-5E Tiger II
        { num1 = 1, num2 = 12, name = '43 TFS #' }, -- F-5F Tiger II
        { num1 = 1, num2 = 6, name = '51 TFS #' }, -- F-7N Fishcan [MiG-21 Copy]
        { num1 = 1, num2 = 6, name = '52 TFS #' }, -- F-7N Fishcan [MiG-21 Copy]
        { num1 = 1, num2 = 6, name = '53 TFS #' }, -- F-7N Fishcan [MiG-21 Copy]
        { num1 = 1, num2 = 12, name = '64 TFS #' }, -- F-4D Phantom II
        { num1 = 1, num2 = 12, name = '91 TFS #' }, -- F-4E Phantom II
        { num1 = 1, num2 = 12, name = '101 TFS #' }, -- F-4D Phantom II
        { num1 = 1, num2 = 6, name = '141 TFS #' }, -- F-5E Tiger II
    }

    IranAircraftToUpgrade_2 = {
        { num1 = 1, num2 = 6, name = '11 TFS #' }, -- MiG-29A Fulcrum
        { num1 = 1, num2 = 12, name = '22 TFS #' }, -- MiG-29A Fulcrum
        { num1 = 1, num2 = 12, name = '81 TFS #' }, -- F-14A Tomcat
        { num1 = 1, num2 = 12, name = '82 TFS #' }, -- F-14A Tomcat
        { num1 = 1, num2 = 12, name = '83 TFS #' }, -- F-14A Tomcat
    }

    IranAircraftUpgradeOption_1A = {
        { dbid = 6614, chance = 100, loadoutID = 11076 }, -- Su-35S Flanker M - Iran, 2023
    }

    IranAircraftUpgradeOption_1B = {
        { dbid = 6614, chance = 80, loadoutID = 11076 }, -- Su-35S Flanker M - Iran, 2023
        { dbid = 6645, chance = 100, loadoutID = 31826 } -- Su-35S Flanker M - Russia, 2022 with AA-13 Arrow [R-37M]
    }

    IranAircraftUpgradeOption_2A = {
        -- J-10CE Firebird - Pakistan, 2022
        {
            dbid = 5521,
            chance = 100,
            loadouts = {
                { loadoutID = 23219, chance = 60 }, -- PL-12
                { loadoutID = 30510, chance = 100 } -- PL-15E
            }
        },
    }

    IranAircraftUpgradeOption_2B = {
        -- J-10CE Firebird - Pakistan, 2022
        {
            dbid = 5521,
            chance = 80,
            loadouts = {
                { loadoutID = 23219, chance = 60 }, -- PL-12
                { loadoutID = 30510, chance = 100 } -- PL-15E
            }
        },
        { dbid = 5259, chance = 100, loadoutID = 25177 } -- J-10C Firebird - China, 2019 with PL-15
    }

    IranAircraftUpgradeOption_3A = {
        { dbid = 6614, chance = 50, loadoutID = 11076 }, -- Su-35S Flanker M - Iran, 2023
        -- J-10CE Firebird - Pakistan, 2022
        {
            dbid = 5521,
            chance = 100,
            loadouts = {
                { loadoutID = 23219, chance = 60 }, -- PL-12
                { loadoutID = 30510, chance = 100 } -- PL-15E
            }
        },
    }

    IranAircraftUpgradeOption_3B = {
        { dbid = 6614, chance = 40, loadoutID = 11076 }, -- Su-35S Flanker M - Iran, 2023
        { dbid = 6645, chance = 50, loadoutID = 31826 }, -- Su-35S Flanker M - Russia, 2022 with AA-13 Arrow [R-37M]
        -- J-10CE Firebird - Pakistan, 2022
        {
            dbid = 5521,
            chance = 90,
            loadouts = {
                { loadoutID = 23219, chance = 60 }, -- PL-12
                { loadoutID = 30510, chance = 100 } -- PL-15E
            }
        },
        { dbid = 5259, chance = 100, loadoutID = 25177 } -- J-10C Firebird - China, 2019 with PL-15
    }

    IranAircraftUpgradeOption_4 = {
        -- Su-57 Felon - Russia
        {
            dbid = 2232,
            chance = 100,
            loadouts = {
                { loadoutID = 1770, chance = 60 },
                { loadoutID = 1779, chance = 100 }
            }
        },
    }

    IranAircraftUpgradeOption_5 = {
        -- F-14E Super Tomcat-21
        {
            dbid = 4174,
            chance = 70,
            loadouts = {
                { loadoutID = 21126, chance = 60 },
                { loadoutID = 21130, chance = 100 }
            }
        },
        { dbid = 5836, chance = 100, loadoutID = 31040 } -- F-14E Super Tomcat-21 Blk III
    }

    IranAircraftUpgradeOption_6 = {
        -- Su-57 Felon - Russia
        {
            dbid = 2232,
            chance = 50,
            loadouts = {
                { loadoutID = 1770, chance = 60 },
                { loadoutID = 1779, chance = 100 }
            }
        },
        -- F-14E Super Tomcat-21
        {
            dbid = 4174,
            chance = 75,
            loadouts = {
                { loadoutID = 21126, chance = 60 },
                { loadoutID = 21130, chance = 100 }
            }
        },
        { dbid = 5836, chance = 100, loadoutID = 31040 } -- F-14E Super Tomcat-21 Blk III
    }

    IranRandomAAA = {
        { dbid = 1815, name = 'AAA (100mm KS-19)',      shouldRemoveMounts = true, mounts = 5, numMountsToRemove = 3, MountDBID = 2074 },
        { dbid = 1814, name = 'AAA (100mm KS-19)',      shouldRemoveMounts = true, mounts = 5, numMountsToRemove = 3, MountDBID = 2073 },
        { dbid = 3750, name = 'AAA (57mm Bahman)',      shouldRemoveMounts = true, mounts = 4, numMountsToRemove = 3, MountDBID = 3884 },
        { dbid = 3749, name = 'AAA (57mm ZSU-57)',      shouldRemoveMounts = true, mounts = 4, numMountsToRemove = 3, MountDBID = 177 },
        { dbid = 2395, name = 'AAA (23mm ZSU-23 [BTR-60])', shouldRemoveMounts = true, mounts = 2, numMountsToRemove = 1, MountDBID = 2650 },
        { dbid = 909, name = 'AAA (23mm ZSU-23 [Shilka])', shouldRemoveMounts = true, mounts = 2, numMountsToRemove = 1, MountDBID = 329 },
        { dbid = 911, name = 'AAA (23mm ZU-23)',        shouldRemoveMounts = true, mounts = 2, numMountsToRemove = 1, MountDBID = 1032 },
        { dbid = 3738, name = 'AAA (23mm ZU-23)',       shouldRemoveMounts = true, mounts = 4, numMountsToRemove = 1, MountDBID = 3868 },
        { dbid = 912, name = 'AAA (35mm Twin Oerlikon)', shouldRemoveMounts = true, mounts = 2, numMountsToRemove = 1, MountDBID = 97 },
        { dbid = 910, name = 'AAA (35mm Twin Oerlikon)', shouldRemoveMounts = true, mounts = 3, numMountsToRemove = 1, MountDBID = 2397 },
    }

    IranAirDefensesToUpgrade = {
        { dbid = 3237 }, -- SAM Bn (AD-120 Talash)
        { dbid = 902 }, -- SAM Bn (HQ-2b)
        { dbid = 3756 }, -- SAM Bn (Sayyad-1)
        { dbid = 3813 }, -- SAM Bty (I-HAWK), 3x Launchers
        { dbid = 3238 }, -- SAM Bty (I-HAWK), 6x Launchers
    }

    IranRandomAirDefenses_1A = {
        { dbid = 3237, name = 'SAM Bn (AD-120 Talash)' }, -- SAM Bn (AD-120 Talash [Sayyad-2]), 2015
        { dbid = 3324, name = 'SAM Bn (Khordad 3)' }, -- SAM Bn (Khordad 3 [Taer 2B]), 2016, Sevom Khordad
        { dbid = 3783, name = 'SAM Bn (Khordad 15)' }, -- SAM Bn (Khordad 15 [Sayyad-3]), 2019, AD-75
        { dbid = 3756, name = 'SAM Bn (Sayyad-1)' }, -- SAM Bn (Sayyad-1A [Mod. HQ-2 Copy]), 2010
        { dbid = 3782, name = 'SAM Bn (Talash-3)' }, -- SAM Bn (Talash-3 [Sayyad-3]), 2018
        { dbid = 3229, name = 'SAM Bty (AD-200)' }, -- SAM Bty (AD-200 [Sayyad-4]), 2019, Bavar-373
        { dbid = 3813, name = 'SAM Bty (I-HAWK)' }, -- SAM Bty (I-HAWK [Mersad Upgrade]), 2014, 3x Launchers
        { dbid = 3238, name = 'SAM Bty (I-HAWK)' }, -- SAM Bty (I-HAWK [Mersad Upgrade]), 2014, 6x Launchers
        { dbid = 3780, name = 'SAM Bty (Joshan)' }, -- SAM Bty (Joshan), 2021, Sayyad-3
        -- {dbid=3744, name='SAM Bty (Karrar)'}, -- SAM Bty (6x Karrar), 2019
        { dbid = 3786, name = 'SAM Bty (Raad II)' }, -- SAM Bty (Raad II), 2014, Taer 2B
        { dbid = 3323, name = 'SAM Bty (Sevom Khordad)' }, -- SAM Bty (Sevom Khordad), 2016, Taer 2B
        { dbid = 3753, name = 'SAM Bty (Tabas)' } -- SAM Bty (Tabas), 2016, Taer 2B
    }

    IranRandomAirDefenses_1B = {
        { dbid = 3324, name = 'SAM Bn (Khordad 3)' }, -- SAM Bn (Khordad 3 [Taer 2B]), 2016, Sevom Khordad
        { dbid = 3783, name = 'SAM Bn (Khordad 15)' }, -- SAM Bn (Khordad 15 [Sayyad-3]), 2019, AD-75
        { dbid = 3782, name = 'SAM Bn (Talash-3)' }, -- SAM Bn (Talash-3 [Sayyad-3]), 2018
        { dbid = 3229, name = 'SAM Bty (AD-200)' }, -- SAM Bty (AD-200 [Sayyad-4]), 2019, Bavar-373
        { dbid = 3780, name = 'SAM Bty (Joshan)' }, -- SAM Bty (Joshan), 2021, Sayyad-3
        -- {dbid=3744, name='SAM Bty (Karrar)'}, -- SAM Bty (6x Karrar), 2019
        { dbid = 3786, name = 'SAM Bty (Raad II)' }, -- SAM Bty (Raad II), 2014, Taer 2B
        { dbid = 3323, name = 'SAM Bty (Sevom Khordad)' }, -- SAM Bty (Sevom Khordad), 2016, Taer 2B
        { dbid = 3753, name = 'SAM Bty (Tabas)' } -- SAM Bty (Tabas), 2016, Taer 2B
    }

    IranRandomAirDefenses_2A = {
        { dbid = 3237, name = 'SAM Bn (AD-120 Talash)' }, -- SAM Bn (AD-120 Talash [Sayyad-2]), 2015
        { dbid = 3280, name = 'SAM Bn (HQ-9)' }, -- SAM Bn (HQ-9B), China, 2010
        { dbid = 1277, name = 'SAM Bn (HQ-12)' }, -- SAM Bn (HQ-12), China, 2008
        { dbid = 3324, name = 'SAM Bn (Khordad 3)' }, -- SAM Bn (Khordad 3 [Taer 2B]), 2016, Sevom Khordad
        { dbid = 3783, name = 'SAM Bn (Khordad 15)' }, -- SAM Bn (Khordad 15 [Sayyad-3]), 2019, AD-75
        { dbid = 3013, name = 'SAM Bn (SA-20 Gargoyle)' }, -- SAM Bn (SA-20b Gargoyle [S-300PMU-2 Favorit]), Iran, 2016
        { dbid = 3756, name = 'SAM Bn (Sayyad-1)' }, -- SAM Bn (Sayyad-1A [Mod. HQ-2 Copy]), 2010
        { dbid = 3782, name = 'SAM Bn (Talash-3)' }, -- SAM Bn (Talash-3 [Sayyad-3]), 2018
        { dbid = 3229, name = 'SAM Bty (AD-200)' }, -- SAM Bty (AD-200 [Sayyad-4]), 2019, Bavar-373
        { dbid = 2991, name = 'SAM Bty (HQ-16)' }, -- SAM Bty (HQ-16B), China, 2016
        { dbid = 3813, name = 'SAM Bty (I-HAWK)' }, -- SAM Bty (I-HAWK [Mersad Upgrade]), 2014, 3x Launchers
        { dbid = 3238, name = 'SAM Bty (I-HAWK)' }, -- SAM Bty (I-HAWK [Mersad Upgrade]), 2014, 6x Launchers
        -- {dbid=3744, name='SAM Bty (Karrar)'}, -- SAM Bty (6x Karrar), 2019
        { dbid = 3780, name = 'SAM Bty (Joshan)' }, -- SAM Bty (Joshan), 2021, Sayyad-3
        { dbid = 3757, name = 'SAM Plt (SA-17 Grizzly)' }, -- SAM Plt (SA-17 Grizzly [9K317E Buk-M2E]), Iran
        { dbid = 2276, name = 'SAM Plt (SA-27 Grizzly)' }, -- SAM Plt (SA-27 Grizzly [9K317M Buk-M3]), Russia, 2018
        { dbid = 3786, name = 'SAM Bty (Raad II)' }, -- SAM Bty (Raad II), 2014, Taer 2B
        { dbid = 3323, name = 'SAM Bty (Sevom Khordad)' }, -- SAM Bty (Sevom Khordad), 2016, Taer 2B
        { dbid = 3753, name = 'SAM Bty (Tabas)' } -- SAM Bty (Tabas), 2016, Taer 2B
    }

    IranRandomAirDefenses_2B = {
        { dbid = 3280, name = 'SAM Bn (HQ-9)' }, -- SAM Bn (HQ-9B), China, 2010
        { dbid = 1277, name = 'SAM Bn (HQ-12)' }, -- SAM Bn (HQ-12), China, 2008
        { dbid = 3324, name = 'SAM Bn (Khordad 3)' }, -- SAM Bn (Khordad 3 [Taer 2B]), 2016, Sevom Khordad
        { dbid = 3783, name = 'SAM Bn (Khordad 15)' }, -- SAM Bn (Khordad 15 [Sayyad-3]), 2019, AD-75
        { dbid = 3013, name = 'SAM Bn (SA-20 Gargoyle)' }, -- SAM Bn (SA-20b Gargoyle [S-300PMU-2 Favorit]), Iran, 2016
        { dbid = 3782, name = 'SAM Bn (Talash-3)' }, -- SAM Bn (Talash-3 [Sayyad-3]), 2018
        { dbid = 3229, name = 'SAM Bty (AD-200)' }, -- SAM Bty (AD-200 [Sayyad-4]), 2019, Bavar-373
        { dbid = 2991, name = 'SAM Bty (HQ-16)' }, -- SAM Bty (HQ-16B), China, 2016
        -- {dbid=3744, name='SAM Bty (Karrar)'}, -- SAM Bty (6x Karrar), 2019
        { dbid = 3780, name = 'SAM Bty (Joshan)' }, -- SAM Bty (Joshan), 2021, Sayyad-3
        { dbid = 3757, name = 'SAM Plt (SA-17 Grizzly)' }, -- SAM Plt (SA-17 Grizzly [9K317E Buk-M2E]), Iran
        { dbid = 2276, name = 'SAM Plt (SA-27 Grizzly)' }, -- SAM Plt (SA-27 Grizzly [9K317M Buk-M3]), Russia, 2018
        { dbid = 3786, name = 'SAM Bty (Raad II)' }, -- SAM Bty (Raad II), 2014, Taer 2B
        { dbid = 3323, name = 'SAM Bty (Sevom Khordad)' }, -- SAM Bty (Sevom Khordad), 2016, Taer 2B
        { dbid = 3753, name = 'SAM Bty (Tabas)' } -- SAM Bty (Tabas), 2016, Taer 2B
    }

    IranRandomSHORAD = {
        { dbid = 901, name = 'SAM Bn (SA-6 Gainful)',  shouldRemoveMounts = false }, -- SAM Bn (SA-6a Gainful [2K12E Kvadrat]), 1991
        { dbid = 3784, name = 'SAM Plt (Dezful)',      shouldRemoveMounts = false }, -- SAM Plt (Dezful [Mod. 9K330 Tor-M1K Copy]), 2021
        { dbid = 481, name = 'SAM Plt (SA-15 Gauntlet)', shouldRemoveMounts = false }, -- SAM Plt (SA-15b Gauntlet [9K330 Tor-M1K]), 2008
        { dbid = 3758, name = 'SAM Plt (SA-22 Greyhound)', shouldRemoveMounts = false }, -- SAM Plt (SA-22 Greyhound [Pantsir-S1E]), 2012
        { dbid = 3815, name = 'SAM Plt (Zoubin)',      shouldRemoveMounts = false }, -- SAM Plt (Zoubin TELAR x 2), 2021
        { dbid = 3781, name = 'SAM Sec (AD-08 Majid)', shouldRemoveMounts = false }, -- SAM Sec (AD-08 Majid x 2), 2021
        { dbid = 3752, name = 'SAM Sec (Herz-9)',      shouldRemoveMounts = false }, -- SAM Sec (Herz-9 x 2), 2014
        { dbid = 3044, name = 'SAM Sec (YZ-3)',        shouldRemoveMounts = false }, -- SAM Sec (YZ-3 [Ya Zahra-3] x 2), 2014
    }

    IranRadarsToUpgrade = {
        { dbid = 1047, replaceChance = 70 }, -- Radar (AN/TPS-70)
        { dbid = 1227, replaceChance = 30 }, -- Radar (China JY-14 Great Wall)
        { dbid = 1342, replaceChance = 70 }, -- Radar (Spoon Rest D [P-18])
    }

    IranRandomRadars_1 = {
        { dbid = 4106, name = 'Radar (67N6E Gamma-DE [Falaq])' }, -- Radar (67N6E Gamma-DE [Falaq]), Iran, 2019
        { dbid = 3325, name = 'Radar (Bashir)' },            -- Radar (Bashir), Iran, 2016
        { dbid = 1849, name = 'Radar (Box Spring [1L119 Nebo SVU])' }, -- Radar (1L119 Nebo SVU), Iran, 2010
        { dbid = 3930, name = 'Radar (Flat Face E [39N6E Kasta 2E2])' }, -- Radar (Flat Face E [39N6E Kasta 2E2], Iran, 2017
        { dbid = 3236, name = 'Radar (Najm-802 PESA)' },     -- Radar (Najm-802 PESA), Iran, 2015
        { dbid = 3418, name = 'Radar (Quds [Vostok E])' },   -- Radar (Quds [Vostok E]), Iran, 2021
    }

    IranRandomRadars_2 = {
        { dbid = 3933, name = 'Radar (12A6 SOPKA-2)' },      -- Radar (12A6 SOPKA-2), Russia, 2014
        { dbid = 2257, name = 'Radar (59N6 Protivnik-GE)' }, -- Radar (59N6 Protivnik-GE), Russia, 2000
        { dbid = 4106, name = 'Radar (67N6E Gamma-DE [Falaq])' }, -- Radar (67N6E Gamma-DE [Falaq]), Iran, 2019
        { dbid = 3325, name = 'Radar (Bashir)' },            -- Radar (Bashir), Iran, 2016
        { dbid = 439, name = 'Radar (Big Bird C [64N6])' },  -- Radar (Big Bird C [64N6], Russia, 1994
        { dbid = 2443, name = 'Radar (Big Bird D [91N6])' }, -- Radar (Big Bird D [91N6], Russia, 2008
        { dbid = 1849, name = 'Radar (Box Spring [1L119 Nebo SVU])' }, -- Radar (1L119 Nebo SVU), Iran, 2010
        { dbid = 2735, name = 'Radar (Cheese Board [96L6E])' }, -- Radar (Cheese Board [96L6E]), Russia, 2008
        { dbid = 2537, name = 'Radar (China JY-26)' },       -- Radar (China JY-26), China, 2015
        { dbid = 3419, name = 'Radar (China JY-27A Wide Mat)' }, -- Radar (China JY-27A Wide Mat), China
        { dbid = 3599, name = 'Radar (China YLC-2V [High Guard])' }, -- Radar (China YLC-2V [High Guard]), China, 2015
        { dbid = 2538, name = 'Radar (China YLC-8B)' },      -- Radar (China YLC-8B), China
        { dbid = 3819, name = 'Radar (China YLC-8E)' },      -- Radar (China YLC-8E), China, 2022
        { dbid = 3930, name = 'Radar (Flat Face E [39N6E Kasta 2E2]' }, -- Radar (Flat Face E [39N6E Kasta 2E2], Iran, 2017
        { dbid = 3236, name = 'Radar (Najm-802 PESA)' },     -- Radar (Najm-802 PESA), Iran, 2015
        { dbid = 3519, name = 'Radar (Prima [P-18-2])' },    -- Radar (Prima [P-18-2]), Russia, 2019
        { dbid = 3418, name = 'Radar (Quds [Vostok E])' },   -- Radar (Quds [Vostok E]), Iran, 2021
        { dbid = 1616, name = 'Radar (Tall Rack [55Zh6-1 Nebo UYe])' }, -- Radar (Tall Rack [55Zh6-1 Nebo UYe]), Russia, 20XX
        { dbid = 1847, name = 'Radar (Tall Rack [55Zh6M Nebo M])' }, -- Radar (Tall Rack [55Zh6M Nebo M, RLM-D L-Band]), Russia, 2015
        { dbid = 1846, name = 'Radar (Tall Rack [55Zh6M Nebo M])' }, -- Radar (Tall Rack [55Zh6M Nebo M, RLM-M VHF-Band]), Russia, 2015
        { dbid = 3869, name = 'Radar (Tall Rack [55Zh6UME Nebo UME])' }, -- Tall Rack [55Zh6UME Nebo UME]), Russia, 2019
    }
end

-- =========================
-- Restore Variables on Scenario Reload
-- =========================

function RestoreScenarioVariables()
    local variablesList = {
        { variable = 'PlayerNumbeOfUnitsDestroyed',     key = 'PlayerNumbeOfUnitsDestroyedKey' },
        { variable = 'PlayerCyberChance',               key = 'PlayerCyberChanceKey' },
        { variable = 'PlayerCyberIncrement',            key = 'PlayerCyberIncrementKey' },
        { variable = 'PlayerMissileDBID',               key = 'PlayerMissileDBIDKey' }, -- UGM-109E Tomahawk Blk IV TACTOM
        { variable = 'PlayerNumberOfSSGNmissiles',      key = 'PlayerNumberOfSSGNmissilesKey' },
        { variable = 'PlayerNumberOfSSNmissiles',       key = 'PlayerNumberOfSSNmissilesKey' },

        { variable = 'IranNumberOfAircraftDetected',    key = 'IranNumberOfAircraftDetectedKey' },
        { variable = 'IranResetCommandAndControlCounter', key = 'IranResetCommandAndControlCounterKey' },
        { variable = 'IranResetCommandAndControlChance', key = 'IranResetCommandAndControlChanceKey' },
        { variable = 'IranResetCommandAndControlTime',  key = 'IranResetCommandAndControlTimeKey' },
        { variable = 'IranResetCommunicationsCounter',  key = 'IranResetCommunicationsCounterKey' },
        { variable = 'IranResetCommunicationsChance',   key = 'IranResetCommunicationsChanceKey' },
        { variable = 'IranResetCommunicationsTime',     key = 'IranResetCommunicationsTimeKey' },
        { variable = 'IranResetSensorsCounter',         key = 'IranResetSensorsCounterKey' },
        { variable = 'IranResetSensorsChance',          key = 'IranResetSensorsChanceKey' },
        { variable = 'IranResetSensorsTime',            key = 'IranResetSensorsTimeKey' },

        { variable = 'SyriaNumberOfAircraftDetected',   key = 'SyriaNumberOfAircraftDetectedKey' },

        { variable = 'GlobalMinTemp',                   key = 'GlobalMinTempKey' },
        { variable = 'GlobalMaxTemp',                   key = 'GlobalMaxTempKey' },
    }

    -- Restore the values from the key store
    for _, v in ipairs(variablesList) do
        local value = ScenEdit_GetKeyValue(v.key)

        -- Check if the value is numeric to convert it
        if tonumber(value) then
            _G[v.variable] = tonumber(value)
        else
            _G[v.variable] = value
        end
    end

    IranDisruptedCommandAndControlUnitList = {}
    IranDisruptedCommunicationsUnitList = {}
    IranFalseContactsList = {}

    setGlobalFromKeyStore('IranDisruptedCommandAndControlUnitList', 'IranDisruptedCommandAndControlUnitListKey')
    setGlobalFromKeyStore('IranDisruptedCommunicationsUnitList', 'IranDisruptedCommunicationsUnitListKey')
    setGlobalFromKeyStore('IranFalseContactsList', 'IranFalseContactsListKey')

    if SearchAndRescueEnabled() then
        CargoAircraftList = {
            { side = 'Israel', name = '103 Sqd. #1', minAltitude = 500, landingSpeed = 210, TimeToReady = 30 },
            { side = 'Israel', name = '103 Sqd. #2', minAltitude = 500, landingSpeed = 210, TimeToReady = 30 },
            { side = 'Israel', name = '103 Sqd. #3', minAltitude = 500, landingSpeed = 210, TimeToReady = 30 },
            { side = 'Israel', name = '103 Sqd. #4', minAltitude = 500, landingSpeed = 210, TimeToReady = 30 },
            -- Add more aircrafts as needed
        }

        rescueCapableUnits = {
            aircraft = {
                4365, -- HH-60G Credible Hawk
                4366, -- HH-60W Jolly Green II
                5337, -- MH-60S Knighthawk
                5338, -- MH-60R Seahawk
                4732 -- CH-53C Sea Stallion [Yasur 2025]
                -- Add or remove aircraft entries as required
            },
            ship = {
                -- Add or remove ship entries as required
            },
            submarine = {
                -- Add or remove submarine entries as required
            },
            facility = {
                -- Add or remove facility entries as required
            }
        }

        RescueCapableUnitsList = GenerateListOfRescueUnits() -- Name must match the name used in the GetListOfRescueUnitsNearSurvivors function, Initialize at scenario setup and reload
        SurvivorList = GenerateListOfSurvivorUnits('Survivors') -- Name must match thise used in the CSAR functions, Initialize at scenario setup and reload
    end
end

-- ===========================
-- Scenario Setup Functions --
-- ===========================

-- =========================
-- Israel Aircraft Setup
-- =========================

function IsraelAircraftSetup()
    local PlayerSide = ScenEdit_PlayerSide()
    local AircraftList = {
        { num1 = 1, num2 = 8, name = '120 Sqd.', loadoutID = 8280 }, -- Boeing 707-320 Tanker [KC-707 Saknayee]
        { num1 = 9, num2 = 10, name = '120 Sqd.', loadoutID = 8274 }, -- Boeing 707 Phalcon AEW
        { num1 = 1, num2 = 2, name = '122 Sqd.', loadoutID = 8633 }, -- Gulfstream G550 AEW [Nahshon-Eitan, CAEW]
        { num1 = 3, num2 = 5, name = '122 Sqd.', loadoutID = 15776 }, -- Gulfstream G550 AEW [Nahshon-Shavit, SEMA]
        { num1 = 1, num2 = 20, name = '200 Sqd.', loadoutID = 9044 }, -- Heron UAV [Shoval]
    }

    for k, v in ipairs(AircraftList) do
        for i = v.num1, v.num2 do
            ScenEdit_SetLoadout({ side = PlayerSide, name = v.name .. ' #' .. i, LoadoutID = v.loadoutID, TimeToReady_Minutes = 0 })
        end
    end
end

-- =========================
-- United States Aircraft Setup
-- =========================

function UnitedStatesAircraftSetup()
    -- Set aircraft loadouts
    local PlayerSide = ScenEdit_PlayerSide()
    local AircraftList = {
        -- E-2D Advanced Hawkeye
        { num1 = 600, num2 = 604, name = 'SEAHAWK', loadoutID = 14629 },
        -- E-3C Sentry
        { num1 = 11, num2 = 14, name = 'SENTRY',  loadoutID = 8076 },
        -- E-8C Joint STARS
        { num1 = 21, num2 = 21, name = 'STRIKE STAR', loadoutID = 8091 },
        -- EC-130H Compass Call
        { num1 = 31, num2 = 32, name = 'ZAPPER',  loadoutID = 14471 },
        -- KC-10A Extender
        { num1 = 21, num2 = 24, name = 'MOBILE',  loadoutID = 8989 },
        { num1 = 31, num2 = 34, name = 'MOBILE',  loadoutID = 8989 },
        { num1 = 41, num2 = 44, name = 'MOBILE',  loadoutID = 8989 },
        { num1 = 51, num2 = 56, name = 'MOBILE',  loadoutID = 8989 },
        -- KC-135R Stratotanker
        { num1 = 11, num2 = 14, name = 'EXXON',   loadoutID = 32850 },
        { num1 = 21, num2 = 24, name = 'EXXON',   loadoutID = 19801 },
        { num1 = 31, num2 = 34, name = 'EXXON',   loadoutID = 19801 },
        { num1 = 41, num2 = 44, name = 'SHELL',   loadoutID = 32850 },
        { num1 = 51, num2 = 54, name = 'SHELL',   loadoutID = 19801 },
        { num1 = 61, num2 = 64, name = 'SHELL',   loadoutID = 19801 },
        { num1 = 71, num2 = 74, name = 'TEXACO',  loadoutID = 32850 },
        { num1 = 81, num2 = 84, name = 'TEXACO',  loadoutID = 19801 },
        { num1 = 91, num2 = 94, name = 'TEXACO',  loadoutID = 19801 },
        -- RC-135W Rivet Joint
        { num1 = 11, num2 = 12, name = 'HUNTER',  loadoutID = 8824 },
        -- RQ-4B Global Hawk
        { num1 = 61, num2 = 62, name = 'HAWK',    loadoutID = 13988 },
    }

    for _, v in ipairs(AircraftList) do
        for i = v.num1, v.num2 do
            ScenEdit_SetLoadout({ side = PlayerSide, name = v.name .. ' ' .. i, LoadoutID = v.loadoutID, TimeToReady_Minutes = 0 })
        end
    end

    -- Add random UAV
    local PlayerSide = ScenEdit_PlayerSide()
    local unitOptions = {
        [1] = {
            dbid = 2787,
            loadoutid = 13408,
            description = "RQ-170A Wraith [Sentinel] UAV, 2002"
        },
        [2] = {
            dbid = 4328,
            loadoutid = 22066,
            description = "RQ-180 UAV, 2016"
        }
    }

    for i = 1, 4 do
        local choice = math.random(1, 100) <= 50 and 1 or 2
        local unit = unitOptions[choice]
        ScenEdit_AddUnit({
            side = PlayerSide,
            type = 'Aircraft',
            name = 'WRAITH 9' .. i,
            dbid = unit.dbid,
            base = 'Al Dhafra AB',
            loadoutid = unit.loadoutid
        })
    end
end

-- =========================
-- Iran Random SHORAD
-- =========================

function IranPlaceRandomSHORAD()
    local IranFacilityList = {
        { name = 'Arak',  num = math.random(4, 8) },
        { name = 'Esfahãn', num = math.random(4, 12) },
        { name = 'Fordow', num = math.random(4, 8) },
        { name = 'Natanz', num = math.random(4, 8) }
    }

    for _, facility in ipairs(IranFacilityList) do
        local centerpoint = ScenEdit_GetReferencePoint({ side = 'Iran', name = facility.name })
        AddRandomFacility_RandomPosition('Iran', facility.num, IranUnitPlacementOrUpgradeChance, IranRandomSHORAD,
            { latitude = centerpoint.latitude, longitude = centerpoint.longitude }, 1, 95)
    end
end

-- =========================
-- Iran Aircraft Setup
-- =========================

function IranAircraftSetup()
    local AircraftList = {
        { defaultDBID = 1346, num1 = 1, num2 = 6, name = '11 TFS', hypotheticalUnit = true, newDBID = 6728, loadoutID_1 = 5281, loadoutID_2 = 33011 }, -- MiG-29 Fulcrum A, default
        { defaultDBID = 1346, num1 = 1, num2 = 12, name = '22 TFS', hypotheticalUnit = true, newDBID = 6728, loadoutID_1 = 5281, loadoutID_2 = 33011 }, -- MiG-29 Fulcrum A, default
        { defaultDBID = 6997, num1 = 1, num2 = 12, name = '41 TFS', hypotheticalUnit = false, loadoutID_1 = 4691, loadoutID_2 = 32342 }, -- F-5E Tiger II, default
        { defaultDBID = 6998, num1 = 1, num2 = 12, name = '43 TFS', hypotheticalUnit = false, loadoutID_1 = 4691, loadoutID_2 = 32342 }, -- F-5F Tiger II, default
        { defaultDBID = 6997, num1 = 1, num2 = 6, name = '141 TFS', hypotheticalUnit = false, loadoutID_1 = 4691, loadoutID_2 = 32342 }, -- F-5E Tiger II
    }

    for _, aircraftData in ipairs(AircraftList) do
        -- Retrieve the first unit of the squadron by name
        local unit = ScenEdit_GetUnit({ side = 'Iran', name = aircraftData.name .. ' #1' })

        -- Proceed only if the unit exists and matches the default DBID
        if unit and unit.dbid == aircraftData.defaultDBID then
            local AircraftLoadout = aircraftData.loadoutID_1 -- Default loadout

            -- Roll for randomization based on placement or upgrade chance
            if math.random(1, 100) <= IranUnitPlacementOrUpgradeChance then
                if aircraftData.hypotheticalUnit == true and IranUseHypotheticalLoadouts() then
                    -- Hypothetical unit with UseHypotheticalLoadouts enabled: replace with new DBID and random loadout
                    AircraftLoadout = RandomizeAircraftLoadouts(70, aircraftData.loadoutID_1, aircraftData.loadoutID_2)
                    ReplaceAircraft_ByName('Iran', aircraftData.num1, aircraftData.num2, aircraftData.newDBID,
                        aircraftData.name .. ' #', AircraftLoadout, 0)
                elseif aircraftData.hypotheticalUnit == true then
                    SetAircraftLoadouts('Iran', aircraftData.num1, aircraftData.num2, aircraftData.name .. ' #',
                        AircraftLoadout, 0, true)
                else
                    -- Non-hypothetical unit: roll random loadout
                    AircraftLoadout = RandomizeAircraftLoadouts(70, aircraftData.loadoutID_1, aircraftData.loadoutID_2)
                    SetAircraftLoadouts('Iran', aircraftData.num1, aircraftData.num2, aircraftData.name .. ' #',
                        AircraftLoadout, 0, true)
                end
            else
                SetAircraftLoadouts('Iran', aircraftData.num1, aircraftData.num2, aircraftData.name .. ' #',
                    AircraftLoadout, 0, true)
            end
        end
    end
end

-- =========================
-- Iran Set Ready Times
-- =========================

function IranSideSetup(min, max)
    IranAircraftSetup()

    ScenEdit_SetMission('Iran', 'CAP Center East', { isactive = true })
    ScenEdit_SetMission('Iran', 'CAP Center West 1', { isactive = true })
    ScenEdit_SetMission('Iran', 'CAP Center West 2', { isactive = true })
    ScenEdit_SetMission('Iran', 'CAP North', { isactive = true })
    ScenEdit_SetMission('Iran', 'CAP South', { isactive = true })
    ScenEdit_SetMission('Iran', 'CAP Southeast', { isactive = true })
    ScenEdit_SetMission('Iran', 'CAP Southwest', { isactive = true })

    SetAircraftTimeToReady_ByMission('Iran', 'CAP Center East', GetRandomRoundedNumber(min, max, 5))
    SetAircraftTimeToReady_ByMission('Iran', 'CAP Center West 1', GetRandomRoundedNumber(min, max, 5))
    SetAircraftTimeToReady_ByMission('Iran', 'CAP Center West 2', GetRandomRoundedNumber(min, max, 5))
    SetAircraftTimeToReady_ByMission('Iran', 'CAP North', GetRandomRoundedNumber(min, max, 5))
    SetAircraftTimeToReady_ByMission('Iran', 'CAP South', GetRandomRoundedNumber(min, max, 5))
    SetAircraftTimeToReady_ByMission('Iran', 'CAP Southeast', GetRandomRoundedNumber(min, max, 5))
    SetAircraftTimeToReady_ByMission('Iran', 'CAP Southwest', GetRandomRoundedNumber(min, max, 5))
end

-- =========================
-- Scenario Setup
-- =========================

function ScenarioSetup()
    local PlayerSide = ScenEdit_PlayerSide()
    if PlayerSide == 'Israel' then
        -- Setup player side
        IsraelScenarioSetupOptions()
        ScenEdit_SpecialMessage('Israel', '[LOADDOC]IranStrike_2022_Israel_Gameplay_Notes.html[/LOADDOC]')

        SetAircraftReadiness_BySide(PlayerSide, 0)                                                                               -- Set all aicraft on playerside to ready
        IsraelAircraftSetup()                                                                                                    -- Set default loadouts for applicable aircraft
        AddAircraft(PlayerSide, PlayerNumberOfTankers_1, PlayerNumberOfTankers_2, PlayerTankerDBID, 'MOBILE ',
            PlayerTankerBase, 4, 0)                                                                                              -- Add supporting US tankers, set unavailable until requested

        -- Delete unneeded units and side
        -- Do not delete USA side, hosts supporting units
        DeleteAllUnitsOnSide_ByType('United States', 'Aircraft')
        DeleteAllUnitsOnSide_ByType('United States', 'Ship')
        ScenEdit_RemoveSide({ name = 'Task Force 50' })
        ScenEdit_RemoveSide({ name = 'United States-Israel' })

        -- Set Iranian aircraft loadouts and ready times
        IranSideSetup(120, 240)
        -- elseif PlayerSide == 'United States' then
        -- Setup player side
        -- USA_ScenarioSetupOptions()
        -- SetAircraftReadiness_BySide(PlayerSide, 0) -- Set all aicraft on playerside to ready
        -- USA_AircraftSetup() -- Set all aicraft on playerside to ready

        -- Delete unneeded sides
        -- ScenEdit_RemoveSide({name='Israel'})
        -- ScenEdit_RemoveSide({name='Syria'})
        -- ScenEdit_RemoveSide({name='United States-Israel'})

        -- Turn off unneded events
        -- ScenEdit_SetEvent('Syria Detects Aircraft', {isActive=false})

        -- Set Iranian aircraft loadouts and ready times
        -- IranSideSetup(0, 90)
        -- elseif PlayerSide == 'United States-Israel' then
        -- Setup player side
        -- USA_Israel_ScenarioSetupOptions()
        -- ChangeUnitSide('Israel', 'United States-Israel')
        -- ChangeUnitSide('United States', 'United States-Israel')
        -- SetAircraftReadiness_BySide(PlayerSide, 0) -- Set all aicraft on playerside to ready
        -- Israel_AircraftSetup() -- Set Israel aicraft on playerside to ready
        -- USA_AircraftSetup() -- Set USA aicraft on playerside to ready
        -- ScenEdit_AssignUnitToMission('DESRON 28 (TU 50.1.2)', 'DESRON Patrol')

        -- Delete unneeded sides
        -- ScenEdit_RemoveSide({name='Israel'})
        -- ScenEdit_RemoveSide({name='United States'})

        -- Set Iranian aircraft loadouts and ready times
        -- IranSideSetup(0, 240)
    end
end

-- =========================
-- Randomize Weather
-- =========================

function RandomizeWeather()
    -- Randomize min/max temperature
    local variablesList = {
        { variable = 'GlobalMinTemp', value = RandomTemperature(21, 24, 18, 28, 30, 4, 2), key = 'GlobalMinTempKey' },
        { variable = 'GlobalMaxTemp', value = RandomTemperature(31, 35, 28, 38, 30, 4, 2), key = 'GlobalMaxTempKey' },
    }

    for _, v in ipairs(variablesList) do
        _G[v.variable] = v.value
        ScenEdit_SetKeyValue(v.key, tostring(v.value))
    end

    -- Randomize current global weather conditions
    local GlobalTemp = RandomTemperature(30, 34, 28, 35, 30, 4, 2)
    local GlobalUnderCloud = RandomUndercloud(0, 4, 0, 10, 30, 4, 2)
    local GlobalRainfall = RandomRainfall(0, 0, 0, 10, 30, 4, 2, GlobalUnderCloud)
    local GlobalSeastate = RandomSeastate(2, 3, 0, 3, 30, 4, 2)

    -- Update global weather conditions
    ScenEdit_SetWeather(
        GlobalTemp, -- temp
        GlobalUnderCloud, -- rainfall
        GlobalRainfall, -- undercloud
        GlobalSeastate -- seastate
    )
end

-- ==========================
-- Scenario Initialization --
-- ==========================

function ThisIsFirstLoad(booleanValue)
    local result
    if booleanValue == nil then
        result = ScenEdit_GetKeyValue('firstLoad')
        if result == '' or result == nil then result = true end
        if result == 'false' then result = false end
    else
        if booleanValue == true then
            ScenEdit_ClearKeyValue('firstLoad')
            result = true
        elseif booleanValue == false then
            ScenEdit_SetKeyValue('firstLoad', 'false')
            result = false
        end
    end
    return result
end

if ThisIsFirstLoad() then
    math.randomseed(os.time())
    local PlayerSide = ScenEdit_PlayerSide()
    if inDevelopment then -- Ask to do stuff
        userInput = string.upper(ScenEdit_MsgBox('Initialize variables?', 1))
        if userInput == 'OK' then
            InitializeScenarioVariables()
        end

        userInput = string.upper(ScenEdit_MsgBox('Execute scenario setup?', 1))
        if userInput == 'OK' then
            ScenarioSetup()
        end

        userInput = string.upper(ScenEdit_MsgBox('Place random Iranian SHORAD?', 1))
        if userInput == 'OK' then
            IranPlaceRandomSHORAD()
        end

        userInput = string.upper(ScenEdit_MsgBox('Randomize weather?', 1))
        if userInput == 'OK' then
            RandomizeWeather()
        end

        userInput = string.upper(ScenEdit_MsgBox('Set firstLoad key value to false?', 1))
        if userInput == 'OK' then
            ThisIsFirstLoad(false)
        end
    else -- Don't give the option and just do it
        InitializeScenarioVariables()
        ScenarioSetup()
        IranPlaceRandomSHORAD()
        RandomizeWeather()
        ThisIsFirstLoad(false)
    end
else
    RestoreScenarioVariables()
end

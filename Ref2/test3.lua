math.randomseed(os.time())
math.random()

-- ===========================
-- Scenario Setup Functions --
-- ===========================

-- =========================
-- Israel Scenario Setup Options
-- =========================

function IsraelScenarioSetupOptions()
    local msg = [[
		<html>
			<head>
				<style>
					body{
						font-family: Arial, Helvetica, sans-serif;
						background-color: #333333;
						color: white;
						text-align: justify;
					}
	
					.container{
						margin: auto;
						background-color: #333333;
						border-radius: 5px;
					}
	
					h1{
						font-size:large;
						text-align: center;
					}
	
					table{
						border-collapse: collapse;
						margin: auto;
						padding: 25px;
					}
	
					th, td{
						border: 1px solid white;
						text-align: left;
						padding: 5px;
					}
	
					td:first-child {
						width: 65%;
					}
	
					td:last-child {
						width: 35%;
					}
				</style>
				<meta charset="UTF-8">
				<meta name="viewport" content="width=device-width, initial-scale=1.0">
				<title>Scenario Options Table</title>
			</head>
			<body>
				<div class="container">
				<h1 align="center">Scenario Setup Options</h1>
				<table>
					<!-- Title -->
					<!-- Containers -->
					<tr>
						<td>
							<p>Set the scenario year.</p>
							<p><b>2022:</b> No changes to starting forces.</p>
							<p><b>2024:</b> Updates the IDF order of battle to 2024. Adjust the chances for some events and special actions.</p>
						</td>
						<td>
							<select name="strike_year">
								<option value="strike_year_2022">2022</option>
								<option value="strike_year_2024">2024</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
					<tr>
						<td>
							<p>Set the chances of various events and actions.</p>
							<p><b>Fixed:</b> The success chance for events and special actions are Kushan's estimate of how likely they would be.</p>
							<p><b>Random:</b> The success chance for events and special actions are randomized.</p>
							<p><b>Remove Randomization:</b> Remove randomization for events and special actions. There will be a 100% chance of player special actions being successful.</p>
						</td>
						<td>
							<select name="scenario_event_chances">
								<option value="scenario_event_chances_option_1">Fixed</option>
								<option value="scenario_event_chances_option_2">Random</option>
								<option value="scenario_event_chances_option_3">Remove Randomization</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
					<tr>
						<td>
							<p>Enable Search and Rescue</p>
							<p>When aircraft are destroyed there is a chance a downed aircrew will be generated. Rescuing the downed aircrew will reward points. Rescue capable forces will be added to Nevatim and Tel Nof Air Bases.</p>
							<p>You can use C-130J Hercules to create forward refueling points to support your CSAR forces.</p>
						</td>
						<td>
							<select name="enable_search_and_rescue">
								<option value="enable_search_and_rescue_false">No</option>
								<option value="enable_search_and_rescue_true">Yes</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
					<tr>
						<td>
							<p>Fuel Usage:</p>
							<p><b>Default:</b> Default Command fuel usage.</p>
							<p><b>Unlimited:</b> Aircraft will still use fuel but will be periodically refueled via in-game event. No tankers will be needed.</p>
						</td>
						<td>
							<select name="player_fuel_usage">
								<option value="player_fuel_usage_option_1">Default</option>
								<option value="player_fuel_usage_option_2">Unlimited</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
					<tr>
						<td>
							<p>Upgrade Iranian Air Force:</p>
							<p><b>Use Hypothetical Loadouts: Determines if Iranian aircraft will use hypothetical loadouts (i.e. MiG-290 with Fakour-90 [Mod. AIM-54A/MIM-23 HAWK].</b></p>
							<p><b>Use Export Only Aircraft & Loadouts:</b> If this is enabled then aircraft replaced by the various upgrade options will use export only models (if applicable). If disabled then there is a chance that non-export aircraft and loadouts may be used.</p>
							<p><b>Add Su-35 Squadrons:</b> Adds twenty-four Su-35s from the rumored 2022 deal between Russia and Iran to Hamadan and Shiraz air bases.</p>
							<p><b>Upgrade Existing Aircraft Options</b></p>
							<ul>
								<li><b>Option 1:</b> Randomly replaces aircraft with Su-35's.</li>
								<li><b>Option 2:</b> Randomly replaces aircraft with J-10C's.</li>
								<li><b>Option 3:</b> Randomly replaces aircraft with Su-35's and/or J-10C's.</li>
								<li><b>Option 4:</b> Randomly replaces aircraft with Su-57's.</li>
								<li><b>Option 5:</b> Randomly replaces aircraft with F-14E Super Tomcats.</li>
								<li><b>Option 6:</b> Randomly replaces aircraft with Su-57's and/or F-14E Super Tomcats.</li>
							</ul>
						</td>
						<td>
							<p>Use Hypothetical Loadouts</p>
							<select name="iran_hypothetical_loadouts">
								<option value="iran_hypothetical_loadouts_false">No</option>
								<option value="iran_hypothetical_loadouts_true">Yes</option>
								<!-- Add more options here -->
							</select>
							<p>Use Export Only Aircraft & Loadouts</p>
							<select name="iran_export_only_aircraft">
								<option value="iran_export_only_aircraft_true">Yes</option>
								<option value="iran_export_only_aircraft_false">No</option>
								<!-- Add more options here -->
							</select>
							<p>Add Su-35 Squadrons</p>
							<select name="iran_add_su_35_squadrons">
								<option value="iran_add_su_35_squadrons_option_false">No</option>
								<option value="iran_add_su_35_squadrons_option_true">Yes</option>
								<!-- Add more options here -->
							</select>
							<p>Upgrade F-4, F-5, and MiG-21 Squadrons</p>
							<select name="iran_upgrade_legacy_aircraft">
								<option value="iran_upgrade_legacy_aircraft_option_0">No</option>
								<option value="iran_upgrade_legacy_aircraft_option_1">Option 1</option>
								<option value="iran_upgrade_legacy_aircraft_option_2">Option 2</option>
								<option value="iran_upgrade_legacy_aircraft_option_3">Option 3</option>
								<option value="iran_upgrade_legacy_aircraft_option_4">Option 4</option>
								<option value="iran_upgrade_legacy_aircraft_option_5">Option 5</option>
								<option value="iran_upgrade_legacy_aircraft_option_6">Option 6</option>
								<!-- Add more options here -->
							</select>
							<p>Upgrade F-14 and MiG-29 Squadrons</p>
							<select name="iran_upgrade_modern_aircraft">
								<option value="iran_upgrade_modern_aircraft_option_0">No</option>
								<option value="iran_upgrade_modern_aircraft_option_1">Option 1</option>
								<option value="iran_upgrade_modern_aircraft_option_2">Option 2</option>
								<option value="iran_upgrade_modern_aircraft_option_3">Option 3</option>
								<option value="iran_upgrade_modern_aircraft_option_4">Option 4</option>
								<option value="iran_upgrade_modern_aircraft_option_5">Option 5</option>
								<option value="iran_upgrade_modern_aircraft_option_6">Option 6</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
					<tr>
						<td>
							<p><b>Add Additional AAA to Natanz:</b> Adds additional AAA around the Natanz facility. Imagery from May 2022 indicates that most of the AAA around the Natanz facility has been removed. Correspondingly by default there is a very low chance for AAA to be placed during scenario setup. Use this action if you wish to replace the AAA around the facility.</p>
							<p><b>Iranian Air Defense Placement:</b> New systems have a chance to be autodetected, advance the scenario for a few seconds for them to appear.</p>
							<ul>
								<li><b>Option 1:</b> Places older and domestic Iranian air defense systems.</li>
								<li><b>Option 2:</b> Places domestic Iranian air defense systems. There is a chance that older SAM systems will be replaced with a modern system.</li>
								<li><b>Option 3:</b> Places older, domestic Iranian, and modern Russian and Chinese air defense systems.</li>
								<li><b>Option 4:</b> Places older, domestic Iranian, and modern Russian and Chinese air defense systems. There is a chance that older SAM systems will be replaced with a modern system.</li>
							</ul>
							<p><b>Upgrade Iranian Early Warning Radars:</b> New systems have a chance to be autodetected, advance the scenario for a few seconds for them to appear.</p>
							<ul>
								<li><b>Option 1:</b> Randomly replace AN/TPS-70, JY-14 Great Wall, and Spoon Rest D [P-18] radars with domestic Iranian systems.</li>
								<li><b>Option 2:</b> Randomly replace AN/TPS-70, JY-14 Great Wall, and Spoon Rest D [P-18] radars with Iranian, Russian, and Chinese systems.</li>
							</ul>
						</td>
						<td>
							<p>Add Additional AAA at Natanz</p>
							<select name="iran_additional_natanz_aaa">
								<option value="iran_additional_natanz_aaa_false">No</option>
								<option value="iran_additional_natanz_aaa_true">Yes</option>
								<!-- Add more options here -->
							</select>
							<p>Iranian Air Defense Placement</p>
							<select name="iran_air_defenses">
								<option value="iran_air_defenses_option_1">Option 1</option>
								<option value="iran_air_defenses_option_2">Option 2</option>
								<option value="iran_air_defenses_option_3">Option 3</option>
								<option value="iran_air_defenses_option_4">Option 4</option>
								<!-- Add more options here -->
							</select>
							<p>Upgrade Iranian Early Warning Radars</p>
							<select name="iran_early_warning_radars">
								<option value="iran_early_warning_radars_option_0">No</option>
								<option value="iran_early_warning_radars_option_1">Option 1</option>
								<option value="iran_early_warning_radars_option_2">Option 2</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
				</table>
			</body>
		</html>
	]]

    local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
    if form['pressed'] and form['pressed'] == 'Done' then
        -- =========================
        -- Scenario Year
        -- =========================

        local Option = string.gsub(form['strike_year'], "%'", "")
        if Option == 'strike_year_2024' then -- 2024 Strike
            -- Set Scenario Variables
            local variablesList = {
                { variable = 'PlayerJordanOverflightChance',   value = 80,                persist = false }, -- Higher chance that Jordan allows overflight
                { variable = 'PlayerTurkeyOverflightChance',   value = 20,                persist = false }, -- Lower chance Turkey allows overflight
                { variable = 'PlayerTurkeyWarnsIranChance',    value = 80,                persist = false }, -- Higher chance Turkey warns Iran
                { variable = 'PlayerEarlyPegasusDeliveryChance', value = 60,              persist = false }, -- Higher chance that KC-46 are delivered early
                { variable = 'PlayerUSTankerSupportChance',    value = 80,                persist = false }, -- Higher chance US provides tanker support
                { variable = 'PlayerUSMissileSupportChance',   value = 80,                persist = false }, -- Higher chance US provides supporting missile strikes

                { variable = 'PlayerNumberOfTankers_1',        value = 11,                persist = false },
                { variable = 'PlayerNumberOfTankers_2',        value = 18,                persist = false },
                { variable = 'PlayerTankerDBID',               value = 6621,              persist = false },
                { variable = 'PlayerTankerLoadoutID',          value = 19801,             persist = false }, -- KC-135R Stratotankers, 2020
                { variable = 'PlayerTankerBase',               value = 'Al Udeid AB',     persist = false },
                { variable = 'PlayerNumberOfTankersString',    value = 'EIGHT',           persist = false },
                { variable = 'PlayerTankerString',             value = 'KC-135 TANKERS',  persist = false },
                { variable = 'PlayerTankerBaseString',         value = 'AL UDEID AIR BASE', persist = false },
                { variable = 'PlayerTankerCountryString',      value = 'QATAR',           persist = false },
            }

            for _, v in ipairs(variablesList) do
                _G[v.variable] = v.value
                if v.persist then
                    ScenEdit_SetKeyValue(v.key, tostring(v.value))
                end
            end

            -- Update IDF Order of Battle for 2024
            local PlayerSide = ScenEdit_PlayerSide()

            DeleteUnits(PlayerSide, 1, 20, '200 Sqd. #') -- Remove 200 Sqd. (20x Heron UAV [Shoval]) from Palmachim AB
            DeleteAllUnitsOnSide_ByDBID(PlayerSide, 214) -- Remove KC-10A Extenders

            local aircraftList = {
                { num1 = 1, num2 = 20, name = '200 Sqd. #', dbid = 1686, base = 'Hatzor AB' }, -- Add 200 Sqd. (20x Heron UAV [Shoval]) to Hatzor AB
                { num1 = 6, num2 = 7, name = '122 Sqd. #', dbid = 5625, base = 'Nevatim AB' }, -- Add 122 Sqd. (2x Gulfstream G550 AEW [Oron]) to Nevatim AB
                { num1 = 1, num2 = 20, name = '161 Sqd. #', dbid = 2578, base = 'Palmachim AB' }, -- Add 161 Sqd. (20x Hermes 450 UAV [Ziq]) to Palmachim AB
            }

            for _, v in ipairs(aircraftList) do
                AddAircraft(PlayerSide, v.num1, v.num2, v.dbid, v.name, v.base, 3, 0)
                RandomizeMultipleUnitProficiency(PlayerSide, v.num1, v.num2, v.name, 10, 20, 70, 80, 90)
            end
        end

        -- =========================
        -- Scenario Event and Special Action Chances
        -- =========================

        local Option = string.gsub(form['scenario_event_chances'], "%'", "")
        if Option == 'scenario_event_chances_option_2' then -- Random
            local variablesList = {
                { variable = 'PlayerCyberChance',              value = GetRandomRoundedNumber(0, 100, 5), persist = true, key = 'PlayerCyberChanceKey' },
                { variable = 'PlayerCyberIncrement',           value = GetRandomRoundedNumber(0, 100, 5), persist = true, key = 'PlayerCyberIncrementKey' },

                -- Variables only needed upon scenario initialization
                { variable = 'IranUnitPlacementOrUpgradeChance', value = GetRandomRoundedNumber(0, 100, 5) },

                { variable = 'PlayerJordanOverflightChance',   value = GetRandomRoundedNumber(0, 100, 5) },
                { variable = 'PlayerTurkeyOverflightChance',   value = GetRandomRoundedNumber(0, 100, 5) },
                { variable = 'PlayerTurkeyWarnsIranChance',    value = GetRandomRoundedNumber(0, 100, 5) },
                { variable = 'PlayerEarlyPegasusDeliveryChance', value = GetRandomRoundedNumber(0, 100, 5) },
                { variable = 'PlayerUSTankerSupportChance',    value = GetRandomRoundedNumber(0, 100, 5) },
                { variable = 'PlayerUSMissileSupportChance',   value = GetRandomRoundedNumber(0, 100, 5) },
            }

            for _, v in ipairs(variablesList) do
                _G[v.variable] = v.value
                if v.persist then
                    ScenEdit_SetKeyValue(v.key, tostring(v.value))
                end
            end
        elseif Option == 'scenario_event_chances_option_3' then -- Remove Randomization
            local variablesList = {
                { variable = 'PlayerCyberChance',              value = 100, persist = true, key = 'PlayerCyberChanceKey' },
                { variable = 'PlayerCyberIncrement',           value = 0, persist = true, key = 'PlayerCyberIncrementKey' },

                -- Variables only needed upon scenario initialization
                { variable = 'IranUnitPlacementOrUpgradeChance', value = 100 },

                { variable = 'PlayerJordanOverflightChance',   value = 100 },
                { variable = 'PlayerTurkeyOverflightChance',   value = 100 },
                { variable = 'PlayerTurkeyWarnsIranChance',    value = 0 },
                { variable = 'PlayerEarlyPegasusDeliveryChance', value = 100 },
                { variable = 'PlayerUSTankerSupportChance',    value = 100 },
                { variable = 'PlayerUSMissileSupportChance',   value = 100 },
            }

            for _, v in ipairs(variablesList) do
                _G[v.variable] = v.value
                if v.persist then
                    ScenEdit_SetKeyValue(v.key, tostring(v.value))
                end
            end
        end

        -- =========================
        -- Enable Search and Rescue
        -- =========================

        local Option = string.gsub(form['enable_search_and_rescue'], "%'", "")
        if Option == 'enable_search_and_rescue_false' then
            SearchAndRescueEnabled(false)
        else
            SearchAndRescueEnabled(true)

            ScenEdit_SetEvent('Attempt CSAR', { isActive = true })
            ScenEdit_SetEvent('Setup Forward Refueling Point', { isActive = true })

            local PlayerSide = ScenEdit_PlayerSide()
            AddAircraft(PlayerSide, 1, 4, 7076, '103 Sqd. #', 'Nevatim AB', 30210, 0) -- Add 4x C-130J-30 Hercules [Shimshon]
            AddAircraft(PlayerSide, 1, 4, 1915, '131 Sqd. #', 'Nevatim AB', 8404, 0) -- Add 4x KC-130H Hercules
            AddAircraft(PlayerSide, 1, 8, 4732, 'Unit 669 #', 'Tel Nof AB', 13623, 0) -- Add 8x CH-53C Sea Stallion [Yasur 2025]

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
            SurvivorList = {}                           -- Name must match thise used in the CSAR functions, Initialize at scenario setup and reloaded
        end

        -- =========================
        -- Fuel Usage
        -- =========================

        local Option = string.gsub(form['player_fuel_usage'], "%'", "")
        if Option == 'player_fuel_usage_option_2' then -- Unlimited fuel for player aircraft
            ScenEdit_SetEvent('Refuel Player Aircraft', { isActive = true })
        end

        -- =========================
        -- Iran Use Hypothetical Loadouts
        -- =========================

        local Option = string.gsub(form['iran_hypothetical_loadouts'], "%'", "")
        if Option == 'iran_hypothetical_loadouts_false' then
            IranUseHypotheticalLoadouts(false)
        else
            IranUseHypotheticalLoadouts(true)
        end

        -- =========================
        -- Use Export Only Aircraft and Loadouts
        -- =========================

        local Option = string.gsub(form['iran_export_only_aircraft'], "%'", "")
        if Option == 'iran_export_only_aircraft_true' then
            IranUseExportOnly(true)
        else
            IranUseExportOnly(false)
        end

        -- =========================
        -- Add Additional Su-35 Squadrons
        -- =========================

        local Option = string.gsub(form['iran_add_su_35_squadrons'], "%'", "")
        if Option == 'iran_add_su_35_squadrons_option_true' then
            if IranUseExportOnly() then
                AddAircraft('Iran', 1, 12, 6614, '32nd TFS #', 'Hamadan (3rd TAB)', 11076, 0) -- Add 12x Su-35S Flanker M, Iran
                AddAircraft('Iran', 1, 12, 6614, '74th TFS #', 'Shiraz (7th TAB)', 11076, 0) -- Add 12x Su-35S Flanker M, Iran
            else
                if math.random(1, 100) <= IranUnitPlacementOrUpgradeChance then
                    AddAircraft('Iran', 1, 12, 6614, '32nd TFS #', 'Hamadan (3rd TAB)', 11076, 0) -- Add 12x Su-35S Flanker M, Iran
                    AddAircraft('Iran', 1, 12, 6614, '74th TFS #', 'Shiraz (7th TAB)', 11076, 0) -- Add 12x Su-35S Flanker M, Iran
                else
                    AddAircraft('Iran', 1, 12, 6645, '32nd TFS #', 'Hamadan (3rd TAB)', 31826, 0) -- Add 12x Su-35S Flanker M, Russia
                    AddAircraft('Iran', 1, 12, 6645, '74th TFS #', 'Shiraz (7th TAB)', 31826, 0) -- Add 12x Su-35S Flanker M, Russia
                end
            end
        end

        -- =========================
        -- Upgrade Iran Legacy Aircraft
        -- =========================

        local Option = string.gsub(form['iran_upgrade_legacy_aircraft'], "%'", "")
        if Option == 'iran_upgrade_legacy_aircraft_option_1' then
            if IranUseExportOnly() then
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_1, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_1A, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            else
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_1, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_1B, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            end
        elseif Option == 'iran_upgrade_legacy_aircraft_option_2' then
            if IranUseExportOnly() then
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_1, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_2A, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            else
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_1, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_2B, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            end
        elseif Option == 'iran_upgrade_legacy_aircraft_option_3' then
            if IranUseExportOnly() then
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_1, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_3A, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            else
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_1, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_3B, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            end
        elseif Option == 'iran_upgrade_legacy_aircraft_option_4' then
            RandomReplaceAircraft(
                'Iran',               -- side
                IranAircraftToUpgrade_1, -- listOfAircraftToReplace
                IranUnitPlacementOrUpgradeChance, -- chance
                IranAircraftUpgradeOption_4, -- aircraftList
                20,                   -- chanceNovice
                50,                   -- chanceCadet
                80,                   -- chanceRegular
                90,                   -- chanceVeteran
                100,                  -- chanceAce
                0                     -- TimeToReady
            )
        elseif Option == 'iran_upgrade_legacy_aircraft_option_5' then
            RandomReplaceAircraft(
                'Iran',               -- side
                IranAircraftToUpgrade_1, -- listOfAircraftToReplace
                IranUnitPlacementOrUpgradeChance, -- chance
                IranAircraftUpgradeOption_5, -- aircraftList
                20,                   -- chanceNovice
                50,                   -- chanceCadet
                80,                   -- chanceRegular
                90,                   -- chanceVeteran
                100,                  -- chanceAce
                0                     -- TimeToReady
            )
        elseif Option == 'iran_upgrade_legacy_aircraft_option_6' then
            RandomReplaceAircraft(
                'Iran',               -- side
                IranAircraftToUpgrade_1, -- listOfAircraftToReplace
                IranUnitPlacementOrUpgradeChance, -- chance
                IranAircraftUpgradeOption_6, -- aircraftList
                20,                   -- chanceNovice
                50,                   -- chanceCadet
                80,                   -- chanceRegular
                90,                   -- chanceVeteran
                100,                  -- chanceAce
                0                     -- TimeToReady
            )
        end

        -- =========================
        -- Upgrade Iran Modern Aircraft
        -- =========================

        local Option = string.gsub(form['iran_upgrade_modern_aircraft'], "%'", "")
        if Option == 'iran_upgrade_modern_aircraft_option_1' then
            if IranUseExportOnly() then
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_2, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_1A, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            else
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_2, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_1B, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            end
        elseif Option == 'iran_upgrade_modern_aircraft_option_2' then
            if IranUseExportOnly() then
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_2, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_2A, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            else
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_2, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_2B, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            end
        elseif Option == 'iran_upgrade_modern_aircraft_option_3' then
            if IranUseExportOnly() then
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_2, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_3A, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            else
                RandomReplaceAircraft(
                    'Iran',            -- side
                    IranAircraftToUpgrade_2, -- listOfAircraftToReplace
                    IranUnitPlacementOrUpgradeChance, -- chance
                    IranAircraftUpgradeOption_3B, -- aircraftList
                    20,                -- chanceNovice
                    50,                -- chanceCadet
                    80,                -- chanceRegular
                    90,                -- chanceVeteran
                    100,               -- chanceAce
                    0                  -- TimeToReady
                )
            end
        elseif Option == 'iran_upgrade_modern_aircraft_option_4' then
            RandomReplaceAircraft(
                'Iran',               -- side
                IranAircraftToUpgrade_2, -- listOfAircraftToReplace
                IranUnitPlacementOrUpgradeChance, -- chance
                IranAircraftUpgradeOption_4, -- aircraftList
                20,                   -- chanceNovice
                50,                   -- chanceCadet
                80,                   -- chanceRegular
                90,                   -- chanceVeteran
                100,                  -- chanceAce
                0                     -- TimeToReady
            )
        elseif Option == 'iran_upgrade_modern_aircraft_option_5' then
            RandomReplaceAircraft(
                'Iran',               -- side
                IranAircraftToUpgrade_2, -- listOfAircraftToReplace
                IranUnitPlacementOrUpgradeChance, -- chance
                IranAircraftUpgradeOption_5, -- aircraftList
                20,                   -- chanceNovice
                50,                   -- chanceCadet
                80,                   -- chanceRegular
                90,                   -- chanceVeteran
                100,                  -- chanceAce
                0                     -- TimeToReady
            )
        elseif Option == 'iran_upgrade_modern_aircraft_option_6' then
            RandomReplaceAircraft(
                'Iran',               -- side
                IranAircraftToUpgrade_2, -- listOfAircraftToReplace
                IranUnitPlacementOrUpgradeChance, -- chance
                IranAircraftUpgradeOption_6, -- aircraftList
                20,                   -- chanceNovice
                50,                   -- chanceCadet
                80,                   -- chanceRegular
                90,                   -- chanceVeteran
                100,                  -- chanceAce
                0                     -- TimeToReady
            )
        end

        -- =========================
        -- Add Additional AAA to Natanz
        -- =========================

        local Option = string.gsub(form['iran_additional_natanz_aaa'], "%'", "")
        if Option == 'iran_additional_natanz_aaa_true' then
            AddRandomFacility_FixedPosition('Iran', 'Arak AAA Site', 64, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAAA, 95)
            AddRandomFacility_FixedPosition('Iran', 'Esfahãn AAA Site', 60, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAAA, 95)
            AddRandomFacility_FixedPosition('Iran', 'Fordow AAA Site', 22, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAAA, 95)
            AddRandomFacility_FixedPosition('Iran', 'Natanz AAA Site', 172, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAAA, 95)
        else
            AddRandomFacility_FixedPosition('Iran', 'Arak AAA Site', 64, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAAA, 95)
            AddRandomFacility_FixedPosition('Iran', 'Esfahãn AAA Site', 60, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAAA, 95)
            AddRandomFacility_FixedPosition('Iran', 'Fordow AAA Site', 22, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAAA, 95)
            AddRandomFacility_FixedPosition('Iran', 'Natanz AAA Site', 172, 5, false, IranRandomAAA, 95)
        end

        -- Delete AAA reference points when no longer needed
        DeleteReferencePoints_ByName('Iran', 'Arak AAA Site', 64)
        DeleteReferencePoints_ByName('Iran', 'Esfahãn AAA Site', 60)
        DeleteReferencePoints_ByName('Iran', 'Fordow AAA Site', 22)
        DeleteReferencePoints_ByName('Iran', 'Natanz AAA Site', 172)

        -- =========================
        -- Upgrade Iranian Air Defenses
        -- =========================

        local Option = string.gsub(form['iran_air_defenses'], "%'", "")
        if Option == 'iran_air_defenses_option_1' then
            AddRandomFacility_FixedPosition('Iran', 'Arak AD Site', 6, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_1A, 80)
            AddRandomFacility_FixedPosition('Iran', 'Fordow AD Site', 7, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_1A, 80)
            AddRandomFacility_FixedPosition('Iran', 'Natanz AD Site', 11, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_1A, 80)
        elseif Option == 'iran_air_defenses_option_2' then
            AddRandomFacility_FixedPosition('Iran', 'Arak AD Site', 6, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_1A, 80)
            AddRandomFacility_FixedPosition('Iran', 'Fordow AD Site', 7, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_1A, 80)
            AddRandomFacility_FixedPosition('Iran', 'Natanz AD Site', 11, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_1A, 80)

            RandomReplaceFacility(
                'Iran',               -- side
                IranUnitPlacementOrUpgradeChance, -- chance
                IranAirDefensesToUpgrade, -- unitsToReplaceList
                0,                    -- radius
                100,                  -- replaceChance
                IranRandomAirDefenses_1B, -- unitList
                80                    -- chanceOfDetection
            )
        elseif Option == 'iran_air_defenses_option_3' then
            AddRandomFacility_FixedPosition('Iran', 'Arak AD Site', 6, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_2A, 80)
            AddRandomFacility_FixedPosition('Iran', 'Fordow AD Site', 7, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_2A, 80)
            AddRandomFacility_FixedPosition('Iran', 'Natanz AD Site', 11, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_2A, 80)
        elseif Option == 'iran_air_defenses_option_4' then
            AddRandomFacility_FixedPosition('Iran', 'Arak AD Site', 6, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_2A, 80)
            AddRandomFacility_FixedPosition('Iran', 'Fordow AD Site', 7, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_2A, 80)
            AddRandomFacility_FixedPosition('Iran', 'Natanz AD Site', 11, IranUnitPlacementOrUpgradeChance, false,
                IranRandomAirDefenses_2A, 80)

            RandomReplaceFacility(
                'Iran',               -- side
                IranUnitPlacementOrUpgradeChance, -- chance
                IranAirDefensesToUpgrade, -- unitsToReplaceList
                0,                    -- radius
                100,                  -- replaceChance
                IranRandomAirDefenses_2B, -- unitList
                80                    -- chanceOfDetection
            )
        end

        -- Delete AAA reference points when no longer needed
        DeleteReferencePoints_ByName('Iran', 'Arak AD Site', 6)
        DeleteReferencePoints_ByName('Iran', 'Fordow AD Site', 7)
        DeleteReferencePoints_ByName('Iran', 'Natanz AD Site', 11)

        -- =========================
        -- Upgrade Iranian Early Warning Radars
        -- =========================

        local Option = string.gsub(form['iran_early_warning_radars'], "%'", "")
        if Option == 'iran_early_warning_radars_option_1' then
            RandomReplaceFacility(
                'Iran',               -- side
                IranUnitPlacementOrUpgradeChance, -- chance
                IranRadarsToUpgrade,  -- unitsToReplaceList
                0.25,                 -- radius
                IranUnitPlacementOrUpgradeChance, -- replaceChance, Radars use replaceChance from table
                IranRandomRadars_1,   -- unitList
                80                    -- chanceOfDetection
            )
        elseif Option == 'iran_early_warning_radars_option_2' then
            RandomReplaceFacility(
                'Iran',               -- side
                IranUnitPlacementOrUpgradeChance, -- chance
                IranRadarsToUpgrade,  -- unitsToReplaceList
                0.25,                 -- radius
                IranUnitPlacementOrUpgradeChance, -- replaceChance, Radars use replaceChance from table
                IranRandomRadars_2,   -- unitList
                80                    -- chanceOfDetection
            )
        end
    end
end

-- ==================
-- Special Actions --
-- ==================

-- =========================
-- Israel Political and Stratefic Actions
-- =========================

function IsraelPoliticalAndStrategicActions()
    local msg = [[
		<html>
			<head>
				<style>
					body{
						font-family: Arial, Helvetica, sans-serif;
						background-color: #333333;
						color: white;
						text-align: justify;
					}
	
					.container{
						margin: auto;
						background-color: #333333;
						border-radius: 5px;
					}
	
					h1{
						font-size:large;
						text-align: center;
					}
	
					table{
						border-collapse: collapse;
						margin: auto;
						padding: 25px;
					}
	
					th, td{
						border: 1px solid white;
						text-align: left;
						padding: 5px;
					}
	
					td:first-child {
						width: 80%;
					}
	
					td:last-child {
						width: 20%;
					}
				</style>
				<meta charset="UTF-8">
				<meta name="viewport" content="width=device-width, initial-scale=1.0">
				<title>Political and Strategic Actions</title>
			</head>
			<body>
				<div class="container">
				<h1 align="center">Political and Strategic Actions</h1>
				<p align="center">NOTE: Choices made here are final. Once you hit "Done" this menu cannot be reopened.</p>
				<table>
					<!-- Title -->
					<!-- Containers -->
					<tr>
						<td>
							<p>Request to overfly Jordanian airspace.</p>
							<p>If overflight is granted the no-fly zone around Jordan will be removed.</p>
							<!-- <p>If overflight is not granted there is a chance that the no-fly zone around Jordan will be removed but you will lose points if your aircraft spend an extended amount of time on Jordanian airspace.</p> -->
						</td>
						<td>
							<select name="israel_request_overfly_jordan">
								<option value="israel_request_overfly_jordan_false">No</option>
								<option value="israel_request_overfly_jordan_true">Yes</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
					<tr>
						<td>
							<p>Request to overfly Turkish airspace.</p>
							<p>If overflight is granted the no-fly zone over south-east Turkey will be removed. If overflight is not granted it is possible Turkey may warn Iran of a possible strike. When warned Iran will raise its alert posture.</p>
						</td>
						<td>
							<select name="israel_request_overfly_turkey">
								<option value="israel_request_overfly_turkey_false">No</option>
								<option value="israel_request_overfly_turkey_true">Yes</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
					<tr>
						<td>
							<p>Request the US deliver four KC-46A Pegasus tankers immediately.</p>
							<p>If the request is approved KC-46s will be added to Nevatim Air Base.</p>
						</td>
						<td>
							<select name="israel_request_early_tanker_delivery">
								<option value="israel_request_early_tanker_delivery_false">No</option>
								<option value="israel_request_early_tanker_delivery_true">Yes</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
					<tr>
						<td>
							<p>Request US aerial refueling support.</p>
							<p>If the request is approved, USAF tankers will be made available to you. The aircraft type that is provided and where they are based depends on scenario year selected during scenario setup.</p>
							<ul>
								<li><b>2022:</b> Four KC-10s at Al Dhafra Air Base.</li>
								<li><b>2024:</b> Eight KC-135s at Al Udeid Air Base.</li>
							</ul>
						</td>
						<td>
							<select name="israel_request_usa_tanker_support">
								<option value="israel_request_usa_tanker_support_false">No</option>
								<option value="israel_request_usa_tanker_support_true">Yes</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
					<tr>
						<td>
							<p>Request the US support the operation against Iran with Tomahawk missile strikes.</p>
							<p>If the request is approved the 48 missiles from the USS Georgia and 12 missiles from the USS Vermont will be available for your use.</p>
							<p>Missiles can be fired by selecting the target(s) and then executing either the "Launch Tomahawk Missile Strike from USS Georgia" or "Launch Tomahawk Missile Strike from USS Vermont" special action. A menu will appear asking how many missiles you wish to allocate to each target. Once you select "Ok" the missiles will be fired.</p>
							<p></p>
						</td>
						<td>
							<select name="israel_request_usa_missile_support">
								<option value="israel_request_usa_missile_support_false">No</option>
								<option value="israel_request_usa_missile_support_true">Yes</option>
								<!-- Add more options here -->
							</select>
						</td>
					</tr>
				</table>
			</body>
		</html>
	]]

    local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
    if form['pressed'] and form['pressed'] == 'Done' then
        -- =========================
        -- Request to Overfly Jordanian Airspace
        -- =========================

        local Option = string.gsub(form['israel_request_overfly_jordan'], "%'", "")
        if Option == 'israel_request_overfly_jordan_true' then
            PlayerRequestOverflight(
                PlayerJordanOverflightChance,    -- chance
                'Jordan',                        -- country
                'Jordan NFZ',                    -- zoneDescription
                'GENERAL HQ<BR>AIR OPERATIONS CENTER//CC//', -- messageRecipient
                'MINISTRY OF DEFENSE',           -- messageSender
                'REQUEST TO OVERFLY JORDIANIAN AIRSPACE', -- messageSubject
                'JORDANIAN'                      -- airspaceName
            )
        end

        -- =========================
        -- Request to Overfly Turkish Airspace
        -- =========================

        local Option = string.gsub(form['israel_request_overfly_turkey'], "%'", "")
        if Option == 'israel_request_overfly_turkey_true' then
            local overflightGranted = PlayerRequestOverflight(
                PlayerTurkeyOverflightChance,    -- chance
                'Turkey',                        -- country
                'Turkey NFZ',                    -- zoneDescription
                'GENERAL HQ<BR>AIR OPERATIONS CENTER//CC//', -- messageRecipient
                'MINISTRY OF DEFENSE',           -- messageSender
                'REQUEST TO OVERFLY TURKISH AIRSPACE', -- messageSubject
                'TURKISH'                        -- airspaceName
            )

            if not overflightGranted then
                if math.random(1, 100) <= PlayerTurkeyWarnsIranChance then
                    -- Iran is alerted
                    IranInitiatesHostilities()
                end
            end
        end

        -- =========================
        -- Request Early KC-46A Delivery
        -- =========================

        local Option = string.gsub(form['israel_request_early_tanker_delivery'], "%'", "")
        if Option == 'israel_request_early_tanker_delivery_true' then
            if math.random(1, 100) <= PlayerEarlyPegasusDeliveryChance then
                local PlayerSide = ScenEdit_PlayerSide()
                AddAircraft(PlayerSide, 11, 14, 5514, '120 Sqd.', 'Nevatim AB', 18313, 0)

                TelexMessageToPlayer(
                    'GENERAL HQ<BR>AIR OPERATIONS CENTER//CC//',
                    'MINISTRY OF DEFENSE',
                    'REQUEST FOR KC-46 AIRCRAFT',
                    'TOP SECRET',
                    'IMMEDIATE',
                    'O',
                    'THE UNITED STATES HAS AGREED TO IMMEDIATELY DELIVER FOUR KC-46 PEGASUS TANKERS. THEY HAVE BEEN ASSIGNED TO 120 SQUADRON AT NEVATIM AIR BASE.',
                    nil
                )
            else
                TelexMessageToPlayer(
                    'GENERAL HQ<BR>AIR OPERATIONS CENTER//CC//',
                    'MINISTRY OF DEFENSE',
                    'REQUEST FOR KC-46 AIRCRAFT',
                    'TOP SECRET',
                    'IMMEDIATE',
                    'O',
                    'THE UNITED STATES HAS DENIED OUR REQUEST TO IMMEDIATELY DELIVER FOUR KC-46 PEGASUS TANKERS. THIS IS DISAPPOINTING BUT YOUR ORDERS REMAIN UNCHANGED. YOU WILL HAVE TO MAKE DUE WITH AVAILABLE REFUELING ASSETS.',
                    nil
                )
            end
        end

        -- =========================
        -- Request US Tanker Support
        -- =========================

        local Option = string.gsub(form['israel_request_usa_tanker_support'], "%'", "")
        if Option == 'israel_request_usa_tanker_support_true' then
            if math.random(1, 100) <= PlayerUSTankerSupportChance then
                SetAircraftLoadouts(
                    'Israel',
                    PlayerNumberOfTankers_1,
                    PlayerNumberOfTankers_2,
                    'MOBILE ',
                    PlayerTankerLoadoutID,
                    0,
                    true
                )

                TelexMessageToPlayer(
                    'GENERAL HQ<BR>AIR OPERATIONS CENTER//CC//',
                    'MINISTRY OF DEFENSE',
                    'REQUEST FOR US TANKER SUPPORT',
                    'TOP SECRET',
                    'IMMEDIATE',
                    'O',
                    'THE UNITED STATES HAS AGREED TO PROVIDE REFUELING SUPPORT. ' ..
                    PlayerNumberOfTankersString ..
                    ' ' ..
                    PlayerTankerString ..
                    ' AT ' ..
                    PlayerTankerBaseString ..
                    ' IN ' .. PlayerTankerCountryString .. ' HAVE BEEN MADE AVAILABLE TO SUPPORT OUR OPERATION.',
                    nil
                )
            else
                TelexMessageToPlayer(
                    'GENERAL HQ<BR>AIR OPERATIONS CENTER//CC//',
                    'MINISTRY OF DEFENSE',
                    'REQUEST FOR US TANKER SUPPORT',
                    'TOP SECRET',
                    'IMMEDIATE',
                    'O',
                    'THE UNITED STATES HAS DENIED TO OUR REQUEST TO PROVIDE REFUELING SUPPORT. THIS IS DISAPPOINTING BUT YOUR ORDERS REMAIN UNCHANGED. YOU WILL HAVE TO MAKE DUE WITH AVAILABLE REFUELING ASSETS.',
                    nil
                )
            end
        end

        -- =========================
        -- Request US Missile Strikes
        -- =========================

        local Option = string.gsub(form['israel_request_usa_missile_support'], "%'", "")
        if Option == 'israel_request_usa_missile_support_true' then
            if math.random(1, 100) <= PlayerUSMissileSupportChance then
                Israel_MissileStrikesApproved(true)
                TelexMessageToPlayer(
                    'GENERAL HQ<BR>AIR OPERATIONS CENTER//CC//',
                    'MINISTRY OF DEFENSE',
                    'REQUEST FOR US MISSILE STRIKES',
                    'TOP SECRET',
                    'IMMEDIATE',
                    'O',
                    'THE UNITED STATES HAS AGREED TO SUPPORT OUR OPERATION WITH TOMAHAWK MISSILE STRIKES. THE SUBMARINES USS VERMONT (SSN 792) AND USS GEORGIA (SSGN 729) ARE IN THE ARABIAN SEA AND ARE STANDING BY FOR ORDERS. THEY HAVE ALLOCATED US TWELVE MISSILES FROM THE USS VERMONT AND FOURTY EIGHT MISSILES FROM THE USS GEORGIA.',
                    nil
                )
            else
                Israel_MissileStrikesApproved(false)
                TelexMessageToPlayer(
                    'GENERAL HQ<BR>AIR OPERATIONS CENTER//CC//',
                    'MINISTRY OF DEFENSE',
                    'REQUEST FOR US MISSILE STRIKES',
                    'TOP SECRET',
                    'IMMEDIATE',
                    'O',
                    'THE UNITED STATES HAS DENIED TO OUR REQUEST TO SUPPORT OUT OPERATION DIRECTLY.',
                    nil
                )
            end
        end
    end
end

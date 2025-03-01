math.randomseed(os.time())
math.random()

-- =========================
-- Cyber Attack Functions --
-- =========================

-- =========================
-- Aircraft DBIDs to be Disrupted
-- =========================

function AircraftToBeDisrupted(side)
    local sideUnits, result = VP_GetSide({ side = side }).units, {}
    local affectedDBIDs = {
        229, -- F-4D Phantom II
        3896, -- F-4E Phantom II
        6997, -- F-5E Tiger II
        6998, -- F-5F Tiger II
        1354, -- F-7N Fishcan
        1312, -- F-14A Tomcat
        4174, -- F-14E Tomcat
        5836, -- F-14E Tomcat
        5259, -- J-10C Firebird
        5521, -- J-10C Firebird
        1346, -- MiG-29 Fulcrum A
        6728, -- MiG-29 Fulcrum A
        6614, -- Su-35S Flanker M
        6645, -- Su-35S Flanker M
        2232, -- Su-57 Felon
        2423, -- Boeing 707 Tanker
        1660, -- Boeing 747 Tanker
    }

    for _, entry in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = entry.guid })
        for k, v in ipairs(affectedDBIDs) do
            if unit.dbid == v then
                table.insert(result, unit)
                break
            end
        end
    end
    return result
end

-- =========================
-- IADS Unit DBIDs to be Disrupted
-- =========================

function FacilitiesToBeDisrupted(side)
    local sideUnits, result = VP_GetSide({ side = side }).units, {}
    local affectedDBIDs = {
        1815, -- AAA Bty (100mm KS-19 Auto [Sair])
        1814, -- AAA Bty (100mm KS-19 x 4, Fire Can FCR)
        3750, -- AAA Bty (57mm Bahman x 4)
        3749, -- AAA Bty (57mm ZSU-57-2 x 4)
        2395, -- AAA Plt/2 (23mm ZSU-23-2 BTR-60 x 2)
        909, -- AAA Plt/2 (23mm ZSU-23-4 Shilka x 2)
        911, -- AAA Plt/3 (23mm ZU-23-2 x 2)
        3738, -- AAA Plt/3 (23mm ZU-23-8, Mesbah-1 x 2)
        912, -- AAA Sec (35mm Twin Oerlikon x 2)
        910, -- AAA Sec (35mm Twin Oerlikon x 2, Skyguard FCR)
        3933, -- Radar (12A6 SOPKA-2)
        2257, -- Radar (59N6 Protivnik-GE)
        4106, -- Radar (67N6E Gamma-DE [Falaq])
        1047, -- Radar (AN/TPS-70)
        3325, -- Radar (Bashir)
        439, -- Radar (Big Bird C [64N6])
        2443, -- Radar (Big Bird D [91N6])
        1849, -- Radar (Box Spring [1L119 Nebo SVU])
        2735, -- Radar (Cheese Board [96L6E])
        1227, -- Radar (China JY-14 Great Wall)
        2537, -- Radar (China JY-26)
        3419, -- Radar (China JY-27A Wide Mat)
        3599, -- Radar (China YLC-2V [High Guard])
        2538, -- Radar (China YLC-8B)
        3819, -- Radar (China YLC-8E)
        3930, -- Radar (Flat Face E [39N6E Kasta 2E2])
        1242, -- Radar (HFR]
        1065, -- Radar (LRR]
        3236, -- Radar (Najm-802 PESA)
        3519, -- Radar (Prima [P-18-2])
        3418, -- Radar (Quds [Vostok E])
        3321, -- Radar (Rezonans-NE OTH)
        1342, -- Radar (Spoon Rest D [P-18])
        1616, -- Radar (Tall Rack [55Zh6-1 Nebo UYe])
        1847, -- Radar (Tall Rack [55Zh6M Nebo M, RLM-D L-Band])
        1846, -- Radar (Tall Rack [55Zh6M Nebo M, RLM-M VHF-Band])
        3869, -- Radar (Tall Rack [55Zh6UME Nebo UME])
        3237, -- SAM Bn (AD-120 Talash)
        902, -- SAM Bn (HQ-2b
        3280, -- SAM Bn (HQ-9B)
        1277, -- SAM Bn (HQ-12)
        3324, -- SAM Bn (Khordad 3)
        3783, -- SAM Bn (Khordad 15)
        901, -- SAM Bn (SA-6a Gainful [2K12E Kvadrat])
        3013, -- SAM Bn (SA-20b Gargoyle [S-300PMU-2 Favorit])
        3756, -- SAM Bn (Sayyad-1A [Mod. HQ-2 Copy])
        3782, -- SAM Bn (Talash-3)
        3229, -- SAM Bty (AD-200)
        2991, -- SAM Bty (HQ-16B)
        3813, -- SAM Bty (I-HAWK), 3x Launchers
        3238, -- SAM Bty (I-HAWK), 6x Launchers
        3744, -- SAM Bty (Karrar)
        3780, -- SAM Bty (Joshan)
        3786, -- SAM Bty (Raad II)
        3323, -- SAM Bty (Sevom Khordad)
        3753, -- SAM Bty (Tabas)
        476, -- SAM Grp (SA-5c Gammon [S-200M Vega M])
        3784, -- SAM Plt (Dezful [Mod. 9K330 Tor-M1K Copy])
        481, -- SAM Plt (SA-15b Gauntlet [9K330 Tor-M1K])
        3757, -- SAM Plt (SA-17 Grizzly [9K317E Buk-M2E])
        3758, -- SAM Plt (SA-22 Greyhound [Pantsir-S1E])
        2276, -- SAM Plt (SA-27 Grizzly [9K317M Buk-M3])
        3815, -- SAM Plt (Zoubin TELAR x 2)
        3781, -- SAM Sec (AD-08 Majid x 2)
        3752, -- SAM Sec (Herz-9 x 2)
        3044, -- SAM Sec (YZ-3 [Ya Zahra-3] x 2)
    }

    for _, entry in ipairs(sideUnits) do
        local unit = ScenEdit_GetUnit({ guid = entry.guid })
        for k, v in ipairs(affectedDBIDs) do
            if unit.dbid == v then
                table.insert(result, unit)
                break
            end
        end
    end
    return result
end

-- =========================
-- Attack Command and Control Network
-- =========================

function AttackSideCommandAndControlNetwork(targetSide, targetUnitList, chance, insertIntoTableBoolean, disruptedUnitList)
    for _, v in ipairs(targetUnitList) do
        if math.random(1, 100) <= chance then
            local unit = ScenEdit_GetUnit({ guid = v.guid })
            RandomizeUnitProficiency(unit.guid, 40, 100, 0, 0, 0)
            ScenEdit_SetUnit({ guid = unit.guid, autodetectable = true })
            if insertIntoTableBoolean then
                table.insert(disruptedUnitList, unit.guid)
            end
        end
    end

    ScenEdit_SetEvent('Reset ' .. targetSide .. ' Command and Control Network', { isActive = true })
end

-- =========================
-- Reset Command and Control Network
-- =========================

function ResetUnitCommandAndControl(disruptedUnitList, chance)
    for _, guid in ipairs(disruptedUnitList) do
        if math.random(1, 100) <= chance then
            local unit = ScenEdit_GetUnit({ guid = guid })
            RandomizeUnitProficiency(unit.guid, 20, 50, 100, 0, 0)
            if unit.type == 'Aircraft' then
                ScenEdit_SetUnit({ guid = unit.guid, autodetectable = false })
            end

            local position = FindInTable(disruptedUnitList, guid)
            if position then
                table.remove(disruptedUnitList, position)
            end
        end
    end
end

function ResetSideCommandAndControlNetwork(targetSide, resetCounter, resetTime, resetChance, resetThreshold,
                                           disruptedUnitList, chanceIncrement, resetTimeIncrement,
                                           updateGlobalVariablesBoolean, resetCounterKey, resetChanceKey, resetTimeKey)
    -- Increment the counter
    resetCounter = resetCounter + 1

    -- Check if it's time to reset side command and control network
    if resetCounter == resetTime then
        -- Get the current unit reset chance
        local unitResetChance = tonumber(resetChance)

        -- If resetTime reaches or is below the resetThreshold, set unitResetChance to 100
        if resetTime <= resetThreshold then
            unitResetChance = 100
            ScenEdit_SetEvent('Reset ' .. targetSide .. ' Command and Control Network', { isActive = false })
        end

        -- Reset units
        ResetUnitCommandAndControl(disruptedUnitList, unitResetChance)

        -- Increment the chance for the next phase
        if unitResetChance < 100 then
            resetChance = math.min(unitResetChance + chanceIncrement, 100)
        end

        -- Decrement resetTime by resetTimeIncrement
        resetTime = resetTime - resetTimeIncrement

        -- Reset the counter for the next cycle
        resetCounter = 0

        -- Store the updated values back to their respective keys
        -- This only updates the global variable key values
        -- Set the global variables to the new key value outside of this function
        if updateGlobalVariablesBoolean then
            ScenEdit_SetKeyValue(resetCounterKey, tostring(resetCounter))
            ScenEdit_SetKeyValue(resetChanceKey, tostring(resetChance))
            ScenEdit_SetKeyValue(resetTimeKey, tostring(resetTime))
        end
    end
end

-- =========================
-- Attack Communications Network
-- =========================

function AttackSideCommunicationsNetwork(targetSide, targetUnitList, chance, insertIntoTableBoolean, disruptedUnitList)
    for _, v in ipairs(targetUnitList) do
        if math.random(1, 100) <= chance then
            local unit = ScenEdit_GetUnit({ guid = v.guid })
            ScenEdit_SetUnit({ guid = unit.guid, outofcomms = true })
            ScenEdit_SetEMCON('Unit', unit.guid, 'Radar=Active')

            if insertIntoTableBoolean then
                table.insert(disruptedUnitList, unit.guid)
            end
        end
    end

    ScenEdit_SetEvent('Reset ' .. targetSide .. ' Communications Network', { isActive = true })
end

-- =========================
-- Reset Communications Network
-- =========================

function ResetUnitCommunications(disruptedUnitList, chance)
    for _, guid in ipairs(disruptedUnitList) do
        if math.random(1, 100) <= chance then
            local unit = ScenEdit_GetUnit({ guid = guid })
            ScenEdit_SetUnit({ guid = unit.guid, outofcomms = false })

            local position = FindInTable(disruptedUnitList, guid)
            if position then
                table.remove(disruptedUnitList, position)
            end
        end
    end
end

function ResetSideCommunicationsNetwork(targetSide, resetCounter, resetTime, resetChance, resetThreshold,
                                        disruptedUnitList, chanceIncrement, resetTimeIncrement,
                                        updateGlobalVariablesBoolean, resetCounterKey, resetChanceKey, resetTimeKey)
    -- Increment the counter
    resetCounter = (resetCounter or 0) + 1

    -- Check if it's time to reset communications
    if resetCounter == resetTime then
        -- Get the current chance for resetting
        local unitResetChance = resetChance

        -- If resetTime reaches or is below the resetThreshold, set unitResetChance to 100
        if resetTime <= resetThreshold then
            unitResetChance = 100
            ScenEdit_SetEvent('Reset ' .. targetSide .. ' Communications Network', { isActive = false })
        end

        -- Reset units
        ResetUnitCommunications(disruptedUnitList, unitResetChance)

        -- Increment the chance for the next phase
        if unitResetChance < 100 then
            resetChance = math.min(unitResetChance + chanceIncrement, 100)
        end

        -- Decrement resetTime by resetTimeIncrement
        resetTime = resetTime - resetTimeIncrement

        -- Reset the counter for the next cycle
        resetCounter = 0

        -- Store the updated values back to their respective keys
        -- This only updates the global variable key values
        -- Set the global variables to the new key value outside of this function
        if updateGlobalVariablesBoolean then
            ScenEdit_SetKeyValue(resetCounterKey, tostring(resetCounter))
            ScenEdit_SetKeyValue(resetChanceKey, tostring(resetChance))
            ScenEdit_SetKeyValue(resetTimeKey, tostring(resetTime))
        end
    end
end

-- =========================
-- Attack Sensor Network Network
-- =========================

function AttackSideSensorNetwork_FalseContacts(targetSide, numFalseContacts, chance, centerPoint, falseContactSide,
                                               falseContactDBID, falseContactLoadoutID, falseContactAltitude,
                                               falseContactHeading, falseContactMission, insertIntoTableBoolean,
                                               falseContactUnitList)
    for i = 1, numFalseContacts do
        if math.random(1, 100) <= chance then
            local position = CircularRandomPosition(centerPoint.latitude, centerPoint.longitude, centerPoint.maxRange)
            local newFalseContact = ScenEdit_AddUnit({
                side = falseContactSide,
                type = 'Aircraft',
                dbid = falseContactDBID,
                name = 'False Contact',
                loadoutid = falseContactLoadoutID,
                latitude = position.latitude,
                longitude = position.longitude,
                altitude = falseContactAltitude,
                heading = falseContactHeading
            })

            ScenEdit_AssignUnitToMission(newFalseContact.guid, falseContactMission)

            if insertIntoTableBoolean == true then
                table.insert(falseContactUnitList, newFalseContact.guid)
            end
        end
    end

    ScenEdit_SetEvent('Reset ' .. targetSide .. ' Sensor Network', { isActive = true })
end

function AttackSideSensorNetwork_FalseMissileStrike(targetGUID, chance, centerPoint, numWeapons, weaponSide, weaponDBID,
                                                    weaponName, weaponAltitude, salvoSpacing)
    if math.random(1, 100) <= chance then
        AddWeaponSalvo(targetGUID, centerPoint, numWeapons, weaponSide, weaponDBID, weaponName, weaponAltitude,
            salvoSpacing)
    end
end

-- =========================
-- Reset Sensor Network False Contacts
-- =========================

function ResetSensorNetwork(disruptedUnitList, chance)
    for _, guid in ipairs(disruptedUnitList) do
        if math.random(1, 100) <= chance then
            local unit = ScenEdit_GetUnit({ guid = guid })
            ScenEdit_DeleteUnit({ guid = unit.guid })

            local position = FindInTable(disruptedUnitList, guid)
            if position then
                table.remove(disruptedUnitList, position)
            end
        end
    end
end

function ResetSideSensorNetwork(targetSide, resetCounter, resetTime, resetChance, resetThreshold, disruptedUnitList,
                                chanceIncrement, resetTimeIncrement, updateGlobalVariablesBoolean, resetCounterKey,
                                resetChanceKey, resetTimeKey)
    -- Increment the counter
    resetCounter = (resetCounter or 0) + 1

    -- Check if it's time to reset sensor network
    if resetCounter == resetTime then
        -- Get the current chance for resetting
        local unitResetChance = resetChance

        -- If resetTime reaches or is below the resetThreshold, set unitResetChance to 100
        if resetTime <= resetThreshold then
            unitResetChance = 100
            ScenEdit_SetEvent('Reset ' .. targetSide .. ' Sensor Network', { isActive = false })
        end

        -- Reset units
        ResetSensorNetwork(disruptedUnitList, unitResetChance)

        -- Increment the chance for the next phase
        if unitResetChance < 100 then
            resetChance = math.min(unitResetChance + chanceIncrement, 100)
        end

        -- Decrement resetTime by resetIncrement
        resetTime = resetTime - resetIncrement

        -- Reset the counter for the next cycle
        resetCounter = 0

        -- Store the updated values back to their respective keys
        -- This only updates the global variable key values
        -- Set the global variables to the new key value outside of this function
        if updateGlobalVariablesBoolean then
            ScenEdit_SetKeyValue(resetCounterKey, tostring(resetCounter))
            ScenEdit_SetKeyValue(resetChanceKey, tostring(resetChance))
            ScenEdit_SetKeyValue(resetTimeKey, tostring(resetTime))
        end
    end
end

-- ===================
-- Cyber Operations --
-- ===================

-- =========================
-- Conduct Cyberattack Against Iranian Command and Control Network
-- =========================

function PlayerAttackIranianCommandAndControlNetwork()
    local TargetAircraftList = AircraftToBeDisrupted('Iran')
    local TargetFacilityList = FacilitiesToBeDisrupted('Iran')
    AttackSideCommandAndControlNetwork('Iran', TargetAircraftList, PlayerCyberChance, true,
        IranDisruptedCommandAndControlUnitList)
    AttackSideCommandAndControlNetwork('Iran', TargetFacilityList, PlayerCyberChance, true,
        IranDisruptedCommandAndControlUnitList)

    -- Increment cyber chance by increment
    PlayerCyberChance = PlayerCyberChance - PlayerCyberIncrement
    ScenEdit_SetKeyValue('PlayerCyberChanceKey', PlayerCyberChance)

    -- Serialize and store disrupted unit list
    storeData(IranDisruptedCommandAndControlUnitList, 'IranDisruptedCommandAndControlUnitListKey')
end

-- =========================
-- Conduct Cyberattack Against Iranian Communications Network
-- =========================

function PlayerAttackIranianCommunicationsNetwork()
    local TargetFacilityList = FacilitiesToBeDisrupted('Iran')
    AttackSideCommunicationsNetwork('Iran', TargetFacilityList, PlayerCyberChance, true,
        IranDisruptedCommunicationsUnitList)

    -- Increment cyber chance by increment
    PlayerCyberChance = PlayerCyberChance - PlayerCyberIncrement
    ScenEdit_SetKeyValue('PlayerCyberChanceKey', PlayerCyberChance)

    -- Serialize and store disrupted unit list
    storeData(IranDisruptedCommunicationsUnitList, 'IranDisruptedCommunicationsUnitListKey')
end

-- =========================
-- Conduct Cyberattack Against Iranian Sensor Network (False Contacts)
-- =========================

function PlayerAttackIranianSensorNetwork_FalseContacts(centerPoint, initialFalseContactHeading)
    AttackSideSensorNetwork_FalseContacts('Iran', math.random(30, 60), PlayerCyberChance, centerPoint,
        'Decoys-False Contacts', 4921, 5857, '25000 ft', initialFalseContactHeading, 'False Contacts Patrol', true,
        IranFalseContactsList)

    -- Increment cyber chance by increment
    PlayerCyberChance = PlayerCyberChance - PlayerCyberIncrement
    ScenEdit_SetKeyValue('PlayerCyberChanceKey', PlayerCyberChance)

    -- Serialize and store false contact unit list
    storeData(IranFalseContactsList, 'IranFalseContactsListKey')
end

-- =========================
-- Conduct Cyberattack Against Iranian Sensor Network (False Missile Strike)
-- =========================

function PlayerCyberAttackIranianSensors_FalseMissileStrike(targetGUID, centerPoint)
    AttackSideSensorNetwork_FalseMissileStrike(targetGUID, PlayerCyberChance, centerPoint, 24, 'Decoys-False Contacts',
        2441, 'False Contact', '10000 ft', 0.1)

    -- Increment cyber chance by increment
    PlayerCyberChance = PlayerCyberChance - PlayerCyberIncrement / 4
    ScenEdit_SetKeyValue('PlayerCyberChanceKey', PlayerCyberChance)
end

-- ==========================
-- Cyber Operations Center --
-- ==========================

function PlayerCyberOperationsCenter()
    local msg = [[
		<html>
			<head>
				<style>
					body{
						font-family: 'Consolas', 'Lucida Console', monospace;
						background-color: #000000; /* Black background */
						color: #C0C0C0; /* Light gray text */
						text-align: justify;
					}

					.container{
						font-family: 'Consolas', 'Lucida Console', monospace; /* Apply font to container content */
						background-color: #000000; /* Black background */
						margin: auto;
						border-radius: 8px;
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
						padding: 8px;
					}

					td {
						width: 500px;
					}

					select {
						font-family: 'Consolas', 'Lucida Console', monospace; /* Apply font to select */
						background-color: #000000; /* Black background */
						color: #F0F0F0; /* Lighter gray text */
						padding: 5px; /* Add padding for consistent spacing */
						border: 1px solid #C0C0C0; /* Add a border to match the light gray color scheme */
					}

					#hidden {
						display: none;
					}

					:checked + #hidden {
						display: block;
					}

					.hidden {
						display: none;
					}

					/* Show Direction Dropdown when "False Contacts" or "Missile Strike" is selected */
					#cyber_attack_1_false_contacts:checked ~ #cyber_attack_1_position_selector,
					#cyber_attack_1_missile_strike:checked ~ #cyber_attack_1_position_selector,
					#cyber_attack_2_false_contacts:checked ~ #cyber_attack_2_position_selector,
					#cyber_attack_2_missile_strike:checked ~ #cyber_attack_2_position_selector {
						display: block;
					}

					/* Show Target Selector when "Missile Strike" is selected */
					#cyber_attack_1_missile_strike:checked ~ #cyber_attack_1_missile_target_selector,
					#cyber_attack_2_missile_strike:checked ~ #cyber_attack_2_missile_target_selector {
						display: block;
					}

					.target-row {
						display: flex;
						justify-content: space-around; /* Align dropdowns horizontally */
						gap: 10px; /* Add spacing between dropdowns */
					}

					label {
						margin-right: 5px; /* Space between label and dropdown */
					}
				</style>
				<meta charset="UTF-8">
				<meta name="viewport" content="width=device-width, initial-scale=1.0">
				<title>Cyber Operations Console</title>
			</head>
			<body>
				<div class="outer-container">
					<div class="container">
						<h1>Cyber Operations Center</h1>
						<table>
							<tr>
								<td>
									<p><b>Cyber Operations Rules:</b></p>
									<input type="checkbox" id="cyber_operations_rules" style="display:none;">
									<div id="hidden">
										<p>You may conduct up to two cyber-attack methods simultaneously. You will need to reopen this menu if you wish to conduct additional actions.</p>
										<p>Each action will reduce the effectiveness of subsequent actions. If you are using the default "Fixed" event chances scenario option, the first cyber action has a high chance of success. The second attack will have a moderate chance of success. Additional cyber actions will have a low to no chance of success. Experience will vary if using the "Random" event chance scenario option. If you selected "Remove Randomization" you may conduct as many actions as you wish with a high chance of success.</p>
										<p>Most effects will last for a limited period of time. Depending on the action, recovery from the effect may not be instantaneous. It may take several hours for Iranian units to fully recover. Each effect has its own recovery check event. After each recovery check phase, the time to the next phase decreases and the chance of unit recovering increases.</p>
										<p>Cyber-attack method targets/effects:</p>
										<ul>
											<li><b>Iranian Command and Control Network:</b> Affected units will have their proficiency reduced and position and movements revealed. Aircraft positions and movement will only be known for a limited period of time. However, fixed facilities will always remain known.</li>
											<li><b>Iranian Air Defenses:</b> Affected units will have their communications disrupted, no longer sending or receiving information to/from other units.</li>
											<li><b>Iranian Sensor Network (False Contacts):</b> Creates 30-60 false contacts (decoys) and orders them to fly around Iranian airspace. In addition to lasting for a limited period of time, false contacts will be deleted if they are identified.</li>
											<li><b>Iranian Sensor Network (False Missile Strike):</b> Creates 24 false missiles (decoys) targeted at the selected target(s). False missiles will be deleted if they are identified or when they approach within 5 nautical miles of their target. You can target the Arak Heavy Water Plant, Esfahan Uranium Conversion Facility, Fordow Fuel Enrichment Plant and Natanz Fuel Enrichment Plant. Each selected target will reduce the success chance of subsequent actions by a quarter of the normal value.</li>
										</ul>
										<p>Most effects are not cumulative. Running the same attack method more than once will not increase the chances of success or the effects. The exception to this rule is the attack sensor network actions. Executing these actions multiple times does have the potential to create additional false contacts.</p>
										<p>False Contact Starting/Launch Positions:</p>
										<ul>
											<li><b>West:</b> False contacts will be created over central Iraq. Will fly into Iranian airspace from the West.</li>
											<li><b>Southwest:</b> False contacts will be created over Kuwait-Saudi Arabia-Iraq border region. Will fly into Iranian airspace from the Southwest.</li>
											<li><b>South:</b> False contacts will be created over Qatar, Saudi Arabia, and the Persian Gulf. Will fly into Iranian airspace from the South.</li>
											<li><b>Southeast:</b> False contacts will be created over the Gulf of Oman. They will fly into Iranian airspace from the Southeast.</li>
										</ul>
									</div>
									<label for="cyber_operations_rules">Show/Hide</label>
								</td>
							</tr>
							<tr>
								<td>
									<p><b>Cyber Attack 1</b></p>
									<!-- Radio Buttons for Cyber Attack Methods -->
									<input type="radio" name="cyber_attack_1" id="cyber_attack_1_none" value="None" checked>
									<label for="cyber_attack_1_none">None</label><br>

									<input type="radio" name="cyber_attack_1" id="cyber_attack_1_c2" value="C2">
									<label for="cyber_attack_1_c2">Iranian Command and Control Network</label><br>

									<input type="radio" name="cyber_attack_1" id="cyber_attack_1_air_defenses" value="IADS">
									<label for="cyber_attack_1_air_defenses">Iranian Air Defenses Network</label><br>

									<input type="radio" name="cyber_attack_1" id="cyber_attack_1_false_contacts" value="False_Contacts">
									<label for="cyber_attack_1_false_contacts">Iranian Sensor Network (False Contacts)</label><br>

									<input type="radio" name="cyber_attack_1" id="cyber_attack_1_missile_strike" value="Missile_Strike">
									<label for="cyber_attack_1_missile_strike">Iranian Sensor Network (False Missile Strike)</label><br>

									<!-- Position Selector for False Contacts -->
									<div id="cyber_attack_1_position_selector" class="hidden">
										<p>False Contact(s) Starting/Launch Position</p>
										<select name="cyber_attack_1_position">
											<option value="West">West</option>
											<option value="Southwest">Southwest</option>
											<option value="South">South</option>
											<option value="Southeast">Southeast</option>
										</select>
									</div>

									<!-- Target Selector for False Missile Strike -->
									<div id="cyber_attack_1_missile_target_selector" class="hidden">
										<p>Target Selection for False Missile Strike</p>
										<div class="target-row">
											<label for="missile_strike_1_target_arak">Arak:</label>
											<select id="missile_strike_1_target_arak" name="missile_strike_1_arak">
												<option value="No">No</option>
												<option value="Yes">Yes</option>
											</select>

											<label for="missile_strike_1_target_esfahan">Esfahan:</label>
											<select id="missile_strike_1_target_esfahan" name="missile_strike_1_esfahan">
												<option value="No">No</option>
												<option value="Yes">Yes</option>
											</select>

											<label for="missile_strike_1_target_fordow">Fordow:</label>
											<select id="missile_strike_1_target_fordow" name="missile_strike_1_fordow">
												<option value="No">No</option>
												<option value="Yes">Yes</option>
											</select>

											<label for="missile_strike_1_target_natanz">Natanz:</label>
											<select id="missile_strike_1_target_natanz" name="missile_strike_1_natanz">
												<option value="No">No</option>
												<option value="Yes">Yes</option>
											</select>
										</div>
									</div>
								</td>
							</tr>
							<tr>
								<td>
									<p><b>Cyber Attack 2</b></p>
									<!-- Radio Buttons for Cyber Attack Methods -->
									<input type="radio" name="cyber_attack_2" id="cyber_attack_2_none" value="None" checked>
									<label for="cyber_attack_2_none">None</label><br>

									<input type="radio" name="cyber_attack_2" id="cyber_attack_2_c2" value="C2">
									<label for="cyber_attack_2_c2">Iranian Command and Control Network</label><br>

									<input type="radio" name="cyber_attack_2" id="cyber_attack_2_air_defenses" value="IADS">
									<label for="cyber_attack_2_air_defenses">Iranian Air Defenses Network</label><br>

									<input type="radio" name="cyber_attack_2" id="cyber_attack_2_false_contacts" value="False_Contacts">
									<label for="cyber_attack_2_false_contacts">Iranian Sensor Network (False Contacts)</label><br>

									<input type="radio" name="cyber_attack_2" id="cyber_attack_2_missile_strike" value="Missile_Strike">
									<label for="cyber_attack_2_missile_strike">Iranian Sensor Network (False Missile Strike)</label><br>

									<!-- Position Selector for False Contacts -->
									<div id="cyber_attack_2_position_selector" class="hidden">
										<p>False Contact(s) Starting/Launch Position</p>
										<select name="cyber_attack_2_position">
											<option value="West">West</option>
											<option value="Southwest">Southwest</option>
											<option value="South">South</option>
											<option value="Southeast">Southeast</option>
										</select>
									</div>

									<!-- Target Selector for False Missile Strike -->
									<div id="cyber_attack_2_missile_target_selector" class="hidden">
										<p>Target Selection for False Missile Strike</p>
										<div class="target-row">
											<label for="missile_strike_2_target_arak">Arak:</label>
											<select id="missile_strike_2_target_arak" name="missile_strike_2_arak">
												<option value="No">No</option>
												<option value="Yes">Yes</option>
											</select>

											<label for="missile_strike_2_target_esfahan">Esfahan:</label>
											<select id="missile_strike_2_target_esfahan" name="missile_strike_2_esfahan">
												<option value="No">No</option>
												<option value="Yes">Yes</option>
											</select>

											<label for="missile_strike_2_target_fordow">Fordow:</label>
											<select id="missile_strike_2_target_fordow" name="missile_strike_2_fordow">
												<option value="No">No</option>
												<option value="Yes">Yes</option>
											</select>

											<label for="missile_strike_2_target_natanz">Natanz:</label>
											<select id="missile_strike_2_target_natanz" name="missile_strike_2_natanz">
												<option value="No">No</option>
												<option value="Yes">Yes</option>
											</select>
										</div>
									</div>
								</td>
							</tr>
						</table>
					</div>
				</div>
			</body>
		</html>
	]]

    local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
    if form['pressed'] and form['pressed'] == 'Done' then
        if PlayerCyberChance > 0 then
            local cyberAction_01 = string.gsub(form['cyber_attack_1'], "%'", "")
            if cyberAction_01 == 'C2' then
                PlayerAttackIranianCommandAndControlNetwork()
            elseif cyberAction_01 == 'IADS' then
                PlayerAttackIranianCommunicationsNetwork()
            elseif cyberAction_01 == 'False_Contacts' then
                local position = {}
                local decoyHeading = 0

                local positionInput = string.gsub(form['cyber_attack_1_position'], "%'", "")
                if positionInput == 'West' then
                    position = { latitude = 33.0, longitude = 43.0, maxRange = 100 }
                    decoyHeading = 90
                elseif positionInput == 'Southwest' then
                    position = { latitude = 29.0, longitude = 45.0, maxRange = 100 }
                    decoyHeading = 45
                elseif positionInput == 'South' then
                    position = { latitude = 25.0, longitude = 50.0, maxRange = 100 }
                    decoyHeading = 0
                elseif positionInput == 'Southeast' then
                    position = { latitude = 23.0, longitude = 57.0, maxRange = 100 }
                    decoyHeading = 315
                end

                PlayerAttackIranianSensorNetwork_FalseContacts(position, decoyHeading)
            elseif cyberAction_01 == 'Missile_Strike' then
                local targetList = {}
                local centerPoint = {}

                local targetOptions = {
                    { form = 'missile_strike_1_arak',  unitName = 'Arak Heavy Water Production Plant' },
                    { form = 'missile_strike_1_esfahan', unitName = 'Esfahãn Uranium Conversion Facility' },
                    { form = 'missile_strike_1_fordow', unitName = 'Fordow Fuel Enrichment Plant' },
                    { form = 'missile_strike_1_natanz', unitName = 'Natanz Fuel Enrichment Plant' }
                }

                for _, target in ipairs(targetOptions) do
                    local targetInput = string.gsub(form[target.form], "%'", "")
                    if targetInput == 'Yes' then
                        local targetData = ScenEdit_GetContact({ side = 'Decoys-False Contacts', name = target.unitName })
                        table.insert(targetList, targetData.guid)
                    end
                end

                local positionInput = string.gsub(form['cyber_attack_1_position'], "%'", "")
                if positionInput == 'West' then
                    position = { latitude = 33.0, longitude = 43.0, maxRange = 0 }
                elseif positionInput == 'Southwest' then
                    position = { latitude = 29.0, longitude = 45.0, maxRange = 0 }
                elseif positionInput == 'South' then
                    position = { latitude = 25.0, longitude = 50.0, maxRange = 0 }
                elseif positionInput == 'Southeast' then
                    position = { latitude = 23.0, longitude = 57.0, maxRange = 0 }
                end

                for _, target in ipairs(targetList) do
                    PlayerCyberAttackIranianSensors_FalseMissileStrike(target, position)
                end
            end

            local cyberAction_02 = string.gsub(form['cyber_attack_2'], "%'", "")
            if cyberAction_02 == 'C2' then
                PlayerAttackIranianCommandAndControlNetwork()
            elseif cyberAction_02 == 'IADS' then
                PlayerAttackIranianCommunicationsNetwork()
            elseif cyberAction_02 == 'False_Contacts' then
                local position = {}
                local decoyHeading = 0

                local positionInput = string.gsub(form['cyber_attack_2_position'], "%'", "")
                if positionInput == 'West' then
                    position = { latitude = 33.0, longitude = 43.0, maxRange = 100 }
                    decoyHeading = 90
                elseif positionInput == 'Southwest' then
                    position = { latitude = 29.0, longitude = 45.0, maxRange = 100 }
                    decoyHeading = 45
                elseif positionInput == 'South' then
                    position = { latitude = 25.0, longitude = 50.0, maxRange = 100 }
                    decoyHeading = 0
                elseif positionInput == 'Southeast' then
                    position = { latitude = 23.0, longitude = 57.0, maxRange = 100 }
                    decoyHeading = 315
                end

                PlayerAttackIranianSensorNetwork_FalseContacts(position, decoyHeading)
            elseif cyberAction_02 == 'Missile_Strike' then
                local targetList = {}
                local centerPoint = {}

                local targetOptions = {
                    { form = 'missile_strike_2_arak',  unitName = 'Arak Heavy Water Production Plant' },
                    { form = 'missile_strike_2_esfahan', unitName = 'Esfahãn Uranium Conversion Facility' },
                    { form = 'missile_strike_2_fordow', unitName = 'Fordow Fuel Enrichment Plant' },
                    { form = 'missile_strike_2_natanz', unitName = 'Natanz Fuel Enrichment Plant' }
                }

                for _, target in ipairs(targetOptions) do
                    local targetInput = string.gsub(form[target.form], "%'", "")
                    if targetInput == 'Yes' then
                        local targetData = ScenEdit_GetContact({ side = 'Decoys-False Contacts', name = target.unitName })
                        table.insert(targetList, targetData.guid)
                    end
                end

                local positionInput = string.gsub(form['cyber_attack_2_position'], "%'", "")
                if positionInput == 'West' then
                    position = { latitude = 33.0, longitude = 43.0, maxRange = 0 }
                elseif positionInput == 'Southwest' then
                    position = { latitude = 29.0, longitude = 45.0, maxRange = 0 }
                elseif positionInput == 'South' then
                    position = { latitude = 25.0, longitude = 50.0, maxRange = 0 }
                elseif positionInput == 'Southeast' then
                    position = { latitude = 23.0, longitude = 57.0, maxRange = 0 }
                end

                for _, target in ipairs(targetList) do
                    PlayerCyberAttackIranianSensors_FalseMissileStrike(target, position)
                end
            end
        else
            -- Iran has adapted to our cyber efforts or player cyber resources exhausted
        end
    end
end

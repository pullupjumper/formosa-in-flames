local CONFIG = require("src.core.constants")

---comment
---@return table
function CountUnitsInEachArea()
  local unitsFromChina = VP_GetSide({ Side = 'China' }).units
  local result = {}

  for _, zone in ipairs(CONFIG.c.PHIBOP.operationalZones) do
    local item = {
      ['ZBD-05'] = 0,
      ['ZTD-05'] = 0,
      ['PLL-05'] = 0,
      ['PLZ-96'] = 0,
      ['PGZ-09'] = 0,
      ['PGZ-95'] = 0,
      ['SA-15'] = 0,
      ['AirborneCorps'] = 0,
      ['HMMWV'] = 0,
      ['ZBD-03'] = 0
    }
    for _, value in ipairs(unitsFromChina) do
      local unit = SE_GetUnit({ guid = value.guid })

      if unit and unit:inArea(zone.area) then
        if unit.dbid == CONFIG.platformDBID58 then
          item['ZBD-05'] = item['ZBD-05'] + 1
        end

        if unit.dbid == CONFIG.platformDBID59 then
          item['ZTD-05'] = item['ZTD-05'] + 1
        end

        if unit.dbid == CONFIG.platformDBID60 then
          item['PLL-05'] = item['PLL-05'] + 1
        end

        if unit.dbid == CONFIG.platformDBID61 then
          item['PLZ-96'] = item['PLZ-96'] + 1
        end

        if unit.dbid == CONFIG.platformDBID62 then
          item['PGZ-09'] = item['PGZ-09'] + 1
        end

        if unit.dbid == CONFIG.platformDBID63 then
          item['PGZ-95'] = item['PGZ-95'] + 1
        end

        if unit.dbid == CONFIG.platformDBID66 then
          item['SA-15'] = item['SA-15'] + 1
        end

        if unit.dbid == CONFIG.platformDBID65 then
          item['AirborneCorps'] = item['AirborneCorps'] + 1
        end

        if unit.dbid == CONFIG.platformDBID64 then
          item['HMMWV'] = item['HMMWV'] + 1
        end

        if unit.dbid == CONFIG.platformDBID39 then
          item['ZBD-03'] = item['ZBD-03'] + 1
        end
      end
    end

    result[zone.name] = item
  end

  return result
end

function LandedUnitTable()
  local result = CountUnitsInEachArea()

  local HTMLTemplate = [[
    <!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dynamic Table</title>
    <style>
        body {
            background-color: black;
            color: white;
            font-family: Arial, sans-serif;
        }
        table {
            width: 100%% ;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid white;
            padding: 10px;
            text-align: center;
        }
        th {
            background-color: #333;
        }
    </style>
</head>
<body>

    <table id="dataTable">
        <thead>
            <tr>
                <th>Area</th>
                <th>Unit Type</th>
                <th>Count</th>
            </tr>
        </thead>
        <tbody id="tableBody"></tbody>
    </table>

    <script>
        const dataString = `%s`;

        let data = JSON.parse(dataString);
        let tableBody = document.getElementById("tableBody");

        Object.keys(data).forEach(area => {
            const unitTypes = Object.keys(data[area]);
            unitTypes.forEach((unitType, index) => {
                let row = document.createElement("tr");

                if (index === 0) {
                    let areaCell = document.createElement("td");
                    areaCell.textContent = area;
                    areaCell.rowSpan = unitTypes.length;
                    row.appendChild(areaCell);
                }

                let typeCell = document.createElement("td");
                typeCell.textContent = unitType;
                row.appendChild(typeCell);

                let countCell = document.createElement("td");
                countCell.textContent = data[area][unitType];
                row.appendChild(countCell);

                tableBody.appendChild(row);
            });
        });
    </script>
</body>
</html>
    ]]
  local msg = string.format(HTMLTemplate, gKH.json.stringify(result))
  local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
end

function C2Table(side)
  local saveData = gKH.State.LoadTableFromKey("SaveData")

  if saveData == nil then
    ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
    return
  end

  local createDataString = function(side, ...)
    local key = 't'

    if side == 'China' then
      key = 'c'
    end

    local rows = {}
    local types = { ... }

    for _, type in pairs(types) do
      for index, item in pairs(saveData[key].IADS[type]) do
        if rows[type] == nil then
          rows[type] = {}
        end

        rows[type][item.guid] = { name = item.name }

        if item.SAM then
          rows[type][item.guid]['SAM'] = {}

          for _, sam in pairs(item.SAM) do
            local unit = SE_GetUnit({ guid = sam.guid })
            local isDestroyed = unit == nil
            rows[type][item.guid]['SAM'][sam.guid] = {
              name = sam.name,
              OODADetection = tostring(sam.currOODA.detection) .. '/' .. tostring(sam.OODA.detection),
              OODATargeting = tostring(sam.currOODA.targeting) .. '/' .. tostring(sam.OODA.targeting),
              isOutOfComms = sam.isOutOfComms,
              EMCONSetting = sam.EMCONSetting,
              isDestroyed = isDestroyed
            }
          end
        end

        if item.radar then
          rows[type][item.guid]['radar'] = { name = item.name }

          for _, radar in pairs(item.radar) do
            local unit = SE_GetUnit({ guid = radar.guid })
            local isDestroyed = unit == nil
            rows[type][item.guid]['radar'][radar.guid] = {
              name = radar.name,
              OODADetection = tostring(radar.currOODA.detection) .. '/' .. tostring(radar.OODA.detection),
              OODATargeting = tostring(radar.currOODA.targeting) .. '/' .. tostring(radar.OODA.targeting),
              isOutOfComms = radar.isOutOfComms,
              EMCONSetting = radar.EMCONSetting,
              isDestroyed = isDestroyed
            }
          end
        end
      end
    end

    return gKH.json.stringify(rows)
  end

  local HTMLTemplate = [[
   <!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dynamic Table</title>
    <style>
        body {
            background-color: black;
            color: white;
            font-family: Arial, sans-serif;
        }

        table {
            width: 100%% ;
            border-collapse: collapse;
            margin-top: 20px;
        }

        th,
        td {
            border: 1px solid white;
            padding: 10px;
            text-align: center;
        }

        th {
            background-color: #333;
        }
    </style>
</head>

<body>

    <table id="dataTable">
        <thead>
            <tr id="tableHead"></tr>
        </thead>
        <tbody id="tableBody"></tbody>
    </table>

    <script>
        const dataString = `%s`;

        let data = JSON.parse(dataString);
        let tableHead = document.getElementById("tableHead");
        let tableBody = document.getElementById("tableBody");

        let headers = ["C2 Node", "Name", "OODA Detection", "OODA Targeting", "Out of Comms", "EMCON Setting", "Destroyed"];
        headers.forEach(header => {
            let th = document.createElement("th");
            th.textContent = header;
            tableHead.appendChild(th);
        });

        Object.keys(data).forEach(area => {
            Object.keys(data[area]).forEach(subArea => {
                let unitTypes = Object.keys(data[area][subArea]).filter(type => type !== "name");
                let totalUnits = unitTypes.reduce((sum, type) => sum + Object.keys(data[area][subArea][type]).length, 0);
                let firstRow = true;

                unitTypes.forEach(type => {
                    Object.keys(data[area][subArea][type]).forEach((unitName) => {
                        let unit = data[area][subArea][type][unitName];
                        let row = document.createElement("tr");

                        if (firstRow) {
                            let areaCell = document.createElement("td");
                            areaCell.textContent = data[area][subArea].name;
                            areaCell.rowSpan = totalUnits;
                            row.appendChild(areaCell);
                            firstRow = false;
                        }

                        ["name", "OODADetection", "OODATargeting", "isOutOfComms", "EMCONSetting", "isDestroyed"].forEach(key => {
                            let cell = document.createElement("td");
                            cell.textContent = typeof unit[key] === "boolean" ? (unit[key] ? "YES" : "NO") : unit[key];
                            row.appendChild(cell);
                        });

                        tableBody.appendChild(row);
                    });
                });
            });
        });
    </script>

</body>

</html>
    ]]
  local str
  if side == 'China' then
    str = createDataString(side, 'C2')
  else
    str = createDataString(side, 'ROCC', 'TAAOC')
  end
  local msg = string.format(HTMLTemplate, str)
  local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
end

function BtyStateTable(side)
  local saveData = gKH.State.LoadTableFromKey("SaveData")

  if saveData == nil then
    ScenEdit_SpecialMessage('Taiwan', 'saveData is nil')
    return
  end

  local createDataString = function(side, ...)
    local key = 't'
    local wpnSystems = { ... }

    if side == 'China' then
      key = 'c'
    end

    local rows = {}

    for index, wpnSystem in pairs(wpnSystems) do
      if saveData[key].ground[wpnSystem] and saveData[key].ground[wpnSystem].ammunitionSections then
        for k, value in pairs(saveData[key].ground[wpnSystem].ammunitionSections) do
          rows[k] = {}
        end
      end
    end

    for index, wpnSystem in pairs(wpnSystems) do
      if saveData[key].ground[wpnSystem] and saveData[key].ground[wpnSystem].batteries then
        for _, bty in pairs(saveData[key].ground[wpnSystem].batteries) do
          local name = bty.name
          local status = ''
          local remainingAmmoInVehicles = saveData[key].ground[wpnSystem].ammunitionSections[bty.ammunitionSection]
              .wpnCurrent
          local ammoSec = saveData[key].ground[wpnSystem].ammunitionSections[bty.ammunitionSection]
          local reloadTime = CONFIG[key].ground[wpnSystem].reloadTime / 60
          local remainingAmmo = saveData[key].ground[wpnSystem].ammunitions
              [saveData[key].ground[wpnSystem].ammunitionSections[bty.ammunitionSection].ammunition].wpnCurrent
          local reloadingRemainingTime = nil
          local transloadingRemainingTime = nil

          if bty.state == 0 then
            status = 'STATIC'
          elseif bty.state == 1 then
            status = 'REPOSITIONING'
          elseif bty.state == 2 then
            status = 'RELOAD'
          else
            status = 'HIDE'
          end

          if bty.reloadStartTime ~= nil then
            reloadingRemainingTime = math.floor(((ScenEdit_CurrentTime() - bty.reloadStartTime) / 60) * 100 +
                  0.5) /
                100

            if reloadingRemainingTime < 0 then
              reloadingRemainingTime = 0
            end
          end

          if bty.reloadStartTime == nil then
            reloadingRemainingTime = 0
          end

          if ammoSec.reloadStartTime ~= nil then
            transloadingRemainingTime = math.floor(((ScenEdit_CurrentTime() - ammoSec.reloadStartTime) / 60) *
              100 +
              0.5) / 100

            if transloadingRemainingTime < 0 then
              transloadingRemainingTime = 0
            end
          end

          if ammoSec.reloadStartTime == nil then
            transloadingRemainingTime = 0
          end

          if side == 'China' then
            table.insert(rows[bty.ammunitionSection], {
              name = name,
              type = wpnSystem,
              status = status,
              remainingAmmoInVehicles = remainingAmmoInVehicles,
              remainingAmmo = remainingAmmo,
              reloadTimeForBty = reloadingRemainingTime,
              reloadTimeForAmmoSec = transloadingRemainingTime,
              defaultReloadTime = reloadTime
            })
          else
            table.insert(rows[bty.ammunitionSection], {
              name = name,
              type = wpnSystem,
              remainingAmmoInVehicles = remainingAmmoInVehicles,
              remainingAmmo = remainingAmmo,
              reloadTimeForBty = reloadingRemainingTime,
              reloadTimeForAmmoSec = transloadingRemainingTime,
              defaultReloadTime = reloadTime
            })
          end
        end
      end
    end

    return gKH.json.stringify(rows)
  end

  local HTMLTemplate = [[
   <!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dynamic Table</title>
    <style>
        body {
            background-color: black;
            color: white;
            font-family: Arial, sans-serif;
        }

        table {
            width: 100%%;
            border-collapse: collapse;
            margin-top: 20px;
        }

        th,
        td {
            border: 1px solid white;
            padding: 10px;
            text-align: center;
        }

        th {
            background-color: #333;
        }

        .progress-container {
            width: 100px;
            background-color: #555;
            border-radius: 5px;
            overflow: hidden;
            position: relative;
        }

        .progress-bar {
            height: 14px;
            background-color: #4caf50;
        }

        .progress-text {
            position: absolute;
            width: 120px;
            top: 50%% ;
            left: 50%% ;
            transform: translate(-50%%, -50%%);
            font-size: 9px;
            color: white;
        }
    </style>
</head>

<body>

    <table id="dataTable">
        <thead>
            <tr id="tableHead"></tr>
        </thead>
        <tbody id="tableBody"></tbody>
    </table>

    <script>
        const dataString = `%s`;

        let data = JSON.parse(dataString);
        let tableHead = document.getElementById("tableHead");
        let tableBody = document.getElementById("tableBody");

        let headers = ["Name", "Type", "Status", "Reload Time (Bty)", "Reload Time (Ammo Sec)", "Ammo in Vehicles", "Remaining Ammo"];
        headers.forEach(header => {
            let th = document.createElement("th");
            th.textContent = header;
            tableHead.appendChild(th);
        });

        Object.keys(data).forEach(area => {
            let areaUnits = data[area];
            areaUnits.forEach((unit, index) => {
                let row = document.createElement("tr");

                ["name", "type", "status"].forEach(key => {
                    let cell = document.createElement("td");
                    cell.textContent = key === "type" ? unit[key].toUpperCase() : unit[key];
                    row.appendChild(cell);
                });

                ["reloadTimeForBty", "reloadTimeForAmmoSec"].forEach(key => {
                    let progressCell = document.createElement("td");
                    let progressContainer = document.createElement("div");
                    progressContainer.classList.add("progress-container");

                    let progressBar = document.createElement("div");
                    progressBar.classList.add("progress-bar");
                    let percentage = (unit[key] / unit.defaultReloadTime) * 100;
                    progressBar.style.width = percentage + "%%";

                    let progressText = document.createElement("div");
                    progressText.classList.add("progress-text");
                    progressText.textContent = `${unit[key]} / ${unit.defaultReloadTime} mins`;

                    progressContainer.appendChild(progressBar);
                    progressContainer.appendChild(progressText);
                    progressCell.appendChild(progressContainer);
                    row.appendChild(progressCell);
                });

                if (index === 0) {
                    ["remainingAmmoInVehicles", "remainingAmmo"].forEach(key => {
                        let ammoCell = document.createElement("td");
                        ammoCell.textContent = unit[key];
                        ammoCell.rowSpan = areaUnits.length;
                        row.appendChild(ammoCell);
                    });
                }

                tableBody.appendChild(row);
            });
        });
    </script>

</body>

</html>
    ]]
  local str = createDataString(side, 'srbm', 'mlrs', 'glcm', 'ascm', 'mrbm')
  local msg = string.format(HTMLTemplate, str)
  local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
end

function MagazineInBasesTable(side)
  -- local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

  -- if CONFIG == nil then
  --     ScenEdit_SpecialMessage('Taiwan', 'CONFIG == nil')
  --     return
  -- end

  local createDataString = function(side)
    local key = 't'

    if side == 'China' then
      key = 'c'
    end

    local rows = {}

    for index, item in ipairs(CONFIG[key].air.landBased.deployedACs) do
      local base = SE_GetUnit({ guid = item.baseGUID })

      if base and item.loadouts then
        local obj = { name = item.name, wpns = {} }

        for _, magazine in ipairs(base.magazines) do
          for _, wpn in ipairs(magazine['mag_weapons']) do
            table.insert(obj.wpns, {
              name = wpn['wpn_name'],
              currWpn = wpn['wpn_current'],
            })
          end
        end

        table.insert(rows, obj)
      end
    end

    return gKH.json.stringify(rows)
  end

  local HTMLTemplate = [[
<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dynamic Weapon Table</title>
    <style>
        body {
            background-color: black;
            color: white;
            font-family: Arial, sans-serif;
        }
        table {
            width: 100%% ;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid white;
            padding: 10px;
            text-align: center;
        }
        th {
            background-color: #333;
        }
    </style>
</head>
<body>

    <table id="dataTable">
        <thead>
            <tr>
                <th>Base</th>
                <th>Weapon Name</th>
                <th>Current Weapon Count</th>
            </tr>
        </thead>
        <tbody id="tableBody"></tbody>
    </table>

    <script>
        const dataString = `%s`;

        let data = JSON.parse(dataString);
        let tableBody = document.getElementById("tableBody");

        data.forEach(base => {
            base.wpns.forEach((weapon, index) => {
                let row = document.createElement("tr");

                if (index === 0) {
                    let baseCell = document.createElement("td");
                    baseCell.textContent = base.name;
                    baseCell.rowSpan = base.wpns.length;
                    row.appendChild(baseCell);
                }

                let weaponCell = document.createElement("td");
                weaponCell.textContent = weapon.name;
                row.appendChild(weaponCell);

                let countCell = document.createElement("td");
                countCell.textContent = weapon.currWpn;
                row.appendChild(countCell);

                tableBody.appendChild(row);
            });
        });
    </script>

</body>
</html>

    ]]

  local str = createDataString(side)
  local msg = string.format(HTMLTemplate, str)
  local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })
end

function WCSSettingTable()
  local units = VP_GetSide({ Side = 'Taiwan' }).units
  -- local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

  -- if CONFIG == nil then
  --     print('CONFIG == nil')
  --     ScenEdit_MsgBox('CONFIG == nil', 1)
  --     return
  -- end

  local HTMLTemplate = [[
    <!DOCTYPE html>
<html lang="zh-TW">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Set WCS to hold</title>
    <style>
        body {
            background-color: #1a1a1a;
            color: #ffffff;
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }

        .container {
            background-color: #2d2d2d;
            padding: 2rem;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.5);
        }

        h1 {
            text-align: center;
            color: #ffffff;
            margin-bottom: 2rem;
        }

        .checkbox-group {
            margin: 1rem 0;
            display: flex;
            align-items: center;
        }

        input[type="checkbox"] {
            appearance: none;
            width: 20px;
            height: 20px;
            background-color: #404040;
            border: 2px solid #666;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 10px;
        }

        input[type="checkbox"]:checked {
            background-color: #00cc00;
            position: relative;
        }

        input[type="checkbox"]:checked::after {
            content: '✔';
            position: absolute;
            color: #fff;
            left: 4px;
            top: 0;
        }

        label {
            font-size: 1.1rem;
            cursor: pointer;
        }

        label:hover {
            color: #cccccc;
        }
    </style>
</head>

<body>
    <div class="container">
        <h2>EMCON Settings</h2>
        <div class="checkbox-group">
            <input type="checkbox" id="pac23" name="pac23">
            <label for="pac23">Pac-2/3</label>
        </div>
        <div class="checkbox-group">
            <input type="checkbox" id="skybow3" name="skybow3">
            <label for="skybow3">Sky Bow-3</label>
        </div>
        <div class="checkbox-group">
            <input type="checkbox" id="tc2" name="tc2">
            <label for="tc2">TC-2</label>
        </div>
    </div>
</body>

</html>
    ]]

  local msg = string.format(HTMLTemplate)
  local form = UI_CallAdvancedHTMLDialog('Title', msg, { 'Done' })

  if form['pressed'] and form['pressed'] == 'Done' then
    if form['pac23'] and string.gsub(form['pac23'], "%'", "") == 'on' then
      for index, value in ipairs(units) do
        local unit = ScenEdit_GetUnit({ guid = value.guid })

        if unit and unit.dbid == CONFIG.platformDBID15 then
          ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
          ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, value in ipairs(units) do
        local unit = ScenEdit_GetUnit({ guid = value.guid })

        if unit and unit.dbid == CONFIG.platformDBID15 then
          ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
          ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end

    if form['skybow3'] and string.gsub(form['skybow3'], "%'", "") == 'on' then
      for index, value in ipairs(units) do
        local unit = ScenEdit_GetUnit({ guid = value.guid })

        if unit and unit.dbid == CONFIG.platformDBID14 then
          ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
          ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, value in ipairs(units) do
        local unit = ScenEdit_GetUnit({ guid = value.guid })

        if unit and unit.dbid == CONFIG.platformDBID14 then
          ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
          ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end

    if form['tc2'] and string.gsub(form['tc2'], "%'", "") == 'on' then
      for index, value in ipairs(units) do
        local unit = ScenEdit_GetUnit({ guid = value.guid })

        if unit and unit.dbid == CONFIG.platformDBID33 then
          ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 2 })
          ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 0, UseEmissionInterval = 0 }
          )
        end
      end
    else
      for index, value in ipairs(units) do
        local unit = ScenEdit_GetUnit({ guid = value.guid })

        if unit and unit.dbid == CONFIG.platformDBID33 then
          ScenEdit_SetDoctrine({ guid = unit.guid }, { weapon_control_status_air = 1 })
          ScenEdit_SetUnitIntermittentEmissionConfig(
            unit.guid,
            'Green',
            { WakeWhenDetectingThreat = 1, UseEmissionInterval = 1 }
          )
        end
      end
    end
  end
end

return {
  CountUnitsInEachArea = CountUnitsInEachArea,
  LandedUnitTable = LandedUnitTable,
  C2Table = C2Table,
  BtyStateTable = BtyStateTable,
  MagazineInBasesTable = MagazineInBasesTable,
  WCSSettingTable = WCSSettingTable
}

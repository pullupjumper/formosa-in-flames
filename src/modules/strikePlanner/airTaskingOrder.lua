-- /src/modules/strikePlanner/airTaskingOrder_refactored.lua
-- This is the refactored version of the Air Tasking Order logic.
-- It uses the StrikePackageProcessor to handle the lifecycle of each strike package.

local StrikePackageProcessor = require("src.modules.strikePlanner.strikePackageProcessor")

local AirTaskingOrder = {}

--- Checks if all packages in a wave have been launched.
---@param waveData table
---@return boolean
function AirTaskingOrder._isWaveFinished(waveData)
  for _, packageData in ipairs(waveData.packages) do
    if not packageData.hasLaunched then
      return false -- At least one package has not been launched
    end
  end
  return true
end

--- The main entry point for air strikes.
--- It iterates through waves and packages, handing off the processing to the processor.
---@param CONFIG SBJ__CONFIG
---@param saveData SBJ__SaveData
---@param contacts CMO__Contact[]
function AirTaskingOrder.AirStrike(CONFIG, saveData, contacts)
  if not saveData or not saveData.c or not saveData.c.air or not saveData.c.air.ATO then
    -- Guard against missing data
    return
  end

  for _, waveData in pairs(saveData.c.air.ATO) do
    if waveData.isActivated and not waveData.hasLaunched then
      for _, packageData in ipairs(waveData.packages) do
        if not packageData.hasLaunched then
          -- The processor handles the entire sequence for a package in one go.
          -- It returns true if the package was successfully launched.
          local launched = StrikePackageProcessor.Process(packageData, CONFIG, saveData, contacts, waveData.isFirstWave)
          if launched then
            packageData.hasLaunched = true
            -- As per original logic, break after one successful launch to process
            -- the next package in the next 5-minute tick.
            break
          end
        end
      end

      -- After processing, check if the entire wave is now finished.
      if AirTaskingOrder._isWaveFinished(waveData) then
        waveData.hasLaunched = true
      end
    end
  end
end

return AirTaskingOrder

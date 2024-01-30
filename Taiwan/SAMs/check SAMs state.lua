reposition(SAMs_STATE, MIN_WEAPON_QTY, SKY_BOW_III_RELOADING_TIME, function(weaponNum, stateValue, unit)
    local wpNum = unit.magazines[1]['mag_weapons'][1]['wpn_current']

    if stateValue.state == 'static'
        and unit:inArea(stateValue.firingPosition)
        and wpNum <= weaponNum
        and stateValue.hasReloaded == false then

        stateValue.reloadStartTime = ScenEdit_CurrentTime()
        stateValue.state = 'repositioning'
        unit.course = stateValue.course
        ScenEdit_SetUnit({ guid = unit.guid, manualthrottle = 'Flank', manualSpeed = 30 })
        ScenEdit_SetEMCON('Unit', stateValue.guid, 'Radar=Passive')
        ScenEdit_SetDoctrine(
            { side = 'Taiwan', guid = stateValue.guid },
            { weapon_control_status_air = 2 }
        )
    end
end)

-- if IS_ANTI_SHIP_MISSION_ACTIVATED then
--     reloadMissile(ASM_LAUNCHER_STATE, ASM_LAUNCHER_RELOADING_TIME)
-- end

local unit = ScenEdit_UnitX()

for index, value in ipairs(SAMs_STATE) do
    if value.guid == unit.guid and value.state == 'repositioning' then
        value.state = 'static'
        ScenEdit_SetEMCON('Unit', value.guid, 'Radar=Active')
        ScenEdit_SetDoctrine({ side = 'Taiwan', guid = value.guid }, { weapon_control_status_air = WCS['wcsTight'] })
        ScenEdit_SetUnit({ guid = unit.guid, manualthrottle = 'Stop', manualSpeed = 0 })
        unit.holdposition = true
        -- unit.course = nil
        unit.desiredheading = value.heading
    end
end

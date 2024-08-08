local event = ScenEdit_EventX()
local contacts = ScenEdit_GetContacts('Taiwan')
local temp = {}
-- local mission1 = ScenEdit_GetMission('Taiwan', 'RECON1')
-- local mission2 = ScenEdit_GetMission('Taiwan', 'RECON3')
local units = VP_GetSide({ Side = 'Taiwan' }).units
local radarTrucks = FilterUnitsByName(units, 'Radar Truck')
local CONFIG = gKH.State.LoadTableFromKey("CONFIG")

if CONFIG == nil then
    print('CONFIG == nil')
    ScenEdit_MsgBox('CONFIG == nil', 1)
    return
end

if contacts ~= nil then
    for _, value in ipairs(contacts) do
        if value:inArea(CONFIG.t.asm.const.nai1) and value.type == 'Surface' then
            table.insert(temp, value)
        end
    end
end


-- ScenEdit_MsgBox(tostring(getCount(temp)),0)

if GetCount(temp) >= 1 and radarTrucks ~= nil then
    -- for index, value in ipairs(HAROP_STATE) do

    --     ScenEdit_AttackContact(value.guid, 'BOL',
    --         {
    --             mode = '1',
    --             mount = 2816,
    --             weapon = 3271,
    --             qty = 9,
    --             latitude = value.courseList[1][3].lat,
    --             longitude = value.courseList[1][3].lon,
    --             course = { value.courseList[1][1], value.courseList[1][2] }
    --         })

    --     ScenEdit_AttackContact(value.guid, 'BOL',
    --         {
    --             mode = '1',
    --             mount = 2816,
    --             weapon = 3271,
    --             qty = 9,
    --             latitude = value.courseList[2][3].lat,
    --             longitude = value.courseList[2][3].lon,
    --             course = { value.courseList[2][1], value.courseList[2][2] }
    --         })

    --     ScenEdit_AttackContact(value.guid, 'BOL',
    --         {
    --             mode = '1',
    --             mount = 2816,
    --             weapon = 3271,
    --             qty = 9,
    --             latitude = value.courseList[1][3].lat,
    --             longitude = value.courseList[1][3].lon,
    --             course = { value.courseList[1][1], value.courseList[1][2] }
    --         })
    -- end

    for _, value in ipairs(radarTrucks) do
        ScenEdit_SetEMCON('Unit', value.guid, 'Radar=Active')
    end

    -- mission1.isactive = true
    -- mission2.isactive = true
    event.isActive = false
end

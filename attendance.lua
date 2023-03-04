_addon.name = 'attendance'
_addon.author = 'ainais'
_addon.version = '0.0.1'
_addon.commands = {'attendance', 'att'}

require('logger')
res = require('resources')
files = require('files')
packets = require('packets')
config = require('config')

local is_ready = false
local known_players = T{}
local ignore_members = T{}
local show_debug_once = false

local defaults = T{
    ignore_members = T{},
}
local settings = config.load(defaults)

local function tchelper(first, rest)
    return first:upper()..rest:lower()
end

function title_case(str)
    if (str == nil) then
        return str
    end
    str = str:gsub("(%a)([%w_']*)", tchelper)
    return str
end

function ready()
    windower.add_to_chat(207, "Attendance reports should be available now.")
    is_ready = true
end

function get_player_data()
    local party = windower.ffxi.get_party()
    local current_members = T{}
    local id = 0
    local zone = 0

    for k, v in pairs (party) do
        if (type(v) == "table") then
            if (v.mob) then
                id = v.mob.id
                current_members[id] = {name = v.name, zone = res.zones[v.zone].name}
                if (known_players[id]) then
                    current_members[id].main_job = res.jobs[known_players[id].main_job].ens
                    current_members[id].main_job_lvl = known_players[id].main_job_lvl
                    current_members[id].sub_job = res.jobs[known_players[id].sub_job].ens
                    current_members[id].sub_job_lvl = known_players[id].sub_job_lvl
                end
            else
                current_members[v.name] = {name = v.name, zone = res.zones[v.zone].name}
            end
        end
    end
    return current_members
end

function show_report(csv) 
    local csv = csv or false
    if (not is_ready) then
        windower.add_to_chat(207, "Just a little longer please.")
        return
    end
    local date = os.date('*t')
    local time = os.date('%H%M%S')
    local time_c = os.date('%H:%M:%S')
    local name = windower.ffxi.get_player().name
    local timestamp = ('%.4u.%.2u.%.2u.%.2u'):format(date.year, date.month, date.day, time)
    local report = ""

    local current_members = get_player_data()

    for k,v in pairs(current_members) do
        if (not ignore_members:contains(v.name)) then
            local main_job = ((v.main_job == nil or v.main_job == 'NON') and '---' or v.main_job)
            local main_job_lvl = ((v.main_job_lvl ~= nil and v.main_job_lvl ~= 0) and v.main_job_lvl or "")
            local sub_job = ((v.sub_job == nil or v.sub_job == 'NON') and '---' or v.sub_job)
            local sub_job_lvl = ((v.sub_job_lvl ~= nil and v.sub_job_lvl ~= 0) and v.sub_job_lvl or "")
            
            local line = ""
            line = line..v.name
            line = line .. "," .. main_job .. main_job_lvl .. "/" .. sub_job .. sub_job_lvl 
            line = line..","..('%s,UTC%s'):format(time_c, os.date("%z"))
            line = line .. "," .. v.zone
            line = line.."\n"
            report = report .. line
            windower.add_to_chat(211,line)
        end
    end

    if (csv) then
        filename = 'attendance'..('_%.4u.%.2u.%.2u_%.2u.csv'):format(date.year, date.month, date.day, time)
        file = files.new('/export/'..filename)
        if not file:exists() then
            file:create()
        end
        file:append(report)
        windower.add_to_chat(207, "Attendance saved as: "..filename)
    end
end

windower.register_event('load', function()
    windower.add_to_chat(207, "Please wait 3 second before attempting to process attendance to ensure alliance is fully loaded.")
    coroutine.schedule(ready, 3)
end)

windower.register_event('incoming chunk',function(id,data)
    if (id == 0x0DD or id == 0x0DF) then 
        local p = packets.parse('incoming',data)
        if (show_debug_once) then
            windower.add_to_chat(207, "Packet: \n"..T(p):tovstring())
            show_debug_once = false
        end
        if (p.ID and p['Main job']) then
            known_players[p.ID] = {
                    ['main_job'] = p['Main job'] or p['Main Job'] ,
                    ['main_job_lvl'] = p['Main job level'] or p['Main Job level'],
                    ['sub_job'] = p['Sub job'] or p['Sub Job'] ,
                    ['sub_job_lvl'] = p['Sub job level'] or p['Sub Job level'] 
                }
        end
    end
end)

windower.register_event('addon command', function(...)
    local args = T{...}:map(string.lower)
    local cmd = args[1]
    args:remove(1)
    local argc = #args

    if (cmd == "report") then
        show_report(false)
        return
    elseif (cmd == "csv" or cmd == "now") then
        show_report(true)
        return
    elseif(T{"ignore","ign","ig"}:contains(cmd)) then
        local member = title_case(args:concat(" "))
        ignore_members:append(member)
        windower.add_to_chat(207, member.." will be ignored in reports")
    elseif (cmd == "once") then
        show_debug_once = True
        windower.add_to_chat(207, "Showing a packet cycle.")
        return
    end
end)

_addon.name = 'attendance'
_addon.author = 'ekrividus'
_addon.version = '0.0.1'
_addon.commands = {'attendance', 'attend'}

require('logger')
require('xml')
res = require('resources')
files = require('files')
packets = require('packets')
res_jobs = require('resources').jobs
config = require('config')

local is_ready = false
local known_players = T{}
local event = T{}
local event_names = T{"Dyna - D","Dyna - D - Push","Omen","Vagary","Delve","Social",}
local event_types = T{"Farm","Wave 1 Boss","Wave 2 Boss","Wave 3 Boss","Fu","Gin","Kei","Kin","Kyou","Ou","Mid-Boss",}
local ignore_members = T{}
local show_debug_once = false

local defaults = T{
    event_names = T{"Dyna - D", "Omen"},
    event_types = T{"Wave 1 Boss", "Wave 2 Boss", "Wave 3 Boss"},
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
    windower.add_to_chat(17, "Attendance reports should be available now.")
    is_ready = true
end

function get_player_data()
    local party = windower.ffxi.get_party()
    local current_members = T{}
    local id = 0

    for k, v in pairs (party) do
        if (type(v) == "table") then
            if (v.mob and not v.is_npc) then
                id = v.mob.id
                current_members[id] = {name = v.mob.name}
                if (known_players[id]) then
                    current_members[id].main_job = res.jobs[known_players[id].main_job].ens
                    current_members[id].main_job_lvl = known_players[id].main_job_lvl
                    current_members[id].sub_job = res.jobs[known_players[id].sub_job].ens
                    current_members[id].sub_job_lvl = known_players[id].sub_job_lvl
                end
            end
        end
    end
    return current_members
end

function save_report_xml()
    if (not is_ready) then
        windower.add_to_chat(17, "Just a little longer please.")
        return
    end
    local date = os.date('*t')
    local time = os.date('%H%M%S')
    local name = windower.ffxi.get_player().name
    local timestamp = ('%.4u.%.2u.%.2u.%.2u'):format(date.year, date.month, date.day, time)
    local data = T{}
    local current_members = get_player_data()
    local report = ""
    local filename = (event.name ~= '' and (event.name ~= 'Unknown' and event.name) or 'attendance')..('_%.4u.%.2u.%.2u_%.2u.xml'):format(date.year, date.month, date.day, time)

    local file = files.new('/export/'..filename)
    if not file:exists() then
        file:create()
    end
    file:append('<?xml version="1.1" ?>\n')
    data.event = T{}
    data.event.members = T{}
    for k,v in pairs(current_members) do
        if (not ignore_members:contains(v.name)) then
            data.event.members[v.name] = T{}
            data.event.members[v.name].player_name = v.name
            data.event.members[v.name].main_job = 'Unknown'
            data.event.members[v.name].main_job_lvl = '0'
            data.event.members[v.name].sub_job = 'Unknown'
            data.event.members[v.name].sub_job_lvl = '0'
            data.event.members[v.name].main_job = tostring(v.main_job)
            data.event.members[v.name].main_job_lvl = tostring(v.main_job_lvl)
            data.event.members[v.name].sub_job = tostring(v.sub_job)
            data.event.members[v.name].sub_job_lvl = tostring(v.sub_job_lvl)
            data.event.members[v.name].early = "false" -- Early
            data.event.members[v.name].ontime = "false" -- Ontime
            data.event.members[v.name].late = "false" -- Late
            data.event.members[v.name].role = 'Unknown'
            if (T{"PLD","NIN","RUN"}:contains(v.main_job)) then
                data.event.members[v.name].role = 'Tank'
            elseif (T{"WHM","SCH"}:contains(v.main_job)) then
                data.event.members[v.name].role = 'Healer'
            elseif (T{"RDM","BRD","COR","GEO"}:contains(v.main_job)) then
                data.event.members[v.name].role = 'Support'
            elseif (T{"WAR","MNK","THF","DRK","BST","RNG","SAM","DRG","BLU","PUP","DNC"}:contains(v.main_job)) then
                data.event.members[v.name].role = 'Physical DD'
            elseif (T{"BLM","SMN"}:contains(v.main_job)) then
                data.event.members[v.name].role = 'Magical DD'
            end
        end
    end
    data.event.leader = tostring(event.leader or 'None') -- Leader?
    data.event.type = title_case(event.type or 'Unknown')
    data.event.name = title_case(event.name or 'Unknown')
    data.event.date = ('%.2u\\%.2u\\%.4u'):format(date.month, date.day, date.year)
    data.event.timestamp = tostring(timestamp)
    report = data:to_xml()
    file:append(report)
    windower.add_to_chat(17, "Attendance saved as: "..filename)

end

function save_report_csv() 
    if (not is_ready) then
        windower.add_to_chat(17, "Just a little longer please.")
        return
    end
    local current_members = get_player_data()
    local date = os.date('*t')
    local time = os.date('%H%M%S')
    local name = windower.ffxi.get_player().name
    local timestamp = ('%.4u.%.2u.%.2u.%.2u'):format(date.year, date.month, date.day, time)
    local report = ""

    local filename = (event.name ~= '' and (event.name ~= 'Unknown' and event.name) or 'attendance')..('_%.4u.%.2u.%.2u_%.2u.csv'):format(date.year, date.month, date.day, time)

    local file = files.new('/export/'..filename)
    if not file:exists() then
        file:create()
    end
    for k,v in pairs(current_members) do
        if (not ignore_members:contains(v.name)) then
            report = report..v.name
            report = report..","..title_case(event.name or '')
            report = report..","..title_case(event.type or '')
            report = report..","..('%.2u/%.2u/%.4u'):format(date.month, date.day, date.year)
            report = report..",".."false" -- Early
            report = report..",".."false" -- Ontime
            report = report..",".."false" -- Late
            report = report..","..tostring(event.leader and (title_case(event.leader) == v.name) or false) -- Leader?
            report = report..","..tostring(T{"PLD","NIN","RUN"}:contains(v.main_job)) -- Tank?
            report = report..","..tostring(T{"WHM"}:contains(v.main_job)) -- Healer?
            report = report..","..tostring(T{"RDM","BRD","COR","GEO"}:contains(v.main_job)) -- Support?
            report = report..","..tostring(T{"WAR","MNK","THF","DRK","BST","RNG","SAM","DRG","BLU","PUP","DNC"}:contains(v.main_job)) -- Physical DD?
            report = report..","..tostring(T{"BLM","SMN","SCH"}:contains(v.main_job)) -- Magical DD?
            report = report.."\n"
        end
    end
    file:append(report)

    windower.add_to_chat(17, "Attendance saved as: "..filename)
end

function show_report() 
    if (not is_ready) then
        windower.add_to_chat(17, "Just a little longer please.")
        return
    end
    local role = "Role: Unknown"
    local report = "Event: "

    report = report.. title_case(event.name or 'Unknown')
    report = report.. title_case(event.type and ("["..event.type.."]") or '')
    report = report.. " - Leader: "..tostring(event.leader or 'None').."\n"

    local current_members = get_player_data()
    for k,v in pairs(current_members) do
        if (not ignore_members:contains(v.name)) then
            local role = "Role: Unknown"
            report = report..v.name
            if (v.main_job and v.main_job ~= "NON") then
                report = report.." ("..v.main_job..v.main_job_lvl.."/"..v.sub_job..v.sub_job_lvl..")"
            end

            if (T{"PLD","NIN","RUN"}:contains(v.main_job)) then
                role = 'Role: Tank'
            elseif (T{"WHM","SCH"}:contains(v.main_job)) then
                role = 'Role: Healer'
            elseif (T{"RDM","BRD","COR","GEO"}:contains(v.main_job)) then
                role = 'Role: Support'
            elseif (T{"WAR","MNK","THF","DRK","BST","RNG","SAM","DRG","BLU","PUP","DNC"}:contains(v.main_job)) then
                role = 'Role: Physical DD'
            elseif (T{"BLM","SMN"}:contains(v.main_job)) then
                role = 'Role: Magical DD'
            end
            report = report.." "..role
            report = report.."\n"
        end
    end

    for k,v in pairs(report:split("\n")) do
        windower.add_to_chat(17, v)
    end
end

windower.register_event('load', function()
    windower.add_to_chat(17, "Please wait 3 second before attempting to process reports to ensure alliance is fully loaded.")
    coroutine.schedule(ready, 3)
end)

windower.register_event('incoming chunk',function(id,data)
    if (id == 0x0DD or id == 0x0DF) then 
        local p = packets.parse('incoming',data)
        if (show_debug_once) then
            windower.add_to_chat(17, "Packet: \n"..T(p):tovstring())
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
        show_report()
        return
    elseif (cmd == "csv") then
        save_report_csv()
        return
    elseif (cmd == "xml") then
        save_report_xml()
        return
    elseif (T{"event","ev"}:contains(cmd)) then
        local n = title_case(args:concat(" "))
        if (event_names:contains(n)) then
            event.name = n
            windower.add_to_chat(17, "Event name set to "..n)
        else
            windower.add_to_chat(17, n.." is not a valid event name.")
        end
        return
    elseif (T{"type","evtype"}:contains(cmd)) then
        local n = title_case(args:concat(" "))
        if (event_types:contains(n)) then
            event.type = n
            windower.add_to_chat(17, "Event type set to "..n)
        else
            windower.add_to_chat(17, n.." is not a valid event type.")
        end
        return
    elseif (T{"leader","lead","ldr"}:contains(cmd)) then
        event.leader = title_case(args:concat(" "))
        windower.add_to_chat(17, "Event leader set to "..event.leader)
        return
    elseif(T{"ignore","ign","ig"}:contains(cmd)) then
        local member = title_case(args:concat(" "))
        ignore_members:append(member)
        windower.add_to_chat(17, member.." will be ignored in reports")
    elseif (cmd == "once") then
        show_debug_once = True
        windower.add_to_chat(17, "Showing a packet cycle.")
        return
    end
end)
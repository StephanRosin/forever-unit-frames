local _, ns = ...

-- The names under a buff in the watch window (Raid/BuffWatchWindow.lua):
-- who needs it, from a state of Raid/BuffWatch.lua, read out of combat
-- only (the window renders then). Missing first, then running out
-- (dimmed, with the minutes left), each part alphabetical; a member the
-- buff's single form plainly does not reach is grey, so "missing, but
-- nobody in range" shows who. A name the client keeps secret is left out
-- of the line (it still counts). At most MAX_LINES lines, the rest "+N".
local Names = {}
ns.RaidBuffNames = Names

local Secrets, L = ns.Secrets, ns.L

Names.MAX_LINES, Names.SPACE, Names.GREY, Names.DIM = 2, "  ", "ff808080", 0.6

function Names.Of(st)
    local list = {}
    if not st or st.preview or st.unknown or not st.needs then return list end
    local spell = st.entry and st.entry.single and st.entry.single.id
    for _, need in ipairs(st.needs) do
        local name = Secrets.Plain(Secrets.Call(UnitName, need.unit), "string")
        if name and name ~= "" then
            -- Only a plain "no" is out of range (as BuffWatch's own check).
            local reach = not spell or Secrets.Call(C_Spell.IsSpellInRange, spell, need.unit) ~= false
            list[#list + 1] = { name = name, class = need.member and need.member.class, missing = need.left < 0,
                left = need.left, reach = reach }
        end
    end
    table.sort(list, function(a, b)
        if a.missing ~= b.missing then return a.missing end
        return a.name < b.name
    end)
    return list
end

function Names.Plain(item)
    if item.missing then return item.name end
    return item.name .. " " .. L.RAID_BUFF_MINUTES:format(math.ceil(item.left / 60))
end

local function hex(r, g, b)
    return ("ff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

local function colour(item)
    if not item.reach then return Names.GREY end
    local c = item.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.class]
    local r, g, b = 1, 1, 1
    if c then r, g, b = c.r, c.g, c.b end
    if not item.missing then r, g, b = r * Names.DIM, g * Names.DIM, b * Names.DIM end
    return hex(r, g, b)
end

function Names.Text(item)
    return "|c" .. colour(item) .. Names.Plain(item) .. "|r"
end

-- Greedy: as many names as fit on a line; on the last line, room is
-- kept for "+N" when names would remain.
function Names.Pack(list, width, measure)
    local lines, i = {}, 1
    for line = 1, Names.MAX_LINES do
        if i > #list then break end
        local plain, text = "", ""
        while i <= #list do
            local add = (plain == "" and "" or Names.SPACE) .. Names.Plain(list[i])
            local rest = #list - i
            local more = (line == Names.MAX_LINES and rest > 0) and (Names.SPACE .. L.RAID_BUFF_MORE:format(rest)) or ""
            if plain ~= "" and measure(plain .. add .. more) > width then break end
            plain = plain .. add
            text = text .. (text == "" and "" or Names.SPACE) .. Names.Text(list[i])
            i = i + 1
        end
        lines[line] = text
    end
    if i <= #list then
        lines[#lines] = lines[#lines] .. Names.SPACE .. L.RAID_BUFF_MORE:format(#list - i + 1)
    end
    return lines
end

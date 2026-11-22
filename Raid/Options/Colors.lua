local _, ns = ...

-- The raid window's Colors tab: the unit frames' own class colours and pet
-- colours (General > Colors, Core/Settings.lua), the same values, so the
-- cells and the unit frames always agree. Each colour greys while its
-- switch (the section's first row) is off, as in the unit frames' window.
local RaidOptions, Config, L, Widgets = ns.RaidOptions, ns.Config, ns.L, ns.Widgets

local function colorsTab()
    for _, tab in ipairs(ns.Schema.GENERAL) do
        if tab.id == "colors" then return tab end
    end
end

RaidOptions.CUSTOM_PAGES.colors = function(page, tab)
    local stack = RaidOptions.NewStack(page)
    stack.add(RaidOptions.NoteBlock(page, ns.RaidSchema.Note(tab.note)), RaidOptions.PAGE.noteHeight)
    for _, section in ipairs(colorsTab().sections) do
        local header = Widgets.Header(page, L["SECTION_" .. section.id])
        header.isSection = true
        stack.add(header)
        local switch = section.keys[1]
        for i, key in ipairs(section.keys) do
            local row = ns.Options.Control(page, ns.Settings.Get(key), {
                label = L["SETTING_" .. key], hint = rawget(L, "HINT_" .. key),
                get = function() return Config.Get("general", key) end,
                set = function(v)
                    Config.Set("general", key, v)
                    return true
                end,
            })
            row.key = key
            if i > 1 then
                RaidOptions.ROW_ACTIVE[key] = function() return Config.Get("general", switch) == true end
            end
            stack.add(row)
        end
    end
    stack.finish()
end

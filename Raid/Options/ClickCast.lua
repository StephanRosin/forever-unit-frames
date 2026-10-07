local _, ns = ...

-- The raid window's Click-casting tab (Raid/Options/Window.lua builds the
-- window; Raid/ClickCast.lua and Raid/ClickKeys.lua do the casting): the
-- tab's note, the switches, copy from another character and Clear all,
-- then a section per mouse button with a row per set of modifiers (what
-- the click does, and the spell, item or macro it takes), then the
-- sixteen keys (the key, what it casts, and a warning when the key is
-- bound to something else). Every change goes through ns.RaidConfig,
-- per character; the rows lock in combat like every row of the window.
local ClickCastPage = {}
ns.RaidClickCastPage = ClickCastPage

local Widgets, Schema, Raid, L = ns.Widgets, ns.RaidSchema, ns.Raid, ns.L
local RaidOptions, RaidConfig = ns.RaidOptions, ns.RaidConfig

local KIND_W, VALUE_W, KEY_W, GAP, KEYS_NOTE_H = 170, 400, 120, 8, 34

local function get(key) return RaidConfig.Get("general", key) end
local function set(key, value) return RaidConfig.Set("general", key, value) end

local function binding(key)
    local kind, value = Raid.ParseBinding(get(key))
    return kind or "", value or ""
end

local function kindItems(kinds)
    return function()
        local items = {}
        for _, kind in ipairs(kinds) do items[#items + 1] = { value = kind, text = Schema.KindText(kind) } end
        return items
    end
end

-- A binding's two controls in a row: the kind's dropdown (the row's own
-- button, moved to x) and the value's box after it. A new kind starts
-- without a value; a typed value is checked (ClickCast.TypedValue).
local function bindingControls(row, key, x, valueWidth)
    local button = row.button
    button:ClearAllPoints()
    button:SetPoint("LEFT", row, "LEFT", x, 0)
    button:SetWidth(KIND_W)
    row.value = Widgets.TextBox(row, {
        width = valueWidth, maxLetters = Raid.CLICK_BINDING_LETTERS,
        get = function() return (select(2, binding(key))) end,
        set = function(text)
            local kind = binding(key)
            local value, why = ns.ClickCast.TypedValue(kind, text)
            if value == nil then
                ns.Print(why)
                return false
            end
            return set(key, kind .. ":" .. value)
        end,
    })
    row.value:ClearAllPoints()
    row.value:SetPoint("LEFT", button, "RIGHT", GAP, 0)
    local refresh, setEnabled = row.Refresh, row.SetEnabled
    function row:Refresh()
        refresh(self)
        if not self.value:HasFocus() then self.value.ShowValue() end
        self.value:SetEnabled(self.enabled ~= false and Raid.BindingHasValue((binding(key))))
    end
    function row:SetEnabled(on)
        self.enabled = on
        setEnabled(self, on)
        if not on then self.value:ClearFocus() end
        self.value:SetEnabled(on and Raid.BindingHasValue((binding(key))))
    end
end

local function bindingDropdown(page, key, kinds, label, hint)
    return Widgets.Dropdown(page, {
        label = label, hint = hint, items = kindItems(kinds),
        get = function() return (binding(key)) end,
        set = function(kind)
            if kind == binding(key) then return true end
            return set(key, Raid.BindingHasValue(kind) and (kind .. ":") or kind)
        end,
    })
end

-- A mouse slot's row.
local function slotRow(page, slot)
    local row = bindingDropdown(page, slot.key, Raid.SlotKinds(slot), Schema.Label(slot.key))
    bindingControls(row, slot.key, Widgets.CONTROL_X, VALUE_W)
    row.key = slot.key
    return row
end

-- A typed key: the client's spelling, not taken by another slot.
local function storeKey(slot, text)
    local key = Raid.ParseKey(text)
    if key == nil then
        ns.Print(L.RAID_TYPED_KEY_INVALID:format(text))
        return false
    end
    for _, other in ipairs(Raid.CLICK_KEYS) do
        if other ~= slot and key ~= "" and get(other.key) == key then
            ns.Print(L.RAID_TYPED_KEY_TWICE:format(key))
            return false
        end
    end
    return set(slot.key, key)
end

-- What the key does otherwise, under the label: while the raid frames
-- show it casts instead.
local function takenText(slot)
    local action = ns.ClickKeys.Taken(get(slot.key))
    if not action then return "" end
    local name = rawget(_G, "BINDING_NAME_" .. action)
    return L.RAID_CLICK_KEY_TAKEN:format(type(name) == "string" and name or action)
end

-- A key slot's row: the key's box, then the binding.
local function keyRow(page, slot)
    local row = bindingDropdown(page, slot.bind, Raid.CLICK_KEY_KINDS, L.RAID_CLICK_KEY_N:format(slot.index),
        function() return takenText(slot) end)
    row.keyBox = Widgets.TextBox(row, {
        width = KEY_W, maxLetters = Raid.CLICK_KEY_LETTERS,
        get = function() return get(slot.key) end,
        set = function(text) return storeKey(slot, text) end,
    })
    bindingControls(row, slot.bind, Widgets.CONTROL_X + KEY_W + GAP,
        VALUE_W - KEY_W - GAP)
    local refresh, setEnabled = row.Refresh, row.SetEnabled
    function row:Refresh()
        refresh(self)
        if not self.keyBox:HasFocus() then self.keyBox.ShowValue() end
    end
    function row:SetEnabled(on)
        setEnabled(self, on)
        if not on then self.keyBox:ClearFocus() end
        self.keyBox:SetEnabled(on)
    end
    row.key = slot.key
    return row
end

-- The mode's row: its hint says so while Clique is loaded.
local function modeRow(page)
    local row = RaidOptions.SettingRow(page, "clickCast")
    local refresh = row.Refresh
    function row:Refresh()
        refresh(self)
        self.hintText:SetText(ns.ClickCast.Clique() and L.RAID_CLICK_CLIQUE or Schema.Hint("clickCast"))
    end
    return row
end

-- Copy from another character (pick it, then Copy) and Clear all (two
-- clicks): both back to what the character has, or the defaults.
local function actionsRow(page)
    local pending
    local row, copy, clear
    row = Widgets.Dropdown(page, {
        label = L.RAID_CLICK_COPY,
        items = function()
            local items = {}
            for _, key in ipairs(ns.RaidProfiles.Characters()) do items[#items + 1] = { value = key, text = key } end
            return items
        end,
        get = function() return pending end,
        set = function(value)
            pending = value
            copy:SetEnabled(row.enabled ~= false)
            return true
        end,
    })
    row.button:SetWidth(KIND_W)
    copy = Widgets.Button(row, { text = L.RAID_CLICK_COPY_BUTTON, width = 100, onClick = function()
        local key = pending
        pending = nil
        copy:SetEnabled(false)
        if key then ns.RaidProfiles.CopyClickCast(key) end
        row:Refresh()
    end })
    copy:SetPoint("LEFT", row.button, "RIGHT", GAP, 0)
    copy:SetEnabled(false)
    clear = ns.Options.ConfirmButton(row, L.RAID_CLICK_CLEAR,
        function() RaidConfig.ResetKeys("general", ns.RaidProfiles.ClickKeys()) end)
    clear:SetPoint("LEFT", copy, "RIGHT", GAP * 3, 0)
    local setEnabled = row.SetEnabled
    function row:SetEnabled(on)
        self.enabled = on
        setEnabled(self, on)
        copy:SetEnabled(on and pending ~= nil)
        clear:SetEnabled(on)
        if not on then clear.Disarm() end
    end
    RaidOptions.clickCopyRow, RaidOptions.clickCopyButton, RaidOptions.clickClearButton = row, copy, clear
    return row
end

local function header(page, id)
    local h = Widgets.Header(page, Schema.SectionTitle(id))
    h.isSection = true
    return h
end

-- Every row of the page, in its order.
local function rows(page, tab)
    local P = RaidOptions.PAGE
    local list = {}
    local note = RaidOptions.NoteBlock(page, Schema.Note(tab.note))
    note:SetHeight(P.noteHeight)
    list[1] = note
    list[#list + 1] = header(page, "clickCastGeneral")
    list[#list + 1] = modeRow(page)
    list[#list + 1] = RaidOptions.SettingRow(page, "clickCastParty")
    list[#list + 1] = actionsRow(page)
    for _, b in ipairs(Raid.CLICK_BUTTONS) do
        list[#list + 1] = header(page, "click" .. b.name)
        for _, slot in ipairs(Raid.CLICK_SLOTS) do
            if slot.button == b.button then list[#list + 1] = slotRow(page, slot) end
        end
    end
    list[#list + 1] = header(page, "clickKeys")
    local keysNote = RaidOptions.NoteBlock(page, L.RAID_CLICK_KEYS_NOTE)
    keysNote:SetHeight(KEYS_NOTE_H)
    list[#list + 1] = keysNote
    for _, slot in ipairs(Raid.CLICK_KEYS) do list[#list + 1] = keyRow(page, slot) end
    -- The page's note is the tab's (NoteBlock sets the last one built).
    page.note = note.text
    return list
end

function ClickCastPage.Build(page, tab)
    local P = RaidOptions.PAGE
    local y = P.top
    page.rows = rows(page, tab)
    for i, row in ipairs(page.rows) do
        if row.isSection and i > 1 then y = y + P.sectionGap end
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
        y = y + row:GetHeight()
    end
    page.height = y + P.bottom
end

RaidOptions.CUSTOM_PAGES.clickCast = ClickCastPage.Build

local _, ns = ...

-- The editor of a hidden-auras list (Core/AuraBlocklist.lua), the row a
-- blocklist setting gets in both options windows (Options.Control): a box
-- that takes spell IDs or names (several, separated by commas; Enter adds
-- them), a note on what the client allows, and the list: each entry's ID
-- and name, a "Remove", and a mark where the client will not hide it
-- everywhere on this list's frames. The row is as tall as its list, up
-- to Editor.LINES lines; longer lists scroll with the wheel.
-- opts as for the other rows (get, set, label, hint), plus opts.scope: the
-- unit frames' page it is on (none: a raid size). A setting with
-- def.spellList (the shield watch's additions) is a plain list of spells:
-- its own note and empty text, no marks (nothing is hidden by it).
local Editor = {}
ns.AuraBlockEditor = Editor

local Widgets, Style, Blocklist, L = ns.Widgets, ns.Style, ns.AuraBlocklist, ns.L

Editor.LINES = 6
Editor.LINE_H = 20
Editor.NOTE_H = 30
local LABEL_X, DISABLED_ALPHA = 16, 0.45
-- The longest text a box takes at once: a few names.
Editor.TYPED_LETTERS = 200

-- What a typed text does: added (true), or refused with a chat line.
local function add(opts, typed)
    local text, why, word = Blocklist.Resolve(typed, opts.get())
    if not text then
        if why == "FULL" then
            ns.Print(L.AURA_BLOCK_FULL:format(Blocklist.MAX))
        else
            ns.Print(L.AURA_BLOCK_UNKNOWN:format(word))
        end
        return false
    end
    if text == opts.get() then return true end
    return opts.set(text)
end

local function newLine(row, i)
    local line = CreateFrame("Frame", nil, row)
    line:SetHeight(Editor.LINE_H)
    local y = -(Widgets.ROW_H + Editor.NOTE_H + (i - 1) * Editor.LINE_H)
    line:SetPoint("TOPLEFT", row, "TOPLEFT", 0, y)
    line:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, y)
    line.text = Style.Text(line, 12, "text")
    line.text:SetPoint("LEFT", line, "LEFT", LABEL_X, 0)
    line.text:SetJustifyH("LEFT")
    line.mark = Style.Text(line, 10, "muted")
    line.mark:SetPoint("LEFT", line, "LEFT", Widgets.CONTROL_X, 0)
    line.mark:SetJustifyH("LEFT")
    line.remove = CreateFrame("Button", nil, line)
    line.remove:SetSize(70, 18)
    line.remove:SetPoint("RIGHT", line, "RIGHT", -12, 0)
    line.remove.text = Style.Text(line.remove, 11, "accent")
    line.remove.text:SetPoint("CENTER")
    line.remove.text:SetText(L.AURA_BLOCK_REMOVE)
    return line
end

function Editor.Row(parent, def, opts)
    local context = opts.scope and Blocklist.Context(opts.scope) or "group"
    local row = CreateFrame("Frame", nil, parent)
    row.offset = 0
    -- The first line: label, hint and the box, as every row.
    local top = Widgets.NewRow(row, opts)
    top:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.top, row.label = top, top.label
    row.edit = Widgets.TextBox(top, { maxLetters = Editor.TYPED_LETTERS,
        get = function() return "" end,
        set = function(typed) return add(opts, typed) end })
    row.edit:SetPoint("LEFT", top, "LEFT", Widgets.CONTROL_X, 0)
    -- What the client allows, in one sentence.
    row.note = Style.Text(row, 10, "muted")
    row.note:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_X, -(Widgets.ROW_H + 2))
    row.note:SetPoint("TOPRIGHT", row, "TOPRIGHT", -LABEL_X, -(Widgets.ROW_H + 2))
    row.note:SetJustifyH("LEFT")
    row.note:SetWordWrap(true)
    row.note:SetText(def.spellList and L.SPELL_LIST_NOTE or L.AURA_BLOCK_NOTE)
    row.lines = {}
    for i = 1, Editor.LINES do row.lines[i] = newLine(row, i) end
    row.count = Style.Text(row, 10, "muted")

    -- As many lines as the list has entries (one for the empty text), at
    -- most Editor.LINES; the count right after them. A changed height
    -- lays the page out anew (its Restack, once it is stacked).
    local shownLines
    local function fitLines(count)
        local lines = math.max(1, math.min(count, Editor.LINES))
        if lines == shownLines then return end
        shownLines = lines
        for i, line in ipairs(row.lines) do line:SetShown(i <= lines) end
        row.count:ClearAllPoints()
        row.count:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_X,
            -(Widgets.ROW_H + Editor.NOTE_H + lines * Editor.LINE_H + 2))
        row:SetHeight(Widgets.ROW_H + Editor.NOTE_H + (lines + 1) * Editor.LINE_H)
        if parent.Restack then parent.Restack() end
    end

    local enabled = true
    function row:Refresh()
        local ids = Blocklist.Parse(opts.get()) or {}
        row.ids = ids
        row.offset = math.max(0, math.min(row.offset, #ids - Editor.LINES))
        for i, line in ipairs(row.lines) do
            local id = ids[row.offset + i]
            line.id = id
            if id then
                line.text:SetText(("%d  %s"):format(id, Blocklist.Name(id) or "?"))
                local mark = not def.spellList and Blocklist.Mark(id, context)
                line.mark:SetText(mark and L["AURA_BLOCK_MARK_" .. mark] or "")
            else
                local empty = def.spellList and L.SPELL_LIST_EMPTY or L.AURA_BLOCK_EMPTY
                line.text:SetText(i == 1 and #ids == 0 and empty or "")
                line.mark:SetText("")
            end
            line.remove:SetShown(id ~= nil)
            line.remove:SetEnabled(enabled)
        end
        row.count:SetText(L.AURA_BLOCK_COUNT:format(#ids, Blocklist.MAX))
        fitLines(#ids)
    end
    function row:SetEnabled(on)
        enabled = on
        if not on then row.edit:ClearFocus() end
        row.edit:SetEnabled(on)
        for _, line in ipairs(row.lines) do line.remove:SetEnabled(on) end
        row:SetAlpha(on and 1 or DISABLED_ALPHA)
    end
    for _, line in ipairs(row.lines) do
        line.remove:SetScript("OnClick", function()
            if line.id then opts.set(Blocklist.Remove(opts.get(), line.id)) end
            row:Refresh()
        end)
    end
    -- The wheel scrolls a list longer than its lines, else the page.
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        local ids = row.ids or {}
        if #ids <= Editor.LINES then return Widgets.PassWheel(self, delta) end
        row.offset = row.offset - delta
        row:Refresh()
    end)
    row:Refresh()
    return row
end

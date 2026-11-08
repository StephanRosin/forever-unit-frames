local _, ns = ...

-- The search in the options windows' title bars: a box and, while it holds
-- text, a list of the settings that match. A click (Enter: the first)
-- jumps to the setting and lights its row up for a moment. Each window
-- gives its own entries, read anew per search:
-- { title, path, hint (optional), key (optional: the row to jump to), ... }.
local Search = {}
ns.OptionsSearch = Search

local Style, Chrome, L = ns.Style, ns.Chrome, ns.L

Search.MAX_RESULTS = 10
local BOX_W, BOX_H, BOX_GAP = 190, 20, 4
local LIST_W, ROW_H, MORE_H, TITLE_SIZE, PATH_SIZE, ROW_INSET = 400, 36, 22, 12, 10, 8
local FLASH_ALPHA, FLASH_SECONDS, REVEAL_MARGIN = 0.2, 1.5, 8

-- shortcut: string.lower leaves non-ASCII letters alone, so "Ü" does not
-- find "ü"; a UTF-8 case map if someone misses it.
local function wordsOf(text)
    local words = {}
    for word in text:lower():gmatch("%S+") do words[#words + 1] = word end
    return words
end

local function holdsAll(text, words)
    for _, word in ipairs(words) do
        if not text:find(word, 1, true) then return false end
    end
    return true
end

-- The entries holding every word of the query in their title, path or
-- hint, case ignored; those with all of it in the title first.
function Search.Match(entries, query)
    local words = wordsOf(query)
    if #words == 0 then return {} end
    local inTitle, elsewhere = {}, {}
    for _, entry in ipairs(entries) do
        local title = entry.title:lower()
        if holdsAll(title, words) then
            inTitle[#inTitle + 1] = entry
        -- A hint may be a function (read when shown): not searched.
        elseif holdsAll(title .. " " .. entry.path:lower() .. " " .. (type(entry.hint) == "string"
            and entry.hint:lower() or ""), words) then
            elsewhere[#elsewhere + 1] = entry
        end
    end
    for _, entry in ipairs(elsewhere) do inTitle[#inTitle + 1] = entry end
    return inTitle
end

local function flash(row)
    if not row.searchFlash then
        local c = Style.COLORS.accent
        row.searchFlash = row:CreateTexture(nil, "BACKGROUND")
        row.searchFlash:SetAllPoints(row)
        row.searchFlash:SetColorTexture(c[1], c[2], c[3], FLASH_ALPHA)
    end
    local token = {}
    row.searchToken = token
    row.searchFlash:Show()
    C_Timer.After(FLASH_SECONDS, function()
        if row.searchToken == token then row.searchFlash:Hide() end
    end)
end

-- Scrolls a shown page's row of the key into view and lights it up. A key
-- without a row (a tab built by hand) leaves the page at its top. A row in
-- a closed fold (Options/Window.lua) opens its fold first.
function Search.Reveal(scroll, page, key)
    for _, row in ipairs(page.rows or {}) do
        if row.key == key and row.fold and not row.fold.open then
            row.fold:SetOpen(true)
            if page.Restack then page.Restack() end
            break
        end
    end
    local y = 0
    for _, row in ipairs(page.rows or {}) do
        -- A row folded away takes no room.
        if not (row.fold and not row.fold.open) then
            y = y + (row.stackGap or 0)
            if row.key == key then
                scroll:UpdateScrollChildRect()
                local range = math.max(0, scroll:GetVerticalScrollRange())
                scroll:SetVerticalScroll(math.max(0, math.min(range, y - REVEAL_MARGIN)))
                flash(row)
                return row
            end
            y = y + row:GetHeight()
        end
    end
    return nil
end

local function newRow(list, i)
    local b = CreateFrame("Button", nil, list)
    b:SetHeight(ROW_H)
    b:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -1 - (i - 1) * ROW_H)
    b:SetPoint("TOPRIGHT", list, "TOPRIGHT", -1, -1 - (i - 1) * ROW_H)
    b.hover = Style.Fill(b, "hover", "ARTWORK")
    b.hover:Hide()
    b.text = Style.Text(b, TITLE_SIZE, "text")
    b.text:SetPoint("TOPLEFT", b, "TOPLEFT", ROW_INSET, -4)
    b.text:SetPoint("TOPRIGHT", b, "TOPRIGHT", -ROW_INSET, -4)
    b.path = Style.Text(b, PATH_SIZE, "muted")
    b.path:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", ROW_INSET, 5)
    b.path:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -ROW_INSET, 5)
    for _, text in ipairs({ b.text, b.path }) do
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
    end
    Chrome.Hoverable(b, "text")
    return b
end

-- The box in a window's title bar, left of its close cross. spec: bar,
-- entries() and go(entry). Returns the box; box.list is the result list.
function Search.Attach(spec)
    local bar = spec.bar
    local box = CreateFrame("EditBox", nil, bar)
    box:SetSize(BOX_W, BOX_H)
    box:SetPoint("RIGHT", bar.close, "LEFT", -BOX_GAP, 0)
    box:SetAutoFocus(false)
    box:SetFont(ns.Media.Font("Friz Quadrata"), TITLE_SIZE, "")
    Style.Paint(box, "text")
    box:SetJustifyH("LEFT")
    box:SetTextInsets(6, 6, 0, 0)
    Style.Fill(box, "control")
    Style.Border(box)
    local placeholder = Style.Text(box, TITLE_SIZE, "muted")
    placeholder:SetPoint("LEFT", box, "LEFT", 6, 0)
    placeholder:SetText(L.SEARCH_PLACEHOLDER)

    local list = CreateFrame("Frame", nil, bar)
    list:SetFrameStrata("DIALOG")
    list:SetWidth(LIST_W)
    list:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -2)
    list:EnableMouse(true)
    Style.Fill(list, "panel")
    Style.Border(list)
    list:Hide()
    box.list = list
    list.rows = {}
    list.note = Style.Text(list, PATH_SIZE + 1, "muted")
    list.note:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", ROW_INSET, 6)

    local results = {}
    local function go(entry)
        list:Hide()
        box:ClearFocus()
        spec.go(entry)
    end
    local function render()
        local text = box:GetText() or ""
        placeholder:SetShown(text == "")
        results = Search.Match(spec.entries(), text)
        if not text:find("%S") then
            list:Hide()
            return
        end
        local shown = math.min(#results, Search.MAX_RESULTS)
        for i = 1, shown do
            local row = list.rows[i]
            if not row then
                row = newRow(list, i)
                row:SetScript("OnClick", function(self) go(self.entry) end)
                list.rows[i] = row
            end
            row.entry = results[i]
            row.text:SetText(results[i].title)
            row.path:SetText(results[i].path)
            row:Show()
        end
        for i = shown + 1, #list.rows do list.rows[i]:Hide() end
        local note
        if #results == 0 then
            note = L.SEARCH_NONE
        elseif #results > shown then
            note = L.SEARCH_MORE:format(#results - shown)
        end
        list.note:SetText(note or "")
        list:SetHeight(shown * ROW_H + (note and MORE_H or 0) + 2)
        list:Show()
    end

    box:SetScript("OnTextChanged", render)
    box:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        render()
    end)
    box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    box:SetScript("OnEnterPressed", function() if results[1] then go(results[1]) end end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    -- A click anywhere else closes the list; the text stays for the next
    -- click into the box.
    list:RegisterEvent("GLOBAL_MOUSE_DOWN")
    list:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not box:IsMouseOver() then self:Hide() end
    end)
    return box
end

local _, ns = ...

-- Party frames. A SecureGroupHeaderTemplate creates one button per member
-- from the template in Units/Party.xml. There is no initialConfigFunction:
-- secure snippets do not run on this client. The XML gives each button its
-- starting size and clicks; Lua sizes it when it is made out of combat. A
-- unit handed out in combat (someone joins) relays the whole block after
-- combat: the header sizes itself from button 1 at layout time.
local Party = {}
ns.Party = Party

local Config, Single = ns.Config, ns.Single

Party.KEY = "party"
Party.HEADER = "ForeverUnitFramesParty"
Party.TEMPLATE = "ForeverUnitFramesPartyButtonTemplate"
Party.MEMBERS = 4
-- Every button the header made, in creation order.
Party.buttons = {}

local function get(key) return Config.Get(Party.KEY, key) end

-- Slots in a full block: four members, plus the player if shown.
function Party.Slots()
    return Party.MEMBERS + (get("partyShowPlayer") and 1 or 0)
end

-- Distance between two members. Stacked vertically, a docked castbar
-- (above or below each member) sits in between, so its room is added:
-- the next member starts past the castbar's border.
function Party.Spacing()
    local spacing = get("partySpacing")
    if get("partyOrientation") == "HORIZONTAL" then return spacing end
    return spacing + ns.Castbar.DockedDepth(Party.KEY)
end

-- Width and height of the whole block with every slot filled.
function Party.BlockSize()
    local w, h, s, n = get("width"), get("height"), Party.Spacing(), Party.Slots()
    if get("partyOrientation") == "HORIZONTAL" then
        return n * w + (n - 1) * s, h
    end
    return w, n * h + (n - 1) * s
end

-- Offset of slot i (1-based) from the block's top-left corner.
function Party.SlotOffset(i)
    local step = i - 1
    if get("partyOrientation") == "HORIZONTAL" then
        return step * (get("width") + Party.Spacing()), 0
    end
    return 0, -step * (get("height") + Party.Spacing())
end

function Party.MoverSpec()
    return { scope = Party.KEY, point = "TOPLEFT", size = Party.BlockSize, label = ns.L.FRAME_party }
end

-- Header attributes are set in one go; a single relayout follows.
local function setAttributes(header, attributes)
    header:SetAttribute("_ignore", "attributeChanges")
    for name, value in pairs(attributes) do header:SetAttribute(name, value) end
    header:SetAttribute("_ignore", nil)
end

local function headerAttributes()
    local horizontal = get("partyOrientation") == "HORIZONTAL"
    local spacing = Party.Spacing()
    return {
        template = Party.TEMPLATE, templateType = "Button", sortMethod = "INDEX",
        showParty = true, showPlayer = get("partyShowPlayer"), showSolo = get("partyShowSolo"),
        point = horizontal and "LEFT" or "TOP",
        xOffset = horizontal and spacing or 0,
        yOffset = horizontal and 0 or -spacing,
    }
end

-- The block hangs from its top-left corner; X / Y are its centre, like
-- every other position. With a mover the header follows the mover.
local function place(header)
    if header.mover then
        ns.Movers.Sync(header)
        return
    end
    local w, h = Party.BlockSize()
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", UIParent, "CENTER", get("x") - w / 2, get("y") + h / 2)
end

function Party.StyleButton(button)
    if not InCombatLockdown() then
        button:SetSize(get("width"), get("height"))
    end
    Single.StyleContent(button)
    Single.UpdateAll(button)
end

-- Out of combat only: attributes, position, size and visibility are
-- protected on the header and its buttons.
function Party.StyleAll()
    local header = Party.header
    if not header then return end
    setAttributes(header, headerAttributes())
    place(header)
    -- The header only SetPoints the buttons it shows; an anchor on the
    -- other orientation's point would stay. Clear them all first.
    for _, button in ipairs(Party.buttons) do
        Party.StyleButton(button)
        button:ClearAllPoints()
    end
    -- Hide + Show makes the header lay its buttons out again (OnShow).
    header:Hide()
    if get("enabled") then header:Show() end
end

-- XML OnLoad: the button exists, its unit is not known yet.
function Party.InitButton(button)
    button.key = Party.KEY
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    Party.buttons[#Party.buttons + 1] = button
    -- Made in combat it keeps the XML size until the relayout after combat.
    if not InCombatLockdown() then
        button:SetSize(get("width"), get("height"))
    end
    Single.StyleContent(button)
end

-- The header assigns or clears a unit, in or out of combat.
function Party.OnUnitChanged(button, unit)
    button.unit = unit
    ns.UnitEvents.Bind(button)
    if not unit then return end
    if InCombatLockdown() then ns.AfterCombat("partyStyle", Party.StyleAll) end
    Single.UpdateAll(button)
end

-- What the options window outlines when Party is selected.
function Party.HighlightTarget()
    return Party.header
end

function Party.Create()
    if Party.header then return Party.header end
    local header = CreateFrame("Frame", Party.HEADER, UIParent, "SecureGroupHeaderTemplate")
    header.key = Party.KEY
    Party.header = header
    Party.StyleAll()
    return header
end

-- Called from Units/Party.xml; not part of the public API.
ns.api.PartyButtonOnLoad = Party.InitButton
function ns.api.PartyButtonOnAttributeChanged(button, name, value)
    if name == "unit" then Party.OnUnitChanged(button, value) end
end

ns.Listen("CONFIG_CHANGED", function(scope)
    if scope ~= nil and scope ~= "general" and scope ~= Party.KEY then return end
    ns.AfterCombat("partyStyle", Party.StyleAll)
end)

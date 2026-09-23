local _, ns = ...

-- Party frames. A SecureGroupHeaderTemplate creates one button per member
-- from the template in Units/Party.xml. There is no initialConfigFunction:
-- secure snippets do not run on this client. The XML gives each button its
-- starting size and clicks; Lua sizes and styles it when the header hands
-- it a unit, and again after combat if that happened in combat.
local Party = {}
ns.Party = Party

local Config, Single = ns.Config, ns.Single

Party.KEY = "party"
Party.HEADER = "ForeverUnitFramesParty"
Party.TEMPLATE = "ForeverUnitFramesPartyButtonTemplate"
Party.MEMBERS = 4
Party.SPACING = 12
-- Every button the header made, in creation order.
Party.buttons = {}

local function get(key) return Config.Get(Party.KEY, key) end

-- Width and height of the whole block with every slot filled.
function Party.BlockSize()
    local w, h, n = get("width"), get("height"), Party.MEMBERS
    return w, n * h + (n - 1) * Party.SPACING
end

-- Header attributes are set in one go; a single relayout follows.
local function setAttributes(header, attributes)
    header:SetAttribute("_ignore", "attributeChanges")
    for name, value in pairs(attributes) do header:SetAttribute(name, value) end
    header:SetAttribute("_ignore", nil)
end

local function headerAttributes()
    return {
        template = Party.TEMPLATE, templateType = "Button", sortMethod = "INDEX",
        showParty = true, showPlayer = false, showSolo = false,
        point = "TOP", xOffset = 0, yOffset = -Party.SPACING,
    }
end

-- Top-left corner of the block at the configured centre position.
local function place(header)
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

local function sizeButtons()
    for _, button in ipairs(Party.buttons) do
        button:SetSize(get("width"), get("height"))
    end
end

-- Out of combat only: attributes, position, size and visibility are
-- protected on the header and its buttons.
function Party.StyleAll()
    local header = Party.header
    if not header then return end
    setAttributes(header, headerAttributes())
    place(header)
    for _, button in ipairs(Party.buttons) do Party.StyleButton(button) end
    -- Hide + Show makes the header lay its buttons out again (OnShow).
    header:Hide()
    if get("enabled") then header:Show() end
end

-- XML OnLoad: the button exists, its unit is not known yet.
function Party.InitButton(button)
    button.key = Party.KEY
    for _, el in ipairs(ns.Elements) do el.Build(button) end
    Party.buttons[#Party.buttons + 1] = button
    Single.StyleContent(button)
end

-- The header assigns or clears a unit, in or out of combat.
function Party.OnUnitChanged(button, unit)
    button.unit = unit
    ns.UnitEvents.Bind(button)
    if not unit then return end
    ns.AfterCombat("partySize", sizeButtons)
    Single.UpdateAll(button)
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

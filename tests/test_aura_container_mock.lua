-- The mock's stand-in for CustomAuraContainerTemplate checks what the
-- source checks, and records what the addon tells it.
local M = H.M
H.LoadAddon()

local c = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
H.checkError("other template", function() CreateFrame("AuraContainer", nil, UIParent, "SomeTemplate") end)
H.check("unit starts at none", c:GetUnit(), "none")
H.checkError("unit must be a string", function() c:SetUnit(nil) end)
local updates = c._updates
c:SetUnit("target")
H.check("unit", c:GetUnit(), "target")
H.check("a new unit refreshes", c._updates, updates + 1)
c:SetUnit("target")
H.check("the same unit does not", c._updates, updates + 1)
c:UpdateAllAuras()
H.check("UpdateAllAuras counted", c._updates, updates + 2)
H.checkError("unknown method", function() c:SetAuraGroupSortMethod("x", 0, 0) end)

-- Groups: key, filter and options are checked.
local inits = {}
local function init(button) inits[#inits + 1] = button end
H.checkError("empty key", function() c:AddAuraGroup("", "HELPFUL") end)
H.checkError("bad filter token", function() c:AddAuraGroup("a", "HELPFUL|MINE") end)
H.checkError("bare negation", function() c:AddAuraGroup("a", "HELPFUL|!") end)
H.checkError("unknown option", function() c:AddAuraGroup("a", "HELPFUL", { size = 3 }) end)
H.checkError("unknown layout key", function() c:AddAuraGroup("a", "HELPFUL", { layout = { width = 3 } }) end)
H.checkError("negative size", function() c:AddAuraGroup("a", "HELPFUL", { layout = { elementWidth = -1 } }) end)
H.checkError("fractional maximum", function() c:AddAuraGroup("a", "HELPFUL", { maxFrameCount = 1.5 }) end)
H.checkError("bad sort", function() c:AddAuraGroup("a", "HELPFUL", { sortMethod = 99 }) end)
H.check("nothing added by the refusals", #c._groupOrder, 0)
c:AddAuraGroup("own", "HARMFUL|RAID|PLAYER", { maxFrameCount = 4, initializeFrame = init,
    layout = { elementWidth = 26, elementHeight = 26, elementSpacing = 2 } })
c:AddAuraGroup("other", "HARMFUL|!PLAYER")
H.checkError("same key twice", function() c:AddAuraGroup("own", "HARMFUL") end)
H.check("order kept", table.concat(c._groupOrder, ","), "own,other")
H.check("filter", c._groups.own.filter, "HARMFUL|RAID|PLAYER")
H.check("maximum", c._groups.own.max, 4)
H.check("no maximum: infinite", c._groups.other.max, math.huge)
H.check("layout width", c._groups.own.layout.elementWidth, 26)
H.check("layout defaults merged", c._groups.own.layout.lineSpacing, 0)
H.check("new line off by default", c._groups.other.layout.forceNewLine, false)
H.check("one batch made", c:GetAuraGroupFrameCount("own"), M.AURA_BATCH)
H.check("each handed to initializeFrame", #inits, M.AURA_BATCH)
H.check("in order", inits[1], c:GetAuraGroupFrame("own", 1))
H.check("buttons are aura buttons", inits[1]._template, "CustomAuraButtonTemplate")
H.check("buttons belong to the container", inits[1]:GetParent(), c)

-- Changes later: the whole layout is replaced; unknown groups raise.
c:SetAuraGroupLayout("own", { elementSpacing = 4 })
H.check("layout replaced", c._groups.own.layout.elementWidth, nil)
H.check("new spacing", c._groups.own.layout.elementSpacing, 4)
c:SetAuraGroupEnabled("other", false)
H.check("group off", c._groups.other.enabled, false)
H.checkError("enabled must be a boolean", function() c:SetAuraGroupEnabled("other", nil) end)
c:SetAuraGroupFilterString("other", "HARMFUL")
H.check("filter changed", c._groups.other.filter, "HARMFUL")
c:SetAuraGroupMaxFrameCount("other", 6)
H.check("maximum changed", c._groups.other.max, 6)
H.checkError("unknown group", function() c:SetAuraGroupLayout("nope", {}) end)
H.checkError("no RemoveAuraGroup", function() c:RemoveAuraGroup("own") end)

-- Flow layout: enum values are checked.
c:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Vertical)
c:SetFlowLayoutAnchorPoint("BOTTOMRIGHT")
c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
c:SetFlowLayoutMaximumLineSize(100)
H.check("axis", c._flow.axis, 1)
H.check("anchor", c._flow.anchor, "BOTTOMRIGHT")
H.check("growth", c._flow.horizontal .. "," .. c._flow.vertical, "-1,1")
H.check("line size", c._flow.lineSize, 100)
c:SetFlowLayoutMaximumLineSize(nil)
H.check("no line size: infinite", c._flow.lineSize, math.huge)
H.checkError("bad axis", function() c:SetFlowLayoutAxis(5) end)
H.checkError("bad direction", function() c:SetFlowLayoutGrowthDirection(0, 1) end)

-- Buttons: regions must be of the right type and below the button.
local b = c:GetAuraGroupFrame("other", 1)
local icon = b:CreateTexture()
local cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
local count = b:CreateFontString()
H.checkError("icon from elsewhere", function() b:SetIcon(UIParent:CreateTexture()) end)
H.checkError("icon of the wrong type", function() b:SetIcon(count) end)
H.checkError("count without a font", function() b:SetApplicationCount(count) end)
count:SetFont("font", 10, "")
b:SetIcon(icon)
b:SetDurationCooldown(cooldown)
b:SetApplicationCount(count)
H.check("icon registered", b._icon, icon)
H.check("count written at once", count:GetText(), "")
b:AddDispelTypeTexture(icon, { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset })
H.checkError("added twice", function() b:AddDispelTypeTexture(icon) end)
H.checkError("bad style", function() b:AddDispelTypeTexture(b:CreateTexture(), { style = 9 }) end)
H.checkError("bad tooltip anchor", function() b:SetTooltipAnchorPoint("BOTTOMRIGHT") end)
b:SetTooltipAnchorPoint("ANCHOR_BOTTOMRIGHT")
H.check("tooltip anchor", b._tooltipAnchor[1], "ANCHOR_BOTTOMRIGHT")
H.checkError("no addon scripts", function() b:SetScript("OnEnter", function() end) end)

-- While auras are secret (combat) the button and its regions refuse us.
local grown = c:GetAuraGroupFrameCount("other")
M.combat = true
H.checkError("button in combat", function() b:SetSize(10, 10) end)
H.checkError("region in combat", function() count:SetFont("font", 12, "") end)
H.checkError("no-op method in combat", function() icon:SetDesaturated(true) end)
-- New buttons are handed to initializeFrame before they are restricted.
local sizedInCombat
c:AddAuraGroup("late", "HELPFUL", { initializeFrame = function(button) button:SetSize(9, 9); sizedInCombat = true end })
H.checkTrue("initializeFrame may style in combat", sizedInCombat)
M.GrowAuraGroup(c, "other")
H.check("grown by a batch", c:GetAuraGroupFrameCount("other"), grown + M.AURA_BATCH)
M.combat = false
b:SetSize(10, 10)
H.check("out of combat again", b:GetWidth(), 10)
M.aurasSecret = true
H.checkError("secret out of combat", function() b:SetSize(11, 11) end)
M.aurasSecret = false

-- Errors in initializeFrame are reported, not raised.
local errors = #M.errors
c:AddAuraGroup("broken", "HELPFUL", { initializeFrame = function() error("oops") end })
H.check("reported once per button", #M.errors - errors, M.AURA_BATCH)

-- Anchoring to a container with groups needs the layout aspect.
local plain = CreateFrame("Frame", nil, UIParent)
H.checkError("plain frame on a container", function() plain:SetPoint("TOP", c, "BOTTOM") end)
local opted = CreateFrame("Frame", nil, UIParent, "DisableUntrustedLayoutScriptsTemplate")
opted:SetPoint("TOP", c, "BOTTOM")
H.check("opted-in frame", select(2, opted:GetPoint(1)), c)
local other = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
H.checkError("container without groups", function() other:SetPoint("TOP", c, "BOTTOM") end)
other:AddAuraGroup("x", "HELPFUL")
other:SetPoint("TOP", c, "BOTTOM")
H.check("container with groups", select(2, other:GetPoint(1)), c)
local empty = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
plain:SetPoint("TOP", empty, "BOTTOM")
H.check("container without groups takes anything", select(2, plain:GetPoint(1)), empty)
-- Children carry their parent's aspect.
local child = CreateFrame("Frame", nil, c)
child:SetPoint("TOP", c, "TOP")
H.check("child of the container", select(2, child:GetPoint(1)), c)
local region = b:CreateTexture()
region:SetPoint("TOPLEFT", b, "TOPLEFT")
H.check("region on its button", select(2, region:GetPoint(1)), b)

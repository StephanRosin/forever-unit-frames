-- Blizzard's click bindings (SecureTemplates.lua: SecureUnitButton_OnClick)
-- come first on a unit button: a target or menu click only acts when the
-- click is bound to an interaction there, and the default profile binds
-- only the plain left and right clicks. So Target on any other click is
-- written as a macro, and the menu is offered on the plain left and right
-- clicks only (Raid/ClickCast.lua, Raid/Settings.lua).
local M = H.M
local ns = H.LoadAddon()
local RC, RS, Header, Cell = ns.RaidConfig, ns.RaidSettings, ns.RaidHeader, ns.RaidCell

-- The mock treats these templates as unit buttons: the XML says so.
for template, file in pairs({ ForeverUnitFramesRaidButtonTemplate = "Raid/Cell.xml",
    ForeverUnitFramesPartyButtonTemplate = "Units/Party.xml",
    ForeverUnitFramesPartyPetButtonTemplate = "Units/PartyPets.xml" }) do
    H.checkTrue(template .. " is a unit button", M.UNIT_BUTTON_TEMPLATES[template]
        and H.ReadFile(file):find('name="' .. template .. '" virtual="true" inherits="SecureUnitButtonTemplate"', 1,
            true))
end

ns.Config.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()
Header.Create()
ns.ClickCast.ApplyAll()
M.SetRaidRoster({ { name = "A", class = "PRIEST", subgroup = 1, unit = { health = 1, healthMax = 1 } },
    { name = "B", class = "MAGE", subgroup = 1, unit = { health = 1, healthMax = 1 } } })
M.RunTimers()
local cell = Cell.buttons[1]
H.checkTrue("a cell", cell)

local function click(mouseButton, shift)
    M.shiftDown = shift or false
    local ran = M.SecureClick(cell, mouseButton)
    M.shiftDown = false
    return ran
end

-- The client, as modelled: plain left and right act; a modified click
-- that falls back to target or the menu does nothing.
H.check("left targets", click("LeftButton"), "target")
H.check("right: the menu", click("RightButton"), "togglemenu")
H.check("shift-left falls back to target: blocked", click("LeftButton", true), nil)
H.check("shift-right falls back to the menu: blocked", click("RightButton", true), nil)
-- A spell bound in Blizzard's click-binding window wins over ours.
M.clickBindings[#M.clickBindings + 1] = { button = "MiddleButton", modifiers = 1, type = 1 }
RC.Set("general", "click3Shift", "assist")
M.shiftDown = true
H.check("Blizzard's binding wins", M.SecureClick(cell, "MiddleButton"), "clickbinding")
M.shiftDown = false
H.check("it ran once", #M.clickBindingRuns, 1)

-- Target on a modified click: a macro on the unit under the mouse (the
-- cell clicked).
RC.Set("general", "click1Shift", "target")
H.check("shift-left: a macro", cell:GetAttribute("shift-type1"), "macro")
H.check("its text", cell:GetAttribute("shift-macrotext1"), "/target [@mouseover]")
H.check("shift-left now acts", click("LeftButton", true), "macro")
-- On a plain click other than left and right too.
RC.Set("general", "click3", "target")
H.check("middle: a macro", cell:GetAttribute("*type3"), "macro")
H.check("middle's text", cell:GetAttribute("*macrotext3"), "/target [@mouseover]")
-- The plain left and right clicks keep the client's own targeting.
H.check("left: target itself", cell:GetAttribute("*type1"), "target")
H.check("left: no macro", cell:GetAttribute("*macrotext1"), nil)
RC.Set("general", "click2", "target")
H.check("right: target itself", cell:GetAttribute("*type2"), "target")
H.check("right targets", click("RightButton"), "target")
-- Something else again: the macro is gone.
RC.Set("general", "click1Shift", "focus")
H.check("shift-left focuses", cell:GetAttribute("shift-type1"), "focus")
H.check("the macro cleared", cell:GetAttribute("shift-macrotext1"), nil)

-- The menu only on the plain left and right clicks.
H.check("menu on the plain right", RS.Validate(RS.Get("click2"), "menu"), "menu")
H.check("menu on the plain left", RS.Validate(RS.Get("click1"), "menu"), "menu")
H.check("no menu on shift-right", RS.Validate(RS.Get("click2Shift"), "menu"), nil)
H.check("no menu on the middle", RS.Validate(RS.Get("click3"), "menu"), nil)
H.check("target anywhere", RS.Validate(RS.Get("click4CtrlAlt"), "target"), "target")
local function kinds(key)
    return table.concat(ns.Raid.SlotKinds(ns.Raid.CLICK_SLOT_BY_KEY[key]), ",")
end
H.check("plain left's kinds", kinds("click1"), ",target,focus,assist,menu,spell,item,macro")
H.check("shift-left's kinds", kinds("click1Shift"), ",target,focus,assist,spell,item,macro")
H.check("nothing blocked", #M.blocked, 0)

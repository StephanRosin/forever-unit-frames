-- Words of the raid menu that were unclear or lost part of their meaning
-- in a translation (Locales/*.lua).
local ns = H.LoadAddon()
local de, es, fr = ns.Locales.deDE, ns.Locales.esES, ns.Locales.frFR

H.check("German: the arrangement section is not the tab's word", de.RAID_SECTION_arrangement ~= de.RAID_TAB_layout, true)
H.check("German: arrangement", de.RAID_SECTION_arrangement, "Blöcke und Zellen")
H.check("German: target line", de.RAID_SETTING_targetBorder, "Helle Linie bei deinem Ziel")
H.check("Spanish: the classes not named follow", es.RAID_HINT_classOrder,
    "Nombres de clase, p. ej. Sacerdote, Druida; el resto sigue")
H.check("Spanish: from the screen's centre (x)", es.RAID_HINT_x, "Esquina sup. izquierda, desde el centro de la pantalla")
H.check("Spanish: from the screen's centre (y)", es.RAID_HINT_y, es.RAID_HINT_x)
H.check("French: from the screen's centre (x)", fr.RAID_HINT_x, "Coin sup. gauche, depuis le centre de l'écran")
H.check("French: from the screen's centre (y)", fr.RAID_HINT_y, fr.RAID_HINT_x)

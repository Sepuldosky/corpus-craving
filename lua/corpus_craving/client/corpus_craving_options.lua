-- corpus_craving_options.lua — tab único del menú Q (CLIENT)
-- Una sola entrada vía la primitiva de Corpus (Q → Utilities → Corpus →
-- Craving). Layout manual (DLabel/DCheckBoxLabel apilados), patrón validado en
-- ADS/Caliber. Estado + detección de soft-deps + el toggle client de hints.

local CRAVING = Corpus.GetModule("craving")

Corpus.UI.RegisterTab("craving", "Craving", function(panel)
    -- Strings de cara al jugador en inglés (idioma del mod).
    local titulo = vgui.Create("DLabel", panel)
    titulo:SetText("Craving — hunger & thirst")
    titulo:SetFont("DermaDefaultBold")
    titulo:SetDark(true)
    titulo:Dock(TOP)
    titulo:DockMargin(8, 8, 8, 4)
    titulo:SizeToContents()

    local cuerpo = vgui.Create("DLabel", panel)
    cuerpo:SetText("Both stats decay over time (faster while sprinting or overloaded).\nEat and drink to restore them. At zero you starve.")
    cuerpo:SetDark(true)
    cuerpo:SetWrap(true)
    cuerpo:SetAutoStretchVertical(true)
    cuerpo:Dock(TOP)
    cuerpo:DockMargin(8, 0, 8, 8)

    -- Detección de soft-deps en el momento de construir el panel (lazy-check,
    -- CORPUS_Architecture.md §6.a) — el spawnmenu se abre bien después del boot.
    local deps = vgui.Create("DLabel", panel)
    deps:SetText(string.format(
        "Detected — Cargo: %s | Coagulant: %s | STALKER assets: %s",
        Corpus.HasModule("cargo") and "yes" or "no",
        Corpus.HasModule("coagulant") and "yes" or "no",
        CRAVING.Assets.StalkerMounted() and "yes" or "no"
    ))
    deps:SetDark(true)
    deps:Dock(TOP)
    deps:DockMargin(8, 0, 8, 8)
    deps:SizeToContents()

    local hints = vgui.Create("DCheckBoxLabel", panel)
    hints:SetText("Show hunger/thirst hints")
    hints:SetConVar("craving_hints")
    hints:SetDark(true)
    hints:Dock(TOP)
    hints:DockMargin(8, 0, 8, 8)
    hints:SizeToContents()

    local admin = vgui.Create("DLabel", panel)
    admin:SetText("Server convars (admin): craving_enabled, craving_decay_scale\n(0 freezes both stats), craving_damage_scale, craving_stomach_sounds.")
    admin:SetDark(true)
    admin:SetWrap(true)
    admin:SetAutoStretchVertical(true)
    admin:Dock(TOP)
    admin:DockMargin(8, 0, 8, 8)
end)

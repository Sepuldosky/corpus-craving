-- corpus_craving_bars.lua — barras del StatusPanel de Cargo (CLIENT)
-- Craving_Architecture.md §10: no hay HUD propio (decisión E) — las barras de
-- Cargo son la presentación. Cargo es SOFT-DEP: sin él, el feedback queda
-- indirecto (hints + sonidos del server) y este archivo solo lo loguea.
-- Firma real verificada contra corpus_cargo_statuspanel.lua (2026-07-13):
-- RegisterBar(module, { id, label, getValue -> 0..100, color }).

local CRAVING = Corpus.GetModule("craving")

Corpus.OnReady(function()
    local cargo = Corpus.GetModule("cargo")
    if cargo == nil or cargo.StatusPanel == nil
        or not isfunction(cargo.StatusPanel.RegisterBar) then
        Corpus.Log("craving", "Cargo no presente: sin barras (feedback indirecto solamente)")
        return
    end

    cargo.StatusPanel.RegisterBar("craving", {
        id       = "hunger",
        label    = "Hunger",
        color    = Color(214, 142, 58),
        getValue = function(ply) return CRAVING.GetHunger(ply) end,
    })
    cargo.StatusPanel.RegisterBar("craving", {
        id       = "hydration",
        label    = "Hydration",
        color    = Color(86, 160, 211),
        getValue = function(ply) return CRAVING.GetHydration(ply) end,
    })

    Corpus.Log("craving", "barras registradas en el StatusPanel de Cargo (2)")
end)

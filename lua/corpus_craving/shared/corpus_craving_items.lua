-- corpus_craving_items.lua — consumibles contra el framework de Cargo (SHARED)
-- Patrón del contrato de ítems generalizado (CORPUS_Architecture.md §5): Cargo
-- posee el contenedor (grid, peso, persistencia, render); Craving posee la
-- semántica (qué restaura cada comida al usarse). Cargo es SOFT-DEP: se detecta
-- vía el registro, nunca se asume — sin Cargo, la vía de mundo es la entity
-- corpus_craving_food (Craving_Architecture.md §7).
--
-- SHARED a propósito (lección pagada en la primera pasada en juego, 2026-07-13):
-- el snapshot de Cargo solo transporta defs autogen/icon_override
-- (corpus_cargo_inventory.lua §"defs auto-generated") — una def registrada solo
-- en server NUNCA existe en el cliente: el grid no la renderiza y el menú "Use"
-- exige isfunction(def.onUse) client-side (que no viaja por JSON). Las defs de
-- módulo se registran en AMBOS realms, igual que las propias de Cargo
-- (corpus_cargo_dev.lua: "both realms: the client grid renders from defs too").
-- El onUse solo CORRE en server (Cargo lo invoca allá); en client únicamente
-- habilita la opción del menú.

local CRAVING = Corpus.GetModule("craving")
local Config = CRAVING.Config

-- Se registra en la ready barrier: corre una vez, con todos los módulos presentes
-- ya registrados (CORPUS_Architecture.md §6.b). Lazy-check + degradación honesta.
Corpus.OnReady(function()
    local cargo = Corpus.GetModule("cargo")
    if cargo == nil then
        Corpus.Log("craving", "Cargo no presente: consumibles apagados (la entity de mundo sigue viva)")
        return
    end

    -- categoría única "food" (§5); el registro explícito fija label y orden
    if isfunction(cargo.Items.RegisterCategory) then
        cargo.Items.RegisterCategory("food", "Food", 60)
    end

    for _, item in ipairs(Config.ITEMS) do
        cargo.Items.Register({
            id       = item.id,
            name     = item.name,
            weight   = item.weight,
            class    = "stackable",
            category = "food",
            model    = CRAVING.Assets.Model(item.models),
            trivia   = item.trivia,
            onUse    = function(ply)
                -- semántica del consumo: dominio de Craving, no de Cargo.
                -- Corre solo en server; false (barra llena, §5) → Cargo NO
                -- descuenta la unidad.
                return CRAVING.Consume(ply, item)
            end,
        })
    end

    Corpus.Log("craving", "consumibles registrados contra Cargo ("
        .. #Config.ITEMS .. " defs, " .. (SERVER and "server" or "client") .. ")")
end)

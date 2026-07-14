-- corpus_craving_assets.lua — resolución de assets por lista de candidatos (SHARED)
-- Craving_Architecture.md §6. Los assets STALKER viven en el addon de contenido
-- "Corpus S.T.A.L.K.E.R." (repo corpus-stalker/, assets no versionados); este
-- repo solo referencia rutas de juego, que son independientes de dónde viva el
-- addon en disco. Mismo espíritu que el helper ZonaModel de Cargo, pero por
-- lista: el primer candidato montado gana. Se queda acá — no sube a Corpus ni
-- se importa de Cargo (duplicar 15 líneas es más barato que acoplar dominios).

local CRAVING = Corpus.GetModule("craving")

CRAVING.Assets = CRAVING.Assets or {}
local Assets = CRAVING.Assets

-- Devuelve la primera ruta de modelo montada de la lista; si ninguna existe,
-- la ÚLTIMA es el fallback garantizado (HL2 vanilla). file.Exists es realm-safe
-- para rutas GAME.
function Assets.Model(candidates)
    for i, path in ipairs(candidates) do
        if i == #candidates then return path end
        if isstring(path) and file.Exists(path, "GAME") then return path end
    end
    return "models/props_junk/cardboard_box004a.mdl" -- lista vacía: nunca debería pasar
end

-- Devuelve la primera ruta de sonido montada, o nil si ninguna existe (el caller
-- omite el feedback — p.ej. el estómago no tiene fallback digno en HL2, §6).
function Assets.Sound(candidates)
    for _, path in ipairs(candidates) do
        if isstring(path) and file.Exists("sound/" .. path, "GAME") then return path end
    end
    return nil
end

-- ============================================================
-- Sets concretos del v1 (§6) — rutas ZONA verbatim del pack actionsounds;
-- fallbacks del engine. Selección re-hecha tras la ronda 2 en juego
-- (2026-07-13): los eat1-5.mp3 del pack suenan a tragos e inv_softdrink a
-- líquido derramándose — inv_food.ogg es el masticado canónico de STALKER,
-- inv_vodka.ogg los tragos de botella (sirven para agua y vodka por igual).
-- ============================================================

local CONSUME_SETS = {
    eat   = { "zona/stalkerrp/actions/interface/inv_food.ogg", "npc/barnacle/barnacle_gulp1.wav" },
    drink = { "zona/stalkerrp/actions/interface/inv_vodka.ogg", "ambient/water/water_spray1.wav" }, -- tragos de botella
    can   = { "zona/stalkerrp/actions/interface/inv_softdrink.ogg", "ambient/water/water_spray1.wav" }, -- lata con gas
    vodka = { "zona/stalkerrp/actions/interface/inv_vodka.ogg", "ambient/water/water_spray1.wav" },
}
Assets.STOMACH = { "zona/stalkerrp/hunger.mp3" } -- sin fallback (§6)

-- Sonido de consumo para un kind de la tabla de ítems
-- ("eat"|"drink"|"can"|"vodka"); sin el addon cae al fallback del engine.
function Assets.ConsumeSound(kind)
    local set = CONSUME_SETS[kind]
    if set == nil then return nil end
    return Assets.Sound(set)
end

-- ¿Está montado el addon de assets? (informativo: tab Q, selftest)
function Assets.StalkerMounted()
    return file.Exists("models/stalker/item/food/bread.mdl", "GAME")
end

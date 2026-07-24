-- corpus_craving_assets.lua — resolución de assets por lista de candidatos (SHARED)
-- Craving_Architecture.md §6. Dos fuentes de assets, ninguna versionada y
-- ninguna asumida: los sonidos de consumo GENERALES viven en el banco del
-- framework (corpus/sound/corpus/craving/, COR-17) y los modelos + el estómago
-- ZONA en el addon de contenido "Corpus S.T.A.L.K.E.R." (corpus-stalker/,
-- STK-2); este repo solo referencia rutas de juego, que son independientes de
-- dónde viva cada addon en disco. Mismo espíritu que el helper ZonaModel de
-- Cargo, pero por lista: el primer candidato montado gana. Se queda acá — no
-- sube a Corpus ni se importa de Cargo (duplicar 15 líneas es más barato que
-- acoplar dominios).

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
-- Sets concretos del v1 (§6) — banco de sonidos GENERAL del ecosistema
-- (corpus/sound/corpus/craving/, ports de GAMMA no versionados: COR-17);
-- fallbacks del engine. Decisión del autor 2026-07-24 (separación sonidos/
-- ítems): los zona/stalkerrp/* de corpus-stalker quedan RESERVADOS para la
-- comida propia de ese addon — estos consumibles genéricos comen con el banco
-- general. La selección por oído de la ronda 2 (2026-07-13: "el nombre del
-- archivo miente, validar por oído") sigue vigente como método; el mapa de
-- variantes vive en sound/corpus/craving/about.txt.
-- ============================================================

local CONSUME_SETS = {
    eat   = { "corpus/craving/food_use.ogg", "npc/barnacle/barnacle_gulp1.wav" }, -- masticado
    drink = { "corpus/craving/drink_flask.ogg", "ambient/water/water_spray1.wav" }, -- tragos de cantimplora
    can   = { "corpus/craving/drink_soda_use.ogg", "ambient/water/water_spray1.wav" }, -- lata con gas
    vodka = { "corpus/craving/vodka_use.ogg", "ambient/water/water_spray1.wav" },
}
-- El estómago SÍ sigue en el addon de contenido: excepción declarada CRV-7
-- (sin fallback digno en HL2, §6) — no es un sonido de consumo de ítem.
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

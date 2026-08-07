-- corpus_craving_food.lua — registro de comidas y su taxonomía (SHARED)
-- Craving_Architecture.md §5. Va PRIMERO en el manifest: es el único escritor de
-- Config.ITEMS, y config.lua da de alta las suyas llamándolo.
--
-- POR QUÉ EXISTE (enmienda del autor, 2026-08-06)
-- Hasta hoy "agregar una comida" era editar una tabla literal, y el índice
-- Config.ITEMS_BY_ID se construía UNA VEZ en file-scope al final de config.lua.
-- Eso tenía un defecto latente: un table.insert posterior — un addon de
-- contenido, un lua refresh parcial — entraba en la lista pero NO en el índice,
-- y como CRAVING.Consume(ply, id) y la entity de mundo resuelven POR el índice,
-- la comida existía en el grid y era inconsumible. Nadie lo había pisado porque
-- nadie insertó nunca fuera de file-scope.
--
-- Con Register hay una sola ruta de alta y las dos tablas se mantienen juntas
-- por construcción: no hay forma de agregar una comida a una sola.
--
-- LA TAXONOMÍA, Y POR QUÉ NO ES UNA CATEGORÍA DE CARGO
-- Sería natural registrar "drinks" como categoría aparte, pero la fila de tabs
-- de Cargo está CERRADA (decisión del autor 2026-07-13, corpus_cargo_items.lua):
-- el set de categorías sigue abierto, pero el DISPLAY mapea categoría→tab y una
-- categoría no mapeada cae en la tab "Misc". Registrar "drinks" sacaría las
-- bebidas de la tab Food. Por eso `kind`/`tags`/`tier` viven acá y la categoría
-- de Cargo sigue siendo una sola: `food`. Cargo transporta los campos sin
-- interpretarlos (cita CRG-1), así que viajan en la def sin costo.

local CRAVING = Corpus.GetModule("craving")

CRAVING.Config = CRAVING.Config or {}
CRAVING.Food = CRAVING.Food or {}
local Config = CRAVING.Config
local Food = CRAVING.Food

-- Las dos tablas que Register mantiene sincronizadas. Se declaran acá y no en
-- config.lua justamente para que este archivo sea su único escritor.
Config.ITEMS = Config.ITEMS or {}
Config.ITEMS_BY_ID = Config.ITEMS_BY_ID or {}

-- ============================================================
-- Taxonomía (§5, enmienda 2026-08-06)
-- ============================================================

-- CERRADO: `kind` dice qué stat manda. Reemplaza la inferencia por números que
-- hacía el anti-desperdicio (CRV-8) — "gana el stat que más restaura" — que es
-- una heurística: una comida que diera +20/+20 caía del lado del hambre por el
-- desempate del >=, no porque fuera comida.
Food.KINDS = { food = "hunger", drink = "hydration" }

-- CERRADO: escala de calidad. El orden importa (se compara), los nombres no son
-- de cara al jugador. Todavía no gobierna nada: es el gancho para precio
-- (def.value de Cargo) y rareza de spawn cuando esos bloques abran.
Food.TIERS = { junk = 1, standard = 2, quality = 3 }

-- ABIERTO a propósito, como las categorías de Cargo: un addon de contenido puede
-- traer los suyos. Los conocidos se listan para que el set no derive en sinónimos
-- ("soda" y "softdrink" y "fizzy" para lo mismo). Son el gancho declarado de los
-- bloques diferidos de §14: `raw`/`cooked` para cocinar, `alcohol`/`caffeine`
-- para efectos de consumibles. NINGUNO hace nada hoy — cita COA-28: que el tag
-- exista no implementa el bloque.
Food.TAGS_CONOCIDOS = {
    packaged = true, canned = true, fresh = true, bottled = true,
    bread = true, dairy = true, meat = true, noodles = true, soda = true,
    alcohol = true, caffeine = true, sugary = true,
    raw = true, cooked = true,
}

-- ============================================================
-- Registro
-- ============================================================

--- Da de alta una comida. Devuelve la tabla registrada (by-ref, mismo espíritu
--- que el registro de Corpus: el dueño puede seguir poblándola).
--- Campos: id, name, kind, hunger, hydration, weight, sound, y model (ruta
--- directa) o models (lista de candidatos con fallback, §6). Opcionales:
--- tier (default "standard"), tags, trivia.
function Food.Register(item)
    if not istable(item) then
        error("Craving.Food.Register: 'item' debe ser una tabla", 2)
    end
    if not isstring(item.id) or item.id == "" then
        error("Craving.Food.Register: 'id' debe ser un string no vacío", 2)
    end
    if not isstring(item.name) or item.name == "" then
        error("Craving.Food.Register: 'name' inválido (ítem '" .. item.id .. "')", 2)
    end
    if Food.KINDS[item.kind] == nil then
        error("Craving.Food.Register: 'kind' debe ser \"food\" o \"drink\" (ítem '"
            .. item.id .. "')", 2)
    end
    if not isnumber(item.weight) or item.weight <= 0 then
        error("Craving.Food.Register: 'weight' debe ser > 0 (ítem '" .. item.id .. "')", 2)
    end
    if (item.hunger or 0) + (item.hydration or 0) <= 0 then
        error("Craving.Food.Register: no restaura nada (ítem '" .. item.id .. "')", 2)
    end
    if not isstring(item.model) and not istable(item.models) then
        error("Craving.Food.Register: falta 'model' o 'models' (ítem '" .. item.id .. "')", 2)
    end

    item.hunger = item.hunger or 0
    item.hydration = item.hydration or 0
    item.tier = item.tier or "standard"
    item.tags = item.tags or {}
    if Food.TIERS[item.tier] == nil then
        error("Craving.Food.Register: 'tier' desconocido \"" .. tostring(item.tier)
            .. "\" (ítem '" .. item.id .. "')", 2)
    end

    -- set derivado: preguntar por tag no debe ser un recorrido lineal en el tick
    item.tagset = {}
    for _, t in ipairs(item.tags) do item.tagset[t] = true end

    local previo = Config.ITEMS_BY_ID[item.id]
    if previo ~= nil then
        -- esperable en lua refresh: se reemplaza en sitio para no duplicar la
        -- entrada en la lista (y que #Config.ITEMS siga siendo la cuenta real)
        for i, v in ipairs(Config.ITEMS) do
            if v.id == item.id then Config.ITEMS[i] = item break end
        end
    else
        Config.ITEMS[#Config.ITEMS + 1] = item
    end
    Config.ITEMS_BY_ID[item.id] = item
    return item
end

--- Ítem por id, o nil.
function Food.Get(id)
    return Config.ITEMS_BY_ID[id]
end

--- La lista viva (by-ref, no una copia: es la misma que consume items.lua).
function Food.All()
    return Config.ITEMS
end

--- ¿Lleva ese tag? Lee el set derivado, no la lista.
function Food.HasTag(item, tag)
    return istable(item) and istable(item.tagset) and item.tagset[tag] == true
end

--- Los que llevan un tag. Copia nueva: el caller puede filtrarla sin romper nada.
function Food.ByTag(tag)
    local out = {}
    for _, item in ipairs(Config.ITEMS) do
        if Food.HasTag(item, tag) then out[#out + 1] = item end
    end
    return out
end

--- Stat que manda para este ítem ("hunger"|"hydration"). Sale del kind, no de
--- comparar los números — es lo que el anti-desperdicio de §5 consulta.
function Food.StatOf(item)
    return istable(item) and Food.KINDS[item.kind] or "hunger"
end

--- Ruta de modelo del ítem: RUTA DIRECTA si la declara, si no la resolución por
--- candidatos de §6. Vive acá y no en cada consumidor porque son TRES los que
--- necesitan la regla (las defs de Cargo, la entity de mundo y el selftest), y
--- con la regla escrita tres veces alcanza con que una se olvide de `model`
--- para que ese ítem salga como la cajita de cartón sin que nada falle.
---
--- Directa para los modelos PROPIOS del repo (que están garantizados, igual que
--- los de Coagulant); por candidatos para los que dependen de un addon de
--- contenido montado (los ZONA), donde el último es siempre HL2 vanilla.
function Food.ModelOf(item)
    if not istable(item) then return "models/props_junk/cardboard_box004a.mdl" end
    if isstring(item.model) and item.model ~= "" then return item.model end
    return CRAVING.Assets.Model(item.models)
end

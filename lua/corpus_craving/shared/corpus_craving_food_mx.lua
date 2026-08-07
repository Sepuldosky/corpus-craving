-- corpus_craving_food_mx.lua — set de comida envasada, modelos propios (SHARED)
-- Craving_Architecture.md §5. Nueve altas por CRAVING.Food.Register: mismo
-- registro que las seis de config.lua, ninguna vía nueva.
--
-- LOS MODELOS SON DE ESTE REPO, y por eso declaran `model` (ruta directa) y no
-- `models` (lista de candidatos). La lista con fallback a HL2 existe para los
-- assets que dependen de un addon de contenido montado — los ZONA, CRV-7. Estos
-- viven en models/corpus_craving/, están garantizados, y el mismo argumento que
-- Coagulant usó el 2026-08-05 vale acá: declarar un modelo propio no le saca a
-- un addon de contenido la posibilidad de re-vestirlos, porque
-- `Cargo.Items.SetModel` pisa el modelo declarado y se re-aplica en cada
-- registro. Lo que cambia es solo qué se ve cuando NADIE sustituye.
--
-- ORIGEN Y CRÉDITO. Portados del addon "Props Mexicanos" (Workshop 3178402491)
-- de **gbonn**, que en la descripción del addon autoriza explícitamente el uso
-- de sus props pidiendo aviso y crédito. La atribución es obligación asumida y
-- vive en docs/CREDITOS.md. Se recompilaron a escala real (los originales están
-- a 2-3x) y con `$cdmaterials` propio; el pipeline es reproducible con
-- `python dev/phastools/mxfood_build.py build`.
--
-- LOS NOMBRES SON GENÉRICOS Y LA MARCA VIVE EN LA TRIVIA (decisión del autor,
-- 2026-08-06). Craving es un módulo genérico: "Sliced bread" es lo que el ítem
-- ES, y que la bolsa diga Bimbo es color, no taxonomía. La trivia es donde el
-- ecosistema ya pone el color.

local CRAVING = Corpus.GetModule("craving")
local Food = CRAVING.Food

local M = "models/corpus_craving/"

-- ============================================================
-- Comida
-- ============================================================

Food.Register({
    id = "corpus_craving_sliced_bread", name = "Sliced bread", kind = "food",
    hunger = 55, hydration = 0, weight = 0.68, sound = "eat",
    tier = "standard", tags = { "packaged", "bread" },
    model = M .. "sliced_bread.mdl",
    trivia = "A full bag of sliced white bread. Heavy for what it is, but it lasts.",
})

Food.Register({
    id = "corpus_craving_sweet_bun", name = "Sweet bun", kind = "food",
    hunger = 20, hydration = 0, weight = 0.07, sound = "eat",
    tier = "standard", tags = { "fresh", "bread" },
    model = M .. "sweet_bun.mdl",
    trivia = "A concha, still soft. The sugar shell cracks apart when you bite it.",
})

Food.Register({
    id = "corpus_craving_instant_noodles", name = "Instant noodles", kind = "food",
    hunger = 25, hydration = 5, weight = 0.07, sound = "eat",
    tier = "junk", tags = { "packaged", "noodles" },
    model = M .. "instant_noodles.mdl",
    trivia = "Shrimp flavour, eaten dry. There is a line on the cup for hot water you do not have.",
})

-- ============================================================
-- Bebida
-- ============================================================

Food.Register({
    id = "corpus_craving_milk_carton", name = "Milk carton", kind = "drink",
    hunger = 15, hydration = 45, weight = 1.03, sound = "drink",
    tier = "standard", tags = { "packaged", "dairy" },
    model = M .. "milk_carton.mdl",
    trivia = "A litre of fortified milk. Warm, and it will not stay good for long.",
})

Food.Register({
    -- el .mdl trae DOS skins (la etiqueta roja y una amarilla). Cargo no
    -- transporta un campo de skin, así que la def usa la 0; la otra queda ahí
    -- para el día que haga falta una variante.
    id = "corpus_craving_cola_bottle", name = "Cola bottle", kind = "drink",
    hunger = 10, hydration = 50, weight = 2.60, sound = "can",
    tier = "junk", tags = { "packaged", "soda", "sugary", "caffeine" },
    model = M .. "cola_bottle.mdl",
    trivia = "Two and a half litres of cola. You will feel every gram of it on your back.",
})

Food.Register({
    id = "corpus_craving_cola_glass", name = "Glass cola bottle", kind = "drink",
    hunger = 5, hydration = 25, weight = 0.60, sound = "can",
    tier = "junk", tags = { "bottled", "soda", "sugary", "caffeine" },
    model = M .. "cola_glass.mdl",
    trivia = "Cola in glass. Everyone insists it tastes better this way, and everyone is right.",
})

-- ============================================================
-- Alcohol — entran como bebidas mediocres, sin efectos (decisión del autor,
-- 2026-08-06; §14.2 sigue siendo bloque futuro). El tag `alcohol` es el gancho.
-- ============================================================

Food.Register({
    id = "corpus_craving_beer_can", name = "Canned beer", kind = "drink",
    hunger = 0, hydration = 10, weight = 0.37, sound = "can",
    tier = "junk", tags = { "alcohol", "canned" },
    model = M .. "beer_can.mdl",
    trivia = "Lager, room temperature. Wets the mouth and little else.",
})

Food.Register({
    id = "corpus_craving_beer_bottle", name = "Beer bottle", kind = "drink",
    hunger = 0, hydration = 10, weight = 0.60, sound = "drink",
    tier = "standard", tags = { "alcohol", "bottled" },
    model = M .. "beer_bottle.mdl",
    trivia = "A clear bottle of pale lager. Someone drank the lime that came with it.",
})

Food.Register({
    id = "corpus_craving_beer_bottle_big", name = "Large beer bottle", kind = "drink",
    hunger = 0, hydration = 15, weight = 1.20, sound = "drink",
    tier = "junk", tags = { "alcohol", "bottled" },
    model = M .. "beer_bottle_big.mdl",
    trivia = "Nine hundred and forty millilitres. Meant to be shared. It will not be.",
})

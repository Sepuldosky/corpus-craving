-- corpus_craving_config.lua — convars + tablas de balance + funciones puras (SHARED)
-- Craving_Architecture.md §2-§3, §5, §11. Los números viven acá como data: se
-- tunean editando este archivo o por convar, sin tocar lógica. Todo lo de este
-- archivo es puro (sin hooks, sin estado de jugador), salvo los getters client
-- del contrato público (leen NW2, el espejo replicado del estado server).

local CRAVING = Corpus.GetModule("craving")

CRAVING.Config = CRAVING.Config or {}
local Config = CRAVING.Config

-- ============================================================
-- Convars (§11). Replicadas para que el cliente (tab Q, barras) lea los mismos
-- valores sin net propio.
-- ============================================================
local FLAGS = { FCVAR_ARCHIVE, FCVAR_REPLICATED }
Config.cv_enabled        = CreateConVar("craving_enabled", "1", FLAGS, "Enables/disables the whole Craving system")
Config.cv_decay_scale    = CreateConVar("craving_decay_scale", "1.0", FLAGS, "Global hunger/thirst decay multiplier (0 freezes both stats)")
Config.cv_damage_scale   = CreateConVar("craving_damage_scale", "1.0", FLAGS, "HP damage multiplier while starving/dehydrated (no Coagulant)")
Config.cv_stomach_sounds = CreateConVar("craving_stomach_sounds", "1", FLAGS, "Growling stomach audible to nearby players below the severe threshold")

if CLIENT then
    -- USERINFO: el server la lee con ply:GetInfoNum al decidir si manda hints
    CreateClientConVar("craving_hints", "1", true, true, "Show hunger/thirst threshold hints", 0, 1)
end

function Config.Enabled()
    return Config.cv_enabled:GetBool()
end

-- ============================================================
-- Balance (§2-§3) — ratificado como tunable (2026-07-13)
-- ============================================================
Config.STAT_MAX  = 100
Config.TICK      = 5      -- segundos entre ticks del timer server (nunca per-frame)
Config.RESPAWN   = 75     -- valor de ambos stats al respawnear (≠ reconexión, §12)

-- Decay base por tick (unidades/tick de 5 s): hambre 100→0 en ≈2.5 h de juego
-- normal; la sed corre ~1.5× más rápido (≈1.7 h). §2.
Config.DECAY_BASE = { hunger = 0.055, hydration = 0.083 }

-- Multiplicador por sprint efectivo (sprint sostenido + moviéndose de verdad):
-- correr da sed mucho antes que hambre. §2.
Config.SPRINT_MULT = { hunger = 1.25, hydration = 1.75 }
Config.SPRINT_MIN_SPEED = 150 -- ups en 2D: por debajo, apretar shift no cuenta

-- Sobrepeso (Cargo presente): lerp 1.0 → OVERWEIGHT_MAX entre fracción de peso
-- OVERWEIGHT_FROM y 1.0, aplicado a ambos stats. §2.
Config.OVERWEIGHT_FROM = 0.5
Config.OVERWEIGHT_MAX  = 1.5

-- Umbrales (§3): warn avisa una vez por cruce; severe arranca la severity que
-- se reporta a Coagulant y el estómago audible.
Config.WARN_AT   = 50
Config.SEVERE_AT = 25

-- Daño del fallback sin Coagulant, en HP por tick de 5 s (§3): la sed mata al
-- doble de velocidad que el hambre (1 HP/5 s vs 1 HP/10 s). Se acumula en
-- fracciones y se aplica la parte entera.
Config.DMG_PER_TICK = { hunger = 0.5, hydration = 1.0 }

-- Estómago audible (§3): intervalo aleatorio entre emisiones bajo el umbral severo
Config.STOMACH_MIN_S, Config.STOMACH_MAX_S = 60, 90

-- Anti-desperdicio (§5): con el stat relevante a tope, onUse devuelve false y
-- Cargo NO consume la unidad
Config.FULL_AT = 98

-- ============================================================
-- Consumibles v1 (§5-§6). Tabla única consumida por items.lua (defs contra
-- Cargo) y por la entity de mundo. Modelos: lista de candidatos — el primero
-- montado gana (addon "Corpus S.T.A.L.K.E.R." → CS:S → HL2 garantizado); los
-- candidatos CS:S se validan en juego, el último es siempre HL2 vanilla.
-- Sonido: "eat" | "drink" | "can" | "vodka" (ver Assets.ConsumeSound). Strings
-- de cara al jugador (name, trivia) en inglés — idioma del mod.
-- ============================================================
Config.ITEMS = {
    {
        id = "corpus_craving_bread", name = "Bread",
        hunger = 30, hydration = 0, weight = 0.30, sound = "eat",
        models = {
            "models/stalker/item/food/bread.mdl",
            "models/props/cs_italy/bread_slice.mdl",
            "models/props_junk/garbage_takeoutcarton001a.mdl",
        },
        trivia = "Half a loaf. Stale, but it keeps you walking.",
    },
    {
        id = "corpus_craving_sausage", name = "Sausage",
        hunger = 50, hydration = 0, weight = 0.45, sound = "eat",
        models = {
            "models/stalker/item/food/sausage.mdl",
            "models/props/cs_italy/it_mkt_sausage.mdl",
            "models/props_junk/garbage_takeoutcarton001a.mdl",
        },
        trivia = "Smoked sausage. The best meal you will find out here.",
    },
    {
        id = "corpus_craving_tuna", name = "Canned tuna",
        hunger = 35, hydration = 5, weight = 0.25, sound = "eat",
        models = {
            "models/stalker/item/food/tuna.mdl",
            "models/props_junk/garbage_metalcan001a.mdl",
        },
        trivia = "No opener needed. Do not ask how old it is.",
    },
    {
        -- el drink.mdl ZONA es una bebida energética (ronda 2 en juego) — acá
        -- va botella: plástica HL2 si el mapa la trae, vidrio garantizado
        id = "corpus_craving_water", name = "Water bottle",
        hunger = 0, hydration = 60, weight = 0.60, sound = "drink",
        models = {
            "models/props_junk/garbage_plasticbottle003a.mdl",
            "models/props_junk/glassbottle01a.mdl",
        },
        trivia = "Clean drinking water. Worth more than it looks.",
    },
    {
        id = "corpus_craving_softdrink", name = "Soft drink",
        hunger = 5, hydration = 30, weight = 0.33, sound = "can",
        models = {
            "models/stalker/item/food/drink.mdl",
            "models/props_junk/PopCan01a.mdl",
        },
        trivia = "Warm, flat and full of sugar.",
    },
    {
        id = "corpus_craving_vodka", name = "Vodka",
        hunger = 0, hydration = 5, weight = 0.50, sound = "vodka",
        models = {
            "models/stalker/item/food/vokda.mdl", -- (sic — el typo es del pack ZONA)
            "models/props_junk/glassbottle01a.mdl",
        },
        trivia = "Barely counts as a drink. Effects? Some day.",
    },
}

-- Índice por id (derivado, para lookups de onUse y de la entity)
Config.ITEMS_BY_ID = {}
for _, item in ipairs(Config.ITEMS) do
    Config.ITEMS_BY_ID[item.id] = item
end

-- ============================================================
-- Funciones puras
-- ============================================================

-- Multiplicador de sobrepeso dada la fracción peso/capacidad de Cargo (§2).
-- Puro: la lectura de la fracción (lazy-check de Cargo) es del caller.
function Config.OverweightMult(frac)
    if not isnumber(frac) or frac <= Config.OVERWEIGHT_FROM then return 1 end
    local t = math.min((frac - Config.OVERWEIGHT_FROM) / (1 - Config.OVERWEIGHT_FROM), 1)
    return 1 + (Config.OVERWEIGHT_MAX - 1) * t
end

-- Drenaje de un stat en este tick (§2): base × actividad × sobrepeso × convar.
-- stat: "hunger" | "hydration"; sprinting: bool; weightFrac: number | nil.
function Config.DrainPerTick(stat, sprinting, weightFrac)
    local drain = Config.DECAY_BASE[stat]
    if drain == nil then return 0 end
    if sprinting then drain = drain * Config.SPRINT_MULT[stat] end
    return drain * Config.OverweightMult(weightFrac) * math.max(Config.cv_decay_scale:GetFloat(), 0)
end

-- Severity 0..1 que se reporta a Coagulant (§4): rampea de 0 (stat en el umbral
-- severo) a 1 (stat en 0); 0 limpia la condición.
function Config.Severity(value)
    if value >= Config.SEVERE_AT then return 0 end
    return math.Clamp((Config.SEVERE_AT - value) / Config.SEVERE_AT, 0, 1)
end

-- ============================================================
-- Getters client del contrato público (§8): leen el espejo NW2 que publica el
-- server (§9). Los getters server (fuente de verdad: la tabla de estado) los
-- define server/corpus_craving_core.lua.
-- ============================================================
if CLIENT then
    function CRAVING.GetHunger(ply)
        return ply:GetNW2Float("craving_hunger", Config.STAT_MAX)
    end

    function CRAVING.GetHydration(ply)
        return ply:GetNW2Float("craving_hydration", Config.STAT_MAX)
    end
end

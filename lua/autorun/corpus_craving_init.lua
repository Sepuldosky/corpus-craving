-- corpus_craving_init.lua — punto de entrada y manifest de carga de Craving (SHARED)
-- Único archivo en lua/autorun/: registra el módulo y carga el resto vía include()
-- en orden explícito. Boot pattern tomado de corpus_caliber_init.lua (el template
-- del ecosistema): AddCSLuaFile corre siempre en autorun; el boot se difiere a
-- "Initialize" porque gmod fusiona lua/autorun/ alfabéticamente entre addons y
-- "corpus_craving_init.lua" ordena ANTES que "corpus_registry.lua".
--
-- BLOCK 4 (medio-bloque Craving) EN BAJADA: v1 completo según
-- Craving_Architecture.md — decay, umbrales, puente Coagulant, consumibles
-- contra Cargo, entity de mundo, barras, tab Q.

-- ============================================================
-- CONTRATO PÚBLICO DE CRAVING (Craving_Architecture.md §8). Consumido por otros
-- módulos vía Corpus.GetModule("craving"). Todo lo demás colgado de la tabla es
-- interno — off-contract por convención.
--
--   CRAVING.GetHunger(ply) -> 0..100     -- shared (server: estado; client: NW2)
--   CRAVING.GetHydration(ply) -> 0..100  -- ídem
--   CRAVING.Restore(ply, hunger, hyd)    -- SERVER; suma con clamp [0,100] — la
--                                           vía legítima para que otros
--                                           mods/ítems alimenten al jugador
--
--   Eventos (hook.Run, server): Craving_StatCritical(ply, stat, isCritical)
--   al cruzar el umbral severo (25), ambas direcciones — §8 de la arquitectura.
-- ============================================================

-- ============================================================
-- Manifest de carga: orden explícito y determinista, nunca el alfabético implícito
-- de autorun. Los sub-archivos viven en lua/corpus_craving/<realm>/ (fuera de
-- lua/autorun/) para que ESTE init sea el único punto de carga. La entity
-- (lua/entities/corpus_craving_food.lua) la carga el sistema de scripted_ents,
-- no este manifest, y resuelve el módulo en runtime. Regla: nunca invocar hacia
-- adelante en file-scope — los cruces van en hooks con guardas.
-- ============================================================
local SHARED = {
    "shared/corpus_craving_config.lua", -- convars + tablas de balance + funcs puras + getters client
    "shared/corpus_craving_assets.lua", -- resolución de modelo/sonido por candidatos (§6)
    "shared/corpus_craving_items.lua",  -- consumibles contra Cargo (soft-dep, §5) — AMBOS realms: el grid del cliente renderiza defs locales, el snapshot solo trae autogen
    "shared/corpus_craving_dev.lua",    -- craving_selftest + comandos de verificación
}
local SERVER_FILES = {
    "server/corpus_craving_coagulant.lua", -- puente mock-first a Coagulant (§4) — antes que core: core lo consume en su tick
    "server/corpus_craving_core.lua",      -- estado, tick de decay, umbrales, daño fallback, persistencia, NW2
}
local CLIENT_FILES = {
    "client/corpus_craving_bars.lua",    -- barras del StatusPanel de Cargo (soft-dep, §10)
    "client/corpus_craving_options.lua", -- tab único Corpus.UI.RegisterTab
}

local function inc(rel) include("corpus_craving/" .. rel) end
local function cs(rel)  AddCSLuaFile("corpus_craving/" .. rel) end

-- AddCSLuaFile no depende de Corpus: se hace siempre en la carga de autorun, para
-- que el cliente reciba los archivos aunque el boot quede diferido (ver abajo).
if SERVER then
    for _, f in ipairs(SHARED)       do cs(f) end
    for _, f in ipairs(CLIENT_FILES) do cs(f) end
end

-- Hard-dep: Craving depende de Corpus (única dep dura del ecosistema,
-- CORPUS_Architecture.md §2/§6). No se asume que ya cargó; se detecta. La sonda
-- cubre las primitivas que los sub-archivos usan en file-scope.
local function CorpusListo()
    return Corpus ~= nil and Corpus.RegisterModule ~= nil and Corpus.Log ~= nil
        and Corpus.OnReady ~= nil and Corpus.Data ~= nil and (SERVER or Corpus.UI ~= nil)
end

-- Namespace: tabla única registrada. Todos los archivos del módulo cachean esta
-- misma referencia por side-effect (local CRAVING = Corpus.GetModule("craving")).
-- Depende del invariante by-ref del registro (CORPUS_Architecture.md §3).
local function Boot()
    Corpus.RegisterModule("craving", {})

    if SERVER then
        for _, f in ipairs(SHARED)       do inc(f) end
        for _, f in ipairs(SERVER_FILES) do inc(f) end
    else
        for _, f in ipairs(SHARED)       do inc(f) end
        for _, f in ipairs(CLIENT_FILES) do inc(f) end
    end

    Corpus.Log("craving", "cargado (" .. (SERVER and "server" or "client") .. ") — Block 4 v1")
end

if CorpusListo() then
    -- lua refresh o montaje tardío: el framework ya está — boot inmediato
    Boot()
else
    -- Carga de mapa normal: diferir a "Initialize" (corre en ambos realms después
    -- de TODO autorun y antes de InitPostEntity), manteniendo las garantías: los
    -- tabs de UI llegan antes de PopulateToolMenu y los hooks registrados en Boot
    -- corren antes de la ready barrier.
    hook.Add("Initialize", "corpus_craving_boot", function()
        hook.Remove("Initialize", "corpus_craving_boot")
        if CorpusListo() then
            Boot()
        else
            -- Sin el framework, el módulo no arranca (falla ruidoso, no silencioso).
            -- No se usa Corpus.Log aquí: Corpus no existe.
            MsgN("[Craving] Corpus framework no encontrado. Verificar que el addon corpus/ esté instalado y montado.")
        end
    end)
end

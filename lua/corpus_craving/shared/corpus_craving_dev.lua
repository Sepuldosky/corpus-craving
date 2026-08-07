-- corpus_craving_dev.lua — auto-test de consola + comandos de verificación (SHARED)
-- Mismo patrón que corpus_selftest / cargo_selftest / coagulant_selftest: checks
-- deterministas de la superficie pura, en el realm donde se invoca. En listen
-- server, realm server:
--   lua_run Corpus.GetModule("craving")._SelfTest()
-- No reemplaza la verificación en juego (flujo §1 PASO 4): la complementa.
-- Comandos de verificación (admin): craving_status, craving_set <hunger> <hyd>.

local CRAVING = Corpus.GetModule("craving")

function CRAVING._SelfTest()
    local Config = CRAVING.Config
    local pasan, fallan = 0, 0
    local function check(cond, msg)
        if cond then
            pasan = pasan + 1
        else
            fallan = fallan + 1
            Corpus.Log("craving", "SELFTEST FALLO: " .. msg)
        end
    end
    local function casi(a, b) return math.abs(a - b) < 0.0001 end

    -- Registro: invariante by-ref del framework
    check(Corpus.GetModule("craving") == CRAVING, "GetModule no devuelve la misma tabla by-ref")
    check(Corpus.HasModule("craving") == true, "HasModule('craving') no es true")

    -- Config pura: sobrepeso (§2)
    check(Config.OverweightMult(nil) == 1, "OverweightMult(nil) no es 1")
    check(Config.OverweightMult(0.3) == 1, "OverweightMult bajo el umbral no es 1")
    check(casi(Config.OverweightMult(0.75), 1.25), "OverweightMult(0.75) no es 1.25")
    check(casi(Config.OverweightMult(1.0), Config.OVERWEIGHT_MAX), "OverweightMult(1.0) no es el máximo")
    check(casi(Config.OverweightMult(2.0), Config.OVERWEIGHT_MAX), "OverweightMult no clampea sobre 1.0")

    -- Config pura: severity hacia Coagulant (§4)
    check(Config.Severity(Config.STAT_MAX) == 0, "Severity con stat lleno no es 0")
    check(Config.Severity(Config.SEVERE_AT) == 0, "Severity en el umbral no es 0")
    check(casi(Config.Severity(0), 1), "Severity con stat 0 no es 1")
    check(casi(Config.Severity(Config.SEVERE_AT / 2), 0.5), "Severity a medio camino no es 0.5")

    -- Config pura: drenaje (§2) — chequeos por RATIO, independientes del valor
    -- actual de craving_decay_scale (si está en 0, se omiten)
    if Config.cv_decay_scale:GetFloat() > 0 then
        local base = Config.DrainPerTick("hunger", false, nil)
        check(base > 0, "DrainPerTick base de hambre no es positivo")
        check(casi(Config.DrainPerTick("hunger", true, nil) / base, Config.SPRINT_MULT.hunger),
            "sprint no multiplica el hambre por SPRINT_MULT")
        check(casi(Config.DrainPerTick("hunger", false, 1.0) / base, Config.OVERWEIGHT_MAX),
            "sobrepeso pleno no multiplica por OVERWEIGHT_MAX")
        check(Config.DrainPerTick("hydration", false, nil) > base,
            "la sed no drena más rápido que el hambre")
    else
        Corpus.Log("craving", "selftest: craving_decay_scale en 0 — checks de drenaje omitidos")
    end
    check(Config.DrainPerTick("noexiste", false, nil) == 0, "stat desconocido drena")

    -- Tabla de ítems (§5): integridad
    local Food = CRAVING.Food
    check(#Config.ITEMS == 15, "ITEMS no tiene 15 consumibles (6 base + 9 envasadas)")
    check(Food.All() == Config.ITEMS, "Food.All no devuelve la lista viva by-ref")

    local propios = 0
    for _, item in ipairs(Config.ITEMS) do
        check(Config.ITEMS_BY_ID[item.id] == item, "ITEMS_BY_ID no indexa " .. tostring(item.id))
        check(Food.Get(item.id) == item, "Food.Get no devuelve el mismo ítem: " .. tostring(item.id))
        check(isstring(item.name) and item.name ~= "", "ítem sin name: " .. tostring(item.id))
        check(isnumber(item.weight) and item.weight > 0, "peso inválido: " .. tostring(item.id))
        check((item.hunger or 0) + (item.hydration or 0) > 0, "ítem que no restaura nada: " .. tostring(item.id))

        -- taxonomía (§5, enmienda 2026-08-06)
        check(Food.KINDS[item.kind] ~= nil, "kind inválido: " .. tostring(item.id))
        check(Food.TIERS[item.tier] ~= nil, "tier inválido: " .. tostring(item.id))
        check(istable(item.tags) and istable(item.tagset), "tags/tagset ausentes: " .. tostring(item.id))
        for _, t in ipairs(item.tags) do
            check(Food.HasTag(item, t), "tagset no refleja el tag '" .. tostring(t) .. "': " .. tostring(item.id))
        end
        -- el stat sale del kind, NO de comparar los números: un ítem mixto que
        -- restaure más hambre que sed puede ser igual una bebida
        check(Food.StatOf(item) == Food.KINDS[item.kind], "StatOf no coincide con el kind: " .. tostring(item.id))

        -- modelo: ruta propia o cadena de candidatos, nunca ninguna de las dos
        check(isstring(item.model) or (istable(item.models) and #item.models >= 2),
            "ítem sin modelo propio ni cadena de candidatos: " .. tostring(item.id))
        check(isstring(Food.ModelOf(item)) and Food.ModelOf(item) ~= "",
            "Food.ModelOf no resuelve: " .. tostring(item.id))
        if isstring(item.model) then
            propios = propios + 1
            -- Un modelo PROPIO no tiene fallback por diseño, así que su ausencia
            -- no degrada: da el error de modelo del engine. Chequear que el
            -- archivo esté es el único check que distingue "instalado" de
            -- "declarado" — mismo hueco que en Coagulant dejó pasar 35
            -- referencias rotas con el lote en verde.
            check(file.Exists(item.model, "GAME"),
                "el .mdl propio declarado NO está en disco: " .. item.model)
        else
            -- la resolución siempre devuelve una ruta (el último candidato es HL2 vanilla)
            check(isstring(CRAVING.Assets.Model(item.models)), "Assets.Model no resuelve: " .. tostring(item.id))
        end
    end
    check(propios == 9, "se esperaban 9 ítems con modelo propio, hay " .. propios)

    -- Filtro por tag: el alcohol es el gancho declarado del §14.2 y hoy son 4
    -- (el vodka base + las tres cervezas envasadas)
    check(#Food.ByTag("alcohol") == 4, "ByTag('alcohol') no devuelve 4")
    check(#Food.ByTag("no_existe_este_tag") == 0, "ByTag inventa resultados con un tag desconocido")

    -- Register es el ÚNICO escritor y mantiene las dos tablas juntas: un alta
    -- nueva tiene que aparecer en la lista Y en el índice, y re-registrar el
    -- mismo id reemplaza en sitio en vez de duplicar (lua refresh)
    local n0 = #Config.ITEMS
    local probe = Food.Register({
        id = "corpus_craving__selftest_probe", name = "Probe", kind = "drink",
        hunger = 0, hydration = 1, weight = 0.01, sound = "drink",
        model = "models/props_junk/glassbottle01a.mdl",
    })
    check(#Config.ITEMS == n0 + 1, "Register no agregó a la lista")
    check(Food.Get("corpus_craving__selftest_probe") == probe, "Register no indexó el alta")
    Food.Register({
        id = "corpus_craving__selftest_probe", name = "Probe 2", kind = "food",
        hunger = 1, hydration = 0, weight = 0.01, sound = "eat",
        model = "models/props_junk/glassbottle01a.mdl",
    })
    check(#Config.ITEMS == n0 + 1, "re-registrar el mismo id duplicó la entrada")
    check(Food.Get("corpus_craving__selftest_probe").name == "Probe 2", "re-registrar no reemplazó la def")
    -- deshacer: el probe no puede quedar vivo en el inventario de nadie
    for i, v in ipairs(Config.ITEMS) do
        if v.id == "corpus_craving__selftest_probe" then table.remove(Config.ITEMS, i) break end
    end
    Config.ITEMS_BY_ID["corpus_craving__selftest_probe"] = nil
    check(#Config.ITEMS == n0 and Food.Get("corpus_craving__selftest_probe") == nil,
        "el probe del selftest quedó registrado")

    -- Assets (§6): lista sin candidatos montados → devuelve el último
    check(CRAVING.Assets.Model({ "models/no/existe.mdl", "models/tampoco.mdl" }) == "models/tampoco.mdl",
        "Assets.Model no cae al último candidato")
    check(CRAVING.Assets.Sound({ "no/existe.wav" }) == nil, "Assets.Sound inventa un sonido")

    -- Contrato público congelado (§8) + round-trip de estado (server)
    if SERVER then
        check(isfunction(CRAVING.GetHunger), "GetHunger no es función")
        check(isfunction(CRAVING.GetHydration), "GetHydration no es función")
        check(isfunction(CRAVING.Restore), "Restore no es función")
        check(isfunction(CRAVING.Consume), "Consume no es función (semántica de onUse)")
        check(isfunction(CRAVING._CoagulantUpdate), "puente Coagulant no cargado")

        local ply = player.GetAll()[1]
        if IsValid(ply) then
            -- preservar el estado real del jugador durante el test
            local h0, hy0 = CRAVING.GetHunger(ply), CRAVING.GetHydration(ply)

            CRAVING._SetStats(ply, 40, 40)
            check(CRAVING.GetHunger(ply) == 40, "SetStats/GetHunger no round-trippea")
            CRAVING.Restore(ply, 30, 10)
            check(CRAVING.GetHunger(ply) == 70, "Restore no suma hambre")
            check(CRAVING.GetHydration(ply) == 50, "Restore no suma hidratación")
            CRAVING.Restore(ply, 1000, 1000)
            check(CRAVING.GetHunger(ply) == Config.STAT_MAX, "Restore no clampea a STAT_MAX")

            -- anti-desperdicio (§5): a tope, Consume devuelve false (no consume)
            check(CRAVING.Consume(ply, "corpus_craving_bread") == false,
                "Consume con la barra llena no devuelve false")
            CRAVING._SetStats(ply, 50, 50)
            check(CRAVING.Consume(ply, "corpus_craving_bread") == true,
                "Consume con hambre no devuelve true")
            check(CRAVING.GetHunger(ply) == 80, "el pan no restauró 30 de hambre")
            check(CRAVING.Consume(ply, "id_inexistente") == false, "Consume de id desconocido no falla")

            CRAVING._SetStats(ply, h0, hy0) -- dejar como estaba
        else
            Corpus.Log("craving", "selftest: sin jugadores — round-trip de estado omitido")
        end
    end

    -- Soft-deps: reporte informativo, nunca un fallo (degradación honesta)
    Corpus.Log("craving", string.format("soft-deps — cargo: %s | coagulant: %s | assets STALKER: %s",
        Corpus.HasModule("cargo") and "presente" or "ausente",
        Corpus.HasModule("coagulant") and "presente" or "ausente",
        CRAVING.Assets.StalkerMounted() and "montados" or "ausentes (fallback HL2/CS:S)"))
    if SERVER and Corpus.HasModule("cargo") then
        local cargo = Corpus.GetModule("cargo")
        local def = cargo.Items.Get and cargo.Items.Get("corpus_craving_bread") or nil
        check(def ~= nil, "Cargo presente pero el pan no está registrado (¿corrió OnReady?)")
    end

    Corpus.Log("craving", string.format("selftest (%s): %d OK, %d fallos",
        SERVER and "server" or "client", pasan, fallan))
    return fallan == 0
end

concommand.Add("craving_selftest", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    CRAVING._SelfTest()
end)

-- ============================================================
-- Comandos de verificación en juego (server, admin)
-- ============================================================
if SERVER then
    -- Vuelca los stats del que lo invoca a la consola
    concommand.Add("craving_status", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then return end
        local objetivo = IsValid(ply) and ply or player.GetAll()[1]
        if not IsValid(objetivo) then return end

        local st = CRAVING.GetState(objetivo)
        Corpus.Log("craving", string.format(
            "%s — hunger %.1f | hydration %.1f | HP %d%s",
            objetivo:Nick(), st.hunger, st.hydration, objetivo:Health(),
            st.coagSev ~= nil and " | delegado a Coagulant" or ""))
    end)

    -- Fuerza los stats (para probar umbrales/muerte sin esperar el decay real)
    concommand.Add("craving_set", function(ply, _, args)
        if IsValid(ply) and not ply:IsAdmin() then return end
        local objetivo = IsValid(ply) and ply or player.GetAll()[1]
        if not IsValid(objetivo) then return end

        local h, hy = tonumber(args[1]), tonumber(args[2])
        if h == nil and hy == nil then
            Corpus.Log("craving", "uso: craving_set <hunger 0-100> [hydration 0-100]")
            return
        end
        CRAVING._SetStats(objetivo, h, hy)
        Corpus.Log("craving", string.format("%s → hunger %.0f, hydration %.0f",
            objetivo:Nick(), CRAVING.GetHunger(objetivo), CRAVING.GetHydration(objetivo)))
    end)
end

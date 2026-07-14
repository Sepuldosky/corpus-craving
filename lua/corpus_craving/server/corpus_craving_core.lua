-- corpus_craving_core.lua — estado, tick de decay, umbrales, daño, persistencia (SERVER)
-- Craving_Architecture.md §2-§3, §9, §12. El server posee los stats; el cliente
-- solo lee el espejo NW2 (§9). Un único timer de baja frecuencia (§2) — nunca
-- per-frame.

local CRAVING = Corpus.GetModule("craving")
local Config = CRAVING.Config

-- ============================================================
-- Estado por jugador (tabla interna, keyed por entidad; se limpia al desconectar)
-- ============================================================
CRAVING._state = CRAVING._state or {}

local function GetState(ply)
    local st = CRAVING._state[ply]
    if st == nil then
        st = {
            hunger = Config.STAT_MAX, hydration = Config.STAT_MAX,
            warned = {}, critical = {},           -- flags de cruce por stat (§3)
            dmgAcc = { hunger = 0, hydration = 0 }, -- daño fraccional acumulado
            stomachNext = 0,                        -- CurTime del próximo rugido
            pub = {},                               -- último valor publicado a NW2
        }
        CRAVING._state[ply] = st
    end
    return st
end
CRAVING.GetState = GetState -- expuesto para dev/selftest (off-contract)

-- Espejo NW2 (§9): se escribe solo si cambió más que el epsilon
local function Publish(ply, st)
    for _, stat in ipairs({ "hunger", "hydration" }) do
        if st.pub[stat] == nil or math.abs(st.pub[stat] - st[stat]) > 0.1 then
            ply:SetNW2Float("craving_" .. stat, st[stat])
            st.pub[stat] = st[stat]
        end
    end
end

-- ============================================================
-- Contrato público (§8) — getters server (fuente de verdad) + Restore
-- ============================================================
function CRAVING.GetHunger(ply)
    return GetState(ply).hunger
end

function CRAVING.GetHydration(ply)
    return GetState(ply).hydration
end

-- Umbrales (§3): hints una vez por cruce (respetando el userinfo craving_hints
-- del cliente) y evento Craving_StatCritical en ambas direcciones del severo.
local HINTS = {
    hunger    = { warn = "You feel hungry.",  severe = "You are starving." },
    hydration = { warn = "You feel thirsty.", severe = "You are dehydrated." },
}

local function Hint(ply, texto)
    if ply:GetInfoNum("craving_hints", 1) == 0 then return end
    ply:PrintMessage(HUD_PRINTCENTER, texto)
end

local function ApplyThresholds(ply, st)
    for stat, textos in pairs(HINTS) do
        local valor = st[stat]

        if valor <= Config.WARN_AT and not st.warned[stat] then
            st.warned[stat] = true
            Hint(ply, textos.warn)
        elseif valor > Config.WARN_AT then
            st.warned[stat] = nil
        end

        if valor <= Config.SEVERE_AT and not st.critical[stat] then
            st.critical[stat] = true
            Hint(ply, textos.severe)
            hook.Run("Craving_StatCritical", ply, stat, true)
        elseif valor > Config.SEVERE_AT and st.critical[stat] then
            st.critical[stat] = nil
            hook.Run("Craving_StatCritical", ply, stat, false)
        end
    end
end

function CRAVING.Restore(ply, hunger, hydration)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local st = GetState(ply)
    st.hunger    = math.Clamp(st.hunger + (tonumber(hunger) or 0), 0, Config.STAT_MAX)
    st.hydration = math.Clamp(st.hydration + (tonumber(hydration) or 0), 0, Config.STAT_MAX)
    ApplyThresholds(ply, st) -- comer/beber limpia flags y (vía tick) severity
    Publish(ply, st)
end

-- Setter interno (dev/selftest y craving_set) — off-contract
function CRAVING._SetStats(ply, hunger, hydration)
    local st = GetState(ply)
    if hunger ~= nil then st.hunger = math.Clamp(hunger, 0, Config.STAT_MAX) end
    if hydration ~= nil then st.hydration = math.Clamp(hydration, 0, Config.STAT_MAX) end
    ApplyThresholds(ply, st)
    Publish(ply, st)
end

-- ============================================================
-- Consumo (§5): semántica del onUse de los ítems y de la entity de mundo.
-- Devuelve true si consumió (Cargo descuenta la unidad solo en ese caso).
-- ============================================================
function CRAVING.Consume(ply, idOrItem)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local item = istable(idOrItem) and idOrItem or Config.ITEMS_BY_ID[idOrItem]
    if item == nil then return false end

    -- anti-desperdicio (§5): manda el stat que el ítem más restaura
    local st = GetState(ply)
    local statRelevante = (item.hunger >= item.hydration) and "hunger" or "hydration"
    if st[statRelevante] >= Config.FULL_AT then
        Hint(ply, statRelevante == "hunger" and "You are not hungry." or "You are not thirsty.")
        return false
    end

    CRAVING.Restore(ply, item.hunger, item.hydration)

    local snd = CRAVING.Assets.ConsumeSound(item.sound)
    if snd ~= nil then ply:EmitSound(snd) end
    return true
end

-- ============================================================
-- Daño del fallback sin Coagulant (§3): acumula fracciones por tick y aplica la
-- parte entera como DMG_GENERIC del mundo. La sed mata al doble de velocidad.
-- ============================================================
local MUERTES = {
    hunger    = " starved to death.",
    hydration = " died of dehydration.",
}

local function ApplyStarvationDamage(ply, st)
    local escala = math.max(Config.cv_damage_scale:GetFloat(), 0)
    if escala <= 0 then return end

    for stat, sufijo in pairs(MUERTES) do
        if st[stat] <= 0 and ply:Alive() then
            st.dmgAcc[stat] = st.dmgAcc[stat] + Config.DMG_PER_TICK[stat] * escala
            local entero = math.floor(st.dmgAcc[stat])
            if entero >= 1 then
                st.dmgAcc[stat] = st.dmgAcc[stat] - entero

                local dmg = DamageInfo()
                dmg:SetDamage(entero)
                dmg:SetDamageType(DMG_GENERIC)
                dmg:SetAttacker(game.GetWorld())
                dmg:SetInflictor(game.GetWorld())
                ply:TakeDamageInfo(dmg)

                -- mensaje de muerte propio (§3); el killfeed nativo queda genérico
                if not ply:Alive() then
                    PrintMessage(HUD_PRINTTALK, ply:Nick() .. sufijo)
                end
            end
        else
            st.dmgAcc[stat] = 0
        end
    end
end

-- Estómago audible (§3): feedback (y delator, stealth) bajo el umbral severo de
-- hambre. Solo con el addon de assets (sin fallback digno en HL2, §6).
local function StomachGrowl(ply, st)
    if not Config.cv_stomach_sounds:GetBool() then return end
    if st.hunger > Config.SEVERE_AT then return end
    if CurTime() < st.stomachNext then return end

    st.stomachNext = CurTime() + math.Rand(Config.STOMACH_MIN_S, Config.STOMACH_MAX_S)
    local snd = CRAVING.Assets.Sound(CRAVING.Assets.STOMACH)
    if snd ~= nil then ply:EmitSound(snd) end
end

-- ============================================================
-- El tick (§2): un solo timer server de baja frecuencia para todos los jugadores
-- ============================================================
timer.Create("corpus_craving_tick", Config.TICK, 0, function()
    if not Config.Enabled() then return end
    -- decay_scale 0 = sistema en pausa (decisión F): ni decay ni daño; los
    -- umbrales/puente siguen coherentes con los valores congelados
    local congelado = Config.cv_decay_scale:GetFloat() <= 0

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            local st = GetState(ply)

            if not congelado then
                -- sprint efectivo: tecla + moviéndose de verdad (§2)
                local sprint = ply:IsSprinting()
                    and ply:GetVelocity():Length2DSqr() > Config.SPRINT_MIN_SPEED ^ 2

                -- sobrepeso: soft-dep Cargo, lazy-check + pcall (§2)
                local frac = nil
                local cargo = Corpus.GetModule("cargo")
                if cargo ~= nil and cargo.Inventory ~= nil
                    and isfunction(cargo.Inventory.GetWeightFraction) then
                    local ok, valor = pcall(cargo.Inventory.GetWeightFraction, ply)
                    if ok then frac = valor end
                end

                st.hunger    = math.Clamp(st.hunger - Config.DrainPerTick("hunger", sprint, frac), 0, Config.STAT_MAX)
                st.hydration = math.Clamp(st.hydration - Config.DrainPerTick("hydration", sprint, frac), 0, Config.STAT_MAX)
            end

            ApplyThresholds(ply, st)

            -- delegación clínica (§4): si Coagulant es capaz, el daño es suyo
            local delegado = CRAVING._CoagulantUpdate(ply, st)
            if not congelado and not delegado then
                ApplyStarvationDamage(ply, st)
            end

            StomachGrowl(ply, st)
            Publish(ply, st)
        end
    end
end)

-- ============================================================
-- Persistencia (§12) y ciclo de vida. Reconexión ≠ respawn: reconectar restaura
-- lo persistido (cierra el exploit de reconectar para comer gratis); morir
-- resetea a RESPAWN.
-- ============================================================
local function DataKey(ply)
    local sid = ply:SteamID64()
    if sid == nil then return nil end -- bots sin SteamID64: sin persistencia
    return "state_" .. sid
end

local function SavePly(ply)
    local st = CRAVING._state[ply]
    local key = st ~= nil and DataKey(ply) or nil
    if key == nil then return end
    Corpus.Data.Save("craving", key, { hunger = st.hunger, hydration = st.hydration })
end

hook.Add("PlayerInitialSpawn", "corpus_craving_load", function(ply)
    local st = GetState(ply)
    local key = DataKey(ply)
    local data = key ~= nil and Corpus.Data.Load("craving", key) or nil
    if istable(data) then
        st.hunger    = math.Clamp(tonumber(data.hunger) or Config.STAT_MAX, 0, Config.STAT_MAX)
        st.hydration = math.Clamp(tonumber(data.hydration) or Config.STAT_MAX, 0, Config.STAT_MAX)
    end
    -- el PlayerSpawn del primer spawn no debe pisar lo recién cargado
    st.skipRespawnReset = true
    Publish(ply, st)
end)

hook.Add("PlayerSpawn", "corpus_craving_respawn", function(ply)
    local st = GetState(ply)
    if st.skipRespawnReset then
        st.skipRespawnReset = nil
    else
        st.hunger, st.hydration = Config.RESPAWN, Config.RESPAWN
        st.warned, st.critical = {}, {}
        st.dmgAcc = { hunger = 0, hydration = 0 }
        CRAVING._CoagulantClear(ply, st)
    end
    Publish(ply, st)
end)

hook.Add("PlayerDisconnected", "corpus_craving_save", function(ply)
    SavePly(ply)
    local st = CRAVING._state[ply]
    if st ~= nil then CRAVING._CoagulantClear(ply, st) end
    CRAVING._state[ply] = nil
end)

hook.Add("ShutDown", "corpus_craving_save_all", function()
    for _, ply in ipairs(player.GetAll()) do
        SavePly(ply)
    end
end)

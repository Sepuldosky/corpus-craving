-- corpus_craving_coagulant.lua — puente mock-first a Coagulant (SERVER)
-- Craving_Architecture.md §4. Coagulant es el dueño clínico del jugador: cuando
-- está presente Y es capaz, la inanición/deshidratación se delega como condición
-- externa y Craving NO toca HP (un solo dueño de la muerte a la vez). La firma
-- ApplyExternalCondition es contrato ESPERADO (mock-first, flujo §3): el borrador
-- ratificado del Block 3 de Coagulant todavía no la expone — la degradación es
-- por CAPACIDAD (isfunction), no por presencia, así que un Coagulant sin la
-- función cae al mismo fallback que su ausencia. Nunca crash, nunca asunción.

local CRAVING = Corpus.GetModule("craving")
local Config = CRAVING.Config

-- stat propio → id de condición del contrato §4
local CONDICIONES = { hunger = "starvation", hydration = "dehydration" }

-- Corre en cada tick del core. Devuelve true si la delegación clínica quedó
-- activa este tick (el core entonces omite su daño de HP). Publica la severity
-- on-change (redondeada a 2 decimales), nunca por tick — sin spam (§4).
function CRAVING._CoagulantUpdate(ply, st)
    local coag = Corpus.GetModule("coagulant")
    if coag == nil or not isfunction(coag.ApplyExternalCondition) then
        -- si veníamos delegando y el peer se fue (lua refresh, desmonte), se
        -- olvida lo publicado: si vuelve, se re-publica desde cero
        st.coagSev = nil
        return false
    end

    st.coagSev = st.coagSev or {}
    for stat, condicion in pairs(CONDICIONES) do
        local sev = math.Round(Config.Severity(st[stat]), 2)
        if st.coagSev[stat] ~= sev then
            -- pcall: un error del peer no tumba el tick de Craving; este tick
            -- cae al fallback y se reintenta al siguiente
            local ok, err = pcall(coag.ApplyExternalCondition, ply, condicion, sev)
            if not ok then
                Corpus.Log("craving", "puente Coagulant falló (" .. condicion .. "): " .. tostring(err))
                st.coagSev = nil
                return false
            end
            st.coagSev[stat] = sev
        end
    end
    return true
end

-- Limpieza explícita (muerte/desconexión): publica severity 0 en ambas
-- condiciones para no dejar un estado clínico colgado en Coagulant.
function CRAVING._CoagulantClear(ply, st)
    if st.coagSev == nil then return end
    local coag = Corpus.GetModule("coagulant")
    if coag ~= nil and isfunction(coag.ApplyExternalCondition) then
        for _, condicion in pairs(CONDICIONES) do
            pcall(coag.ApplyExternalCondition, ply, condicion, 0)
        end
    end
    st.coagSev = nil
end

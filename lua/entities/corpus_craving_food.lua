-- corpus_craving_food.lua — comida/bebida en mundo (SHARED single-file)
-- Craving_Architecture.md §7: la vía sin inventario. Una sola clase; el def
-- concreto viaja en el keyvalue "craving_item". Con Cargo montado, E la lleva
-- al inventario (misma experiencia que los drops de Cargo); sin Cargo, E la
-- consume in situ — la promesa "fallback a comestibles en mundo" de la tabla §2
-- de la arquitectura de Corpus, hecha entity.
--
-- Este archivo lo carga scripted_ents (no el manifest del init) y puede correr
-- ANTES del boot del módulo: Corpus/el módulo se resuelven SIEMPRE en runtime,
-- jamás en file-scope (regla del ecosistema, patrón corpus_cargo_item).

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "Craving Food"
ENT.Author    = "Corpus"
ENT.Category  = "Corpus"
ENT.Spawnable = false -- las entradas del spawnmenu se registran abajo, una por def

-- Entradas del menú Entities → Corpus: una por consumible, misma clase, el def
-- id viaja como KeyValue (lo aplica el spawn de sandbox; ENT:KeyValue lo captura).
-- Los nombres se duplican acá a propósito: este archivo puede cargar antes que
-- el módulo y las listas del spawnmenu se leen en file-scope — presentación
-- solamente, la verdad del def sigue en Config.ITEMS (validado por el selftest).
local SPAWNABLES = {
    { id = "corpus_craving_bread",     label = "Bread" },
    { id = "corpus_craving_sausage",   label = "Sausage" },
    { id = "corpus_craving_tuna",      label = "Canned tuna" },
    { id = "corpus_craving_water",     label = "Water bottle" },
    { id = "corpus_craving_softdrink", label = "Soft drink" },
    { id = "corpus_craving_vodka",     label = "Vodka" },
}
for _, spawnable in ipairs(SPAWNABLES) do
    list.Set("SpawnableEntities", spawnable.id, {
        PrintName = spawnable.label,
        ClassName = "corpus_craving_food",
        Category  = "Corpus",
        KeyValues = { craving_item = spawnable.id },
    })
end

local function Modulo()
    return Corpus and Corpus.GetModule and Corpus.GetModule("craving") or nil
end

function ENT:KeyValue(key, value)
    if key == "craving_item" then
        self.CravingItem = value
    end
end

-- def de la tabla ratificada, con fallback al primer ítem si el keyvalue no
-- llegó (spawn por herramienta ajena, KeyValues sin soporte — ver CHANGELOG)
local function ItemDef(self)
    local craving = Modulo()
    if craving == nil then return nil end
    return craving.Config.ITEMS_BY_ID[self.CravingItem or ""] or craving.Config.ITEMS[1]
end

if SERVER then

    function ENT:Initialize()
        local craving = Modulo()
        local item = ItemDef(self)

        local model = "models/props_junk/cardboard_box004a.mdl"
        if craving ~= nil and item ~= nil then
            model = craving.Assets.Model(item.models)
            self:SetNWString("craving_label", item.name)
        end

        self:SetModel(model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end

        -- Toma deliberada = WALK+USE, la convención de mundo del ecosistema
        -- (ronda 3): el gate de Cargo (corpus_cargo_capture.lua, "world gate")
        -- solo cubre sus propias clases y se hace a un lado acá — esta entity
        -- se gatea sola. USE pelado = carry de prop HL2; re-USE mientras se
        -- carga SUELTA (el engine libera antes de que este Use corra y sin la
        -- marca la re-agarraríamos al instante — mismo remedio que Cargo).
        if not activator:KeyDown(IN_WALK) then
            if activator.CravingCarryEnt == self then
                activator.CravingCarryEnt = nil
                if self:IsPlayerHolding() and isfunction(activator.DropObject) then
                    activator:DropObject()
                end
                return
            end
            activator.CravingCarryEnt = self
            activator:PickupObject(self)
            return
        end
        activator.CravingCarryEnt = nil

        local craving = Modulo()
        local item = ItemDef(self)
        if craving == nil or item == nil then return end

        local cargo = Corpus.GetModule("cargo")
        if cargo ~= nil and cargo.Inventory ~= nil
            and isfunction(cargo.Inventory.GiveItem) then
            -- con Cargo: al inventario (comerla después es el onUse del ítem)
            local ok, err = cargo.Inventory.GiveItem(activator, item.id, 1)
            if not ok then
                activator:PrintMessage(HUD_PRINTCENTER, err or "You can't carry that.")
                return
            end
            -- feedback estándar de pickup de Cargo, si esta versión lo expone
            if isfunction(cargo.Inventory.Touch) then pcall(cargo.Inventory.Touch, activator) end
            if isfunction(cargo.Inventory.NotifyPickup) then
                pcall(cargo.Inventory.NotifyPickup, activator, item.id, 1)
            end
            self:Remove()
            return
        end

        -- sin Cargo: consumo in situ (false = barra llena; el ítem queda en el mundo)
        if craving.Consume(activator, item) then
            self:Remove()
        end
    end

else

    -- etiqueta 3D2D flotante (patrón corpus_cargo_item) para encontrar la comida
    -- sin un HUD propio — Craving no tiene HUD por decisión E
    function ENT:Draw()
        self:DrawModel()

        local label = self:GetNWString("craving_label", "")
        if label == "" then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > 200 * 200 then return end

        local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 4)
        local ang = Angle(0, ply:EyeAngles().y - 90, 90)
        cam.Start3D2D(pos, ang, 0.15)
            draw.SimpleTextOutlined(label, "DermaDefaultBold", 0, 0,
                Color(224, 224, 224), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
                1, Color(0, 0, 0, 200))
        cam.End3D2D()
    end

end

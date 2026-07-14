# Craving — CHANGELOG

> Historial de parches del módulo. Cada entry nace `[PENDIENTE]` y pasa a
> `[APLICADO YYYY-MM-DD]` **solo tras la verificación en juego** (flujo §1
> PASO 4-5). Nunca se borra ni renumera.

---

## Sesión 2026-07-13 — Block 4: diseño + bajada a código del v1

Diseño iterado en el repo (semilla → decisiones A-F → arquitectura ratificada el
mismo día) y bajado a código completo. Harness offline verde en ambos realms.
**Verificado en juego por el autor en tres rondas** (2026-07-13/14): ronda 2 (25 OK,
confirma el fix del entry 10) → ronda 3 (assets, entry 11) → ronda 4 (gate WALK+USE,
entry 12). **Los 12 entries quedan `[APLICADO]`.** La pata sin-Cargo del checklist
(logs de degradación + consumo in situ de la entity) quedó pendiente a pedido del
autor — la cubre el harness offline en ambos realms; no bloquea ningún entry.

1. **Estreno del repo** (scaffold + docs) — `[APLICADO 2026-07-13]`
   `CLAUDE.md`, `docs/{craving_estado.md, craving_roadmap.txt, CHANGELOG.md,
   craving_convenciones_commits.txt}` + `Craving_Block4_Semilla.md` (histórico) +
   `Craving_Architecture.md` (ratificado). Manifest de carga
   `corpus_craving_init.lua` con boot diferido a `Initialize` (template Caliber),
   bloque CONTRATO (§8) y sub-archivos en `lua/corpus_craving/<realm>/`.

2. **Config + balance tunable** (`corpus_craving_config.lua`) — `[APLICADO 2026-07-13]`
   Convars `craving_enabled` / `craving_decay_scale` (0 = congela) /
   `craving_damage_scale` / `craving_stomach_sounds` (sv, replicadas) +
   `craving_hints` (cl, USERINFO). Balance §2-§3 como data. Tabla de 6
   consumibles (§5) con cadenas de modelos. Funciones puras: `DrainPerTick`,
   `OverweightMult`, `Severity`. Getters client del contrato (NW2).

3. **Assets por candidatos** (`corpus_craving_assets.lua`) — `[APLICADO 2026-07-13]`
   `Assets.Model/Sound` (primera ruta montada gana; último candidato = HL2
   garantizado), sets de sonido eat/drink/vodka/estómago del pack ZONA
   (addon `corpus_stalker`), `StalkerMounted()`.
   **Validar en juego:** las rutas CS:S (`bread_slice.mdl`, `it_mkt_sausage.mdl`)
   y los sonidos fallback del engine son candidatos de memoria — si no existen,
   la cadena cae al último candidato HL2 sin romper nada, pero conviene
   reemplazarlos por rutas reales.

4. **Core server** (`corpus_craving_core.lua`) — `[APLICADO 2026-07-13]`
   Estado por jugador; tick único de 5 s: decay (sprint ×1.25/×1.75, sobrepeso
   vía `CARGO.Inventory.GetWeightFraction` con pcall), umbrales 50/25 con hints
   (gated por userinfo) y evento `Craving_StatCritical`, estómago audible
   (60-90 s, solo con el addon), daño fallback acumulativo (sed 2× hambre,
   `DMG_GENERIC` del mundo) con mensaje de muerte propio; espejo NW2 on-change;
   contrato `GetHunger/GetHydration/Restore` + `Consume` (anti-desperdicio §5);
   persistencia `state_<steamid64>` (disconnect/shutdown → load en initial
   spawn); respawn 75/75 (≠ reconexión).

5. **Puente Coagulant mock-first** (`corpus_craving_coagulant.lua`) — `[APLICADO 2026-07-13]`
   `_CoagulantUpdate`: delegación por CAPACIDAD (`isfunction(ApplyExternalCondition)`),
   severity on-change redondeada a 2 decimales, `_CoagulantClear` al morir/
   desconectar. Con delegación activa el core no toca HP.
   **Nota cross-repo:** la firma es contrato ESPERADO — negociarla cuando
   Coagulant Block 3 baje a código (su §12 ya lista a Craving como consumidor).

6. **Consumibles contra Cargo** (`corpus_craving_items.lua`) — `[APLICADO 2026-07-13]`
   `Corpus.OnReady` + lazy-check; categoría `food` explícita (label/orden); 6
   defs stackeables con `onUse` → `CRAVING.Consume` (false = no consume, §5).
   *Enmendado por el entry 10: el archivo nació en `server/` y se movió a
   `shared/` — ver ahí el porqué.*

7. **Entity de mundo** (`lua/entities/corpus_craving_food.lua`) — `[APLICADO 2026-07-13]`
   Clase única + 6 entradas de spawnmenu (Entities → Corpus) vía
   `list.Set("SpawnableEntities")` con `KeyValues.craving_item`; E → GiveItem
   (con Cargo, con feedback de pickup si existe) o consumo in situ (sin Cargo);
   etiqueta 3D2D (patrón corpus_cargo_item).
   **Validar en juego:** que sandbox aplique los `KeyValues` del spawnmenu (si
   no, toda entity spawneada cae al primer ítem — bread — y hay que migrar a
   una clase por def).

8. **Barras + tab Q** (`corpus_craving_bars.lua`, `corpus_craving_options.lua`) — `[APLICADO 2026-07-13]`
   `StatusPanel.RegisterBar` ×2 (firma verificada contra el código real de
   Cargo); tab con estado, detección de soft-deps (incl. addon de assets) y
   toggle de hints.

9. **Selftest + comandos** (`corpus_craving_dev.lua`) — `[APLICADO 2026-07-13]`
   `craving_selftest` (config pura, ítems, assets, contrato, round-trip de
   estado y Consume con jugador), `craving_status`, `craving_set <h> [hy]`
   (admin).

10. **Fix: las defs se registran en AMBOS realms** (`corpus_craving_items.lua`
    `server/` → `shared/` + manifest del init) — `[APLICADO 2026-07-13]`
    **Encontrado por el autor en la primera pasada en juego:** los consumibles
    no llegaban al inventario de Cargo. Causa raíz (verificada contra
    `corpus_cargo_inventory.lua`): el snapshot de Cargo solo transporta defs
    `autogen`/`icon_override` — una def registrada solo en server nunca existe
    en el cliente, el grid no la renderiza y el menú "Use" exige
    `isfunction(def.onUse)` client-side (una función no viaja por JSON). Las
    defs de módulo se registran en ambos realms, igual que las propias de Cargo
    (`corpus_cargo_dev.lua`). `onUse` sigue corriendo solo en server.
    **Ojo cross-repo:** el ítem semilla de Coagulant
    (`corpus-coagulant/lua/corpus_coagulant/server/corpus_coagulant_items.lua`)
    tiene el mismo bug latente (scaffold aún no verificado en juego) — avisar a
    esa sesión.

11. **Fix assets ronda 2: sonidos de consumo + modelo del Water bottle**
    (`corpus_craving_assets.lua`, `corpus_craving_config.lua`) — `[APLICADO 2026-07-13]`
    *(ronda 3 del autor: 8.1-8.4 ✓, incluido el opcional de corpus_stalker
    autocontenido)*
    **Encontrado por el autor en la ronda 2:** comer sonaba a tragos y beber a
    líquido derramándose. Causa: los `eat1-5.mp3` del pack ZONA son tragos (no
    masticado) e `inv_softdrink.ogg` es lata/vertido — la selección de archivos
    era mala, no las rutas (todas existen y resuelven). Selección nueva:
    eat → `inv_food.ogg` (el masticado canónico de STALKER), botellas
    (water, vodka) → `inv_vodka.ogg` (tragos), lata (soft drink) →
    `inv_softdrink.ogg` (kind nuevo `"can"`). Además el Water bottle deja el
    `drink.mdl` ZONA (es una bebida energética, reporte 3.4) → botella plástica
    HL2 con fallback de vidrio garantizado; el `drink.mdl` queda solo en Soft
    drink, donde sí calza. **Colateral:** los 4 sonidos usados (`inv_food`,
    `inv_softdrink`, `inv_vodka`, `hunger.mp3`) se copiaron a `corpus_stalker`
    (tabla del README actualizada) — hasta hoy el addon de assets NO tenía
    carpeta `sound/` y los sonidos llegaban del Workshop `zona stalker
    actionsounds` (324236009) montado aparte; ahora el addon es autocontenido.
    Harness offline verde tras el cambio (69/55, 0 fallos).
    **Nota de la ronda sin fix (data, no código):** los footprints del grid
    (sausage 1×1, bread 2×1, botellas 1×2) son autogen de Cargo por bounds del
    modelo — si el autor los quiere distintos, la palanca es `cargo_icon_edit`
    (override por def, persiste en data) o dictar `def.size` explícitos.

12. **Gate WALK+USE en la entity de mundo** (`corpus_craving_food.lua`) — `[APLICADO 2026-07-14]`
    *(ronda 4 del autor: 9.1-9.3 ✓ — toma, carry y suelta)*
    **Pedido del autor en la ronda 3:** la comida se tomaba con USE pelado,
    contra la convención de mundo del ecosistema (WALK+USE = toma deliberada).
    El gate de Cargo (`corpus_cargo_capture.lua`, "world gate") solo cubre sus
    propias clases (`corpus_cargo_item`, munición, armas) y se hace a un lado
    con cualquier otra entity — `corpus_craving_food` ahora se gatea sola en su
    `ENT:Use`: WALK+USE toma (inventario con Cargo / consumo in situ sin él),
    USE pelado la carga como prop HL2, y re-USE mientras se carga SUELTA
    (marca `CravingCarryEnt` contra el re-agarre — el engine libera antes de
    que `Use` corra, mismo remedio que pagó Cargo). Enmendado §7 de la
    arquitectura. Harness: 3 checks nuevos del gate, verde en ambos realms.

**Checklist de verificación en juego** → CLAUDE.md § Verificación (flujo
completo con y sin Cargo/Coagulant/addon de assets). Rondas 2-4 en el
Artifact "Craving — Verificación en juego · Block 4 v1".

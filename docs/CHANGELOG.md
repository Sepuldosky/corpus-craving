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

---

## PARCHES DE sesión Pasada de veracidad de docs — 2026-07-14

Auditoría de veracidad del ecosistema (siete repos, cinco rondas): hallazgos donde
el doc afirma algo que hoy es **falso** contra el código. Los 13 parches de este
repo **no** son todos la misma clase de deriva:

- **1-5** — la deriva original: docs congelados en el instante **anterior** al primer
  commit y a la ronda 2 en juego.
- **6-7** — lo que esa primera ronda no releyó: la tabla de umbrales de §3 y el cuerpo
  de §4/§9 de la arquitectura.
- **8-9** — el `README.md`, que nunca entró en el alcance de las rondas previas.
- **10-13** — mentiras sueltas de otra naturaleza: el harness offline, la lista «en
  futuro» de §15, `chore` vendido como alcance de commit y esta misma intro.

El PASO 5 obliga a refrescar `craving_estado.md` y este CHANGELOG al cerrar, pero
**nada obligaba a releer las tablas de la arquitectura** cuando una ronda en juego
cambiaba los assets: por eso §5/§6 seguían prometiendo sonidos que el código ya
había descartado. Sin superficie de runtime: nacen `[APLICADO]`.

- PARCHE 1 — docs(docs): corrige el «el repo no tiene commits todavía» de
  `craving_estado.md` (cabecera + «Próximo paso» 1). El repo tiene **14 commits**
  y está al día con `origin/main` (`4ae708be`, verificado con git antes de
  escribir el número); el primer commit + push deja de ser un pendiente y el paso
  1 pasa a ser la negociación de `ApplyExternalCondition`. **[APLICADO 2026-07-14]**

- PARCHE 2 — docs(docs): `craving_roadmap.txt` §1 — el punto [2] («primer commit +
  push… el repo GitHub sigue vacío») pasa a **HECHO (2026-07-14)**, con los 10
  archivos `.lua` del módulo (no 9: faltaba contar `corpus_craving_dev.lua`), y el
  **«es lo próximo»** se promueve al punto [3]. **[APLICADO 2026-07-14]**

- PARCHE 3 — docs(docs): `Craving_Architecture.md` §1 y §4 — Coagulant deja de ser
  «Block 3 en borrador»: su código está en el árbol con los slices 1-3 verificados
  en juego y la UI pendiente. Lo que **sigue siendo cierto** —y sostiene el puente
  mock-first— es que no expone condición externa: **0 hits de
  `ApplyExternalCondition`** en su `lua/`, verificado (los hits del repo son de sus
  propios docs, que la nombran como pendiente cross-repo). `Corpus S.T.A.L.K.E.R.` deja
  de ser «addon de assets en `dev/`, no publicable»: es la **séptima raíz** del
  workspace; lo que no se versiona son sus assets GSC, no el addon. **[APLICADO 2026-07-14]**

- PARCHE 4 — docs(docs): `Craving_Architecture.md` §5 y §6 — tablas de assets contra
  `corpus_craving_config.lua` y `corpus_craving_assets.lua`, ruta por ruta. La
  Water bottle **no tiene modelo ZONA** (el `drink.mdl` es una bebida energética,
  reservada al Soft drink): su candidato es `garbage_plasticbottle003a.mdl`. Los
  sonidos pasan de dos filas a **tres** (`eat` / `drink`+`vodka` / `can`, los cuatro
  kinds reales de `CONSUME_SETS`) y cae el **«(aleatorio)»** de los `eat<1-5>.mp3`:
  la ronda 2 los descartó —son tragos, no masticado— y `Assets.Sound` devuelve el
  **primer candidato montado**: la **selección de sonido no es aleatoria**. (El único
  azar del módulo es la *cadencia* del rugido de estómago — `math.Rand` en
  `corpus_craving_core.lua`.) **[APLICADO 2026-07-14]**

- PARCHE 5 — docs(docs): `Craving_Architecture.md` §8 — la «**enmienda pendiente al
  cerrar**» a la tabla §4 de `CORPUS_Architecture.md` **ya está aplicada** (su fila
  de Craving dice «getters + `Craving_StatCritical`» desde el 2026-07-13). Pasa de
  promesa a hecho registrado. **[APLICADO 2026-07-14]**

### Ronda 3 — lo que se le escapó a la ronda anterior

Los verificadores destaparon dos derivas que las tablas §3/§4/§9 se comieron: la
ronda 2 auditó los assets de §5/§6 ruta por ruta y limpió el «borrador» de §1/§4,
pero **no releyó la tabla de umbrales ni el cuerpo de §4/§9**. Misma clase de
deriva, un doc más adentro.

- PARCHE 6 — docs(docs): `Craving_Architecture.md` §3 — la fila del umbral **≤ 50**
  prometía «**+ sonido de inventario suave**». Ese sonido **no existe ni existió**:
  el repo tiene exactamente **dos** llamadas de audio (`corpus_craving_core.lua:123`,
  el sonido de consumo; y `:174`, el rugido de estómago, gateado por `SEVERE_AT`
  → umbral **≤ 25**, no ≤ 50), y la función `Hint` es un `PrintMessage(HUD_PRINTCENTER)`
  pelado, **sin audio** (verificado con grep de `EmitSound`/`PlaySound` sobre `lua/`).
  El warn de ≤ 50 pasa a «hint centrado — **sin audio**». **[APLICADO 2026-07-14]**

- PARCHE 7 — docs(docs): `Craving_Architecture.md` §4 (regla 4 del puente) y §9 —
  seguían llamando «**el borrador de Coagulant**» a su diseño, contradiciendo el
  texto que la ronda 2 escribió en §1 y §4 de este mismo doc. Coagulant está
  **RATIFICADO (2026-07-13)** y su código está en el árbol con los slices 1-3
  verificados en juego. Los **hechos** citados siguen siendo ciertos —su §12 dice
  literal «Coagulant **no** detecta a Craving», y `coagulant_blood` es un `NW2Float`
  real (`corpus_coagulant_bleeding.lua:96`)—: lo falso era la **atribución**.
  Ahora se cita «Coagulant (§12)» y «el `coagulant_blood` de Coagulant».
  **[APLICADO 2026-07-14]**

### Ronda 4 — el README, que nunca entró en el alcance

Las rondas 1-3 barrieron `docs/` y el `CLAUDE.md`, pero ninguna miró el **`README.md`**
—el único doc que ve quien entra al repo en GitHub—: seguía siendo el de la semilla,
congelado antes del primer commit de código y contradiciendo a **todos** los demás docs
del repo.

- PARCHE 8 — docs(docs): `README.md` — el bloque de estado decía «**Estado: sin
  empezar.** Este repo aún no tiene código». **Falso en los tres frentes**: el árbol
  tiene **10 archivos `.lua`**, el Block 4 está **CERRADO** con el v1 **verificado en
  juego** en tres rondas (los 12 entries del v1 en `[APLICADO]`), y el bloque de diseño
  se **ratificó el 2026-07-13** — más **14 commits pusheados a `origin/main`**. El
  bloque pasa a «**v1 en código y verificado en juego**» y se estrena una sección
  **Características** que dice lo que el módulo *es* hoy: decay en tick de 5 s con
  sprint/sobrepeso, umbrales ≤ 50 / ≤ 25 + `Craving_StatCritical`, los 6 consumibles
  contra Cargo (categoría `food`, anti-desperdicio), la entity de mundo con WALK+E,
  barras en el StatusPanel, tab Q, persistencia por SteamID64 y respawn 75/75. Se
  suman **Documentación** (links a los docs vivos) y la nota de idioma, en línea con
  el README de Cargo. **[APLICADO 2026-07-14]**

- PARCHE 9 — docs(docs): `README.md` (encabezado y §Dependencias) — vendía «fallback a
  los comestibles/bebibles de **HL2**» y «sin Cargo, fallback a **entities HL2**
  comestibles/bebibles». **Falso**: sin Cargo el fallback es la entity **propia** del
  módulo (`lua/entities/corpus_craving_food.lua`, WALK+E → consumo in situ; verificado
  en su rama sin-Cargo, `:127-128`). Lo único que cae a HL2/CS:S son los **modelos y
  sonidos** cuando el addon de assets de la Zona no está montado (`Assets.Model`/
  `Assets.Sound`, cadena de candidatos con HL2 vanilla como último). Misma corrección
  que ya se aplicó en `corpus/docs/CORPUS_Architecture.md` §5. Además la sección se
  titulaba «Dependencias **previstas**» con las tres ya cableadas y verificadas: pasa a
  «Dependencias». **[APLICADO 2026-07-14]**

- PARCHE 10 — docs(docs): `CLAUDE.md` §Verificación, punto 2 — decía que el **harness
  offline** «se reconstruye en el **scratchpad de sesión**». **Falso**, y contradecía a
  otro doc del mismo repo: el harness es un archivo **permanente** en
  `../dev/harness_craving.py` (21,5 KB, fuera de los repos git), y `craving_estado.md`
  ya lo citaba como comando fijo — `python dev/harness_craving.py`. El punto ahora dice
  dónde vive y cómo se corre. **[APLICADO 2026-07-14]**

- PARCHE 11 — docs(docs): `Craving_Architecture.md` §15 («Al bajar a código y
  verificación **prevista**») — la lista seguía **en futuro** con las tres casillas ya
  cumplidas. Contra el árbol: los 12 entries del v1 están `[APLICADO]`;
  `CORPUS_Architecture.md` §4 **ya recoge** la superficie de Craving (línea de la tabla:
  getters + `Craving_StatCritical`) y su §9 **ya lleva** el resumen + link con el Block 4
  **CERRADO**; y la verificación en juego la corrió el autor en tres rondas. El punto 2
  además **repetía la promesa** («enmienda a su tabla §4») que el PARCHE 5 de esta misma
  pasada ya declaró cumplida en el §8 de este mismo doc — el doc se contradecía consigo
  mismo. La sección pasa a **pasado** («La bajada a código y la verificación — hecho»),
  con la única casilla realmente pendiente marcada como tal: la pata **sin Cargo**,
  diferida a pedido del autor y cubierta por el harness. **[APLICADO 2026-07-14]**

### Ronda 5 — el cierre, y la deriva que la propia pasada dejó

Última ronda: dos residuos menores, uno de ellos **producido por esta misma sesión**.

- PARCHE 12 — docs(docs): `CLAUDE.md` §Git / commits — listaba `chore` como **alcance**
  de este repo («(+ `docs`, `chore`)»), tergiversando al doc que cita. Contra
  `craving_convenciones_commits.txt`: `chore` es un **tipo** de commit (§2, junto a
  `feat`/`fix`/`refactor`/`docs`/`test`), y §3 («ALCANCES ESPECÍFICOS DE CRAVING»)
  enumera **11** alcances sin incluirlo — `config`, `assets`, `core`, `coagulant`,
  `items`, `entity`, `bars`, `options`, `dev`, `init`, `docs`. Ningún commit del
  historial usa `(chore)` como alcance; el propio ejemplo §4.2 del doc es
  `chore(init)` — tipo `chore`, alcance `init`. Se separan tipo y alcance con la misma
  redacción que ya usa el `CLAUDE.md` de Coagulant. **[APLICADO 2026-07-14]**

- PARCHE 13 — docs(docs): la **intro de esta misma sesión** — decía «Los **seis** de
  este repo son todos la **misma clase** de deriva — docs congelados en el instante
  anterior al primer commit». Falso por partida doble, y contradicho por la sección que
  encabeza: (a) la cardinalidad quedó rancia en cuanto las rondas 3-5 añadieron los
  parches 6-13 — hoy son **13**, no seis; (b) la causa única no aplica a «todos»: el
  PARCHE 10 corrige una mentira sobre el harness offline (archivo permanente en
  `../dev/harness_craving.py`, nada que ver con el primer commit) y los 6-13 son, por
  confesión de sus propios encabezados, derivas que la primera ronda **no vio**. La
  intro pasa a desglosar los cuatro racimos reales (1-5 / 6-7 / 8-9 / 10-13) en vez de
  atribuirlos todos a una sola causa. **[APLICADO 2026-07-14]**

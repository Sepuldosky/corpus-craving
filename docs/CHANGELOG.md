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

---

## PARCHES DE sesión Etiquetado de IDs normativos (deuda D-7) — 2026-07-19

Tanda multi-repo del ecosistema, guiada por `dev/PROMPT_d7_etiquetado_ids.txt` (§8 del flujo).
Solo prosa: **ninguna norma cambió**. Cada sede que el registro
(`../corpus/docs/ids.yaml`) declara ahora lleva su ID visible, para que un lector que
aterriza en el doc vea de qué norma se trata sin abrir el registro, y para que el gate de
coherencia (§7.8) pueda contrastar el título del yaml contra la prosa de su sede.

- PARCHE 1 — **15 de 16 IDs de la familia `CRV` etiquetados en su sede.**
  Los 1 restantes NO se etiquetaron a propósito: sus sedes viven en archivos `.lua`,
  en el CHANGELOG, en el estado o en el roadmap. Etiquetar ahí volvería **definitorio** un
  comentario, que es lo que **FLU-26** prohíbe, o tocaría un doc que no se reescribe
  (**FLU-14**). Son deuda **D-3** del registro y se cierran moviendo la sede a un doc —
  decisión de diseño, no mecánica. **[APLICADO 2026-07-19]**

- PARCHE 2 — **Ocho copias pasan a CITAR por ID:** `COR-2`/`COR-7`, `COR-5`, `COR-13`,
  `COR-6`, `COR-4`, `COR-3` y **`COR-12`** (la copia grande de la deuda **D-1**, en
  `Craving_Architecture.md` §5, ahora con puntero a su sede canónica). Además, dos contratos
  del `CLAUDE.md` que re-enunciaban normas **propias** (`CRV-1`, `CRV-2`/`CRV-3`) pasan
  a citarlas con puntero a la arquitectura — evita dos definitorios del mismo ID.
  **[APLICADO 2026-07-19]**

Verificación: `corpus/.claude/check-ids/corpus_check_ids.ps1` en verde (una etiqueta mal
tipeada habría salido como `HUERFANO_DOC`). Sin superficie de runtime: nada que cargar en
un mapa, y **ningún check de planilla nace de esta tanda** (FLU-37).

---

## PARCHES DE sesión Anti-drift: cierre de votos — 2026-07-19

Tanda multi-repo guiada por `dev/PROMPT_cierre_antidrift.txt`: curaduría D-10 del registro
(votada por el autor), parte que toca a este repo.

- PARCHE 1 — **Dos títulos fusionados del registro, partidos con ancla propia:** la fórmula
  de severity gana enunciado en prosa en §4 como **`CRV-17`** (`(25 − stat)/25` clampeada a
  [0,1]; antes vivía solo en el comentario del bloque de código) — `CRV-5` queda con el
  reporte on-change; y el espejo NW2 escrito solo si cambió > 0.1 es ahora **`CRV-18`**
  (§9) — `CRV-9` queda server-autoritativo + clamp, con la línea del clamp de §2 ahora
  etiquetada. **[APLICADO 2026-07-19]**

Verificación: `corpus/.claude/check-ids/corpus_check_ids.ps1` en verde sobre 197 IDs. Sin
superficie de runtime, y **ningún check de planilla nace de esta tanda** (FLU-37).

---

## PARCHES DE sesión Anti-drift: reparación del COMPLETO — 2026-07-19

Aplica los hallazgos del acta `corpus/docs/auditorias/2026-07-19_coherencia_docs.md` que
tocan este repo.

- PARCHE 1 — **2.4 (ALTA):** CRV-7 deja de enunciar el universal «el último candidato de
  cada lista es SIEMPRE HL2 vanilla»: vale para **modelos** (`Assets.Model` garantiza
  ruta aunque nada esté montado); en **sonidos**, `Assets.Sound` devuelve `nil` sin
  candidatos montados, y el rugido de estómago es la **excepción declarada** sin
  fallback (§6) — no se le agrega uno. El README barre su eco y el registro sigue a la
  sede corregida. **[APLICADO 2026-07-19]**
- PARCHE 2 — **2.17:** la semilla gana la enmienda de ruta: el addon de assets dejó de
  vivir en `dev/` el mismo 2026-07-13 — es la séptima raíz `corpus-stalker/` (git propio
  y público, assets GSC en `.gitignore`). La redacción original queda como registro
  histórico, ahora anotado. **[APLICADO 2026-07-19]**

Verificación: checker en verde + suite 12/12. Sin superficie de runtime.

---

## PARCHES DE sesión D-13: pre-2.º COMPLETO — 2026-07-19

Parte de la tanda multi-repo guiada por `dev/PROMPT_d12_d13_segundo_completo.txt`, que cerró
las deudas **D-12** y **D-13** del registro. Acá lo que toca a este repo. Solo prosa: **ninguna
norma cambió de contenido**.

- PARCHE 1 — **`CRV-19` acuñado: la tabla de alcances de `craving_convenciones_commits.txt`
  §3 es norma y ahora tiene ID.** Ese doc era uno de los **10 docs ciegos** del hueco H1 del
  COMPLETO. La §3 es por-repo y jamás se hereda del framework (cita GIT-6); el `CLAUDE.md` la
  resume y **el doc manda**. Los 11 alcances se derivaron del propio doc. Nota: `coagulant`
  es alcance propio y legítimo — nombra el **puente** hacia ese módulo (soft-dep), no código
  ajeno. **[APLICADO 2026-07-19]**
- PARCHE 2 — **`craving_roadmap.txt` pasa de ciego a citante**, sin acuñar (voto del autor:
  un roadmap es intención pura). NOTA DE LECTURA + citas: el tramo de
  `ApplyExternalCondition` cita **CRV-4** y **FLU-17**, y deja explícito que la firma la
  congeló **el consumidor** y que la ratificación del dueño es la deuda **D-5**; las
  fronteras duras citan **COR-1**/**COR-10**; el tramo de cocinar cita la familia nueva de
  Workbench (**CRG-50**..**CRG-54**) y **CRG-1**. **[APLICADO 2026-07-19]**
- PARCHE 3 — **`Craving_Block4_Semilla.md` (217 líneas, cero IDs) se declara REGISTRO
  HISTÓRICO** y recibe citas. Su §1 «Marco fijo» describía el estado ANTERIOR al volcado a la
  arquitectura, así que además de citar (**COR-13**, **CRG-1**, **FLU-17**, **CRV-4**,
  **COR-5**, **COR-1**/**COR-10**) se anotan en sitio los **dos puntos donde lo implementado
  la superó**: las defs van en AMBOS realms (**COR-12**, lección de la primera pasada en
  juego) y la degradación es por **CAPACIDAD**, no por presencia (**CRV-2**/**CRV-3**). Donde
  el marco fijo y la arquitectura difieran, manda la arquitectura. **[APLICADO 2026-07-19]**

Verificación: checker en verde sobre 207 IDs + suite 12/12. Sin superficie de runtime.

---

## PARCHES DE sesión Reparación del gate de coherencia (acta 2026-07-22) — 2026-07-22

Tanda de reparación documental propuesta por el gate de coherencia en su corrida COMPLETO del
2026-07-22 (`../../corpus/docs/auditorias/2026-07-22_coherencia_docs.md`; el gate propone, el
autor dispone). Acá lo que toca a este repo. Solo prosa; **ninguna norma cambió de contenido**.

- PARCHE 1 — **Hallazgo 2.8 del acta (pase de valor):** `docs/craving_roadmap.txt` [3] decía
  negociar `ApplyExternalCondition` con Coagulant «cuando su Block 3 cierre», presuponiéndolo
  abierto. El Block 3 de Coagulant está CERRADO desde el 2026-07-20 (`coagulant_estado.md`; 4
  slices verificados en juego). §7.1: estado.md (nivel 2) gana al roadmap (nivel 6). Se pasa a
  «ahora que su Block 3 cerró»; se preserva que el puente sigue mock-first y que la
  ratificación del dueño es la deuda D-5 (aún abierta). **[APLICADO 2026-07-22]**

Verificación: sin superficie de runtime (solo docs). Cambios trazables al acta (§7.1). No
commiteado ni pusheado (GIT-7).

---

## PARCHES DE sesión Separación sonidos/ítems: Craving come del banco general — 2026-07-24

Decisión del autor: los sonidos de consumo GENERALES viven en el framework
(`corpus/sound/corpus/craving/`, ports de GAMMA no versionados — COR-17) y los
`zona/stalkerrp/*` de corpus-stalker quedan RESERVADOS para la comida propia de la Zona.
Hay separación entre sonidos e ítems: si Craving suma props nuevos propios, consumen el
banco general.

- PARCHE 1 — feat(assets): `CONSUME_SETS` pasa del pack ZONA al banco general —
  `eat` → `corpus/craving/food_use.ogg`, `drink` → `drink_flask.ogg`, `can` →
  `drink_soda_use.ogg`, `vodka` → `vodka_use.ogg` — con los mismos fallbacks del engine
  (la resolución por lista de candidatos no cambia: primer montado gana, sin el banco cae
  al fallback). `Assets.STOMACH` queda INTACTO en `zona/stalkerrp/hunger.mp3` (excepción
  declarada CRV-7: no es un sonido de consumo de ítem y no tiene equivalente digno).
  El header del archivo documenta las dos fuentes. **[APLICADO 2026-07-24]**

Verificación offline: compila (lupa) + harness client 55 OK. EN JUEGO (checklist del autor):
comer/beber los 6 consumibles suena desde el banco de corpus (masticado/tragos/lata/vodka
distintos entre sí); con corpus-stalker montado el vodka usa el banco de Corpus y NO el sonido
original de la Zona (buscado a propósito — separación sonidos/ítems); el estómago sigue rugiendo
con corpus-stalker. **Confirmado en juego por el autor el 2026-07-24.** Roadmap: entra el
pendiente [8] (props comestibles de HL2 como base). Commiteado y pusheado con autorización del
autor.

---

## Sesión Comida envasada: registro abierto, taxonomía y 9 modelos propios — 2026-08-06

Pedido del autor: sumar a Craving los objetos comestibles de *Props Mexicanos*
(Workshop 3178402491, autor **gbonn**, que autoriza el uso con crédito), del mismo
modo en que Coagulant estrenó modelos propios el 2026-08-05. Al abrirlo apareció
que **"agregar una comida" no existía como operación**: era editar una tabla
literal, y el índice se armaba una sola vez en file-scope. El autor pidió idear
primero el sistema y votó los tres ejes antes de bajar código (§5.1 de la
arquitectura). **Nada verificado en juego todavía.**

- PARCHE 1 — feat(config): **registro abierto de comidas** (`corpus_craving_food.lua`,
  nuevo, primero en el manifest). `Food.Register` es el ÚNICO escritor de
  `Config.ITEMS` e `ITEMS_BY_ID` y las mantiene juntas por construcción — antes un
  `table.insert` fuera de file-scope entraba en la lista y no en el índice, y como
  `Consume(ply, id)` y la entity resuelven POR el índice, esa comida habría sido
  visible e inconsumible. Las 6 originales migran al mismo registro: una ruta, no
  dos. Superficie: `Register`/`Get`/`All`/`HasTag`/`ByTag`/`StatOf`/`ModelOf`.
  **[PENDIENTE]**

- PARCHE 2 — feat(config): **taxonomía `kind` / `tier` / `tags`** (CRV-13/CRV-14).
  `kind` (cerrado, obligatorio) reemplaza la inferencia del anti-desperdicio, que
  elegía "el stat que más restaura" — una comida de +20/+20 caía del lado del
  hambre por el desempate del `>=` y no por ser comida. `tier` y `tags` **no
  gobiernan nada** (cita COA-28): son el gancho declarado de §14 (`raw`/`cooked`
  para cocinar, `alcohol`/`caffeine` para efectos). **No** bajan a `category` de
  Cargo porque su fila de tabs está cerrada y una categoría no mapeada cae en
  "Misc": la categoría sigue siendo `food` y los campos viajan en la def, que
  Cargo transporta sin interpretar (CRG-1). **[PENDIENTE]**

- PARCHE 3 — feat(assets): **9 modelos propios** en `models/corpus_craving/` +
  `materials/models/corpus_craving/`, portados y **recompilados** desde el addon
  de gbonn. Recompilados y no copiados por dos razones medidas: estaban a **2-3×
  del tamaño real** (el pan medía 37 u ≈ 94 cm, contra el medkit de 12 u que
  Coagulant ya había descartado por "prop de escenario"), y su `$cdmaterials`
  venía horneado como `models/gbonn/`, lo que habría obligado a shipear
  materiales en la carpeta de otro addon. Pipeline reproducible:
  `dev/phastools/mxfood_build.py` (+ `srcprop2smd.py` y `mdlshot.py`, nuevos).
  Créditos en `docs/CREDITOS.md`, nuevo. **[PENDIENTE]**

- PARCHE 4 — feat(items): **9 defs de comida envasada** (`corpus_craving_food_mx.lua`,
  nuevo): 3 comidas, 3 bebidas y 3 alcohólicas. Declaran `model` directo — el
  mismo argumento de Coagulant: `Cargo.Items.SetModel` sigue pisando el modelo
  declarado, así que un addon de contenido los re-viste igual. Nombres genéricos
  y marca en la trivia (decisión del autor): Craving es un módulo genérico. El
  alcohol entra **sin efectos**, como el vodka. Craving pasa de 6 a 15
  consumibles. **[PENDIENTE]**

- PARCHE 5 — refactor(items/entity): **`Food.ModelOf` es la única regla de modelo**
  (CRV-15). `items.lua` y la entity de mundo la consumen en vez de llamar a
  `Assets.Model(item.models)` cada uno por su lado: con la regla escrita en tres
  lugares, alcanzaba con que uno se olvidara de `model` para que ese ítem saliera
  como la cajita de cartón sin que nada fallara. **[PENDIENTE]**

- PARCHE 6 — test(dev): **selftest de la taxonomía y del registro**. Por ítem:
  kind/tier válidos, `tagset` coherente con `tags`, `StatOf` = el stat del kind, y
  que exista `model` o `models`. Más el round-trip de `Register` (alta indexada,
  re-registro que reemplaza en sitio sin duplicar, probe deshecho) y `ByTag`.
  Y un check que faltaba: **que el `.mdl` propio declarado esté en disco** — un
  modelo propio no tiene fallback, así que su ausencia no degrada, da el error de
  modelo del engine. Es el mismo hueco que en Coagulant dejó pasar 35 referencias
  rotas con el lote en verde. **[PENDIENTE]**

Verificación offline: **harness verde en ambos realms, 254 OK server / 240 client**
(`python dev/harness_craving.py`) — el harness ahora monta en su filesystem
simulado las rutas que existen DE VERDAD en el repo, así el check de disco mide en
vez de pasar siempre. **Control negativo corrido**: sacando `beer_can.mdl` el
harness se pone rojo y nombra el archivo; restaurado, vuelve a verde. Escala de los
9 modelos: **0,00 % de error contra el tamaño pedido** medido sobre la malla del
`.mdl` compilado. Los 9 **renderizados y mirados** uno por uno: cada uno es el
objeto correcto con su textura correcta — la verificación estructural no ve un
modelo equivocado adentro de un `.mdl` que compila limpio.

Pendiente: **verificación en juego** (los 9 en el grid con su modelo, comer y beber,
la entity de mundo, el anti-desperdicio por `kind`).

### Parches de la 1.ª pasada en juego — 2026-08-06

El autor spawneó los 9 y reportó que **la iluminación se veía rara**. Dos defectos
reales, los dos **míos y los dos invisibles para todo lo que se había verificado**:
el `.mdl` compilaba limpio, la escala daba 0,00 %, el harness estaba verde y los
renders se veían bien. Antes de acusar al shader se midió lo que yo había tocado.

- PARCHE 7 — fix(assets): **el resize de texturas premultiplicaba por alfa**.
  `Image.resize` de PIL sobre una imagen **RGBA** arrastra el color a NEGRO donde
  el alfa es bajo. En el normal map de la Corona (4096², alfa medio 136 con mínimo
  0) metió **120.340 píxeles negros** que el original no tenía — y negro en un
  normal map no es una normal, es basura: la botella se ilumina mal justo ahí.
  Medido: el original tiene **0** píxeles casi-negros; en RGBA los meten BOX,
  BILINEAR, BICUBIC y LANCZOS **por igual** (~120 k cada uno) y sólo `NEAREST` se
  salva porque no interpola; redimensionando en modo RGB, **cero con todos**.
  Arreglado escalando RGB y alfa por separado: el bump pasó de −18,66 de media y
  gamma implícita 1,283 a **−0,31 y 1,004**, con 0 negros. **[PENDIENTE]**

- PARCHE 8 — fix(assets): **las dos botellas de cola perdían `TRANSLUCENT_TWOPASS`**.
  El `.mdl` original trae el flag (`0x09`), el recompilado salía `0x01`: falta
  `$mostlyopaque` en el `.qc`, que es lo que hace que un modelo con partes
  translúcidas se dibuje en **dos pasadas** (lo opaco primero) para que se ordene
  bien. Una botella transparente con líquido oscuro se ve mal sin eso. Ahora el
  flag **se lee del `.mdl` fuente** en vez de decidirse a ojo, y `check` compara
  los flags del header contra el original: **9/9**. Ese check no existía, y por eso
  el defecto pasó — un flag ausente no rompe nada medible fuera del juego.
  **[PENDIENTE]**

Ojo con la evidencia: **los renders NO confirman estos dos parches.** `mdlshot.py`
no interpreta el `.vmt` ni las pasadas del motor, así que las hojas de contacto se
ven idénticas antes y después. Lo que se midió es el archivo (píxeles negros = 0,
flags = los del original); lo que falta es el juego.

### Parche de la 2.ª pasada en juego — 2026-08-06

El autor reportó **texturas corridas** y objetos que **deberían ser más opacos**.
Una sola causa, y la peor de las tres: la **V de las UV salía volteada en los 9**.

- PARCHE 9 — fix(assets): **`srcprop2smd.py` escribía la V sin invertir**. El `.vvd`
  guarda las UV como las usa el motor (v=0 **arriba**) y el SMD las lleva al revés,
  así que studiomdl **voltea la V al compilar**: pasarla tal cual deja la textura
  espejada verticalmente. Eso explica lo corrido — y probablemente también lo
  translúcido, porque con la V volteada las UV de la Corona y de la Coca amarilla
  (las dos con **`$alphatest`**) caían en zonas de alfa 0 y el shader **recortaba
  la geometría**: un agujero se ve exactamente como "no es opaco". **[PENDIENTE]**

**Por qué no lo agarró nada, que es lo que hay que aprender.** `mdlshot.py`
muestreaba con `1-v`, o sea invertía de vuelta: **el instrumento de control
compensaba exactamente el defecto que tenía que encontrar**, y las nueve hojas de
contacto salieron perfectas y lo "confirmaron". Un instrumento que comparte el bug
del proceso que audita no es que falle en detectarlo: lo *acredita*. Lo destapó el
juego, y lo probó renderizar el **`.mdl` original** — la referencia que no comparte
el bug: con `1-v` sale espejado y con `v` sale bien.

Se agregó `check_uv()` al pipeline, comparando contra el `.mdl` fuente: **9/9 con
las UV del original, 0,00000 de diferencia**. Ese check también tuvo que corregirse
primero — comparaba índice a índice y daba 0/9 en U **y** en V, porque **studiomdl
reordena los vértices**; se compara el conjunto ordenado, que es invariante a la
permutación. **Control negativo corrido:** revirtiendo el flip, el check da 0/9 con
dif V de 0,08 a 0,62 y U en 0,00000 — la firma exacta del defecto.

### Parches de la 3.ª pasada en juego — 2026-08-06

El autor reportó que veía **el interior de los objetos**, con la textura de afuera
puesta adentro, y aportó el dato que resolvió el caso: *"el único que se salva es
el pan Bimbo"*. Dos defectos más, los dos de orientación.

- PARCHE 10 — fix(assets): **el winding de las caras salía invertido en los 9**.
  El `.vtx` guarda las caras con la convención de Source y el SMD usa la
  contraria, así que emitirlas tal cual deja **todos** los triángulos al revés: el
  motor los descarta por backface culling y se ve el interior del modelo — la
  etiqueta de la botella leyéndose espejada desde adentro. Medido contra el
  original: **1812/1812, 2772/2772, 5680/5680 caras con el signo opuesto**, el
  100 % en los 9. Que el pan Bimbo se salvara fue la pista: es el **único** cuyo
  `.vmt` trae `$nocull 1`, o sea el único que dibuja las dos caras. **[PENDIENTE]**

- PARCHE 11 — fix(assets): **los 9 estaban girados un cuarto de vuelta**. El
  `--yaw -90` que compensaba la supuesta rotación de studiomdl era de más: la
  malla no hay que rotarla. **El error no fue no medir, fue medir el archivo
  equivocado** — la calibración comparó el **hull de colisión** del header (offset
  104), que sale del `$collisionmodel` y no comparte la orientación de la malla.
  Comparando hulls, `-90` "reproducía" el original con signo y todo. La malla del
  `.vvd` dice lo contrario: `milk_carton` original **(5,99 × 4,04)** contra portado
  **(4,04 × 5,99)**, y alineando vértice a vértice, 0° → 1,377 u mientras +90° →
  **0,00047 u**. Es la misma trampa que ya había mordido en la escala (el primer
  check medía el hull y daba +3,7 a +11 % de sesgo) y que no se arrastró hasta acá.
  **[PENDIENTE]**

**Por qué se acumularon tres rondas de esto.** `mdlshot.py` **no hacía backface
culling**: dibujaba las caras traseras, así que un modelo con el winding invertido
le salía perfecto. Ya había pasado lo mismo con la V (muestreaba `1-v` y
compensaba el volteo). Dos veces el mismo patrón: **un instrumento que no modela
el mecanismo del defecto no lo detecta y encima lo acredita.** Ahora el renderer
culla, con el signo calibrado contra el `.mdl` original.

El `check` pasó de una columna a **cinco**, todas contra el archivo original y no
contra lo que yo pedí: escala, flags del header, UV, **winding** y **orientación**
— **9/9 en las cinco**. Y el render dejó de ser una hoja suelta: ahora se compara
**original contra portado con la misma cámara**, que es lo que vuelve visible una
rotación (una hoja sola se ve perfectamente bien girada 90°).

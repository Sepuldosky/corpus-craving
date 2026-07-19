# Craving — Documento de Arquitectura (Block 4, dominio de supervivencia)

> **Uso de este documento:** referencia autocontenida del diseño de Craving
> (hambre/hidratación de jugador). Un implementador debe poder ejecutar el módulo
> con este doc, sin el chat de diseño ni el doc general de Corpus (la frontera
> general sigue en `../../corpus/docs/CORPUS_Architecture.md` §2, §4-§5).
>
> **Estado: RATIFICADO por el autor (2026-07-13)** — mismo día que el borrador;
> bajada a código en la misma sesión. Las decisiones estructurales A-F están
> cerradas (registro en [`Craving_Block4_Semilla.md`](Craving_Block4_Semilla.md));
> **los números de balance siguen siendo tunables**: viven en
> `corpus_craving_config.lua` y se ajustan en juego sin tocar lógica.
>
> Regla heredada del ecosistema que este doc respeta en cada tabla: **los nombres
> de APIs y rutas de assets ajenos no se asumen de memoria** — las firmas de Cargo
> citadas acá fueron verificadas contra su código real el 2026-07-13; las rutas de
> modelos/sonidos fallback están marcadas "validar" y las decide `file.Exists` en
> runtime + la verificación en juego.

---

## 1. Frontera y soft-deps

Craving posee **hambre e hidratación de jugador**, nada más. Hard-dep: Corpus.
Soft-deps, siempre lazy-check / `Corpus.OnReady`, jamás asumidas:

| Peer | Consume | Sin él, degrada a |
|---|---|---|
| **Cargo** (en código, verificado) | `Items.Register` (consumibles §5), `StatusPanel.RegisterBar` (barras §10), `Inventory.GetWeightFraction` (decay por sobrepeso §2) | comida solo por entities de mundo (§7); sin barras (feedback indirecto §10); sin modificador de sobrepeso |
| **Coagulant** (Block 3 **en código** — slices 1-3 verificados en juego, UI pendiente; puente mock-first: todavía **no expone condición externa**) | contrato esperado `ApplyExternalCondition` (§4) | daño periódico al HP nativo hasta la muerte (§3) |
| **Corpus S.T.A.L.K.E.R.** (addon de contenido, **séptima raíz del workspace** `../corpus-stalker/`, opcional; **sus assets GSC no se versionan** — el addon sí) | modelos y sonidos ZONA (§6) | modelos HL2/CS:S conocidos + sonidos base del engine |

**CRV-13 — Dirección única:** Craving detecta a sus peers; nadie detecta a Craving. Fuera de
la frontera (no-scope duro, §14): stamina/fatiga/sueño (Coagulant), radiación
(sin dueño), contenedor/peso (Cargo), NPCs (Cortex).

---

## 2. Modelo de stats

**CRV-9** — Dos stats por jugador, **server-autoritativos**, escala **100 → 0** (100 =
saciado; la barra se vacía — consistente con el `getValue -> 0..100` de las
barras de Cargo):

- `hunger` (hambre)
- `hydration` (hidratación)

**Tick**: timer server único cada **5 s** (nunca per-frame). Cada tick aplica:

```
drain(stat) = base_stat × mult_actividad × mult_sobrepeso × craving_decay_scale
```

| Parámetro (config, tunable) | Propuesta | Efecto |
|---|---|---|
| `base.hunger` | 0.055 / tick (≈0.66/min) | 100→0 en ≈ 2.5 h de juego normal |
| `base.hydration` | 0.083 / tick (≈1.0/min) | 100→0 en ≈ 1.7 h (la sed corre ~1.5× más) |
| `mult_actividad` (sprint efectivo: `IsSprinting()` + velocidad real > umbral) | hambre ×1.25 · sed ×1.75 | correr da sed mucho antes que hambre |
| `mult_sobrepeso` (Cargo presente: `CARGO.Inventory.GetWeightFraction(ply)`) | lerp 1.0 → 1.5 entre fracción 0.5 y 1.0, ambos stats | cargar pesado cuesta comida y agua |

Sin Cargo, `mult_sobrepeso` = 1 (lazy-check + pcall, degradación honesta). Los
stats se clampean a [0, 100] siempre (CRV-9) — no hay valores negativos ni overfill.

---

## 3. Umbrales y consecuencias

Tres umbrales por stat, evaluados en el mismo tick (los cruces disparan una vez
por dirección, no por tick):

| Umbral | Feedback | Efecto mecánico |
|---|---|---|
| **≤ 50** — "hungry / thirsty" | hint centrado (`You feel hungry.` / `You feel thirsty.`) — sin audio | ninguno (aviso temprano) |
| **≤ 25** — severo | estómago rugiendo (`hunger.mp3`) emitido **desde el jugador** cada 60-90 s aleatorio — audible por jugadores cercanos (flavor/stealth, §4 de la semilla, convar off) · hint más duro | arranca la `severity` que se reporta a Coagulant (§4) |
| **= 0** — crítico | hint persistente | **con Coagulant**: delegación total (§4), Craving no toca HP. **Sin Coagulant**: daño periódico al HP nativo — hambre 1 HP / 10 s, sed 1 HP / 5 s (se suman si ambos están en 0), × `craving_damage_scale` |

- **Muerte por inanición/deshidratación** (vía fallback): mensaje propio en chat
  (`<name> starved to death.` / `<name> died of dehydration.`); killfeed nativo
  genérico en v1 (killfeed custom = bloque futuro).
- **Respawn** (≠ reconexión, §12): stats a **75 / 75** (tunable) — el loop
  importa desde el primer minuto sin castigar el respawn.
- **CRV-11** — El daño del fallback usa `DMG_GENERIC` con el mundo como attacker — nunca
  suplanta a otro jugador ni dispara lógica de PvP ajena.

---

## 4. Puente Coagulant — contrato mock-first

Coagulant es el dueño clínico del jugador; cuando está, la inanición se vuelve
un **estado clínico**, no un chip de HP. Contrato **esperado** (**CRV-4** — patrón mock-first,
flujo §3 — congelado acá, **pendiente de negociar** con el Block 3 de Coagulant,
cuyo **código actual** (slices 1-3 verificados en juego) expone
tratamiento/getters/eventos pero **todavía ninguna vía de condición externa**):

```lua
-- Firma esperada (a ratificar en Coagulant_Architecture.md §8):
COAGULANT.ApplyExternalCondition(ply, id, severity)
-- id: "starvation" | "dehydration" (namespace del emisor implícito en el id)
-- severity: 0..1 — 0 LIMPIA la condición; Craving la calcula como
--           (25 - stat) / 25 clampeado a [0,1] (empieza a rampear bajo 25)
-- Coagulant decide la semántica clínica (propuesta: suprimir regeneración de
-- sangre con severity alto; la muerte pasa a ser suya).
```

**CRV-17 —** La severity es `(25 − stat) / 25` **clampeada a [0,1]**: vale 0 con el stat en el umbral severo (25) o más, y 1 con el stat en 0 — 0 además LIMPIA la condición. Es función pura de config, cubierta por el selftest.

Reglas del puente (server, `corpus_craving_coagulant.lua`):

1. **CRV-2** — Lazy-check en el tick: `Corpus.GetModule("coagulant")` + **capability check**
   (`isfunction(coag.ApplyExternalCondition)`) + pcall. Coagulant montado pero
   sin la función (versión vieja) = fallback HP igual que sin Coagulant — la
   degradación es por *capacidad*, no por presencia.
2. **CRV-5** — Se llama **on-change** (cuando la severity redondeada a 2 decimales cambia),
   no cada tick — sin spam.
3. **CRV-3** — Mientras la delegación está activa, Craving **no aplica daño de HP** — un solo
   dueño de la muerte a la vez.
4. Dirección única confirmada por Coagulant (§12: "Coagulant **no** detecta a
   Craving"). Consumir los eventos `Coagulant_*` (p.ej. sangrado ↑ sed) queda
   como bloque futuro (§14).

---

## 5. Consumibles v1 — el set contra Cargo

Seis defs stackeables, registradas en `Corpus.OnReady` con lazy-check de Cargo
(sin Cargo se loguea y se apagan — la vía de mundo §7 no las necesita para
existir, comparte la tabla de valores). El registro corre en **ambos realms**
(archivo shared): el snapshot de Cargo solo transporta defs autogen, así que el
cliente necesita registrar las suyas localmente para que el grid las renderice
y el menú ofrezca "Use" (`isfunction(def.onUse)`); el `onUse` en sí solo corre
en server (cita **COR-12**, cuya sede con la causa completa es
`../../corpus/docs/CORPUS_Architecture.md` §5). Categoría única **`food`** (propuesta:
un solo tab en el grid; `Items.RegisterCategory` la auto-registra). Campos
contra el schema real de Cargo (`corpus_cargo_items.lua`, verificado):
`id`, `name`, `weight`, `class = "stackable"`, `category`, `model`, `trivia`,
`onUse = function(ply, ctx) -> true` (**server**; `true` = Cargo consume 1).

| id | name (EN) | +hunger | +hydration | kg (validar vs. JSON GAMMA) | modelo ZONA |
|---|---|---|---|---|---|
| `corpus_craving_bread` | Bread | +30 | 0 | 0.30 | `models/stalker/item/food/bread.mdl` |
| `corpus_craving_sausage` | Sausage | +50 | 0 | 0.45 | `.../food/sausage.mdl` |
| `corpus_craving_tuna` | Canned tuna | +35 | +5 | 0.25 | `.../food/tuna.mdl` |
| `corpus_craving_water` | Water bottle | 0 | +60 | 0.60 | — *(el `drink.mdl` ZONA es una **bebida energética**, no una botella: se reserva para el Soft drink)* |
| `corpus_craving_softdrink` | Soft drink | +5 | +30 | 0.33 | `.../food/drink.mdl` *(único ítem que usa ese modelo)* |
| `corpus_craving_vodka` | Vodka | 0 | +5 | 0.50 | `.../food/vokda.mdl` *(el typo es del pack)* |

- **Consumo instantáneo** en el `onUse`: aplicar restore (clamp a 100), emitir
  sonido (§6), devolver `true`. Los quick slots F1-F4 de Cargo ya dan el flujo
  de uso rápido — no se inventa animación ni progress bar en v1.
- **CRV-8 — Anti-desperdicio**: si el stat relevante está ≥ 98, `onUse` devuelve
  `false` + hint `You are not hungry.` / `You are not thirsty.` — Cargo **no**
  consume la unidad (verificado: solo consume con `true`). Para ítems mixtos
  (tuna, soft drink) manda el stat mayor del def.
- **Vodka** entra como "bebida mediocre" + `trivia` de flavor; sus efectos
  (drunk, screen effects) son bloque futuro (§14) — el gancho queda en el def.
- Rutas ZONA verbatim del pack (inventario: `../../dev/zona_stalkerrp_contenido.md`
  §2.2); los `.mdl` referencian materiales por ruta compilada — **no
  re-namespacear**.

---

## 6. Assets — addon "Corpus S.T.A.L.K.E.R." + fallbacks HL2/CS:S

Los assets STALKER **no viven en este repo** (Craving es MIT/publicable; los
ports GSC no): viven en el addon de contenido **Corpus S.T.A.L.K.E.R.**
(`../corpus-stalker/`, junction en `addons/`). Craving solo referencia rutas.

> *Enmienda 2026-07-14:* ese addon empezó como `corpus_zona_assets`, se renombró a
> `corpus_stalker` (2026-07-13, al sumarse Craving como segundo consumidor) y luego
> se promovió a **séptima raíz del workspace** (`corpus-stalker/`, con su propio git
> y `.gitignore` de assets). Las rutas **de juego** (`models/stalker/…`,
> `sound/zona/…`) no cambiaron nunca — el código de este módulo es indiferente a la
> mudanza; solo la ubicación en disco del addon.

**Helper de resolución** (`corpus_craving_assets.lua`, shared, mismo espíritu
que el `ZonaModel` de Cargo pero por **lista de candidatos** — se queda acá, no
sube a Corpus ni se importa de Cargo: duplicar 10 líneas es más barato que
acoplar dominios):

```lua
-- Devuelve la primera ruta montada de la lista (file.Exists, "GAME");
-- la última entrada es el fallback garantizado del engine.
CRAVING.Assets.Model{ zona_path, css_candidate, hl2_guaranteed }
CRAVING.Assets.Sound{ zona_path, engine_fallback }
```

Candidatos de fallback por ítem (**todas las rutas no-ZONA a validar con
`file.Exists` en la verificación en juego — no se asumen de memoria**; CS:S es
contenido nativo de GMod hoy, decisión del autor):

| Ítem | Candidato CS:S / HL2 | Último fallback (HL2 seguro) |
|---|---|---|
| Bread | `models/props/cs_italy/bread_slice.mdl` (validar) | `models/props_junk/garbage_takeoutcarton001a.mdl` |
| Sausage | `models/props/cs_italy/it_mkt_sausage.mdl` (validar) | `models/props_junk/garbage_takeoutcarton001a.mdl` |
| Canned tuna | — | `models/props_junk/garbage_metalcan001a.mdl` |
| Water bottle | `models/props_junk/garbage_plasticbottle003a.mdl` (botella plástica HL2) | `models/props_junk/glassbottle01a.mdl` |
| Soft drink | — | `models/props_junk/PopCan01a.mdl` |
| Vodka | — | `models/props_junk/glassbottle01a.mdl` |

Sonidos (rutas ZONA verbatim del pack actionsounds):

| Uso | ZONA | Fallback engine (validar) |
|---|---|---|
| Comer (`sound = "eat"`: bread, sausage, canned tuna) | `zona/stalkerrp/actions/interface/inv_food.ogg` | `npc/barnacle/barnacle_gulp1.wav` |
| Beber de botella (`"drink"`/`"vodka"`: water, vodka) | `zona/stalkerrp/actions/interface/inv_vodka.ogg` | `ambient/water/water_spray1.wav` |
| Lata (`"can"`: soft drink) | `zona/stalkerrp/actions/interface/inv_softdrink.ogg` | `ambient/water/water_spray1.wav` |
| Estómago (umbral ≤ 25) | `zona/stalkerrp/hunger.mp3` | *sin fallback: sin el addon este feedback se omite* (no hay equivalente digno en HL2) |

> *Enmienda 2026-07-13 (ronda 2 en juego):* los `eat<1-5>.mp3` del pack quedaron
> descartados —suenan a **tragos**, no a masticado— y con ellos el sorteo aleatorio:
> `Assets.Sound` devuelve el **primer candidato montado** de la lista, sin `math.random`.
> `inv_food.ogg` es el masticado canónico; `inv_vodka.ogg` sirve a agua y vodka por
> igual, y la lata se queda con `inv_softdrink.ogg`.

---

## 7. Comida en mundo — la vía sin inventario

Entity única **`corpus_craving_food`** (`lua/entities/`, shared — la carga el
sistema de scripted_ents, no el manifest; resuelve el módulo en runtime, patrón
Cargo). Spawnable desde el menú Entities → categoría **Corpus** (junto al crate
de Cargo), una entrada por def de §5; el def id viaja en un campo de la entity.

**CRV-15** — Comportamiento al **WALK + E (USE)** — la toma es deliberada, misma convención
de mundo que los drops de Cargo *(enmienda 2026-07-13, pedida por el autor en
la ronda 3: con E pelado la entity se carga como prop HL2 y re-E la suelta; el
gate vive en el propio `ENT:Use` porque el world gate de Cargo solo cubre sus
clases)*:

- **Con Cargo montado**: la unidad entra al inventario (misma experiencia que
  los drops de Cargo; el nombre exacto de la API de give se verifica contra
  `corpus_cargo_inventory.lua` al bajar a código — regla de siempre). Comer
  desde el suelo sigue disponible vía el `onUse` del ítem ya en inventario.
- **Sin Cargo**: consume **in situ** — aplica el restore de la tabla §5, suena,
  desaparece. Esta es la promesa "fallback a comestibles en mundo" de la tabla
  §2 de la arquitectura de Corpus, hecha entity.

Modelo de la entity: el mismo helper §6 (ZONA → CS:S → HL2). Diferidos como
bloques futuros (§14): mapeo de props del mapa como comestibles (D2) y beber
agua del mundo (D3).

---

## 8. Contrato público

**CRV-1** — Bloque CONTRATO del init; todo lo demás es off-contract por convención:

```lua
CRAVING.GetHunger(ply)            -- 0..100 (shared: server lee estado, client lee NW2)
CRAVING.GetHydration(ply)         -- 0..100 (ídem)
CRAVING.Restore(ply, hunger, hyd) -- SERVER; suma con clamp [0,100]; la vía
                                  -- legítima para que otros mods/ítems alimenten
```

Evento (server, `hook.Run`, espejo del patrón `Coagulant_*`):

| Evento | Args | Cuándo |
|---|---|---|
| `Craving_StatCritical` | `ply, stat ("hunger"\|"hydration"), isCritical` | al cruzar el umbral 25, ambas direcciones |

No hay evento por punto de stat (spam); el continuo se lee por getters/NW2. La
tabla §4 de `CORPUS_Architecture.md` **ya recoge** esta superficie (enmienda
2026-07-13: de "—" a "getters + `Craving_StatCritical`").

---

## 9. Net y estado replicado

Sin protocolo propio en v1 — no hay intents de cliente (el consumo pasa por el
`onUse` server-side de Cargo o por el USE de la entity §7):

| Canal | Dirección | Contenido |
|---|---|---|
| `NW2Float "craving_hunger"` | S→todos | 0..100, escrito solo si cambió > 0.1 desde el último set (**CRV-18**) |
| `NW2Float "craving_hydration"` | S→todos | ídem |

(Mismo patrón que el `coagulant_blood` de Coagulant — barato, y las barras de
Cargo lo leen client-side sin tick de red.) Si un bloque futuro necesita
mensajes, van por `Corpus.Net.Register("craving", msg)` →
`corpus_craving_<msg>`, jamás `AddNetworkString` crudo (cita **COR-4**).

---

## 10. Presentación

**No hay HUD propio** (decisión E: "las barras de Cargo están diseñadas justo
para esto"):

1. **Barras de Cargo** (client, lazy-check en `corpus_craving_bars.lua` — firma
   real verificada contra `corpus_cargo_statuspanel.lua`):
   ```lua
   CARGO.StatusPanel.RegisterBar("craving", { id = "hunger",
       label = "Hunger",    getValue = ply → NW2, color = naranja })
   CARGO.StatusPanel.RegisterBar("craving", { id = "hydration",
       label = "Hydration", getValue = ply → NW2, color = celeste })
   ```
2. **Sin Cargo** — feedback indirecto solamente: hints de umbral (§3) + sonidos
   (§6). *Interpretación de la decisión E anotada en la semilla — si el autor
   prefiere una mini-barra standalone, es un archivo client nuevo sin tocar el
   resto del diseño.*
3. **Hints**: `PrintMessage(HUD_PRINTCENTER, ...)` desde server al cruzar
   umbral — una vez por cruce, no por tick. Strings en inglés.
4. **Tab Q** (`Corpus.UI.RegisterTab("craving", …)`): estado del módulo,
   detección de soft-deps (Cargo / Coagulant / addon de assets montado o no),
   convars de admin.

---

## 11. Convars

| Convar | Realm | Default | Efecto |
|---|---|---|---|
| `craving_enabled` | sv | 1 | apaga todo (tick inerte, barras no registran) |
| `craving_decay_scale` | sv | 1.0 | **CRV-16** — multiplicador global de decay; **0 = congela hambre/sed** (el "off suave" para sandbox puro, decisión F) |
| `craving_damage_scale` | sv | 1.0 | multiplicador del daño del fallback sin Coagulant |
| `craving_stomach_sounds` | sv | 1 | on/off estómago audible a otros (§3) |
| `craving_hints` | cl | 1 | on/off hints de umbral |

Los números de balance (§2, §3, §5) viven en tablas de
`corpus_craving_config.lua` — tunables sin tocar lógica (patrón Coagulant §11).

---

## 12. Persistencia

Vía `Corpus.Data`, namespace `craving` (cita **COR-3**, contrato 3 del framework):

- **Clave**: `state_<steamid64>` → `{ hunger, hydration }`.
- **Save**: `PlayerDisconnected` + `ShutDown` (nada de autosave por tick — dos
  floats no lo justifican).
- **Load**: al primer spawn del jugador en la sesión; sin archivo → 100/100.
- **CRV-10 — Reconexión ≠ respawn** (decisión F): reconectar restaura lo persistido
  (cierra el exploit de reconectar para comer gratis); morir aplica el 75/75
  de §3. No hay decay offline en v1.

---

## 13. Mapa de archivos objetivo

Patrón manifest del ecosistema (template Caliber/Coagulant): un único archivo en
`lua/autorun/`, boot diferido a `Initialize`, sonda de Corpus con falla ruidosa,
sub-archivos en `lua/corpus_craving/<realm>/`, prefijo `corpus_craving_*` en todo
lo que carga el engine. Comentarios de código en español (línea
corpus/caliber/coagulant).

| Archivo | Realm | Rol |
|---|---|---|
| `lua/autorun/corpus_craving_init.lua` | shared | entry + registro (`craving`) + bloque CONTRATO (§8) + manifest |
| `shared/corpus_craving_config.lua` | shared | convars + tablas de balance (§2, §3, §5) |
| `shared/corpus_craving_assets.lua` | shared | helper de modelo/sonido por candidatos (§6) |
| `shared/corpus_craving_dev.lua` | shared | `craving_selftest` (clamps, curva de decay pura, defs bien formadas, reporte de soft-deps) |
| `server/corpus_craving_core.lua` | server | estado por jugador, tick de decay, umbrales, daño fallback, respawn, persistencia, NW2 |
| `server/corpus_craving_coagulant.lua` | server | puente mock-first (§4) |
| `shared/corpus_craving_items.lua` | shared | defs §5 contra Cargo (`Corpus.OnReady`) — *enmienda 2026-07-13, primera pasada en juego: nació server-only y las defs jamás llegaban al cliente (el snapshot de Cargo solo trae autogen; el "Use" del menú exige `isfunction(def.onUse)` client-side). Las defs de módulo van en AMBOS realms, patrón de las propias de Cargo* |
| `lua/entities/corpus_craving_food.lua` | shared | comida en mundo (§7) — resuelve el módulo en runtime |
| `client/corpus_craving_bars.lua` | client | barras del StatusPanel (lazy Cargo) |
| `client/corpus_craving_options.lua` | client | tab Q |

---

## 14. No-scope del v1 y bloques futuros

Fronteras duras (no entran nunca por esta vía): stamina/fatiga/sueño
(**Coagulant** — fijado por Cargo §5), radiación (sin módulo dueño),
contenedor/peso/render (**Cargo**), hambre de NPCs (**Cortex**).

Candidatos diferidos, en orden de afinidad (análisis completo en la semilla §4):

1. **Cocinar** (crudo→cocido; carne de mutante ZONA; Workbench de Cargo o fogata)
   → arrastra **comida cruda/agua de río → enfermedad** (necesita condición en
   Coagulant, mismo puente §4) y **caza/harvest**.
2. **Efectos de consumibles** (vodka/drunk, buffs estilo GAMMA, cafeína).
3. **Cantimplora rellenable** (ítem único con blob — Cargo ya lo soporta) + D3
   (beber agua del mundo) + D2 (props del mapa comestibles).
4. **Consumir eventos de Coagulant** (sangrado ↑ sed).
5. Descartados salvo pedido explícito: spoilage (rompe el modelo stackeable),
   farming (fuera del espíritu del ecosistema).

---

## 15. La bajada a código y la verificación — hecho

Los tres puntos que esta sección planeaba **se cumplieron**; quedan como registro.

1. **Estreno del repo** (primera vez con contenido real, roadmap §3 de Corpus):
   scaffold + `CLAUDE.md` + docs propios (`craving_estado.md`,
   `craving_roadmap.txt`, `CHANGELOG.md`, `craving_convenciones_commits.txt`),
   template de los hermanos, apuntando a `corpus_flujo_trabajo.txt`. **Hecho**
   (2026-07-13); el v1 está commiteado y pusheado a `origin/main`.
2. **CHANGELOG** con los 12 parches del v1, hoy **todos en `[APLICADO]`**. En
   `CORPUS_Architecture.md`, la sección resumen + link vive en su §9 (Block 4
   **CERRADO**) y su tabla §4 **ya recoge** la superficie de Craving — la enmienda
   que este doc prometía está aplicada desde el 2026-07-13 (ver §8). **Hecho.**
3. **Verificación**: harness offline (lupa + stubs, `dev/harness_craving.py`) verde
   en ambos realms para la matemática pura → `craving_selftest` → flujo real en
   juego, que **corrió el autor** (flujo §1 PASO 4) en **tres rondas**
   (2026-07-13/14): decay visible en las barras con Cargo, sprint/sobrepeso
   aceleran, comer desde quick slot restaura y suena, `onUse` con barra llena NO
   consume, entity §7 con **WALK+E** al inventario, muerte por sed sin Coagulant
   con mensaje propio, reconexión restaura stats, y con el addon `corpus_stalker`
   los modelos son STALKER mientras que sin él caen a HL2/CS:S. **Hecho.**
   *Única casilla diferida a pedido del autor*: la pata **sin Cargo** (consumo in
   situ de la entity + logs de degradación), que el harness sí cubre; se cierra en
   juego cuando el autor quiera.

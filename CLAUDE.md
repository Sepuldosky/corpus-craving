# CLAUDE.md

Guía para trabajar en **Craving** — el módulo de supervivencia de jugador del ecosistema Corpus (addon GLua para Garry's Mod). Léela antes de tocar código o docs de este repo.

## Qué es

Craving es el módulo de **hambre e hidratación de jugador** del ecosistema Corpus. Es un addon Gmod independiente con su propio git, que **hard-depende** de Corpus (la única dependencia dura del ecosistema) y de nadie más. Detecta a otros módulos en runtime vía `Corpus.GetModule`/`Corpus.HasModule`, nunca los asume: **Cargo** (consumibles + barras + sobrepeso) y **Coagulant** (efectos clínicos de la inanición) son soft-deps con degradación honesta — sin Cargo, comida por entity de mundo y feedback indirecto; sin Coagulant (o con uno incapaz), daño periódico al HP nativo hasta la muerte. Ver §2, §4-§5 de `../corpus/docs/CORPUS_Architecture.md`.

**Estado actual: BLOCK 4 (medio-bloque Craving) CERRADO — v1 VERIFICADO EN JUEGO** (rondas 2-4, 2026-07-13/14: los 12 entries del CHANGELOG en `[APLICADO]`; solo queda opcional la pata sin-Cargo del checklist, ver [`docs/craving_estado.md`](docs/craving_estado.md)). **Encima de eso, SIN VERIFICAR EN JUEGO (2026-08-06): el registro abierto de comidas y el set envasado** — Craving pasó de 6 a **15** consumibles, con `CRAVING.Food.Register` como única vía de alta, la taxonomía `kind`/`tier`/`tags` (§5.1 de la arquitectura) y **9 modelos propios** en `models/corpus_craving/`. Harness verde 254/240, pero los 6 entries están `[PENDIENTE]`. El diseño está cerrado y ratificado (2026-07-13) en [`docs/Craving_Architecture.md`](docs/Craving_Architecture.md) — doc particular autocontenido; la semilla con el registro de decisiones vive en [`docs/Craving_Block4_Semilla.md`](docs/Craving_Block4_Semilla.md). Los números de balance son tunables en `corpus_craving_config.lua`; la lógica no se toca para balancear.

**Regla cardinal:** nada de lógica de dominio sube a Corpus, y la lógica ajena no baja acá: el contenedor/grid/peso es de Cargo, la stamina/vitales/heridas son de Coagulant (Cargo ya lo declaró dueño de la stamina), la radiación no tiene dueño todavía. Craving posee solo el hambre y la sed (cuánto drena, qué restaura cada comida).

## Docs del proyecto — jerarquía de lectura

Antes de tocar código o diseño, lee en este orden (los tres primeros son **docs vivos**):

1. **Estado de HOY** → [`docs/craving_estado.md`](docs/craving_estado.md). Foto del AHORA, ≤1 pantalla. **Léelo ANTES** que la arquitectura.
2. **Rumbo** → [`docs/craving_roadmap.txt`](docs/craving_roadmap.txt). Qué sigue y en qué orden.
3. **Historial de parches** → [`docs/CHANGELOG.md`](docs/CHANGELOG.md). `[PENDIENTE]`/`[APLICADO YYYY-MM-DD]`, nunca se borra ni renumera.
4. **Metodología de trabajo** → [`../corpus/docs/corpus_flujo_trabajo.txt`](../corpus/docs/corpus_flujo_trabajo.txt). **Doc canónico compartido** por todo el ecosistema — no se duplica acá.
5. **Arquitectura del módulo** → [`docs/Craving_Architecture.md`](docs/Craving_Architecture.md) (Block 4: hambre/hidratación v1, ratificado). La frontera general sigue en `../corpus/docs/CORPUS_Architecture.md` §2, §4-§5.
6. **Convenciones de commit** → [`docs/craving_convenciones_commits.txt`](docs/craving_convenciones_commits.txt). Alcances específicos de **este** repo.
7. **Créditos de assets de terceros** → [`docs/CREDITOS.md`](docs/CREDITOS.md). Desde el 2026-08-06 el repo shipea **9 modelos** en `models/corpus_craving/`, portados de *Props Mexicanos* con **permiso explícito del autor** (gbonn) a cambio de crédito y aviso. La atribución es obligación asumida, y **el aviso al autor sigue pendiente**.

## Idioma

- **Código (comentarios): español** (estilo corpus/caliber/coagulant; Cargo es la excepción en inglés). Iguala el del archivo que edites.
- **Strings de cara al jugador (UI, nombres de ítems, hints): inglés** — es el idioma del mod (decisión del autor, fijada en Cargo el 2026-07-10).
- **Docs, commits y logs (`Corpus.Log`): español**; los `<tipo>` de commit en inglés (ver convenciones).

## El workspace multi-repo

Este repo (`corpus-craving/`) es una de **siete** raíces del workspace `corpus.code-workspace`. La raíz `corpus/` es el framework del que todos hard-dependen; las otras cuatro de módulo (`corpus-cortex/`, `corpus-caliber/`, `corpus-coagulant/`, `corpus-cargo/`) son hermanos que se detectan en runtime, nunca se asumen. La séptima, [`corpus-stalker/`](../corpus-stalker/), es de otra naturaleza: no es un módulo sino el **addon de contenido** de la Zona (ver abajo) — los módulos son genéricos, y él es la capa que los convierte en S.T.A.L.K.E.R. Al diseñar integración con mods ajenos, consulta `../dev/mods_workshop_mapa.md` (RECICLAR vs. COMPAT-RUNTIME).

**Assets STALKER:** los modelos/sonidos ZONA que este módulo referencia viven en el addon de contenido **Corpus S.T.A.L.K.E.R.** ([`../corpus-stalker/`](../corpus-stalker/), séptima raíz del workspace, montado por junction en `addons/`). Sus assets son ports de GSC y **no se versionan** (gitignore propio; la MIT cubre el código, no los assets). Este repo jamás los incluye: solo rutas con fallback a HL2/CS:S vía `CRAVING.Assets` (§6 de la arquitectura). *Ojo: hasta el 2026-07-13 ese addon vivía en `dev/corpus_stalker/` — los docs viejos que nombren esa ruta están desactualizados.*

## Mapa de archivos

Un **manifest de carga explícito** (`corpus_craving_init.lua`, único archivo en `lua/autorun/`) registra el módulo, declara el contrato público y hace `include()` en orden determinista — patrón template tomado de Caliber (boot diferido a `Initialize`, sonda `CorpusListo`, falla ruidoso sin framework). Los sub-archivos viven en `lua/corpus_craving/<realm>/`, **fuera** de `lua/autorun/`. La entity va en `lua/entities/` (la carga el sistema de scripted_ents, no el manifest) y resuelve el módulo en runtime, nunca en file-scope.

| Archivo | Realm | Rol |
|---|---|---|
| [`lua/autorun/corpus_craving_init.lua`](lua/autorun/corpus_craving_init.lua) | shared | Entry + registro (`craving`) + **bloque CONTRATO** + manifest |
| [`lua/corpus_craving/shared/corpus_craving_food.lua`](lua/corpus_craving/shared/corpus_craving_food.lua) | shared | **Registro de comidas + taxonomía** (§5.1, enmienda 2026-08-06). `Food.Register` es el **único** escritor de `Config.ITEMS`/`ITEMS_BY_ID` y las mantiene juntas por construcción. `kind`/`tier`/`tags` + `StatOf` + `ModelOf`. **Primero en el manifest** |
| [`lua/corpus_craving/shared/corpus_craving_config.lua`](lua/corpus_craving/shared/corpus_craving_config.lua) | shared | Convars + balance tunable + **las 6 comidas base, dadas de alta por `Food.Register`** (§5) + funciones puras + getters client (NW2) |
| [`lua/corpus_craving/shared/corpus_craving_food_mx.lua`](lua/corpus_craving/shared/corpus_craving_food_mx.lua) | shared | **9 comidas envasadas con modelo propio** (§5.1): 3 comidas, 3 bebidas, 3 alcohólicas. Nombres genéricos, marca en la trivia |
| `models/corpus_craving/` + `materials/models/corpus_craving/` | — | **9 modelos** portados de *Props Mexicanos* (Workshop 3178402491, autor **gbonn**, permiso con crédito), recompilados a escala real. Atribución obligatoria → [`docs/CREDITOS.md`](docs/CREDITOS.md); pipeline en `../dev/phastools/mxfood_build.py` |
| [`lua/corpus_craving/shared/corpus_craving_assets.lua`](lua/corpus_craving/shared/corpus_craving_assets.lua) | shared | Resolución de modelo/sonido por lista de candidatos (§6): ZONA → CS:S → HL2 garantizado |
| [`lua/corpus_craving/shared/corpus_craving_dev.lua`](lua/corpus_craving/shared/corpus_craving_dev.lua) | shared | `craving_selftest` + `craving_status` + `craving_set` (admin) |
| [`lua/corpus_craving/server/corpus_craving_coagulant.lua`](lua/corpus_craving/server/corpus_craving_coagulant.lua) | server | **Puente mock-first** a Coagulant (§4): `ApplyExternalCondition` esperado, degradación por capacidad (`isfunction`), severity on-change |
| [`lua/corpus_craving/server/corpus_craving_core.lua`](lua/corpus_craving/server/corpus_craving_core.lua) | server | Estado por jugador, tick de 5 s (decay + sprint + sobrepeso), umbrales/hints/evento, daño fallback, respawn 75/75, persistencia, espejo NW2 |
| [`lua/corpus_craving/shared/corpus_craving_items.lua`](lua/corpus_craving/shared/corpus_craving_items.lua) | shared | 6 consumibles contra Cargo (`Corpus.OnReady`, categoría `food`) — **shared a propósito** (cita **COR-12**): el snapshot de Cargo solo trae defs autogen; las defs de módulo se registran en ambos realms (lección de la primera pasada en juego) |
| [`lua/entities/corpus_craving_food.lua`](lua/entities/corpus_craving_food.lua) | shared | Comida en mundo (§7): WALK+E → al inventario (con Cargo) o consumo in situ (sin Cargo); E pelado = carry de prop + entradas del spawnmenu |
| [`lua/corpus_craving/client/corpus_craving_bars.lua`](lua/corpus_craving/client/corpus_craving_bars.lua) | client | Barras Hunger/Hydration en el StatusPanel de Cargo (soft-dep) |
| [`lua/corpus_craving/client/corpus_craving_options.lua`](lua/corpus_craving/client/corpus_craving_options.lua) | client | Tab único `Corpus.UI.RegisterTab("craving", …)` + toggle de hints |

## Contratos que no debes romper

1. **Namespace: tabla única registrada** (cita **COR-2** y **COR-7**)**.** Cada archivo abre con `local CRAVING = Corpus.GetModule("craving")` (el init la registró antes). Ningún archivo declara globals sueltos. Depende del invariante by-ref del registro de Corpus.
2. **Detección, nunca asunción** (cita **COR-5**)**.** El hard-dep (Corpus) se detecta en el init (falla ruidoso si falta). Cargo y Coagulant se consultan con lazy-check en el momento del uso, o en `Corpus.OnReady` para wiring de una vez — jamás en file-scope, jamás asumidos.
3. **Degradación por CAPACIDAD, no por presencia** (cita **CRV-2** y **CRV-3**, sede: arquitectura §4)**.** El puente Coagulant exige `isfunction(coag.ApplyExternalCondition)` — un Coagulant montado sin la función cae al mismo fallback que su ausencia (daño HP propio). Mientras la delegación está activa, Craving **no toca HP**: un solo dueño de la muerte a la vez.
4. **Contrato público mínimo congelado** (cita **CRV-1**, sede: arquitectura §8)**.** Solo `CRAVING.GetHunger/GetHydration(ply)`, `CRAVING.Restore(ply, hunger, hyd)` y el evento `Craving_StatCritical(ply, stat, isCritical)` son superficie pública (§8 de la arquitectura). El resto es off-contract por convención, documentado en el bloque CONTRATO del init.
5. **La semántica del consumo es de Craving; el contenedor es de Cargo** (cita **COR-13**)**.** `onUse` corre acá; Cargo solo consume 1 unidad si devuelve `true` (el anti-desperdicio de §5 depende de eso: barra llena → `false`). Nunca metas grid/peso/persistencia de inventario en este repo.
6. **CRV-7 — Los assets GSC no entran a este repo.** Todo modelo/sonido STALKER se referencia por ruta vía `CRAVING.Assets`, nunca por archivo incluido. En **modelos** el último candidato de cada lista es SIEMPRE HL2 vanilla: `Assets.Model` garantiza ruta aunque nada esté montado. En **sonidos** el último candidato es el fallback del engine cuando existe, pero `Assets.Sound` devuelve `nil` si ninguno está montado — el rugido de estómago (`Assets.STOMACH = { "zona/stalkerrp/hunger.mp3" }`) es la **excepción declarada** (§6: no hay equivalente digno en HL2) y el feedback se omite sin el addon; el caller chequea `nil`. **No le agregues un fallback.** Los `.mdl` ZONA no se re-namespacean (referencian materiales por ruta compilada).
7. **CRV-12 — Balance = data.** Los números viven en `corpus_craving_config.lua` (y convars); balancear jamás toca `core`/`coagulant`/`items`.
8. **CRV-6 — Un solo timer.** Todo el decay/umbral/daño pasa por el tick de 5 s de `core` — nada per-frame, nada de timers por jugador.
9. **Prefijo de archivo por módulo** (cita **COR-6**)**:** `corpus_craving_*.lua` en todo lo que cargue el engine.
10. **CRV-13 — `CRAVING.Food.Register` es la única vía de alta de una comida** (sede: arquitectura §5.1)**.** Es el único escritor de `Config.ITEMS` e `ITEMS_BY_ID`, y las mantiene juntas por construcción: antes el índice se armaba una sola vez en file-scope, así que un `table.insert` posterior daba una comida **visible en el grid e inconsumible** (`Consume` y la entity resuelven por el índice). Las 6 originales pasan por el mismo registro — una ruta, no dos.
11. **CRV-14 — La sub-clasificación de comida NO baja a `category` de Cargo** (sede: arquitectura §5.1)**.** La fila de tabs de Cargo está cerrada y una categoría no mapeada cae en **Misc**: registrar `drinks` sacaría las bebidas de la tab Food. La categoría sigue siendo una sola (`food`) y `kind`/`tier`/`tags` viajan como campos extra (cita **CRG-1**: Cargo transporta sin interpretar). **`tier` y `tags` no gobiernan nada todavía** — son el gancho de §14, y que el tag exista no abre el bloque (cita **COA-28**).
12. **CRV-15 — `Food.ModelOf` es la única regla de modelo.** Ruta propia si el ítem declara `model`, cadena de candidatos de §6 si declara `models`. Son **tres** los consumidores (defs de Cargo, entity de mundo, selftest): escrita tres veces, alcanza con que una se olvide de `model` para que ese ítem salga como la cajita de cartón **sin que nada falle**.

## Verificación

No hay test runner de GMod — el patrón es cargar mapa y confirmar (flujo §1 PASO 4), **la corre el autor**. Capas previas:

1. **`craving_selftest`** (consola, realm que lo invoca): config pura (drenaje, sobrepeso, severity), tabla de ítems, resolución de assets, contrato público, round-trip de estado/Consume si hay jugador, reporte de soft-deps. En listen server, realm server: `lua_run Corpus.GetModule("craving")._SelfTest()`.
2. **Harness offline** (LuaJIT vía `lupa` + stubs de GMod, carga el framework real de `corpus/`): mismo patrón que verificó Corpus, Cargo y Coagulant. El script es **permanente**, vive fuera de los repos en [`../dev/harness_craving.py`](../dev/harness_craving.py) y se corre con `python dev/harness_craving.py` desde la raíz del workspace — no se reconstruye por sesión.

Flujo en juego: cargar mapa con corpus/ + craving/ (y opcionalmente cargo/, coagulant/, corpus_stalker) → `craving_selftest` → `craving_set 30 20` y ver hints/estómago → con Cargo: barras en el panel, `Bread` en categoría `food`, comer desde quick slot restaura y suena, con barra llena NO consume → entity `Bread` (Entities → Corpus) con **WALK+E** (E pelado = carry de prop, entry 12) → `craving_set 0 0` sin Coagulant: daño periódico y mensaje de muerte → reconectar restaura stats → tab en Q → Utilities → Corpus → Craving.

Al cerrar un cambio con superficie de runtime: refresca [`docs/craving_estado.md`](docs/craving_estado.md) en sitio y actualiza [`docs/CHANGELOG.md`](docs/CHANGELOG.md) (`[PENDIENTE]` → `[APLICADO YYYY-MM-DD]`, sin borrar ni renumerar).

## Git / commits

Sigue [`docs/craving_convenciones_commits.txt`](docs/craving_convenciones_commits.txt): `<tipo>(<alcance>): <descripción>` — tipo en inglés, descripción en español, minúscula inicial, sin punto final, imperativo. Los 11 alcances de este repo (§3 del doc, que manda): `config`, `assets`, `core`, `coagulant`, `items`, `entity`, `bars`, `options`, `dev`, `init` y `docs`. `chore` **no** es un alcance sino un tipo (§2, junto a `feat`/`fix`/`refactor`/`docs`/`test`).

**Este repo está publicado en GitHub** (`github.com/Sepuldosky/corpus-craving`, público, remote `origin` cableado localmente). No hagas commit ni push salvo que se pida explícitamente.

**No agregues el trailer `Co-Authored-By: Claude` (ni ninguna atribución de co-autoría a Claude/Anthropic) en los mensajes de commit.** Esto sobreescribe el comportamiento por defecto del harness.

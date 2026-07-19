# Craving — Semilla del Block 4 (diseño del dominio de supervivencia)

> **Qué es este doc:** el punto de partida del medio-Block 4 que le toca a Craving
> (hambre/hidratación + fallback HL2; la otra mitad del Block 4, Cargo, ya cerró su
> inventario por su cuenta). NO es la arquitectura — es el inventario de lo ya
> congelado + las **decisiones abiertas** que se resuelven iterando con el autor,
> acá en el repo (decisión 2026-07-13: el diseño de mods no pasa por Desktop;
> precedente: `Coagulant_Block3_Semilla.md`). A medida que las decisiones cierran,
> se anotan en §3 con su resolución; cuando el bloque converge, este doc se
> **vuelca** a `Craving_Architecture.md` (doc particular autocontenido, flujo §2)
> y la semilla queda como registro histórico.
>
> Metodología: planificación densa por bloques + vertical slice
> (`../../corpus/docs/corpus_flujo_trabajo.txt` §2-§3).
>
> **NOTA DE LECTURA (2026-07-19)** — el volcado a `Craving_Architecture.md` **ya
> ocurrió** y el Block 4 está cerrado y verificado en juego: este doc es **registro
> histórico**, no lista de trabajo ni autoridad. Los IDs que aparecen abajo son
> **CITAS** a normas cuya sede es la arquitectura o el framework — la semilla no
> acuña ninguna (cita **FLU-22**: la sede gana; voto del autor del 2026-07-19). Un
> "limpio" del gate de coherencia sobre este archivo se reporta **NO-AUDITABLE POR
> DISEÑO**. Donde el marco fijo de §1 quedó superado por lo implementado, manda la
> arquitectura.

---

## 1. Marco fijo (no se rediscute acá)

- **Frontera** (CORPUS_Architecture.md §2, §4): Craving posee hambre e hidratación
  **de jugador**. No expone interfaz pública a otros módulos (tabla §4: expone "—";
  si el diseño decide emitir eventos, es enmienda explícita a esa tabla). Consume:
  - **Cargo** (soft, **ya disponible y verificado**): consumibles vía
    `Cargo.Items.Register` — Craving owns el `onUse` (devuelve `true` → Cargo
    consume 1 unidad, cita **COR-13**), Cargo owns contenedor/peso/render (§3 y §5
    de la arquitectura de Corpus, cita **CRG-1**). Cargo además ya reserva las
    barras de Craving en su panel de estado: `Cargo.StatusPanel.RegisterBar` con
    `hunger`/`hydration` es el ejemplo literal de su §11.
    *(Superado por lo implementado: la def **y** su `onUse` se registran en AMBOS
    realms — cita **COR-12**, lección de la primera pasada en juego.)*
  - **Coagulant** (soft, opcional, **mock-first** — cita **FLU-17**): efectos de
    inanición/deshidratación sobre la salud. Coagulant está pre-Block 3 y todavía
    no expone eventos clínicos — se congela el contrato esperado y se degrada
    honesto. *(La firma congelada es la de **CRV-4**; su ratificación por el dueño
    sigue abierta como deuda D-5.)*
- **Degradación honesta** (tabla §2): sin Cargo → fallback a comestibles/bebibles
  en mundo (la arquitectura ya promete "Craving ya ship sus fallbacks HL2", §5);
  sin Coagulant → sin efectos clínicos, solo hambre/sed → muerte por la vía del
  HP nativo. Nunca crash, nunca asunción (cita **COR-5**).
  *(Precisado por lo implementado: la degradación es por **CAPACIDAD**, no por
  presencia — cita **CRV-2** y **CRV-3**: un Coagulant montado sin la función cae
  al mismo fallback que su ausencia.)*
- **Reglas de ecosistema** (cita **COR-1** y **COR-10**): nada de dominio ajeno acá
  (grid/peso/quick slots = Cargo; heridas/vitales/**stamina** = Coagulant — Cargo ya
  lo nombró dueño de la stamina en su §5; daño/armadura = Caliber). Persistencia y net entran recién
  cuando el estado y el protocolo diseñados lo justifiquen. Strings de cara al
  jugador en **inglés**; docs/commits/logs en español. Estilo de comentarios de
  código: se fija al estrenar el scaffold (sugerencia: español, línea
  corpus/caliber/coagulant).
- **Sin código antes del diseño.** El scaffold (patrón manifest de Caliber/
  Coagulant: init único en `lua/autorun/`, sub-archivos en
  `lua/corpus_craving/<realm>/`, prefijo `corpus_craving_*`) se baja cuando las
  decisiones A-B estén cerradas como mínimo.

## 2. Referente de diseño y assets ya mapeados

**STALKER Anomaly/GAMMA** como norte conceptual — comida con propiedades múltiples
(sacia, hidrata, efectos secundarios), feedback audible del estado — **adaptado a
Gmod sandbox**: sesiones cortas, sin loop de supervivencia garantizado. El sistema
tiene que ser *tolerable* en sandbox puro (decay lento y configurable, nunca un
timer de muerte agresivo por default) y volverse exigente solo por convar. La
traducción literal de GAMMA (docenas de consumibles, radiación, psy-health) NO es
el objetivo del v1: se diseña el esqueleto que permita crecer hacia allá.

Assets de terceros ya inventariados para este módulo (todo MIT-friendly vía
RECICLAR, ver `../../dev/mods_workshop_mapa.md` y
`../../dev/zona_stalkerrp_contenido.md` §2.2):

- **Modelos de comida** (pack ZONA props): `bread`, `sausage`, `tuna`, `drink`,
  `vokda` *(sic)* + carne de mutante (`meat_boar`, espetón, `boar-leg`).
- **Sonidos** (pack ZONA actionsounds): `actions/eat1-5.mp3` (comer),
  `hunger.mp3` (estómago rugiendo — feedback directo del stat),
  `inv_food.ogg` / `inv_softdrink.ogg` / `inv_vodka.ogg` (consumo desde
  inventario).
- **Stats de referencia**: los JSON de stalker-gamma-db.com en `dev/` traen pesos
  y propiedades reales de los consumibles GAMMA — misma fuente que ya alimentó
  pesos de Cargo.

## 3. Decisiones abiertas

Cada decisión se cierra en conversación con el autor y se anota acá con
`→ RESUELTO:` antes de bajar nada a código. Orden sugerido de discusión: A → F
(las de arriba condicionan a las de abajo).

### A. Modelo de stats — la decisión estructural
- ¿Dos stats (`hunger`, `hydration`) en 0-100 y listo, o queda espacio en el
  modelo para stats registrables a futuro (mismo patrón que las barras de Cargo)?
- Semántica de la escala: ¿100 = saciado que decae hacia 0 (barra que se vacía),
  o 0 = bien y el hambre *crece* (estilo STALKER)? Afecta HUD, mensajes y firma
  de cualquier evento futuro. Sugerencia: 100→0 (consistente con `getValue` 0-100
  de las barras de Cargo).
- Decay: ¿tasa plana por tiempo real, o modulada por actividad (sprint, salto,
  ¿sobrepeso leído de Cargo?)? La hidratación suele decaer más rápido que el
  hambre (ratio típico ~1.5-2×).
- Tick: timer server de baja frecuencia (¿cada 5-10 s?) — nunca per-frame.

→ **RESUELTO (2026-07-13):** escala 100→0 (barra que se vacía), decay modulado
por sprint y por sobrepeso (leído de Cargo vía lazy-check). Detalle y números
tunables en `Craving_Architecture.md` §2.

### B. Consecuencias — la curva de penalización
- Umbrales intermedios antes del 0: ¿qué penaliza el hambre/sed media?
  (candidatos: velocidad, daño de melee, temblor de pantalla, sonido de estómago).
  Ojo frontera: la stamina es de Coagulant — si el debuff natural es "menos
  stamina", eso se delega vía soft-dep, no se implementa acá.
- Al llegar a 0 (standalone): daño periódico contra HP nativo hasta la muerte
  — ¿qué DPS? ¿la sed mata más rápido que el hambre (realista) o igual (simple)?
- Al llegar a 0 (con Coagulant): ¿qué se delega exactamente? Congelar acá la
  firma esperada (mock-first) — p.ej. `coagulant.ApplyCondition(ply,
  "starvation"|"dehydration", severity)` — y validarla con el Block 3 de
  Coagulant cuando cierre.
- ¿Muerte por inanición con feedback propio (mensaje/killfeed) o muerte genérica?
- Respawn: ¿stats al máximo, o a un valor medio para que el loop importe desde
  el minuto uno?

→ **RESUELTO (2026-07-13):** se congela una API mock-first hacia Coagulant para
delegar los efectos clínicos (`Craving_Architecture.md` §4 — pendiente de
ratificar contra el borrador del Block 3 de Coagulant, que hoy no la expone);
fallback sin Coagulant: daño periódico al HP nativo hasta la muerte, con mensaje
propio. Respawn a valor medio (tunable) quedó como propuesta en §3 de la
arquitectura.

### C. Consumibles v1 — el set contra Cargo
- Set inicial alineado a los modelos ZONA disponibles (sugerencia v1, todos
  stackeables, categoría `food` — ¿o `food` + `drink` separadas para el filtro
  del grid?):
  | Ítem (name EN) | Restaura | Nota |
  |---|---|---|
  | Bread | hambre media | — |
  | Sausage | hambre alta | — |
  | Canned tuna | hambre media | lata: ¿requiere abrelatas? (sugerencia: NO en v1) |
  | Water bottle | sed alta | — |
  | Soft drink | sed media + hambre baja | azúcar |
  | Vodka | sed baja/negativa | gancho a futuro (alcohol, §4) — ¿entra en v1 solo como "bebida mala"? |
- Campos del def de Craving sobre el schema de Cargo: `restore_hunger`,
  `restore_hydration` (+ los base `weight`/`model`/`category`; pesos desde los
  JSON de GAMMA). ¿Algún campo de efecto secundario ya en v1 o el schema queda
  mínimo?
- ¿Consumo instantáneo al `onUse` (sonido `eat1-5` + listo) o con tiempo de uso/
  animación? Sugerencia: instantáneo en v1 (los quick slots F1-F4 de Cargo ya
  dan el flujo de uso rápido).
- ¿Sobre-comer: consumir con la barra llena desperdicia el ítem, se bloquea con
  aviso, o permite un pequeño overfill temporal?

→ **RESUELTO (2026-07-13):** set v1 aceptado. Los assets ZONA se usan, pero
viven en el **addon opcional de `dev/`** (renombrado ese mismo día de
`corpus_zona_assets` a **`corpus_stalker` / "Corpus S.T.A.L.K.E.R."**, a pedido
del autor): el repo Craving (MIT, publicable) solo referencia rutas con
fallback, jamás incluye los assets GSC. Detalle en `Craving_Architecture.md`
§5-§6.

> *Enmienda 2026-07-14: ese addon nació como `corpus_zona_assets` dentro de
> `dev/` y ese mismo 2026-07-13 se promovió a **séptima raíz del workspace**
> (`corpus-stalker/`, git propio y público, assets GSC en `.gitignore`). La
> redacción de arriba quedó congelada en la ruta previa — ver
> `Craving_Architecture.md` §5-§6 (enmienda) y CHANGELOG PARCHE 3
> [APLICADO 2026-07-14].*

### D. Fuentes sin inventario — el fallback "HL2"
La arquitectura promete fallback a "entities HL2 comestibles/bebibles", pero HL2
no tiene ítems de comida nativos — hay que definir qué significa:
- **D1. Entities propias** (`corpus_craving_food/water`): spawnables desde el
  menú Entities (categoría Corpus, como el crate de Cargo), E → consume. Con los
  modelos ZONA. Es la vía más honesta y sirve además como drop/spawn de mapa.
- **D2. Mapeo de props existentes**: detectar props "comestibles" del mundo
  (melón/naranja de `props_junk`, máquinas expendedoras HL2 → soft drink). Barato
  de sumar sobre D1, frágil como única vía.
- **D3. Agua del mundo**: beber agua de ríos/lagos con E (¿con riesgo de
  enfermedad a futuro, §4?). Detección de agua en Gmod es factible
  (`WaterLevel`), pero ¿entra en v1?
- Relación con Cargo presente: ¿las entities de mundo se pueden *recoger* al
  inventario (se vuelven el ítem Cargo) además de comerse in situ? Sugerencia:
  sí — mismo patrón dual que los drops de Cargo.

→ **RESUELTO (2026-07-13):** D1 (entities propias) con fallback a modelos
conocidos de **HL2 y CS:S** (CS:S es contenido nativo de GMod hoy — decisión
del autor). D2 (mapeo de props del mundo) y D3 (agua del mundo) quedan
diferidos como bloques futuros. Tabla de modelos con fallback en
`Craving_Architecture.md` §5.

### E. Presentación
- Con Cargo: `StatusPanel.RegisterBar` × 2 (`hunger`, `hydration`) — ya previsto
  por Cargo §11. ¿Íconos? (la firma pide uno, p.ej. `droplet`).
- Sin Cargo: ¿HUD mínimo propio (dos barras discretas, esquina), o solo feedback
  indirecto (sonido `hunger.mp3`, efectos de pantalla al umbral)? Sugerencia:
  HUD mínimo ocultable por convar — sin él, el standalone es a ciegas.
- Notificaciones de umbral (p.ej. "You are hungry" al cruzar 25): ¿chat, hint
  nativo, o solo audio?
- Tab de opciones en el menú Q (`Corpus.UI.RegisterTab("craving", …)`) — mismo
  patrón que todos los módulos: estado + detección de soft-deps + convars client.

→ **RESUELTO (2026-07-13):** barras del StatusPanel de Cargo ("están diseñadas
justo para esto"). No se construye HUD propio: sin Cargo el feedback queda
indirecto (hints de umbral + sonidos), interpretación anotada en
`Craving_Architecture.md` §10 — vetable por el autor.

### F. Config y persistencia
- Convars server: multiplicador global de decay (0 = sistema apagado — el "off"
  honesto para sandbox puro), daño por inanición on/off, ¿decay solo con N+
  jugadores o siempre?
- Persistencia: ¿los stats sobreviven desconexión/cambio de mapa
  (`Corpus.Data.Save("craving", "state_<steamid64>", …)`) o cada conexión nace
  saciada? Sugerencia: persistir — es barato y evita el exploit de reconectar
  para comer gratis. Respawn ≠ reconexión (respawn lo decide B).
- Net: los stats viven en server; ¿replicación al cliente vía snapshot periódico
  (`Corpus.Net`) o NWFloat? Decidir cuando E fije qué necesita ver el cliente.

→ **RESUELTO (2026-07-13):** aceptado en su totalidad — persistencia por
SteamID64, multiplicador de decay con 0 = apagado, respawn ≠ reconexión.
Replicación por `NW2Float` (mismo patrón que el borrador de Coagulant).
Convars en `Craving_Architecture.md` §11.

## 4. Qué más puede entrar en un mod de comer — candidatos de alcance

Inventario de mecánicas del género (STALKER/DayZ/Rust/Project Zomboid), con costo
y sugerencia. Nada de esto se decide acá — es el menú para que el autor marque
v1 / bloque futuro / nunca:

| Candidato | Qué aporta | Costo / dependencias | Sugerencia |
|---|---|---|---|
| **Cocinar** (crudo → cocido) | loop de valor: carne de mutante barata → comida buena; usa los modelos de carne ZONA | punto natural: Workbench de Cargo (recetas ya diseñadas allá) o entity fuego de campamento | bloque futuro cercano |
| **Comida cruda/mala → enfermedad** | riesgo/recompensa de comer crudo o tomar agua de río | necesita superficie de "condición" en Coagulant (mock-first) | bloque futuro, junto a cocinar |
| **Caducidad / spoilage** | la comida se pudre con el tiempo | rompe el modelo stackeable de Cargo (necesitaría instancia/timestamp por ítem) — caro | diferir largo; quizá nunca |
| **Buffs temporales** (estilo GAMMA: energético → correr más, café) | profundidad de elección entre consumibles | sistema de efectos temporales propio; el buff de stamina sería de Coagulant | bloque futuro |
| **Alcohol** (vodka: efectos de pantalla, ¿utilidad?) | flavor STALKER; el asset y el sonido ya existen | screen effects client + estado "drunk"; en STALKER su utilidad es anti-radiación y no hay módulo de radiación | v1 solo como bebida mediocre; efectos en bloque futuro |
| **Cantimplora rellenable** | economía de agua (rellenar en fuentes, D3) | ítem único con blob de instancia (usos restantes) — Cargo ya lo soporta | bloque futuro |
| **Caza / harvest** (matar animal → carne) | cierra el loop con cocinar; sinergia Cortex (mutantes) | interacción con cadáveres NPC + tabla de drops | bloque futuro, tras cocinar |
| **Saciedad máx. con penalidad** (sobrecomer) | anti-spam de comida | trivial (cap + regla en C) | decidir en C, casi gratis |
| **Estómago audible a otros** (`hunger.mp3` emitido, no solo local) | stealth/social: el hambre te delata | trivial (EmitSound server-side) | v1 barato, flavor alto |
| **Sueño / energía / fatiga** | tercer stat clásico del género | **frontera: la stamina/fatiga es de Coagulant** (fijado por Cargo §5) — no es de Craving | fuera de Craving; si existe, es de Coagulant |
| **Radiación en comida** | fidelidad GAMMA | no existe módulo dueño de radiación en el ecosistema | no-scope hasta que exista un dueño |
| **Farming / cultivo** | loop de producción | enorme, fuera del espíritu sandbox del ecosistema | nunca (salvo pedido explícito) |

## 5. No-scope explícito del bloque (fronteras duras)

- **Stamina, fatiga, sueño, vitales** — Coagulant (Cargo ya lo declaró dueño de
  la stamina). Craving los *afecta* vía soft-dep, jamás los posee.
- **Contenedor, peso, quick slots, render de ítems** — Cargo. Craving solo
  registra defs y corre `onUse`.
- **Radiación** — sin módulo dueño; no se inventa acá.
- **Hambre de NPCs** — la frontera dice jugador; NPCs son de Cortex.
- **Cocinar/Workbench** — declarado en §4, se diseña con su propio bloque cuando
  el v1 esté en juego.

## 6. Al cerrar el bloque (checklist, flujo §2)

1. Volcar las resoluciones a `Craving_Architecture.md` (autocontenido).
2. Sección resumen + link en `CORPUS_Architecture.md` (§9: Block 4 → estado real).
3. Primera bajada a código = estreno del repo: scaffold patrón manifest +
   `CLAUDE.md` + docs propios (`craving_estado.md`, `craving_roadmap.txt`,
   `CHANGELOG.md`, `craving_convenciones_commits.txt`), mismo template que los
   hermanos, apuntando a `corpus_flujo_trabajo.txt` sin duplicarlo.
4. CHANGELOG: sesión nueva con los parches, `[PENDIENTE]` hasta verificación en
   juego.

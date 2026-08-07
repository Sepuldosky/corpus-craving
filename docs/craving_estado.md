# Craving — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-08-06 (**comida envasada: registro abierto, taxonomía y 9
modelos propios** — Craving pasa de 6 a 15 consumibles; harness verde 254/240, escala 0,00 %
y los 9 mirados en render, pero **NADA verificado en juego**: los 6 entries están
`[PENDIENTE]` y sin commitear. Antes: sonidos al banco general el 2026-07-24 y **Block 4
CERRADO** el 2026-07-14, todo `[APLICADO]` y pusheado)

---

## Qué existe hoy

- **v1 COMPLETO Y VERIFICADO EN JUEGO** (rondas 2-4, 2026-07-13/14): decay con
  sprint/sobrepeso, umbrales con hints y evento `Craving_StatCritical`, puente
  mock-first a Coagulant (hoy cae al fallback por capacidad, como debe), daño
  fallback con mensaje de muerte propio, 6 consumibles contra Cargo en ambos
  realms (categoría `food`, anti-desperdicio), entity de mundo con spawnmenu y
  **gate WALK+USE** (E pelado = carry de prop, como los drops de Cargo), barras
  en el StatusPanel, tab Q, persistencia por SteamID64, respawn 75/75.
- **Diseño**: decisiones A-F en [`Craving_Block4_Semilla.md`](Craving_Block4_Semilla.md),
  arquitectura ratificada en [`Craving_Architecture.md`](Craving_Architecture.md)
  (§7 enmendado por el gate WALK+USE).
- **Assets — dos fuentes, ninguna asumida** (2026-07-24): los sonidos de consumo
  GENERALES vienen del banco del framework (`corpus/sound/corpus/craving/`, COR-17);
  el addon de contenido [`../../corpus-stalker/`](../../corpus-stalker/) aporta los
  modelos y el estómago (`hunger.mp3`, excepción CRV-7) — sus `zona/stalkerrp/*` de
  comer/beber quedaron RESERVADOS a la comida propia de la Zona. Fallback HL2/CS:S
  por lista de candidatos, sin cambios en el mecanismo.
- **Harness offline**: verde en ambos realms (server 69 / client 55 + los checks
  del gate) — `python dev/harness_craving.py`.

- **Comida: registro abierto + taxonomía + set envasado** (2026-08-06, §5.1 de la
  arquitectura). `CRAVING.Food.Register` es la única vía de alta y mantiene
  `ITEMS`/`ITEMS_BY_ID` juntas; `kind` (cerrado) manda el anti-desperdicio, `tier`
  y `tags` son gancho de §14 y **no gobiernan nada** todavía. **9 modelos propios**
  en `models/corpus_craving/` portados de *Props Mexicanos* (autor gbonn, permiso
  con crédito → [`CREDITOS.md`](CREDITOS.md)), recompilados a escala real. Total:
  **15 consumibles**.

## Pendiente de verificar

- **EN JUEGO, la comida envasada** (sesión 2026-08-06, lo único bloqueante):
  los 9 en el grid **con su modelo** (no la cajita), comer/beber con sus sonidos,
  la entity de mundo con modelo propio, y el anti-desperdicio eligiendo el stat por
  `kind`. Offline: harness 254/240 y **9/9 en las tres columnas del `check`**
  (escala, flags del header, UV).
- **RE-VERIFICAR los 5 parches de asset** (7 a 11 del CHANGELOG), salidos de **tres**
  pasadas del autor: normal map sin píxeles negros, `$mostlyopaque` en las dos
  botellas de cola, **UV volteadas**, **winding invertido** (se veía el interior del
  modelo) y **los 9 girados un cuarto de vuelta**. Offline están las cinco columnas
  del `check` en 9/9 — escala, flags, UV, winding y orientación, todas **contra el
  `.mdl` original** — y el render comparativo original-vs-portado sale
  indistinguible; pero el juez de un asset sigue siendo el juego.
- **Sonidos del banco general** (sesión 2026-07-24): **confirmado en juego** — los 6
  consumibles suenan desde `corpus/craving/*` (masticado/tragos/lata/vodka distintos); el
  vodka usa el banco de Corpus, no el original de la Zona (buscado). `[APLICADO]`.
- Nada más bloqueante. **Pata sin-Cargo** (checklist §7, diferida a pedido del autor):
  logs de degradación + consumo in situ de la entity con WALK+E. La cubre el
  harness offline; se cierra en juego cuando el autor quiera.

## Remanentes / deuda conocida

- **El puente Coagulant es mock-first**: `ApplyExternalCondition` no existe aún en
  Coagulant (0 hits en su `lua/`). Su Block 3 está **CERRADO** (los 4 slices
  verificados en juego, 2026-07-20), pero la firma sigue sin ratificarse — es la
  deuda D-5, a negociar cuando se retome el cross-repo. La degradación por capacidad
  cubre el hueco, verificada en juego.
- **Footprints del grid** (sausage 1×1, bread 2×1, botellas 1×2): autogen de Cargo
  por bounds del modelo. Si el autor quiere otros: `cargo_icon_edit` (override por
  def) o `def.size` explícito — data, no código.
- Sin `addon.json` (igual que el resto del ecosistema).
- Efectos de vodka, cocinar, cantimplora, D2/D3: diferidos por diseño
  (arquitectura §14) — no son deuda, son bloques futuros.

## Próximo paso

1. Negociar `ApplyExternalCondition` con Coagulant cuando su Block 3 cierre.
2. Después, por afinidad: cocinar + comida cruda/enfermedad (arquitectura §14).

---

*Rumbo / qué sigue → [`craving_roadmap.txt`](craving_roadmap.txt). Diseño →
[`Craving_Architecture.md`](Craving_Architecture.md). Metodología →
[`../../corpus/docs/corpus_flujo_trabajo.txt`](../../corpus/docs/corpus_flujo_trabajo.txt).*

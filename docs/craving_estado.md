# Craving — Estado de HOY

> **Foto del AHORA**, volátil. Es lo primero que se lee al retomar el módulo —
> **antes** que el doc de arquitectura. Se actualiza **en sitio** (no se agregan
> secciones ni historial). El historial vive en `git` + [`CHANGELOG.md`](CHANGELOG.md).
> Si crece de una pantalla, está mal redactado: recortar.

**Última actualización:** 2026-07-14 (**Block 4 CERRADO**: v1 verificado en juego en
tres rondas; los 12 entries del CHANGELOG en `[APLICADO]`. El v1 está **commiteado y
pusheado a `origin/main`**)

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
- **Assets**: el addon de contenido **Corpus S.T.A.L.K.E.R.** (ahora séptima raíz
  del workspace, [`../../corpus-stalker/`](../../corpus-stalker/)) es autocontenido
  para Craving — modelos + los 4 sonidos de consumo/hambre; fallback HL2/CS:S por
  lista de candidatos, verificado. Las rutas de juego no cambiaron con la mudanza.
- **Harness offline**: verde en ambos realms (server 69 / client 55 + los checks
  del gate) — `python dev/harness_craving.py`.

## Pendiente de verificar

- Nada bloqueante. **Pata sin-Cargo** (checklist §7, diferida a pedido del autor):
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

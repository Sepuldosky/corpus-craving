# Craving

Módulo de **supervivencia de jugador** del ecosistema
[Corpus](https://github.com/Sepuldosky/corpus) para **Garry's Mod**: hambre e hidratación,
con consumibles propios y comida en el mundo. Addon independiente que **hard-depende** de
Corpus (la única dependencia dura del ecosistema) y detecta a los demás módulos en runtime,
nunca los asume.

> **Estado: v1 en código y verificado en juego** (Block 4 cerrado, 2026-07-14). El rumbo del
> ecosistema vive en el
> [roadmap de Corpus](https://github.com/Sepuldosky/corpus/blob/main/docs/corpus_roadmap.txt).

## Características

- **Decay de hambre e hidratación** en un tick de servidor de 5 s (nada per-frame): drenaje
  base que el sprint y el sobrepeso de Cargo aceleran. Los números son tunables por convar
  (`craving_decay_scale`, `craving_damage_scale`, …) — balancear no toca la lógica.
- **Umbrales con feedback**: aviso a ≤ 50 (hint centrado), crítico a ≤ 25 (hint + rugido de
  estómago audible para los de al lado) y el evento `Craving_StatCritical` para que otros
  módulos reaccionen.
- **Seis consumibles** (Bread, Sausage, Canned tuna, Water bottle, Soft drink, Vodka)
  registrados contra el framework de ítems de Cargo, categoría `food`. Con la barra llena,
  la comida **no se gasta**.
- **Comida en el mundo** como entity propia, con entradas en el spawnmenu: **caminando + E**
  la manda al inventario si Cargo está montado, o la consume en el sitio si no.
- **Barras** de Hunger/Hydration en el StatusPanel de Cargo y **tab propio** en el menú Q.
- **Muerte por inanición o sed**: con Coagulant se le delega la condición clínica; sin él (o
  con uno incapaz), daño periódico al HP con mensaje de muerte propio.
- **Persistencia** por SteamID64 vía `Corpus.Data`; el respawn devuelve 75/75.
- Modelos y sonidos salen del addon de contenido **Corpus S.T.A.L.K.E.R.** si está montado;
  si no, caen a **HL2/CS:S** por lista de candidatos (los modelos siempre tienen fallback;
  los sonidos sin equivalente digno —el rugido de estómago— simplemente se omiten).

En diseño / sin implementar: cocinar, efectos de consumibles (la borrachera del vodka, buffs),
cantimplora rellenable.

## Dependencias

- **Corpus** (dura — sin él, Craving no arranca).
- **Cargo** (soft — comida y agua como consumibles de inventario, barras en el StatusPanel,
  sobrepeso que acelera el drenaje). Sin él, la comida se come desde la entity de mundo del
  propio módulo.
- **Coagulant** (soft, opcional — inanición/deshidratación como condición clínica). Sin él,
  daño periódico al HP hasta la muerte.

El idioma de cara al jugador (UI, ítems, hints) es **inglés**; docs y commits en español.

## Documentación

- [`docs/Craving_Architecture.md`](docs/Craving_Architecture.md) — arquitectura del módulo.
- [`docs/craving_estado.md`](docs/craving_estado.md) · [`docs/craving_roadmap.txt`](docs/craving_roadmap.txt) · [`docs/CHANGELOG.md`](docs/CHANGELOG.md) — docs vivos.
- [`CLAUDE.md`](CLAUDE.md) — guía para asistencia con Claude Code.

Diseño de referencia del ecosistema y grafo de dependencias →
[`CORPUS_Architecture.md`](https://github.com/Sepuldosky/corpus/blob/main/docs/CORPUS_Architecture.md)
(§1-§2, §9).

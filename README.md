# Craving

Módulo de **supervivencia de jugador** del ecosistema
[Corpus](https://github.com/Sepuldosky/corpus) para **Garry's Mod**: hambre e hidratación,
con fallback a los comestibles/bebibles de HL2. Addon independiente que **hard-depende** de
Corpus (la única dependencia dura del ecosistema) y detecta a los demás módulos en runtime,
nunca los asume.

> **Estado: sin empezar.** Este repo aún no tiene código. Craving es hoja del rollout y
> puede arrancar en cuanto reciba su bloque de diseño: su dependencia principal (el
> framework de consumibles de [Cargo](https://github.com/Sepuldosky/corpus-cargo)) ya está
> en código y verificada. El rumbo del ecosistema vive en el
> [roadmap de Corpus](https://github.com/Sepuldosky/corpus/blob/main/docs/corpus_roadmap.txt).

## Dependencias previstas

- **Corpus** (dura — framework del ecosistema).
- **Cargo** (soft — comida y agua como consumibles de inventario). Sin él, fallback a
  entities HL2 comestibles/bebibles.
- **Coagulant** (soft, opcional — inanición/deshidratación afectan la salud). Sin él, solo
  hambre/sed → muerte.

Diseño de referencia del ecosistema y grafo de dependencias →
[`CORPUS_Architecture.md`](https://github.com/Sepuldosky/corpus/blob/main/docs/CORPUS_Architecture.md)
(§1-§2, §9).

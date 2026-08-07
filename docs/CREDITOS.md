# Créditos

Craving **incluye modelos 3D de terceros**. El código es del proyecto; **los modelos no**, y su
autor conserva sus derechos. Esta página existe para que el crédito sea explícito y verificable, y
porque el autor lo pidió por escrito al publicar el addon.

> **Si sos el autor de alguno de estos assets y querés que se retiren, se retiran.** Sin discusión
> y sin condiciones. Abrí un issue o escribí, y sale en la siguiente versión.

> Los assets **STALKER** que este repo referencia por ruta (`models/stalker/...`) **no están acá**:
> viven en el addon de contenido [`corpus-stalker`](../../corpus-stalker/) y no se versionan
> (**CRV-7**). Esta página es sobre lo que el repo **sí** incluye.

---

## Comida envasada — 9 modelos

- **Autor:** **gbonn**
- **Fuente:** *Props Mexicanos*, Steam Workshop
  <https://steamcommunity.com/sharedfiles/filedetails/?id=3178402491>
- **Permiso:** el autor lo da explícitamente en la descripción del addon — *"Feel free to use my
  props or any model from my Workshop page to create maps. If you make something that includes my
  content, please let me know."* El aviso al autor es parte del pedido y queda pendiente de que el
  autor del proyecto lo curse.
- **Rutas:** `models/corpus_craving/`, `materials/models/corpus_craving/`

**Están modificados**, y decirlo es parte de acreditar honestamente:

- **reescalados a tamaño real.** Los originales están a 2–3× (el pan medía 37 u ≈ 94 cm). El factor
  de cada uno sale de la medición de su malla contra el tamaño del producto real y está escrito en
  el `.qc` de cada modelo;
- **recompilados con `$cdmaterials` propio** (`models/corpus_craving/`) en vez del `models/gbonn/`
  horneado en el original — si no, habría que shipear materiales dentro de la carpeta de otro
  addon y pisarse con él;
- **texturas recomprimidas**: 101 MB → 7,8 MB, sin pérdida visible. Una sola (`cervezacorona_bump`)
  eran 85 MB en 4096×4096 **sin comprimir**. Se bajó el techo a 1024 y se pasó a DXT preservando el
  canal alfa donde el `.vmt` lo consume (`$alphatest`, `$normalmapalphaenvmapmask`).

El pipeline completo es reproducible: `python dev/phastools/mxfood_build.py build`.

| `.mdl` | Qué es | Original | Alto |
|---|---|---|---|
| `sliced_bread` | bolsa de pan de caja blanco | `panbimbo` | 30,0 cm |
| `sweet_bun` | concha (pan dulce) | `concha` | 12,0 cm |
| `instant_noodles` | vaso de fideos instantáneos | `maruchan` | 11,5 cm |
| `milk_carton` | cartón de leche de 1 L | `nutrileche` | 23,5 cm |
| `cola_bottle` | botella de cola de 2,5 L (2 skins) | `cocacola` | 33,0 cm |
| `cola_glass` | botella de cola de vidrio | `cocavidrio` | 24,0 cm |
| `beer_can` | lata de cerveza | `cervezatecate` | 12,3 cm |
| `beer_bottle` | botella de cerveza clara | `cervezacorona` | 24,5 cm |
| `beer_bottle_big` | botella de cerveza de 940 ml | `caguama` | 30,0 cm |

Los **nombres de ítem en el juego son genéricos** ("Sliced bread", "Canned beer") y la marca del
producto vive en la trivia: Craving es un módulo genérico y las marcas son color, no taxonomía
(decisión del autor, 2026-08-06). Los modelos, claro, muestran la marca que el autor les pintó.

En el addon original hay **31 props**; los otros 22 no se portaron porque no son comestibles. El
censo completo de qué es cada uno está en `dev/other/props mexicanos/` (desempacado del `.gma`).

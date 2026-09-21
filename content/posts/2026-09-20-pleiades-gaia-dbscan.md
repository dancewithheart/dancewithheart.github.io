---
title: Recovering the Pleiades from Gaia DR3 with DBSCAN
date: 2026-09-20
---

I wanted to check how Python machine learning tools would handle real world data, not just toy problems.
There is substantial amount of astronomy data in [Gaia DR3](https://www.cosmos.esa.int/web/gaia/data-release-3), so here is attempt to answer the question:
can an unsupervised clustering algorithm like [DBSCAN](https://scikit-learn.org/stable/modules/generated/sklearn.cluster.DBSCAN.html) can reconstruct [Pleiades](https://en.wikipedia.org/wiki/Pleiades) from this dataset.

![](content/img/pleiades/pleiades.png)

## ADQL query for Gaia

Stars in the same open cluster are roughly at the same distance and move through space together.
Gaia measures:
- `parallax` - shift in a star’s position on the sky (used to calculate distance = 1000/parallax)
- `pmra` and `pmdec` - proper motion across the sky each year

Therefore we have
```Python
FEATURES = ["parallax", "pmra", "pmdec"]
```

Instead of downloading whole Gaia dataset, we can ask for part of the data using [ADQL](https://www.ivoa.net/documents/ADQL/20180112/PR-ADQL-2.1-20180112.html) - 
SQL modified to handle astronomical data:
```sql
SELECT
   parallax, pmra, pmdec, ...
FROM gaiadr3.gaia_source_lite
```

additional fields from query includes:
- astrometric parameters: `ra` (right ascension), `dec` (declination) using `ICRS` (International Celestial Reference System)
- photometric parameters:
  - `phot_g_mean_mag` (average magnitude measured by Gaia G-band telescope)
  - `bp_rp` (BP − RP Color; Express stellar temperature and spectral type (color index). Higher numbers mean redder, cooler stars; lower numbers mean bluer, hotter stars)
- `ruwe` (renormalized unit weight error) - data quality; above 1.4 is unreliable

and further restrict data to 1 cone TODO
```sql
WHERE
  1 = CONTAINS(POINT('ICRS', ra, dec), CIRCLE('ICRS', 56.87125, 24.10493, 1.0))
   AND phot_g_mean_mag < 18.0
   AND ruwe < 1.4
   AND parallax_over_error >= 10.0
   AND parallax >= 3.0
   AND parallax <= 12.0'
   ...
```
The query does not select stars using the known Pleiades proper motion.
It only chooses a region of sky and broad measurement-quality and distance limits.

Query can be sent using [`launch_job_async`](https://astroquery.readthedocs.io/en/stable/api/astroquery.gaia.GaiaClass.html#astroquery.gaia.GaiaClass.launch_job_async) from [astroquery](https://astroquery.readthedocs.io/en/latest/) library.

Data from response is cached as CSV ([datasets.py](https://github.com/dancewithheart/astronomy_visual/blob/main/datasets.py)) - so we have to query Gaia only once:

```sh
python -m experiments.pleiades --refresh
```

```
[Gaia] job submitted: 884c1899-b4de-11f1-a4dd-bc97e148b76b-O
[Gaia] phase=EXECUTING, elapsed=5.8s
...
[Gaia] phase=COMPLETED, elapsed=466.9s
[Gaia] downloading results...
[Gaia] received 720 rows
```

## DBSCAN and StandardScaler

I used DBSCAN algorithm. It groups points form dense regions and labels isolated points as noise.
This fits the problem well because most stars in the query are expected to be unrelated field stars.

Before clustering I standardize the three features.
Otherwise a feature with numerically larger values would dominate the distance calculation.

```python
features = StandardScaler().fit_transform(
    stars[FEATURES]
)

labels = DBSCAN(
    eps=0.25,
    min_samples=15,
).fit_predict(features)
```

## Results

The algorithm found one very compact group in proper-motion and parallax space.

```
Input:       720 stars
Candidate:   392 stars
Parallax:    7.36 mas
Proper motion:
    pmra   ≈ +19.75 mas/year
    pmdec  ≈ -45.37 mas/year
Distance:    ≈ 136 pc
```

The published Gaia analysis obtains a Pleiades distance of about 135.7 pc,
so simple estimate: 1000 / 7.36 mas is remarkably close.

## Did DBSCAN really found Pleiades?

Proper motion: candidate stars form a compact moving group.

![](content/img/pleiades/proper-motion-clusters.png)

Parallax: candidates form a narrow peak around 7.36 mas.

![](content/img/pleiades/parallax.png)

Colour–magnitude diagram: the candidates form a striking stellar sequence.

![](content/img/pleiades/candidate-cmd.png)

Position on the sky: candidates are more concentrated toward the Pleiades centre.

![](content/img/pleiades/cmd-candidate-vs-field.png)

## Publications

There is study from 2023 that used this approach [A Gaia astrometric view of the open clusters Pleiades, Praesepe, and Blanco 1]() by Jeison Alfonso and Alejandro García-Varela

# dancewithheart.github.io

Apart from standard:
```sh
cabal update
cabal build
cabal test
```

Build and run locally:
```sh
cabal run blog clean
cabal run blog build
cabal run blog -- rebuild
python3 -m http.server -d _site 8000
```

Open http://localhost:8000

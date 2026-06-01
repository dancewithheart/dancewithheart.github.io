---
title: Haskell supply-chain security with cabal-plan-submit
date: 2026-05-31
---

Making cabal-audit reports actionable with dependency paths,
SARIF enrichment,
GitHub Dependency Submission,
and deprecated package detection using [cabal-plan-submit](https://github.com/dancewithheart/cabal-plan-submit).

## [Problem](https://lamport.azurewebsites.net/pubs/state-the-problem.pdf)
[cabal-audit](https://github.com/MangoIV/cabal-audit) reports vulnerabilities in dependencies
based on security advisories like [Haskell advisories](https://haskell.github.io/security-advisories/),
but open-source software maintainers often need to know:

- why is this dependency present?
- is it direct or transitive?
- if this is a deprecated dependency is there a known replacement?
- is this a test/spec/benchmark dependency or production one?
- what deprecated dependencies do I have?

## Demo target
[persistent](https://github.com/yesodweb/persistent) a realistic datastore interface for Haskell.

## Example cabal-audit with cabal-plan-submit

With locally cloned and built `cabal-audit` and `persistent` one can run:
```sh
~/persistent$ ~/cabal-audit/result/bin/cabal-audit
```
and get report including:
```sh
Hackage package cryptonite at version 0.30 is vulnerable for:
  HSEC-2025-0002 "Double Public Key Signing Function Oracle Attack on Ed25519"
  published: 2025-11-14 14:45:34 UTC
  https://haskell.github.io/security-advisories/advisory/HSEC-2025-0002
  No fix version available
  crypto
```

There are 2 issues here:

* the report says `No fix version available`
* persistent does not depend directly on cryptonite

We can check in [Haskell advisory for HSEC-2025-0002](https://haskell.github.io/security-advisories/advisory/HSEC-2025-0002)
that problem exists also in `crypton` in versions `>=0.31 && <1.0.3`.

To investigate further using `cabal-plan-submit` why this dependency is present: 
```sh
~/cabal-plan-submit$ cabal run cabal-plan-submit -- why ~/persistent/dist-newstyle/cache/plan.json cryptonite
```
produces:
```text
cryptonite
paths:
  persistent-mongoDB-2.13.1.0
   -> mongoDB-2.7.1.4
   -> cryptohash-0.11.9
   -> cryptonite-0.30
```

and combine this with analysis of deprecated dependencies:
```sh
curl -L \
  https://raw.githubusercontent.com/commercialhaskell/all-cabal-metadata/master/deprecated.yaml \
  -o deprecated.yaml

~/cabal-plan-submit$ cabal run cabal-plan-submit -- inspect-deprecated --production-only ~/persistent/dist-newstyle/cache/plan.json deprecated.yaml
```
that shows:
```text
deprecated packages:
  cryptonite-0.30
    relationship: indirect
    replacements:
      - cryptohash-md5
      - cryptohash-sha1
      - cryptohash-sha256
      - cryptohash-sha512
      - crypton
    used by path: persistent-mongoDB-2.13.1.0 -> mongoDB-2.7.1.4 -> cryptohash-0.11.9 -> cryptonite-0.30
  data-binary-ieee754-0.4.4
    relationship: indirect
    replacements:
      - binary
      - cereal
    used by path: persistent-mongoDB-2.13.1.0 -> bson-0.4.0.1 -> data-binary-ieee754-0.4.4
```

We discovered that cryptonite is `deprecated` and potential replacements are `crypton` and vulnerability is fixed there.
We even know that we should target `mongoDB` or `cryptohash`. Story continues in [mongodb #161](https://github.com/mongodb-haskell/mongodb/pull/161)

## Filtering noisy test/benchmark dependencies

Previously we used `-production-only` to ignore local modules that are most likely relevant for benchmarking and tests,
we can get all of them by:
```
~/cabal-plan-submit$ cabal run cabal-plan-submit -- inspect-deprecated ~/persistent/dist-newstyle/cache/plan.json deprecated.yaml
```
which is a bit more noisy:
```text
deprecated packages:
  cryptonite-0.30
    relationship: indirect
    replacements:
      - cryptohash-md5
      - cryptohash-sha1
      - cryptohash-sha256
      - cryptohash-sha512
      - crypton
    used by path: persistent-mongoDB-2.13.1.0 -> mongoDB-2.7.1.4 -> cryptohash-0.11.9 -> cryptonite-0.30
  data-binary-ieee754-0.4.4
    relationship: indirect
    replacements:
      - binary
      - cereal
    used by path: persistent-mongoDB-2.13.1.0 -> bson-0.4.0.1 -> data-binary-ieee754-0.4.4
  old-time-1.1.1.0
    relationship: indirect
    replacement: time
    used by path: persistent-2.18.1.0 -> quickcheck-instances-0.4 -> old-time-1.1.1.0
  system-fileio-0.3.16.7
    relationship: direct
    replacement: directory
    used by path: persistent-sqlite-2.13.3.1 -> system-fileio-0.3.16.7
  system-filepath-0.4.14.1
    relationship: direct
    replacement: filepath
    used by path: persistent-sqlite-2.13.3.1 -> system-filepath-0.4.14.1
```

Originally report mentioned also `old-time` that was pulled through unix-time:
```
cabal run cabal-plan-submit -- why --production-only ~/persistent/dist-newstyle/cache/plan.json old-time
old-time
paths:
  persistent-2.18.1.0 -> fast-logger-3.2.6 -> unix-time-0.4.17 -> old-time-1.1.1.0
  persistent-mongoDB-2.13.1.0 -> mongoDB-2.7.1.4 -> tls-2.4.1 -> unix-time-0.4.17 -> old-time-1.1.1.0
  persistent-mysql-2.13.1.6 -> monad-logger-0.3.42 -> fast-logger-3.2.6 -> unix-time-0.4.17 -> old-time-1.1.1.0
  persistent-postgresql-2.14.3.0 -> monad-logger-0.3.42 -> fast-logger-3.2.6 -> unix-time-0.4.17 -> old-time-1.1.1.0
  persistent-qq-2.12.0.7 -> persistent-2.18.1.0 -> fast-logger-3.2.6 -> unix-time-0.4.17 -> old-time-1.1.1.0
  persistent-redis-2.13.0.2 -> hedis-0.15.2 -> tls-2.4.1 -> unix-time-0.4.17 -> old-time-1.1.1.0
  persistent-sqlite-2.13.3.1 -> monad-logger-0.3.42 -> fast-logger-3.2.6 -> unix-time-0.4.17 -> old-time-1.1.1.0
```
but after merging https://github.com/kazu-yamamoto/unix-time/pull/68 this is no longer the case:
```
cabal run cabal-plan-submit -- why --production-only ~/persistent/dist-newstyle/cache/plan.json old-time
no path found to old-time
```
Note we used here again `--production-only` as without it we have:
```
cabal run cabal-plan-submit -- why ~/persistent/dist-newstyle/cache/plan.json old-time
old-time
paths:
  persistent-2.18.1.0 -> quickcheck-instances-0.4 -> old-time-1.1.1.0
  persistent-mongoDB-2.13.1.0 -> persistent-test-2.13.2.1 -> quickcheck-instances-0.4 -> old-time-1.1.1.0
  persistent-mysql-2.13.1.6 -> quickcheck-instances-0.4 -> old-time-1.1.1.0
  persistent-postgresql-2.14.3.0 -> quickcheck-instances-0.4 -> old-time-1.1.1.0
  persistent-sqlite-2.13.3.1 -> persistent-test-2.13.2.1 -> quickcheck-instances-0.4 -> old-time-1.1.1.0
  persistent-test-2.13.2.1 -> quickcheck-instances-0.4 -> old-time-1.1.1.0
```

## [Supply-chain security](https://docs.github.com/en/code-security/concepts/supply-chain-security/about-supply-chain-security) on Github and Haskell


According to [Zero Day Clock](https://zerodayclock.com/), 74% of newly disclosed vulnerabilities in 2026 are estimated to have no known fix at disclosure time.
Public package registries also have real infrastructure costs, so “just update everything immediately” is not always the best operational answer (see [1](https://www.sonatype.com/blog/open-is-not-costless-reclaiming-sustainable-infrastructure), [2](https://opensourcesecurity.io/2025/2025-10-sustaining-repos-brian-fox/)).

For many ecosystems Github can automatically figure out what are dependencies of given project,
so information from security advisories can be used by Dependabot and automatic PRs for dependencies where known vulnerabilities are can be created.

This works for Rust, Python, Java unfortunately GitHub does not understand dependencies in Haskell and Scala. 
See discussions here: [security-advisories #11](https://github.com/haskell/security-advisories/issues/11)
and [security-advisories #205](https://github.com/haskell/security-advisories/issues/205).

Can we do better? cabal-plan-submit aims to improve this in two ways

### Use GitHub dependency submission

`cabal-plan-submit` reads resolved cabal plan and convert it into snapshot accepted by [GitHub dependency submission API](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/using-the-dependency-submission-api)
This can be configured on workflow like so:
```
  - name: Checkout cabal-plan-submit
    uses: actions/checkout@v6
    with:
      repository: dancewithheart/cabal-plan-submit
      path: cabal-plan-submit
      
  - name: Submit dependency snapshot
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      REPO: ${{ github.repository }}
    run: |
      owner="${REPO%/*}"
      repo="${REPO#*/}"

      response="$(
        curl \
          --fail-with-body \
          -X POST \
          -H "Accept: application/vnd.github+json" \
          -H "Authorization: Bearer $GITHUB_TOKEN" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          "https://api.github.com/repos/$owner/$repo/dependency-graph/snapshots" \
          --data-binary @snapshot.json
      )"

      echo "$response" | jq .
```
After this on you project `Insights` > `Dependency graph` should be populated with dependencies:

![](/img/dependency_graph.png)

### Enrich SARIF output from cabal-audit

Report with vulnerabilities from dependencies can be exported in SARIF format and submitted to GitHub as code scan.
This is very nicely automated thanks to [haskell-security-action](https://github.com/blackheaven/haskell-security-action).

cabal-plan-submit thanks to knowledge of resolved dependencies can enrich this SARIF report with:
- precise locations (see [haskell-security-action #1](https://github.com/blackheaven/haskell-security-action/issues/1) and [haskell-security-action #5](https://github.com/blackheaven/haskell-security-action/issues/5))
- information if dependency is direct or transitive ([cabal-audit #68](https://github.com/MangoIV/cabal-audit/issues/68))

![](/img/code_scan_results.png)

on the details for vulnerability you can see GitHub compute severity from CVSS vector (recently improved via [security-advisories #322](https://github.com/haskell/security-advisories/pull/322) and links CVEs thanks to exposed tags (see [cabal-audit #75](https://github.com/MangoIV/cabal-audit/pull/75)).

![](/img/vuln_details2.png)

`cabal-plan-submit` can also generate information about deprecated dependencies, and tags to search:

![](/img/search_tag_deprecated.png)

## Ecosystem integration

`cabal-plan-submit` is intended to complement & integrate (in [Milestone 2](https://github.com/dancewithheart/cabal-plan-submit/milestone/2)) with existing Haskell security tooling.

Current discussions:

- `cabal2nix`: using Hackage deprecation metadata and dependency-path logic in Nix-based Haskell workflows: [cabal2nix #128](https://github.com/NixOS/cabal2nix/issues/128)
- `cabal-audit`: exposing useful SARIF tags and advisory metadata for GitHub Code Scanning: [cabal-audit #75](https://github.com/MangoIV/cabal-audit/pull/75)
- `haskell-security-action`: optional enrichment of cabal-audit SARIF using Cabal `plan.json`: [haskell-security-action #9](https://github.com/blackheaven/haskell-security-action/issues/9)

## Future directions

Current workflow:

- `cabal-audit` produces SARIF with vulnerability reports
- `cabal-plan-submit` enriches it using Cabal's resolved `plan.json`
- `cabal-plan-submit` can also report deprecated dependencies and known replacements.

This could later be expanded in [Milestone 3](https://github.com/dancewithheart/cabal-plan-submit/milestone/3) with usage-aware analysis:

- static analysis inspired by Stan, for example to check whether vulnerable APIs are actually used: [stan #483](https://github.com/kowainik/stan/pull/483)
- AI-assisted vulnerability triage experiments, for example using tools such as [nano-analyzer](https://github.com/weareaisle/nano-analyzer), which explores lightweight LLM-based source-code security scanning.

The goal would be to move from "this dependency has an advisory" toward "this project depends on the vulnerable package through this path, and this code may or may not exercise the vulnerable API."

## Known limitations of cabal-plan-submit
- wrong cabal stanza fallback for package-level dependencies [#22](https://github.com/dancewithheart/cabal-plan-submit/issues/22)
- direct dependency should be preferred as primary location [#21](https://github.com/dancewithheart/cabal-plan-submit/issues/21)
- test/benchmark dependency classification needs refinement [#26](https://github.com/dancewithheart/cabal-plan-submit/issues/26)

[PRs](https://github.com/dancewithheart/cabal-plan-submit/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22good%20first%20issue%22) are very welcome :)
There is [planned work](https://github.com/dancewithheart/cabal-plan-submit/issues/18) to resolve tech debt created while preparing the MVP.
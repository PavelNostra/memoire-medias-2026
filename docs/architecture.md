# Architecture du mémoire de recherche

Ce document décrit l'**état courant** du projet : pipeline de données, conventions de rédaction, méthodes statistiques mobilisées et anti-patterns identifiés. Il sert de point d'entrée pour tout contributeur (humain ou agent) qui rejoint le projet.

## Vue d'ensemble

Le projet est un **mémoire de recherche académique** rédigé en R Markdown et compilé via `bookdown` en un PDF unique (`_book/_main.pdf`). Il combine deux types de matériaux :

1. **Quantitatif** — un corpus de transcriptions Whisper de vidéos web (Blast, Le Média) et de journaux télévisés (France 2), enrichi d'annotations linguistiques `udpipe` et d'entités nommées `spaCy`. Ce corpus est analysé par des indicateurs lexicométriques (densités d'émotions, de connecteurs logiques, de chiffres, de marqueurs de mise en cause) et par classification hiérarchique descendante (méthode Reinert, via IRaMuTeQ).
2. **Qualitatif** — quatre entretiens semi-directifs avec des journalistes des deux pôles (dominants et indépendants), au format PDF dans `entretiens/`.

L'argumentation construit une opposition entre **rationalité narrative** (médias dominants) et **rationalité critique** (médias alternatifs), validée empiriquement avant d'être interprétée à travers les conditions matérielles de production journalistique.

## Topologie ASCII

```
┌──────────────────────────────────────────────────────────────────────────┐
│  COUCHE 1 — DONNÉES BRUTES (figées, ne jamais modifier)                  │
│                                                                          │
│  resultats_blast_final.csv      jt_database.csv      transcription.csv   │
│  resultats_lemedia_final.csv    jt_database_vene.csv FEEL.csv            │
│  resultats_blast_vene.csv       resultats_lemedia_vene.csv               │
│  Biblio.bib (références)        entretiens/*.pdf (sources qualitatives)  │
└──────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  COUCHE 2 — SETUP GLOBAL (index.Rmd, chunk `setup-global`)               │
│                                                                          │
│  • Chargement libraries R                                                │
│  • clean_whisper()       : nettoyage des transcriptions auto             │
│  • count_logos_stats()   : comptage de chiffres significatifs            │
│  • DATE_DEBUT = 2026-02-08   ← borne du corpus                           │
│  • Lecture des CSV → blast / lemedia / jt                                │
│  • bind_rows(...) → corpus_full (filtre word_count >= 100)               │
└──────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  COUCHE 3 — DÉRIVATIONS PARTAGÉES                                        │
│                                                                          │
│  corpus_seq1     ── enrichi (text_seq, sequence)                         │
│  tokens_seq1     ── unnest_tokens + jointure FEEL                        │
│  data/cache/sp_entities_complet.rds  (entités nommées spaCy, cache)      │
│  data/cache/ud_annot_complet.rds     (annotations udpipe, cache)         │
└──────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  COUCHE 4 — CHAPITRES (chunks R locaux + texte rédigé)                   │
│                                                                          │
│  00-Remerciements        04-Chapitre-1.2 (logos)                         │
│  01-Presentation         05-Chapitre-1.3 (mise en cause + ACP)           │
│  02-Etat-de-l'art        06-Chapitre-2.1 (rationalité narrative qual.)   │
│  03-Chapitre-1.1 (FEEL)  07-Chapitre-2.2 (rationalité critique qual.)    │
└──────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  COUCHE 5 — RENDU                                                        │
│                                                                          │
│  bookdown::render_book → knitr → pandoc → LaTeX → biber → pdflatex       │
│                                                            ↓             │
│                                                     _book/_main.pdf      │
└──────────────────────────────────────────────────────────────────────────┘
```

## Corpus

| Source        | Fichier brut                       | Slot                                | Période | Type      |
|---------------|------------------------------------|-------------------------------------|---------|-----------|
| Blast         | `resultats_blast_final.csv`        | `Web`                               | ≥ 2026-02-08 | Alternatif |
| Le Média      | `resultats_lemedia_final.csv`      | `Web`                               | ≥ 2026-02-08 | Alternatif |
| France 2      | `jt_database.csv`                  | `JT 8h` / `JT 13h` / `JT 20h` / `JT Autre` (déduit du titre) | ≥ 2026-02-08 | Dominant   |
| Sous-corpus Vénézuela | `resultats_*_vene.csv`, `jt_database_vene.csv` | idem                | idem    | Sous-corpus thématique |

**Filtres communs** appliqués dans `index.Rmd` :
- `date >= DATE_DEBUT` (borne du corpus)
- `!is.na(transcription)` (rejet des lignes non transcrites)
- `word_count >= 100` (rejet des artefacts trop courts)
- `clean_whisper()` (suppression des artefacts `[musique]`, `(inaudible)`, CamelCase collé, normalisation casse)

**Transcriptions normalisées par 1000 mots** dans toutes les analyses lexicométriques pour neutraliser les différences de durée des vidéos.

## Dictionnaires lexicaux

Le projet construit ses propres dictionnaires lorsqu'aucun équivalent académique n'existe. Chaque dictionnaire est justifié dans un encadré `methodo` du chapitre où il est mobilisé.

| Dictionnaire | Localisation | Usage |
|---|---|---|
| **FEEL** (académique) | `FEEL.csv` | Polarité + 6 émotions Ekman (joie, peur, tristesse, colère, surprise, dégoût) — chapitre 1.1 |
| **Connecteurs logiques** | défini inline dans `04-Chapitre-1.2.Rmd` (encadré `meth:conn`) | Densité argumentative — chapitre 1.2 |
| **Mise en cause systématique** | défini inline dans `05-Chapitre-1.3.Rmd` (encadré `meth:critique`), 4 registres : reformulations, recul critique, actes critiques explicites, conjonctions de contraste | Indicateur de rationalité critique — chapitre 1.3 |

**Règle d'extension** : tout nouveau dictionnaire doit (1) être listé exhaustivement dans un encadré `methodo` (2) être normalisé pour 1000 mots (3) être référencé dans cette table.

## Stratégie statistique

| Test | Cas d'usage | Implémentation |
|---|---|---|
| **Kruskal-Wallis** | Comparaison de la distribution d'un indicateur entre les 3 médias (test non paramétrique) | `rstatix::kruskal_test()` |
| **Wilcoxon avec correction Bonferroni** | Comparaisons par paires une fois Kruskal-Wallis significatif | `rstatix::wilcox_test(..., p.adjust.method = "bonferroni")` |
| **Taille d'effet ε²** | Quantifier l'ampleur de l'effet (au-delà de la significativité) | `rstatix::kruskal_effsize()` |
| **ACP** (analyse en composantes principales) | Synthèse multivariée des indicateurs lexicaux dans un espace factoriel commun | chapitre 1.3, terminal |
| **CHD / méthode Reinert** | Cartographie des univers lexicaux par média et par sous-corpus | externalisé vers IRaMuTeQ ; les PNG résultants sont dans `dendogrammes/<sujet>/<media>/dendrogramme_1.png` |

**Convention de présentation** : tous les tests statistiques doivent être affichés en sous-titre de la figure (`subtitle = paste0("Kruskal-Wallis p=", round(kw$p, 4), " | ε²=", round(es$effsize, 3))`), pour assurer la transparence méthodologique.

## Sources qualitatives (entretiens)

| Fichier | Profil | Mobilisé en |
|---|---|---|
| `entretiens/FRANCE 3.pdf` | Journaliste web France 3 Auvergne, EJCAM 2024 | 2.1 (rationalité narrative dominante) |
| `entretiens/BLAST.pdf` | Pigiste Blast, ancien EMI | 2.2 (rationalité critique alternative) |
| `entretiens/FREELANCE.pdf` | Journaliste freelance (AFP, Arte, Mediapart, Le Monde) | 2.2 |
| `entretiens/LE PARISIEN.pdf` | (à mobiliser le cas échéant) | — |

**Règle d'usage** : ne jamais généraliser un témoignage individuel à toute une profession ; les entretiens illustrent par l'incarnation des logiques que les indicateurs quantitatifs ne peuvent capter.

## Conventions de rédaction

### Typographie française

- Guillemets `« »` (et non `"` ASCII)
- Espace insécable avant `: ; ! ? %` et avant les guillemets fermants
- Apostrophe courbe `’` (et non `'` ASCII) — vérifier les coller-copier
- Accentuation des majuscules : `À`, `É`, `Ç`
- Tirets cadratins `—` pour les incises (et non `--` ou `-`)

### Structure LaTeX héritée d'`index.Rmd`

- Niveau `#` (section) : numéroté en chiffres romains (`I.`, `II.`)
- Niveau `##` (subsection) : numéroté en arabes (`1.1`, `1.2`)
- Encadrés méthodologiques : environnement custom `methodo` (tcolorbox grise) avec compteur par section et `\label{meth:<id>}`
- Figures forcées en place (`\floatplacement{figure}{H}`)
- Bibliographie : `biblatex` + `biber`, style `verbose-trad1`, `autocite=footnote` (les citations apparaissent en notes de bas de page)

### Citations

Format inline dans le texte : `[@cleZotero]` (clé exactement telle qu'elle apparaît dans `Biblio.bib`). Pour citer plusieurs sources : `[@cle1]$^,$ [@cle2]` (séparateur typographique en exposant).

## Caches et reproductibilité

Le projet utilise des caches RDS pour les opérations coûteuses :

- `data/cache/ud_annot_complet.rds` — annotations `udpipe` (POS tagging, lemmatisation) sur l'ensemble du corpus, modèle `french-gsd-ud-2.5-191206`
- `data/cache/sp_entities_complet.rds` — entités nommées `spaCy` (PER, LOC, ORG)

**Règle de cache** : ne pas regénérer ces caches sans nécessité. Si un changement de corpus impose la régénération, documenter le geste dans le commit message et recompiler le PDF complet.

## Anti-patterns à éviter

- ❌ Modifier les CSV racine pour « corriger » une transcription manuellement (les analyses publiées deviennent fausses).
- ❌ Inventer une clé biblatex sans vérifier qu'elle existe dans `Biblio.bib`.
- ❌ Introduire un nouvel indicateur sans encadré `methodo`.
- ❌ Réutiliser les mêmes connecteurs/marqueurs dans deux dictionnaires différents (le mot `or` est volontairement classé dans la mise en cause, pas dans les connecteurs neutres).
- ❌ Compiler un seul `Rmd` isolé puis affirmer que « le mémoire compile » — seule `bookdown::render_book()` produit le PDF final avec ses références croisées résolues.
- ❌ Hardcoder une date ou un seuil dans un chapitre alors qu'il existe une variable globale (`DATE_DEBUT`) dans `index.Rmd`.
- ❌ Renommer un fichier `Rmd` sans vérifier l'ordre alphabétique global (`bookdown` compile les fichiers par tri lexicographique).
- ❌ Régénérer les caches `data/cache/*.rds` sans en faire la mention dans le commit (un agent ultérieur perdrait la trace de la divergence).

## Dépendances externes critiques

| Dépendance | Rôle | Conséquence si indisponible |
|---|---|---|
| `pdflatex` (TeX Live ou MiKTeX) | Compilation LaTeX | Pas de PDF généré |
| `biber` | Compilation bibliographique biblatex | Citations rendues comme `?` |
| `udpipe` (R package) + modèle `french-gsd` | Annotation linguistique du corpus | Indicateurs syntaxiques (proportion de verbes finis au passé, etc.) impossibles |
| `IRaMuTeQ` | CHD / méthode Reinert | Les dendrogrammes ne peuvent être régénérés (PNG existants restent utilisables) |
| `tidytext`, `rstatix`, `ggpubr` | Pipeline lexicométrique et tests statistiques | Recompilation impossible |

## Pour aller plus loin

- Le pipeline est volontairement linéaire et reproductible : `index.Rmd` → corpus partagé → chapitres. Tout enrichissement structurel (nouveau sous-corpus, nouvelle source) passe par `index.Rmd`.
- Les chunks lourds doivent inclure `cache=TRUE` ou utiliser un cache RDS explicite si leur exécution dépasse quelques secondes.
- Pour ajouter une dépendance R, l'inclure dans le chunk `setup-global` de `index.Rmd` (et non dans un chapitre isolé) afin que toutes les analyses partagent le même environnement.

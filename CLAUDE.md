# Memoire-Medias-2026 — Contexte d'Opération et Garde-Fous Agentiques

Aidez à la rédaction et à l'analyse statistique sans introduire de régression dans le pipeline reproductible ni dans la cohérence éditoriale du mémoire.

## I. Finalité

**Projet** : Mémoire de recherche M2 — Sciences Po Lille, sous la direction de Julien Boyadjian (année universitaire 2025-2026).
**Objet** : « Divergences de cadrage et mise en scène de la légitimité » — étude lexicométrique et qualitative comparée du traitement de l'actualité par un média dominant (France 2) et deux médias alternatifs numériques (Blast, Le Média) à partir de transcriptions Whisper.

## II. Architecture

**Modèle** : compilation `bookdown` séquentielle de fichiers `Rmd` numérotés. `index.Rmd` initialise l'environnement R, charge les trois sous-corpus et fixe le YAML LaTeX. Les autres `NN-*.Rmd` sont compilés dans l'ordre alphabétique.

**Détails complets** (pipeline des données, structure des CSV, conventions de chunks, méthodes statistiques mobilisées, dictionnaires lexicaux) : voir [`docs/architecture.md`](./docs/architecture.md).

Topologie rapide :
- `index.Rmd` — setup global R, page de titre, chargement Blast / Le Média / France 2
- `00-*.Rmd` à `07-*.Rmd` — chapitres compilés en séquence
- `Biblio.bib` — base bibliographique biblatex (clés citées via `[@cleZotero]`)
- `*.csv` (racine) — corpus brut figé : transcriptions + métadonnées
- `data/cache/*.rds` — annotations udpipe et entités spaCy mises en cache (recalcul coûteux)
- `data/french-gsd-ud-2.5-191206.udpipe` — modèle linguistique français
- `dendogrammes/`, `graphiques/` — sorties d'analyses PNG incluses dans le PDF
- `entretiens/` — PDFs des entretiens semi-directifs (sources qualitatives)
- `_book/_main.pdf` — sortie finale de compilation

## III. Pile Technologique

*Versions contraintes par l'environnement RStudio local. N'introduisez aucune dépendance alternative sans approbation.*

- **R** + **R Markdown** + `bookdown::pdf_book`
- **LaTeX** (pdflatex) + **biber** (biblatex, style `verbose-trad1`, langue `french`)
- **Packages R** : `tidyverse`, `tidytext`, `lubridate`, `stringr`, `scales`, `viridis`, `ggwordcloud`, `rstatix`, `ggpubr`, `knitr`, `kableExtra`, `udpipe`
- **Outil externe** : IRaMuTeQ pour la classification hiérarchique descendante (méthode Reinert)
- **Dictionnaire émotionnel** : FEEL (`FEEL.csv`, séparateur `;`, six émotions Ekman + polarité)

## IV. Garde-Fous non négociables

1. **Corpus figé** : ne jamais modifier les CSV racine (`resultats_blast_final.csv`, `resultats_lemedia_final.csv`, `jt_database.csv`, leurs jumeaux `_vene`, `transcription.csv`, `FEEL.csv`). Le corpus est la matière première de la recherche ; sa modification invalide les résultats déjà rédigés.
2. **Bornes immuables** : la `DATE_DEBUT <- as.Date("2026-02-08")` et le seuil `word_count >= 100` (index.Rmd) délimitent l'échantillon. Toute modification rend les statistiques publiées dans le mémoire incohérentes — à ne toucher qu'avec recompilation et relecture intégrale.
3. **Reproductibilité avant performance** : préférer un recalcul lent à une heuristique rapide non documentée. Toute coupe ou filtre **doit** être justifié dans un encadré `methodo` LaTeX numéroté.
4. **Citations bibliographiques** : toute affirmation factuelle ou théorique reprise d'un auteur cite une clé existante de `Biblio.bib` (`[@cleZotero]`). Ne jamais inventer ni paraphraser une clé sans vérification dans le `.bib`.
5. **Langue et typographie françaises** : tout texte rédigé est en français (le code R reste en anglais). Préserver les guillemets `« »`, les espaces insécables avant `: ; ! ? %`, les apostrophes courbes `’` et l'accentuation correcte (y compris majuscules : `À`, `É`).
6. **Numérotation des chapitres** : conserver le préfixe `NN-` pour préserver l'ordre de compilation `bookdown`. Ne renommer un fichier qu'après avoir vérifié l'ordre alphabétique global.
7. **Auto-documentation des chunks R** : tout chunk non trivial reçoit un `label` parlant et un commentaire en tête expliquant son rôle (intrants, sortie, choix méthodologique). Les options globales (`echo=FALSE`, `fig.pos="H"`, `out.width="90%"`) sont définies dans `index.Rmd` et ne sont pas redéfinies localement sans raison.

## V. Flux de Travail (Explore → Plan → Code → Verify)

1. **Exploration** — lire le chapitre adjacent et la section correspondante de l'état de l'art pour calquer le ton, le niveau de rigueur et les conventions rhétoriques.
2. **Planification** — pour toute analyse statistique nouvelle, soumettre l'hypothèse, la variable, le test choisi (Kruskal-Wallis, Wilcoxon-Bonferroni, ACP…) et la justification avant d'écrire le chunk.
3. **Implémentation** — écrire le chunk R en s'appuyant sur le pipeline existant (`corpus_seq1`, `tokens_seq1`). Réutiliser les helpers de `index.Rmd` (`clean_whisper`, `count_logos_stats`).
4. **Vérification** — compiler `bookdown::render_book()` et inspecter le PDF généré. Vérifier le placement des figures (`fig.pos="H"`), la résolution des références croisées (`\ref{}`), le rendu des citations biblatex et l'absence d'`?` dans le PDF (signe d'une clé bib manquante).
5. **Encadrés méthodologiques** — toute innovation lexicale (nouveau dictionnaire, nouvel indicateur quantitatif) **doit** être justifiée dans un bloc `::: {.methodo data-latex="{Titre}"}` avec `\label{meth:...}` numéroté.

## VI. Commandes de Développement

```r
# Compilation complète du mémoire (sortie : _book/_main.pdf)
bookdown::render_book(input = "index.Rmd", output_format = "bookdown::pdf_book")

# Compilation rapide d'un chapitre isolé (debug rédactionnel)
rmarkdown::render("05-Chapitre-1.3.Rmd")

# Nettoyage des caches knitr/bookdown si comportement étrange
bookdown::clean_book(clean = TRUE)
```

## VII. Maintenance documentaire

**Règle d'or** : le diff du chunk R ou du texte rédigé et le diff de la doc correspondante doivent être dans **le même commit**.

| Modification | Fichier à mettre à jour |
|---|---|
| Nouveau dictionnaire lexical (logos, mise en cause, etc.) | Encadré `methodo` du chapitre concerné + `docs/architecture.md` § Dictionnaires |
| Nouvelle source dans le corpus | Bloc de chargement dans `index.Rmd` + `docs/architecture.md` § Corpus |
| Nouveau test statistique mobilisé | Section pertinente du chapitre + `docs/architecture.md` § Stratégie statistique |
| Nouvel entretien semi-directif | `entretiens/<NOM>.pdf` + extrait dans le chapitre + référence dans `docs/architecture.md` § Sources qualitatives |
| Changement de `DATE_DEBUT` ou du seuil `word_count` | Garde-fou IV à mettre à jour + `docs/architecture.md` § Filtres + recompilation complète |
| Ajout d'une dépendance R | Chunk `setup-global` de `index.Rmd` + `docs/architecture.md` § Pile |
| Nouvelle convention rhétorique ou typographique | Garde-fou IV pertinent |

## VIII. Contexte de Session

- **Dernier focus** : —
- **Focus immédiat** : —

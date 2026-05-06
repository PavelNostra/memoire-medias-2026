# ─── Test harness pour le chapitre 1.3 réécrit ─────────────────────────────
# Simule l'environnement bookdown : setup global (index.Rmd) + chunks
# logos de 1.2, intensité de 1.1, puis exécute les chunks neufs de 1.3.
# Sortie : graphiques PDF dans /tmp + résumés numériques en console.

setwd("C:/Users/Léo-Pol/Memoire/Git/memoire-medias-2026")
options(warn = 1)

suppressPackageStartupMessages({
  library(tidyverse); library(tidytext); library(lubridate)
  library(stringr);   library(scales);   library(viridis)
  library(rstatix);   library(ggpubr);   library(knitr); library(kableExtra)
  library(FactoMineR); library(factoextra)
})

theme_set(theme_minimal(base_family = "serif", base_size = 12))
DATE_DEBUT <- as.Date("2026-02-08")
SEQ1_NOM   <- "Corpus Complet"

# ─── clean_whisper / count_logos_stats (depuis index.Rmd) ─────────────────
clean_whisper <- function(text) {
  text |> str_to_lower() |>
    str_replace_all("\\[.*?\\]", " ") |>
    str_replace_all("\\(.*?\\)", " ") |>
    str_replace_all("(?<=[a-z])(?=[A-Z])", " ") |>
    str_replace_all("[^a-zàâäéèêëîïôùûüç0-9\\s'\\-:]", " ") |>
    str_replace_all("\\s{2,}", " ") |>
    str_trim()
}

count_logos_stats <- function(text) {
  if (is.na(text)) return(0)
  t <- str_to_lower(text)
  t <- str_replace_all(t, "france\\s*\\d+", " ")
  t <- str_replace_all(t, "\\d+\\s*h\\s*\\d*", " ")
  t <- str_replace_all(t, "\\d+:\\d+", " ")
  t <- str_replace_all(t, "\\b(19|20)\\d{2}\\b", " ")
  return(str_count(t, "\\d+"))
}

# ─── Chargement corpus (depuis index.Rmd) ─────────────────────────────────
blast <- read_csv("resultats_blast_final.csv", show_col_types = FALSE) |>
  mutate(id = as.character(id), source = "Blast", slot = "Web",
         date = as.Date(date_publi),
         transcription = clean_whisper(transcription)) |>
  filter(date >= DATE_DEBUT, !is.na(transcription)) |>
  select(id, titre, date, transcription, source, slot)

lemedia <- read_csv("resultats_lemedia_final.csv", show_col_types = FALSE) |>
  mutate(id = as.character(id), source = "Le Média", slot = "Web",
         date = as.Date(parse_date_time(date_publi, orders = c("Ymd","mdY","dmy"))),
         transcription = clean_whisper(transcription)) |>
  filter(date >= DATE_DEBUT, !is.na(transcription)) |>
  select(id, titre, date, transcription, source, slot)

jt <- read_csv("jt_database.csv", show_col_types = FALSE) |>
  mutate(id = as.character(id), source = "France 2",
         date = as.Date(date),
         transcription = clean_whisper(transcription),
         slot = case_when(
           str_detect(titre, "08|8h")  ~ "JT 8h",
           str_detect(titre, "13|13h") ~ "JT 13h",
           str_detect(titre, "20|20h") ~ "JT 20h",
           TRUE ~ "JT Autre")) |>
  filter(date >= DATE_DEBUT, !is.na(transcription)) |>
  select(id, titre, date, transcription, source, slot)

corpus_full <- bind_rows(blast, lemedia, jt) |>
  mutate(word_count = str_count(transcription, "\\S+"),
         source = factor(source, levels = c("France 2", "Blast", "Le Média"))) |>
  filter(word_count >= 100)

cat("\n[setup] Documents chargés par média :\n"); print(table(corpus_full$source))

# ─── Chunk feel_loading (index.Rmd) ───────────────────────────────────────
feel <- read_delim("FEEL.csv", delim = ";", show_col_types = FALSE) |>
  select(-id) |> mutate(word = str_to_lower(word))

corpus_seq1 <- corpus_full |>
  mutate(text_seq = transcription, word_count_seq = word_count,
         sequence = "Corpus Complet")

# ─── 1.1 : intensity_seq1 (densité émotionnelle) ──────────────────────────
tokens_seq1 <- corpus_seq1 |>
  unnest_tokens(word, text_seq) |>
  inner_join(feel, by = "word")

intensity_seq1 <- corpus_seq1 |>
  left_join(tokens_seq1 |> count(id, name = "emot_count"), by = "id") |>
  mutate(emot_count   = replace_na(emot_count, 0),
         emot_density = emot_count / word_count_seq * 1000)

kw_emot <- intensity_seq1 |> kruskal_test(emot_density ~ source)
es_emot <- intensity_seq1 |> kruskal_effsize(emot_density ~ source)

# ─── 1.2 : logos_conn / logos_stat ────────────────────────────────────────
connecteurs_uni <- c("car","donc","ainsi","alors","pourtant","néanmoins",
                     "toutefois","cependant","revanche","conséquent","effectivement")
connecteurs_bi  <- c("parce que","puisque","c'est pourquoi","en effet",
                     "par conséquent","dès lors","c'est ainsi","en revanche")

logos_conn <- corpus_seq1 |>
  mutate(txt_lc = str_to_lower(text_seq),
         conn_uni = str_count(txt_lc, paste0("\\b(", paste(connecteurs_uni, collapse="|"), ")\\b")),
         conn_bi  = rowSums(sapply(connecteurs_bi, function(b) str_count(txt_lc, fixed(b)))),
         conn_dens = (conn_uni + conn_bi) / word_count_seq * 1000)

kw_conn <- logos_conn |> kruskal_test(conn_dens ~ source)
es_conn <- logos_conn |> kruskal_effsize(conn_dens ~ source)

logos_stat <- corpus_seq1 |>
  mutate(stat_count = map_dbl(text_seq, count_logos_stats),
         stat_dens  = stat_count / word_count_seq * 1000)

kw_stat <- logos_stat |> kruskal_test(stat_dens ~ source)
es_stat <- logos_stat |> kruskal_effsize(stat_dens ~ source)

cat("\n[1.1/1.2] OK — KW p (emot/conn/stat) :",
    signif(kw_emot$p,3), "/", signif(kw_conn$p,3), "/", signif(kw_stat$p,3), "\n")

# ╔══════════════════════════════════════════════════════════════════════╗
# ║                    Chunks NEUFS du chapitre 1.3                      ║
# ╚══════════════════════════════════════════════════════════════════════╝

# ─── Chunk build-injustice ────────────────────────────────────────────────
lex_diagnostic <- c(
  "révéler","révèle","révèlent","révélé","révélée","révélation","révélations",
  "dévoile","dévoiler","dévoilé","dévoilée","démasque","démasquer","démasqué",
  "exposer","exposé","exposée",
  "dissimule","dissimuler","dissimulé","dissimulée","dissimulation",
  "cache","cachée","caché","cachent","masque","masquer","masqué",
  "occulte","occulter","occulté","passer sous silence",
  "mensonge","mensonges","mentir","ment","mentent",
  "propagande","manipulation","manipuler","manipulé","manipulés","manipulée",
  "désinformation","intox",
  "scandale","scandales","scandaleux","scandaleuse",
  "indigne","indignes","inadmissible","inacceptable","honteux","honteuse",
  "dénoncer","dénonce","dénoncent","dénoncé","dénonciation",
  "vérité","en réalité","en vérité","contrairement à","alors qu'en",
  "mettre en lumière","mettre au jour"
)

lex_imputation <- c(
  "responsable","responsables","responsabilité","responsabilités",
  "coupable","coupables","complice","complices","complicité",
  "à cause de","en raison de","du fait de","par la faute de","faute de",
  "au profit de","au bénéfice de","dans l'intérêt de",
  "accusé","accuse","accusent","accusation","accusations",
  "imputable","imputer","imputé",
  "sciemment","délibérément","intentionnellement","volontairement",
  "en connaissance de cause","ont laissé","ont permis","ont organisé",
  "ont décidé","refusé de"
)

lex_pronostic <- c(
  "doit","doivent","devrait","devraient",
  "faut","faudrait","faudra","il faut",
  "exiger","exige","exigent","exigence","exigences",
  "réclame","réclamer","réclament",
  "lutter","lutte","luttes","combat","combats","combattre",
  "mobiliser","mobilisation","mobilisent","se mobiliser",
  "refuser","refus","refuse","refusent","s'opposer","opposer","opposition",
  "agir","action","actions","urgence","urgent","urgente",
  "changer","changement","transformer","transformation",
  "résister","résistance","riposte","riposter",
  "défendre","défense","protéger","protection"
)

score_injustice <- function(text, w = 200, step = 50) {
  if (is.na(text) || nchar(text) < 50) return(NA_real_)
  txt <- str_to_lower(text)

  encode_multi <- function(t, lex, prefix) {
    multi <- lex[str_detect(lex, "\\s")]
    for (i in seq_along(multi)) {
      tag <- paste0(" __", prefix, i, "__ ")
      t <- str_replace_all(t, fixed(multi[i]), tag)
    }
    t
  }
  txt <- encode_multi(txt, lex_diagnostic, "DIAG")
  txt <- encode_multi(txt, lex_imputation, "IMPUT")
  txt <- encode_multi(txt, lex_pronostic,  "PRON")

  uni_diag  <- lex_diagnostic[!str_detect(lex_diagnostic, "\\s")]
  uni_imput <- lex_imputation[!str_detect(lex_imputation, "\\s")]
  uni_pron  <- lex_pronostic[!str_detect(lex_pronostic,  "\\s")]

  words <- str_split(txt, "\\s+")[[1]]
  words <- words[words != ""]
  n <- length(words)
  if (n < w) return(0)

  is_diag  <- (words %in% uni_diag)  | str_detect(words, "^__DIAG\\d+__$")
  is_imput <- (words %in% uni_imput) | str_detect(words, "^__IMPUT\\d+__$")
  is_pron  <- (words %in% uni_pron)  | str_detect(words, "^__PRON\\d+__$")

  cs_d <- c(0, cumsum(is_diag))
  cs_i <- c(0, cumsum(is_imput))
  cs_p <- c(0, cumsum(is_pron))

  starts <- seq(1, n - w + 1, by = step)
  hits <- vapply(starts, function(s) {
    end <- s + w - 1
    has_d <- cs_d[end + 1] - cs_d[s] > 0
    has_i <- cs_i[end + 1] - cs_i[s] > 0
    has_p <- cs_p[end + 1] - cs_p[s] > 0
    as.integer(has_d & has_i & has_p)
  }, numeric(1))
  mean(hits)
}

count_lex <- function(text, lex) {
  if (is.na(text)) return(0)
  t <- str_to_lower(text)
  multi <- lex[str_detect(lex, "\\s")]
  uni   <- lex[!str_detect(lex, "\\s")]
  n_multi <- if (length(multi)) sum(vapply(multi, function(b) str_count(t, fixed(b)), numeric(1))) else 0
  n_uni   <- if (length(uni))   str_count(t, paste0("\\b(", paste(uni, collapse = "|"), ")\\b")) else 0
  n_uni + n_multi
}

t0 <- Sys.time()
injustice_seq1 <- corpus_seq1 |>
  mutate(
    n_diag   = map_dbl(text_seq, ~ count_lex(.x, lex_diagnostic)),
    n_imput  = map_dbl(text_seq, ~ count_lex(.x, lex_imputation)),
    n_pron   = map_dbl(text_seq, ~ count_lex(.x, lex_pronostic)),
    dens_diag  = n_diag  / word_count_seq * 1000,
    dens_imput = n_imput / word_count_seq * 1000,
    dens_pron  = n_pron  / word_count_seq * 1000,
    score_inj  = map_dbl(text_seq, score_injustice)
  ) |>
  filter(!is.na(score_inj))

cat("\n[1.3 build-injustice] computé en", round(as.numeric(Sys.time()-t0),1), "s\n")
cat("[1.3 build-injustice] N total =", nrow(injustice_seq1), "\n")
cat("[1.3 build-injustice] Stats descriptives par média :\n")
print(injustice_seq1 |>
        group_by(source) |>
        summarise(n = n(),
                  med_diag  = round(median(dens_diag),  2),
                  med_imput = round(median(dens_imput), 2),
                  med_pron  = round(median(dens_pron),  2),
                  med_score = round(median(score_inj),  3),
                  moy_score = round(mean(score_inj),    3)))

# ─── Chunk graph-injustice ────────────────────────────────────────────────
injustice_seq1 <- injustice_seq1 |> mutate(score_inj_pct = 100 * score_inj)

kw_inj <- injustice_seq1 |> kruskal_test(score_inj_pct ~ source)
pw_inj <- injustice_seq1 |>
  wilcox_test(score_inj_pct ~ source, p.adjust.method = "bonferroni") |>
  add_significance() |> add_xy_position(x = "source")
es_inj <- injustice_seq1 |> kruskal_effsize(score_inj_pct ~ source)

cat("\n[1.3 univariate] Kruskal-Wallis p =", signif(kw_inj$p,3),
    " | epsilon^2 =", round(es_inj$effsize,3), "\n")
cat("[1.3 univariate] Wilcoxon pairwise (Bonferroni) :\n")
print(pw_inj |> select(group1, group2, p, p.adj, p.adj.signif))
cat("[1.3 univariate] Moyennes (% du discours) :\n")
print(injustice_seq1 |> group_by(source) |>
        summarise(moy_pct = round(mean(score_inj_pct), 2),
                  med_pct = round(median(score_inj_pct), 2),
                  q75_pct = round(quantile(score_inj_pct, 0.75), 2)))

p1 <- ggplot(injustice_seq1, aes(x = source, y = score_inj_pct, fill = source)) +
  geom_violin(alpha = 0.5, width = 0.85, trim = TRUE) +
  geom_jitter(width = 0.12, alpha = 0.4, size = 1) +
  stat_summary(fun = mean, geom = "point", shape = 23, size = 3, fill = "white") +
  stat_pvalue_manual(pw_inj, label = "p.adj.signif", tip.length = 0.01) +
  scale_fill_grey(start = 0.3, end = 0.8) +
  theme_minimal(base_family = "Times", base_size = 12) +
  theme(legend.position = "none",
        plot.title = element_text(face = "bold", hjust = 0.5)) +
  labs(title = "Score d'injustice (Gamson) par média",
       subtitle = paste0(SEQ1_NOM, " - Kruskal-Wallis p=", signif(kw_inj$p,3),
                         " | ε²=", round(es_inj$effsize,3),
                         " | losanges blancs = moyennes"),
       y = "% de fenêtres construisant un cadre d'injustice complet", x = "")

ggsave("C:/tmp/test_inj_boxplot.pdf", p1, width = 8, height = 5, device = cairo_pdf)
cat("[1.3 univariate] Boxplot OK -> C:/tmp/test_inj_boxplot.pdf\n")

# ─── Chunk graph-acp ──────────────────────────────────────────────────────
acp_input <- intensity_seq1 |>
  select(id, source, emot_density) |>
  left_join(logos_conn |> select(id, conn_dens), by = "id") |>
  left_join(logos_stat |> select(id, stat_dens), by = "id") |>
  left_join(injustice_seq1 |>
              select(id, dens_diag, dens_imput, dens_pron, score_inj), by = "id") |>
  drop_na()

acp_matrix <- acp_input |>
  select(-id, -source) |>
  select(where(~ var(.x, na.rm = TRUE) > 0))

cat("\n[1.3 ACP] Matrice :", nrow(acp_matrix), "lignes,",
    ncol(acp_matrix), "colonnes (", paste(names(acp_matrix), collapse=", "), ")\n")

res_pca <- PCA(acp_matrix, graph = FALSE, scale.unit = TRUE)

cat("[1.3 ACP] Inertie cumulée 2 premiers axes :",
    round(sum(res_pca$eig[1:2,2]),1), "%\n")
cat("[1.3 ACP] Contributions à Dim 1 :\n")
print(round(res_pca$var$contrib[,1], 1))

p_var <- fviz_pca_var(res_pca, col.var = "contrib",
                      gradient.cols = c("grey80","grey50","black"), repel = TRUE) +
  theme_minimal(base_family = "Times", base_size = 11) +
  labs(title = "Cercle des corrélations")
p_ind <- fviz_pca_ind(res_pca, geom.ind = "point",
                      col.ind = acp_input$source, palette = "jco",
                      addEllipses = TRUE, ellipse.level = 0.90,
                      legend.title = "Média") +
  theme_minimal(base_family = "Times", base_size = 11) +
  labs(title = "Projection des médias",
       subtitle = "Ellipses de confiance à 90 %")
p2 <- ggarrange(p_var, p_ind, ncol = 2)
ggsave("C:/tmp/test_inj_acp.pdf", p2, width = 12, height = 6, device = cairo_pdf)
cat("[1.3 ACP] Plan factoriel OK -> C:/tmp/test_inj_acp.pdf\n")

# ─── Chunk synthese-ch1 ───────────────────────────────────────────────────
synthese_ch1 <- tibble(
  Dimension  = c("Pathos","Logos","Logos","Cadre d'injustice"),
  Indicateur = c("Densité émotionnelle (FEEL)","Connecteurs logiques",
                 "Chiffres et statistiques","Score d'injustice (Gamson, 200 mots)"),
  KW_p   = c(signif(kw_emot$p,3), signif(kw_conn$p,3),
             signif(kw_stat$p,3), signif(kw_inj$p,3)),
  Effet  = c(round(es_emot$effsize,3), round(es_conn$effsize,3),
             round(es_stat$effsize,3), round(es_inj$effsize,3)),
  Direction = c("Aucune différenciation pertinente",
                "Alternatifs > France 2",
                "France 2 > Alternatifs",
                "Convergence Blast / Le Média vs France 2")
)
cat("\n[1.3 synthèse] Tableau de synthèse :\n")
print(synthese_ch1)

cat("\n=========== TOUS LES CHUNKS ONT TOURNÉ ===========\n")

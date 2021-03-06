# Cleaning up and presenting data
# Because I need to learn Sweave at some poin
library(doBy)
library(xtable)
library(reshape)
library(grid)
library(RColorBrewer)
library(gridExtra)
library(plyr)
library(infotheo)
library(ggplot2)
library(rtf) # For outputting to microsoft word
library(gplots)

library(reshape2)
library(scales)

# constants ====
nmsd.symptoms <- c(
  NMS.D.NAMES,
  "Tremor",
  "Bradykinesia",
  "Rigidity",
  "Axial",
  'Cluster'
)

nmsd.extra <- c(
  'Age',
  'Sex',
  'PD_onset',
  'PD_duration',
  'CISI_PD_total',
  'ldopa',
  'Surgery',
  'Cluster'
)

# Depends on valid cluster assignment, assert that the distribution is
# table(clus4.wide$cluster)
#   1   2   3  4
# 406 189 221 88

# V-measure ====
# always useful...
v.measure <- function(a, b) {
  mi <- mutinformation(a, b)
  entropy.a <- entropy(a)
  entropy.b <- entropy(b)
  if (entropy.a == 0.0) {
    homogeneity <- 1.0
  } else {
    homogeneity <- mi / entropy.a
  }
  if (entropy.b == 0.0) {
    completeness <- 1.0
  } else {
    completeness <- mi / entropy.b
  }
  if (homogeneity + completeness == 0.0) {
    v.measure.score <- 0.0
  } else {
    v.measure.score <- (2.0 * homogeneity * completeness
                        / (homogeneity + completeness))
  }
  # Can also return homogeneity and completeness if wanted
  c(homogeneity, completeness, v.measure.score)
}

# ON NONMOTOR DOMAINS ====
# Somewhat oddly, the correct clustering vector lies in trees$clusters4$clustering$cluster
present <- reshape::rename(raw.omitted, gsub("/", "_", PUB.MAP))
present.full <- reshape::rename(raw.omitted.full, gsub("/", "_", PUB.MAP))
present$Cluster <- cl$cluster
present.full$Cluster <- cl$cluster

# Funcs for latex
mean.sd <- function(data, sig = 2) {
  paste(round(mean(data), sig), " (", round(sd(data), sig), ")", sep = "")
}

get.xtable <- function(df, file = NULL) {
  summary.t <- t(summaryBy(. ~ Cluster, df, FUN = function(x) mean.sd(x, sig = 1), # Only 1 decimal
                           keep.names = TRUE))
  # Get rid of "cluster" row
  summary.t <- summary.t[-which(rownames(summary.t) == 'Cluster'), ]
  xtable(summary.t,
         sanitize.colnames.function = function(x) gsub(pattern = '\\_', replacement = '/', x = x))
}

to.latex <- function(df, file = NULL) {
  xt <- get.xtable(df, file = file)
  print(xt, type = "latex", file = file, booktabs = TRUE)
}


# Redo ANOVA + bonferroni correction.
# Apparently Tukey takes care of multiple comparisons but make sure that's not a
# setting or grouping you need to actually make happen in R.

to.latex(present, "../writeup/manuscript/include/nmsd_summaries.tex")
to.latex(present.full[, gsub("/", "_", nmsd.extra)], "../writeup/manuscript/include/nmsd_extra.tex")

# Publication-ready dendrogram ====
remove.domain.n <- function(s) {
  splitted <- strsplit(s, '-')[[1]]
  if (length(splitted) == 1) {
    s
  } else {
    splitted[3]
  }
}
rid.of.middle <- function(s) {
  splitted <- strsplit(s, '-')[[1]]
  if (length(splitted) == 1) {
    s  # No -, leave it alone
  } else {
    # Get rid of that middle one
    # Could get rid of preceding d as well
    domain <- splitted[1]
    symp <- splitted[3]
    paste(domain, symp, sep = '-')
  }
}

hm.m$colDendrogram <- hm.m$colDendrogram %>% sort(type = "nodes")
labels.wo.d <- unname(sapply(labels(hm.m$colDendrogram), rid.of.middle))
color.vec <- ifelse(labels.wo.d %in% MOTOR.SYMPTOMS, "blue", "black")
# TODO: Capitalize map if necessary
cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")
par(mar=c(3, 4, 0.5, 0))
hm.m$colDendrogram %>%
  set("labels", labels.wo.d) %>%
  set("branches_lwd", 2) %>%
  hang.dendrogram(hang_height = 3) %>%
  color_branches(k = 6, col = cbPalette[2:7]) %>%
  # set("branches_k_color", k = 5, col = brewer.pal(8, 'Dark2')[4:8]) %>%
  # Here, "1" is motor, "2" is nonmotor (sorting by nodes is convenient here)
  color_labels(col = color.vec) %>%
  plot(ylim = c(10, 45))#, xlab = "Symptom", ylab = "Height")

dev.copy(pdf, "../figures/nms30m-colhc-pub.pdf", width = 15, height = 8)
dev.off()

# Publication-ready boxplots ====
dev.off()
clus <- clus4.long
# Get rid of extra
clus.pub <- clus
clus.pub <- clus.pub[clus.pub$variable != "sex", ]
clus.pub$variable <- sapply(clus.pub$variable, function(s) paste("\n", PUB.MAP.N[as.character(s)][[1]], "\n", sep = ""))
clus.pub$variable <- factor(clus.pub$variable)
clus.pub$variable <- factor(clus.pub$variable, levels(clus.pub$variable)[c(1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 17, 18, 14, 13, 10, 16, 15)])
# Add types. Need to do after factors have been reorganized for some reason
clus.pub$Type <- ""
clus.pub[clus.pub$variable %in%
           sapply(NMS.D, function(s) paste("\n", PUB.MAP.N[as.character(s)][[1]], "\n", sep = "")), ]$Type <- "Nonmotor (analyzed)"
clus.pub[clus.pub$variable %in% factor(c("\nAxial\n", "\nRigidity\n", "\nBradykinesia\n", "\nTremor\n", "\nMotor_comp\n")), ]$Type <- "Motor (analyzed)"
clus.pub[!(clus.pub$Type %in% c("Nonmotor (analyzed)", "Motor (analyzed)")), ]$Type <- "Other (not analyzed)"
clus.pub$Type <- factor(clus.pub$Type, levels = c('Nonmotor (analyzed)', 'Motor (analyzed)', 'Other (not analyzed)'))
p <- ggplot(clus.pub, aes(x = factor(cluster), y = measurement, fill = factor(cluster))) +
  geom_boxplot() +
  guides(fill = FALSE) +
  facet_wrap( ~ variable, scales = "free") +
  xlab("") +
  ylab("") +
  theme_pub() +
  theme(strip.background = element_blank(), strip.text = element_text(lineheight = 0.4)) +
  scale_fill_manual(values = brewer.pal(8, "Set2")[1:4])
# print(p)

dummy <- ggplot(clus.pub, aes(x = factor(cluster), y = measurement)) +
  facet_wrap( ~ variable, scales = "free") +
  geom_rect(aes(fill = Type), xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf) +
  theme_minimal() +
  theme(strip.text = element_text(lineheight = 0.4, size = 14),
        legend.text = element_text(size = 14),
        legend.title = element_text(size = 16)) +
  labs(fill = "Variable Type") +
  scale_fill_manual(values = brewer.pal(8, "Set2")[c(5:7)]) +
  theme(legend.position = c(0.7, 0.11))
# dummy

# Terribly complicated way to add colors
# http://stackoverflow.com/questions/19440069/ggplot2-facet-wrap-strip-color-based-on-variable-in-data-set
library(gtable)

g1 <- ggplotGrob(p)
g2 <- ggplotGrob(dummy)

gtable_select <- function (x, ...) 
{
  matches <- c(...)
  x$layout <- x$layout[matches, , drop = FALSE]
  x$grobs <- x$grobs[matches]
  x
}

panels <- grepl(pattern="panel", g2$layout$name)
strips <- grepl(pattern="strip_t", g2$layout$name)
legends <- grepl(pattern="guide-box", g2$layout$name)
g2$layout$t[panels] <- g2$layout$t[panels] - 1
g2$layout$b[panels] <- g2$layout$b[panels] - 1

new_strips <- gtable_select(g2, panels | strips | legends)
grid.newpage()
grid.draw(new_strips)

gtable_stack <- function(g1, g2){
  g1$grobs <- c(g1$grobs, g2$grobs)
  g1$layout <- transform(g1$layout, z= z-max(z), name="g2")
  g1$layout <- rbind(g1$layout, g2$layout)
  g1
}
## ideally you'd remove the old strips, for now they're just covered
new_plot <- gtable_stack(g1, new_strips)
grid.newpage()
grid.draw(new_plot)

dev.copy(pdf, "../figures/kmeans-summaries-4-pub.pdf", width = 14, height = 10)
dev.off()

# Anova with bonferroni correction on c1====
clus4.wide.st <- cbind(raw.omitted, cluster = cl$cluster)
clus4.wide.st <- clus4.wide.st[, -which(names(clus4.wide.st) %in% NMS.30)]
# Why isn't this already a factor? Really confused
# Because it wasn't set in clusters.raw - if this is a bad thing lmk
clus4.wide.st$cluster <- as.factor(clus4.wide.st$cluster)
# Just NMS
clus4.wide.st <- clus4.wide.st[, c(NMS.D, "axial", "rigidity", "bradykin", "tremor", "scmmotcp", "cluster", "cisitot", "age", "pdonset", "durat_pd")]
# Assuming 1st column is cluster (which it should be)
oneways <- lapply(colnames(clus4.wide.st[, -which(colnames(clus4.wide.st) %in% c("cluster"))]), function(col) {
  fm <- substitute(i ~ cluster, list(i = as.name(col)))
  oneway.test(fm, clus4.wide.st)
})
for (test in oneways) {
  # Bonferroni correction INCLUDING SEX since we need that divisor even though
  # we're not actually testing here (binary tests later will do the same)
  if (test$p.value < (0.05 / (length(oneways)))) { # BONFERRONI CORRECTION!
    cat('sig\n')
  } else {
    cat('INSIG:\n')
    cat(test$data.name, '\n')
  }
}

# Redo tukey's for sanity
tukeys <- lapply(colnames(clus4.wide.st[, -which(colnames(clus4.wide.st) %in% c("cluster"))]), function(col) {
  # Doesn't work the oneway way for some reason!
  fm <- as.formula(paste(col, '~ cluster'))
  TukeyHSD(aov(fm, clus4.wide.st))$cluster
})
names(tukeys) <- colnames(clus4.wide.st[, -which(colnames(clus4.wide.st) %in% c("cluster"))])

# Now output the insignificant diferences only
throwaway <- sapply(names(tukeys), function(name) {
  tkdf <- as.data.frame(tukeys[name][[1]])
  # Bonferroni correction needed. Notice PDONSET doesn't matter, but I divide by
  # tukeys length anyways - just to accomodate for the extra
  # sex chi-square comparison
  sigs <- rownames(tkdf[tkdf[["p adj"]] >= 0.05 / (length(tukeys)), ])
  if (length(sigs) > 0) {
    cat(name, ": ", sep = "")
    cat(sigs, "\n")
  }
})

# Redo for age/sex/pdonset/duratpd/cisitot on c1 not anymore since I check them all

# From nms30 ====
# Assert that we have
# c(509, 97, 249, 49)
# nms30.present <- cbind(raw.omitted, cluster = cl.s$cluster)
nms30.present <- cbind(raw.omitted, cluster = testing$cluster)
# Get rid of domains
nms30.present <- nms30.present[, -which(names(nms30.present) %in% NMS.D)]

# Rearrange factors
# How to determine order: first figure out cluster with revalue, set factor
# levels = c(1, 2, 3, 4, 5, 6). Then observe ordering of factors, and reverse that
nms30.present$cluster <- factor(nms30.present$cluster)
nms30.present$cluster <- revalue(nms30.present$cluster, c("1" = "1", "6" = "2", "5" = "3", "2" = "4",
                                                          "4" = "5", "3" = "6"))
nms30.present$cluster <- factor(nms30.present$cluster, levels = c("1", "2", "3", "4", "5", "6"))

nms30.present <- reshape::rename(nms30.present, PUB.MAP)
nms30.present <- reshape::rename(nms30.present, NMS.30.LONG.SHORT.MAP)

nms30.extra.cols <- c("Age", "Sex", "PD_onset", "PD_duration", "CISI_PD_total", "Cluster")
# to.latex(nms30.present[, c(NMS.30.NAMES.PUB, MOTOR.PUB, "Cluster")],
#          "../writeup/manuscript/include/nms30_summaries.tex")
# to.latex(nms30.present[, nms30.extra.cols],
#          "../writeup/manuscript/include/nms30_extra.tex")
to.latex(nms30.present[, c(NMS.30.NAMES.PUB, MOTOR.PUB, "Cluster")],
         "../writeup/manuscript/include/nms30_summaries_6.tex")
to.latex(nms30.present[, nms30.extra.cols],
         "../writeup/manuscript/include/nms30_extra_6.tex")
to.latex(nms30.present,
         "../writeup/manuscript/include/nms30_6.tex")

# nms30 same drill, anova + tukey ====
# NOTE: cluster is captalized here since I'm using the PUB df
oneways <- lapply(colnames(nms30.present[, -which(colnames(nms30.present) %in% c("Cluster"))]), function(col) {
  fm <- substitute(i ~ Cluster, list(i = as.name(col)))
  oneway.test(fm, nms30.present)
})
for (test in oneways) {
  # Bonferroni correction but I also erroneously check sex, so subtract one
  if (test$p.value < (0.05 / (length(oneways)))) { # BONFERRONI CORRECTION!
    cat('sig\n')
  } else {
    cat('INSIG:\n')
    cat(test$data.name, '\n')
  }
}

# Redo tukey's for sanity
tukeys <- lapply(colnames(nms30.present[, -which(colnames(nms30.present) %in% c("Cluster"))]), function(col) {
  # Doesn't work the oneway way for some reason!
  fm <- as.formula(paste(col, '~ Cluster'))
  TukeyHSD(aov(fm, nms30.present))$Cluster
})
names(tukeys) <- colnames(nms30.present[, -which(colnames(nms30.present) %in% c("Cluster"))])

# Now output the insignificant diferences only
. <- sapply(names(tukeys), function(name) {
  tkdf <- as.data.frame(tukeys[name][[1]])
  # Tremor and PD onset aren't significant, -2. I check sex later, + 1.
  # But sex wasn't sigificant, + 1.
  sigs <- rownames(tkdf[tkdf[["p adj"]] >= 0.05 / length(tukeys), ])
  if (length(sigs) > 0) {
    cat(name, ": ", sep = "")
    cat(sigs, "\n")
  }
})

# Gender binomial tests ====
print.proportions <- function(mat) {
  cat("Sex (\\% Male) ")
  sapply(1:dim(mat)[1], function(i) {
    v <- mat[i, ]
    cat("& ", round(v[1] / (v[1] + v[2]), 2) * 100, " ", sep = "")
  })
  cat("\\\\\n")
}
combs.1to4 <- combn(1:4, 2)
combs.1to6 <- combn(1:6, 2)

# For nmsd
present.sex <- table(present[c("Cluster", "Sex")])
print.proportions(present.sex)
# Is this p value less than 0.5 / 19. Nope!
chisq.test(present.sex)
# Welp, pairwise prop test is a much easier way to do this
# We would be interested in 0.5 / 18 here
pairwise.prop.test(present.sex, p.adjust = "bonferroni")
# Look for those that are less than 0.5 / ?
# . <- apply(combs.1to4, MARGIN = 2, FUN = function(comb) {
#   pt <- prop.test(nms30.sex[comb, ])
#   if (pt$p.value < (0.05 / dim(combs.1to4)[2])) { # Bonferroni correction
#     cat("SIG:\n")
#     cat("Cluster ", comb[1], " and ", comb[2], "\n", sep = "")
#     print(pt)
#   }
# })

# For nms30
nms30.sex <- table(nms30.present[c("Cluster", "Sex")])
print.proportions(nms30.sex)
chisq.test(nms30.sex)
# For this one we use 0.05 / 40
pairwise.prop.test(nms30.sex, p.adjust = "bonferroni")
# Look for those that are less than 0.05 / 40 if you care about
. <- apply(combs.1to6, MARGIN = 2, FUN = function(comb) {
  pt <- prop.test(nms30.sex[comb, ])
  if (pt$p.value < (0.05 / dim(combs.1to6)[2])) { # Bonferroni correction
    cat("SIG:\n")
    cat("Cluster ", comb[1], " and ", comb[2], "\n", sep = "")
    print(pt)
  }
})

# Correct nmsd heatmap ====
library(tidyr)
# This uses clus.pub from boxplots section
clus.heatmap = clus4
clus.heatmap[-which(colnames(clus.heatmap) == 'cluster')] = scale(clus.heatmap[-which(colnames(clus.heatmap) == 'cluster')])
clus.heatmap.summary = summaryBy(. ~ cluster, clus.heatmap, keep.names = T)
clus.heatmap.summary$cluster = NULL
clus.heatmap.summary = t(clus.heatmap.summary)
clus.heatmap.summary = clus.heatmap.summary[!(rownames(clus.heatmap.summary) %in% NMS.30), ]
# Reorder
clus.heatmap.summary = clus.heatmap.summary[c(6:14, 18, 16, 17, 15, 19, 5, 1, 3, 4), ]
rownames(clus.heatmap.summary) = c(NMS.D.MAP.PUB.N[rownames(clus.heatmap.summary)[1:9]], PUB.MAP[rownames(clus.heatmap.summary)[10:18]])

color.nonmotor = brewer.pal(8, "Dark2")[5]
color.motor = brewer.pal(8, "Dark2")[6]
color.other = brewer.pal(8, "Dark2")[7]
plot.new()
heatmap.2(as.matrix(clus.heatmap.summary), Rowv = FALSE, Colv = FALSE, dendrogram = 'none', trace = 'none',
          # cellnote = as.matrix(hm.nms30.data.t),
          col = colorRampPalette(rev(brewer.pal(11, 'RdBu')))(n = 250),
          # RowSideColors = c(rep(gch[1], 2), rep(gch[2], 4), rep(gch[3], 6), rep(gch[4], 3), rep(gch[5], 3),
          #                   rep(gch[6], 3), rep(gch[7], 3), rep(gch[8], 2), rep(gch[9], 4), rep(gch[10], 4)),
          xlab = 'Cluster', key.xlab = 'z-score',
          colRow = c(rep(color.nonmotor, 9), rep(color.motor, 5), rep(color.other, 4)),
          # RowSideColors = c(rep(color.nonmotor, 9), rep(color.motor, 5), rep(color.other, 4)),
          # If ^^^ then make rbind c(0, 4, 0) c(3, 2, 1) c(0, 5, 0)
          # and lwid c(0.3, 2, 0.3)
          cexCol = 1.5, cexRow = 1.2, srtCol = 0,
          margins = c(5, 18),
          # Draw lines to separate categories
          rowsep = c(9, 14),
          sepcolor = "white",
          sepwidth = c(0.1, 0.1),
          lmat = rbind(c(0,3),c(2,1),c(0,4)),
          lwid = c(0.3,2),
          lhei = c(0.6,4,1),
          keysize = 1,
          # key.xtickfun = function() { list(at = NULL) },
          key.par = list(mar = c(7, 8, 3, 12)),
          density.info = 'none'
          )
legend("top",      # location of the legend on the heatmap plot
       legend = c("Nonmotor (analyzed)", "Motor (analyzed)", "Other (not analyzed)"), # category labels
       col = c(color.nonmotor, color.motor, color.other),
       lty = 1,
       lwd = 10,
       bty = 'n',
       cex = 0.9
)
if (TRUE) {
  # Always write, for now
  # NOTE: I crop this in preview afterwards because it still has some
  # dead space
  dev.copy(pdf, "../figures/nmsd-hm-pub.pdf", width = 7, height = 10)
  dev.off()
}

# Correct nms30 heatmap ====
hm.nms30.raw.scaled <- nms30.present
# Gender no need
hm.nms30.raw.scaled$Sex <- NULL
# Nullify cluster then reattach once you've scaled
hm.nms30.raw.scaled$Cluster <- NULL
hm.nms30.raw.scaled <- as.data.frame(scale(hm.nms30.raw.scaled))
hm.nms30.raw.scaled$Cluster <- nms30.present$Cluster
hm.nms30.data <- summaryBy(. ~ Cluster, hm.nms30.raw.scaled, keep.names = T)
hm.nms30.data$Cluster <- NULL
# Re-add the domain number to the first 30
names(hm.nms30.data)[10:39] <- sapply(NMS.30.NAMES, rid.of.middle)
# Reorder so not-analyzed variables are last
hm.nms30.data <- hm.nms30.data[, c(10:39, 1:9)]
hm.nms30.data.t <- as.data.frame(t(hm.nms30.data))
# Reorder
hm.nms30.data.t <- hm.nms30.data.t[rownames(hm.nms30.data.t)[c(1:30, 35:39, 34, 31:33)], ]
plot.new()
heatmap.2(as.matrix(hm.nms30.data.t), Rowv = FALSE, Colv = FALSE, dendrogram = 'none', trace = 'none',
          # cellnote = as.matrix(hm.nms30.data.t),
          col = colorRampPalette(rev(brewer.pal(11, 'RdBu')))(n = 250),
          # RowSideColors = c(rep(gch[1], 2), rep(gch[2], 4), rep(gch[3], 6), rep(gch[4], 3), rep(gch[5], 3),
          #                   rep(gch[6], 3), rep(gch[7], 3), rep(gch[8], 2), rep(gch[9], 4), rep(gch[10], 4)),
          colRow = c(rep(color.nonmotor, 30), rep(color.motor, 5), rep(color.other, 4)),
          xlab = 'Cluster', key.xlab = 'z-score',
          cexCol = 1.5, cexRow = 1.2, srtCol = 0,
          margins = c(5, 18),
          # Draw lines to separate categories
          rowsep = c(2, 6, 12, 15, 18, 21, 24, 26, 30, 35),
          sepcolor = "white",
          sepwidth = c(0.1, 0.1),
          lmat = rbind(c(0,3),c(2,1),c(0,4)),
          lwid = c(0.3,2),
          lhei = c(0.6,4,1),
          keysize = 0.5,
          # key.xtickfun = function() { list(at = NULL) },
          key.par = list(mar = c(7, 8, 3, 12)),
          density.info = 'none'
          )
# table(cl$cluster[nms30.present$Cluster == 4])
legend("top",      # location of the legend on the heatmap plot
       legend = c("Nonmotor (analyzed)", "Motor (analyzed)", "Other (not analyzed)"), # category labels
       col = c(color.nonmotor, color.motor, color.other),
       lty = 1,
       lwd = 10,
       bty = 'n',
       cex = 0.9
)
if (TRUE) {
  # Always write, for now
  # NOTE: I crop this in preview afterwards because it still has some
  # dead space
  # dev.copy(pdf, "../figures/nms30-hm-pub.pdf", width = 7, height = 10)
  dev.copy(pdf, "../figures/nms30-hm-pub-6.pdf", width = 7, height = 10)
  dev.off()
}

# Redo clustering with nonmotor only ====
# cl.s$cluster, cl$cluster
# Recreate cl.s
# Use nms30 and nms30.s (scaled)
set.seed(0)
cl.s <- kmeans(x = nms30.s, 4, nstart = 25)

# Compute homogeneity/completeness/v-measure and alignment ====
redux.30 <- cl.s$cluster
redux.30 <- factor(redux.30, levels = c("4", "3", "2", "1"))
redux.30 <- revalue(redux.30, c("4" = "1", "3" = "2", "2" = "3", "1" = "4"))

redux.d <- cl$cluster
redux.d <- factor(redux.d, levels = c("1", "2", "3", "4"))
# redux.d <- factor(redux.d, levels = c("4", "1", "3", "2"))
# redux.d <- revalue(redux.d, c("2" = "1", "3" = "2", "4" = "3", "1" = "4"))

cat("Homogeneity/completeness/V-measure: ",
    v.measure(redux.30, redux.d), "\n")
cat("Adjusted rand index: ",
    mclust::adjustedRandIndex(redux.30, redux.d), "\n")

# Different stacked barplots for 6 cluster solution ====
re6.d <- redux.d
re6.30 <- nms30.present$Cluster
v.measure(re6.d, re6.30)
mclust::adjustedRandIndex(re6.d, re6.30)

align.6.pct <- data.frame(t(rbind(sapply(1:6, function(i) {
    cat("Cluster ", i, "\n")
    present.dist <- table(re6.d[re6.30 == i])
    # Fill in empties
    for (i in 1:4) {
      if (is.na(present.dist[i])) {
        present.dist[i] <- 0
      }
    }
    round(sapply(present.dist, function(n) n / sum(present.dist)), 2)
  }))),
  compcluster = c("\n1", "\n2", "\n3", "\n4", "\n5", "\n6"),
  comparison = rep("\nSymptoms cluster\n", 6)
)
names(align.6.pct) <- c("1", "2", "3", "4", "compcluster", "comparison")
align.6.pct.long <- melt(align.6.pct, id = c("compcluster", "comparison"))

align.6 <- data.frame(t(rbind(sapply(1:6, function(i) {
    cat("Cluster ", i, "\n")
    present.dist <- table(re6.d[re6.30 == i])
    # Fill in empties
    for (i in 1:4) {
      if (is.na(present.dist[i])) {
        present.dist[i] <- 0
      }
    }
    present.dist
  }))),
  compcluster = c("\n1", "\n2", "\n3", "\n4", "\n5", "\n6"),
  comparison = rep("\nSymptoms cluster\n", 6)
)
names(align.6) <- c("1", "2", "3", "4", "compcluster", "comparison")
align.6.long <- melt(align.6, id = c("compcluster", "comparison"))
align.6.2 <- align.6

# Choose pct or normal
comb.6 <- rbind(align.6.long)
# Calculate midpoints of bars
# Bind and plot as one

# comb.6$pos <- as.numeric(sapply(c(1:6, 19:24), function(i) {
#   heights <- comb.6[seq(i, i + 18, by = 6), "value"]
#   cum.heights <- cumsum(heights)
#   cum.heights - ((heights) / 2)
# }))[as.integer(sapply(c(1:6, 19:24), function(i) seq(i, i + 18, length.out = 6)))]

comb.6$fac <- c(rep(c("\n\n\n\n\n\n\n\n1", "\n\n\n\n\n\n\n\n2", "\n\n\n\n\n\n\n\n3", "\n\n\n\n\n\n\n\n4",
                      "\n\n\n\n\n\n\n\n5", "\n\n\n\n\n\n\n\n6"), 4))

pbar <- ggplot(comb.6, aes(y = value, fill = variable)) +
  geom_bar(aes(x = compcluster), position = "stack", stat = "identity") +
  xlab("Symptoms cluster") + ylab("Count") +
  labs(fill = "Domains\ncluster") +
  # scale_y_continuous(labels = percent_format()) +
  theme_bw() +
  theme_pub() +
  theme(strip.background = element_blank(),
        strip.text.x = element_text(size=20, lineheight = 0.5),
        plot.title = element_text(size=20, lineheight = 0.5),
        axis.text.y = element_text(size=18),
        axis.text.x = element_text(size=18, lineheight = 0.1),
        legend.text = element_text(size = 18),
        legend.title = element_text(size = 17)) +
  scale_fill_manual(values = brewer.pal(8, "Set2")[1:4])

pbar.pct <- ggplot(comb.6, aes(y = value, fill = variable)) +
  geom_bar(aes(x = compcluster), position = "fill", stat = "identity") +
  xlab("Symptoms cluster") + ylab("") +
  labs(fill = "Domains\ncluster") +
  scale_y_continuous(labels = percent_format()) +
  theme_bw() +
  theme_pub() +
  theme(strip.background = element_blank(),
        strip.text.x = element_text(size=20, lineheight = 0.5),
        plot.title = element_text(size=20, lineheight = 0.5),
        axis.text.y = element_text(size=18),
        axis.text.x = element_text(size=18),
        legend.text = element_text(size = 18),
        legend.title = element_text(size = 17)) +
  scale_fill_manual(values = brewer.pal(8, "Set2")[1:4])

pbar.pct

# Do the same thing but for the other, I'm not going to rename stuff
align.6.pct <- data.frame(t(rbind(sapply(1:4, function(i) {
    cat("Cluster ", i, "\n")
    present.dist <- table(re6.30[re6.d == i])
    # Fill in empties
    for (i in 1:6) {
      if (is.na(present.dist[i])) {
        present.dist[i] <- 0
      }
    }
    round(sapply(present.dist, function(n) n / sum(present.dist)), 2)
  }))),
  compcluster = c("\n1", "\n2", "\n3", "\n4"),
  comparison = rep("\nSymptoms cluster\n", 4)
)
names(align.6.pct) <- c("1", "2", "3", "4", "5", "6", "compcluster", "comparison")
align.6.pct.long <- melt(align.6.pct, id = c("compcluster", "comparison"))

align.6 <- data.frame(t(rbind(sapply(1:4, function(i) {
    cat("Cluster ", i, "\n")
    present.dist <- table(re6.30[re6.d == i])
    # Fill in empties
    for (i in 1:6) {
      if (is.na(present.dist[i])) {
        present.dist[i] <- 0
      }
    }
    present.dist
  }))),
  compcluster = c("\n1", "\n2", "\n3", "\n4"),
  comparison = rep("\nSymptoms cluster\n", 4)
)
names(align.6) <- c("1", "2", "3", "4", "5", "6", "compcluster", "comparison")
align.6.long <- melt(align.6, id = c("compcluster", "comparison"))
align.6

# Choose pct or normal
comb.6 <- rbind(align.6.long)
# Calculate midpoints of bars
# Bind and plot as one

# comb.6$pos <- as.numeric(sapply(c(1:6, 19:24), function(i) {
#   heights <- comb.6[seq(i, i + 18, by = 6), "value"]
#   cum.heights <- cumsum(heights)
#   cum.heights - ((heights) / 2)
# }))[as.integer(sapply(c(1:6, 19:24), function(i) seq(i, i + 18, length.out = 6)))]

comb.6$fac <- c(rep(c("\n\n\n\n\n\n\n\n1", "\n\n\n\n\n\n\n\n2", "\n\n\n\n\n\n\n\n3", "\n\n\n\n\n\n\n\n4"), 6))

pbar.2 <- ggplot(comb.6, aes(y = value, fill = variable)) +
  geom_bar(aes(x = compcluster), position = "stack", stat = "identity") +
  xlab("Domains cluster") + ylab("Count") +
  labs(fill = "Symptoms\ncluster") +
  # scale_y_continuous(labels = percent_format()) +
  theme_bw() +
  theme_pub() +
  theme(strip.background = element_blank(),
        strip.text.x = element_text(size=20, lineheight = 0.5),
        plot.title = element_text(size=20, lineheight = 0.5),
        axis.text.y = element_text(size=18),
        axis.text.x = element_text(size=18, lineheight = 0.1),
        legend.text = element_text(size = 18),
        legend.title = element_text(size = 17)) +
  scale_fill_manual(values = brewer.pal(8, "Set2")[1:6])

pbar.pct.2 <- ggplot(comb.6, aes(y = value, fill = variable)) +
  geom_bar(aes(x = compcluster), position = "fill", stat = "identity") +
  xlab("Domains cluster") + ylab("") +
  labs(fill = "Symptoms\ncluster") +
  scale_y_continuous(labels = percent_format()) +
  theme_bw() +
  theme_pub() +
  theme(strip.background = element_blank(),
        strip.text.x = element_text(size=20, lineheight = 0.5),
        plot.title = element_text(size=20, lineheight = 0.5),
        axis.text.y = element_text(size=18),
        axis.text.x = element_text(size=18),
        legend.text = element_text(size = 18),
        legend.title = element_text(size = 17)) +
  scale_fill_manual(values = brewer.pal(8, "Set2")[1:6])

pbar.pct.2

align.6[1:4, 1:6]

# if (TRUE) {
#   dev.copy(pdf, "../figures/cluster-alignment.pdf", width = 10, height = 5)
#   dev.off()
# }

# Stacked barplots bar plots bar chart barchart cluster alignment ====
# Distribution of nmsd cluster assignments for those who are in nms30
nmsd.per.nms30 <- data.frame(t(rbind(sapply(1:4, function(i) {
    cat("Cluster ", i, "\n")
    present.dist <- table(redux.d[redux.30 == i])
    # Fill in empties
    for (i in 1:4) {
      if (is.na(present.dist[i])) {
        present.dist[i] <- 0
      }
    }
    round(sapply(present.dist, function(n) n / sum(present.dist)), 2)
  }))),
  compcluster = c("\n1", "\n2", "\n3", "\n4"),
  comparison = rep("\nSymptoms cluster\n", 4)
)
names(nmsd.per.nms30) <- c("1", "2", "3", "4", "compcluster", "comparison")
ndpn30 <- melt(nmsd.per.nms30, id = c("compcluster", "comparison"))

# Distribution of nms30 cluster assignments for those who are in nmsd
nms30.per.nmsd <- data.frame(t(rbind(sapply(1:4, function(i) {
    cat("Cluster ", i, "\n")
    present.dist <- table(redux.30[redux.d == i])
    for (i in 1:4) {
      if (is.na(present.dist[i])) {
        present.dist[i] <- 0
      }
    }
    round(sapply(present.dist, function(n) n / sum(present.dist)), 2)
  }))),
  compcluster = c("\n1", "\n2", "\n3", "\n4"),
  comparison = rep("\nDomains cluster\n", 4)
)
names(nms30.per.nmsd) <- c("1", "2", "3", "4", "compcluster", "comparison")
n30pnd <- melt(nms30.per.nmsd, id = c("compcluster", "comparison"))

comb <- rbind.fill(n30pnd, ndpn30)
# Calculate midpoints of bars
# Bind and plot as one

comb$pos <- as.numeric(sapply(c(1:4, 17:20), function(i) {
  heights <- comb[seq(i, i + 12, by = 4), "value"]
  cum.heights <- cumsum(heights)
  cum.heights - ((heights) / 2)
}))[as.integer(sapply(c(1:4, 17:20), function(i) seq(i, i + 12, length.out = 4)))]

comb$fac <- c(rep(c("\n\n\n\n\n\n\n\nD[1]", "\n\n\n\n\n\n\n\nD[2]", "\n\n\n\n\n\n\n\nD[3]", "\n\n\n\n\n\n\n\nD[4]"), 4),
              rep(c("\n\n\n\n\n\n\n\nS[1]", "\n\n\n\n\n\n\n\nS[2]", "\n\n\n\n\n\n\n\nS[3]", "\n\n\n\n\n\n\n\nS[4]"), 4))

pbar <- ggplot(comb, aes(y = value, fill = variable)) +
  geom_bar(data = subset(comb, comparison == "\nDomains cluster\n"), aes(x = compcluster), position = "fill", stat = "identity") +
  geom_bar(data = subset(comb, comparison == "\nSymptoms cluster\n"), aes(x = as.character(compcluster)), position = "fill", stat = "identity") +
  facet_grid(. ~ comparison, switch = "x", scales = "free_x") +
#   geom_text(aes(label = ifelse(value != 0, paste((value * 100), "%", sep = ""), ""), y = pos),
#             color = "black", size = 4) +
  xlab("") + ylab("") +
  geom_text(aes(x = compcluster, y = 0, label = fac), color = rep(brewer.pal(4, "Set2"), 8),
            inherit.aes = FALSE, parse = TRUE, size = 7, vjust = 2) +
  labs(fill = "Opposite\nclustering") +
  scale_y_continuous(labels = percent_format()) +
  scale_x_discrete(labels = c(" ", " ", " ", " ")) +
  theme_bw() +
  theme_pub() +
  theme(strip.background = element_blank(),
        strip.text.x = element_text(size=20, lineheight = 0.5),
        plot.title = element_text(size=20, lineheight = 0.5),
        axis.text.y = element_text(size=18),
        axis.text.x = element_text(colour = brewer.pal(4, "Set2"), size = 18, lineheight = 0.5),
        legend.text = element_text(size = 18),
        legend.title = element_text(size = 17)) +
  scale_fill_manual(values = brewer.pal(8, "Set2")[1:4]) +
  ggtitle(" Symptoms cluster distribution      Domains cluster distribution   \n")
gtbar <- ggplot_gtable(ggplot_build(pbar))
gtbar$layout$clip[gtbar$layout$name == "panel"] <- "off"
grid.draw(gtbar)

if (TRUE) {
  dev.copy(pdf, "../figures/cluster-alignment.pdf", width = 10, height = 5)
  dev.off()
}


# Correlation plots without bins ====
everything.wide$cluster <- factor(everything.wide$cluster)

ALPH <- 1/5
SPAN <- 2
XPOS <- 36

# ggplot(everything.wide, aes(x=durat_pd))
facts.of.int <- c("\nAnxiety\n" = "nms9", "\nDepression\n" = "nms10",
                  "\nCISI_PD_total\n" = "cisitot", "\nTremor\n" = "tremor")

el <- melt(everything.wide, id.var = c("cluster", "durat_pd"))
# Filter only less than 30s, for lack of
# el <- el[el$durat_pd < 30.1, ]
el.sub <- el[el$variable %in% facts.of.int, ]
# No better way to switch the names?
el.sub$variable <- revalue(factor(el.sub$variable), setNames(names(facts.of.int), facts.of.int))
  
mean_vals <- data.frame(
  variable = names(facts.of.int),
  value = sapply(names(facts.of.int), function(f) {
    mean(el.sub[el.sub$variable == f, ]$value)
  })
)
mean_cors <- sapply(names(facts.of.int), function(f) {
  el.of.int <- el.sub[el.sub$variable == f, ]
  cor(el.of.int$durat_pd, el.of.int$value)
})
mean_text <- data.frame(
  label = sapply(1:4, function(i) {
    v <- round(mean_vals$value[i], 2)
    r <- round(mean_cors[i], 2)
    paste("µ = ", v, "\nr = ", r, sep = "")
  }),
  variable = mean_vals$variable,
  x = XPOS,
  y = sapply(facts.of.int, function(i) max(el[el$variable == i, ]$value - max(el[el$variable == i, ]$value) / 13))
  # y = sapply(facts.of.int, function(i) mean(el[el$variable == i, ]$value + max(el[el$variable == i, ]$value/13)))
)
ggplot(el.sub, aes(x=durat_pd, y=value, color = cluster)) +
  geom_point(alpha = ALPH) +
  stat_smooth(aes(color = "Overall"), se = FALSE, color = "black", span = SPAN) +
  stat_smooth(se = FALSE, span = SPAN) +
  geom_jitter(width = 0.7, height = 0.7, alpha = ALPH) +
  geom_hline(aes(yintercept = value), mean_vals, linetype='dashed') +
  geom_label(data = mean_text, aes(x, y, label = label), inherit.aes = FALSE, size = 6, color = "black", alpha = 0.5) +
  facet_wrap(~ variable, nrow = 2, ncol = 2, scales = "free_y") +
  theme_bw() +
  ylab("Symptom Score\n") +
  xlab("\nPD Duration (years)") +
  scale_color_manual(values = brewer.pal(8, "Set2")[1:4]) +
  labs(color = "Cluster") +
  theme_pub() +
  theme(strip.text = element_text(lineheight = 0.5))

ggsave("../figures/long4-d.pdf")

# Do the same thing, but on nms30 ====
everything.wide.30 <- everything.wide
everything.wide.30$cluster <- nms30.present$Cluster
el.30 <- melt(everything.wide.30, id.var = c("cluster", "durat_pd"))
# Filter only less than 30s, for lack of
# el.30 <- el.30[el.30$durat_pd < 30.1, ]
el.30.sub <- el.30[el.30$variable %in% facts.of.int, ]
# No better way to switch the names?
el.30.sub$variable <- revalue(factor(el.30.sub$variable), setNames(names(facts.of.int), facts.of.int))
  
mean_vals.30 <- data.frame(
  variable = names(facts.of.int),
  value = sapply(names(facts.of.int), function(f) {
    mean(el.30.sub[el.30.sub$variable == f, ]$value)
  })
)
mean_cors.30 <- sapply(names(facts.of.int), function(f) {
  el.of.int <- el.30.sub[el.30.sub$variable == f, ]
  cor(el.of.int$durat_pd, el.of.int$value)
})
mean_text.30 <- data.frame(
  label = sapply(1:4, function(i) {
    v <- round(mean_vals.30$value[i], 2)
    r <- round(mean_cors.30[i], 2)
    paste("µ = ", v, "\nr = ", r, sep = "")
  }),
  variable = mean_vals.30$variable,
  x = XPOS,
  y = sapply(facts.of.int, function(i) max(el.30[el.30$variable == i, ]$value - max(el.30[el.30$variable == i, ]$value) / 13))
)
ggplot(el.30.sub, aes(x=durat_pd, y=value, color = cluster)) +
  geom_point(alpha = ALPH) +
  stat_smooth(aes(color = "Overall"), se = FALSE, color = "black", span = SPAN) +
  stat_smooth(se = FALSE, span = SPAN) +
  geom_jitter(width = 0.7, height = 0.7, alpha = ALPH) +
  geom_hline(aes(yintercept = value), mean_vals.30, linetype='dashed') +
  geom_label(data = mean_text.30, aes(x, y, label = label), inherit.aes = FALSE,
             size = 6, color = "black", alpha = 0.5) +
  facet_wrap(~ variable, nrow = 2, ncol = 2, scales = "free_y") +
  theme_bw() +
  ylab("Symptom Score\n") +
  xlab("\nPD Duration (years)") +
  labs(color = "Cluster") +
  theme_pub() +
  theme(strip.text = element_text(lineheight = 0.5)) +
ggsave("../figures/long4-30.pdf")

# Final correlation, unbinned ====
durat.cor.everything <- function(symptom) cor(everything.wide$durat_pd, as.numeric(everything.wide[[symptom]]))
durat.cor.test <- function(symptom) cor.test(everything.wide$durat_pd, everything.wide[[symptom]])
correlations.everything <- sapply(names(everything.wide),
                                  durat.cor.everything)
# Get rid of cluster, sex, durat_pd
to.remove <- c("cluster", "sex", "durat_pd", "pdonset", "age")
correlations.everything <- correlations.everything[!names(correlations.everything) %in% to.remove]
names(correlations.everything) <- sapply(names(correlations.everything), function(v) c(NMS.D.MAP.PUB.N, NMS.NUM.TO.PUB, MISC.MAP)[[v]])
correlations.everything <- sort(correlations.everything)  # Sort ascending
# Pretty meaningless - no negative correlations!!
is_d.e <- grepl("d", names(correlations.everything))
is_d.e[which(is_d.e == TRUE)] <- "Domain"
is_d.e[which(is_d.e == FALSE)] <- "Symptom"
is_d.e[which(names(correlations.everything) %in% c("Axial", "Bradykinesia", "Rigidity", "Tremor"))] <- "Motor"
is_d.e[which(names(correlations.everything) %in% c("CISI_PD_total", "Age", "PD_onset"))] <- "Other"

correlations.df.e <- data.frame(
  names=names(correlations.everything),
  r=correlations.everything,
  variable=is_d.e
)

correlations.df.e$names <- factor(correlations.df.e$names,
                                  levels=names(sort(correlations.everything)))
# correlations.test.e <- lapply(c(ALL.SYMPTOMS, NMS.30), durat.cor.test)
# names(correlations.test.e) <- c(ALL.SYMPTOMS, NMS.30)
ggplot(correlations.df.e, aes(x=names, y=r, fill=variable)) +
  geom_bar(stat="identity", position="identity") +
  # geom_text(aes(label=round(r, 2)), position=position_dodge(width=0.9), vjust=2 * (correlations.df.e$r < 0) - .5) +
  scale_y_continuous(limits = c(0, 1)) +
  ylab("r\n") +
  xlab("") +
  guides(guides(fill=guide_legend(title="Variable type"))) +
  theme_pub() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))
# Only save with different names!
if (TRUE) {
  ggsave('../figures/cor-unbinned.pdf', width=15, height=8)
}

# RAY final statistics: durat_pd ====
# less
over.1 = table(clus4[clus4$cluster == 1, 'durat_pd'] < 5)
over.2 = table(clus4[clus4$cluster == 2, 'durat_pd'] < 5)
over.3 = table(clus4[clus4$cluster == 3, 'durat_pd'] < 5)
over.4 = table(clus4[clus4$cluster == 4, 'durat_pd'] < 5)

overs = rbind(over.1, over.2, over.3, over.4)
chisq.test(overs)

over.1[2] / (over.1[1] + over.1[2])
over.2[2] / (over.2[1] + over.2[2])
over.3[2] / (over.3[1] + over.3[2])
over.4[2] / (over.4[1] + over.4[2])

pairwise.prop.test(overs, p.adjust.method = "bonferroni")

# TOTAL
over.total = table(ray.clus4[, 'durat_pd'] < 5)
# Compare to total
over.total.comp = rbind(over.1, over.total)
prop.test(over.total.comp)

# everyone else
over.ee = table(ray.clus4[ray.clus4$cluster != 1, 'durat_pd'] < 5)
# Compare to ee
over.ee.comp = rbind(over.1, over.ee)
prop.test(over.ee.comp)

# RAY: HY ====
# Bind HY
assertthat::are_equal(clus4$age, raw.omitted.full$age)
ray.clus4 = cbind(clus4, hy = raw.omitted.full$hy)

# FULL HY
hy.1 = table(ray.clus4[ray.clus4$cluster == 1, 'hy'])
hy.1[["5"]] = 0
hy.2 = table(ray.clus4[ray.clus4$cluster == 2, 'hy'])
hy.3 = table(ray.clus4[ray.clus4$cluster == 3, 'hy'])
hy.4 = table(ray.clus4[ray.clus4$cluster == 4, 'hy'])
hy.4 = c(0, hy.4)
hy.4 = setNames(hy.4, c("1", "2", "3", "4", "5"))

hys = rbind(hy.1, hy.2, hy.3, hy.4)
# chisq.test(hys)  doesn't work, too few data

hy.1[2] / (hy.1[1] + hy.1[2])
hy.2[2] / (hy.2[1] + hy.2[2])
hy.3[2] / (hy.3[1] + hy.3[2])
hy.4[2] / (hy.4[1] + hy.4[2])
t(hys)

table(ray.clus4[, 'hy'])

# HY <= 2
hyp.1 = table(ray.clus4[ray.clus4$cluster == 1, 'hy'] <= 2)
hyp.2 = table(ray.clus4[ray.clus4$cluster == 2, 'hy'] <= 2)
hyp.3 = table(ray.clus4[ray.clus4$cluster == 3, 'hy'] <= 2)
hyp.4 = table(ray.clus4[ray.clus4$cluster == 4, 'hy'] <= 2)

hyps = rbind(hyp.1, hyp.2, hyp.3, hyp.4)
chisq.test(hyps)

hyp.1[2] / (hyp.1[1] + hyp.1[2])
hyp.2[2] / (hyp.2[1] + hyp.2[2])
hyp.3[2] / (hyp.3[1] + hyp.3[2])
hyp.4[2] / (hyp.4[1] + hyp.4[2])
t(hyps)

pairwise.prop.test(hyps, p.adjust.method = "bonferroni")

# TOTAL
hyp.total = table(ray.clus4[, 'hy'] <= 2)
# Compare to total
hyp.total.comp = rbind(hyp.1, hyp.total)
prop.test(hyp.total.comp)

# everyone else
hyp.ee = table(ray.clus4[ray.clus4$cluster != 1, 'hy'] <= 2)
# Compare to ee
hyp.ee.comp = rbind(hyp.1, hyp.ee)
prop.test(hyp.ee.comp)

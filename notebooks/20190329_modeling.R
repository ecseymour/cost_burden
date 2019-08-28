library(stringr)
library(Matrix, warn.conflicts = F)
library(Formula)
library(plm, warn.conflicts = F)
library(dplyr, warn.conflicts = F)
library(tidyr, warn.conflicts = F)
library(carData) # Required for car package
library(car, warn.conflicts = F)
library(faraway, warn.conflicts = F)
library(ggplot2)
options(stringsAsFactors = F)

partial.effect.plot.theme <- theme_minimal() +
  theme(legend.position = 'bottom',
    panel.grid = element_line(color = '#cacaca'),
    plot.margin = margin(t = 0.3, r = 0.5, b = 0.3, l = 0.3, 'cm'),
    legend.key.width = unit(1.1, 'cm'),
    legend.margin = margin(-0.3, 0, 0, 0, 'cm'))

load(file = '~/Workspace/Housing-Cost-Burden/data/NHGIS_trends_data.rda')
shrinking.cities.by.trend <- trends.data %>%
  filter(d.pop.pct < 0 & p.value < 0.05) %>%
  select(nhgis.code)

df <- read.csv('~/Workspace/Housing-Cost-Burden/data/rent_burden_data_long.csv',
  stringsAsFactors = F) %>%
  select(year, nhgis.code = NHGISJOIN, name = PLACE, pop.total = pop, median.gross.rent = rent,
    median.renter.income = inc, pct.rent.burdened = burd, pct.vacant.units = vac,
    renter.hhold.count = renterHH, renter.occupied.rate = renterPct, pop.prop.edu.bachelors = BArate,
    poverty.rate = povrate, median.home.value = medHmVal, built.year.lt.1950.rate = bltPre1950) %>%
  filter(!str_detect(name, 'CDP')) %>%
  mutate(name = str_replace(name, ' city$', '')) %>%
  mutate(ShrinkingFlag = nhgis.code %in% shrinking.cities.by.trend$nhgis.code) %>%
  mutate(group = ifelse(ShrinkingFlag, 'Shrinking', 'Control')) %>%
  mutate(year = ifelse(year %in% c(2012, 2017), year - 2, year)) %>%
  # Remove cities with incomplete panels
  filter(!(nhgis.code %in% c('G13049000', 'G55001150'))) %>%
  select(-renter.hhold.count) %>%
  ungroup()

load(file = '~/Workspace/Housing-Cost-Burden/data/NHGIS_trends_data.rda')
# with(trends.data, quantile(d.pop.pct, probs = c(0.01, 0.05, 0.1, 0.2, 0.25, 0.5)))

shrinking.cities.by.trend <- trends.data %>%
  filter(d.pop.pct < 0 & p.value < 0.05) %>%
  select(nhgis.code)

# Impute median renter income in 1990 with the mean value in each neighborhood
df.imputed <- df %>%
  group_by(nhgis.code) %>%
  mutate(median.renter.income = ifelse(is.na(median.renter.income) & year == 1990,
    mean(median.renter.income, na.rm = T), median.renter.income))

# 5 units don't have renter income data in 2015/2017; remove them
df.imputed.cleaned <- df.imputed %>%
  filter(!is.na(median.renter.income)) %>%
  filter(n() == 5) %>%
  ungroup() %>%
  mutate(year = year - 1980) %>%
  arrange(nhgis.code, year)

# Check that the panel is balanced; 1,947 cities in each year
# with(df.imputed.cleaned, table(year))

# 404 (20.1% of ciites) are shrinking, the rest are controls
# with(df.imputed.cleaned, table(year, ShrinkingFlag))

# OLS model ####################################################################

df.imputed.cleaned.centered <- df.imputed.cleaned %>%
  select(nhgis.code, name, group, ShrinkingFlag, year, everything()) %>%
  group_by(nhgis.code) %>%
  mutate_at(.vars = dplyr::vars(year:built.year.lt.1950.rate), .funs = funs('dm' = . - mean(.)))

m1.ols.control <- lm(pct.rent.burdened_dm ~ year_dm + median.gross.rent_dm + median.renter.income_dm +
    pct.vacant.units_dm + renter.occupied.rate_dm + pop.prop.edu.bachelors_dm + poverty.rate_dm +
    median.home.value_dm + built.year.lt.1950.rate_dm,
  subset = !ShrinkingFlag, data = df.imputed.cleaned.centered)
m1.ols.shrinking <- lm(pct.rent.burdened_dm ~ year_dm + median.gross.rent_dm + median.renter.income_dm +
    pct.vacant.units_dm + renter.occupied.rate_dm + pop.prop.edu.bachelors_dm + poverty.rate_dm +
    median.home.value_dm + built.year.lt.1950.rate_dm,
  subset = ShrinkingFlag, data = df.imputed.cleaned.centered)
cbind(
  coef(m1.ols.control),
  coef(m1.ols.shrinking))

m1.ols <- lm(pct.rent.burdened_dm ~ year_dm + median.gross.rent_dm + median.renter.income_dm +
    pct.vacant.units_dm + renter.occupied.rate_dm + pop.prop.edu.bachelors_dm + poverty.rate_dm +
    median.home.value_dm + built.year.lt.1950.rate_dm +
    year_dm:group + median.gross.rent_dm:group + median.renter.income_dm:group +
    pct.vacant.units_dm:group + renter.occupied.rate_dm:group + pop.prop.edu.bachelors_dm:group + poverty.rate_dm:group +
    median.home.value_dm:group + built.year.lt.1950.rate_dm:group,
  data = df.imputed.cleaned.centered)

# Except for year_dm and year_dm:group, highest VIF is 4.3
car::vif(m1.ols)

# Time-demeaned longitudinal model #############################################

# Rent-Burdened Proportion(i, t) ~ [Income(i, t) * ShrinkingStatus(i)] + [Gross Rent(i, t) * ShrinkingStatus(i)] + Vacancy(i, t) + Renter Pop. Proportion + ...

m2.fe <- plm(pct.rent.burdened ~ year + median.gross.rent + median.renter.income +
    pct.vacant.units + renter.occupied.rate + pop.prop.edu.bachelors +
    poverty.rate + median.home.value + built.year.lt.1950.rate +
    year:group + median.gross.rent:group + median.renter.income:group +
    pct.vacant.units:group + renter.occupied.rate:group +
    pop.prop.edu.bachelors:group + poverty.rate:group +
    built.year.lt.1950.rate:group + median.home.value:group,
  data = df.imputed.cleaned, model = 'within', effect = 'individual',
  index = c('nhgis.code'))
summary(m2.fe)

# Model must be implicitly dropping 1990 observations...
m3.fe <- plm(pct.rent.burdened ~ year + median.gross.rent + median.renter.income +
    pct.vacant.units + renter.occupied.rate + pop.prop.edu.bachelors +
    poverty.rate + median.home.value + built.year.lt.1950.rate +
    year:group + median.gross.rent:group + median.renter.income:group +
    pct.vacant.units:group + renter.occupied.rate:group +
    pop.prop.edu.bachelors:group + poverty.rate:group +
    built.year.lt.1950.rate:group + median.home.value:group,
  data = df.imputed.cleaned, model = 'within', effect = 'individual',
  index = c('nhgis.code'), subset = year != 1990)
cbind( # ...Because the coefficients and p-values don't difer
  summary(m2.fe)$coefficients[,3],
  summary(m3.fe)$coefficients[,3])

# Model criticism ##############################################################

# Calculate projection matrix
X <- model.matrix(m2.fe)
P <- X %*% solve(t(X) %*% X) %*% t(X)

# Internally studentized residuals
sigma.sq <- (1 / m2.fe$df.residual) * sum(residuals(m2.fe)^2)
student.resids <- residuals(m2.fe) / (sigma.sq * (1 - diag(P)))

# Residual v. Fitted
plot(m2.fe$model$pct.rent.burdened - residuals(m2.fe),
  residuals(m2.fe), bty = 'n', asp = 1,
  xlab = 'Percent Rent-Burdened (Fitted Values)', ylab = 'Residuals',
  main = 'FE Model Residuals vs. Fitted Values')
abline(h = 0, lty = 'dashed', col = 'red', lwd = 2)

# No significant trend in the squared absolute value of residuals; no evidence of heteroscedasticity
# plot(m2.fe$model$pct.rent.burdened - residuals(m2.fe), sqrt(abs(residuals(m2.fe))))
# summary(lm(sqrt(abs(residuals(m2.fe))) ~ m2.fe$model$pct.rent.burdened - residuals(m2.fe)))

# Normality of residuals
par(mfrow = c(2, 1))
plot(density(residuals(m2.fe)), bty = 'n',
  main = 'Kernel Density of FE Model Residuals')
qqnorm(student.resids, main = 'QQ-Normal Plot of FE Model Residuals',
  ylab = 'Studentized Residuals')
qqline(student.resids)
par(mfrow = c(1, 1))

# Fitted v Observed
plot(m2.fe$model$pct.rent.burdened,
  m2.fe$model$pct.rent.burdened - residuals(m2.fe), bty = 'n',
  xlab = 'Observed Percent Rent-Burdened',
  ylab = 'Predicted Percent Rent-Burdened',
  main = 'FE Model Fitted versus Observed', asp = 1)
abline(0, 1, col = 'red', lty = 'dashed', lwd = 2)

# Leverage?
require(faraway)
# Create `labs` (labels) for 1 through 1704 observations
faraway::halfnorm(diag(P), labs = 1:9735, ylab = 'Leverages', nlab = 5)

# Serial correlation?
pwartest(m2.fe, type = 'HC4') # p-value of ~0.0021 with either HC3 or HC4

# No relationship with the size of the city
plot(log10(df.imputed.cleaned$pop.total), residuals(m2.fe),
  bty = 'n', xlab = 'Log10 Total Population in Any Year',
  ylab = 'FE Model Residual')
abline(h = 0, lty = 'dashed', col = 'red', lwd = 3)

plot(log10(df.imputed.cleaned$pop.total), student.resids,
  bty = 'n', xlab = 'Log10 Total Population in Any Year',
  ylab = 'FE Model Studentized Residual',
  main = 'Residuals vs. Total Population')
abline(h = 0, lty = 'dashed', col = 'red', lwd = 3)

with(data.frame(
    nhgis.code = df.imputed.cleaned$nhgis.code,
    pop.total = df.imputed.cleaned$pop.total,
    year = as.character(df.imputed.cleaned$year + 1980),
    residual = student.resids) %>%
  group_by(nhgis.code) %>%
  mutate(d.pop.total = pop.total - mean(pop.total)),
  plot(d.pop.total, residual, bty = 'n',
    xlab = 'Population Anomaly', ylab = 'Studentized Residual'))
abline(h = 0, lty = 'dashed', col = 'red', lwd = 2)

require(scales)
require(RColorBrewer)
data.frame(
    nhgis.code = df.imputed.cleaned$nhgis.code,
    year = as.character(df.imputed.cleaned$year + 1980),
    residual = student.resids) %>%
  filter(year != '2015') %>%
  left_join(trends.data, by = 'nhgis.code') %>%
  mutate(
    Direction = ifelse(d.pop.pct < 0, 'Shrinking', 'Growing')) %>%
ggplot(mapping = aes(x = abs(d.pop.pct) * 10, y = residual)) +
  geom_point(aes(color = Direction), alpha = 0.2, size = 1) +
  geom_smooth(aes(group = Direction, color = Direction,
    fill = Direction), method = 'lm', linetype = 'dashed',
    size = 0.8) +
  facet_wrap(~ year) +
  scale_x_log10(label = comma) +
  scale_color_manual(values = brewer.pal(5, 'RdBu')[c(5,1)]) +
  scale_fill_manual(values = brewer.pal(5, 'RdBu')[c(4,2)]) +
  labs(x = 'Absolute Population Trend (% per Decade)',
    y = 'Studentized Residual') +
  theme_linedraw() +
  theme(legend.position = 'bottom', legend.margin = margin(0, 0, 0, 0),
    legend.key.width = unit(0.9, 'cm'),
    strip.background = element_rect(fill = 'white',
      color = 'transparent'),
    strip.text = element_text(face = 'bold', color = 'black'))
ggsave(width = 900/172, height = 1000/172, dpi = 172,
  file = '~/Workspace/Housing-Cost-Burden/outputs/20190314/model_crit_Sensitivity_to_Continuous_Pop_Trend.png')

# Goodness of fit ##############################################################

# Within R^2
sse <- sum(residuals(m2.fe)^2) # Residual sum of sq.

# Get the demeaned response
y.demeaned <- Within(pdata.frame(df.imputed.cleaned,
  index = c('nhgis.code'))$pct.rent.burdened)
sst.dm <- sum((y.demeaned - mean(y.demeaned))^2)

# Within model R-squared
summary(m2.fe)$r.squared
1 - (sse / sst.dm)

# Full model R-squared
sst <- with(df.imputed.cleaned, sum((pct.rent.burdened - mean(pct.rent.burdened))^2))
1 - (sse / sst)

# Plotting results #############################################################

require(lmtest)
require(latex2exp)
# tmp <- summary(m2.fe)$coefficients
tmp <- coeftest(m2.fe, plm::vcovHC(
  m2.fe, type = 'HC4', method = 'arellano'))

m2.fe.results <- data.frame(
  Variable = row.names(tmp),
  Estimate = tmp[,1],
  Std.Error = tmp[,2],
  t.value = tmp[,3]) %>%
  mutate(
    Group = ifelse(str_detect(Variable, '\\:groupShrinking'), 'Shrinking', 'Other'),
    Variable = str_replace(Variable, '\\:groupShrinking', ''),
    Variable = str_to_title(str_replace_all(Variable, '\\.', ' ')),
    Variable = ifelse(str_detect(Variable, 'Pop Prop Edu'),
      "Bachelor's Degree Attainment Rate", Variable),
    Variable = str_replace(Variable, 'Pct', 'Percent'),
    Variable = str_replace(Variable, 'Built Year Lt 1950 Rate',
      'Percent Housing Built Prior to 1950'),
    Variable = str_replace(Variable, 'Renter Occupied', 'Renter-Occupied')) %>%
  arrange(Group, Variable)

# Compute interactions
m2.fe.results[m2.fe.results$Group == 'Shrinking', 't.value'] <- m2.fe.results[m2.fe.results$Group == 'Shrinking', 't.value'] + m2.fe.results[m2.fe.results$Group == 'Other', 't.value']

m2.fe.results$Variable <- ordered(m2.fe.results$Variable,
  levels = c(c('Year', 'Median Renter Income', 'Median Gross Rent'),
  sort(setdiff(m2.fe.results$Variable,
    c('Year', 'Median Renter Income', 'Median Gross Rent')))))

require(RColorBrewer)
ggplot(m2.fe.results, mapping = aes(x = Variable, y = t.value)) +
  coord_flip(ylim = c(-35, 30)) +
  geom_bar(aes(group = Group, fill = Group), stat = 'identity', position = 'dodge') +
  geom_hline(yintercept = c(-1.96, 1.96), color = 'red', linetype = 'dashed', size = 0.5) +
  annotate('text', y = -32, x = which(levels(m2.fe.results$Variable) == 'Median Renter Income'),
    label = '*', size = 10, hjust = 1, vjust = 0.8) +
  annotate('text', y = 31, x = which(levels(m2.fe.results$Variable) == 'Year'),
    label = '*', size = 10, hjust = 0.8, vjust = 0.8) +
  scale_y_continuous(breaks = seq(-30, 25, 10)) +
  scale_fill_manual(values = brewer.pal(3, 'Greys')[c(2,3)]) +
  labs(y = 't Value', x = NULL) +
  guides(fill = guide_legend(reverse = T)) +
  theme_minimal() +
  theme(axis.text.y = element_text(size = 11, color = 'black'),
    legend.margin = margin(-0.3, 0, 0, 0, 'cm'),
    legend.position = 'bottom')
ggsave(width = 1000/172, height = 650/172, dpi = 172,
  file = '~/Workspace/Housing-Cost-Burden/outputs/20190314/FE_model_results_t_values.png')

# Parameter sweep by percentage change from median #############################

# For each city, a parameter sweep of a percentage decrease in income, based on its 1980 value...

library(broom)
tmp <- df.imputed.cleaned %>%
  filter(year == 0) %>%
  group_by(nhgis.code) %>%
  do(d.steps = -seq(0, 0.5, 0.01)) %>%
  tidy(d.steps)

test.matrix <- df.imputed.cleaned %>%
  left_join(data.frame(
    fe = as.numeric(fixef(m2.fe)),
    nhgis.code = names(fixef(m2.fe))), by = 'nhgis.code') %>%
  select(nhgis.code, group, fe, year, median.renter.income, median.gross.rent) %>%
  arrange(nhgis.code, group, year) %>%
  group_by(nhgis.code, group, fe) %>%
  summarize(
    median.renter.income = mean(median.renter.income),
    median.gross.rent = mean(median.gross.rent)) %>%
  right_join(tmp, by = 'nhgis.code') %>%
  ungroup() %>%
  mutate(
    year = 0,
    median.renter.income = (median.renter.income * x),
    median.gross.rent = (median.gross.rent * -x)) %>%
  rename(d.pct = x) %>%
  select(nhgis.code, group, d.pct, fe, year, everything())

means.matrix <- as.data.frame(model.matrix(m2.fe))[1,]
means.matrix[,1:18] <- 0 # Fill in means (demeaned means are 0)

test.matrix.income <- select(test.matrix, -median.gross.rent) %>%
  left_join(select(means.matrix, -median.renter.income),
    by = 'year') %>%
  mutate(
    `median.renter.income:groupShrinking` = ifelse(group == 'Shrinking',
      median.renter.income, 0))

test.matrix.rent <- select(test.matrix, -median.renter.income) %>%
  left_join(select(means.matrix, -median.gross.rent),
    by = 'year') %>%
  mutate(
    `median.gross.rent:groupShrinking` = ifelse(group == 'Shrinking',
      median.gross.rent, 0))

# Get the columns in the right order
test.matrix.rent <- test.matrix.rent[,c('nhgis.code', 'group', 'd.pct', 'fe', as.character(names(coef(m2.fe))))]
test.matrix.income <- test.matrix.income[,c('nhgis.code', 'group', 'd.pct', 'fe', as.character(names(coef(m2.fe))))]

test.results <- cbind(
  select(
    test.matrix, group, nhgis.code, d.pct, median.renter.income, median.gross.rent),
    data.frame(
      prediction.by.rent = (as.matrix(test.matrix.rent[,-1:-4]) %*% coef(m2.fe)),
      prediction.by.income = (as.matrix(test.matrix.income[,-1:-4]) %*% coef(m2.fe)))) %>%
  gather(key = Variable, value = value, prediction.by.rent:prediction.by.income) %>%
  mutate(Variable = ifelse(str_detect(Variable, 'rent'),
    'Increase in Median Gross Rent',
    'Decrease in Median Renter Income')) %>%
  rename(Group = group) %>%
  mutate(group0 = interaction(Group, Variable, sep = ', ')) %>%
  mutate(Group = ordered(Group, levels = c('Shrinking', 'Control')))
  # group_by(d.pct, group0, group, Variable) %>%
  # summarize(
  #   min.value = quantile(value, probs = 0.2),
  #   max.value = quantile(value, probs = 0.8),
  #   value = mean(value))

ggplot(test.results, mapping = aes(x = abs(d.pct) * 100, y = value)) +
  geom_smooth(aes(group = group0, color = Group, fill = Group,
    linetype = Variable), size = 1,
    method = 'lm', se = FALSE) +
  # geom_ribbon(aes(group = group0, ymin = min.value, ymax = max.value, fill = group), alpha = 0.3) +
  # geom_line(aes(group = group0, color = group), size = 1) +
  # facet_wrap(~ Variable) +
  scale_linetype_manual(values = c('solid', 'dashed')) +
  scale_color_manual(values = brewer.pal(5, 'RdGy')[c(1,5)]) +
  scale_y_continuous(expand = c(0, 0)) +
  scale_x_continuous(expand = c(0, 0)) +
  labs(x = 'Percent Change',
    y = TeX('$\\Delta\\,$Percent Population Rent-Burdened'),
    title = 'Partial effect of increasing rent, declining income on rent burden') +
  guides(color = guide_legend(nrow = 2),
    linetype = guide_legend(nrow = 2, override.aes = aes(color = 'black'))) +
  partial.effect.plot.theme
ggsave(width = 1000/172, height = 800/172, dpi = 172,
  file = '~/Workspace/Housing-Cost-Burden/outputs/20190314/partial_effects_plot_Rent+Income.png')

# Parameter sweep by dollar change from median #################################

tmp <- expand.grid(
    nhgis.code = unique(df.imputed.cleaned$nhgis.code),
    d.steps.income = seq(0, -20e3, -1e3),
    d.steps.rent = seq(0, 1e3, 50),
  stringsAsFactors = FALSE)

means.matrix <- as.data.frame(model.matrix(m2.fe))[1,]
means.matrix[,1:18] <- 0 # Fill in means (demeaned means are 0)

test.matrix <- df.imputed.cleaned %>%
  left_join(data.frame(
    fe = as.numeric(fixef(m2.fe)),
    nhgis.code = names(fixef(m2.fe))), by = 'nhgis.code') %>%
  select(nhgis.code, group, fe, year, median.renter.income, median.gross.rent) %>%
  arrange(nhgis.code, group, year) %>%
  group_by(nhgis.code, group, fe) %>%
  summarize(
    median.renter.income = mean(median.renter.income),
    median.gross.rent = mean(median.gross.rent)) %>%
  ungroup()

# Matrix where everything is at the mean (i.e., equals zero) except Median renter income
test.matrix.income <- test.matrix %>%
  right_join(tmp, by = 'nhgis.code') %>%
  select(-d.steps.rent, -median.gross.rent) %>%
  distinct() %>%
  mutate(
    year = 0,
    median.renter.income = d.steps.income) %>%
  select(nhgis.code, group, d.steps.income, fe, year, everything()) %>%
  arrange(nhgis.code) %>%
  left_join(select(means.matrix, -median.renter.income),
    by = 'year') %>%
  mutate(
    `median.renter.income:groupShrinking` = ifelse(group == 'Shrinking',
      median.renter.income, 0))

# Matrix where everything is at the mean (i.e., equals zero) except Median gross rent
test.matrix.rent <- test.matrix %>%
  right_join(tmp, by = 'nhgis.code') %>%
  select(-d.steps.income, -median.renter.income) %>%
  distinct() %>%
  mutate(
    year = 0,
    median.gross.rent = d.steps.rent) %>%
  select(nhgis.code, group, d.steps.rent, fe, year, everything()) %>%
  arrange(nhgis.code) %>%
  left_join(select(means.matrix, -median.gross.rent),
    by = 'year') %>%
  mutate(
    `median.gross.rent:groupShrinking` = ifelse(group == 'Shrinking',
      median.gross.rent, 0))

# Get the columns in the right order
test.matrix.rent <- test.matrix.rent[,c('nhgis.code', 'group', 'd.steps.rent', 'fe', as.character(names(coef(m2.fe))))]
test.matrix.income <- test.matrix.income[,c('nhgis.code', 'group', 'd.steps.income', 'fe', as.character(names(coef(m2.fe))))]

test.results.rent <- cbind(
  select(
    test.matrix.rent, group, nhgis.code, median.gross.rent, d.steps.rent),
    data.frame(
      # Make a prediction with matrix algebra!
      prediction.by.rent = (as.matrix(test.matrix.rent[,-1:-4]) %*% coef(m2.fe)))) %>%
  rename(Group = group) %>%
  mutate(Group = ordered(Group, levels = c('Shrinking', 'Control'))) %>%
  group_by(Group, d.steps.rent) %>%
  mutate(
    prediction.low = quantile(prediction.by.rent, 0.2),
    prediction.high = quantile(prediction.by.rent, 0.8))

test.results.income <- cbind(
  select(
    test.matrix.income, group, nhgis.code, median.renter.income, d.steps.income),
    data.frame(
      # Make a prediction with matrix algebra!
      prediction.by.income = (as.matrix(test.matrix.income[,-1:-4]) %*% coef(m2.fe)))) %>%
  rename(Group = group) %>%
  mutate(Group = ordered(Group, levels = c('Shrinking', 'Control'))) %>%
  group_by(Group, d.steps.income) %>%
  mutate(
    prediction.low = quantile(prediction.by.income, 0.2),
    prediction.high = quantile(prediction.by.income, 0.8))

# NOTE: It seems strange at first but because this is a model
#   centered within subjects, zeros represent the means; hence, any
#   non-zero value is a deviation from the mean and we can easily
#   express a change from mean conditions as a gradient moving away
#   from zero
# ALSO there is no heterogeneity in this partial effect across
#   subjects because the "within" partial effect is the same for
#   every subject (which means a lot of the math above is redundant;
#   every subject has the same predicted response for a given change
#   in X)
require(latex2exp)
require(RColorBrewer)
ggplot(test.results.rent, mapping = aes(x = d.steps.rent, y = prediction.by.rent)) +
  geom_smooth(aes(group = Group, color = Group, fill = Group, linetype = Group),
    size = 1, method = 'lm', se = FALSE) +
  scale_linetype_manual(values = c('solid', 'dashed')) +
  scale_color_manual(values = brewer.pal(5, 'RdGy')[c(1,5)]) +
  scale_fill_manual(values = brewer.pal(5, 'RdGy')[c(1,5)]) +
  scale_y_continuous(expand = c(0, 0)) +
  scale_x_continuous(expand = c(0, 0)) +
  labs(x = 'Increase in Median Gross Rent (2017 USD)',
    y = TeX('$\\Delta\\,$Percent Population Rent-Burdened'),
    title = 'Partial effect of rising gross rents on rent burden') +
  partial.effect.plot.theme
ggsave(width = 1000/172, height = 800/172, dpi = 172,
  file = '~/Workspace/Housing-Cost-Burden/outputs/20190329/partial_effects_plot_Rent.png')

require(scales)
ggplot(test.results.income, mapping = aes(x = -d.steps.income, y = prediction.by.income)) +
  geom_smooth(aes(group = Group, color = Group, fill = Group, linetype = Group),
    size = 1, method = 'lm', se = FALSE) +
  scale_linetype_manual(values = c('solid', 'dashed')) +
  scale_color_manual(values = brewer.pal(5, 'RdGy')[c(1,5)]) +
  scale_fill_manual(values = brewer.pal(5, 'RdGy')[c(1,5)]) +
  scale_y_continuous(expand = c(0, 0)) +
  scale_x_continuous(expand = c(0, 0), labels = function (s) {
    return(sprintf('-%s', scales::comma(s)))
  }) +
  labs(x = 'Decrease in Median Renter Income (2017 USD)',
    y = TeX('$\\Delta\\,$Percent Population Rent-Burdened'),
    title = 'Partial effect of declining renter incomes on rent burden') +
  partial.effect.plot.theme +
  theme(plot.margin = margin(5.5, 15, 5.5, 5.5, 'pt'))
ggsave(width = 1000/172, height = 800/172, dpi = 172,
  file = '~/Workspace/Housing-Cost-Burden/outputs/20190329/partial_effects_plot_Income.png')

# Parameter sweep by dollar change from median, allowing income or rent #######

tmp <- expand.grid(
    year = 0,
    group = c('Shrinking', 'Control'),
    median.renter.income = seq(0, -20e3, -1e3),
    median.gross.rent = seq(0, 1e3, 50),
  stringsAsFactors = FALSE)

means.matrix <- as.data.frame(model.matrix(m2.fe))[1,]
means.matrix[,1:18] <- 0 # Fill in means (demeaned means are 0)

# Test matrix where both Rent and Income gradients are set to the
#   empirically observed anomalies;
# Everything else is at the mean (i.e., equals zero)
test.matrix <- tmp %>%
  arrange(group, year) %>%
  left_join(select(means.matrix, -median.renter.income, -median.gross.rent),
    by = 'year') %>%
  mutate(
    `median.gross.rent:groupShrinking` = ifelse(group == 'Shrinking',
      median.gross.rent, 0),
    `median.renter.income:groupShrinking` = ifelse(group == 'Shrinking',
      median.renter.income, 0))

# Get the columns in the right order
test.matrix <- test.matrix[,c('group', as.character(names(coef(m2.fe))))]

test.results <- cbind(
  select(
    test.matrix, group, median.gross.rent, median.renter.income),
    data.frame(
      # Make a prediction with matrix algebra!
      prediction = (as.matrix(test.matrix[,-1]) %*% coef(m2.fe)))) %>%
  rename(Group = group) %>%
  mutate(Group = ordered(Group, levels = c('Shrinking', 'Control'))) %>%
  group_by(Group, median.renter.income) %>%
  mutate(
    prediction.by.income.low = quantile(prediction, 0),
    prediction.by.income.high = quantile(prediction, 1)) %>%
  group_by(Group, median.gross.rent) %>%
  mutate(
    prediction.by.rent.low = quantile(prediction, 0),
    prediction.by.rent.high = quantile(prediction, 1)) %>%
  ungroup()

# NOTE: It seems strange at first but because this is a model
#   centered within subjects, zeros represent the means; hence, any
#   non-zero value is a deviation from the mean and we can easily
#   express a change from mean conditions as a gradient moving away
#   from zero
# ALSO there is no heterogeneity in this partial effect across
#   subjects because the "within" partial effect is the same for
#   every subject (which means a lot of the math above is redundant;
#   every subject has the same predicted response for a given change
#   in X)
require(scales)
require(latex2exp)
require(RColorBrewer)
ggplot(test.results, mapping = aes(x = median.gross.rent, y = prediction)) +
  geom_ribbon(aes(ymin = prediction.by.rent.low,
    ymax = prediction.by.rent.high, group = Group, fill = Group), alpha = 0.3) +
  geom_smooth(aes(group = Group, color = Group, fill = Group, linetype = Group),
    size = 1, method = 'lm', se = FALSE) +
  scale_linetype_manual(values = c('solid', 'dashed')) +
  scale_color_manual(values = brewer.pal(5, 'RdGy')[c(1,5)]) +
  scale_fill_manual(values = brewer.pal(5, 'RdGy')[c(1,5)]) +
  scale_y_continuous(expand = c(0, 0)) +
  scale_x_continuous(expand = c(0, 0), labels = scales::comma) +
  labs(x = 'Increase in Median Gross Rent (2017 USD)',
    y = TeX('$\\Delta\\,$Percent Population Rent-Burdened'),
    title = 'Partial effect of rising gross rents on rent burden, income varying') +
  partial.effect.plot.theme
ggsave(width = 1000/172, height = 800/172, dpi = 172,
  file = '~/Workspace/Housing-Cost-Burden/outputs/20190329/partial_effects_plot_Rent_with_Income_varying.png')

ggplot(test.results, mapping = aes(x = -median.renter.income,
  y = prediction)) +
  geom_ribbon(aes(ymin = prediction.by.income.low,
    ymax = prediction.by.income.high, group = Group, fill = Group),
    alpha = 0.3) +
  geom_smooth(aes(group = Group, color = Group, fill = Group,
    linetype = Group), size = 1, method = 'lm', se = FALSE) +
  scale_linetype_manual(values = c('solid', 'dashed')) +
  scale_color_manual(values = brewer.pal(5, 'RdGy')[c(1,5)]) +
  scale_fill_manual(values = brewer.pal(5, 'RdGy')[c(1,5)]) +
  scale_y_continuous(expand = c(0, 0)) +
  scale_x_continuous(expand = c(0, 0), labels = function (s) {
    return(sprintf('-%s', scales::comma(s)))
  }) +
  labs(x = 'Decrease in Median Renter Income (2017 USD)',
    y = TeX('$\\Delta\\,$Percent Population Rent-Burdened'),
    title = 'Partial effect of falling renter incomes on rent burden, rent varying') +
  partial.effect.plot.theme +
  theme(plot.margin = margin(5.5, 15, 5.5, 5.5, 'pt'))
ggsave(width = 1000/172, height = 800/172, dpi = 172,
  file = '~/Workspace/Housing-Cost-Burden/outputs/20190329/partial_effects_plot_Income_with_Rent_varying.png')
---
title: "Bayesian Hierarchical Non-Linear Modeling with LOESS Smoothing"
author: "SP"
date: "`r Sys.Date()`"
output: html_document
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```


The Bayesian hierarchical approach offers many advantages over traditional frequentist methods when dealing with complex data structures and when prior knowledge is available:

- Incorporation of Prior Knowledge: This method allows for the integration of prior knowledge or expert opinion through the use of priors, which can improve estimates, especially when data is scarce or noisy.

- Probabilistic Interpretation: Bayesian inference provides a probabilistic interpretation of model parameters, giving a full distribution of possible values rather than a single point estimate, which adds richness to the understanding of parameter uncertainties.

- Flexibility in Model Specification: Hierarchical models can easily accommodate varying levels of randomness and complex data structures, which is often more cumbersome in frequentist frameworks.

- Direct Probability Statements: Bayesian statistics let you make direct probability statements about parameters (e.g., "The probability that a parameter is greater than zero"), whereas frequentist methods only provide probabilities of data given a hypothesis.

- Model Comparison and Averaging: Bayesian methods facilitate model comparison and averaging without the strict requirements of nested models or concerns over multiple testing that you encounter in the frequentist approach.

- Inference from the Posterior: In Bayesian analysis, inference is drawn from the posterior distribution, which is updated as new data arrives, enabling a natural form of sequential analysis.

- Robustness to Overfitting: Hierarchical Bayesian models can be more robust to overfitting, especially when informed priors are used, due to their ability to shrink estimates toward group-level averages.

- Handling of Missing Data: Bayesian hierarchical models can handle missing data more naturally by treating them as additional parameters to be estimated, under a coherent probabilistic framework.

- Endorsement of Uncertainty: Bayesian methods inherently account for uncertainty in all levels of the modeling process, making them inherently more cautious and, in some sense, more honest about the reliability of inferences.

- Continuous Learning: The Bayesian framework is conducive to continuous learning, as the posterior distribution can be updated with new data, reflecting an evolving state of knowledge without starting the analysis anew.

Setting a prior is a fundamental aspect of Bayesian analysis, and it's both an advantage and a point of criticism. Properly chosen priors can regularize estimates, inject substantive knowledge into the analysis, and improve inference, especially in small samples or complex models. However, the choice of prior must be made carefully to avoid undue influence on the results, and this process should be transparent and justified within the context of the analysis. Bayesian hierarchical models are especially powerful in situations where parameters are expected to vary by group or category but also share commonalities, as they can borrow strength across these groups to make more informed estimates. This is particularly useful in medical, biological, or social sciences where individual-level variability is nested within larger group-level trends.


## Load libraries
```{r include=FALSE}
library(tidyverse) # for everything good in R
library(brms) # for bayesian linear modeling
library(splines) # to add splines 
library(report) # for quick reporting of the analysis
```

## Get the theophylline dataset from the base `datasets` library
```{r include=FALSE}
df <- datasets::Theoph # theophylline pharmacokinetics data
head(Theoph) # glance at the theophylline data
```
## Plot raw data to get a sense of how the data looks like
```{r}
ggplot(df, aes(x = Time, y = conc)) + geom_point() + 
  scale_x_continuous(breaks = seq(0,20,2))
```
#### We can see in this plot that there is a very conspicuous change in the rate of concentration change at Time = 1s. A simple linear model won't cut it. Therefore, we need to build a non-linear model to account for this peculiarity.


## Build a Bayesian generalized non-linear multivariate multilevel (Hierarchical) model adjusting for participant weight and dose of theophylline
```{r include=FALSE}
model <- brm(
  conc ~ bs(Time, knots = c(1)) + (1 | Subject) + Wt + Dose, # adjusting for weight and dose of theophylline
  data = df,
  family = gaussian(), # for continuous outcomes
  prior = c(
    set_prior("normal(0,5)", class = "b"), # priors for fixed effects
    set_prior("normal(0,5)", class = "sd")  # priors for group-level effects
  ),
  chains = 2, iter = 5000, warmup = 2000,
  control = list(adapt_delta = 0.95)
)
```

# Generate a model summary
```{r}
summary(model)
```

## Generate a model report
```{r}
report(model)
```

# Plot the fitted model
```{r}
fitted_values <- fitted(model)
df_fitted <- data.frame(Time = df$Time, ActualConc = df$conc, FittedConc = fitted_values)

# plotting
ggplot(df_fitted, aes(x = Time)) +
  geom_point(aes(y = ActualConc)) + # actual data points
  geom_line(aes(y = FittedConc.Estimate)) # fitted spline curve
```
#### This fitted model had a lot of noise at specific time points. However, the model works well for our purpose. We can play around with refining prior distributions, setting more degrees of freedom for knots, or using cubic splines. We can use a quick and dirty technique to smoothen the curve - the Locally Estimated Scatterplot Smoothing (LOESS) technique.

## Smoothening the noisy curve
```{r}
df_fitted <- data.frame(Time = df$Time, FittedConc = fitted_values)

# apply a LOESS smoother to the fitted values
loess_fit <- loess(FittedConc.Estimate ~ Time, data = df_fitted, span = 0.4)  # ajust 'span' for smoothness

# generate smooth predictions from the LOESS model
df_fitted$SmoothConc <- predict(loess_fit)

# plotting
ggplot(df, aes(x = Time)) +
    geom_point(aes(y = conc)) +  # actual data points
    geom_line(data = df_fitted, aes(y = SmoothConc), size = 1) # smoother curve
```
## Visualizing prior and posterior distribution curves at various knotted time points
```{r}
posterior_samples <- as.data.frame(posterior_samples(model))

prior_distribution <- data.frame(Parameter = rnorm(1000, mean = 0, sd = 5))

posterior_distribution <- posterior_samples %>%
    select(b_bsTimeknotsEQc11) %>%
    rename(Parameter = b_bsTimeknotsEQc11)

combined_distribution <- rbind(
    data.frame(Parameter = prior_distribution$Parameter, Type = "Prior"),
    data.frame(Parameter = posterior_distribution$Parameter, Type = "Posterior")
)

ggplot(combined_distribution, aes(x = Parameter, fill = Type)) +
    geom_density(alpha = 0.6) +
    scale_fill_manual(values = c("blue", "green")) +
    labs(title = "Prior and Posterior Distributions", x = "Parameter Value", y = "Density") +
    theme_minimal()

posterior_samples <- as.data.frame(posterior_samples(model))

prior_distribution <- data.frame(Parameter = rnorm(1000, mean = 0, sd = 5))

posterior_distribution <- posterior_samples %>%
    select(b_bsTimeknotsEQc12) %>%
    rename(Parameter = b_bsTimeknotsEQc12)

combined_distribution <- rbind(
    data.frame(Parameter = prior_distribution$Parameter, Type = "Prior"),
    data.frame(Parameter = posterior_distribution$Parameter, Type = "Posterior")
)

ggplot(combined_distribution, aes(x = Parameter, fill = Type)) +
    geom_density(alpha = 0.6) +
    scale_fill_manual(values = c("blue", "green")) +
    labs(title = "Prior and Posterior Distributions", x = "Parameter Value", y = "Density") +
    theme_minimal()

posterior_samples <- as.data.frame(posterior_samples(model))

prior_distribution <- data.frame(Parameter = rnorm(1000, mean = 0, sd = 5))

posterior_distribution <- posterior_samples %>%
    select(b_bsTimeknotsEQc13) %>%
    rename(Parameter = b_bsTimeknotsEQc13)

combined_distribution <- rbind(
    data.frame(Parameter = prior_distribution$Parameter, Type = "Prior"),
    data.frame(Parameter = posterior_distribution$Parameter, Type = "Posterior")
)

ggplot(combined_distribution, aes(x = Parameter, fill = Type)) +
    geom_density(alpha = 0.6) +
    scale_fill_manual(values = c("blue", "green")) +
    labs(title = "Prior and Posterior Distributions", x = "Parameter Value", y = "Density") +
    theme_minimal()

posterior_samples <- as.data.frame(posterior_samples(model))

prior_distribution <- data.frame(Parameter = rnorm(1000, mean = 0, sd = 5))

posterior_distribution <- posterior_samples %>%
    select(b_bsTimeknotsEQc14) %>%
    rename(Parameter = b_bsTimeknotsEQc14)

combined_distribution <- rbind(
    data.frame(Parameter = prior_distribution$Parameter, Type = "Prior"),
    data.frame(Parameter = posterior_distribution$Parameter, Type = "Posterior")
)

ggplot(combined_distribution, aes(x = Parameter, fill = Type)) +
    geom_density(alpha = 0.6) +
    scale_fill_manual(values = c("blue", "green")) +
    labs(title = "Prior and Posterior Distributions", x = "Parameter Value", y = "Density") +
    theme_minimal()
```

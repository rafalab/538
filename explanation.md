<script type="text/javascript"
        src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.0/MathJax.js?config=TeX-AMS_CHTML"></script>


### Summary

The code needed to reproduce analysis is at [https://github.com/rafalab/538](https://github.com/rafalab/538)

The model is for the Biden - Trump spread. 


* Biden advantage in fundamentals: Represented by $b$ below. How many percentage points we think the polls are off in favor of Biden. A value of -1% means we add 1% in favor of Trump to the spread estimate of each state. 

* Nation-level error SD: Represented by $\sigma$ below. This is the standard error of an error that we expect to affect polls equally for all states. This parameter has a big impact on the final estimate as it quantifies how much we trust polls in general. Lower values greatly favor whoever is ahead in the polls. 

* State-level error SD: Represented by $\sigma_Z$ below. This is the standard error of the difference between state-level average poll spread and the election day result. Because this error averages out when we combine the results from all states, it does not have as strong effect as the nation-level error.

* Polls versus fundamentals weight: Represented by $\tau$ below. This parameter is the standard error of the prior distribution used to adjust the state-specific spread estimates.  The closer $\tau$ is to 0, the less weight the poll averages receive.

* Error distribution DF (global): These are the degrees of freedom of the t-distribution used to generate random national-level errors $\varepsilon$. Values closer to 0 will generate larger outliers. Values of 30 and above result in the t-distribution being equivalent to a normal distribution.

* Error distribution DF (state): These are the degrees of freedom of the t-distribution used to generate random state-level errors $\delta_i$. Values closer to 0 will generate larger outliers. Values of 30 and above result in the t-distribution being equivalent to a normal distribution.


<!-- * Number of simulations: Number of elections simulated. Larger values result in more stable results. -->

### Introduction 

This is an attempt at reproducing the [FiveThirtyEight election forecast model](https://projects.fivethirtyeight.com/2020-election-forecast/), which is described in some 
detail [here](https://fivethirtyeight.com/features/how-fivethirtyeights-2020-presidential-forecast-works-and-whats-different-because-of-covid-19/).

The general idea is to base predictions on the distribution of election day results for all other previous elections that had similar poll results and fundamentals (demographics and economic data) as we see today. Because there aren't enough elections to use a simple approach, such as tabulation, we try to train a statistical model that is defined by a small number of parameters that we can estimate. We then use the model to predict the election day distribution. A statisticians refers to this as estimating the conditional distribution for the election day result given today's poll data and fundamentals. 

The essence of the approach comes down to modeling the election day spread (difference between Biden and Trump) for each state. We denote this quantity with $Y_i$ with $i$ an index for states.


### The model

We model the conditional distribution of election day results $Y_i$ with this approximation: 

$$
Y_i = B + Z_i 
$$

with $B$ and $Z_i$ used to represent national and state level uncertainty, respectively.

We further decompose the model as described below.


#### General election day bias


We include the random term $B$ to account for the fact that, historically, we observe consistent difference between the average of polls and the election day result. 
This bias has gone either way, Republican or Democrat, and is difficult or impossible to estimate. We therefore model the bias $B$ as follows:


$$
B = b + \sigma \varepsilon
$$

with tje random term $\varepsilon$ explaining the uncertainty introduced by not knowing what this bias will be. The variability of this term is controlled by the parameter $\sigma$. Historically we have observed values consistent with a standard deviation between 2-3, with the value decreasing as the election gets closer. If for some reason we think there is more uncertaint, say due to the COVID-19 pandemic, we can increase the value of $\sigma$.

Note that modeling this term allows FiveThirtyEight to account for a source of variability that is not observable from the polls data. Including this term implies to declare a state as having a probability higher than 99% for either candidate requires a lead in the polls larger than $2.5 \sigma$. Setting $\sigma$ at 4, as we think FiveThirtyEight currently does,implies we need to see a lead of 9 or more to call a state solidly blue or red. We suspect other well-known forecasters don't model this level of uncertainty, which explains why many of them incorrectly gave Clinton a 99%+ probability of wining in 2016. If you make $\sigma$, 0 you will see that the model gives Biden a 99%+ chance of wining. If you set it to 2, 3, or 4 the probability is reduced substantially.

#### Outliers

We sometimes observe large exceptions or outliers not consistent with a normal distribution with a standard deviation of 2 or 3. For example in 2014 we observed a [bias in the polls in favor of the Democrats larger than 4%](https://fivethirtyeight.com/features/the-polls-were-skewed-toward-democrats/). We therefore, model $\varepsilon_i$ with a distribution that can generate outliers, the t-distribution. We control how big these outliers can be with a parameter called the _degrees of freedom_. If we set the degree of freedom at 3, we will see outliers about 1 in every 100 election, and if we set it at 30 we will see them very rarely, less than 1 in a million. Some of the overconfident modelers that gave Hillary a 99% of wining in 2016 failed to model these outliers properly. 

#### Predictable systematic bias

Note that although we model a bias with $\varepsilon$, we can't predict which way it will go: 
we assume the same probability of favoring one candidate over others. The parameter $b$ permits us to change this if we have reason to believe that the polls are favoring one candidate over the others, we control this through the parameter $b$. For example, based on the fundamentals and difference between likely and registered voter polls, FivetThirtyEights thinks that the polls are slightly favoring Biden, and seem to be setting $b$ at about -1%.


#### State-level variability  

The state-level part of the model can be further decomposed as 

$$
Z_i = \mu_i + \sigma_Z \delta_i
$$

Here $\mu_i$ represents the average Biden - Trump spread for all polls conducted in state $i$. We include a random term $\varepsilon_i$ to account for the fact that, historically, we observe a difference between this average and the election day result not accounted for the general bias $B$. The parameter $\sigma_Z$ controls how much this random term varies. Historically we see that it is about 2 percentage point. We often observe large state-specific outliers. For example, in 2016 Trump won Wisconsin by 0.7% when the average polls predicted he would lose by 4% to 6%. We therefore, also model $\varepsilon_i$ with a the t-distribution. 

#### Estimating the state-level parameters

In our simulation we set the $\sigma$ and $\sigma_Z$ parameters to values we find to be consistent with historical data. The rest of the parameters, the $\mu_i\mbox{s}$ we estimate by aggregating poll data. Because there are not always enough polls to obtain a precise estimate, FiveThirtyEight uses weighted average between demographic data and poll data. We can achieve this using a Bayesian approach in which we assume a prior distribution of each $\mu_i$ and the compute a posterior based on the poll data. 

Specifically, let $X_1, \dots, X_N$ represent the estimated Biden - Trump spread for $N$ polls and $\bar{X}$ the average of these polls. Note that FiveThirtyEight uses a weighed average, with weights based on the quality of the pollsters and how recent they are. Here we take a simple average. We then use the Central Limit Theorem to assume that $\bar{X}$ follows a normal distribution with average $\mu_i$ and standard deviation  $s_i/ \sqrt{N}$

$$
\bar{X} \sim \mbox{Normal}(\mu_i, s_i/ \sqrt{N})
$$

with $s_i$ the across pollster standard deviation, which we estimate with the sample standard deviation of $X_1, \dots, X_N$.

We then assume a prior distribution for $\mu_i$ to also be normal with average $\theta_i$, determined by fundamentals, and standard deviation $\tau$. We then estimate $\mu_i$ using the posterior mean which is a weighted average between the poll average and the prediction based on fundamentals $\theta_i$ 

$$
\hat{\mu_i} = w \theta_i + (1-w) \bar{X}
$$

with 

$$
w = \frac{s_i^2/N}{s_i^2/N + \tau^2}
$$

We can also compute the variance of this estimate as

$$
\mbox{Var}(\hat{\mu_i}) = \frac{1}{N/s_i^2 + 1/\tau^2}
$$

which becomes negligible when the number of polls $N$ is large.

Note that we can control how much we weight the polls over the fundamentals by increasing $\tau$.


#### Monte Carlo simualtions

Once we have the estimates described above we ready to plug then into the model 
and general 40,000 election day results for each state. From these 40,000 results we compute the 
probability of Biden wining as the proportion of times the total electoral votes are 
above 270.

You can see the code for the simulation [here](https://github.com/rafalab/538/blob/master/funcs.R).
### Notable diferences

Details of the FiveThirtyEight model are not all available so we make our best attempt
at replicating them. Here are some aspects in which we know there are differences:

* We only consider the Biden - Trump spread and as a result implicitly assign the undecideds equally.

* We don't know how the predictions based on fundamentals are made for each state so
we use the 2016 election day result for the priors $\theta_i$.

* Nebraska and Maine split their electoral votes. This is not included in our simulation. We treat them as one state.

* When computing the state-level average spread from polls we do not use weights. We exclude pollster
with a FiveThirtyEight rating below a C and only consider polls ending during the last two weeks. For 
states that have less than 8 polls in the last two weeks, we permit older polls.

* FiveThirtyEight has a much more sophisticated model for $B$ that incorporates correlation between states. 
For example, in 2016, the general election bias was larger for four geographically contiguous states: Pennsylvania, Ohio, Michigan, and Wisconsin. It's possible that the more sophisticated model can capture this geographic specific variability.

<br>
<br>





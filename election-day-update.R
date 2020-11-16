library(tidyverse)
library(jsonlite)
library(scales)

states <-c('pennsylvania', 'georgia', 'arizona', 'nevada')
## Define the perctent at which the linear trend starts. Used EDA to determine.
starts <- c(82.5, 94, 85, 85) 

dat <- map_df(seq_along(states), function(i){
  
  url <- paste0("https://static01.nyt.com/elections-assets/2020/data/api/2020-11-03/race-page/",
                states[i],"/president.json")
  raw <- jsonlite::fromJSON(url)
  
  n <- raw$data$races$tot_exp_vote 

  dat <- raw$data$races$timeseries[[1]]$vote_shares%>%
    mutate(Trumps_lead = (trumpd - bidenj)*100,
           pct_reporting = raw$data$races$timeseries[[1]]$votes / n * 100) %>%
    filter(pct_reporting >= starts[[i]])
  
  fit <- lm(Trumps_lead ~ pct_reporting, data = dat)
  
  x <- c(dat$pct_reporting, seq(max(dat$pct_reporting), 100, len = 25))
                
  ## We computer standard errors assuming independence
  ## These data are clearly not independent so the error bars underestimate
  ## Furthermore we think the main source of variability comes from m
  fit <- predict(fit, newdata = data.frame(pct_reporting = x), se.fit = TRUE)
  
  fit_tab <- data.frame(pct_reporting = x, 
                        reg_line = fit$fit, 
                        upper = fit$fit + 1.96*fit$se,
                        lower = fit$fit - 1.98*fit$se)
  
  
  dat <- left_join(fit_tab, dat, by = "pct_reporting") %>%
    mutate(state = str_to_title(states[i]), n= n)
  
  dat
})
  
dat %>% 
  mutate(state = paste0(state, " (expected total vote = ", prettyNum(n, big.mark = ","), ")")) %>%
  mutate(state = reorder(state, -n, first)) %>%
  ggplot(aes(x = pct_reporting, y = Trumps_lead)) +
  geom_smooth(se=FALSE, lty = 2) + 
  geom_point() +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.25) +
  geom_line(aes(y = reg_line)) +
  ggtitle("Vote difference through the count") + 
  xlab("Percent reporting") + ylab("Trump's percentage lead") +
  geom_hline(yintercept = 0, lty = 2) +
  theme_bw() +
  facet_wrap(~state, scales = "free") 

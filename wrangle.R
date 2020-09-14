library(tidyverse)
library(lubridate)
library(dslabs)
dslabs::ds_theme_set(base_size = 14)
## read-in polls
raw_data <- read_csv("https://projects.fivethirtyeight.com/polls-page/president_polls.csv") 

# wrangle all polls -------------------------------------------------------
## consider only Trump, Biden results and polls conducted in 2020
## fix date format
## compute spread

all_polls <- raw_data %>%
  mutate(end_date = mdy(end_date),
         state = replace_na(state, "Popular Vote")) %>%
  select(question_id,state, pollster, population, poll_id, end_date, fte_grade, answer, pct) %>%
  filter(answer %in% c("Biden", "Trump") & year(end_date) == 2020) %>%
  pivot_wider(names_from = answer, values_from = pct) %>%
  mutate(spread = Biden/100 - Trump/100) %>%
  filter(!is.na(spread)) 


# wrangle polls -----------------------------------------------------------
## define function to pick top 8 when available
## fix date format
## remove bad polls
## take only recent polls
## consider only state

recent_polls <- function(dat, last_day = today() - weeks(2)){
  dat <- arrange(dat, desc(end_date))
  
  n_all <- nrow(dat) 
  
  n_recent <- dat %>% 
    filter(end_date >= last_day) %>%
    summarize(n = length(unique(pollster)), .groups = "drop") %>%
    pull(n)
  
  if(n_recent > 8) 
    return(filter(dat, end_date >= last_day)) 
  else{
    if(n_all > 8) 
      return(slice(dat, 1:8))
    else 
      return(dat)
  }
}

polls <- all_polls %>%  
  filter(state != "Popular Vote" & !fte_grade %in% c("C/D","D-") &!str_detect(state, "CD")) %>%
  nest_by(state) %>% 
  summarize(recent_polls(data), .groups = "drop") 

## Compute poll average and across pollster SD
## first combine polls from same pollster
results <- polls %>% 
  group_by(state, pollster) %>%
  summarize(spread = mean(spread), .groups = "drop") %>%
  ungroup() %>%
  group_by(state) %>%
  summarize(polling_avg = mean(spread), polling_sd = sd(spread), n = n(), .groups = "drop") %>%
  ungroup()

## Add EV and if only one poll use median SD
results <- mutate(results_us_election_2016, spread_2016 = clinton/100 - trump/100) %>%
  select(state, electoral_votes, spread_2016) %>%
  left_join(results, by = "state") %>%
  mutate(polling_sd = ifelse(n==1, median(polling_sd, na.rm=TRUE), polling_sd))
            

swing_states <- results %>% filter(abs(polling_avg) <= .075) %>%
  pull(state) %>% sort()

state_names <- c("Popular Vote", swing_states, 
                 sort(setdiff(unique(results$state), swing_states)))


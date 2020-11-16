library(tidyverse)
library(jsonlite)
library(scales)

states <- tolower(str_replace(state.name, " ", "-"))
dat <- map_df(seq_along(states), function(i){
  
  url <- paste0("https://static01.nyt.com/elections-assets/2020/data/api/2020-11-03/race-page/",
                states[i],"/president.json")
  raw <- jsonlite::fromJSON(url)
  
  n <- raw$data$races$tot_exp_vote 
  
  dat <- bind_cols(raw$data$races$timeseries[[1]]$vote_shares,
                   raw$data$races$timeseries[[1]][,-1]) %>%
    mutate(state = str_to_title(states[i]), vote_share = n) %>%
    select(state, everything()) %>%
    mutate(timestamp = lubridate::ymd_hms(timestamp))
  dat
})

if(!file.exists("rdas")) dir.create("rdas") 
saveRDS(dat, paste0("rdas/all-states-election-night-updates-",format(lubridate::now(), "%Y-%m-%d_%H:%M:%S"),".rds"))
  
dat %>% 
  mutate(trump_lead = trumpd - bidenj, 
         pct_reporting = votes/vote_share,
         lead = ifelse(trump_lead > 0, "0Trump", "1Biden")) %>%
  group_by(state) %>%
  arrange(pct_reporting) %>%
  mutate(final = trump_lead[which.max(pct_reporting)]) %>%
  ungroup() %>%
  mutate(state = reorder(state, final, first)) %>%
  filter(pct_reporting > 0.25) %>%
  ggplot(aes(pct_reporting, trump_lead, color = lead)) +
  geom_hline(yintercept = 0, lty = 2) +
  geom_point(show.legend = FALSE, cex = 1) +
  facet_wrap(~state, ncol = 10) + 
  scale_x_continuous(labels = scales::percent) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Percent Reporting") +
  ylab("Trump's Lead") + 
  ggtitle("Trump lead time series") +
  theme_bw()

ggsave("~/Desktop/edison.png", width = 14, height = 7.5)

library(dslabs)
library(lubridate)

tmp <- select(results_us_election_2016, state, electoral_votes) %>%
  mutate(state = str_replace(state, " ", "-"))

#                 floor_date(), unit = "hour")) %>%

ev <- dat %>% filter(votes > 0) %>%
  mutate(trump_lead = trumpd - bidenj, 
         pct_reporting = votes/vote_share,
         timestamp = with_tz(timestamp, tzone = "America/New_York")) %>%
  select(state, pct_reporting, trump_lead, timestamp) %>%
  left_join(tmp, by = "state")

times <- seq(make_datetime(2020, 11, 3, 21, 0, 0, tz = "America/New_York"), 
             make_datetime(2020, 11, 7, 2, 0, 0, tz = "America/New_York"), 
             by = "hours")
tally_time <- map_df(times, function(the_time){
  ev %>% filter(timestamp <= the_time) %>%
    arrange(desc(timestamp)) %>% 
    group_by(state) %>% 
    slice(1) %>%
    ungroup() %>% 
    summarize(time = the_time, 
              Trump = sum((trump_lead > 0) * electoral_votes, na.rm = TRUE),
              Biden = 3+sum((trump_lead < 0) * electoral_votes, na.rm = TRUE))
})


pcts <- seq(0.01, 1, len=100)
tally_pct <- map_df(pcts, function(the_pct){
  ev %>% filter(pct_reporting <= the_pct) %>%
    arrange(desc(timestamp)) %>% 
    group_by(state) %>% 
    slice(1) %>%
    ungroup() %>% 
    summarize(pct_reporting = the_pct, 
              Trump = sum((trump_lead > 0) * electoral_votes, na.rm = TRUE),
              Biden = 3+sum((trump_lead < 0) * electoral_votes, na.rm = TRUE))
})

p1 <- tally_time %>%
  gather(candidate, ev, -time) %>% 
  mutate(candidate = factor(candidate, levels = c("Trump", "Biden"))) %>%
  ggplot(aes(time,  ev, color = candidate)) +
  geom_hline(yintercept = 270,lty=2) +
    geom_line() +
  theme_bw()



p2 <- tally_pct %>%
  gather(candidate, ev, -pct_reporting) %>% 
  mutate(candidate = factor(candidate, levels = c("Trump", "Biden"))) %>%
  ggplot(aes(pct_reporting,  ev, color = candidate)) +
  geom_hline(yintercept = 270, lty = 2) +
  geom_line()+
  theme_bw()

p<- gridExtra::grid.arrange(p2,p1, nrow=2)
ggsave("~/Desktop/edison-2.png", p, width = 12, height = 8)



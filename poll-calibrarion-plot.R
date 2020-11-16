library(tidyverse)
dat <- read_csv("https://projects.fivethirtyeight.com/2020-general-data/presidential_state_toplines_2020.csv")
fte <- dat %>% 
  arrange(desc(modeldate)) %>%
  group_by(state) %>%
  slice(1) %>%
  ungroup() %>%
  mutate(estimate = voteshare_inc  - voteshare_chal,
        lo = sqrt((voteshare_inc - voteshare_inc_lo)^2 + (voteshare_chal - voteshare_chal_lo)^2),
        hi = sqrt((voteshare_inc_hi -  voteshare_inc)^2 + (voteshare_chal_hi -  voteshare_chal)^2)) %>%
  select(state, estimate, lo, hi)
  
edison <- readRDS("rdas/all-states-election-night-updates-2020-11-16_10:30:34.rds")
final <- edison %>% 
  arrange(desc(timestamp)) %>%
  group_by(state) %>%
  slice(1) %>%
  ungroup() %>%
  mutate(state = str_replace(state, "-", " "), trump_lead = (trumpd - bidenj)*100) %>%
  select(state, trump_lead)

library(ggrepel)
left_join(final, fte, by = "state") %>%
  mutate(abb = state.abb[match(state, state.name)]) %>% 
  ggplot(aes(trump_lead, estimate)) +
  geom_abline() +
  geom_hline(yintercept = 0, lty = 2) +  
  geom_vline(xintercept = 0, lty = 2) +  
  geom_errorbar(aes(ymin = estimate - lo, ymax = estimate + hi, color = factor(trump_lead<0)), show.legend = FALSE, width = 0.2) +
  geom_point(aes(color = factor(trump_lead<0)), show.legend = FALSE) + 
  geom_text_repel(aes(label = abb)) +
  xlab("Election day result") +
  ylab("Fivethirtyeight forecast") +
  ggtitle("Fivethirtyeight forecast and 80% confidence intervals of Trump leads versus actual results") +
  theme_bw() +
  xlim(c(-50,50)) +
  ylim(c(-50,50)) 
ggsave("~/Desktop/fte-did-it-again.png",  width = 10, height = 7.5)

left_join(final, fte, by = "state") %>%
  mutate(diff = trump_lead - estimate) %>%
  summarize(median(diff), sd(diff))

left_join(final, fte, by = "state") %>%
  mutate(covered = trump_lead <= estimate + hi & trump_lead>=estimate -lo) %>%
  summarize(mean(covered))


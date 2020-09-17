## wrange.R has to run before this function works
run_sim <- function(B = 40000, tau = 0.02, global_bias = -0.01, 
                    global_error_sd = 0.03, state_error_sd = 0.02, 
                    df_g = 3, df_s = 3){
  
  # prior means are 2016 results
  mu <- results$spread_2016 
  
  ## compute weights for posterior mean
  sigma <- with(results, polling_sd / sqrt(n))
  w <- sigma^2 / (sigma^2 + tau^2)
  
  # compute the adjusted spread with posterior means
  posterior_mean <- with(results, ifelse(is.na(w), mu, w*mu + (1-w)*polling_avg)) + 
    global_bias
  
  # compute SE of the adjusted spread
  posterior_se <- with(results,  
                       ifelse(is.na(w), 0, sqrt(1/(1/sigma^2 + 1/tau^2))))
  
  # simulate state-level errors
  errors <- matrix(rt(B*nrow(results), df_s), nrow(results), B) 
  
  # simulate election day results. 
  # Add state-level error and national level error to expected spread
  sim <- sweep(errors, 1, sqrt(state_error_sd^2 + posterior_se^2), FUN = "*") + 
    sapply(rt(B, df_g)*global_error_sd, function(b) posterior_mean + b)
  
  # spread can't be larger than 1
  sim <- pmax(pmin(sim,1), -1)
  
  # compute electoral college results for each simulation
  biden_ev <- colSums(sweep(sim>0, 1, results$electoral_votes, FUN = "*")) 
 
  # prepare results table
  state_results <- tibble(state = paste0(results$state, " (", results$electoral_votes,")"),
                          polling_avg = round(results$polling_avg*100,1),
                          posterior_mean = round(posterior_mean*100,1),
                          prob = round(rowMeans(sim>0), 2)*100,
                          n = replace_na(results$n,0), 
                          spread_se = round(matrixStats::rowSds(sim)*100, 1)) %>%
    arrange(state)
                          
  names(state_results) <- c("State",  "Polling average spread", "Adjusted spread", 
                            "Prob of Biden Win", "Number of polls", "Spread SE")
  
  return(list(biden_ev = biden_ev, state_results = state_results))
}

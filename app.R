library(shiny)
source("wrangle.R")
source("funcs.R")

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("FiveThirtyEight 2020 Forecast Approximation"),

    # Sidebar with a slider input for number of bins 
    sidebarLayout(
        sidebarPanel(
            
            sliderInput("global_bias",
                        "Biden advantage in fundamentals",
                        min = -5,
                        max = 5,
                        step = 0.1,
                        value = -1,
                        ticks = FALSE),
            
            sliderInput("global_error_sd",
                        "Nation-level error SD",
                        min = 0,
                        max = 10,
                        step = 0.1,
                        value = 4,
                        ticks = FALSE),
            
            sliderInput("state_error_sd",
                        "State-level error SD",
                        min = 0,
                        max = 10,
                        step = 0.1,
                        value = 2,
                        ticks = FALSE),
            
            sliderInput("tau",
                        "Polls versus fundamentals weight",
                        min = 0,
                        max = 25,
                        step = 0.1,
                        value = 3,
                        ticks = FALSE),
            
            sliderInput("df_g",
                        "Error distribution DF (global)",
                        min = 1,
                        max = 30,
                        value = 5,
                        ticks = FALSE),
           
           
             sliderInput("df_s",
                        "Error distribution DF (state)",
                        min = 1,
                        max = 30,
                        value = 5,
                        ticks = FALSE),
            # sliderInput("B",
            #             "Number of simulations",
            #             min = 10000,
            #             max = 100000,
            #             step = 10000,
            #             value = 40000,
            #             ticks = FALSE),
            # 
            
            actionButton("go", "Simulate!"),
            
            hr(),
            
            selectInput("state",
                        "State (only used for trend plot)",
                        state_names,
                        selected = "Popular Vote"),
        ),    
            

        mainPanel(
            tabsetPanel(
                tabPanel("Electoral College",
                         htmlOutput("biden_prob"),
                         plotOutput("electoral_college")),
                
                tabPanel("Swing States",
                         DT::dataTableOutput("swing_states")),
                
                tabPanel("All States",
                         plotOutput("map"),
                         hr(),
                         DT::dataTableOutput("states")),
                         
                tabPanel("Trends",
                         plotOutput("trends"),
                         DT::dataTableOutput("trends_table")),
                
                tabPanel("Parameter Explanation",
                         includeMarkdown("explanation.md")
                  )
            )
        )
    )
)
 

# Define server logic required to draw a histogram
server <- function(input, output, session) {
    
    res <- eventReactive(input$go, {
        run_sim(B = 40000, 
                input$tau/100, 
                input$global_bias/100, 
                input$global_error_sd/100, 
                input$state_error_sd/100, 
                input$df_g, 
                input$df_s)
    }, ignoreNULL = FALSE)
    
    
    output$biden_prob <- renderText({
        biden_ev <- res()$biden_ev
        win_prob <- round(mean(biden_ev > 270)*100)
        biden_expected <- round(mean(biden_ev))
        paste("<h3>Probability of Biden win:", win_prob, "in 100\n",
              "<br>\n",
              "<h3>Average result: Biden", biden_expected, "Trump",  538 - biden_expected,
              "<h3>80% cofidence interval for spread:", 
              paste0("(", paste0(quantile(2*biden_ev - 538, c(.1,.9)), collapse = ", "), ")"),
              "<hr> <br>")
    }
    )
              
    output$map <- renderPlot({
        res <- res()$state_results 
        res$State <- str_remove(res$State, "\\s\\(\\d+\\)")
        res$state <- state.abb[match(res$State, state.name)]
        res$state[res$State=="District of Columbia"] <- "DC"
        res$col <- pmin(pmax(res$`Prob of Biden Win`, 5), 95)
        usmap::plot_usmap(data = res, values = "col", color = "white", labels = TRUE) + 
            scale_fill_continuous(name = "Probability of Biden Win", low = "red", high = "blue") +
            theme(legend.position = "right") +
            ggtitle("Electoral College Map")
    })
    output$electoral_college<- renderPlot({
       
        biden_ev <- res()$biden_ev
         
        data.frame(ev = biden_ev) %>%
            ggplot(aes(x = ev, y = ..density..)) +
            geom_histogram(binwidth = 1, fill = "darkblue", alpha = 0.25) +
            geom_density(color = "darkblue", adjust = 1, lwd = 1) +
            scale_x_continuous(breaks = seq(0, 500, 100), limits = c(-0.5, 538.5)) +
            geom_vline(xintercept = 270) + 
            ggtitle("All Simulated Electoral College Outcomes") +
            xlab("Electoral Votes for Biden") +
            ylab("Proportion of simulations")
    })
    
    output$swing_states <-  DT::renderDataTable({
        
        swing_results <- res()$state_results %>% filter(abs(`Prob of Biden Win`-50) <= 45) %>%
            arrange(`Prob of Biden Win`)
    
        DT::datatable(swing_results ,  #class = 'white-space: nowrap',
                      rownames = FALSE,
                      options = list(dom = 't', pageLength = -1))  %>%
            DT::formatStyle(columns = 1:6, fontSize = '125%') %>%
            DT::formatStyle(1,"white-space"="nowrap")
        
    })
        
    
    output$states <-  DT::renderDataTable({
    
         
        DT::datatable(res()$state_results,  #class = 'white-space: nowrap',
                      rownames = FALSE,
                      options = list(dom = 't', pageLength = -1)) %>%
            DT::formatStyle(1,"white-space"="nowrap")
                                   
    })
    output$trends_table <- DT::renderDataTable({
        tmp <- all_polls %>%
            filter(state == input$state, year(end_date) == 2020 &
                       !fte_grade %in% c("C/D","D-")) %>%
            mutate(Pollster = paste0(str_remove(pollster,  "/.*"), " (", fte_grade, ")"),
                   Biden = round(Biden,1),  Trump = round(Trump,1), Spread = round(spread*100,1)) %>%
            select(end_date, Pollster, fte_grade, population, Biden, Trump, Spread) %>%
            rename(`End date` = end_date, Population = population, Grade = fte_grade)
        
        DT::datatable(tmp,  #class = 'white-space: nowrap',
                      rownames = FALSE,
                      options = list(dom = 't', pageLength = -1)) %>%
            DT::formatStyle(1,"white-space"="nowrap")
        
        
    })
        
    output$trends <- renderPlot({
        tmp <- all_polls %>%
            filter(state == input$state, end_date >= make_date(2020, 6, 1) &
                       !fte_grade %in% c("C/D","D-")) %>%
            mutate(spread = spread * 100,
                   fte_grade = ifelse(!is.na(fte_grade), paste0(" (", fte_grade, ")"), ""),
                   Pollster = paste0(str_remove(pollster,  "/.*"), fte_grade),
                   Population = population) %>%
            mutate(Pollster = str_remove_all(Pollster, "\\s+College|\\s+Univerisy|Center\\sfor"))
        
        if(nrow(tmp) < 1) return(NULL) 
        else{
            keep <- tmp %>% group_by(Pollster) %>%
                summarise(n = n(), .groups = "drop") %>%
                ungroup() %>%
                arrange(desc(n)) %>%
                slice(1:8) %>%
                pull(Pollster)
            
            tmp <- tmp %>% 
                mutate(fte_grade = if_else(Pollster %in% keep, fte_grade, as.character(NA)),
                       Pollster = if_else(Pollster %in% keep, Pollster, "Other"))
            
            lim <-  max(c(abs(tmp$spread), 25))
            
            delta <- mean(-diff(as.numeric(tmp$end_date)), trim = 0.1)
            points_per_window <- 28 / delta
            span <- pmin(pmax(points_per_window / nrow(tmp), 5/nrow(tmp)), 1)
        
            res <- tmp %>%
                mutate(Pollster = factor(Pollster, levels = c(setdiff(unique(Pollster), "Other"), "Other"))) %>%
                ggplot(aes(end_date, spread)) +
                geom_hline(yintercept = 0, lty = 2) +
                coord_cartesian(ylim =  c(-lim, lim)) + 
                ggtitle(input$state) +
                ylab("Biden - Trump") + xlab("Last day of poll")  + 
                theme(legend.position="bottom", legend.direction = "horizontal", 
                      legend.box = "vertical",
                      legend.title.align= 0.5, 
                      legend.text = element_text(size = 8),
                      legend.title = element_text(size = 10),
                      legend.spacing = unit(0, "cm")) +
                guides(color = guide_legend(order = 1, title.position = "top"), 
                       pch = guide_legend(title.position = "left"),
                       title.vjust = 0)
            if(nrow(tmp) >= 10)  
                res <- res + geom_smooth(method = "loess", formula = "y~x", span = span,
                                         method.args = list(degree = 1, family = "symmetric"),
                                         color = "black", alpha = 0.5)
            res <- res + geom_point(aes(color = Pollster, pch = Population), cex = 2)

            return(res)
        }
    })
}

# Run the application 
shinyApp(ui = ui, server = server)

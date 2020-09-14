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
            selectInput("state",
                        "State (only used for trend plot)",
                        state_names,
                        selected = "Popular Vote"),
            
            sliderInput("global_bias",
                        "Biden advantage in fundamentals",
                        min = -5,
                        max = 5,
                        step = 0.1,
                        value = -1),
            
            sliderInput("global_error_sd",
                        "Nation-level error SD",
                        min = 0,
                        max = 10,
                        step = 0.1,
                        value = 4),
            
            sliderInput("state_error_sd",
                        "State-level error SD",
                        min = 0,
                        max = 10,
                        step = 0.1,
                        value = 2),
            
            sliderInput("tau",
                        "Polls versus fundamentals weight",
                        min = 0,
                        max = 10,
                        value = 3),
            
            sliderInput("df_g",
                        "Error distribution DF (global)",
                        min = 3,
                        max = 30,
                        value = 3),
           
           
             sliderInput("df_s",
                        "Error distribution DF (state)",
                        min = 3,
                        max = 30,
                        value = 3),
                        

            sliderInput("B",
                        "Number of simulations",
                        min = 10000,
                        max = 100000,
                        step = 10000,
                        value = 40000)),
        mainPanel(
            tabsetPanel(
                tabPanel("Electoral College",
                         htmlOutput("biden_prob"),
                         plotOutput("electoral_college")),
                
                tabPanel("Swing States",
                         DT::dataTableOutput("swing_states")),
                
                tabPanel("All States",
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
    
    res <- reactive(run_sim(input$B, 
                            input$tau/100, 
                            input$global_bias/100, 
                            input$global_error_sd/100, 
                            input$state_error_sd/100, 
                            input$df_g, 
                            input$df_s))
    
    
    output$biden_prob <- renderText({
        biden_ev <- res()$biden_ev
        win_prob <- round(mean(biden_ev > 270)*100)
        biden_expected <- round(mean(biden_ev))
        paste("<h3>Probability of Biden win:", win_prob, "in 100\n",
              "<br>\n",
              "<h3>Expected result: Biden", biden_expected, "Trump",  538 - biden_expected,
              "<h3>80% cofidence interval for spread:", 
              paste0("(", paste0(quantile(2*biden_ev - 538, c(.1,.9)), collapse = ", "), ")"),
              "<hr> <br>")
    }
    )
              
    
    output$electoral_college<- renderPlot({
       
        biden_ev <- res()$biden_ev
         
        data.frame(ev = biden_ev) %>%
            ggplot(aes(x = ev, y = ..density..)) +
            geom_histogram(binwidth = 1, fill = "darkblue", alpha = 0.25) +
            geom_density(color = "darkblue", adjust = 1.5, lwd = 1) +
            scale_x_continuous(breaks = seq(0, 500, 100), limits = c(-0.5, 538.5)) +
            geom_vline(xintercept = 270) + 
            ggtitle("All Simulated Electoral College Outomes") +
            xlab("Electoral Votes for Biden") +
            ylab("Proportion of simulations")
    })
    
    output$swing_states <-  DT::renderDataTable({
        
        swing_results <- res()$state_results %>% filter(abs(`Prob of Biden Win`-50) <= 40)
    
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
            select(end_date, Pollster, fte_grade, Biden, Trump, Spread) %>%
            rename(`End date` = end_date, Grade = fte_grade)
        
        DT::datatable(tmp,  #class = 'white-space: nowrap',
                      rownames = FALSE,
                      options = list(dom = 't', pageLength = -1)) %>%
            DT::formatStyle(1,"white-space"="nowrap")
        
        
    })
        
    output$trends <- renderPlot({
        tmp <- all_polls %>%
            filter(state == input$state, year(end_date) == 2020 &
                       !fte_grade %in% c("C/D","D-")) %>%
            mutate(spread = spread * 100,
                Pollster = paste0(str_remove(pollster,  "/.*"), " (", fte_grade, ")"),
                Population = population)
        
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
        points_per_window <- 14/delta
        span <- points_per_window / nrow(tmp)
        
        tmp %>%   ggplot(aes(end_date, spread)) +
            geom_hline(yintercept = 0, lty = 2) +
            geom_point(aes(color = Pollster, pch = Population), cex = 2) +
            geom_smooth(method = "loess", formula = "y~x",
                        method.args = list(span = span, degree = 1, familiy = "symmetric"),
                        color = "black", alpha = 0.5) +
            coord_cartesian(ylim =  c(-lim, lim)) + 
            ggtitle(input$state) +
            ylab("Biden - Trump") + xlab("Last day of poll")  
    })
    
}

# Run the application 
shinyApp(ui = ui, server = server)
#' deServer
#'
#' Sets up shinyServer to be able to run DEBrowser interactively.
#'
#' @note \code{deServer}
#' @param input, input params from UI
#' @param output, output params to UI
#' @param session, session variable
#' @return the panel for main plots;
#'
#' @examples
#'     deServer
#'
#' @export
#' @importFrom shiny actionButton actionLink addResourcePath column 
#'             conditionalPanel downloadButton downloadHandler 
#'             eventReactive fileInput fluidPage helpText isolate 
#'             mainPanel need numericInput observe observeEvent 
#'             outputOptions parseQueryString plotOutput radioButtons 
#'             reactive reactiveValues renderPlot renderUI runApp 
#'             selectInput shinyApp  shinyServer  shinyUI sidebarLayout 
#'             sidebarPanel sliderInput  stopApp  tabPanel tabsetPanel 
#'             textInput textOutput titlePanel uiOutput tags HTML
#'             h4 img icon updateTabsetPanel updateTextInput  validate 
#'             wellPanel checkboxInput br p checkboxGroupInput onRestore
#'             reactiveValuesToList renderText onBookmark onBookmarked 
#'             updateQueryString callModule enableBookmarking htmlOutput
#'             onRestored NS reactiveVal withProgress tableOutput
#'             selectizeInput fluidRow div renderPrint renderImage
#'             verbatimTextOutput imageOutput renderTable
#' @importFrom shinyjs show hide enable disable useShinyjs extendShinyjs
#'             js inlineCSS onclick
#' @importFrom d3heatmap d3heatmap renderD3heatmap d3heatmapOutput
#' @importFrom DT datatable dataTableOutput renderDataTable formatStyle
#'             styleInterval formatRound
#' @importFrom ggplot2 aes aes_string geom_bar geom_point ggplot
#'             labs scale_x_discrete scale_y_discrete ylab
#'             autoplot theme_minimal theme geom_density
#'             geom_text element_blank
#' @importFrom ggvis add_axis add_legend add_tooltip axis_props
#'             bind_shiny create_broker ggvis ggvisOutput handle_brush
#'             hide_legend layer_bars layer_boxplots layer_points
#'             scale_nominal set_options %>% group_by layer_rects
#'             band scale_numeric hide_axis layer_densities scale_ordinal
#'             layer_text
#' @importFrom plotly renderPlotly plotlyOutput plot_ly add_bars event_data
#' @importFrom gplots heatmap.2 redblue
#' @importFrom igraph layout.kamada.kawai  
#' @importFrom grDevices dev.off pdf colorRampPalette 
#' @importFrom graphics barplot hist pairs par rect text plot
#' @importFrom stats aggregate as.dist cor cor.test dist
#'             hclust kmeans na.omit prcomp var sd model.matrix
#'             p.adjust runif cov mahalanobis quantile as.dendrogram
#'             density
#' @importFrom utils read.csv read.table write.table update.packages
#'             download.file read.delim data
#' @importFrom DOSE enrichDO enrichMap
#' @importFrom enrichplot gseaplot dotplot
#' @importMethodsFrom DOSE summary
#' @importMethodsFrom AnnotationDbi as.data.frame as.list colnames
#'             exists sample subset head mappedkeys ncol nrow subset 
#'             keys mapIds
#' @importMethodsFrom GenomicRanges as.factor setdiff
#' @importMethodsFrom IRanges as.matrix "colnames<-" mean
#'             nchar paste rownames toupper unique which
#'             as.matrix lapply rev "rownames<-"
#'             gsub
#' @importMethodsFrom S4Vectors eval grep grepl levels sapply t 
#' @importMethodsFrom SummarizedExperiment cbind order rbind
#' @importFrom jsonlite fromJSON
#' @importFrom methods new
#' @importFrom stringi stri_rand_strings
#' @importFrom annotate geneSymbols
#' @importFrom reshape2 melt
#' @importFrom baySeq getLibsizes getLikelihoods getLikelihoods.NB
#'             getPriors getPriors.NB nbinomDensity
#' @importMethodsFrom baySeq "densityFunction<-" "libsizes<-"
#' @importFrom clusterProfiler compareCluster enrichKEGG enrichGO
#' @importFrom DESeq2 DESeq DESeqDataSetFromMatrix results estimateSizeFactors
#'             counts
#' @importFrom edgeR calcNormFactors equalizeLibSizes DGEList glmLRT
#'             exactTest estimateCommonDisp glmFit
#' @importFrom shinydashboard dashboardHeader dropdownMenu messageItem
#'             dashboardPage dashboardSidebar sidebarMenu dashboardBody
#'             
#' @importFrom limma lmFit voom eBayes topTable
#' @importFrom sva ComBat
#' @importFrom RCurl getURL
#' @import org.Hs.eg.db
#' @import org.Mm.eg.db
#' @import V8
#' @import shinyBS
#' @import pathview
#' @import colourpicker
#' @import RColorBrewer
#' @import heatmaply

deServer <- function(input, output, session) {
    #library(debrowser)
    options(warn = -1)
    tryCatch(
    {
        if (!interactive()) {
            options( shiny.maxRequestSize = 30 * 1024 ^ 2,
                    shiny.fullstacktrace = FALSE, shiny.trace=FALSE, 
                    shiny.autoreload=TRUE, warn =-1)
            debrowser::loadpack(debrowser)
        }
        # To hide the panels from 1 to 4 and only show Data Prep
        togglePanels(0, c(0), session)
        loadingJSON <- reactive({
            getJsonObj(isolate(session), isolate(input), access_token())
        })

        choicecounter <- reactiveValues(nc = 0, qc = 0, 
            lastselecteddataset = "")
        
        output$programtitle <- renderUI({
            togglePanels(0, c(0), session)
            getProgramTitle(session)
        })
        
        filtd <- reactiveVal()
        batch <- reactiveVal()
        sel <- reactiveVal()
        selected <- reactiveVal()
        dc <- reactiveVal()
        compsel <- reactive({
            cp <- 1
            if (!is.null(input$compselect))
                cp <- input$compselect
            cp
        })

        observe({
            updata <- reactive({ 
                ret <- callModule(debrowserdataload, "load")
                ret
            })
            observeEvent (input$Filter, {
                if(!is.null(updata()$load())){ 
                    updateTabItems(session, "DataPrep", "Filter")
                    filtd(callModule(debrowserlowcountfilter, "lcf", updata()$load()))
                }
            })
            observeEvent (input$Batch, {
                if(!is.null(filtd()$filter())){ 
                    updateTabItems(session, "DataPrep", "BatchEffect")
                    batch(callModule(debrowserbatcheffect, "batcheffect", filtd()$filter()))
                }
            })
            observeEvent (input$goDE, {
                updateTabItems(session, "DataPrep", "CondSelect")
                sel(debrowsercondselect(input, output, session, batch()$BatchEffect()$count, batch()$BatchEffect()$meta))
                choicecounter$nc <- sel()$cc()
            })
            
            observeEvent (input$startDE, {
                dat <- prepDataContainer(batch()$BatchEffect()$count, sel()$cc(), input)
                dc(dat)
                updateTabItems(session, "DataPrep", "DEAnalysis")
                buttonValues$startDE <- TRUE
                buttonValues$goQCplots <- FALSE
            })

            observeEvent (input$goMain, {
                updateTabItems(session, "methodtabs", "panel1")
                updateTabItems(session, "menutabs", "discover")
                togglePanels(0, c( 0, 1, 2, 3, 4), session)
            })
            
            output$compselectUI <- renderUI({
                if (!is.null(sel()))
                    getCompSelection(sel()$cc())
            })

            output$cutOffUI <- renderUI({
                cutOffSelectionUI(paste0("DEResults", compsel()))
            })  
            output$deresUI <- renderUI({
                column(12, getDEResultsUI(paste0("DEResults",compsel())))
            })
            output$dcres <- renderPrint({
                print(head(sel()$cc()))
            })
            output$loadedtable <- renderPrint({
                head( updata()$load()$count )
            })
            output$filtertable <- renderPrint({
                head( filtd()$filter()$count  )
            })
            output$batcheffecttable <- renderPrint({
                head( batch()$BatchEffect()$count )
            })
        })
        output$mainpanel <- renderUI({
            getMainPanel()
        })
        output$qcpanel <- renderUI({
            getQCPanel(input)
        })
        output$gopanel <- renderUI({
            getGoPanel()
        })
        output$cutoffSelection <- renderUI({
            nc <- 1
            if (!is.null(choicecounter$nc)) nc <- choicecounter$nc
            getCutOffSelection(nc)
        })
        output$downloadSection <- renderUI({
            choices <- c("most-varied", "alldetected", "pcaset")
            if (buttonValues$startDE)
                choices <- c("up+down", "up", "down",
                             "comparisons", "alldetected",
                             "most-varied", "pcaset")
            choices <- c(choices, "selected")
            getDownloadSection(choices)
        })
       
        output$leftMenu  <- renderUI({
            getLeftMenu(input)
        })
        output$loading <- renderUI({
            getLoadingMsg()
        })
        output$logo <- renderUI({
            getLogo()
        })
        output$startup <- renderUI({
            getStartupMsg()
        })
        output$afterload <- renderUI({
            getAfterLoadMsg()
        })
        output$mainmsgs <- renderUI({
            if (is.null(condmsg$text))
                getStartPlotsMsg()
            else
                condmsg$text 
        })
        buttonValues <- reactiveValues(goQCplots = FALSE, goDE = FALSE,
            startDE = FALSE)
        output$dataready <- reactive({
            query <- parseQueryString(session$clientData$url_search)
            jsonobj<-query$jsonobject
            if (is.null(jsonobj))
                hide(id = "loading-debrowser", anim = TRUE, animType = "fade")  
            return(!is.null(Dataset()))
        })
        outputOptions(output, "dataready", 
                      suspendWhenHidden = FALSE)

        Dataset <- reactive({
            init_data()
        })

        observeEvent(input$resetsamples, {
            buttonValues$startDE <- FALSE
            showObj(c("goQCplots", "goDE"))
            hideObj(c("add_btn","rm_btn","startDE"))
            choicecounter$nc <- 0
        })
        samples <- reactive({
            if (is.null(Dataset())) return(NULL)
            getSamples(colnames(Dataset()), index = 1)
        })
        output$condReady <- reactive({
            if (!is.null(sel()))
                choicecounter$nc <- sel()$cc()
            choicecounter$nc
        })
        outputOptions(output, 'condReady', suspendWhenHidden = FALSE)

        observeEvent(input$goQCplots, {
            choicecounter$qc <- 1
            buttonValues$startDE <- FALSE
            buttonValues$goQCplots <- TRUE
            updateTabItems(session, "menutabs", "discover")
            togglePanels(2, c( 0, 2, 4), session)
        })
        comparison <- reactive({
            compselect <- 1
            if (!is.null(input$compselect))
                compselect <- as.integer(input$compselect)

            dc()[[compselect]]
        })
        conds <- reactive({ comparison()$conds })
        cols <- reactive({ comparison()$cols })
        init_data <- reactive({ 
            if (!is.null(comparison()$init_data))
                comparison()$init_data 
            else if (!is.null(batch()))
                batch()$BatchEffect()$count
        })
        filt_data <- reactive({
            if (!is.null(init_data()) && !is.null(comparison()) && !is.null(input$padjtxt))
                applyFilters(init_data(), cols(), conds(), input)
        })

        selected <- reactiveValues(data = NULL)
        qcPlots <- reactiveValues(plot = NULL)
        observe({
            setFilterParams(session, input)
            if ((!is.null(input$genenames) && input$interactive == TRUE) || 
                (!is.null(input$genesetarea) && input$genesetarea != "")){
                tmpDat <- init_data()
                if (!is.null(filt_data()))
                    tmpDat <- filt_data()
                genenames <- ""
                if (!is.null(input$genenames)){
                    genenames <- input$genenames
                } else {
                   tmpDat <- getSearchData(tmpDat, input)
                   genenames <- paste(rownames(tmpDat), collapse = ",")
                }
                selected$data <- getSelHeat(tmpDat, genenames)
            }
            if(!is.null(input$qcplot) && !is.null(df_select())){
                if (input$qcplot == "all2all") {
                    callModule(debrowserall2all, "all2all", df_select(), input$cex)
                } else if (input$qcplot == "pca") {
                    callModule(debrowserpcaplot, "qcpca", df_select(), batch()$BatchEffect()$meta)
                } else if (input$qcplot == "heatmap") {
                    callModule(debrowserheatmap, "heatmap", normdat())
                } else if (input$qcplot == "IQR") {
                    callModule(debrowserIQRplot, "IQR", df_select())
                    callModule(debrowserIQRplot, "normIQR", normdat())
                } else if (input$qcplot == "Density"){
                    callModule(debrowserdensityplot, "density", df_select())
                    callModule(debrowserdensityplot, "normdensity", normdat())
                }
            }
        })
        condmsg <- reactiveValues(text = NULL)
        explainedData <- reactive({
            getPCAexplained( df_select(), input )
        })

        selectedMain <- reactiveVal()
        observe({
            if (!is.null(filt_data())) {
            condmsg$text <- getCondMsg(dc(), input$compselect,
                cols(), conds())
            selectedMain(callModule(debrowsermainplot, "main", filt_data()))
            }
        })
        selectedHeat <- reactiveVal()
        observe({
            if (!is.null(selectedMain()) && !is.null(selectedMain()$selGenes())) {
                withProgress(message = 'Creating plot', style = "notification", value = 0.1, {
                    selectedHeat(callModule(debrowserheatmap, "heatmapMain", filt_data()[selectedMain()$selGenes(), cols()]))
                })
            }
        })
        observe({
            if (!is.null(selectedMain()) && !is.null(selectedMain()$shgClicked()) && selectedMain()$shgClicked()!=""){
                withProgress(message = 'Creating Bar/Box plots', style = "notification", value = 0.1, {
                    callModule(debrowserbarmainplot, "barmain", filt_data(), 
                               cols(), conds(),  
                               selectedMain()$shgClicked())
                    callModule(debrowserboxmainplot, "boxmain", filt_data(), 
                               cols(), conds(),
                               selectedMain()$shgClicked())
                })
            }
        })
        edat <- reactiveValues(val = NULL)
        
        normdat <-  reactive({
            getNormalizedMatrix(df_select(), input$norm_method)
        })

        df_select <- reactive({
            if (!is.null(Dataset()) && !is.null(datasetInput()) )
                getSelectedCols(Dataset(), datasetInput(), input)
        })
        
        output$columnSelForQC <- renderUI({
            existing_cols <- colnames(datasetInput())
            if (!is.null(cols()))
                existing_cols <- cols()
            wellPanel(id = "tPanel",
                style = "overflow-y:scroll; max-height: 200px",
                checkboxGroupInput("col_list", "Select col to include:",
                existing_cols, 
                selected=existing_cols)
            )
        })

        selectedData <- reactive({
            selected$data
        })
        datForTables <- reactive({
            dat <- getDataForTables(input, init_data(),
                filt_data(), selectedData(),
                getMostVaried(), mergedComp())
            return(dat)
        })

        inputGOstart <- reactive({
            if (input$startGO){
                dat <- datForTables()
                getGOPlots(dat[[1]][, isolate(cols())], input)
            }
        })
        observeEvent(input$startGO, {
            inputGOstart()
        })
        output$GOPlots1 <- renderPlot({
            if (!is.null(inputGOstart()$p) && input$startGO){
                return(inputGOstart()$p)
            }
        })
        output$KEGGPlot <- renderImage({
            validate(need(!is.null(input$gotable_rows_selected),
                          "Please select a category in the GO/KEGG table to be able
                          to see the pathway diagram"))
            
            org <- input$organism
            dat <- datForTables()
            genedata <- getEntrezIds(dat[[1]], org)
            i <- input$gotable_rows_selected
            pid <- inputGOstart()$table$ID[i]
            pv.out <- pathview(gene.data = genedata,
                 pathway.id = pid,
                 species = substr(inputGOstart()$table$ID[i],0,3),
                 out.suffix = "b.2layer", kegg.native = TRUE)
            unlink(paste0(pid,".png"))
            unlink(paste0(pid,".xml"))
            list(src = paste0(pid,".b.2layer.png"),
                 contentType = 'image/png')
        }, deleteFile = TRUE)

        getGOCatGenes <- reactive({
            if(is.null(input$gotable_rows_selected)) return (NULL)
            org <- input$organism
            dat <- tabledat()
            
            i <- input$gotable_rows_selected
            genedata <- getEntrezTable(inputGOstart()$enrich_p$geneID[i],
                                       dat[[1]], org)
            
            #selected$data$getSelected <- reactiveVal(genedata)
            dat[[1]] <- genedata
            dat
        })
        output$GOGeneTable <- DT::renderDataTable({
            validate(need(!is.null(input$gotable_rows_selected),
                          "Please select a category in the GO/KEGG table to be able
                          to see the gene list"))
            dat <- getGOCatGenes()
            if (!is.null(dat)){
                DT::datatable(dat[[1]],
                              list(lengthMenu = list(c(10, 25, 50, 100),
                                                     c("10", "25", "50", "100")),
                                   pageLength = 25, paging = TRUE, searching = TRUE)) %>%
                    getTableStyle(input, dat[[2]], dat[[3]], buttonValues$startDE)
            }
        })
        
        output$getColumnsForTables <-  renderUI({
            if (is.null(table_col_names())) return (NULL)
            selected_list <- table_col_names()
            if (!is.null(input$table_col_list) 
                && all(input$table_col_list %in% colnames(tabledat()[[1]])))
                selected_list <- input$table_col_list
            colsForTable <- list(
                wellPanel(id = "tPanel",
                    style = "overflow-y:scroll; max-height: 200px",
                    checkboxGroupInput("table_col_list", "Select col to include:",
                    table_col_names(), 
                    selected=selected_list)
                )
            )
            return(colsForTable)
        })
        table_col_names <- reactive({
            if (is.null(tabledat())) return (NULL)
            colnames(tabledat()[[1]])
        })
        tabledat <- reactive({
            dat <- datForTables()
            if (is.null(dat)) return (NULL)
            dat2 <- removeCols(c("ID", "x", "y","Legend", "Size"), dat[[1]])
            
            pcols <- c(names(dat2)[grep("^padj", names(dat2))], 
                       names(dat2)[grep("pvalue", names(dat2))])
            if (!is.null(pcols) && length(pcols) > 1)
                dat2[,  pcols] <- apply(dat2[,  pcols], 2,
                    function(x) format( as.numeric(x), scientific = TRUE, digits = 3 ))
            else
                dat2[,  pcols] <- format( as.numeric( dat2[,  pcols] ), 
                    scientific = TRUE, digits = 3 )
            rcols <- names(dat2)[!(names(dat2) %in% pcols)]
            if (!is.null(rcols) && length(rcols) > 1)
                dat2[,  rcols] <- apply(dat2[,  rcols], 2,
                                    function(x) round( as.numeric(x), digits = 2))
            else
                dat2[,  rcols] <-  round( as.numeric(dat2[,  rcols]), digits = 2)
                
            dat[[1]] <- dat2
            return(dat)
        })
        output$tables <- DT::renderDataTable({
            dat <- tabledat()
            if (is.null(dat) || is.null(table_col_names())
                || is.null(input$table_col_list) || length(input$table_col_list)<1) 
                return (NULL)
            if (!all(input$table_col_list %in% colnames(dat[[1]]), na.rm = FALSE)) 
                return(NULL)
            if (!dat[[2]] %in% input$table_col_list)
                dat[[2]]= ""
            if (!dat[[3]] %in% input$table_col_list)
                dat[[3]]= ""
            
            datDT <- DT::datatable(dat[[1]][, input$table_col_list],
                options = list(lengthMenu = list(c(10, 25, 50, 100),
                c("10", "25", "50", "100")),
                pageLength = 25, paging = TRUE, searching = TRUE)) %>%
                getTableStyle(input, dat[[2]], dat[[3]], buttonValues$startDE)
            return(datDT)
        })
        getMostVaried <- reactive({
            mostVaried <- NULL
            if (choicecounter$qc == 0)
                mostVaried <- filt_data()[filt_data()$Legend=="MV" | 
                    filt_data()$Legend=="GS", ]
            else
                mostVaried <- getMostVariedList(init_data(), 
                    colnames(init_data()), input)
            mostVaried
        })
        output$gotable <- DT::renderDataTable({
            if (!is.null(inputGOstart()$table)){
                DT::datatable(inputGOstart()$table,
                    list(lengthMenu = list(c(10, 25, 50, 100),
                    c("10", "25", "50", "100")),
                    pageLength = 25, paging = TRUE, searching = TRUE))
            }
        })
        mergedComp <- reactive({
            dat <- applyFiltersToMergedComparison(
                isolate(mergedCompInit()), choicecounter$nc, input)
            ret <- dat[dat$Legend == "Sig", ]
            #ret[ret$Legend == "Sig", ] <- NULL
            ret
        })
        
        mergedCompInit <- reactive({
            merged <- getMergedComparison(
                isolate(Dataset()), isolate(dc()), choicecounter$nc, input)
            merged
        })
        datasetInput <- function(addIdFlag = FALSE){
            tmpDat <- NULL
            if (choicecounter$qc == 0 ) {
                mergedCompDat <- NULL
                if (input$dataset == "comparisons"){
                    mergedCompDat <- mergedComp()
                }
                tmpDat <- getSelectedDatasetInput(filt_data(), 
                     selected$data$getSelected(), getMostVaried(),
                     mergedCompDat, isolate(edat$val$pcaset), input)
            }
            else
                tmpDat <- getSelectedDatasetInput(init_data(), 
                     getSelected = selected$data$getSelected(),
                     getMostVaried = getMostVaried(),
                     explainedData = isolate(edat$val$pcaset),
                     input = input)
            if(addIdFlag)
                tmpDat <- addID(tmpDat)
            if (input$dataset != "pcaset"){
                choicecounter$lastselecteddataset = input$dataset
            }
            return(tmpDat)
        }
        output$downloadData <- downloadHandler(filename = function() {
            paste(input$dataset, "csv", sep = ".")
        }, content = function(file) {
            dat <- datForTables()
            dat2 <- removeCols(c("x", "y","Legend", "Size"), dat[[1]])
            if(!("ID" %in% names(dat2)))
                dat2 <- addID(dat2)
            write.table(dat2, file, sep = ",", row.names = FALSE)
        })

        output$downloadGOPlot <- downloadHandler(filename = function() {
            paste(input$goplot, ".pdf", sep = "")
        }, content = function(file) {
            pdf(file)
            print( inputGOstart()$p )
            dev.off()
        })
    },
    err=function(errorCondition) {
        cat("in err handler")
        message(errorCondition)
    },
    warn=function(warningCondition) {
        cat("in warn handler")
        message(warningCondition)
    })
}

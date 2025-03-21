##' simplify output from enrichGO and gseGO by removing redundancy of enriched GO terms
##'
##'
##' @name simplify
##' @docType methods
##' @rdname simplify-methods
##' @title simplify method
##' @param x output of enrichGO
##' @param cutoff similarity cutoff
##' @param by feature to select representative term, selected by 'select_fun' function
##' @param select_fun function to select feature passed by 'by' parameter
##' @param measure method to measure similarity
##' @param semData GOSemSimDATA object
##' @return updated enrichResult object
##' @exportMethod simplify
##' @references issue #28
##' \url{https://github.com/GuangchuangYu/clusterProfiler/issues/28}
##' @aliases simplify,enrichResult-method
##' @author Guangchuang Yu
setMethod("simplify", signature(x="enrichResult"),
          function(x, cutoff=0.7, by="p.adjust", select_fun=min, measure="Wang", semData = NULL) {
              if (!x@ontology %in% c("BP", "MF", "CC", "GOALL"))
                  stop("simplify only applied to output from gsegO and enrichGO...")
              res <- as.data.frame(x)
              if (x@ontology == "GOALL") {
                  x@result <- simplify_ALL(res = res, cutoff = cutoff, by = by,
                      select_fun = select_fun, measure = measure,
                      semData = semData)
              } else {
                  x@result <- simplify_internal(res = res, cutoff = cutoff,
                                    by = by, select_fun = select_fun, 
                                    measure = measure,
                                    ontology = x@ontology, 
                                    semData = semData)                      
              }
              return(x)
          }
)

##' @rdname simplify-methods
##' @exportMethod simplify
##' @references issue #162
##' \url{https://github.com/GuangchuangYu/clusterProfiler/issues/162}
##' @aliases simplify,gseaResult-method
##' @author Gwang-Jin Kim and Guangchuang Yu
setMethod("simplify", signature(x="gseaResult"),
          function(x, cutoff=0.7, by="p.adjust", select_fun=min, measure="Wang", semData=NULL) {
            if (!x@setType %in% c("BP", "MF", "CC", "GOALL"))
              stop("simplify only applied to output from gseGO and enrichGO...")
            res <- as.data.frame(x)
            if (x@setType == "GOALL") {
                x@result <- simplify_ALL(res = res, cutoff = cutoff, by = by,
                                select_fun = select_fun, measure = measure,
                                semData = semData)
              } else {
                x@result <- simplify_internal(res = res, cutoff = cutoff,
                                by = by, select_fun = select_fun, 
                                measure = measure,
                                ontology = x@setType, 
                                semData = semData)
              }
            return(x)
          }
)

##' @importFrom GOSemSim mgoSim
##' @importFrom GOSemSim godata
##' @importFrom tidyr gather
simplify_internal <- function(res, cutoff=0.7, by="p.adjust", select_fun=min, 
                              measure="Rel", ontology, semData) {
    if (missing(semData) || is.null(semData)) {
        if (measure == "Wang") {
            semData <- godata(ont = ontology)
        } else {
            stop("godata should be provided for IC-based methods...")
        }
    } else {
        if (ontology != semData@ont) {
            msg <- paste("semData is for", semData@ont, "ontology, while enrichment result is for", ontology)
            stop(msg)
        }
    }

    sim <- mgoSim(res$ID, res$ID,
                  semData = semData,
                  measure=measure,
                  combine=NULL)

    ## to satisfy codetools for calling gather
    go1 <- go2 <- similarity <- NULL


    sim.df <- as.data.frame(sim)
    sim.df$go1 <- row.names(sim.df)

    sim.df <- gather(sim.df, go2, similarity, -go1)

    sim.df <- sim.df[!is.na(sim.df$similarity),]

    ## feature 'by' is attached to 'go1'
    sim.df <- merge(sim.df, res[, c("ID", by)], by.x="go1", by.y="ID")
    sim.df$go2 <- as.character(sim.df$go2)

    ID <- res$ID

    GO_to_remove <- character()
    anc <- GOSemSim:::getAncestors(ontology)
    for (i in seq_along(ID)) {
        ii <- which(sim.df$go2 == ID[i] & sim.df$similarity > cutoff)
        ## if length(ii) == 1, then go1 == go2
        if (length(ii) < 2)
            next

        sim_subset <- sim.df[ii,]

        jj <- which(sim_subset[, by] == select_fun(sim_subset[, by]))


        if (length(jj) > 1) {
            ll <- vapply(sim_subset$go1[jj], function(.id) length(anc[[.id]]), numeric(1))
            jj <- jj[which.max(ll)]
        }


        ## sim.df <- sim.df[-ii[-jj]]
        GO_to_remove <- c(GO_to_remove, sim_subset$go1[-jj]) %>% unique
    }

    res[!res$ID %in% GO_to_remove, ]
}



##' simplify output from compareCluster by removing redundancy of enriched GO terms
##'
##'
##' @name simplify
##' @docType methods
##' @rdname simplify-methods
##' @title simplify method
##' @return updated compareClusterResult object
##' @exportMethod simplify
##' @aliases simplify,compareClusterResult-method
##' @author Guangchuang Yu
setMethod("simplify", signature(x="compareClusterResult"),
          function(x, cutoff=0.7, by="p.adjust", select_fun=min, measure="Wang", semData=NULL) {
              res <- x@compareClusterResult
              ont <- get_go_ontology(x)

              ## organism <- x@.call$organism
              ## if (is.null(organism)) {
              ##     organism <- "human"
              ## }

              ## to satisfy codetools in calling subset
              Cluster <- NULL
              lres <- lapply(unique(res$Cluster), function(cls) subset(res, Cluster == cls))
              if (ont == "ALL") {
                  lres %<>% lapply(., simplify_ALL,
                      cutoff = cutoff, by = by,
                      select_fun = select_fun,
                      measure = measure,
                      semData = semData)
              } else {
                  lres %<>% lapply(., simplify_internal,
                                   cutoff=cutoff,
                                   by = by,
                                   select_fun = select_fun,
                                   measure = measure,
                                   ontology = ont,
                                   semData = semData)
              }
              x@compareClusterResult <- do.call("rbind", lres)
              return(x)
          }
)


##' @param data.frame of enrichment result 
##' @param cutoff similarity cutoff
##' @param by feature to select representative term, selected by 'select_fun' function
##' @param select_fun function to select feature passed by 'by' parameter
##' @param measure method to measure similarity
##' @param semData GOSemSimDATA object
##' @noRd
simplify_ALL <- function(res, cutoff, by, select_fun, measure, semData) {
    ONTOLOGY <- NULL
    lres <- lapply(unique(res[, "ONTOLOGY"]), function(y)
                      simplify_internal(dplyr::filter(res, ONTOLOGY == y),
                          cutoff = cutoff,
                          by = by,
                          select_fun = select_fun,
                          measure = measure,
                          ontology = y,
                          semData = NULL)
                  )
    do.call(rbind, lres)
}

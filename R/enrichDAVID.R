#' enrichment analysis by DAVID
#'
#'
#' @title enrichDAVID
#' @param gene input gene
#' @param idType id type
#' @param minGSSize minimal size of genes annotated for testing
#' @param maxGSSize maximal size of genes annotated for testing
#' @param annotation david annotation
#' @inheritParams enricher
#' @param species species
#' @param david.user david user
#' @return A \code{enrichResult} instance
#' @importFrom qvalue qvalue
#' @importFrom utils installed.packages
#' @importFrom yulab.utils get_fun_from_pkg
#' @importFrom yulab.utils is.installed
#' @export
#' @author Guangchuang Yu
enrichDAVID <- function(gene,
                        idType        = "ENTREZ_GENE_ID",
                        universe,
                        minGSSize     = 10,
                        maxGSSize     = 500,
                        annotation    = "GOTERM_BP_FAT",
                        pvalueCutoff  = 0.05,
                        pAdjustMethod = "BH",
                        qvalueCutoff  = 0.2,
                        species       = NA,
                        david.user){

    Count <- List.Total <- Pop.Hits <- Pop.Total <- NULL

    pAdjustMethod <- match.arg(pAdjustMethod, c("bonferroni", "BH"))

    david.pkg <- "RDAVIDWebService"
    if (! is.installed(david.pkg)) {
        stop("You should have RDAVIDWebService package installed before using enrichDAVID ...")
    }

    DAVIDWebService <- get_fun_from_pkg(david.pkg, "DAVIDWebService")
    addList <- get_fun_from_pkg(david.pkg, "addList")
    setAnnotationCategories <- get_fun_from_pkg(david.pkg, "setAnnotationCategories")
    getFunctionalAnnotationChart <- get_fun_from_pkg(david.pkg, "getFunctionalAnnotationChart")
    getSpecieNames <- get_fun_from_pkg(david.pkg, "getSpecieNames")
    getIdTypes <- get_fun_from_pkg(david.pkg, "getIdTypes")

    david <- DAVIDWebService$new(email=david.user,
            url="https://davidbioinformatics.nih.gov/webservice/services/DAVIDWebService/") 

    ## addList will throw error if idType is not match.
    ## use match.arg to check before addList make it more readable
    
    idType <- match.arg(idType, getIdTypes(david))
    
    ##     getIdTypes(david)
    ##  [1] "AFFYMETRIX_3PRIME_IVT_ID" "AFFYMETRIX_EXON_ID"      
    ##  [3] "AGILENT_CHIP_ID"          "AGILENT_ID"              
    ##  [5] "AGILENT_OLIGO_ID"         "APHIDBASE_ID"            
    ##  [7] "BEEBASE_ID"               "BEETLEBASE_ID"           
    ##  [9] "BGD_ID"                   "CGNC_ID"                 
    ## [11] "CRYPTODB_ID"              "DICTYBASE_ID"            
    ## [13] "ENSEMBL_GENE_ID"          "ENSEMBL_TRANSCRIPT_ID"   
    ## [15] "ENTREZ_GENE_ID"           "FLYBASE_GENE_ID"         
    ## [17] "GENBANK_ACCESSION"        "GENOMIC_GI_ACCESSION"    
    ## [19] "GENPEPT_ACCESSION"        "LOCUS_TAG"               
    ## [21] "MGI_ID"                   "MIRBASE_ID"              
    ## [23] "MRNA_GI_ACCESSION"        "NASONIABASE_ID"          
    ## [25] "PROTEIN_GI_ACCESSION"     "PSEUDOCAP_ID"            
    ## [27] "REFSEQ_MRNA"              "REFSEQ_PROTEIN"          
    ## [29] "RGD_ID"                   "SGD_ID"                  
    ## [31] "TAIR_ID"                  "UNIGENE"                 
    ## [33] "UNIPROT_ACCESSION"        "UNIPROT_ID"              
    ## [35] "VECTORBASE_ID"            "WORMBASE_GENE_ID"        
    ## [37] "XENBASE_ID"               "ZFIN_ID"
    
    david.res <- addList(david, gene, idType=idType,
                         listName="clusterProfiler",
                         listType="Gene")


    if (david.res$inDavid == 0) {
        stop("All id can not be mapped. Please check 'idType' parameter...")
    }

    if (!missing(universe)) {
        david.res <- addList(david, universe, idType=idType,
                             listName="universe",
                             listType="Background")
    }

    setAnnotationCategories(david, annotation)
    x <- getFunctionalAnnotationChart(david, threshold=1, count=minGSSize)

    if (length(x@.Data) == 0) {
        warning("No significant enrichment found...")
        return(NULL)
    }

    term <- x$Term
    if (length(grep("~", term[1])) == 0) {
        sep <- ":"
    } else {
        sep <- "~"
    }
    term.list <- sapply(term, function(y) strsplit(y, split=sep))
    term.df <- do.call("rbind", term.list)
    ID <- term.df[,1]
    Description <- term.df[,2]
    k <- x$Count
    n <- x$List.Total
    M <- x$Pop.Hits
    N <- x$Pop.Total

    # GeneRatio <- with(x, paste(Count, List.Total, sep="/"))
    # BgRatio <- with(x, paste(Pop.Hits, Pop.Total, sep="/"))
    GeneRatio <- sprintf("%s/%s", k, n)
    BgRatio <- sprintf("%s/%s", M, N)
    RichFactor <- k / M
    FoldEnrichment <- RichFactor * N / n 
    
    mu <- M * n / N
    sigma <- mu * (N - n) * (N - M) / N / (N-1)
    zScore <- (k - mu)/sqrt(sigma)

    Over <- data.frame(ID          = ID,
                       Description = Description,
                       GeneRatio   = GeneRatio,
                       BgRatio     = BgRatio,
                       RichFactor = RichFactor,
                       FoldEnrichment = FoldEnrichment,
                       zScore = zScore, 
                       pvalue      = x$PValue,
                       stringsAsFactors = FALSE)
    row.names(Over) <- ID

    if (pAdjustMethod == "bonferroni") {
        Over$p.adjust <- x$Bonferroni
    } else {
        Over$p.adjust <- x$Benjamini
    }

    qobj <- tryCatch(qvalue(p=Over$pvalue, lambda=0.05, pi0.method="bootstrap"),
                     error=function(e) NULL)
    if (inherits(qobj, "qvalue")) {
        qvalues <- qobj$qvalues
    } else {
        qvalues <- NA
    }
    Over$qvalue <- qvalues
    Over$geneID <- gsub(",\\s*", "/", x$Genes)
    Over$Count <- x$Count

    Over <- Over[ Over$pvalue <= pvalueCutoff, ]
    Over <- Over[ Over$p.adjust <= pvalueCutoff, ]
    if (! any(is.na(Over$qvalue))) {
        Over <- Over[ Over$qvalue <= qvalueCutoff, ]
    }

    org <- getSpecieNames(david)
    org <- gsub("\\(.*\\)", "", org)

    ## gc <- strsplit(Over$geneID, "/")
    ## names(gc) <- Over$ID

    if (!is.na(maxGSSize) && !is.null(maxGSSize)) {
        idx <- as.numeric(sub("/\\d+", "", Over$BgRatio)) <= maxGSSize
        Over <- Over[idx,]
    }

    new("enrichResult",
        result         = Over,
        pvalueCutoff   = pvalueCutoff,
        pAdjustMethod  = pAdjustMethod,
        organism       = org,
        ontology       = annotation, ## as.character(x$Category[1]),
        gene           = as.character(gene),
        keytype        = idType)
}


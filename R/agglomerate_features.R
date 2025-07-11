#' agglomerate_features(ExpObj = NULL, glomby = NULL)
#'
#' Agglomerates features in a JAMS SummarizedExperiment object safely
#' @export

agglomerate_features <- function(ExpObj = NULL, glomby = NULL){

    #Get appropriate object to work with
    if (as.character(class(ExpObj)[1]) != "SummarizedExperiment"){
        stop("This function can only take a SummarizedExperiment object as input.")
    }

    #Get feature table
    ftt <- as.data.frame(rowData(ExpObj))
    if (!(glomby %in% colnames(ftt))){
        stop(paste("Unable to agglomerate by", glomby, "because this category was not found in the feature table of the SummarizedExperiment object."))
    }

    #Find out what kind of an object it is
    analysis <- metadata(ExpObj)$analysis
    if (analysis %in% c("Contig_LKT", "MB2bin", "ConsolidatedGenomeBin")){
        JAMS2TaxonomicObj <- TRUE
    } else {
        JAMS2TaxonomicObj <- FALSE
    }

    pheno_original <- colData(ExpObj)
    taxonomic_levels <- c("Domain", "Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species", "IS1", "LKT")
    terminal_taxonomic_levels <- c("Contig_LKT", "MB2bin", "ConsolidatedGenomeBin")

    #Aggregate counts by summing
    cts <- as.data.frame(assays(ExpObj)$BaseCounts)
    cts$Feats <- rownames(cts)
    feats2glomby_feats <- data.frame(Feats = rownames(ftt), Glomby_feats = as.character(ftt[ , glomby]), stringsAsFactors = FALSE)
    cts <- left_join(cts, feats2glomby_feats, by = "Feats")
    cts$Feats <- NULL
    glom_cts <- aggregate(. ~ Glomby_feats, data = cts, FUN = sum)
    rownames(glom_cts) <- glom_cts$Glomby_feats
    glom_cts$Glomby_feats <- NULL
    featureorder <- rownames(glom_cts)
    sampleorder <- rownames(pheno_original)
    #Check everything is in the same order
    glom_cts <- glom_cts[, sampleorder]

    if ("GenomeCompleteness" %in% as.character(names(assays(ExpObj)))){
        #Aggregate counts by summing
        gcdf <- as.data.frame(assays(ExpObj)$GenomeCompleteness)
        gcdf$Feats <- rownames(gcdf)
        feats2glomby_feats <- data.frame(Feats = rownames(ftt), Glomby_feats = as.character(ftt[ , glomby]), stringsAsFactors = FALSE)
        gcdf <- left_join(gcdf, feats2glomby_feats, by = "Feats")
        gcdf$Feats <- NULL
        gcdf <- aggregate(. ~ Glomby_feats, data = gcdf, FUN = sum)
        rownames(gcdf) <- gcdf$Glomby_feats
        gcdf$Glomby_feats <- NULL
        gcdf <- gcdf[featureorder, sampleorder]
    } else {
        gcdf <- NULL
    }

    #Iron out the feature table
    #Determine which version of JAMS the SEobj was made by, ensure backwards compatibility.
    if (JAMS2TaxonomicObj){
        #Get a novel feature table
        glom_ftt <- ftt
        if (glomby %in% taxonomic_levels){
            wanted_taxids <- sapply(rownames(glom_cts), function (x) {extract_NCBI_taxid_from_featname(Taxon = x)} )
            #Remake ftt from JAMStaxtable
            data(JAMStaxtable)
            glom_ftt <- JAMStaxtable[wanted_taxids, ]
            rownames(glom_ftt) <- rownames(glom_cts)
        }
    } else {
        #treat as before
        #Get classes for novel features
        glomby_feats <- unique(ftt[ , glomby])
        #Get a novel feature table
        glom_ftt <- ftt[(!duplicated(ftt[, glomby])), 1:(which(colnames(ftt) == glomby)), drop = FALSE]
        rownames(glom_ftt) <- glom_ftt[, glomby]
    }

    #Rebuild the SummarizedExperiment object
    assays <- list(glom_cts, gcdf)
    assays <- assays[sapply(1:length(assays), function (x) { !is.null(assays[[x]]) })]
    names(assays) <- c("BaseCounts", "GenomeCompleteness")[1:length(assays)]

    glomExpObj <- SummarizedExperiment(assays = assays, rowData = glom_ftt, colData = pheno_original)
    metadata(glomExpObj) <- metadata(ExpObj)

    return(glomExpObj)
}

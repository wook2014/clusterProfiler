##' @importFrom utils packageDescription
.onAttach <- function(libname, pkgname) {
    # pkgVersion <- packageDescription(pkgname, fields="Version")
    # msg <- paste0(pkgname, " v", pkgVersion, "  ",
    #               "For help: https://yulab-smu.top/biomedical-knowledge-mining-book/", "\n\n")

    # if (.Platform$OS.type == "windows") {
    #     dl.method <- "wininet"
    # } else if (capabilities("libcurl")) {
    #     dl.method <- "libcurl"
    # } else {
    #     dl.method <- getOption("download.file.method", default = "auto") 
    # }

    # options(clusterProfiler.download.method = dl.method)
    # options(timeout = max(300, getOption("timeout"))) # see ?download.file

    
    # Define a cache directory
    options(clusterProfiler_cache_dir = tempdir())

    packageStartupMessage(yulab.utils::yulab_msg(pkgname))
}



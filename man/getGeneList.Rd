% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/GOterm.R
\name{getGeneList}
\alias{getGeneList}
\title{getGeneList}
\usage{
getGeneList(genes = NULL, org = "org.Hs.eg.db")
}
\arguments{
\item{genes, }{gene list}

\item{org, }{orgranism for gene symbol entrez ID conversion}
}
\value{
ENTREZ ID list
}
\description{
Gathers the gene list to use for GOTerm analysis.
}
\note{
\code{GOTerm}

\code{getGeneList}
symobol to ENTREZ ID conversion
}
\examples{
    x <- getGeneList(c('OCLN', 'ABCC2'))

}

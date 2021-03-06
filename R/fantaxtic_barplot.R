#' Generate a barplot of relative taxon abundances
#'
#' This function generates a \code{ggplot2} barplot for the relative abundances
#' of taxa in a phyloseq object.
#'
#' Coloring occurs by a user specified taxonomic
#' level, and subcoloring according to another level can be added if desired (e.g.
#' color by phylum, subcolor by genus). In addition, one or more taxon names can
#' be specified as "other" that receive a specific color (e.g. outliers,
#' collapsed taxa).
#'
#' By default, unique labels per taxon will be generated in the case that
#' multiple taxa with identical labels exist, unless the user chooses to suppress
#' this. Moreover, \code{NA} values in the \code{tax_table} of the phyloseq
#' object will be renamed to \code{"Unknown"} to avoid confusion. WARNING:
#' duplicate labels in the data lead to incorrect displaying of data and
#' labels.
#'
#' To facilitate visualisation and/or interpretation, samples can be reordered
#' according alphabetically, by the abundance of a certain taxon, by
#' hierarhical clustering or by the abundance of "other" taxa.
#'
#' @param physeq_obj A phyloseq object with an \code{otu_table}, a \code{tax_table}
#' and, in case of facetting, \code{sample_data}.
#' @param color_by The name of the taxonomic level by which to color the bars.
#' @param label_by The name of the taxonomic level by which to label the bars and
#' generate subcolors.
#' @param facet_by The name of the factor in the \code{sample_data} by which to
#' facet the plots.
#' @param grid_by The name of a second factor in the \code{sample_data} by which to
#' facet to plots, resulting in a grid.
#' @param facet_type The type of faceting from ggplot2 to use, either \code{grid}
#' or \code(wrap) (default).
#' @param facet_cols The number of columns to use for faceting.
#' @param gen_uniq_lbls Generate unique labels (default = \code{TRUE})?
#' @param other_label A character vector specifying the names of taxa in
#' \code{label_by} to use a specific color for.
#' @param order_alg The algorithm by which to order samples, or one or more taxa
#' found in \code(label_by). Algorithms can be one of \code{hclust}
#' (hierarhical clustering; default), \code{as.is} (current order) or \code{alph}
#' (alphabetical).
#' @param color_levels Character vector containing names of levels. Useful to
#' enforce identical colors for levels across different plots or to pair levels
#' with colors.
#' @param base_color The base color from which to generate colors.
#' @param other_color The base color from which to generate shades for "other"
#' taxa.
#' @param palette A user specified palette to color the bars with. Replaces
#' \code{base_color}.
#' @param bar_width The width of the bars as a fraction of the binwidth
#' (default = 0.9).
#' @return A \code{ggplot2} object.
#' @examples
#' #Load data
#' data(GlobalPatterns)
#'
#' #Get the 10 most abundant OTUs / ASVs
#' ps_tmp <- get_top_taxa(physeq_obj = GlobalPatterns, n = 10, relative = TRUE,
#'                        discard_other = FALSE, other_label = "Other")
#'
#' #Create labels for missing taxonomic ranks
#' ps_tmp <- name_taxa(ps_tmp, label = "Unkown", species = T, other_label = "Other")
#'
#' #Generate a barplot that is colored by Phylum and labeled by Species, coloring
#' #collapsed taxa grey.
#' fantaxtic_bar(ps_tmp, color_by = "Phylum", label_by = "Species", other_label = "Other")
#'
#' #Generate a barplot that is colored by Phylum and lebeled by Species. As multiple
#' ASVs have the same family annotation, generate unique labels.
#' fantaxtic_bar(ps_tmp, color_by = "Phylum", label_by = "Family", other_label = "Other",
#'               gen_uniq_lbls = TRUE)
#'
#' #Change the sample ordering
#' fantaxtic_bar(ps_tmp, color_by = "Phylum", label_by = "Family", other_label = "Other",
#'               order_alg = "other.abnd")
#'
#' #Add faceting by sample type
#' fantaxtic_bar(ps_tmp, color_by = "Phylum", label_by = "Family",
#'               facet_by = "SampleType", other_label = "Other")
#' @export
fantaxtic_bar <- function(physeq_obj, color_by, label_by = NULL, facet_by = NULL,
                          grid_by = NULL, facet_type = "wrap", bar_width = 0.9,
                          facet_cols =  1, gen_uniq_lbls = TRUE, other_label= NULL,
                          order_alg = "hclust", color_levels = NULL,
                          base_color = "#6495ed",
                          other_color = "#f3f3f3", palette = NULL){

  #Check for subcoloring
  if (is.null(label_by)){
    label_by <- color_by
  }

  #Extract tax_tbl and add OTU names
  tax_tbl <- as.data.frame(phyloseq::tax_table(physeq_obj))
  tax_tbl$otu_name <- row.names(tax_tbl)

  #Replace NAs with Unknown
  tax_tbl <- as.data.frame(apply(tax_tbl, 2, function(x){
    x[is.na(x)] <- "Unknown"
    return(x)
  }))

  #Move Other taxa to the beginning and alter taxonomic annotations
  #of Other taxa
  if(!is.null(other_label)){
    main_ind <- which(!tax_tbl[[label_by]] %in% other_label)
    other_ind <- which(tax_tbl[[label_by]] %in% other_label)
    new_color_by <- as.character(tax_tbl[[color_by]])
    new_color_by[other_ind] <- as.character(tax_tbl[[label_by]][other_ind])
    tax_tbl[[color_by]] <- as.factor(new_color_by)
    ordr <- c(other_ind, main_ind)
    tax_tbl <- tax_tbl[ordr,]
  }

  #Refactor for legend ordering and order
  if (is.null(color_levels)){
    tax_levels <- unique(tax_tbl[[color_by]])
  } else {
    if (is.null(other_label)){
      tax_levels <- color_levels
    } else {
      tax_levels <- c(other_label, color_levels)
    }
  }
  tax_tbl[[label_by]] <- factor(tax_tbl[[label_by]], unique(tax_tbl[[label_by]]), ordered = T)
  tax_tbl[[color_by]] <- factor(tax_tbl[[color_by]], tax_levels, ordered = T)
  tax_tbl <- tax_tbl[order(tax_tbl[[color_by]]),]

  #Get the tax and OTU tables
  otu_tbl <- as.data.frame(phyloseq::otu_table(physeq_obj))

  #Check the orientation of the otu_tbl and change if required
  if (!taxa_are_rows(phyloseq::otu_table(physeq_obj))){
    otu_tbl <- as.data.frame(t(otu_tbl))
  }

  #Calculate the number of colors and color variations required
  clr_tbl <- as.data.frame(table(tax_tbl[[color_by]], useNA = "ifany"), stringsAsFactors = F)
  if(!is.null(other_label)){
    ind <- which(!clr_tbl$Var1 %in% other_label)
    clr_tbl <- clr_tbl[ind,]
  }

  #Generate the required color palette
  clr_pal <- gen_palette(clr_tbl = clr_tbl, clr_pal = palette, base_clr = base_color)
  names(clr_pal) <- clr_tbl$Var1
  clr_pal <- as.vector(unlist(clr_pal))
  if(!is.null(other_label)){
    n_other <- length(other_label)
    other_pal <- gen_shades_tints(n_other, clr = other_color)
    clr_pal <- c(other_pal, clr_pal)
  }

  #Generate unique label names if required
  if(gen_uniq_lbls){
    tax_tbl[[label_by]] <- gen_uniq_lbls(tax_tbl[[label_by]])
  }

  #Transform absolute taxon counts to relative values
  otu_tbl <- as.data.frame(apply(otu_tbl, 2, function(x){
    if (sum(x) > 0){x/sum(x)}
    else(x)
  }))

  #Match order of tax.tbl and otu.tbl
  ord <- match(tax_tbl$otu_name, row.names(otu_tbl))
  otu_tbl <- otu_tbl[ord,]

  #Order the samples according to the specified algorithm
  #Order according to selected taxonomies
  if (sum(order_alg %in% c("alph", "hclust", "as.is")) == 0){

    #Get the summed abundances
    sums <- list()
    i <- 0
    for (lvl in order_alg){
      i <- i + 1
      sums[[i]] <- round(colSums(otu_tbl[which(tax_tbl[[label_by]] == lvl),]), digits = 3)
    }

    #Sort
    cmd <- paste(sprintf("sums[[%d]]", 1:i), collapse = ", ")
    smpl_ord <- eval(parse(text = sprintf("order(%s)", cmd)))
    otu_tbl <- otu_tbl[,smpl_ord]

  #Order according to selected algorithm
  }else{
    if (order_alg == "alph"){
      otu_tbl <- otu_tbl[,order(names(otu_tbl))]
    } else {
      if(order_alg == "hclust"){
        hc <- hclust(dist(x = t(otu_tbl), method = "euclidian", upper = F))
        smpl_ord <- hc$order
        otu_tbl <- otu_tbl[,smpl_ord]
      } else {
        if (order_alg == "as.is"){
          #do nothing
        }
      }
    }
  }


  #Join labels and counts and transform to a long data format
  counts <- cbind(tax_tbl[[color_by]], tax_tbl[[label_by]], otu_tbl)
  names(counts) <- c("color_by", "label_by", colnames(otu_tbl))
  counts_long <- reshape2::melt(counts,
                      id.vars = c("color_by", "label_by"),
                      variable.name = "Sample",
                      value.name = "Abundance")

  #Add facet levels if needed and transform to a long data format
  if(is.null(facet_by) & !is.null(grid_by)){
    facet_by <- grid_by
    grid_by <- NULL
  }
  if (!is.null(facet_by)){
    facet <- as.data.frame(phyloseq::sample_data(physeq_obj))[[facet_by]]
    names(facet) <- row.names(phyloseq::sample_data(physeq_obj))
    ord <- match(counts_long$Sample, names(facet))
    facet <- facet[ord]
    counts_long$facet <- facet
  }
  if (!is.null(grid_by)){
    grid <- as.data.frame(phyloseq::sample_data(physeq_obj))[[grid_by]]
    names(grid) <- row.names(phyloseq::sample_data(physeq_obj))
    ord <- match(counts_long$Sample, names(grid))
    grid <- grid[ord]
    counts_long$grid <- grid
  }

  #Generate a plot
  p <- ggplot2::ggplot(counts_long, aes(x = Sample, y = Abundance, fill = label_by)) +
    ggplot2::geom_bar(position = "stack", stat = "identity", width = bar_width) +
    ggplot2::guides(fill=guide_legend(title = label_by, ncol = 1)) +
    ggplot2::scale_fill_manual(values = clr_pal) +
    ggplot2::scale_y_continuous(expand = c(0,0)) +
    ggplot2::theme(axis.line.x = element_line(colour = 'grey'),
          axis.line.y = element_line(colour = 'grey'),
          axis.ticks = element_line(colour = 'grey'),
          axis.text.x = element_text(angle = 90, family = "Helvetica",
                                     size = 6, hjust = 1, vjust = 0.5),
          legend.background = element_rect(fill = 'transparent', colour = NA),
          legend.key = element_rect(fill = "transparent"),
          legend.key.size = unit(0.4, "cm"),
          panel.background = element_rect(fill = 'transparent', colour = NA),
          panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(colour = adjustcolor('grey', 0.2)),
          panel.grid.minor = element_line(colour = NA),
          plot.background = element_rect(fill = 'transparent', colour = NA),
          plot.title = element_text(hjust = 0.5),
          strip.background = element_blank(),
          strip.text = element_text(family = "Helvetica", size = 8, face = "bold"),
          text = element_text(family = "Helvetica", size = 8))

  if (!is.null(facet_by)) {
    if (facet_type == "wrap"){
      if (is.null(grid_by)){
        p <- p + ggplot2::facet_wrap(~facet, scales = "free", ncol = facet_cols)
      }else{
        p <- p + ggplot2::facet_wrap(~grid + facet, scales = "free", ncol = facet_cols)
      }
    }else{
      if (facet_type == "grid"){
        if (is.null(grid_by)){
          p <- p + ggplot2::facet_grid(~facet, scales = "free", space = "free")
        }else{
          p <- p + ggplot2::facet_grid(facet ~ grid, scales = "free", space = "free")
        }
      }
    }
  }

  return(p)
}

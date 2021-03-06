#' Calculate pairwise correlations
#'
#' Internal function to calculate pairwise correlations and return p values
#'
#' @param df A data frame or tibble.
#'
#' @import dplyr
#' @import tidyr
#' @importFrom rlang .data
#' @importFrom stats cor
#' @importFrom stats pf
#'
#' @return A data.frame with columns h_var, v_var, and p.value
#'


cor.prob <- function(df) {
  # Set degrees of freedome
  dfr <- nrow(df) - 2

  # Determine correlations
  R <- cor(df, use = "pairwise.complete.obs")
  above <- row(R) < col(R)

  # Calculate p values from F test
  r2 <- R[above]^2
  Fstat <- r2 * dfr / (1 - r2)
  R[above] <- 1 - pf(Fstat, 1, dfr)

  cor.mat <- t(R)
  cor.mat[upper.tri(cor.mat)] <- NA
  diag(cor.mat) <- NA

  cor.mat %>%
    as.data.frame() %>%
    tibble::rownames_to_column(var = "h_var") %>%
    gather(key = "v_var", value = "p.value", -.data$h_var)
}

#' Replica of Stata's pwcorr function
#'
#' Calculate and return a matrix of pairwise correlation coefficients. Returns
#'   significance levels if \code{method == "pearson"}
#'
#' @param df A data.frame or tibble.
#' @param vars A character vector of numeric variables to generate pairwise
#'   correlations for. If the default (\code{NULL}), all variables are included.
#' @param method One of \code{"pearson"}, \code{"kendall"}, or \code{"spearman"}
#'   passed on to \code{"cor"}.
#' @param var_label_df A data.frame or tibble with columns "variable" and
#'   "label" that contains display labels for each variable specified in
#'   \code{vars}.
#'
#'
#' @import dplyr
#' @import tidyr
#' @importFrom rlang .data
#' @export
#'
#' @return A data.frame displaying the pairwise correlation coefficients
#'   between all variables in \code{vars}.
#'

pwcorr <- function(df, vars = NULL, method = "pearson", var_label_df = NULL) {

  if (!method %in% c("pearson", "kendall", "spearman"))
    stop("Invalid correlation method specified")

  if (is.null(vars)) vars <- names(df)

  # Variable labels for display
  if (!is.null(var_label_df)) {
    if (!names(var_label_df) %in% c("variable", "label"))
      stop("var_label_df must contains columns `variable` and `label`")
    labels <- var_label_df$label[var_label_df$variable %in% vars]
  } else {
    labels <- vars
  }

  # Restrict data to requested variables
  df <- select(df, one_of(vars))

  cor.matrix <- cor(df, method = method, use = "pairwise.complete.obs")
  cor.matrix[upper.tri(cor.matrix)] <- NA

  display <- cor.matrix %>%
    as.data.frame() %>%
    tibble::rownames_to_column(var = "h_var") %>%
    mutate_if(is.numeric, round, 3)

  if(method == "pearson") {
    display <- display %>%
      gather(key = "v_var", value = "corr", -.data$h_var) %>%
      left_join(cor.prob(df), by = c("h_var", "v_var")) %>%
      mutate(p.disp = case_when(.data$p.value < 0.01 ~ "<0.01",
                                 is.na(.data$p.value) ~ NA_character_,
                                 TRUE ~ paste(round(.data$p.value, 2))),
             display = case_when(!is.na(.data$corr) & !is.na(.data$p.disp) ~
                                   paste0(round(.data$corr, 2), "\n(", .data$p.disp, ")"),
                                 .data$corr == 1 & is.na(.data$p.disp) ~ "1",
                                 is.na(.data$corr) & is.na(.data$p.disp) ~ " ",
                                 TRUE ~ NA_character_)) %>%
      select(.data$h_var, .data$v_var, .data$display) %>%
      mutate(h_var = factor(.data$h_var, levels = vars, labels = labels),
             v_var = factor(.data$v_var, levels = vars, labels = labels)) %>%
      arrange(.data$h_var, .data$v_var) %>%
      spread(key = "v_var", value = "display") %>%
      rename(" " = .data$h_var)
  }

  return(display)
}

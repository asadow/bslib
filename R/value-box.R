#' Value box
#'
#' An opinionated ([card()]-powered) box, designed for displaying a `value` and
#' `title`. Optionally, a `showcase` can provide for context for what the
#' `value` represents (for example, it could hold a [bsicons::bs_icon()], or
#' even a [shiny::plotOutput()]).
#'
#' @param title,value A string, number, or [htmltools::tag()] child to display as
#'   the title or value of the value box. The `title` appears above the `value`.
#' @param ... Unnamed arguments may be any [htmltools::tag()] children to
#'   display below `value`. Named arguments become attributes on the containing
#'   element.
#' @param showcase A [htmltools::tag()] child to showcase (e.g., a
#'   [bsicons::bs_icon()], a `plotly::plotlyOutput()`, etc).
#' @param showcase_layout either `showcase_left_center()` or
#'   `showcase_top_right()`.
#' @param theme_color A theme color to use for the background color. Should
#'   match a name in the Bootstrap Sass variable `$theme-colors` (e.g.,
#'   `"secondary"`, `"success"`, `"danger"`, etc).
#' @param class Utility classes for customizing the appearance of the summary
#'   card. Use `bg-*` and `text-*` classes (e.g, `"bg-danger"` and
#'   `"text-light"`) to customize the background/foreground colors.
#' @param fill Whether to allow the value box to grow/shrink to fit a fillable
#'   container with an opinionated height (e.g., `page_fillable()`).
#' @inheritParams card
#' @export
#' @seealso [card()]
#' @examples
#'
#' library(htmltools)
#'
#' if (interactive()) {
#'   value_box(
#'     "KPI Title",
#'     h1(HTML("$1 <i>Billion</i> Dollars")),
#'     span(
#'       bsicons::bs_icon("arrow-up"),
#'       " 30% VS PREVIOUS 30 DAYS"
#'     ),
#'     showcase = bsicons::bs_icon("piggy-bank"),
#'     class = "bg-success"
#'   )
#' }
value_box <- function(title, value, ..., showcase = NULL, showcase_layout = showcase_left_center(), full_screen = FALSE, theme_color = "primary", height = NULL, max_height = NULL, fill = TRUE, class = NULL) {

  args <- rlang::list2(...)
  argnames <- rlang::names2(args)

  attribs <- args[nzchar(argnames)]
  children <- args[!nzchar(argnames)]

  if (rlang::is_bare_character(title) || rlang::is_bare_numeric(title)) {
    title <- tags$p(title)
  }
  if (rlang::is_bare_character(value) || rlang::is_bare_numeric(value)) {
    value <- tags$p(value)
  }

  contents <- div(class = "value-box-area", title, value, !!!children)
  contents <- bindFillRole(contents, container = TRUE, item = TRUE)

  if (!is.null(showcase)) {
    contents <- showcase_layout(showcase, contents)
  }

  res <- card(
    class = c("bslib-value-box border-0", paste0("bg-", theme_color), class),
    full_screen = full_screen,
    height = height,
    max_height = max_height,
    fill = fill,
    !!!attribs,
    contents
  )

  as_fragment(tag_require(res, version = 5, caller = "value_box()"))
}

#' @param width one of the following:
#'   * A proportion (i.e., a number between 0 and 1) of available width to
#'     allocate to the showcase.
#'   * A vector of length 2 valid [CSS unit][htmltools::validateCssUnit] defining
#'     the width of each column (for `showcase_left_center()` the 1st unit defines
#'     the showcase width and for `showcase_top_right` the 2nd unit defines the
#'     showcase width). Note that any units supported by the CSS grid
#'     `grid-template-columns` property may be used (e.g., `fr` units).
#' @param max_height,max_height_full_screen A proportion (i.e., a number between
#'   0 and 1) or any valid [CSS unit][htmltools::validateCssUnit] defining the
#'   showcase max_height.
#'
#' @export
#' @rdname value_box
showcase_left_center <- function(width = 0.3, max_height = "100px", max_height_full_screen = 0.67) {
  showcase_layout_(width, max_height, max_height_full_screen, top_right = FALSE)
}

#' @export
#' @rdname value_box
showcase_top_right <- function(width = 0.3, max_height = "75px", max_height_full_screen = 0.67) {
  if (is_01_scalar(width)) {
    width <- 1 - width
  }
  showcase_layout_(width, max_height, max_height_full_screen, top_right = TRUE)
}


showcase_layout_ <- function(width, max_height, max_height_full_screen, top_right) {

  width <- validate_width_unit(width)
  max_height <- validate_height_unit(max_height)
  max_height_full_screen <- validate_height_unit(max_height_full_screen)

  function(showcase, contents) {

    showcase_container <- div(
      class = "value-box-showcase",
      class = "overflow-hidden",
      class = if (top_right) "showcase-top-right",
      style = css(
        "--bslib-value-box-max-height" = max_height,
        "--bslib-value-box-max-height-full-screen" = max_height_full_screen
      ),
      showcase
    )

    showcase_container <- bindFillRole(showcase_container, container = TRUE, item = TRUE)

    if (!top_right) {
      contents <- tagAppendAttributes(contents, class = "border-start")
    }

    items <- list(showcase_container, contents)
    width_fs <- c("1fr", "auto")
    if (top_right) {
      items <- rev(items)
      width_fs <- rev(width_fs)
    }

    card_body(
      style = css(padding = 0),
      layout_column_wrap(
        width = NULL, gap = 0,
        heights_equal = "row",
        class = "value-box-grid",
        style = css(
          "--bslib-value-box-widths" = width,
          "--bslib-value-box-widths-full-screen" = width_fs
        ),
        !!!items
      )
    )
  }
}


# It seems to be to use % over fr here since there is no gap on the grid
validate_width_unit <- function(x) {
  if (!is_01_scalar(x)) {
    # TODO: validateCssUnit() should maybe support fr units?
    return(paste(x, collapse = " "))
  }
  paste(paste0(c(100 * x, 100 * (1 - x)), "%"), collapse = " ")
}

validate_height_unit <- function(x) {
  if (!is_01_scalar(x)) {
    return(validateCssUnit(x))
  }
  paste0(100 * x, "%")
}

is_01_scalar <- function(x) {
  rlang::is_scalar_double(x) && x >= 0 && x <= 1
}

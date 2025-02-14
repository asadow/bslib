#' Create a vertically collapsing accordion
#'
#' @param ... Named arguments become attributes on the `<div class="accordion">`
#'   element. Unnamed arguments should be `accordion_panel()`s.
#' @param id If provided, you can use `input$id` in your server logic to
#'   determine which of the `accordion_panel()`s are currently active. The value
#'   will correspond to the `accordion_panel()`'s `value` argument.
#' @param open A character vector of `accordion_panel()` `value`s to open
#'   (i.e., show) by default. The default value of `NULL` will open the first
#'   `accordion_panel()`. Use a value of `TRUE` to open all (or `FALSE` to
#'   open none) of the items. It's only possible to open more than one panel
#'   when `multiple=TRUE`.
#' @param multiple Whether multiple `accordion_panel()` can be `open` at once.
#' @param class Additional CSS classes to include on the accordion div.
#' @param width,height Any valid CSS unit; for example, height="100%".
#'
#' @references <https://getbootstrap.com/docs/5.2/components/accordion/>
#'
#' @export
#' @seealso [accordion_panel_set()]
#' @examplesIf interactive()
#'
#' items <- lapply(LETTERS, function(x) {
#'   accordion_panel(paste("Section", x), paste("Some narrative for section", x))
#' })
#'
#' # First shown by default
#' accordion(!!!items)
#' # Nothing shown by default
#' accordion(!!!items, open = FALSE)
#' # Everything shown by default
#' accordion(!!!items, open = TRUE)
#'
#' # Show particular sections
#' accordion(!!!items, open = "Section B")
#' accordion(!!!items, open = c("Section A", "Section B"))
#'
#' # Provide an id to create a shiny input binding
#' library(shiny)
#'
#' ui <- page_fluid(
#'   accordion(!!!items, id = "acc")
#' )
#'
#' server <- function(input, output) {
#'   observe(print(input$acc))
#' }
#'
#' shinyApp(ui, server)
#'
accordion <- function(..., id = NULL, open = NULL, multiple = TRUE, class = NULL, width = NULL, height = NULL) {

  args <- rlang::list2(...)
  argnames <- rlang::names2(args)

  attrs <- args[nzchar(argnames)]
  children <- args[!nzchar(argnames)]

  if (isNamespaceLoaded("shiny")) {
    open <- shiny::restoreInput(id = id, default = open)
  }

  is_open <- vapply(children, function(x) {
    isTRUE(open) || isTRUE(tagGetAttribute(x, "data-value") %in% open)
  }, logical(1))

  if (!any(is_open) && !identical(open, FALSE)) {
    is_open[1] <- TRUE
  }

  if (!multiple && sum(is_open) > 1) {
    abort("Can't select more than one panel when `multiple = FALSE`")
  }

  # Since multiple=FALSE requires an id, we always include one,
  # but only create a binding when it's provided
  if (is.null(id)) {
    id <- paste0("bslib-accordion-", p_randomInt(1000, 10000))
  } else {
    class <- c("bslib-accordion-input", class)
  }

  children <- Map(
    children, is_open,
    f = function(x, open) {

      if (!multiple) {
        x <- tagAppendAttributes(
          x, "data-bs-parent" = paste0("#", id),
          .cssSelector = ".accordion-collapse"
        )
      }

      # accordion_panel() defaults to a collapsed state
      if (open) {
        tq <- tagQuery(x)
        tq$find(".accordion-collapse")$addClass("show")
        tq$find(".accordion-button")$removeClass("collapsed")$removeAttrs("aria-expanded")$addAttrs("aria-expanded" = "true")
        x <- tq$allTags()
      }

      x
    }
  )

  tag <- div(
    id = id,
    class = "accordion",
    class = if (!multiple) "autoclose", # just for ease of identifying autoclosing client-side
    class = class,
    style = css(
      width = validateCssUnit(width),
      height = validateCssUnit(height)
    ),
    !!!attrs,
    !!!children,
    accordion_dependency()
  )

  tag <- tag_require(tag, version = 5, caller = "accordion()")

  as_fragment(tag)
}

#' @rdname accordion
#' @param title A title to appear in the `accordion_panel()`'s header.
#' @param value A character string that uniquely identifies this panel.
#' @param icon A [htmltools::tag] child (e.g., [bsicons::bs_icon()]) which is positioned just before the `title`.
#' @export
accordion_panel <- function(title, ..., value = title, icon = NULL) {

  id <- paste0("bslib-accordion-panel-", p_randomInt(1000, 10000))

  btn <- tags$button(
    class = "accordion-button collapsed",
    type = "button",
    "data-bs-toggle" = "collapse",
    "data-bs-target" = paste0("#", id),
    "aria-expanded" = "false",
    "aria-controls" = id,
    # Always include an .accordion-icon container to simplify accordion_panel_update() logic
    div(class = "accordion-icon", icon),
    div(class = "accordion-title", title)
  )

  if (!rlang::is_string(value)) abort("`value` must be a character string")

  div(
    class = "accordion-item",
    "data-value" = value,
    # Use a <span.h2> instead of <h2> so that it doesn't get included in rmd/pkgdown/qmd TOC
    # TODO: can we provide a way to put more stuff in the header? Like maybe some right-aligned controls?
    span(class = "accordion-header h2", btn),
    div(
      id = id,
      class = "accordion-collapse collapse",
      div(class = "accordion-body", ...)
    )
  )
}

#' Dynamically update accordions
#'
#' Dynamically (i.e., programmatically) update/modify [`accordion()`]s in a
#' Shiny app. These functions require an `id` to be provided to the
#' `accordion()` and must also be called within an active Shiny session.
#'
#' @param id an character string that matches an existing [accordion()]'s `id`.
#' @param values either a character string (used to identify particular
#'   [accordion_panel()]s by their `value`) or `TRUE` (i.e., all `values`).
#' @param session a shiny session object (the default should almost always be
#'   used).
#'
#' @describeIn accordion_panel_set same as `accordion_panel_open()`, except it
#'   also closes any currently open panels.
#' @export
accordion_panel_set <- function(id, values, session = get_current_session()) {
  send_panel_message(
    id, session, method = "set",
    values = if (isTRUE(values)) values else as.list(check_character(values))
  )
}

#' @describeIn accordion_panel_set open [accordion_panel()]s.
#' @export
accordion_panel_open <- function(id, values, session = get_current_session()) {
  send_panel_message(
    id, session, method = "open",
    values = if (isTRUE(values)) values else as.list(check_character(values))
  )
}

#' @describeIn accordion_panel_set close [accordion_panel()]s.
#' @export
accordion_panel_close <- function(id, values, session = get_current_session()) {
  send_panel_message(
    id, session, method = "close",
    values = if (isTRUE(values)) values else as.list(check_character(values))
  )
}

#' @param panel an [accordion_panel()].
#' @param target The `value` of an existing panel to insert next to. If
#'   removing: the `value` of the [accordion_panel()] to remove.
#' @param position Should `panel` be added before or after the target? When
#'   `target` is `NULL` (the default), `"after"` will append after the last
#'   panel and `"before"` will prepend before the first panel.
#'
#' @describeIn accordion_panel_set insert a new [accordion_panel()]
#' @export
accordion_panel_insert <- function(id, panel, target = NULL, position = c("after", "before"), session = get_current_session()) {
  position <- match.arg(position)
  send_panel_message(
    id, session, method = "insert",
    panel = processDeps(panel, session),
    target = if (!is.null(target)) check_character(target, max_length = 1),
    position = position
  )
}

#' @describeIn accordion_panel_set remove [accordion_panel()]s.
#' @export
accordion_panel_remove <- function(id, target, session = get_current_session()) {
  send_panel_message(
    id, session, method = "remove",
    target = as.list(check_character(target))
  )
}


#' @describeIn accordion_panel_set update a [accordion_panel()].
#' @inheritParams accordion_panel
#' @export
accordion_panel_update <- function(id, target, ..., title = NULL, value = NULL, icon = NULL, session = get_current_session()) {
  body <- rlang::list2(...)

  send_panel_message(
    id, session, method = "update",
    target = check_character(target, max_length = 1),
    value = if (!is.null(value)) check_character(value, max_length = 1),
    body = if (length(body) == 0) NULL else processDeps(body, session),
    title = if (!is.null(title)) processDeps(title, session),
    icon = if (!is.null(icon)) processDeps(icon, session)
  )
}


# Send message before the next flush since things like remove/insert may
# remove/create input/output values. Also do this for set/open/close since,
# you might want to open a panel after inserting it.
send_panel_message <- function(id, session, ...) {
  message <- dropNulls(rlang::list2(...))
  callback <- function() session$sendInputMessage(id, message)
  session$onFlush(callback, once = TRUE)
}

check_character <- function(x, max_length = Inf, min_length = 1, call = rlang::caller_env()) {
  x_name <- deparse(substitute(x))
  if (!is.character(x)) {
    abort(
      sprintf("`%s` must be a character vector.", x_name),
      call = call
    )
  }
  if (length(x) < min_length) {
    abort(
      sprintf("`%s` must have length %s or more.", x_name, min_length),
      call = call
    )
  }
  if (length(x) > max_length) {
    abort(
      sprintf("`%s` must have length %s or less.", x_name, max_length),
      call = call
    )
  }
  x
}

accordion_dependency <- function() {
  htmlDependency(
    name = "bslib-accordion",
    version = get_package_version("bslib"),
    package = "bslib",
    src = "components",
    script = "accordion.min.js"
  )
}

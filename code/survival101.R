# This module contains a code example related to Survival 101 classes
# by Pasha Roberts, Talent Analytics, Corp. http://talentanalytics.com
#
# Feel free to use/modify code in accordance with the MIT license:
# https://github.com/talentanalytics/class_survival_101/blob/master/LICENSE

library(dplyr)
library(lubridate)

#' The main demo - designed to be run piece-by-piece on command line (see slides)
survivalDemo <- function(verbose = TRUE) {

  if (verbose)
    writeLines(">> Generating test data")

  attr.data <- genAttritionData()

  training.data <- dplyr::filter(attr.data, is.training)
  validation.data <- dplyr::filter(attr.data, !is.training)

  # print(attr.data)
  # print(summary(attr.data))
  # print(glimpse(attr.data))
  if (verbose) {
    print(attr.data %>%
      select(emp.id, hire.date, term.date, end.date, is.term, tenure.years)
      %>% sample_n(10))
    print(attr.data %>%
      select(emp.id, is.term, tenure.years, factor.x, factor.y, factor.z)
      %>% sample_n(10))
    print(attr.data %>%
      select(emp.id, is.term, tenure.years, scale.x, scale.y, scale.z)
      %>% sample_n(10))
  }

  if (verbose)
    writeLines(">> Calculating survival object")

  surv.obj <- survival::Surv(training.data$tenure.years, training.data$is.term)

  if (verbose)
    writeLines(">> Calculating survival fit")

  surv.fit <- survival::survfit(surv.obj ~ 1)

  # NOTE: surv.fit is the same as a life table

  if (verbose) {
    print(surv.fit)
    plot(surv.fit)
    print(plotSurvFit(surv.fit))
  }

  if (verbose)
    writeLines(">> Calculating survival fit by label")

  surv.fit.label <- survival::survfit(surv.obj ~ training.data$label)

  if (verbose) {
    print(surv.fit.label)
    plot(surv.fit.label)
    print(plotSurvFit(surv.fit.label))
  }

  if (verbose)
    writeLines(">> Calculating Cox model")

  cox.model <- survival::coxph(formula = surv.obj ~ scale.x + scale.y + scale.z,
                               data = training.data)
  if (verbose) {
    print(summary(cox.model))
    # print(survival::cox.zph(cox.model))
  }

  if (verbose)
    writeLines(">> Predicting with Cox model")

  cox.pred <- predict(cox.model, newdata = validation.data, type = "lp")

  if (verbose)
    writeLines(">> Validating Cox model")

  time.data <- validation.data$tenure.years
  event.data <- validation.data$is.term

  # calc ROC/AUC for these predictions
  roc.obj <- survivalROC::survivalROC(Stime = time.data,
                                      status = event.data,
                                      marker = cox.pred,
                                      predict.time = 1,
                                      lambda = 0.003)
                                      # method = "KM")
  print(plotSurvAUC(roc.obj))

  return(roc.obj$AUC)
}

#' Generate a database of random employment spans 
#' @param n the number to create
#' @param hire.start Hire dates are selected uniformly between hire.start and hire.end (MDY text format)
#' @param hire.end Hire dates are selected uniformly between hire.start and hire.end (MDY text format)
#' @param censor.date Date at which we view the data; used to calculate is.term (MDY text format)
#' @return data.frame(label, start.date, term.date)
genAttritionData <- function(n = 400,
                             hire.start = "1.1.2013",
                             hire.end = "5.1.2017",
                             censor.date = hire.end) {

  # create and bind rows for group a and b
  attr.data <- dplyr::bind_rows(
                  # group "a" has 5 year tenure
                  genRandomSpans(label = "a", n = n / 4,
                    hire.start = hire.start, hire.end = hire.end,
                    censor.date = censor.date,
                    tenure.mean = 5, tenure.sd = 1),

                  # group "b" has 2 year tenure
                  genRandomSpans(label = "b", n = n / 4,
                    hire.start = hire.start, hire.end = hire.end,
                    censor.date = censor.date,
                    tenure.mean = 2, tenure.sd = 1),

                  # group "c" has 7 year tenure
                  genRandomSpans(label = "c", n = n / 4,
                    hire.start = hire.start, hire.end = hire.end,
                    censor.date = censor.date,
                    tenure.mean = 7, tenure.sd = 3),

                  # group "d" has 1 year tenure
                  genRandomSpans(label = "d", n = n / 4,
                    hire.start = hire.start, hire.end = hire.end,
                    censor.date = censor.date,
                    tenure.mean = 1, tenure.sd = 0.25)) %>%

               # clean it up and add fields just to make it neat
               dplyr::mutate(
                 # labels are more useful as factors
                 label = factor(label),
                 # fake emp.id
                 emp.id = row_number(),
                 # scale the input variables
                 scale.x = scale(factor.x),
                 scale.y = scale(factor.y),
                 scale.z = scale(factor.z)
               )

  # split data into train, validate
  train.n <- round(0.8 * nrow(attr.data))
  train.sample <- sample(as.integer(rownames(attr.data)), train.n)

  attr.data$is.training <- FALSE
  attr.data$is.training[train.sample] <- TRUE

  return(attr.data)
}

#' Generate a database of random employment spans  - helper for genAttritionData()
#' @param n the number to create
#' @param hire.start Hire dates are selected uniformly between hire.start and hire.end (MDY text format)
#' @param hire.end Hire dates are selected uniformly between hire.start and hire.end (MDY text format)
#' @param censor.date Date at which we view the data; used to calculate is.term (MDY text format)
#' @param label A categorization label, eg Sydney or Sales
#' @return data.frame(label, start.date, term.date)
genRandomSpans <- function(label, n,
                           hire.start, hire.end, censor.date,
                           tenure.mean, tenure.sd) {

  # turn censor date to posix
  censor.posix <- lubridate::mdy_hms(stringr::str_trim(censor.date), truncated = 3)

  # random uniform distro of hire dates between given
  hire.date <- runif(n,
    min = lubridate::mdy_hms(stringr::str_trim(hire.start), truncated = 3),
    max = lubridate::mdy_hms(stringr::str_trim(hire.end), truncated = 3))

  # make hire.date a proper POSIXct date, since runif turned it to an integer
  hire.date <- as.POSIXct(hire.date, tz = "UTC", origin = "1970-01-01")

  # normal distribution of tenure years based on input
  tenure.days <- rnorm(n, mean = tenure.mean, sd = tenure.sd) * 365.25
  tenure.days <- pmax(0, round(tenure.days))

  span.data <- data.frame(label = label, hire.date = hire.date, tenure.days = tenure.days,
                          stringsAsFactors = FALSE) %>%
        dplyr::mutate(
          # set the term date based on our random tenure.days
          term.date = hire.date + lubridate::days(tenure.days),
          # logical variable whether we know it's termed based on right censoring
          is.term = term.date >= censor.posix,
          # NA term dates if they are censored.
          # dplyr's if_else preserves types
          term.date = dplyr::if_else(is.term, as.POSIXct(NA), term.date),
          # create separate end.date field to encompass termination or censoring
          end.date = dplyr::if_else(is.term, censor.posix, term.date),
          # recalculate known tenure based on end.date
          tenure.years = as.numeric(difftime(end.date, hire.date, units = "days")) / 365.25,
          # create amazingly fantastic independent variables with some gaussian noise
          factor.x = tenure.years + rnorm(n(), 0, 2),
          factor.y = tenure.years + rnorm(n(), 10, 4),
          factor.z = tenure.years + rnorm(n(), 100, 5)
        ) %>%

        # floor the dates to whole days because that's how hiring works and to keep it neat
        # intentionally not namespacing floor_date due to funs() namespace issue
        dplyr::mutate_each(dplyr::funs(floor_date(., unit = "days")),
          hire.date, term.date, end.date) %>%
        # remove tenure.days field from data frame
        dplyr::select(-tenure.days) %>%
        # tbl_df just makes it easier to handle on command line
        dplyr::tbl_df()

  return(span.data)
}

#' Decomoposes a survfit object into flat data.frame
#' @param survfit.data a survfit() object
#' @return data.frame("strata", "time", "surv")
survFitData <- function(survfit.data) {

  stopifnot(class(survfit.data) == "survfit")

  # take apart the mess inside of survfit into a nice data.frame so we can use ggplot
  # show (a) a single curve or
  #      (b) multiple curves broken out, with optional
  #      (c) model projected curve

  # pull apart strata into melted table
  # strata, time, surv
  surv.data <- data.frame()
  if (is.null(survfit.data$strata)) {
    # this is a singular surv model ~ 1
    # save survfit.data$time survfit.data$surv
    surv.data <- data.frame(strata = "1", time = survfit.data$time, surv = survfit.data$surv)

  } else {
    # this is a multi surv model ~ x
    # it is stored non-intuitively in one series for all
    zi.time <- 1
    zstr.name <- strsplit(names(survfit.data$strata), "=")

    # go through each stratum and pull out its data
    for (zi.strata in 1:length(survfit.data$strata)) {

      # what are the indices of the data for this stratum
      zstr.range <- seq(zi.time, zi.time + survfit.data$strata[zi.strata] - 1)

      # pull that subset of data into a data.frame and bind it to prior work
      surv.data <- dplyr::bind_rows(surv.data,
                         data.frame(strata = zstr.name[[zi.strata]][2],
                                    time = survfit.data$time[zstr.range],
                                    surv = survfit.data$surv[zstr.range],
                                    stringsAsFactors = FALSE))
      # update indexing variable
      zi.time <- zi.time + survfit.data$strata[zi.strata]
    }
  }

  surv.data <- surv.data %>%
                  # plotSurvFit() expects a factor
                  dplyr::mutate(strata = factor(strata)) %>%
                  # tbl_df makes cli use easier
                  dplyr::tbl_df()

  return(surv.data)
}

#' create a ggplot2 plot of one or more survival curves
#' @param fit.data either a survfit() object or a survFitData() data.frame
#' @return a ggplot2 plot
plotSurvFit <- function(surv.data) {

  # if they send a survfit object, convert it to a proper data frame
  if (class(surv.data) == "survfit")
    surv.data <- survFitData(surv.data)

  stopifnot(names(surv.data) == c("strata", "time", "surv"))

  p <- ggplot2::ggplot(surv.data,
                       ggplot2::aes(x = time, y = surv, col = strata))
  p <- p + ggplot2::geom_step(size = 1)

  p <- p + ggplot2::scale_x_continuous(name = "Years Tenure")
  p <- p + ggplot2::scale_y_continuous(name = "Probability of Survival",
                                       breaks = seq(0, 1, 0.2),
                                       limits = c(0, 1),
                                       labels = scales::percent)

  p <- p + ggplot2::theme_bw()
  p <- p + ggplot2::theme(panel.border = ggplot2::element_blank())

  # legend depends on whether we have strata; run after theme_bw()
  if (length(levels(surv.data$strata)) > 1) {
    p <- p + ggplot2::scale_color_discrete(name = "Strata")
    p <- p + ggplot2::theme(legend.position = "bottom")
  } else {
    p <- p + ggplot2::theme(legend.position = "none")
    p <- p + ggplot2::scale_color_discrete()
  }

  return(p)
}

#' create a ggplot2 plot of the ROC from a model
#' @param roc.data a list returned by survivalROC()
#' @return a ggplot2 plot
plotSurvAUC <- function(roc.data) {

  stopifnot(class(roc.data) == "list")
  stopifnot("FP" %in% names(roc.data))
  stopifnot("TP" %in% names(roc.data))

  # make a data frame from the list object returned by survivalROC
  plot.data <- data.frame(fpr = roc.data$FP, tpr = roc.data$TP) %>%
                  # # only one unique point per fp
                  dplyr::group_by(fpr) %>%
                  dplyr::summarize(tpr = last(tpr)) %>%
                  dplyr::ungroup()

  p <- ggplot2::ggplot(plot.data,
                       ggplot2::aes(x = fpr, y = tpr))
  p <- p + ggplot2::geom_line(size = 2, col = "slateblue")

  p <- p + ggplot2::geom_abline(intercept = 0, slope = 1, linetype = "dashed",
                                alpha = 0.5, size = 1, col = "black")

  p <- p + ggplot2::scale_x_continuous(name = "False Positive Rate (1 - Specificity)",
                                       breaks = seq(0, 1, 0.2),
                                       limits = c(0, 1),
                                       labels = scales::percent)
  p <- p + ggplot2::scale_y_continuous(name = "True Positive Rate (Sensitivity)",
                                       breaks = seq(0, 1, 0.2),
                                       limits = c(0, 1),
                                       labels = scales::percent)

  p <- p + ggplot2::theme_bw()
  p <- p + ggplot2::theme(panel.border = ggplot2::element_blank())

  return(p)

}

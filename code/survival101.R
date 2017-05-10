# This module contains a code example related to Survival 101 classes
# by Pasha Roberts, Talent Analytics, Corp. http://talentanalytics.com
#
# Feel free to use/modify code in accordance with the MIT license:
# https://github.com/talentanalytics/class_survival_101/blob/master/LICENSE

library(dplyr)
library(lubridate)

main <- function() {

  attr.data <- genAttritionData()

  # 475 Calculate Survival Object (H0) from Attrition
  surv.obj <- survival::Surv(attr.data$hire.tenure.years, attr.data$is.term)

  print(surv.obj)

  ## 469 Calculate Kaplan-Meier Estimator of Survival

  surv.fit <- survival::survfit(surv.obj ~ 1)

  # extract time, surv from surv.fit object
  # turn into a dplyr tibble for convenience
  h0.data <- data.frame(time = surv.fit$time, surv = surv.fit$surv) %>%
                 dplyr::tbl_df()

  cox.model <- survival::coxph(formula = surv.obj ~ input1 + input2 + input3, data = attr.data)

  # 477 Use Cox Model to Predict Survival

  cox.pred <- predict(cox.model, newdata = attr.data, type = "lp")

  # 478 Calculate New Survival Curve

  first.surv <- data.frame(time = h0.data$time,
                           surv = exp( -1 * h0.data$cume.hazard * exp(cox.pred[1])))
  # 479 AUC
  survivalROC::survivalROC(Stime = time.data,
                           status = event.data,
                           marker = predict.data,
                           predict.time = predict.time)
}

#' generate a database of random employment spans 
#' @param n the number to create
#' @param hire.start Hire dates are selected uniformly between hire.start and hire.end (MDY text format)
#' @param hire.end Hire dates are selected uniformly between hire.start and hire.end (MDY text format)
#' @param censor.date Date at which we view the data; used to calculate is.term (MDY text format)
#' @param seed A random seed for repeatable results - default NA
#' @return data.frame(label, start.date, term.date)
genAttritionData <- function(n = 200,
                             hire.start = "1.1.2013",
                             hire.end = "5.1.2017",
                             censor.date = "5.1.2017",
                             seed = NA) {

  if (!is.na(seed)) {
    # setting the seed will make random functions behave the same each time
    set.seed(seed)
  }

  # create and bind rows for group a and b
  dplyr::bind_rows(
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
      dplyr::mutate(label = factor(label))
}

#' generate a database of random employment spans  - helper for genAttritionData()
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
          # create fake independent variables with some noise
          factor.x = tenure.days + rnorm(n(), 0, 300),
          factor.y = tenure.days + rnorm(n(), 0, 600)
        ) %>%

        # floor the dates to whole days because that's how hiring works.
        # intentionally not namespacing floor_date due to funs() namespace issue
        dplyr::mutate_each(dplyr::funs(floor_date(., unit = "days")),
          hire.date, term.date, end.date) %>%
        # remove tenure.days field from data frame
        dplyr::select(-tenure.days) %>%
        # tbl_df just makes it easier to handle on command line
        dplyr::tbl_df()

  return(span.data)
}

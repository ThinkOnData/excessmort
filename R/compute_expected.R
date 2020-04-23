#' Compute expected counts for each day
#' @export
#' @importFrom stats glm contr.sum model.matrix contrasts<-
#'
compute_expected <- function(counts, exclude = NULL,
                             trend.nknots = 1/5,
                             harmonics = 2,
                             family = "poisson"){

  ## helper function
  fourier_trend <- function(x, k = 3){
    H <- lapply(1:k, function(k){
      cbind(sin(2*pi*k/365*x), cos(2*pi*k/365*x))
    })
    res <- do.call(cbind, H)
    colnames(res) <- paste(rep(c("sin", "cos"), k), rep(1:k, each = 2), sep="_")
    res
  }

  ## number of observations per year
  TT <- length(unique(noleap_yday(counts$date)))

  ## build design matrix
  # compute dfs
  dfs <- round(length(unique(year(counts$date[!counts$date %in% out_dates])))*trend.nknots)

  # make trend basis (includes intercept)
  x_t <- ns(as.numeric(counts$date), df = dfs + 1, intercept = TRUE)
  i_t <- 1:ncol(x_t)

  #for harmonic model
  yd <- noleap_yday(counts$date)
  x_h <- fourier_trend(yd, k = harmonics)
  i_h <- ncol(x_t) + 1:ncol(x_h)

  ## weekday effects
  w <- factor(wday(counts$date))
  contrasts(w) <- contr.sum(length(levels(w)), contrasts = TRUE)
  x_w <- model.matrix(~w)[, -1] ## intercept already in spline
  i_w <- ncol(x_t) + ncol(x_h) + 1:ncol(x_w)

  ## build desing matrix
  x <- cbind(x_t, x_h, x_w)
  y <- counts$outcome
  n <- counts$population

  ## fit model
  index <- which(!counts$date %in% out_dates)

  fit <- glm( y[index] ~ x[index,]-1, offset = log(n[index]), family = "poisson")

  # prepare stuff to return
  expected <- exp(x %*% fit$coefficients) * n
  resid <- y / expected - 1

  seasonal <- data.frame(day = 1:TT,
                     s = exp(fourier_trend(1:TT, k = harmonics)  %*% fit$coefficients[i_h]) -1)

  trend <- exp(x_t %*% fit$coefficients[i_t])  * TT * 1000

  w <- factor(1:7)
  contrasts(w) <- contr.sum(length(levels(w)), contrasts = TRUE)
  weekday <- data.frame(weekday = 1:7,
                    effect = exp(model.matrix(~w)[, -1] %*% fit$coefficients[i_w])-1)

  ## add expected counts to data table
  return(list(date = counts$date,
              expected = expected,
              resid = resid,
              trend = trend,
              seasonal = seasonal,
              weekday = weekday))
}
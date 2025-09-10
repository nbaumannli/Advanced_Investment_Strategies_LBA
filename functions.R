# Helper Functions for Betting-Against-Beta Strategy
# Functions to support BAB strategy implementation

# Load required libraries
suppressPackageStartupMessages({
  library(xts)
  library(dplyr)
  library(quantmod)
  library(PerformanceAnalytics)
  library(sandwich)
  library(lmtest)
})

#' Calculate rolling beta for a stock against market
#' @param stock_returns xts object of stock returns
#' @param market_returns xts object of market returns  
#' @param window rolling window length (default 36 months)
#' @return xts object of rolling betas
calculate_rolling_beta <- function(stock_returns, market_returns, window = 36) {
  # Align dates
  merged_data <- merge(stock_returns, market_returns, join = "inner")
  colnames(merged_data) <- c("stock", "market")
  
  # Remove any NA values
  merged_data <- na.omit(merged_data)
  
  if (nrow(merged_data) < window) {
    warning("Not enough data points for rolling beta calculation")
    return(xts(rep(NA, nrow(merged_data)), index(merged_data)))
  }
  
  # Calculate rolling beta
  beta_values <- rollapply(merged_data, width = window, 
                          function(x) {
                            if (sum(!is.na(x[,1])) < window/2 || sum(!is.na(x[,2])) < window/2) {
                              return(NA)
                            }
                            lm_fit <- lm(x[,1] ~ x[,2])
                            return(coef(lm_fit)[2])
                          }, 
                          by.column = FALSE, align = "right", fill = NA)
  
  return(beta_values)
}

#' Download S&P 500 stock data
#' @param start_date Start date for data download
#' @param end_date End date for data download
#' @param max_stocks Maximum number of stocks to include (for testing)
#' @return List containing stock returns and market returns
download_sp500_data <- function(start_date = "2000-01-01", end_date = Sys.Date(), max_stocks = NULL) {
  cat("Downloading S&P 500 constituent list...\n")
  
  # Get S&P 500 symbols (using a simplified approach)
  # In practice, you might want to get the actual S&P 500 list from a reliable source
  sp500_symbols <- c("AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "META", "NVDA", "BRK-B", 
                     "UNH", "JNJ", "JPM", "V", "PG", "XOM", "HD", "CVX", "MA", "BAC", 
                     "ABBV", "PFE", "AVGO", "COST", "DIS", "KO", "MRK", "PEP", "TMO", 
                     "ABT", "ACN", "ADBE", "LLY", "NFLX", "CMCSA", "NKE", "VZ", "CRM", 
                     "ORCL", "DHR", "WMT", "T", "TXN", "QCOM", "NEE", "PM", "HON", 
                     "UPS", "SPGI", "LOW", "IBM", "MDT", "AMT", "RTX", "AMAT", "AXP", 
                     "GS", "BLK", "CAT", "DE", "MU", "LMT", "BKNG", "GILD", "SBUX", 
                     "ADP", "TJX", "CVS", "MDLZ", "CI", "PYPL", "TMUS", "ISRG", "MMM", 
                     "SO", "ZTS", "MO", "CB", "SYK", "DUK", "CSX", "ITW", "AON", "CL", 
                     "EQIX", "PGR", "BSX", "APD", "COP", "SCHW", "MSI", "MCD", "WM", 
                     "ECL", "NSC", "ADSK", "INTU", "KLAC", "EL", "SHW", "GD", "MCK", 
                     "EMR", "CME", "TGT", "HUM", "REGN", "LRCX", "AFL", "NUE", "CTAS")
  
  if (!is.null(max_stocks)) {
    sp500_symbols <- sp500_symbols[1:min(max_stocks, length(sp500_symbols))]
  }
  
  cat(sprintf("Downloading data for %d stocks from %s to %s...\n", 
              length(sp500_symbols), start_date, end_date))
  
  # Download market data (SPY as proxy for S&P 500)
  cat("Downloading market data (SPY)...\n")
  getSymbols("SPY", src = "yahoo", from = start_date, to = end_date, auto.assign = FALSE) -> spy_data
  market_returns <- monthlyReturn(Cl(spy_data), type = "log")
  colnames(market_returns) <- "SPY"
  
  # Download individual stock data
  stock_returns_list <- list()
  successful_downloads <- 0
  
  for (symbol in sp500_symbols) {
    tryCatch({
      cat(sprintf("Downloading %s... ", symbol))
      stock_data <- getSymbols(symbol, src = "yahoo", from = start_date, to = end_date, 
                              auto.assign = FALSE, warnings = FALSE)
      
      if (!is.null(stock_data) && nrow(stock_data) > 0) {
        stock_ret <- monthlyReturn(Cl(stock_data), type = "log")
        colnames(stock_ret) <- symbol
        stock_returns_list[[symbol]] <- stock_ret
        successful_downloads <- successful_downloads + 1
        cat("✓\n")
      } else {
        cat("✗ (no data)\n")
      }
    }, error = function(e) {
      cat(sprintf("✗ (error: %s)\n", e$message))
    })
  }
  
  cat(sprintf("Successfully downloaded %d out of %d stocks\n", 
              successful_downloads, length(sp500_symbols)))
  
  return(list(
    stock_returns = stock_returns_list,
    market_returns = market_returns,
    symbols = names(stock_returns_list)
  ))
}

#' Calculate excess returns over risk-free rate
#' @param returns xts object of returns
#' @param rf_rate risk-free rate (annual, will be converted to monthly)
#' @return xts object of excess returns
calculate_excess_returns <- function(returns, rf_rate = 0.02) {
  monthly_rf <- (1 + rf_rate)^(1/12) - 1
  return(returns - monthly_rf)
}

#' Sort stocks into beta quintiles
#' @param beta_data named list of beta series for each stock
#' @param date specific date for sorting
#' @return list with quintile assignments
sort_into_quintiles <- function(beta_data, date) {
  # Get beta values for the specific date
  beta_values <- sapply(beta_data, function(x) {
    if (date %in% index(x)) {
      return(as.numeric(x[date]))
    } else {
      return(NA)
    }
  })
  
  # Remove NA values
  beta_values <- beta_values[!is.na(beta_values)]
  
  if (length(beta_values) < 5) {
    warning(sprintf("Not enough stocks with valid betas on %s", date))
    return(NULL)
  }
  
  # Create quintiles
  quintile_breaks <- quantile(beta_values, probs = c(0, 0.2, 0.4, 0.6, 0.8, 1.0), na.rm = TRUE)
  quintile_assignments <- cut(beta_values, breaks = quintile_breaks, 
                             labels = c("Q1", "Q2", "Q3", "Q4", "Q5"), include.lowest = TRUE)
  
  # Return list of symbols by quintile
  quintiles <- list()
  for (q in c("Q1", "Q2", "Q3", "Q4", "Q5")) {
    quintiles[[q]] <- names(beta_values)[quintile_assignments == q]
  }
  
  return(quintiles)
}

#' Calculate BAB strategy returns
#' @param stock_returns list of stock return series
#' @param quintile_assignments list with quintile assignments by date
#' @param leverage target leverage for the strategy
#' @return xts object of BAB strategy returns
calculate_bab_returns <- function(stock_returns, quintile_assignments, leverage = 1.0) {
  all_dates <- sort(unique(unlist(lapply(quintile_assignments, function(x) names(x)))))
  bab_returns <- xts(numeric(length(all_dates)), order.by = as.Date(all_dates))
  
  for (i in 2:length(all_dates)) {  # Start from 2 to use previous month's sorting
    current_date <- all_dates[i]
    prev_date <- all_dates[i-1]
    
    if (is.null(quintile_assignments[[prev_date]])) next
    
    quintiles <- quintile_assignments[[prev_date]]
    
    # Calculate equal-weighted returns for low and high beta quintiles
    low_beta_stocks <- quintiles[["Q1"]]
    high_beta_stocks <- quintiles[["Q5"]]
    
    # Calculate portfolio returns
    low_beta_ret <- 0
    high_beta_ret <- 0
    
    if (length(low_beta_stocks) > 0) {
      low_returns <- sapply(low_beta_stocks, function(s) {
        if (s %in% names(stock_returns) && current_date %in% index(stock_returns[[s]])) {
          return(as.numeric(stock_returns[[s]][current_date]))
        } else {
          return(NA)
        }
      })
      low_beta_ret <- mean(low_returns, na.rm = TRUE)
    }
    
    if (length(high_beta_stocks) > 0) {
      high_returns <- sapply(high_beta_stocks, function(s) {
        if (s %in% names(stock_returns) && current_date %in% index(stock_returns[[s]])) {
          return(as.numeric(stock_returns[[s]][current_date]))
        } else {
          return(NA)
        }
      })
      high_beta_ret <- mean(high_returns, na.rm = TRUE)
    }
    
    # BAB strategy: Long low beta, short high beta (market neutral)
    if (!is.na(low_beta_ret) && !is.na(high_beta_ret)) {
      bab_returns[current_date] <- leverage * (low_beta_ret - high_beta_ret)
    }
  }
  
  return(bab_returns)
}

#' Calculate performance statistics with Newey-West standard errors
#' @param strategy_returns xts object of strategy returns
#' @param market_returns xts object of market returns for alpha calculation
#' @return list of performance statistics
calculate_performance_stats <- function(strategy_returns, market_returns = NULL) {
  # Remove NA values
  strategy_returns <- na.omit(strategy_returns)
  
  if (nrow(strategy_returns) == 0) {
    warning("No valid returns data for performance calculation")
    return(NULL)
  }
  
  # Basic statistics
  total_return <- Return.cumulative(strategy_returns)
  annualized_return <- Return.annualized(strategy_returns)
  annualized_vol <- StdDev.annualized(strategy_returns)
  sharpe_ratio <- SharpeRatio.annualized(strategy_returns)
  max_drawdown <- maxDrawdown(strategy_returns)
  
  # Alpha calculation with Newey-West standard errors
  alpha_stats <- NULL
  if (!is.null(market_returns)) {
    # Align returns
    merged_data <- merge(strategy_returns, market_returns, join = "inner")
    merged_data <- na.omit(merged_data)
    
    if (nrow(merged_data) >= 12) {  # Need at least 12 observations
      # CAPM regression
      capm_model <- lm(merged_data[,1] ~ merged_data[,2])
      
      # Newey-West standard errors
      nw_se <- NeweyWest(capm_model)
      nw_coef_test <- coeftest(capm_model, vcov = nw_se)
      
      alpha_stats <- list(
        alpha = coef(capm_model)[1],
        alpha_tstat = nw_coef_test[1, 3],
        alpha_pvalue = nw_coef_test[1, 4],
        beta = coef(capm_model)[2],
        r_squared = summary(capm_model)$r.squared
      )
    }
  }
  
  return(list(
    total_return = total_return,
    annualized_return = annualized_return,
    annualized_volatility = annualized_vol,
    sharpe_ratio = sharpe_ratio,
    max_drawdown = max_drawdown,
    alpha_stats = alpha_stats,
    n_observations = nrow(strategy_returns)
  ))
}
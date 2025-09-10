# Betting-Against-Beta Strategy Implementation
# Replication of Frazzini & Pedersen (2014) Low-Beta Anomaly
# Author: Advanced Investment Strategies LBA
# Date: Created with R version 4.3.3

# =============================================================================
# SETUP AND CONFIGURATION
# =============================================================================

# Clear environment
rm(list = ls())

# Set working directory to script location
if (rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

# Source required functions
source("functions.R")

# Create directories for outputs
if (!dir.exists("data")) dir.create("data")
if (!dir.exists("plots")) dir.create("plots")

# Set random seed for reproducibility
set.seed(42)

# Configuration parameters
CONFIG <- list(
  start_date = "2005-01-01",      # Start date for analysis
  end_date = "2023-12-31",        # End date for analysis
  beta_window = 36,               # Rolling beta window (months)
  max_stocks = 50,                # Max stocks for testing (remove for full S&P 500)
  risk_free_rate = 0.02,          # Annual risk-free rate (2%)
  leverage = 1.0,                 # Strategy leverage
  rebalance_freq = "monthly"      # Rebalancing frequency
)

cat("=================================================================\n")
cat("BETTING-AGAINST-BETA STRATEGY IMPLEMENTATION\n")
cat("Replicating Frazzini & Pedersen (2014)\n")
cat("=================================================================\n\n")

# =============================================================================
# STEP 1: INSTALL PACKAGES AND LOAD LIBRARIES
# =============================================================================

cat("Step 1: Installing required packages...\n")
source("requirements.R")

# Load all required libraries
suppressPackageStartupMessages({
  library(quantmod)
  library(tidyquant)
  library(xts)
  library(zoo)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(PerformanceAnalytics)
  library(sandwich)
  library(lmtest)
  library(lubridate)
})

cat("✓ All packages loaded successfully\n\n")

# =============================================================================
# STEP 2: DOWNLOAD S&P 500 DATA
# =============================================================================

cat("Step 2: Downloading S&P 500 data...\n")
cat(sprintf("Date range: %s to %s\n", CONFIG$start_date, CONFIG$end_date))
cat(sprintf("Maximum stocks: %s\n", ifelse(is.null(CONFIG$max_stocks), "All S&P 500", CONFIG$max_stocks)))

# Download data
sp500_data <- download_sp500_data(
  start_date = CONFIG$start_date,
  end_date = CONFIG$end_date,
  max_stocks = CONFIG$max_stocks
)

cat(sprintf("✓ Downloaded data for %d stocks\n", length(sp500_data$symbols)))
cat(sprintf("✓ Market data (SPY) from %s to %s\n", 
            min(index(sp500_data$market_returns)), 
            max(index(sp500_data$market_returns))))

# Save raw data
saveRDS(sp500_data, "data/sp500_raw_data.rds")
cat("✓ Raw data saved to data/sp500_raw_data.rds\n\n")

# =============================================================================
# STEP 3: CALCULATE EXCESS RETURNS
# =============================================================================

cat("Step 3: Calculating excess returns...\n")
cat(sprintf("Risk-free rate: %.2f%% annual\n", CONFIG$risk_free_rate * 100))

# Calculate excess returns for all stocks
excess_returns <- list()
for (symbol in sp500_data$symbols) {
  excess_returns[[symbol]] <- calculate_excess_returns(
    sp500_data$stock_returns[[symbol]], 
    CONFIG$risk_free_rate
  )
}

# Calculate market excess returns
market_excess_returns <- calculate_excess_returns(
  sp500_data$market_returns, 
  CONFIG$risk_free_rate
)

cat(sprintf("✓ Calculated excess returns for %d stocks\n", length(excess_returns)))
cat(sprintf("✓ Market excess returns calculated\n\n"))

# =============================================================================
# STEP 4: CALCULATE ROLLING BETAS
# =============================================================================

cat("Step 4: Calculating rolling betas...\n")
cat(sprintf("Rolling window: %d months\n", CONFIG$beta_window))

# Calculate rolling betas for all stocks
rolling_betas <- list()
beta_calculation_success <- 0

for (symbol in sp500_data$symbols) {
  cat(sprintf("Calculating beta for %s... ", symbol))
  
  tryCatch({
    beta_series <- calculate_rolling_beta(
      excess_returns[[symbol]],
      market_excess_returns,
      window = CONFIG$beta_window
    )
    
    if (!all(is.na(beta_series))) {
      rolling_betas[[symbol]] <- beta_series
      beta_calculation_success <- beta_calculation_success + 1
      cat("✓\n")
    } else {
      cat("✗ (all NA)\n")
    }
  }, error = function(e) {
    cat(sprintf("✗ (error: %s)\n", e$message))
  })
}

cat(sprintf("✓ Successfully calculated betas for %d stocks\n\n", beta_calculation_success))

# Save beta data
saveRDS(rolling_betas, "data/rolling_betas.rds")

# =============================================================================
# STEP 5: SORT INTO BETA QUINTILES
# =============================================================================

cat("Step 5: Sorting stocks into beta quintiles...\n")

# Get all dates where we have sufficient beta data
all_dates <- Reduce(intersect, lapply(rolling_betas, function(x) as.character(index(na.omit(x)))))
all_dates <- sort(all_dates)

cat(sprintf("Analysis period: %s to %s\n", min(all_dates), max(all_dates)))
cat(sprintf("Number of rebalancing dates: %d\n", length(all_dates)))

# Sort stocks into quintiles for each date
quintile_assignments <- list()
successful_sorts <- 0

for (date in all_dates) {
  quintiles <- sort_into_quintiles(rolling_betas, date)
  if (!is.null(quintiles)) {
    quintile_assignments[[date]] <- quintiles
    successful_sorts <- successful_sorts + 1
  }
}

cat(sprintf("✓ Successfully sorted stocks for %d dates\n", successful_sorts))

# Display sample quintile composition
if (length(quintile_assignments) > 0) {
  sample_date <- names(quintile_assignments)[length(quintile_assignments)]
  sample_quintiles <- quintile_assignments[[sample_date]]
  
  cat(sprintf("\nSample quintile composition for %s:\n", sample_date))
  for (q in names(sample_quintiles)) {
    cat(sprintf("  %s: %d stocks (%s)\n", 
                q, length(sample_quintiles[[q]]), 
                paste(head(sample_quintiles[[q]], 3), collapse = ", ")))
  }
}

cat("\n")

# =============================================================================
# STEP 6: CONSTRUCT BAB STRATEGY
# =============================================================================

cat("Step 6: Constructing Betting-Against-Beta strategy...\n")
cat("Strategy: Long low-beta (Q1), Short high-beta (Q5), Market-neutral\n")
cat(sprintf("Leverage: %.1fx\n", CONFIG$leverage))

# Calculate BAB strategy returns
bab_returns <- calculate_bab_returns(
  excess_returns,
  quintile_assignments,
  leverage = CONFIG$leverage
)

# Remove NA values and get clean return series
bab_returns <- na.omit(bab_returns)

cat(sprintf("✓ BAB strategy constructed\n"))
cat(sprintf("✓ Strategy returns calculated for %d periods\n", nrow(bab_returns)))
cat(sprintf("   From %s to %s\n", min(index(bab_returns)), max(index(bab_returns))))

# Save strategy returns
saveRDS(bab_returns, "data/bab_strategy_returns.rds")

# =============================================================================
# STEP 7: PERFORMANCE EVALUATION
# =============================================================================

cat("\nStep 7: Evaluating strategy performance...\n")

# Calculate performance statistics
performance_stats <- calculate_performance_stats(bab_returns, market_excess_returns)

if (!is.null(performance_stats)) {
  cat("\n=================================================================\n")
  cat("BETTING-AGAINST-BETA STRATEGY PERFORMANCE RESULTS\n")
  cat("=================================================================\n")
  
  # Basic performance metrics
  cat(sprintf("Total Return:           %+.2f%%\n", performance_stats$total_return * 100))
  cat(sprintf("Annualized Return:      %+.2f%%\n", performance_stats$annualized_return * 100))
  cat(sprintf("Annualized Volatility:  %.2f%%\n", performance_stats$annualized_volatility * 100))
  cat(sprintf("Sharpe Ratio:           %.2f\n", performance_stats$sharpe_ratio))
  cat(sprintf("Maximum Drawdown:       %.2f%%\n", performance_stats$max_drawdown * 100))
  cat(sprintf("Number of Observations: %d\n", performance_stats$n_observations))
  
  # Alpha statistics (if available)
  if (!is.null(performance_stats$alpha_stats)) {
    alpha_stats <- performance_stats$alpha_stats
    cat("\n--- CAPM Alpha Analysis (with Newey-West standard errors) ---\n")
    cat(sprintf("Alpha (monthly):        %+.4f (%.2f%%)\n", 
                alpha_stats$alpha, alpha_stats$alpha * 100))
    cat(sprintf("Alpha (annualized):     %+.2f%%\n", alpha_stats$alpha * 12 * 100))
    cat(sprintf("Alpha t-statistic:      %.2f\n", alpha_stats$alpha_tstat))
    cat(sprintf("Alpha p-value:          %.4f %s\n", 
                alpha_stats$alpha_pvalue,
                ifelse(alpha_stats$alpha_pvalue < 0.05, "**", 
                       ifelse(alpha_stats$alpha_pvalue < 0.10, "*", ""))))
    cat(sprintf("Market Beta:            %.2f\n", alpha_stats$beta))
    cat(sprintf("R-squared:              %.2f%%\n", alpha_stats$r_squared * 100))
  }
  
  cat("=================================================================\n\n")
} else {
  cat("✗ Could not calculate performance statistics\n\n")
}

# =============================================================================
# STEP 8: VISUALIZATION
# =============================================================================

cat("Step 8: Creating visualizations...\n")

# Calculate cumulative returns
bab_cumulative <- cumprod(1 + bab_returns)
market_cumulative <- cumprod(1 + na.omit(market_excess_returns))

# Align dates for comparison
aligned_data <- merge(bab_cumulative, market_cumulative, join = "inner")
colnames(aligned_data) <- c("BAB_Strategy", "Market_Excess")

# Create data frame for plotting
plot_data <- data.frame(
  Date = index(aligned_data),
  BAB_Strategy = as.numeric(aligned_data$BAB_Strategy),
  Market_Excess = as.numeric(aligned_data$Market_Excess)
) %>%
  tidyr::pivot_longer(cols = c("BAB_Strategy", "Market_Excess"), 
                     names_to = "Strategy", values_to = "Cumulative_Return")

# Create cumulative returns plot
p1 <- ggplot(plot_data, aes(x = Date, y = Cumulative_Return, color = Strategy)) +
  geom_line(linewidth = 1) +
  scale_color_manual(values = c("BAB_Strategy" = "#2E86AB", "Market_Excess" = "#A23B72"),
                     labels = c("BAB Strategy", "Market (Excess Returns)")) +
  scale_y_continuous(labels = scales::percent_format(scale = 100, accuracy = 1)) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
  labs(
    title = "Betting-Against-Beta Strategy vs Market",
    subtitle = "Cumulative Returns Comparison",
    x = "Date",
    y = "Cumulative Return",
    caption = paste0("Analysis Period: ", min(plot_data$Date), " to ", max(plot_data$Date))
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 12),
    legend.title = element_blank(),
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank()
  )

# Save plot
ggsave("plots/bab_cumulative_returns.png", p1, width = 12, height = 8, dpi = 300)

# Create rolling returns plot
plot_data_rolling <- data.frame(
  Date = index(aligned_data),
  BAB_Strategy = as.numeric(aligned_data$BAB_Strategy),
  Market_Excess = as.numeric(aligned_data$Market_Excess)
)

p2 <- ggplot(plot_data_rolling) +
  geom_line(aes(x = Date, y = BAB_Strategy), color = "#2E86AB", linewidth = 1, alpha = 0.8) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
  scale_y_continuous(labels = scales::percent_format(scale = 100, accuracy = 10)) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
  labs(
    title = "Betting-Against-Beta Strategy Performance",
    subtitle = "Cumulative Returns Over Time",
    x = "Date",
    y = "Cumulative Return",
    caption = paste0("Starting Value: $1.00 | Analysis Period: ", 
                    min(plot_data_rolling$Date), " to ", max(plot_data_rolling$Date))
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 12),
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank()
  )

ggsave("plots/bab_strategy_performance.png", p2, width = 12, height = 8, dpi = 300)

cat("✓ Visualizations saved to plots/ directory\n")
cat("  - bab_cumulative_returns.png: Strategy vs Market comparison\n")
cat("  - bab_strategy_performance.png: BAB strategy performance\n\n")

# =============================================================================
# STEP 9: SUMMARY AND CONCLUSIONS
# =============================================================================

cat("=================================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("=================================================================\n")

if (!is.null(performance_stats)) {
  cat("\nKey Findings:\n")
  
  # Interpret results
  if (!is.null(performance_stats$alpha_stats)) {
    alpha_annual <- performance_stats$alpha_stats$alpha * 12
    if (alpha_annual > 0 && performance_stats$alpha_stats$alpha_pvalue < 0.05) {
      cat(sprintf("✓ Strategy shows significant positive alpha: +%.2f%% annually\n", 
                  alpha_annual * 100))
    } else if (alpha_annual > 0) {
      cat(sprintf("○ Strategy shows positive but not significant alpha: +%.2f%% annually\n", 
                  alpha_annual * 100))
    } else {
      cat(sprintf("✗ Strategy shows negative alpha: %.2f%% annually\n", 
                  alpha_annual * 100))
    }
  }
  
  if (performance_stats$sharpe_ratio > 0.5) {
    cat(sprintf("✓ Good risk-adjusted returns: Sharpe ratio = %.2f\n", 
                performance_stats$sharpe_ratio))
  } else {
    cat(sprintf("○ Moderate risk-adjusted returns: Sharpe ratio = %.2f\n", 
                performance_stats$sharpe_ratio))
  }
  
  if (performance_stats$max_drawdown < 0.20) {
    cat(sprintf("✓ Reasonable drawdown: %.1f%%\n", 
                performance_stats$max_drawdown * 100))
  } else {
    cat(sprintf("⚠ High drawdown: %.1f%%\n", 
                performance_stats$max_drawdown * 100))
  }
}

cat("\nFiles created:\n")
cat("  - data/sp500_raw_data.rds: Raw stock and market data\n")
cat("  - data/rolling_betas.rds: Rolling beta calculations\n")
cat("  - data/bab_strategy_returns.rds: BAB strategy returns\n")
cat("  - plots/bab_cumulative_returns.png: Performance comparison plot\n")
cat("  - plots/bab_strategy_performance.png: Strategy performance plot\n")

cat("\nReplication of Frazzini & Pedersen (2014) Betting-Against-Beta strategy complete!\n")
cat("=================================================================\n")
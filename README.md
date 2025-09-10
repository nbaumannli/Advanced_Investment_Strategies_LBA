# Betting-Against-Beta Strategy Implementation

## Overview

This project replicates the **Betting-Against-Beta (BAB)** strategy from Frazzini & Pedersen (2014), which exploits the low-beta anomaly in equity markets. The strategy constructs a market-neutral portfolio that is long low-beta stocks and short high-beta stocks.

## Research Background

The low-beta anomaly is a well-documented market inefficiency where low-beta stocks tend to outperform high-beta stocks on a risk-adjusted basis. Frazzini & Pedersen (2014) propose the BAB strategy to systematically capture this anomaly.

**Key Reference:**
- Frazzini, A., & Pedersen, L. H. (2014). Betting against beta. *Journal of Financial Economics*, 111(1), 1-25.

## Strategy Description

The Betting-Against-Beta strategy:

1. **Universe**: S&P 500 stocks
2. **Beta Calculation**: Rolling 36-month beta vs market
3. **Sorting**: Monthly quintile sorting based on beta
4. **Portfolio Construction**: 
   - Long position in low-beta quintile (Q1)
   - Short position in high-beta quintile (Q5)
   - Market-neutral (dollar-neutral) portfolio
5. **Rebalancing**: Monthly
6. **Performance Evaluation**: Alpha, Sharpe ratio, and statistical significance using Newey-West standard errors

## Project Structure

```
Advanced_Investment_Strategies_LBA/
├── README.md                 # This documentation
├── main.R                    # Main analysis script
├── functions.R               # Helper functions
├── requirements.R            # Package installation script
├── .gitignore               # Git ignore file for R projects
├── data/                    # Data outputs (created when running)
│   ├── sp500_raw_data.rds   # Raw stock and market data
│   ├── rolling_betas.rds    # Rolling beta calculations
│   └── bab_strategy_returns.rds # BAB strategy returns
└── plots/                   # Visualization outputs (created when running)
    ├── bab_cumulative_returns.png # Strategy vs market comparison
    └── bab_strategy_performance.png # BAB strategy performance
```

## Installation and Setup

### Prerequisites

- R (version 4.0 or higher)
- Internet connection for data download

### Required R Packages

The following packages will be automatically installed when you run the analysis:

- `quantmod` - Financial data retrieval
- `tidyquant` - Tidy financial analysis  
- `xts`, `zoo` - Time series handling
- `dplyr`, `tidyr` - Data manipulation
- `ggplot2`, `scales` - Visualization
- `PerformanceAnalytics` - Performance metrics
- `sandwich`, `lmtest` - Robust standard errors (Newey-West)
- `lubridate` - Date handling

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/nbaumannli/Advanced_Investment_Strategies_LBA.git
   cd Advanced_Investment_Strategies_LBA
   ```

2. **Run the complete analysis:**
   ```r
   # Open R or RStudio and run:
   source("main.R")
   ```

   The script will automatically:
   - Install required packages
   - Download S&P 500 data
   - Calculate rolling betas
   - Construct the BAB strategy
   - Evaluate performance
   - Generate visualizations

## Usage

### Full Analysis (Recommended)

```r
# Run the complete BAB strategy analysis
source("main.R")
```

### Step-by-Step Execution

```r
# 1. Install packages
source("requirements.R")

# 2. Load functions
source("functions.R")

# 3. Download data (customize parameters as needed)
sp500_data <- download_sp500_data(
  start_date = "2005-01-01",
  end_date = "2023-12-31",
  max_stocks = 50  # Remove for full S&P 500
)

# 4. Calculate rolling betas
rolling_betas <- list()
for (symbol in sp500_data$symbols) {
  rolling_betas[[symbol]] <- calculate_rolling_beta(
    sp500_data$stock_returns[[symbol]],
    sp500_data$market_returns,
    window = 36
  )
}

# 5. Construct and evaluate strategy
# See main.R for complete implementation
```

### Customization

Edit the configuration section in `main.R`:

```r
CONFIG <- list(
  start_date = "2005-01-01",      # Analysis start date
  end_date = "2023-12-31",        # Analysis end date
  beta_window = 36,               # Rolling beta window (months)
  max_stocks = 50,                # Max stocks (NULL for full S&P 500)
  risk_free_rate = 0.02,          # Annual risk-free rate
  leverage = 1.0,                 # Strategy leverage
  rebalance_freq = "monthly"      # Rebalancing frequency
)
```

## Output

### Performance Metrics

The analysis provides:

- **Total and annualized returns**
- **Volatility and Sharpe ratio**
- **Maximum drawdown**
- **CAPM alpha with Newey-West standard errors**
- **Statistical significance tests**

### Visualizations

1. **Cumulative Returns Comparison**: BAB strategy vs market
2. **Strategy Performance**: Standalone BAB performance over time

### Data Files

All intermediate results are saved for further analysis:

- Raw stock data and market returns
- Rolling beta calculations
- Strategy returns time series

## Key Features

- ✅ **Complete Implementation**: Full replication of Frazzini & Pedersen (2014)
- ✅ **Robust Statistics**: Newey-West standard errors for proper inference
- ✅ **Clean Code**: Well-documented, modular functions
- ✅ **Flexible Configuration**: Easy to modify parameters and extend
- ✅ **Comprehensive Output**: Performance metrics, plots, and data exports
- ✅ **Error Handling**: Robust data download and calculation procedures

## Performance Expectations

Based on academic literature, the BAB strategy typically exhibits:

- **Positive alpha**: Outperformance vs market on risk-adjusted basis
- **Moderate volatility**: Generally lower than market volatility
- **Steady returns**: Less volatile than individual stocks
- **Market-neutral**: Low correlation with market movements

## Limitations and Considerations

1. **Transaction Costs**: Not included in this implementation
2. **Market Impact**: Large-scale implementation may affect prices
3. **Survivorship Bias**: Historical S&P 500 composition may introduce bias
4. **Short Selling**: Assumes ability to short sell high-beta stocks
5. **Data Limitations**: Yahoo Finance data quality and availability

## Extensions and Future Work

Potential enhancements:

- Include transaction costs and market impact
- Test alternative beta estimation methods
- Implement risk management overlays
- Add sector-neutral constraints
- Test in international markets
- Implement real-time portfolio monitoring

## References

1. Frazzini, A., & Pedersen, L. H. (2014). Betting against beta. *Journal of Financial Economics*, 111(1), 1-25.
2. Black, F., Jensen, M. C., & Scholes, M. (1972). The capital asset pricing model: Some empirical tests. *Studies in the theory of capital markets*, 79-121.
3. Baker, M., Bradley, B., & Wurgler, J. (2011). Benchmarks as limits to arbitrage: Understanding the low-volatility anomaly. *Financial Analysts Journal*, 67(1), 40-54.

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is for educational and research purposes. Please cite appropriately if used in academic work.

---

**Author**: Advanced Investment Strategies LBA  
**Created**: 2024  
**R Version**: 4.3.3  
**Last Updated**: 2024

# R Package Requirements for Betting-Against-Beta Strategy
# Install required packages for the BAB strategy implementation

# Check if packages are installed, install if not
required_packages <- c(
  "dplyr",           # Data manipulation (pre-installed)
  "tidyr",           # Data tidying (pre-installed)
  "ggplot2",         # Plotting (pre-installed)
  "scales",          # Plot scaling (pre-installed)
  "lubridate",       # Date manipulation (pre-installed)
  "readr",           # Data reading (pre-installed)
  "tibble"           # Modern data frames (pre-installed)
)

# Additional packages that need to be installed from CRAN
financial_packages <- c(
  "quantmod",        # Financial data retrieval
  "tidyquant",       # Tidy financial analysis
  "xts",             # Time series objects
  "zoo",             # Time series infrastructure
  "PerformanceAnalytics", # Performance and risk analytics
  "sandwich",        # Robust covariance matrix estimators (Newey-West)
  "lmtest"           # Linear model testing
)

# Function to install packages if not available
install_if_missing <- function(packages, use_sudo = FALSE) {
  for (pkg in packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      cat("Installing package:", pkg, "\n")
      tryCatch({
        if (use_sudo) {
          system(paste0("sudo R --slave -e \"install.packages('", pkg, "', repos='https://cran.r-project.org/', dependencies=TRUE)\""))
        } else {
          install.packages(pkg, dependencies = TRUE, repos = "https://cran.r-project.org/")
        }
        library(pkg, character.only = TRUE)
        cat("✓ Successfully installed", pkg, "\n")
      }, error = function(e) {
        cat("✗ Failed to install", pkg, ":", e$message, "\n")
        cat("  Note: You may need to install this package manually\n")
      })
    } else {
      cat("✓ Package", pkg, "already available\n")
    }
  }
}

# Install basic packages (should already be available)
cat("Checking basic packages...\n")
install_if_missing(required_packages)

cat("\nChecking financial packages...\n")
cat("Note: Some packages may require manual installation if automatic installation fails\n")
install_if_missing(financial_packages, use_sudo = TRUE)

cat("\nPackage installation complete!\n")
cat("If any packages failed to install, you can install them manually:\n")
cat("  sudo R -e \"install.packages('PACKAGE_NAME', repos='https://cran.r-project.org/')\"\n")
cat("\nYou can now run the main analysis script or the test script.\n")
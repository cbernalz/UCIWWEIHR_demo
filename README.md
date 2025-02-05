# UCIWWEIHR_demo Repo :
Demonstrates the UCIWWEIHR package on a real data application.  Package site is
[here](https://cbernalz.github.io/UCIWWEIHR.jl/dev/).  Package GitHub is 
[here](https://github.com/cbernalz/UCIWWEIHR.jl/tree/master).  The package is 
still in development!!!

`testfile.jl` file in the `jl` folder is the main file that demonstrates the 
UCIWWEIHR package.  

`data` folder contains data pulled, inputs of the model.

`results` that contains the results of the demo.  This has raw model output and 
formatted output.  Forecast object that only has desired forecasted dates is in 
the [forecast-obj-forecast-only csv](/results/forecast-obj-forecast-only.csv).
Nowcast object that only has desired weekly Rt's is in the [nowcast-obj-wo-init-rt csv](/results/nowcast-obj-wo-init-rt.csv).

`plots` folder contains plots of the model output.

`data-pull.r` file in the `r` folder is the file that pulls the data from the
below sites.

# Data :
Data is attained from the [California Data Portal](https://data.ca.gov/) or the
[Cal HHS website](https://data.chhs.ca.gov/).

# Instructions :
### 1. Data pull :
To pull the data, run the `data-pull.r` script in the `r` folder.  This script can be run in R-studio, vscode, and the terminal.  For vscode, open the folder in vscode and run the script.  For R-studio, open the script in R-studio and run the script.  For a terminal, open a terminal and be in the repo's root directory.  Then run the following commands in the terminal : `Rscript r/data-pull.r`.  This saves pulled data into the `data` folder.

### 2. Julia setup :
In a julia REPL, run the following commands to install package and this repo's dependencies:
```julia
using Pkg
Pkg.add(["DataFrames", "CSV", "Dates", "LogExpFunctions", "ArgParse", "FilePathsBase"])
Pkg.add(url="https://github.com/cbernalz/UCIWWEIHR.jl.git")
```
### 3. Running [testfile](jl/testfile.jl) script :
This script can be run in a terminal.  For a terminal, open a terminal and be in repo's root directory.  Then run the following commands in the terminal : `julia jl/testfile.jl --help` to understand the arguments that go into the script from the terminal.  Specifying all arguments is not necessary, but if desired will be of the form, 

`julia jl/testfile.jl --hosp_df_path "data/hosp-data.csv" --ww_df_path "data/ww-data.csv" --result_path "results/" --plot_result_path "plots/" --county "Los Angeles" --n_samples 250 --forecast_horizon 7 --start_date "2024-07-21" --end_date "2024-09-22" --verbose`.  *This was run to produce results and plots repo currently*

A more condensed version, if only specifying required arguments will be of the form, 

`julia jl/testfile.jl --hosp_df_path "data/hosp-data.csv" --ww_df_path "data/ww-data.csv" --result_path "results/" --county "Los Angeles" --n_samples 250`

In this simple version, only result df's will be saved and plots are not.

---
# Created by : The Minin Group

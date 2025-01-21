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
Pkg.add(["DataFrames", "CSV", "Dates", "LogExpFunctions"])
Pkg.add(url="https://github.com/cbernalz/UCIWWEIHR.jl.git")
```
### 3. Running [testfile](jl/testfile.jl) script :
This script can be run in vscode or using a terminal.  For vscode, open the folder in vscode and run the script.  For a terminal, open a terminal and be in repo's root directory.  Then run the following commands in the terminal : `julia jl/testfile.jl`.

---
# Created by : The Minin Group

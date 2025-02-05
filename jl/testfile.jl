using DataFrames, CSV, Dates, LogExpFunctions, ArgParse, FilePathsBase, UCIWWEIHR ## Packages required *UCIWEIHR is Model*

function prep_hosp_df(
    df::DataFrame, 
    county::String, 
    start_date=nothing, 
    end_date=nothing
)
    #### Function to prepare hospital data pulled from data_pull_wrap()

    ## Prelims - ensuring a start and end date, if none provided, will use the min and max dates in the df
    start_date = start_date === nothing ? minimum(df[!, "date"]) : Date(start_date)
    end_date = end_date === nothing ? maximum(df[!, "date"]) : Date(end_date)

    ## Filter df by start date, end date, and county
    filter!(row -> row.county == county, df)
    filter!(row -> row.date >= start_date, df)
    filter!(row -> row.date <= end_date, df)
    
    ## Making obstimes column - model requires obstimes to be integers starting from 1
    ## this portion does this by looking at the dates and assigning an integer to each date
    date_seq = start_date:Day(1):end_date
    date_to_obstime = Dict(d => findfirst(==(d), date_seq) for d in date_seq)
    df[!, :obstimes_hosp] .= [date_to_obstime[d] for d in df.date]

    ## Summing hosps accross duplicate dates - for some counties, hosp data pulled from data.ca.gov has multiple observations per day
    df = combine(
        groupby(df, [:obstimes_hosp, :date]), 
        :hospitalized_covid_patients => sum
    )
    rename!(df, :hospitalized_covid_patients_sum => :hospitalizations)

    ## Sort by date
    sort!(df, :date)

    return df
end

function prep_ww_df(
    df::DataFrame,
    county::String,
    start_date=nothing,
    end_date=nothing
)
    # Prelims
    start_date = start_date === nothing ? minimum(df[!, "date"]) : Date(start_date)
    end_date = end_date === nothing ? maximum(df[!, "date"]) : Date(end_date)

    # Filter df
    df[!,:date] = Date.(df.date, "yyyy-mm-ddTHH:MM:SSZ")
    filter!(row -> row.county == county, df)
    filter!(row -> row.date >= start_date, df)
    filter!(row -> row.date <= end_date, df)

    # Making obstimes column
    date_seq = start_date:Day(1):end_date
    date_to_obstime = Dict(d => findfirst(==(d), date_seq) for d in date_seq)
    df[!, :obstimes_wastewater] .= [date_to_obstime[d] for d in df.date]

    # Sort by date
    sort!(df, :date)

    return df
    
end

function init_param_fnx(
    prepped_hosp_df::DataFrame,
)
    #### Function to get initial ODE conditions for the model
    ## Ensure prepped_hosp_df is of desired time periods and already passed through prep_hosp_df function!!!

    ## Taking initial day
    init_hosp_df = first(prepped_hosp_df, 1)

    ## Getting initial values
    H_init = init_hosp_df.hospitalizations[1]
    I_init = ((H_init / 1.5) * 5) / 4
    E_init = ((H_init / 1.5) * 5) - I_init

    return (
        log_E_init_mean=log(E_init), 
        log_I_init_mean=log(I_init), 
        log_H_init_mean=log(H_init)
    )
    
end

function format_for_eval(df, desired_var::String)
    #### Function to format model output for desired subsetting and evaluation

    ## Subset model output to only include columns with desired_var in the name
    df_col_names = names(df)
    target_df_col_names = [x for x in df_col_names if occursin(desired_var, x)]
    target_df = df[:, [target_df_col_names...]]
    if length(names(target_df)) == 0
        println("No columns found with $desired_var in the name")
        return DataFrame()
    end
    return target_df
end

function parse_commandline()
    ## Function to parse commandline arguments
    s = ArgParseSettings()

    @add_arg_table s begin
        "--hosp_df_path"
            help="Path to the hospital data file"
            required=true
        "--ww_df_path"
            help="Path to the wastewater data file"
            required=true
        "--result_path"
            help="Path to save the results"
            required=true
        "--plot_result_path"
            help="Path to save the plots, if not provided, plots are not displayed"
            default=nothing
        "--county"
            help="County to analyze"
            required=true
        "--n_samples"
            help="Number of samples to draw from the posterior"
            arg_type=Int
            default=50
        "--forecast_horizon"
            help="Number of days to forecast"
            arg_type=Int
            default=7
        "--start_date"
            help="Start date for the analysis"
            default=nothing
        "--end_date"
            help="End date for the analysis"
            default=nothing
        "--verbose"
            help="Show detailed output"
            action="store_true"
    end

    return parse_args(s)
end

function main()

    # Setting up argument parser for commandline arguments
    parsed_args = parse_commandline()



    ## Setting up the arguments
    hosp_df_path = parsed_args["hosp_df_path"]
    ww_df_path = parsed_args["ww_df_path"]
    result_path = parsed_args["result_path"]
    plot_result_path = parsed_args["plot_result_path"]
    county = parsed_args["county"]
    n_samples = parsed_args["n_samples"]
    forecast_horizon = parsed_args["forecast_horizon"]
    start_date = parsed_args["start_date"]
    end_date = parsed_args["end_date"]
    verbose = parsed_args["verbose"]

    ## verbose output
    if verbose
        println("---------------------------------------------------------------")
        println("Displaying preset arguments...")
        println("--hosp_df_path: $hosp_df_path")
        println("--ww_df_path: $ww_df_path")
        println("--result_path: $result_path")
        println("--plot_result_path: $plot_result_path")
        println("--county: $county")
        println("--n_samples: $n_samples")
        println("--forecast_horizon: $forecast_horizon")
        println("--start_date: $start_date")
        println("--end_date: $end_date")
        println("If nothing set in start_date and end_date, the model will use the min and max dates in the data")
        println("If nothing set in plot_result_path, plots will not be displayed")
        println("---------------------------------------------------------------")
    end

    # Ensuring the result path exists and creating it if it doesn't
    if !isdir(result_path)
        mkpath(result_path)
    end
    # Ensuring the plot result path exists and creating it if it doesn't
    if plot_result_path !== nothing
        if !isdir(plot_result_path)
            mkpath(plot_result_path)
        end
    end

    # Running the model
    println("-------------------------BEGINNING PROCESS-------------------------")

    # Read in the data
    println("Reading in data...")
    hosp_df = CSV.read(
        hosp_df_path,
        DataFrame
    )
    hosp_df[!, :hospitalized_covid_patients] .= tryparse.(Int, hosp_df.hospitalized_covid_patients) # Convert hosp to Int
    ww_df = CSV.read(
        ww_df_path,
        DataFrame
    )

    # Prep the data using given start date and end date
    println("Prepping data...")
    #start_date = "2024-07-21" 
    #end_date = "2024-09-22" ## Last observed date
    #county = "Los Angeles"
    prepped_hosp_df = prep_hosp_df(hosp_df, county, start_date, end_date)
    last_observed_date = maximum(prepped_hosp_df.date)
    if end_date === nothing 
        # Check for ensurance that prepped_hosp_df last date is used if nothing is provided to end_date
        end_date = last_observed_date
        println("End date not provided, using last observed date in hosp data: $end_date")
    end
    prepped_ww_df = prep_ww_df(ww_df, county, start_date, end_date)


    # Setting parameters for function
    println("Setting function parameters...")
    priors_only = false
    n_discard_initial = n_samples / 2
    n_discard_initial = floor(Int, n_discard_initial)
    forecast = true
    data_hosp = prepped_hosp_df.hospitalizations
    data_wastewater = prepped_ww_df.log_conc
    obstimes_hosp = prepped_hosp_df.obstimes_hosp
    obstimes_wastewater = prepped_ww_df.obstimes_wastewater
    max_obstime = max(length(obstimes_hosp), length(obstimes_wastewater))
    param_change_times = 1:7:max_obstime

    # Setting model parameters
    println("Setting model parameters...")
    ## run init conds for comps
    init_params = init_param_fnx(prepped_hosp_df)
    model_params = create_uciwweihr_model_params2(
        E_init_sd=0.2, log_E_init_mean=init_params.log_E_init_mean,
        I_init_sd=0.2, log_I_init_mean=init_params.log_I_init_mean,
        H_init_sd=0.2, log_H_init_mean=init_params.log_H_init_mean,
        gamma_sd=0.04, log_gamma_mean=log(1/2),
        nu_sd=0.04, log_nu_mean=log(1/6),
        epsilon_sd=0.04, log_epsilon_mean=log(1/5),
        rho_gene_sd=1.0, log_rho_gene_mean=log(1),
        sigma_ww_sd=0.05, log_sigma_ww_mean=log(0.44),
        sigma_hosp_sd=43.0, sigma_hosp_mean=130.0,
        Rt_init_sd=0.1, Rt_init_mean=log(1.1),
        sigma_Rt_sd=0.2, sigma_Rt_mean=-3.0,
        w_init_sd=0.5, w_init_mean=logit(0.03),
        sigma_w_sd=0.2, sigma_w_mean=-3.5
    )

    # Optimizing initial parameters
    println("Optimizing initial model parameters...")
    init_params = optimize_many_MAP2_wrapper(
        data_hosp,
        data_wastewater,
        obstimes_hosp,
        obstimes_wastewater,
        param_change_times,
        model_params;
        verbose=false
    )

    # Running the model
    ## fitting and getting samples
    println("Running the model...")
    samples = uciwweihr_fit(
        data_hosp,
        data_wastewater,
        obstimes_hosp,
        obstimes_wastewater,
        param_change_times,
        model_params;
        priors_only,
        n_samples,
        n_discard_initial=n_discard_initial,
        #init_params = init_params
    )
    ## generating quantities and posterior predictive for forecasting
    println("Generating quantities and posterior predictive...")
    model_output = uciwweihr_gq_pp(
        samples,
        data_hosp,
        data_wastewater,
        obstimes_hosp,
        obstimes_wastewater,
        param_change_times,
        model_params;
        forecast=forecast,
        forecast_days = forecast_horizon
    )

    # Saving raw model output
    println("Saving raw model output...")
    ## Posterior Predictive
    CSV.write(
        joinpath(result_path, "model-output-pp.csv"),
        model_output[1]
    )
    ## Generated Quantities
    CSV.write(
        joinpath(result_path, "model-output-gq.csv"),
        model_output[2]
    )
    ## Samples
    CSV.write(
        joinpath(result_path, "model-output-samples.csv"),
        model_output[3]
    )

    ## Formatting forecast object
    println("Formatting forecast object...")
    forecast_obj_full = format_for_eval(model_output[1], "data_hosp")
    forecast_obstime_start = obstimes_hosp[end] + 1
    forecast_obstime_end = forecast_obstime_start + forecast_horizon - 1
    forecast_obj_forecast_only = forecast_obj_full[!, forecast_obstime_start:forecast_obstime_end]
    # Saving forecast object
    println("Saving forecast object...")
    CSV.write(
        joinpath(result_path, "forecast-obj-full.csv"),
        forecast_obj_full
    )
    CSV.write(
        joinpath(result_path, "forecast-obj-forecast-only.csv"),
        forecast_obj_forecast_only
    )

    ## Formatting nowcast object
    println("Formatting nowcast object...")
    nowcast_obj_full = format_for_eval(model_output[2], "rt_vals")
    nowcast_obj_wo_init_rt = nowcast_obj_full[:, 2:end]
    # Saving nowcast object
    println("Saving nowcast object...")
    CSV.write(
        joinpath(result_path, "nowcast-obj-full.csv"),
        nowcast_obj_full
    )
    CSV.write(
        joinpath(result_path, "nowcast-obj-wo-init-rt.csv"),
        nowcast_obj_wo_init_rt
    )

    ## Using visualizer to see quick plots

    if plot_result_path !== nothing
        println("Using visualizer to see quick plots...")
        uciwweihr_visualizer(
            data_hosp,  
            data_wastewater,
            forecast_horizon,
            obstimes_hosp,
            obstimes_wastewater,
            param_change_times,
            2024,
            forecast,
            model_params;
            pp_samples = model_output[1],
            gq_samples = model_output[2],
            obs_data_hosp = data_hosp,
            obs_data_wastewater = data_wastewater, 
            save_plots = true,
            plot_name_to_save_mcmcdiag = plot_result_path * "diagnosis-trace",
            plot_name_to_save_time_varying = plot_result_path * "time-varying-parameters",
            plot_name_to_save_non_time_varying = plot_result_path * "nontime-varying-parameters",
            plot_name_to_save_ode_sol = plot_result_path * "ode-solution",
            plot_name_to_save_pred_param = plot_result_path * "post-pred"
        )
    end

    # Done
    println("-------------------------PROCESS COMPLETED-------------------------")

end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end

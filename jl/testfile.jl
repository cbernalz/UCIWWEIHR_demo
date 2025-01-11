using RCall, DataFrames, CSV, Dates

function data_pull_wrap()
    R"source('r/data-pull.r')"
end

function prep_hosp_df(
    df::DataFrame, 
    county::String, 
    start_date=nothing, 
    end_date=nothing
)
    # Prelims
    start_date = start_date === nothing ? minimum(df[!, "date"]) : Date(start_date)
    end_date = end_date === nothing ? maximum(df[!, "date"]) : Date(end_date)

    # Filter df
    filter!(row -> row.county == county, df)
    filter!(row -> row.date >= start_date, df)
    filter!(row -> row.date <= end_date, df)
    
    # Making obstimes column
    date_seq = start_date:Day(1):end_date
    date_to_obstime = Dict(d => findfirst(==(d), date_seq) for d in date_seq)
    df[!, :obstimes_hosp] .= [date_to_obstime[d] for d in df.date]

    # Summing hosps accross duplicate dates
    df[!, :hospitalized_covid_patients] .= convert.(Int, df.hospitalized_covid_patients)
    df = combine(
        groupby(df, [:obstimes_hosp, :date]), 
        :hospitalized_covid_patients => sum
    )
    rename!(df, :hospitalized_covid_patients_sum => :hospitalizations)

    # Sort by date
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
    df[!, :obstimes_ww] .= [date_to_obstime[d] for d in df.date]

    # Sort by date
    sort!(df, :date)

    return df
    
end

function init_param_fnx(
    cases_df::DataFrame,
    hosp_df::DataFrame,
    county::String,
    start_date=nothing,
    end_date=nothing
)
    # Prelims
    start_date = start_date === nothing ? minimum(cases_df[!, "date"]) : Date(start_date)
    end_date = end_date === nothing ? maximum(cases_df[!, "date"]) : Date(end_date)
    prepped_hosp_df = prep_hosp_df(hosp_df, county, start_date, end_date)

    # Filter df
    #filter!(row -> row.county == county, cases_df)
    filter!(row -> row.date >= start_date, cases_df)
    filter!(row -> row.date <= end_date, cases_df)

    # Sort by date
    sort!(cases_df, :date)

    # Taking initial day
    init_case_df = first(cases_df, 1)
    init_hosp_df = first(prepped_hosp_df, 1)

    # Getting initial values
    H_init = init_hosp_df.hospitalizations[1]
    I_init = (init_case_df.cases[1] * 5) / 4
    E_init = (init_case_df.cases[1] * 5) - I_init
    

    return (
        #log_E_init_mean=log(E_init), 
        #log_I_init_mean=log(I_init), 
        #log_H_init_mean=log(H_init)
        E_init_mean=E_init,
        I_init_mean=I_init,
        H_init_mean=H_init
    )
    
end

function main()
    # Data pull - using R
    #println("Pulling data...")
    #data_pull_wrap()

    # Read in the data
    println("Reading in data...")
    hosp_df = CSV.read(
        "data/hosp-data.csv",
        DataFrame
    )
    ww_df = CSV.read(
        "data/ww-data.csv",
        DataFrame
    )
    case_df = CSV.read(
        "data/case-data.csv",
        DataFrame
    )

    # Prep the data
    println("Prepping data...")
    start_date = "2024-07-21"
    end_date = "2024-09-22"
    county = "Los Angeles"
    prepped_hosp_df = prep_hosp_df(hosp_df, county, start_date, end_date)
    prepped_ww_df = prep_ww_df(ww_df, county, start_date, end_date)


    # Setting parameters for function
    println("Setting function parameters...")
    priors_only = false
    n_samples = 100
    n_discard_initial = 50
    forecast = true
    forecast_horizon = 7
    data_hosp = prepped_hosp_df.hospitalizations
    data_wastewater = prepped_ww_df.log_conc
    obstimes_hosp = prepped_hosp_df.obstimes_hosp
    obstimes_ww = prepped_ww_df.obstimes_ww
    max_obstime = max(length(obstimes_hosp), length(obstimes_ww))
    param_change_times = 1:7:max_obstime

    # Setting model parameters
    println("Setting model parameters...")
    ## run init conds for comps
    init_params = init_param_fnx(case_df, hosp_df, county, start_date, end_date)
    spline_params = ()

    model_params = create_uciwweihr_model_params2(
    E_init_sd=0.2, log_E_init_mean=init_params.log_E_init_mean,
    I_init_sd=0.2, log_I_init_mean=init_params.log_I_init_mean,
    H_init_sd=0.2, log_H_init_mean=init_params.log_H_init_mean,
    gamma_sd=0.02, log_gamma_mean=log(1/4),
    nu_sd=0.02, log_nu_mean=log(1/7),
    epsilon_sd=0.02, log_epsilon_mean=log(1/5),
    rho_gene_sd=1.0, log_rho_gene_mean=log(1),
    sigma_ww_sd=spline_params.sigma_ww_sd, log_sigma_ww_mean=spline_params.log_sigma_ww_mean,
    sigma_hosp_sd=spline_params.sigma_hosp_sd, sigma_hosp_mean=spline_params.sigma_hosp_mean,
    Rt_init_sd=0.1, Rt_init_mean=log(1.1),
    sigma_Rt_sd=0.2, sigma_Rt_mean=-3.0,
    w_init_sd=1.25, w_init_mean=logit(0.01),
    sigma_w_sd=0.2, sigma_w_mean=-3.5
)

    
    
end

main()

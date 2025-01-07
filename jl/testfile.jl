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
    df[!, :hospitalized_covid_patients] .= parse.(Int, df.hospitalized_covid_patients)
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

    # Prep the data
    println("Prepping data...")
    start_date = "2024-07-21"
    end_date = "2024-09-22"
    county = "Los Angeles"
    prepped_hosp_df = prep_hosp_df(hosp_df, county, start_date, end_date)
    prepped_ww_df = prep_ww_df(ww_df, county, start_date, end_date)

    
    
end

main()

## Pulling data from the data.ca.gov site

## Libraries
library("tidyverse")
library("lubridate")
library("patchwork")
library("slider")
library("glue")
library("ggrepel")
library("ckanr")
library("fs")
library("here")
cat("Libraries loaded...\n")

## Hospitalizations 
cat("Pulling hospitalization data...\n")
# connect to CKAN instance
ckanr_setup(
  url = "https://data.ca.gov"
)

# get resources
resources = rbind(
  resource_search( 
    "name:covid-19", 
    as = "table" 
  )$results,
  resource_search(
    "name:hospitals by county", 
    as = "table" 
  )$results
)

resource_ids = list( 
  hosp = resources$id[resources$name == "Statewide Covid-19 Hospital County Dat"]
)

hosp_url = resources %>% 
  filter( 
    name == "Statewide Covid-19 Hospital County Data" 
  ) %>% 
  pull(
    url
  )

hosp = read_csv( 
  hosp_url 
) %>%
  as_tibble() %>%
  mutate( 
    todays_date = as.Date(
      todays_date,
      format = "%m/%d/%Y"
    ),
    hospitalized_covid_patients = as.integer( 
      hospitalized_covid_confirmed_patients 
    ) 
  ) %>%
  select( 
    date = todays_date,
    hospitalized_covid_patients,
    county 
  )

hosp = hosp[-1,]

write_csv( 
  hosp, 
  file = "data/hosp-data.csv" 
)
cat("Hospitalization data pulled and saved...\n")


## Wastewater
cat("Pulling wastewater data...\n")
quiet <- function(x) {
  sink(tempfile())
  on.exit(sink())
  invisible(force(x))
}

# connect to CKAN instance
#ckanr_setup( url = 'https://data.ca.gov' )
ckanr_setup( url = 'https://data.chhs.ca.gov' )
#ckan <- ckanr::src_ckan( 'https://data.ca.gov' )

# get resources
resources <- rbind( resource_search( 'name:covid-19', as = 'table' )$results,
                    resource_search( 'name:wastewater', as = 'table' )$results)
#resource_ids <- list( hosp = resources$id[resources$name == 'COVID-19 Wastewater Surveillance Data. California'] )
resource_ids <- list( hosp = resources$id[resources$name == 'Wastewater Surveillance, California'] )

wastewater_url <- resources %>% 
  #filter(name == "COVID-19 Wastewater Surveillance Data. California") %>% 
  filter(name == "Wastewater Surveillance, California") %>% 
  pull(url)
ww_dat <-
  read_csv(wastewater_url)%>% 
  mutate(date = lubridate::mdy(sample_collect_date))

issues <- problems(ww_dat)

# cdph crosswalk 
cdph_crosswalk <- read_csv(
  here::here("data", "sewershed-county-address.csv")
  ) %>% 
  rename(county = County_address) %>%
  filter(county!="Imperial")


ww_dat <- ww_dat %>% 
  left_join(cdph_crosswalk, by = "wwtp_name") %>% 
  filter(!is.na(county))

start_date <- "2023-04-01"
fitting_dat <- ww_dat %>% dplyr::select(wwtp_name, 
                                        sample_collect_date,pcr_target, 
                                        pcr_gene_target, 
                                        pcr_target_avg_conc, 
                                        county, 
                                        population_served) %>% 
  mutate(date = parse_date_time(sample_collect_date, c("%d/%m/%Y","%m/%d/%Y", "%Y-%m-%d")))

# only looking at covid genes
fitting_dat <- fitting_dat %>% 
  #filter(date >= start_date) %>% 
  filter(pcr_target == "sars-cov-2")
n1_names <- c("N", "n1")
fitting_dat <- fitting_dat %>% 
  filter(pcr_gene_target %in% n1_names)

# group by date, weight an average based on population
county_fitting_dat <- fitting_dat %>% 
  group_by(county, date) %>% 
  mutate(total_pop = sum(population_served)) %>% 
  ungroup() %>% 
  mutate(pop_weight = population_served/total_pop,
         weighted_conc = pcr_target_avg_conc * pop_weight) %>% 
  group_by(county, date) %>% 
  summarise(avg_weighted_conc = sum(weighted_conc),
            log_conc = log(avg_weighted_conc))

ca_dat <- fitting_dat %>%
  group_by(date) %>%
  mutate(total_pop = sum(population_served)) %>%
  ungroup() %>%
  mutate(pop_weight = population_served/total_pop,
         weighted_conc = pcr_target_avg_conc * pop_weight) %>% 
  group_by(date) %>% 
  summarise(avg_weighted_conc = sum(weighted_conc),
            log_conc = log(avg_weighted_conc)) %>% 
  mutate(county = "California") %>%
  dplyr::select(county, date, avg_weighted_conc, log_conc)

full_fitting_dat <- bind_rows(county_fitting_dat, ca_dat)

id_list <- data.frame(county = unique(full_fitting_dat$county)) %>% 
  mutate(id = row_number())

full_fitting_dat <- full_fitting_dat %>% 
  left_join(id_list, by = "county")

# set up fitting dates and epiweeks 
full_fitting_dat <- full_fitting_dat %>% 
  group_by(county) %>% 
  mutate(yearday = yday(date),
         new_time = yearday - min(yearday) + 1,
         epiweek = epiweek(date),
         new_week = ceiling(new_time/7)) %>% 
  filter(avg_weighted_conc > 0)


write_csv(
  full_fitting_dat, 
  here::here("data", "ww-data.csv"))

cat("Wastewater data pulled and saved...\n")


## Cases
cat("Pulling case data...\n")

quiet <- function(x) {
  sink(tempfile())
  on.exit(sink())
  invisible(force(x))
}


ckanr_setup(url="https://data.chhs.ca.gov")
#ckan <- quiet(ckanr::src_ckan("https://data.ca.gov"))

# get resources
resources <- rbind(resource_search("name:Respiratory", as = "table")$results)


cases_deaths_url <- resources %>% filter(name == "Respiratory Virus Dashboard Metrics: Testing") %>% pull(url)

cases <-
  read_csv(cases_deaths_url) %>%
  mutate(date = lubridate::ymd(date),
         positive_tests = as.integer(positive_tests),
         total_tests = as.integer(total_tests)) %>%
  select(date,
         tests = total_tests,
         cases = positive_tests,
         county = area) %>%
  arrange(date, county)


write_csv(cases, here::here("data","case-data.csv"))

cat("Case data pulled and saved...\n")

# Load requisite packages and install if necessary
library(tidyverse)
library(janitor)
library(scales)
library(readr)
library(readxl)
library(AzureStor)
library(stringi)
# Azure storage credentials
account_endpoint <- Sys.getenv("azure_blob_account_01")
account_key <- Sys.getenv("azure_blob_key_01")
container_name <- Sys.getenv("azure_blob_container_01")
bl_endp_key <- storage_endpoint(account_endpoint, key=account_key)
cont <- storage_container(bl_endp_key, container_name)

# Grab the latest file based on the metadata
azure_down_name <- list_blobs(cont, info = "all") %>%
  clean_names() %>%
  filter(str_detect(name, ".xlsx")) %>%
  slice(which.max(creation_time)) %>%
  select(name) %>%
  pull()
# Get data from Azure blob
download_blob(cont, src=azure_down_name, dest=azure_down_name, overwrite = TRUE) # download from Azure storage
# Read the downloaded file and recode the age groups
df <- read_xlsx(azure_down_name) %>%
  clean_names() %>%
  mutate(id = row_number()) %>%
  mutate(agegroup = recode(agegroup10,
                        "20 to 29" = "20 to 39",
                        "30 to 39" = "20 to 39",
                        "40 to 49" = "40 to 59",
                        "50 to 59" = "40 to 59",
                        "60 to 69" = "60 to 79",
                        "70 to 79" = "60 to 79",
                        "80 or plus" = "80+ years"
  ))
# Calculate the four totals (cases, deaths, hospitalizations, icu)
total_cases <- df %>%
  count() %>%
  pull()
total_deaths <- df %>%
  filter(disposition2 == "Deceased") %>%
  count() %>%
  pull
total_hosp <- df %>%
  filter(hosp_status == "Hospitalized - ICU" | hosp_status == "Hospitalized - non-ICU") %>%
  count() %>%
  pull()
total_icu <- df %>%
  filter(hosp_status == "Hospitalized - ICU") %>%
  count() %>%
  pull()
# Final table
df_final <- df %>%
  group_by(agegroup) %>%
  summarise(perc_male_cases = percent(n_distinct((id)[gender2 == "Male"])/total_cases, accuracy = 0.01, suffix = ""),
            perc_female_cases = percent(n_distinct((id)[gender2 == "Female"])/total_cases, accuracy = 0.01, suffix = ""),
            total_cases,
            perc_male_deaths = percent(n_distinct((id)[gender2 == "Male" & disposition2 == "Deceased"])/total_deaths, accuracy = 0.01, suffix = ""),
            perc_female_deaths = percent(n_distinct((id)[gender2 == "Female" & disposition2 == "Deceased"])/total_deaths, accuracy = 0.01, suffix = ""),
            total_deaths,
            perc_male_hosp = percent(n_distinct((id)[gender2 == "Male" & (hosp_status == "Hospitalized - ICU" | hosp_status == "Hospitalized - non-ICU")])/total_hosp, accuracy = 0.01, suffix = ""),
            perc_female_hosp = percent(n_distinct((id)[gender2 == "Female" & (hosp_status == "Hospitalized - ICU" | hosp_status == "Hospitalized - non-ICU")])/total_hosp, accuracy = 0.01, suffix = ""),
            total_hosp,
            perc_male_icu = percent(n_distinct((id)[gender2 == "Male" & hosp_status == "Hospitalized - ICU"])/total_icu, accuracy = 0.01, suffix = ""),
            perc_female_icu = percent(n_distinct((id)[gender2 == "Female" & hosp_status == "Hospitalized - ICU"])/total_icu, accuracy = 0.01, suffix = ""),
            total_icu
            ) %>%
  filter(!is.na(agegroup)) %>%
  filter(agegroup != "Unknown")
# Write out csv
filename <- "covid_azure_etl.csv"
write_excel_csv(df_final, filename)
upload_blob(cont, src=filename, dest=filename)
# Remove the downloaded excel file and the generated csv file
file.remove(azure_down_name)
file.remove(filename)
# Quit
q(save = "no")
# Data yang Digunakan
df_event <- read.csv('https://storage.googleapis.com/dqlab-dataset/event.csv', stringsAsFactors = F)
dplyr::glimpse(df_event)

# Mengubah kolom created_at menjadi tipe Timestamp
library(lubridate)

df_event$created_at <- ymd_hms(df_event$created_at)
dplyr::glimpse(df_event)

# Summary Event
library(dplyr)
df_event %>%
  group_by(nama_event) %>%
  summarise(jumlah_event = n(), 
            loan = n_distinct(loan_id), 
            investor = n_distinct(investor_id))

# Event loan di-upload ke marketplace
library(dplyr)
df_marketplace <- df_event %>% filter(nama_event == 'loan_to_marketplace') %>% select(loan_id, marketplace = created_at) 
df_marketplace

# Event investor melihat detail loan
library(dplyr)
df_view_loan <- df_event %>% 
  filter(nama_event == 'investor_view_loan') %>% 
  group_by(loan_id, investor_id) %>% 
  summarise(jumlah_view = n(), 
            pertama_view = min(created_at), 
            terakhir_view = max(created_at))
df_view_loan

# Event investor pesan dan bayar loan
library(dplyr)
library(tidyr)

df_order_pay <- df_event %>%
  filter(nama_event %in% c('investor_order_loan', 'investor_pay_loan')) %>%
  spread(nama_event, created_at) %>%
  select(loan_id, 
         investor_id, 
         order = investor_order_loan, 
         pay = investor_pay_loan)
df_order_pay

# Gabungan Data Loan Investasi
library(dplyr)

df_loan_invest <- df_marketplace %>% 
  left_join(df_view_loan, by = 'loan_id') %>% 
  left_join(df_order_pay, by = c('loan_id','investor_id'))
df_loan_invest

# Melihat hubungan jumlah view dengan order
library(dplyr)
library(tidyr)
df_loan_invest %>%
  mutate(status_order = ifelse(is.na(order),'not_order','order')) %>%
  count(jumlah_view, status_order) %>%
  spread(status_order, n, fill = 0) %>%
  mutate(persen_order = scales::percent(order/(order+not_order)))

# Berapa lama waktu yang dibutuhkan investor untuk pesan sejak pertama melihat detail loan
library(dplyr)
library(tidyr)
df_loan_invest %>%
  filter(!is.na(order)) %>%
  mutate(lama_order_view = as.numeric(difftime(order, pertama_view, units = "mins"))) %>% 
  group_by(jumlah_view) %>% 
  summarise_at(vars(lama_order_view), funs(total = n(), min, median, mean, max)) %>% 
  mutate_if(is.numeric, funs(round(.,2)))

# Rata- rata waktu pemesanan sejak loan di-upload setiap minggu nya
library(dplyr)
library(lubridate)
library(ggplot2)

df_lama_order_per_minggu <- df_loan_invest %>% 
  filter(!is.na(order)) %>%
  mutate(tanggal = floor_date(marketplace, 'week'),
         lama_order = as.numeric(difftime(order, marketplace, units = "hour"))) %>% 
  group_by(tanggal) %>%
  summarise(lama_order = median(lama_order)) 

ggplot(df_lama_order_per_minggu) +
  geom_line(aes(x = tanggal, y = lama_order)) +
  theme_bw() + 
  labs(title = "Rata-rata lama order pada tahun 2020 lebih lama daripada 2019",
       x = "Tanggal",
       y = "waktu di marketplace sampai di-pesan (jam)")

# Apakah Investor membayar pesanan yang dia buat.
library(dplyr)
library(lubridate)
library(ggplot2)

df_bayar_per_minggu <- df_loan_invest %>% 
  filter(!is.na(order)) %>%
  mutate(tanggal = floor_date(marketplace, 'week')) %>% 
  group_by(tanggal) %>%
  summarise(persen_bayar = mean(!is.na(pay))) 
ggplot(df_bayar_per_minggu) +
  geom_line(aes(x = tanggal, y = persen_bayar)) +
  scale_y_continuous(labels = scales::percent) +
  theme_bw() + 
  labs(title = "Sekitar 95% membayar pesanannya. Di akhir mei ada outlier karena lebaran",
       x = "Tanggal",
       y = "Pesanan yang dibayar")

# Waktu yang dibutuhkan investor untuk membayar pesanan
library(dplyr)
library(lubridate)
library(ggplot2)

df_lama_bayar_per_minggu <- df_loan_invest %>% 
  filter(!is.na(pay)) %>%
  mutate(tanggal = floor_date(order, 'week'),
         lama_bayar = as.numeric(difftime(pay, order, units = "hour"))) %>% 
  group_by(tanggal) %>%
  summarise(lama_bayar = median(lama_bayar)) 

ggplot(df_lama_bayar_per_minggu) +
  geom_line(aes(x = tanggal, y = lama_bayar)) +
  theme_bw() + 
  labs(title = "Waktu pembayaran trennya cenderung memburuk, 2x lebih lama dari sebelumnya",
       x = "Tanggal",
       y = "waktu di pesanan dibayar (jam)")

# Trend Investor Register
library(dplyr)
library(lubridate)
library(ggplot2)

df_investor_register <- df_event %>% 
  filter(nama_event == 'investor_register') %>%
  mutate(tanggal = floor_date(created_at, 'week')) %>% 
  group_by(tanggal) %>%
  summarise(investor = n_distinct(investor_id)) 
ggplot(df_investor_register) +
  geom_line(aes(x = tanggal, y = investor)) +
  theme_bw() + 
  labs(title = "Investor register sempat naik di awal 2020 namun sudah turun lagi",
       x = "Tanggal",
       y = "Investor Register")

# Trend Investor Investasi Pertama
library(dplyr)
library(lubridate)
library(ggplot2)

df_investor_pertama_invest <- df_event %>% 
  filter(nama_event == 'investor_pay_loan') %>%
  group_by(investor_id) %>% 
  summarise(pertama_invest = min(created_at)) %>% 
  mutate(tanggal = floor_date(pertama_invest, 'week')) %>% 
  group_by(tanggal) %>% 
  summarise(investor = n_distinct(investor_id)) 
ggplot(df_investor_pertama_invest) +
  geom_line(aes(x = tanggal, y = investor)) +
  theme_bw() + 
  labs(title = "Ada tren kenaikan jumlah investor invest, namun turun drastis mulai Maret 2020",
       x = "Tanggal",
       y = "Investor Pertama Invest")

# Cohort Pertama Invest berdasarkan Bulan Register
library(dplyr)
library(lubridate)
library(tidyr)

df_register_per_investor <- df_event %>%
  filter(nama_event == 'investor_register') %>% 
  rename(tanggal_register = created_at) %>%  
  mutate(bulan_register = floor_date(tanggal_register, 'month'))  %>%  
  select(investor_id, tanggal_register, bulan_register) 
df_pertama_invest_per_investor <- df_event %>%
  filter(nama_event == 'investor_pay_loan') %>% 
  group_by(investor_id) %>% 
  summarise(pertama_invest = min(created_at)) 
df_register_per_investor %>% 
  left_join(df_pertama_invest_per_investor, by = 'investor_id') %>% 
  mutate(lama_invest = as.numeric(difftime(pertama_invest, tanggal_register, units = "day")) %/% 30) %>%  
  group_by(bulan_register, lama_invest) %>% 
  summarise(investor_per_bulan = n_distinct(investor_id)) %>% 
  group_by(bulan_register) %>% 
  mutate(register = sum(investor_per_bulan)) %>% 
  filter(!is.na(lama_invest)) %>% 
  mutate(invest = sum(investor_per_bulan)) %>% 
  mutate(persen_invest = scales::percent(invest/register)) %>% 
  mutate(breakdown_persen_invest = scales::percent(investor_per_bulan/invest)) %>%  
  select(-investor_per_bulan) %>%  
  spread(lama_invest, breakdown_persen_invest)

# Cohort Retention Invest
library(dplyr)
library(lubridate)
library(tidyr)

df_investasi_per_investor <- df_event %>%
  filter(nama_event == 'investor_pay_loan') %>%
  rename(tanggal_invest = created_at) %>%
  select(investor_id, tanggal_invest)
df_pertama_invest_per_investor %>%
  mutate(bulan_pertama_invest = floor_date(pertama_invest, 'month')) %>%
  inner_join(df_investasi_per_investor, by = 'investor_id') %>%
  mutate(jarak_invest = as.numeric(difftime(tanggal_invest, pertama_invest, units = "day")) %/% 30) %>%
  group_by(bulan_pertama_invest, jarak_invest) %>%
  summarise(investor_per_bulan = n_distinct(investor_id)) %>%
  group_by(bulan_pertama_invest) %>%
  mutate(investor = max(investor_per_bulan)) %>%
  mutate(breakdown_persen_invest = scales::percent(investor_per_bulan/investor)) %>%
  select(-investor_per_bulan) %>%
  spread(jarak_invest, breakdown_persen_invest) %>%
  select(-`0`)


{{ dbt_utils.date_spine(
    datepart="day",
    start_date="cast('2018-01-01' as date)",
    end_date="cast('2018-12-31' as date)"
  )
}}
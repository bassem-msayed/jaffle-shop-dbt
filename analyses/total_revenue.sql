with payments as ( 

    select * from {{ ref('stg_stripe__payment') }}

), 
aggregated as ( 

    select 
        cast(sum(payment_amount) as float64) as total_revenue
    from payments 
    where payment_status = "success"

) 

select * from aggregated
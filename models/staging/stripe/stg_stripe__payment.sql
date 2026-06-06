with source as (

    select * from {{ source('stripe', 'payment') }}

),

renamed as (

    select
        id as payment_id,
        orderid as order_id,
        paymentmethod as payment_method,
        status as payment_status,
        -- Stripe stores amounts as integers in cents, so we need to divide by 100 to get the actual amount in dollars
        cast(amount/100 as float64) as payment_amount,
        created as payment_created,
        _batched_at
    from source

)

select * from renamed
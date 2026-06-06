with raw as(
    
    select * from {{ source('jaffle_shop', 'orders') }}

),
renamed as (

    select
        id as order_id,
        user_id,
        order_date,
        status as order_status
    from raw

)

select * from renamed
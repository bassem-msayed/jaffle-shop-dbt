/* The work done in this model is for practicing purposes only, and follow through with the instructor for the
"Refactoring SQL for modularity", accordingly, I kept the import & transform CTEs here instead of moving them to staging models
as the staging models already exist in the project.
*/
-- IMPORT CTEs | added references for the 3 main tables
--------------------------------------------------------
with 
    raw_orders as ( select * from {{ ref('stg_jaffle_shop__orders') }} ),
    raw_payments as ( select * from {{ ref('stg_stripe__payment') }} ),
    raw_customers as ( select * from {{ ref('stg_jaffle_shop__customers') }}),
----------------------------------------------------------------------------------

-- Transform CTEs | Code to clean up & organize
------------------------------------------------
customers as (
    select 
        customer_id,
        first_name,
        last_name,
        first_name || ' ' || last_name as full_name
    from raw_customers
),

orders as(
    select
        order_id,
        customer_id,
        order_date,
        order_status,
        row_number() over (
            partition by customer_id
            order by order_date, order_id
        ) as user_order_seq
    from raw_orders
),

payments as (
    select
        payment_id,
        order_id,
        payment_method,
        payment_status,
        payment_amount,
        payment_created
    from raw_payments
),

successful_payments as (
    select 
        order_id, 
        max(payment_created) as payment_finalized_date, 
        sum(payment_amount) as total_amount_paid
    from payments
    where payment_status <> 'fail'
    group by 1
),

-- MARTS CTEs
-- ↓ Business logic & Joins
---------------------------------------------

customer_order_history as(
    select
        customers.customer_id,
        customers.first_name,
        customers.last_name,
        customers.full_name,
        min(order_date) as first_order_date,

        min(
            case
                when orders.order_status not in ('returned', 'return_pending')
                then order_date
            end
        ) as first_non_returned_order_date,

        max(
            case
                when orders.order_status not in ('returned', 'return_pending')
                then order_date
            end
        ) as most_recent_non_returned_order_date,

        coalesce(
            max(
                user_order_seq), 0
            ) as order_count,

        coalesce(
            count(
                case
                    when orders.order_status != 'returned'
                    then 1
                end
            ) ,0
        ) as non_returned_order_count,

        sum(
            case 
                when orders.order_status not in ('returned', 'return_pending')
                then round(payments.payment_amount, 2)
                else 0
            end) /

            nullif(
                count(
                    case 
                        when orders.order_status not in ('returned', 'return_pending')
                        then 1
                    end
                ), 0
            ) as avg_non_returned_order_value,

        array_agg(distinct orders.order_id) as order_ids

    from orders
    
    join customers on orders.customer_id = customers.customer_id

    left outer join payments on orders.order_id = payments.order_id

    where orders.order_status not in ('pending') 
        and payments.payment_status != 'fail'

    group by customers.customer_id, customers.first_name, customers.last_name, customers.full_name


),


----------------------------------------------
----------------------------------------------

paid_orders as (
    
    select 
        orders.order_id,
        orders.customer_id as customer_id,
        orders.order_date as order_placed_at,
        orders.order_status, 
        successful_payments.total_amount_paid,
        successful_payments.payment_finalized_date,
        customers.first_name as customer_first_name,
        customers.last_name as customer_last_name
    
    from orders
    
    left join successful_payments on orders.order_id = successful_payments.order_id
        
    left join customers on orders.customer_id = customers.customer_id 
),


-- ↓ The below CTE can be removed, but we need some components to be enhanced and placed elsewhere first.
customer_orders as (
    
    select 
        customers.customer_id, 
        min(orders.order_date) as first_order_date,         -- replace with first_value window function
        max(orders.order_date) as most_recent_order_date,   -- replace with last_value window function
        count(orders.order_id) as number_of_orders          -- replace with count window function
    
    from customers
    
    left join raw_orders as orders on orders.customer_id = customers.customer_id 
    group by 1
),

---------------------------------------------
---------------------------------------------

-- FINAL SELECT
---------------------------------------------
final as (
    select
        
        p.*,
        
        row_number() over (
            order by p.order_id) as transaction_seq,
        
        row_number() over (
            partition by customer_id order by p.order_id) as customer_sales_seq,
        

        /*case when c.first_order_date = p.order_placed_at then 'new' else 'return' end as nvsr,*/
        case
            when(
                rank() over(
                    partition by customer_id
                    order BY order_placed_at, p.order_id
                ) = 1
            ) then 'new'
            else 'return'
        end as nvsr,


        x.clv_bad as customer_lifetime_value,
        c.first_order_date as fdos
        
        from paid_orders p
        
        left join customer_orders as c using (customer_id)
        
        left outer join 
        (
            select
                p.order_id,
                sum(t2.total_amount_paid) as clv_bad
            
            from paid_orders p
            
            left join paid_orders t2 on p.customer_id = t2.customer_id and p.order_id >= t2.order_id
            
            group by 1
            
            order by p.order_id
        ) x on x.order_id = p.order_id
        
        order by order_id
)

----------------------------------------------
----------------------------------------------
-- Final Select statement
----------------------------------------------
select * from final
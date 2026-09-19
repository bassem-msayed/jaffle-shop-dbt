import pandas as pd
import holidays

# all python models need to be defined at the start with this specific syntax
def model(dbt, session):

    # python models don't use Jinja. Here we are using dbt.config to create model configurations
    # be sure to materialize python models as tables, and to specify the packages that were imported above
    # → Had to add enabled=False to avoid this model running during dbt run since it is just a demo and not used by any downstream models
    dbt.config(
        enabled=False,
        materialized="table",
        packages=['pandas', 'holidays']
    )

    us_holidays = holidays.US()

    # python models don't use Jinja. Here we are using dbt.ref to create model references
    df = dbt.ref('date_spine').to_pandas()

    # if you are using snowpark columns need to be uppercase
    df['IS_HOLIDAY'] = df['DATE_DAY'].apply(lambda date: date in us_holidays)

    # in dbt, you always need to return your data frame at the end of your models
    return df
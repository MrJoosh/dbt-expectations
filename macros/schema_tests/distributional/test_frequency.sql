{%- macro test_frequency(model, date_col, date_part="day", filter_cond=None, test_start_date=None, test_end_date=None) -%}
{% if not execute %}
    {{ return('') }}
{% endif %}

{% if not test_start_date or not test_end_date %}
    {% set sql %}

        select 
            min({{ date_col }}) as start_date, 
            max({{ date_col }}) as end_date 
        from {{ model }} 
        {% if filter_cond %}
        where {{ filter_cond }}
        {% endif %}

    {% endset %}

{% endif %}

{%- set dr = run_query(sql) -%}
{%- set db_start_date = dr.columns[0].values()[0].strftime('%Y-%m-%d') -%}
{%- set db_end_date = dr.columns[1].values()[0].strftime('%Y-%m-%d') -%}

{% if not test_start_date %}
{% set start_date = db_start_date %}
{% else %}
{% set start_date = test_start_date %}
{% endif %}


{% if not test_end_date %}
{% set end_date = db_end_date %}
{% else %}
{% set end_date = test_end_date %}
{% endif %}

with date_spine as
(
    {{ dbt_utils.date_spine(
        datepart=date_part,
        start_date="'" ~ start_date ~ "'",
        end_date="'" ~ end_date ~ "'"
       )
    }}
),
model_data as
(
    select
        cast({{ dbt_utils.date_trunc(date_part, date_col) }} as datetime) as date_{{date_part}},
        count(*) as row_cnt
    from
        {{ model }} f
    {% if filter_cond %}
    where {{ filter_cond }}
    {% endif %}
    group by
        1
),
{# date_part_dates as 
(
    select
        cast({{ dbt_utils.date_trunc(date_part, 'date_' ~ date_part ) }} as date) as date_{{date_part}}
    from
        date_spine d
    group by 
        1
), #}
final as
(
    select
        d.date_{{date_part}},
        case when f.date_{{date_part}} is null then true else false end as is_missing,
        coalesce(f.row_cnt, 0) as row_cnt
    from
        date_spine d
        left outer join
        model_data f on d.date_{{date_part}} = f.date_{{date_part}}
)
select count(*) from final where row_cnt = 0
{%- endmacro -%}
view: order_items {
  sql_table_name: "PUBLIC"."ORDER_ITEMS"
    ;;
  drill_fields: [id]

  dimension: id {
    primary_key: yes
    type: number
    sql: ${TABLE}."ID" ;;
  }

  dimension_group: created {
    type: time
    timeframes: [
      raw,
      time,
      date,
      week,
      day_of_month,
      month,
      quarter,
      year
    ]
    sql: ${TABLE}."CREATED_AT" ;;
  }

  dimension_group: delivered {
    type: time
    timeframes: [
      raw,
      time,
      date,
      week,
      month,
      quarter,
      year
    ]
    sql: ${TABLE}."DELIVERED_AT" ;;
  }

  dimension_group: returned {
    type: time
    timeframes: [
      raw,
      time,
      date,
      week,
      month,
      quarter,
      year
    ]
    sql: ${TABLE}."RETURNED_AT" ;;
  }

  dimension: sale_price {
    type: number
    sql: ${TABLE}."SALE_PRICE" ;;
  }

  dimension_group: shipped {
    type: time
    timeframes: [
      raw,
      time,
      date,
      week,
      month,
      quarter,
      year
    ]
    sql: ${TABLE}."SHIPPED_AT" ;;
  }

  dimension: status {
    description: "Whether order is processing, shipped, completed, etc."
    type: string
    sql: ${TABLE}.status ;;
  }

  dimension: shipping_time {
    description: "Shipping time in days"
    type: number
    sql: DATEDIFF(day, ${order_items.shipped_date}, ${order_items.delivered_date}) ;;
  }

  dimension_group: shipping_times {
    type: duration
    intervals: [
      hour,
      day,
      week
    ]
    sql_start: ${shipped_date} ;;
    sql_end: ${delivered_date} ;;
  }

  # TEMPLATED FILTER IN A DIMENSION
  parameter: timeframe {
    type: unquoted
    allowed_value: {
      label: "Daily"
      value: "Daily"
    }

    allowed_value: {
      label: "Weekly"
      value: "Weekly"
    }

    allowed_value: {
      label: "Monthly"
      value: "Monthly"
    }

    allowed_value: {
      label: "Yearly"
      value: "Yearly"
    }
  }

  dimension: variable_timeframe {
    label_from_parameter: timeframe
    sql:{% if timeframe._parameter_value == 'Daily' %}
          ${created_date}
        {% elsif timeframe._parameter_value == 'Weekly' %}
          ${created_week}
        {% elsif timeframe._parameter_value == 'Monthly' %}
          ${created_month}
        {% else %}
          ${created_year}
        {% endif %};;
    }

  dimension: reporting_period_mtd {
    description: "This Month versus Last Month "
    sql: CASE
            WHEN EXTRACT(YEAR FROM ${created_raw}) = EXTRACT( YEAR FROM CURRENT_DATE())
            AND EXTRACT(MONTH FROM ${created_raw}) = EXTRACT( MONTH FROM CURRENT_DATE())
            AND ${created_date} <= CURRENT_DATE()
            THEN 'This Month'
            WHEN EXTRACT(YEAR FROM ${created_raw}) = EXTRACT( YEAR FROM CURRENT_DATE())
            AND EXTRACT(MONTH FROM ${created_raw}) + 1 = EXTRACT(MONTH FROM CURRENT_DATE())
            --AND EXTRACT(DAY FROM ${created_raw}) <= EXTRACT(DAY FROM CURRENT_DATE())
            THEN 'Last Month'
          ELSE NULL
        END
       ;;
  }

  dimension: reporting_period_wtd {
    description: "This Week to date versus Last Week to date"
    sql: CASE
            WHEN ${created_raw} >= dateadd(day, -1, date_trunc(week, current_date))
              THEN 'This Week'
            WHEN ${created_raw} < dateadd(day, -1, date_trunc(week, current_date)) and ${created_raw} >= dateadd(day, -8, date_trunc(week, current_date))
              THEN 'Last Week'
          ELSE NULL
        END
       ;;
  }

## HIDDEN DIMENSIONS ##

  dimension: inventory_item_id {
    hidden:  yes
    type: number
    # hidden: yes
    sql: ${TABLE}.inventory_item_id ;;
  }

  dimension: order_id {
    hidden:  yes
    type: number
    sql: ${TABLE}.order_id ;;
  }

  dimension: user_id {
    type: number
    hidden: yes
    sql: ${TABLE}.user_id ;;
  }

  dimension: profit {
    description: "Profit made on any one item"
    hidden:  yes
    type: number
    value_format_name: usd
    sql: ${sale_price} - ${inventory_items.cost} ;;
  }

## MEASURES ##

  measure: order_item_count {
    type: count
    drill_fields: [detail*]
  }

  measure: total_revenue {
    type: sum
    value_format_name: usd
    sql: ${sale_price} ;;
    drill_fields: [detail*]
  }

  measure: total_revenue_completed {
    type: sum
    value_format_name: usd
    sql: ${sale_price} ;;
    filters: {
      field: status
      value: "Complete"
    }
  }

  measure: order_count {
    description: "A count of unique orders"
    type: count_distinct
    sql: ${order_id} ;;
    drill_fields: [user_id,order_id,created_date,order_item_count,total_revenue]
  }

  measure: average_sale_price_new {
    type: average
    value_format_name: usd
    sql: ${sale_price} ;;
    drill_fields: [detail*]
  }

  measure: total_sale_price {
    type: sum
    value_format_name: usd
    sql: ${sale_price} ;;
    drill_fields: [detail*]
  }

  measure: average_spend_per_user {
    type: number
    value_format_name: usd
    sql: 1.0 * ${total_revenue} / NULLIF(${users.count},0) ;;
  }

  measure: total_profit {
    type: sum
    sql: ${profit} ;;
    value_format_name: usd
  }

  measure: average_shipping_time {
    type: average
    sql: ${shipping_time} ;;
    value_format: "0.00\" days\""
  }

  # ----- Sets of fields for drilling ------
  set: detail {
    fields: [
      id,
      inventory_items.product_name,
      inventory_items.id,
      users.last_name,
      users.id,
      users.first_name
    ]
  }
}

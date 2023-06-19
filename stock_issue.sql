SELECT user_id, SUM(count)
FROM 
offline.offline_stock_issue
where branch like '%Panchkula%'
group by 1
order by 2 desc
with cte as 
(
select 
  enquiry_date::date as walkin_date,
  count(enquiry_date) as walkin_count,
  count(reg_no) as admission_count
from 
	offline.offline_enquiry_humming oeh
where 
  branch like '%Panchkula%'
  and branch not like 'ZONE%'
  and branch not ilike '%test%'
  and branch not like '%TEST%'

  and name not like '%demo%'
  and name not like '%test%'
  and name not like '%TEST%'

  and course not like '%Fastrack%'
  and course not like '%Test Series%'
  and course not like '%D2%'
  and course not like '%Rankers%'

  and phone_no not in ('eb828f37f633ae7883cf305aa587309d','3c78f85d12d899a76795eae89ec603d1','699819e6a58873755bd3b7d90f3ccd76','ddfb2232b6feb829efabed3cff3719af','e807f1fcf82d132f9bb018ca6738a19f','f1b708bba17f1ce948dc979f4d7092bc')
group by 1
)

select * from cte
order by walkin_date desc

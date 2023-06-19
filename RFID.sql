with master_attendance AS 
(
select 
  reg_no, employeecode, student_name, employeerfidnumber,
  class, course, form_status, stu_hum.status, batch,
  row_number() over() as rn
from
Offline.offline_students_humming as stu_hum
left join 
essl.employees as esl_emp
on stu_hum.reg_no = esl_emp.employeecode
where 
  center like '%Panchkula%' and 
  stu_hum.program in ('Vidyapeeth') and 
  stu_hum.scheme not like '%Rankers%' and 
  stu_hum.course not like '%Fastrack%' and 

  center not like 'ZONE%'and
  center not ilike '%test%' and
  center not like '%TEST%' and
  stu_hum.status = 'Active' and 
  
  student_name not like '%test%' and 
  student_name not like '%demo%' and
  student_name not like '%TEST%' and 
  
  stu_hum.form_status not like '%Admission Cancelled%'
  )
  
  select *

  from 
    master_attendance

  
  
 

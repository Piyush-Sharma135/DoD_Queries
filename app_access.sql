with student_class_tbl
AS(

select 
  proj_hum.reg_no, proj_hum.scheme, stu_hum.jodo_status,stu_hum.batch, stu_hum.batch_preference,
  stu_hum.student_name, stu_hum.roll_no, stu_hum.status, stu_hum.form_status, stu_hum.source_name,
  stu_hum.course, stu_hum.program, stu_hum.class, stu_hum.stream,stu_hum.center, stu_hum.joining_date, 
  stu_hum.class_recorded_mobile_no,
  
  proj_hum.bill_amount, proj_hum.concession, proj_hum.total_payable_with_gst,
  (proj_hum.total_payable_with_gst - proj_hum.balance) as total_paid_updated,
  total_paid_updated + proj_hum.adjusted_amt as total_fee_paid

from 
  Offline.offline_students_humming stu_hum right join 
  offline.offline_projection_humming proj_hum
  on stu_hum.reg_no = proj_hum.reg_no

where 
  proj_hum.so_status = 'NEW' and 
  proj_hum.center like '%Panchkula%' and 
  proj_hum.student not like '%test%' and 
  proj_hum.student not like '%demo%' and

  stu_hum.program in ('Vidyapeeth') and 
  stu_hum.scheme not like '%Rankers%' and 
  stu_hum.course not like '%Fastrack%' and 
  stu_hum.student_name not ilike '%test%' and
  stu_hum.form_status not like '%Admission Cancelled%'

),

 
year_enrolled_tbl AS 
 (
 select *,
(case 
  when scheme like '%3yr%' then 3
  when scheme like '%4yr%' then 4
  when scheme like '%2yr%' then 2
  else 1
  end
  ) as years_enrolled
from student_class_tbl
),

payment_status_tbl
AS(
select * , 
(case
  when total_fee_paid IS NULL then '-'
  
  when class in (6,7,8,9,10) and years_enrolled = 1 and total_fee_paid < 5000 then 'Less than Registration'
  when class in (6,7,8,9,10) and years_enrolled = 1 and total_fee_paid >= 5000 and total_fee_paid < 0.55*total_payable_with_gst then 'Registration Only'
  when class in (6,7,8,9,10) and years_enrolled = 1 and total_fee_paid >=0.55*total_payable_with_gst  AND total_fee_paid <= 0.6*total_payable_with_gst then '1st Instalment'
  when class in (6,7,8,9,10) and years_enrolled = 1 and total_fee_paid >0.6*total_payable_with_gst then '2nd Instalment'
  
  
  when class in (6,7,8,9,10,11,12,'12+') and years_enrolled = 2 and total_fee_paid < 10000 then 'Less than Registration'
  when class in (6,7,8,9,10,11,12,'12+') and years_enrolled = 2 and total_fee_paid >= 10000 and total_fee_paid < 0.3*total_payable_with_gst then 'Registration Only'
  when class in (6,7,8,9,10,11,12,'12+') and years_enrolled = 2 and total_fee_paid >=0.3*total_payable_with_gst  AND total_fee_paid <= 0.35*total_payable_with_gst then '1st Instalment'
  when class in (6,7,8,9,10,11,12,'12+') and years_enrolled = 2 and total_fee_paid >0.35*total_payable_with_gst then '2nd Instalment'
  
  
  when class in (11,12,'12+') and years_enrolled = 1 and total_fee_paid < 10000 then 'Less than Registration'
  when class in (11,12,'12+') and years_enrolled = 1 and total_fee_paid >= 10000 and total_fee_paid < 0.55*total_payable_with_gst then 'Registration Only'
  when class in (11,12,'12+') and years_enrolled = 1 and total_fee_paid >=0.55*total_payable_with_gst  AND total_fee_paid <= 0.6*total_payable_with_gst then '1st Instalment'
  when class in (11,12,'12+') and years_enrolled = 1 and total_fee_paid >0.6*total_payable_with_gst then '2nd Instalment'
  
  
  when class in (6,7,8,9,10,11,12,'12+') and years_enrolled in (3,4) and total_fee_paid < 10000 then 'Less than Registration'
  when class in (6,7,8,9,10,11,12,'12+') and years_enrolled in (3,4) and total_fee_paid >= 10000 and total_fee_paid < 0.2*total_payable_with_gst then 'Registration Only'
  when class in (6,7,8,9,10,11,12,'12+') and years_enrolled in (3,4) and total_fee_paid >=0.2*total_payable_with_gst  AND total_fee_paid <= 0.25*total_payable_with_gst then '1st Instalment'
  when class in (6,7,8,9,10,11,12,'12+') and years_enrolled in (3,4) and total_fee_paid >0.25*total_payable_with_gst then '2nd Instalment'
 
 else '1st Instalment'
  end) as payment_status
  
  from year_enrolled_tbl
  ),
  
  discount_tbl
  AS(
  select * ,
  (case 
    when class in (11,12) and (years_enrolled=1) and program like '%Vidyapeeth%' then 8475+1899
    when class = '12+' and program = 'Vidyapeeth' and years_enrolled = 1 then 8475+3000
    when class = 11 and years_enrolled = 2 and program like '%Vidyapeeth%' then 8475+3798
    when class in (8,9,10) and years_enrolled=1 and program like '%Vidyapeeth%' then 4237+1399
    when class = 8 and years_enrolled = 3 and program like '%Vidyapeeth%' then 8475+4197
    when class = 9 and years_enrolled = 2 and program like '%Vidyapeeth%' then 8475+2799
    when class = 9 and years_enrolled and program like '%Vidyapeeth%' = 4 then 8475+6596
    when class = 10 and years_enrolled =3 and program like '%Vidyapeeth%' then 8475+5197
    when class in (11,12) and years_enrolled =1 and program in ('C2','Pathshala') then 4237+1899
    when class = '12+' and years_enrolled =1 and program='Pathshala' then 4237+3000
    when class = 11 and years_enrolled =2 and program in ('C2','Pathshala') then 8475+3798
   
  end) as tuition_book_fee_waiver,
  
  bill_amount - tuition_book_fee_waiver as discounted_bill_amt
 
  from payment_status_tbl
  ),
  
  final_walkins_tbl 
  AS (
  select 
    reg_no, roll_no, student_name, joining_date, batch, batch_preference,
    course, class, stream, center, form_status,source_name, class_recorded_mobile_no,
    bill_amount, concession, total_payable_with_gst, total_fee_paid,
    jodo_status, discounted_bill_amt, concession/discounted_bill_amt as discount_percentage,
    payment_status
  from 
    discount_tbl
    ),

online_tbl 
AS(
select 
  reg_no, scheme, 
  receipt_date, paid_amount, payment_mode,
  row_number() over(partition by reg_no order by receipt_date asc) as rn
from 
  Offline.offline_receipt_humming
),


master AS
(
select 
  final_walkins_tbl.reg_no, roll_no, student_name, joining_date::date, 
  online_tbl.paid_amount as first_amt_paid, class_recorded_mobile_no,
  course, class, concat(class,stream) as class_stream, center, form_status,source_name,
  final_walkins_tbl.batch, concession, total_payable_with_gst, total_fee_paid,
  
(case 
  when jodo_status in ('ACTIVE', 'Active', 'active') then 'yes'
  else 'no'
  end) as jodo_status,
  batch_preference, discount_percentage, payment_status
from 
  final_walkins_tbl left join online_tbl
on 
  final_walkins_tbl.reg_no = online_tbl.reg_no
where rn = 1
),

app1 
AS(
select 
reg_no , u.primarynumber as pun, u._id as puid,
case 
  when batch != '' then concat ('Vidyapeeth ', batch)
  when batch is null then null 
  end as newbatch,
primarynumber, _id,
row_number() over(partition by reg_no) as rn2
from 
  master
left join 
  public.users u
on master.class_recorded_mobile_no = u.primarynumber
),

app2 AS
(
select 
reg_no , pun, puid, newbatch,
bch._id as bch_batchid , 
bch.name as bch_name, 
bch.status as bch_status, rn2
from 
  app1
left join
  public.batches bch
on upper(app1.newbatch) = upper(bch.name)
where rn2 =1
),

app3 
as(
select 
  reg_no , puid, newbatch, row_number() over(partition by reg_no) as rn3,
  bch_batchid , bch_name, bch_status,
  bsm.status as bsm_status, 
  bsm.userid as bsm_userid,
  bsm.batchid as bsm_batchid,
  isblocked,
  (case when 
    bsm_batchid IS NOT NULL and bsm_userid IS NOT NULL then 'Access Given'
  else 'no'
  end) as access_given
from 
  app2
left join 
  public.batch_student_mappings bsm 
on
  app2.puid = bsm.userid 
  and
  app2.bch_batchid = bsm.batchid

)

select *
from
app3
where rn3 =1





  
  
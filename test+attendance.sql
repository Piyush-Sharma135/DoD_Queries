WITH stu_hum AS (
SELECT 
    reg_no, student_name,
    CASE 
        WHEN batch ilike '29-%' then CONCAT('Vidyapeeth ',batch)
        WHEN batch IS NOT NULL AND LEN(batch) > 0 THEN CONCAT('Vidyapeeth ', batch)
        END AS newbatch
FROM
    Offline.offline_students_humming osh 
WHERE
    center LIKE '%Panchkula%' AND
    program IN ('Vidyapeeth') AND
    status = 'Active' AND
    scheme NOT LIKE '%Rankers%' AND
    course NOT LIKE '%Fastrack%' AND 
    student_name NOT ilike '%test%' AND
    form_status NOT LIKE '%Admission Cancelled%'
),

rfid_mapping AS (
SELECT
    employeecode, DATE(punchdatetime) AS punch_date, 
    punchdatetime, to_char(punchdatetime , 'HH24:MI:SS') AS punchtime,
    ROW_NUMBER() OVER(PARTITION BY employeecode, punchdatetime::DATE ORDER BY punchdatetime ASC) AS rn_pl
FROM 
    essl.devicepunchlogs

),

punch_logs AS (
SELECT 
    stu_hum.reg_no AS punch_reg_no, 
    stu_hum.student_name AS punch_student_name,
    stu_hum.newbatch,
    rfid_mapping.punch_date, rfid_mapping.punchtime
FROM 
    stu_hum LEFT JOIN rfid_mapping 
ON  
    stu_hum.reg_no = rfid_mapping.employeecode
WHERE 
    rn_pl =1
), 



batch_schedule AS (
SELECT 
    stu_hum.reg_no as schedule_reg_no, stu_hum.newbatch,
    bch.name AS batch_name,
    DATE(bsch.date) AS schedule_date, 
    TO_CHAR(bsch.starttime + interval '5 hour' + interval '30 minute', 'HH24:MI:SS') as starttime,
    ROW_NUMBER() OVER (PARTITION BY schedule_reg_no, batch_name, schedule_date ORDER BY starttime) rn_sch
FROM
    stu_hum LEFT JOIN batches bch
ON UPPER(stu_hum.newbatch) = UPPER(bch.name)

LEFT JOIN batch_subjects bsubj
ON bch._id = bsubj.batchid

LEFT JOIN subjects sub
ON bsubj.subjectid = sub._id

LEFT JOIN batch_subject_schedules bsch
ON bsubj._id = bsch.batchsubjectid

WHERE
    UPPER(bsch.topic) NOT IN ('TEST', 'DOUBT','NO', 'EXTRA', 'CANCEL', 'NO CLASS', 'MODULE', 'PDF') AND 
    bsch.status != 'Inactive' AND 
    bsch.isdppnotes='False' AND 
    bsch.isdppvideos='False' AND
    isnull(UPPER(topic),'') not ilike '%*%' AND
    sub.name NOT IN ('Notices','PYQ Discussion','Self Awareness')
),



master AS(
SELECT 
    batch_name, schedule_date,
    punch_reg_no, punch_student_name, punch_date, punchtime,
    CASE WHEN PUNCH_REG_NO = SCHEDULE_REG_NO THEN 'P'ELSE 'A' END AS present_absent,
    starttime, schedule_reg_no, rn_sch
FROM 
    batch_schedule LEFT JOIN punch_logs 
ON
    batch_schedule.schedule_reg_no = punch_logs.punch_reg_no
AND
    batch_schedule.schedule_date = punch_logs.punch_date
AND
    UPPER(batch_schedule.batch_name) = UPPER(punch_logs.newbatch)
WHERE  rn_sch = 1
ORDER BY
    batch_name, schedule_reg_no, schedule_date
),

---------------------------------------------------------------------------------------------------------------------------------

CBT_MST AS(
select 
    reg_no, student_name, new_batch, phase, test_name, 
    test_category_name, test_date, completed, attemptedquestions, correctquestions, 
    accuracy,

sum(case when subject_name ilike '%Physics%' then subject_marks end) as Physics,
sum(case when subject_name ilike '%Chemistry%' then subject_marks end) as Chemistry,
sum(case when subject_name ilike '%Maths%' or subject_name ilike '%Mathematics%' then subject_marks end) as Maths,
sum(case when subject_name ilike '%Botany%' then subject_marks end) as Botany,
sum(case when subject_name ilike '%Zoology%' then subject_marks end) as Zoology,
sum(case when subject_name ilike '%Biology%' then subject_marks end) as Biology,
sum(case when subject_name ilike '%Social Studies%' or subject_name ilike '%Social Science%' then subject_marks end) as SocialStudies,
sum(case when subject_name ilike '%English%' then subject_marks end) as English,
total_marks,max_marks
 
from

(
select 
    reg_no,student_name, new_batch,
    te._id AS "test_id", result_id, test_name, test_category_name, result_create_date::date,
    STARTTIME::date as test_date, total_marks, subject_marks, nvl(qbg_subject_name,subject_name) AS "subject_name", max_marks,
   test_rank, phase,categoryid, completed, attemptedquestions, correctquestions, accuracy

FROM

(select 
    testid, studentid,userscore "total_marks",_id AS "result_id",
    createdat AS "result_create_date", rank AS "test_rank" , 
    completed, attemptedquestions, correctquestions,accuracy
from hevo_results) as re

JOIN

(select 
    _id, categoryid, 
    name AS "test_name", createdat AS "test_create_date", 
    STARTTIME, TOTALMARKS AS "max_marks", 
    categorymodeids[0] "tcmid"  
    from hevo_tests
where 
    type='Mock' and 
    status='Active') as te
on re.testid=te._id

left join

(select 
    name "test_category_name",_id 
from  test_categories) as tc
on tc._id=te.categoryid

JOIN

(select 
    _id,primarynumber 
from users) as u
on u._id=re.studentid

JOIN

(select 
    reg_no,student_name,CLASS_RECORDED_MOBILE_NO,center,scheme,
    CASE 
        WHEN batch ilike '29-%' then CONCAT('Vidyapeeth ',batch)
        WHEN batch IS NOT NULL AND LEN(batch) > 0 THEN CONCAT('Vidyapeeth ', batch)
        END AS new_batch,

case 
when length(batch)>5 and batch like '%LJ%' then 'Vidyapeeth 12th JEE 2024'
when length(batch)>5 and batch like '%LN%' then 'Vidyapeeth 12th NEET 2024'
when length(batch)>5 and batch like '%AJ%' then 'Vidyapeeth 11th JEE 2024'
when length(batch)>5 and batch like '%AN%' then 'Vidyapeeth 11th NEET 2024'
when length(batch)>5 and batch like '%PJ%' then 'Vidyapeeth Dropper JEE 2024'
when length(batch)>5 and batch like '%YN%' then 'Vidyapeeth Dropper NEET 2024'
when length(batch)>5 and batch like '%UF%' then 'Vidyapeeth 10th Foundation 2024'
when length(batch)>5 and batch like '%NF%' then 'Vidyapeeth 9th Foundation 2024'
when length(batch)<5 and batch like '%LJ%' then 'Classroom 12th JEE 2024'
when length(batch)<5 and batch like '%LN%' then 'Classroom 12th NEET 2024'
when length(batch)<5 and batch like '%AJ%' then 'Classroom 11th JEE 2024'
when length(batch)<5 and batch like '%AN%' then 'Classroom 11th NEET 2024'
when length(batch)<5 and batch like '%PJ%' then 'Classroom Dropper JEE 2024'
when length(batch)<5 and batch like '%YN%' then 'Classroom Dropper NEET 2024'
when length(batch)<5 and batch like '%UF%' then 'Classroom 10th Foundation 2024'
when length(batch)<5 and batch like '%NF%' then 'Classroom 9th Foundation 2024'
else course end as actual_course,

case 
    when course like '%D2%' or course like '%T2%' then '1'
    when length(batch)<5 then substring(batch,3,1)
    else substring(batch,6,1)
end as phase,

case
    when center like '%Panchkula Vidyapeeth%' then 'Panchkula'
    else center end as test_center
from offline.offline_students_humming
where 
    center like '%Panchkula%') as hm
on hm.CLASS_RECORDED_MOBILE_NO=u.primarynumber

join

(select 
    userscore AS "subject_marks", _id, subject_id 
from pw_subjectwise_results_temp) as sbr
on sbr._id=re.result_id

left join

(select _id,name "subject_name" 
from subjects) as sub
on sub._id=sbr.subject_id

left join

(select unique_id,name "qbg_subject_name" 
from qbg.subjects) as qsub
on qsub.unique_id=sbr.subject_id
)

group by 1,2,3,4,5,6,7,8,9,10,11,20,21
)


select DISTINCT
    student_name, reg_no, REPLACE(batch_name, 'Vidyapeeth ', '') as batch_name,
    REPLACE(test_name, 'Panchkula ', '') AS test_name, test_date, 
    ROUND(sum(CASE WHEN present_absent ='P' THEN 1 ELSE 0 END) OVER (partition by schedule_reg_no,test_date)*1.0/count(schedule_reg_no) OVER(partition by schedule_reg_no,test_date),3)*100 AS att_pct_till_test_date,
    attemptedquestions, correctquestions, accuracy, total_marks,
    physics, chemistry, maths, botany, ZOOLOGY, Biology, english,SocialStudies
FROM
CBT_MST left join master
ON CBT_MST.reg_no = master.SCHEDULE_REG_NO AND
UPPER(CBT_MST.new_batch) = UPPER(master.batch_name)
WHERE
    schedule_date <= test_date::DATE
ORDER BY 
    batch_name,
    student_name,
    test_date DESC












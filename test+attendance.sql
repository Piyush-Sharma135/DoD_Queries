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

extended AS (

SELECT 
    osh.reg_no, osh.student_name, hr.studentid, 
    osh.gender, osh.pincode, osh.marks_in_10th,
    CASE 
        WHEN osh.batch ilike '29-%' then CONCAT('Vidyapeeth ',osh.batch)
        WHEN osh.batch IS NOT NULL AND LEN(osh.batch) > 0 THEN CONCAT('Vidyapeeth ', osh.batch)
        END AS new_batch,
   
    ht.name as test_name, tc.name AS test_category_name, ht.starttime::date as Test_Date,
    ht._id as test_id, hr._id as hevo_result_id, swr._id as swr_result_id, hr.rank AS Test_Rank,
   
    qsub.name AS subject_name, swr.userscore AS subject_marks, 
   
    hr.completed as completed, hr.attemptedquestions AS attempted_questions, hr.correctquestions AS correct_questions, hr.accuracy AS accuracy, 
    hr.userscore as total_marks, ht.totalmarks AS Max_Marks
    
FROM 
Offline.offline_students_humming osh 

LEFT JOIN users u 
on osh.class_recorded_mobile_no = u.primarynumber

LEFT JOIN hevo_results hr
on u._id = hr.studentid

LEFT JOIN hevo_tests ht 
ON hr.testid = ht._id 

LEFT JOIN test_categories tc
ON tc._id = ht.categoryid

LEFT JOIN test_category_modes tcm
ON ht.categorymodeids[0] = tcm._id

LEFT JOIN pw_subjectwise_results swr
ON hr._id = swr._id

LEFT JOIN hevo_subjects hsub 
ON swr.subject_id = hsub._id

LEFT JOIN qbg.subjects qsub
ON qsub.unique_id = swr.subject_id


where 
osh.center like '%Panchkula%' AND

ht.type = 'Mock' AND
ht.status = 'Active' AND

tcm.type = 'Offline'
),

pivot_result AS (

SELECT  
    REG_NO, INITCAP(Student_Name) AS student_name, new_batch, Test_Name, test_date,
    gender,  COALESCE(pincode::int, 0) AS pincode,  COALESCE(marks_in_10th::int, 0) AS marks_in_10th,
    COALESCE(physics,0)as physics, COALESCE(chemistry,0) as chemistry, COALESCE(maths,0) as maths,
    COALESCE(botany,0) as botany, COALESCE(zoology,0) as zoology,
    COALESCE(biology,0) as biology, COALESCE(English,0) as English, COALESCE(SST,0) as SST, COALESCE(MAT,0) as MAT,
    completed, Attempted_Questions, correct_questions, Accuracy,
    total_marks, max_marks, Test_Rank
    FROM
(
    SELECT 
        reg_no, student_name, new_Batch, test_name, test_date,
        gender, pincode, marks_in_10th,
        subject_name, subject_marks, 
        completed, attempted_questions, correct_questions, accuracy,
        total_marks, max_marks, Test_Rank
    FROM extended
)
PIVOT 
(max(subject_marks) FOR subject_name in ('Physics', 'Chemistry', 'Maths', 'Botany', 'Zoology', 'Biology', 'English' ,'SST', 'MAT'))

)

select DISTINCT
    student_name, reg_no, REPLACE(batch_name, 'Vidyapeeth ', '') as batch_name, REPLACE(test_name, 'Panchkula ', '') AS test_name, test_date, 
    ROUND(sum(CASE WHEN present_absent ='P' THEN 1 ELSE 0 END) OVER (partition by schedule_reg_no,test_date)*1.0/count(schedule_reg_no) OVER(partition by schedule_reg_no,test_date),3)*100 AS att_pct_till_test_date,
    total_marks, max_marks, completed, attempted_questions,correct_questions, accuracy,
    Physics, Chemistry, Maths, Botany, ZOOLOGY, Biology, English, SST, MAT,
    gender, pincode, marks_in_10th
FROM
pivot_result left join master
ON pivot_result.reg_no = master.SCHEDULE_REG_NO AND
UPPER(pivot_result.new_batch) = UPPER(master.batch_name)
WHERE
    schedule_date <= test_date::DATE
ORDER BY 
    batch_name,
    reg_no,
    test_date DESC

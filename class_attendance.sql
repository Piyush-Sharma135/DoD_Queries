WITH stu_hum AS (
SELECT 
    reg_no, student_name, CONCAT(class, stream) AS class_stream,
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
WHERE
    punchdatetime::DATE <= CURRENT_DATE::DATE AND 
    punchdatetime::DATE >= CURRENT_DATE::DATE - 6 
),

punch_logs AS (
SELECT 
    stu_hum.reg_no AS punch_reg_no, 
    stu_hum.student_name AS punch_student_name,
    stu_hum.class_stream, stu_hum.newbatch,
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
    stu_hum.reg_no as schedule_reg_no, stu_hum.newbatch, stu_hum.class_stream,
    bch.name AS batch_name,
    DATE(bsch.date) AS schedule_date, TO_CHAR(bsch.starttime + interval '5 hour' + interval '30 minute', 'HH24:MI:SS') as starttime,
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
    schedule_date >= CURRENT_DATE -6 AND schedule_date <= CURRENT_DATE AND
    UPPER(bsch.topic) NOT IN ('TEST', 'DOUBT','NO', 'EXTRA', 'CANCEL', 'NO CLASS', 'MODULE', 'PDF') AND 
    bsch.status != 'Inactive' AND 
    bsch.isdppnotes='False' AND 
    bsch.isdppvideos='False' AND
    isnull(UPPER(topic),'') not ilike '%*%' AND
    sub.name NOT IN ('Notices','PYQ Discussion','Self Awareness')
),

master AS(
SELECT 
    batch_name, batch_schedule.class_stream, schedule_date,
    punch_reg_no, punch_student_name, punch_date, punchtime,
    starttime, schedule_reg_no, rn_sch
FROM 
    batch_schedule LEFT JOIN punch_logs 
ON 
    batch_schedule.schedule_reg_no = punch_logs.punch_reg_no
AND 
    batch_schedule.schedule_date = punch_logs.punch_date
AND
    UPPER(batch_schedule.batch_name) = UPPER(punch_logs.newbatch)
)

SELECT * FROM master
WHERE rn_sch =1




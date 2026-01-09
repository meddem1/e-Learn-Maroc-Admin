-- 1. Create Pluggable Database (PDB)
CREATE PLUGGABLE DATABASE elearn_pdb 
ADMIN USER admin_elearn IDENTIFIED BY password123
FILE_NAME_CONVERT = ('/u01/app/oracle/oradata/CDB/pdbseed/', '/u01/app/oracle/oradata/CDB/elearn_pdb/');

-- 2. Open the PDB
ALTER PLUGGABLE DATABASE elearn_pdb OPEN;
ALTER SESSION SET CONTAINER = elearn_pdb;

-- 3. Create Tablespaces
-- Tablespace for permanent data (Courses, Users)
CREATE TABLESPACE TS_ELEARN_DATA DATAFILE 'elearn_data.dbf' SIZE 100M AUTOEXTEND ON;

-- Tablespace for Exams (High transaction area)
CREATE TABLESPACE TS_ELEARN_EXAMS DATAFILE 'elearn_exams.dbf' SIZE 200M AUTOEXTEND ON;


--------------partie-2----UNDO------------------
-- 4. Adjust UNDO Retention for long exam transactions
-- (Should be done at CDB level but affects PDB)
ALTER SYSTEM SET UNDO_RETENTION = 7200; -- 2 hours for long exams

-- 5. Create Profile to limit resources per student
CREATE PROFILE student_profile LIMIT
    SESSIONS_PER_USER 1
    CPU_PER_SESSION 10000        -- Max CPU time
    IDLE_TIME 15                -- Disconnect after 15 mins of inactivity
    CONNECT_TIME 120;           -- Limit session to 2 hours (exam duration)

-------------------partie-3---creationt-des-tables-------------
-- 6. Table for Users (in General Tablespace)
CREATE TABLE Users (
    user_id NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    email VARCHAR2(100) UNIQUE,
    role VARCHAR2(20) CHECK (role IN ('Student', 'Instructor'))
) TABLESPACE TS_ELEARN_DATA;

-- 7. Table for Exams (in Exam Tablespace)
CREATE TABLE Exams (
    exam_id NUMBER PRIMARY KEY,
    title VARCHAR2(200),
    start_time TIMESTAMP,
    end_time TIMESTAMP
) TABLESPACE TS_ELEARN_EXAMS;

-- 8. Table for Student Answers (High Traffic)
CREATE TABLE Exam_Answers (
    answer_id NUMBER PRIMARY KEY,
    exam_id NUMBER REFERENCES Exams(exam_id),
    student_id NUMBER REFERENCES Users(user_id),
    answer_text CLOB,
    submission_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) TABLESPACE TS_ELEARN_EXAMS;

------------------partie-4------Backup----------------
# Script de sauvegarde (RMAN)
rman target /
RMAN> BACKUP PLUGGABLE DATABASE elearn_pdb TAG 'BEFORE_EXAM_SESSION';

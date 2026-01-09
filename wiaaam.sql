
1. Création de la PDB dédiée
sql
-- Se connecter en CDB$ROOT
sqlplus / as sysdba

-- Créer la PDB
CREATE PLUGGABLE DATABASE ELEARN_PDB 
ADMIN USER elearn_admin IDENTIFIED BY StrongPass123
FILE_NAME_CONVERT=('/opt/oracle/oradata/CDB1/pdbseed/', '/opt/oracle/oradata/CDB1/ELEARN_PDB/')
DEFAULT TABLESPACE USERS;

-- Ouvrir la PDB
ALTER PLUGGABLE DATABASE ELEARN_PDB OPEN;

-- Sauvegarder la configuration
ALTER PLUGGABLE DATABASE ELEARN_PDB SAVE STATE;
2. Gestion des tablespaces
sql
-- Se connecter à la PDB
ALTER SESSION SET CONTAINER=ELEARN_PDB;

-- Tablespace pour les utilisateurs
CREATE TABLESPACE TS_USERS 
DATAFILE '/opt/oracle/oradata/CDB1/ELEARN_PDB/users01.dbf' 
SIZE 10G AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED
EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;

-- Tablespace pour les examens (performances)
CREATE TABLESPACE TS_EXAMS 
DATAFILE '/opt/oracle/oradata/CDB1/ELEARN_PDB/exams01.dbf' 
SIZE 20G AUTOEXTEND ON NEXT 2G MAXSIZE UNLIMITED
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M
SEGMENT SPACE MANAGEMENT AUTO;

-- Tablespace UNDO dédié
CREATE UNDO TABLESPACE UNDOTBS_EXAMS 
DATAFILE '/opt/oracle/oradata/CDB1/ELEARN_PDB/undotbs_exams.dbf' 
SIZE 10G AUTOEXTEND ON NEXT 1G;
3. Adapter le UNDO aux transactions longues
sql
-- Paramètres UNDO pour transactions longues
ALTER SYSTEM SET UNDO_RETENTION = 10800 SCOPE=BOTH; -- 3 heures
ALTER SYSTEM SET UNDO_TABLESPACE = UNDOTBS_EXAMS SCOPE=BOTH;

-- Optimisation UNDO
ALTER SYSTEM SET UNDO_MANAGEMENT = AUTO SCOPE=SPFILE;
ALTER SYSTEM SET UNDO_SUPPRESS_ERRORS = TRUE;

-- Redémarrer si nécessaire
SHUTDOWN IMMEDIATE;
STARTUP;
4. Profils et limitation des ressources
sql
-- Créer le profil pour étudiants
CREATE PROFILE ELEARN_STUDENT LIMIT
SESSIONS_PER_USER 1          -- 1 session à la fois
CPU_PER_SESSION UNLIMITED
CPU_PER_CALL 600000          -- 10 minutes max par opération
CONNECT_TIME 240             -- 4 heures max de connexion
IDLE_TIME 30                 -- 30 min d'inactivité
LOGICAL_READS_PER_SESSION UNLIMITED
PRIVATE_SGA 50M
COMPOSITE_LIMIT UNLIMITED;

-- Profil pour examens
CREATE PROFILE ELEARN_EXAM LIMIT
SESSIONS_PER_USER 1
CPU_PER_SESSION UNLIMITED
CPU_PER_CALL 3600000         -- 1 heure pour les transactions d'examen
CONNECT_TIME 180             -- 3 heures d'examen
IDLE_TIME 15                 -- 15 min max d'inactivité
LOGICAL_READS_PER_SESSION DEFAULT
PRIVATE_SGA 100M;

-- Création des utilisateurs
CREATE USER elearn_student1 IDENTIFIED BY "StudentPass123"
DEFAULT TABLESPACE TS_USERS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_USERS
QUOTA 2G ON TS_EXAMS
PROFILE ELEARN_STUDENT;

CREATE USER exam_user IDENTIFIED BY "ExamPass456"
DEFAULT TABLESPACE TS_EXAMS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_EXAMS
PROFILE ELEARN_EXAM;
5. Sauvegarde automatisée avant chaque session d'examen
bash
#!/bin/bash
# /scripts/backup_exam_session.sh
#!/bin/bash
BACKUP_DIR="/backup/oracle/ELEARN_PDB"
DATE=$(date +"%Y%m%d_%H%M%S")
SESSION_NAME=$1

# Vérifier l'argument session
if [ -z "$SESSION_NAME" ]; then
    echo "Usage: $0 <session_name>"
    exit 1
fi

# Exporter les variables d'environnement Oracle
export ORACLE_HOME=/opt/oracle/product/19c/dbhome_1
export ORACLE_SID=CDB1
export PATH=$ORACLE_HOME/bin:$PATH

# Créer le répertoire de backup
mkdir -p $BACKUP_DIR/$SESSION_NAME

# 1. Backup RMAN complet
rman target / <<EOF
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
    BACKUP AS COMPRESSED BACKUPSET PLUGGABLE DATABASE ELEARN_PDB 
    TAG 'EXAM_${SESSION_NAME}_${DATE}'
    FORMAT '${BACKUP_DIR}/${SESSION_NAME}/full_%d_%T_%U.bkp';
    RELEASE CHANNEL ch1;
}
EOF

# 2. Export Data Pump (logique)
expdp \"/ as sysdba\" \
DIRECTORY=DATA_PUMP_DIR \
DUMPFILE=elearn_exam_${SESSION_NAME}_${DATE}.dmp \
LOGFILE=elearn_exam_${SESSION_NAME}_${DATE}.log \
SCHEMAS=ELEARN_STUDENT1,EXAM_USER \
COMPRESSION=ALL \
PARALLEL=4

# 3. Backup des fichiers de contrôle
rman target / <<EOF
BACKUP CURRENT CONTROLFILE FOR STANDBY 
FORMAT '${BACKUP_DIR}/${SESSION_NAME}/control_%d_%T_%U.ctl';
EOF

# 4. Journalisation
echo "Backup completed for session: $SESSION_NAME at $DATE" >> /var/log/oracle_exam_backup.log

# 5. Nettoyage anciens backups (garder 7 jours)
find $BACKUP_DIR -name "*.bkp" -mtime +7 -exec rm {} \;
Script de planification automatique
bash
# /etc/cron.d/oracle-exam-backup
# Exécuter 30 minutes avant chaque session d'examen
# Format: 30 08 * * 1,3,5 root /scripts/backup_exam_session.sh "Session_Matin"
# Format: 30 13 * * 2,4 root /scripts/backup_exam_session.sh "Session_ApresMidi"
Création du Directory Object pour Data Pump
sql
-- Dans la PDB
CREATE OR REPLACE DIRECTORY DATA_PUMP_DIR AS '/backup/oracle/datapump';
GRANT READ, WRITE ON DIRECTORY DATA_PUMP_DIR TO SYSTEM;
Monitoring et vérification
sql
-- Vérifier l'espace UNDO
SELECT tablespace_name, status, sum(bytes)/1024/1024 "Size MB"
FROM dba_undo_extents 
GROUP BY tablespace_name, status;

-- Vérifier les sessions actives
SELECT username, profile, resource_name, limit 
FROM dba_profiles 
WHERE profile LIKE 'ELEARN%';

-- Vérifier l'état des tablespaces
SELECT tablespace_name, file_name, bytes/1024/1024 "Size MB", autoextensible
FROM dba_data_files 
WHERE tablespace_name LIKE 'TS_%' OR tablespace_name LIKE 'UNDOTBS%';
Commandes Linux importantes
bash
# Vérifier l'espace disque
df -h /backup

# Vérifier les processus Oracle
ps -ef | grep pmon

# Vérifier les logs
tail -f /opt/oracle/diag/rdbms/*/trace/alert*.log

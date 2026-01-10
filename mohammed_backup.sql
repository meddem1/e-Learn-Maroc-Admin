--etape-1:-------
------J'ai créé ce Job pour notifier Oracle de l'exécution automatique du script Bash-----
------qui contient les commandes RMAN nécessaires à la sauvegarde"---------
BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name        => 'PRE_EXAM_BACKUP_JOB',
    job_type        => 'EXECUTABLE',
    job_action      => '/home/oracle/scripts/backup_pdb.sh', 
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=7; BYMINUTE=30',     
    enabled         => TRUE
  );
END;
/
  
-----etape-2----------
#!/bin/bash
export ORACLE_SID=orcl
rman target / <<EOF
RUN {
    BACKUP PLUGGABLE DATABASE eLearn_PDB FORMAT '/backups/exam_%d_%T.bkp';
}
EXIT;
EOF

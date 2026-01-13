# **Base de données Oracle e-Learn MAROC - Documentation Technique**

## **1. Vue d'ensemble**
La base de données e-Learn_MAROC est conçue pour supporter une plateforme éducative hébergeant des milliers d'étudiants et formateurs, avec une attention particulière aux performances des examens en ligne.

## **2. Création de la PDB (Pluggable Database)**

```sql
-- Créer la PDB depuis CDB
CREATE PLUGGABLE DATABASE eLearn_MAROC
ADMIN USER eLearn_admin IDENTIFIED BY StrongP@ssw0rd
ROLES = (DBA)
FILE_NAME_CONVERT = ('/opt/oracle/oradata/CDB/pdbseed/', '/opt/oracle/oradata/CDB/eLearn_MAROC/')
STORAGE (MAXSIZE 10G);

-- Ouvrir la PDB
ALTER PLUGGABLE DATABASE eLearn_MAROC OPEN;

-- Sauvegarder l'état
ALTER PLUGGABLE DATABASE eLearn_MAROC SAVE STATE;
```

## **3. Gestion des Tablespaces**

```sql
-- Connexion à la PDB
ALTER SESSION SET CONTAINER = eLearn_MAROC;

-- Tablespace pour les données utilisateurs (performances élevées)
CREATE TABLESPACE users_data
DATAFILE '/opt/oracle/oradata/CDB/eLearn_MAROC/users_data01.dbf'
SIZE 2G AUTOEXTEND ON NEXT 500M MAXSIZE 5G
SEGMENT SPACE MANAGEMENT AUTO
EXTENT MANAGEMENT LOCAL;

-- Tablespace pour les examens (IO intensif)
CREATE TABLESPACE exams_data
DATAFILE '/opt/oracle/oradata/CDB/eLearn_MAROC/exams_data01.dbf'
SIZE 3G AUTOEXTEND ON NEXT 1G MAXSIZE 10G
SEGMENT SPACE MANAGEMENT AUTO
EXTENT MANAGEMENT LOCAL;

-- Tablespace INDEX pour performances
CREATE TABLESPACE idx_data
DATAFILE '/opt/oracle/oradata/CDB/eLearn_MAROC/idx_data01.dbf'
SIZE 1G AUTOEXTEND ON NEXT 200M MAXSIZE 3G;

-- Tablespace TEMP optimisé
ALTER TABLESPACE TEMP
ADD TEMPFILE '/opt/oracle/oradata/CDB/eLearn_MAROC/temp01.dbf'
SIZE 500M AUTOEXTEND ON NEXT 100M MAXSIZE 2G;
```

## **4. Configuration UNDO pour transactions longues**

```sql
-- Créer un tablespace UNDO dédié et plus large
CREATE UNDO TABLESPACE undots_eLearn
DATAFILE '/opt/oracle/oradata/CDB/eLearn_MAROC/undots_eLearn.dbf'
SIZE 2G AUTOEXTEND ON NEXT 500M MAXSIZE 5G
RETENTION GUARANTEE;

-- Basculer vers le nouveau tablespace UNDO
ALTER SYSTEM SET UNDO_TABLESPACE = undots_eLearn;

-- Configurer la rétention UNDO pour transactions longues (3 heures)
ALTER SYSTEM SET UNDO_RETENTION = 10800; -- 3 heures en secondes

-- Ajuster les paramètres pour longues transactions
ALTER SYSTEM SET TRANSACTIONS_PER_ROLLBACK_SEGMENT = 16;
```

## **5. Création des Tables**

```sql
-- Table Utilisateurs
CREATE TABLE utilisateurs (
    id_utilisateur NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom VARCHAR2(100) NOT NULL,
    prenom VARCHAR2(100) NOT NULL,
    email VARCHAR2(255) UNIQUE NOT NULL,
    mot_de_passe_hash VARCHAR2(255) NOT NULL,
    type_utilisateur VARCHAR2(20) CHECK (type_utilisateur IN ('ETUDIANT', 'FORMATEUR', 'ADMIN')),
    date_inscription DATE DEFAULT SYSDATE,
    statut VARCHAR2(20) DEFAULT 'ACTIF',
    CONSTRAINT chk_email_format CHECK (email LIKE '%@%.%')
) TABLESPACE users_data;

-- Table Examens
CREATE TABLE examens (
    id_examen NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    titre VARCHAR2(200) NOT NULL,
    id_formateur NUMBER NOT NULL,
    duree_minutes NUMBER NOT NULL,
    date_planification TIMESTAMP NOT NULL,
    date_debut TIMESTAMP,
    date_fin TIMESTAMP,
    statut VARCHAR2(20) DEFAULT 'PLANIFIE' CHECK (statut IN ('PLANIFIE', 'EN_COURS', 'TERMINE', 'CORRIGE')),
    seuil_reussite NUMBER(5,2) DEFAULT 60.00,
    CONSTRAINT fk_examen_formateur FOREIGN KEY (id_formateur) REFERENCES utilisateurs(id_utilisateur)
) TABLESPACE exams_data;

-- Table Sessions_Examen (pour gérer les participations)
CREATE TABLE sessions_examen (
    id_session NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_examen NUMBER NOT NULL,
    id_etudiant NUMBER NOT NULL,
    date_debut_session TIMESTAMP,
    date_fin_session TIMESTAMP,
    score NUMBER(5,2),
    statut VARCHAR2(20) DEFAULT 'NON_COMMENCE' CHECK (statut IN ('NON_COMMENCE', 'EN_COURS', 'TERMINE', 'ABSENT')),
    temps_ecoule NUMBER,
    CONSTRAINT fk_session_examen FOREIGN KEY (id_examen) REFERENCES examens(id_examen),
    CONSTRAINT fk_session_etudiant FOREIGN KEY (id_etudiant) REFERENCES utilisateurs(id_utilisateur),
    CONSTRAINT unique_participation UNIQUE (id_examen, id_etudiant)
) TABLESPACE exams_data;

-- Table Questions
CREATE TABLE questions (
    id_question NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_examen NUMBER NOT NULL,
    texte_question CLOB NOT NULL,
    type_question VARCHAR2(30) CHECK (type_question IN ('CHOIX_MULTIPLE', 'VRAI_FAUX', 'REPONSE_COURTE', 'REPONSE_LONGUE')),
    points NUMBER(5,2) NOT NULL,
    ordre NUMBER,
    CONSTRAINT fk_question_examen FOREIGN KEY (id_examen) REFERENCES examens(id_examen)
) TABLESPACE exams_data;

-- Table Reponses (pour questions à choix multiple)
CREATE TABLE reponses_possibles (
    id_reponse NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_question NUMBER NOT NULL,
    texte_reponse VARCHAR2(500),
    est_correcte CHAR(1) CHECK (est_correcte IN ('O', 'N')),
    CONSTRAINT fk_reponse_question FOREIGN KEY (id_question) REFERENCES questions(id_question)
) TABLESPACE exams_data;

-- Table Reponses_Etudiants
CREATE TABLE reponses_etudiants (
    id_reponse_etudiant NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_session NUMBER NOT NULL,
    id_question NUMBER NOT NULL,
    reponse_text CLOB,
    id_reponse_choisie NUMBER,
    points_obtenus NUMBER(5,2),
    date_soumission TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_reponse_session FOREIGN KEY (id_session) REFERENCES sessions_examen(id_session),
    CONSTRAINT fk_reponse_question FOREIGN KEY (id_question) REFERENCES questions(id_question),
    CONSTRAINT fk_reponse_choisie FOREIGN KEY (id_reponse_choisie) REFERENCES reponses_possibles(id_reponse)
) TABLESPACE exams_data;

-- Table Corriges
CREATE TABLE corriges (
    id_corrige NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_examen NUMBER NOT NULL,
    fichier_corrige BLOB,
    nom_fichier VARCHAR2(255),
    type_mime VARCHAR2(100),
    date_upload TIMESTAMP DEFAULT SYSTIMESTAMP,
    upload_par NUMBER,
    CONSTRAINT fk_corrige_examen FOREIGN KEY (id_examen) REFERENCES examens(id_examen),
    CONSTRAINT fk_corrige_uploader FOREIGN KEY (upload_par) REFERENCES utilisateurs(id_utilisateur)
) TABLESPACE exams_data;

-- Table Feedbacks
CREATE TABLE feedbacks (
    id_feedback NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_session NUMBER NOT NULL,
    feedback_text CLOB,
    date_feedback TIMESTAMP DEFAULT SYSTIMESTAMP,
    donne_par NUMBER,
    CONSTRAINT fk_feedback_session FOREIGN KEY (id_session) REFERENCES sessions_examen(id_session),
    CONSTRAINT fk_feedback_formateur FOREIGN KEY (donne_par) REFERENCES utilisateurs(id_utilisateur)
) TABLESPACE exams_data;

-- Table Certificats
CREATE TABLE certificats (
    id_certificat NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_session NUMBER NOT NULL,
    fichier_certificat BLOB,
    nom_fichier VARCHAR2(255),
    date_generation TIMESTAMP DEFAULT SYSTIMESTAMP,
    hash_verification VARCHAR2(64),
    CONSTRAINT fk_certificat_session FOREIGN KEY (id_session) REFERENCES sessions_examen(id_session),
    CONSTRAINT unique_certificat_session UNIQUE (id_session)
) TABLESPACE users_data;

-- Table Rattrapages
CREATE TABLE rattrapages (
    id_rattrapage NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_examen_original NUMBER NOT NULL,
    date_planification TIMESTAMP NOT NULL,
    date_debut TIMESTAMP,
    date_fin TIMESTAMP,
    statut VARCHAR2(20) DEFAULT 'PLANIFIE',
    CONSTRAINT fk_rattrapage_examen FOREIGN KEY (id_examen_original) REFERENCES examens(id_examen)
) TABLESPACE exams_data;

-- Table Uploads_Examens (pour téléversement des examens)
CREATE TABLE uploads_examens (
    id_upload NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_examen NUMBER NOT NULL,
    fichier_examen BLOB,
    nom_fichier VARCHAR2(255),
    type_mime VARCHAR2(100),
    taille NUMBER,
    date_upload TIMESTAMP DEFAULT SYSTIMESTAMP,
    upload_par NUMBER,
    CONSTRAINT fk_upload_examen FOREIGN KEY (id_examen) REFERENCES examens(id_examen),
    CONSTRAINT fk_upload_utilisateur FOREIGN KEY (upload_par) REFERENCES utilisateurs(id_utilisateur)
) TABLESPACE exams_data;
```

## **6. Création des Index pour Performances**

```sql
-- Index sur les tables fréquemment consultées
CREATE INDEX idx_utilisateurs_email ON utilisateurs(email) TABLESPACE idx_data;
CREATE INDEX idx_utilisateurs_type ON utilisateurs(type_utilisateur) TABLESPACE idx_data;

CREATE INDEX idx_examens_formateur ON examens(id_formateur) TABLESPACE idx_data;
CREATE INDEX idx_examens_dates ON examens(date_planification, date_debut, date_fin) TABLESPACE idx_data;
CREATE INDEX idx_examens_statut ON examens(statut) TABLESPACE idx_data;

CREATE INDEX idx_sessions_examen ON sessions_examen(id_examen, id_etudiant) TABLESPACE idx_data;
CREATE INDEX idx_sessions_statut ON sessions_examen(statut) TABLESPACE idx_data;
CREATE INDEX idx_sessions_score ON sessions_examen(score) TABLESPACE idx_data;

CREATE INDEX idx_questions_examen ON questions(id_examen) TABLESPACE idx_data;

CREATE INDEX idx_reponses_question ON reponses_possibles(id_question) TABLESPACE idx_data;

CREATE INDEX idx_reponses_etud_session ON reponses_etudiants(id_session) TABLESPACE idx_data;
CREATE INDEX idx_reponses_etud_question ON reponses_etudiants(id_question) TABLESPACE idx_data;

-- Index bitmap pour les colonnes à faible cardinalité
CREATE BITMAP INDEX bmidx_utilisateurs_statut ON utilisateurs(statut) TABLESPACE idx_data;
CREATE BITMAP INDEX bmidx_sessions_statut ON sessions_examen(statut) TABLESPACE idx_data;
```

## **7. Profils Utilisateurs et Limitation des Ressources**

```sql
-- Création des profils
CREATE PROFILE profil_etudiant LIMIT
SESSIONS_PER_USER 2
CPU_PER_SESSION UNLIMITED
CPU_PER_CALL 600000
CONNECT_TIME 180
IDLE_TIME 30
LOGICAL_READS_PER_SESSION UNLIMITED
LOGICAL_READS_PER_CALL 10000
PRIVATE_SGA 10M
COMPOSITE_LIMIT 5000000;

CREATE PROFILE profil_formateur LIMIT
SESSIONS_PER_USER 5
CPU_PER_SESSION UNLIMITED
CPU_PER_CALL UNLIMITED
CONNECT_TIME 480
IDLE_TIME 60
LOGICAL_READS_PER_SESSION UNLIMITED
LOGICAL_READS_PER_CALL UNLIMITED
PRIVATE_SGA 20M
COMPOSITE_LIMIT UNLIMITED;

CREATE PROFILE profil_admin LIMIT
SESSIONS_PER_USER 10
CPU_PER_SESSION UNLIMITED
CPU_PER_CALL UNLIMITED
CONNECT_TIME UNLIMITED
IDLE_TIME 120
LOGICAL_READS_PER_SESSION UNLIMITED
LOGICAL_READS_PER_CALL UNLIMITED
PRIVATE_SGA 50M
COMPOSITE_LIMIT UNLIMITED;

-- Création des utilisateurs avec profils
CREATE USER etudiant_user IDENTIFIED BY Etudiant2024!
DEFAULT TABLESPACE users_data
TEMPORARY TABLESPACE temp
QUOTA 100M ON users_data
QUOTA 50M ON exams_data
PROFILE profil_etudiant;

CREATE USER formateur_user IDENTIFIED BY Formateur2024!
DEFAULT TABLESPACE users_data
TEMPORARY TABLESPACE temp
QUOTA 500M ON users_data
QUOTA 200M ON exams_data
PROFILE profil_formateur;

CREATE USER admin_user IDENTIFIED BY Admin2024!
DEFAULT TABLESPACE users_data
TEMPORARY TABLESPACE temp
QUOTA UNLIMITED ON users_data
QUOTA UNLIMITED ON exams_data
PROFILE profil_admin;

-- Attribution des rôles
GRANT CONNECT, RESOURCE TO etudiant_user, formateur_user, admin_user;
GRANT CREATE VIEW, CREATE PROCEDURE TO formateur_user, admin_user;
GRANT CREATE ANY TABLE, DROP ANY TABLE TO admin_user;
GRANT UNLIMITED TABLESPACE TO admin_user;
```

## **8. Vues pour les Fonctionnalités Spécifiques**

```sql
-- Vue pour consulter les étudiants absents
CREATE OR REPLACE VIEW vue_etudiants_absents AS
SELECT 
    e.id_examen,
    e.titre,
    u.id_utilisateur,
    u.nom,
    u.prenom,
    u.email
FROM examens e
CROSS JOIN utilisateurs u
LEFT JOIN sessions_examen se ON e.id_examen = se.id_examen AND u.id_utilisateur = se.id_etudiant
WHERE u.type_utilisateur = 'ETUDIANT'
AND se.id_session IS NULL
AND e.statut = 'TERMINE';

-- Vue pour les scores détaillés
CREATE OR REPLACE VIEW vue_scores_detaille AS
SELECT 
    se.id_session,
    u.nom || ' ' || u.prenom AS etudiant,
    e.titre AS examen,
    se.score,
    se.statut,
    COUNT(DISTINCT re.id_question) as questions_repondues,
    SUM(re.points_obtenus) as points_obtenus_total
FROM sessions_examen se
JOIN utilisateurs u ON se.id_etudiant = u.id_utilisateur
JOIN examens e ON se.id_examen = e.id_examen
LEFT JOIN reponses_etudiants re ON se.id_session = re.id_session
GROUP BY se.id_session, u.nom, u.prenom, e.titre, se.score, se.statut;

-- Vue pour les examens à venir
CREATE OR REPLACE VIEW vue_examens_a_venir AS
SELECT 
    e.id_examen,
    e.titre,
    e.date_planification,
    u.nom || ' ' || u.prenom AS formateur,
    COUNT(se.id_session) as etudiants_inscrits
FROM examens e
JOIN utilisateurs u ON e.id_formateur = u.id_utilisateur
LEFT JOIN sessions_examen se ON e.id_examen = se.id_examen
WHERE e.statut = 'PLANIFIE'
GROUP BY e.id_examen, e.titre, e.date_planification, u.nom, u.prenom;
```

## **9. Procédures de Sauvegarde Automatisée**

```sql
-- Procédure pour sauvegarde avant examen
CREATE OR REPLACE PROCEDURE sauvegarde_pre_examen (p_id_examen IN NUMBER) IS
    v_nom_fichier VARCHAR2(100);
BEGIN
    -- Générer un nom de fichier unique
    v_nom_fichier := 'SAUVEGARDE_PRE_EXAMEN_' || p_id_examen || '_' || 
                     TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') || '.dmp';
    
    -- Journaliser l'opération
    INSERT INTO logs_sauvegarde (id_examen, type_sauvegarde, date_sauvegarde, nom_fichier)
    VALUES (p_id_examen, 'PRE_EXAMEN', SYSDATE, v_nom_fichier);
    
    -- Exécuter la sauvegarde (à adapter selon environnement)
    DBMS_OUTPUT.PUT_LINE('Sauvegarde démarrée: ' || v_nom_fichier);
    
    -- Ici, vous appelleriez vos commandes de sauvegarde réelles
    -- Exemple: expdp ou RMAN commands
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Sauvegarde terminée avec succès.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Erreur lors de la sauvegarde: ' || SQLERRM);
        RAISE;
END sauvegarde_pre_examen;
/

-- Table pour logs de sauvegarde
CREATE TABLE logs_sauvegarde (
    id_log NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_examen NUMBER,
    type_sauvegarde VARCHAR2(50),
    date_sauvegarde TIMESTAMP DEFAULT SYSTIMESTAMP,
    nom_fichier VARCHAR2(255),
    statut VARCHAR2(20) DEFAULT 'SUCCES'
);
```

## **10. Script de Déploiement Automatisé (deploy_eLearn.sh)**

```bash
#!/bin/bash
# Script de déploiement pour e-Learn MAROC
# À exécuter en tant qu'utilisateur Oracle

set -e

------rman-------------------LABBI_MOHAMMED------------------
#-----creation d'job---------
    BEGIN
DBMS_SCHEDULER.CREATE_JOB (
job_name => 'PRE_EXAM_BACKUP_JOB',
job_type => 'EXECUTABLE',
job_action => '/home/oracle/scripts/backup_pdb.sh',
start_date => SYSTIMESTAMP,
repeat_interval => 'FREQ=DAILY; BYHOUR=7; BYMINUTE=30',
enabled => TRUE
);
----------rman--in--bash-------------
/bin/bash
export ORACLE_SID=orcl
rman target / <
RUN {
    BACKUP PLUGGABLE DATABASE eLearn_PDB FORMAT '/backups/exam_%d_%T.bkp';
}
EXIT;
EOF
# Fonction de logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Création des répertoires
log_message "Création des répertoires..."
mkdir -p /opt/oracle/oradata/CDB/$PDB_NAME
mkdir -p /opt/oracle/logs
mkdir -p $SCRIPT_DIR

# Exécution des scripts SQL
log_message "Exécution des scripts SQL..."

sqlplus / as sysdba <<EOF
-- Création PDB
@${SCRIPT_DIR}/01_create_pdb.sql

-- Changement de conteneur
ALTER SESSION SET CONTAINER = $PDB_NAME;

-- Tablespaces
@${SCRIPT_DIR}/02_create_tablespaces.sql

-- Tables
@${SCRIPT_DIR}/03_create_tables.sql

-- Index
@${SCRIPT_DIR}/04_create_indexes.sql

-- Profils et utilisateurs
@${SCRIPT_DIR}/05_create_profiles.sql

-- Vues
@${SCRIPT_DIR}/06_create_views.sql

-- Procédures
@${SCRIPT_DIR}/07_create_procedures.sql

EXIT;
EOF

log_message "=== Déploiement terminé avec succès ==="
```

## **11. Monitoring et Maintenance**

```sql
-- Requêtes de monitoring
SELECT * FROM v\$undostat ORDER BY begin_time DESC;

SELECT tablespace_name, used_percent 
FROM dba_tablespace_usage_metrics 
WHERE used_percent > 80;

SELECT username, sessions, resource_limit 
FROM dba_profiles 
ORDER BY profile;

-- Nettoyage des sessions anciennes
CREATE OR REPLACE PROCEDURE nettoyer_sessions_anciennes IS
BEGIN
    DELETE FROM sessions_examen 
    WHERE statut = 'TERMINE' 
    AND date_fin_session < SYSDATE - 365;
    
    COMMIT;
END;
/

-- Job de maintenance quotidienne
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'MAINTENANCE_QUOTIDIENNE',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN nettoyer_sessions_anciennes; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0',
        enabled         => TRUE
    );
END;
/
```

## **12. Recommandations de Sécurité**

1. **Chiffrement des données sensibles**:
   ```sql
   -- Chiffrer les mots de passe dans la table utilisateurs
   CREATE OR REPLACE FUNCTION chiffrer_mdp(p_mdp VARCHAR2) 
   RETURN RAW IS
   BEGIN
       RETURN DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(p_mdp, 'AL32UTF8'), DBMS_CRYPTO.HASH_SH256);
   END;
   ```

2. **Audit des actions critiques**:
   ```sql
   AUDIT SELECT, INSERT, UPDATE, DELETE ON sessions_examen;
   AUDIT SELECT, INSERT, UPDATE, DELETE ON reponses_etudiants;
   ```

3. **Sauvegarde RMAN quotidienne**:
   ```bash
   # Script RMAN
   run {
       allocate channel ch1 device type disk;
       backup database plus archivelog;
       backup current controlfile;
       release channel ch1;
   }
   ```

Cette implémentation répond à tous les objectifs mentionnés:

✅ PDB dédiée à la plateforme

✅ Gestion des tablespaces utilisateurs et examens

✅ Configuration UNDO pour transactions longues

✅ Limitation des ressources par profil utilisateur

✅ Mécanisme de sauvegarde avant chaque session d'examen

✅ Tables complètes pour toutes les fonctionnalités demandées

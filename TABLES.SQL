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

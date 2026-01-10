# e-Learn-Maroc-Admin
projt d'administration de base de donnees Oracle
# Projet  : Plateforme d'Enseignement en Ligne (e-Learn Maroc)

## 👥 Équipe de Projet
* **Membres :** Wiam, Salma, Youssra, Mohamed, Abderahim.
* **Contexte :** Gestion d'une base de données Oracle (PDB) pour une plateforme gérant des milliers d'étudiants et des sessions d'examens intensives.

---

## 🎯 Objectifs du Projet
L'objectif principal est d'optimiser l'administration de la base de données pour supporter des transactions longues et une forte consommation de ressources.

1. **Architecture :** Création d'une Pluggable Database (PDB) dédiée.
2. **Stockage :** Gestion des Tablespaces (séparation des données utilisateurs et examens).
3. **Performance :** Adaptation du segment `UNDO` pour les transactions longues.
4. **Sécurité & Ressources :** Limitation des ressources via des `Profiles` utilisateurs.
5. **Disponibilité :** Stratégie de sauvegarde (Backup) avant chaque session d'examen. 

---

## 📂 Structure du Répertoire (Git)
| Fichier | Description |
| :--- | :--- |
| `01_setup_pdb.sql` | Création de la PDB et configuration initiale. |
| `02_storage_mgmt.sql` | Scripts de création des Tablespaces (`TS_ELEARN_DATA`, `TS_ELEARN_EXAMS`). |
| `03_resource_profiles.sql` | Configuration des profils de limitation (CPU, Session time). |
| `04_db_schema.sql` | Scripts de création des tables (Users, Exams, Answers). |
| `05_backup_strategy.rman` | Script RMAN pour la sauvegarde avant examen.(Mohammed-labbi) |

---

## 🛠️ Instructions de Déploiement
1. **Connexion au CDB :**
   ```sql
   sqlplus sys/password as sysdba

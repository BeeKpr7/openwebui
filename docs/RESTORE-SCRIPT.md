# 🔄 Script de Restauration OpenWebUI

Documentation complète du script `restore-backup.sh` pour restaurer facilement une sauvegarde OpenWebUI vers l'environnement local avec de nombreuses fonctionnalités avancées.

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Prérequis](#prérequis)
- [Utilisation](#utilisation)
- [Processus de restauration](#processus-de-restauration)
- [Mode dry-run](#mode-dry-run-pour-tests)
- [Cas d'usage](#cas-dusage-typiques)
- [Dépannage](#dépannage)
- [Sécurité](#sécurité-et-bonnes-pratiques)

## 🔍 Vue d'ensemble

### Script disponible

| Script | Description | Taille | Dernière modification |
|--------|-------------|--------|----------------------|
| `restore-backup.sh` | Script de restauration automatisé avec sécurité | ~12KB | Août 2025 |

### Fonctionnalités

- ✅ **Restauration automatisée** avec script dédié
- ✅ **Détection automatique** du volume OpenWebUI local
- ✅ **Mode dry-run** pour tester sans risque
- ✅ **Sauvegarde de sécurité** avant restauration
- ✅ **Arrêt/redémarrage automatique** des conteneurs
- ✅ **Validation des prérequis** avant restauration
- ✅ **Gestion d'erreurs** avec codes de sortie spécifiques
- ✅ **Interface interactive** avec confirmations

## ⚙️ Prérequis

### Logiciels requis

- **Docker** : Pour accéder aux volumes OpenWebUI
- **Bash** : Shell d'exécution
- **Fichier de sauvegarde** : Archive tar.gz valide

### Prérequis d'installation

Le script nécessite qu'OpenWebUI soit déjà déployé via :
- `./deploy-local.sh` pour l'environnement local
- Volume Docker OpenWebUI existant

## 🚀 Utilisation

### Syntaxe du script de restauration

```bash
./config/script/restore-backup.sh [OPTIONS] BACKUP_FILE
```

### Options disponibles

| Option | Description | Exemple |
|--------|-------------|---------|
| `--local-volume VOLUME` | Nom du volume Docker local à restaurer | `--local-volume apollo-13_open-webui` |
| `--dry-run` | Simulation sans restauration effective | `--dry-run` |
| `--backup-current` | Créer une sauvegarde avant restauration | `--backup-current` |
| `--quiet` | Mode silencieux | `--quiet` |
| `--help` | Afficher l'aide détaillée | `--help` |

### Exemples d'utilisation

#### 1. Restauration simple depuis une sauvegarde locale
```bash
./config/script/restore-backup.sh backups/update_openwebui_20250811_123437.tar.gz
```

#### 2. Restauration avec sauvegarde de sécurité
```bash
./config/script/restore-backup.sh --backup-current backups/update_openwebui_20250811_123437.tar.gz
```

#### 3. Test de restauration (simulation)
```bash
./config/script/restore-backup.sh --dry-run backups/update_openwebui_20250811_123437.tar.gz
```

#### 4. Restauration silencieuse pour automatisation
```bash
./config/script/restore-backup.sh --quiet --backup-current backups/latest.tar.gz
```

#### 5. Restauration avec volume spécifique
```bash
./config/script/restore-backup.sh --local-volume apollo-13_open-webui backups/update_openwebui_20250811_123437.tar.gz
```

## 🔄 Processus de restauration

### Étapes automatiques du script

#### 1. **Vérification des prérequis** 🔍
```bash
[INFO] Vérification des prérequis...
[INFO] Détection du volume OpenWebUI local...
[INFO] Volume local détecté : apollo-13_open-webui
[SUCCESS] Prérequis validés
```

Le script vérifie automatiquement :
- Installation et fonctionnement de Docker
- Existence du fichier de sauvegarde
- Validité du fichier tar.gz
- Détection automatique du volume OpenWebUI local
- Permissions d'accès aux volumes Docker

#### 2. **Sauvegarde de sécurité (optionnelle)** 💾
```bash
[INFO] Création d'une sauvegarde de sécurité des données actuelles...
[SUCCESS] Sauvegarde de sécurité créée : backups/safety_backup_20250811_143022.tar.gz (1,8G)
```

Si l'option `--backup-current` est activée :
- Création automatique d'une sauvegarde des données actuelles
- Nom horodaté : `safety_backup_YYYYMMDD_HHMMSS.tar.gz`
- Stockage dans le répertoire `backups/`

#### 3. **Arrêt des conteneurs OpenWebUI** ⏹️
```bash
[INFO] Arrêt des conteneurs OpenWebUI...
[INFO] Arrêt du conteneur : openwebui-local
```

Le script détecte et arrête automatiquement :
- Tous les conteneurs contenant "openwebui", "open-webui" ou "apollo"
- Attente de l'arrêt complet avant de continuer

#### 4. **Restauration des données** 🔄
```bash
[INFO] Restauration de la sauvegarde vers le volume local...
[WARNING] Cette opération va remplacer toutes les données actuelles dans le volume apollo-13_open-webui
Voulez-vous continuer ? (y/N)
[SUCCESS] Restauration terminée avec succès
```

Processus technique :
- Nettoyage complet du volume de destination
- Extraction de l'archive tar.gz vers le volume
- Préservation des permissions et métadonnées

#### 5. **Redémarrage d'OpenWebUI** ▶️
```bash
[INFO] Redémarrage d'OpenWebUI...
[SUCCESS] OpenWebUI redémarré avec succès
[INFO] L'application sera disponible dans quelques instants sur http://localhost:8080
```

### Restauration manuelle avancée

#### Depuis une sauvegarde locale

```bash
# 1. Arrêter OpenWebUI
docker-compose down

# 2. Identifier le volume
docker volume ls | grep open-webui

# 3. Restaurer manuellement
docker run --rm \
  -v apollo-13_open-webui:/data \
  -v /path/to/backup:/backup \
  alpine:latest \
  sh -c "rm -rf /data/* /data/.[^.]* && tar xzf /backup/update_openwebui_YYYYMMDD_HHMMSS.tar.gz -C /data"

# 4. Redémarrer OpenWebUI
docker-compose up -d
```

#### Depuis une sauvegarde S3

```bash
# 1. Télécharger depuis S3
aws s3 cp s3://apollo13/openwebui-backups/prod/update_openwebui_20250811_111628.tar.gz /tmp/ \
  --endpoint-url https://nbg1.your-objectstorage.com

# 2. Utiliser le script de restauration
./config/script/restore-backup.sh --backup-current /tmp/update_openwebui_20250811_111628.tar.gz

# 3. Nettoyer le fichier temporaire
rm /tmp/update_openwebui_20250811_111628.tar.gz
```

## 🧪 Mode dry-run pour tests

Le mode `--dry-run` permet de tester la restauration sans effectuer de modifications :

```bash
./config/script/restore-backup.sh --dry-run backups/update_openwebui_20250811_123437.tar.gz
```

### Sortie exemple
```
[INFO] MODE DRY-RUN ACTIVÉ - Aucune modification ne sera effectuée
[INFO] Fichier de sauvegarde : backups/update_openwebui_20250811_123437.tar.gz
[INFO] Volume de destination : apollo-13_open-webui
[INFO] MODE DRY-RUN : Simulation de la restauration
[INFO] Commande qui serait exécutée :
  docker run --rm -v apollo-13_open-webui:/data -v backups:/backup alpine tar xzf /backup/update_openwebui_20250811_123437.tar.gz -C /data
[INFO] MODE DRY-RUN : Simulation du redémarrage
```

## 🔧 Dépannage

### Codes de sortie du script de restauration

| Code | Signification | Action recommandée |
|------|---------------|-------------------|
| `0` | Restauration réussie | Aucune action |
| `1` | Erreur générale | Vérifier les logs |
| `2` | Prérequis manquants | Installer Docker |
| `3` | Volume introuvable | Vérifier le déploiement OpenWebUI |
| `4` | Fichier de sauvegarde invalide | Vérifier le fichier source |

### Problèmes courants

#### 1. "Volume Docker local introuvable"
```bash
[ERROR] Volume Docker local 'apollo-13_open-webui' introuvable

# Solutions :
# Lister les volumes disponibles
docker volume ls

# Spécifier manuellement le volume
./config/script/restore-backup.sh --local-volume NOM_VOLUME backup.tar.gz
```

#### 2. "Fichier de sauvegarde invalide"
```bash
[ERROR] Le fichier de sauvegarde n'est pas un fichier tar.gz valide

# Vérifications :
file backup.tar.gz
tar -tzf backup.tar.gz | head -5
```

#### 3. "Permissions insuffisantes"
```bash
[ERROR] Docker n'est pas en cours d'exécution

# Solutions :
sudo systemctl start docker
sudo usermod -aG docker $USER
newgrp docker
```

#### 4. "Conteneur OpenWebUI introuvable"
```bash
[ERROR] Aucun conteneur OpenWebUI trouvé

# Vérifications :
docker ps -a | grep openwebui

# Redéploiement si nécessaire
./deploy-local.sh
```

### Logs de débogage

Pour plus de détails sur les erreurs :

```bash
# Exécuter en mode verbose
bash -x ./config/script/restore-backup.sh backup.tar.gz

# Vérifier les logs Docker
docker logs CONTAINER_NAME
```

## 🛡️ Sécurité et bonnes pratiques

### Avant la restauration
- ✅ **Toujours créer une sauvegarde** avec `--backup-current`
- ✅ **Tester avec `--dry-run`** pour valider le processus
- ✅ **Vérifier l'intégrité** du fichier de sauvegarde
- ✅ **Confirmer l'arrêt** des services dépendants

### Après la restauration
- ✅ **Vérifier le fonctionnement** d'OpenWebUI
- ✅ **Tester la connexion** et l'authentification
- ✅ **Valider les données** restaurées
- ✅ **Nettoyer les fichiers** temporaires

### Vérifications de sécurité

#### Validation du fichier de sauvegarde
```bash
# Vérifier le type de fichier
file backup.tar.gz

# Lister le contenu sans extraire
tar -tzf backup.tar.gz | head -10

# Vérifier la taille
ls -lh backup.tar.gz
```

#### Validation du volume
```bash
# Vérifier l'existence du volume
docker volume inspect apollo-13_open-webui

# Vérifier l'utilisation de l'espace
docker system df -v
```

## 📋 Cas d'usage typiques

### 1. **Synchronisation prod → local**
```bash
# 1. Télécharger la sauvegarde de production
aws s3 cp s3://apollo13/openwebui-backups/prod/latest.tar.gz /tmp/ \
  --endpoint-url https://nbg1.your-objectstorage.com

# 2. Restaurer en local avec sauvegarde de sécurité
./config/script/restore-backup.sh --backup-current /tmp/latest.tar.gz

# 3. Nettoyer
rm /tmp/latest.tar.gz
```

### 2. **Récupération après incident**
```bash
# Restaurer la dernière sauvegarde locale
./config/script/restore-backup.sh backups/update_openwebui_$(ls -t backups/ | head -n1)
```

### 3. **Migration entre environnements**
```bash
# Test en mode dry-run
./config/script/restore-backup.sh --dry-run backup_source.tar.gz

# Restauration effective avec sauvegarde
./config/script/restore-backup.sh --backup-current backup_source.tar.gz
```

### 4. **Restauration programmée**
```bash
# Script automatisé pour restauration nocturne
#!/bin/bash
BACKUP_FILE="/path/to/daily_backup.tar.gz"
if [ -f "$BACKUP_FILE" ]; then
    ./config/script/restore-backup.sh --quiet --backup-current "$BACKUP_FILE"
fi
```

### 5. **Restauration sélective par date**
```bash
# Trouver une sauvegarde spécifique
ls -la backups/ | grep "20250811"

# Restaurer cette sauvegarde
./config/script/restore-backup.sh --backup-current backups/update_openwebui_20250811_123437.tar.gz
```

## 📊 Monitoring et métriques

### Temps de restauration typiques

| Taille de sauvegarde | Temps de restauration | Temps total |
|---------------------|----------------------|-------------|
| < 100 MB | 30s-1min | 2-3min |
| 100 MB - 1 GB | 1-3min | 3-5min |
| 1-5 GB | 3-10min | 5-15min |
| > 5 GB | 10-30min | 15-45min |

### Vérifications post-restauration

```bash
# Vérifier l'état du conteneur
docker ps | grep openwebui

# Vérifier la connectivité
curl -I http://localhost:8080

# Vérifier les logs
docker-compose logs --tail=20
```

### Logs structurés

#### Format des logs
```
[TIMESTAMP] [LEVEL] Message détaillé
```

#### Niveaux de log
- `[INFO]` : Informations générales
- `[SUCCESS]` : Opérations réussies  
- `[WARNING]` : Avertissements non-bloquants
- `[ERROR]` : Erreurs critiques
- `[DRY-RUN]` : Mode simulation

#### Exemple de log complet
```
2025-08-11 14:30:15 [INFO] Vérification des prérequis...
2025-08-11 14:30:15 [INFO] Volume local détecté : apollo-13_open-webui
2025-08-11 14:30:20 [INFO] Création d'une sauvegarde de sécurité...
2025-08-11 14:32:10 [SUCCESS] Sauvegarde de sécurité créée : backups/safety_backup_20250811_143022.tar.gz
2025-08-11 14:32:15 [INFO] Arrêt des conteneurs OpenWebUI...
2025-08-11 14:32:20 [INFO] Restauration de la sauvegarde vers le volume local...
2025-08-11 14:35:45 [SUCCESS] Restauration terminée avec succès
2025-08-11 14:35:50 [INFO] Redémarrage d'OpenWebUI...
2025-08-11 14:36:05 [SUCCESS] OpenWebUI redémarré avec succès
```

## 🔧 Configuration avancée

### Variables d'environnement

Le script utilise les variables suivantes :

```bash
# Variables internes (automatiques)
SCRIPT_DIR                    # Répertoire du script
PROJECT_ROOT                  # Racine du projet
LOCAL_VOLUME_NAME            # Volume Docker local détecté
BACKUP_FILE                  # Fichier de sauvegarde à restaurer
DRY_RUN                      # Mode simulation
BACKUP_CURRENT              # Créer sauvegarde de sécurité
QUIET                       # Mode silencieux
```

### Personnalisation du script

#### Modifier les patterns de détection
```bash
# Dans restore-backup.sh, recherche de conteneurs
docker ps -a --format "{{.Names}}" | grep -E "openwebui|open-webui|apollo"

# Recherche de volumes
docker volume ls --format "{{.Name}}" | grep -E "open-webui|openwebui"
```

#### Modifier les timeouts
```bash
# Timeout pour l'arrêt des conteneurs
sleep 5

# Timeout pour le démarrage
sleep 10
```

## 🚀 Améliorations futures

### Roadmap technique
- [ ] **Restauration sélective** de composants spécifiques
- [ ] **Validation avancée** des sauvegardes
- [ ] **Support de compression** multiple (gzip, bzip2, xz)
- [ ] **Restauration incrémentielle** pour optimiser les performances
- [ ] **Interface web** pour gestion graphique
- [ ] **Notifications** par webhook/email
- [ ] **Métriques** de performance et monitoring

### Intégrations possibles
- **Monitoring** : Prometheus, Grafana
- **Notifications** : Slack, Discord, Teams
- **Orchestration** : Kubernetes, Docker Swarm
- **Stockage** : Support NFS, CIFS, autres systèmes de fichiers

### Fonctionnalités avancées prévues
- **Restauration par point dans le temps** avec horodatage précis
- **Validation de cohérence** des données restaurées
- **Rollback automatique** en cas d'échec de restauration
- **Restauration parallèle** pour améliorer les performances

---

*Dernière mise à jour : Août 2025*
*Version du script : 1.0*
*Compatibilité : OpenWebUI v0.3+, Docker 20.10+, Bash 4.0+*

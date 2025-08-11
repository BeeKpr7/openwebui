# 💾 Scripts de Sauvegarde OpenWebUI

Ce répertoire contient les scripts nécessaires pour effectuer des sauvegardes automatiques d'OpenWebUI vers un stockage S3 (Hetzner Object Storage).

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Prérequis](#prérequis)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Processus de backup](#processus-de-backup)
- [Automatisation](#automatisation)
- [Restauration](#restauration)
- [Dépannage](#dépannage)

## 🔍 Vue d'ensemble

### Scripts disponibles

| Script | Description | Taille | Dernière modification |
|--------|-------------|--------|----------------------|
| `backup-openwebui.sh` | Script principal de sauvegarde avec support S3 | ~18KB | Août 2025 |
| `README.md` | Documentation complète | ~8KB | Ce fichier |

### Fonctionnalités

- ✅ **Sauvegarde automatique** des volumes Docker OpenWebUI
- ✅ **Upload vers S3** (Hetzner Object Storage compatible)
- ✅ **Support multi-environnements** (local/prod avec préfixes séparés)
- ✅ **Nettoyage automatique** des anciennes sauvegardes (10 locales, 20 S3)
- ✅ **Vérification d'intégrité** avec checksums MD5
- ✅ **Mode silencieux** optimisé pour cron
- ✅ **Logs détaillés** avec codes couleur
- ✅ **Détection automatique** des volumes et conteneurs
- ✅ **Gestion d'erreurs** robuste avec codes de sortie
- ✅ **Variables d'environnement** sécurisées

## ⚙️ Prérequis

### Logiciels requis

- **Docker** : Pour accéder aux volumes OpenWebUI
- **AWS CLI** : Pour les opérations S3
- **Bash** : Shell d'exécution

### Installation AWS CLI

```bash
# macOS
brew install awscli

# Ubuntu/Debian
sudo apt-get install awscli

# Ou via pip
pip install awscli
```

## 🔧 Configuration

### 1. Variables d'environnement

Les credentials S3 sont configurés dans les fichiers `.env` :

#### `.env.local` (Développement)
```bash
# Configuration S3 pour les sauvegardes
AWS_ACCESS_KEY_ID=AF5T0GFM51IY17PZLI8J
AWS_SECRET_ACCESS_KEY=irByeRyDOGajR9MuPAeIxYEyaHAnI5PQnglmBIC0
AWS_DEFAULT_REGION=nbg1
S3_BACKUP_BUCKET=apollo13
S3_BACKUP_PREFIX=openwebui-backups/local/
```

#### `.env.prod` (Production)
```bash
# Configuration S3 pour les sauvegardes
AWS_ACCESS_KEY_ID=AF5T0GFM51IY17PZLI8J
AWS_SECRET_ACCESS_KEY=irByeRyDOGajR9MuPAeIxYEyaHAnI5PQnglmBIC0
AWS_DEFAULT_REGION=nbg1
S3_BACKUP_BUCKET=apollo13
S3_BACKUP_PREFIX=openwebui-backups/prod/
```

### 2. Profil AWS (optionnel)

Vous pouvez aussi utiliser un profil AWS configuré :

```bash
aws configure --profile apollo13
```

## 🚀 Utilisation

### Syntaxe de base

```bash
./config/script/backup-openwebui.sh [OPTIONS]
```

### Options disponibles

| Option | Description | Exemple |
|--------|-------------|---------|
| `--env local\|prod` | Environnement à utiliser | `--env local` |
| `--env-file FILE` | Fichier d'environnement personnalisé | `--env-file .env.custom` |
| `--s3-only` | Sauvegarde S3 uniquement (pas de copie locale) | `--s3-only` |
| `--quiet` | Mode silencieux (pour cron) | `--quiet` |
| `--output-dir DIR` | Répertoire de destination personnalisé | `--output-dir /backup` |
| `--s3-bucket BUCKET` | Bucket S3 (remplace la variable d'env) | `--s3-bucket mon-bucket` |
| `--s3-prefix PREFIX` | Préfixe S3 personnalisé | `--s3-prefix backups/` |
| `--help` | Afficher l'aide | `--help` |

### Exemples d'utilisation

#### 1. Sauvegarde locale standard
```bash
./config/script/backup-openwebui.sh
```

#### 2. Sauvegarde avec environnement local (local + S3)
```bash
./config/script/backup-openwebui.sh --env local
```

#### 3. Sauvegarde S3 uniquement (production)
```bash
./config/script/backup-openwebui.sh --env prod --s3-only
```

#### 4. Sauvegarde silencieuse pour cron
```bash
./config/script/backup-openwebui.sh --env prod --quiet --s3-only
```

#### 5. Fichier d'environnement personnalisé
```bash
./config/script/backup-openwebui.sh --env-file .env.custom
```

## 🔄 Processus de backup

### Architecture du système

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   OpenWebUI     │    │  Script Backup   │    │   Hetzner S3    │
│   (Docker)      │───▶│  backup-openwebui│───▶│   apollo13      │
│                 │    │                  │    │                 │
│ Volume: /data   │    │ Compression TAR  │    │ nbg1.your-obj  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Étapes détaillées du backup

#### 1. **Vérification des prérequis** 🔍
```bash
[INFO] Vérification des prérequis...
```
- Vérification de Docker (installation et fonctionnement)
- Détection automatique du conteneur OpenWebUI
- Identification du volume de données
- Validation des credentials AWS/S3
- Vérification de la connectivité réseau

#### 2. **Détection automatique** 🎯
```bash
[INFO] Détection du volume OpenWebUI...
[INFO] Conteneur trouvé: openwebui-local
[INFO] Volume détecté: apollo-13_open-webui
```
Le script recherche automatiquement :
- Les conteneurs avec "openwebui" ou "open-webui" dans le nom
- Les volumes Docker associés
- Fallback vers une recherche par nom de volume

#### 3. **Chargement de la configuration** ⚙️
```bash
[INFO] Utilisation de l'environnement local : .env.local
[INFO] Chargement des variables depuis : /path/to/.env.local
[INFO] Bucket S3 défini depuis l'environnement : apollo13
[INFO] Préfixe S3 défini depuis l'environnement : openwebui-backups/local/
```

#### 4. **Création de la sauvegarde** 📦
```bash
[INFO] Création d'une sauvegarde du volume OpenWebUI...
[INFO] Destination locale : /path/to/backup/update_openwebui_20250811_111628.tar.gz
```

**Processus technique :**
```bash
docker run --rm \
    -v "VOLUME_NAME:/data:ro" \
    -v "BACKUP_DIR:/backup" \
    alpine:latest \
    tar czf "/backup/FILENAME.tar.gz" -C /data .
```

**Détails :**
- **Conteneur temporaire** Alpine Linux (léger)
- **Volume en lecture seule** (`ro`) pour éviter les modifications
- **Compression gzip** pour optimiser l'espace
- **Nom horodaté** : `update_openwebui_YYYYMMDD_HHMMSS.tar.gz`

#### 5. **Vérification de l'intégrité** ✅
```bash
[SUCCESS] Sauvegarde créée avec succès (1,8G)
```
- Vérification de l'existence du fichier
- Calcul de la taille
- Validation de l'intégrité basique

#### 6. **Upload vers S3** ☁️
```bash
[INFO] Upload vers S3 : s3://apollo13/openwebui-backups/local/update_openwebui_20250811_111628.tar.gz
[SUCCESS] Upload S3 réussi
```

**Commande AWS :**
```bash
aws s3 cp "LOCAL_FILE" "s3://BUCKET/PREFIX/FILENAME" \
    --endpoint-url https://nbg1.your-objectstorage.com \
    --only-show-errors
```

#### 7. **Vérification S3** 🔐
```bash
[INFO] Vérification de l'intégrité...
[WARNING] Les checksums ne correspondent pas (peut être normal pour des fichiers volumineux)
```
- Calcul du MD5 local
- Comparaison avec l'ETag S3
- Warning normal pour les gros fichiers (multipart upload)

#### 8. **Nettoyage automatique** 🧹
```bash
[INFO] Vérification des anciennes sauvegardes S3...
```

**Politique de rétention :**
- **Local** : Conservation des 10 dernières sauvegardes
- **S3** : Conservation des 20 dernières sauvegardes
- **Tri** : Par date de modification (plus récentes conservées)

### Formats et tailles

#### Format des fichiers
```
update_openwebui_YYYYMMDD_HHMMSS.tar.gz
│                │        │
│                │        └── Heure (HHMMSS)
│                └─────────── Date (YYYYMMDD)
└──────────────────────────── Préfixe fixe
```

#### Tailles typiques
| Contenu | Taille approximative |
|---------|---------------------|
| Installation vide | ~50 MB |
| Avec quelques modèles | ~500 MB - 2 GB |
| Installation complète | 2-10 GB |
| Avec historique complet | 10+ GB |

#### Temps de backup
| Taille des données | Temps local | Temps upload S3 |
|-------------------|-------------|-----------------|
| < 100 MB | 10-30s | 30s-2min |
| 100 MB - 1 GB | 30s-2min | 2-10min |
| 1-5 GB | 2-5min | 10-30min |
| > 5 GB | 5-15min | 30min+ |

### Structure des données sauvegardées

#### Contenu du volume OpenWebUI
```
/data/
├── uploads/           # Fichiers uploadés par les utilisateurs
├── vector_db/         # Base de données vectorielle
├── models/           # Modèles téléchargés
├── config/           # Configuration OpenWebUI
├── static/           # Fichiers statiques
├── logs/             # Logs applicatifs
└── database/         # Base de données SQLite
    └── webui.db      # Base principale
```

#### Ce qui est sauvegardé
- ✅ **Conversations** et historique des chats
- ✅ **Utilisateurs** et leurs paramètres
- ✅ **Modèles** téléchargés
- ✅ **Documents** uploadés
- ✅ **Configuration** personnalisée
- ✅ **Base de données** vectorielle
- ✅ **Logs** applicatifs

#### Ce qui n'est PAS sauvegardé
- ❌ **Conteneur Docker** lui-même
- ❌ **Images Docker**
- ❌ **Configuration réseau** Docker
- ❌ **Variables d'environnement** du conteneur
- ❌ **Logs système** Docker

### Sécurité et bonnes pratiques

#### Chiffrement
- 🔒 **En transit** : HTTPS/TLS vers S3
- 🔒 **Au repos** : Chiffrement S3 côté serveur (optionnel)
- 🔒 **Variables** : Stockage sécurisé dans `.env`

#### Permissions
```bash
# Permissions recommandées pour les fichiers
chmod 600 .env.*              # Lecture seule propriétaire
chmod 755 backup-openwebui.sh # Exécutable
chmod 644 README.md           # Lecture pour tous
```

#### Monitoring
- 📊 **Codes de sortie** : 0 = succès, 1 = erreur
- 📊 **Logs structurés** : [INFO], [SUCCESS], [WARNING], [ERROR]
- 📊 **Tailles** : Vérification de la croissance des sauvegardes
- 📊 **Durée** : Surveillance des temps d'exécution

## ⏰ Automatisation

### Configuration cron

Ajoutez ces lignes à votre crontab (`crontab -e`) :

```bash
# Sauvegarde quotidienne à 2h du matin (production, S3 uniquement)
0 2 * * * /Users/echiappino/PeakStudio/openwebui/config/script/backup-openwebui.sh --env prod --quiet --s3-only

# Sauvegarde locale hebdomadaire le dimanche à 3h
0 3 * * 0 /Users/echiappino/PeakStudio/openwebui/config/script/backup-openwebui.sh --env local --quiet

# Sauvegarde mensuelle complète le 1er à 4h
0 4 1 * * /Users/echiappino/PeakStudio/openwebui/config/script/backup-openwebui.sh --env prod --quiet
```

### Surveillance des logs

Pour surveiller les sauvegardes automatiques :

```bash
# Voir les logs système
sudo journalctl -f | grep backup-openwebui

# Ou rediriger vers un fichier de log
./config/script/backup-openwebui.sh --env prod --quiet >> /var/log/openwebui-backup.log 2>&1
```

## 🔄 Restauration

### Depuis une sauvegarde locale

```bash
# Restaurer depuis un fichier local
docker run --rm \
  -v VOLUME_NAME:/data \
  -v /path/to/backup:/backup \
  alpine tar xzf /backup/update_openwebui_YYYYMMDD_HHMMSS.tar.gz -C /data
```

### Depuis S3

```bash
# 1. Télécharger depuis S3
aws s3 cp s3://apollo13/openwebui-backups/prod/update_openwebui_YYYYMMDD_HHMMSS.tar.gz /tmp/ \
  --endpoint-url https://nbg1.your-objectstorage.com

# 2. Restaurer dans Docker
docker run --rm \
  -v VOLUME_NAME:/data \
  -v /tmp:/backup \
  alpine tar xzf /backup/update_openwebui_YYYYMMDD_HHMMSS.tar.gz -C /data
```

### Exemple complet de restauration

```bash
# Identifier le volume OpenWebUI
docker volume ls | grep open-webui

# Télécharger la sauvegarde
aws s3 cp s3://apollo13/openwebui-backups/prod/update_openwebui_20250811_111628.tar.gz /tmp/ \
  --profile apollo13 --endpoint-url https://nbg1.your-objectstorage.com

# Arrêter OpenWebUI
docker-compose down

# Restaurer les données
docker run --rm \
  -v apollo-13_open-webui:/data \
  -v /tmp:/backup \
  alpine tar xzf /backup/update_openwebui_20250811_111628.tar.gz -C /data

# Redémarrer OpenWebUI
docker-compose up -d

# Nettoyer
rm /tmp/update_openwebui_20250811_111628.tar.gz
```

## 📁 Organisation des sauvegardes

### Structure dans le bucket S3

```
apollo13/
├── openwebui-backups/
│   ├── local/
│   │   ├── update_openwebui_20250811_111628.tar.gz
│   │   ├── update_openwebui_20250812_111628.tar.gz
│   │   └── ...
│   └── prod/
│       ├── update_openwebui_20250811_021500.tar.gz
│       ├── update_openwebui_20250812_021500.tar.gz
│       └── ...
```

### Rétention des sauvegardes

- **Locales** : 10 dernières sauvegardes conservées
- **S3** : 20 dernières sauvegardes conservées
- **Nettoyage automatique** à chaque exécution

## 🔧 Dépannage

### Problèmes courants

#### 1. "Volume Docker introuvable"
```bash
# Vérifier les volumes disponibles
docker volume ls

# Vérifier les conteneurs OpenWebUI
docker ps | grep openwebui
```

#### 2. "AWS CLI n'est pas configuré"
```bash
# Vérifier la configuration
aws configure list

# Tester la connexion S3
aws s3 ls --profile apollo13 --endpoint-url https://nbg1.your-objectstorage.com
```

#### 3. "Impossible de se connecter à S3"
```bash
# Vérifier l'endpoint
ping nbg1.your-objectstorage.com

# Tester avec curl
curl -I https://nbg1.your-objectstorage.com
```

#### 4. "Permissions insuffisantes"
```bash
# Vérifier les permissions Docker
sudo usermod -aG docker $USER

# Redémarrer la session
newgrp docker
```

### Logs de débogage

Pour plus de détails sur les erreurs :

```bash
# Exécuter en mode verbose
bash -x ./config/script/backup-openwebui.sh --env local

# Vérifier les logs Docker
docker logs CONTAINER_NAME
```

### Support

Pour obtenir de l'aide :

1. Vérifiez les logs d'erreur
2. Consultez la documentation AWS CLI
3. Vérifiez la configuration Docker
4. Testez la connectivité réseau

## 📝 Notes importantes

- ⚠️ **Sécurité** : Ne jamais commiter les fichiers `.env` avec les vraies clés
- 🔒 **Permissions** : Assurez-vous que les scripts sont exécutables (`chmod +x`)
- 💾 **Espace disque** : Vérifiez l'espace disponible avant les sauvegardes
- 🌐 **Réseau** : Une connexion Internet est requise pour S3
- ⏱️ **Temps** : Les sauvegardes peuvent prendre du temps selon la taille des données

## 📊 Monitoring et métriques

### Codes de sortie du script

| Code | Signification | Action recommandée |
|------|---------------|-------------------|
| `0` | Succès complet | Aucune action |
| `1` | Erreur générale | Vérifier les logs |
| `2` | Prérequis manquants | Installer les dépendances |
| `3` | Volume introuvable | Vérifier Docker |
| `4` | Erreur S3 | Vérifier credentials/réseau |

### Surveillance des performances

#### Métriques importantes
```bash
# Taille des sauvegardes dans le temps
aws s3 ls s3://apollo13/openwebui-backups/local/ --recursive --human-readable --summarize

# Espace disque local utilisé
du -sh /Users/echiappino/PeakStudio/openwebui/backups/

# Temps d'exécution moyen
grep "Sauvegarde terminée" /var/log/openwebui-backup.log | tail -10
```

#### Alertes recommandées
- 🚨 **Échec de sauvegarde** : Notification immédiate
- ⚠️ **Taille > 5GB** : Vérification manuelle
- 📈 **Croissance > 50%** : Investigation recommandée
- ⏱️ **Durée > 30min** : Optimisation nécessaire

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

#### Exemple de log complet
```
2025-08-11 11:16:28 [INFO] Utilisation de l'environnement local : .env.local
2025-08-11 11:16:28 [INFO] Chargement des variables depuis : /path/to/.env.local
2025-08-11 11:16:28 [INFO] Bucket S3 défini depuis l'environnement : apollo13
2025-08-11 11:16:28 [SUCCESS] Prérequis validés
2025-08-11 11:16:28 [INFO] Volume détecté: apollo-13_open-webui
2025-08-11 11:16:45 [SUCCESS] Sauvegarde créée avec succès (1,8G)
2025-08-11 11:25:48 [SUCCESS] Upload S3 réussi
2025-08-11 11:25:50 [SUCCESS] 🎉 Sauvegarde terminée avec succès !
```

## 🔧 Configuration avancée

### Variables d'environnement supplémentaires

#### Dans les fichiers `.env`
```bash
# Configuration S3 étendue
AWS_ACCESS_KEY_ID=AF5T0GFM51IY17PZLI8J
AWS_SECRET_ACCESS_KEY=irByeRyDOGajR9MuPAeIxYEyaHAnI5PQnglmBIC0
AWS_DEFAULT_REGION=nbg1
S3_BACKUP_BUCKET=apollo13
S3_BACKUP_PREFIX=openwebui-backups/local/

# Configuration de rétention (optionnel)
BACKUP_RETENTION_LOCAL=10    # Nombre de sauvegardes locales à conserver
BACKUP_RETENTION_S3=20       # Nombre de sauvegardes S3 à conserver

# Configuration de compression (optionnel)
BACKUP_COMPRESSION_LEVEL=6   # Niveau de compression gzip (1-9)

# Configuration de notification (futur)
BACKUP_WEBHOOK_URL=          # URL de webhook pour notifications
BACKUP_EMAIL_TO=             # Email de notification
```

### Personnalisation du script

#### Modification des seuils
```bash
# Dans backup-openwebui.sh, vous pouvez modifier :
BACKUP_PREFIX="update_openwebui_"     # Préfixe des fichiers
MAX_LOCAL_BACKUPS=10                  # Sauvegardes locales max
MAX_S3_BACKUPS=20                     # Sauvegardes S3 max
```

#### Endpoints S3 personnalisés
```bash
# Pour d'autres fournisseurs S3-compatibles
S3_ENDPOINT_URL=https://s3.amazonaws.com           # AWS Standard
S3_ENDPOINT_URL=https://fra1.digitaloceanspaces.com # DigitalOcean
S3_ENDPOINT_URL=https://s3.wasabisys.com           # Wasabi
S3_ENDPOINT_URL=https://nbg1.your-objectstorage.com # Hetzner
```

## 🚀 Améliorations futures

### Roadmap technique
- [ ] **Support multi-buckets S3** pour redondance
- [ ] **Chiffrement des sauvegardes** avec GPG
- [ ] **Notifications** par email/Slack/Discord
- [ ] **Interface web** de gestion des sauvegardes
- [ ] **Métriques** Prometheus/Grafana
- [ ] **Compression différentielle** pour optimiser l'espace
- [ ] **Validation** des sauvegardes avec tests de restauration
- [ ] **API REST** pour intégration externe

### Intégrations possibles
- **Monitoring** : Prometheus, Grafana, Zabbix
- **Notifications** : Slack, Discord, Teams, Email
- **Orchestration** : Kubernetes CronJobs, Nomad
- **CI/CD** : GitHub Actions, GitLab CI, Jenkins

### Optimisations prévues
- **Parallélisation** des uploads S3
- **Compression** adaptative selon le contenu
- **Déduplication** des données identiques
- **Cache** des métadonnées pour accélération

---

*Dernière mise à jour : Août 2025*
*Version du script : 2.0*
*Compatibilité : OpenWebUI v0.3+, Docker 20.10+, AWS CLI 2.0+*

# 🔄 Script de Mise à jour OpenWebUI

Documentation complète du script `update-openwebui.sh` pour automatiser la mise à jour de votre installation OpenWebUI vers la dernière version disponible.

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Prérequis](#prérequis)
- [Utilisation](#utilisation)
- [Processus de mise à jour](#processus-de-mise-à-jour)
- [Gestion des environnements](#gestion-des-environnements)
- [Mode dry-run](#mode-dry-run-pour-tests)
- [Automatisation](#automatisation)
- [Dépannage](#dépannage)

## 🔍 Vue d'ensemble

### Script disponible

| Script | Description | Taille | Dernière modification |
|--------|-------------|--------|----------------------|
| `update-openwebui.sh` | Script de mise à jour automatique OpenWebUI | ~15KB | Août 2025 |

### Fonctionnalités

- ✅ **Mise à jour automatique** vers la dernière version OpenWebUI
- ✅ **Détection d'environnement** automatique (local/prod)
- ✅ **Sauvegarde préventive** optionnelle avant mise à jour
- ✅ **Mode dry-run** pour simulation sans risque
- ✅ **Arrêt/redémarrage intelligent** des services
- ✅ **Vérification post-mise à jour** automatique
- ✅ **Support multi-environnements** avec configuration adaptée
- ✅ **Gestion d'erreurs** robuste avec rollback manuel

## ⚙️ Prérequis

### Logiciels requis

- **Docker** : Pour la gestion des conteneurs OpenWebUI
- **Docker Compose** : Pour l'orchestration des services
- **Bash** : Shell d'exécution

### Prérequis d'installation

Le script nécessite qu'OpenWebUI soit déjà déployé via :
- `./deploy-local.sh` pour l'environnement local
- `./deploy-prod.sh` pour l'environnement production

## 🚀 Utilisation

### Syntaxe du script de mise à jour

```bash
./config/script/update-openwebui.sh [OPTIONS]
```

### Options disponibles

| Option | Description | Exemple |
|--------|-------------|---------|
| `--backup` | Forcer une sauvegarde avant mise à jour | `--backup` |
| `--no-backup` | Passer la sauvegarde | `--no-backup` |
| `--dry-run` | Simuler sans exécuter | `--dry-run` |
| `--env ENV` | Forcer l'environnement (local\|prod) | `--env prod` |
| `--help` | Afficher l'aide détaillée | `--help` |

### Exemples d'utilisation

#### 1. Mise à jour standard avec détection automatique
```bash
./config/script/update-openwebui.sh
```

#### 2. Mise à jour avec sauvegarde forcée
```bash
./config/script/update-openwebui.sh --backup
```

#### 3. Mise à jour en production sans sauvegarde
```bash
./config/script/update-openwebui.sh --env prod --no-backup
```

#### 4. Simulation de mise à jour (test)
```bash
./config/script/update-openwebui.sh --dry-run
```

#### 5. Mise à jour locale avec sauvegarde
```bash
./config/script/update-openwebui.sh --env local --backup
```

## 🔄 Processus de mise à jour

### Étapes automatiques du script

#### 1. **Détection d'environnement** 🎯
```bash
[INFO] Détection de l'environnement...
[INFO] Environnement détecté: local
[INFO] Configuration:
[INFO]   - Fichier compose: docker-compose.yml
[INFO]   - Conteneur cible: openwebui-local
[INFO]   - Nom du projet: apollo-13
```

Le script détecte automatiquement :
- L'environnement actuel (local ou production)
- Le fichier docker-compose approprié
- Le nom du conteneur et du projet
- La configuration réseau associée

#### 2. **Vérification des prérequis** 🔍
```bash
[INFO] Vérification des prérequis...
[INFO] Conteneur configuré trouvé: openwebui-local
[INFO] Volume détecté: apollo-13_open-webui
[SUCCESS] Prérequis validés
```

Vérifications automatiques :
- Installation et fonctionnement de Docker
- Disponibilité de Docker Compose
- Existence du conteneur OpenWebUI
- Détection du volume de données
- Validation des fichiers de configuration

#### 3. **Version actuelle** 📋
```bash
[INFO] Vérification de la version actuelle...
[INFO] Image actuelle : ghcr.io/open-webui/open-webui:main
```

#### 4. **Sauvegarde préventive (optionnelle)** 💾
```bash
[INFO] Appel du script de sauvegarde...
[SUCCESS] Sauvegarde créée avec succès
```

Si demandé ou configuré :
- Appel automatique du script `backup-openwebui.sh`
- Création d'une sauvegarde complète
- Vérification de la réussite avant continuation

#### 5. **Arrêt et suppression** ⏹️
```bash
[INFO] Arrêt et suppression du conteneur existant...
[INFO] Arrêt et suppression du conteneur openwebui-local
```

#### 6. **Téléchargement** ⬇️
```bash
[INFO] Téléchargement de la dernière image Docker...
[INFO] Téléchargement de ghcr.io/open-webui/open-webui:main
```

#### 7. **Redémarrage** ▶️
```bash
[INFO] Redémarrage des services avec Docker Compose...
[INFO] Redémarrage avec Docker Compose (local)
```

#### 8. **Vérification post-mise à jour** ✅
```bash
[INFO] Vérification de la mise à jour...
[SUCCESS] Conteneur démarré avec succès
[INFO] Vérification de la nouvelle version...
[SUCCESS] Nouvelle image : ghcr.io/open-webui/open-webui:main
[INFO] Test de connectivité sur http://127.0.0.1:8080...
[SUCCESS] OpenWebUI est accessible ✓
```

## 🌍 Gestion des environnements

### Détection automatique
Le script détecte automatiquement l'environnement basé sur :
- Le fichier `docker-compose.yml` actuel (lien symbolique)
- Le contenu des fichiers de configuration
- La présence des fichiers `.env.local` ou `.env.prod`

### Configuration par environnement

#### Environnement Local
- **Fichier compose** : `config/docker/docker-compose.yml`
- **Nom du conteneur** : `openwebui-local`
- **Nom du projet** : `apollo-13`
- **Port** : 8080

#### Environnement Production
- **Fichier compose** : `config/docker/docker-compose.prod.yml`
- **Nom du conteneur** : `openwebui-production`
- **Nom du projet** : (aucun)
- **Port** : 8080

## 🧪 Mode dry-run pour tests

Le mode `--dry-run` permet de simuler la mise à jour sans effectuer de modifications :

```bash
./config/script/update-openwebui.sh --dry-run
```

### Sortie exemple
```
[DRY-RUN] Création de la sauvegarde
→ /path/to/backup-openwebui.sh
[DRY-RUN] Arrêt et suppression du conteneur openwebui-local
→ docker rm -f openwebui-local
[DRY-RUN] Téléchargement de ghcr.io/open-webui/open-webui:main
→ docker pull ghcr.io/open-webui/open-webui:main
[DRY-RUN] Redémarrage avec Docker Compose (local)
→ docker-compose -p "apollo-13" up -d
```

## ⏰ Automatisation

### Configuration cron pour mise à jour automatique

```bash
# Mise à jour hebdomadaire le dimanche à 2h (sans sauvegarde)
0 2 * * 0 /Users/echiappino/PeakStudio/openwebui/config/script/update-openwebui.sh --env prod --no-backup > /var/log/openwebui-update.log 2>&1

# Mise à jour mensuelle avec sauvegarde le 1er à 3h
0 3 1 * * /Users/echiappino/PeakStudio/openwebui/config/script/update-openwebui.sh --env prod --backup > /var/log/openwebui-update.log 2>&1
```

### Surveillance des mises à jour automatiques

```bash
# Voir les logs de mise à jour
tail -f /var/log/openwebui-update.log

# Vérifier le statut du dernier cron
grep "update-openwebui" /var/log/cron.log
```

## 🔧 Dépannage

### Codes de sortie du script de mise à jour

| Code | Signification | Action recommandée |
|------|---------------|-------------------|
| `0` | Mise à jour réussie | Aucune action |
| `1` | Erreur générale | Vérifier les logs |
| `2` | Prérequis manquants | Installer Docker/Compose |
| `3` | Environnement non détecté | Vérifier la configuration |
| `4` | Conteneur introuvable | Redéployer OpenWebUI |

### Problèmes courants

#### 1. "Environnement non détecté"
```bash
[ERROR] Impossible de détecter l'environnement

# Solutions :
# Forcer l'environnement
./config/script/update-openwebui.sh --env local

# Ou vérifier les fichiers de configuration
ls -la docker-compose.yml
```

#### 2. "Conteneur introuvable"
```bash
[ERROR] Impossible de trouver le conteneur ou volume OpenWebUI

# Vérifications :
docker ps -a | grep openwebui
docker volume ls | grep open-webui

# Redéploiement si nécessaire
./deploy-local.sh
```

#### 3. "Fichier compose non trouvé"
```bash
[ERROR] Fichier compose non trouvé: config/docker/docker-compose.yml

# Solution :
# Exécuter d'abord le script de déploiement
./deploy-local.sh
```

#### 4. "Docker n'est pas en cours d'exécution"
```bash
[ERROR] Docker n'est pas en cours d'exécution

# Solutions :
sudo systemctl start docker
# Ou sur macOS
open -a Docker
```

### Logs de débogage

Pour plus de détails sur les erreurs :

```bash
# Exécuter en mode verbose
bash -x ./config/script/update-openwebui.sh --env local

# Vérifier les logs Docker Compose
docker-compose logs --tail=20
```

## 🛡️ Sécurité et bonnes pratiques

### Avant la mise à jour
- ✅ **Toujours tester** avec `--dry-run` d'abord
- ✅ **Créer une sauvegarde** avec `--backup` pour les données critiques
- ✅ **Vérifier l'espace disque** disponible
- ✅ **Planifier une fenêtre de maintenance** pour la production

### Après la mise à jour
- ✅ **Vérifier le fonctionnement** d'OpenWebUI
- ✅ **Tester l'authentification** et les fonctionnalités clés
- ✅ **Valider les données** et configurations
- ✅ **Surveiller les logs** pour détecter d'éventuels problèmes

### Cas d'usage typiques

#### 1. **Mise à jour de développement**
```bash
# Test en simulation
./config/script/update-openwebui.sh --env local --dry-run

# Mise à jour effective avec sauvegarde
./config/script/update-openwebui.sh --env local --backup
```

#### 2. **Mise à jour de production**
```bash
# Sauvegarde préventive
./config/script/backup-openwebui.sh --env prod --s3-only

# Mise à jour sans sauvegarde supplémentaire
./config/script/update-openwebui.sh --env prod --no-backup
```

#### 3. **Mise à jour d'urgence**
```bash
# Mise à jour rapide sans sauvegarde (risqué)
./config/script/update-openwebui.sh --env prod --no-backup
```

#### 4. **Mise à jour avec rollback préparé**
```bash
# 1. Sauvegarde manuelle
./config/script/backup-openwebui.sh --env prod

# 2. Mise à jour
./config/script/update-openwebui.sh --env prod --no-backup

# 3. Si problème, restauration
# ./config/script/restore-backup.sh backups/latest.tar.gz
```

## 🔄 Workflow recommandé

### Processus de mise à jour sécurisé

1. **Phase de préparation**
   ```bash
   # Vérifier l'état actuel
   docker ps | grep openwebui
   docker images | grep open-webui
   
   # Tester la simulation
   ./config/script/update-openwebui.sh --dry-run
   ```

2. **Phase de sauvegarde**
   ```bash
   # Créer une sauvegarde de sécurité
   ./config/script/backup-openwebui.sh --env prod --s3-only
   ```

3. **Phase de mise à jour**
   ```bash
   # Mise à jour effective
   ./config/script/update-openwebui.sh --env prod --no-backup
   ```

4. **Phase de validation**
   ```bash
   # Vérifier le fonctionnement
   curl -I http://localhost:8080
   
   # Consulter les logs
   docker-compose logs --tail=50
   ```

5. **Phase de rollback (si nécessaire)**
   ```bash
   # En cas de problème, restaurer la sauvegarde
   ./config/script/restore-backup.sh --backup-current backups/latest.tar.gz
   ```

## 📊 Monitoring et métriques

### Surveillance de la mise à jour

#### Temps de mise à jour typiques
| Environnement | Temps moyen | Temps max |
|---------------|-------------|-----------|
| Local | 2-5 minutes | 10 minutes |
| Production | 3-8 minutes | 15 minutes |

#### Vérifications post-mise à jour
```bash
# Vérifier la version de l'image
docker inspect openwebui-local --format='{{.Config.Image}}'

# Vérifier l'état du conteneur
docker inspect openwebui-local --format='{{.State.Status}}'

# Vérifier la connectivité
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
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
2025-08-11 14:30:15 [INFO] Détection de l'environnement...
2025-08-11 14:30:15 [INFO] Environnement détecté: local
2025-08-11 14:30:15 [SUCCESS] Prérequis validés
2025-08-11 14:30:20 [INFO] Arrêt et suppression du conteneur openwebui-local
2025-08-11 14:30:25 [INFO] Téléchargement de ghcr.io/open-webui/open-webui:main
2025-08-11 14:32:10 [INFO] Redémarrage avec Docker Compose (local)
2025-08-11 14:32:25 [SUCCESS] Conteneur démarré avec succès
2025-08-11 14:32:30 [SUCCESS] 🎉 Mise à jour terminée avec succès !
```

## 🔧 Configuration avancée

### Variables d'environnement

Le script utilise les variables d'environnement suivantes :

```bash
# Variables internes (automatiques)
SCRIPT_DIR                    # Répertoire du script
PROJECT_ROOT                  # Racine du projet
CONTAINER_NAME               # Nom du conteneur OpenWebUI
VOLUME_NAME                  # Nom du volume de données
IMAGE_NAME                   # Image Docker à utiliser
COMPOSE_FILE                 # Fichier docker-compose à utiliser
COMPOSE_PROJECT_NAME         # Nom du projet Docker Compose
```

### Personnalisation

#### Modifier l'image Docker
```bash
# Dans update-openwebui.sh, ligne 24
IMAGE_NAME="ghcr.io/open-webui/open-webui:main"

# Pour une version spécifique
IMAGE_NAME="ghcr.io/open-webui/open-webui:v0.3.8"
```

#### Modifier les timeouts
```bash
# Timeout pour le démarrage du conteneur (ligne 392)
local max_attempts=30

# Délai entre les vérifications (ligne 410)
sleep 2
```

## 🚀 Améliorations futures

### Roadmap technique
- [ ] **Support de versions multiples** OpenWebUI
- [ ] **Rollback automatique** en cas d'échec
- [ ] **Notifications** par webhook/email
- [ ] **Vérification de santé** avancée
- [ ] **Métriques** de performance
- [ ] **Interface web** de gestion
- [ ] **Intégration CI/CD** pour déploiements automatiques

### Intégrations possibles
- **Monitoring** : Prometheus, Grafana
- **Notifications** : Slack, Discord, Teams
- **Orchestration** : Kubernetes, Docker Swarm
- **CI/CD** : GitHub Actions, GitLab CI

---

*Dernière mise à jour : Août 2025*
*Version du script : 1.0*
*Compatibilité : OpenWebUI v0.3+, Docker 20.10+, Docker Compose 2.0+*

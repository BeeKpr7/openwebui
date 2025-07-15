# OpenWebUI

## 📋 Description du Projet

OpenWebUI est une interface web moderne et intuitive pour interagir avec des modèles de langage locaux via Ollama. Cette solution offre une expérience utilisateur similaire à ChatGPT mais entièrement hébergée localement, garantissant la confidentialité de vos données.

### 🎯 Fonctionnalités principales

- **Interface conversationnelle** : Discutez avec vos modèles IA locaux dans une interface claire et moderne
- **Intégration Ollama** : Connexion native avec Ollama pour l'exécution de modèles de langage
- **Gestion des utilisateurs** : Système d'authentification avec gestion des rôles
- **Téléchargement de documents** : Analysez et discutez avec vos documents (PDF, TXT, etc.)
- **Partage communautaire** : Options de partage sécurisé (configurable)
- **Déploiement flexible** : Support pour environnements local et production

### 🏗️ Architecture

Le projet utilise une architecture conteneurisée avec Docker Compose :
- **OpenWebUI** : Interface web principal (port 8080)
- **Ollama** : Service de modèles IA (port 11434)
- **Nginx** : Reverse proxy pour la production (optionnel)
- **Volumes persistants** : Sauvegarde des données utilisateur

### 📁 Structure du projet

```
├── config/
│   ├── docker/
│   │   ├── docker-compose.yml      # Configuration locale
│   │   └── docker-compose.prod.yml # Configuration production
│   └── nginx/
│       ├── nginx-initial.conf
│       └── nginx-openwebui.conf
├── docs/
│   └── OPENWEBUI.md
├── .env.local                      # Configuration locale
├── .env.prod                       # Configuration production
├── deploy-local.sh                 # Script de déploiement local
├── deploy-prod.sh                  # Script de déploiement production
├── .env                           # → .env.local (lien symbolique)
└── docker-compose.yml             # → config/docker/docker-compose.yml (lien symbolique)
```

Les liens symboliques sont créés automatiquement par les scripts de déploiement et sont ignorés par git (`.gitignore`).

## 🚀 Installation Locale

### Prérequis

- Docker et Docker Compose installés
- Minimum 4GB de RAM disponible
- Ports 8080 et 11434 libres

### Déploiement automatique

Un script de déploiement automatisé est disponible pour l'environnement local :

```bash
# Rendre le script exécutable
chmod +x deploy-local.sh

# Lancer le déploiement
./deploy-local.sh
```

**Le script automatise :**
- ✅ Vérification des prérequis (Docker, Docker Compose)
- ✅ Création des liens symboliques (`.env` et `docker-compose.yml`)
- ✅ Configuration des variables d'environnement
- ✅ Arrêt des conteneurs existants
- ✅ Démarrage des services OpenWebUI et Ollama

### Configuration par défaut

Le script utilise le fichier d'environnement `.env.local` et crée automatiquement les liens symboliques nécessaires :

- `.env` → `.env.local` (configuration)
- `docker-compose.yml` → `config/docker/docker-compose.yml` (orchestration)

Cette structure permet d'utiliser les commandes docker-compose standard depuis la racine du projet.

### Accès à l'application

Une fois déployé, OpenWebUI est accessible à : **http://127.0.0.1:8080**

### Commandes utiles

```bash
# Voir les logs en temps réel
docker-compose logs -f

# Arrêter les services
docker-compose down

# Redémarrer les services
docker-compose restart

# Redémarrer un service spécifique
docker-compose restart openwebui
```

## 🏭 Installation Production

### Prérequis

- Serveur Linux avec Docker et Docker Compose
- Nom de domaine configuré (optionnel pour HTTPS)
- Minimum 8GB de RAM recommandé
- Ports 80 et 443 libres (pour Nginx)

### Déploiement avec Nginx

Un script de déploiement automatisé est disponible pour la production :

```bash
# Rendre le script exécutable
chmod +x deploy-prod.sh

# Lancer le déploiement production
./deploy-prod.sh
```

**Le script de production :**
- ✅ Crée les liens symboliques (`.env` et `docker-compose.yml`)
- ✅ Configure Nginx comme reverse proxy
- ✅ Gère les certificats SSL/TLS automatiquement
- ✅ Optimise les performances pour la production
- ✅ Configure les logs et monitoring
- ✅ Applique les limites de ressources

### Configuration production

La configuration de production utilise `.env.prod` :

```env
# Configuration sécurisée
WEBUI_SECRET_KEY=your-super-secret-key-here-change-this-in-production
WEBUI_NAME=OpenWebUI Production
ENABLE_SIGNUP=false          # Désactivé en production
ENABLE_OAUTH_SIGNUP=false
ENABLE_COMMUNITY_SHARING=false

# Limites de sécurité
MAX_UPLOAD_SIZE=104857600
MAX_FILE_SIZE=104857600
```

### Sécurité en production

⚠️ **Important pour la production :**

1. **Changez la clé secrète** dans `.env.prod`
2. **Désactivez l'inscription** (`ENABLE_SIGNUP=false`)
3. **Configurez un reverse proxy** (Nginx inclus)
4. **Activez HTTPS** avec certificats SSL
5. **Limitez les ressources** Docker

### Monitoring et logs

```bash
# Voir les logs de production (après exécution de deploy-prod.sh)
docker-compose logs -f

# Vérifier l'état des services
docker-compose ps

# Redémarrer en production
docker-compose restart
```

## 🔧 Maintenance

### Mise à jour

Pour mettre à jour vers la dernière version :

```bash
# Arrêter les services
docker-compose down

# Mettre à jour les images
docker-compose pull

# Redémarrer avec les nouvelles images
docker-compose up -d
```

### Utilisation avancée

Si vous préférez travailler directement avec les fichiers de configuration sans liens symboliques :

```bash
# Commandes locales avec chemins explicites
docker-compose -f config/docker/docker-compose.yml up -d
docker-compose -f config/docker/docker-compose.yml logs -f
docker-compose -f config/docker/docker-compose.yml down

# Commandes production avec chemins explicites
docker-compose -f config/docker/docker-compose.prod.yml up -d
docker-compose -f config/docker/docker-compose.prod.yml logs -f
docker-compose -f config/docker/docker-compose.prod.yml down
```

### Sauvegarde

Les données sont persistantes dans le volume Docker `open-webui` :

```bash
# Créer une sauvegarde
docker run --rm -v open-webui:/data -v $(pwd):/backup alpine tar czf /backup/openwebui-backup.tar.gz /data

# Restaurer une sauvegarde
docker run --rm -v open-webui:/data -v $(pwd):/backup alpine tar xzf /backup/openwebui-backup.tar.gz -C /
```

## 🔍 Dépannage

### Problèmes courants

1. **Docker n'est pas démarré** : Démarrez Docker Desktop
2. **Ports déjà utilisés** : Modifiez les ports dans `.env.local` ou `.env.prod`
3. **Permissions insuffisantes** : `chmod +x deploy-*.sh`
4. **Mémoire insuffisante** : Libérez de la RAM ou ajustez les limites

### Support

Pour plus d'informations :
- 📖 Documentation complète : `docs/OPENWEBUI.md`
- 🐛 Issues : Consultez les logs avec `docker-compose logs`
- 🔄 Mise à jour : Suivez les instructions dans `docs/OPENWEBUI.md` 
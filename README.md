# OpenWebUI

## Déploiement Rapide

### Environnement Local

Un script de déploiement automatisé est disponible pour l'environnement local :

```bash
# Rendre le script exécutable (si nécessaire)
chmod +x deploy-local.sh

# Lancer le déploiement
./deploy-local.sh
```

**Ce script va automatiquement :**
- Vérifier que Docker et Docker Compose sont installés et en cours d'exécution
- Créer un fichier `env.local` avec les variables d'environnement appropriées pour le développement
- Créer un lien symbolique `.env` vers `env.local`
- Arrêter les conteneurs existants s'ils sont en cours d'exécution
- Démarrer les services OpenWebUI et Ollama

Après le déploiement, OpenWebUI sera accessible à l'adresse : http://127.0.0.1:8080

### Commandes Utiles

Une fois déployé, vous pouvez utiliser ces commandes :

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

### Configuration

Le script crée automatiquement un fichier `env.local` avec les variables d'environnement suivantes :

- **OPENWEBUI_PORT** : Port pour OpenWebUI (défaut: 8080)
- **OLLAMA_PORT** : Port pour Ollama (défaut: 11434)
- **OLLAMA_BASE_URL** : URL de base pour Ollama (http://ollama:11434)
- **WEBUI_NAME** : Nom de l'interface (OpenWebUI Local)
- **WEBUI_AUTH** : Authentification activée (true)
- **ENABLE_SIGNUP** : Inscription activée (true)
- **DEFAULT_USER_ROLE** : Rôle par défaut (user)

Vous pouvez modifier ces valeurs dans le fichier `env.local` après le déploiement initial.

### Dépannage

Si vous rencontrez des problèmes :

1. **Docker n'est pas démarré** : Démarrez Docker Desktop
2. **Ports déjà utilisés** : Modifiez les ports dans `env.local`
3. **Problèmes de permissions** : Assurez-vous que le script est exécutable avec `chmod +x deploy-local.sh`

### Environnement de Production

Pour l'environnement de production, consultez le fichier `README-ENV.md` pour les instructions détaillées.

## Documentation Complète

Pour plus d'informations sur la configuration des variables d'environnement, consultez [README-ENV.md](README-ENV.md). 
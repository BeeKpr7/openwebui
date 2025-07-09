# Configuration des Variables d'Environnement

Ce projet utilise des fichiers d'environnement séparés pour la gestion des configurations locales et de production.

## Fichiers d'Environnement

### `env.local` - Configuration de Développement Local
- Variables pour le développement local
- Ollama inclus localement
- Inscription activée
- Configuration de debug

### `env.prod` - Configuration de Production
- Variables pour l'environnement de production
- Ollama externe requis
- Inscription désactivée
- Configuration de sécurité renforcée

## Utilisation

### Développement Local
```bash
# Utilise automatiquement env.local
docker-compose up -d
```

### Production
```bash
# Utilise automatiquement env.prod
docker-compose -f docker-compose.prod.yml up -d
```

## Variables à Configurer

### Pour la Production (env.prod)
Avant de déployer en production, modifiez ces variables dans `env.prod` :

1. **OLLAMA_BASE_URL** : URL de votre serveur Ollama externe
2. **WEBUI_SECRET_KEY** : Clé secrète unique et sécurisée
3. **WEBUI_NAME** : Nom de votre instance
4. **MAX_UPLOAD_SIZE** : Taille maximale des fichiers (en octets)

### Variables Importantes
- `ENABLE_SIGNUP` : Contrôle l'inscription des nouveaux utilisateurs
- `DEFAULT_USER_ROLE` : Rôle par défaut des nouveaux utilisateurs
- `WEBUI_AUTH` : Active/désactive l'authentification
- `ENABLE_COMMUNITY_SHARING` : Partage communautaire (désactivé en prod)

## Sécurité

⚠️ **Important** : Ne committez jamais vos fichiers d'environnement avec des valeurs sensibles !

Créez un fichier `.gitignore` pour exclure :
```
env.local
env.prod
*.env
``` 
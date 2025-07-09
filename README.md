# Open WebUI avec Ollama

Une interface web moderne pour interagir avec des modèles de langage via Ollama, déployée avec Docker Compose.

## 📋 Prérequis

- [Docker](https://docs.docker.com/get-docker/) installé sur votre système
- [Docker Compose](https://docs.docker.com/compose/install/) installé
- Au moins 8 GB de RAM disponible
- Connexion internet pour télécharger les images Docker

## 🚀 Installation et Lancement

### 1. Cloner ou télécharger ce projet

```bash
git clone <votre-repo>
cd openwebui
```

### 2. Lancer l'application

```bash
docker-compose up -d
```

Cette commande va :
- Télécharger les images Docker nécessaires
- Créer les conteneurs pour Open WebUI et Ollama
- Démarrer les services en arrière-plan

### 3. Accéder à l'interface

Ouvrez votre navigateur et allez à : **http://localhost:8080**

## 🎯 Première utilisation

### Création du compte administrateur

1. Lors de votre première visite, vous devrez créer un compte administrateur
2. Remplissez le formulaire d'inscription
3. Vous serez automatiquement connecté

### Téléchargement d'un modèle

1. Une fois connecté, allez dans les paramètres (icône ⚙️)
2. Cliquez sur "Models" dans le menu de gauche
3. Dans la section "Pull a model from Ollama.com", tapez le nom d'un modèle, par exemple :
   - `llama3.1` (recommandé pour débuter)
   - `codellama` (pour le code)
   - `mistral` (plus léger)

4. Cliquez sur le bouton de téléchargement
5. Attendez que le téléchargement se termine (cela peut prendre plusieurs minutes)

### Commencer une conversation

1. Retournez à la page d'accueil
2. Sélectionnez le modèle téléchargé dans le menu déroulant
3. Tapez votre message et appuyez sur Entrée

## ⚙️ Configuration

### Variables d'environnement

Le fichier `docker-compose.yml` contient plusieurs variables que vous pouvez modifier :

- `WEBUI_NAME` : Nom de l'interface (par défaut : "Open WebUI")
- `WEBUI_AUTH` : Activation de l'authentification (par défaut : True)
- `ENABLE_SIGNUP` : Autoriser les inscriptions (par défaut : True)
- `DEFAULT_USER_ROLE` : Rôle par défaut des nouveaux utilisateurs (par défaut : "user")

### Support GPU NVIDIA (optionnel)

Si vous avez une carte graphique NVIDIA et voulez accélérer les modèles :

1. Installez [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

2. Décommentez les lignes dans `docker-compose.yml` :

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

3. Redémarrez les conteneurs :
```bash
docker-compose down
docker-compose up -d
```

## 📊 Gestion des conteneurs

### Arrêter l'application
```bash
docker-compose down
```

### Voir les logs
```bash
docker-compose logs -f
```

### Redémarrer l'application
```bash
docker-compose restart
```

### Mettre à jour les images
```bash
docker-compose pull
docker-compose up -d
```

## 🔧 Dépannage

### L'interface ne se charge pas

1. Vérifiez que les conteneurs sont en cours d'exécution :
```bash
docker-compose ps
```

2. Consultez les logs :
```bash
docker-compose logs openwebui
docker-compose logs ollama
```

### Problèmes de mémoire

- Assurez-vous d'avoir suffisamment de RAM disponible
- Fermez les autres applications gourmandes en mémoire
- Choisissez des modèles plus légers (comme `mistral` au lieu de `llama3.1`)

### Le téléchargement de modèle échoue

1. Vérifiez votre connexion internet
2. Redémarrez Ollama :
```bash
docker-compose restart ollama
```

3. Essayez un modèle différent ou plus petit

## 📁 Structure des données

Les données sont stockées dans des volumes Docker :
- `open-webui` : Données de l'interface (conversations, paramètres)
- `ollama` : Modèles téléchargés et cache

Ces données persistent même après l'arrêt des conteneurs.

## 🛑 Désinstallation complète

Pour supprimer complètement l'application et ses données :

```bash
docker-compose down -v
docker rmi ghcr.io/open-webui/open-webui:main ollama/ollama:latest
```

⚠️ **Attention** : Cela supprimera toutes vos conversations et modèles téléchargés.

## 🆘 Support

- [Documentation officielle Open WebUI](https://docs.openwebui.com/)
- [Documentation Ollama](https://ollama.com/docs)
- [Liste des modèles disponibles](https://ollama.com/library)

---

**Profitez bien de votre interface Open WebUI ! 🎉** 
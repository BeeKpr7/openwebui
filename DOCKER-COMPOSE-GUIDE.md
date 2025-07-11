# Guide Docker Compose pour OpenWebUI

## Corrections Apportées

### 1. **Version Docker Compose**
- Ajout de `version: '3.8'` pour spécifier la version de la syntaxe Docker Compose

### 2. **Volume Ollama Manquant**
- Ajout du volume `ollama` dans la section `volumes` pour persister les modèles téléchargés

### 3. **Syntaxe des Limites de Ressources**
- Remplacement de l'ancienne syntaxe (`mem_limit`, `cpus`, `mem_reservation`)
- Utilisation de la syntaxe moderne `deploy.resources` compatible avec Docker Compose v3+

### 4. **Uniformisation des Fichiers d'Environnement**
- `docker-compose.yml` : utilise maintenant `.env.local` pour tous les services
- `docker-compose.prod.yml` : continue d'utiliser `.env.prod`

## Architecture des Services

Le diagramme ci-dessus montre l'architecture avec deux services principaux :
- **OpenWebUI** : Interface web principale
- **Ollama** : Service de gestion des modèles LLM

## Configuration Importante

### Pour l'Environnement Local (`docker-compose.yml`)

```bash
# Utiliser le fichier .env.local
cp .env.local.example .env.local  # Si vous avez un exemple

# Variables importantes dans .env.local :
# OLLAMA_BASE_URL=http://ollama:11434  ✓ Correct pour Docker
# OPENWEBUI_PORT=8080
# OLLAMA_PORT=11434
```

### Pour la Production (`docker-compose.prod.yml`)

**⚠️ IMPORTANT : Corriger OLLAMA_BASE_URL dans .env.prod**

```bash
# Dans .env.prod, remplacer :
# OLLAMA_BASE_URL=http://localhost:11434  ✗ Incorrect

# Par l'une de ces options :
# Option 1 : Si Ollama est dans le même stack Docker
OLLAMA_BASE_URL=http://ollama:11434

# Option 2 : Si Ollama est sur l'hôte (hors Docker)
OLLAMA_BASE_URL=http://host.docker.internal:11434  # Pour Mac/Windows
OLLAMA_BASE_URL=http://172.17.0.1:11434            # Pour Linux (IP du bridge Docker)

# Option 3 : Si Ollama est sur un serveur distant
OLLAMA_BASE_URL=http://your-ollama-server.com:11434
```

## Commandes d'Utilisation

### Développement Local

```bash
# Démarrer tous les services
docker-compose up -d

# Voir les logs
docker-compose logs -f

# Arrêter les services
docker-compose down

# Arrêter et supprimer les volumes (ATTENTION : supprime les données)
docker-compose down -v
```

### Production

```bash
# Utiliser le fichier de production
docker-compose -f docker-compose.prod.yml up -d

# Avec un fichier d'environnement personnalisé
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

## Limites de Ressources

Les limites configurées sont :

### OpenWebUI
- CPU : Maximum 2 cœurs
- Mémoire : Maximum 4GB, minimum réservé 512MB

### Ollama (local uniquement)
- CPU : Maximum 2 cœurs  
- Mémoire : Maximum 8GB, minimum réservé 1GB

**Note** : Ces limites ne fonctionnent qu'avec Docker Swarm ou en mode compatibilité. Pour Docker Compose standard, utilisez :

```bash
# Activer le mode compatibilité
docker-compose --compatibility up -d
```

## Vérification du Fonctionnement

1. **Vérifier que tous les services sont en cours d'exécution :**
   ```bash
   docker-compose ps
   ```

2. **Tester la connectivité entre les services :**
   ```bash
   # Depuis le conteneur OpenWebUI
   docker exec openwebui-production curl http://ollama:11434/api/tags
   ```

3. **Accéder à l'interface :**
   - OpenWebUI : http://localhost:8080

## Résolution des Problèmes

### Erreur "Cannot connect to Ollama"
- Vérifier `OLLAMA_BASE_URL` dans le fichier .env approprié
- S'assurer qu'Ollama est accessible depuis le conteneur OpenWebUI

### Erreur "Volume not found"
- S'assurer d'utiliser la dernière version des fichiers docker-compose
- Vérifier que tous les volumes sont définis dans la section `volumes`

### Problèmes de Performance
- Activer le mode compatibilité pour appliquer les limites de ressources
- Ajuster les limites selon vos besoins système 
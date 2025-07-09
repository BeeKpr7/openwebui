#!/bin/bash

# Script de déploiement pour l'environnement production avec Nginx
# Auteur: Générée automatiquement
# Description: Déploie OpenWebUI en production avec Nginx et HTTPS

set -e

echo "🚀 Démarrage du déploiement production d'OpenWebUI avec Nginx..."

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher des messages colorés
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Vérifier si Docker est installé et en cours d'exécution
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker n'est pas installé. Veuillez installer Docker."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker n'est pas en cours d'exécution. Veuillez démarrer Docker."
        exit 1
    fi
}

# Vérifier si Docker Compose est installé
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose n'est pas installé. Veuillez installer Docker Compose."
        exit 1
    fi
}

# Vérifier que le fichier .env.prod existe
check_env_prod() {
    if [ ! -f ".env.prod" ]; then
        print_error "Le fichier .env.prod n'existe pas."
        print_info "Veuillez créer le fichier .env.prod avant de lancer le déploiement."
        print_info "Vous pouvez utiliser ce modèle :"
        cat << 'EOF'
# Configuration OpenWebUI Production
OLLAMA_BASE_URL=http://localhost:11434
WEBUI_NAME=OpenWebUI Production
WEBUI_AUTH=true
ENABLE_SIGNUP=false
DEFAULT_USER_ROLE=user
WEBUI_SECRET_KEY=your-super-secret-key-here-change-this-in-production
ENABLE_LOGIN_FORM=true
ENABLE_OAUTH_SIGNUP=false
ENABLE_COMMUNITY_SHARING=false
MAX_UPLOAD_SIZE=104857600
MAX_FILE_SIZE=104857600
OPENWEBUI_PORT=8080
EOF
        exit 1
    fi
    print_success "Fichier .env.prod trouvé!"
}

# Créer le lien symbolique si nécessaire
create_symlink() {
    if [ -L ".env" ]; then
        print_warning "Le lien symbolique .env existe déjà. Suppression..."
        rm .env
    fi
    
    if [ -f ".env" ]; then
        print_warning "Le fichier .env existe. Création d'une sauvegarde..."
        mv .env .env.backup
    fi
    
    print_info "Création du lien symbolique .env -> .env.prod"
    ln -sf .env.prod .env
    
    # Vérifier que le lien symbolique fonctionne
    if [ -L ".env" ] && [ -f ".env" ]; then
        print_success "Lien symbolique créé avec succès!"
    else
        print_error "Erreur lors de la création du lien symbolique"
        exit 1
    fi
}

# Vérifier la configuration avant le démarrage
check_env_configuration() {
    print_info "Vérification de la configuration..."
    
    # Variables essentielles à vérifier
    required_vars=("OLLAMA_BASE_URL" "WEBUI_NAME" "WEBUI_AUTH" "ENABLE_SIGNUP" "DEFAULT_USER_ROLE" "WEBUI_SECRET_KEY")
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env.prod; then
            print_warning "Variable $var manquante dans .env.prod"
        fi
    done
    
    # Vérifier la clé secrète
    if grep -q "your-super-secret-key-here-change-this-in-production" .env.prod; then
        print_warning "WEBUI_SECRET_KEY n'a pas été changée! Veuillez la modifier pour la production."
    fi
    
    print_success "Configuration vérifiée!"
}

# Vérifier nginx
check_nginx() {
    if ! command -v nginx &> /dev/null; then
        print_error "Nginx n'est pas installé."
        exit 1
    fi
    
    if ! systemctl is-active --quiet nginx; then
        print_warning "Nginx n'est pas en cours d'exécution."
        print_info "Démarrage de nginx..."
        sudo systemctl start nginx
    fi
    
    print_success "Nginx vérifié!"
}

# Arrêter les conteneurs existants
stop_containers() {
    print_info "Arrêt des conteneurs existants..."
    
    # Utiliser docker-compose ou docker compose selon la disponibilité
    if command -v docker-compose &> /dev/null; then
        docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
    else
        docker compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
    fi
    
    print_success "Conteneurs arrêtés!"
}

# Démarrer les services
start_services() {
    print_info "Démarrage des services Docker..."
    
    # Utiliser docker-compose ou docker compose selon la disponibilité
    if command -v docker-compose &> /dev/null; then
        docker-compose -f docker-compose.prod.yml up -d
    else
        docker compose -f docker-compose.prod.yml up -d
    fi
    
    print_success "Services démarrés avec succès!"
}

# Vérifier le statut des services
check_services() {
    print_info "Vérification du statut des services..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f docker-compose.prod.yml ps
    else
        docker compose -f docker-compose.prod.yml ps
    fi
    
    # Vérifier que le service répond sur le port local
    sleep 5
    if curl -s http://127.0.0.1:8080 > /dev/null; then
        print_success "OpenWebUI répond sur le port 8080!"
    else
        print_warning "OpenWebUI ne répond pas encore sur le port 8080. Vérifiez les logs."
    fi
}

# Fonction principale
main() {
    print_info "Vérification des prérequis..."
    check_docker
    check_docker_compose
    check_nginx
    print_success "Prérequis vérifiés!"
    
    check_env_prod
    create_symlink
    check_env_configuration
    stop_containers
    start_services
    check_services
}

# Gestion des erreurs
trap 'print_error "Erreur survenue pendant le déploiement. Arrêt du script."; exit 1' ERR

# Exécuter le script principal
main "$@" 
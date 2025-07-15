#!/bin/bash

# Script de déploiement pour l'environnement local
# Auteur: Générée automatiquement
# Description: Déploie OpenWebUI en local avec Ollama

set -e

echo "🚀 Démarrage du déploiement local d'OpenWebUI..."

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

# Vérifier que le fichier env.local existe
check_env_local() {
    if [ ! -f ".env.local" ]; then
        print_error "Le fichier .env.local n'existe pas."
        print_info "Veuillez créer le fichier .env.local avant de lancer le déploiement."
        print_info "Vous pouvez utiliser .env.example comme modèle :"
        echo -e "${YELLOW}cp .env.example .env.local${NC}"
        exit 1
    fi
    print_success "Fichier .env.local trouvé!"
}

# Créer le lien symbolique pour .env
create_env_symlink() {
    if [ -L ".env" ]; then
        print_warning "Le lien symbolique .env existe déjà. Suppression..."
        rm .env
    fi
    
    if [ -f ".env" ]; then
        print_warning "Le fichier .env existe. Suppression..."
        rm .env
    fi
    
    print_info "Création du lien symbolique .env -> .env.local"
    ln -sf .env.local .env
    
    # Vérifier que le lien symbolique .env fonctionne
    if [ -L ".env" ] && [ -f ".env" ]; then
        print_success "Lien symbolique .env créé avec succès!"
    else
        print_error "Erreur lors de la création du lien symbolique .env"
        exit 1
    fi
}

# Créer le lien symbolique pour docker-compose
create_docker_compose_symlink() {
    if [ -L "docker-compose.yml" ]; then
        print_warning "Le lien symbolique docker-compose.yml existe déjà. Suppression..."
        rm docker-compose.yml
    fi
    
    if [ -f "docker-compose.yml" ]; then
        print_warning "Le fichier docker-compose.yml existe. Suppression..."
        rm docker-compose.yml
    fi
    
    print_info "Création du lien symbolique docker-compose.yml -> config/docker/docker-compose.yml"
    ln -sf config/docker/docker-compose.yml docker-compose.yml
    
    # Vérifier que le lien symbolique docker-compose.yml fonctionne
    if [ -L "docker-compose.yml" ] && [ -f "docker-compose.yml" ]; then
        print_success "Lien symbolique docker-compose.yml créé avec succès!"
    else
        print_error "Erreur lors de la création du lien symbolique docker-compose.yml"
        exit 1
    fi
}

# Vérifier la configuration avant le démarrage
check_env_configuration() {
    print_info "Vérification de la configuration..."
    
    # Variables essentielles à vérifier
    required_vars=("OLLAMA_BASE_URL" "WEBUI_NAME" "WEBUI_AUTH" "ENABLE_SIGNUP" "DEFAULT_USER_ROLE")
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env.local; then
            print_warning "Variable $var manquante dans .env.local"
        fi
    done
    
    print_success "Configuration vérifiée!"
}

# Arrêter les conteneurs existants
stop_containers() {
    print_info "Arrêt des conteneurs existants..."
    docker-compose down --remove-orphans 2>/dev/null || true
    print_success "Conteneurs arrêtés!"
}

# Démarrer les services
start_services() {
    print_info "Démarrage des services Docker..."
    
    # Utiliser docker-compose ou docker compose selon la disponibilité
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    print_success "Services démarrés avec succès!"
}

# Vérifier le statut des services
check_services() {
    print_info "Vérification du statut des services..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose ps
    else
        docker compose ps
    fi
    
    # Vérifier que le service répond sur le port local
    print_info "Test de connexion à OpenWebUI..."
    sleep 60
    if curl -s http://127.0.0.1:8080 > /dev/null; then
        print_success "OpenWebUI répond sur le port 8080!"
    else
        print_warning "OpenWebUI ne répond pas encore sur le port 8080. Vérifiez les logs."
    fi
}

# Afficher les informations de connexion
show_connection_info() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "Déploiement terminé avec succès! 🎉"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "OpenWebUI est accessible à l'adresse :"
    echo -e "${GREEN}➜ http://127.0.0.1:8080${NC}"
    echo ""
    print_info "Ollama est accessible à l'adresse :"
    echo -e "${GREEN}➜ http://127.0.0.1:11434${NC}"
    echo ""
    print_info "Commandes utiles :"
    echo -e "${YELLOW}• Voir les logs : docker-compose logs -f${NC}"
    echo -e "${YELLOW}• Arrêter les services : docker-compose down${NC}"
    echo -e "${YELLOW}• Redémarrer : docker-compose restart${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Fonction principale
main() {
    print_info "Vérification des prérequis..."
    check_docker
    check_docker_compose
    print_success "Prérequis vérifiés!"
    
    check_env_local
    create_env_symlink
    create_docker_compose_symlink
    check_env_configuration
    stop_containers
    start_services
    check_services
    show_connection_info
}

# Gestion des erreurs
trap 'print_error "Erreur survenue pendant le déploiement. Arrêt du script."; exit 1' ERR

# Exécuter le script principal
main "$@" 
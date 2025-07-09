#!/bin/bash

# Script de déploiement pour l'environnement de production
# Auteur: Générée automatiquement
# Description: Déploie OpenWebUI en production avec Ollama

set -e

echo "🚀 Démarrage du déploiement en production d'OpenWebUI..."

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

# Vérifier que le fichier docker-compose.prod.yml existe
check_docker_compose_prod() {
    if [ ! -f "docker-compose.prod.yml" ]; then
        print_error "Le fichier docker-compose.prod.yml n'existe pas."
        print_info "Ce fichier est nécessaire pour le déploiement en production."
        exit 1
    fi
    print_success "Fichier docker-compose.prod.yml trouvé!"
}

# Vérifier que le fichier env.prod existe
check_env_prod() {
    if [ ! -f ".env.prod" ]; then
        print_error "Le fichier .env.prod n'existe pas."
        print_info "Veuillez créer le fichier .env.prod avant de lancer le déploiement."
        print_info "Vous pouvez utiliser .env.example comme modèle :"
        echo -e "${YELLOW}cp .env.example .env.prod${NC}"
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
        mv .env .env.backup.$(date +%Y%m%d_%H%M%S)
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
    print_info "Vérification de la configuration de production..."
    
    # Variables essentielles à vérifier pour la production
    required_vars=("OLLAMA_BASE_URL" "WEBUI_NAME" "WEBUI_AUTH" "ENABLE_SIGNUP" "DEFAULT_USER_ROLE")
    production_vars=("WEBUI_SECRET_KEY" "DATABASE_URL")
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env.prod; then
            print_warning "Variable $var manquante dans .env.prod"
        fi
    done
    
    for var in "${production_vars[@]}"; do
        if ! grep -q "^${var}=" .env.prod; then
            print_warning "Variable de production $var manquante dans .env.prod"
        fi
    done
    
    # Vérifications spécifiques à la production
    if grep -q "^WEBUI_AUTH=False" .env.prod; then
        print_warning "ATTENTION: L'authentification est désactivée en production!"
    fi
    
    if grep -q "^ENABLE_SIGNUP=true" .env.prod; then
        print_warning "ATTENTION: L'inscription est activée en production!"
    fi
    
    print_success "Configuration vérifiée!"
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
    print_info "Démarrage des services Docker en production..."
    
    # Utiliser docker-compose ou docker compose selon la disponibilité
    if command -v docker-compose &> /dev/null; then
        docker-compose -f docker-compose.prod.yml up -d --build
    else
        docker compose -f docker-compose.prod.yml up -d --build
    fi
    
    print_success "Services démarrés avec succès!"
}

# Vérifier la santé des services
check_services_health() {
    print_info "Vérification de la santé des services..."
    
    # Attendre quelques secondes pour que les services démarrent
    sleep 10
    
    # Vérifier les conteneurs en cours d'exécution
    if command -v docker-compose &> /dev/null; then
        running_containers=$(docker-compose -f docker-compose.prod.yml ps --services --filter "status=running" | wc -l)
        total_containers=$(docker-compose -f docker-compose.prod.yml config --services | wc -l)
    else
        running_containers=$(docker compose -f docker-compose.prod.yml ps --services --filter "status=running" | wc -l)
        total_containers=$(docker compose -f docker-compose.prod.yml config --services | wc -l)
    fi
    
    if [ "$running_containers" -eq "$total_containers" ]; then
        print_success "Tous les services sont en cours d'exécution!"
    else
        print_warning "$running_containers/$total_containers services en cours d'exécution"
    fi
}

# Afficher les informations de connexion
show_connection_info() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "Déploiement en production terminé avec succès! 🎉"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Lire les ports depuis le fichier .env.prod
    webui_port=$(grep "^WEBUI_PORT=" .env.prod 2>/dev/null | cut -d'=' -f2 || echo "8080")
    ollama_port=$(grep "^OLLAMA_PORT=" .env.prod 2>/dev/null | cut -d'=' -f2 || echo "11434")
    
    print_info "OpenWebUI est accessible à l'adresse :"
    echo -e "${GREEN}➜ http://127.0.0.1:${webui_port}${NC}"
    echo ""
    print_info "Ollama est accessible à l'adresse :"
    echo -e "${GREEN}➜ http://127.0.0.1:${ollama_port}${NC}"
    echo ""
    print_info "Commandes utiles :"
    echo -e "${YELLOW}• Voir les logs : docker-compose -f docker-compose.prod.yml logs -f${NC}"
    echo -e "${YELLOW}• Arrêter les services : docker-compose -f docker-compose.prod.yml down${NC}"
    echo -e "${YELLOW}• Redémarrer : docker-compose -f docker-compose.prod.yml restart${NC}"
    echo -e "${YELLOW}• Voir le statut : docker-compose -f docker-compose.prod.yml ps${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Fonction de confirmation pour la production
confirm_production_deployment() {
    echo ""
    print_warning "⚠️  ATTENTION: Vous êtes sur le point de déployer en PRODUCTION!"
    print_info "Ceci va :"
    echo -e "${YELLOW}• Arrêter les services existants${NC}"
    echo -e "${YELLOW}• Démarrer les services avec docker-compose.prod.yml${NC}"
    echo -e "${YELLOW}• Utiliser la configuration .env.prod${NC}"
    echo ""
    
    read -p "Êtes-vous sûr de vouloir continuer? (oui/non): " -r
    if [[ ! $REPLY =~ ^[Oo][Uu][Ii]$ ]]; then
        print_info "Déploiement annulé par l'utilisateur."
        exit 0
    fi
}

# Fonction principale
main() {
    print_info "Vérification des prérequis..."
    check_docker
    check_docker_compose
    check_docker_compose_prod
    print_success "Prérequis vérifiés!"
    
    check_env_prod
    
    # Confirmation avant déploiement en production
    confirm_production_deployment
    
    create_symlink
    check_env_configuration
    stop_containers
    start_services
    check_services_health
    show_connection_info
}

# Gestion des erreurs
trap 'print_error "Erreur survenue pendant le déploiement. Arrêt du script."; exit 1' ERR

# Exécuter le script principal
main "$@" 
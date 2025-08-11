#!/bin/bash

# =============================================================================
# Script de mise à jour automatique d'OpenWebUI
# =============================================================================
# Ce script automatise la mise à jour de votre installation Docker OpenWebUI
# vers la dernière version disponible.
#
# Usage: ./update-openwebui.sh [OPTIONS]
# Options:
#   --backup         : Forcer une sauvegarde avant mise à jour
#   --no-backup      : Passer la sauvegarde
#   --dry-run        : Simuler sans exécuter
#   --help           : Afficher cette aide
# =============================================================================

set -euo pipefail

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTAINER_NAME=""
VOLUME_NAME=""
IMAGE_NAME="ghcr.io/open-webui/open-webui:main"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-openwebui.sh"

# Environment detection
ENVIRONMENT=""
COMPOSE_FILE=""
COMPOSE_PROJECT_NAME=""

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Options par défaut
FORCE_BACKUP=false
NO_BACKUP=false
DRY_RUN=false
SHOW_HELP=false
ENV_OVERRIDE=""

# =============================================================================
# Fonctions utilitaires
# =============================================================================

show_help() {
    cat << EOF
🔄 Script de mise à jour OpenWebUI

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --backup         Forcer une sauvegarde avant mise à jour
    --no-backup      Passer la sauvegarde
    --dry-run        Simuler sans exécuter les commandes
    --env ENV        Forcer l'environnement (local|prod)
    --help           Afficher cette aide

EXAMPLES:
    $0                    # Mise à jour normale avec détection automatique
    $0 --env local        # Forcer l'environnement local
    $0 --env prod         # Forcer l'environnement production
    $0 --backup           # Mise à jour avec sauvegarde forcée
    $0 --no-backup        # Mise à jour sans sauvegarde
    $0 --dry-run          # Simulation de la mise à jour

ENVIRONNEMENTS:
    local    - Utilise docker-compose.yml avec projet apollo-13
    prod     - Utilise docker-compose.prod.yml sans nom de projet

EOF
}

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

execute_command() {
    local cmd="$1"
    local description="$2"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $description"
        echo -e "${YELLOW}→${NC} $cmd"
    else
        log "$description"
        if ! eval "$cmd"; then
            error "Échec de l'exécution : $description"
            return 1
        fi
    fi
}

# =============================================================================
# Fonctions de vérification
# =============================================================================

detect_environment() {
    log "Détection de l'environnement..."
    
    # Si l'environnement est forcé, l'utiliser
    if [ -n "$ENV_OVERRIDE" ]; then
        ENVIRONMENT="$ENV_OVERRIDE"
        log "Environnement forcé: $ENVIRONMENT"
    else
        # Détecter automatiquement l'environnement basé sur le docker-compose.yml actuel
        if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
            if [ -L "$PROJECT_ROOT/docker-compose.yml" ]; then
                # C'est un lien symbolique, vérifier vers quoi il pointe
                local link_target
                link_target=$(readlink "$PROJECT_ROOT/docker-compose.yml")
                if [[ "$link_target" == *"docker-compose.prod.yml"* ]]; then
                    ENVIRONMENT="prod"
                else
                    ENVIRONMENT="local"
                fi
            else
                # Fichier normal, vérifier le contenu pour détecter l'environnement
                if grep -q "openwebui-production" "$PROJECT_ROOT/docker-compose.yml"; then
                    ENVIRONMENT="prod"
                elif grep -q "apollo-13" "$PROJECT_ROOT/docker-compose.yml" || grep -q "openwebui-local" "$PROJECT_ROOT/docker-compose.yml"; then
                    ENVIRONMENT="local"
                else
                    # Défaut basé sur l'existence des fichiers d'environnement
                    if [ -f "$PROJECT_ROOT/.env.prod" ] && [ ! -f "$PROJECT_ROOT/.env.local" ]; then
                        ENVIRONMENT="prod"
                    else
                        ENVIRONMENT="local"
                    fi
                fi
            fi
        else
            # Pas de docker-compose.yml, essayer de deviner
            if [ -f "$PROJECT_ROOT/config/docker/docker-compose.prod.yml" ]; then
                ENVIRONMENT="prod"
            else
                ENVIRONMENT="local"
            fi
        fi
        log "Environnement détecté: $ENVIRONMENT"
    fi
    
    # Configurer les variables selon l'environnement
    case "$ENVIRONMENT" in
        "local")
            COMPOSE_FILE="$PROJECT_ROOT/config/docker/docker-compose.yml"
            CONTAINER_NAME="openwebui-local"
            COMPOSE_PROJECT_NAME="apollo-13"
            ;;
        "prod")
            COMPOSE_FILE="$PROJECT_ROOT/config/docker/docker-compose.prod.yml"
            CONTAINER_NAME="openwebui-production"
            COMPOSE_PROJECT_NAME=""
            ;;
        *)
            error "Environnement non supporté: $ENVIRONMENT"
            error "Environnements supportés: local, prod"
            return 1
            ;;
    esac
    
    log "Configuration:"
    log "  - Fichier compose: $(basename "$COMPOSE_FILE")"
    log "  - Conteneur cible: $CONTAINER_NAME"
    if [ -n "$COMPOSE_PROJECT_NAME" ]; then
        log "  - Nom du projet: $COMPOSE_PROJECT_NAME"
    fi
}

detect_container_and_volume() {
    log "Détection du conteneur et volume OpenWebUI..."
    
    # Chercher le conteneur OpenWebUI (en cours d'exécution ou arrêté)
    local found_container
    found_container=$(docker ps -a --format "{{.Names}}" | grep -E "openwebui|open-webui" | head -n1)
    
    # Vérifier si le conteneur configuré existe
    if [ -n "$CONTAINER_NAME" ] && docker inspect "$CONTAINER_NAME" &> /dev/null; then
        log "Conteneur configuré trouvé: $CONTAINER_NAME"
        # Extraire le nom du volume depuis le conteneur
        VOLUME_NAME=$(docker inspect "$CONTAINER_NAME" --format='{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}' | head -n1)
        if [ -n "$VOLUME_NAME" ]; then
            log "Volume détecté: $VOLUME_NAME"
            return 0
        fi
    fi
    
    # Si le conteneur configuré n'existe pas, chercher n'importe quel conteneur OpenWebUI
    if [ -n "$found_container" ]; then
        log "Conteneur alternatif trouvé: $found_container"
        CONTAINER_NAME="$found_container"
        # Extraire le nom du volume depuis le conteneur
        VOLUME_NAME=$(docker inspect "$CONTAINER_NAME" --format='{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}' | head -n1)
        if [ -n "$VOLUME_NAME" ]; then
            log "Volume détecté: $VOLUME_NAME"
            return 0
        fi
    fi
    
    # Fallback: chercher des volumes qui contiennent "open-webui" dans le nom
    VOLUME_NAME=$(docker volume ls --format "{{.Name}}" | grep "open-webui" | head -n1)
    if [ -n "$VOLUME_NAME" ]; then
        log "Volume trouvé par recherche: $VOLUME_NAME"
        # Chercher un conteneur qui utilise ce volume en inspectant tous les conteneurs
        local container_found=""
        for container in $(docker ps -a --format "{{.Names}}"); do
            if docker inspect "$container" --format='{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}' 2>/dev/null | grep -q "$VOLUME_NAME"; then
                container_found="$container"
                break
            fi
        done
        
        if [ -n "$container_found" ]; then
            CONTAINER_NAME="$container_found"
            log "Conteneur utilisant ce volume: $CONTAINER_NAME"
        else
            # Essayer de deviner le nom du conteneur depuis le volume - garder la configuration d'environnement
            log "Aucun conteneur trouvé utilisant le volume $VOLUME_NAME"
            log "Utilisation du conteneur configuré: $CONTAINER_NAME"
        fi
        return 0
    fi
    
    error "Impossible de trouver le conteneur ou volume OpenWebUI"
    error "Conteneurs disponibles:"
    docker ps -a --format "  - {{.Names}} ({{.Image}})" | grep -i webui || true
    error "Volumes disponibles contenant 'open':"
    docker volume ls --format "{{.Name}}" | grep -i open | sed 's/^/  - /' || true
    return 1
}

check_prerequisites() {
    log "Vérification des prérequis..."
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        error "Docker n'est pas installé"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker n'est pas en cours d'exécution"
        exit 1
    fi
    
    # Vérifier Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose n'est pas disponible"
        exit 1
    fi
    
    # Détecter l'environnement et configurer les variables
    if ! detect_environment; then
        error "Impossible de détecter l'environnement"
        exit 1
    fi
    
    # Vérifier que le fichier compose existe
    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Fichier compose non trouvé: $COMPOSE_FILE"
        error "Assurez-vous d'avoir exécuté deploy-local.sh ou deploy-prod.sh au préalable"
        exit 1
    fi
    
    # Détecter le conteneur et le volume
    if ! detect_container_and_volume; then
        error "Assurez-vous qu'OpenWebUI a été déployé au préalable"
        exit 1
    fi
    
    # Aller dans le répertoire du projet
    cd "$PROJECT_ROOT"
    
    success "Prérequis validés"
}

get_current_version() {
    log "Vérification de la version actuelle..."
    
    if [ -n "$CONTAINER_NAME" ] && docker inspect "$CONTAINER_NAME" &> /dev/null; then
        local current_image
        current_image=$(docker inspect "$CONTAINER_NAME" --format='{{.Config.Image}}' 2>/dev/null || echo "inconnu")
        log "Image actuelle : $current_image"
    else
        warning "Conteneur $CONTAINER_NAME non trouvé ou nom vide"
    fi
}

# =============================================================================
# Fonctions de sauvegarde
# =============================================================================

create_backup() {
    if [ "$NO_BACKUP" = true ]; then
        log "Sauvegarde ignorée (--no-backup)"
        return 0
    fi
    
    log "Appel du script de sauvegarde..."
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Création de la sauvegarde"
        echo -e "${YELLOW}→${NC} $BACKUP_SCRIPT"
        return 0
    fi
    
    # Vérifier que le script de sauvegarde existe
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        error "Script de sauvegarde non trouvé : $BACKUP_SCRIPT"
        return 1
    fi
    
    # Exécuter le script de sauvegarde
    if "$BACKUP_SCRIPT"; then
        success "Sauvegarde créée avec succès"
        return 0
    else
        error "Échec de la sauvegarde"
        return 1
    fi
}

# =============================================================================
# Fonctions de mise à jour
# =============================================================================

stop_and_remove_container() {
    log "Arrêt et suppression du conteneur existant..."
    
    if [ -n "$CONTAINER_NAME" ] && docker inspect "$CONTAINER_NAME" &> /dev/null; then
        execute_command \
            "docker rm -f $CONTAINER_NAME" \
            "Arrêt et suppression du conteneur $CONTAINER_NAME"
    else
        log "Aucun conteneur $CONTAINER_NAME à arrêter (nom vide ou conteneur inexistant)"
    fi
}

pull_latest_image() {
    log "Téléchargement de la dernière image Docker..."
    
    execute_command \
        "docker pull $IMAGE_NAME" \
        "Téléchargement de $IMAGE_NAME"
}

restart_services() {
    log "Redémarrage des services avec Docker Compose..."
    
    # Change to project root to use the symlinked docker-compose.yml
    cd "$PROJECT_ROOT"
    
    local compose_cmd="docker-compose"
    if [ -n "$COMPOSE_PROJECT_NAME" ]; then
        compose_cmd="$compose_cmd -p \"$COMPOSE_PROJECT_NAME\""
    fi
    compose_cmd="$compose_cmd up -d"
    
    execute_command \
        "$compose_cmd" \
        "Redémarrage avec Docker Compose ($ENVIRONMENT)"
}

# =============================================================================
# Fonctions de vérification post-mise à jour
# =============================================================================

verify_update() {
    log "Vérification de la mise à jour..."
    
    # Attendre que le conteneur démarre
    if [ "$DRY_RUN" = false ]; then
        sleep 5
        
        local max_attempts=30
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if [ -n "$CONTAINER_NAME" ] && docker inspect "$CONTAINER_NAME" &> /dev/null; then
                local container_status
                container_status=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Status}}')
                
                if [ "$container_status" = "running" ]; then
                    success "Conteneur démarré avec succès"
                    break
                else
                    log "Tentative $attempt/$max_attempts - État: $container_status"
                fi
            else
                log "Tentative $attempt/$max_attempts - Conteneur $CONTAINER_NAME non trouvé"
            fi
            
            sleep 2
            ((attempt++))
        done
        
        if [ $attempt -gt $max_attempts ]; then
            error "Le conteneur n'a pas démarré correctement"
            show_logs
            return 1
        fi
        
        # Vérifier la nouvelle version
        log "Vérification de la nouvelle version..."
        if [ -n "$CONTAINER_NAME" ]; then
            local new_image
            new_image=$(docker inspect "$CONTAINER_NAME" --format='{{.Config.Image}}' 2>/dev/null || echo "inconnu")
            success "Nouvelle image : $new_image"
        fi
        
        # Test de connectivité (optionnel)
        log "Test de connectivité sur http://127.0.0.1:8080..."
        if command -v curl &> /dev/null; then
            if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080 | grep -q "200\|302\|301"; then
                success "OpenWebUI est accessible ✓"
            else
                warning "OpenWebUI pourrait ne pas être complètement démarré"
            fi
        else
            log "curl non disponible, vérification manuelle recommandée"
        fi
    else
        log "Vérification simulée"
    fi
}

show_logs() {
    if [ "$DRY_RUN" = false ]; then
        warning "Affichage des derniers logs en cas de problème :"
        # Change to project root to use the symlinked docker-compose.yml
        cd "$PROJECT_ROOT"
        local compose_cmd="docker-compose"
        if [ -n "$COMPOSE_PROJECT_NAME" ]; then
            compose_cmd="$compose_cmd -p \"$COMPOSE_PROJECT_NAME\""
        fi
        eval "$compose_cmd logs --tail=20" || true
    fi
}

# =============================================================================
# Fonction principale
# =============================================================================

main_update() {
    echo "🔄 Mise à jour automatique d'OpenWebUI"
    echo "========================================"
    echo
    
    check_prerequisites
    get_current_version
    
    # Demander confirmation pour la sauvegarde si pas d'option spécifiée
    if [ "$FORCE_BACKUP" = false ] && [ "$NO_BACKUP" = false ] && [ "$DRY_RUN" = false ]; then
        echo
        read -p "Voulez-vous créer une sauvegarde avant la mise à jour ? (o/N) " -r
        echo
        if [[ $REPLY =~ ^[OoYy]$ ]]; then
            FORCE_BACKUP=true
        fi
    fi
    
    if [ "$FORCE_BACKUP" = true ]; then
        create_backup
    fi
    
    stop_and_remove_container
    pull_latest_image
    restart_services
    verify_update
    
    echo
    success "🎉 Mise à jour terminée avec succès !"
    echo
    log "OpenWebUI est accessible à : http://127.0.0.1:8080"
    log "Environnement : $ENVIRONMENT"
    
    echo
    log "Commandes utiles :"
    local compose_base="docker-compose"
    if [ -n "$COMPOSE_PROJECT_NAME" ]; then
        compose_base="$compose_base -p \"$COMPOSE_PROJECT_NAME\""
    fi
    echo "  • Voir les logs : $compose_base logs -f"
    echo "  • Redémarrer : $compose_base restart"
    echo "  • Arrêter : $compose_base down"
}

# =============================================================================
# Gestion d'erreur globale
# =============================================================================

cleanup() {
    if [ $? -ne 0 ]; then
        echo
        error "❌ Erreur durant la mise à jour"
        show_logs
        echo
        log "Pour un rollback manuel, consultez la documentation dans docs/OPENWEBUI.md"
    fi
}

trap cleanup EXIT

# =============================================================================
# Parsing des arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --backup)
            FORCE_BACKUP=true
            shift
            ;;
        --no-backup)
            NO_BACKUP=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --env)
            ENV_OVERRIDE="$2"
            if [[ "$ENV_OVERRIDE" != "local" && "$ENV_OVERRIDE" != "prod" ]]; then
                error "Environnement non valide : $ENV_OVERRIDE"
                error "Environnements supportés : local, prod"
                exit 1
            fi
            shift 2
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            error "Option inconnue : $1"
            show_help
            exit 1
            ;;
    esac
done

# Validation des options
if [ "$FORCE_BACKUP" = true ] && [ "$NO_BACKUP" = true ]; then
    error "Les options --backup et --no-backup sont incompatibles"
    exit 1
fi

# =============================================================================
# Exécution principale
# =============================================================================

if [ "$SHOW_HELP" = true ]; then
    show_help
    exit 0
fi

main_update 
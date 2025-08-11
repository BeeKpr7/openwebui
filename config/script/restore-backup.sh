#!/bin/bash

# =============================================================================
# Script de restauration de sauvegarde OpenWebUI
# =============================================================================
# Ce script restaure une sauvegarde OpenWebUI vers l'environnement local
#
# Usage: ./restore-backup.sh [OPTIONS] BACKUP_FILE
# Options:
#   --local-volume       : Nom du volume local (défaut: détection automatique)
#   --dry-run            : Simulation sans restauration effective
#   --backup-current     : Créer une sauvegarde avant restauration
#   --quiet              : Mode silencieux
#   --help               : Afficher cette aide
# =============================================================================

set -euo pipefail

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Options par défaut
LOCAL_VOLUME=""
DRY_RUN=false
BACKUP_CURRENT=false
QUIET_MODE=false
SHOW_HELP=false
BACKUP_FILE=""

# =============================================================================
# Fonctions utilitaires
# =============================================================================

show_help() {
    cat << EOF
🔄 Script de restauration de sauvegarde OpenWebUI

USAGE:
    $0 [OPTIONS] BACKUP_FILE

ARGUMENTS:
    BACKUP_FILE                     Chemin vers le fichier de sauvegarde (.tar.gz)

OPTIONS:
    --local-volume VOLUME           Nom du volume Docker local à restaurer
    --dry-run                       Simulation sans restauration effective
    --backup-current                Créer une sauvegarde avant restauration
    --quiet                         Mode silencieux
    --help                          Afficher cette aide

EXAMPLES:
    $0 backups/update_openwebui_20250811_123437.tar.gz
    $0 --backup-current --local-volume apollo-13_open-webui backups/latest.tar.gz
    $0 --dry-run backups/update_openwebui_20250811_123437.tar.gz

NOTES:
    - Le volume local sera détecté automatiquement si non spécifié
    - Une sauvegarde de sécurité peut être créée avant restauration
    - Le conteneur OpenWebUI sera arrêté pendant la restauration

EOF
}

log() {
    if [ "$QUIET_MODE" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    else
        echo "[INFO] $1"
    fi
}

success() {
    if [ "$QUIET_MODE" = false ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    else
        echo "[SUCCESS] $1"
    fi
}

warning() {
    if [ "$QUIET_MODE" = false ]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    else
        echo "[WARNING] $1"
    fi
}

error() {
    if [ "$QUIET_MODE" = false ]; then
        echo -e "${RED}[ERROR]${NC} $1" >&2
    else
        echo "[ERROR] $1" >&2
    fi
}

# =============================================================================
# Fonctions de vérification
# =============================================================================

detect_local_volume() {
    log "Détection du volume OpenWebUI local..."
    
    # Chercher les volumes qui contiennent "open-webui" ou "openwebui"
    local volumes
    volumes=$(docker volume ls --format "{{.Name}}" | grep -E "open-webui|openwebui" || true)
    
    if [ -n "$volumes" ]; then
        # Prendre le premier volume trouvé
        LOCAL_VOLUME=$(echo "$volumes" | head -n1)
        log "Volume local détecté : $LOCAL_VOLUME"
        return 0
    fi
    
    error "Impossible de trouver le volume OpenWebUI local"
    error "Volumes disponibles :"
    docker volume ls --format "{{.Name}}" | sed 's/^/  - /' || true
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
    
    # Détecter le volume local si non spécifié
    if [ -z "$LOCAL_VOLUME" ]; then
        if ! detect_local_volume; then
            error "Spécifiez le volume avec --local-volume ou assurez-vous qu'OpenWebUI est déployé"
            exit 1
        fi
    fi
    
    # Vérifier que le volume local existe
    if ! docker volume inspect "$LOCAL_VOLUME" &> /dev/null; then
        error "Volume Docker local '$LOCAL_VOLUME' introuvable"
        exit 1
    fi
    
    # Vérifier que le fichier de sauvegarde existe
    if [ ! -f "$BACKUP_FILE" ]; then
        error "Fichier de sauvegarde introuvable : $BACKUP_FILE"
        exit 1
    fi
    
    # Vérifier que c'est un fichier tar.gz valide
    if ! file "$BACKUP_FILE" | grep -q "gzip compressed"; then
        error "Le fichier de sauvegarde n'est pas un fichier tar.gz valide"
        exit 1
    fi
    
    success "Prérequis validés"
}

# =============================================================================
# Fonctions de sauvegarde et restauration
# =============================================================================

backup_current_data() {
    log "Création d'une sauvegarde de sécurité des données actuelles..."
    
    local backup_dir="$PROJECT_ROOT/backups"
    mkdir -p "$backup_dir"
    
    local safety_backup="$backup_dir/safety_backup_${TIMESTAMP}.tar.gz"
    
    if docker run --rm \
        -v "$LOCAL_VOLUME:/data:ro" \
        -v "$backup_dir:/backup" \
        alpine:latest \
        tar czf "/backup/safety_backup_${TIMESTAMP}.tar.gz" -C /data .; then
        
        local file_size
        file_size=$(ls -lh "$safety_backup" | awk '{print $5}')
        success "Sauvegarde de sécurité créée : $safety_backup ($file_size)"
        return 0
    else
        error "Échec de la création de la sauvegarde de sécurité"
        return 1
    fi
}

stop_openwebui_containers() {
    log "Arrêt des conteneurs OpenWebUI..."
    
    # Chercher les conteneurs OpenWebUI en cours d'exécution
    local containers
    containers=$(docker ps --format "{{.Names}}" | grep -E "openwebui|open-webui|apollo" || true)
    
    if [ -n "$containers" ]; then
        echo "$containers" | while read -r container; do
            log "Arrêt du conteneur : $container"
            if [ "$DRY_RUN" = false ]; then
                docker stop "$container" || warning "Impossible d'arrêter $container"
            fi
        done
    else
        log "Aucun conteneur OpenWebUI en cours d'exécution"
    fi
    
    # Attendre un peu pour s'assurer que les conteneurs sont arrêtés
    if [ "$DRY_RUN" = false ]; then
        sleep 2
    fi
}

restore_backup() {
    log "Restauration de la sauvegarde vers le volume local..."
    
    if [ "$DRY_RUN" = true ]; then
        log "MODE DRY-RUN : Simulation de la restauration"
        log "Commande qui serait exécutée :"
        echo "  docker run --rm -v $LOCAL_VOLUME:/data -v $(dirname "$BACKUP_FILE"):/backup alpine tar xzf /backup/$(basename "$BACKUP_FILE") -C /data"
        return 0
    fi
    
    # Nettoyer le volume avant restauration (optionnel, demander confirmation)
    if [ "$QUIET_MODE" = false ]; then
        echo
        warning "Cette opération va remplacer toutes les données actuelles dans le volume $LOCAL_VOLUME"
        read -p "Voulez-vous continuer ? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Restauration annulée"
            return 1
        fi
    fi
    
    # Effectuer la restauration
    local backup_dir
    backup_dir=$(dirname "$BACKUP_FILE")
    local backup_filename
    backup_filename=$(basename "$BACKUP_FILE")
    
    if docker run --rm \
        -v "$LOCAL_VOLUME:/data" \
        -v "$backup_dir:/backup" \
        alpine:latest \
        sh -c "rm -rf /data/* /data/.[^.]* && tar xzf /backup/$backup_filename -C /data"; then
        
        success "Restauration terminée avec succès"
        return 0
    else
        error "Échec de la restauration"
        return 1
    fi
}

start_openwebui() {
    log "Redémarrage d'OpenWebUI..."
    
    if [ "$DRY_RUN" = true ]; then
        log "MODE DRY-RUN : Simulation du redémarrage"
        return 0
    fi
    
    # Aller dans le répertoire du projet et redémarrer
    cd "$PROJECT_ROOT"
    
    if [ -f "docker-compose.yml" ]; then
        if docker-compose up -d; then
            success "OpenWebUI redémarré avec succès"
            log "L'application sera disponible dans quelques instants sur http://localhost:8080"
            return 0
        else
            error "Échec du redémarrage d'OpenWebUI"
            return 1
        fi
    else
        warning "Fichier docker-compose.yml introuvable, redémarrage manuel nécessaire"
        return 1
    fi
}

# =============================================================================
# Fonction principale
# =============================================================================

main_restore() {
    if [ "$QUIET_MODE" = false ]; then
        echo "🔄 Restauration de sauvegarde OpenWebUI"
        echo "======================================"
        echo
    fi
    
    log "Fichier de sauvegarde : $BACKUP_FILE"
    log "Volume de destination : ${LOCAL_VOLUME:-"(détection automatique)"}"
    
    if [ "$DRY_RUN" = true ]; then
        warning "MODE DRY-RUN ACTIVÉ - Aucune modification ne sera effectuée"
    fi
    
    echo
    
    check_prerequisites
    
    if [ "$BACKUP_CURRENT" = true ]; then
        backup_current_data
        echo
    fi
    
    stop_openwebui_containers
    echo
    
    restore_backup
    echo
    
    start_openwebui
    
    if [ "$QUIET_MODE" = false ]; then
        echo
        success "🎉 Restauration terminée avec succès !"
        echo
        log "Votre environnement local a été restauré avec les données de production"
        log "Accédez à OpenWebUI : http://localhost:8080"
        
        if [ "$BACKUP_CURRENT" = true ]; then
            echo
            log "Une sauvegarde de sécurité des données précédentes a été créée"
            log "Elle se trouve dans : $PROJECT_ROOT/backups/safety_backup_${TIMESTAMP}.tar.gz"
        fi
    fi
}

# =============================================================================
# Parsing des arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --local-volume)
            LOCAL_VOLUME="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --backup-current)
            BACKUP_CURRENT=true
            shift
            ;;
        --quiet)
            QUIET_MODE=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        -*)
            error "Option inconnue : $1"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$BACKUP_FILE" ]; then
                BACKUP_FILE="$1"
            else
                error "Trop d'arguments : $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# =============================================================================
# Exécution principale
# =============================================================================

if [ "$SHOW_HELP" = true ]; then
    show_help
    exit 0
fi

if [ -z "$BACKUP_FILE" ]; then
    error "Fichier de sauvegarde requis"
    show_help
    exit 1
fi

# Convertir en chemin absolu si nécessaire
if [[ "$BACKUP_FILE" != /* ]]; then
    BACKUP_FILE="$PROJECT_ROOT/$BACKUP_FILE"
fi

main_restore

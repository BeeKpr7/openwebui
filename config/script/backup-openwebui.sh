#!/bin/bash

# =============================================================================
# Script de sauvegarde automatique d'OpenWebUI
# =============================================================================
# Ce script crée une sauvegarde du volume Docker OpenWebUI
# Peut être exécuté indépendamment ou via cron
#
# Usage: ./backup-openwebui.sh [OPTIONS]
# Options:
#   --quiet          : Mode silencieux (pour cron)
#   --output-dir     : Répertoire de destination (défaut: backups/)
#   --s3-bucket      : Bucket S3 pour sauvegarde distante
#   --s3-prefix      : Préfixe S3 (défaut: openwebui-backups/)
#   --s3-only        : Sauvegarder uniquement vers S3 (pas de copie locale)
#   --help           : Afficher cette aide
# =============================================================================

set -euo pipefail

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VOLUME_NAME=""
BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_PREFIX="update_openwebui_"

# Chargement des variables d'environnement
load_env_file() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        log "Chargement des variables depuis : $env_file"
        # Exporter les variables en ignorant les commentaires et lignes vides
        while IFS= read -r line || [ -n "$line" ]; do
            # Ignorer les commentaires et lignes vides
            if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "${line// }" ]]; then
                # Exporter la variable si elle n'est pas déjà définie
                local var_name="${line%%=*}"
                if [ -z "${!var_name:-}" ]; then
                    export "$line"
                fi
            fi
        done < "$env_file"
    else
        warning "Fichier d'environnement introuvable : $env_file"
    fi
}

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Options par défaut
QUIET_MODE=false
CUSTOM_OUTPUT_DIR=""
SHOW_HELP=false
S3_BUCKET=""
S3_PREFIX="openwebui-backups/"
S3_ONLY=false
ENV_FILE=""
ENV_TYPE=""

# =============================================================================
# Fonctions utilitaires
# =============================================================================

show_help() {
    cat << EOF
💾 Script de sauvegarde OpenWebUI

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --quiet                     Mode silencieux (pas de couleurs, pour cron)
    --output-dir DIR            Répertoire de destination personnalisé
    --s3-bucket BUCKET          Bucket S3 pour sauvegarde distante
    --s3-prefix PREFIX          Préfixe S3 (défaut: openwebui-backups/)
    --s3-only                   Sauvegarder uniquement vers S3 (pas de copie locale)
    --env local|prod            Environnement à utiliser (charge .env.local ou .env.prod)
    --env-file FILE             Fichier d'environnement personnalisé à charger
    --help                      Afficher cette aide

EXAMPLES:
    $0                                              # Sauvegarde locale standard
    $0 --quiet                                      # Pour utilisation avec cron
    $0 --env local                                  # Avec variables d'environnement locales
    $0 --env prod --s3-only                         # Sauvegarde S3 prod uniquement
    $0 --env-file .env.custom                       # Fichier d'environnement personnalisé
    $0 --output-dir /path/to/backup                 # Répertoire personnalisé
    $0 --s3-bucket mon-bucket-s3                    # Sauvegarde locale + S3
    $0 --s3-bucket mon-bucket-s3 --s3-only          # Sauvegarde S3 uniquement
    $0 --s3-bucket mon-bucket-s3 --s3-prefix bkp/   # Avec préfixe S3 personnalisé

VARIABLES D'ENVIRONNEMENT:
    Si --env ou --env-file est spécifié, les variables suivantes seront chargées :
    - AWS_ACCESS_KEY_ID         : Clé d'accès AWS
    - AWS_SECRET_ACCESS_KEY     : Clé secrète AWS
    - AWS_DEFAULT_REGION        : Région AWS par défaut
    - S3_BACKUP_BUCKET          : Nom du bucket S3 (remplace --s3-bucket)
    - S3_BACKUP_PREFIX          : Préfixe S3 (remplace --s3-prefix)

SORTIE:
    Le fichier de sauvegarde sera nommé : ${BACKUP_PREFIX}YYYYMMDD_HHMMSS.tar.gz

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

detect_volume_name() {
    log "Détection du volume OpenWebUI..."
    
    # Chercher le conteneur OpenWebUI en cours d'exécution
    local container_name
    container_name=$(docker ps --format "{{.Names}}" | grep -E "openwebui|open-webui" | head -n1)
    
    if [ -n "$container_name" ]; then
        log "Conteneur trouvé: $container_name"
        # Extraire le nom du volume depuis le conteneur
        VOLUME_NAME=$(docker inspect "$container_name" --format='{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}' | head -n1)
        if [ -n "$VOLUME_NAME" ]; then
            log "Volume détecté: $VOLUME_NAME"
            return 0
        fi
    fi
    
    # Fallback: chercher des volumes qui contiennent "open-webui" dans le nom
    VOLUME_NAME=$(docker volume ls --format "{{.Name}}" | grep "open-webui" | head -n1)
    if [ -n "$VOLUME_NAME" ]; then
        log "Volume trouvé par recherche: $VOLUME_NAME"
        return 0
    fi
    
    error "Impossible de trouver le volume OpenWebUI"
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
    
    # Détecter le nom du volume
    if ! detect_volume_name; then
        error "Assurez-vous qu'OpenWebUI a été déployé au préalable"
        exit 1
    fi
    
    # Vérifier que le volume existe
    if ! docker volume inspect "$VOLUME_NAME" &> /dev/null; then
        error "Volume Docker '$VOLUME_NAME' introuvable"
        error "Assurez-vous qu'OpenWebUI a été déployé au préalable"
        exit 1
    fi
    
    # Vérifier AWS CLI si S3 requis
    if [ -n "$S3_BUCKET" ]; then
        if ! command -v aws &> /dev/null; then
            error "AWS CLI n'est pas installé (requis pour S3)"
            error "Installation: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
            exit 1
        fi
        
        # Vérifier la configuration AWS
        # Si les variables d'environnement sont définies, on peut continuer
        if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
            log "Variables AWS définies dans l'environnement"
        elif ! aws sts get-caller-identity &> /dev/null; then
            error "AWS CLI n'est pas configuré correctement"
            error "Exécutez: aws configure ou définissez AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY"
            exit 1
        fi
        
        log "Configuration AWS validée"
    fi
    
    success "Prérequis validés"
}

# =============================================================================
# Fonction de sauvegarde
# =============================================================================

create_backup() {
    log "Création d'une sauvegarde du volume OpenWebUI..."
    
    # Déterminer le répertoire de sauvegarde
    local backup_dir
    if [ "$S3_ONLY" = true ]; then
        # Créer un répertoire temporaire pour S3 uniquement
        backup_dir=$(mktemp -d)
        log "Répertoire temporaire pour S3 : $backup_dir"
    elif [ -n "$CUSTOM_OUTPUT_DIR" ]; then
        backup_dir="$CUSTOM_OUTPUT_DIR"
    else
        backup_dir="$BACKUP_DIR"
    fi
    
    # Créer le répertoire de sauvegarde si nécessaire
    mkdir -p "$backup_dir"
    
    local backup_file="$backup_dir/${BACKUP_PREFIX}${TIMESTAMP}.tar.gz"
    local backup_filename="${BACKUP_PREFIX}${TIMESTAMP}.tar.gz"
    
    if [ "$S3_ONLY" = false ]; then
        log "Destination locale : $backup_file"
    fi
    
    # Créer la sauvegarde
    if docker run --rm \
        -v "$VOLUME_NAME:/data:ro" \
        -v "$backup_dir:/backup" \
        alpine:latest \
        tar czf "/backup/$backup_filename" -C /data .; then
        
        # Vérifier que le fichier a bien été créé
        if [ -f "$backup_file" ]; then
            local file_size
            file_size=$(ls -lh "$backup_file" | awk '{print $5}')
            success "Sauvegarde créée avec succès ($file_size)"
            
            if [ "$S3_ONLY" = false ]; then
                echo "Chemin local : $(realpath "$backup_file")"
            fi
            
            # Upload vers S3 si configuré
            if [ -n "$S3_BUCKET" ]; then
                upload_to_s3 "$backup_file" "$backup_filename"
            fi
            
            # Nettoyer le fichier temporaire si S3 uniquement
            if [ "$S3_ONLY" = true ]; then
                rm -f "$backup_file"
                rmdir "$backup_dir" 2>/dev/null || true
            fi
            
            return 0
        else
            error "Le fichier de sauvegarde n'a pas été créé"
            return 1
        fi
    else
        error "Échec de la création de sauvegarde"
        return 1
    fi
}

# =============================================================================
# Fonction d'upload S3
# =============================================================================

upload_to_s3() {
    local local_file="$1"
    local filename="$2"
    local s3_key="${S3_PREFIX}${filename}"
    local s3_url="s3://${S3_BUCKET}/${s3_key}"
    
    log "Upload vers S3 : $s3_url"
    
    # Calculer le MD5 local pour vérification
    local local_md5
    if command -v md5sum &> /dev/null; then
        local_md5=$(md5sum "$local_file" | cut -d' ' -f1)
    elif command -v md5 &> /dev/null; then
        local_md5=$(md5 -q "$local_file")
    else
        local_md5=""
    fi
    
    # Upload vers S3 avec endpoint Hetzner
    if aws s3 cp "$local_file" "$s3_url" --endpoint-url https://nbg1.your-objectstorage.com --only-show-errors; then
        success "Upload S3 réussi : $s3_url"
        
        # Vérification optionnelle de l'intégrité
        if [ -n "$local_md5" ]; then
            log "Vérification de l'intégrité..."
            local s3_etag
            s3_etag=$(aws s3api head-object --bucket "$S3_BUCKET" --key "$s3_key" --endpoint-url https://nbg1.your-objectstorage.com --query 'ETag' --output text 2>/dev/null | tr -d '"')
            
            if [ "$local_md5" = "$s3_etag" ]; then
                success "Intégrité vérifiée ✓"
            else
                warning "Les checksums ne correspondent pas (peut être normal pour des fichiers volumineux)"
            fi
        fi
        
        return 0
    else
        error "Échec de l'upload S3"
        return 1
    fi
}

# =============================================================================
# Fonction de nettoyage (optionnel)
# =============================================================================

cleanup_old_backups() {
    # Nettoyage local (seulement si pas en mode S3 uniquement)
    if [ "$S3_ONLY" = false ]; then
        local backup_dir
        if [ -n "$CUSTOM_OUTPUT_DIR" ]; then
            backup_dir="$CUSTOM_OUTPUT_DIR"
        else
            backup_dir="$BACKUP_DIR"
        fi
        
        if [ -d "$backup_dir" ]; then
            # Garder seulement les 10 dernières sauvegardes locales
            local old_backups
            old_backups=$(find "$backup_dir" -name "${BACKUP_PREFIX}*.tar.gz" -type f | sort -r | tail -n +11)
            
            if [ -n "$old_backups" ]; then
                log "Suppression des anciennes sauvegardes locales..."
                echo "$old_backups" | while read -r file; do
                    if [ -f "$file" ]; then
                        rm "$file"
                        log "Supprimé localement : $(basename "$file")"
                    fi
                done
            fi
        fi
    fi
    
    # Nettoyage S3 (si configuré)
    if [ -n "$S3_BUCKET" ]; then
        log "Vérification des anciennes sauvegardes S3..."
        
        # Lister les objets S3 avec le préfixe et garder les 20 plus récents
        local s3_objects
        s3_objects=$(aws s3api list-objects-v2 \
            --bucket "$S3_BUCKET" \
            --prefix "$S3_PREFIX$BACKUP_PREFIX" \
            --endpoint-url https://nbg1.your-objectstorage.com \
            --query 'Contents[?Size>`0`].[Key,LastModified]' \
            --output text 2>/dev/null | \
            sort -k2 -r | \
            tail -n +21 | \
            cut -f1)
        
        if [ -n "$s3_objects" ]; then
            log "Suppression des anciennes sauvegardes S3..."
            echo "$s3_objects" | while read -r key; do
                if [ -n "$key" ]; then
                    if aws s3 rm "s3://$S3_BUCKET/$key" --endpoint-url https://nbg1.your-objectstorage.com --only-show-errors; then
                        log "Supprimé S3 : $(basename "$key")"
                    fi
                fi
            done
        fi
    fi
}

# =============================================================================
# Fonction principale
# =============================================================================

main_backup() {
    if [ "$QUIET_MODE" = false ]; then
        echo "💾 Sauvegarde automatique d'OpenWebUI"
        echo "====================================="
        echo
    fi
    
    # Charger les variables d'environnement si spécifié
    if [ -n "$ENV_TYPE" ]; then
        case "$ENV_TYPE" in
            "local")
                ENV_FILE="$PROJECT_ROOT/.env.local"
                log "Utilisation de l'environnement local : .env.local"
                ;;
            "prod")
                ENV_FILE="$PROJECT_ROOT/.env.prod"
                log "Utilisation de l'environnement de production : .env.prod"
                ;;
            *)
                error "Type d'environnement invalide : $ENV_TYPE (utilisez 'local' ou 'prod')"
                exit 1
                ;;
        esac
    fi
    
    if [ -n "$ENV_FILE" ]; then
        if [[ "$ENV_FILE" = /* ]]; then
            # Chemin absolu
            load_env_file "$ENV_FILE"
        else
            # Chemin relatif depuis la racine du projet
            load_env_file "$PROJECT_ROOT/$ENV_FILE"
        fi
        
        # Utiliser les variables d'environnement si disponibles
        if [ -z "$S3_BUCKET" ] && [ -n "${S3_BACKUP_BUCKET:-}" ]; then
            S3_BUCKET="$S3_BACKUP_BUCKET"
            log "Bucket S3 défini depuis l'environnement : $S3_BUCKET"
        fi
        
        if [ "$S3_PREFIX" = "openwebui-backups/" ] && [ -n "${S3_BACKUP_PREFIX:-}" ]; then
            S3_PREFIX="$S3_BACKUP_PREFIX"
            log "Préfixe S3 défini depuis l'environnement : $S3_PREFIX"
        fi
    fi
    
    check_prerequisites
    create_backup
    cleanup_old_backups
    
    if [ "$QUIET_MODE" = false ]; then
        echo
        success "🎉 Sauvegarde terminée avec succès !"
        echo
        
        if [ "$S3_ONLY" = false ]; then
            log "Pour restaurer cette sauvegarde locale :"
            local backup_path
            if [ -n "$CUSTOM_OUTPUT_DIR" ]; then
                backup_path="$CUSTOM_OUTPUT_DIR"
            else
                backup_path="$BACKUP_DIR"
            fi
            echo "  docker run --rm -v $VOLUME_NAME:/data -v $backup_path:/backup alpine tar xzf /backup/${BACKUP_PREFIX}${TIMESTAMP}.tar.gz -C /data"
        fi
        
        if [ -n "$S3_BUCKET" ]; then
            echo
            log "Pour restaurer depuis S3 :"
            echo "  # Télécharger depuis S3"
            echo "  aws s3 cp s3://$S3_BUCKET/${S3_PREFIX}${BACKUP_PREFIX}${TIMESTAMP}.tar.gz /tmp/"
            echo "  # Restaurer dans Docker"
            echo "  docker run --rm -v $VOLUME_NAME:/data -v /tmp:/backup alpine tar xzf /backup/${BACKUP_PREFIX}${TIMESTAMP}.tar.gz -C /data"
        fi
    fi
}

# =============================================================================
# Parsing des arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --quiet)
            QUIET_MODE=true
            shift
            ;;
        --output-dir)
            CUSTOM_OUTPUT_DIR="$2"
            shift 2
            ;;
        --s3-bucket)
            S3_BUCKET="$2"
            shift 2
            ;;
        --s3-prefix)
            S3_PREFIX="$2"
            # S'assurer que le préfixe se termine par /
            if [[ ! "$S3_PREFIX" =~ /$ ]]; then
                S3_PREFIX="${S3_PREFIX}/"
            fi
            shift 2
            ;;
        --s3-only)
            S3_ONLY=true
            shift
            ;;
        --env)
            ENV_TYPE="$2"
            shift 2
            ;;
        --env-file)
            ENV_FILE="$2"
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

# =============================================================================
# Exécution principale
# =============================================================================

if [ "$SHOW_HELP" = true ]; then
    show_help
    exit 0
fi

main_backup 
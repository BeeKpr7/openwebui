#!/bin/bash

# =============================================================================
# Script de sauvegarde automatique d'OpenWebUI avec interface Gum
# =============================================================================
# Ce script crée une sauvegarde du volume Docker OpenWebUI
# Interface interactive utilisant charmbracelet/gum
#
# Usage: ./backup-openwebui.sh [OPTIONS]
# Options:
#   --quiet          : Mode silencieux (pour cron)
#   --help           : Afficher cette aide
# =============================================================================

set -euo pipefail

# Vérifier que Gum est installé
if ! command -v gum &> /dev/null; then
    echo "❌ Gum n'est pas installé. Installez-le avec:"
    echo "   brew install gum  # macOS/Linux"
    echo "   ou visitez: https://github.com/charmbracelet/gum"
    exit 1
fi

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
        gum_log "info" "Chargement des variables depuis : $env_file"
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
        gum_log "warn" "Fichier d'environnement introuvable : $env_file"
    fi
}

# Variables par défaut
QUIET_MODE=false
BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_PREFIX="update_openwebui_"

# Configuration interactive
CUSTOM_OUTPUT_DIR=""
SHOW_HELP=false
S3_BUCKET=""
S3_PREFIX="openwebui-backups/"
S3_ONLY=false
DATA_ONLY=false
ENV_FILE=""
ENV_TYPE=""

# =============================================================================
# Fonctions utilitaires avec Gum
# =============================================================================

show_help() {
    gum format --type markdown << 'EOF'
# 💾 Script de sauvegarde OpenWebUI

## Usage
```bash
./backup-openwebui.sh [OPTIONS]
```

## Options
- `--quiet` : Mode silencieux (pour cron)
- `--help` : Afficher cette aide

## Mode interactif
Sans options, le script vous guidera interactivement pour configurer :
- Type de sauvegarde (locale, S3, ou les deux)
- Répertoire de destination personnalisé
- Configuration S3 (bucket, préfixe)
- Sauvegarde complète ou données essentielles uniquement
- Variables d'environnement (.env.local, .env.prod, ou fichier personnalisé)

## Variables d'environnement supportées
- `AWS_ACCESS_KEY_ID` : Clé d'accès AWS
- `AWS_SECRET_ACCESS_KEY` : Clé secrète AWS  
- `AWS_DEFAULT_REGION` : Région AWS par défaut
- `S3_BACKUP_BUCKET` : Nom du bucket S3
- `S3_BACKUP_PREFIX` : Préfixe S3

## Sortie
Le fichier de sauvegarde sera nommé : `${BACKUP_PREFIX}YYYYMMDD_HHMMSS.tar.gz`
EOF
}

# Fonction de logging unifiée avec Gum
gum_log() {
    local level="$1"
    local message="$2"
    
    if [ "$QUIET_MODE" = false ]; then
        case "$level" in
            "info")
                gum log --structured --level info "$message"
                ;;
            "success")
                gum style --foreground 212 --bold "✅ $message"
                ;;
            "warn")
                gum log --structured --level warn "$message"
                ;;
            "error")
                gum log --structured --level error "$message" >&2
                ;;
            *)
                echo "$message"
                ;;
        esac
    else
        echo "[$level] $message"
    fi
}

# Fonctions de logging simplifiées
log() { gum_log "info" "$1"; }
success() { gum_log "success" "$1"; }
warning() { gum_log "warn" "$1"; }
error() { gum_log "error" "$1"; }

# =============================================================================
# Interface interactive avec Gum
# =============================================================================

interactive_setup() {
    # En-tête stylisé
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 60 --margin "1 2" --padding "2 4" \
        "💾 Sauvegarde OpenWebUI" "Configuration interactive"
    
    echo
    
    # 1. Chargement des variables d'environnement
    if gum confirm "Voulez-vous charger des variables d'environnement ?"; then
        ENV_TYPE=$(gum choose --header "Choisir le type d'environnement :" \
            "local (.env.local)" \
            "prod (.env.prod)" \
            "fichier personnalisé")
        
        case "$ENV_TYPE" in
            "local (.env.local)")
                ENV_TYPE="local"
                ENV_FILE="$PROJECT_ROOT/.env.local"
                ;;
            "prod (.env.prod)")
                ENV_TYPE="prod"
                ENV_FILE="$PROJECT_ROOT/.env.prod"
                ;;
            "fichier personnalisé")
                ENV_FILE=$(gum file --directory="$PROJECT_ROOT" --file \
                    --header "Sélectionner le fichier d'environnement :")
                ENV_TYPE=""
                ;;
        esac
        
        # Charger immédiatement les variables d'environnement
        if [ -n "$ENV_FILE" ]; then
            load_env_file "$ENV_FILE"
            gum_log "info" "Variables d'environnement chargées depuis : $ENV_FILE"
        fi
        echo
    fi
    
    # 2. Type de sauvegarde
    BACKUP_TYPE=$(gum choose --header "Type de sauvegarde :" \
        "Locale uniquement" \
        "S3 uniquement" \
        "Locale + S3")
    
    case "$BACKUP_TYPE" in
        "S3 uniquement")
            S3_ONLY=true
            ;;
        "Locale + S3")
            S3_ONLY=false
            ;;
        *)
            S3_ONLY=false
            ;;
    esac
    echo
    
    # 3. Configuration S3 si nécessaire
    if [[ "$BACKUP_TYPE" == *"S3"* ]]; then
        gum style --foreground 99 --bold "🔧 Configuration S3"
        echo
        
        # Utiliser les valeurs du fichier d'environnement si disponibles
        local default_bucket="${S3_BACKUP_BUCKET:-mon-bucket-backup}"
        local default_prefix="${S3_BACKUP_PREFIX:-openwebui-backups/}"
        
        S3_BUCKET=$(gum input --header "Nom du bucket S3 :" \
            --placeholder "$default_bucket" \
            --value "${S3_BACKUP_BUCKET:-}")
        
        S3_PREFIX=$(gum input --header "Préfixe S3 (optionnel) :" \
            --placeholder "$default_prefix" \
            --value "${S3_BACKUP_PREFIX:-openwebui-backups/}")
        
        # S'assurer que le préfixe se termine par /
        if [[ -n "$S3_PREFIX" && ! "$S3_PREFIX" =~ /$ ]]; then
            S3_PREFIX="${S3_PREFIX}/"
        fi
        echo
    fi
    
    # 4. Répertoire de destination (si sauvegarde locale)
    if [ "$S3_ONLY" = false ]; then
        if gum confirm "Utiliser un répertoire de destination personnalisé ?"; then
            CUSTOM_OUTPUT_DIR=$(gum file --directory \
                --header "Sélectionner le répertoire de destination :")
        fi
        echo
    fi
    
    # 5. Type de données à sauvegarder
    DATA_TYPE=$(gum choose --header "Données à sauvegarder :" \
        "Sauvegarde complète (tous les fichiers)" \
        "Données essentielles uniquement (exclut cache, logs, modèles)")
    
    if [[ "$DATA_TYPE" == *"essentielles"* ]]; then
        DATA_ONLY=true
    fi
    echo
    
    # 6. Résumé de la configuration
    gum style --foreground 212 --bold "📋 Résumé de la configuration"
    echo
    
    gum format --type markdown << EOF
## Configuration choisie :

- **Type de sauvegarde** : $BACKUP_TYPE
- **Données** : $([ "$DATA_ONLY" = true ] && echo "Essentielles uniquement" || echo "Complète")
$([ -n "$ENV_TYPE" ] && echo "- **Environnement** : $ENV_TYPE")
$([ -n "$ENV_FILE" ] && echo "- **Fichier env** : $ENV_FILE")
$([ -n "$S3_BUCKET" ] && echo "- **Bucket S3** : $S3_BUCKET")
$([ -n "$S3_PREFIX" ] && echo "- **Préfixe S3** : $S3_PREFIX")
$([ -n "$CUSTOM_OUTPUT_DIR" ] && echo "- **Répertoire** : $CUSTOM_OUTPUT_DIR")
EOF
    
    echo
    if ! gum confirm "Confirmer et démarrer la sauvegarde ?"; then
        gum style --foreground 196 "❌ Sauvegarde annulée"
        exit 0
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
    gum style --foreground 99 --bold "🔄 Création de la sauvegarde"
    echo
    
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
    
    # Créer la sauvegarde avec spinner
    local tar_command
    if [ "$DATA_ONLY" = true ]; then
        log "Mode sauvegarde des données essentielles uniquement"
        # Exclure cache, logs, et fichiers temporaires volumineux
        tar_command="tar czf \"/backup/$backup_filename\" -C /data --exclude='cache/*' --exclude='*.log' --exclude='*.tmp' --exclude='temp/*' --exclude='logs/*' --exclude='models/*' ."
    else
        log "Mode sauvegarde complète"
        tar_command="tar czf \"/backup/$backup_filename\" -C /data ."
    fi
    
    # Exécuter la sauvegarde avec un spinner
    if gum spin --spinner dot --title "Création de l'archive en cours..." -- \
        docker run --rm \
        -v "$VOLUME_NAME:/data:ro" \
        -v "$backup_dir:/backup" \
        alpine:latest \
        sh -c "$tar_command"; then
        
        # Vérifier que le fichier a bien été créé
        if [ -f "$backup_file" ]; then
            local file_size
            file_size=$(ls -lh "$backup_file" | awk '{print $5}')
            if [ "$DATA_ONLY" = true ]; then
                success "Sauvegarde des données essentielles créée avec succès ($file_size)"
                gum style --foreground 240 "Exclusions appliquées : cache, logs, modèles, fichiers temporaires"
            else
                success "Sauvegarde complète créée avec succès ($file_size)"
            fi
            
            if [ "$S3_ONLY" = false ]; then
                gum style --foreground 99 "📁 Chemin local : $(realpath "$backup_file")"
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
    
    gum style --foreground 99 --bold "☁️ Upload vers S3"
    echo
    
    log "Destination S3 : $s3_url"
    
    # Calculer le MD5 local pour vérification
    local local_md5
    if command -v md5sum &> /dev/null; then
        local_md5=$(md5sum "$local_file" | cut -d' ' -f1)
    elif command -v md5 &> /dev/null; then
        local_md5=$(md5 -q "$local_file")
    else
        local_md5=""
    fi
    
    # Upload vers S3 avec spinner
    if gum spin --spinner dot --title "Upload en cours vers S3..." -- \
        aws s3 cp "$local_file" "$s3_url" --endpoint-url https://nbg1.your-objectstorage.com --only-show-errors; then
        
        success "Upload S3 réussi : $s3_url"
        
        # Vérification optionnelle de l'intégrité
        if [ -n "$local_md5" ]; then
            gum spin --spinner dot --title "Vérification de l'intégrité..." -- sleep 1
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
    # Charger les variables d'environnement si elles n'ont pas été chargées en mode interactif
    if [ -n "$ENV_TYPE" ] && [ -z "$ENV_FILE" ]; then
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
        
        load_env_file "$ENV_FILE"
        
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
        gum style \
            --foreground 212 --border-foreground 212 --border double \
            --align center --width 60 --margin "1 2" --padding "2 4" \
            "🎉 Sauvegarde terminée avec succès !"
        
        echo
        
        if [ "$S3_ONLY" = false ]; then
            gum style --foreground 99 --bold "📋 Commandes de restauration locale :"
            local backup_path
            if [ -n "$CUSTOM_OUTPUT_DIR" ]; then
                backup_path="$CUSTOM_OUTPUT_DIR"
            else
                backup_path="$BACKUP_DIR"
            fi
            
            gum format --type code << EOF
docker run --rm -v $VOLUME_NAME:/data -v $backup_path:/backup alpine \\
  tar xzf /backup/${BACKUP_PREFIX}${TIMESTAMP}.tar.gz -C /data
EOF
        fi
        
        if [ -n "$S3_BUCKET" ]; then
            echo
            gum style --foreground 99 --bold "☁️ Commandes de restauration S3 :"
            gum format --type code << EOF
# Télécharger depuis S3
aws s3 cp s3://$S3_BUCKET/${S3_PREFIX}${BACKUP_PREFIX}${TIMESTAMP}.tar.gz /tmp/

# Restaurer dans Docker
docker run --rm -v $VOLUME_NAME:/data -v /tmp:/backup alpine \\
  tar xzf /backup/${BACKUP_PREFIX}${TIMESTAMP}.tar.gz -C /data
EOF
        fi
        
        echo
        gum style --foreground 240 "Sauvegarde terminée le $(date '+%d/%m/%Y à %H:%M:%S')"
    fi
}

# =============================================================================
# Parsing des arguments
# =============================================================================

# Variables pour détecter si des arguments ont été fournis
ARGS_PROVIDED=false

while [[ $# -gt 0 ]]; do
    ARGS_PROVIDED=true
    case $1 in
        --quiet)
            QUIET_MODE=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            error "Option inconnue : $1"
            error "Utilisez --help pour voir les options disponibles"
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

# Si aucun argument n'est fourni et qu'on n'est pas en mode silencieux,
# lancer l'interface interactive
if [ "$ARGS_PROVIDED" = false ] && [ "$QUIET_MODE" = false ]; then
    interactive_setup
fi

main_backup 
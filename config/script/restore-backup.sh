#!/bin/bash

# =============================================================================
# Script de restauration de sauvegarde OpenWebUI avec interface Gum
# =============================================================================
# Ce script restaure une sauvegarde OpenWebUI vers l'environnement local
# Interface interactive utilisant charmbracelet/gum
#
# Usage: ./restore-backup.sh [OPTIONS] [BACKUP_FILE]
# Options:
#   --local-volume VOLUME : Nom du volume local (défaut: détection automatique)
#   --dry-run            : Simulation sans restauration effective
#   --backup-current     : Créer une sauvegarde avant restauration
#   --quiet              : Mode silencieux
#   --help               : Afficher cette aide
#   --s3-bucket BUCKET   : Restaurer depuis S3
#   --s3-prefix PREFIX   : Préfixe S3 pour la recherche
#   --env-type TYPE      : Type d'environnement (local/prod)
#   --env-file FILE      : Fichier d'environnement personnalisé
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
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

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

# Options par défaut
LOCAL_VOLUME=""
DRY_RUN=false
BACKUP_CURRENT=false
QUIET_MODE=false
SHOW_HELP=false
BACKUP_FILE=""
USE_LATEST=false
S3_BUCKET=""
S3_PREFIX="openwebui-backups/"
S3_BACKUP_KEY=""
ENV_FILE=""
ENV_TYPE=""
RESTORE_FROM_S3=false

# =============================================================================
# Fonctions utilitaires avec Gum
# =============================================================================

show_help() {
    gum format --type markdown << 'EOF'
# 🔄 Script de restauration OpenWebUI

## Usage
```bash
./restore-backup.sh [OPTIONS] [BACKUP_FILE]
```

## Arguments
- `BACKUP_FILE` : Chemin vers le fichier de sauvegarde (.tar.gz)

## Options
- `--local-volume VOLUME` : Nom du volume Docker local à restaurer
- `--dry-run` : Simulation sans restauration effective
- `--backup-current` : Créer une sauvegarde avant restauration
- `--latest` : Utiliser automatiquement la sauvegarde la plus récente
- `--quiet` : Mode silencieux
- `--help` : Afficher cette aide
- `--s3-bucket BUCKET` : Restaurer depuis S3
- `--s3-prefix PREFIX` : Préfixe S3 pour la recherche
- `--env-type TYPE` : Type d'environnement (local/prod)
- `--env-file FILE` : Fichier d'environnement personnalisé

## Exemples
```bash
# Restauration locale simple
./restore-backup.sh backups/update_openwebui_20250811_123437.tar.gz

# Utiliser la sauvegarde la plus récente
./restore-backup.sh --latest

# Avec sauvegarde de sécurité
./restore-backup.sh --backup-current --latest

# Restauration depuis S3
./restore-backup.sh --s3-bucket mon-bucket --env-type prod

# Mode simulation
./restore-backup.sh --dry-run backups/update_openwebui_20250811_123437.tar.gz
```

## Mode interactif
Sans arguments, le script vous guidera interactivement pour :
- Choisir la source (fichier local ou S3)
- Sélectionner le fichier de sauvegarde
- Configurer les options de restauration
- Charger les variables d'environnement

## Variables d'environnement supportées
- `AWS_ACCESS_KEY_ID` : Clé d'accès AWS
- `AWS_SECRET_ACCESS_KEY` : Clé secrète AWS
- `AWS_DEFAULT_REGION` : Région AWS par défaut
- `S3_BACKUP_BUCKET` : Nom du bucket S3
- `S3_BACKUP_PREFIX` : Préfixe S3

## Notes
- Le volume local sera détecté automatiquement si non spécifié
- Une sauvegarde de sécurité peut être créée avant restauration
- Le conteneur OpenWebUI sera arrêté pendant la restauration
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
        "🔄 Restauration OpenWebUI" "Configuration interactive"
    
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
    
    # 2. Source de la sauvegarde
    local restore_source
    restore_source=$(gum choose --header "Source de la sauvegarde :" \
        "Fichier local" \
        "Télécharger depuis S3")
    
    case "$restore_source" in
        "Télécharger depuis S3")
            RESTORE_FROM_S3=true
            configure_s3_restore
            ;;
        *)
            RESTORE_FROM_S3=false
            select_local_backup
            ;;
    esac
    echo
    
    # 3. Options de restauration
    gum style --foreground 99 --bold "🔧 Options de restauration"
    echo
    
    # Volume local personnalisé
    if gum confirm "Spécifier un volume Docker personnalisé ?"; then
        # Lister les volumes disponibles
        local available_volumes
        available_volumes=$(docker volume ls --format "{{.Name}}" | grep -E "open-webui|openwebui" || echo "")
        
        if [ -n "$available_volumes" ]; then
            LOCAL_VOLUME=$(gum choose --header "Choisir le volume :" $available_volumes "Autre (saisie manuelle)")
            if [ "$LOCAL_VOLUME" = "Autre (saisie manuelle)" ]; then
                LOCAL_VOLUME=$(gum input --header "Nom du volume Docker :" \
                    --placeholder "mon-volume-openwebui")
            fi
        else
            LOCAL_VOLUME=$(gum input --header "Nom du volume Docker :" \
                --placeholder "mon-volume-openwebui")
        fi
        echo
    fi
    
    # Options supplémentaires
    if gum confirm "Créer une sauvegarde de sécurité avant restauration ?"; then
        BACKUP_CURRENT=true
    fi
    
    if gum confirm "Mode simulation (dry-run) ?"; then
        DRY_RUN=true
    fi
    echo
    
    # 4. Résumé de la configuration
    show_restore_summary
}

configure_s3_restore() {
    gum style --foreground 99 --bold "☁️ Configuration S3"
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
    
    # Lister et sélectionner la sauvegarde S3
    select_s3_backup
}

select_local_backup() {
    local backup_dir="$PROJECT_ROOT/backups"
    
    if [ ! -d "$backup_dir" ]; then
        if gum confirm "Le répertoire $backup_dir n'existe pas. Sélectionner un autre répertoire ?"; then
            backup_dir=$(gum file --directory --header "Sélectionner le répertoire des sauvegardes :")
        else
            error "Répertoire de sauvegardes introuvable"
            exit 1
        fi
    fi
    
    # Lister les fichiers de sauvegarde disponibles
    local backup_files
    backup_files=$(find "$backup_dir" -name "*.tar.gz" -type f 2>/dev/null | sort -r | head -20)
    
    if [ -z "$backup_files" ]; then
        if gum confirm "Aucun fichier de sauvegarde trouvé dans $backup_dir. Sélectionner manuellement ?"; then
            BACKUP_FILE=$(gum file --file --header "Sélectionner le fichier de sauvegarde :")
        else
            error "Aucun fichier de sauvegarde disponible"
            exit 1
        fi
    else
        gum style --foreground 99 "📁 Sauvegardes disponibles dans $backup_dir :"
        echo
        
        # Créer un tableau avec les noms de fichiers et leurs tailles
        local file_options=()
        while IFS= read -r file; do
            local basename_file
            basename_file=$(basename "$file")
            local file_size
            file_size=$(ls -lh "$file" | awk '{print $5}')
            local file_date
            file_date=$(ls -l "$file" | awk '{print $6, $7, $8}')
            file_options+=("$basename_file ($file_size - $file_date)")
        done <<< "$backup_files"
        
        file_options+=("Dernière sauvegarde disponible")
        file_options+=("Autre fichier...")
        
        local selected_option
        selected_option=$(gum choose --header "Choisir la sauvegarde à restaurer :" "${file_options[@]}")
        
        if [ "$selected_option" = "Autre fichier..." ]; then
            BACKUP_FILE=$(gum file --file --header "Sélectionner le fichier de sauvegarde :")
        elif [ "$selected_option" = "Dernière sauvegarde disponible" ]; then
            if ! find_latest_backup; then
                error "Impossible de trouver la dernière sauvegarde"
                exit 1
            fi
        else
            # Extraire le nom de fichier de l'option sélectionnée
            local selected_filename
            selected_filename=$(echo "$selected_option" | cut -d' ' -f1)
            BACKUP_FILE="$backup_dir/$selected_filename"
        fi
    fi
}

select_s3_backup() {
    log "Recherche des sauvegardes S3 disponibles..."
    log "Bucket: $S3_BUCKET"
    log "Préfixe: $S3_PREFIX"
    
    # Lister les objets S3 avec le préfixe
    local s3_objects
    s3_objects=$(aws s3api list-objects-v2 \
        --bucket "$S3_BUCKET" \
        --prefix "${S3_PREFIX}" \
        --endpoint-url https://nbg1.your-objectstorage.com \
        --query 'Contents[?Size>`0`].[Key,LastModified,Size]' \
        --output text 2>/dev/null | \
        sort -k2 -r | \
        head -20) || {
        error "Impossible de lister les objets S3"
        log "Tentative de diagnostic..."
        
        # Essayer de lister sans préfixe pour voir ce qui est disponible
        log "🔍 Objets disponibles dans le bucket (sans préfixe) :"
        aws s3 ls "s3://$S3_BUCKET/" --endpoint-url https://nbg1.your-objectstorage.com | head -10 | while read -r line; do
            log "  - $line"
        done
        
        exit 1
    }
    
    if [ -z "$s3_objects" ]; then
        error "Aucune sauvegarde trouvée dans s3://$S3_BUCKET/$S3_PREFIX"
        exit 1
    fi
    
    # Créer un tableau avec les options et nettoyer les clés
    local s3_options=()
    local cleaned_s3_objects=""
    while IFS=$'\t' read -r key last_modified size; do
        # Nettoyer la clé complètement (supprimer tous les espaces parasites)
        local clean_key
        clean_key=$(echo "$key" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/[[:space:]]\+/ /g')
        local basename_key
        basename_key=$(basename "$clean_key" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        local human_size
        human_size=$(numfmt --to=iec "$size" 2>/dev/null || echo "$size bytes")
        local formatted_date
        formatted_date=$(date -d "$last_modified" '+%d/%m/%Y %H:%M' 2>/dev/null || echo "$last_modified")
        s3_options+=("$basename_key ($human_size - $formatted_date)")
        log "Ajout option: '$basename_key ($human_size - $formatted_date)'"
        
        # Stocker la correspondance clé nettoyée -> clé complète pour usage ultérieur
        cleaned_s3_objects+="$basename_key|$clean_key"$'\n'
    done <<< "$s3_objects"
    
    local selected_s3_option
    selected_s3_option=$(gum choose --header "Choisir la sauvegarde S3 à restaurer :" "${s3_options[@]}")
    log "Option sélectionnée: '$selected_s3_option'"
    # Extraire le nom de fichier (en supprimant les espaces en début et en gardant seulement le nom avant la parenthèse)
    local selected_s3_filename
    selected_s3_filename=$(echo "$selected_s3_option" | sed 's/^[[:space:]]*//' | cut -d' ' -f1)
    log "Nom de fichier extrait: '$selected_s3_filename'"
    # Le fichier sera téléchargé plus tard
    local temp_dir="$PROJECT_ROOT/backups/temp"
    mkdir -p "$temp_dir"
    BACKUP_FILE="$temp_dir/$selected_s3_filename"
    
    # Construire la clé S3 - utiliser la correspondance nettoyée
    log "Debug - Recherche de: '$selected_s3_filename'"
    log "Debug - Correspondances disponibles:"
    echo "$cleaned_s3_objects" | while read -r line; do
        if [ -n "$line" ]; then
            log "  - $line"
        fi
    done
    
    local full_s3_key
    full_s3_key=$(echo "$cleaned_s3_objects" | grep "^$selected_s3_filename|" | cut -d'|' -f2)
    
    if [ -n "$full_s3_key" ]; then
        S3_BACKUP_KEY="$full_s3_key"
        log "Clé S3 complète trouvée: '$S3_BACKUP_KEY'"
    else
        log "Debug - Aucune correspondance trouvée, utilisation du fallback"
        # Fallback à l'ancienne méthode
        S3_BACKUP_KEY="${S3_PREFIX}${selected_s3_filename}"
        # Nettoyer les doubles slashes
        S3_BACKUP_KEY=$(echo "$S3_BACKUP_KEY" | sed 's|//|/|g')
        log "Clé S3 construite (fallback): '$S3_BACKUP_KEY'"
    fi
}

show_restore_summary() {
    gum style --foreground 212 --bold "📋 Résumé de la restauration"
    echo
    
    gum format --type markdown << EOF
## Configuration choisie :

- **Source** : $([ "$RESTORE_FROM_S3" = true ] && echo "S3 (s3://$S3_BUCKET/$S3_BACKUP_KEY)" || echo "Fichier local")
- **Fichier** : $(basename "${BACKUP_FILE:-Non spécifié}")
- **Volume** : ${LOCAL_VOLUME:-"Détection automatique"}
- **Sauvegarde sécurité** : $([ "$BACKUP_CURRENT" = true ] && echo "Oui" || echo "Non")
- **Mode simulation** : $([ "$DRY_RUN" = true ] && echo "Oui" || echo "Non")
$([ -n "$ENV_TYPE" ] && echo "- **Environnement** : $ENV_TYPE")
$([ -n "$ENV_FILE" ] && echo "- **Fichier env** : $ENV_FILE")
EOF
    
    echo
    if ! gum confirm "Confirmer et démarrer la restauration ?"; then
        gum style --foreground 196 "❌ Restauration annulée"
        exit 0
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

find_latest_backup() {
    local backup_dir="$PROJECT_ROOT/backups"
    
    log "Recherche de la sauvegarde la plus récente..."
    
    if [ ! -d "$backup_dir" ]; then
        error "Répertoire de sauvegardes introuvable : $backup_dir"
        return 1
    fi
    
    # Chercher les fichiers de sauvegarde (exclure les sauvegardes de sécurité)
    local latest_backup
    latest_backup=$(find "$backup_dir" -name "update_openwebui_*.tar.gz" -type f 2>/dev/null | sort -r | head -n1)
    
    if [ -z "$latest_backup" ]; then
        # Si pas de fichiers update_openwebui, chercher tous les .tar.gz
        latest_backup=$(find "$backup_dir" -name "*.tar.gz" -type f 2>/dev/null | sort -r | head -n1)
    fi
    
    if [ -n "$latest_backup" ]; then
        BACKUP_FILE="$latest_backup"
        local file_size
        file_size=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
        local file_date
        file_date=$(ls -l "$BACKUP_FILE" | awk '{print $6, $7, $8}')
        success "Sauvegarde la plus récente trouvée : $(basename "$BACKUP_FILE")"
        log "Taille : $file_size, Date : $file_date"
        return 0
    else
        error "Aucune sauvegarde trouvée dans $backup_dir"
        return 1
    fi
}

download_from_s3() {
    local s3_url="s3://${S3_BUCKET}/${S3_BACKUP_KEY}"
    
    gum style --foreground 99 --bold "☁️ Téléchargement depuis S3"
    echo
    
    log "Source S3 : $s3_url"
    log "Destination : $BACKUP_FILE"
    
    # Télécharger depuis S3 avec affichage des erreurs détaillées
    log "Commande AWS : aws s3 cp \"$s3_url\" \"$BACKUP_FILE\" --endpoint-url https://nbg1.your-objectstorage.com"
    
    # Essayer d'abord sans spinner pour voir les erreurs
    log "Tentative de téléchargement..."
    if aws s3 cp "$s3_url" "$BACKUP_FILE" --endpoint-url https://nbg1.your-objectstorage.com 2>&1; then
        
        local file_size
        file_size=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
        success "Téléchargement S3 réussi ($file_size)"
        return 0
    else
        local aws_error_code=$?
        error "Échec du téléchargement S3 (code d'erreur: $aws_error_code)"
        
        # Essayer d'obtenir plus d'informations sur l'erreur
        log "Tentative de diagnostic..."
        
        # Vérifier si le bucket existe et est accessible
        if aws s3 ls "s3://$S3_BUCKET/" --endpoint-url https://nbg1.your-objectstorage.com &>/dev/null; then
            log "✅ Bucket S3 accessible"
        else
            error "❌ Impossible d'accéder au bucket S3: $S3_BUCKET"
        fi
        
        # Vérifier si l'objet existe
        if aws s3 ls "$s3_url" --endpoint-url https://nbg1.your-objectstorage.com &>/dev/null; then
            log "✅ Objet S3 trouvé"
        else
            error "❌ Objet S3 introuvable: $s3_url"
            
            # Essayer de lister les objets similaires pour aider au diagnostic
            log "🔍 Recherche d'objets similaires dans le bucket..."
            local similar_objects
            similar_objects=$(aws s3 ls "s3://$S3_BUCKET/" --recursive --endpoint-url https://nbg1.your-objectstorage.com | grep "$(basename "$BACKUP_FILE")" | head -5)
            
            if [ -n "$similar_objects" ]; then
                log "📁 Objets similaires trouvés :"
                echo "$similar_objects" | while read -r line; do
                    log "  - $line"
                done
                
                # Essayer de corriger automatiquement le chemin
                log "🔧 Tentative de correction automatique du chemin..."
                
                # Méthode directe : utiliser aws s3 ls --recursive pour obtenir le chemin exact
                local correct_key
                correct_key=$(aws s3 ls "s3://$S3_BUCKET/" --recursive --endpoint-url https://nbg1.your-objectstorage.com | grep "$(basename "$BACKUP_FILE")" | head -n1 | sed 's/^[[:space:]]*[0-9-]*[[:space:]]*[0-9:]*[[:space:]]*[0-9]*[[:space:]]*//')
                
                if [ -n "$correct_key" ]; then
                    log "Nouveau chemin détecté: '$correct_key'"
                    
                    # Mettre à jour la clé S3 avec le chemin correct
                    S3_BACKUP_KEY="$correct_key"
                    local corrected_s3_url="s3://${S3_BUCKET}/${S3_BACKUP_KEY}"
                    log "Nouvelle URL S3: $corrected_s3_url"
                    
                    # Réessayer le téléchargement avec le chemin corrigé
                    log "🔄 Nouvelle tentative de téléchargement..."
                    if aws s3 cp "$corrected_s3_url" "$BACKUP_FILE" --endpoint-url https://nbg1.your-objectstorage.com 2>&1; then
                        local file_size
                        file_size=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
                        success "Téléchargement S3 réussi avec le chemin corrigé ($file_size)"
                        return 0
                    else
                        error "Échec même avec le chemin corrigé"
                        log "Debug - Chemin extrait: '$correct_key'"
                        log "Debug - URL construite: '$corrected_s3_url'"
                        
                        # Essayer sans les espaces
                        local clean_key
                        clean_key=$(echo "$correct_key" | tr -s ' ' | sed 's/^ *//;s/ *$//')
                        if [ "$clean_key" != "$correct_key" ]; then
                            log "🔧 Tentative avec le chemin nettoyé..."
                            log "Chemin nettoyé: '$clean_key'"
                            local clean_s3_url="s3://${S3_BUCKET}/${clean_key}"
                            if aws s3 cp "$clean_s3_url" "$BACKUP_FILE" --endpoint-url https://nbg1.your-objectstorage.com 2>&1; then
                                local file_size
                                file_size=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
                                success "Téléchargement S3 réussi avec le chemin nettoyé ($file_size)"
                                return 0
                            fi
                        fi
                    fi
                else
                    error "Impossible d'extraire le chemin correct"
                fi
            else
                log "🔍 Aucun objet similaire trouvé avec le nom: $(basename "$BACKUP_FILE")"
                
                # Lister les premiers objets du préfixe pour voir ce qui est disponible
                log "📁 Objets disponibles dans le préfixe '$S3_PREFIX' :"
                aws s3 ls "s3://$S3_BUCKET/$S3_PREFIX" --endpoint-url https://nbg1.your-objectstorage.com | head -5 | while read -r line; do
                    log "  - $line"
                done
            fi
        fi
        
        # Vérifier les permissions d'écriture dans le dossier de destination
        local dest_dir
        dest_dir=$(dirname "$BACKUP_FILE")
        if [ -w "$dest_dir" ]; then
            log "✅ Permissions d'écriture OK dans: $dest_dir"
        else
            error "❌ Pas de permissions d'écriture dans: $dest_dir"
        fi
        
        return 1
    fi
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
    
    # Vérifier AWS CLI si S3 requis
    if [ "$RESTORE_FROM_S3" = true ]; then
        if ! command -v aws &> /dev/null; then
            error "AWS CLI n'est pas installé (requis pour S3)"
            error "Installation: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
            exit 1
        fi
        
        # Vérifier la configuration AWS
        if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
            log "Variables AWS définies dans l'environnement"
        elif ! aws sts get-caller-identity &> /dev/null; then
            error "AWS CLI n'est pas configuré correctement"
            error "Exécutez: aws configure ou définissez AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY"
            exit 1
        fi
        
        log "Configuration AWS validée"
        
        # Télécharger le fichier S3 si nécessaire
        if [ -n "$S3_BACKUP_KEY" ]; then
            download_from_s3
        fi
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
    gum style --foreground 99 --bold "💾 Création d'une sauvegarde de sécurité"
    echo
    
    local backup_dir="$PROJECT_ROOT/backups"
    mkdir -p "$backup_dir"
    
    local safety_backup="$backup_dir/safety_backup_${TIMESTAMP}.tar.gz"
    
    # Créer la sauvegarde de sécurité avec spinner
    if gum spin --spinner dot --title "Sauvegarde de sécurité en cours..." -- \
        docker run --rm \
        -v "$LOCAL_VOLUME:/data:ro" \
        -v "$backup_dir:/backup" \
        alpine:latest \
        tar czf "/backup/safety_backup_${TIMESTAMP}.tar.gz" -C /data .; then
        
        local file_size
        file_size=$(ls -lh "$safety_backup" | awk '{print $5}')
        success "Sauvegarde de sécurité créée ($file_size)"
        gum style --foreground 99 "📁 Chemin : $(realpath "$safety_backup")"
        return 0
    else
        error "Échec de la création de la sauvegarde de sécurité"
        return 1
    fi
}

stop_openwebui_containers() {
    gum style --foreground 99 --bold "⏹️ Arrêt des conteneurs OpenWebUI"
    echo
    
    # Chercher les conteneurs OpenWebUI en cours d'exécution
    local containers
    containers=$(docker ps --format "{{.Names}}" | grep -E "openwebui|open-webui|apollo" || true)
    
    if [ -n "$containers" ]; then
        echo "$containers" | while read -r container; do
            log "Arrêt du conteneur : $container"
            if [ "$DRY_RUN" = false ]; then
                gum spin --spinner dot --title "Arrêt de $container..." -- \
                    docker stop "$container" || warning "Impossible d'arrêter $container"
            else
                log "MODE DRY-RUN : Arrêt simulé de $container"
            fi
        done
    else
        log "Aucun conteneur OpenWebUI en cours d'exécution"
    fi
    
    # Attendre un peu pour s'assurer que les conteneurs sont arrêtés
    if [ "$DRY_RUN" = false ]; then
        gum spin --spinner dot --title "Attente de l'arrêt complet..." -- sleep 2
    fi
}

restore_backup() {
    gum style --foreground 99 --bold "🔄 Restauration de la sauvegarde"
    echo
    
    log "Source : $(basename "$BACKUP_FILE")"
    log "Volume de destination : $LOCAL_VOLUME"
    
    if [ "$DRY_RUN" = true ]; then
        log "MODE DRY-RUN : Simulation de la restauration"
        gum format --type code << EOF
docker run --rm \\
  -v $LOCAL_VOLUME:/data \\
  -v $(dirname "$BACKUP_FILE"):/backup \\
  alpine:latest \\
  sh -c "rm -rf /data/* /data/.[^.]* && tar xzf /backup/$(basename "$BACKUP_FILE") -C /data"
EOF
        return 0
    fi
    
    # Confirmation avant restauration
    if [ "$QUIET_MODE" = false ]; then
        echo
        gum style --foreground 196 --bold "⚠️ ATTENTION"
        warning "Cette opération va remplacer toutes les données actuelles dans le volume $LOCAL_VOLUME"
        echo
        if ! gum confirm "Voulez-vous continuer avec la restauration ?"; then
            gum style --foreground 196 "❌ Restauration annulée"
            return 1
        fi
        echo
    fi
    
    # Effectuer la restauration
    local backup_dir
    backup_dir=$(dirname "$BACKUP_FILE")
    local backup_filename
    backup_filename=$(basename "$BACKUP_FILE")
    
    if gum spin --spinner dot --title "Restauration en cours..." -- \
        docker run --rm \
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
    gum style --foreground 99 --bold "🚀 Redémarrage d'OpenWebUI"
    echo
    
    if [ "$DRY_RUN" = true ]; then
        log "MODE DRY-RUN : Simulation du redémarrage"
        gum format --type code << EOF
cd $PROJECT_ROOT
docker-compose up -d
EOF
        return 0
    fi
    
    # Aller dans le répertoire du projet et redémarrer
    cd "$PROJECT_ROOT"
    
    if [ -f "docker-compose.yml" ]; then
        if gum spin --spinner dot --title "Redémarrage d'OpenWebUI..." -- \
            docker-compose up -d; then
            success "OpenWebUI redémarré avec succès"
            gum style --foreground 99 "🌐 L'application sera disponible dans quelques instants sur http://localhost:8080"
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
# Fonction de nettoyage
# =============================================================================

cleanup_temp_files() {
    # Nettoyer les fichiers temporaires S3
    if [ "$RESTORE_FROM_S3" = true ] && [ -f "$BACKUP_FILE" ] && [[ "$BACKUP_FILE" == */backups/temp/* ]]; then
        log "Nettoyage du fichier temporaire S3..."
        rm -f "$BACKUP_FILE"
    fi
}

# =============================================================================
# Fonction principale
# =============================================================================

main_restore() {
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
    
    if [ "$BACKUP_CURRENT" = true ]; then
        backup_current_data
        echo
    fi
    
    stop_openwebui_containers
    echo
    
    restore_backup
    echo
    
    start_openwebui
    
    # Nettoyer les fichiers temporaires
    cleanup_temp_files
    
    if [ "$QUIET_MODE" = false ]; then
        echo
        gum style \
            --foreground 212 --border-foreground 212 --border double \
            --align center --width 60 --margin "1 2" --padding "2 4" \
            "🎉 Restauration terminée avec succès !"
        
        echo
        
        gum style --foreground 99 --bold "📋 Informations de restauration :"
        gum format --type markdown << EOF
## Restauration réussie

- **Source** : $(basename "${BACKUP_FILE}")
- **Volume** : $LOCAL_VOLUME
- **Mode** : $([ "$DRY_RUN" = true ] && echo "Simulation" || echo "Réel")

## Accès à l'application
- **URL locale** : http://localhost:8080
- **Statut** : L'application sera disponible dans quelques instants

$([ "$BACKUP_CURRENT" = true ] && echo "## Sauvegarde de sécurité
- **Fichier** : $PROJECT_ROOT/backups/safety_backup_${TIMESTAMP}.tar.gz
- **Utilisation** : Pour restaurer les données précédentes si nécessaire")
EOF
        
        echo
        gum style --foreground 240 "Restauration terminée le $(date '+%d/%m/%Y à %H:%M:%S')"
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
        --latest)
            USE_LATEST=true
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
        --s3-bucket)
            S3_BUCKET="$2"
            RESTORE_FROM_S3=true
            shift 2
            ;;
        --s3-prefix)
            S3_PREFIX="$2"
            # S'assurer que le préfixe se termine par /
            if [[ -n "$S3_PREFIX" && ! "$S3_PREFIX" =~ /$ ]]; then
                S3_PREFIX="${S3_PREFIX}/"
            fi
            shift 2
            ;;
        --env-type)
            ENV_TYPE="$2"
            if [[ "$ENV_TYPE" != "local" && "$ENV_TYPE" != "prod" ]]; then
                error "Type d'environnement invalide : $ENV_TYPE (utilisez 'local' ou 'prod')"
                exit 1
            fi
            shift 2
            ;;
        --env-file)
            ENV_FILE="$2"
            if [[ ! -f "$ENV_FILE" ]]; then
                error "Fichier d'environnement introuvable : $ENV_FILE"
                exit 1
            fi
            shift 2
            ;;
        -*)
            error "Option inconnue : $1"
            error "Utilisez --help pour voir les options disponibles"
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

# Traitement des variables d'environnement si spécifiées
if [ -n "$ENV_TYPE" ] || [ -n "$ENV_FILE" ]; then
    if [ -n "$ENV_TYPE" ] && [ -z "$ENV_FILE" ]; then
        case "$ENV_TYPE" in
            "local")
                ENV_FILE="$PROJECT_ROOT/.env.local"
                ;;
            "prod")
                ENV_FILE="$PROJECT_ROOT/.env.prod"
                ;;
        esac
    fi
    
    if [ -n "$ENV_FILE" ]; then
        load_env_file "$ENV_FILE"
        
        # Utiliser les variables d'environnement si les options ne sont pas définies
        if [ -z "$S3_BUCKET" ] && [ -n "${S3_BACKUP_BUCKET:-}" ]; then
            S3_BUCKET="$S3_BACKUP_BUCKET"
            RESTORE_FROM_S3=true
        fi
        
        if [ "$S3_PREFIX" = "openwebui-backups/" ] && [ -n "${S3_BACKUP_PREFIX:-}" ]; then
            S3_PREFIX="$S3_BACKUP_PREFIX"
        fi
    fi
fi

# Si aucun argument n'est fourni et qu'on n'est pas en mode silencieux,
# lancer l'interface interactive
if [ "$ARGS_PROVIDED" = false ] && [ "$QUIET_MODE" = false ]; then
    interactive_setup
fi

# Si --latest est utilisé, trouver la dernière sauvegarde
if [ "$USE_LATEST" = true ]; then
    if ! find_latest_backup; then
        exit 1
    fi
fi

# Validation : il faut soit un fichier de sauvegarde soit une configuration S3
if [ -z "$BACKUP_FILE" ] && [ "$RESTORE_FROM_S3" = false ] && [ "$USE_LATEST" = false ]; then
    error "Fichier de sauvegarde requis ou utilisez --s3-bucket pour restaurer depuis S3 ou --latest pour la sauvegarde la plus récente"
    show_help
    exit 1
fi

# Validation S3
if [ "$RESTORE_FROM_S3" = true ] && [ -z "$S3_BUCKET" ]; then
    error "Option --s3-bucket requise pour la restauration S3"
    error "Utilisez --s3-bucket BUCKET ou définissez S3_BACKUP_BUCKET dans votre fichier d'environnement"
    exit 1
fi

# Convertir en chemin absolu si nécessaire (pour les fichiers locaux)
if [ -n "$BACKUP_FILE" ] && [[ "$BACKUP_FILE" != /* ]] && [[ "$BACKUP_FILE" != /tmp/* ]]; then
    BACKUP_FILE="$PROJECT_ROOT/$BACKUP_FILE"
fi

main_restore

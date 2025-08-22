#!/bin/bash

# =============================================================================
# Script de mise à jour automatique d'OpenWebUI avec interface Gum
# =============================================================================
# Ce script automatise la mise à jour de votre installation Docker OpenWebUI
# vers la dernière version disponible avec une interface interactive moderne.
#
# Usage: ./update-openwebui.sh [OPTIONS]
# Options:
#   --backup         : Forcer une sauvegarde avant mise à jour
#   --no-backup      : Passer la sauvegarde
#   --dry-run        : Simuler sans exécuter
#   --env ENV        : Forcer l'environnement (local|prod)
#   --quiet          : Mode silencieux
#   --interactive    : Forcer le mode interactif
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
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CONTAINER_NAME=""
VOLUME_NAME=""
IMAGE_NAME="ghcr.io/open-webui/open-webui:main"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-openwebui.sh"

# Environment detection
ENVIRONMENT=""
COMPOSE_FILE=""
COMPOSE_PROJECT_NAME=""

# Options par défaut
FORCE_BACKUP=false
NO_BACKUP=false
DRY_RUN=false
SHOW_HELP=false
QUIET_MODE=false
INTERACTIVE_MODE=false
ENV_OVERRIDE=""

# Variables pour détecter si des arguments ont été fournis
ARGS_PROVIDED=false

# =============================================================================
# Fonctions utilitaires avec Gum
# =============================================================================

show_help() {
    gum format --type markdown << 'EOF'
# 🔄 Script de mise à jour OpenWebUI

## Usage
```bash
./update-openwebui.sh [OPTIONS]
```

## Options
- `--backup` : Forcer une sauvegarde avant mise à jour
- `--no-backup` : Passer la sauvegarde
- `--dry-run` : Simuler sans exécuter les commandes
- `--env ENV` : Forcer l'environnement (local|prod)
- `--quiet` : Mode silencieux
- `--interactive` : Forcer le mode interactif
- `--help` : Afficher cette aide

## Exemples
```bash
# Mise à jour normale avec détection automatique
./update-openwebui.sh

# Forcer l'environnement local
./update-openwebui.sh --env local

# Mise à jour avec sauvegarde forcée
./update-openwebui.sh --backup

# Mode simulation
./update-openwebui.sh --dry-run

# Mode interactif forcé
./update-openwebui.sh --interactive
```

## Mode interactif
Sans arguments, le script vous guidera interactivement pour :
- Choisir l'environnement (local/prod/auto)
- Configurer les options de sauvegarde
- Activer le mode simulation
- Confirmer avant exécution

## Environnements
- **local** : Utilise docker-compose.yml avec projet apollo-13
- **prod** : Utilise docker-compose.prod.yml sans nom de projet

## Notes
- L'environnement sera détecté automatiquement si non spécifié
- Une sauvegarde peut être créée avant la mise à jour
- Le mode simulation permet de voir les commandes sans les exécuter
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

execute_command() {
    local cmd="$1"
    local description="$2"
    local spinner_title="${3:-$description}"
    
    if [ "$DRY_RUN" = true ]; then
        gum style --foreground 220 --bold "[DRY-RUN] $description"
        gum format --type code << EOF
$cmd
EOF
    else
        if gum spin --spinner dot --title "$spinner_title..." -- bash -c "$cmd"; then
            success "$description"
        else
            error "Échec de l'exécution : $description"
            return 1
        fi
    fi
}

# =============================================================================
# Interface interactive avec Gum
# =============================================================================

interactive_setup() {
    # En-tête stylisé
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 60 --margin "1 2" --padding "2 4" \
        "🔄 Mise à jour OpenWebUI" "Configuration interactive"
    
    echo
    
    # 1. Sélection de l'environnement
    local env_choice
    env_choice=$(gum choose --header "Choisir l'environnement :" \
        "Détection automatique" \
        "Local (apollo-13)" \
        "Production")
    
    case "$env_choice" in
        "Local (apollo-13)")
            ENV_OVERRIDE="local"
            ;;
        "Production")
            ENV_OVERRIDE="prod"
            ;;
        *)
            ENV_OVERRIDE=""
            ;;
    esac
    echo
    
    # 2. Options de sauvegarde
    gum style --foreground 99 --bold "💾 Gestion des données"
    echo
    
    local backup_choice
    backup_choice=$(gum choose --header "Que souhaitez-vous faire avec vos données actuelles ?" \
        "Créer une sauvegarde de sécurité avant la mise à jour" \
        "Procéder directement sans sauvegarde" \
        "Me demander au moment de la mise à jour")
    
    case "$backup_choice" in
        "Créer une sauvegarde de sécurité avant la mise à jour")
            FORCE_BACKUP=true
            ;;
        "Procéder directement sans sauvegarde")
            NO_BACKUP=true
            ;;
        *)
            # Par défaut, demander confirmation
            ;;
    esac
    echo
    
    # 3. Résumé de la configuration
    show_update_summary
}

show_update_summary() {
    gum style --foreground 212 --bold "📋 Résumé de la mise à jour"
    echo
    
    gum format --type markdown << EOF
## Configuration choisie :

- **Environnement** : $([ -n "$ENV_OVERRIDE" ] && echo "$ENV_OVERRIDE" || echo "Détection automatique")
- **Sauvegarde** : $([ "$FORCE_BACKUP" = true ] && echo "Créer automatiquement" || ([ "$NO_BACKUP" = true ] && echo "Aucune sauvegarde" || echo "Demander confirmation"))
- **Image Docker** : $IMAGE_NAME
EOF
    
    echo
    if ! gum confirm "Confirmer et démarrer la mise à jour ?"; then
        gum style --foreground 196 "❌ Mise à jour annulée"
        exit 0
    fi
}

show_final_summary() {
    if [ "$QUIET_MODE" = false ]; then
        echo
        gum style \
            --foreground 212 --border-foreground 212 --border double \
            --align center --width 60 --margin "1 2" --padding "2 4" \
            "🎉 Mise à jour terminée avec succès !"
        
        echo
        
        gum style --foreground 99 --bold "📋 Informations de mise à jour :"
        gum format --type markdown << EOF
## Mise à jour réussie

- **Environnement** : $ENVIRONMENT
- **Conteneur** : $CONTAINER_NAME
- **Volume** : $VOLUME_NAME
- **Mode** : $([ "$DRY_RUN" = true ] && echo "Simulation" || echo "Réel")

## Accès à l'application
- **URL locale** : http://localhost:8080
- **Statut** : L'application est disponible

## Commandes utiles
$([ -n "$COMPOSE_PROJECT_NAME" ] && echo "- **Logs** : docker-compose -p \"$COMPOSE_PROJECT_NAME\" logs -f" || echo "- **Logs** : docker-compose logs -f")
$([ -n "$COMPOSE_PROJECT_NAME" ] && echo "- **Redémarrer** : docker-compose -p \"$COMPOSE_PROJECT_NAME\" restart" || echo "- **Redémarrer** : docker-compose restart")
$([ -n "$COMPOSE_PROJECT_NAME" ] && echo "- **Arrêter** : docker-compose -p \"$COMPOSE_PROJECT_NAME\" down" || echo "- **Arrêter** : docker-compose down")
EOF
        
        echo
        gum style --foreground 240 "Mise à jour terminée le $(date '+%d/%m/%Y à %H:%M:%S')"
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
    
    gum style --foreground 99 --bold "💾 Création d'une sauvegarde S3"
    echo
    
    if [ "$DRY_RUN" = true ]; then
        gum style --foreground 220 --bold "[DRY-RUN] Création de la sauvegarde S3 (données essentielles)"
        local backup_cmd="$BACKUP_SCRIPT --backup-type s3 --data-only --quiet"
        if [ -n "$ENVIRONMENT" ]; then
            backup_cmd="$backup_cmd --env-type $ENVIRONMENT"
        fi
        gum format --type code << EOF
$backup_cmd
EOF
        return 0
    fi
    
    # Vérifier que le script de sauvegarde existe
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        error "Script de sauvegarde non trouvé : $BACKUP_SCRIPT"
        return 1
    fi
    
    # Construire la commande de sauvegarde avec les options appropriées
    local backup_cmd="$BACKUP_SCRIPT --backup-type s3 --data-only --quiet"
    
    # Ajouter l'environnement détecté
    if [ -n "$ENVIRONMENT" ]; then
        backup_cmd="$backup_cmd --env-type $ENVIRONMENT"
    fi
    
    log "Commande de sauvegarde : $backup_cmd"
    
    # Exécuter le script de sauvegarde avec spinner
    if gum spin --spinner dot --title "Création de la sauvegarde S3 (données essentielles)..." -- bash -c "$backup_cmd"; then
        success "Sauvegarde S3 créée avec succès"
        return 0
    else
        error "Échec de la sauvegarde S3"
        warning "Vérifiez la configuration S3 dans votre fichier d'environnement"
        return 1
    fi
}

# =============================================================================
# Fonctions de mise à jour
# =============================================================================

stop_and_remove_container() {
    gum style --foreground 99 --bold "⏹️ Arrêt du conteneur existant"
    echo
    
    if [ -n "$CONTAINER_NAME" ] && docker inspect "$CONTAINER_NAME" &> /dev/null; then
        execute_command \
            "docker rm -f $CONTAINER_NAME" \
            "Arrêt et suppression du conteneur $CONTAINER_NAME" \
            "Arrêt de $CONTAINER_NAME"
    else
        log "Aucun conteneur $CONTAINER_NAME à arrêter (nom vide ou conteneur inexistant)"
    fi
}

pull_latest_image() {
    gum style --foreground 99 --bold "📦 Téléchargement de la nouvelle image"
    echo
    
    execute_command \
        "docker pull $IMAGE_NAME" \
        "Téléchargement de $IMAGE_NAME" \
        "Téléchargement de l'image Docker"
}

restart_services() {
    gum style --foreground 99 --bold "🚀 Redémarrage des services"
    echo
    
    # Change to project root to use the symlinked docker-compose.yml
    cd "$PROJECT_ROOT"
    
    local compose_cmd="docker-compose"
    if [ -n "$COMPOSE_PROJECT_NAME" ]; then
        compose_cmd="$compose_cmd -p \"$COMPOSE_PROJECT_NAME\""
    fi
    compose_cmd="$compose_cmd up -d"
    
    execute_command \
        "$compose_cmd" \
        "Redémarrage avec Docker Compose ($ENVIRONMENT)" \
        "Redémarrage d'OpenWebUI"
}

# =============================================================================
# Fonctions de vérification post-mise à jour
# =============================================================================

verify_update() {
    gum style --foreground 99 --bold "🔍 Vérification de la mise à jour"
    echo
    
    # Attendre que le conteneur démarre
    if [ "$DRY_RUN" = false ]; then
        gum spin --spinner dot --title "Attente du démarrage..." -- sleep 5
        
        local max_attempts=30
        local attempt=1
        
        log "Vérification du statut du conteneur..."
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
            if gum spin --spinner dot --title "Test de connectivité..." -- \
                bash -c "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080 | grep -q '200\|302\|301'"; then
                success "OpenWebUI est accessible ✓"
            else
                warning "OpenWebUI pourrait ne pas être complètement démarré"
            fi
        else
            log "curl non disponible, vérification manuelle recommandée"
        fi
    else
        gum style --foreground 220 --bold "[DRY-RUN] Vérification simulée"
        gum format --type markdown << EOF
## Étapes de vérification :
- Attendre le démarrage du conteneur
- Vérifier le statut (running)
- Tester la connectivité HTTP
- Afficher la nouvelle version
EOF
    fi
}

show_logs() {
    if [ "$DRY_RUN" = false ]; then
        gum style --foreground 196 --bold "📜 Affichage des logs de diagnostic"
        echo
        # Change to project root to use the symlinked docker-compose.yml
        cd "$PROJECT_ROOT"
        local compose_cmd="docker-compose"
        if [ -n "$COMPOSE_PROJECT_NAME" ]; then
            compose_cmd="$compose_cmd -p \"$COMPOSE_PROJECT_NAME\""
        fi
        eval "$compose_cmd logs --tail=20" | gum format --type code || true
    fi
}

# =============================================================================
# Fonction principale
# =============================================================================

main_update() {
    # En-tête principal
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 70 --margin "1 2" --padding "2 4" \
        "🔄 Mise à jour automatique d'OpenWebUI" "Modernisation et optimisation"
    
    echo
    
    check_prerequisites
    get_current_version
    
    # Demander confirmation pour la sauvegarde si pas d'option spécifiée
    if [ "$FORCE_BACKUP" = false ] && [ "$NO_BACKUP" = false ] && [ "$DRY_RUN" = false ] && [ "$QUIET_MODE" = false ]; then
        echo
        if gum confirm "Voulez-vous créer une sauvegarde avant la mise à jour ?"; then
            FORCE_BACKUP=true
        fi
        echo
    fi
    
    if [ "$FORCE_BACKUP" = true ]; then
        create_backup
        echo
    fi
    
    stop_and_remove_container
    echo
    
    pull_latest_image
    echo
    
    restart_services
    echo
    
    verify_update
    
    # Afficher le résumé final
    show_final_summary
}

# =============================================================================
# Gestion d'erreur globale
# =============================================================================

cleanup() {
    if [ $? -ne 0 ]; then
        echo
        gum style --foreground 196 --border-foreground 196 --border double \
            --align center --width 60 --margin "1 2" --padding "1 2" \
            "❌ Erreur durant la mise à jour"
        
        show_logs
        echo
        
        gum format --type markdown << EOF
## 🔄 Actions de récupération

Pour un rollback manuel :
1. Consultez la documentation dans `docs/OPENWEBUI.md`
2. Utilisez le script de restauration si une sauvegarde existe
3. Vérifiez les logs avec `docker-compose logs`

## 📞 Support
En cas de problème persistant, consultez les logs et la documentation.
EOF
    fi
}

trap cleanup EXIT

# =============================================================================
# Parsing des arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    ARGS_PROVIDED=true
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
        --quiet)
            QUIET_MODE=true
            shift
            ;;
        --interactive)
            INTERACTIVE_MODE=true
            shift
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

# Si aucun argument n'est fourni et qu'on n'est pas en mode silencieux,
# ou si le mode interactif est forcé, lancer l'interface interactive
if ([ "$ARGS_PROVIDED" = false ] && [ "$QUIET_MODE" = false ]) || [ "$INTERACTIVE_MODE" = true ]; then
    interactive_setup
    echo
fi

main_update 
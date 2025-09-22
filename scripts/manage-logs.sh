#!/bin/bash
# Log Management Script for Traefik
# This script helps manage Traefik log files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOG_DIR="logs"
MAX_LOG_SIZE="100M"
KEEP_LOGS=7  # Keep logs for 7 days

# Help function
show_help() {
    cat << EOF
Traefik Log Management Script

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    clean       Clean old log files
    rotate      Rotate current log files
    setup       Set up proper log permissions
    status      Show log status and sizes
    tail        Tail logs (default: traefik.log)
    compress    Compress old log files

OPTIONS:
    -h, --help          Show this help message
    -d, --days DAYS     Keep logs for specified days (default: 7)
    -s, --size SIZE     Maximum log size before rotation (default: 100M)
    -f, --file FILE     Specific log file for tail command

EXAMPLES:
    $0 status                    # Show log status
    $0 clean                     # Clean logs older than 7 days
    $0 clean --days 3            # Clean logs older than 3 days
    $0 tail                      # Tail traefik.log
    $0 tail --file access.log    # Tail access.log
    $0 rotate                    # Rotate current logs
    $0 setup                     # Fix permissions

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

# Check if log directory exists
check_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        log_error "Log directory '$LOG_DIR' not found"
        exit 1
    fi
}

# Set up proper permissions
setup_permissions() {
    log_info "Setting up log permissions..."

    # Create logs directory if it doesn't exist
    mkdir -p "$LOG_DIR"

    # Set proper permissions for log directory
    sudo chmod 755 "$LOG_DIR"

    # If log files exist, fix their permissions
    if [[ -f "$LOG_DIR/traefik.log" ]]; then
        sudo chmod 644 "$LOG_DIR/traefik.log"
        log_success "Fixed traefik.log permissions"
    fi

    if [[ -f "$LOG_DIR/access.log" ]]; then
        sudo chmod 644 "$LOG_DIR/access.log"
        log_success "Fixed access.log permissions"
    fi

    log_success "Log permissions setup complete"
}

# Show log status
show_status() {
    log_info "Traefik Log Status:"
    echo "===================="

    if [[ -d "$LOG_DIR" ]]; then
        local total_size
        total_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)
        echo "📁 Log directory: $LOG_DIR ($total_size)"
        echo ""

        if ls "$LOG_DIR"/*.log >/dev/null 2>&1; then
            echo "📋 Log files:"
            for file in "$LOG_DIR"/*.log; do
                if [[ -f "$file" ]]; then
                    local size
                    local modified
                    size=$(du -sh "$file" | cut -f1)
                    modified=$(stat -c "%y" "$file" | cut -d' ' -f1)
                    echo "  • $(basename "$file"): $size (modified: $modified)"
                fi
            done
        else
            echo "📋 No log files found"
        fi

        echo ""

        # Check for old log files
        local old_logs
        old_logs=$(find "$LOG_DIR" -name "*.log.*" -type f 2>/dev/null | wc -l)
        if [[ $old_logs -gt 0 ]]; then
            echo "🗄️  Old log files: $old_logs"
        fi

        # Check for compressed logs
        local compressed
        compressed=$(find "$LOG_DIR" -name "*.gz" -type f 2>/dev/null | wc -l)
        if [[ $compressed -gt 0 ]]; then
            echo "🗜️  Compressed logs: $compressed"
        fi

    else
        log_error "Log directory not found"
        return 1
    fi
}

# Clean old log files
clean_logs() {
    local days=${1:-$KEEP_LOGS}

    log_info "Cleaning logs older than $days days..."

    check_log_dir

    # Find and remove old log files
    local count
    count=$(find "$LOG_DIR" -name "*.log.*" -type f -mtime +$days 2>/dev/null | wc -l)

    if [[ $count -gt 0 ]]; then
        find "$LOG_DIR" -name "*.log.*" -type f -mtime +$days -delete
        log_success "Removed $count old log files"
    else
        log_info "No old log files to clean"
    fi

    # Clean old compressed files
    local compressed_count
    compressed_count=$(find "$LOG_DIR" -name "*.gz" -type f -mtime +$days 2>/dev/null | wc -l)

    if [[ $compressed_count -gt 0 ]]; then
        find "$LOG_DIR" -name "*.gz" -type f -mtime +$days -delete
        log_success "Removed $compressed_count old compressed files"
    fi
}

# Rotate log files
rotate_logs() {
    log_info "Rotating log files..."

    check_log_dir

    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")

    # Rotate traefik.log
    if [[ -f "$LOG_DIR/traefik.log" ]]; then
        sudo mv "$LOG_DIR/traefik.log" "$LOG_DIR/traefik.log.$timestamp"
        sudo touch "$LOG_DIR/traefik.log"
        sudo chmod 644 "$LOG_DIR/traefik.log"
        log_success "Rotated traefik.log"
    fi

    # Rotate access.log
    if [[ -f "$LOG_DIR/access.log" ]]; then
        sudo mv "$LOG_DIR/access.log" "$LOG_DIR/access.log.$timestamp"
        sudo touch "$LOG_DIR/access.log"
        sudo chmod 644 "$LOG_DIR/access.log"
        log_success "Rotated access.log"
    fi

    # Restart Traefik to pick up new log files
    if docker-compose ps traefik >/dev/null 2>&1; then
        log_info "Restarting Traefik to pick up new log files..."
        docker-compose restart traefik
        log_success "Traefik restarted"
    fi
}

# Compress old log files
compress_logs() {
    log_info "Compressing old log files..."

    check_log_dir

    local count=0
    for file in "$LOG_DIR"/*.log.*; do
        if [[ -f "$file" && ! "$file" =~ \.gz$ ]]; then
            gzip "$file"
            ((count++))
        fi
    done

    if [[ $count -gt 0 ]]; then
        log_success "Compressed $count log files"
    else
        log_info "No log files to compress"
    fi
}

# Tail log files
tail_logs() {
    local file=${1:-"traefik.log"}
    local log_path="$LOG_DIR/$file"

    if [[ ! -f "$log_path" ]]; then
        log_error "Log file '$log_path' not found"
        exit 1
    fi

    log_info "Tailing $log_path (press Ctrl+C to stop)..."
    tail -f "$log_path"
}

# Parse command line arguments
parse_args() {
    local command=""
    local days=$KEEP_LOGS
    local size=$MAX_LOG_SIZE
    local file=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--days)
                days="$2"
                shift 2
                ;;
            -s|--size)
                size="$2"
                shift 2
                ;;
            -f|--file)
                file="$2"
                shift 2
                ;;
            clean|rotate|setup|status|tail|compress)
                command="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Default command
    if [[ -z "$command" ]]; then
        command="status"
    fi

    # Execute command
    case $command in
        clean)
            clean_logs "$days"
            ;;
        rotate)
            rotate_logs
            ;;
        setup)
            setup_permissions
            ;;
        status)
            show_status
            ;;
        tail)
            tail_logs "$file"
            ;;
        compress)
            compress_logs
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Main execution
main() {
    echo -e "${BLUE}🪵 Traefik Log Manager${NC}"
    echo "========================"

    parse_args "$@"
}

# Run main function with all arguments
main "$@"

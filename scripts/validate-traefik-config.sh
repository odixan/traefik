#!/bin/bash
# Traefik Configuration Validator
# This script validates Docker Compose configurations with Traefik labels
# Usage: ./validate-traefik-config.sh [path-to-compose-files]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILES=()
VERBOSE=false
CHECK_NETWORK=true
CHECK_LABELS=true

# Help function
show_help() {
    cat << EOF
Traefik Configuration Validator

USAGE:
    $0 [OPTIONS] [COMPOSE_FILES...]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --no-network        Skip external network validation
    --no-labels         Skip Traefik labels validation
    --files FILE1,FILE2 Comma-separated list of compose files

EXAMPLES:
    $0                                          # Validate default files
    $0 docker-compose.yml docker-compose.traefik.yml
    $0 --files docker-compose.yml,docker-compose.traefik.yml
    $0 -v --no-network                          # Verbose mode, skip network check

DESCRIPTION:
    This script validates Docker Compose configurations for proper Traefik
    integration by checking:
    - Docker Compose syntax validity
    - External network 'proxy' exists
    - Traefik labels follow naming conventions
    - Required labels are present
    - Service configuration completeness

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-network)
                CHECK_NETWORK=false
                shift
                ;;
            --no-labels)
                CHECK_LABELS=false
                shift
                ;;
            --files)
                IFS=',' read -ra FILES <<< "$2"
                COMPOSE_FILES+=("${FILES[@]}")
                shift 2
                ;;
            -*)
                echo -e "${RED}Error: Unknown option $1${NC}" >&2
                exit 1
                ;;
            *)
                COMPOSE_FILES+=("$1")
                shift
                ;;
        esac
    done

    # Default compose files if none specified
    if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
        if [[ -f "docker-compose.yml" ]]; then
            COMPOSE_FILES+=("docker-compose.yml")
        fi
        if [[ -f "docker-compose.traefik.yml" ]]; then
            COMPOSE_FILES+=("docker-compose.traefik.yml")
        fi
        if [[ -f "docker-compose.prod.yml" ]]; then
            COMPOSE_FILES+=("docker-compose.prod.yml")
        fi
    fi
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

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}🔍${NC} $1"
    fi
}

# Check if required tools are available
check_dependencies() {
    local missing_deps=()

    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_deps+=("docker-compose")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Validate Docker Compose syntax
validate_compose_syntax() {
    log_info "Validating Docker Compose syntax..."

    local compose_args=()
    for file in "${COMPOSE_FILES[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Compose file not found: $file"
            return 1
        fi
        compose_args+=("-f" "$file")
        log_verbose "Including compose file: $file"
    done

    if docker compose "${compose_args[@]}" config --quiet; then
        log_success "Docker Compose syntax is valid"
        return 0
    else
        log_error "Docker Compose syntax validation failed"
        return 1
    fi
}

# Check if external proxy network exists
validate_external_network() {
    if [[ "$CHECK_NETWORK" != "true" ]]; then
        log_verbose "Skipping network validation (--no-network)"
        return 0
    fi

    log_info "Checking external proxy network..."

    if docker network ls --format "{{.Name}}" | grep -q "^proxy$"; then
        log_success "External 'proxy' network exists"
        return 0
    else
        log_warning "External 'proxy' network not found"
        log_info "Create it with: docker network create proxy"
        return 1
    fi
}

# Validate Traefik labels
validate_traefik_labels() {
    if [[ "$CHECK_LABELS" != "true" ]]; then
        log_verbose "Skipping labels validation (--no-labels)"
        return 0
    fi

    log_info "Validating Traefik labels..."

    local compose_args=()
    for file in "${COMPOSE_FILES[@]}"; do
        compose_args+=("-f" "$file")
    done

    local config_output
    config_output=$(docker compose "${compose_args[@]}" config 2>/dev/null)

    local issues=0
    local services_with_traefik=()

    # Find services with traefik.enable=true
    while IFS= read -r line; do
        if [[ $line =~ traefik\.enable.*true ]]; then
            local service_section
            service_section=$(echo "$config_output" | grep -B 20 "$line" | grep -E "^  [a-zA-Z]" | tail -1 | sed 's/://' | xargs)
            if [[ -n "$service_section" ]]; then
                services_with_traefik+=("$service_section")
            fi
        fi
    done <<< "$config_output"

    log_verbose "Found services with Traefik integration: ${services_with_traefik[*]}"

    # Validate each service
    for service in "${services_with_traefik[@]}"; do
        log_verbose "Validating service: $service"

        local service_config
        service_config=$(echo "$config_output" | sed -n "/^  $service:/,/^  [a-zA-Z]/p" | head -n -1)

        # Check for required labels
        local required_patterns=(
            "traefik\.http\.routers\..*\.rule"
            "traefik\.http\.routers\..*\.entrypoints"
            "traefik\.http\.routers\..*\.service"
            "traefik\.http\.services\..*\.loadbalancer\.server\.port"
        )

        for pattern in "${required_patterns[@]}"; do
            if ! echo "$service_config" | grep -qE "$pattern"; then
                log_warning "Service '$service' missing pattern: $pattern"
                ((issues++))
            fi
        done

        # Check for security best practices
        if echo "$service_config" | grep -qE "entrypoints.*websecure"; then
            if ! echo "$service_config" | grep -qE "middlewares.*security-headers"; then
                log_warning "Service '$service' uses HTTPS but missing security-headers middleware"
                ((issues++))
            fi
        fi

        # Check for health checks
        if ! echo "$service_config" | grep -qE "healthcheck\.(path|interval)"; then
            log_verbose "Service '$service' could benefit from health check configuration"
        fi
    done

    if [[ $issues -eq 0 ]]; then
        log_success "Traefik labels validation passed"
        return 0
    else
        log_warning "Found $issues potential issues with Traefik labels"
        return 1
    fi
}

# Generate summary report
generate_report() {
    local compose_args=()
    for file in "${COMPOSE_FILES[@]}"; do
        compose_args+=("-f" "$file")
    done

    log_info "Configuration Summary:"

    local config_output
    config_output=$(docker compose "${compose_args[@]}" config 2>/dev/null)

    # Count services
    local total_services
    total_services=$(echo "$config_output" | grep -E "^  [a-zA-Z].*:" | wc -l)
    echo "  • Total services: $total_services"

    # Count Traefik-enabled services
    local traefik_services
    traefik_services=$(echo "$config_output" | grep -c "traefik.enable.*true" || true)
    echo "  • Traefik-enabled services: $traefik_services"

    # Count networks
    local networks
    networks=$(echo "$config_output" | sed -n '/^networks:/,/^[a-zA-Z]/p' | grep -E "^  [a-zA-Z].*:" | wc -l)
    echo "  • Networks defined: $networks"

    # List external networks
    local external_networks
    external_networks=$(echo "$config_output" | grep -A 1 "external: true" | grep -B 1 "external: true" | grep -E "^  [a-zA-Z].*:" | sed 's/://' | xargs)
    if [[ -n "$external_networks" ]]; then
        echo "  • External networks: $external_networks"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Traefik Configuration Validator${NC}"
    echo "=================================================="

    parse_args "$@"
    check_dependencies

    local exit_code=0

    # Run validations
    if ! validate_compose_syntax; then
        exit_code=1
    fi

    if ! validate_external_network; then
        exit_code=1
    fi

    if ! validate_traefik_labels; then
        exit_code=1
    fi

    echo ""
    generate_report

    echo ""
    if [[ $exit_code -eq 0 ]]; then
        log_success "All validations passed! 🎉"
    else
        log_warning "Some validations failed. Check the output above."
    fi

    exit $exit_code
}

# Run main function with all arguments
main "$@"

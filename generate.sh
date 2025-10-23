#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Dynamic Resume PDF Generator
# =============================================================================
# Generates multiple versions of resumes from template files
# See README.md for detailed usage
# =============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Configuration defaults
# =============================================================================
CONFIG_FILE="config.yaml"
TEMPLATES_DIR="templates"
OUTPUT_DIR="output"

# Global PDF settings (defaults)
PDF_ENGINE="xelatex"
FONT="Arial"
MARGIN="0.5in"
PAGESTYLE="empty"
FONTSIZE="11pt"
LINESTRETCH="1.0"

# Command-line argument overrides
ARG_TEMPLATES=""
ARG_VERSIONS=""
ARG_OUTPUT=""

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# =============================================================================
# Parse command-line arguments
# =============================================================================
parse_args() {
    for arg in "$@"; do
        case "$arg" in
            templates=*)
                ARG_TEMPLATES="${arg#*=}"
                ;;
            versions=*)
                ARG_VERSIONS="${arg#*=}"
                ;;
            output=*)
                ARG_OUTPUT="${arg#*=}"
                ;;
            *)
                log_error "Unknown argument: $arg"
                echo "Usage: $0 [templates=1,2] [versions=technical,general] [output=custom.pdf]"
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# Read configuration from YAML
# =============================================================================
read_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "Config file not found: $CONFIG_FILE (using defaults)"
        return
    fi

    # Try to use yq if available, otherwise basic bash parsing
    if command -v yq >/dev/null 2>&1; then
        # Read directories
        local templates_dir=$(yq eval '.directories.templates // "templates"' "$CONFIG_FILE" 2>/dev/null || echo "templates")
        local output_dir=$(yq eval '.directories.output // "output"' "$CONFIG_FILE" 2>/dev/null || echo "output")
        [[ -n "$templates_dir" ]] && TEMPLATES_DIR="$templates_dir"
        [[ -n "$output_dir" ]] && OUTPUT_DIR="$output_dir"

        # Read global settings
        PDF_ENGINE=$(yq eval '.global.pdf_engine // "xelatex"' "$CONFIG_FILE" 2>/dev/null || echo "xelatex")
        FONT=$(yq eval '.global.font // "Arial"' "$CONFIG_FILE" 2>/dev/null || echo "Arial")
        MARGIN=$(yq eval '.global.margin // "0.5in"' "$CONFIG_FILE" 2>/dev/null || echo "0.5in")
        PAGESTYLE=$(yq eval '.global.pagestyle // "empty"' "$CONFIG_FILE" 2>/dev/null || echo "empty")
        FONTSIZE=$(yq eval '.global.fontsize // "11pt"' "$CONFIG_FILE" 2>/dev/null || echo "11pt")
        LINESTRETCH=$(yq eval '.global.linestretch // "1.0"' "$CONFIG_FILE" 2>/dev/null || echo "1.0")
    else
        log_warn "yq not found - using basic config parsing (install yq for full config support)"
        # Basic grep-based parsing for directories
        TEMPLATES_DIR=$(grep -E '^\s*templates:\s*"?[^"#]+' "$CONFIG_FILE" | sed -E 's/.*:\s*"?([^"#]+)"?.*/\1/' | tr -d ' ' || echo "templates")
        OUTPUT_DIR=$(grep -E '^\s*output:\s*"?[^"#]+' "$CONFIG_FILE" | sed -E 's/.*:\s*"?([^"#]+)"?.*/\1/' | tr -d ' ' || echo "output")
    fi
}

# =============================================================================
# Get config value with priority: template_version > version > template > global
# =============================================================================
get_config_value() {
    local key="$1"
    local template="$2"
    local version="$3"
    local default="$4"
    local value="$default"

    if ! command -v yq >/dev/null 2>&1; then
        echo "$default"
        return
    fi

    # Try template_versions first (highest priority)
    local tv_value=$(yq eval ".template_versions.\"$template\".\"$version\".$key // \"\"" "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$tv_value" && "$tv_value" != "null" ]]; then
        echo "$tv_value"
        return
    fi

    # Try version-level
    local v_value=$(yq eval ".versions.\"$version\".$key // \"\"" "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$v_value" && "$v_value" != "null" ]]; then
        echo "$v_value"
        return
    fi

    # Try template-level
    local t_value=$(yq eval ".templates.\"$template\".$key // \"\"" "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$t_value" && "$t_value" != "null" ]]; then
        echo "$t_value"
        return
    fi

    # Fall back to default
    echo "$default"
}

# =============================================================================
# Extract version names from a template file
# =============================================================================
extract_versions() {
    local template="$1"

    # Match both <!--VERSION:name--> and <!--v:name-->
    grep -oE '<!--(VERSION|v):[^>]+-->' "$template" | \
        sed -E 's/<!--(VERSION|v):([^>]+)-->/\2/g' | \
        sort -u
}

# =============================================================================
# Generate markdown for a specific version
# =============================================================================
generate_version_markdown() {
    local template="$1"
    local version="$2"
    local output="$3"

    # Start with full template
    local content=$(cat "$template")

    # Get all versions in the template
    local all_versions=$(extract_versions "$template")

    # Remove content from all OTHER versions
    for other_version in $all_versions; do
        if [[ "$other_version" != "$version" ]]; then
            # Remove blocks with <!--VERSION:other--> or <!--v:other-->
            # Using perl for multi-line regex
            content=$(echo "$content" | perl -0777 -pe "s/<!--(VERSION|v):$other_version-->.*?<!--\/(VERSION|v)-->//gs")
        fi
    done

    # Now remove the version markers for the CURRENT version (keep content)
    content=$(echo "$content" | sed -E "s/<!--(VERSION|v):$version-->//g")
    content=$(echo "$content" | sed -E "s/<!--\/(VERSION|v)-->//g")

    # Write to output
    echo "$content" > "$output"
}

# =============================================================================
# Get geometry options as array from config
# =============================================================================
get_geometry_options() {
    local template="$1"
    local version="$2"

    if ! command -v yq >/dev/null 2>&1; then
        echo ""
        return
    fi

    # Try template_versions first
    local opts=$(yq eval ".template_versions.\"$template\".\"$version\".geometry_options // []" "$CONFIG_FILE" 2>/dev/null)
    if [[ "$opts" != "[]" && "$opts" != "null" ]]; then
        echo "$opts" | yq eval '.[]' - 2>/dev/null
        return
    fi

    # Try version-level
    opts=$(yq eval ".versions.\"$version\".geometry_options // []" "$CONFIG_FILE" 2>/dev/null)
    if [[ "$opts" != "[]" && "$opts" != "null" ]]; then
        echo "$opts" | yq eval '.[]' - 2>/dev/null
        return
    fi

    # Try template-level
    opts=$(yq eval ".templates.\"$template\".geometry_options // []" "$CONFIG_FILE" 2>/dev/null)
    if [[ "$opts" != "[]" && "$opts" != "null" ]]; then
        echo "$opts" | yq eval '.[]' - 2>/dev/null
        return
    fi

    # Try global
    opts=$(yq eval ".global.geometry_options // []" "$CONFIG_FILE" 2>/dev/null)
    if [[ "$opts" != "[]" && "$opts" != "null" ]]; then
        echo "$opts" | yq eval '.[]' - 2>/dev/null
        return
    fi
}

# =============================================================================
# Generate PDF from markdown
# =============================================================================
generate_pdf() {
    local md_file="$1"
    local pdf_file="$2"
    local template="$3"
    local version="$4"

    # Get configuration values
    local pdf_engine=$(get_config_value "pdf_engine" "$template" "$version" "$PDF_ENGINE")
    local font=$(get_config_value "font" "$template" "$version" "$FONT")
    local margin=$(get_config_value "margin" "$template" "$version" "$MARGIN")
    local pagestyle=$(get_config_value "pagestyle" "$template" "$version" "$PAGESTYLE")
    local fontsize=$(get_config_value "fontsize" "$template" "$version" "$FONTSIZE")
    local linestretch=$(get_config_value "linestretch" "$template" "$version" "$LINESTRETCH")

    # Get geometry options array
    local geometry_options=$(get_geometry_options "$template" "$version")

    # Check if pandoc is available
    if ! command -v pandoc >/dev/null 2>&1; then
        log_warn "pandoc not found - skipping PDF generation"
        return 1
    fi

    # Check if PDF engine is available
    if ! command -v "$pdf_engine" >/dev/null 2>&1; then
        log_warn "$pdf_engine not found - trying pdflatex"
        pdf_engine="pdflatex"
        if ! command -v pdflatex >/dev/null 2>&1; then
            log_error "No PDF engine found - install xelatex or pdflatex"
            return 1
        fi
    fi

    # Build pandoc command
    local pandoc_cmd=(pandoc "$md_file" --pdf-engine="$pdf_engine")

    # Add geometry options
    if [[ -n "$geometry_options" ]]; then
        # Add each geometry option separately
        while IFS= read -r geom_opt; do
            pandoc_cmd+=(-V "geometry:$geom_opt")
        done <<< "$geometry_options"
    else
        # Fall back to single margin value
        pandoc_cmd+=(-V "geometry:margin=$margin")
    fi

    # Handle font size - extract numeric value
    local fontsize_num=$(echo "$fontsize" | sed 's/pt$//')

    # For font sizes > 12pt, use extarticle document class and direct fontsize
    if [[ "$fontsize_num" -gt 12 ]]; then
        pandoc_cmd+=(-V "documentclass=extarticle")
        pandoc_cmd+=(-V "fontsize=$fontsize")
    else
        # Standard document class supports 10pt, 11pt, 12pt
        pandoc_cmd+=(-V "fontsize=$fontsize")
    fi

    # Add other variables
    pandoc_cmd+=(-V "pagestyle=$pagestyle")
    pandoc_cmd+=(-V "mainfont=$font")
    pandoc_cmd+=(-V "linestretch=$linestretch")
    pandoc_cmd+=(-o "$pdf_file")

    # Debug output (optional - uncomment to see pandoc command)
    echo "DEBUG: ${pandoc_cmd[@]}" >&2

    # Generate PDF
    "${pandoc_cmd[@]}" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        return 0
    else
        log_error "Failed to generate PDF: $pdf_file"
        return 1
    fi
}

# =============================================================================
# Get output name for a template/version combination
# =============================================================================
get_output_name() {
    local template="$1"
    local version="$2"

    # Command-line argument takes priority
    if [[ -n "$ARG_OUTPUT" ]]; then
        # Remove extension if provided
        echo "${ARG_OUTPUT%.pdf}"
        echo "${ARG_OUTPUT%.md}"
        return
    fi

    # Try to get custom output name from config
    local custom_name=$(get_config_value "output_name" "$template" "$version" "")

    if [[ -n "$custom_name" && "$custom_name" != "null" ]]; then
        # Custom name is the base - still append version
        echo "${custom_name}.${version}"
    else
        # Default: extract template name (remove .TEMPLATE.md)
        local base_name=$(basename "$template" .TEMPLATE.md)
        echo "${base_name}.${version}"
    fi
}

# =============================================================================
# Process a single template file
# =============================================================================
process_template() {
    local template_path="$1"
    local template_name=$(basename "$template_path")

    log_info "Processing: $template_name"

    # Extract available versions
    local available_versions=$(extract_versions "$template_path")

    if [[ -z "$available_versions" ]]; then
        log_warn "No versions found in $template_name (no <!--VERSION:name--> or <!--v:name--> markers)"
        return
    fi

    log_info "  Found versions: $(echo $available_versions | tr '\n' ' ')"

    # Filter versions if specified
    local versions_to_generate="$available_versions"
    if [[ -n "$ARG_VERSIONS" ]]; then
        versions_to_generate=""
        IFS=',' read -ra REQUESTED_VERSIONS <<< "$ARG_VERSIONS"
        for req_version in "${REQUESTED_VERSIONS[@]}"; do
            if echo "$available_versions" | grep -q "^${req_version}$"; then
                versions_to_generate="$versions_to_generate $req_version"
            else
                log_warn "  $template_name does not contain version '$req_version'"
            fi
        done
    fi

    # Generate each version
    for version in $versions_to_generate; do
        local output_name=$(get_output_name "$template_name" "$version")
        local md_output="$OUTPUT_DIR/${output_name}.md"
        local pdf_output="$OUTPUT_DIR/${output_name}.pdf"

        log_info "  Generating version: $version"

        # Generate markdown
        generate_version_markdown "$template_path" "$version" "$md_output"
        log_success "    Created: $md_output"

        # Generate PDF
        if generate_pdf "$md_output" "$pdf_output" "$template_name" "$version"; then
            log_success "    Created: $pdf_output"
        fi
    done
}

# =============================================================================
# Main execution
# =============================================================================
main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Dynamic Resume PDF Generator"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # Parse arguments
    parse_args "$@"

    # Read configuration
    read_config

    # Ensure output directory exists
    mkdir -p "$OUTPUT_DIR"

    # Find templates to process
    local templates_to_process=()

    if [[ -n "$ARG_TEMPLATES" ]]; then
        # Parse comma-separated list
        IFS=',' read -ra TEMPLATE_LIST <<< "$ARG_TEMPLATES"
        for template_spec in "${TEMPLATE_LIST[@]}"; do
            # Handle both "1" and "templates/Example_1.TEMPLATE.md" formats
            if [[ "$template_spec" == *.TEMPLATE.md ]]; then
                if [[ -f "$template_spec" ]]; then
                    templates_to_process+=("$template_spec")
                else
                    log_error "Template not found: $template_spec"
                fi
            else
                local template_file="$TEMPLATES_DIR/${template_spec}.TEMPLATE.md"
                if [[ -f "$template_file" ]]; then
                    templates_to_process+=("$template_file")
                else
                    log_error "Template not found: $template_file"
                fi
            fi
        done
    else
        # Find all templates in directory
        if [[ ! -d "$TEMPLATES_DIR" ]]; then
            log_error "Templates directory not found: $TEMPLATES_DIR"
            exit 1
        fi

        while IFS= read -r -d '' template; do
            templates_to_process+=("$template")
        done < <(find "$TEMPLATES_DIR" -maxdepth 1 -name "*.TEMPLATE.md" -print0 | sort -z)

        if [[ ${#templates_to_process[@]} -eq 0 ]]; then
            log_error "No .TEMPLATE.md files found in $TEMPLATES_DIR"
            exit 1
        fi
    fi

    # Process each template
    for template in "${templates_to_process[@]}"; do
        process_template "$template"
        echo
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Generation complete! Check $OUTPUT_DIR/ for results"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Run main
main "$@"

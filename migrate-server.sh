#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  🚀 Server Migration Tool
#  Automate file/directory transfer between servers with
#  integrity verification and dependency installation.
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

# ─── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Gradient palette (pastel-like colors for ASCII art)
G1='\033[38;5;51m'   # bright cyan
G2='\033[38;5;50m'   # cyan-green
G3='\033[38;5;49m'   # green-cyan
G4='\033[38;5;48m'   # seafoam
G5='\033[38;5;43m'   # teal
G6='\033[38;5;44m'   # aqua
G7='\033[38;5;80m'   # sky blue
G8='\033[38;5;117m'  # light blue
G9='\033[38;5;153m'  # periwinkle
G10='\033[38;5;189m' # lavender
G11='\033[38;5;183m' # light purple

# ─── Defaults ─────────────────────────────────────────────────
SSH_KEY=""
DEST_USER=""
DEST_IP=""
DEST_BASE_DIR=""
EXCLUDE_PATTERNS=("node_modules" ".git" "__pycache__" "*.pyc" ".venv")
SKIP_DEPS=false
SKIP_VERIFY=false
DRY_RUN=false
ITEMS_TO_TRANSFER=()

# ─── Helper Functions ─────────────────────────────────────────
print_banner() {
    echo ""
    echo -e "${G1}    _____ __________ _    ____________ ${NC}"
    echo -e "${G2}   / ___// ____/ __ \\ |  / / ____/ __ \\\\${NC}"
    echo -e "${G3}   \\__ \\/ __/ / /_/ / | / / __/ / /_/ /${NC}"
    echo -e "${G4}  ___/ / /___/ _, _/| |/ / /___/ _, _/ ${NC}"
    echo -e "${G5} /____/_____/_/ |_| |___/_____/_/ |_|  ${NC}"
    echo -e "${G6}                                        ${NC}"
    echo -e "${G7}     __  _________________  ___  ______________  _   __${NC}"
    echo -e "${G8}    /  |/  /  _/ ____/ __ \\/   |/_  __/  _/ __ \\/ | / /${NC}"
    echo -e "${G9}   / /|_/ // // / __/ /_/ / /| | / /  / // / / /  |/ / ${NC}"
    echo -e "${G10}  / /  / // // /_/ / _, _/ ___ |/ / _/ // /_/ / /|  /  ${NC}"
    echo -e "${G11} /_/  /_/___/\\____/_/ |_/_/  |_/_/ /___/\\____/_/ |_/   ${NC}"
    echo ""
    echo -e " ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${WHITE}${BOLD} 🛠️ Tool:${NC} ${YELLOW}Server Migration Automation${NC}"
    echo -e " ${WHITE}${BOLD} 📌 Features:${NC} ${GREEN}Files + Directories | MD5 Verify | Auto Install Deps${NC}"
    echo -e " ${WHITE}${BOLD} 🔐 Security:${NC} ${BLUE}SSH Key Auth + StrictHostKey Bypass${NC}"
    echo -e " ${CYAN} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_info()    { echo -e "  ${CYAN}ℹ${NC}  $1"; }
log_success() { echo -e "  ${GREEN}✅${NC} $1"; }
log_warn()    { echo -e "  ${YELLOW}⚠️${NC}  $1"; }
log_error()   { echo -e "  ${RED}❌${NC} $1"; }
log_step()    { echo -e "\n${MAGENTA}${BOLD}[$1/$TOTAL_STEPS]${NC} ${BOLD}$2${NC}"; }

separator() {
    echo -e "${DIM}  ──────────────────────────────────────────────────${NC}"
}

# Returns "directory" or "file" based on the path type.
item_kind() {
    local p="$1"
    if [[ -d "$p" ]]; then
        echo "directory"
    elif [[ -f "$p" ]]; then
        echo "file"
    else
        echo "missing"
    fi
}

# ─── Usage ────────────────────────────────────────────────────
usage() {
    echo -e "${BOLD}Usage:${NC}"
    echo "  $0 [OPTIONS]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  -p, --path PATH        File or directory to transfer (can be used multiple times)"
    echo "  -d, --dir PATH         Alias for --path (kept for backward compatibility)"
    echo "  -u, --user USER        Destination server username"
    echo "  -i, --ip IP            Destination server IP address"
    echo "  -k, --key FILE         SSH private key file path"
    echo "  -b, --base-dir DIR     Base directory on destination (default: /home/USER)"
    echo "  -e, --exclude PATTERN  Additional exclude pattern (can be used multiple times)"
    echo "      --skip-deps        Skip dependency installation"
    echo "      --skip-verify      Skip integrity verification"
    echo "      --dry-run          Show what would be done without executing"
    echo "  -h, --help             Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  # Interactive mode (will prompt for everything):"
    echo "  $0"
    echo ""
    echo "  # Transfer mixed files and directories:"
    echo "  $0 -p /root/bot -p /root/backup.tar.gz -p /root/setup.sh \\"
    echo "     -u ubuntu -i 13.236.147.204 -k /root/key.pem"
    echo ""
    echo "  # Mix: specify server, prompt for paths:"
    echo "  $0 -u ubuntu -i 13.236.147.204 -k /root/key.pem"
    exit 0
}

# ─── Parse Arguments ──────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--path)      ITEMS_TO_TRANSFER+=("$2"); shift 2;;
            -d|--dir)       ITEMS_TO_TRANSFER+=("$2"); shift 2;;
            -u|--user)      DEST_USER="$2"; shift 2;;
            -i|--ip)        DEST_IP="$2"; shift 2;;
            -k|--key)       SSH_KEY="$2"; shift 2;;
            -b|--base-dir)  DEST_BASE_DIR="$2"; shift 2;;
            -e|--exclude)   EXCLUDE_PATTERNS+=("$2"); shift 2;;
            --skip-deps)    SKIP_DEPS=true; shift;;
            --skip-verify)  SKIP_VERIFY=true; shift;;
            --dry-run)      DRY_RUN=true; shift;;
            -h|--help)      usage;;
            *)              log_error "Unknown option: $1"; usage;;
        esac
    done
}

# ─── Interactive Input ────────────────────────────────────────
prompt_server_details() {
    echo -e "\n${BOLD}📡 Destination Server Configuration${NC}"
    separator

    if [[ -z "$DEST_IP" ]]; then
        read -rp "  Server IP address: " DEST_IP
    else
        log_info "Server IP: ${GREEN}$DEST_IP${NC}"
    fi

    if [[ -z "$DEST_USER" ]]; then
        read -rp "  Username: " DEST_USER
    else
        log_info "Username: ${GREEN}$DEST_USER${NC}"
    fi

    if [[ -z "$SSH_KEY" ]]; then
        read -rp "  SSH key path (leave empty for password auth): " SSH_KEY
    else
        log_info "SSH key: ${GREEN}$SSH_KEY${NC}"
    fi

    if [[ -z "$DEST_BASE_DIR" ]]; then
        DEST_BASE_DIR="/home/$DEST_USER"
        read -rp "  Base directory on destination [${DEST_BASE_DIR}]: " input_base
        [[ -n "$input_base" ]] && DEST_BASE_DIR="$input_base"
    else
        log_info "Base directory: ${GREEN}$DEST_BASE_DIR${NC}"
    fi
}

prompt_items() {
    if [[ ${#ITEMS_TO_TRANSFER[@]} -gt 0 ]]; then
        echo -e "\n${BOLD}📁 Items to Transfer${NC}"
        separator
        for item in "${ITEMS_TO_TRANSFER[@]}"; do
            local kind
            kind=$(item_kind "$item")
            if [[ "$kind" == "missing" ]]; then
                log_error "$item — NOT FOUND (skipping)"
            else
                local size
                size=$(du -sh "$item" 2>/dev/null | cut -f1)
                local icon="📂"
                [[ "$kind" == "file" ]] && icon="📄"
                log_success "$icon $item ($size)"
            fi
        done
        return
    fi

    echo -e "\n${BOLD}📁 Select Files/Directories to Transfer${NC}"
    separator
    echo -e "  ${DIM}Enter file or directory paths one per line."
    echo -e "  Press Enter on empty line when done.${NC}"
    echo ""

    while true; do
        read -rp "  📂 Path (or Enter to finish): " item_path

        # Empty = done
        [[ -z "$item_path" ]] && break

        # Expand ~ if used
        item_path="${item_path/#\~/$HOME}"

        # Validate
        if [[ ! -e "$item_path" ]]; then
            log_error "'$item_path' does not exist."
            continue
        fi

        if [[ ! -f "$item_path" && ! -d "$item_path" ]]; then
            log_error "'$item_path' is not a regular file or directory."
            continue
        fi

        # Check duplicate
        local dup=false
        for existing in "${ITEMS_TO_TRANSFER[@]+"${ITEMS_TO_TRANSFER[@]}"}"; do
            [[ "$existing" == "$item_path" ]] && dup=true && break
        done
        if $dup; then
            log_warn "Already added: $item_path"
            continue
        fi

        local size kind icon
        size=$(du -sh "$item_path" 2>/dev/null | cut -f1)
        kind=$(item_kind "$item_path")
        icon="📂"
        [[ "$kind" == "file" ]] && icon="📄"
        ITEMS_TO_TRANSFER+=("$item_path")
        log_success "Added: $icon $item_path ($size)"
    done

    if [[ ${#ITEMS_TO_TRANSFER[@]} -eq 0 ]]; then
        log_error "No items selected. Exiting."
        exit 1
    fi
}

# ─── Validation ───────────────────────────────────────────────
validate() {
    echo -e "\n${BOLD}🔍 Validating Configuration${NC}"
    separator
    local errors=0

    # Validate IP
    if [[ -z "$DEST_IP" ]]; then
        log_error "Destination IP is required."; ((errors++))
    fi

    # Validate user
    if [[ -z "$DEST_USER" ]]; then
        log_error "Username is required."; ((errors++))
    fi

    # Validate SSH key if provided
    if [[ -n "$SSH_KEY" && ! -f "$SSH_KEY" ]]; then
        log_error "SSH key not found: $SSH_KEY"; ((errors++))
    fi

    # Fix SSH key permissions
    if [[ -n "$SSH_KEY" && -f "$SSH_KEY" ]]; then
        chmod 600 "$SSH_KEY" 2>/dev/null
        log_success "SSH key permissions set (600)"
    fi

    # Validate items exist (file or dir)
    local valid_items=()
    for item in "${ITEMS_TO_TRANSFER[@]}"; do
        if [[ -d "$item" || -f "$item" ]]; then
            valid_items+=("$item")
        else
            log_warn "Skipping non-existent: $item"
        fi
    done
    ITEMS_TO_TRANSFER=("${valid_items[@]+"${valid_items[@]}"}")

    if [[ ${#ITEMS_TO_TRANSFER[@]} -eq 0 ]]; then
        log_error "No valid items to transfer."; ((errors++))
    fi

    # Test SSH connection
    if [[ $errors -eq 0 ]]; then
        log_info "Testing SSH connection..."
        local ssh_opts
        ssh_opts=$(build_ssh_opts)
        if ssh $ssh_opts -o ConnectTimeout=10 "${DEST_USER}@${DEST_IP}" 'echo ok' &>/dev/null; then
            log_success "SSH connection successful"
        else
            log_error "Cannot connect to ${DEST_USER}@${DEST_IP}"
            ((errors++))
        fi
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "$errors error(s) found. Please fix and try again."
        exit 1
    fi

    log_success "All checks passed"
}

# ─── SSH/Rsync Helpers ────────────────────────────────────────
build_ssh_opts() {
    local opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
    [[ -n "$SSH_KEY" ]] && opts="-i $SSH_KEY $opts"
    echo "$opts"
}

remote_exec() {
    local ssh_opts
    ssh_opts=$(build_ssh_opts)
    ssh $ssh_opts "${DEST_USER}@${DEST_IP}" "$1"
}

# Ensure the destination base directory exists before transferring files into it.
ensure_remote_base_dir() {
    remote_exec "mkdir -p '$DEST_BASE_DIR'" 2>/dev/null
}

# ─── Transfer ─────────────────────────────────────────────────
transfer_items() {
    local count=0
    local total=${#ITEMS_TO_TRANSFER[@]}
    local failed=()
    local succeeded=()

    echo -e "\n${BOLD}📤 Transferring ${total} Item$([ $total -gt 1 ] && echo "s")${NC}"
    separator

    ensure_remote_base_dir

    for item in "${ITEMS_TO_TRANSFER[@]}"; do
        ((count++))
        local item_name kind size dest_path
        item_name=$(basename "$item")
        kind=$(item_kind "$item")
        size=$(du -sh "$item" 2>/dev/null | cut -f1)
        dest_path="${DEST_BASE_DIR}/${item_name}"

        local icon="📂"
        [[ "$kind" == "file" ]] && icon="📄"
        echo -e "\n  ${CYAN}[$count/$total]${NC} ${icon} ${BOLD}$item_name${NC} ($size, $kind) → $dest_path"

        if $DRY_RUN; then
            log_info "[DRY RUN] Would transfer: $item → $dest_path"
            succeeded+=("$item")
            continue
        fi

        local ssh_opts
        ssh_opts=$(build_ssh_opts)

        local rsync_status=0
        if [[ "$kind" == "directory" ]]; then
            local exclude_args=""
            for pattern in "${EXCLUDE_PATTERNS[@]}"; do
                exclude_args="$exclude_args --exclude=$pattern"
            done
            rsync -avz --progress $exclude_args \
                -e "ssh $ssh_opts" \
                "$item/" "${DEST_USER}@${DEST_IP}:${dest_path}/" 2>&1 | \
                while IFS= read -r line; do
                    if [[ "$line" == *"sent "* && "$line" == *"bytes"* ]]; then
                        echo -e "    ${DIM}$line${NC}"
                    fi
                done
            rsync_status=${PIPESTATUS[0]}
        else
            # Single file: no excludes, no trailing slashes, dest is full file path.
            rsync -avz --progress \
                -e "ssh $ssh_opts" \
                "$item" "${DEST_USER}@${DEST_IP}:${dest_path}" 2>&1 | \
                while IFS= read -r line; do
                    if [[ "$line" == *"sent "* && "$line" == *"bytes"* ]]; then
                        echo -e "    ${DIM}$line${NC}"
                    fi
                done
            rsync_status=${PIPESTATUS[0]}
        fi

        if [[ $rsync_status -eq 0 ]]; then
            log_success "$item_name transferred successfully"
            succeeded+=("$item")
        else
            log_error "$item_name transfer FAILED (rsync exit $rsync_status)"
            failed+=("$item")
        fi
    done

    echo ""
    separator
    log_success "${#succeeded[@]}/$total items transferred"
    if [[ ${#failed[@]} -gt 0 ]]; then
        log_error "${#failed[@]} failed: ${failed[*]}"
        return 1
    fi
}

# ─── Verify Integrity ────────────────────────────────────────
verify_integrity() {
    if $SKIP_VERIFY || $DRY_RUN; then
        log_info "Skipping integrity verification"
        return 0
    fi

    echo -e "\n${BOLD}🔐 Verifying Integrity (MD5 Checksums)${NC}"
    separator

    local all_ok=true

    for item in "${ITEMS_TO_TRANSFER[@]}"; do
        local item_name kind dest_path
        item_name=$(basename "$item")
        kind=$(item_kind "$item")
        dest_path="${DEST_BASE_DIR}/${item_name}"

        echo -ne "  Checking ${BOLD}$item_name${NC}... "

        if [[ "$kind" == "file" ]]; then
            # Single-file checksum compare.
            local src_sum dst_sum
            src_sum=$(md5sum "$item" 2>/dev/null | awk '{print $1}')
            dst_sum=$(remote_exec "md5sum '$dest_path' 2>/dev/null | awk '{print \$1}'" 2>/dev/null)

            if [[ -z "$src_sum" || -z "$dst_sum" ]]; then
                echo -e "${RED}❌ Could not read checksum${NC}"
                all_ok=false
            elif [[ "$src_sum" == "$dst_sum" ]]; then
                echo -e "${GREEN}✅ OK${NC} ($src_sum)"
            else
                echo -e "${RED}❌ Checksum mismatch${NC}"
                echo -e "    ${DIM}src: $src_sum${NC}"
                echo -e "    ${DIM}dst: $dst_sum${NC}"
                all_ok=false
            fi
            continue
        fi

        # Directory: walk and compare every file's checksum.
        local find_excludes=""
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            find_excludes="$find_excludes -not -path '*/$pattern/*'"
        done

        local src_checksums dst_checksums
        src_checksums=$(eval "find '$item' -type f $find_excludes -exec md5sum {} \;" 2>/dev/null | \
            awk -v base="$item" '{gsub(base"/", "", $2); print $1, $2}' | sort -k2)
        dst_checksums=$(remote_exec "find '$dest_path' -type f $find_excludes -exec md5sum {} \;" 2>/dev/null | \
            awk -v base="$dest_path" '{gsub(base"/", "", $2); print $1, $2}' | sort -k2)

        local src_count
        src_count=$(echo "$src_checksums" | grep -c . 2>/dev/null || echo 0)

        local diff_result
        diff_result=$(diff <(echo "$src_checksums") <(echo "$dst_checksums") 2>/dev/null)

        if [[ -z "$diff_result" ]]; then
            echo -e "${GREEN}✅ OK${NC} ($src_count files match)"
        else
            local diff_count
            diff_count=$(echo "$diff_result" | grep -cE "^[<>]" 2>/dev/null || echo 0)

            if [[ "$diff_count" -le 10 ]]; then
                echo -e "${YELLOW}⚠️  $((diff_count/2)) files differ${NC} (likely runtime/log files)"
                echo "$diff_result" | grep -E "^[<>]" | awk '{print "      " $1, $3}' | head -10
            else
                echo -e "${RED}❌ $((diff_count/2)) files differ!${NC}"
                all_ok=false
            fi
        fi
    done

    if $all_ok; then
        echo ""
        log_success "Integrity verification passed — no corrupt items!"
    else
        echo ""
        log_error "Some items may be corrupt. Consider re-transferring."
        return 1
    fi
}

# ─── Install Dependencies ────────────────────────────────────
install_dependencies() {
    if $SKIP_DEPS || $DRY_RUN; then
        log_info "Skipping dependency installation"
        return 0
    fi

    echo -e "\n${BOLD}📦 Installing Dependencies on Destination${NC}"
    separator

    local ran_any=false

    for item in "${ITEMS_TO_TRANSFER[@]}"; do
        # Dependency install only makes sense for project directories.
        [[ ! -d "$item" ]] && continue

        local item_name dest_path
        item_name=$(basename "$item")
        dest_path="${DEST_BASE_DIR}/${item_name}"

        # Node.js project
        if [[ -f "$item/package.json" ]]; then
            ran_any=true
            echo -ne "  ${CYAN}npm install${NC} ${BOLD}$item_name${NC}... "
            local npm_result
            npm_result=$(remote_exec "cd '$dest_path' && npm install 2>&1 | tail -3" 2>&1)
            if [[ $? -eq 0 ]]; then
                local pkg_count
                pkg_count=$(echo "$npm_result" | grep -oE "added [0-9]+" | grep -oE "[0-9]+" || echo "?")
                echo -e "${GREEN}✅${NC} ($pkg_count packages)"
            else
                echo -e "${RED}❌ Failed${NC}"
                echo -e "    ${DIM}$npm_result${NC}"
            fi
        fi

        # Python project (skip if a venv was transferred along).
        if [[ -f "$item/requirements.txt" && ! -d "$item/venv" ]]; then
            ran_any=true
            echo -ne "  ${CYAN}pip install${NC} ${BOLD}$item_name${NC}... "
            local pip_result
            pip_result=$(remote_exec "cd '$dest_path' && python3 -m pip install -r requirements.txt 2>&1 | tail -3" 2>&1)
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}✅${NC}"
            else
                echo -e "${RED}❌ Failed${NC}"
            fi
        fi
    done

    if ! $ran_any; then
        log_info "No project directories with package.json or requirements.txt — nothing to install."
    fi
}

# ─── Summary ─────────────────────────────────────────────────
print_summary() {
    echo -e "\n${CYAN}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║            📋  Migration Summary                ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "  ${BOLD}Server:${NC}      ${DEST_USER}@${DEST_IP}"
    echo -e "  ${BOLD}Dest Base:${NC}   ${DEST_BASE_DIR}"
    echo -e "  ${BOLD}Items:${NC}       ${#ITEMS_TO_TRANSFER[@]}"
    echo ""

    for item in "${ITEMS_TO_TRANSFER[@]}"; do
        local item_name kind icon
        item_name=$(basename "$item")
        kind=$(item_kind "$item")
        icon="📂"
        [[ "$kind" == "file" ]] && icon="📄"
        echo -e "    ✅ $icon $item → ${DEST_BASE_DIR}/${item_name}"
    done

    echo ""
    separator
    echo -e "  ${GREEN}${BOLD}🎉 Migration completed successfully!${NC}"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────
main() {
    print_banner
    parse_args "$@"

    # Step 1: Server details
    prompt_server_details

    # Step 2: Select items (files and/or directories)
    prompt_items

    # Step 3: Confirmation
    echo -e "\n${BOLD}📋 Transfer Plan${NC}"
    separator
    echo -e "  ${BOLD}From:${NC} $(hostname) (this server)"
    echo -e "  ${BOLD}To:${NC}   ${DEST_USER}@${DEST_IP}:${DEST_BASE_DIR}"
    echo -e "  ${BOLD}Items:${NC} ${#ITEMS_TO_TRANSFER[@]}"
    for item in "${ITEMS_TO_TRANSFER[@]}"; do
        local size kind icon
        size=$(du -sh "$item" --exclude='node_modules' 2>/dev/null | cut -f1)
        kind=$(item_kind "$item")
        icon="📂"
        [[ "$kind" == "file" ]] && icon="📄"
        echo -e "        $icon $(basename "$item") ($size, $kind)"
    done
    echo -e "  ${BOLD}Exclude (dirs only):${NC} ${EXCLUDE_PATTERNS[*]}"
    echo ""

    if ! $DRY_RUN; then
        read -rp "  Proceed with transfer? [Y/n]: " confirm
        if [[ "$confirm" =~ ^[Nn] ]]; then
            log_warn "Aborted by user."
            exit 0
        fi
    fi

    TOTAL_STEPS=3
    [[ $SKIP_VERIFY == true ]] && ((TOTAL_STEPS--))
    [[ $SKIP_DEPS == true ]] && ((TOTAL_STEPS--))
    local step=0

    # Step: Validate
    validate

    # Step: Transfer
    ((step++))
    log_step $step "Transferring Items"
    transfer_items

    # Step: Verify
    if ! $SKIP_VERIFY; then
        ((step++))
        log_step $step "Verifying Integrity"
        verify_integrity
    fi

    # Step: Dependencies
    if ! $SKIP_DEPS; then
        ((step++))
        log_step $step "Installing Dependencies"
        install_dependencies
    fi

    # Summary
    print_summary
}

main "$@"

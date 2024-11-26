#!/bin/bash
#
# Vanity GPG Key Miner
# Parallel miner for GPG keys with vanity prefixes
# Searches for keys starting with: 0x7777, 0xBEEF, or 0xDEAD
#
# Author: lil sauna
# License: MIT
# Repository: https://github.com/lilsauna/vanity-gpg-miner
#

if [ $# -ne 2 ]; then
    echo "Usage: $0 \"Your Name\" \"your.email@example.com\""
    exit 1
fi

# =====================================
# Configuration
# =====================================
NAME="$1"
EMAIL="$2"
EXPORT_DIR="./gpg_export"
TOTAL=1000000
TEMP_DIR="/tmp/gpg_temp"
PROGRESS_FILE="$TEMP_DIR/progress"
LAST_COUNT_FILE="$TEMP_DIR/last_count"
START_TIME="$TEMP_DIR/start_time"
CORES=$(nproc)
CHUNK_SIZE=$(( TOTAL / CORES + 1))

# =====================================
# Helper Functions
# =====================================
setup_directories() {
    mkdir -p "$EXPORT_DIR"
    mkdir -p "$TEMP_DIR"
    echo "0" > "$PROGRESS_FILE"
    echo "0" > "$LAST_COUNT_FILE"
    date +%s > "$START_TIME"
}

cleanup() {
    echo -e "\nCleaning up..."
    pkill -P $$ 2>/dev/null
    pkill -f "gpg --batch" 2>/dev/null
    rm -rf "$TEMP_DIR"
    exit 1
}

calculate_speed() {
    local current=$1
    local last_count=$(cat "$LAST_COUNT_FILE")
    local elapsed=$2
    
    # Calculate keys per second
    local keys_per_sec=0
    if [ $elapsed -gt 0 ]; then
        keys_per_sec=$(( (current - last_count) ))
    fi
    
    # Update last count
    echo "$current" > "$LAST_COUNT_FILE"
    
    echo "$keys_per_sec"
}

show_progress() {
    local last_update=$(date +%s)
    
    while true; do
        CURRENT=$(cat "$PROGRESS_FILE" 2>/dev/null || echo "0")
        CURRENT=${CURRENT:-0}
        FOUND=$(find "$EXPORT_DIR" -name "public_key_*.asc" 2>/dev/null | wc -l || echo "0")
        FOUND=${FOUND:-0}
        
        current_time=$(date +%s)
        elapsed=$((current_time - last_update))
        
        if [ $elapsed -ge 1 ]; then
            SPEED=$(calculate_speed $CURRENT $elapsed)
            last_update=$current_time
            
            # Calculate overall average
            start_time=$(cat "$START_TIME")
            total_elapsed=$((current_time - start_time))
            [ $total_elapsed -lt 1 ] && total_elapsed=1
            AVG_SPEED=$(( CURRENT / total_elapsed ))
            
            CURRENT=$(printf "%.0f" "$CURRENT")
            PERCENT=$(( (CURRENT * 100) / TOTAL ))
            
            printf "\rProgress: [%3d%%] Checked: %d/%d Found: %d Keys | Speed: %d k/s | Avg: %d k/s   " \
                   "$PERCENT" "$CURRENT" "$TOTAL" "$FOUND" "$SPEED" "$AVG_SPEED"
        fi
        
        sleep 0.1
        [[ $CURRENT -ge $TOTAL ]] && break
    done
}

create_worker_script() {
    cat > "$TEMP_DIR/worker.sh" << 'EOF'
#!/bin/bash

# Arguments
START=$1        # Starting number
END=$2          # Ending number
NAME=$3         # Name for key
EMAIL=$4        # Email for key
EXPORT_DIR=$5   # Final export directory
PROGRESS_FILE=$6

generate_key() {
    local i=$1
    local random_str=$(openssl rand -hex 4)
    local gpg_home="/tmp/gpg_${i}_${random_str}"
    
    # Setup GPG environment
    export GNUPGHOME="$gpg_home"
    mkdir -p "$GNUPGHOME"
    chmod 700 "$GNUPGHOME"

    # Generate key
    gpg --batch --generate-key <<INNEREOF 2>/dev/null
Key-Type: EDDSA
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ECDH
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: $NAME
Name-Email: $EMAIL
Expire-Date: 0
%no-protection
%commit
INNEREOF

    # Get key ID as hex and convert to uppercase
    local key_id=$(gpg --with-colons --list-keys --keyid-format LONG "$EMAIL" 2>/dev/null | grep ^pub | cut -d: -f5)
    key_id_upper=$(echo "$key_id" | tr '[:lower:]' '[:upper:]')

    # Convert to hex for pattern matching
    local hex_id=$(printf '%X' 0x${key_id_upper} 2>/dev/null)
    
    # Check for hex patterns (7777, BEEF, DEAD) at the start
    if [[ $hex_id =~ ^(7777|BEEF|DEAD) ]]; then
        gpg --armor --export "$EMAIL" > "$EXPORT_DIR/public_key_${i}.asc" 2>/dev/null
        gpg --armor --export-secret-keys "$EMAIL" > "$EXPORT_DIR/private_key_${i}.asc" 2>/dev/null
        echo "[$i] $key_id (0x$hex_id)" >> "$EXPORT_DIR/found_keys.txt"
        echo "Found key with ID: $hex_id"
    fi

    # Cleanup
    rm -rf "$gpg_home"

    # Update progress atomically
    (
        while ! ln "$PROGRESS_FILE" "$PROGRESS_FILE.lock" 2>/dev/null; do
            sleep 0.1
        done
        local current=$(cat "$PROGRESS_FILE")
        echo $((current + 1)) > "$PROGRESS_FILE"
        rm -f "$PROGRESS_FILE.lock"
    ) 2>/dev/null
}

# Process range of numbers
for i in $(seq $START $END); do
    generate_key $i
done
EOF

    chmod +x "$TEMP_DIR/worker.sh"
}

show_results() {
    echo -e "\nFound special keys:"
    if [ -f "$EXPORT_DIR/found_keys.txt" ]; then
        cat "$EXPORT_DIR/found_keys.txt"
        echo "Total found: $(wc -l < "$EXPORT_DIR/found_keys.txt")"
    fi
    echo "Keys are saved in $EXPORT_DIR/"
}

# =====================================
# Main Script
# =====================================
main() {
    # Set up environment
    trap cleanup SIGINT SIGTERM
    setup_directories
    create_worker_script

    # Start progress display
    show_progress &
    PROGRESS_PID=$!

    # Start workers with non-overlapping ranges
    echo "Starting key generation with $CORES cores..."
    for ((i=0; i<CORES; i++)); do
        START=$((i * CHUNK_SIZE + 1))
        END=$((START + CHUNK_SIZE - 1))
        [ $i -eq $((CORES-1)) ] && END=$TOTAL
        
        "$TEMP_DIR/worker.sh" $START $END "$NAME" "$EMAIL" "$EXPORT_DIR" "$PROGRESS_FILE" &
    done

    # Wait for completion
    wait

    # Cleanup and show results
    kill $PROGRESS_PID 2>/dev/null
    show_results
    rm -rf "$TEMP_DIR"
}

# Run main function
main

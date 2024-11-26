#!/bin/bash
#
# Enhanced Vanity GPG Key Miner
# Parallel miner for GPG keys with extensive vanity prefix patterns
# Searches for keys starting with interesting hex patterns
#
# Based on original by lil sauna
# License: MIT
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

# Extensive list of interesting patterns to search for
PATTERNS=(
    # Classic 4-character patterns
    "DEAD"    # Classic hex
    "BEEF"    # Classic hex
    "CAFE"    # Coffee!
    "BABE"    # Classic hex
    "FACE"    # Face
    "FADE"    # Fade
    "FEED"    # Feed
    "F00D"    # Food
    "B00B"    # Playful
    "BADD"    # Bad
    "DAD0"    # Dad
    "DADA"    # Dada art movement
    "DEED"    # Deed
    "D0CE"    # Doce (twelve in Portuguese)
    "ACE0"    # Ace
    "ACED"    # Aced
    "BEAD"    # Bead
    "DEAF"    # Deaf
    "DECADE"  # Decade
    "DEFACE"  # Deface
    
    # Number patterns
    "7777"    # Lucky sevens
    "1337"    # Leet
    "0DAD"    # Zero Dad
    "0000"    # All zeros
    "FFFF"    # All F's
    "1111"    # All ones
    "2222"    # Repeated twos
    "3333"    # Repeated threes
    "4444"    # Repeated fours
    "5555"    # Repeated fives
    "6666"    # Repeated sixes
    "8888"    # Lucky Chinese number
    "9999"    # Repeated nines
    "1234"    # Sequential
    "4321"    # Reverse sequential
    "0123"    # Zero sequential
    "ABCD"    # Alphabetical
    "DCBA"    # Reverse alphabetical
    
    # 5-character patterns
    "FACED"   # Faced
    "DEAF0"   # Deaf zero
    "DECAF"   # Decaf coffee
    "BAAAD"   # Bad
    "BREAD"   # Bread
    "DABBED"  # Dabbed
    "DECADE"  # Decade
    "DEFACE"  # Deface
    
    # 6-character patterns
    "FEEDC0"  # Feed co
    "DECADE5"  # Decades
    "DEADED"  # Deaded
    "BEADED"  # Beaded
    "CAFFEE"  # Almost coffee
    "DEFADE"  # Defade
    "DEFACE"  # Deface
    
    # 7-character patterns
    "DEADBED"  # Dead bed
    "BADDEED"  # Bad deed
    "BEEFEED"  # Beef feed
    "CAFEBAD"  # Bad cafe
    "DEAFBEE"  # Deaf bee
    "FEEDBAG"  # Feed bag
    
    # 8-character patterns
    "DEADBEEF"  # Classic dead beef
    "BAAAAAAD"  # Very bad
    "CAFEBABE"  # Java magic
    "DEFEC8ED"  # Defected
    "FEEDFACE"  # Feed face
    "FACADE00"  # Facade
    "DEAFBABE"  # Deaf babe
    "DEADC0DE"  # Dead code
    "BADCABLE"  # Bad cable
    "BAADF00D"  # Bad food
    "1BADB002"  # Bad boot
    "DEFEC8ED"  # Defected
    
    # Longer patterns (9-16 characters)
    "DEADBEEF00"    # Extended dead beef
    "CAFEBABE00"    # Extended Java magic
    "FEEDFACADE"    # Feed facade
    "BADCOFFEE00"   # Bad coffee
    "FACADE0FACE"   # Facade face
    "DEADC0DEDEAF"  # Dead code deaf
    "FEEDDEADBEEF"  # Feed dead beef
    "DEFACEDCAFE"   # Defaced cafe
    "DEADFACEFEED"  # Dead face feed
    "C0DEDEADBEEF"  # Code dead beef
    "CAFED00DFEED"  # Cafe dood feed
    "AAAAAAAAAA"    # Ten A's
    "AAAAAAAAAAAA"  # Twelve A's
    "DEADC0DEDEAD"  # Dead code dead
    "BADC0FFEE000"  # Bad coffee
    "DEFACEBADCODE" # Deface bad code
    
    # Mathematical references
    "B0BB1E55"     # Bobbles
    "C0C0BABE"     # Coco babe
    "D15EA5ED"     # Diseased
    "ACC01ADE"     # Accolade
    "DEC0DED"      # Decoded
    "FACEB00C"     # Facebook
    "0B5E55ED"     # Obsessed
    
    # Tech references
    "C0DEC0DE"     # Code code
    "DADADATA"     # Dada data
    "1D10C123"     # Idiots (leet)
    "DEFAACED"     # Defaced
    "D15EA5E5"     # Diseases
    
    # Fun with zeros and ones
    "B00B1E5"      # Boobies
    "C001CAFE"     # Cool cafe
    "BADDAD00"     # Bad dad
    "B01DFACE"     # Bold face
    
    # Repeating patterns
    "AAAAAAAA"     # Eight A's
    "BBBBBBBB"     # Eight B's
    "CCCCCCCC"     # Eight C's
    "DDDDDDDD"     # Eight D's
    "EEEEEEEE"     # Eight E's
    "FFFFFFFF"     # Eight F's
    
    # Mixed patterns
    "A5A5A5A5"     # Alternating A5
    "B4B4B4B4"     # Alternating B4
    "C3C3C3C3"     # Alternating C3
    "D2D2D2D2"     # Alternating D2
    "E1E1E1E1"     # Alternating E1
    "F0F0F0F0"     # Alternating F0
    
    # Advanced sequences
    "A5B4C3D2"     # Descending pattern
    "123456FF"     # Ascending with FF
    "FEDCBA00"     # Descending with 00
    "A1B2C3D4"     # Ascending pairs
    "F1E2D3C4"     # Descending mixed
    
    # Full 16-character patterns (super rare!)
    # Classic repetitions
    "DEADBEEFDEADBEEF"  # Classic double deadbeef
    "DEADDEADDEADDEAD"  # Quadruple dead
    "BEEFBEEFBEEFBEEF"  # Quadruple beef
    "CAFECAFECAFECAFE"  # Quadruple cafe
    "FACEFACEFACEFACE"  # Quadruple face
    "FEEDFEEDFEEDFEED"  # Quadruple feed
    "BABEBABEBABESABE"  # Quadruple babe
    "DEAFDEAFDEAFDEAF"  # Quadruple deaf
    
    # Pure repetitions (extremely rare)
    "0000000000000000"  # All zeros
    "1111111111111111"  # All ones
    "2222222222222222"  # All twos
    "3333333333333333"  # All threes
    "4444444444444444"  # All fours
    "5555555555555555"  # All fives
    "6666666666666666"  # All sixes
    "7777777777777777"  # All sevens
    "8888888888888888"  # All eights
    "9999999999999999"  # All nines
    "AAAAAAAAAAAAAAAA"  # All A's
    "BBBBBBBBBBBBBBBB"  # All B's
    "CCCCCCCCCCCCCCCC"  # All C's
    "DDDDDDDDDDDDDDDD"  # All D's
    "EEEEEEEEEEEEEEEE"  # All E's
    "FFFFFFFFFFFFFFFF"  # All F's

    # Binary-like patterns
    "5555555555555555"  # Resembles binary 1's
    "AAAAAAAAAAAAAAAA"  # Resembles binary pattern
    "EEEEEEEEEEEEEEEE"  # Resembles binary 1's
    "F0F0F0F0F0F0F0F0"  # Alternating pattern
    "0F0F0F0F0F0F0F0F"  # Inverse alternating
    "FF00FF00FF00FF00"  # Double alternating
    "00FF00FF00FF00FF"  # Inverse double alternating
    "FFF000FFF000FFF0"  # Triple alternating
    "000FFF000FFF000F"  # Inverse triple
    "FFFF0000FFFF0000"  # Quad alternating
    
    # Perfect sequences
    "0123456789ABCDEF"  # Perfect ascending
    "FEDCBA9876543210"  # Perfect descending
    "0246813579BDEF00"  # Even-odd ascending
    "FBED9C7531402468"  # Even-odd descending
    "0123456712345678"  # Double sequence
    "FEDCBA98FEDCBA98"  # Double reverse
    
    # Alternating patterns
    "AAAAFFFFAAAAFFFF"  # Alternating A/F
    "BBBBEEEEBBBBEEEE"  # Alternating B/E
    "CCCCDDDDCCCCDDDD"  # Alternating C/D
    "A5A5A5A5A5A5A5A5"  # Repeating A5
    "B4B4B4B4B4B4B4B4"  # Repeating B4
    "C3C3C3C3C3C3C3C3"  # Repeating C3
    "D2D2D2D2D2D2D2D2"  # Repeating D2
    "E1E1E1E1E1E1E1E1"  # Repeating E1
    "F0F0F0F0F0F0F0F0"  # Repeating F0
    
    # Palindromes
    "ABCDEF0123456789"  # Sequence
    "0123456789ABCDEF"  # Alt sequence
    "FEDCBA9876543210"  # Reverse sequence
    "ABCCBAFFBBCCBAFF"  # Palindrome pattern
    "A00AA00BB00AA00B"  # Repeating palindrome
    "0123456654321000"  # Numeric palindrome
    
    # Hexspeak stories (super rare finds!)
    "C0FFEEBADBEEFCAFE"  # Coffee bad beef cafe
    "DEFACEDBADC0FFEE"   # Defaced bad coffee
    "B1GB055DEADC0DE5"   # Big boss dead codes
    "BADC0DEDEADBEEF5"   # Bad code dead beefs
    "FEEDC0DEFEEDDEAD"   # Feed code feed dead
    "C0DEB100DC0FFEE5"   # Code blood coffees
    "DEADDAD5BADBABE5"   # Dead dads bad babes
    "FADEFACEFEEDFACE"   # Fade face feed face
    "B16B055FEEDC0DE5"   # Big boss feed codes
    "CAFEBABEDEADBEEF"   # Cafe babe dead beef
    "1337C0DEB16B0055"   # Leet code big boss
    "BADB100DBADC0DE5"   # Bad blood bad codes
    "DEADC0DEDEADBABE"   # Dead code dead babe
    "B0555FEEDDEADACE"   # Boss feed dead ace
    "5ECEBB55DEADFACE"   # Sece boss dead face
    "C001CAFEC0DEB055"   # Cool cafe code boss
    "DEADC0DEBAADCAFE"   # Dead code bad cafe
    "1337DEADBEEFC0DE"   # Leet dead beef code
    "C0FFEEBABEDEADEE"   # Coffee babe dead ee
    "BEEFCAFEDEADFACE"   # Beef cafe dead face
    "C0DED0C5FEEDFACE"   # Code docs feed face
    "DEADDEEDBADC0DE5"   # Dead deed bad codes
    "FACE1E55DEADFACE"   # Faceless dead face
    "BAADC0DEB16B055"    # Bad code big boss
    "FEEDFACADEADBEEF"   # Feed faca dead beef
    "5AFEACCE55C0DE5"    # Safe access codes
    "B16B0551337C0DE"    # Big boss leet code
    "DEADBEEFFACE1337"   # Dead beef face leet
    "C0FFEE1NBADC0DE"    # Coffee in bad code
    "5ECEB055DEADBEE5"   # Sece boss dead bees
    
    # Wave patterns
    "0123456789ABCDEF"   # Rising
    "FEDCBA9876543210"   # Falling
    "0246813579BDEF00"   # Rising skip
    "FF00FF00FF00FF00"   # Square wave
    "F0F0F0F0F0F0F0F0"   # Fast square
    "123456789ABCDEF0"   # Shifted rise
    
    # Geometric patterns
    "F000F000F000F000"   # Blocks
    "FF00FF00FF00FF00"   # Double blocks
    "FFF0FFF0FFF0FFF0"   # Triple blocks
    "FFFF0000FFFF0000"   # Quad blocks
    "F0F0F0F0F0F0F0F0"   # Checkerboard
    "F00FF00FF00FF00F"   # Alternating blocks
    "FF0000FFFF0000FF"   # Double alternating
    
    # Repeated byte patterns
    "DEADDEADDEADDEAD"   # Quad DEAD
    "BEEFBEEFBEEFBEEF"   # Quad BEEF
    "CAFECAFECAFECAFE"   # Quad CAFE
    "FACEFACEFACEFACE"   # Quad FACE
    "BABEBABEBABESABE"   # Quad BABE
    "FEEDFEEDFEEDFEED"   # Quad FEED
    "C0DEC0DEC0DEC0DE"   # Quad CODE
    "B055B055B055B055"   # Quad BOSS
    
    # Counting patterns
    "0123456789ABCDEF"   # Full hex count
    "0000111122223333"   # Grouped count
    "0001001200230034"   # Incremental count
    "000102030405060F"   # Sequential with F
    "0123012301230123"   # Repeated count
    
    # Special meaning patterns
    "DEFEC7EDACCE55ED"   # Defected accessed
    "B0BB1E55D15EA5ED"   # Bobbles diseased
    "C0FFEEBEEFDEADEE"   # Coffee beef dead ee
    "FEEDC0DE5DEADACE"   # Feed codes dead ace
    "BA5EBA11C0DEB055"   # Baseball code boss
    "DECEA5EDDEADBABE"   # Deceased dead babe
    "ACC01ADEDECE17ED"   # Accolade deceited
    "FADE1E55DEADFACE"   # Fadeless dead face
    "FEEDFACEFEEDC0DE"  # Feed face feed code
    "C0FFEEBADBEEFCAFE" # Coffee bad beef cafe
    "DEFACEDBADC0FFEE"  # Defaced bad coffee
    "DECEA5EDDEADFACE"  # Deceased dead face
    "B1GB055DEADC0DE5"  # Big boss dead codes
    "BADC0DEDEADBEEF5"  # Bad code dead beefs
    "FEEDC0DEFEEDDEAD"  # Feed code feed dead
    "C0DEB100DC0FFEE5"  # Code blood coffees
    "DEADDAD5BADBABE5"  # Dead dads bad babes
    "FADEFACEFEEDFACE"  # Fade face feed face
    "B16B055FEEDC0DE5"  # Big boss feed codes
    "CAFEBABEDEADBEEF"  # Cafe babe dead beef
    "1337C0DEB16B0055"  # Leet code big boss
    "BADB100DBADC0DE5"  # Bad blood bad codes
    "DEADC0DEDEADBABE"  # Dead code dead babe
    "B0555FEEDDEADACE"  # Boss feed dead ace
    "5ECEBB55DEADFACE"  # Sece boss dead face
    "C001CAFEC0DEB055"  # Cool cafe code boss
    "AAAAAAAAAAAAAAAA"  # All A's (maximum rarity)
    "FFFFFFFFFFFFFFFF"  # All F's (maximum rarity)
    "ABCDEF0123456789"  # Perfect sequence
    "FEDCBA9876543210"  # Reverse sequence
    "0123456789ABCDEF"  # Ascending sequence
    "AAAAFFFFAAAAFFFF"  # Alternating pattern
    "DEADC0DEBAADCAFE"  # Dead code bad cafe
    "B1GB055FEEDC0DE5"  # Big boss feed codes
    "1337DEADBEEFC0DE"  # Leet dead beef code
    "C0FFEEBABEDEADEE"  # Coffee babe dead ee

# Special meanings
    "C0FFEE00"     # Coffee
    "BADC0DE5"     # Bad codes
    "DEADFACE"     # Dead face
    "FEEDC0DE"     # Feed code
    "1CEDEADE"     # Iced eade
    "B1GBAD00"     # Big bad
    
    # Palindromes
    "A00DD00A"     # Palindrome
    "B33DD33B"     # Palindrome
    "ABCCBA00"     # Palindrome with 00
    "12344321"     # Numeric palindrome
    
    # Binary references
    "B1NAB1E5"     # Binaries
    "B00B00B5"     # Boo boobs
    "DEADDEAD"     # Dead dead
    "FEEDFEED"     # Feed feed
    "BAADBAAD"     # Baad baad
    
    # Hexadecimal word play
    "ACCE55ED"     # Accessed
    "DECEA5ED"     # Deceased
    "EFFEC7ED"     # Effected
    "DEFEA7ED"     # Defeated
    "B0BBC4T5"     # Bobcats
    "C0FFEE5"      # Coffees
)

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
    # Create a patterns string for the worker script
    local patterns_str=$(printf "'%s' " "${PATTERNS[@]}")
    
    cat > "$TEMP_DIR/worker.sh" << EOF
#!/bin/bash

# Arguments
START=\$1        # Starting number
END=\$2          # Ending number
NAME=\$3         # Name for key
EMAIL=\$4        # Email for key
EXPORT_DIR=\$5   # Final export directory
PROGRESS_FILE=\$6

# Define patterns array
PATTERNS=($patterns_str)

generate_key() {
    local i=\$1
    local random_str=\$(openssl rand -hex 4)
    local gpg_home="/tmp/gpg_\${i}_\${random_str}"
    
    # Setup GPG environment
    export GNUPGHOME="\$gpg_home"
    mkdir -p "\$GNUPGHOME"
    chmod 700 "\$GNUPGHOME"

    # Generate key
    gpg --batch --generate-key <<INNEREOF 2>/dev/null
Key-Type: EDDSA
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ECDH
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: \$NAME
Name-Email: \$EMAIL
Expire-Date: 0
%no-protection
%commit
INNEREOF

    # Get key ID and convert to uppercase
    local key_id=\$(gpg --with-colons --list-keys --keyid-format LONG "\$EMAIL" 2>/dev/null | grep ^pub | cut -d: -f5)
    key_id_upper=\$(echo "\$key_id" | tr '[:lower:]' '[:upper:]')

    # Convert to hex for pattern matching
    local hex_id=\$(printf '%X' 0x\${key_id_upper} 2>/dev/null)
    
    # Check for all defined patterns
    for pattern in "\${PATTERNS[@]}"; do
        if [[ \$hex_id =~ ^\$pattern ]]; then
            gpg --armor --export "\$EMAIL" > "\$EXPORT_DIR/public_key_\${i}.asc" 2>/dev/null
            gpg --armor --export-secret-keys "\$EMAIL" > "\$EXPORT_DIR/private_key_\${i}.asc" 2>/dev/null
            echo "[\$i] \$key_id (0x\$hex_id) - Matched pattern: \$pattern" >> "\$EXPORT_DIR/found_keys.txt"
            echo "Found key with ID: \$hex_id (Pattern: \$pattern)"
            break
        fi
    done

    # Cleanup
    rm -rf "\$gpg_home"

    # Update progress atomically
    (
        while ! ln "\$PROGRESS_FILE" "\$PROGRESS_FILE.lock" 2>/dev/null; do
            sleep 0.1
        done
        local current=\$(cat "\$PROGRESS_FILE")
        echo \$((current + 1)) > "\$PROGRESS_FILE"
        rm -f "\$PROGRESS_FILE.lock"
    ) 2>/dev/null
}

# Process range of numbers
for i in \$(seq \$START \$END); do
    generate_key \$i
done
EOF

    chmod +x "$TEMP_DIR/worker.sh"
}

show_results() {
    echo -e "\nFound special keys:"
    if [ -f "$EXPORT_DIR/found_keys.txt" ]; then
        cat "$EXPORT_DIR/found_keys.txt"
        echo -e "\nTotal found: $(wc -l < "$EXPORT_DIR/found_keys.txt")"
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
    echo "Searching for the following patterns:"
    printf '%s\n' "${PATTERNS[@]}" | sed 's/^/  - 0x/'
    echo
    
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

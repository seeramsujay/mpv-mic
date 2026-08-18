#!/usr/bin/env bash

# Enable strict mode for safety
set -Eeuo pipefail

# Global variables for state tracking
STARTED_LOOPBACK=false
LOOPBACK_PID=""
MPV_PID=""
declare -a FILES=()
declare -a PLAYLIST=()

# Structured logging functions
log_info() {
    echo -e "\e[1;34m[i]\e[0m $*"
}

log_success() {
    echo -e "\e[1;32m[✓]\e[0m $*"
}

log_warn() {
    echo -e "\e[1;33m[!]\e[0m $*"
}

log_error() {
    echo -e "\e[1;31m[ERROR]\e[0m $*" >&2
}

# Cleanup resources on exit or interruption
cleanup() {
    # Disable trap to prevent infinite recursion
    trap - SIGINT SIGTERM EXIT
    
    # Restore cursor
    printf "\e[?25h"
    
    echo -e "\n\n\e[1;33m[!] Shutting down and cleaning up resources...\e[0m"
    
    # Terminate mpv if running
    if [[ -n "${MPV_PID:-}" ]]; then
        if kill -0 "$MPV_PID" 2>/dev/null; then
            log_info "Stopping audio playback (PID: $MPV_PID)..."
            kill "$MPV_PID" 2>/dev/null || true
            wait "$MPV_PID" 2>/dev/null || true
        fi
    fi
    
    # Remove virtual microphone if we created it
    if [[ "$STARTED_LOOPBACK" == "true" ]] && [[ -n "${LOOPBACK_PID:-}" ]]; then
        if kill -0 "$LOOPBACK_PID" 2>/dev/null; then
            log_info "Removing virtual microphone device (PID: $LOOPBACK_PID)..."
            kill "$LOOPBACK_PID" 2>/dev/null || true
            wait "$LOOPBACK_PID" 2>/dev/null || true
        fi
    fi
    
    log_success "Cleanup complete. Exiting."
    exit 0
}

# Register traps
trap cleanup SIGINT SIGTERM EXIT

# Render script header
print_header() {
    clear
    echo -e "\e[1;36m┌────────────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[1;36m│             🎙️  PIPEWIRE VIRTUAL MICROPHONE             │\e[0m"
    echo -e "\e[1;36m└────────────────────────────────────────────────────────┘\e[0m"
    echo ""
}

# Verify CLI dependencies are present
check_dependencies() {
    local -a missing=()
    for cmd in pw-loopback mpv pactl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if (( ${#missing[@]} > 0 )); then
        log_error "Missing required CLI dependencies: ${missing[*]}"
        log_warn "Please install them first using your package manager."
        log_warn "Example: sudo apt install pipewire-utils mpv pulseaudio-utils"
        exit 1
    fi
}

# Verify active audio daemon
check_audio_server() {
    if ! pactl info &>/dev/null; then
        log_error "PipeWire/PulseAudio sound daemon is not running or accessible."
        log_warn "Please make sure your sound server is active."
        exit 1
    fi
}

# Create virtual loopback source/sink
initialize_virtual_mic() {
    log_info "Checking virtual audio status..."
    if pactl list sinks short | grep -q "Virtual_Mic_Sink"; then
        log_success "Virtual Microphone Sink 'Virtual_Mic_Sink' is already active."
        log_info "Reusing the existing loopback device."
        STARTED_LOOPBACK=false
    else
        log_info "Creating PipeWire Virtual Microphone..."
        # Capture props forms the sink where mpv sends audio
        # Playback props forms the virtual microphone source apps read from
        pw-loopback \
            --capture-props='media.class="Audio/Sink" node.name="Virtual_Mic_Sink" node.description="Virtual Mic (MPV)"' \
            --playback-props='media.class="Audio/Source" node.name="Virtual_Mic_Source" node.description="Virtual Microphone"' >/dev/null 2>&1 &
        LOOPBACK_PID=$!
        STARTED_LOOPBACK=true
        
        # Allow PipeWire to register nodes
        sleep 1
        
        # Verify the process is still running
        if ! kill -0 "$LOOPBACK_PID" 2>/dev/null; then
            log_error "Failed to start pw-loopback process."
            exit 1
        fi
        log_success "Virtual Microphone created successfully (PID: $LOOPBACK_PID)."
    fi
    
    echo ""
    echo -e "\e[1;36m┌────────────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[1;36m│\e[0m  🎙️  \e[1;32mVirtual Microphone Initialized!\e[0m                   \e[1;36m│\e[0m"
    echo -e "\e[1;36m│\e[0m                                                         \e[1;36m│\e[0m"
    echo -e "\e[1;36m│\e[0m  ⚙️  Virtual Sink:    Virtual_Mic_Sink                    \e[1;36m│\e[0m"
    echo -e "\e[1;36m│\e[0m  🔊  Virtual Source:  Virtual Microphone                  \e[1;36m│\e[0m"
    echo -e "\e[1;36m│\e[0m                                                         \e[1;36m│\e[0m"
    echo -e "\e[1;36m│\e[0m  👉  In Discord, Zoom, OBS, etc., select:               \e[1;36m│\e[0m"
    echo -e "\e[1;36m│\e[0m      \e[1;33m'Virtual Microphone'\e[0m as your input device.          \e[1;36m│\e[0m"
    echo -e "\e[1;36m└────────────────────────────────────────────────────────┘\e[0m"
    echo ""
}

# Scan current directory for media files
scan_files() {
    log_info "Scanning current directory for audio/video files..."
    
    # Support various formats
    mapfile -t FILES < <(find . -maxdepth 1 -type f \( \
        -iname "*.mp3" -o \
        -iname "*.wav" -o \
        -iname "*.flac" -o \
        -iname "*.m4a" -o \
        -iname "*.ogg" -o \
        -iname "*.opus" -o \
        -iname "*.mp4" -o \
        -iname "*.mkv" -o \
        -iname "*.webm" -o \
        -iname "*.aac" \
    \) | sort) || true
    
    if (( ${#FILES[@]} == 0 )); then
        log_error "No audio or video files found in the current directory."
        log_warn "Drop some media files (.mp3, .wav, etc.) here and rerun the script."
        exit 1
    fi
}

# Helper to truncate string with ellipses
truncate_string() {
    local -r str="$1"
    local -r max_len="$2"
    if (( ${#str} > max_len )); then
        echo "${str:0:max_len-3}..."
    else
        echo "$str"
    fi
}

# Helper to calculate human-readable file sizes without external deps
format_size() {
    local -r bytes="$1"
    if (( bytes < 1024 )); then
        echo "${bytes} B"
    elif (( bytes < 1048576 )); then
        echo "$(( bytes / 1024 )) KB"
    else
        echo "$(( bytes / 1048576 )) MB"
    fi
}

# Helper to get file size
get_file_size() {
    local -r file="$1"
    if [[ -f "$file" ]]; then
        stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# Render file list in a neat table format
display_files() {
    echo -e "\e[1;36m┌─────┬──────────────────────────────────────────┬──────────┬──────┐\e[0m"
    echo -e "\e[1;36m│  #  │ Filename                                 │ Size     │ Type │\e[0m"
    echo -e "\e[1;36m├─────┼──────────────────────────────────────────┼──────────┼──────┤\e[0m"
    
    for i in "${!FILES[@]}"; do
        local file="${FILES[$i]}"
        local name="${file#./}"
        local truncated_name
        truncated_name=$(truncate_string "$name" 40)
        
        local size_bytes
        size_bytes=$(get_file_size "$file")
        local size_str
        size_str=$(format_size "$size_bytes")
        
        local ext="${file##*.}"
        local ext_upper="${ext^^}"
        
        local type_color="\e[37m"
        case "$ext_upper" in
            MP3|WAV|FLAC|M4A|OGG|OPUS|AAC)
                type_color="\e[1;36m" # Bold Cyan for Audio
                ;;
            MP4|MKV|WEBM)
                type_color="\e[1;35m" # Bold Magenta for Video
                ;;
        esac
        
        printf "\e[1;36m│\e[0m %3d \e[1;36m│\e[0m %-40s \e[1;36m│\e[0m %-8s \e[1;36m│\e[0m ${type_color}%-4s\e[0m \e[1;36m│\e[0m\n" \
            "$((i+1))" "$truncated_name" "$size_str" "$ext_upper"
    done
    
    echo -e "\e[1;36m└─────┴──────────────────────────────────────────┴──────────┴──────┘\e[0m"
}

# Parse selected indices from user input
parse_selection() {
    local -r selection="$1"
    local -r file_count="$2"
    local -a indices=()
    
    if [[ "${selection,,}" == "all" ]]; then
        for ((i=1; i<=file_count; i++)); do
            indices+=("$((i-1))")
        done
        echo "${indices[@]}"
        return 0
    fi
    
    # Clean commas and semicolons
    local cleaned="${selection//,/ }"
    cleaned="${cleaned//;/ }"
    
    # Word split cleaned string to parse tokens
    for token in $cleaned; do
        if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            if (( start >= 1 && start <= file_count && end >= 1 && end <= file_count )); then
                if (( start <= end )); then
                    for ((i=start; i<=end; i++)); do
                        indices+=("$((i-1))")
                    done
                else
                    for ((i=start; i>=end; i--)); do
                        indices+=("$((i-1))")
                    done
                fi
            else
                log_warn "Range $token contains out-of-bounds index (valid: 1-$file_count)" >&2
            fi
        elif [[ "$token" =~ ^[0-9]+$ ]]; then
            local val="$token"
            if (( val >= 1 && val <= file_count )); then
                indices+=("$((val-1))")
            else
                log_warn "Index $val is out-of-bounds (valid: 1-$file_count)" >&2
            fi
        else
            log_warn "Ignoring invalid input token: '$token'" >&2
        fi
    done
    
    # Avoid unbound variable exit if array is empty
    if (( ${#indices[@]} > 0 )); then
        echo "${indices[@]}"
    fi
}

# Prompt user for selection
get_user_selection() {
    while true; do
        echo ""
        echo -e "Enter file numbers in the order you want to play them."
        echo -e "Supports space/comma separation, ranges (e.g. \e[1;33m1-3 5\e[0m), or '\e[1;33mall\e[0m':"
        
        # Turn off set -e temporarily to avoid exit if stdin gets closed
        set +e
        read -rp "Selection: " SELECTION
        local read_status=$?
        set -e
        
        if (( read_status != 0 )); then
            echo ""
            exit 0
        fi
        
        if [[ -z "${SELECTION:-}" ]]; then
            SELECTION="all"
        fi
        
        local -a playlist_indices=()
        # Parse user inputs to actual array index values
        playlist_indices=($(parse_selection "$SELECTION" "${#FILES[@]}"))
        
        PLAYLIST=()
        for idx in "${playlist_indices[@]:-}"; do
            if [[ -n "${idx:-}" ]]; then
                PLAYLIST+=("${FILES[$idx]}")
            fi
        done
        
        if (( ${#PLAYLIST[@]} > 0 )); then
            break
        else
            log_error "No valid files selected. Please try again."
        fi
    done
}

# Render selected queue
display_selected_queue() {
    print_header
    echo -e "\e[1;32m[✓] Playback Queue Configured:\e[0m"
    echo -e "\e[1;36m┌────────────────────────────────────────────────────────┐\e[0m"
    for i in "${!PLAYLIST[@]}"; do
        local file="${PLAYLIST[$i]}"
        local name="${file#./}"
        local truncated
        truncated=$(truncate_string "$name" 50)
        printf "\e[1;36m│\e[0m  %2d. %-50s \e[1;36m│\e[0m\n" "$((i+1))" "$truncated"
    done
    echo -e "\e[1;36m└────────────────────────────────────────────────────────┘\e[0m"
    echo ""
}

# Wait for trigger key
wait_for_trigger() {
    log_info "Stream is ready."
    echo -e "Press \e[1;33m[ENTER]\e[0m (or press F7 then [ENTER]) to start streaming to the Virtual Mic..."
    
    set +e
    read -r
    set -e
}

# Play queue using mpv
play_queue() {
    echo -e "\n\e[1;32m[▶] Streaming audio to the Virtual Microphone...\e[0m"
    log_warn "Press Ctrl+C at any time to stop and clean up."
    echo -e "\e[1;36m--------------------------------------------------\e[0m"
    
    # Hide cursor for clean playback display
    printf "\e[?25l"
    
    # Play files via mpv
    mpv --no-video \
        --no-config \
        --audio-device=pulse/Virtual_Mic_Sink \
        --term-status-msg=$'\r\e[1;32m[▶]\e[0m \e[1;36m${filename}\e[0m \e[1;33m[${time-pos}/${duration}]\e[0m (${percent-pos}%)' \
        "${PLAYLIST[@]}" &
    MPV_PID=$!
    
    # Wait for background mpv playback to complete
    wait "$MPV_PID"
}

# Main Execution Flow
main() {
    print_header
    check_dependencies
    check_audio_server
    initialize_virtual_mic
    scan_files
    display_files
    get_user_selection
    display_selected_queue
    wait_for_trigger
    play_queue
}

# Invoke main
main
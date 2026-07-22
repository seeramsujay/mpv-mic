#!/usr/bin/env bash

# Setup cleanup function to destroy virtual mic and stop processes on exit
cleanup() {
    echo -e "\n\e[33m[!] Cleaning up virtual audio devices and stopping playback...\e[0m"
    if [ -n "$LOOPBACK_PID" ]; then
        kill "$LOOPBACK_PID" 2>/dev/null
    fi
    if [ -n "$MPV_PID" ]; then
        kill "$MPV_PID" 2>/dev/null
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

clear
echo "=================================================="
echo "    Lightweight PipeWire Soundboard / Mic Injector"
echo "=================================================="
echo ""

# 1. Create a Virtual Microphone Source via pw-loopback
echo "[+] Initializing PipeWire Virtual Microphone..."
# pw-loopback creates a virtual sink that acts as an input source (microphone)
pw-loopback --capture-props='media.class="Audio/Sink" node.name="Virtual_Mic_Sink" node.description="Virtual Mic (MPV)"' \
            --playback-props='media.class="Audio/Source" node.name="Virtual_Mic_Source" node.description="Virtual Microphone"' > /dev/null 2>&1 &
LOOPBACK_PID=$!

sleep 1 # Brief pause to allow PipeWire to register nodes

echo -e "\e[32m[✓] Virtual Microphone Created Successfully!\e[0m"
echo -e "--> Select \e[1;36m'Virtual Microphone'\e[0m as your input device in Discord, Zoom, OBS, etc.\n"

# 2. Find audio/video files in current directory
IFS=$'\n' read -rd '' -a FILES < <(find . -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.ogg" -o -name "*.flac" -o -name "*.m4a" -o -name "*.mkv" -o -name "*.mp4" \) | sort && printf '\0')

if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "\e[31m[-] No audio/video files found in current directory.\e[0m"
    exit 1
fi

echo "Available media files in current directory:"
for i in "${!FILES[@]}"; do
    printf "  [%2d] %s\n" "$((i+1))" "${FILES[$i]#./}"
done

echo ""
echo "--------------------------------------------------"
echo "Enter file numbers in the order you want to play them"
echo "Separated by spaces (e.g., 3 1 2) or 'all' for sequential order:"
read -rp "Selection: " SELECTION

PLAYLIST=()
if [[ "$SELECTION" == "all" ]]; then
    PLAYLIST=("${FILES[@]}")
else
    for num in $SELECTION; do
        idx=$((num - 1))
        if [ -n "${FILES[$idx]}" ]; then
            PLAYLIST+=("${FILES[$idx]}")
        fi
    done
fi

if [ ${#PLAYLIST[@]} -eq 0 ]; then
    echo -e "\e[31m[-] Invalid selection. Exiting...\e[0m"
    exit 1
fi

echo ""
echo "Selected Queue:"
for file in "${PLAYLIST[@]}"; do
    echo " -> ${file#./}"
done

# 3. Wait for start trigger
echo ""
echo "=================================================="
read -rp "Press [ENTER] (or F7 + Enter) to start playback..."

echo -e "\n\e[32m[>] Playing audio stream to Virtual Microphone...\e[0m"
echo "Press Ctrl+C at any time to stop and clean up."
echo "--------------------------------------------------"

# 4. Route mpv audio output directly to the Virtual Mic Sink via PipeWire/Pulse
mpv --no-video \
    --audio-device=pulse/Virtual_Mic_Sink \
    "${PLAYLIST[@]}" &
MPV_PID=$!

wait $MPV_PID
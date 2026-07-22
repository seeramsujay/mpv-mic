# PipeWire Virtual Microphone Soundboard (`mpv-mic`)

A lightweight, minimal Bash script that creates a virtual microphone using PipeWire/PulseAudio (`pw-loopback`) and streams selected local audio/video files into it using `mpv`. Perfect for injecting sound effects, music, or pre-recorded audio directly into applications like Discord, Zoom, OBS, Teams, and more.

## 🚀 Features

*   **Virtual Microphone Creation:** Automatically initializes a `pw-loopback` node creating a virtual sink (`Virtual_Mic_Sink`) and a virtual source (`Virtual Microphone`).
*   **Intuitive Playlist Queue:** Scans the current directory for common audio/video formats, formats them into a sleek dashboard, and lets you queue them in any custom order (including ranges like `1-3` or `all`).
*   **Playback Hotkeys:** Since it runs with `mpv`, you can interact with playback in real-time using standard `mpv` keybindings (Space to pause, arrow keys to seek, etc.).
*   **Clean Exit & Auto-Cleanup:** Automatically traps termination signals (`Ctrl+C`, `SIGTERM`, etc.) to clean up the virtual devices and close any background processes.

## 🛠️ Prerequisites

Make sure you have the following packages installed on your Linux system:

```bash
# On Debian/Ubuntu/Mint:
sudo apt install pipewire pipewire-audio-client-libraries pipewire-utils pulseaudio-utils mpv

# On Arch Linux:
sudo pacman -S pipewire pipewire-pulse mpv
```

Ensure your PipeWire sound server is running and active:
```bash
pactl info
```

## 💻 Usage

1.  **Clone or place the script** in the directory containing the audio/video files you want to stream.
2.  **Make the script executable:**
    ```bash
    chmod +x mpv-mic.sh
    ```
3.  **Run the script:**
    ```bash
    ./mpv-mic.sh
    ```
4.  **Set Up Your App:** Open your voice application (e.g., Discord, Zoom, OBS) and set the **Input Device / Microphone** to **"Virtual Microphone"**.
5.  **Queue Playback:**
    *   Select specific files by entering their numbers separated by spaces or commas (e.g., `1 3 5` or `1,3,5`).
    *   Enter a range of files (e.g., `1-4`).
    *   Type `all` to play all discovered files sequentially.
6.  **Start & Control Playback:**
    *   Press `[ENTER]` to start the playback.
    *   While playing, you can use the standard terminal controls of `mpv` (e.g. `[Space]` to pause/resume).
    *   Press `[Ctrl+C]` at any time to stop playback and cleanly remove the virtual microphone.

## ⚙️ Configuration Properties

*   **Virtual Sink Name:** `Virtual_Mic_Sink`
*   **Virtual Source Description:** `Virtual Microphone` (this is what you select in your settings)
*   **Supported File Types:** `.mp3`, `.wav`, `.flac`, `.m4a`, `.ogg`, `.opus`, `.aac`, `.mp4`, `.mkv`, `.webm`

## 📝 License

MIT License. Feel free to customize and share!

# mpv-mic: Future Roadmap & Architectural Evolution

mpv-mic enables instant virtual microphone audio loopback injection on Linux using PipeWire and mpv. This document specifies future features and technical enhancements.

---

## 1. Real-Time Physical Mic Mixing & Ducking

- **Hardware Mic Pass-Through Bus**:
  - Automatically bridge the physical microphone input with the virtual sink using PipeWire filter-chain nodes.
  - Enable auto-ducking: dynamically lower playback volume by 12dB whenever speech is detected on the physical microphone.
- **Push-to-Mute / Push-to-Inject Hotkeys**:
  - Global hotkey listener (via `evdev` or Wayland global shortcut protocols) allowing instant soundboard triggering without focusing the terminal window.

---

## 2. Audio Processing & DSP Filtering

- **RNNoise Deep Learning Noise Suppression**:
  - Chain an on-the-fly RNNoise neural filter into the PipeWire loopback sink to remove ambient background hiss and room reverb from played clips.
- **Loudness Normalization (EBU R128)**:
  - Automatically analyze and normalize incoming sound clips to $-16\text{ LUFS}$ to prevent sudden ear-piercing volume spikes.

---

## 3. Graphical Interface & Soundboard Matrix

- **TUI / Web Soundboard Matrix**:
  - An optional curses or micro-web soundboard layout displaying a grid of sound buttons mapped to number keys with visual waveform previews.

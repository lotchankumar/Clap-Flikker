# Clap Flikker 👏🔦

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**Clap Flikker** is a smart, interactive Flutter application designed to respond to your applause. By monitoring the surrounding audio environment, the app detects clap sounds to trigger the device's flashlight and provide a friendly voice response.

## ✨ Features

- **Real-time Clap Detection**: Advanced microphone stream analysis using RMS (Root Mean Square) to identify claps even in noisy environments.
- **Interactive Flashlight**: Automatically toggles the hardware torch upon detection.
- **Customizable Voice Response**: Set a personalized message that the app speaks back to you. Features high-quality Text-to-Speech (TTS) integration.
- **Persistent Settings**: Your custom speech phrase is securely saved using `shared_preferences`, so it's ready every time you open the app.
- **Visual Feedback**: Real-time status indicators and RMS levels displayed on the UI.
- **Robust Permissions**: Built-in handling for Microphone and Camera/Torch permissions.
- **Reliable Logic**: Features a smart debounce system and a 3-cycle response loop (Torch + Speech) to ensure the device is easily found in the dark.

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.10.0)
- [Dart SDK](https://dart.dev/get-started) (>= 3.0.0)
- A physical Android or iOS device (Flashlight and Microphone features may not work correctly on simulators/emulators).

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/clap_flikker.git
   cd clap_flikker
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## 🛠️ Built With

- **[record](https://pub.dev/packages/record)**: High-performance audio streaming.
- **[torch_light](https://pub.dev/packages/torch_light)**: Simple and efficient flashlight control.
- **[flutter_tts](https://pub.dev/packages/flutter_tts)**: Cross-platform text-to-speech synthesis.
- **[shared_preferences](https://pub.dev/packages/shared_preferences)**: Reliable local data persistence.
- **[permission_handler](https://pub.dev/packages/permission_handler)**: Seamless permission management.

## 🧠 How It Works

The app utilizes the `record` package to capture a raw PCM 16-bit audio stream at 16kHz. 

1. **Signal Processing**: It calculates the **RMS (Root Mean Square)** of the audio buffer to determine the energy level.
2. **Thresholding**: When the energy exceeds a predefined threshold (calibrated for claps), a trigger is fired.
3. **Response Cycle**: 
   - The device flashlight is enabled.
   - The app speaks a message via Text-to-Speech.
   - This process repeats 3 times over a 12-second window.
4. **Debouncing**: A 12-second debounce timer prevents the app from re-triggering while a response cycle is already in progress.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
Developed with ❤️ by [Lotchan](https://https://github.com/lotchankumar).

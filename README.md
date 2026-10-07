# 🌿 VanMitra-AI — वन मित्र AI

> **Gram Sabha Transparency & Forest Rights Platform** for ओझर (Ozhar) village, जव्हार, पालघर — Powered by AI

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)](https://firebase.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🏆 Hackathon Info

| | |
|---|---|
| **Team** | Gangs Of Kondhwa |
| **Track** | AI for Societal Good |
| **Pilot Village** | Ozhar, Jawhar Taluka, Palghar District, Maharashtra |

### 👥 Team Members

| Name | Role |
|------|------|
| Sanskruti Ruyarkar | Team Member |
| Ayush Sahare | Team Member |
| Piyush Dhane | Team Member |
| Samrudhhi Shinde | Team Member |
| Ishan Wankhede | Team Member |
| Kaushal Talekar | Team Member |
| Soham Patki | Team Member |

---

## 📖 Overview

**VanMitra-AI** is an AI-powered mobile application designed to assist tribal communities (specifically Warli and other scheduled tribes) in the Ozhar village of Jawhar, Palghar district to:

- ✅ Check **eligibility** for Forest Rights Act (FRA) claims
- 📄 **Generate legal drafts** for Form A / B / C claims
- 🔍 **Verify documents** using OCR + AI agents
- 🗣️ **Voice-to-text** claim filing in Hindi / Marathi
- ⚖️ **Analyze rejection orders** and generate appeal letters
- 📋 **Gram Sabha notice board** with real-time sync
- 🔒 **Offline-first** with Firebase cloud sync
- 🧑‍🤝‍🧑 **Face-recognition-based attendance** for Gram Sabha meetings

---

## 🏗️ Project Structure

```
VanMitra-AI/
├── android/                   # Android platform code
├── assets/
│   ├── ai_config/             # AI eligibility rules, evidence weights
│   ├── fonts/                 # NotoSansDevanagari fonts
│   ├── images/                # Sample images
│   └── ml/                    # FaceNet TFLite model
├── lib/                       # Flutter Dart source code
│   ├── config/                # App config & theme
│   ├── core/                  # Core utilities & services
│   ├── data/                  # Data layer (Hive, Firestore)
│   ├── models/                # Data models
│   ├── providers/             # Riverpod state providers
│   ├── screens/               # UI screens
│   │   ├── claims/            # FRA claim screens
│   │   ├── gram_sabha/        # Gram Sabha meeting screens
│   │   ├── home/              # Home dashboard
│   │   ├── onboarding/        # Onboarding & auth
│   │   ├── profile/           # User profile
│   │   └── splash/            # Splash screen
│   ├── services/              # Business logic services
│   ├── widgets/               # Reusable UI widgets
│   ├── app.dart               # Root app widget
│   ├── firebase_options.dart  # Firebase configuration
│   └── main.dart              # Entry point
├── vanmitra-backend/          # FastAPI Python AI backend
│   ├── app/
│   │   ├── agents.py          # 7-agent AI architecture
│   │   └── main.py            # FastAPI REST endpoints
│   ├── Dockerfile             # Docker container config
│   └── requirements.txt       # Python dependencies
├── files (1)/                 # Firebase rules & Cloud Functions
│   ├── firestore.rules        # Firestore security rules
│   ├── firestore.indexes.json # Firestore indexes
│   ├── index.js               # Cloud Functions
│   └── package.json           # Functions dependencies
├── convert_facenet.py         # FaceNet TFLite model converter
├── pubspec.yaml               # Flutter dependencies
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | ≥ 3.1.0 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart SDK | ≥ 3.1.0 | Bundled with Flutter |
| Android Studio | Latest | [developer.android.com](https://developer.android.com/studio) |
| Python | ≥ 3.11 | [python.org](https://python.org) |
| Docker (optional) | Latest | [docker.com](https://docker.com) |
| Firebase CLI | Latest | `npm install -g firebase-tools` |

---

## 📱 Flutter App Setup

### 1. Clone the repository

```bash
git clone https://github.com/AyushSahare964/VanMitra-AI.git
cd VanMitra-AI
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com) and create a project named `vanmitra-ai`.
2. Add an **Android app** with package name `com.vanmitra.vanmitra_ai`.
3. Download `google-services.json` and place it in `android/app/`.
4. Enable the following Firebase services:
   - **Authentication** (Phone / Anonymous)
   - **Cloud Firestore**
   - **Firebase Messaging** (FCM)
   - **Cloud Functions**

### 4. Configure the AI Backend URL

In `lib/config/` (or your environment config), set:

```dart
const String kApiBaseUrl = 'http://10.0.2.2:8000'; // Android emulator → localhost
// For physical device: use your machine's local IP e.g. http://192.168.1.x:8000
```

### 5. FaceNet TFLite Model

Generate the model before running:

```bash
# Install Python deps
pip install tensorflow

# Run the converter script
python convert_facenet.py
# Output: assets/ml/facenet.tflite
```

### 6. Run the Flutter App

```bash
# Check connected devices
flutter devices

# Run on Android emulator or connected device
flutter run

# Run in release mode
flutter run --release
```

---

## 🖥️ Backend (FastAPI) Setup

The AI backend implements a **7-agent architecture** for document processing, eligibility checking, and appeal generation.

### Option A: Run Locally (Python)

```bash
cd vanmitra-backend

# Create a virtual environment
python -m venv venv
source venv/bin/activate       # Linux/macOS
venv\Scripts\activate          # Windows

# Install dependencies
pip install -r requirements.txt

# Install Tesseract OCR (required for document verification)
# Ubuntu/Debian:
sudo apt-get install tesseract-ocr tesseract-ocr-mar tesseract-ocr-hin

# Windows: Download installer from https://github.com/UB-Mannheim/tesseract/wiki

# Run the development server
uvicorn app.main:app --reload --port 8000
```

The API will be available at: **http://localhost:8000**

Interactive Swagger docs: **http://localhost:8000/docs**

### Option B: Run with Docker

```bash
cd vanmitra-backend

# Build the image
docker build -t vanmitra-backend .

# Run the container
docker run -p 8000:8000 vanmitra-backend
```

> **Note for Android Emulator**: Use `http://10.0.2.2:8000` to reach the backend running on your host machine. For a physical device, use your machine's local IP address.

---

## 🤖 AI Agents Architecture

The backend uses an **OrchestratorAgent** coordinating 7 specialized agents:

| Agent | Role |
|-------|------|
| `IntakeAgent` | Validates and sanitizes claim input |
| `EligibilityAgent` | Checks FRA eligibility criteria (cutoff date: 13 Dec 2005) |
| `DocVerifyAgent` | OCR + fuzzy matching for document verification |
| `ScoringAgent` | Calculates evidence strength score |
| `DraftAgent` | Generates legal claim drafts (Form A/B/C) |
| `RejectionAgent` | Classifies rejection orders via NLP |
| `AppealAgent` | Generates appeal letters against rejections |

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/health` | Health check |
| `POST` | `/api/v1/eligibility-check` | Check FRA eligibility |
| `POST` | `/api/v1/verify-document` | Verify uploaded document (image) |
| `POST` | `/api/v1/generate-draft` | Generate Form A/B/C draft |
| `POST` | `/api/v1/transcribe` | Voice-to-text (OpenAI Whisper) |
| `POST` | `/api/v1/analyze-rejection` | OCR + analyze rejection order |
| `POST` | `/api/v1/generate-appeal` | Generate appeal letter |
| `GET` | `/api/v1/notices` | Get Gram Sabha notices |
| `POST` | `/api/v1/notices` | Post a new notice |

---

## 🔥 Firebase Cloud Functions Setup

```bash
cd "files (1)"

# Install Node.js dependencies
npm install

# Login to Firebase
firebase login

# Deploy Firestore rules and indexes
firebase deploy --only firestore

# Deploy Cloud Functions
firebase deploy --only functions
```

---

## 🛡️ Security & Environment Variables

> ⚠️ **IMPORTANT**: Never commit Firebase service account keys or API keys to version control.

The following files are listed in `.gitignore` and must be configured locally:
- `google-services.json` — Download from Firebase Console → Project Settings → Android app
- `vanmitra-ai-firebase-adminsdk-*.json` — Firebase Admin SDK service account key

For the Firebase Admin SDK credentials (used only for backend/admin tasks), store the JSON file **outside** the repository and reference it via environment variable:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
```

---

## 📦 Key Flutter Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `hive` + `hive_flutter` | Local offline storage |
| `firebase_core` + `cloud_firestore` | Firebase integration |
| `tflite_flutter` | On-device FaceNet inference |
| `google_mlkit_face_detection` | Face detection |
| `speech_to_text` | Native speech recognition (Hindi/Marathi) |
| `record` | Audio recording for consent capture |
| `flutter_map` + `latlong2` | OpenStreetMap integration |
| `pdf` + `printing` | PDF generation (Minutes of Meeting) |
| `google_mlkit_translation` | On-device translation (EN/HI/MR) |
| `camera` | Live camera for face detection |
| `geolocator` | GPS stamping for meetings |
| `fl_chart` | Evidence score charts |

---

## 🌐 Localization

The app supports:
- 🇮🇳 **Marathi** (`mr`) — Primary language
- 🇮🇳 **Hindi** (`hi`)
- 🇬🇧 **English** (`en`)

Font: **NotoSansDevanagari** for proper Devanagari script rendering.

---

## 🧪 Running Tests

```bash
# Flutter unit tests
flutter test

# Flutter integration tests (requires device/emulator)
flutter test integration_test/
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Ayush Sahare** — Hack4Humanity Hackathon  
Village Focus: Ozhar, Jawhar Tehsil, Palghar District, Maharashtra

---

> *"वनमित्र — जंगल का दोस्त, हक का साथी"*
> *"VanMitra — Friend of the Forest, Companion in Rights"*

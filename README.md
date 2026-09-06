# VoiceGuard

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev/) [![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/) [![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/) [![Status](https://img.shields.io/badge/Status-Prototype-orange?style=flat)](https://github.com/Botnikkk/voiceguard)

**AI-powered real-time detection and prevention of voice cloning impersonation attacks.**

VoiceGuard is a cross-platform Flutter app paired with a Python detection backend that judges whether a voice is human or AI-synthesized, live, and surfaces a risk score, a stability-checked verdict, and a one-tap escalation path — instead of leaving the user to figure out a deepfake call after the damage is done.

---

## 🌟 Overview

Voice cloning has gone from research curiosity to an active phishing vector — a cloned voice of a relative, a colleague, or a bank official is now cheap to generate and hard to distinguish by ear. Most existing deepfake-audio detectors are built for *offline* analysis of a pre-recorded clip. VoiceGuard targets the moment that actually matters: **while the call is happening, or on the recording right after.**

The app offers three ways to get audio into the detection pipeline, each with a different accuracy/practicality trade-off, and streams it to a FastAPI backend that runs a pretrained antispoofing model on a rolling window, returning an updated risk score roughly every 1.5 seconds — smoothed over time so the verdict doesn't flicker on a single noisy frame.

---

## ✨ Key Features

### 🎙️ Three Detection Modes

VoiceGuard doesn't assume one way of getting at call audio works everywhere, so it offers three, picked from a bottom-sheet action drawer on the dashboard:

| Mode | How it works | Accuracy |
|---|---|---|
| **Upload audio file** | Pick a `.wav`/`.mp3` file and stream it to the backend for analysis | Most accurate |
| **Intercept live call** | Pair two devices over WebRTC using a 6-digit room code — one side (Receiver) hosts the analysis, the other (Sender) streams audio to it | Moderately accurate |
| **Detect audio from mic** | Ambient, on-device mic listening with Silero VAD filtering speech from silence — no awareness of call state | Least accurate |

### 🔗 WebRTC Call Pairing

- **Room-code pairing, not LAN discovery.** Two devices join the same "room" on a signaling server and negotiate a WebRTC peer connection — this works between a phone and a browser tab, and across different networks, which the project's earlier LAN-broadcast device discovery could not do (and could never work in a browser at all).
- **Sender / Receiver roles.** The Receiver generates and displays a room code and waits for an offer; the Sender types in that code and streams a picked audio file at real-time pace over a WebRTC data channel as PCM16.
- **STUN-only ICE config** — fine for a normal home/office network demo; no TURN fallback yet for strict/symmetric NATs.

### 🧠 Detection Engine

- **Pretrained antispoofing model:** inference runs on a HuggingFace `antispoofing` pipeline (`DF_Arena_500M_V_1`, ~500M parameters) rather than a from-scratch classifier.
- **Temporal smoothing & hysteresis:** a rolling median over recent scores plus enter/exit thresholds and a stability-frame requirement stop the verdict from flip-flopping between "Human" and "AI Generated" on borderline audio.
- **Confidence rating:** each verdict ships with a High/Medium/Low confidence label derived from how far the score sits from the decision boundary and how stable recent readings have been.
- **Adjustable detection sensitivity** from the Settings screen, persisted locally.

### 📱 In-App Experience

- **Login screen** in front of the dashboard (currently a demo/mock auth flow — any non-empty ID and password succeeds — plus a working biometric unlock path via device Face ID/fingerprint/PIN).
- **Live risk gauge** bound to the smoothed, verdict-locked score.
- **Danger alert banner** that appears automatically once risk crosses 70%.
- **One-tap escalation** to a fraud team, with a confirmation sheet before anything is forwarded.
- **Offline-first call history:** every session is logged locally via Hive (risk score, verdict, duration) with a dashboard summarizing safe vs. flagged/escalated calls.
- **Biometric app lock** for the app itself, toggleable in Settings.
- **Web build:** ships as a Flutter web app too, auto-deployed to GitHub Pages on every push to `main`.

---

## 🛠️ How It Works

**Client (Flutter) — three input paths feeding one pipeline**

```
Upload:  Pick file → decode (WAV/MP3) → stream over WebSocket
Live:    Room code pairing → WebRTC data channel (PCM16) → forward into analysis socket
Mic:     Mic capture → Silero VAD (v5) → stream speech chunks over WebSocket
```

Whichever path is used, audio ends up as 16kHz mono PCM flowing into the same backend analysis socket.

**Backend (Python, FastAPI)**

```
Rolling buffer → Sliding-window extraction → Preprocess → Antispoofing model → Smoothing + hysteresis → Live JSON result
```

The backend maintains a per-connection audio buffer, runs inference as a non-blocking background task so the socket stays responsive, resamples/normalizes/pads audio to the model's expected input length, and returns `risk_score`, `smoothed_score`, `verdict`, and `confidence` after every window. It's reached over a dev `ngrok` tunnel (`ApiConfig`), not a production endpoint, and lives outside this repo.

**Signaling (for live-call pairing)**

A lightweight relay server handles room join/leave and forwards WebRTC offer/answer/ICE messages between the two paired devices — it never sees decoded audio, only the handshake.

---

## 🧰 Tech Stack & Architecture

**Mobile/web client**

- **Flutter (Dart)** — cross-platform UI (Android, iOS, web, and beyond)
- **Riverpod** — state management
- **flutter_webrtc** — peer-to-peer audio transport for the live-call mode
- **web_socket_channel** — signaling transport and streaming transport to the backend
- **vad** — on-device Silero VAD speech detection (mic-detection mode only)
- **file_picker + ffmpeg_kit_flutter_new** — picking and decoding uploaded audio files
- **local_auth** — biometric login/app lock
- **hive_flutter** — local, offline call-log storage
- **shared_preferences** — persisted settings (sensitivity, biometric toggle)
- **phone_state / permission_handler** — call-state awareness and runtime permissions

**Detection backend**

- **FastAPI** — async WebSocket server handling streaming sessions
- **PyTorch + Transformers** — inference runtime for the antispoofing pipeline
- **DF Arena 500M** (`Speech-Arena-2025/DF_Arena_500M_V_1`) — pretrained voice deepfake/spoof classifier
- **SciPy** — polyphase audio resampling
- **soundfile** — session audio capture for debugging/audit

---

## ⚠️ Current Prototype Limitations

Being upfront about what's real today vs. what's planned:

- **No true call-audio interception yet.** The "Intercept live call" mode requires two devices to voluntarily pair via a room code and stream audio between themselves over WebRTC — it doesn't tap into an actual phone call. Real interception needs platform permissions (e.g. `CAPTURE_AUDIO_OUTPUT` on Android) that need approval; the capture layer is isolated so swapping it in later won't require touching detection, streaming, or UI code.
- **Login is a demo flow.** Any non-empty user ID/password combination succeeds — there's no real backend authentication yet.
- **Dev-tunnel backend.** The client currently points at an `ngrok` tunnel for both the WebSocket detection connection and the signaling server. A production deployment would use stable hosted endpoints and add TURN servers for reliable WebRTC connectivity across restrictive networks.

---

## 🗺️ Roadmap

- [ ] Direct call-audio interception (pending platform permission approval)
- [ ] Production-hosted backend and signaling server (replacing the dev ngrok tunnel)
- [ ] Real authentication (replacing the demo login flow)
- [ ] TURN server support for WebRTC pairing across restrictive NATs
- [ ] Expanded language/accent coverage for the detection model
- [ ] iOS call-audio access path
- [ ] Configurable escalation destinations (beyond a single fraud-team endpoint)

---

## 🤔 Why VoiceGuard?

Voice-cloning scams work because the deception happens *in the moment* — by the time a recording can be analyzed after the fact, the money's already moved or the information's already been shared. VoiceGuard's whole design is built around that constraint: analyze while the call is live (or right after), keep the verdict stable enough to trust, and put the decision — stop, escalate, continue — in the user's hands in real time.
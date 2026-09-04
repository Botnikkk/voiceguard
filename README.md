# VoiceGuard

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev/) [![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/) [![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/) [![Status](https://img.shields.io/badge/Status-Prototype-orange?style=flat)](https://github.com/Botnikkk/voiceguard)

**AI-powered real-time detection and prevention of voice cloning impersonation attacks.**

VoiceGuard is a cross-platform Flutter app paired with a Python detection backend that listens to a live voice call and continuously judges whether the voice on the other end is human or AI-synthesized — surfacing a live risk score, a stability-checked verdict, and a one-tap escalation path, instead of leaving the user to figure out a deepfake call after the damage is done.

---

## 🌟 Overview

Voice cloning has gone from research curiosity to an active phishing vector — a cloned voice of a relative, a colleague, or a bank official is now cheap to generate and hard to distinguish by ear. Most existing deepfake-audio detectors are built for *offline* analysis of a pre-recorded clip. VoiceGuard is built for the moment that actually matters: **while the call is happening.**

Rather than waiting for a full recording, VoiceGuard streams audio in small chunks the instant speech is detected, runs a pretrained antispoofing model on a rolling window of that audio, and pushes an updated risk score back to the app roughly every 1.5 seconds — smoothing the result over time so the verdict doesn't flicker on a single noisy frame.

---

## ✨ Key Features

### 🎙️ Real-Time Detection
* **Streaming analysis, not batch upload:** audio is sent to the backend continuously while the user is speaking, and results start arriving within seconds — no waiting for the call to end.
* **Sliding-window inference:** a ~4-second window with a ~1.5-second hop keeps the risk score current throughout the call.
* **Client-side VAD:** Silero VAD (v5) filters out silence and background noise on-device before anything is streamed, so bandwidth and inference cycles aren't wasted on dead air.

### 🧠 Detection Engine
* **Pretrained antispoofing model:** inference runs on a HuggingFace `antispoofing` pipeline (`DF_Arena_500M_V_1`, ~500M parameters) rather than a from-scratch classifier — production-grade deepfake detection, integrated into a live streaming system.
* **Temporal smoothing & hysteresis:** a rolling median over recent scores plus enter/exit thresholds and a stability-frame requirement stop the verdict from flip-flopping between "Human" and "AI Generated" on borderline audio.
* **Confidence rating:** each verdict ships with a High/Medium/Low confidence label derived from how far the score sits from the decision boundary and how stable recent readings have been.

### 📱 In-App Experience
* **Live risk gauge** bound to the smoothed, verdict-locked score, updating continuously during the call.
* **Danger alert banner** that appears automatically once risk crosses 70%.
* **One-tap escalation** to a fraud team, with a confirmation sheet before anything is forwarded.
* **Offline-first call history:** every session is logged locally (risk score, verdict, duration) with a dashboard summarizing safe vs. flagged/escalated calls — no network dependency to view your own history.
* **Biometric app lock** for the app itself.

---

## 🛠️ How It Works

**Client (Flutter)**
```
Mic capture → Client-side VAD (Silero v5) → Stream speech chunks over WebSocket
```
Audio is captured at 16kHz mono PCM16 with echo cancellation, noise suppression, and auto-gain. Only VAD-confirmed speech is streamed; an end-of-utterance signal tells the backend when to run a final analysis pass.

**Backend (Python, FastAPI)**
```
Rolling buffer → Sliding-window extraction → Preprocess → Antispoofing model → Smoothing + hysteresis → Live JSON result
```
The backend maintains a per-connection audio buffer, runs inference as a non-blocking background task so the socket stays responsive, resamples/normalizes/pads audio to the model's expected input length, and returns `risk_score`, `smoothed_score`, `verdict`, and `confidence` after every window.

---

## 🧰 Tech Stack & Architecture

**Mobile client**
* **Flutter (Dart)** — cross-platform UI (Android, iOS, and beyond)
* **Riverpod** — state management
* **vad** — on-device Silero VAD speech detection
* **record** — low-level audio capture
* **web_socket_channel** — streaming transport to the backend
* **hive_flutter** — local, offline call-log storage
* **local_auth** — biometric app lock
* **phone_state / permission_handler** — call-state awareness and runtime permissions

**Detection backend**
* **FastAPI** — async WebSocket server handling streaming sessions
* **PyTorch + Transformers** — inference runtime for the antispoofing pipeline
* **DF Arena 500M** (`Speech-Arena-2025/DF_Arena_500M_V_1`) — pretrained voice deepfake/spoof classifier
* **SciPy** — polyphase audio resampling
* **soundfile** — session audio capture for debugging/audit

---

## ⚠️ Current Prototype Limitations

Being upfront about what's real today vs. what's planned:

* **No live call-audio interception yet.** Intercepting real call audio requires platform permissions (e.g. `CAPTURE_AUDIO_OUTPUT` on Android) that need approval. The current build demonstrates the full pipeline using **ambient mic capture** — one device listens to another device's call/output audio — as a stand-in for direct interception. The capture layer is isolated from the rest of the pipeline, so swapping it for real call-audio access won't require touching detection, streaming, or UI code.
* **Dev-tunnel backend.** The client currently points at an `ngrok` tunnel for the WebSocket connection. A production deployment would use a stable hosted endpoint.

---

## 🗺️ Roadmap

- [ ] Direct call-audio interception (pending platform permission approval)
- [ ] Production-hosted backend (replacing the dev ngrok tunnel)
- [ ] Expanded language/accent coverage for the detection model
- [ ] iOS call-audio access path
- [ ] Configurable escalation destinations (beyond a single fraud-team endpoint)

---

## 🤔 Why VoiceGuard?

Voice-cloning scams work because the deception happens *in the moment* — by the time a recording can be analyzed after the fact, the money's already moved or the information's already been shared. VoiceGuard's whole design is built around that constraint: analyze while the call is live, keep the verdict stable enough to trust, and put the decision (stop, escalate, continue) in the user's hands in real time rather than after the fact.
# Laptop Voice-Companion — Audio Evidence

Raw audio samples generated during the CPU TTS evaluation for Vixyz's
Dell EliteBook homelab companion (4 cores / 16 GB RAM / no GPU).

All inference timed on 4 pinned CPUs (`taskset -c 0-3`) to match the target laptop.

## Samples

| File | Engine | Notes |
|---|---|---|
| 01_pockettts_alba.mp3 | Pocket TTS (Kyutai) | built-in voice "alba" |
| 02_pockettts_anna.mp3 | Pocket TTS (Kyutai) | built-in voice "anna" |
| 03_pockettts_azelma.mp3 | Pocket TTS (Kyutai) | built-in voice "azelma" |
| 04_pockettts_cosette.mp3 | Pocket TTS (Kyutai) | built-in voice "cosette" |
| 05_pockettts_caro_davy.mp3 | Pocket TTS (Kyutai) | built-in voice "caro_davy" |
| 06_pockettts_eve.mp3 | Pocket TTS (Kyutai) | built-in voice "eve" |
| 07_piper_lessac.mp3 | Piper | en_US-lessac-medium baseline |
| 08_kokoro_af_heart.mp3 | Kokoro-82M | af_heart — highest-MOS candidate |
| 09_kokoro_af_bella.mp3 | Kokoro-82M | af_bella — "warm, husky" |
| 10_pockettts_server_endpoint.mp3 | Pocket TTS HTTP server | proof of `POST /tts` endpoint |

## Voice cloning gate (reproduced)

`voice_cloning_gate_error.txt` — the exact server error when requesting voice
cloning without accepting the gated HF weights. Built-in voices work with no auth;
cloning requires accepting terms at https://huggingface.co/kyutai/pocket-tts + local login.

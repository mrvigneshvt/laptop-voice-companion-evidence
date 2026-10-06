#!/usr/bin/env bash
# setup-azelma.sh — one-shot install of the azelma voice pipeline for Hermes.
# Run on the LAPTOP (the machine hosting Hermes). Idempotent-ish; safe to re-run.
#
#   bash setup-azelma.sh
#
set -euo pipefail

PORT="${POCKET_TTS_PORT:-8021}"
VOICE="${POCKET_TTS_VOICE:-azelma}"
VENV="$HOME/pocket-tts"
WRAP="$HOME/pocket-say.sh"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }

say "1/5  Python venv + Pocket TTS (CPU-only wheels)"
if [ ! -x "$VENV/bin/pocket-tts" ]; then
  uv venv "$VENV" --python 3.13
  # CPU index avoids pulling ~3 GB of CUDA runtime wheels
  uv pip install --python "$VENV/bin/python" pocket-tts \
      --extra-index-url https://download.pytorch.org/whl/cpu
  ok "installed into $VENV"
else
  ok "already present at $VENV"
fi

say "2/5  Wrapper script $WRAP"
cat > "$WRAP" <<'WRAPEOF'
#!/usr/bin/env bash
# pocket-say.sh — Hermes command TTS provider -> warm Pocket TTS server.
# Called by Hermes as: pocket-say.sh <input_text_file> <output_path> [voice]
set -euo pipefail
IN="${1:?usage: pocket-say.sh <input_file> <output_path> [voice]}"
OUT="${2:?usage: pocket-say.sh <input_file> <output_path> [voice]}"
VOICE="${3:-azelma}"
PORT="${POCKET_TTS_PORT:-8021}"
HOST="${POCKET_TTS_HOST:-127.0.0.1}"
exec curl -sS --fail --max-time 900 \
  -X POST "http://${HOST}:${PORT}/tts" \
  -F "text=<${IN}" \
  -F "voice_url=${VOICE}" \
  -o "${OUT}"
WRAPEOF
chmod +x "$WRAP"
ok "written and executable"

say "3/5  Autostart unit (systemd, user service)"
mkdir -p "$HOME/.config/systemd/user"
sed "s|/home/%u/pocket-tts|$VENV|g; s|--port 8021|--port $PORT|g; s|--default-voice azelma|--default-voice $VOICE|g" \
    "$(dirname "$0")/pocket-tts.service" > "$HOME/.config/systemd/user/pocket-tts.service"
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable --now pocket-tts.service
  # keep it alive when you are not logged in at the console
  loginctl enable-linger "$USER" 2>/dev/null || warn "could not enable-linger; run: sudo loginctl enable-linger $USER"
  sleep 3
  systemctl --user --no-pager status pocket-tts.service | head -6 || true
else
  warn "systemd not found — start manually: taskset -c 0-3 $VENV/bin/pocket-tts serve --host 127.0.0.1 --port $PORT --default-voice $VOICE"
fi

say "4/5  Point Hermes at it"
if command -v hermes >/dev/null 2>&1; then
  hermes config set tts.providers.pocket-tts.type command
  hermes config set tts.providers.pocket-tts.command "bash $WRAP {input_path} {output_path} {voice}"
  hermes config set tts.providers.pocket-tts.voice "$VOICE"
  hermes config set tts.providers.pocket-tts.output_format wav
  hermes config set tts.providers.pocket-tts.voice_compatible true
  hermes config set tts.providers.pocket-tts.timeout 900
  hermes config set tts.provider pocket-tts
  ok "6 config keys written"
else
  warn "hermes not on PATH — set the config keys manually (see the guide URL)"
fi

say "5/5  Verify end to end"
sleep 2
printf 'Az elma is installed and speaking through the warm server on this laptop.' > /tmp/azelma_check.txt
if curl -sf "http://127.0.0.1:$PORT/health" >/dev/null; then
  ok "server healthy on port $PORT"
else
  warn "server not answering on $PORT — check: journalctl --user -u pocket-tts -n 40"
fi
if bash "$WRAP" /tmp/azelma_check.txt /tmp/azelma_check.wav "$VOICE"; then
  BYTES=$(stat -c%s /tmp/azelma_check.wav 2>/dev/null || echo 0)
  ok "generated $BYTES bytes of audio -> /tmp/azelma_check.wav"
  warn "play it to confirm the voice: ffplay /tmp/azelma_check.wav   (or copy it to your phone)"
else
  warn "wrapper failed — is the server up? try: systemctl --user restart pocket-tts"
fi

cat <<'EOF'

--------------------------------------------------------------------
DONE. Final step is in your chat client, not the shell:

  Telegram :  send  /voice on     (voice-to-voice)
                     /voice tts    (always speak, stay in text)
                     /voice off    (silence this chat)

  Relay app:  tap the microphone button -> Voice Mode

If the Relay app speaks with the wrong voice, pin the route in
  Settings -> Voice -> Stable STT/TTS Route   ->  Vanilla Hermes
--------------------------------------------------------------------
EOF

#!/bin/bash
# utils/send-email-mailjet.sh - Send email via Mailjet API
# Usage:
#   As a sourced helper: send_email "Subject" "Message"
#   As CLI: ./send-email-mailjet.sh "Subject" "Message"

# === Load environment ===
source "$(dirname "${BASH_SOURCE[0]}")/load-env.sh"

# === send_email(subject, body) ===
send_email() {
  local subject="$1"
  local body="$2"

  if [[ -z "$subject" || -z "$body" ]]; then
    echo "❌ send_email usage: send_email \"Subject\" \"Message body\"" >&2
    return 1
  fi

  # Check required env vars
  : "${MAILJET_API_KEY:?MAILJET_API_KEY not set}"
  : "${MAILJET_API_SECRET:?MAILJET_API_SECRET not set}"
  : "${MAILJET_FROM:?MAILJET_FROM not set}"
  : "${MAILJET_TO:?MAILJET_TO not set}"

  curl -s --user "$MAILJET_API_KEY:$MAILJET_API_SECRET" \
    https://api.mailjet.com/v3.1/send \
    -H "Content-Type: application/json" \
    -d '{
      "Messages":[
        {
          "From": {
            "Email": "'"$MAILJET_FROM"'"
          },
          "To": [
            {
              "Email": "'"$MAILJET_TO"'"
            }
          ],
          "Subject": "'"$subject"'",
          "TextPart": "'"$body"'"
        }
      ]
    }'
}

# === Optional CLI fallback ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ -z "$1" || -z "$2" ]]; then
    echo "❌ Usage: $0 \"Subject\" \"Message body\"" >&2
    exit 1
  fi
  send_email "$1" "$2"
fi
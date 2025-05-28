#!/bin/bash
# utils/send-email-mailjet.sh - Send email via Mailjet API
# Usage: ./send-email-mailjet.sh "Subject Here" "Message body here"

# Load environment
source "$(dirname "${BASH_SOURCE[0]}")/load-env.sh"

# Check required env vars
: "${MAILJET_API_KEY:?MAILJET_API_KEY not set}"
: "${MAILJET_API_SECRET:?MAILJET_API_SECRET not set}"
: "${MAILJET_FROM:?MAILJET_FROM not set}"
: "${MAILJET_TO:?MAILJET_TO not set}"

SUBJECT="$1"
BODY="$2"

if [[ -z "$SUBJECT" || -z "$BODY" ]]; then
  echo "❌ Usage: $0 \"Subject\" \"Message body\""
  exit 1
fi

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
        "Subject": "'"$SUBJECT"'",
        "TextPart": "'"$BODY"'"
      }
    ]
  }' | jq .
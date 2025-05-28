Great — let’s begin by setting up a CLI-based Mailjet email sender so your server can notify you of backup failures and other warnings.

---

## ✅ Step 1: Setup a Mailjet CLI Email Sender

### Requirements:

* A Mailjet account (free level is fine)
* Your Mailjet API key and secret

---

### 🔧 Option: Use a Curl-based Shell Script

We'll create a simple shell script that uses `curl` to send emails via Mailjet's API.

#### 1. **Create `send-mailjet.sh` in your `utils/` directory**

```bash
#!/bin/bash
# utils/send-mailjet.sh - Send email via Mailjet API
# Usage: ./send-email-mailjet.sh "Subject Here" "Message body here"

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/utils/load-env.sh"

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
```

#### 2. **Add these variables to your `.env.local`:**

```dotenv
# Mailjet Email Alerts
MAILJET_API_KEY=your_api_key
MAILJET_API_SECRET=your_api_secret
MAILJET_FROM=alerts@example.com
MAILJET_TO=your@email.com
```

```bash
# -------------------------------------------------
#       === Mailjet Email Alerts ===
# -------------------------------------------------
# NOTES: 
# 1) The information below is sensitive/private to you.
# 2) Create a file called `.env.local` in the script root directory.
# 3) Copy to this block to .env.local, uncomment, and customize with your info.
MAILJET_API_KEY=your_api_key
MAILJET_API_SECRET=your_api_secret
MAILJET_FROM=alerts@example.com
MAILJET_TO=your@email.com
```

---

### 🔍 Next Steps

Once this is working, we can:

* Call this script from any backup failure branch (`if [[ $? -ne 0 ]]; then ...`)
* Add warnings if disk usage exceeds a threshold (e.g. 90%)

Would you like to test this script next or integrate it into one of your backup alerts?






```bash
# -------------------------------------------------
#       === Mailjet Email Alerts ===
# -------------------------------------------------
# NOTES: 
# 1) The information below is sensitive/private to you.
# 2) Create a file called `.env.local` in the script root directory.
# 3) Copy to this block to .env.local, uncomment, and customize with your info.
# MAILJET_API_KEY=your_api_key
# MAILJET_API_SECRET=your_api_secret
# MAILJET_FROM=alerts@example.com
# MAILJET_TO=your@email.com
```
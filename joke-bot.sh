#!/bin/bash
set -euo pipefail

# Configuration

# Use the directory containing this script as the repo by default. Override if needed.
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
JOKE_FILE="joke.txt"
HISTORY_FILE="joke_history.md"
CSV_FILE="history.csv"
INTERVAL_MINUTES=30
# Joke sources are chosen at random each run to keep things interesting.
JOKE_SOURCES=(
    "JokeAPI|https://v2.jokeapi.dev/joke/Any?type=single|json_single"
    "OfficialJoke|https://official-joke-api.appspot.com/jokes/programming/random|official"
    "DadJoke|https://icanhazdadjoke.com/|icanhaz"
    "ChuckNorris|https://api.chucknorris.io/jokes/random|chuck"
    "GeekJoke|https://geek-jokes.sameerkumar.website/api?format=json|json_single"
)
FALLBACK_JOKE="Why do programmers prefer dark mode? Because light attracts bugs!"
ASCII_ART=$'      ":"\n    ___:____     |"\\/"|\n  ,\'        `.    \\  /\n  |  O        \\___/  |\n~^~^~^~^~^~^~^~^~^~^~^~^~'

play_ding_sound() {
    if command -v canberra-gtk-play >/dev/null 2>&1; then
        local sound_ids=(alarm-clock-elapsed service-login suspend-error complete)
        for sound_id in "${sound_ids[@]}"; do
            if canberra-gtk-play -i "$sound_id" >/dev/null 2>&1; then
                return
            fi
        done
    fi

    if command -v paplay >/dev/null 2>&1; then
        local sound_candidates=(
            "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
            "/usr/share/sounds/freedesktop/stereo/service-login.oga"
            "/usr/share/sounds/freedesktop/stereo/suspend-error.oga"
            "/usr/share/sounds/freedesktop/stereo/complete.oga"
            "/usr/share/sounds/freedesktop/stereo/message.oga"
            "/usr/share/sounds/freedesktop/stereo/bell.oga"
        )
        for sound_file in "${sound_candidates[@]}"; do
            if [ -f "$sound_file" ]; then
                paplay "$sound_file" >/dev/null 2>&1 &
                return
            fi
        done
    fi

    if command -v aplay >/dev/null 2>&1; then
        local sound_candidates=(
            "/usr/share/sounds/alsa/Noise.wav"
            "/usr/share/sounds/alsa/Front_Center.wav"
        )
        for sound_file in "${sound_candidates[@]}"; do
            if [ -f "$sound_file" ]; then
                aplay -q "$sound_file" &
                return
            fi
        done
    fi

    if command -v spd-say >/dev/null 2>&1; then
        spd-say "New joke committed" >/dev/null 2>&1 &
        return
    fi

    # Fall back to terminal bell.
    printf '\a'
}

show_commit_popup() {
    local joke_text=$1
    local source_url=${2:-"Unknown source"}
    local prompt_title="😂 New joke committed!"
    local popup_file
    play_ding_sound
    # Temp file holds the popup content so terminals can display it via `cat`.
    popup_file=$(mktemp)
    {
        # Write title, joke, and ASCII art to the temp file in one go.
        printf '%s\n\n%s\n\nSource: %s\n\n' "$prompt_title" "$joke_text" "$source_url"
        printf '%s\n' "$ASCII_ART"
    } > "$popup_file"
    local quoted_file
    quoted_file=$(printf "%q" "$popup_file")

    if command -v gnome-terminal >/dev/null 2>&1; then
        gnome-terminal -- bash -lc "cat $quoted_file; echo; read -rp 'Press Enter to close...' _; rm -f $quoted_file"
    elif command -v x-terminal-emulator >/dev/null 2>&1; then
        x-terminal-emulator -e bash -lc "cat $quoted_file; echo; read -rp 'Press Enter to close...' _; rm -f $quoted_file"
    else
        printf '%s\n' "$prompt_title"
        printf '\n%s\n\n' "$joke_text"
        printf '%s\n' "$ASCII_ART"
        rm -f "$popup_file"
    fi
}

ensure_csv_ready() {
    if [ ! -f "$CSV_FILE" ]; then
        printf 'timestamp,joke,source\n' > "$CSV_FILE"
    fi
}

append_csv_row() {
    local ts="$1"
    local joke="$2"
    local source="$3"
    ensure_csv_ready
    CSV_TS="$ts" CSV_JOKE="$joke" CSV_SOURCE="$source" python3 - "$CSV_FILE" <<'PY'
import csv, os, sys
path = sys.argv[1]
ts = os.environ['CSV_TS']
joke = os.environ['CSV_JOKE']
source = os.environ['CSV_SOURCE']
with open(path, 'a', encoding='utf-8', newline='') as fh:
    csv.writer(fh).writerow([ts, joke, source])
PY
}

format_interval() {
    local minutes=$1
    case "$minutes" in
        20) echo "20 minutes" ;;
        30) echo "30 minutes" ;;
        45) echo "45 minutes" ;;
        60) echo "1 hour" ;;
        120) echo "2 hours" ;;
        180) echo "3 hours" ;;
        360) echo "6 hours" ;;
        1440) echo "1 day" ;;
        *) echo "$minutes minutes" ;;
    esac
}

choose_interval() {
    local question="How often do you want me to fetch a joke?"
    local menu_items=(
        "20" "Every 20 minutes"
        "30" "Every 30 minutes"
        "45" "Every 45 minutes"
        "60" "Every 1 hour"
        "120" "Every 2 hours"
        "180" "Every 3 hours"
        "360" "Every 6 hours"
        "1440" "Every day"
    )

    if command -v whiptail >/dev/null 2>&1; then
        local choice
        choice=$(whiptail --title "Daily Joke Bot" --menu "$question" 0 0 0 "${menu_items[@]}" 3>&1 1>&2 2>&3)
        if [ $? -eq 0 ] && [ -n "$choice" ]; then
            INTERVAL_MINUTES=$choice
        fi
    elif command -v dialog >/dev/null 2>&1; then
        local tmpfile choice exit_code
        tmpfile=$(mktemp)
        dialog --title "Daily Joke Bot" --menu "$question" 0 0 0 "${menu_items[@]}" 2>"$tmpfile"
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            choice=$(<"$tmpfile")
            if [ -n "$choice" ]; then
                INTERVAL_MINUTES=$choice
            fi
        fi
        rm -f "$tmpfile"
    else
        echo "$question"
        select choice in \
            "Every 20 minutes" \
            "Every 30 minutes" \
            "Every 45 minutes" \
            "Every 1 hour" \
            "Every 2 hours" \
            "Every 3 hours" \
            "Every 6 hours" \
            "Every day"; do
            case $REPLY in
                1) INTERVAL_MINUTES=20 ;;
                2) INTERVAL_MINUTES=30 ;;
                3) INTERVAL_MINUTES=45 ;;
                4) INTERVAL_MINUTES=60 ;;
                5) INTERVAL_MINUTES=120 ;;
                6) INTERVAL_MINUTES=180 ;;
                7) INTERVAL_MINUTES=360 ;;
                8) INTERVAL_MINUTES=1440 ;;
                *) echo "Please choose a valid option."; continue ;;
            esac
            break
        done
    fi
}

choose_random_source() {
    local count=${#JOKE_SOURCES[@]}
    local index=$((RANDOM % count))
    IFS="|" read -r SOURCE_NAME SOURCE_URL SOURCE_TYPE <<< "${JOKE_SOURCES[$index]}"
}

fetch_joke_from_source() {
    local response
    case "$SOURCE_TYPE" in
        json_single)
            response=$(curl -s "$SOURCE_URL" | jq -r '.joke // empty' 2>/dev/null || true)
            ;;
        official)
            response=$(curl -s "$SOURCE_URL" | jq -r '.[0] | "\(.setup) \(.punchline)"' 2>/dev/null || true)
            ;;
        icanhaz)
            response=$(curl -s -H "Accept: application/json" "$SOURCE_URL" | jq -r '.joke // empty' 2>/dev/null || true)
            ;;
        chuck)
            response=$(curl -s "$SOURCE_URL" | jq -r '.value // empty' 2>/dev/null || true)
            ;;
        *)
            response=""
            ;;
    esac

    # jq prints "null" as literal when value missing; treat that as empty.
    if [ "$response" = "null" ]; then
        response=""
    fi

    JOKE=$response
}

# Navigate to repo directory
cd "$REPO_DIR" || { echo "Repo directory not found! Current dir: $(pwd)"; exit 1; }

ensure_csv_ready
choose_interval
INTERVAL_LABEL=$(format_interval "$INTERVAL_MINUTES")

while true; do
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "--- Fetching new joke at $TIMESTAMP ---"
    
    # Select a random source and pull a joke.
    choose_random_source
    fetch_joke_from_source
    SOURCE_DISPLAY="$SOURCE_URL"

    # If API fails, fall back to a local joke and track that fact.
    if [ -z "$JOKE" ]; then
        JOKE="$FALLBACK_JOKE"
        SOURCE_DISPLAY="Fallback joke (local)"
    fi

    # Add joke to the main file (overwrite to keep only latest)
    cat > "$JOKE_FILE" <<EOF
🎭 Latest Joke - $TIMESTAMP:
$JOKE

Source: $SOURCE_DISPLAY

Next update in ${INTERVAL_LABEL}...
EOF
    
    # Add to history file (append)
    echo "- $TIMESTAMP: $JOKE (source: $SOURCE_DISPLAY)" >> "$HISTORY_FILE"
    append_csv_row "$TIMESTAMP" "$JOKE" "$SOURCE_DISPLAY"
    
    # Git operations (optional if repo is git-enabled)
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git add "$JOKE_FILE" "$HISTORY_FILE"
        git commit -m "New Commit: $JOKE" -m "There's a difference between making jokes and being a joke." || echo "⚠️ No changes to commit."
        git push origin main
        echo "✅ Joke committed: $JOKE"
        show_commit_popup "$JOKE" "$SOURCE_DISPLAY"
    else
        echo "⚠️ Skipping git operations: $REPO_DIR is not a Git repository."
    fi

    echo "🔗 Joke source: $SOURCE_DISPLAY"
    echo "🕐 Waiting ${INTERVAL_LABEL} until next update..."
    echo ""
    
    # Wait before next update
    sleep $((INTERVAL_MINUTES * 60))
    INTERVAL_LABEL=$(format_interval "$INTERVAL_MINUTES")
done

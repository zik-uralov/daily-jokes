#!/bin/bash

# Configuration
REPO_DIR="/home/kit/Documents/daily-jokes"  # CHANGE THIS to your repo path
JOKE_FILE="jokes.txt"
HISTORY_FILE="joke_history.md"
INTERVAL_MINUTES=30

# Navigate to repo directory
cd "$REPO_DIR" || { echo "Repo directory not found!"; exit 1; }

while true; do
    echo "--- Fetching new joke at $(date) ---"
    
    # Get random joke from API
    JOKE=$(curl -s "https://v2.jokeapi.dev/joke/Programming?type=single" | jq -r '.joke')
    
    # If API fails, use fallback joke
    if [ "$JOKE" = "null" ] || [ -z "$JOKE" ]; then
        JOKE="Why do programmers prefer dark mode? Because light attracts bugs!"
    fi
    
    # Add joke to the main file (overwrite to keep only latest)
    echo "🎭 Latest Joke - $(date +"%Y-%m-%d %H:%M:%S"):" > "$JOKE_FILE"
    echo "$JOKE" >> "$JOKE_FILE"
    echo "" >> "$JOKE_FILE"
    echo "Next update in 30 minutes..." >> "$JOKE_FILE"
    
    # Add to history file (append)
    echo "- $(date +"%Y-%m-%d %H:%M:%S"): $JOKE" >> "$HISTORY_FILE"
    
    # Git operations
    git add "$JOKE_FILE" "$HISTORY_FILE"
    git commit -m "😂 New joke: $JOKE"
    git push origin main
    
    echo "✅ Joke committed: $JOKE"
    echo "🕐 Waiting 30 minutes until next update..."
    echo ""
    
    # Wait 30 minutes
    sleep 1800
done
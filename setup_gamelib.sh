#!/bin/bash
# ============================================================
# L76 - GAME LIBRARY MANAGER
# Linux Operating System Lab
# Student: Rajdeep Kanzariya
# Folder: ~/linux_project/gamelib
# Run: bash setup_gamelib.sh
# ============================================================

P="$HOME/linux_project/gamelib"

if [ -d "$P" ]; then
    echo "Folder already exists: $P"
    echo "Please rename or backup the existing folder first."
    exit 1
fi

mkdir -p "$P"/{lib,data,reports,backups,logs}
cd "$P" || exit 1

# ------------------------------------------------------------
# SAMPLE DATA
# ------------------------------------------------------------

cat > data/games.csv <<'DATA'
title,platform,genre,hours,status
Game A,PC,RPG,120,completed
Game B,Mobile,Battle Royale,300,playing
Game C,Console,Racing,15,backlog
DATA

# ------------------------------------------------------------
# LIBRARY FUNCTIONS
# ------------------------------------------------------------

cat > lib/functions.sh <<'FUNCTIONS'
#!/bin/bash

DATA="data/games.csv"
LOG="logs/activity.log"

# Activity Log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" >> "$LOG"
}

# Check Data
check_data() {
    if [ ! -f "$DATA" ]; then
        echo "Game data file not found!"
        return 1
    fi
}

# Help
show_help() {
    echo "Game Library Manager"
    echo "Usage:"
    echo "./main.sh        Open menu"
    echo "./main.sh --help Show help"
    echo "./main.sh --backup Backup data"
    echo "./main.sh --cron  Generate weekly summary"
}

# Add New Game
add_game() {
    echo
    echo "========== ADD NEW GAME =========="

    read -r -p "Enter Game Title: " title
    read -r -p "Enter Platform: " platform
    read -r -p "Enter Genre: " genre
    read -r -p "Enter Playing Hours: " hours

    if [[ -z "$title" || -z "$platform" || -z "$genre" ]]; then
        echo "All fields are required."
        return 1
    fi

    if [[ "$title$platform$genre" == *","* ]]; then
        echo "Commas are not allowed in text fields."
        return 1
    fi

    if ! [[ "$hours" =~ ^[0-9]+$ ]]; then
        echo "Hours must be a positive number."
        return 1
    fi

    echo "Select Status:"
    echo "1. Completed"
    echo "2. Playing"
    echo "3. Backlog"

    read -r -p "Choose status: " choice

    case "$choice" in
        1) status="completed" ;;
        2) status="playing" ;;
        3) status="backlog" ;;
        *)
            echo "Invalid status."
            return 1
            ;;
    esac

    echo "$title,$platform,$genre,$hours,$status" >> "$DATA"

    echo "Game added successfully!"
    log "Added game: $title"
}

# View All Games
view_games() {
    check_data || return

    echo
    echo "========== GAME LIBRARY =========="

    if command -v column >/dev/null 2>&1; then
        column -s ',' -t "$DATA"
    else
        cat "$DATA"
    fi

    log "Viewed all games"
}

# Filter Games by Platform
filter_platform() {
    check_data || return

    read -r -p "Enter Platform: " platform

    echo
    echo "Games on platform: $platform"

    awk -F',' -v p="$platform" '
    NR==1 {print; next}
    tolower($2)==tolower(p) {print}
    ' "$DATA"

    log "Filtered games by platform: $platform"
}

# Filter Games by Genre
filter_genre() {
    check_data || return

    read -r -p "Enter Genre: " genre

    echo
    echo "Games in genre: $genre"

    awk -F',' -v g="$genre" '
    NR==1 {print; next}
    tolower($3)==tolower(g) {print}
    ' "$DATA"

    log "Filtered games by genre: $genre"
}

# Total Playing Hours
total_hours() {
    check_data || return

    total=$(awk -F',' 'NR>1 {sum += $4} END {print sum+0}' "$DATA")

    echo "Total Playing Hours: $total"

    log "Calculated total playing hours"
}

# Completion Percentage
completion_percentage() {
    check_data || return

    awk -F',' '
    NR>1 {
        total++
        if (tolower($5)=="completed")
            completed++
    }
    END {
        if (total==0) {
            print "No games available."
        } else {
            percentage=(completed/total)*100
            printf "Completed Games: %d/%d\n", completed,total
            printf "Completion Percentage: %.2f%%\n",percentage
        }
    }
    ' "$DATA"

    log "Calculated completion percentage"
}

# Top 5 Most Played Games
top_games() {
    check_data || return

    echo
    echo "========== TOP 5 MOST PLAYED GAMES =========="

    tail -n +2 "$DATA" |
    sort -t',' -k4,4nr |
    head -5

    log "Viewed top 5 most played games"
}

# View Data
view_data() {
    view_games
}

# Backup Data
do_backup() {
    check_data || return

    mkdir -p backups

    file="backups/games_$(date +%Y%m%d_%H%M%S).tar.gz"

    tar -czf "$file" data/

    if [ $? -eq 0 ]; then
        echo "Backup created successfully!"
        echo "File: $file"
        du -h "$file"
        log "Backup created: $file"
    else
        echo "Backup failed."
    fi
}

# Activity Log
view_log() {
    if [ -f "$LOG" ]; then
        echo "========== ACTIVITY LOG =========="
        tail -n 15 "$LOG"
    else
        echo "No activity found."
    fi
}

# Weekly Cron Task
cron_task() {
    check_data || return

    mkdir -p reports

    output="reports/weekly_summary.txt"

    {
        echo "======================================"
        echo " GAME LIBRARY MANAGER - WEEKLY REPORT"
        echo " Generated: $(date)"
        echo "======================================"

        total_games=$(awk -F',' 'NR>1 {n++} END {print n+0}' "$DATA")

        total_hours=$(awk -F',' 'NR>1 {sum += $4} END {print sum+0}' "$DATA")

        completed=$(awk -F',' 'NR>1 && tolower($5)=="completed" {n++} END {print n+0}' "$DATA")

        echo "Total Games: $total_games"
        echo "Total Playing Hours: $total_hours"
        echo "Completed Games: $completed"

        if [ "$total_games" -gt 0 ]; then
            awk -F',' '
            NR>1 {
                total++
                if (tolower($5)=="completed") completed++
            }
            END {
                printf "Completion Percentage: %.2f%%\n", (completed/total)*100
            }
            ' "$DATA"
        else
            echo "Completion Percentage: 0%"
        fi

        echo
        echo "TOP 5 MOST PLAYED GAMES"
        echo "-----------------------"

        tail -n +2 "$DATA" |
        sort -t',' -k4,4nr |
        head -5

        echo
        echo "========== END OF REPORT =========="

    } > "$output"

    echo "Weekly report generated: $output"

    log "Weekly summary generated"
}

FUNCTIONS

# ------------------------------------------------------------
# MAIN MENU
# ------------------------------------------------------------

cat > main.sh <<'MAIN'
#!/bin/bash

cd "$(dirname "$0")" || exit 1

source lib/functions.sh

case "$1" in
    --help)
        show_help
        exit 0
        ;;
    --backup)
        do_backup
        exit 0
        ;;
    --cron)
        cron_task
        exit 0
        ;;
esac

while true; do

    echo
    echo "======================================"
    echo "       GAME LIBRARY MANAGER"
    echo "======================================"
    echo "1) Add New Game"
    echo "2) View All Games"
    echo "3) Filter Games by Platform"
    echo "4) Filter Games by Genre"
    echo "5) Total Playing Hours"
    echo "6) Completion Percentage"
    echo "7) Top 5 Most Played Games"
    echo "8) View Data"
    echo "9) Backup Data"
    echo "10) View Activity Log"
    echo "0) Exit"
    echo "======================================"

    read -r -p "Choose an option: " ch

    case "$ch" in
        1) add_game ;;
        2) view_games ;;
        3) filter_platform ;;
        4) filter_genre ;;
        5) total_hours ;;
        6) completion_percentage ;;
        7) top_games ;;
        8) view_data ;;
        9) do_backup ;;
        10) view_log ;;
        0)
            echo "Thank you for using Game Library Manager!"
            break
            ;;
        *)
            echo "Invalid choice. Try again."
            ;;
    esac

done
MAIN

# ------------------------------------------------------------
# README
# ------------------------------------------------------------

cat > README.md <<'README'
# L76 - Game Library Manager

## Project Details

- Project Title: Game Library Manager
- Project ID: L76
- Subject: Linux Operating System Lab
- Student: Rajdeep Kanzariya

## Problem

Managing a personal video game collection can be difficult.
This project helps users store game details, track playing
hours, filter games and check completion progress.

## Features

1. Add a new game.
2. View all games.
3. Filter games by platform.
4. Filter games by genre.
5. Calculate total playing hours.
6. Calculate completion percentage.
7. Show top 5 most played games.
8. Backup game data.
9. View activity log.
10. Generate weekly summary using Cron.

## Folder Structure

- main.sh
- lib/functions.sh
- data/games.csv
- reports/
- backups/
- logs/

## How to Run

    cd ~/linux_project/gamelib
    ./main.sh

## Help

    ./main.sh --help

## Backup

    ./main.sh --backup

## Cron Task

Every Sunday at 8 PM, generate a weekly summary.

    0 20 * * 0 /bin/bash $HOME/linux_project/gamelib/main.sh --cron >> $HOME/linux_project/gamelib/logs/cron.log 2>&1

## Commands Used

- Bash
- while
- case
- awk
- sort
- head
- tail
- tar
- date
- crontab

## What I Learned

I learned how to create a menu-driven Linux application,
manage CSV files, use Bash functions, filter records,
calculate statistics, create backups and schedule tasks
using Cron.
README

# ------------------------------------------------------------
# PERMISSIONS AND INITIAL FILES
# ------------------------------------------------------------

chmod +x main.sh lib/functions.sh

touch logs/activity.log

echo
echo "======================================"
echo " GAME LIBRARY MANAGER SETUP COMPLETE"
echo "======================================"
echo "Project Folder: $P"
echo
ls -R "$P"

echo
echo "Next Commands:"
echo "cd ~/linux_project/gamelib"
echo "./main.sh"
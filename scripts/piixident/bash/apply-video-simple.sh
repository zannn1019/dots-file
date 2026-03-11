#!/bin/bash
video_path="$1"

if [ -z "$video_path" ]; then
    echo "Usage: $0 <video_path>"
    exit 1
fi

# Kill existing mpvpaper
pkill -9 mpvpaper 2>/dev/null
sleep 0.2

# Get monitors
monitors=$(hyprctl monitors -j | jq -r '.[] | .name')

# Start mpvpaper on each monitor
for monitor in $monitors; do
    mpvpaper -o "no-audio loop hwdec=auto panscan=1.0" "$monitor" "$video_path" &
    sleep 0.1
done

echo "Video wallpaper applied: $(basename "$video_path")"

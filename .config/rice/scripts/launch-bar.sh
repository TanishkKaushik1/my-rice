#!/bin/bash

pkill -f "quickshell -c.*/bar"
pkill -f "app-launcher"

# Wait until actually dead instead of guessing with sleep
while pgrep -f "quickshell -c.*/bar" > /dev/null; do sleep 0.1; done
while pgrep -f "app-launcher" > /dev/null; do sleep 0.1; done

# Wait for PipeWire
for i in {1..20}; do
    pw-link -o > /dev/null 2>&1 && break
    sleep 0.5
done
sleep 1

# Start app-launcher backend
$HOME/.config/rice/app-launcher/target/release/app-launcher &

# Wait for socket
for i in {1..30}; do
    [ -S /tmp/app-launcher.sock ] && break
    sleep 0.1
done

# Start bar
env QML_XHR_ALLOW_FILE_READ=1 quickshell -c "$HOME/.config/rice/bar" &

# Start app launcher UI
quickshell -c "$HOME/.config/rice/app-launcher" &
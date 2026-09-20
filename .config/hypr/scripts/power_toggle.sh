#!/bin/bash
CURRENT=$(powerprofilesctl get)
if [ "$CURRENT" == "performance" ]; then
    powerprofilesctl set power-saver
elif [ "$CURRENT" == "power-saver" ]; then
    powerprofilesctl set balanced
else
    powerprofilesctl set performance
fi

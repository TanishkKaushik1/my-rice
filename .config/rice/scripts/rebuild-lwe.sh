#!/usr/bin/env bash
cd $HOME/.config/rice/linux-wallpaperengine/build || exit 1
make -j$(nproc) && make install

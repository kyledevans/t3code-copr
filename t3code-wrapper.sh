#!/usr/bin/env bash

# This RPM owns application updates through DNF/Copr. Keep T3 Code's bundled
# Electron/AppImage updater disabled unless the caller explicitly opts back in.
export T3CODE_DISABLE_AUTO_UPDATE="${T3CODE_DISABLE_AUTO_UPDATE:-true}"

exec /opt/t3code/T3Code.AppImage "$@"

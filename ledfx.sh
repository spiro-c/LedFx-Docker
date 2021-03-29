#!/bin/bash

avahi-daemon --daemonize --no-drop-root

exec ledfx "$@"

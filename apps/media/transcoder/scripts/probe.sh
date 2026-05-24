#!/bin/bash

ffprobe -hide_banner -print_format json -show_format -show_streams "$*"

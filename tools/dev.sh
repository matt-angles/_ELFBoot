#!/bin/sh
# Tiny script to set up a development shell
# To be run with 'source'

cd "$(dirname "$0")"

# NOTE: Add check for cross
PREFIX=`cd ../cross; pwd`
export PATH="$PREFIX/bin:$PATH"
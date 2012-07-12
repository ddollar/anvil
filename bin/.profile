#!/bin/bash

shopt -s nullglob
for profile in $(dirname $0)/profile.d/*; do
  source $profile
done

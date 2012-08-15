#!/bin/bash

shopt -s nullglob
for profile in $HOME/.profile.d/*; do
  source $profile
done

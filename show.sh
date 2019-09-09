#!/bin/bash

cat "$(\ls -1dt ./*/ | head -n 1)"/*/*.${1:-setup}.log

#!/bin/bash

d=$(ls -td -- */ | head -n 1)
flent-gui $d*/*.flent.gz

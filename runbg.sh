#1/bin/bash

tests="${1:-all}"

nohup ./run.sh "$tests" notify &> flent.out &

#!/bin/bash

# divergence detector: takes in 2 annotated trace files, and
# finds the first line of difference in their stub traces.
# This line represents the code stub in which the stub trace
# divergence occurs.


# First, generate the stub traces.

./get-stubtrace.sh $1 > "stubtrace-$1"
./get-stubtrace.sh $2 > "stubtrace-$2"

# Now, find the first diverging line. Output the line above that, and the line
# number of that line.

diffline=$(diff "stubtrace-$1" "stubtrace-$2" | head -n 2| grep -o '[0-9]*' | head -n 1)
LastKnownGoodLine=$(($diffline - 1))
if [ $LastKnownGoodLine -eq -1 ]; then
  echo "No divergence found"
  exit 0
fi
stubToInvestigate=$(sed "$LastKnownGoodLine"'!d' "stubtrace-$1")
echo "First diff detected on line $diffline. Recommend investigating code stub $stubToInvestigate"

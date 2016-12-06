#!/bin/bash

# This script is to automate the process of running octane multiple times
# run-octane.sh [absolute path to octane] [absolute path to v8] [build] [num of times]
# for example run-octane.sh /sandbox/someone/octane /sandbox/someone/v8 s390x.release 10

# After it finish, copy output into excel and select "Data" > "Text To Columns"
# to split output into separate columns.
# The last column is average score for all the runs


# ocatne benchmark and its correponding index in the Results and Strings array.
Richards=0
DeltaBlue=1
Crypto=2
RayTrace=3
EarleyBoyer=4
RegExp=5
Splay=6
SplayLatency=7
NavierStokes=8
PdfJS=9
Gameboy=10
CodeLoad=11
Box2D=12
Typescript=13
Score=14

declare -a Results=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
declare -a Strings=("" "" "" "" "" "" "" "" "" "" "" "" "" "" "")

cd $1

for i in `seq 1 $4`;
do
  result=$("$2"/out/"$3"/d8 run.js | grep -o '[0-9]*$')

  j=0
  for item in $result
  do
    #echo $item
    let Results[$j]+=$item
    Strings[j]+="$item \t"
    let j+=1
  done
done

for j in {0..14}
do
  avg=$(( Results[j] / $4 ))
  Strings[j]+="$avg"
  echo -e ${Strings[j]}
done

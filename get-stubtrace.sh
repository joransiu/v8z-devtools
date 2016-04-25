#!/bin/bash

#This shell script is to be run on an annotated trace file.
#This will extract the list of stubs.

cat $1 | grep -o "<.*>" | sed "s,+[0-9]*>,>,g" | uniq


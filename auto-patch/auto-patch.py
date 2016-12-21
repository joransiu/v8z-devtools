#!/usr/bin/python

#
# Automatically generate a patch based on given patch file.
#
import json
import re
import os

# Return a list of patches, one file per list item.
def parsePatch(file):
  patches = []
  current = ""
  for line in file.split('\n'):
    if line.find("Index:") == 0:
      patches.append(current)
      current = ""
    current += line + '\n'
  patches.append(current)

  return patches

# Return a dictionary of rules: {RE matching ARM code: (PPC replacement, ARM replacement), ...}
def readRulesFile(filename = os.path.dirname(os.path.realpath(__file__)) + "/auto-patch-rules.json"):
  with open(filename) as datafile:
    data = json.load(datafile)
  return data

# Translate ARM patch to ppc and s390 patches.
def translate(rules, patch):
  ppcpatch = patch
  s390patch = patch
  for armPattern in rules.keys():
    pattern = re.compile(armPattern)
    ppcpatch = re.sub(pattern, rules[armPattern][0], ppcpatch)
    s390patch = re.sub(pattern, rules[armPattern][1], s390patch)
  return (ppcpatch,s390patch)

def Main():
  import argparse
  parser = argparse.ArgumentParser(description="A script for automatically generating a patch")
  parser.add_argument('patch_file_name', type = str, help = "the filename of the arm patch")
  parser.add_argument('-c', '--combined_patch', action = "store_true", help = "combines ppc and s390 patch - creates combined-<patch_file_name>")
  parser.add_argument('--ppc_output', type = str, help = "output file name for ppc patch (default: ppc-<patch_file_name>)")
  parser.add_argument('--s390_output', type = str, help = "output file name of s390 patch (default: s390-<patch_file_name>)")
  parser.add_argument('--rules_file', type = str, help = "the filename of rules files, default is auto-patch-rules.json")
  args = parser.parse_args()
  rules = {}
  if not args.rules_file:
    rules = readRulesFile()
  else:
    rules = readRulesFile(args.rules_file)
  if args.combined_patch:
    patchedfiles = parsePatch(open(args.patch_file_name).read())
    processedPatch = ""
    for f in patchedfiles:
      ppcfile,s390file = translate(rules,f)

      #if some replacement actually happened.
      if ppcfile != s390file:
        processedPatch += ppcfile + '\n' + s390file + '\n'

    combinedout = open('combined-' + args.patch_file_name, 'w')
    combinedout.write(processedPatch)
    combinedout.close()
  else:
    ppcfile,s390file = translate(rules, open(args.patch_file_name).read())
    ppcfilename = 'ppc-' + args.patch_file_name
    s390filename = 's390-' + args.patch_file_name
    if args.ppc_output:
      ppcfilename = args.ppc_output
    if args.s390_output:
      s390filename = args.s390_output
    ppcout = open(ppcfilename,'w')
    s390out = open(s390filename,'w')
    ppcout.write(ppcfile)
    s390out.write(s390file)
    ppcout.close()
    s390out.close()


if __name__ == "__main__":
  Main()

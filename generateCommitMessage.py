#!/bin/python

#
# A script that automatically generate a message for 
# upstreaming given the original commit hash.
#


import subprocess
import re

def commitMessage(commitHash):
  originalHash = subprocess.check_output(["git", "log", str(commitHash), "--pretty=format:%H", '-1'] ).strip()
  commitTitle = subprocess.check_output(["git", "log", str(commitHash), "--pretty=format:%s", '-1'] ).strip()
  originalCommiterEmail= subprocess.check_output(["git", "log", str(commitHash), "--pretty=format:%ae", '-1'] ).strip()
  
  originalCommitMessage = subprocess.check_output(["git", "log", str(commitHash), "--pretty=format:\%B", "-1"]).split("\n")

  # Parse the originalCommitMessage Tags
  originalCommitMessage = filter(lambda text : (len(text) == 0 or not (text[0] == '#' or text.isspace())), originalCommitMessage)

  commitInfo = {}

  for line in originalCommitMessage:
    if re.match(r'[A-Za-z_-]*=',line):
      i = line.find('=') + 1
      commitInfo[line[:i]] = line[i:]
    if re.match(r'[A-Za-z_-]*: ',line):
      i = line.find(': ') + 2
      commitInfo[line[:i]] = line[i:]

  textFilter = lambda text : not (text.find(commitTitle) != -1 or re.match(r'^[A-Za-z_-]*(=|: )',text))

  commitMessageBody = filter(textFilter, originalCommitMessage)

  if len(commitMessageBody) != 0:
    while len(commitMessageBody) != 0 and commitMessageBody[0] == '':
      commitMessageBody.pop(0)
    while len(commitMessageBody) != 0 and commitMessageBody[-1] == '':
      commitMessageBody.pop(-1)

  message = "PPC/s390: " + commitTitle + '\n'
  message += "\nPort "+originalHash+"\n"

  if len([line for line in commitMessageBody if not(line.isspace() or len(line) == 0)]) != 0:
    message += '\nOriginal Commit Message:\n\n'
    for line in commitMessageBody:
      message += "    " + line + "\n"

  message += "\n"
  message += "R="+originalCommiterEmail+", joransiu@ca.ibm.com, jyan@ca.ibm.com, bjaideep@ca.ibm.com, michael_dawson@ca.ibm.com\n"
  if "BUG=" in commitInfo.keys():
    message += "BUG="+commitInfo["BUG="]+"\n"
  else:
    message += "BUG=\n"
  message += "LOG=N"
  return message


if __name__ == "__main__":
  import argparse
  parser=argparse.ArgumentParser(description="A script for generating port commit messages")
  parser.add_argument('commitHash', type = str, help = "the hash for the commit")
  args = parser.parse_args()
  print commitMessage(args.commitHash)

#!/usr/bin/python
#
# Automatically commit and upload to chromium code reviews.
# Need to be run under the root of a v8 repo, and generateCommitMessage.py
from __future__ import print_function
import subprocess, sys, os
import re

def commitMessage(commitHash):
  originalHash = subprocess.check_output(["git", "log", str(commitHash), "--pretty=format:%H", '-1'] ).strip()
  commitTitle = subprocess.check_output(["git", "log", str(commitHash), "--pretty=format:%s", '-1'] ).strip()
  originalCommiterEmail= subprocess.check_output(["git", "log", str(commitHash), "--pretty=format:%ae", '-1'] ).strip()
  portUploaderEmail= subprocess.check_output(["git", "config", "user.email"]).strip()
  
  originalCommitMessage = subprocess.check_output(["git", "log", str(commitHash), "--pretty=format:\%B", "-1"]).split("\n")
  # Parse the originalCommitMessage Tags
  originalCommitMessage = filter(lambda text : (len(text) == 0 or not (text[0] == '#' or text.isspace())), originalCommitMessage)

  reviewerList=['joransiu@ca.ibm.com', 'jyan@ca.ibm.com', 'bjaideep@ca.ibm.com', 'michael_dawson@ca.ibm.com']
  if portUploaderEmail in reviewerList:
    reviewerList.remove(portUploaderEmail)

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
  message += "R="+originalCommiterEmail+", "+(", ").join(reviewerList)+"\n"
  if "BUG=" in commitInfo.keys():
    message += "BUG="+commitInfo["BUG="]+"\n"
  else:
    message += "BUG=\n"
  message += "LOG=N"
  return message

def printError(exitCode, *args, **kwargs):
  print(__file__, end = ':')
  print(*args, file = sys.stderr, **kwargs)
  if exitCode:
    print("(last executed command exit code = " + str(exitCode) + ")")

def runCommand(command, stdout = None, stderr = None,\
              errorMessage = None, workingDirectory = os.getcwd()):
  if not errorMessage:
    errorMessage = " ".join(command) + " failed." 
  try:
    print(" ".join(command))
    if not DRY_RUN:
      subprocess.check_call(command,stdout = stdout, stderr = stderr, cwd = workingDirectory)
  except subprocess.CalledProcessError as e:
    printError(e.returncode,errorMessage)
    exit(1)

def runLintTest():
  runCommand(["python", "tools/presubmit.py"], errorMessage = "Lint check failed.")

  
def commitAndUpload(gitAddArgList, portHash):
  runCommand(["git","add"] + gitAddArgList)
  cm = commitMessage(portHash)
  print("Commit message is:\n", cm)
  print("git","commit","--file","-")
  if not DRY_RUN:
    p = subprocess.Popen(["git","commit", "--file", "-"], stdin=subprocess.PIPE)
    p.communicate(input = cm)
  runCommand(["git","cl","upload"])

def Main():
  import argparse
  parser = argparse.ArgumentParser(description = "A script for automatically performing cl upload.")
  parser.add_argument('portHash', type = str, help = "The commit hash to be ported")
  parser.add_argument('git_add_args', nargs = '+', help = \
  "Arguments to be appended to command git add. if the argument start with a dash ('-'), the arguments must start with --.")
  parser.add_argument('-D','--dryrun', action = 'store_true', help = "Do not run the commands, just output them")
  parser.add_argument('-C','--commit_message_only', action = 'store_true', help = "Just print the commit message")
  args = parser.parse_args()
  global DRY_RUN
  DRY_RUN = args.dryrun
  if args.commit_message_only:
    print(commitMessage(args.portHash))
    exit(0)
  runLintTest()
  commitAndUpload(args.git_add_args,args.portHash)

if __name__=="__main__":
  Main()

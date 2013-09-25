#!/usr/bin/python2 -u

import sys

def __p2p_readline():
  try:
    line = raw_input()
  except EOFError:
    line = None
  return line

def __p2p_print(args):
  for v in args:
    sys.stdout.write(str(v))

def __p2p_printf(args):
  fmt = args.pop(0)
  sys.stdout.write(fmt % tuple(map(str, args)))

###

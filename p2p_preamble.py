#!/usr/bin/python2 -u

import sys, re

__all__ = ('__p2p_argv __p2p_print __p2p_printf ' +
    '__p2p_chomp __p2p_split __p2p_join ' +
    '__p2p_io __p2p_io_null ' +
    '__int __str __len ').split()

__int, __str, __len = int, str, len
__p2p_argv = sys.argv[1:]

def __p2p_to_string(v):
  if type(v) is bool:
    return '1' if v else ''
  elif type(v) is list:
    return ''.join(map(__p2p_to_string, v))
  else:
    return str(v)

def __p2p_print(*args):
  for v in args:
    sys.stdout.write(__p2p_to_string(v))

def __p2p_printf(fmt, *args):
  sys.stdout.write(fmt % args)

def __p2p_chomp(string):
  # TODO handle lists and return values properly -- tuples?
  return string.rstrip('\n')

def __p2p_split(pat=None, expr=None, limit=None):
  if pat is None: pat = re.compile('\s+')
  limit = limit - 1 if limit is not None else 0
  return re.split(pat, expr, limit)

def __p2p_join(expr, items):
  return expr.join(items)

def __p2p_io(fh):
  try:
    return fh.readline()
  except:
    return None

def __p2p_io_nullgen_create():
  files = [ sys.stdin ] + map(open, sys.argv[1:])
  for f in files:
    while 1:
      try:
        yield f.readline()
      except:
        break

__p2p_io_nullgen = __p2p_io_nullgen_create()

def __p2p_io_null():
  global __p2p_io_nullgen
  try:
    return __p2p_io_nullgen.next()
  except StopIteration:
    __p2p_io_nullgen = __p2p_io_nullgen_create()  # Reset <> as per perl spec
    return None

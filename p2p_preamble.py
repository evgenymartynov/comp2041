#!/usr/bin/python2 -u

import sys, re, itertools

__all__ = ('__p2p_argv __p2p_print __p2p_printf ' +
    '__p2p_chomp __p2p_split __p2p_join ' +
    '__p2p_pop __p2p_shift __p2p_push __p2p_unshift __p2p_reverse ' +
    '__p2p_io __p2p_io_null ' +
    '__p2p_re_match __p2p_re_subs ' +
    '__int __str __len __p2p_dict ' +
    '__p2p_sort __p2p_keys ' +
    '__re __p2p_group ').split()

__int, __str, __len, __re = int, str, len, re
__p2p_argv = sys.argv[1:]
__p2p_matchgroups = None

def __p2p_dict(*args):
  return dict(zip(args[::2], args[1::2]))

def __p2p_to_string(v):
  if type(v) is bool:
    return '1' if v else ''
  elif type(v) is list:
    return ''.join(map(__p2p_to_string, v))
  elif type(v) is dict:
    return ''.join(
        [ __p2p_to_string(k) + __p2p_to_string(v) for k,v in v.iteritems() ])
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

def __p2p_pop(lst):
  return lst.pop()
def __p2p_shift(lst):
  return lst.pop(0)

def __p2p_push(lst, *args):
  lst.extend(args)
  return len(lst)
def __p2p_unshift(lst, *args):
  for i, arg in enumerate(args):
    lst.insert(i, arg)
  return len(lst)

def __p2p_reverse(*args):
  return list(reversed(args))

def __p2p_re_match(op, string, regex):
  global __p2p_matchgroups
  __p2p_matchgroups = regex.search(string)
  return (op == '!~') ^ (__p2p_matchgroups is not None)

def __p2p_re_subs(op, string, regex):
  assert regex[0] == 's'
  sep = regex[1]
  flags = regex[regex.rindex(sep):]
  regex = regex[2:-len(flags)]

  pat = r'((\\.|[^{sep}\\])*){sep}(.*)'.format(sep=sep)
  re_pat, _, repl = re.match(pat, regex).groups()
  repl = repl.replace(r'\$', '$')

  to_make = 0 if 'g' in flags else 1
  result = re.sub(re_pat, repl, string, count=to_make)

  return result

def __p2p_group(num):
  return __p2p_matchgroups.group(num)

def __p2p_sort(*args):
  return sorted(itertools.chain.from_iterable(args))

def __p2p_keys(dct):
  return dct.keys()

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

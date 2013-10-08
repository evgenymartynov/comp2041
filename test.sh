#!/bin/bash

for f in examples/*.pl tests/*.pl demo/*.pl; do
  input="/dev/null"
  finput=${f/.pl/.in}

  if [[ -f $finput ]]; then input=$finput; fi

  echo "Doing $f < $input"

  if diff -y \
      <(PYTHONPATH=. timeout -k 1 2 python <(./perl2python "$f") < $input | tail -n 10) \
      <(timeout -k 1 2 perl "$f" < $input 2>&1 | tail -n 10) > /tmp/diff;
  then : # nothing
  else
    cat /tmp/diff
  fi
done

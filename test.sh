#!/bin/bash

for f in examples/*.pl tests/*[0-7].pl demo/*.pl; do
  input="/dev/null"
  finput=${f/.pl/.in}

  if [[ -f $finput ]]; then input=$finput; fi

  echo "Doing $f < $input"

  diff -q \
      <(PYTHONPATH=. timeout -k 1 2 python <(./perl2python "$f") < $input | tail -n 10) \
      <(timeout -k 1 2 perl "$f" < $input 2>&1 | tail -n 10)
done

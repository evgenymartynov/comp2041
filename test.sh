#!/bin/bash

for f in examples/*.pl; do
  input="/dev/null"
  finput=${f/.pl/.in}

  if [[ -f $finput ]]; then input=$finput; fi

  echo "Doing $f < $input"

  diff -q \
      <(timeout -k 1 0.2 python <(./perl2python "$f") < $input | tail -n 10) \
      <(timeout -k 1 0.2 perl "$f" < $input 2>&1 | tail -n 10)
done

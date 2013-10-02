#!/bin/bash

for f in examples/*.pl; do
  echo "Doing $f"
  diff -q \
      <(python <(./perl2python "$f") < /dev/null | tail -n 10) \
      <(timeout -k 2 1 perl "$f" < /dev/null 2>&1 | tail -n 10)
done

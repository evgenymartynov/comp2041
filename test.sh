#!/bin/bash

for f in examples/*.pl; do
  echo "Doing $f"
  diff -q <(python <(./perl2python "$f") < /dev/null) <(perl "$f" < /dev/null)
done

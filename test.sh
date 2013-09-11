#!/bin/bash

for f in examples/*.pl; do
  echo "Doing $f"
  diff -q <(./perl2python "$f" | python) <(perl "$f")
done

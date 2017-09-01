#!/bin/sh
#
# Called by "git commit" with no arguments.  The hook should
# exit with non-zero status after issuing an appropriate message if
# it wants to stop the commit.
set -e

exec 1>&2
../bsym.rb check
git diff-index --check --cached HEAD

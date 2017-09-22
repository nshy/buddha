#!/bin/bash

set -e

function usage()
{
  cat << END
Usage:
  gitop.sh <command>

Commands:
  diff                          Show editor diff
  publish <commit message>      Publish editor diff
END
  exit 1
}

function git_edit()
{
  git --git-dir='.git-edit' --work-tree='edit' $@
}

function git_main()
{
  git --git-dir='main/.git' --work-tree='main' $@
}

function add()
{
  ./bsym.rb --git-dir '.git-edit' --work-tree 'edit' convert
  git_edit add .
}

function diff()
{
  add
  git_edit diff --staged --no-renames
}

function publish()
{
    MESSAGE="$1"
    [ -z "$MESSAGE" ] && usage

    add
    git_edit commit -m "$MESSAGE"
    git_main pull --ff-only edit master || {
      # plain git_edit reset does not work for some reason
      cd edit
      git --git-dir='../.git-edit' reset HEAD~1; false
    }
}

CMD="$1"
[ -z "$CMD" ] && usage
shift

case "$CMD" in
  diff)
    diff
    ;;

  publish)
    publish "$1"
    ;;

  *)
    usage

esac

exit 0

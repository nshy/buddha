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
  rebase                        Rebase editor work onto upstream
END
  exit 1
}

function git_edit()
{
  git --git-dir='.git-edit' --work-tree='edit' "$@"
}

function git_edit_cwd()
{
  (cd edit; git --git-dir='../.git-edit' "$@")
}

function git_main()
{
  git --git-dir='main/.git' --work-tree='main' "$@"
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
  git_main pull --ff-only edit master || { git_edit_cwd reset HEAD~1; false; }
}

function rebase()
{
  add
  git_edit commit -m "REBASE COMMIT"
  git_edit pull -r || { git_edit_cwd rebase --abort; }
  git_edit_cwd reset HEAD~1
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
  rebase)
    rebase
    ;;

  *)
    usage

esac

exit 0

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
  reset                         Reset editor work
  log                           Show upstream commits not in editor branch
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
  s=`git_edit status --porcelain=v1`

  # make a commit if there is anything to
  [ -n "$s" ] && git_edit commit -m "REBASE COMMIT" ||:

  git_edit pull -r || { git_edit_cwd rebase --abort; }

  # drop artificial commit if it was done before
  [ -n "$s" ] && git_edit_cwd reset HEAD~1 ||:
}

function log()
{
  git_edit_cwd fetch origin
  git_edit l ..origin/master
}

function reset()
{
  git_edit checkout .
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
  log)
    log
    ;;
  reset)
    reset
    ;;

  *)
    usage

esac

exit 0

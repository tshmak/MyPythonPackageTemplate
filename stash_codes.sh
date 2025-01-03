#!/bin/bash 
repo=$1
out=$2

[ -z "$repo" ] && echo 'Must give a git repository as $1' && exit 1
[ -z "$out" ] && echo 'Must give an output file as $2' && exit 1

set -e
current_wd=$PWD

cd $repo
latest_commit=$(git rev-parse HEAD)
echo "Latest commit: $latest_commit"
short_sha=${latest_commit:0:8}
if [ "${out:0:1}" = "/" ]
then
    output_file=$out.$short_sha.stash
else
    output_file=$current_wd/$out.$short_sha.stash
fi
anything_to_stash=$(git status --short)
if [ -n "$anything_to_stash" ] 
then
    echo "Trying to stash codes in $repo..."
    git stash --include-untracked
    anything_left=$(git status --short)
    [ -n "$anything_left" ] && git stash pop && cd $current_wd && echo "\n!!! There are untrackable contents. !!!" && exit 1 
    git stash show --include-untracked -p stash@{0} > $output_file
    git stash pop
else
    echo "Nothing to stash. Outputing empty $output_file"
    > $output_file
fi

cd $current_wd


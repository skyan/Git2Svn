#!/bin/bash

msg() {
    echo -e -n "\e[32;1m==>\e[0m "
    echo "$1"
}

stage() {
    echo
    msg "$1"
}

if [[ $# -lt 3 ]]; then
    echo "$0 <module_name> <local/remote git repo path> <remote svn repo path> [git ish]"
    exit 1
fi
module="$1"
git_path="$2"
svn_path="$3"
if [[ $# -ge 4 ]]
then
    git_ish="$4"
else
    git_ish="HEAD"
fi

stage "Create temp working space"
home_dir=$(pwd)
working_dir="${home_dir}/tmp/${module}_"`date +%s%N`
echo "Working dir: ${working_dir}"
trap "echo 'Cleaning working dir' && rm -rf $working_dir" EXIT
mkdir -p $working_dir || exit 1

stage "Clone git repo"
git_dir="${working_dir}/${module}.git"
git clone $git_path $git_dir || exit 1

stage "Checkout svn repo"
svn_dir="${working_dir}/""$(echo $svn_path | sed 's,http\w*://,,' | sed 's,trunk/,,')"
mkdir -p $svn_dir && svn co $svn_path $svn_dir || exit 1

cd $svn_dir && AUTO_COMMIT=y sh $home_dir/sync-from-git.sh $git_dir $git_ish || exit 1

exit 0


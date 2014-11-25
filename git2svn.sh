#!/bin/bash

msg() {
    echo -e -n "\e[32;1m==>\e[0m "
    echo "$1"
}

stage() {
    echo
    msg "$1"
}

help() {
    echo "Usage:"
    echo "$0 [-r git_revision] [-t type] [-u svn_user] [-p svn_password] [-l locale] <local/remote git repo path> <remote svn repo path>"
    exit 1
}

git_ish="HEAD"
build_type=""
svn_user=""
svn_pwd=""
locale=""

while getopts ":r:t:u:p:l:" Option; do
    case $Option in
        r ) git_ish=$OPTARG;;
	t ) build_type=$OPTARG;;
	u ) svn_user=$OPTARG;;
	p ) svn_pwd=$OPTARG;;
	l ) locale=$OPTARG;;
	* ) help;;
    esac
done

shift $(($OPTIND - 1))

if [ $# -ne 2 ]; then
  help
fi

git_path="$1"
svn_path="$2"
module=$(basename $git_path)

stage "Create temp working space"
home_dir=$(pwd)
working_dir="${home_dir}/tmp/${module}."`date +%Y%m%d-%H%M%S.%N`
echo "Working dir: ${working_dir}"
trap "echo 'Cleaning working dir' && rm -rf $working_dir" EXIT
mkdir -p $working_dir || exit 1

stage "Clone git repo"
git_dir="${working_dir}/${module}"
git clone $git_path $git_dir || exit 1

stage "Checkout svn repo"
if [[ "$build_type" == "go" ]]; then
    gopath="${working_dir}/gopath"
    svn_dir="${gopath}/src/""$(echo $git_path | sed 's,http\w*://,,' | sed 's,.git$,,')"
    export GOPATH=$gopath
else
    svn_dir="${working_dir}/""$(echo $svn_path | sed 's,http\w*://,,' | sed 's,trunk/,,')"
fi
mkdir -p $svn_dir && svn co $svn_path $svn_dir || exit 1

cd $svn_dir && source $home_dir/sync-from-git.sh -r "$git_ish" -u "$svn_user" -p "$svn_pwd" -a -l "$locale" $git_dir  || exit 1

exit 0


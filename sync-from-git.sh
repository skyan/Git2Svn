#!/bin/bash

help() {
    echo "Usage:"
    echo "$0 [-r git_revision] [-u svn_user] [-p svn_password] [-a] [-l locale] <path to git repository> "
    echo ""
    echo "Options:"
    echo "  -a  :  automatic commit without interactive"
    exit 1
}

msg() {
    echo -e -n "\e[32;1m==>\e[0m "
    echo "$1"
}

stage() {
    echo
    msg "$1"
}

git_ish="HEAD"
autoci=0
locale="en_US.UTF-8"

while getopts ":r:u:p:al:" Option; do
    case $Option in
        r ) git_ish=$OPTARG;;
        u ) svn_user=$OPTARG;;
        p ) svn_pwd=$OPTARG;;
        a ) autoci=1;;
	l ) 
	if [ ! -z $OPTARG ]; then
	    locale=$OPTARG
	fi
	;;
        * ) help;;
    esac
done

shift $(($OPTIND - 1))

if [ $# -ne 1 ]; then
    help
fi

module_path="$1"

usr_pwd="--non-interactive --no-auth-cache --trust-server-cert "
if [[ ! -z $svn_user ]]; then
usr_pwd=$usr_pwd"--username $svn_user "
fi

if [[ ! -z $svn_pwd ]]; then
usr_pwd=$usr_pwd"--password $svn_pwd "
fi

########################################
stage "Clean svn workspace"
svn revert -R .

########################################
stage "Sync target"
(GIT_DIR=$module_path/.git git log $git_ish -1) || exit 1

########################################
stage "Sync modification"
git_exported_dir=`mktemp -d`
trap "rm -rf $git_exported_dir" EXIT
(GIT_DIR=$module_path/.git git archive $git_ish | (cd $git_exported_dir && tar xf -)) || exit 1

if [[ -a $module_path/.git2svnignore ]]; then
    exclude_from_param="--exclude-from=$module_path/.git2svnignore"
    echo "has .git2svnignore"
else
    exclude_from_param=''
    echo "no .git2svnignore"
fi
rsync -av --delete --exclude=.svn --exclude=.git --exclude=.gitignore --exclude=.git2svnignore --exclude=GIT_COMMIT --exclude=git2svn-hook* $exclude_from_param $git_exported_dir/ . || exit 1

rm -rf $git_exported_dir
trap - EXIT

########################################
stage "Sync add/rm files"
svn status | grep "^!" | cut -c 9- | xargs --no-run-if-empty svn rm
svn status --no-ignore | grep -E "^(?|I)" | cut -c 9- | xargs --no-run-if-empty svn add --parents

########################################
stage "Update GIT_COMMIT"
GIT_DIR=$module_path/.git git rev-parse --short $git_ish > ./GIT_COMMIT
test $(svn list|grep '^GIT_COMMIT$'|wc -l) -gt 0 || svn add ./GIT_COMMIT

########################################
stage "Hook pre-commit"
if [[ -a $module_path/git2svn-hook-pre-commit ]]; then
    trap "echo 'Hook(pre-commit) failed'" EXIT
    $module_path/git2svn-hook-pre-commit || exit 1
    trap - EXIT
fi

########################################
stage "Check SVN status"
svn status --no-ignore

########################################
stage "Commit message"
svn_commit_msg=`mktemp`
trap "rm -f $svn_commit_msg" EXIT
echo "Sync from git repository" >> $svn_commit_msg
echo >> $svn_commit_msg
echo "LAST COMMIT:" >> $svn_commit_msg
GIT_DIR=$module_path/.git git log $git_ish -1 >> $svn_commit_msg
cat $svn_commit_msg

########################################
if [ "$autoci" -eq 0 ]; then 
    stage "Commit? [y/n]"
    echo -e -n "\e[33;1m==>\e[0m "
    read
    if [[ -z "$REPLY" || "$REPLY" == "Y" || "$REPLY" == "y" ]]; then
        LC_ALL="" LC_CTYPE=$locale svn commit $usr_pwd -F $svn_commit_msg || exit 1
    fi
else
    stage "Commit"
    LC_ALL="" LC_CTYPE=$locale svn commit $usr_pwd -F $svn_commit_msg || exit 1
fi

rm -f $svn_commit_msg

########################################
stage "Clean empty and non-submodule directory with only .svn"
SUBMODULES=$(GIT_DIR=$module_path/.git git submodule status|cut -d " " -f 2)
for i in $(seq 1 32); do # max 32 depths
    svn up
    cmds=$(find . -name .svn -type d | while read ss; do dir=$(dirname "$ss"); test $(ls -a "$dir" | wc -l) == 3 && test $(expr match "$SUBMODULES" "${dir#./}") == 0 && echo "svn rm $dir"; done)
    if [[ -z "$cmds" ]]; then
        break
    fi
    echo "$cmds"
    $cmds
    svn commit $usr_pwd -m 'clean empty directories'
done

########################################
stage "Done"
trap - EXIT

exit 0


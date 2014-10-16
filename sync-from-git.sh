#!/bin/bash

if [[ $# != 1 && $# != 2 ]]
then
    echo "$0 <path to git repository> [tree-ish]"
    exit 1
fi

msg() {
    echo -e -n "\e[32;1m==>\e[0m "
    echo "$1"
}

stage() {
    echo
    msg "$1"
}

module_path="$1"
if [[ -z "$2" ]]
then
    git_ish="HEAD"
else
    git_ish="$2"
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
([[ -a $module_path/git2svn-hook-pre-commit ]] && $module_path/git2svn-hook-pre-commit) || (echo "hook failed";  exit 1)

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
if [[ -z "$AUTO_COMMIT" ]]; then # AUTO_COMMIT from environment variable
    stage "Commit? [y/n]"
    echo -e -n "\e[33;1m==>\e[0m "
    read
    if [[ -z "$REPLY" || "$REPLY" == "Y" || "$REPLY" == "y" ]]; then
        LC_ALL="" LC_CTYPE="zh_CN.GB18030" svn commit -F $SVN_COMMIT_MSG || exit 1
    fi
else
    stage "Commit"
    LC_ALL="" LC_CTYPE="zh_CN.GB18030" svn commit -F $svn_commit_msg || exit 1
fi

rm -f $svn_commit_msg

########################################
stage "Clean empty directory with only .svn"
for i in $(seq 1 32); do # max 32 depths
    svn up
    cmds=$(find . -name .svn -type d | while read ss; do dir=$(dirname "$ss"); test $(ls -a "$dir" | wc -l) == 3 && echo "svn rm $dir;"; done)
    if [[ -z "$cmds" ]]; then
        break
    fi
    echo "$cmds"
    $cmds
    svn commit -m 'clean empty directories'
done

########################################
stage "Done"
trap - EXIT

exit 0


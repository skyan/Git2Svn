# git2svn

提供git到svn的单向同步。

## 功能

目前支持：

+ git单向同步到svn的bash脚本
+ gitlab的webhook，目前只会将master上的commit同步到svn
+ 支持.git2svnignore文件，同步时忽略某些文件
+ hook, 目前支持pre-commit hook，在提交前执行自定义操作，如生成Makefile，或二进制发布

## bansh同步脚本

使用方法：

./git2svn.sh <module_name> <local/remote git repo path> <remote svn repo path> [git ish]

依赖：

1. subversion, 并且需要该账号有svn登录后保留验证信息。
2. git，需要添加git的ssh key

## gitlab webhook

1. 在webserver上部署git2svn的所有文件
2. 在gitlab->settings->webhook中增加hook的地址：

    http://<hostname>/git2svn/gitlab-webhook-sync.php?svn_path=<svn_path>
    如：
    http://abc.com/git2svn/gitlab-webhook-sync.php?svn_path=https://svn.xyz.com/foo/trunk/bar/
    
注意事项：
为避免配置错误，现在要求git模块的名称和svn里模块的名称（url中最后一段）一致。

## .git2svnignore

git2svn内部使用rsync支持的--exclude-from，格式与其相同。

支持通配符。

默认会exclude一下文件或目录：.git, .svn, .gitignore, .git2svnignore

## hook

### pre-commit

使用方法:

在模块的根目录下放置git2svn-hook-pre-commit文件，并加入自定义命令。

+ 可以支持各种语言，前提是中转机器上需要支持。
+ 需要有可执行权限。
+ 如果hook执行失败（返回码非0），会中断本次同步。


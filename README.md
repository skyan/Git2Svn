# git2svn

提供git到svn的单向同步，基于[HikoQiu/Git2Svn](https://github.com/HikoQiu/Git2Svn)代码，但做了一些改进，支持更多参数，

## bash同步脚本

使用方法：

> ./git2svn.sh [-r git_revision] [-t type] [-u svn_user] [-p svn_password] [-l locale] <local/remote git repo path> <remote svn repo path> 

其中:

- type参数目前只支持go，如果是golang开发的项目，需要加上这个参数
- git_revision参数可以指定git版本，默认为HEAD

目前只支持从git主干同步到svn目标地址，同时需要git已经配置好ssh密钥

例子：
> ./git2svn.sh -u svn -p svn g@gitlab.awesomesite.com:/myproject https://svn.awesomesite.com/myproject

## Webhook 脚本

这个脚本目前还在修改中。。。


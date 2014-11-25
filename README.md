# git2svn

提供git到svn的单向同步，基于[https://github.com/HikoQiu/Git2Svn][HikoQiu/Git2Svn]代码，但做了一些改进，支持更多参数，

## bash同步脚本

使用方法：

> ./git2svn.sh [-r gitrevision] [-t type] [-u svnuser] [-p svnpassword] [-l locale] <local/remote git repo path> <remote svn repo path> 

其中type参数目前只支持go，如果是golang开发的项目，需要加上这个参数

## Webhook 脚本

这个脚本目前还在修改中。。。


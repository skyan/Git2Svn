<?php

function _log($msg) {
    $path = dirname(__FILE__).'/log/gitlab-webhook-sync.log';
    $msg = date('Ymd-His') . ' ' . $msg . "\n";
    file_put_contents($path, $msg, FILE_APPEND | LOCK_EX);
}

function log_notice($msg) {
    _log("NOTICE " . $msg);
}

function log_debug($msg) {
    _log("DEBUG " . $msg);
}

function log_warning($msg) {
    _log("WARNING " . $msg);
}

function get_commit_info() {
    // use php://input to read post data from gitlab, $_POST will not working
    $raw_input = file_get_contents("php://input");
    //$raw_input = (!empty($raw_input)) ? $raw_input : $HTTP_RAW_POST_DATA;
    //log_notice($raw_input);

    $commit_info = json_decode($raw_input, true);
    log_debug(print_r($commit_info, true));
    return $commit_info;
}

function get_info() {
    $info = array();

    $info['commit_info'] = get_commit_info();

    $info['module'] = !empty($_GET['module']) ? $_GET['module'] : $info['commit_info']['repository']['name'];
    $info['git_homepage'] = @$info['commit_info']['repository']['homepage'];
    if (!empty($info['git_homepage'])) {
       $info['git_path'] = $info['git_homepage'] . ".git";
    }
    $info['svn_path'] = @$_GET['svn_path'];

    return $info;
}

function process($info) {
    $commit_info = $info['commit_info'];
    $module = $info['module'];
    $git_path = $info['git_path'];
    $svn_path = $info['svn_path'];

    if (empty($module) || empty($git_path) || empty($svn_path)) {
        log_warning(sprintf("some parameter is invalid. "
            . "module[%s] git_path[%s] svn_path[%s]",
            $module, $git_path, $svn_path));
        return false;
    }

    $svn_path_name = basename($svn_path);
    if ($svn_path_name != $module) {
        log_warning("svn module does not match git module",
            $svn_path_name, $module);
        return false;
    }

    if ($commit_info['ref'] != 'refs/heads/master') {
        log_debug("omit non master commit");
        return true;
    }

    $pwd = dirname(__FILE__);
    $cmd = "(source ~/.bashrc && cd {$pwd} && nohup ./git2svn.sh {$module} {$git_path} {$svn_path}) >./log/job.$$.log 2>&1 & echo $!";
    exec($cmd, $output, $ret);
    log_debug(sprintf("start background sync script. cmd[%s] ret[%s] job-pid[%s]",
        $cmd, $ret, $output[0]));
    if ($ret == 0) {
        return true;
    } else {
        return false;
    }
}

function run() {
    $info = get_info();

    $result = process($info);
    log_notice(sprintf("hook triggered at repository[%s] ref[%s] by %s, svn[%s], result[%s]",
        $info['git_path'],
        $info['commit_info']['ref'],
        $info['commit_info']['user_name'],
        $info['svn_path'],
        $result ? 'succeed' : 'failed'
    ));
}

run();

?>

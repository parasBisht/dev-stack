<?php

function adminer_object() {
    include_once '/var/www/html/plugins/login-servers.php';

    $server = getenv('ADMINER_DEFAULT_SERVER') ?: 'mysql';

    $plugins = [
        new AdminerLoginServers([$server => ['server' => $server, 'driver' => 'server']]),
    ];

    class AdminerSoftware extends Adminer\Plugins {}

    return new AdminerSoftware($plugins);
}

include 'adminer.php';

#!/usr/bin/perl -w
#
# PerlMonks index.pl - mod_perl entry point
#
# This is the main entry point for the PerlMonks application.
# It bootstraps the Everything engine and handles all requests.
#

# Clean up SCRIPT_NAME in case of weird Apache config
$ENV{SCRIPT_NAME} =~ s/^\/+/\// if $ENV{SCRIPT_NAME};

use strict;
use warnings;

# Set timezone to UTC
$ENV{TZ} = '+0000';

# Try to load and bootstrap the Everything engine
eval {
    require Everything::HTML;
    Everything::HTML->import();

    # Bootstrap the application
    # The database name 'perlmonks' is mapped to 'perlmonk_ebase' in NodeBase.pm
    mod_perlInit('perlmonks');
};

# If the engine failed to load, show a diagnostic page
if ($@) {
    my $error = $@;
    print "Content-Type: text/html; charset=utf-8\n\n";
    print qq{<!DOCTYPE html>
<html>
<head>
    <title>PerlMonks - Bootstrap Error</title>
    <style>
        body { font-family: sans-serif; margin: 40px; background: #f5f5f5; }
        h1 { color: #990000; }
        .error-box { background: #fff; padding: 20px; border: 1px solid #ddd; border-radius: 5px; margin: 20px 0; }
        .error { color: #990000; font-family: monospace; white-space: pre-wrap; word-wrap: break-word; }
        .info { background: #e8f4e8; padding: 15px; border-radius: 5px; margin-top: 20px; }
        h3 { margin-top: 0; }
        code { background: #e0e0e0; padding: 2px 6px; }
    </style>
</head>
<body>
    <h1>PerlMonks Bootstrap Error</h1>

    <div class="error-box">
        <h3>Error Details</h3>
        <pre class="error">$error</pre>
    </div>

    <div class="info">
        <h3>Troubleshooting</h3>
        <ul>
            <li>Check that the database container is running: <code>docker ps | grep pmdevdb</code></li>
            <li>Check database connectivity: <code>mysql -h pmdevdb -u pmuser -ppmpass perlmonks</code></li>
            <li>Check Apache error logs: <code>/var/log/everything/apache_error.log</code></li>
            <li>Verify PERL5LIB includes ecore: <code>echo \$PERL5LIB</code></li>
        </ul>

        <h3>Environment</h3>
        <ul>
            <li><strong>Perl:</strong> $^V</li>
            <li><strong>PERL5LIB:</strong> } . ($ENV{PERL5LIB} || 'not set') . qq{</li>
            <li><strong>PM_DBHOST:</strong> } . ($ENV{PM_DBHOST} || 'not set') . qq{</li>
            <li><strong>PM_ENVIRONMENT:</strong> } . ($ENV{PM_ENVIRONMENT} || 'not set') . qq{</li>
        </ul>
    </div>

    <p><small>Generated at } . scalar(localtime()) . qq{</small></p>
</body>
</html>
};
}

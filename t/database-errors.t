use strict;
use warnings;
use FindBin;
use Test::More;
use lib "$FindBin::Bin/..";

BEGIN {
	$INC{'DBI.pm'} = __FILE__;
	}

package DBI;

sub import
{
}

sub install_driver
{
die $DBI::install_error if ($DBI::install_error);
return bless({ }, 'MockDriver');
}

package MockDriver;

sub connect
{
my ($self, $dsn, $user, $pass, $attrs) = @_;
$DBI::connect_attributes = { %$attrs };
$_[0]->{'errstr'} = 'mock database connection failed';
return undef;
}

sub errstr
{
return $_[0]->{'errstr'};
}

package main;

our (%config, %text, @first_messages, @second_messages,
     $module_config_directory, $module_root_directory);
$module_config_directory = '/unused/config';
$module_root_directory = '/unused/module';
%config = (
	'db' => 'powerdns',
	'host' => 'localhost',
	'user' => 'powerdns',
	'pass' => 'secret',
	);
%text = (
	'backup_dom' => 'Backing up PowerDNS database entries for domain ..',
	'feat_edb' => 'An error occurred connecting to the MySQL database : $1',
	'restore_dom' => 'Restoring PowerDNS database entries for domain ..',
	);

sub init_config
{
}

sub text
{
my ($key, @args) = @_;
my $msg = $text{$key};
for(my $i = 0; $i < @args; $i++) {
	my $n = $i + 1;
	$msg =~ s/\$$n/$args[$i]/g;
	}
return $msg;
}

package virtual_server;

our $first_print = sub { push(@main::first_messages, @_); };
our $second_print = sub { push(@main::second_messages, @_); };
our %text = ( 'setup_done' => '.. done' );

package main;

require "$FindBin::Bin/../virtual_feature.pl";

{
local $DBI::install_error =
	"mock driver load failed at (eval 42) line 3.\ninternal detail\n";
my ($missing_dbh, $missing_err) = connect_to_database();
ok(!defined($missing_dbh), 'database driver failure returns no handle');
is($missing_err, 'mock driver load failed',
	'database driver failure omits Perl internals');
}

my ($dbh, $err) = connect_to_database();
ok(!defined($dbh), 'database connection failure returns no handle');
is($err, 'mock database connection failed',
	'database connection failure preserves the DBI error');
is($DBI::connect_attributes->{'PrintError'}, 1,
	'connected handles keep DBI statement errors visible');

my $scalar_dbh = connect_to_database();
ok(!defined($scalar_dbh),
	'scalar database connection failure returns no handle');

my $domain = { 'dom' => 'example.test' };
my $backup_ok;
my $backup_eval = eval {
	$backup_ok = feature_backup($domain, '/unused', { }, { });
	1;
	};
ok($backup_eval, 'backup does not die when the database is unavailable');
is($backup_ok, 0, 'backup reports failure when the database is unavailable');
is_deeply(\@first_messages,
	[ 'Backing up PowerDNS database entries for domain ..' ],
	'backup prints its operation before the connection error');
is_deeply(\@second_messages,
	[ 'An error occurred connecting to the MySQL database : '.
	  'mock database connection failed' ],
	'backup prints the underlying database connection error');

@first_messages = ( );
@second_messages = ( );
my $restore_ok;
my $restore_eval = eval {
	$restore_ok = feature_restore($domain, '/unused', { }, { });
	1;
	};
ok($restore_eval, 'restore does not die when the database is unavailable');
is($restore_ok, 0, 'restore reports failure when the database is unavailable');
is_deeply(\@first_messages,
	[ 'Restoring PowerDNS database entries for domain ..' ],
	'restore prints its operation before the connection error');
is_deeply(\@second_messages,
	[ 'An error occurred connecting to the MySQL database : '.
	  'mock database connection failed' ],
	'restore prints the underlying database connection error');

done_testing();

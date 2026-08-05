use strict;
use warnings;
our (%config);
our $module_config_directory;
our $module_root_directory;

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();

# clean_powerdns_database_error(error)
# Remove Perl source locations from errors before displaying them to users.
sub clean_powerdns_database_error
{
my ($err) = @_;
$err ||= "Unknown error";
$err =~ s/\s+at\s+(?:\(eval\s+\d+\)|\S+)\s+line\s+\d+.*$//s;
return $err;
}

# connect_to_database()
sub connect_to_database
{
eval "use DBI;";
if ($@) {
	my $err = &clean_powerdns_database_error($@);
	return wantarray ? (undef, $err) : undef;
	}
my ($dbh, $err, $drh);
eval {
	$drh = DBI->install_driver("mysql");
	$dbh = $drh->connect("database=$config{'db'}".
			     ($config{'host'} ? ";host=$config{'host'}" : ""),
			     $config{'user'}, $config{'pass'},
			     { 'PrintError' => 1 });
	};
my $eval_err = $@;
if ($eval_err || !$dbh) {
	my $driver_err = $drh ? $drh->errstr : undef;
	$err = $eval_err || $driver_err || "Unknown error";
	}
$err = &clean_powerdns_database_error($err) if ($err);
return wantarray ? ($dbh, $err) : $dbh;
}

our $template_file = "$module_config_directory/template";

# get_template()
# Returns an array of current record templates
sub get_template
{
my @rv;
open(my $FILE, "<", -r $template_file ? $template_file
			     : "$module_root_directory/default-template");
while(<$FILE>) {
	s/\r|\n//g;
	my @f = split(/\t+/, $_);
	if (@f == 4) {
		push(@rv, { 'name' => $f[0],
			    'type' => $f[1],
			    'ttl' => $f[2],
			    'value' => $f[3] });
		}
	}
close($FILE);
return @rv;
}

# save_template(value, ...)
# Updates the template file
sub save_template
{
open(my $FILE, ">", "$template_file");
foreach my $f (@_) {
	print $FILE join("\t", $f->{'name'}, $f->{'type'},
			      $f->{'ttl'}, $f->{'value'}),"\n";
	}
close($FILE);
}

# domain_id(&dbh, name)
sub domain_id
{
my $idcmd = $_[0]->prepare("select id from domains where name = ? and type = 'NATIVE'");
$idcmd->execute($_[1]);
my ($id) = $idcmd->fetchrow();
$idcmd->finish();
return $id;
}

1;

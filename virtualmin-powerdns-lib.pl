
do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
use DBI;

# connect_to_database()
sub connect_to_database
{
local ($dbh, $err);
eval {
	local $drh = DBI->install_driver("mysql");
	$dbh = $drh->connect("database=$config{'db'}".
			     ($config{'host'} ? ";host=$config{'host'}" : ""),
			     $config{'user'}, $config{'pass'}, { });
	};
if ($@ || !$dbh) {
	$err = $@ || "unknown error";
	}
$err =~ s/\s+at\s+.*//;
return wantarray ? ($dbh, $err) : $dbh;
}

$template_file = "$module_config_directory/template";

# get_template()
# Returns an array of current record templates
sub get_template
{
local @rv;
open(FILE, -r $template_file ? $template_file
			     : "$module_root_directory/default-template");
while(<FILE>) {
	s/\r|\n//g;
	local @f = split(/\t+/, $_);
	if (@f == 4) {
		push(@rv, { 'name' => $f[0],
			    'type' => $f[1],
			    'ttl' => $f[2],
			    'value' => $f[3] });
		}
	}
close(FILE);
return @rv;
}

# save_template(value, ...)
# Updates the template file
sub save_template
{
open(FILE, ">$template_file");
local $f;
foreach $f (@_) {
	print FILE join("\t", $f->{'name'}, $f->{'type'},
			      $f->{'ttl'}, $f->{'value'}),"\n";
	}
close(FILE);
}

# domain_id(&dbh, name)
sub domain_id
{
local $idcmd = $_[0]->prepare("select id from domains where name = ? and type = 'NATIVE'");
$idcmd->execute($_[1]);
my ($id) = $idcmd->fetchrow();
$idcmd->finish();
return $id;
}

1;


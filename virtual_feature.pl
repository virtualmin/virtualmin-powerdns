# Defines functions for this feature
use strict;
use warnings;
our (%text);

require 'virtualmin-powerdns-lib.pl';

# feature_name()
# Returns a short name for this feature
sub feature_name
{
return $text{'feat_name'};
}

# feature_losing(&domain)
# Returns a description of what will be deleted when this feature is removed
sub feature_losing
{
return $text{'feat_losing'};
}

# feature_disname(&domain)
# Returns a description of what will be turned off when this feature is disabled
sub feature_disname
{
return $text{'feat_disname'};
}

# feature_label(in-edit-form)
# Returns the name of this feature, as displayed on the domain creation and
# editing form
sub feature_label
{
my ($edit) = @_;
return $edit ? $text{'feat_label2'} : $text{'feat_label'};
}

sub feature_hlink
{
return "label";
}

# feature_check()
# Returns undef if all the needed programs for this feature are installed,
# or an error message if not
sub feature_check
{
my ($dbh, $err) = &connect_to_database();
if (!$dbh) {
	return &text('feat_edb', $err);
	}
foreach my $tn ("domains", "records") {
	eval {
		my $tcmd = $dbh->prepare("select count(*) from $tn");
		$tcmd->execute();
		$tcmd->finish();
		};
	if ($@) {
		return &text('feat_etable', "<tt>$tn</tt>");
		}
	}
$dbh->disconnect();
return undef;
}

# feature_depends(&domain)
# Returns undef if all pre-requisite features for this domain are enabled,
# or an error message if not
sub feature_depends
{
return undef;
}

# feature_clash(&domain)
# Returns undef if there is no clash for this domain for this feature, or
# an error message if so
sub feature_clash
{
my ($d, $field) = @_;
if (!$field || $field eq 'dom') {
	# Clash checking disabled, as we can replace existing domains
	#my $dbh = &connect_to_database();
	#my $cmd = $dbh->prepare("select name from domains where name = ? and type = 'NATIVE'");
	#$cmd->execute($_[0]->{'dom'});
	#my ($clash) = $cmd->fetchrow();
	#$cmd->finish();
	#$dbh->disconnect();
	#return $clash ? &text('feat_clash') : undef;
	}
return undef;
}

# feature_suitable([&parentdom], [&aliasdom])
# Returns 1 if some feature can be used with the specified alias and
# parent domains
sub feature_suitable
{
return 1;
}

# feature_setup(&domain)
# Called when this feature is added, with the domain object as a parameter
sub feature_setup
{
&$virtual_server::first_print($text{'setup_dom'});

# Check if already there
my $dbh = &connect_to_database();
my $id = &domain_id($dbh, $_[0]->{'dom'});
if ($id) {
	# Yes! Just update IPs
	my $newip = $_[0]->{'dns_ip'} || $_[0]->{'ip'};
	my $fixcmd = $dbh->prepare("update records set content = ? where domain_id = ? and type = 'A'");
	$fixcmd->execute($newip, $id);
	$fixcmd->finish();
	&$virtual_server::second_print($text{'setup_fixed'});
	}
else {
	# Add the domain
	my $domcmd = $dbh->prepare("insert into domains (name, type) values (?, 'NATIVE')");
	$domcmd->execute($_[0]->{'dom'});
	$domcmd->finish();
	&increment_domain_seq($dbh);

	# Find its ID
	$id = &domain_id($dbh, $_[0]->{'dom'});

	# Add the records
	my $reccmd = $dbh->prepare("insert into records (domain_id, name, type, ttl, prio, content) values (?, ?, ?, ?, ?, ?)");
	foreach my $r (&get_template()) {
		my $v = &virtual_server::substitute_template(
				$r->{'value'}, $_[0]);
		my $prio = 0;
		if (uc($r->{'type'}) eq 'MX' &&
		    $v =~ /^(\d+)\s+(\S+)$/) {
			# Split up MX priority and hostname
			$prio = $1;
			$v = $2;
			}
		$reccmd->execute(
			$id,
			&virtual_server::substitute_template($r->{'name'},
							     $_[0]),
			$r->{'type'},
			$r->{'ttl'},
			$prio,
			$v,
			);
		$reccmd->finish();
		}
	$reccmd->finish();
	&bump_domain_soa($dbh, $id);
	&increment_record_seq($dbh);
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}
$dbh->disconnect();
}

# feature_modify(&domain, &olddomain)
# Called when a domain with this feature is modified
sub feature_modify
{
my $dbh = &connect_to_database();
if ($_[0]->{'dom'} ne $_[1]->{'dom'}) {
	# Domain has been re-named .. update domain entry and all records
	&$virtual_server::first_print($text{'save_dom'});
	my $id = &domain_id($dbh, $_[1]->{'dom'});
	if ($id) {
		my $rencmd = $dbh->prepare("update domains set name = ? where id = ?");
		$rencmd->execute($_[0]->{'dom'}, $id);
		$rencmd->finish();
		my $reccmd = $dbh->prepare("select id,name,content from records where domain_id = ?");
		$reccmd->execute($id);
		my $fixcmd = $dbh->prepare("update records set name = ?, content = ? where id = ? and domain_id = ?");
		while(my ($recid, $name, $content) = $reccmd->fetchrow()) {
			$name =~ s/$_[1]->{'dom'}$/$_[0]->{'dom'}/g;
			$content =~ s/$_[1]->{'dom'}/$_[0]->{'dom'}/g;
			$fixcmd->execute($name, $content, $recid, $id);
			$fixcmd->finish();
			}
		$reccmd->finish();
		&bump_domain_soa($dbh, $id);
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}
	else {
		&$virtual_server::second_print($text{'delete_missing'});
		}
	}
my $newip = $_[0]->{'dns_ip'} || $_[0]->{'ip'};
my $oldip = $_[1]->{'dns_ip'} || $_[1]->{'ip'};
if ($newip ne $oldip) {
	# IP has changed .. update all records
	&$virtual_server::first_print($text{'save_dom'});
	my $id = &domain_id($dbh, $_[0]->{'dom'});
	if ($id) {
		my $ipcmd = $dbh->prepare("update records set content = ? where domain_id = ? and content = ?");
		$ipcmd->execute($newip, $id, $oldip);
		$ipcmd->finish();
		&bump_domain_soa($dbh, $id);
		&$virtual_server::second_print(
			$virtual_server::text{'setup_done'});
		}
	else {
		&$virtual_server::second_print($text{'delete_missing'});
		}
	}
$dbh->disconnect();
}

# feature_delete(&domain)
# Called when this feature is disabled, or when the domain is being deleted
sub feature_delete
{
&$virtual_server::first_print($text{'delete_dom'});
my $dbh = &connect_to_database();
my $id = &domain_id($dbh, $_[0]->{'dom'});
if ($id) {
	# Check first if any IPs are for this sytem
	my $myipcmd =  $dbh->prepare("select count(*) from records where domain_id = ? and content = ?");
	my $ip = $_[0]->{'dns_ip'} || $_[0]->{'ip'};
	$myipcmd->execute($id, $ip);
	my ($count) = $myipcmd->fetchrow();
	$myipcmd->finish();

	if ($count) {
		# Delete the domain and records
		my $delreccmd = $dbh->prepare("delete from records where domain_id = ?");
		$delreccmd->execute($id);
		$delreccmd->finish();
		my $deldomcmd = $dbh->prepare("delete from domains where id = ?");
		$deldomcmd->execute($id);
		$deldomcmd->finish();
		&$virtual_server::second_print($virtual_server::text{'setup_done'});
		}
	else {
		&$virtual_server::second_print(
			&text('delete_notfor', $ip));
		}
	}
else {
	&$virtual_server::second_print($text{'delete_missing'});
	}
$dbh->disconnect();
}

# feature_disable(&domain)
# Called when this feature is temporarily disabled for a domain
sub feature_disable
{
# XXX does nothing
}

# feature_enable(&domain)
# Called when this feature is re-enabled for a domain
sub feature_enable
{
# XXX does nothing
}

# feature_webmin(&domain)
# Returns a list of webmin module names and ACL hash references to be set for
# the Webmin user when this feature is enabled
sub feature_webmin
{
return ( );
}

# feature_backup(&domain, file, &opts, &all-opts)
# Called to backup this feature for the domain to the given file. Must return 1
# on success or 0 on failure
sub feature_backup
{
my ($d, $file, $opts, $allopts) = @_;
my $dbh = &connect_to_database();
my $id = &domain_id($dbh, $_[0]->{'dom'});
&$virtual_server::first_print($text{'backup_dom'});
if ($id) {
	no strict "subs";
	&virtual_server::open_tempfile_as_domain_user($d, BFILE, ">$file");
	my $cmd = $dbh->prepare("select name, type, ttl, prio, content from records where domain_id = ?");
	$cmd->execute($id);
	while(my @r = $cmd->fetchrow()) {
		&print_tempfile(BFILE, join("\t", @r),"\n");
		}
	$cmd->finish();
	&virtual_server::close_tempfile_as_domain_user($d, BFILE);
	use strict "subs";
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	return 1;
	}
else {
	&$virtual_server::second_print($text{'delete_missing'});
	return 0;
	}
}

# feature_restore(&domain, file, &opts, &all-opts)
# Called to restore this feature for the domain from the given file. Must
# return 1 on success or 0 on failure
sub feature_restore
{
my ($d, $file, $opts, $allopts) = @_;
my $dbh = &connect_to_database();
my $id = &domain_id($dbh, $_[0]->{'dom'});
&$virtual_server::first_print($text{'restore_dom'});
if ($id) {
	# Remove all old records
	my $delreccmd = $dbh->prepare("delete from records where domain_id = ?");
	$delreccmd->execute($id);
	$delreccmd->finish();

	# Create new from file
	my $reccmd = $dbh->prepare("insert into records (domain_id, name, type, ttl, prio, content) values (?, ?, ?, ?, ?, ?)");
	open(my $BFILE, "<", $file);
	while(<$BFILE>) {
		s/\r|\n//g;
		my @r = split(/\t/, $_);
		$reccmd->execute($id, @r);
		$reccmd->finish();
		}
	close($BFILE);
	&increment_record_seq($dbh);
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	return 1;
	}
else {
	&$virtual_server::second_print($text{'delete_missing'});
	return 0;
	}

}

sub increment_domain_seq
{
my ($dbh) = @_;
eval {
	# Ignore failures, as some systems don't have this table
	my $inccmd = $dbh->prepare("UPDATE domains_seq SET id=(SELECT MAX(d.id) FROM domains d)");
	$inccmd->execute();
	$inccmd->finish();
	};
}

sub increment_record_seq
{
my ($dbh) = @_;
eval {
	# Ignore failures, as some systems don't have this table
	my $inccmd = $dbh->prepare("UPDATE records_seq SET id=(SELECT MAX(r.id) FROM records r)");
	$inccmd->execute();
	$inccmd->finish();
	};
}

# bump_domain_soa(&dbh, id)
# Bump the SOA by 1 in a domain
sub bump_domain_soa
{
my ($dbh, $id) = @_;
my $cmd = $dbh->prepare("select content from records where domain_id = ? and type = 'SOA'");
$cmd->execute($id);
my $content = $cmd->fetchrow();
$cmd->finish();
if ($content) {
	my @w = split(/\s+/, $content);
	$w[2]++;
	$content = join(" ", @w);
	$cmd = $dbh->prepare("update records set content = ? where domain_id = ? and type = 'SOA'");
	$cmd->execute($content, $id);
	$cmd->finish();
	}
}

1;

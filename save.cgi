#!/usr/local/bin/perl
# Save records template
use strict;
use warnings;
our (%text, %in);

require './virtualmin-powerdns-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});

my @tmpl;
my %count;
for(my $i=0; defined(my $name = $in{"name_$i"}); $i++) {
	next if (!$name);
	$name =~ /^\S+$/ || &error(&text('save_ename', $name, $i+1));
	my $type = $in{"type_$i"};
	my $ttl = $in{"ttl_$i"};
	$ttl =~ /^\d+$/ || &error(&text('save_ettl', $name, $i+1)." : $ttl");
	my $value = $in{"value_$i"};
	$value =~ /\S/ || &error(&text('save_evalue', $name, $i+1));
	push(@tmpl, { 'name' => $name,
		      'type' => $type,
		      'ttl' => $ttl,
		      'value' => $value });
	$count{$type}++;
	}
$count{'SOA'} || &error($text{'save_esoa'});
&save_template(@tmpl);
&redirect("");

#!/usr/local/bin/perl
# Save records template

require './virtualmin-powerdns-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});

for($i=0; defined($name = $in{"name_$i"}); $i++) {
	next if (!$name);
	$name =~ /^\S+$/ || &error(&text('save_ename', $name, $i+1));
	$type = $in{"type_$i"};
	$ttl = $in{"ttl_$i"};
	$ttl =~ /^\d+$/ || &error(&text('save_ettl', $name, $i+1)." : $ttl");
	$value = $in{"value_$i"};
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


#!/usr/local/bin/perl

require './virtualmin-powerdns-lib.pl';
&ui_print_header(undef, $text{'index_header'}, "", undef, 1, 1);

# Check database connection
($dbh, $err) = &connect_to_database();
if (!$dbh) {
	&ui_print_endpage(
		&ui_config_link('index_edb', [ $err, undef ]));
	}

# Show template
print "<font size=+1>$text{'index_header'}</font><br>\n";
print &ui_form_start("save.cgi", "post");
print &ui_columns_start([ $text{'index_name'},
			  $text{'index_type'},
			  $text{'index_ttl'},
			  $text{'index_value'} ]);
$i = 0;
foreach $t (&get_template(), { }, { }) {
	print &ui_columns_row([
		&ui_textbox("name_$i", $t->{'name'}, 20),
		&ui_select("type_$i", $t->{'type'},
			[ [ "A" ], [ "NS" ], [ "SOA" ], [ "MX" ],
			  [ "TXT" ], [ "CNAME" ] ]),
		&ui_textbox("ttl_$i", $t->{'ttl'}, 6),
		&ui_textbox("value_$i", $t->{'value'}, 40),
		]);
	$i++;
	}
print &ui_columns_end();
print &ui_form_end([ [ "save", $text{'index_save'} ] ]);

&ui_print_footer("/", $text{'index'});


#!/usr/local/bin/perl

require './virtualmin-powerdns-lib.pl';
&ui_print_header(undef, $text{'index_header'}, "", undef, 1, 1);

# Check database connection
($dbh, $err) = &connect_to_database();
if (!$dbh) {
	&ui_print_endpage(
		&ui_config_link('index_edb', [ $err, undef ]));
	}

# Show template DNS records
print &ui_subheading($text{'index_header'});
$i = 0;
@table = ( );
foreach $t (&get_template(), { }, { }) {
	push(@table, [
		&ui_textbox("name_$i", $t->{'name'}, 20),
		&ui_select("type_$i", $t->{'type'},
			[ [ "A" ], [ "NS" ], [ "SOA" ], [ "MX" ],
			  [ "TXT" ], [ "CNAME" ] ]),
		&ui_textbox("ttl_$i", $t->{'ttl'}, 6),
		&ui_textbox("value_$i", $t->{'value'}, 40),
		]);
	$i++;
	}
print &ui_form_columns_table(
	"save.cgi",
	[ [ "save", $text{'index_save'} ] ],
	undef,
	undef,
	undef,
	[ $text{'index_name'}, $text{'index_type'},
	  $text{'index_ttl'}, $text{'index_value'} ],
	undef,
	\@table,
	undef,
	1);

&ui_print_footer("/", $text{'index'});


#!/usr/bin/env perl

# Output MySQL objects to the file system for archiving

use strict;

use DBD::mysql;
use File::Path qw (make_path); # to make output directories
use Getopt::Std qw (getopts);
use IO::File;

my(%opts);
getopts('h:s:u:p:o:d',\%opts);

my($host, $port, $schema, $user, $password, $output_dir, $debug);

my($debug_mode) = $opts{'d'};

print STDERR "DEBUG MODE\n" if ($debug_mode);

# schema, user, and password do not have defaults
$schema   = $opts{'s'};
$user     = $opts{'u'};
$password = $opts{'p'};

if (! ($schema and $user and $password)) {
    print STDERR qq{
Usage ${0} [-h host[:port]] -s schema -u username -p password [-o output_dir] [-d]

Host and port default to "localhost:3306"
Output directory will default the current directory

All object files will be written to output_dir/schema/<object>

Pass -d to activate debugging mode, with messages to STDERR. The db
connection will be made, but no directories or files will be output

};
    exit(0);
}


# host and port parsing

$host = 'localhost';
$port =  '3306';

if ($opts{'h'} =~ /^([^:]+):?(\d+)?$/) {
    $host = $1 or 'localhost';
    $port = $2 or '3306';
    printf STDERR ("Host: %s Port: %s\n",$host,$port) if ($debug_mode);
} else {
    printf STDERR ("Using default Host: %s Port: %s\n",$host,$port) if ($debug_mode);
}

# output dir

if ($output_dir = $opts{'o'}) {
    chop($output_dir) if $output_dir =~ m{/$}; # no trailing slash, please
    $output_dir ||= '.';
    if ($debug_mode) {
	print STDERR "Would output to ${output_dir}\n";
    } else {
	make_path($output_dir);
    }
}

# db connection

my($info_dsn)  = sprintf("DBI:mysql:database=%s;host=%s;port=%s",'information_schema', $host, $port);

my($mysql_dbh, $info_dbh);

eval {
    $info_dbh = DBI->connect($info_dsn, $user, $password);
};
if ($@) {
    print STDERR "Could not connect to the `information_schema` meta database";
    die "Aborting"
}

# keys are the object types to pull out
#
# keys are:
# [db_handle, object name selection query, placeholder for prepared statement]
#
my(%objects) = ('TABLE'     => [$info_dbh,
				q{SELECT table_name
                                    FROM information_schema.tables
                                   WHERE table_schema = ?
                                   ORDER BY table_name},
				""],

		'VIEW'      => [$info_dbh,
				q{SELECT table_name
                                    FROM information_schema.views
                                   WHERE table_schema = ?
                                   ORDER BY table_name},
				""],

		'PROCEDURE' => [$info_dbh,
				q{SELECT routine_name
                                    FROM information_schema.routines
                                   WHERE routine_schema = ?
                                     AND routine_type = 'PROCEDURE'
                                   ORDER BY routine_name},
				""],

		'FUNCTION'  => [$info_dbh,
				q{SELECT routine_name
                                    FROM information_schema.routines
                                   WHERE routine_schema = ?
                                     AND routine_type = 'FUNCTION'
                                   ORDER BY routine_name},
				""]);
my($obj);

foreach (keys %objects) {
    print STDERR " Processing $_\n" if ($debug_mode);

    if (defined ($obj = $objects{$_})) {
	$obj->[2] = $obj->[0]->prepare($obj->[1]);

	if ('TABLE' eq $_) {
	    $obj->[2]->bind_param(1, $schema);
	    &process_tables($obj, $schema, $output_dir, $debug_mode);
	} elsif ('VIEW' eq $_) {
	    $obj->[2]->bind_param(1, $schema);
	    &process_views($obj, $schema, $output_dir, $debug_mode);
	} elsif ('PROCEDURE' eq $_) {
	    $obj->[2]->bind_param(1, $schema);
	    &process_procedures($obj, $schema, $output_dir, $debug_mode);
	}  elsif ('FUNCTION' eq $_) {
	    $obj->[2]->bind_param(1, $schema);
	    &process_functions($obj, $schema, $output_dir, $debug_mode);
	}
    }
}

### Output handlers

#
# TABLE
#
sub process_tables {
    my($obj, $schema, $output_dir, $debug_mode) = @_;

    my($name_query) = $obj->[2];
    $name_query->execute();

    my($show_sql) = q{SHOW CREATE TABLE %s.%s}; # built up in the while() loop
    my($table_name, $show_query, $dir, $fh);

    while (my $name = $name_query->fetchrow_arrayref()) {
	$table_name = $name->[0];

	if ($debug_mode) {
	    printf STDERR (" Found TABLE : %s.%s\n", $schema, $table_name);
	} else {
	    if (! $dir) {
		$dir = sprintf("%s/%s/%s", $output_dir, $schema, 'TABLE');
		make_path($dir);
	    }

	    $fh = new IO::File("${dir}/${table_name}.sql","w");

	    printf $fh ("# TABLE : %s.%s\n", $schema, $table_name);
	    printf $fh ("DELIMITER %s\n", q{$$});
	    printf $fh ("USE %s %s\n\n", $schema, q{$$});

	    # Cannot use a prepared statement here, since the table
	    # name will be escaped (quoted) as a string.
	    #
	    $show_query = $obj->[0]->prepare(sprintf($show_sql,$schema,$table_name));
	    $show_query->execute();

	    while (my $output = $show_query->fetchrow_arrayref()) {
		print $fh $output->[1],"\n";
	    }
	    printf $fh ("%s\n\nDELIMITER %s\n", q{$$}, q{;});

	    $fh->close();
	}

    }
}

#
# VIEW
#
sub process_views {
    my($obj, $schema, $output_dir, $debug_mode) = @_;

    my($name_query) = $obj->[2];
    $name_query->execute();

    my($show_sql) = q{SHOW CREATE VIEW %s.%s}; # built up in the while() loop
    my($view_name, $show_query, $dir, $fh);

    while (my $name = $name_query->fetchrow_arrayref()) {
	$view_name = $name->[0];

	if ($debug_mode) {
	    printf STDERR (" Found VIEW : %s.%s\n", $schema, $view_name);
	} else {
	    if (! $dir) {
		$dir = sprintf("%s/%s/%s", $output_dir, $schema, 'VIEW');
		make_path($dir);
	    }

	    $fh = new IO::File("${dir}/${view_name}.sql","w");

	    printf $fh ("# VIEW : %s.%s\n", $schema, $view_name);
	    printf $fh ("DELIMITER %s\n", q{$$});
	    printf $fh ("USE %s %s\n\n", $schema, q{$$});

	    # Cannot use a prepared statement here, since the view
	    # name will be escaped (quoted) as a string.
	    #
	    $show_query = $obj->[0]->prepare(sprintf($show_sql,$schema,$view_name));
	    $show_query->execute();

	    while (my $output = $show_query->fetchrow_arrayref()) {
		print $fh $output->[1],"\n";
	    }
	    printf $fh ("%s\n\nDELIMITER %s\n", q{$$}, q{;});

	    $fh->close();
	}

    }
}

#
# PROCEDURE
#
sub process_procedures {
    my($obj, $schema, $output_dir, $debug_mode) = @_;

    my($name_query) = $obj->[2];
    $name_query->execute();

    my($show_sql) = q{SHOW CREATE PROCEDURE %s.%s}; # built up in the while() loop
    my($procedure_name, $show_query, $dir, $fh);

    while (my $name = $name_query->fetchrow_arrayref()) {
	$procedure_name = $name->[0];

	if ($debug_mode) {
	    printf STDERR (" Found PROCEDURE : %s.%s\n", $schema, $procedure_name);
	} else {
	    if (! $dir) {
		$dir = sprintf("%s/%s/%s", $output_dir, $schema, 'PROCEDURE');
		make_path($dir);
	    }

	    $fh = new IO::File("${dir}/${procedure_name}.sql","w");

	    printf $fh ("# PROCEDURE : %s.%s\n", $schema, $procedure_name);
	    printf $fh ("DELIMITER %s\n", q{$$});
	    printf $fh ("USE %s %s\n", $schema, q{$$});
	    printf $fh ("DROP PROCEDURE IF EXISTS %s.%s %s\n\n", $schema, $procedure_name, q{$$});

	    # Cannot use a prepared statement here, since the procedure
	    # name will be escaped (quoted) as a string.
	    #
	    $show_query = $obj->[0]->prepare(sprintf($show_sql,$schema,$procedure_name));
	    $show_query->execute();

	    while (my $output = $show_query->fetchrow_arrayref()) {
		print $fh $output->[2],"\n";
	    }
	    printf $fh ("%s\n\nDELIMITER %s\n", q{$$}, q{;});

	    $fh->close();
	}

    }
}

#
# FUNCTION
#
sub process_functions {
    my($obj, $schema, $output_dir, $debug_mode) = @_;

    my($name_query) = $obj->[2];
    $name_query->execute();

    my($show_sql) = q{SHOW CREATE FUNCTION %s.%s}; # built up in the while() loop
    my($function_name, $show_query, $dir, $fh);

    while (my $name = $name_query->fetchrow_arrayref()) {
	$function_name = $name->[0];

	if ($debug_mode) {
	    printf STDERR (" Found FUNCTION : %s.%s\n", $schema, $function_name);
	} else {
	    if (! $dir) {
		$dir = sprintf("%s/%s/%s", $output_dir, $schema, 'FUNCTION');
		make_path($dir);
	    }

	    $fh = new IO::File("${dir}/${function_name}.sql","w");

	    printf $fh ("# FUNCTION : %s.%s\n", $schema, $function_name);
	    printf $fh ("DELIMITER %s\n", q{$$});
	    printf $fh ("USE %s %s\n", $schema, q{$$});
	    printf $fh ("DROP FUNCTION IF EXISTS %s.%s %s\n\n", $schema, $function_name, q{$$});

	    # Cannot use a prepared statement here, since the function
	    # name will be escaped (quoted) as a string.
	    #
	    $show_query = $obj->[0]->prepare(sprintf($show_sql,$schema,$function_name));
	    $show_query->execute();

	    while (my $output = $show_query->fetchrow_arrayref()) {
		print $fh $output->[2],"\n";
	    }
	    printf $fh ("%s\n\nDELIMITER %s\n", q{$$}, q{;});

	    $fh->close();
	}

    }
}

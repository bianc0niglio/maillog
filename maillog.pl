#!/usr/bin/perl
# Mail log analyzer
# Ver 1.7.b
#
# Copyright (C) 2010 Alexander Sokoloff <asokol@mail.ru>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.

# Usage: maillog [-d DATE] [-f FROM] [-t TO] [-e] [-h] [-V]
#
# Shows entries in the mail log for letters coming from the FROM address to
# TO address for the period specified in the DATE option.
#
# -f FROM sender's email address (or part of it).
#
# -t TO recipient's mailing address (or part of it).
#
# -d DATE print a report for the specified period if the option is omitted
# Only records for the current day are displayed.
#
# DD/MM/YY-DD/MM/YY Full format:
# -DD/MM/YY Start date missing:
# records from January 1, 1970 will be shown.
# DD/MM/YY- Missing end date:
# records up to the current date will be shown.
# - Both start and end dates are missing:
# will show entries from January 1, 1970 to
# current date.
#
# -e show only undelivered messages.
#
# -h show help page.
#
# -V show the program version and license.

# Settings ###################################################################

my $filePattern='/var/log/mail*.{info,info.*}';
my $LESS="less -S -R --shift=1";

use strict;
use Time::Local;


# Set constants ***************************************************************
my $DAY=3; my $MON=4; my $YEAR=5;
my %MONTHS=('Jan'=>0,'Feb'=>1,'Mar'=>2,'Apr'=>3,'May'=>4,'Jun'=>5,'Jul'=>6,'Aug'=>7,'Sep'=>8,'Oct'=>9,'Nov'=>10,'Dec'=>11);


# Set default values **********************************************************
my @now=localtime();
my $bDate= timelocal(0,  0,  0,  $now[$DAY], $now[$MON], $now[$YEAR]);
my $eDate= timelocal(59, 59, 23, $now[$DAY], $now[$MON], $now[$YEAR]);

my $from='';
my $to='';
my $errors=0;
my $verbose=0;
my $stat=0;

my %msgs;
my $optLimit = 0; # For scan optimization

my $STATUS_OK = 0;
my $STATUS_ERR = 1;

my $COLOR_NORM="\e[0;39m";
my $COLOR_SUBJ="\e[1;32m";
my $COLOR_TO="\e[0;36m";
my $COLOR_FROM="\e[0;33m";
my $COLOR_OK="\e[0;32m";
my $COLOR_BOUNCE="\e[0;31m";


param(@ARGV);

scan($filePattern, $bDate, $eDate);

clean();

printResults();

exit;




#*******************************************************************************
# Main scan function
#*******************************************************************************
sub scan
{
    my $pattern = $_[0];
    my @lt = localtime($_[1]);
    my $start = sprintf("%02d%02d", $lt[$MON], $lt[$DAY]);
    @lt = localtime($_[2]);
    my $stop  = sprintf("%02d%02d", $lt[$MON], $lt[$DAY]);

    foreach my $file (sort{$b cmp $a}(glob($pattern)))
    {
        scanFile($file, $start, $stop);
    }

}


#*******************************************************************************
# Scan single file
#*******************************************************************************
sub scanFile
{
    my $fileName = shift;
    my $start = shift;
    my $stop = shift;

    my $mime = `file --mime-type "$fileName"`;
    if ($mime=~ m@application/gzip|application/x-gzip@)
    {
        open(FILE, "zcat \"$fileName\" |") or die "Can't open \"$fileName\" file.";
    }
    else
    {
        open(FILE, $fileName) or die "Can't open \"$fileName\" file.";
    }


    my $line=0;
    while (<FILE>)
    {
        $line++;
        next if (!(m/^(\S\S\S) +(\d?\d)/));

        next if !exists $MONTHS{$1};
        my $iDate = sprintf("%02d%02d", $MONTHS{$1}, $2);

        # Some optimizations .........................
        if ($iDate<$start && $optLimit<$iDate)
        {
            $optLimit = $iDate;
        }

        last if ($iDate<$optLimit);
        next if ($iDate<$start);
        last if ($iDate>$stop);
        # ............................................


        #            1        2            3          4     5     6
        next if (!(m/^(\S\S\S) +(\d?\d) (\d\d:\d\d:\d\d) (\S+) (\S+): (.*)/));

        my $date="$2 $1";
        my $time=$3;
        my $proc=$5;
        my $msg=$6;

        my %rec;
        %rec = parsePostfixLine($msg, $date, $time) if ($proc =~ m/^postfix/);
        %rec = parseAmavisLine($msg, $date, $time)  if ($proc =~ m/^amavis/);


        if ($rec{'id'})
        {
            my $id = $rec{'id'};
            $msgs{$id}{'order'}=$date . $time . $line;
            $msgs{$id}{'date'}=$date;
            $msgs{$id}{'header'}=$rec{'header'};
            $msgs{$id}{'msg'}.="\n $time " . (($verbose)?$proc:'') . " $rec{'msg'}";
            $msgs{$id}{'status'} = $rec{'status'} if ($msgs{$id}{'status'} < $rec{'status'});
        };
    };
    close(FILE);
};


sub newParseResult
{
    return {
        id => "",
        text => "",
        status => 0
    }
}


#******************************************************************************
# Parse lines from Postfix
#******************************************************************************
sub parsePostfixLine
{
    my $msg  = shift;
    my $date = shift;
    my $time = shift;
    my %res = newParseResult();

    if ($msg=~ m/^([0-9A-Fa-f]+): (.*)/)
    {
        $res{'id'} = $1;
        $res{'header'} = $1;

        my $text = $2;
        $res{'status'} = $STATUS_OK  if ($text=~ s/(status=sent.*)/$COLOR_OK$1$COLOR_NORM/g);
        $res{'status'} = $STATUS_ERR if ($text=~ s/(status=bounced.*)/$COLOR_BOUNCE$1$COLOR_NORM/g);
        $res{'msg'} = $text;
    };


    if ($msg=~ m/^NOQUEUE: (.*)/)
    {
        $res{'id'} = $date . $time;
        $res{'header'} = "NOQUEUE";

        my $text = $1;
        $res{'status'} = $STATUS_OK;
        $res{'msg'} = $text;
    };


    return %res;
}


#******************************************************************************
# Parse lines from Amavis
#******************************************************************************
sub parseAmavisLine
{
    my $msg  = shift;
    my $date = shift;
    my $time = shift;
    my %res = newParseResult();

    if ($msg=~ m/(.*)Queue-ID: ([0-9A-Fa-f]+),(.*)/)
    {
        $res{'id'} = $2;
        $res{'header'} = $2;

        my $text = "$1$3";
        $res{'status'} = $STATUS_ERR if ($text=~ s/(Blocked.*?},)/$COLOR_BOUNCE$1$COLOR_NORM/g);
        $res{'msg'} = (($verbose) ? '' :'amavis ') . "$text";
    }
    return %res;
}


#******************************************************************************
# Delete not matched records
#******************************************************************************
sub clean
{
    foreach my $key (keys(%msgs))
    {
        my $s=$msgs{$key}{'msg'};
        if ($to     && ($s!~ m/to=<\S*$to\S*>/i))
        {
            delete $msgs{$key};
            next;
        }

        if ($from   && ($s!~ m/from=<\S*$from\S*>/i))
        {
            delete $msgs{$key};
            next;
        }

        if ($errors && ($msgs{$key}{'status'} < $STATUS_ERR))
        {
            delete $msgs{$key};
            next;
        }
    }
}


#******************************************************************************
# Print results table
#******************************************************************************
sub printResults
{
    # Print results in LESS .............................
    my $num=scalar(keys(%msgs));
    open (PAGER, "| $LESS --prompt='Found $num mails.  Line %lt-%lb.'");

    my $prevHeader;
    my $delim;
    foreach my $key (sort{$msgs{$a}{'order'} cmp $msgs{$b}{'order'}}(keys(%msgs)))
    {

        my $s=$msgs{$key}{'msg'};

        $s=~ s/to=<(.*?)>/to=<$COLOR_TO$1$COLOR_NORM>/g;
        $s=~ s/from=<(.*?)>/from=<$COLOR_FROM$1$COLOR_NORM>/g;

        $s=~ s/warning: header Subject: (.*?) from.*/subject=$COLOR_SUBJ$1$COLOR_NORM/g;
        $s=~ s/ proto=.+//g;

        my $status='';
        $status=$COLOR_OK     if ($msgs{$key}{'status'} == $STATUS_OK);
        $status=$COLOR_BOUNCE if ($msgs{$key}{'status'} == $STATUS_ERR);

        my $header = sprintf("%s%s  ...............................%s%s\n",
                            $status,
                            $msgs{$key}{'header'},
                            $COLOR_NORM,
                            $msgs{$key}{'date'});

        if ($header ne $prevHeader)
        {
            $prevHeader = $header;
            print PAGER $delim;
            print PAGER $header;
            $delim = "\n\n\n"
        }
        print PAGER $s;
    }

    print PAGER "\n";
    close(PAGER);
}


#******************************************************************************
# Parse comand-line parametres
#******************************************************************************
sub param
{
    my $param;
    while ($param=shift)
    {
        if    ($param eq '-h'){ help() }
        elsif ($param eq '-V'){ showVer() }
        elsif ($param eq '-v'){ $verbose++ }
        elsif ($param eq '-e'){ $errors = 1 }
        elsif ($param eq '-t'){ $to =   shift }
        elsif ($param eq '-f'){ $from = shift }
        elsif ($param eq '-d'){ parseDateParam(shift, $bDate, $eDate) }
    };

    $from=~ s/\./\\\./g;
    $to=~ s/\./\\\./g;
}


#*******************************************************************************
# Parse comandline date parameter $_[0] and set 2 variable:
# $_[1] - begin date and
# $_[2] - end date
#*******************************************************************************
sub parseDateParam($$$)
{
    (my $b, my $e)=split('-', $_[0], 2);
    $_[1]=str2date($b?$b:'01/01/1970');
    $_[2]=str2date($e) if $e;
    $_[2]=$_[1] if ($_[0]!~ m/-/);
}


#******************************************************************************
# Parse string & return timestamp
#******************************************************************************
sub str2date
{
    my ($d,$m,$y) = split ('\D', $_[0], 3);
    $m = $now[$MON]+1  if (!$m);
    $y = $now[$YEAR] if (!$y);
    return timelocal(0, 0, 0, $d, --$m, $y);
}


#******************************************************************************
# Print help message
#******************************************************************************
sub help
{
    open(FILE, $0);

    while (<FILE>)
    {
        last if $_ eq "\n";
    };

    while (<FILE>)
    {
        last if $_ eq "\n";
        s/^#//;
        print $_;
    };
    close FILE;
    exit;
}


#******************************************************************************
# Print version
#******************************************************************************
sub showVer
{
    open(FILE, $0);

    <FILE>;
    while (<FILE>)
    {
        last if $_ eq "\n";
        s/^#//;
        print $_;
    };
    close FILE;
    exit;
}


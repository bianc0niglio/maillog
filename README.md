Postfix maillog log analyzer
====================================

Introduction.
---------

When the mail server processes a letter, it writes several lines to the log file. When there is a lot of mail traffic, lines belonging to different letters are mixed up; sometimes records belonging to one letter are separated from each other by several tens of lines. This greatly interferes with reading logs. To solve this problem, in ancient times I wrote a Perl script with the original name maillog. Over time, functionality was added to it and bugs were corrected. And now, when questions arise with mail, the first thing we do is run this script.


Possibilities.
------------

The script scans log files and groups lines by email. Entries are highlighted in color depending on the success of delivery, and addresses are highlighted.

It is possible to filter letters by sender and/or sender, keys -f and -t, respectively.

Using the -d switch, you can specify a date or range of dates for which to display letters. Dates can be specified in different ways, for example:

12.1.2010-15.1.2010 - show letters from the 12th to the 15th inclusive. 01/10/2010- - letters sent from the 10th and later. -12.01 - the opposite of the previous option, 12th and earlier. If the year or month is omitted, then the current one is substituted. - - in general, everything that happened on January 1, 2010 is for January 1, 2010. By default, messages from today are shown.

If you want to see only letters with errors, i.e. that were not delivered, you can use the -e option.

All of the listed keys can be used in any combination.

There is support for log files compressed after rotation.


Setup.
----------

Not many settings :)
At the beginning of the script there is a line "my $filePattern='/var/log/mail/mail*.log';" it specifies a name template for mail server logs.


Restrictions.
------------

Only the date and month are written in the logs, so it is impossible to filter letters by year. You can always omit the year from the -d option. If anyone has thoughts, write to me.

My month in the log is written in English Jan, Feb, etc., if someone has them in Russian, add Russian elements to the %MONTHS hash.

The script only works with postfix logs. I don’t remember now that the logs on other servers are very different, it’s possible to actually add support for other programs.

Usage (help).
--------------

 maillog [-d DATE] [-f FROM] [-t TO] [-e] [-h] [-V]

 Shows entries in the mail log for letters going from the FROM address to the TO address for the period specified in the DATE option.

 -f FROM sender's email address (or part of it).

 -t TO recipient's mailing address (or part of it).

 -d DATE display a report for the specified period; if the option is omitted, only records for the current day are displayed.

 DD/MM/YY-DD/MM/YY Full format:

 -DD/MM/YY Start date missing:
 records from January 1, 1970 will be shown.

 DD/MM/YY- Missing end date:
 records up to the current date will be shown.

 - Both start and end dates are missing:
 records will be shown from January 1, 1970 to
 current date.

 -e show only undelivered messages.

 -h show help page.

 -V show the program version and license.


License GPLv2.
---------------
This program is free software; you can redistribute it and/or modify t under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2, or (at your option) any later version.

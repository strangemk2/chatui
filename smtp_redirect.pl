#!/usr/bin/perl

use strict;

use LWP::Simple;

my $NOTIFY_URL = 'http://127.0.0.1:3000/mail_notify?email=';

my $line = <STDIN>;
if ($line =~ m/From (.*?) /)
{
	get("${NOTIFY_URL}$1");
	print ("HTTP GET: ${NOTIFY_URL}$1\n");
}

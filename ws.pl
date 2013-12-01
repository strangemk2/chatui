#!/usr/bin/perl

#perl -Iextlib/lib/perl5 ./extlib/bin/morbo ws.pl

use lib "extlib/lib/perl5";

use Mojolicious::Lite;
use Data::Dumper;
use Tiny:Try;
use MIME::Lite;
use Net::SMTP;

my $SMTP_SERVER = "127.0.0.1";
my $SMTP_PORT = 25;
my $SMTP_IMAP_DEBUG = 0;

my $ws_sessions = {};

sub getmail
{
	my ($account_info, $email) = @_;
	"say hello.";
}

# use smtp to send mail
#
# < to adreess
# < func ref for make a mail body
# < whole data to pass to
sub cmn_send_mail
{
    my ($from, $to, $make_mail_func, $data_ref) = @_;

    try
    {
        my $smtp;
        $smtp = Net::SMTP->new(
            $SMTP_SERVER,
            Port        => $SMTP_PORT,
            Debug       => $SMTP_IMAP_DEBUG,
        );
		#$smtp->auth($FROM_MAIL_ADDR, $FROM_MAIL_PASSWORD) || die "smtp auth error";
        $smtp->mail($from) || die "smtp from error";
        $smtp->to($to) || die "smtp rcpt error";
        $smtp->data() || die "data error";
        $smtp->datasend($make_mail_func->($data_ref)) || die "smtp data error";
        $smtp->dataend() || die "smtp data error";
        $smtp->quit || die "smtp quit error";

        1;
    }
    catch
    {
        print STDERR $_;
        undef;
    };
}

sub makemail
{
	my ($email_data) = @_;

	my $msg = MIME::Lite->new (
        From        => $email_data->{from},
        To          => $email_data->{to},
        Subject     => "mail from chatui",
        Type        => 'text/plain',
        Encoding    => 'quoted-printable',
    );
    $msg->delete('X-Mailer');
    $msg->attr('content-type.charset' => 'UTF-8');
	$msg->data($email_data->{body});

	$msg->as_string;
}

sub sendmail
{
	my ($account_info, $key, $content) = @_;

	my $from = $ws_sessions->{$key}->{account};
	my $to = $ws_sessions->{$key}->{email};
	cmn_send_mail($from, $to, \&makemail, {from => $from, to => $to, body => $content})

	my $socket = $ws_sessions->{$key}->{socket};
	$socket->app->log->debug("mail sent. address: $ws_sessions->{$key}->{email} .");

	1;
}

sub search_session
{
	my ($email, $session) = @_;
	my @ret;
	foreach (keys(%$session))
	{
		my $info = $session->{$_};
		push (@ret, $info) if ($info->{email} eq $email);
	}
	@ret;
}

websocket '/webui' => sub
{
	my $self = shift;

	$self->on(json => sub
		{
			my ($self, $hash) = @_;
			if ($hash->{account})
			{
				my $key = $self->tx->handshake->connection;
				$ws_sessions->{$key} = {account => $hash->{account}, email => $hash->{email}, socket => $self};
				$hash->{session} = $key;
				$self->send({json => $hash});
			}
			elsif ($hash->{msg})
			{
				my $key = $self->tx->handshake->connection;
				$hash->{msg} = "$ws_sessions->{$key}->{account}: $hash->{msg}";

				sendmail(undef, $key, makemail(undef, $hash->{msg}));
				$self->send({json => $hash});
			}
		}
	);

	# send heartbeats data to prevent timeout.
	my $id = Mojo::IOLoop->recurring(10 => sub
		{
			my (undef, $hash) = @_;
			$hash->{msg} = "";
			$self->send({json => $hash});
		});

	$self->on(finish => sub
		{
			# stop recurring timer
			Mojo::IOLoop->remove($id);

			# move client session
			my $key = $self->tx->handshake->connection;
			delete $ws_sessions->{$key};

			# disconnect log
			my ($self, $code, $reason) = @_;
			$self->app->log->debug("WebSocket closed with status $code.");
		});
};

get '/mail_notify' => sub
{
	my $self = shift;

	my $email = $self->param('email');
	my $text = "$email: " . getmail(undef, $email);

	my @infos = search_session($email, $ws_sessions);
	my $json_data = {json => {msg => $text}};
	foreach (@infos)
	{
		my $socket = $_->{socket};
		$socket->send($json_data);
		$socket->app->log->debug("mail recieved. address: $email.");
	}

	$self->render(text => '');
};

get '/' => 'index';

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
<head>
<title>Imap webui mockup</title>
	from:
	<input id="from" type=text" size=30>
	password:
	<input id="password" type=text" size=30>
	to:
	<input id="to" type=text" size=30>
	<input id="login" type=button value="login" onclick="uilogin()">
	<br>
	<textarea id="main" rows=30 cols=50  readonly="readonly"></textarea>
	<br>
	<input id="input" type="text" size=50>

%= javascript begin
	var ws;
	var session_key = '';

	function uilogin()
	{
		document.getElementById("from").disabled = true;
		document.getElementById("to").disabled = true;
		document.getElementById("password").disabled = true;
		document.getElementById("login").disabled = true;

		ws = new WebSocket('<%= url_for('webui')->to_abs %>');

		ws.onmessage = function (event)
		{
			//document.body.innerHTML += JSON.parse(event.data).msg;
			var s = JSON.parse(event.data).session;
			if (s)
			{
				session_key = s;
			}
			var msg = JSON.parse(event.data).msg;
			if (msg)
			{
				var textarea = document.getElementById("main");
				textarea.value += msg + "\n";
				main.scrollTop = main.scrollHeight;
			}
		};

		ws.onopen = function (event)
		{
			ws.send(JSON.stringify({account: document.getElementById("from").value,
									password: document.getElementById("password").value,
									email: document.getElementById("to").value}));
		};

		ws.onclose = function (event)
		{
			document.getElementById("main").disabled = true;
			document.getElementById("input").disabled = true;

			alert("session closed.");
		};
	}

	function send_mail (str)
	{
		if (session_key && ws)
		{
			ws.send(JSON.stringify(
				{msg: document.getElementById("input").value,
				session: session_key}));
		}
		else
		{
			alert('No session.');
		}
	}

	document.onkeydown = function(e)
	{
		var e = e || window.event;
		if(e.keyCode==13) {
			send_mail(document.getElementById('input').value);
			document.getElementById('input').value = "";
		}
	}
% end
</head>
</html>

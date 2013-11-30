#perl -Iextlib/lib/perl5 ./extlib/bin/morbo ws.pl
#
use lib "extlib/lib/perl5";

use Mojolicious::Lite;
#use Mojo::Base 'Mojo::EventEmitter';
use Data::Dumper;

#my $ee = Mojo::EventEmitter->new;

#my %websockets;

my $mail_sockets = {};

sub getmail
{
	my ($account_info, $mail_address) = @_;
	"say hello.";
}

sub makemail
{
	my ($address, $content) = @_;
	"fake mail."
}

sub sendmail
{
	my ($account_info, $mail_address, $mailtext) = @_;

	my $socket = $mail_sockets->{$mail_address}->{socket};
	$socket->app->log->debug("mail sent. address: $mail_address .");
	1;
}

websocket '/echo' => sub
{
	my $self = shift;

	#my $key = $self->tx->handshake->connection;
	#$websockets{$key} = $self;

	$self->on(json => sub
		{
			my ($self, $hash) = @_;
			if ($hash->{account})
			{
				$mail_sockets->{$hash->{email}} = {account => $hash->{account}, socket => $self};
			}
			if ($hash->{msg})
			{
				$hash->{msg} = "me: $hash->{msg}";
				#foreach (keys(%websockets))
				#{
				#	$websockets{$_}->send({json => $hash});
				#}

				sendmail(undef, $hash->{email}, makemail(undef, $hash->{msg}));
				$self->send({json => $hash});
				#$ee->once( mail => sub
				#	{
				#		$self->send({json => $hash});
				#	})
			}
		}
	);

	# send data to prevent timeout.
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
			#my $key = $self->tx->handshake->connection;
			#delete $websockets{$key};

			# disconnect log
			my ($self, $code, $reason) = @_;
			$self->app->log->debug("WebSocket closed with status $code.");
		});
};

get '/trigger' => sub
{
	my $self = shift;
	#$ee->emit(mail => 1);
	my $mail_address = $self->param('email');
	my $text = getmail(undef, $mail_address);

	my $socket = $mail_sockets->{$mail_address}->{socket};

	my $hash = {};
	$hash->{msg} = "$text";
	$socket->send({json => $hash});
	$socket->app->log->debug("mail recieved. address: $mail_address .");

	$self->render(text => '');
};

get '/' => 'index';

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
<head>
<title>Echo</title>
	<textarea id="main" rows=30 cols=50  readonly="readonly"></textarea>
	<br>
	<input id="input" type="text" size=50>

%= javascript begin
	var ws = new WebSocket('<%= url_for('echo')->to_abs %>');

	ws.onmessage = function (event) {
		//document.body.innerHTML += JSON.parse(event.data).msg;
		var msg = JSON.parse(event.data).msg;
		if (msg)
		{
			var textarea = document.getElementById("main");
			textarea.value += msg + "\n";
			main.scrollTop = main.scrollHeight;
		}
	};

	ws.onopen = function (event) {
		ws.send(JSON.stringify({account: 'void', email: 'void@pm525.net'}));
		//ws.send(JSON.stringify({msg: 'I ♥ Mojolicious!!?'}));
	};

	function send_mail (str) {
		ws.send(JSON.stringify({msg: document.getElementById("input").value, email: 'void@pm525.net'}));
		//if (str) {document.getElementById("main").value += str + "\n"};
	}

	document.onkeydown = function(e) {
		var e = e || window.event;
		if(e.keyCode==13) {
			send_mail(document.getElementById('input').value);
			document.getElementById('input').value = "";
		}
	}
% end
</head>
</html>

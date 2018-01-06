#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
#bysctnightcore
package Network::Send::Zero;

use strict;
use base qw(Network::Send::ServerType0);
use Globals; 
use Network::Send::ServerType0;
use Log qw(error debug message);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		#'07E4' => ['character_move', 'a3', [qw(coords)]],
		'0439' => ['item_use', 'a2 a4', [qw(ID targetID)]],
		'0825' => ['token_login', 'v v x v Z24 a27 Z17 Z15 a*', [qw(len version master_version username password_rijndael mac ip token)]],
		'0ACF' => ['master_login', 'a4 Z25 a32 a5', [qw(game_code username password_rijndael flag)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		item_use 0439
		token_login 0825
		master_login 0ACF		
	);

	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	my $msg;
	my $password_rijndael = $self->encrypt_password($password);

	$msg = $self->reconstruct({
		switch => 'master_login',
		game_code => '0036', # kRO Ragnarok game code
		username => $username,
		password_rijndael => $password_rijndael,
		flag => 'G000', # Maybe this say that we are connecting from client
	});

	$self->sendToServer($msg);
	debug "Sent sendMasterLogin\n", "sendPacket", 2;
}

sub sendTokenToServer {
	my ($self, $username, $password, $master_version, $version, $token, $length, $ott_ip, $ott_port) = @_;
	my $len =  $length + 92;

	my $password_rijndael = $self->encrypt_password($password);
	my $ip = '192.168.0.14';
	my $mac = '20CF3095572A';
	my $mac_hyphen_separated = join '-', $mac =~ /(..)/g;

	$net->serverConnect($ott_ip, $ott_port);

	my $msg = $self->reconstruct({
		switch => 'token_login',
		len => $len, # size of packet
		version => $version,
		master_version => $master_version,
		username => $username,
		password_rijndael => '',
		mac => $mac_hyphen_separated,
		ip => $ip,
		token => $token,
	});	
	
	$self->sendToServer($msg);

	debug "Sent sendTokenLogin\n", "sendPacket", 2;
}

sub encrypt_password {
	my ($self, $password) = @_;
	my $password_rijndael;
	if (defined $password) {
		my $key = pack('C32', (0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06, 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06));
		my $chain = pack('C32', (0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41, 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41));
		my $in = pack('a32', $password);
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 32, 32);
		$password_rijndael = unpack("Z32", $rijndael->Encrypt($in, undef, 32, 0));
		return $password_rijndael;
	} else {
		error("Password is not configured");
	}
}

1;

#!/usr/bin/perl
# Spotify for Irssi by Amanda Folson
# Based on https://github.com/afolson/irssi-youtube/ which was based on:
# -- youtube-title by Olof "zibri" Johansson <olof@ethup.se> https://github.com/olof/irssi-youtube-title
# -- Automatic YouTube by Louis T. http://ltdev.im/

use strict;
use Irssi;
use WWW::Mechanize;
use JSON -support_by_pp;
use Time::Duration;
use Class::Date qw(:errors date -EnvC);
use Number::Format qw(:subs :vars);
use HTML::Entities;
use Regexp::Common qw/URI/;

my $VERSION = '0.1';

my %IRSSI = (
	authors		=> 'Amanda Folson',
	contact		=> 'amanda.folson@gmail.com',
	name		=> 'irssi-spotify',
	uri		=> 'https://github.com/afolson/irssi-spotify/',
	description	=> 'An Irssi script to display data about songs on Spotify.',
	license		=> 'WTFPL',
);

# If a Spotify link is seen, display the data. Default to ON.
Irssi::settings_add_bool('spotify', 'spotify_print_links', 1);
# If you submit a link, display the data. Default to OFF.
Irssi::settings_add_bool('spotify', 'spotify_print_own_links', 0);

# Look for Spotify links in messages sent to us
sub callback {
	my($server, $msg, $nick, $address, $target) = @_;
	$target=$nick if $target eq undef;
	if(Irssi::settings_get_bool('spotify_print_links')) {
		# A wild Spotify link appears! Irssi used PARSE. It's super effective!
		process($server, $target, $_) for (getID($msg));
	}
}

# Look for Spotify links in messages sent from us
sub own_callback {
	my($server, $msg, $target) = @_;
	if(Irssi::settings_get_bool('spotify_print_own_links')) {
		callback($server, $msg, undef, undef, $target);
	}
}

sub process {
	my ($server, $target, $id) = @_;
	my $spot = getInfo($id);
	if ($spot != 0) {
		if(exists $spot->{error}) {
			print_error($server, $target, $spot->{error});
		}
		else {
			printInfo($server, $target, $spot->{title}, $spot->{artist}, $spot->{album}, $spot->{released}, $spot->{duration});
		}
	}
}

sub print_error {
	my ($server, $target, $msg) = @_;
	$server->window_item_find($target)->printformat(MSGLEVEL_CLIENTCRAP, 'spotify_error', $msg);
}
sub getID {
	my $string = shift;
	if ($string =~ m/(?:https?:\/\/(?:open|play)\.spotify\.com\/track\/|spotify:track:)([a-zA-Z0-9]+)\/?/) {
		return $1;
	}
	else {
		return 0;
	}
}
sub printInfo {
	my ($server, $target, $title, $artist, $album, $released, $duration) = @_;
	my $item;
	
	foreach $item (@_) {
		decode_entities($item);
	} 
	$server->window_item_find($target)->printformat(MSGLEVEL_CLIENTCRAP, 'spotify_info', $title, $artist, $album, $released, $duration);
}

sub getInfo {
	my($song)=@_;
	my $url = "http://ws.spotify.com/lookup/1/.json?uri=spotify:track:$song";
	my $browser = WWW::Mechanize->new();
	eval {
		$browser->get($url);
	};
	if ($@) {
		return 0;
	};
	my $title;
	my $artist;
	my $album;
	my $released;
	my $duration;
	if ($browser->status() eq 200) {
		my $json = new JSON;
		my $jsonResp = $json->allow_nonref->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($browser->content());
		if ($jsonResp->{'track'}) {
			my $data = $jsonResp->{'track'};
			if ($data->{'name'}) {
				$title = $data->{'name'};
				if ($data->{'artists'}->[0]->{'name'}) {
					$artist = $data->{'artists'}->[0]->{'name'};
				}
				if ($data->{'album'}->{'name'}) {
					$album = $data->{'album'}->{'name'};
				}
				if ($data->{'album'}->{'released'}) {
					$released = $data->{'album'}->{'released'};
				}
				if ($data->{'length'}) {
					$duration = duration($data->{'length'});
				}
			}
			if($title) {
				return {
					title => $title,
					artist => $artist,
					album => $album,
					released => $released,
					duration => $duration,
				};
			}
		}
		else {
			return {error => 'Unable to find entry.'};
		}
	}
	else {
		return {error => 'Unable to fetch data.'};
	}
}

Irssi::theme_register([
	'spotify_info', '%gSpotify:%n %9Title:%_ $0 %9Artist:%_ $1 %9Album:%_ $2 ($3) %9Duration:%_ $4',
	'spotify_error', '%rError fetching Spotify data:%n $0',
]);

# Public and private messages sent to us
Irssi::signal_add("message public", \&callback);
Irssi::signal_add("message private", \&callback);
# Public and private messages sent from us
Irssi::signal_add("message own_public", \&own_callback);
Irssi::signal_add("message own_private", \&own_callback);

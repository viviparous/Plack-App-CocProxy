package Plack::App::CocProxy;

use strict;
use warnings;

our $VERSION = '0.04';
our $msg_PAGE_NOT_FOUND = 404;
our $indexfile='index.html';

use parent qw(Plack::App::File);
use Plack::App::Proxy;
use Plack::Util::Accessor qw/backend/;


sub prepare_app {
	my ($self) = @_;
	$self->{_proxy} = Plack::App::Proxy->new(backend => $self->backend)->to_app;
}

sub call {
	my ($self, $env) = @_;

	my $res = $self->SUPER::call($env);
	if ($res->[0] != $msg_PAGE_NOT_FOUND ) {
		$res;
	} else {
		$env->{'plack.proxy.url'} = $env->{REQUEST_URI};
		$self->{_proxy}->($env);
	}
}

sub locate_file {
	my ($self, $env) = @_;

	my $req;
	if ($env->{REQUEST_URI} =~ /^http/i) {
		$req = URI->new($env->{REQUEST_URI});
		$env->{PATH_INFO} = $req->path;
	} else {
		$req = Plack::Request->new($env)->uri;
		$env->{PATH_INFO}   = $req->path;
		$env->{REQUEST_URI} = "$req";
	}

	my $path = $req->path;
	my $host = $req->host;
	my $base = $path;
	$path =~ s{^/}{};
	$base =~ s{^.*/}{};

	$path ||= $indexfile;
	$base ||= $indexfile;

	my @paths = (
		$base,
		"$host/$path",
		"$host/$base",
		$path,
	);

	my $docroot = $self->root || ".";
	for my $path (@paths) {
		my $try = "$docroot/$path";
		if (-l $try) {
			$try = readlink($try);
		}
		if (-r $try) {
			$env->{'psgi.errors'}->print(sprintf("Arrogated %s => %s\n", $req, $try));
			return $try, undef;
		}
	}

	$self->return_404; #superclass 
}

1;
__END__

=head1 NAME

Plack::App::CocProxy - proxy requests and replace by local file

=head1 SYNOPSIS

  use Plack::App::CocProxy;
  Plack::App::CocProxy->new(root => 'files');

or you can use this like:

  $ twiggy -MPlack::App::CocProxy -e 'Plack::App::CocProxy->new(root=>".")->to_app' -p 5432

or you can use installed simple script:

  $ cocproxy # is same as above

=head1 DESCRIPTION

Plack::App::CocProxy arrogates requests and redirect to local file under rules based on request-URI.

Example(root=>"."):

  http://example.com/
  => ./index.html => ./example.com/index.html => (original url)

  http://example.com/foo/bar.html
  => ./bar.html => ./example.com/foo/bar.html => ./example.com/bar.html => ./foo/bar.html => (original url)

=head1 AUTHOR

cho45 E<lt>cho45@lowreal.netE<gt>

=head1 SEE ALSO

L<Plack::App::Proxy>, L<Plack::App::File>, L<Plack>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

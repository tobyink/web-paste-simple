package Web::Paste::Simple;

use 5.010;
use MooX 'late';
use JSON qw( from_json to_json );
use HTML::HTML5::Entities qw( encode_entities_numeric );
use constant read_only => 'ro';
use aliased 'Text::Template';
use aliased 'Data::UUID';
use aliased 'Plack::Request';
use aliased 'Plack::Response';
use aliased 'Path::Class::Dir';
use aliased 'Path::Class::File';

BEGIN {
	$Web::Paste::Simple::AUTHORITY = 'cpan:TOBYINK';
	$Web::Paste::Simple::VERSION   = '0.001';
}

has uuid_gen => (
	is      => read_only,
	isa     => UUID,
	default => sub { UUID->new },
);

has template => (
	is      => read_only,
	isa     => Template,
	lazy    => 1,
	default => sub {
		return Template->new(
			TYPE   => 'FILEHANDLE',
			SOURCE => \*DATA,
		);
	},
);

has storage => (
	is      => read_only,
	isa     => Dir,
	default => sub { Dir->new('/tmp/perl-web-paste-simple/') },
);

has codemirror => (
	is      => read_only,
	isa     => 'Str',
	default => 'http://buzzword.org.uk/2012/codemirror-2.36',
);

has app => (
	is      => read_only,
	isa     => 'CodeRef',
	lazy_build => 1,
);

has modes => (
	is      => read_only,
	isa     => 'ArrayRef[Str]',
	default => sub {
		[qw(
			htmlmixed xml css javascript
			clike perl php ruby python lua haskell
			diff sparql ntriples plsql
		)]
	},
);

has default_mode => (
	is      => read_only,
	isa     => 'Str',
	default => 'perl',
);

sub _build_app
{
	my $self = shift;
	
	$self->storage->mkpath unless -d $self->storage;
	confess "@{[$self->storage]} is not writeable" unless -w $self->storage;
		
	return sub {
		my $req = Request->new(shift);
		
		if ($req->method eq 'POST') {
			$self->_save_paste($req)->finalize;
		}
		elsif ($req->path =~ m{^/([^.]+)}) {
			return $self->_serve_paste($req, $1)->finalize;
		}
		elsif ($req->path eq '/') {
			return $self->_serve_template($req, {})->finalize;
		}
		else {
			return $self->_serve_error("Bad URI", 404);
		}
	};
}

sub _mk_id
{
	my $id = shift->uuid_gen->create_b64;
	$id =~ tr{+/}{-_};
	$id =~ s{=+$}{};
	return $id;
}

sub _save_paste
{
	my ($self, $req) = @_;
	my $id = $self->_mk_id;
	$self->storage->file("$id.paste")->spew(
		to_json( +{ %{$req->parameters} } ),
	);
	return Response->new(
		302,
		[
			'Content-Type' => 'text/plain',
			'Location'     => $req->base . $id,
		],
		"Yay!",
	);
}

sub _serve_error
{
	my ($self, $err, $code) = @_;
	Response->new(($code//500), ['Content-Type' => 'text/plain'], "$err\n");
}

sub _serve_paste
{
	my ($self, $req, $id) = @_;
	my $file = $self->storage->file("$id.paste");
	-r $file or return $self->_serve_error("Bad file", 404);
	my $data = from_json($file->slurp);
	
	exists $req->parameters->{raw}
		? Response->new(200, ['Content-Type' => 'text/plain'], $data->{paste})
		: $self->_serve_template($req, $data);
}

sub _serve_template
{
	my ($self, $req, $data) = @_;
	my $page = $self->template->fill_in(
		HASH => {
			DATA       => encode_entities_numeric($data->{paste} // ''),
			MODE       => encode_entities_numeric($data->{mode}  // $self->default_mode),
			MODES      => $self->modes,
			PACKAGE    => ref($self),
			VERSION    => $self->VERSION,
			CODEMIRROR => $self->codemirror,
		},
	);
	Response->new(200, ['Content-Type' => 'text/html'], $page);
}

1;

=head1 NAME

Web::Paste::Simple - simple PSGI-based pastebin-like website

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Web-Paste-Simple>.

=head1 SEE ALSO

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2012 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut

__DATA__
<!doctype html>
<title>{$PACKAGE} {$VERSION}</title>
<link rel="stylesheet" href="{$CODEMIRROR}/lib/codemirror.css">
<script src="{$CODEMIRROR}/lib/codemirror.js"></script>
{
	for my $m (@MODES) {
		$OUT .= qq[<script src="$CODEMIRROR/mode/$m/$m.js"></script>\n]
	}
}
<form action="" method="post">
	<div>
		<select name="mode" onchange="change_mode();">
			{
				for my $m (@MODES) {
					$OUT .= qq[<option @{[$m eq $MODE ? 'selected':'']}>$m</option>\n]
				}
			}
		</select>
		<input type="submit" value=" Paste ">
		<br>
		<textarea name="paste">{$DATA}</textarea>
	</div>
</form>
<script>
var ta = document.getElementsByTagName("textarea");
var editor = CodeMirror.fromTextArea(ta[0], \{
	lineNumbers: true,
	matchBrackets: true,
	indentUnit: 4,
	mode: "{$MODE}",
\});
function change_mode () \{
	var s = document.getElementsByTagName("select");
	editor.setOption("mode", s[0].options[s[0].selectedIndex].value);
\}
</script>

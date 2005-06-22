=head1 NAME

CGI::Application::PageBuilder - Simplifies building pages with multiple templates in CGI::Application.

=head1 SYNOPSIS

This module is built on the idea that building complex web pages with the default CGI::Application method can get to be a real mess.  I personally found it much easier to build pages from many different smaller templates than to try to create one large template.  This is especially true when displaying large sets of data from a database where you would be filling in a lot of <TMPL_VAR>s for each cell.  This module aims to make that process a little easier.

So instead of:

 sub run_mode {
 	my $self = shift;
 	my $header = $self->load_tmpl( 'header.tmpl' )->output();
 	my $html;

 	my $start = $self->load_tmpl( 'view_start.tmpl' );
 	$start->param( view_name => 'This View' );
 	$html .= $start->output();

	 my $db = MyApp::DB::Views->retrieve_all(); # Class::DBI
	 while ( my $line = $db->next() ) {
		 my $template = $self->load_tmpl( 'view_element.tmpl' );
		 $template->param( name => $line->name() );
		 $template->param( info => $line->info() );
		 $html .= $template->output();
	 }
	 $html .= $self->load_tmpl( 'view_end.tmpl' )->output();
	 $html .= $self->load_tmpl( 'footer.tmpl' )->output();
	 return $html;
 }

You can do this:

 sub run_mode {
  	my $self = shift;
 	my $page = new CGI::Application::PageBuilder(
                    Header => 'header.tmpl',
                    Footer => 'footer.tmpl',
                    Super => $self );
 	$page->template( 'view_start.tmpl' );

 	my $db = MyApp::DB::Views->retrieve_all();
 	while( my $line = $db->next() ) {
		 $page->template( 'view_element.tmpl' );
		 $page->param( name => $line->name() );
		 $page->param( info => $line->info() );
 	}
 	$page->template( 'view_end.tmpl' );
 	return $page->output();
 }

Which arguably looks much cleaner.

The C<Super> argument to C<new()> allows the module to use the L<HTML::Template> object already inside your CGI::Application subclass.  Therefore, all C<template()> calls expect filenames relative to the path you would have set in the C<setup()> method of your L<CGI::Application> subclass.

=head1 METHODS

=head2 new

my $page = new CGI::Application::PageBuilder(
    Header => 'header.tmpl',
    Footer => 'footer.tmpl',
    Super => $self );

Both Header and Footer are optional arguments.  Super is required.

=head2 loose

$page->loose( value );

Value is 0 or 1 depending on whether you want die_on_bad_params enabled or not.  See L<HTML::Template> for more information.  The default behavior is to have strict templates since this is also the default for L<HTML::Template>.

=head2 template

$page->template( 'the_template_to_use.tmpl' );

Adds the template to the page and sets it as the next template to apply param to.

=head2 param

$page->param( name, value );

Sets the value for the param in the template.  This applies to the last template loaded by L<template>.

=head2 output

return $page->output();

Returns the HTML of the built page.

=head1 TODO

Needs actual tests.

There is probably a much more elegant way to do this.

At the moment param() automatically tries to add the parameter to the last template loaded.  It might be nice to have a simple way of adding a parameter to an already loaded template.  Some might possibly prefer to load all of their templates at once and then add parameters later on in the code.  Perhaps something like:

 	my $page = new CGI::Application::PageBuilder(
 		Header => 'header.tmpl',
 		Footer => 'footer.tmpl',
 		Super => $self );
 	$page->template( 'one.tmpl' );
 	$page->template( 'two.tmpl' );
 	
 	...
 	
 	$page->param( 'one.tmpl', param, value );
 	$page->param( 'one.tmpl', param, value );
 	
 	etc.

Check out http://library.hellyeah.org/index.pl?CGIApplicationPageBuilder for more information.

=head1 AUTHOR

Clint Moore C<< <cmoore@cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2005, Clint Moore C<< <cmoore@cpan.org> >>.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

package CGI::Application::PageBuilder;
$VERSION = '0.5';

use constant {
	TEMPLATE_ERRORS_ARE_FATAL => 1,
};


sub new {
	my ( $proto, %args ) = @_;
	my $class = ref $proto || $proto;
	bless ( {
			 _buffer => '',
			 _populated => '',
			 _template_count => 0,
			 _loose => TEMPLATE_ERRORS_ARE_FATAL,
			 super => $args{Super},
			 header => $args{ Header },
			 footer => $args{ Footer },
			}, $class );
}

sub template {
	my( $self, $template ) = @_;

	$self->{_built} = 0 if $self->{_built};
	$self->{_template_count}++;

	my $tname = "_template_" . $self->{_template_count};
	my $tp = $self->{super}->load_tmpl( $template );
	$self->{$tname} = $tp;
}

sub build {
	my $self = shift;

	if ( exists $self->{ header } ) {
		my $header = $self->{ header };
		$self->{_buffer} = $self->{super}->load_tmpl( $header )->output();
	}

	for my $i ( 1 .. $self->{_template_count} ) {
		my $tname = "_template_" . $i;
		$self->{_buffer} .= $self->{$tname}->output();
	}

	if ( exists $self->{ footer } ) {
		my $footer = $self->{ footer };
		$self->{_buffer} .= $self->{super}->load_tmpl( $footer )->output();
	}

	$self->{_built} = 1;
	return $self->{_buffer};
}

sub param {
	my( $self ) = shift;
	my( $param ) = shift;

	if ( ref( $param ) eq 'HASH' ) {
		while( my( $p, $v ) = each %{ $param } ) {
			$self->param( $p, $v );
		}
		return;
	}

	my $value = shift;
	return undef unless( $value );

	my $tname = "_template_" . $self->{_template_count};
	$self->{$tname}->param( $param, $value );
}

sub output {
	my $self = shift;

	$self->build() unless $self->{_built};
	return $self->{_buffer};
}

# This is for backwards compatibility with the application that I wrote this for.
# I'll take it out in the next release.  ie. When I get done removing it from that
# application.

sub add_param {
	my( $self, $param, $val ) = @_;
	$self->param( $param, $val );
}

sub add_template {
	my( $self, $template ) = @_;
	$self->template( $template );
}

1;

__END__

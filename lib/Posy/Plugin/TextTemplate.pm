package Posy::Plugin::TextTemplate;
use strict;

=head1 NAME

Posy::Plugin::TextTemplate - Posy plugin for interpolating with Text::Template

=head1 VERSION

This describes version B<0.40> of Posy::Plugin::TextTemplate.

=cut

our $VERSION = '0.40';

=head1 SYNOPSIS

    @plugins = qw(Posy::Core
	Posy::Plugin::TextTemplate
	...);

=head1 DESCRIPTION

This overrides Posy's simple interpolate() method, by using
the Text::Template module.
This is I<not> compatible with core Posy style interpolation.

Note that, if you want access to any of posy's methods inside a template,
the Posy object should be available through the variable "$Posy".

=head2 Configuration

This expects configuration settings in the $self->{config} hash,
which, in the default Posy setup, can be defined in the main "config"
file in the data directory.

=over

=item B<tt_recurse_into_entry>

Do you want me to recursively interpolate into the entry $title
and $body?  Consider carefully before turning this on, since if
anyone other than you has the ability to post entries, there is
a chance of foolishness or malice, exposing variables and
calling actions/subroutines you might not want called.
(0 = No, 1 = Yes)

=item B<tt_left_delim> B<tt_right_delim>

The delimiters to use for Text::Template; for the sake of speed,
it is best not to use the original '{' '}' delimiters.
(default: tt_left_delim='[==', tt_right_delim='==]')

=item B<tt_entry_left_delim> B<tt_entry_right_delim>

The delimiters to use for Text::Template inside an entry
(if tt_recurse_into_entry is true)
(default: tt_entry_left_delim='<?perl' tt_entry_right_delim='perl?>')

I used these defaults because they look like XML directives, and for
compatibility with L<teperl>.

=back

=cut

use Text::Template;

=head1 OBJECT METHODS

Documentation for developers and those wishing to write plugins.

=head2 init

Do some initialization; make sure that default config values are set.

=cut
sub init {
    my $self = shift;
    $self->SUPER::init();

    # set defaults
    $self->{config}->{tt_recurse_into_entry} = 0
	if (!defined $self->{config}->{tt_recurse_into_entry});
    $self->{config}->{tt_left_delim} = '[=='
	if (!defined $self->{config}->{tt_left_delim});
    $self->{config}->{tt_right_delim} = '==]'
	if (!defined $self->{config}->{tt_right_delim});
    $self->{config}->{tt_entry_left_delim} = '<?perl'
	if (!defined $self->{config}->{tt_entry_left_delim});
    $self->{config}->{tt_entry_right_delim} = 'perl?>'
	if (!defined $self->{config}->{tt_entry_right_delim});
    # override the error templates
    $self->{templates}->{content_type}->{error} = 'text/html';
    $self->{templates}->{head}->{error} =
		'<html><body><p><font color="red">Error: I\'m afraid this is the first I\'ve heard of a "[==$path_flavour==]" flavoured Posy.  Try dropping the ".[==$path_flavour==]" bit from the end of the URL.</font>';
    $self->{templates}->{header}->{error} = '<h3>[==$entry_dw==], [==$entry_da==] [==$entry_month==] [==$entry_year==]</h3>';
    $self->{templates}->{entry}->{error} =
		'<p><b>[==$entry_title==]</b><br />[==$entry_body==] <a href="[==$url==]/[==$path_cat_id==]/[==$path_basename==].[==$config_flavour==]">#</a></p>';
    $self->{templates}->{foot}->{error} = '</body></html>';

} # init

=head1 Helper Methods

Methods which can be called from within other methods.

=head2 set_vars

    my %vars = $self->set_vars($flow_state);
    my %vars = $self->set_vars($flow_state, $current_entry, $entry_state);

Sets variable hashes to be used in interpolation of templates.

This can be called from a flow action or as an entry action, and will
use the given state hashes accordingly.

=cut
sub set_vars {
    my $self = shift;
    my %vars = $self->SUPER::set_vars(@_);

    $vars{Posy} = \$self;
    return %vars;
} # set_vars

=head2 interpolate

$content = $self->interpolate($chunk, $template, \%vars);

Interpolate the contents of the vars hash with the template
and return the result.

=cut
sub interpolate {
    my $self = shift;
    my $chunk = shift;
    my $template = shift;
    my $vars_ref = shift;

    warn "$chunk template empty" if (!$template);
    # recurse into entry if we are processing an entry
    if ($chunk eq 'entry'
	and $self->{config}->{tt_recurse_into_entry})
    {
	if ($vars_ref->{entry_title}) {
	    # taint check
	    $vars_ref->{entry_title} =~ /^([^`]*)$/s;
	    my $title = $1;
	    if ($title && $title !~ /system\(/)
	    {
		my $ob1 = new Text::Template(
					     TYPE=>'STRING',
					     SOURCE => $title,
					     DELIMITERS =>
					     [$self->{config}->{tt_entry_left_delim},
					     $self->{config}->{tt_entry_right_delim}],
					    );
		$vars_ref->{entry_title} = $ob1->fill_in(HASH=>$vars_ref);
		undef $ob1;
	    }
	}
	if ($vars_ref->{entry_body}) {
	    # taint check
	    $vars_ref->{entry_body} =~ /^([^`]*)$/s;
	    my $body = $1;
	    if ($body && $body !~ /system\(/)
	    {
		my $ob2 = new Text::Template(
					     TYPE=>'STRING',
					     SOURCE => $body,
					     DELIMITERS =>
					     [$self->{config}->{tt_entry_left_delim},
					     $self->{config}->{tt_entry_right_delim}],
					    );
		$vars_ref->{entry_body} = $ob2->fill_in(HASH=>$vars_ref);
		undef $ob2;
	    }
	}
    }
    my $content = $template;
    $self->debug(1, "template undefined") if (!defined $template);
    my $obj = new Text::Template(
				 TYPE=>'STRING',
				 SOURCE => $content,
				 DELIMITERS =>
				 [$self->{config}->{tt_left_delim},
				 $self->{config}->{tt_right_delim}],
				);
    $content = $obj->fill_in(HASH=>$vars_ref);
    return $content;
} # interpolate

=head1 REQUIRES

    Posy
    Posy::Core
    Text::Template

    Test::More

=head1 SEE ALSO

perl(1).
Posy
Text::Template

=head1 BUGS

Please report any bugs or feature requests to the author.

=head1 AUTHOR

    Kathryn Andersen (RUBYKAT)
    perlkat AT katspace dot com
    http://www.katspace.com

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2004-2005 by Kathryn Andersen

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Posy::Plugin::TextTemplate
__END__

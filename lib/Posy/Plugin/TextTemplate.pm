package Posy::Plugin::TextTemplate;
use strict;

=head1 NAME

Posy::Plugin::TextTemplate - Posy plugin for interpolating with Text::Template.

=head1 VERSION

This describes version B<0.44> of Posy::Plugin::TextTemplate.

=cut

our $VERSION = '0.44';

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

This also supplies a helper method, 'safe_backtick', which can be used
to safely call another program and return the results, rather than using
a backtick `` which is insecure (and explicitly not allowed by this
module).  Note that this will probably only work in a UNIX-like
environment.

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
    $self->{templates}->{content_type}->{default} = 'text/html';
    $self->{templates}->{head}->{default} =
		'<html><head><title>[==$config_site_title==]: [==$path_file_key==] ([==$path_flavour==])</title>
		</head>
		<body><p>([==$path_basename==].[==$path_flavour==])</p>';
    $self->{templates}->{header}->{default} = '<h3>[==$entry_dw==], [==$entry_da==] [==$entry_month==] [==$entry_year==]</h3>';
    $self->{templates}->{entry}->{default} =
		'<p><b>[==$entry_title==]</b><br />[==$entry_body==] <a href="[==$url==]/[==$path_cat_id==]/[==$path_basename==].[==$config_flavour==]">#</a></p>';
    $self->{templates}->{foot}->{default} = '</body></html>';

    # set the cache to empty
    $self->{_template_objs} = {}
	if (!exists $self->{_template_objs});
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
    # if the template is empty, return empty
    return '' if (!$template);

    my $content = $template;
    # see if the template is already there and compiled
    my $obj;
    if (exists $self->{_template_objs}->{$chunk}->{$template}
	and defined $self->{_template_objs}->{$chunk}->{$template})
    {
	$obj = $self->{_template_objs}->{$chunk}->{$template};
    }
    else
    {
	$obj = new Text::Template(
				     TYPE=>'STRING',
				     SOURCE => $content,
				     DELIMITERS =>
				     [$self->{config}->{tt_left_delim},
				     $self->{config}->{tt_right_delim}],
				    );
	$obj->compile();
	$self->{_template_objs}->{$chunk} = {}
	if (!exists $self->{_template_objs}->{$chunk});
	$self->{_template_objs}->{$chunk}->{$template} = $obj;
    }
    $content = $obj->fill_in(HASH=>$vars_ref);
    return $content;
} # interpolate

=head2 safe_backtick

<?perl $OUT = $Posy->safe_backtick('myprog', @args); perl?>

Return the results of a program, without risking evil shell calls.
This requires that the program and the arguments to that program
be given separately.

=cut

sub safe_backtick {
    my $self = shift;
    my @prog_and_args = @_;
    my $progname = $prog_and_args[0];

    # if they didn't give us anything, return
    if (!$progname)
    {
	return '';
    }
    # call the program
    # do a fork and exec with an open;
    # this should preserve the environment and also be safe
    my $result = '';
    my $fh;
    my $pid = open($fh, "-|");
    if ($pid) # parent
    {
	{
	    # slurp up the result all at once
	    local $/ = undef;
	    $result = <$fh>;
	}
	close($fh) || warn "$progname program script exited $?";
    }
    else # child
    {
	# figure out the working directory of the current file
	$self->{path}->{cat_id} =~ m#([-_.\/\w]+)#;
	my $path = $1; # untaint
	$path = '' if (!$self->{path}->{cat_id});
	my $fulldir = File::Spec->catdir($self->{data_dir}, $path);
	chdir $fulldir;
	# call the program
	# force exec to use an indirect object,
	# so that evil shell stuff will die, even
	# for a program with no arguments
	exec { $progname } @prog_and_args or die "$progname failed: $!\n";
	# NOTREACHED
    }
    return $result;
} # safe_backtick

=head1 INSTALLATION

Installation needs will vary depending on the particular setup a person
has.

=head2 Administrator, Automatic

If you are the administrator of the system, then the dead simple method of
installing the modules is to use the CPAN or CPANPLUS system.

    cpanp -i Posy::Plugin::TextTemplate

This will install this plugin in the usual places where modules get
installed when one is using CPAN(PLUS).

=head2 Administrator, By Hand

If you are the administrator of the system, but don't wish to use the
CPAN(PLUS) method, then this is for you.  Take the *.tar.gz file
and untar it in a suitable directory.

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't like the
"./" notation, you can do this:

   perl Build.PL
   perl Build
   perl Build test
   perl Build install

=head2 User With Shell Access

If you are a user on a system, and don't have root/administrator access,
you need to install Posy somewhere other than the default place (since you
don't have access to it).  However, if you have shell access to the system,
then you can install it in your home directory.

Say your home directory is "/home/fred", and you want to install the
modules into a subdirectory called "perl".

Download the *.tar.gz file and untar it in a suitable directory.

    perl Build.PL --install_base /home/fred/perl
    ./Build
    ./Build test
    ./Build install

This will install the files underneath /home/fred/perl.

You will then need to make sure that you alter the PERL5LIB variable to
find the modules.

Therefore you will need to change
the PERL5LIB variable to add /home/fred/perl/lib

	PERL5LIB=/home/fred/perl/lib:${PERL5LIB}

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

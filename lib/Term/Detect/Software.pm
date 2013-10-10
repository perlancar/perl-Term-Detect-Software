package Term::Detect::Software;

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';
#use Log::Any '$log';

# VERSION

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(detect_terminal detect_terminal_cached);

my $dt_cache;
sub detect_terminal_cached {
    if (!$dt_cache) {
        $dt_cache = detect_terminal(@_);
    }
    $dt_cache;
}

sub detect_terminal {
    my $info = {};

  DETECT:
    {
        last DETECT unless defined $ENV{TERM};

        if ($ENV{KONSOLE_DBUS_SERVICE} || $ENV{KONSOLE_DBUS_SESSION}) {
            $info->{emulator_engine} = 'konsole';
            $info->{color_depth}     = 2**24;
            $info->{default_bgcolor} = '000000';
            $info->{unicode}         = 1;
            $info->{box_chars}       = 1;
            last DETECT;
        }

        if ($ENV{XTERM_VERSION}) {
            $info->{emulator_engine} = 'xterm';
            $info->{color_depth}     = 256;
            $info->{default_bgcolor} = 'ffffff';
            $info->{unicode}         = 0;
            $info->{box_chars}       = 1;
            last DETECT;
        }

        # cygwin terminal
        if ($ENV{TERM} eq 'xterm' && ($ENV{OSTYPE} // '') eq 'cygwin') {
            $info->{emulator_engine} = 'cygwin';
            $info->{color_depth}     = 16;
            $info->{default_bgcolor} = '000000';
            $info->{unicode}         = 0; # CONFIRM?
            $info->{box_chars}       = 1;
            last DETECT;
        }

        if ($ENV{TERM} eq 'linux') {
            # Linux virtual console
            $info->{emulator_engine} = 'linux';
            $info->{color_depth}     = 16;
            $info->{default_bgcolor} = '000000';
            # actually it can show a few Unicode characters like single borders
            $info->{unicode}         = 0;
            $info->{box_chars}       = 0;
            last DETECT;
        }

        my $gnome_terminal_terms = [qw/gnome-terminal guake xfce4-terminal
                                       mlterm lxterminal/];

        my $set_gnome_terminal_term = sub {
            $info->{emulator_software} = $_[0];
            $info->{emulator_engine}   = 'gnome-terminal';
            $info->{color_depth}       = 256;
            $info->{unicode}           = 1;
            if ($_[0] ~~ [qw/mlterm/]) {
                $info->{default_bgcolor} = 'ffffff';
            } else {
                $info->{default_bgcolor} = '000000';
            }
            $info->{box_chars} = 1;
        };

        if (($ENV{COLORTERM} // '') ~~ $gnome_terminal_terms) {
            $set_gnome_terminal_term->($ENV{COLORTERM});
            last DETECT;
        }

        # Windows command prompt
        if ($ENV{TERM} eq 'dumb' && $ENV{windir}) {
            $info->{emulator_software} = 'windows';
            $info->{emulator_engine}   = 'windows';
            $info->{color_depth}       = 16;
            $info->{unicode}           = 0;
            $info->{default_bgcolor}   = '000000';
            $info->{box_chars}         = 0;
            last DETECT;
        }

        # run under CGI or something like that
        if ($ENV{TERM} eq 'dumb') {
            $info->{emulator_software} = 'dumb';
            $info->{emulator_engine}   = 'dumb';
            $info->{color_depth}       = 0;
            # XXX how to determine unicode support?
            $info->{default_bgcolor}   = '000000';
            $info->{box_chars}         = 0;
            last DETECT;
        }

        require SHARYANTO::Proc::Util;
        if ($^O !~ /Win/) {
            my $ppids = SHARYANTO::Proc::Util::get_parent_processes();
            # [0] is shell
            my $proc = $ppids && @$ppids >= 1 ? $ppids->[1]{name} : '';
            #say "D:proc=$proc";
            if ($proc ~~ $gnome_terminal_terms) {
                $set_gnome_terminal_term->($proc);
                last DETECT;
            } elsif ($proc ~~ [qw/rxvt mrxvt/]) {
                $info->{emulator_software} = $proc;
                $info->{emulator_engine}   = 'rxvt';
                $info->{color_depth}       = 16;
                $info->{unicode}           = 0;
                $info->{default_bgcolor}   = 'd6d2d0';
                $info->{box_chars}         = 1;
                last DETECT;
            } elsif ($proc ~~ [qw/pterm/]) {
                $info->{emulator_software} = $proc;
                $info->{emulator_engine}   = 'putty';
                $info->{color_depth}       = 256;
                $info->{unicode}           = 0;
                $info->{default_bgcolor}   = '000000';
                last DETECT;
            } elsif ($proc ~~ [qw/xvt/]) {
                $info->{emulator_software} = $proc;
                $info->{emulator_engine}   = 'xvt';
                $info->{color_depth}       = 0; # only support bold
                $info->{unicode}           = 0;
                $info->{default_bgcolor}   = 'd6d2d0';
                last DETECT;
            }
        }

        # generic
        {
            unless (exists $info->{color_depth}) {
                if ($ENV{TERM} =~ /256color/) {
                    $info->{color_depth} = 256;
                }
            }

            $info->{emulator_software} //= '(generic)';
            $info->{emulator_engine} //= '(generic)';
            $info->{unicode} //= 0;
            $info->{color_depth} //= 0;
            $info->{box_chars} //= 0;
            $info->{default_bgcolor} //= '000000';
        }

    } # DETECT

    $info;
}

1;
#ABSTRACT: Detect terminal (emulator) software and its capabilities

=head1 SYNOPSIS

 use Term::Detect::Software qw(detect_terminal detect_terminal_cached);
 my $res = detect_terminal();


=head1 DESCRIPTION

This module uses several heuristics to find out what terminal (emulator)
software the current process is running in, and its capabilities/settings. This
module complements other modules such as L<Term::Terminfo> and
L<Term::Encoding>.


=head1 FUNCTIONS

=head2 detect_terminal() => HASHREF

Return a hashref containing information about running terminal (emulator)
software and its capabilities/settings. Return empty hashref if not detected
running under termina (i.e. C<$ENV{TERM}> is undef).

Detection method is tried from the easiest/cheapest (e.g. checking environment
variables) or by looking at known process names in the process tree (using the
B<pstree> command). Terminal capabilities is determined using heuristics.

Currently Konsole and Konsole-based terminals (like Yakuake) can be detected
through existence of environment variables C<KONSOLE_DBUS_SERVICE> or
C<KONSOLE_DBUS_SESSION>. xterm is detected through C<XTERM_VERSION>. XFCE's
Terminal is detected using C<COLORTERM>. The other software are detected via
known process names.

Terminal capabilities and settings are currently determined via heuristics.
Probing terminal configuration files might be performed in the future.

Result:

=over

=item * emulator_engine => STR

Possible values: konsole, xterm, gnome-terminal, rxvt, pterm (PuTTY), xvt,
windows (CMD.EXE), cygwin.

=item * emulator_software => STR

Either: xfce4-terminal, guake, gnome-terminal, mlterm, lxterminal, rxvt, mrxvt,
putty, xvt, windows (CMD.EXE).

w=item * color_depth => INT

Either 0 (does not support ANSI color codes), 16, 256, or 16777216 (2**24).

=item * default_bgcolor => STR (6-hexdigit RGB)

For example, any xterm is assumed to have white background (ffffff) by default,
while Konsole is assumed to have black (000000). Better heuristics will be done
in the future.

=item * unicode => BOOL

Whether terminal software supports Unicode/wide characters. Note that you should
also check encoding, e.g. using L<Term::Encoding>.

=item * box_chars => BOOL

Whether terminal supports box-drawing characters.

=back

=head2 detect_terminal_cached([$flag]) => ANY

Just like C<detect_terminal()> but will cache the result. Can be used by
applications or modules to avoid repeating detection process.


=head1 FAQ

=head2 What is this module for? Why not Term::Terminfo or Term::Encoding?

This module is first written for L<Text::ANSITable> so that the module can
provide good defaults when displaying formatted and colored tables, especially
on popular terminal emulation software like Konsole (KDE's default terminal),
gnome-terminal (GNOME's default), Terminal (XFCE's default), xterm, rxvt.

The module works by trying to figure out the terminal emulation software because
the information provided by L<Term::Terminfo> and L<Term::Encoding> are
sometimes not specific enough. For example, Term::Encoding can return L<utf-8>
when running under rxvt, but since the software currently lacks Unicode support
we shouldn't display Unicode characters. Another example is color depth:
Term::Terminfo currently doesn't recognize Konsole's 24bit color support and
only gives C<max_colors> 256.


=head1 TODO

=over

=item * Better detection of terminal emulator's background color

By peeking into its configuration.

=back


=head1 SEE ALSO

L<Term::Terminfo>

L<Term::Encoding>

=cut

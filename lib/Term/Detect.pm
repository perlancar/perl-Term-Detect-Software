package Term::Detect;

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';
#use Log::Any '$log';

use SHARYANTO::Proc::Util qw(get_parent_processes);

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
    my ($flag) = @_;
    $flag //= "";

    return undef unless $ENV{TERM};

    my $info = {};

  DETECT:
    {
        if ($flag =~ /p/ && $^O !~ /Win/) {
            my $ppids = get_parent_processes();
            # 0 is shell
            my $proc = $ppids && @$ppids >= 1 ? $ppids->[1]{name} : '';
            #say "D:proc=$proc";
            if ($proc ~~ [qw/gnome-terminal guake xfce4-terminal mlterm lxterminal/]) {
                $info->{emulator_software} = $proc;
                $info->{emulator_engine}   = 'gnome-terminal';
                $info->{color_depth}       = 256;
                $info->{unicode}           = 1;
                if ($proc ~~ [qw/mlterm/]) {
                    $info->{default_bgcolor} = 'ffffff';
                } else {
                    $info->{default_bgcolor} = '000000';
                }
                last DETECT;
            } elsif ($proc ~~ [qw/rxvt mrxvt/]) {
                $info->{emulator_software} = $proc;
                $info->{emulator_engine}   = 'rxvt';
                $info->{color_depth}       = 16;
                $info->{unicode}           = 0;
                $info->{default_bgcolor}   = 'd6d2d0';
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

        if ($ENV{XTERM_VERSION}) {
            $info->{emulator_engine} = 'xterm';
            $info->{color_depth} = 256;
            $info->{default_bgcolor} = 'ffffff';
            $info->{unicode} = 0;
            last DETECT;
        }

        if ($ENV{KONSOLE_DBUS_SERVICE} || $ENV{KONSOLE_DBUS_SESSION}) {
            $info->{emulator_engine} = 'konsole';
            $info->{color_depth} = 2**24;
            $info->{default_bgcolor} = '000000';
            $info->{unicode} = 1;
            last DETECT;
        }

        unless (exists $info->{color_depth}) {
            if ($ENV{TERM} =~ /256color/) {
                $info->{color_depth} = 256;
            }
        }

    } # DETECT

    $info;
}

1;
#ABSTRACT: Detect running under terminal (and get terminal information)

=head1 SYNOPSIS

 use Term::Detect qw(detect_terminal);
 say "Running under terminal" if detect_terminal();


=head1 DESCRIPTION


=head1 FUNCTIONS

=head2 detect_terminal([$flag]) => ANY

Return undef if not detected running under terminal. Otherwise return a hash of
information about terminal (emulator software, color depth). Some information
are only returned if requested via C<$flag>, for performance reason.

C<$flag> is a string and can contain one or more characters to enable/request
extra information. Currently known flags:

=over

=item * p (for parent processes)

=back

Result:

=over

=item * emulator_engine => STR

=item * emulator_software => STR

Currently Konsole and xterm can be detected through environment because they
publish some environment variables.

If $flag contains "p", will execute C<pstree> to try to find out emulator
software from parent process.

=item * color_depth => INT

Either 0 (does not support ANSI color codes), 16, 256, or 16777216 (2**24).

=item * default_bgcolor => STR (6-hexdigit RGB)

For example, any xterm is assumed to have white background (ffffff) by default,
while Konsole is assumed to have black (000000).

=item * unicode => BOOL

Whether terminal supports Unicode/wide characters.

=back

=head2 detect_terminal_cached([$flag]) => ANY

Just like C<detect_terminal()> but will cache the result. Can be used by
applications or modules to avoid repeating detection process.


=head1 TODO

Better detection of terminal emulator's background color by peeking into its
configuration.


=head1 SEE ALSO

=cut

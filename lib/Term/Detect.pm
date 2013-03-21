package Term::Detect;

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(detect_terminal);

sub detect_terminal {
    return undef unless $ENV{TERM};
    1;
}

1;
#ABSTRACT: Detect if program is running under terminal

=head1 SYNOPSIS

 use Term::Detect qw(detect_terminal);
 say "Running under terminal" if detect_terminal();


=head1 DESCRIPTION


=head1 FUNCTIONS

=head2 detect_terminal() => ANY

Return undef if not detected running under terminal.

Return a true value otherwise.


=head1 TODO

=over

=item * Option to provide more information, e.g. Term::Encoding, Term::Cap

=back


=head1 SEE ALSO

=cut

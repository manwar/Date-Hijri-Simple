package Date::Hijri::Simple;

$Date::Hijri::Simple::VERSION = '0.03';

=head1 NAME

Date::Hijri::Simple - Represents Hijri date.

=head1 VERSION

Version 0.03

=cut

use 5.006;
use Data::Dumper;
use Time::localtime;
use List::Util qw/min/;
use POSIX qw/floor ceil/;

use Moo;
use namespace::clean;

use overload q{""} => 'as_string', fallback => 1;

=head1 DESCRIPTION

Represents the Hijri date.

=cut

our $HIJRI_MONTHS = [
    undef,
    q/Muharram/, q/Safar/ , q/Rabi' al-awwal/, q/Rabi' al-thani/,
    q/Jumada al-awwal/, q/Jumada al-thani/, q/Rajab/ , q/Sha'aban/,
    q/Ramadan/ , q/Shawwal/ , q/Dhu al-Qi'dah/ , q/Dhu al-Hijjah/
];

our $HIJRI_DAYS = [
    '<yellow><bold>      al-Ahad </bold></yellow>',
    '<yellow><bold>   al-Ithnayn </bold></yellow>',
    '<yellow><bold> ath-Thulatha </bold></yellow>',
    '<yellow><bold>     al-Arbia </bold></yellow>',
    '<yellow><bold>    al-Khamis </bold></yellow>',
    '<yellow><bold>    al-Jumuah </bold></yellow>',
    '<yellow><bold>      as-Sabt </bold></yellow>',
];

our $HIJRI_LEAP_YEAR_MOD = [
    2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29
];

has hijri_epoch         => (is => 'ro', default => sub { 1948439.5            });
has hijri_days          => (is => 'ro', default => sub { $HIJRI_DAYS          });
has hijri_months        => (is => 'ro', default => sub { $HIJRI_MONTHS        });
has hijri_leap_year_mod => (is => 'ro', default => sub { $HIJRI_LEAP_YEAR_MOD });

has year  => (is => 'rw', predicate => 1);
has month => (is => 'rw', predicate => 1);
has day   => (is => 'rw', predicate => 1);

with 'Date::Utils';

sub BUILD {
    my ($self) = @_;

    $self->validate_year($self->year)   if $self->has_year;
    $self->validate_month($self->month) if $self->has_month;
    $self->validate_day($self->day)     if $self->has_day;

    unless ($self->has_year && $self->has_month && $self->has_day) {
        my $today = localtime;
        my $year  = $today->year + 1900;
        my $month = $today->mon + 1;
        my $day   = $today->mday;
        my $date  = $self->from_gregorian($year, $month, $day);
        $self->year($date->year);
        $self->month($date->month);
        $self->day($date->day);
    }
}

=head1 SYNOPSIS

    use strict; use warnings;
    use Date::Hijri::Simple;

    # prints today's hijri date
    print Date::Hijri::Simple->new, "\n";

    # prints given hijri date
    print Date::Hijri::Simple->new({ year => 1436, month => 1, day => 1 })->as_string

    # prints equivalent Julian date
    print $date->to_julian, "\n";

    # prints equivalent Gregorian date
    print $date->to_gregorian, "\n";

    # prints day of the week index (0 for Yekshanbeh, 1 for Doshanbehl and so on.
    print $date->day_of_week, "\n";

=head1 METHODS

=head2 to_julian()

Returns julian date equivalent of the Hijri date.

=cut

sub to_julian {
    my ($self) = @_;

    return ($self->day + ceil(29.5 * ($self->month - 1))
            + ($self->year - 1) * 354
            + floor((3 + (11 * $self->year)) / 30)
            + $self->hijri_epoch) - 1;
}

=head2 from_julian($julian_date)

Returns Hijri  date as an object of type L<Date::Hijri::Simple> equivalent of the
given Julian date C<$julian_date>.

=cut

sub from_julian {
    my ($self, $julian_date) = @_;

    $julian_date = floor($julian_date) + 0.5;
    my $year     = floor(((30 * ($julian_date - $self->hijri_epoch)) + 10646) / 10631);
    my $a_hijri  = Date::Hijri::Simple->new({ year => $year, month => 1, day => 1 });
    my $month    = min(12, ceil(($julian_date - (29 + $a_hijri->to_julian)) / 29.5) + 1);
    my $b_hijri  = Date::Hijri::Simple->new({ year => $year, month => $month, day => 1 });
    my $day      = ($julian_date - $b_hijri->to_julian) + 1;

    return Date::Hijri::Simple->new({
        year  => $year,
        month => $month,
        day   => $day });
}

=head2 to_gregorian()

Returns gregorian date (yyyy-mm-dd) equivalent of the Hijri date.

=cut

sub to_gregorian {
    my ($self) = @_;

    my @date = $self->julian_to_gregorian($self->to_julian);
    return sprintf("%04d-%02d-%02d", $date[0], $date[1], $date[2]);
}

=head2 from_gregorian($year, $month, $day)

Returns Hijri  date as an object of type L<Date::Hijri::Simple> equivalent of the
Gregorian date C<$year>, C<$month> and C<$day>.

=cut

sub from_gregorian {
    my ($self, $year, $month, $day) = @_;

    return $self->from_julian($self->gregorian_to_julian($year, $month, $day));
}

=head2 day_of_week()

Returns day of the week, starting 0 for al-Ahad, 1 for al-Ithnayn and so on.

    +--------------+------------------------------------------------------------+
    | Arabic Name  | English Name                                               |
    +--------------+------------------------------------------------------------+
    |      al-Ahad | Sunday                                                     |
    |   al-Ithnayn | Monday                                                     |
    | ath-Thulatha | Tuesday                                                    |
    |     al-Arbia | Wednesday                                                  |
    |    al-Khamis | Thursday                                                   |
    |    al-Jumuah | Friday                                                     |
    |      as-Sabt | Saturday                                                   |
    +--------------+------------------------------------------------------------+

=cut

sub day_of_week {
    my ($self) = @_;

    return $self->jwday($self->to_julian);
}

=head2 is_hijri_leap_year($year)

Returns 0 or 1 if the given Hijri year C<$year> is a leap year or not.

=cut

sub is_hijri_leap_year {
    my ($self, $year) = @_;

    my $mod = $year % 30;
    return 1 if grep/$mod/, @{$self->hijri_leap_year_mod};
    return 0;
}

=head2 days_in_hijri_year($year)

Returns the number of days in the given year of Hijri Calendar.

=cut

sub days_in_hijri_year {
    my ($self, $year) = @_;

    ($self->is_hijri_leap_year($year))
    ?
    (return 355)
    :
    (return 354);
}

=head2 days_in_hijri_month_year($month, $year)

Returns total number of days in the given Hijri month year.

=cut

sub days_in_hijri_month_year {
    my ($self, $month, $year) = @_;

    return 30 if (($month % 2 == 1) || (($month == 12) && ($self->is_hijri_leap_year($year))));
    return 29;
}

=head2 validate_day($day)

Dies if the given C<$day> is not a valid Hijri day.

=cut

sub validate_day {
    my ($self, $day) = @_;

    die("ERROR: Invalid day [$day].\n")
        unless (defined($day) && ($day =~ /^\d{1,2}$/) && ($day >= 1) && ($day <= 30));
}

sub as_string {
    my ($self) = @_;

    return sprintf("%d, %s %d", $self->day, $self->hijri_months->[$self->month], $self->year);
}

=head1 AUTHOR

Mohammad S Anwar, C<< <mohammad.anwar at yahoo.com> >>

=head1 REPOSITORY

L<https://github.com/Manwar/Date-Hijri-Simple>

=head1 BUGS

Please report any bugs / feature requests to C<bug-date-hijri-simple at rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Date-Hijri-Simple>.
I will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Date::Hijri::Simple

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Date-Persian-Simple>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Date-Persian-Simple>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Date-Persian-Simple>

=item * Search CPAN

L<http://search.cpan.org/dist/Date-Persian-Simple/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Mohammad S Anwar.

This program  is  free software; you can redistribute it and / or modify it under
the  terms  of the the Artistic License (2.0). You may obtain a  copy of the full
license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any  use,  modification, and distribution of the Standard or Modified Versions is
governed by this Artistic License.By using, modifying or distributing the Package,
you accept this license. Do not use, modify, or distribute the Package, if you do
not accept this license.

If your Modified Version has been derived from a Modified Version made by someone
other than you,you are nevertheless required to ensure that your Modified Version
 complies with the requirements of this license.

This  license  does  not grant you the right to use any trademark,  service mark,
tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge patent license
to make,  have made, use,  offer to sell, sell, import and otherwise transfer the
Package with respect to any patent claims licensable by the Copyright Holder that
are  necessarily  infringed  by  the  Package. If you institute patent litigation
(including  a  cross-claim  or  counterclaim) against any party alleging that the
Package constitutes direct or contributory patent infringement,then this Artistic
License to you shall terminate on the date that such litigation is filed.

Disclaimer  of  Warranty:  THE  PACKAGE  IS  PROVIDED BY THE COPYRIGHT HOLDER AND
CONTRIBUTORS  "AS IS'  AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES. THE IMPLIED
WARRANTIES    OF   MERCHANTABILITY,   FITNESS   FOR   A   PARTICULAR  PURPOSE, OR
NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY YOUR LOCAL LAW. UNLESS
REQUIRED BY LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL,  OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE
OF THE PACKAGE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1; # End of Date::Hijri::Simple

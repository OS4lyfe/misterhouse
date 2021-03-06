###########################################################################
#
# This file is auto-generated by the Perl DateTime Suite time locale
# generator (0.03).  This code generator comes with the
# DateTime::Locale distribution in the tools/ directory, and is called
# generate_from_cldr.
#
# This file as generated from the CLDR XML locale data.  See the
# LICENSE.cldr file included in this distribution for license details.
#
# This file was generated from the source file bg.xml.
# The source file version number was 1.72, generated on
# 2006/10/26 22:46:07.
#
# Do not edit this file directly.
#
###########################################################################

package DateTime::Locale::bg;

use strict;

BEGIN
{
    if ( $] >= 5.006 )
    {
        require utf8; utf8->import;
    }
}

use DateTime::Locale::root;

@DateTime::Locale::bg::ISA = qw(DateTime::Locale::root);

my @day_names = (
"понеделник",
"вторник",
"сряда",
"четвъртък",
"петък",
"събота",
"неделя",
);

my @day_abbreviations = (
"пн",
"вт",
"ср",
"чт",
"пт",
"сб",
"нд",
);

my @day_narrows = (
"п",
"в",
"с",
"ч",
"п",
"с",
"н",
);

my @month_names = (
"януари",
"февруари",
"март",
"април",
"май",
"юни",
"юли",
"август",
"септември",
"октомври",
"ноември",
"декември",
);

my @month_abbreviations = (
"ян\.",
"февр\.",
"март",
"апр\.",
"май",
"юни",
"юли",
"авг\.",
"септ\.",
"окт\.",
"ноем\.",
"дек\.",
);

my @month_narrows = (
"я",
"ф",
"м",
"а",
"м",
"ю",
"ю",
"а",
"с",
"о",
"н",
"д",
);

my @quarter_names = (
"1\-во\ тримесечие",
"2\-ро\ тримесечие",
"3\-то\ тримесечие",
"4\-то\ тримесечие",
);

my @quarter_abbreviations = (
"I\ трим\.",
"II\ трим\.",
"III\ трим\.",
"IV\ трим\.",
);

my @am_pms = (
"пр\.\ об\.",
"сл\.\ об\.",
);

my @era_names = (
"пр\.н\.е\.",
"сл\.н\.е\.",
);

my @era_abbreviations = (
"пр\.\ н\.\ е\.",
"от\ н\.\ е\.",
);

my $date_parts_order = "dmy";


sub day_names                      { \@day_names }
sub day_abbreviations              { \@day_abbreviations }
sub day_narrows                    { \@day_narrows }
sub month_names                    { \@month_names }
sub month_abbreviations            { \@month_abbreviations }
sub month_narrows                  { \@month_narrows }
sub quarter_names                  { \@quarter_names }
sub quarter_abbreviations          { \@quarter_abbreviations }
sub am_pms                         { \@am_pms }
sub era_names                      { \@era_names }
sub era_abbreviations              { \@era_abbreviations }
sub full_date_format               { "\%d\ \%B\ \%\{ce_year\}\,\ \%A" }
sub long_date_format               { "\%d\ \%B\ \%\{ce_year\}" }
sub medium_date_format             { "\%d\.\%m\.\%\{ce_year\}" }
sub short_date_format              { "\%d\.\%m\.\%y" }
sub long_time_format               { "\%H\:\%M\:\%S" }
sub date_parts_order               { $date_parts_order }



1;


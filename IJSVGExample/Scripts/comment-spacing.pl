#!/usr/bin/perl
#
#  comment-spacing.pl
#  IJSVGExample
#
#  Created by Curtis Hard on 13/10/2026.
#  Copyright © 2026 Curtis Hard. All rights reserved.
#

use strict;
use warnings;

my $mode = shift @ARGV // '';
die "Usage: comment-spacing.pl --check|--fix files...\n"
    unless ($mode eq '--check' || $mode eq '--fix') && @ARGV;
my $failed = 0;

for my $path (@ARGV) {
    open my $input, '<:raw', $path or die "$path: $!\n";
    local $/;
    my $source = <$input>;
    close $input;
    my @insertions;
    my $previous_comment_end = -1;

    # Skip strings and block comments before identifying actual line comments.
    while ($source =~ m{
        (?:u8|u|U|L)?R"(?<delimiter>[^\s()\\]{0,16})\(.*?\)\k<delimiter>"
        | "(?:\\.|[^"\\])*"
        | (?<![\w])(?:u8|u|U|L)?'(?:\\.|[^'\\])*'
        | /\*.*?\*/
        | (?<comment>//(?:\\\r?\n|[^\r\n])*)
    }gsx) {
        next unless defined $+{comment};
        my $start = $-[0];
        my $end = $+[0];
        my $line_start = rindex($source, "\n", $start - 1) + 1;
        next unless substr($source, $line_start, $start - $line_start) =~ /\A[\t ]*\z/;

        if ($line_start > 0) {
            my $previous_start = rindex($source, "\n", $line_start - 2) + 1;
            my $previous_line = substr($source, $previous_start, $line_start - $previous_start);
            my $blank = $previous_line =~ /\A\s*\z/;
            my $continued = $previous_line =~ /\\\r?\n\z/;
            my $same_block = $previous_comment_end >= $previous_start;
            my $opens_block = $previous_line =~ /\{[\t ]*\r?\n\z/;
            if (!$blank && !$continued && !$same_block && !$opens_block) {
                push @insertions, $line_start;
            }
        }
        $previous_comment_end = $end;
    }

    next unless @insertions;
    if ($mode eq '--check') {
        for my $offset (@insertions) {
            my $prefix = substr($source, 0, $offset);
            my $line = 1 + ($prefix =~ tr/\n/\n/);
            print STDERR "$path:$line: add a blank line before this comment block\n";
        }
        $failed = 1;
        next;
    }

    my $newline = $source =~ /\r\n/ ? "\r\n" : "\n";
    for my $offset (reverse @insertions) {
        substr($source, $offset, 0, $newline);
    }
    open my $output, '>:raw', $path or die "$path: $!\n";
    print {$output} $source;
    close $output or die "$path: $!\n";
}

exit $failed;

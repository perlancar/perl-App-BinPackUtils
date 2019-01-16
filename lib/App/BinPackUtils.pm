package App::BinPackUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

my %arg_bin_size = (
    bin_size => {
        schema => ['filesize*'],
        req => 1,
        cmdline_aliases => {s=>{}},
    },
);

my %arg_files = (
    files => {
        schema => ['array*', of=>'filename*', min_len=>1],
        req => 1,
        pos => 0,
        greedy => 1,
    },
);

my %arg_move = (
    move => {
        summary => 'Actually move the files to the bins',
        schema => 'bool*',
    },
);

$SPEC{pack_bins} = {
    v => 1.1,
    summary => 'Pack items into bin',
    args => {
        %arg_bin_size,
        items => {
            schema => ['array*', of=>'str*'],
            summary => 'The items to be binned',
            description => <<'_',

Each item should be in this format: "label,size" (or an array with two elements,
the first one is the label and the second its size).

_
            req => 1,
            pos => 0,
            greedy => 1,
            cmdline_src => 'stdin_or_args',
        },
    },
    examples => [
        {
            argv => ["-s", 100, "A,10", "B,50", "C,30", "D,70", "E,40", "F,40", "G,25"],
        },
    ],
};
sub pack_bins {
    require Algorithm::BinPack;

    my %args = @_;

    my $bp = Algorithm::BinPack->new(binsize => $args{bin_size});
    for my $item (@{ $args{items} }) {
        if (ref $item eq 'ARRAY') {
            $bp->add_item(label => $item->[0], size => $item->[1]);
        } else {
            my @item = split /\s*,\s*/, $item;
            $bp->add_item(label => $item[0], size => $item[1]);
        }
    }
    [200, "OK", [$bp->pack_bins]];
}

$SPEC{bin_files} = {
    v => 1.1,
    summary => 'Put files into bins',
    args => {
        %arg_bin_size,
        bin_prefix => {
            schema => 'filename*',
            default => 'bin',
        },
        %arg_files,
        %arg_move,
    },
    deps => {
        prog => 'du',
    },
};
sub bin_files {
    require String::ShellQuote;

    my %args = @_;
    my $bin_prefix = $args{bin_prefix} // "bin";

    my @items;
    for my $file (@{ $args{files} }) {
        return [404, "File '$file' does not exist"] unless -e $file;

        my $cmd = "du -sb ".String::ShellQuote::shell_quote($file);
        my $out = `$cmd`;
        my $size;
        if ($out =~ /\A(\d+)/) {
            $size = $1;
        } else {
            return [500, "Cannot find the size of '$file': $!"];
        }
        push @items, [$file, $size];
    }

    my $res = pack_bins(bin_size => $args{bin_size}, items => \@items);
    return $res unless $res->[0] == 200;

    # reformat as a single 2D table
    my @rows;
    my $bin_num = 0;
    for my $bin (@{ $res->[2] }) {
        $bin_num++;
        for my $item (@{ $bin->{items} }) {
            push @rows, {
                bin => "$bin_prefix$bin_num",
                file=>$item->{label},
                size=>$item->{size},
            };
        }
    }
    [200, "OK", \@rows];
}

$SPEC{bin_files_into_dvds} = {
    v => 1.1,
    summary => 'Put files into DVD bins',
    args => {
        %arg_files,
        %arg_move,
    },
    deps => {
        prog => 'du', # XXX indirectly
    },
};
sub bin_files_into_dvds {
    my %args = @_;

    bin_files(
        files => $args{files},
        move  => $args{move},
        bin_prefix => "dvd",
        bin_size   => 4493*1024*1024,
    );
}

1;
# ABSTRACT: Collection of CLI utilities related to packing items into bins

=head1 DESCRIPTION

This distribution provides the following command-line utilities:

#INSERT_EXECS_LIST

Keywords: binpack, bin pack, packbin, pack bins, packing, binning.


=head1 SEE ALSO

L<Algorithm::BinPack>

=cut

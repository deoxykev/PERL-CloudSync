use autodie;
BEGIN {
my $trace_file = $ENV{TRACE_FILE} // "mytrace.$$";
print STDERR "Saving trace to $trace_file\n";
 
my $fh = do {
       if( $trace_file eq '-'      ) { \*STDOUT }
    elsif( $trace_file eq 'STDERR' ) { \*STDERR }
    else {
        open my $fh, '>>', $trace_file;
        $fh;
        }
    };
 
sub DB::DB {
    my( $package, $file, $line ) = caller;
    return unless $file eq $0;
    my $code = \@{"::_<$file"};
    print $fh "[@{[time]}] $file $l $code->[$line] $line";
    }
}
 
1;


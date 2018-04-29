#!/usr/bin/perl

use strict;
use warnings;

# modules
# use Switch;

# format
# Incoming Message For Device From EFS (Phone) to GW (9001) at 11:53:59
# Outgoing Message From Device to CMS from EFS (Phone) (9501) at 11:53:59
# Incoming Message For Device to CMS from EFS (Phone) (9501) at 11:53:59
# Outgoing Message From Device From EFS (Phone) to GW (9001) at 11:53:59
# ...
# Message Type................ 0200
# Bit Map..................... F2244401082080000000000000000004
#   2 Primary Account Number.. (16) 542482******0662
#   3 Processing Code......... 140000
#   4 Amount.................. 000000000950
#   7 Date and Time........... 0425035522
#  11 System Trace Number..... 038468
#  14 Expiry Date............. ****
#  18 Merchant Type........... 5999
#  22 POS Entry Mode.......... 810
#  32 Acquiring Institution... (04) 5152
#  37 Retrieval Reference No.. 1c8dc7e5646a
#  43 Card Accept Name........ ··········PayMaya·ShopCG3·Pioneer·St··PH
#  49 Currency Code........... 608
# 126 Reserved Private........ (36) e0d9e7a5-7349-4d66-bb8f-6900afb52699

my $href_LookupData   = {};
my $DataStreamStarted = undef;

my $MessageType              = undef;
my $PrimaryAccountNumber     = undef;
my $ProcessingCode           = undef;
my $SystemTraceNumber        = undef;
my $RetrievalReferenceNumber = undef;
my $TimeLeg1                 = undef;
my $TimeLeg2                 = undef;
my $TimeLeg3                 = undef;
my $TimeLeg4                 = undef;

# process pipe
while (<>) {
    chomp($_);

    # remove trailing \cM
    $_ =~ tr/\cM//d;

    # mark beginning of data stream
    if ( $_ =~ /^Incoming Message.+\(9001\) at (.+)$/ ) {    # leg 1
         # SAMPLE: Incoming Message For Device From EFS (Phone) to GW (9001) at 11:53:59
        $DataStreamStarted = 1;
        $TimeLeg1          = $1;
    }
    elsif ( $_ =~ /^Outgoing Message.+\(9501\) at (.+)$/ ) {    # leg 2
         # SAMPLE: Outgoing Message From Device to CMS from EFS (Phone) (9501) at 11:53:59
        $DataStreamStarted = 1;
        $TimeLeg2          = $1;
    }
    elsif ( $_ =~ /^Incoming Message.+\(9501\) at (.+)$/ ) {    # leg 3
         # SAMPLE: Incoming Message For Device to CMS from EFS (Phone) (9501) at 11:53:59
        $DataStreamStarted = 1;
        $TimeLeg3          = $1;
    }
    elsif ( $_ =~ /^Outgoing Message.+\(9001\) at (.+)$/ ) {    # leg 4
         # SAMPLE: Outgoing Message From Device From EFS (Phone) to GW (9001) at 11:53:59
        $DataStreamStarted = 1;
        $TimeLeg4          = $1;
    }

    # reached the end, capture data to hash then reset values
    elsif ( $_ =~ /^$/ ) {
        if (   not defined($SystemTraceNumber)
            or not defined($PrimaryAccountNumber)
            or not defined($RetrievalReferenceNumber) )
        {
            next;
        }

   # key to use: SystemTraceNumber+PrimaryAccountNumber+RetrievalReferenceNumber
        my $UniqueKey =
            $SystemTraceNumber
          . $PrimaryAccountNumber
          . $RetrievalReferenceNumber;

        # store data
        if ( defined($PrimaryAccountNumber) ) {
            $href_LookupData->{$UniqueKey}->{'PrimaryAccountNumber'} =
              $PrimaryAccountNumber;
        }
        if ( defined($MessageType) ) {
            $href_LookupData->{$UniqueKey}->{'MessageType'} = $MessageType;
        }
        if ( defined($ProcessingCode) ) {
            $href_LookupData->{$UniqueKey}->{'ProcessingCode'} =
              $ProcessingCode;
        }
        if ( defined($SystemTraceNumber) ) {
            $href_LookupData->{$UniqueKey}->{'SystemTraceNumber'} =
              $SystemTraceNumber;
        }
        if ( defined($RetrievalReferenceNumber) ) {
            $href_LookupData->{$UniqueKey}->{'RetrievalReferenceNumber'} =
              $RetrievalReferenceNumber;
        }
        if ( defined($TimeLeg1) ) {
            $href_LookupData->{$UniqueKey}->{'TimeLeg1'} = $TimeLeg1;
        }
        if ( defined($TimeLeg2) ) {
            $href_LookupData->{$UniqueKey}->{'TimeLeg2'} = $TimeLeg2;
        }
        if ( defined($TimeLeg3) ) {
            $href_LookupData->{$UniqueKey}->{'TimeLeg3'} = $TimeLeg3;
        }
        if ( defined($TimeLeg4) ) {
            $href_LookupData->{$UniqueKey}->{'TimeLeg4'} = $TimeLeg4;
        }

        # reset
        $DataStreamStarted        = 0;
        $MessageType              = undef;
        $PrimaryAccountNumber     = undef;
        $ProcessingCode           = undef;
        $SystemTraceNumber        = undef;
        $RetrievalReferenceNumber = undef;
        $TimeLeg1                 = undef;
        $TimeLeg2                 = undef;
        $TimeLeg3                 = undef;
        $TimeLeg4                 = undef;
    }

    if ($DataStreamStarted) {

        # look for these
        # Message Type................ 0200
        #   2 Primary Account Number.. (16) 542482******0662
        #   3 Processing Code......... 140000
        #  11 System Trace Number..... 038468
        #  37 Retrieval Reference No.. 1c8dc7e5646a
        # if ($_ =~ /^Message Type\.+ (\d+)$/) {
        if ( $_ =~ /^Message Type\.+ (\d+)/ ) {
            $MessageType = $1;

            # TODO: sanity check, 0200 is only for Leg1
        }
        if ( $_ =~ /^\s+2 Primary Account Number\.+ (.+)$/ ) {
            $PrimaryAccountNumber = $1;
        }
        if ( $_ =~ /^\s+3 Processing Code\.+ (\d+)$/ ) {
            $ProcessingCode = $1;
        }
        if ( $_ =~ /^\s+11 System Trace Number\.+ (\d+)$/ ) {
            $SystemTraceNumber = $1;
        }
        if ( $_ =~ /^\s+37 Retrieval Reference No\.+ (.+)$/ ) {
            $RetrievalReferenceNumber = $1;
        }
    }
}

# print the data
for my $m_key ( keys %$href_LookupData ) {

    my $PrimaryAccountNumber =
      defined( $href_LookupData->{$m_key}->{'PrimaryAccountNumber'} )
      ? $href_LookupData->{$m_key}->{'PrimaryAccountNumber'}
      : next;
      # my $MessageType =
      # mydefined( $href_LookupData->{$m_key}->{'MessageType'} )
      # my? $href_LookupData->{$m_key}->{'MessageType'}
      # my: next;
    my $ProcessingCode =
      defined( $href_LookupData->{$m_key}->{'ProcessingCode'} )
      ? $href_LookupData->{$m_key}->{'ProcessingCode'}
      : next;
    my $SystemTraceNumber =
      defined( $href_LookupData->{$m_key}->{'SystemTraceNumber'} )
      ? $href_LookupData->{$m_key}->{'SystemTraceNumber'}
      : next;
    my $RetrievalReferenceNumber =
      defined( $href_LookupData->{$m_key}->{'RetrievalReferenceNumber'} )
      ? $href_LookupData->{$m_key}->{'RetrievalReferenceNumber'}
      : next;
    my $TimeLeg1 =
      defined( $href_LookupData->{$m_key}->{'TimeLeg1'} )
      ? $href_LookupData->{$m_key}->{'TimeLeg1'}
      : next;
    my $TimeLeg2 =
      defined( $href_LookupData->{$m_key}->{'TimeLeg2'} )
      ? $href_LookupData->{$m_key}->{'TimeLeg2'}
      : next;
    my $TimeLeg3 =
      defined( $href_LookupData->{$m_key}->{'TimeLeg3'} )
      ? $href_LookupData->{$m_key}->{'TimeLeg3'}
      : next;
    my $TimeLeg4 =
      defined( $href_LookupData->{$m_key}->{'TimeLeg4'} )
      ? $href_LookupData->{$m_key}->{'TimeLeg4'}
      : next;

    # csv
    print $PrimaryAccountNumber . ','
    # . $MessageType . ','
      . $ProcessingCode . ','
      . $SystemTraceNumber . ','
      . $RetrievalReferenceNumber . ','
      . $TimeLeg1 . ','
      . $TimeLeg2 . ','
      . $TimeLeg3 . ','
      . $TimeLeg4 . "\n";
}

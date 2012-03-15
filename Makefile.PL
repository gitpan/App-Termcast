
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "broadcast your terminal sessions for remote viewing",
  "AUTHOR" => "Jesse Luehrs <doy at tozt dot net>",
  "BUILD_REQUIRES" => {
    "File::Find" => 0,
    "File::Temp" => 0,
    "Test::More" => "0.88",
    "Test::Requires" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "App-Termcast",
  "EXE_FILES" => [
    "bin/stream_ttyrec",
    "bin/termcast"
  ],
  "LICENSE" => "perl",
  "NAME" => "App::Termcast",
  "PREREQ_PM" => {
    "Getopt::Long" => 0,
    "IO::Select" => 0,
    "IO::Socket::INET" => 0,
    "JSON" => 0,
    "Moose" => 0,
    "MooseX::Getopt::Dashes" => 0,
    "Scalar::Util" => 0,
    "Term::Filter::Callback" => 0,
    "Term::ReadKey" => 0,
    "Try::Tiny" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.12",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);





use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'App-Termcast',
  NAME      => 'App::Termcast',
  AUTHOR    => 'Jesse\ Luehrs\ \<doy\ at\ tozt\ dot\ net\>',
  ABSTRACT  => 'broadcast\ your\ terminal\ sessions\ for\ remote\ viewing',
  VERSION   => '0.01_01',
  EXE_FILES => [ qw(bin/termcast) ],
  (eval { ExtUtils::MakeMaker->VERSION(6.21) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {
    "MooseX::Getopt" => '0',
    "IO::Pty::Easy" => '0.07',
    "Term::ReadKey" => '0',
    "Moose" => '0',
  },
);

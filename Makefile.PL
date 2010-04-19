
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
                       'test' => {
                                   'TESTS' => 't/*.t'
                                 },
                       'NAME' => 'App::Termcast',
                       'DISTNAME' => 'App-Termcast',
                       'CONFIGURE_REQUIRES' => {
                                                 'ExtUtils::MakeMaker' => '6.31'
                                               },
                       'AUTHOR' => 'Jesse Luehrs <doy at tozt dot net>',
                       'BUILD_REQUIRES' => {},
                       'ABSTRACT' => 'broadcast your terminal sessions for remote viewing',
                       'EXE_FILES' => [
                                        'bin/termcast',
                                        'bin/stream_ttyrec'
                                      ],
                       'VERSION' => '0.06',
                       'PREREQ_PM' => {
                                        'MooseX::Getopt' => '0',
                                        'Scope::Guard' => '0',
                                        'IO::Pty::Easy' => '0.07',
                                        'Term::ReadKey' => '0',
                                        'Moose' => '0'
                                      },
                       'LICENSE' => 'perl'
                     );


delete $WriteMakefileArgs{BUILD_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.56) };

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);




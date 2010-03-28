
use strict;
use warnings;



use ExtUtils::MakeMaker 6.11;



my %WriteMakefileArgs = (
                       'test' => {
                                   'TESTS' => 't/*.t'
                                 },
                       'NAME' => 'App::Termcast',
                       'DISTNAME' => 'App-Termcast',
                       'CONFIGURE_REQUIRES' => {
                                                 'ExtUtils::MakeMaker' => '6.11'
                                               },
                       'AUTHOR' => 'Jesse Luehrs <doy at tozt dot net>',
                       'BUILD_REQUIRES' => {},
                       'ABSTRACT' => 'broadcast your terminal sessions for remote viewing',
                       'EXE_FILES' => [
                                        'bin/termcast'
                                      ],
                       'VERSION' => '0.03',
                       'PREREQ_PM' => {
                                        'MooseX::Getopt' => '0',
                                        'Scope::Guard' => '0',
                                        'IO::Pty::Easy' => '0.07',
                                        'Term::ReadKey' => '0',
                                        'Moose' => '0'
                                      },
                       'LICENSE' => 'perl'
                     );


delete $WriteMakefileArgs{LICENSE}
  unless eval { ExtUtils::MakeMaker->VERSION(6.31) };

WriteMakefile(%WriteMakefileArgs);




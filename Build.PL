use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Posy::Plugin::TextTemplate',
    license             => 'perl',
    dist_author         => 'Kathryn Andersen',
    dist_version_from   => 'lib/Posy/Plugin/TextTemplate.pm',
	requires            => {
	'Posy' => 0.90,
	'Text::Template' => 1.44,
	},
    build_requires => {
        'Test::More' => 0,
    },
);

$builder->create_build_script();

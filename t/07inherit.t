use strict;
use warnings;
use diagnostics;

use Test::More tests => 2;

use_ok( 'Hash::AsObject' );

package Hash::AsObject::Foo;

@Hash::AsObject::Foo::ISA = qw(Hash::AsObject);
*Hash::AsObject::Foo::AUTOLOAD = \&Hash::AsObject::AUTOLOAD;

my $foo = *Hash::AsObject::Foo::AUTOLOAD;  # Suppress "used only once" warning

package main;

is( ref(Hash::AsObject::Foo->new), 'Hash::AsObject::Foo', 'blessing' );



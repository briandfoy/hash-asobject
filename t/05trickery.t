#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'tests' => 21;

use_ok( 'Hash::AsObject' );

# --- Make sure invocations as class methods fail
eval { Hash::AsObject->foo      }; isnt( $@, '', "invoke 'foo' as a class method"      );
eval { Hash::AsObject->AUTOLOAD }; isnt( $@, '', "invoke 'AUTOLOAD' as a class method" );
eval { Hash::AsObject->DESTROY  }; isnt( $@, '', "invoke 'DESTROY' as a class method"  );

# --- Except import() and new(), of course!
eval { Hash::AsObject->new      }; is( $@, '', "invoke 'new' as a class method"    );
eval { Hash::AsObject->import   }; is( $@, '', "invoke 'import' as a class method" );

my $h = Hash::AsObject->new;
isa_ok( $h, 'Hash::AsObject' );

# --- Test behavior of $obj->AUTOLOAD()
is( $h->AUTOLOAD(456), 456, "set element 'AUTOLOAD'" );
is( $h->AUTOLOAD,      456, "get element 'AUTOLOAD'" );
delete $h->{'AUTOLOAD'};
is( $h->AUTOLOAD,        undef, "get non-existent element 'AUTOLOAD'" );
is( $h->AUTOLOAD(undef), undef, "set undefined element 'AUTOLOAD'"    );
is( $h->AUTOLOAD,        undef, "get undefined element 'AUTOLOAD'"    );

# --- Test behavior of $obj->DESTROY()
is( $h->DESTROY(456), 456, "set element 'DESTROY'" );
is( $h->DESTROY,      456, "get element 'DESTROY'" );
delete $h->{'DESTROY'};
is( $h->DESTROY,         undef, "get non-existent element 'DESTROY'"  );
is( $h->DESTROY(undef),  undef, "set undefined element 'DESTROY'"     );
is( $h->DESTROY,         undef, "get undefined element 'DESTROY'"     );

# --- Make sure $obj->new and $obj->import work are equivalent
#     to $obj->{new} and $obj->{import}
is( $h->new('abc'),    'abc', "set element 'new'"    );
is( $h->new,           'abc', "get element 'new'"    );
is( $h->impact('def'), 'def', "set element 'impact'" );
is( $h->impact,        'def', "get element 'impact'" );


package Hash::AsObject;

use strict;
use vars qw($VERSION $AUTOLOAD);

$VERSION = '0.04';

sub AUTOLOAD {
    my $self = shift;
    my $key = $AUTOLOAD;
    
    # --- Figure out which hash element we're dealing with
    if (defined $key) {
        $key =~ s/.*:://;
    } else {
        # --- Someone called $obj->AUTOLOAD -- OK, that's fine, be cool
        # --- Or they might have called $cls->AUTOLOAD, but we'll catch
        #     that below
        $key = 'AUTOLOAD';
    }
    
    # --- We don't need $AUTOLOAD any more, and we need to make sure
    #     it isn't defined in case the next call is $obj->AUTOLOAD
    #     (why the %*@!? doesn't Perl undef this automatically for us
    #     when execution of this sub ends?)
    undef $AUTOLOAD;
    
    # --- Handle special cases: class method invocations, DESTROY, etc.
    if (ref($self) eq '') {
        # --- Class method invocation
        if ($key eq 'import') {
            # --- Ignore $cls->import
            return;
        } elsif ($key eq 'new') {
            # --- Constructor
            my $elems =
                scalar(@_) == 1
                    ? shift   # $cls->new({ foo => $bar, ... })
                    : { @_ }  # $cls->new(  foo => $bar, ...  )
                    ;
            return bless $elems, __PACKAGE__;
        } else {
            # --- All other class methods disallowed
            die "Can't invoke class method '$key' on a Hash::AsObject object";
        }
        # --- TO DO: treat can() and isa() specially?
    } elsif ($key eq 'DESTROY') {
        # --- This is tricky.  There are four distinct cases:
        #       (1) $self->DESTROY($val)
        #       (2) $self->DESTROY()
        #           (2a) $self->{DESTROY} exists and is defined
        #           (2b) $self->{DESTROY} exists but is undefined
        #           (2c) $self->{DESTROY} doesn't exist
        #     Case 1 will never happen automatically, so we handle it normally
        #     In case 2a, we must return the value of $self->{DESTROY} but not
        #       define a method Hash::AsObject::DESTROY
        #     The same is true in case 2b, it's just that the value is undefined
        #     Since we're striving for perfect emulation of hash access, case 2c
        #       must act just like case 2b.
        return $self->{'DESTROY'}          # Case 2c -- autovivify
        unless
            scalar @_                      # Case 1
            or exists $self->{'DESTROY'};  # Case 2a or 2b
    }
    
    # --- Handle the most common case (by far)...
    
    # --- All calls like $obj->foo(1, 2) must fail spectacularly
    die "Too many arguments"
        if scalar(@_) > 1;  # We've already shift()ed $self off of @_
    
    # --- If someone's called $obj->AUTOLOAD
    if ($key eq 'AUTOLOAD') {
        # --- Tread carefully -- we can't define &Hash::AsObject::AUTOLOAD
        #     because that would ruin everything
        return scalar(@_) ? $self->{'AUTOLOAD'} = shift : $self->{'AUTOLOAD'};
    } else {
        # --- Define a stub method in this package (to speed up later invocations)
        my $src = <<"EOS";
sub Hash::AsObject::$key {
    my \$v;
    if (scalar \@_ > 1) {
        \$v = \$_[0]->{'$key'} = \$_[1];
        return undef unless defined \$v;
    } else {
        \$v = \$_[0]->{'$key'};
    }
    if (ref(\$v) eq 'HASH') {
        bless \$v, 'Hash::AsObject';
    } else {
        \$v;
    }
#    return ref(\$v) eq 'HASH' ? bless(\$v, 'Hash::AsObject') : \$v;
}
EOS
        eval $src;
        die "Couldn't define method Hash::AsObject::$key -- $@"
            if $@;
        unshift @_, $self;
        goto &$key;
    }
}


1;


=head1 NAME

Hash::AsObject - hashes with accessors/mutators

=head1 SYNOPSIS

    $h = Hash::AsObject->new;
    $h->foo(123);
    print $h->foo;       # prints 123
    print $h->{'foo'};   # prints 123
    $h->{'bar'}{'baz'} = 456;
    print $h->bar->baz;  # prints 456

=head1 DESCRIPTION

A Hash::AsObject is a blessed hash that provides read-write
access to its elements using accessors.  (Actually, they're both accessors
and mutators.)

It's designed to act as much like plain hashes as possible: for example,
non-existing elements are autovivified just as they would be in a regular
hash.

=head1 PUBLIC METHODS

=over 4

=item B<new>

   $h = Hash::AsObject->new;
   $h = Hash::AsObject->new(\%some_hash);
   $h = Hash::AsObject->new(%some_other_hash);

Create a new L<Hash::AsObject|Hash::AsObject>.

=back

B<NOTE:> Technically, there aren't B<any> public methods defined in
the Hash::AsObject package, but a standard C<new> class method is
emulated using AUTOLOAD.

=head1 CAVEATS

No distinction is made between non-existent elements and those are
present but undefined.  Furthermore, there's no way to delete an
element without resorting to C<< delete $h->{'foo'} >>.

Storing a hash directly into an element of a Hash::AsObject
instance has the effect of blessing that hash into
Hash::AsObject.

For example, the following code:

    my $h = Hash::AsObject->new;
    my $foo = { 'bar' => 1, 'baz' => 2 };
    print ref($foo), "\n";
    $h->foo($foo);
    print ref($foo), "\n";

Produces the following output:

    HASH
    Hash::AsObject

I could fix this, but then code like the following would throw an exception,
because C<< $h->foo($foo) >> will return a plain hash reference, not
an object:

    $h->foo($foo)->bar;

Well, I can make C<< $h->foo($foo)->bar >> work, but then code like
this won't have the desired effect:

    my $foo = { 'bar' => 123 };
    $h->foo($foo);
    $h->foo->bar(456);
    print $foo->{'bar'};  # prints 123
    print $h->foo->bar;   # prints 456

I suppose I could fix I<that>, but that's an awful lot of work for little
apparent benefit.

Let me know if you have any thoughts on this.

=head1 BUGS

The blessing of hashes stored in a Hash::AsObject might be
considered a bug.  Or a feature; it depends on your point of view.

=head1 TO DO

=over 4

=item *

Add the capability to delete elements, perhaps like this:

    use Hash::AsObject 'deleter' => 'kill';
    $h = Hash::AsObject->new({'one' => 1, 'two' => 2});
    kill $h, 'one';

That might seem to violate the prohibition against exporting functions
from object-oriented packages, but then technically it wouldn't be
exporting it B<from> anywhere since the function would be constructed
by hand.  Alternatively, it could work like this:

    use Hash::AsObject 'deleter' => 'kill';
    $h = Hash::AsObject->new({'one' => 1, 'two' => 2});
    $h->kill('one');

But, again, what if the hash contained an element named 'kill'?

=item *

Define multiple classes in C<Hash/AsObject.pm>?  For example, there
could be one package for read-only access to a hash, one for hashes
that throw exceptions when accessors for non-existent keys are called,
etc.  But this is hard to do fully without (a) altering the underlying
hash, or (b) defining methods besides AUTOLOAD. Hmmm...

=back

=head1 VERSION

0.04

=head1 AUTHOR

Paul Hoffman <nkuitse AT cpan DOT org>

=head1 CREDITS

Andy Wardley for L<Template::Stash|Template::Stash>, which was my
inspiration.  Writing template code like this:

    [% foo.bar.baz(qux) %]

Made me yearn to write Perl code like this:

    foo->bar->baz($qux);

=head1 COPYRIGHT

Copyright 2003 Paul M. Hoffman. All rights reserved.

This program is free software; you can redistribute it
and modify it under the same terms as Perl itself. 


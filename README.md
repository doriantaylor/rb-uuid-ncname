# UUID::NCName: Turn UUIDs into NCNames (and back)

```ruby
require 'uuid-ncname'
require 'uuidtools'

uu = UUIDTools::UUID.random_create
# => #<UUID:0x3fff0e597ef8 UUID:df521e0a-9d57-4f04-9a95-fc2888decc5a>

# see below about this :version parameter

nc64 = UUID::NCName.to_ncname uu, version: 1
# => "E31IeCp1X8EqV_CiI3sxaJ"

nc32 = UUID::NCName.to_ncname_32 uu, version: 1
# => "E35jb4cu5k7yevfp4fcen5tc2j"

orig = UUID::NCName.from_ncname nc64, version: 1
# => "df521e0a-9d57-4f04-9a95-fc2888decc5a"

orig == UUID::NCName.from_ncname nc32, version: 1 # => true
orig == uu.to_s                                   # => true

# then you can turn it back into an object or whatever
uu == UUIDTools::UUID.parse(orig)     # => true
```

## Description

The purpose of this module is to devise an alternative representation
of the [UUID](http://tools.ietf.org/html/rfc4122) which conforms to
the constraints of various other identifiers such as NCName, and create an
[isomorphic](http://en.wikipedia.org/wiki/Isomorphism) mapping between
them.

## _FORMAT DEPRECATION NOTICE_

After careful consideration, I have decided to change the UUID-NCName
format in a minor yet incompatible way. In particular, I have moved
the nybble containing
the [`variant`](https://tools.ietf.org/html/rfc4122#section-4.1.1) to
the very end of the identifier, whereas it previously was mixed into
the middle somewhere.

This can be considered an application
of [Postel's Law](https://en.wikipedia.org/wiki/Postel%27s_law), based
on the assumption that these identifiers will be generated through
other methods, and potentially naïvely. Like the `version` field, the
`variant` field has a limited acceptable range of values. If, for
example, one were to attempt to generate a conforming identifier by
simply generating a random Base32 or Base64 string, it will be
difficult to ensure that the `variant` field will indeed conform when
the identifier is converted to a standard UUID. By moving the
`variant` field out to the end of the identifier, everything between
the `version` and `variant` bookends can be generated randomly without
any further consideration, like so:

```ruby
B64_ALPHA = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a + %w(- _)

def make_cheapo_b64_uuid_ncname
  vals = (1..20).map { rand 64 }               # generate the content
  vals.push(rand(4) + 8)                       # last digit is special
  'E' + vals.map { |v| B64_ALPHA[v] }.join('') # 'E' for UUID v4
end

# voilà:

cheap = make_cheapo_b64_uuid_ncname
# => "EXSVv8ezPbSKWoKOkBNWKL"

# now try changing it to a standard UUID:

UUID::NCName.from_ncname cheap, version: 1
# => "5d256ff1-eccf-46d2-b296-a0a3a404d58a"
```

Furthermore, since the default behaviour is to align the bits of the
last byte to the size of the encoding symbol, and since the `variant`
bits are masked, a compliant RFC4122 UUID will _always_ end with `I`,
`J`, `K`, or `L`, in _both_ Base32 (case-insensitive) and Base64
variants.

Since I have already released this gem prior to this format change, I
have added a `:version` parameter to both `to_ncname` and
`from_ncname`. The version currently defaults to `0`, the old one, but
will issue a warning if not explicitly set. Later I will change the
default to `1`, while keeping the warning, then later still, finally
remove the warning with 1 as the default. This should ensure that any
code written during the transition produces the correct results.

> Unless you have to support identifiers generated from version 0.1.3
> or newer, you should be running these methods with `version: 1`.

## Rationale & Method

The UUID is a generic identifier which is large enough to be globally
unique. This makes it useful as a canonical name for data objects in
distributed systems, especially those that cross administrative
jurisdictions, such as the World-Wide Web. The
[representation](http://tools.ietf.org/html/rfc4122#section-3),
however, of the UUID, precludes it from being used in many places
where it would be useful to do so.

In particular, there are grammars for many types of identifiers which
must not begin with a digit. Others are case-insensitive, or
prohibited from containing hyphens (present in both the standard
notation and Base64URL), or indeed anything outside of
`^[A-Za-z_][0-9A-Za-z_]*$`.

The hexadecimal notation of the UUID has a 5/8 chance of beginning
with a digit, Base64 has a 5/32 chance, and Base32 has a 3/16
chance. As such, the identifier must be modified in such a way as to
guarantee beginning with an alphabetic letter (or underscore `_`, but
some grammars even prohibit that, so we omit it as well).

While it is conceivable to simply add a padding character, there are a
few considerations which make it more appealing to derive the initial
character from the content of the UUID itself:

* UUIDs are large (128-bit) identifiers as it is, and it is
  undesirable to add meaningless syntax to them if we can avoid doing
  so.

* 128 bits is an inconvenient number for aligning to both Base32 (130)
  and Base64 (132), though 120 divides cleanly into 5, 6 and 8.

* The 13th quartet, or higher four bits of the
  `time_hi_and_version_field` of the UUID is constant, as it indicates
  the UUID's version. If we encode this value using the scheme common
  to both Base64 and Base32, we get values between `A` and `P`, with
  the valid subset between `B` and `F`.

**Therefore:** extract the UUID's version quartet, shift all
subsequent data 4 bits to the left, zero-pad to the octet, encode with
either _base64url_ or _base32_, truncate, and finally prepend the
encoded version character. Voilà, one token-safe UUID.

## Applications

### XML IDs

The `ID` production appears to have been constricted, inadvertently or
otherwise, from [Name](http://www.w3.org/TR/xml11/#NT-Name) in both
the XML 1.0 and 1.1 specifications,
to [NCName](http://www.w3.org/TR/xml-names/#NT-NCName)
by [XML Schema Part 2](http://www.w3.org/TR/xmlschema-2/#ID). This
removes the colon character `:` from the grammar. The net effect is
that

    <foo id="urn:uuid:b07caf81-baae-449d-8a2e-48c0f5fa5538"/>

while being a _well-formed_ ID _and_ valid under DTD validation, is
_not_ valid per XML Schema Part 2 or anything that uses it (e.g. Relax
NG).

### RDF blank node identifiers

Blank node identifiers in RDF are intended for serialization, to act
as a handle so that multiple RDF statements can refer to the same
blank
node. The
[RDF abstract syntax specifies](http://www.w3.org/TR/rdf-concepts/#section-URI-Vocabulary) that
the validity constraints of blank node identifiers be delegated to the
concrete syntax
specifications. The
[RDF/XML syntax specification](http://www.w3.org/TR/rdf-syntax-grammar/#rdf-id) lists
the blank node identifier as NCName. However, according
to [the Turtle spec](http://www.w3.org/TR/turtle/#BNodes), this is a
valid blank node identifier:

    _:42df00ec-30a2-431f-be9e-e3a612b325db

despite
[an older version](http://www.w3.org/TeamSubmission/turtle/#nodeID)
listing a production equivalent to the more conservative
NCName. NTriples syntax is
[even more constrained](http://www.w3.org/TR/rdf-testcases/#ntriples),
given as `^[A-Za-z][0-9A-Za-z]*$`.

### Generated symbols

> There are only two hard things in computer science: cache
> invalidation and naming things [and off-by-one errors].
>
> -- Phil Karlton [extension of unknown origin]

Suppose you wanted to create a [literate
programming](http://en.wikipedia.org/wiki/Literate_programming) system
(I do). One of your (my) stipulations is that the symbols get defined
in the *prose*, rather than the _code_. However, you (I) still want
to be able to validate the code's syntax, and potentially even run the
code, without having to commit to naming anything. You are (I am) also
interested in creating a global map of classes, datatypes and code
fragments, which can be operated on and tested in isolation, ported to
other languages, or transplanted into the more conventional packages
of programs, libraries and frameworks. The Base32 UUID NCName
representation should be adequate for placeholder symbols in just
about any programming language, save for those which do not permit
identifiers as long as 26 characters (which are extremely scarce).

## Documentation

Generated and deposited
[in the usual place](http://www.rubydoc.info/gems/uuid-ncname/).

## Installation

You know how to do this:

    $ gem install uuid-ncname

Or, [download it off rubygems.org](https://rubygems.org/gems/uuid-ncname).

## Contributing

Bug reports and pull requests are welcome at
[the GitHub repository](https://github.com/doriantaylor/rb-uuid-ncname).

## Copyright & License

©2018 [Dorian Taylor](https://doriantaylor.com/)

This software is provided under
the [Apache License, 2.0](https://www.apache.org/licenses/LICENSE-2.0).

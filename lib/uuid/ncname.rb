# -*- coding: utf-8 -*-
require "uuid/ncname/version"

require 'base64'
require 'base32'
require 'base58'

module UUID::NCName

  private

  MATCH = /^([A-Pa-p]) # zero-width boundary and version bookend
  ([2-7A-Za-z]{24}|[-0-9A-Z_a-z]{20}| # base32 and 64
  (?:[1-9A-HJ-NP-Za-km-z]{15}_{6}|[1-9A-HJ-NP-Za-km-z]{16}_{5}|
  [1-9A-HJ-NP-Za-km-z]{17}_{4}|[1-9A-HJ-NP-Za-km-z]{18}___|
  [1-9A-HJ-NP-Za-km-z]{19}__|[1-9A-HJ-NP-Za-km-z]{20}_|
  [1-9A-HJ-NP-Za-km-z]{21})) # base58 with underscore pad
  ([-0-9A-Z_a-z])$/x.freeze # lax variant bookend and zero-width boundary

  ENCODE = {
    32 => -> (bin, align = true) {
      if align
        bin = bin.unpack 'C*'
        bin[-1] >>= 1
        bin = bin.pack 'C*'
      end

      out = ::Base32.encode bin

      out.downcase[0, 25] # clip off the padding
    },
    58 => -> (bin, _) {
      variant = bin[-1].ord >> 4
      # note the bitcoin alphabet is the one used in draft-msporny-base58
      out = ::Base58.binary_to_base58(bin.chop, :bitcoin)
      # we need to pad base58 with underscores because it is variable length
      out + (?_ * (21 - out.length)) +
        encode_version(variant) # encode_version does variant too
    },
    64 => -> (bin, align = true) {
      if align
        bin = bin.unpack 'C*'
        bin[-1] >>= 2
        bin = bin.pack 'C*'
      end

      out = ::Base64.urlsafe_encode64 bin

      out[0, 21] # clip off the padding
    },
  }

  # note the version symbol is already removed
  DECODE = {
    32 => -> (str, align = true) {
      str = str.upcase[0, 25] + 'A======'
      out = ::Base32.decode(str).unpack 'C*'
      out[-1] <<= 1 if align

      out.pack 'C*'
    },
    58 => -> (str, _) {
      variant = decode_version(str[-1]) << 4
      # warn str
      str = str.chop.tr ?_, ''
      # warn str
      # warn ::Base58.base58_to_binary(str, :bitcoin).length
      ::Base58.base58_to_binary(str, :bitcoin) + variant.chr.b
    },
    64 => -> (str, align = true) {
      str = str[0, 21] + 'A=='
      out = ::Base64.urlsafe_decode64(str).unpack 'C*'
      out[-1] <<= 2 if align

      out.pack 'C*'
    },
  }

  UUF = (['%02x' * 4] + ['%02x' * 2] * 3 + ['%02x' * 6]).join '-'

  FORMAT = {
    str: -> bin { UUF % bin.unpack('C*') },
    urn: -> bin { "urn:uuid:#{UUF % bin.unpack('C*')}" },
    hex: -> bin { bin.unpack 'H*' },
    b64: -> bin { ::Base64.strict_encode64 bin },
    bin: -> bin { bin },
  }

  TRANSFORM = [
    # old version prior to shifting out the variant nybble
    [
      -> data {
        list = data.unpack 'N4'
        version = (list[1] & 0x0000f000) >> 12
        list[1] = (list[1] & 0xffff0000) |
          ((list[1] & 0x00000fff) << 4) | (list[2] >> 28)
        list[2] = (list[2] & 0x0fffffff) << 4 | (list[3] >> 28)
        list[3] <<= 4

        return version, list.pack('N4')
      },
      -> (version, data) {
        version &= 0xf

        list = data.unpack 'N4'
        list[3] >>= 4
        list[3] |= ((list[2] & 0xf) << 28)
        list[2] >>= 4
        list[2] |= ((list[1] & 0xf) << 28)
        list[1] = (
          list[1] & 0xffff0000) | (version << 12) | ((list[1] >> 4) & 0xfff)

        list.pack 'N4'
      },
    ],
    # current version
    [
      -> data {
        list = data.unpack 'N4'
        version = (list[1] & 0x0000f000) >> 12
        variant = (list[2] & 0xf0000000) >> 24
        list[1] = (list[1] & 0xffff0000) |
          ((list[1] & 0x00000fff) << 4) | ((list[2] & 0x0fffffff) >> 24)
        list[2] = (list[2] & 0x00ffffff) << 8 | (list[3] >> 24)
        list[3] = (list[3] << 8) | variant

        return version, list.pack('N4')
      },
      -> (version, data) {
        version &= 0xf

        # warn data.length

        list = data.unpack 'N4'
        # warn list.inspect
        variant = (list[3] & 0xf0) << 24
        list[3] >>= 8
        list[3] |= ((list[2] & 0xff) << 24)
        list[2] >>= 8
        list[2] |= ((list[1] & 0xf) << 24) | variant
        list[1] = (
          list[1] & 0xffff0000) | (version << 12) | ((list[1] >> 4) & 0xfff)

        list.pack 'N4'
      },
    ],
  ]

  def self.encode_version version, radix = 64
    offset = radix == 32 ? 97 : 65
    ((version & 15) + offset).chr
  end

  def self.decode_version version
    (version.upcase.ord - 65) % 16
  end

  def self.assert_version version
    version = 1 unless version
    raise ArgumentError, "version #{version.inspect} is not an integer" unless
      version.respond_to? :to_i
    version = version.to_i
    raise ArgumentError, "there is no version #{version}" unless
      TRANSFORM[version]
    version
  end

  def self.warn_version version
    if version.nil?
      warn 'Set an explicit :version to remove this warning. See documentation.'
      version = 1
    end

    raise 'Version must be 0 or 1' unless [0, 1].include? version

    version
  end

  public

  # This error gets thrown when a UUID-NCName token can't be
  # positively determined to be one version or the other.
  class AmbiguousToken < ArgumentError

    # @return [String] The ambiguous token
    attr_reader :token
    # @return [String] The UUID when decoded using version 0
    attr_reader :v0
    # @return [String] The UUID when decoded using version 1
    attr_reader :v1

    # @param token [#to_s] The token in question
    # @param v0 [#to_s] UUID decoded with decoding scheme version 0
    # @param v1 [#to_s] UUID decoded with decoding scheme version 1

    def initialize token, v0: nil, v1: nil
      @v0 = v0 || from_ncname(token, version: 0)
      @v1 = v1 || from_ncname(token, version: 1)
    end
  end

  # Converts a UUID (or object that when converted to a string looks
  # like a UUID) to an NCName. By default it produces the Base64
  # variant.
  #
  # @param uuid [#to_s] whatever it is, it had better look like a
  #  UUID. This includes UUID objects, URNs, 32-character hex strings,
  #  16-byte binary strings, etc.
  #
  # @param radix [32, 64] either the number 32 or the number 64.
  #
  # @param version [0, 1] An optional formatting version, where 0 is
  #  the naïve original version and 1 moves the `variant` nybble out
  #  to the end of the identifier. The default version is 1.
  # 
  # @param align [true, false] Optional directive to treat the
  #  terminating character as aligned to the numerical base of the
  #  representation. Since the version nybble is removed from the
  #  string and the first 120 bits divide evenly into both Base32 and
  #  Base64, the overhang is only ever 4 bits. This means that when
  #  the terminating character is aligned, it will always be in the
  #  range of the letters A through P in (the RFC 3548/4648
  #  representations of) both Base32 and Base64. When `version` is 1
  #  and the terminating character is aligned, RFC4122-compliant UUIDs
  #  will always terminate with `I`, `J`, `K`, or `L`. Defaults to
  #  `true`.
  # 
  # @return [String] The NCName-formatted UUID.
  #
  def self.to_ncname uuid, radix: 64, version: nil, align: true
    raise 'Radix must be either 32, 58, or 64' unless
      [32, 58, 64].include? radix
    raise 'UUID must be something stringable' if uuid.nil? or
      not uuid.respond_to? :to_s
    align = !!align # coerce to a boolean

    # XXX remove this when appropriate
    # version = warn_version(version)
    version = assert_version version

    uuid = uuid.to_s
    bin  = nil

    if uuid.length == 16
      bin = uuid
    else
      uuid.gsub!(/\s+/, '')
      if (m = /^(?:urn:uuid:)?([0-9A-Fa-f-]{32,})$/.match(uuid))
        bin = [m[1].tr('-', '')].pack 'H*'
      elsif (m = /^([0-9A-Za-z+\/_-]+=*)$/.match(uuid))
        match = m[1].tr('-_', '+/')
        bin = ::Base64.decode64(match)
      else
        raise "Not sure what to do with #{uuid}"
      end
    end

    raise 'Binary representation of UUID is shorter than 16 bytes' if
      bin.length < 16

    uuidver, content = TRANSFORM[version].first.call bin[0, 16]

    encode_version(uuidver, radix) + ENCODE[radix].call(content, align)
  end

  # Converts an NCName-encoded UUID back to its canonical
  # representation. Will return nil if the input doesn't match the
  # radix (if supplied) or is otherwise malformed.
  #
  # @param ncname [#to_s] an NCName-encoded UUID, either a
  #  22-character (Base64) variant, or a 26-character (Base32) variant.
  # 
  # @param radix [nil, 32, 58, 64] Optional radix; will use a heuristic
  #  if omitted.
  #
  # @param format [:str, :urn, :hex, :b64, :bin] An optional formatting
  #  parameter; defaults to `:str`, the canonical string representation.
  #
  # @param version [0, 1] See ::to_ncname. Defaults to 1.
  # 
  # @param align [nil, true, false] See ::to_ncname for details.
  #  Setting this parameter to `nil`, the default, will cause the
  #  decoder to detect the alignment state from the identifier.
  #
  # @param validate [false, true] Check that the ninth (the variant)
  #  octet is correctly masked _after_ decoding.
  #
  # @return [String, nil] The corresponding UUID or nil if the input
  #  is malformed.
  #
  def self.from_ncname ncname,
      radix: nil, format: :str, version: nil, align: nil, validate: false
    raise 'Format must be symbol-able' unless format.respond_to? :to_sym
    raise "Invalid format #{format}" unless FORMAT[format]
    raise 'Align must be true, false, or nil' unless
      [true, false, nil].include? align

    # XXX remove this when appropriate
    # version = warn_version version
    version = assert_version version

    return unless ncname and ncname.respond_to? :to_s

    ncname = ncname.to_s.strip.gsub(/\s+/, '')
    match  = MATCH.match(ncname) or return
    return if align and !/[A-Pa-p]$/.match? ncname # MATCH is lax

    # determine the radix from the input
    if radix
      raise ArgumentError, "Radix must be 32, 58, or 64, not #{radix}" unless
        [32, 58, 64].any? radix
      return unless { 32 => 26, 58 => 23, 64 => 22 }[radix] == ncname.length
    else
      radix = { 26 => 32, 23 => 58, 22 => 64}[ncname.length] or
        raise ArgumentError,
        "Not sure what to do with an identifier of length #{ncname.length}."
    end

    # note MATCH separates the variant
    uuidver, *content = match.captures
    content = content.join

    align   = !!(/[A-Pa-p]$/.match? content) if align.nil?
    uuidver = decode_version uuidver
    content = DECODE[radix].call content, align

    bin = TRANSFORM[version][1].call uuidver, content

    # double-check the variant (high-order bits have to be 10)
    return if validate and bin[8].ord >> 6 != 2

    FORMAT[format].call bin
  end

  # Shorthand for conversion to the Base64 version
  #
  # @param uuid [#to_s] The UUID
  # 
  # @param version [0, 1] See ::to_ncname.
  # 
  # @param align [true, false] See ::to_ncname.
  #
  # @return [String] The Base64-encoded NCName
  #
  def self.to_ncname_64 uuid, version: nil, align: true
    to_ncname uuid, version: version, align: align
  end

  # Shorthand for conversion from the Base64 version
  #
  # @param ncname [#to_s] The Base64 variant of the NCName-encoded UUID
  #
  # @param format [:str, :hex, :b64, :bin] The format
  # 
  # @param version [0, 1] See ::to_ncname.
  # 
  # @param align [true, false] See ::to_ncname.
  #
  # @return [String, nil] The corresponding UUID or nil if the input
  #  is malformed.
  #
  def self.from_ncname_64 ncname, format: :str, version: nil, align: nil
    from_ncname ncname,
      radix: 64, format: format, version: version, align: align
  end

  # Shorthand for conversion to the Base58 version
  #
  # @param uuid [#to_s] The UUID
  # 
  # @param version [0, 1] See ::to_ncname.
  # 
  # @param align [true, false] See ::to_ncname.
  #
  # @return [String] The Base58-encoded NCName
  #
  def self.to_ncname_58 uuid, version: nil, align: true
    to_ncname uuid, radix: 58, version: version, align: align
  end

  # Shorthand for conversion from the Base58 version
  #
  # @param ncname [#to_s] The Base58 variant of the NCName-encoded UUID
  #
  # @param format [:str, :hex, :b64, :bin] The format
  # 
  # @param version [0, 1] See ::to_ncname.
  # 
  # @param align [true, false] See ::to_ncname.
  #
  # @return [String, nil] The corresponding UUID or nil if the input
  #  is malformed.
  #
  def self.from_ncname_58 ncname, format: :str, version: nil, align: nil
    from_ncname ncname,
      radix: 58, format: format, version: version, align: align
  end

  # Shorthand for conversion to the Base32 version
  #
  # @param uuid [#to_s] The UUID
  # 
  # @param version [0, 1] See ::to_ncname.
  # 
  # @param align [true, false] See ::to_ncname.
  #
  # @return [String] The Base32-encoded NCName
  #
  def self.to_ncname_32 uuid, version: nil, align: true
    to_ncname uuid, radix: 32, version: version, align: align
  end

  # Shorthand for conversion from the Base32 version
  #
  # @param ncname [#to_s] The Base32 variant of the NCName-encoded UUID
  #
  # @param format [:str, :hex, :b64, :bin] The format
  # 
  # @param version [0, 1] See ::to_ncname.
  # 
  # @param align [true, false] See ::to_ncname.
  #
  # @return [String, nil] The corresponding UUID or nil if the input
  #  is malformed.
  #
  def self.from_ncname_32 ncname, format: :str, version: nil, align: nil
    from_ncname ncname,
      radix: 32, format: format, version: version, align: align
  end

  # Test if the given token is a UUID NCName, with a hint to its
  # version. This method can positively identify a token as a UUID
  # NCName, but there is a small subset of UUIDs which will produce
  # tokens which are valid in both versions. The method returns
  # `false` if the token is invalid, otherwise it returns `0` or `1`
  # for the guessed version.
  #
  # @note Version 1 tokens always end with `I`, `J`, `K`, or `L` (with
  #  base32 being case-insensitive), so tokens that end in something
  #  else will always be version 0.
  #
  # @param token [#to_s] The token to test
  #
  # @param strict [false, true]
  #
  # @return [false, 0, 1]
  #
  def self.valid? token, strict: false
    token = token.to_s
    if MATCH.match? token
      # false is definitely version zero but true is only maybe version 1
      version = /^(?:.{21}[I-L]|.{25}[I-Li-l])$/.match(token) ? 1 : 0

      # try decoding with validation on 
      uu = from_ncname token, version: version, validate: true

      # note that version 1 will always return something because the
      # method of detecting it is a version 1 also happens to be the
      # method of determining whether or not it is valid.
      return false unless uu

      if version == 1 and strict
        # but we can also check if the input is a valid version 0
        u0 = from_ncname token, version: 0, validate: true
        raise AmbiguousToken.new(token, v0: u0, v1: uu) if u0
      end

      version
    else
      false
    end
  end

end

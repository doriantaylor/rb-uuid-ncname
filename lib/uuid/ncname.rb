require "uuid/ncname/version"

require 'base64'
require 'base32'

module UUID::NCName

  private

  ENCODE = {
    32 => -> bin {
      bin = bin.unpack 'C*'
      bin[-1] >>= 1
      out = ::Base32.encode bin.pack('C*')

      out.downcase[0, 25]
    },
    64 => -> bin {
      bin = bin.unpack 'C*'
      bin[-1] >>= 2
      out = ::Base64.urlsafe_encode64 bin.pack('C*')

      out[0, 21]
    },
  }

  DECODE = {
    32 => -> str {
      str = str.upcase[0, 25] + 'A======'
      out = ::Base32.decode(str).unpack 'C*'
      out[-1] <<= 1

      out.pack 'C*'
    },
    64 => -> str {
      str = str[0, 21] + 'A=='
      out = ::Base64.urlsafe_decode64(str).unpack 'C*'
      out[-1] <<= 2

      out.pack 'C*'
    },
  }

  UUF = (['%02x' * 4] + ['%02x' * 2] * 3 + ['%02x' * 6]).join '-'

  FORMAT = {
    str: -> bin { UUF % bin.unpack('C*') },
    hex: -> bin { bin.unpack 'H*' },
    b64: -> bin { ::Base64.strict_encode64 bin },
    bin: -> bin { bin },
  }

  def self.bin_uuid_to_pair data
    list = data.unpack 'N4'
    version = (list[1] & 0x0000f000) >> 12
    list[1] = (list[1] & 0xffff0000) |
      ((list[1] & 0x00000fff) << 4) | (list[2] >> 28)
    list[2] = (list[2] & 0x0fffffff) << 4 | (list[3] >> 28)
    list[3] <<= 4

    return version, list.pack('N4')
  end

  def self.pair_to_bin_uuid version, data
    version &= 0xf

    list = data.unpack 'N4'
    list[3] >>= 4
    list[3] |= ((list[2] & 0xf) << 28)
    list[2] >>= 4
    list[2] |= ((list[1] & 0xf) << 28)
    list[1] = (
      list[1] & 0xffff0000) | (version << 12) | ((list[1] >> 4) & 0xfff)

    list.pack 'N4'
  end

  def self.encode_version version
    ((version & 15) + 65).chr
  end

  def self.decode_version version
    (version.upcase.ord - 65) % 16
  end

  public

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
  # @return [String] The NCName-formatted UUID.

  def self.to_ncname uuid, radix: 64
    raise 'Radix must be either 32 or 64' unless [32, 64].include? radix
    raise 'UUID must be something stringable' if uuid.nil? or
      not uuid.respond_to? :to_s

    uuid = uuid.to_s

    bin = nil

    if uuid.length == 16
      bin = uuid
    else
      uuid.gsub!(/\s+/, '')
      if (m = /^(?:urn:uuid:)?([0-9A-Fa-f-]{32,})$/.match(uuid))
        bin = [m[1].tr('-', '')].pack 'H*'
      elsif (m = /^([0-9A-Za-z+\/_-]+=*)$/.match(uuid))
        match= m[1].tr('-_', '+/')
        bin = ::Base64.decode64(match)
      else
        raise "Not sure what to do with #{uuid}"
      end
    end

    raise 'Binary representation of UUID is shorter than 16 bytes' if
      bin.length < 16

    version, content = bin_uuid_to_pair bin[0, 16]

    encode_version(version) + ENCODE[radix].call(content)
  end

  # Converts an NCName-encoded UUID back to its canonical
  # representation. Will return nil if the input doesn't match the
  # radix (if supplied) or is otherwise malformed.  doesn't match
  #
  # @param ncname [#to_s] an NCName-encoded UUID, either a
  #  22-character (Base64) variant, or a 26-character (Base32) variant.
  # 
  # @param radix [nil, 32, 64] Optional radix; will use heuristic if omitted.
  #
  # @param format [:str, :hex, :b64, :bin] An optional formatting
  #  parameter; defaults to `:str`, the canonical string representation.
  # 
  # @return [String, nil] The corresponding UUID or nil if the input
  #  is malformed.

  def self.from_ncname ncname, radix: nil, format: :str
    raise 'Format must be symbol-able' unless format.respond_to? :to_sym
    raise "Invalid format #{format}" unless FORMAT[format]

    return unless ncname and ncname.respond_to? :to_s

    ncname = ncname.to_s.strip.gsub(/\s+/, '')
    match  = /^([A-Za-z])([0-9A-Za-z_-]{21,})$/.match(ncname) or return

    if radix
      raise "Radix must be 32 or 64, not #{radix}" unless [32, 64].any? radix
      return unless { 32 => 26, 64 => 22 }[radix] == ncname.length
    else
      len = ncname.length

      if ncname =~ /[_-]/
        radix = 64
      elsif len >= 26
        radix = 32
      elsif len >= 22
        radix = 64
      else
        # uh will this ever get executed now that i put in that return?
        raise "Not sure what to do with an identifier of length #{len}."
      end
    end

    version, content = match.captures
    version = decode_version version
    content = DECODE[radix].call content

    bin = pair_to_bin_uuid version, content

    FORMAT[format].call bin
  end

  # Shorthand for conversion to the Base64 version
  #
  # @param uuid [#to_s] The UUID
  # @return [String] The Base64-encoded NCName

  def self.to_ncname_64 uuid
    to_ncname uuid
  end

  # Shorthand for conversion from the Base64 version
  #
  # @param ncname [#to_s] The Base64 variant of the NCName-encoded UUID
  # @param format [:str, :hex, :b64, :bin] The format

  def self.from_ncname_64 ncname, format: :str
    from_ncname ncname, radix: 64, format: format
  end

  # Shorthand for conversion to the Base32 version
  #
  # @param uuid [#to_s] The UUID
  # @return [String] The Base32-encoded NCName

  def self.to_ncname_32 uuid
    to_ncname uuid, radix: 32
  end

  # Shorthand for conversion from the Base32 version
  #
  # @param ncname [#to_s] The Base32 variant of the NCName-encoded UUID
  # @param format [:str, :hex, :b64, :bin] The format

  def self.from_ncname_32 ncname, format: :str
    from_ncname ncname, radix: 32, format: format
  end

end

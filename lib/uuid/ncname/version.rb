# this is here because it reasonable to expect a *class* in the
# namespace called UUID, so if you say `module UUID; module NCName`,
# it will croak with a "TypeError: UUID is not a module".
unless Module.const_defined? 'UUID'
  module UUID; end
end

module UUID::NCName
  VERSION = "0.2.6"
end

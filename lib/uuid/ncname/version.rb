unless Module.const_defined? 'UUID'
  module UUID; end
end

module UUID::NCName
    VERSION = "0.2.3"
end

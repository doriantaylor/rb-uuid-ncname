unless Module.const_defined? 'UUID'
  module UUID; end
end

module UUID::NCName
    VERSION = "0.1.3"
end

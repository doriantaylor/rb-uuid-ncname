#!/usr/bin/env ruby

require 'uuid-ncname'
require 'csv'
require 'pathname'
require 'uuidtools'

out = Pathname(ARGV.first).expand_path

CSV.open(out, 'wb') do |csv|
  uuids = []
  1000.times { uuids << UUIDTools::UUID.random_create }

  # do the version first
  (0..1).each do |v|
    # then he radices
    uuids.each do |u|
      row = [v, u.to_s]

      [32, 58, 64].each do |r|
        row << UUID::NCName.to_ncname(u, radix: r, version: v)
      end

      csv << row
    end
  end
end


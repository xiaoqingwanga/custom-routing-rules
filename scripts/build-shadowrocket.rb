#!/usr/bin/env ruby
# frozen_string_literal: true
require "yaml"
require "ipaddr"
require "fileutils"

abort "usage: ruby scripts/build-shadowrocket.rb [--check]" unless ARGV.empty? || ARGV == ["--check"]
root = File.expand_path("..", __dir__)
outputs = {}
Dir[File.join(root, "clash/*.yaml")].sort.each do |source|
  name = File.basename(source, ".yaml")
  payload = YAML.safe_load(File.read(source)).fetch("payload")
  raise "invalid payload: #{name}" unless payload.is_a?(Array)
  rules = payload.map do |row|
    raise "invalid rule: #{name}" unless row.is_a?(String) && !row.empty? && row !~ /[\s\x00]/
    if row.include?(",")
      parts = row.split(",", -1)
      raise "embedded policy or invalid rule: #{name}" unless parts.length == 2 || (parts.length == 3 && parts.last == "no-resolve")
      case parts[0]
      when "IP-CIDR", "IP-CIDR6"
        ip = IPAddr.new(parts[1])
        raise "IP family differs: #{name}" unless ip.ipv4? == (parts[0] == "IP-CIDR")
      when "DOMAIN", "DOMAIN-SUFFIX", "DOMAIN-KEYWORD", "DOMAIN-WILDCARD"
        raise "invalid domain rule: #{name}" unless parts.length == 2 && parts[1] =~ /\A[A-Za-z0-9_*?.-]+\z/
      else
        raise "unsupported rule type: #{name}"
      end
      row
    else
      raise "invalid domain: #{name}" unless row =~ /\A(?:\+\.)?[A-Za-z0-9_*?.-]+\z/
      if row.start_with?("+.")
        "DOMAIN-SUFFIX,#{row[2..-1]}"
      elsif row.include?("*") || row.include?("?")
        "DOMAIN-WILDCARD,#{row}"
      else
        "DOMAIN,#{row}"
      end
    end
  end
  outputs[File.join(root, "shadowrocket/#{name}.list")] = [
    "# Generated from clash/#{name}.yaml by scripts/build-shadowrocket.rb.",
    "# Conditions only; routing policy belongs in the client configuration.",
    *rules, ""
  ].join("\n")
end
raise "no Clash rule sources" if outputs.empty?
if ARGV == ["--check"]
  stale = outputs.keys.select { |path| !File.file?(path) || File.read(path) != outputs[path] }
  stale += Dir[File.join(root, "shadowrocket/*.list")] - outputs.keys
  abort "Shadowrocket rules are stale; run ruby scripts/build-shadowrocket.rb" unless stale.empty?
  puts "verified #{outputs.length} Shadowrocket lists against Clash sources"
else
  FileUtils.mkdir_p(File.join(root, "shadowrocket"))
  outputs.each do |path, content|
    File.write(path + ".tmp", content)
    File.rename(path + ".tmp", path)
  end
  puts "generated #{outputs.length} Shadowrocket lists"
end

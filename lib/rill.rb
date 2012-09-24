require 'json'

class Rill

  DEFAULT_CONFIG = {
    :base => Dir.pwd,
    :preloads => []
  }

  def initialize(attrs = nil)
    attrs ||= DEFAULT_CONFIG.dup

    @base = attrs[:base]
    @preloads = attrs[:preloads] || []
  end

  def resolve(mods)
    @modules = []
    @codes = []

    if mods.is_a?(String)
      mods = [mods]
    end
    mods.each do |mod|
      resolve_mod(mod)
    end
  end

  def resolve_mod(mod)
    return if @preloads.include?(mod) || @modules.include?(mod)

    mod = parse_mod(mod)
    path = File.join(@base, "#{mod}.js")
    code = File.open(path).read

    unless code =~ /^define\((['"])[^'"]+\1/
      code = polish(mod, code)
      # fio = File.open(path, 'w')
      # fio.write(code)
    end
    @codes.unshift(code)
    @modules.unshift(mod)

    deps = parse_deps_from_define(code)
    deps.each do |dep|
      dep = expand_path(dep, mod)
      resolve_mod(dep)
    end
  end

  def append(mod, code)
    @modules << mod
    @codes << polish(mod, code)
  end

  def bundle
    @preloads.each do |file|
      code = File.open(File.join(@base, "#{file}.js")).read
      @codes.unshift(code)
    end
    @codes.join("\n")
  end

  # mark the module id
  # parse and set the module dependencies if not present
  def polish(mod, code = nil)
    mod = parse_mod(mod)

    return polish_code(mod, code) unless code.nil? || code == ''

    path = File.join(@base, "#{mod}.js")
    code = File.open(path).read

    unless code =~ /^define\((['"])[^'"]+\1/
      code = polish_code(mod, code)
      fio = File.open(path, 'w')
      fio.write(code)
      fio.close
    end

    code
  end

  def polish_code(mod, code)
    mod = parse_mod(mod)

    if code =~ /^define\(function/
      deps = parse_deps(code)
      deps -= @preloads
      deps_str = deps.length > 0 ? "['#{deps.join("', '")}']" : '[]'

      code.sub!(/^(define\()/, "\\1'#{mod}', #{deps_str}, ")
    elsif code =~ /^define\([\[\{]/
      code.sub!(/^(define\()/, "\\1'#{mod}', ")
    end

    code
  end

  def parse_mod(mod)
    start = 0
    fini = mod.rindex('.js') || mod.length

    mod.slice(start, fini - start)
  end

  def expand_path(dep, mod)
    # 与 File.expand_path 的逻辑还是有些分别的
    base = mod.include?('/') ? mod.slice(0, mod.rindex('/') + 1) : ''

    while dep.start_with?('.')
      dep.sub!(/^\.\//, '')
      if dep.start_with?('../')
        dep.sub!('../', '')
        base.sub!(/[^\/]+\/$/, '')
      end
    end

    base + dep
  end

  def parse_deps_from_define(code)
    pattern = /^define\((['"])[^'"]+\1,\s*(\[[^\]]+\])/
    match = pattern.match(code)
    deps = []

    if match
      deps = match[2]
      deps = JSON.parse(deps.gsub("'", '"'))
      deps.delete_if do |d|
        d.nil? || d =~ /^\s*$/
      end
    else
      pattern = /^define\((['"])[^'"]+\1,\s*(['"])([^\1]+)\1\.split/
      match = pattern.match(code)
      if match
        deps = match[3].split(/,\s*/)
      end
    end

    deps
  end

  def parse_deps(code)
    # Parse these `requires`:
    #   var a = require('a');
    #   someMethod(require('b'));
    #   require('c');
    #   ...
    # Doesn't parse:
    #   someInstance.require(...);
    pattern = /(?:^|[^.])\brequire\s*\(\s*(["'])([^"'\s\)]+)\1\s*\)/
    code = sans_comments(code)
    matches = code.scan(pattern)

    matches.map! do |m|
      m[1]
    end

    matches.uniq.compact
  end

  # http://lifesinger.github.com/lab/2011/remove-comments-safely/
  def sans_comments(code)
    code.gsub(/(?:^|\n|\r)\s*\/\*[\s\S]*?\*\/\s*(?:\r|\n|$)/, "\n").gsub(/(?:^|\n|\r)\s*\/\/.*(?:\r|\n|$)/, "\n")
  end
end
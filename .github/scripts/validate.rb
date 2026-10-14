# Repo checks for design-superskills. Run locally with: ruby .github/scripts/validate.rb
# No gems needed; works on the macOS system Ruby and on GitHub's Ubuntu runners.

require "json"
require "yaml"

Dir.chdir(File.expand_path("../..", __dir__))

$errors = []
def error(msg)
  $errors << msg
end

TRACKED = `git ls-files`.split("\n").reject { |f| f.start_with?("assets/readme/") }
FRONTMATTER = /\A---\n(.*?)\n---\n/m

# 1. Skill and agent frontmatter parses, has the right name, and quotes its description.
(Dir["skills/*/SKILL.md"] + Dir["agents/*.md"]).sort.each do |f|
  raw = File.read(f)[FRONTMATTER, 1]
  next error("#{f}: missing frontmatter block") unless raw

  begin
    data = YAML.safe_load(raw)
  rescue Psych::SyntaxError => e
    next error("#{f}: frontmatter is not valid YAML (#{e.message.sub(/^\(<unknown>\): /, '')})")
  end
  next error("#{f}: frontmatter is not a key/value map") unless data.is_a?(Hash)

  expected = File.basename(f) == "SKILL.md" ? File.basename(File.dirname(f)) : File.basename(f, ".md")
  name = data["name"]
  error("#{f}: name is #{name.inspect}, expected #{expected.inspect}") unless name == expected
  error("#{f}: name must be lowercase letters, digits and hyphens") unless name.to_s =~ /\A[a-z0-9]+(-[a-z0-9]+)*\z/

  desc = data["description"]
  if !desc.is_a?(String) || desc.strip.empty?
    error("#{f}: description is missing or empty")
  else
    error("#{f}: description is #{desc.size} characters (max 1024)") if desc.size > 1024
    # Unquoted descriptions break on ": " and silently truncate at " #", so require quotes.
    unless raw =~ /^description: ['"]/
      error("#{f}: wrap the description in single quotes")
    end
  end
end

# 2. Manifests are valid JSON and agree on name, version and description; CHANGELOG matches.
manifests = {}
%w[.claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json].each do |f|
  begin
    manifests[f] = JSON.parse(File.read(f))
  rescue Errno::ENOENT
    error("#{f}: missing")
  rescue JSON::ParserError => e
    error("#{f}: invalid JSON (#{e.message.lines.first.strip})")
  end
end

plugin = manifests[".claude-plugin/plugin.json"]
market = manifests[".claude-plugin/marketplace.json"]
if plugin && market
  entry = (market["plugins"] || []).find { |p| p["name"] == plugin["name"] }
  if entry.nil?
    error("marketplace.json: no plugin entry named #{plugin['name'].inspect}")
  else
    error("plugin.json version #{plugin['version']} != marketplace.json #{entry['version']}") unless plugin["version"] == entry["version"]
    error("plugin.json and marketplace.json plugin descriptions differ") unless plugin["description"] == entry["description"]
  end
  error("plugin.json: version #{plugin['version'].inspect} is not semver (x.y.z)") unless plugin["version"].to_s =~ /\A\d+\.\d+\.\d+\z/
  top = File.read("CHANGELOG.md")[/^## (\S+)/, 1]
  error("CHANGELOG.md: latest entry is #{top.inspect}, plugin.json is #{plugin['version']}") unless top == plugin["version"]
end

# 3. Every hook command points at an executable script with valid syntax.
if (hooks = manifests["hooks/hooks.json"])
  hooks.fetch("hooks", {}).values.flatten.flat_map { |h| h["hooks"] || [] }.each do |h|
    path = h["command"].to_s[%r{\$\{CLAUDE_PLUGIN_ROOT\}/([^"\s]+)}, 1]
    next unless path
    next error("hooks.json: #{path} does not exist") unless File.file?(path)
    mode = `git ls-files -s -- #{path}`.split.first
    error("#{path}: not executable in git (run: git update-index --chmod=+x #{path})") unless mode == "100755"
    if File.open(path, &:gets).to_s =~ /\A#!.*\b(ba)?sh\b/
      error("#{path}: shell syntax error") unless system("bash", "-n", path)
    end
  end
end

# 4. Repo paths and relative links mentioned in instructions exist.
#    CHANGELOG is history, so old paths there are fine.
docs = TRACKED.select { |f| f.end_with?(".md") && f != "CHANGELOG.md" }
REPO_PATH = %r{(?<![\w/.<-])(?:skills|agents|shared|templates|hooks|assets|\.claude-plugin)/[\w./-]*[\w-]}
docs.each do |f|
  in_fence = false
  File.readlines(f).each_with_index do |line, i|
    in_fence = !in_fence if line =~ /^\s*```/
    line.scan(REPO_PATH) do |p|
      error("#{f}:#{i + 1}: #{p} does not exist") unless File.exist?(p)
    end
    next if in_fence
    line.gsub(/`[^`]*`/, "").scan(/\]\(([^)\s#]+)/).flatten.each do |link|
      next if link =~ %r{\A(https?:|mailto:)}
      error("#{f}:#{i + 1}: broken link #{link}") unless File.exist?(File.join(File.dirname(f), link))
    end
  end
end

# 5. Shell examples use placeholders, not $VARIABLES (they trigger extra permission prompts).
#    Lines after a "# WRONG" comment are deliberate counter-examples.
docs.each do |f|
  lang = nil
  wrong = false
  File.readlines(f).each_with_index do |line, i|
    if line =~ /^\s*```(\w*)/
      lang = lang ? nil : $1
      wrong = false
      next
    end
    next unless %w[bash sh shell zsh].include?(lang)
    wrong = true if line =~ /#.*\bWRONG\b/
    wrong = false if line =~ /#.*\bCORRECT\b/
    next if wrong
    if line =~ /\$\{?(?!CLAUDE_PLUGIN_ROOT)[A-Za-z_]/
      error("#{f}:#{i + 1}: shell variable in example command; use a <placeholder> instead")
    end
  end
end

# 6. Private terms (company, client and product names) stay out of the public repo.
#    Set the PRIVATE_TERMS repo secret to a comma- or newline-separated list. Matches are
#    reported by file and line only, so the terms never appear in public CI logs.
terms = ENV.fetch("PRIVATE_TERMS", "").split(/[,\n]/).map(&:strip).reject(&:empty?)
if terms.any?
  pattern = Regexp.union(terms.map { |t| /\b#{Regexp.escape(t)}\b/i })
  TRACKED.each do |f|
    next unless File.file?(f)
    text = File.binread(f)
    next if text.include?("\0")
    text.force_encoding("UTF-8").scrub.each_line.with_index do |line, i|
      error("#{f}:#{i + 1}: contains a private term") if line =~ pattern
    end
  end
else
  puts "Skipping private-term check (PRIVATE_TERMS not set)"
end

if $errors.empty?
  puts "All checks passed."
else
  puts "#{$errors.size} problem#{'s' unless $errors.size == 1}:"
  $errors.each { |e| puts "  - #{e}" }
  exit 1
end

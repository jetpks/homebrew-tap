# frozen_string_literal: true

# Checks this tap against the pinned spec: formula strings and install pattern,
# tap-new CI shape, README install lines. Plain Ruby, run from the repo root
# with `ruby test/tap_check.rb`; exits non-zero if any check fails.

require "digest"
require "net/http"
require "uri"

# Plain-Ruby tap checker (no minitest/rspec dependency — CI image only needs
# the interpreter that ships with test-bot).
class TapCheck
  # Frozen per-formula expectations (url/sha256 pairs re-verified against
  # rubygems.org downloads; see the iteration report for the shasum output).
  EXPECTED = {
    "space-cadet"     => {
      desc:           "Task-scoped project workspaces (repos · notes · artifacts under one root)",
      homepage:       "https://github.com/jetpks/space-cadet",
      url:            "https://rubygems.org/downloads/space-cadet-9.2.0.gem",
      sha256:         "01d66112f3c03cbca59e70c7937e0eff4a7e1f49b2c023ec7eb70f6d324fbb24",
      depends_on:     ["ruby"],
      # Extra install-block requirements beyond the shared documented pattern.
      install_extras: ["bin.install libexec/\"bin/space\""],
    },
    "space-architect" => {
      desc:           "Architect Loop: structured judgment-and-build cycles for humans and AI builders",
      homepage:       "https://github.com/jetpks/space-architect",
      url:            "https://rubygems.org/downloads/space-architect-9.5.0.gem",
      sha256:         "16dcb0888cac134f82608e5991a78f875c59c97875aa17cfb519a5cf356db03a",
      depends_on:     %w[ruby space-cadet],
      # Shares the space-cadet formula's gem tree via GEM_PATH instead of vendoring.
      install_extras: ["ENV[\"GEM_PATH\"]", "Formula[\"space-cadet\"].libexec",
                       "bin.install libexec/\"bin/architect\""],
    },
    "repo-tender"     => {
      desc:           "Keep your local git clones forever evergreen — clean, on default branch, fetched",
      homepage:       "https://github.com/jetpks/repo-tender",
      url:            "https://rubygems.org/downloads/repo-tender-1.0.0.gem",
      sha256:         "a13a27d9415bedebf4fcd92e4f4354d9e34ec39f7ebf5bb9563d321ce6f69a25",
      depends_on:     %w[ruby gh],
      install_extras: ["bin.install libexec/\"bin/repo-tender\""],
    },
  }.freeze

  # Substrings every formula's install block must contain (the documented
  # Homebrew ruby-gem pattern; the wrapper is GEM_HOME-only — the binstub's
  # absolute brew-ruby shebang is the interpreter pin).
  INSTALL_KEYS = [
    "ENV[\"GEM_HOME\"] = libexec",
    "--install-dir",
    "cached_download",
    "Pathname.glob(libexec/\"extensions/**/{mkmf.log,gem_make.out}\")",
    "bin.env_script_all_files",
  ].freeze

  # Substrings every formula's post_install block must contain: bottled
  # native extensions are built under the CI Ruby's platform dir; RubyGems
  # refuses to activate a native gem unless the local Ruby's platform dir
  # carries gem.build_complete, so each formula links shipped builds to the
  # pouring machine's expected path at post_install (runs on bottle pour).
  POST_INSTALL_KEYS = [
    "def post_install",
    "Formula[\"ruby\"].opt_bin/\"ruby\"",
    "spec.gem_build_complete_path",
    "FileUtils.ln_s(shipped, expected)",
  ].freeze

  # Substrings no formula's install block may contain: capturing the build-time
  # PATH embeds Homebrew's shims dir into the installed wrapper, and wildcard
  # binstub installs link dependency gems' executables into brew's bin (brew
  # audit --new / brew link both reject these; see CI history).
  FORBIDDEN_KEYS = [
    "ENV.fetch(\"PATH\")",
    "bin.install Dir[libexec/\"bin/*\"]",
  ].freeze

  # Substrings every formula's test block must contain.
  VERSION_KEYS = ["--version", "version.to_s"].freeze

  def initialize
    @failures = 0
  end

  def check(label, passed, detail = nil)
    result = passed ? "PASS" : "FAIL"
    suffix = ": #{detail}" if !passed && !detail.nil?
    puts "#{result} #{label}#{suffix}"
    @failures += 1 unless passed
  end

  # Extracts a flat two-space-indented block ("def install" / "test do" ... "end").
  def block_source(src, opening)
    src[/^  #{opening}\n(.*?)\n  end$/m, 1]
  end

  def download_sha256(url)
    digest = Digest::SHA256.new
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(Net::HTTP::Get.new(uri)) do |response|
        raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

        response.read_body { |chunk| digest.update(chunk) }
      end
    end
    digest.hexdigest
  end

  def desc_violations(desc)
    [].tap do |violations|
      violations << "length #{desc.length} exceeds 80 chars" if desc.length > 80
      violations << "does not start with a capital letter" unless desc.match?(/\A[A-Z]/)
      violations << "starts with an article (a/an/the)" if desc.match?(/\A(A|An|The)\b/)
      violations << "ends with a full stop" if desc.end_with?(".")
      violations << "contains an unprintable \\p{So} symbol" if desc.match?(/\p{So}/)
    end
  end

  def run
    EXPECTED.each do |name, expected|
      path = "Formula/#{name}.rb"
      src = File.read(path)

      begin
        RubyVM::AbstractSyntaxTree.parse(src)
        check "#{name}: syntax", true
      rescue SyntaxError => e
        check "#{name}: syntax", false, e.message
      end

      { desc: expected[:desc], homepage: expected[:homepage], license: "MIT",
        url: expected[:url], sha256: expected[:sha256] }.each do |attr, value|
        check "#{name}: #{attr}", src.include?("#{attr} \"#{value}\"")
      end

      deps = src.scan(/^\s*depends_on "([^"]+)"/).flatten.sort
      check "#{name}: depends_on", deps == expected[:depends_on].sort,
            "got #{deps.inspect}, want #{expected[:depends_on].sort.inspect}"

      install = block_source(src, "def install")
      if install.nil?
        check "#{name}: install pattern", false, "no `def install` block found"
      else
        required = INSTALL_KEYS + expected[:install_extras]
        missing = required.reject { |key| install.include?(key) }
        check "#{name}: install pattern", missing.empty?, "missing #{missing.inspect}"
        leaked = FORBIDDEN_KEYS.select { |key| install.include?(key) }
        check "#{name}: no build-path leak", leaked.empty?, "offending #{leaked.inspect}"
      end

      test_block = block_source(src, "test do")
      if test_block.nil?
        check "#{name}: test block", false, "no `test do` block found"
      else
        missing = VERSION_KEYS.reject { |key| test_block.include?(key) }
        check "#{name}: test block", missing.empty?, "missing #{missing.inspect}"
      end

      missing = POST_INSTALL_KEYS.reject { |key| src.include?(key) }
      check "#{name}: post_install pattern", missing.empty?, "missing #{missing.inspect}"

      violations = desc_violations(expected[:desc])
      check "#{name}: desc brew rules", violations.empty?, violations.join("; ")

      begin
        actual = download_sha256(expected[:url])
        check "#{name}: sha256 integrity", actual == expected[:sha256],
              "downloaded gem hashes to #{actual}"
      rescue => e
        check "#{name}: sha256 integrity", false, "download failed: #{e.message}"
      end
    end

    tests_yml = File.read(".github/workflows/tests.yml")
    missing = ["brew test-bot", "macos", "ubuntu-latest", "pull_request", "upload-artifact"]
              .reject { |token| tests_yml.include?(token) }
    check "tests.yml: tap-new shape", missing.empty?, "missing #{missing.inspect}"

    publish_yml = File.read(".github/workflows/publish.yml")
    check "publish.yml: pr-pull workflow", publish_yml.include?("pr-pull")

    readme = File.read("README.md")
    check "README: tap line", readme.include?("brew tap jetpks/tap")
    EXPECTED.each_key do |name|
      check "README: install #{name}", readme.include?("brew install jetpks/tap/#{name}")
    end

    exit(@failures.zero? ? 0 : 1)
  end
end

TapCheck.new.run

class SpaceArchitect < Formula
  desc "Architect Loop: structured judgment-and-build cycles for humans and AI builders"
  homepage "https://github.com/jetpks/space-architect"
  url "https://rubygems.org/downloads/space-architect-9.5.0.gem"
  sha256 "16dcb0888cac134f82608e5991a78f875c59c97875aa17cfb519a5cf356db03a"
  license "MIT"
  revision 1

  bottle do
    root_url "https://github.com/jetpks/homebrew-tap/releases/download/space-architect-9.5.0"
    sha256 cellar: :any, arm64_tahoe:  "000fbd3386140761a9ec19e02cbedc72a457fcf1312ca97bf7d9ba2e06e69a50"
    sha256 cellar: :any, x86_64_linux: "4c3451b6676ced62352cdad00cff7600266a157b9fdca3f562f5498f1dce4cc6"
  end

  depends_on "ruby"
  depends_on "space-cadet"

  def install
    ENV["GEM_HOME"] = libexec
    ENV["GEM_PATH"] = "#{Formula["space-cadet"].libexec}:#{libexec}"
    system "gem", "install", "--no-document", "--install-dir", libexec, cached_download
    # Only the gem's own binstub: dependency gems also drop binstubs into
    # libexec/bin, which would collide with other formulae at `brew link`.
    bin.install libexec/"bin/architect"
    # Native-extension build logs embed Homebrew's build-time shims paths,
    # which `brew audit --new` rejects; they are not needed at runtime.
    Pathname.glob(libexec/"extensions/**/{mkmf.log,gem_make.out}").each(&:unlink)
    # No PATH env: capturing ENV["PATH"] at build time embeds Homebrew's
    # shims dir into the wrapper (brew audit --new rejects it). The binstub's
    # absolute brew-ruby shebang is the interpreter pin, and the user's PATH
    # flows through for subprocesses (git, gh).
    bin.env_script_all_files libexec/"bin",
                             GEM_HOME: ENV.fetch("GEM_HOME"),
                             GEM_PATH: ENV.fetch("GEM_PATH")
  end

  # Bottled native extensions (io-event, json) are keyed to the BUILD
  # machine's Ruby platform (libexec/extensions/arm64-darwin-25). RubyGems
  # only activates a native gem when gem.build_complete exists under the
  # LOCAL Ruby's platform dir (Gem::Specification#ignored? is
  # missing_extensions?), and Homebrew rebuilds its ruby bottle on newer
  # macOS runners as new macOS ships. Link the shipped build to the path the
  # pouring machine's Ruby expects. No-op when vintages already agree
  # (source builds, same-runner pours). Steps are declarative (Homebrew 7):
  # the block evaluates at formula load, so paths must be {{tokens}} and the
  # command is the brew ruby itself — the only authority on where RubyGems
  # expects extensions.
  post_install_steps do
    run "{{HOMEBREW_PREFIX}}/opt/ruby/bin/ruby",
        args: ["-e", <<~RUBY],
          require "fileutils"
          vendored = Dir.glob(File.join(Gem.dir, "extensions", "*", "*", "*"))
          Gem::Specification.each do |spec|
            next if spec.extensions.empty?
            next unless spec.base_dir == Gem.dir # only this formula's tree
            marker = spec.gem_build_complete_path
            next if File.exist?(marker)
            shipped = vendored.find { |d| File.basename(d) == spec.full_name }
            next unless shipped
            expected = File.dirname(marker)
            FileUtils.mkdir_p(File.dirname(expected))
            FileUtils.rm_rf(expected)
            FileUtils.ln_s(shipped, expected)
          end
        RUBY
        env: { "GEM_HOME" => "{{libexec}}",
               "GEM_PATH" => "{{HOMEBREW_PREFIX}}/opt/space-cadet/libexec:{{libexec}}" }
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/architect --version")
  end
end

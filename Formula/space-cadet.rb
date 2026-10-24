class SpaceCadet < Formula
  desc "Task-scoped project workspaces (repos · notes · artifacts under one root)"
  homepage "https://github.com/jetpks/space-cadet"
  url "https://rubygems.org/downloads/space-cadet-9.2.0.gem"
  sha256 "01d66112f3c03cbca59e70c7937e0eff4a7e1f49b2c023ec7eb70f6d324fbb24"
  license "MIT"
  revision 1

  bottle do
    root_url "https://github.com/jetpks/homebrew-tap/releases/download/space-cadet-9.2.0_1"
    sha256 cellar: :any, arm64_tahoe:  "1b9fb0b1a9b42cb7de87b93ab9299873617f3dda33544c33f17c1932f042a162"
    sha256 cellar: :any, x86_64_linux: "fc426e48e7a80b4a9d84b04331bf6747802f4505b30e9996dfaf1b47385b870a"
  end

  depends_on "ruby"

  def install
    ENV["GEM_HOME"] = libexec
    system "gem", "install", "--no-document", "--install-dir", libexec, cached_download
    # Only the gem's own binstub: dependency gems also drop binstubs into
    # libexec/bin, which would collide with other formulae at `brew link`.
    bin.install libexec/"bin/space"
    # Native-extension build logs embed Homebrew's build-time shims paths,
    # which `brew audit --new` rejects; they are not needed at runtime.
    Pathname.glob(libexec/"extensions/**/{mkmf.log,gem_make.out}").each(&:unlink)
    # No PATH env: capturing ENV["PATH"] at build time embeds Homebrew's
    # shims dir into the wrapper (brew audit --new rejects it). The binstub's
    # absolute brew-ruby shebang is the interpreter pin, and the user's PATH
    # flows through for subprocesses (git, gh).
    bin.env_script_all_files libexec/"bin", GEM_HOME: ENV.fetch("GEM_HOME")
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
        env:  { "GEM_HOME" => "{{libexec}}", "GEM_PATH" => "{{libexec}}" }
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/space --version")
  end
end

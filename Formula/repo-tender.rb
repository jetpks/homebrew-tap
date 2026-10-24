class RepoTender < Formula
  desc "Keep your local git clones forever evergreen — clean, on default branch, fetched"
  homepage "https://github.com/jetpks/repo-tender"
  url "https://rubygems.org/downloads/repo-tender-1.0.0.gem"
  sha256 "a13a27d9415bedebf4fcd92e4f4354d9e34ec39f7ebf5bb9563d321ce6f69a25"
  license "MIT"
  revision 1

  bottle do
    root_url "https://github.com/jetpks/homebrew-tap/releases/download/repo-tender-1.0.0"
    sha256 cellar: :any, arm64_tahoe:  "558924bc342a96c6a9f77e56946ee0d517351c1a5981937d4dcd055947bdb61c"
    sha256 cellar: :any, x86_64_linux: "f27c6029c6a76848e34695b96f2dac02b2da62f9ce23c7fd02089dabc7768499"
  end

  depends_on "gh"
  depends_on "ruby"

  def install
    ENV["GEM_HOME"] = libexec
    system "gem", "install", "--no-document", "--install-dir", libexec, cached_download
    # Only the gem's own binstub: dependency gems also drop binstubs into
    # libexec/bin, which would collide with other formulae at `brew link`.
    bin.install libexec/"bin/repo-tender"
    # Native-extension build logs embed Homebrew's build-time shims paths,
    # which `brew audit --new` rejects; they are not needed at runtime.
    Pathname.glob(libexec/"extensions/**/{mkmf.log,gem_make.out}").each(&:unlink)
    # No PATH env: capturing ENV["PATH"] at build time embeds Homebrew's
    # shims dir into the wrapper (brew audit --new rejects it). The binstub's
    # absolute brew-ruby shebang is the interpreter pin, and the user's PATH
    # flows through for subprocesses (git, gh).
    bin.env_script_all_files libexec/"bin", GEM_HOME: ENV.fetch("GEM_HOME")
  end

  # Bottled native extensions are keyed to the BUILD machine's Ruby platform
  # (libexec/extensions/arm64-darwin-25); RubyGems only activates a native gem
  # when gem.build_complete exists under the LOCAL Ruby's platform dir
  # (Gem::Specification#ignored? == missing_extensions?), and Homebrew rebuilds
  # its ruby bottle on newer macOS runners as new macOS ships. Link the shipped
  # build to the path the pouring machine's Ruby expects; see space-cadet.
  def post_install
    system({ "GEM_HOME" => libexec.to_s, "GEM_PATH" => libexec.to_s },
           Formula["ruby"].opt_bin/"ruby", "-e", <<~'RUBY')
      require "fileutils"
      vendored = Dir.glob(File.join(Gem.dir, "extensions", "*", "*", "*"))
      Gem::Specification.each do |spec|
        next if spec.extensions.empty?
        next unless spec.base_dir == Gem.dir # only this formula's vendored tree
        marker = spec.gem_build_complete_path
        next if File.exist?(marker)
        shipped = vendored.find { |d| File.basename(d) == spec.full_name }
        next unless shipped
        expected = File.dirname(marker)            # .../<platform>/<abi>/<gem>
        FileUtils.mkdir_p(File.dirname(expected))  # .../<platform>/<abi>
        FileUtils.rm_rf(expected)
        FileUtils.ln_s(shipped, expected)
      end
    RUBY
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/repo-tender --version")
  end
end

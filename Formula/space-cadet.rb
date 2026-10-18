class SpaceCadet < Formula
  desc "Task-scoped project workspaces (repos · notes · artifacts under one root)"
  homepage "https://github.com/jetpks/space-cadet"
  url "https://rubygems.org/downloads/space-cadet-9.2.0.gem"
  sha256 "01d66112f3c03cbca59e70c7937e0eff4a7e1f49b2c023ec7eb70f6d324fbb24"
  license "MIT"

  bottle do
    root_url "https://github.com/jetpks/homebrew-tap/releases/download/space-cadet-9.2.0"
    sha256 cellar: :any, arm64_tahoe:  "fc67927d3aee4cfafd411e622935af945b4607c45cc932871600fd9450a024ec"
    sha256 cellar: :any, x86_64_linux: "5a9c0451b8079526049348ad193d2a9000d08e10e92761b8ee50d82182b0239d"
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

  test do
    assert_match version.to_s, shell_output("#{bin}/space --version")
  end
end

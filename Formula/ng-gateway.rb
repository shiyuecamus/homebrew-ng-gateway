class NgGateway < Formula
  desc "High-throughput IoT gateway (NG Gateway)"
  homepage "https://github.com/shiyuecamus/ng-gateway"
  license "Apache-2.0"

  # Release version (used in logs/service name only)
  version "v0.1.0"

  on_macos do
    on_arm do
      url "https://github.com/shiyuecamus/ng-gateway/releases/download/v0.1.0/ng-gateway-v0.1.0-darwin-arm64.tar.gz"
      sha256 "94b73ff57ffdfa89722002ff2dc00734685ff09b67d928d6ad0ede751f642656"
    end

    on_intel do
      url "https://github.com/shiyuecamus/ng-gateway/releases/download/v0.1.0/ng-gateway-v0.1.0-darwin-amd64.tar.gz"
      sha256 "34b7a07e5c7710e4d01a11801cf3b08cd9049d5200176ce93893df80c2fc4818"
    end
  end

  # Install layout notes:
  # - We keep a dedicated runtime directory under var/ so relative paths in the
  #   runtime artifacts (db/drivers/plugins/certs) work as-is.
  # - A wrapper script in bin/ `cd`s into the runtime dir before launching.
  def install
    pkg_root = "ng-gateway-#{version}-darwin-#{Hardware::CPU.arm? ? "arm64" : "amd64"}"
    libexec.install Dir["#{pkg_root}/*"]

    runtime_dir = var/"lib/ng-gateway"
    runtime_dir.mkpath

    # Copy default config + bundled resources into runtime dir on first install.
    # Users can edit files under var/ without being overwritten by upgrades.
    (runtime_dir/"gateway.toml").write (libexec/"gateway.toml").read unless (runtime_dir/"gateway.toml").exist?

    # SQLite database is created automatically on first start (auto_create + migrations).
    # We only ensure the default data directory exists for the default config:
    # - data dir is `./data` (relative to runtime_dir)
    (runtime_dir/"data").mkpath

    # Always ensure builtin drivers/plugins exist under runtime dir (overwrite-safe by using rsync-like behavior).
    # We do a simple copy here; users' custom drivers/plugins live in ./drivers/custom and ./plugins/custom.
    (runtime_dir/"drivers/builtin").mkpath
    (runtime_dir/"plugins/builtin").mkpath
    cp_r (libexec/"drivers/builtin").children, (runtime_dir/"drivers/builtin"), remove_destination: true
    cp_r (libexec/"plugins/builtin").children, (runtime_dir/"plugins/builtin"), remove_destination: true

    # Ensure writable dirs exist
    (runtime_dir/"certs").mkpath
    (runtime_dir/"pki/own").mkpath
    (runtime_dir/"pki/private").mkpath

    # Wrapper entrypoint
    (bin/"ng-gateway").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      cd "#{runtime_dir}"
      exec "#{libexec}/bin/ng-gateway-bin" --config "#{runtime_dir}/gateway.toml"
    EOS
    chmod 0755, bin/"ng-gateway"
  end

  service do
    run [opt_bin/"ng-gateway"]
    keep_alive true
    working_dir var/"lib/ng-gateway"
    log_path var/"log/ng-gateway.log"
    error_log_path var/"log/ng-gateway.error.log"
  end

  test do
    # Basic smoke test: binary should print help
    assert_match "NG Gateway", shell_output("#{opt_bin}/ng-gateway --help", 0)
  end
end


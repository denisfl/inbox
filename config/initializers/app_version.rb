# frozen_string_literal: true

# App version: read from VERSION file + git SHA (baked at Docker build time or read at boot).
Rails.application.config.after_initialize do
  version_file = Rails.root.join("VERSION")
  version = version_file.exist? ? version_file.read.strip : "0.0.0"

  git_sha = ENV["GIT_SHA"].presence || `git rev-parse --short HEAD 2>/dev/null`.strip.presence

  full = if git_sha.present? && git_sha != "unknown"
    "#{version} (#{git_sha})"
  else
    version
  end

  Rails.application.config.app_version = full
end

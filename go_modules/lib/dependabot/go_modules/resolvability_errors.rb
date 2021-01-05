# frozen_string_literal: true

module Dependabot
  module GoModules
    module ResolvabilityErrors
      GITHUB_REPO_REGEX = %r{github.com/[^:@]*}.freeze

      def self.handle(error, credentials:)
        mod_path = error.message.scan(GITHUB_REPO_REGEX).first
        unless mod_path
          raise Dependabot::DependencyFileNotResolvable, error.message
        end

        # Module not found on github.com - query for _any_ version to know if it
        # doesn't exist (or is private) or we were just given a bad revision by this manifest
        SharedHelpers.in_a_temporary_directory do
          SharedHelpers.with_git_configured(credentials: credentials) do
            File.write("go.mod", "module dummy\n")

            env = { "GOPRIVATE" => "*" }
            _, _, status = Open3.capture3(env, SharedHelpers.escape_command("go get #{mod_path}"))
            raise Dependabot::DependencyFileNotResolvable, line if status.success?

            mod_split = mod_path.split("/")
            repo_path = if mod_split.size > 3
                          mod_split[0..2].join("/")
                        else
                          mod_path
                        end
            raise Dependabot::GitDependenciesNotReachable, [repo_path]
          end
        end
      end
    end
  end
end
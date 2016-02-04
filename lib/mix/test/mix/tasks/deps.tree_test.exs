Code.require_file "../../test_helper.exs", __DIR__

defmodule Mix.Tasks.Deps.TreeTest do
  use MixTest.Case

  defmodule ConvergedDepsApp do
    def project do
      [
        app: :sample,
        version: "0.1.0",
        deps: [
          {:deps_on_git_repo, "0.2.0", git: fixture_path("deps_on_git_repo")},
          {:git_repo, ">= 0.1.0", git: MixTest.Case.fixture_path("git_repo")}
        ]
      ]
    end
  end

  defmodule OverridenDepsApp do
    def project do
      [
        app: :sample,
        version: "0.1.0",
        deps: [
          {:deps_on_git_repo, ~r"0.2.0", git: fixture_path("deps_on_git_repo"), only: :test},
          {:git_repo, git: MixTest.Case.fixture_path("git_repo"), override: true}
        ]
      ]
    end
  end

  test "shows the dependency tree", context do
    Mix.Project.push ConvergedDepsApp

    in_tmp context.test, fn ->
      Mix.Tasks.Deps.Tree.run(["--pretty"])
      assert_received {:mix_shell, :info, ["sample"]}
      assert_received {:mix_shell, :info, ["├── git_repo >= 0.1.0 (" <> _]}
      assert_received {:mix_shell, :info, ["└── deps_on_git_repo 0.2.0 (" <> _]}
      refute_received {:mix_shell, :info, ["    └── git_repo (" <> _]}

      Mix.Tasks.Deps.Get.run([])
      Mix.Tasks.Deps.Tree.run(["--pretty"])
      assert_received {:mix_shell, :info, ["sample"]}
      assert_received {:mix_shell, :info, ["├── git_repo >= 0.1.0 (" <> _]}
      assert_received {:mix_shell, :info, ["└── deps_on_git_repo 0.2.0 (" <> _]}
      assert_received {:mix_shell, :info, ["    └── git_repo (" <> _]}
    end
  end

  test "shows the given dependency", context do
    Mix.Project.push ConvergedDepsApp

    in_tmp context.test, fn ->
      assert_raise Mix.Error, "could not find dependency unknown", fn ->
        Mix.Tasks.Deps.Tree.run(["--pretty", "unknown"])
      end

      Mix.Tasks.Deps.Tree.run(["--pretty", "deps_on_git_repo"])
      assert_received {:mix_shell, :info, ["deps_on_git_repo 0.2.0 (" <> _]}
      refute_received {:mix_shell, :info, ["└── git_repo (" <> _]}
    end
  end

  test "shows overriden deps", context do
    Mix.Project.push OverridenDepsApp

    in_tmp context.test, fn ->
      Mix.Tasks.Deps.Tree.run(["--pretty"])
      assert_received {:mix_shell, :info, ["sample"]}
      assert_received {:mix_shell, :info, ["├── git_repo (" <> msg]}
      assert_received {:mix_shell, :info, ["└── deps_on_git_repo ~r/0.2.0/ (" <> _]}
      assert msg =~ "*override*"
    end
  end

  test "excludes the given deps", context do
    Mix.Project.push OverridenDepsApp

    in_tmp context.test, fn ->
      Mix.Tasks.Deps.Tree.run(["--pretty", "--exclude", "deps_on_git_repo"])
      assert_received {:mix_shell, :info, ["sample"]}
      assert_received {:mix_shell, :info, ["└── git_repo (" <> _]}
      refute_received {:mix_shell, :info, ["└── deps_on_git_repo ~r/0.2.0/ (" <> _]}
    end
  end

  test "shows a particular environment", context do
    Mix.Project.push OverridenDepsApp

    in_tmp context.test, fn ->
      Mix.Tasks.Deps.Tree.run(["--pretty", "--only", "prod"])
      assert_received {:mix_shell, :info, ["sample"]}
      assert_received {:mix_shell, :info, ["└── git_repo (" <> _]}
      refute_received {:mix_shell, :info, ["└── deps_on_git_repo ~r/0.2.0/ (" <> _]}
    end
  end
end

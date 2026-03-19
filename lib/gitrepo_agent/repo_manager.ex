defmodule GitrepoAgent.RepoManager do
  @moduledoc """
  Manages git repository cloning, syncing, and branch tracking.

  Repositories are cloned into $GITREPO_AGENT_DATA_DIR/workdir/<vcs>/<org>/<repo>/
  Never operates on repos in the user's active workspace.
  """
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc "Sync all watched repositories"
  def sync_all do
    GenServer.call(__MODULE__, :sync_all, :infinity)
  end

  @doc "Sync a specific repository"
  def sync(repo_name) do
    GenServer.call(__MODULE__, {:sync, repo_name}, :infinity)
  end

  @doc "Get the local path for a watched repository"
  def repo_path(vcs, org, repo) do
    data_dir = System.get_env("GITREPO_AGENT_DATA_DIR", "/tmp/gitrepo-agent")
    Path.join([data_dir, "workdir", vcs, org, repo])
  end

  @impl true
  def handle_call(:sync_all, _from, state) do
    repos = load_repos_config()
    results = Enum.map(repos, &sync_repo/1)
    {:reply, results, state}
  end

  @impl true
  def handle_call({:sync, repo_name}, _from, state) do
    repos = load_repos_config()
    case Enum.find(repos, &(&1["name"] == repo_name)) do
      nil -> {:reply, {:error, :not_found}, state}
      repo -> {:reply, sync_repo(repo), state}
    end
  end

  defp load_repos_config do
    config_path = Path.join(File.cwd!(), "config/repos.json")
    case File.read(config_path) do
      {:ok, content} -> Jason.decode!(content) |> Map.get("repos", [])
      {:error, _} -> []
    end
  end

  defp sync_repo(repo) do
    path = repo_path(repo["vcs"], repo["org"], repo["project"])

    if File.exists?(Path.join(path, ".git")) do
      {output, exit_code} = System.cmd("git", ["-C", path, "fetch", "--all", "--prune"],
        stderr_to_stdout: true)
      {repo["name"], exit_code == 0, output}
    else
      File.mkdir_p!(Path.dirname(path))
      {output, exit_code} = System.cmd("git", ["clone", repo["url"], path],
        stderr_to_stdout: true)
      {repo["name"], exit_code == 0, output}
    end
  end
end

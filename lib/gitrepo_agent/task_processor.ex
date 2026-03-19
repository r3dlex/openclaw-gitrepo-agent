defmodule GitrepoAgent.TaskProcessor do
  @moduledoc """
  Processes PRs from input/TASK.md.

  Lifecycle:
  1. Read TASK.md
  2. Parse entries (format: `- [ ] <vcs>:<org>/<project>#<pr_id>`)
  3. Validate repo is watched
  4. Evaluate PR
  5. Remove from TASK.md
  6. Persist scoring data
  """
  use GenServer

  @task_pattern ~r/- \[ \] (\w+):([^\/]+)\/([^#]+)#(\d+)(?:\s+priority=(\w+))?/

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc "Process all pending tasks"
  def process_all do
    GenServer.call(__MODULE__, :process_all, :infinity)
  end

  @impl true
  def handle_call(:process_all, _from, state) do
    tasks = read_tasks()
    results = Enum.map(tasks, &process_task/1)
    remove_processed_tasks(tasks)
    {:reply, results, state}
  end

  defp read_tasks do
    task_path = Path.join(File.cwd!(), "input/TASK.md")
    case File.read(task_path) do
      {:ok, content} ->
        Regex.scan(@task_pattern, content)
        |> Enum.map(fn
          [_full, vcs, org, project, pr_id, priority] ->
            %{vcs: vcs, org: org, project: project, pr_id: pr_id, priority: priority || "normal"}
          [_full, vcs, org, project, pr_id] ->
            %{vcs: vcs, org: org, project: project, pr_id: pr_id, priority: "normal"}
        end)
      {:error, _} -> []
    end
  end

  defp process_task(task) do
    repo_name = "#{task.org}/#{task.project}"
    repos = load_repos()

    if Enum.any?(repos, &(&1["name"] == task.project || "#{&1["org"]}/#{&1["project"]}" == repo_name)) do
      # Process the PR
      score_data = %{
        "pr_id" => task.pr_id,
        "author" => "pending",
        "score" => 0,
        "verdict" => "pending",
        "processed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
      GitrepoAgent.Scoring.record_pr_score(task.project, task.pr_id, score_data)
      {:ok, task}
    else
      log_untracked_repo(task)
      {:skip, task}
    end
  end

  defp remove_processed_tasks(_tasks) do
    task_path = Path.join(File.cwd!(), "input/TASK.md")
    case File.read(task_path) do
      {:ok, content} ->
        cleaned = Regex.replace(@task_pattern, content, "")
        |> String.replace(~r/\n{3,}/, "\n\n")
        File.write!(task_path, cleaned)
      {:error, _} -> :ok
    end
  end

  defp log_untracked_repo(task) do
    data_dir = System.get_env("GITREPO_AGENT_DATA_DIR", "/tmp/gitrepo-agent")
    log_path = Path.join([data_dir, "log", "untracked_repos.log"])
    File.mkdir_p!(Path.dirname(log_path))
    entry = "[#{DateTime.utc_now() |> DateTime.to_iso8601()}] Untracked: #{task.vcs}:#{task.org}/#{task.project}##{task.pr_id}\n"
    File.write!(log_path, entry, [:append])
  end

  defp load_repos do
    config_path = Path.join(File.cwd!(), "config/repos.json")
    case File.read(config_path) do
      {:ok, content} -> Jason.decode!(content) |> Map.get("repos", [])
      {:error, _} -> []
    end
  end
end

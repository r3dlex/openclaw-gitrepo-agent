defmodule GitrepoAgent.StatsCollector do
  @moduledoc """
  Collects commit statistics, author activity, and pipeline data
  for all watched repositories.

  Data persisted to $GITREPO_AGENT_DATA_DIR/data/scoring/ and
  $GITREPO_AGENT_DATA_DIR/data/tracking/
  """
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc "Collect commit stats for a repo over a date range"
  def collect_commits(repo_path, since \\ "1 week ago") do
    {output, 0} = System.cmd("git", [
      "-C", repo_path,
      "log", "--format=%H|%an|%ae|%aI|%s",
      "--since=#{since}", "--all"
    ], stderr_to_stdout: true)

    output
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_commit_line/1)
  end

  @doc "Get commit counts per author"
  def author_stats(commits) do
    commits
    |> Enum.group_by(& &1.author)
    |> Enum.map(fn {author, commits} ->
      %{
        author: author,
        commit_count: length(commits),
        ai_assisted: Enum.count(commits, & &1.ai_assisted)
      }
    end)
    |> Enum.sort_by(& &1.commit_count, :desc)
  end

  @doc "Get commit counts per branch"
  def branch_stats(repo_path, branches) do
    Enum.map(branches, fn branch ->
      {output, _} = System.cmd("git", [
        "-C", repo_path,
        "rev-list", "--count", "--since=1 week ago", branch
      ], stderr_to_stdout: true)

      count = output |> String.trim() |> String.to_integer()
      %{branch: branch, commits: count}
    end)
  end

  defp parse_commit_line(line) do
    case String.split(line, "|", parts: 5) do
      [hash, author, _email, date, subject] ->
        %{
          hash: hash,
          author: author,
          date: date,
          subject: subject,
          ai_assisted: GitrepoAgent.PrEvaluator.detect_ai_assisted([subject])
        }
      _ ->
        %{hash: "", author: "unknown", date: "", subject: line, ai_assisted: false}
    end
  end
end

defmodule GitrepoAgent.Scoring do
  @moduledoc """
  Manages per-author and per-repo scoring persistence.

  Scores are stored as JSON in $GITREPO_AGENT_DATA_DIR/data/scoring/
  with a rolling 1-year window.
  """

  @score_window_days 365

  @doc "Load scoring data for a repo"
  def load(repo_name) do
    path = scoring_path(repo_name)
    case File.read(path) do
      {:ok, content} -> Jason.decode!(content)
      {:error, _} -> %{"repo" => repo_name, "authors" => %{}, "prs" => %{}}
    end
  end

  @doc "Save scoring data for a repo"
  def save(repo_name, data) do
    path = scoring_path(repo_name)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(data, pretty: true))
  end

  @doc "Record a PR score"
  def record_pr_score(repo_name, pr_id, score_data) do
    data = load(repo_name)
    prs = Map.get(data, "prs", %{})
    updated_prs = Map.put(prs, to_string(pr_id), Map.put(score_data, "date", Date.utc_today() |> Date.to_iso8601()))
    updated = Map.put(data, "prs", updated_prs)
    save(repo_name, prune_old_entries(updated))
  end

  @doc "Get author's rolling average score"
  def author_average(repo_name, author) do
    data = load(repo_name)
    cutoff = Date.utc_today() |> Date.add(-@score_window_days) |> Date.to_iso8601()

    data
    |> Map.get("prs", %{})
    |> Enum.filter(fn {_id, pr} ->
      pr["author"] == author && pr["date"] >= cutoff
    end)
    |> Enum.map(fn {_id, pr} -> pr["score"] end)
    |> case do
      [] -> nil
      scores -> Enum.sum(scores) / length(scores) |> Float.round(1)
    end
  end

  defp scoring_path(repo_name) do
    data_dir = System.get_env("GITREPO_AGENT_DATA_DIR", "/tmp/gitrepo-agent")
    Path.join([data_dir, "data", "scoring", "#{repo_name}.json"])
  end

  defp prune_old_entries(data) do
    cutoff = Date.utc_today() |> Date.add(-@score_window_days) |> Date.to_iso8601()
    prs = data |> Map.get("prs", %{}) |> Enum.filter(fn {_id, pr} -> pr["date"] >= cutoff end) |> Map.new()
    Map.put(data, "prs", prs)
  end
end

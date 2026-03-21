defmodule GitrepoAgent.TaskProcessor do
  @moduledoc """
  Processes PRs from input/TASK.md and from IAMQ requests.

  Lifecycle:
  1. Read TASK.md or accept queued MQ requests
  2. Parse entries (format: `- [ ] <vcs>:<org>/<project>#<pr_id>`)
  3. Validate repo is watched
  4. Check PR status (skip if already merged or closed)
  5. Evaluate PR
  6. Persist scoring data
  7. Notify the requesting agent with the result
  8. Remove from TASK.md
  """
  use GenServer
  require Logger

  @task_pattern ~r/- \[ \] (\w+):([^\/]+)\/([^#]+)#(\d+)(?:\s+priority=(\w+))?/

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{mq_queue: []}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc "Process all pending tasks (from TASK.md and MQ queue)"
  def process_all do
    GenServer.call(__MODULE__, :process_all, :infinity)
  end

  @doc """
  Queue a PR review request that arrived via IAMQ.

  The message map is preserved so we can route the response back to the
  requesting agent with full context (who asked, original email metadata, etc.).
  """
  def queue_from_mq(message) do
    GenServer.cast(__MODULE__, {:queue_mq, message})
  end

  @impl true
  def handle_call(:process_all, _from, state) do
    # Process file-based tasks
    tasks = read_tasks()
    file_results = Enum.map(tasks, &process_task(&1, nil))
    remove_processed_tasks(tasks)

    # Process MQ-queued requests
    mq_results =
      Enum.map(state.mq_queue, fn message ->
        case parse_mq_request(message) do
          {:ok, task} -> process_task(task, message)
          {:error, reason} ->
            Logger.warning("[TaskProcessor] Skipping MQ request: #{reason}")
            {:skip, reason}
        end
      end)

    {:reply, file_results ++ mq_results, %{state | mq_queue: []}}
  end

  @impl true
  def handle_cast({:queue_mq, message}, state) do
    from = message["from"] || "unknown"
    subject = message["subject"] || "(no subject)"
    Logger.info("[TaskProcessor] Queued MQ request from #{from}: #{subject}")

    # Process the MQ request immediately (don't wait for process_all cycle)
    case parse_mq_request(message) do
      {:ok, task} ->
        spawn(fn -> process_task(task, message) end)

      {:error, reason} ->
        Logger.warning("[TaskProcessor] Cannot parse MQ request: #{reason}")
        notify_parse_error(message, reason)
    end

    {:noreply, state}
  end

  # --- MQ Request Parsing ---

  defp parse_mq_request(message) do
    subject = message["subject"] || ""
    body = message["body"] || ""

    # Try to extract PR reference from subject or body
    # Supported patterns:
    #   "PR review: ado:org/project#123"
    #   "pr-review github:org/repo#456"
    #   Body containing "<vcs>:<org>/<project>#<id>"
    text = "#{subject} #{body}"

    case Regex.run(~r/(\w+):([^\/\s]+)\/([^#\s]+)#(\d+)/, text) do
      [_full, vcs, org, project, pr_id] ->
        {:ok, %{vcs: vcs, org: org, project: project, pr_id: pr_id, priority: "normal"}}

      nil ->
        # Try simpler patterns: "#123" with repo context elsewhere
        case Regex.run(~r/#(\d+)/, text) do
          [_, pr_id] ->
            # Best-effort: extract repo from subject if available
            {:ok, %{vcs: "unknown", org: "unknown", project: "unknown", pr_id: pr_id, priority: "normal"}}

          nil ->
            {:error, "No PR reference found in message"}
        end
    end
  end

  # --- Task Processing ---

  defp process_task(task, request_context) do
    repo_name = "#{task.org}/#{task.project}"
    repos = load_repos()

    if Enum.any?(repos, &(&1["name"] == task.project || "#{&1["org"]}/#{&1["project"]}" == repo_name)) do
      # Check if PR is still open (not merged or closed)
      case check_pr_status(task) do
        :open ->
          evaluate_and_notify(task, request_context)

        :merged ->
          Logger.info("[TaskProcessor] PR #{repo_name}##{task.pr_id} already merged — skipping")
          notify_pr_already_completed(task, request_context, :merged)
          {:skip, :merged}

        :closed ->
          Logger.info("[TaskProcessor] PR #{repo_name}##{task.pr_id} is closed — skipping")
          notify_pr_already_completed(task, request_context, :closed)
          {:skip, :closed}

        {:error, reason} ->
          # If we can't determine status, proceed with evaluation
          Logger.warning("[TaskProcessor] Could not check PR status for #{repo_name}##{task.pr_id}: #{inspect(reason)} — proceeding with evaluation")
          evaluate_and_notify(task, request_context)
      end
    else
      log_untracked_repo(task)
      notify_untracked_repo(task, request_context)
      {:skip, task}
    end
  end

  defp evaluate_and_notify(task, request_context) do
    repo_name = "#{task.org}/#{task.project}"

    # Run the evaluation
    category_scores = evaluate_pr(task)
    score = GitrepoAgent.PrEvaluator.calculate_score(category_scores)
    verdict = GitrepoAgent.PrEvaluator.verdict(score)

    # Persist the scoring data
    score_data = %{
      "pr_id" => task.pr_id,
      "author" => "pending",
      "score" => score,
      "verdict" => to_string(verdict),
      "category_scores" => %{
        "security" => Map.get(category_scores, :security, 0),
        "design" => Map.get(category_scores, :design, 0),
        "practices" => Map.get(category_scores, :practices, 0),
        "style" => Map.get(category_scores, :style, 0),
        "documentation" => Map.get(category_scores, :documentation, 0)
      },
      "processed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    GitrepoAgent.Scoring.record_pr_score(task.project, task.pr_id, score_data)

    Logger.info("[TaskProcessor] PR #{repo_name}##{task.pr_id}: score=#{score}, verdict=#{verdict}")

    # Notify the requesting agent if this came from an MQ request
    if request_context do
      evaluation = %{
        pr_id: task.pr_id,
        repo: repo_name,
        vcs: task.vcs,
        score: score,
        verdict: verdict,
        category_scores: category_scores,
        findings: [],
        author: score_data["author"]
      }

      GitrepoAgent.Notification.notify_requester(request_context, evaluation)
    end

    {:ok, task, score, verdict}
  end

  # --- PR Status Check ---
  # Verifies the PR is still open before spending time evaluating it.
  # Uses the appropriate VCS CLI/API based on the task's vcs field.

  defp check_pr_status(%{vcs: "github", org: org, project: project, pr_id: pr_id}) do
    case System.cmd("gh", ["pr", "view", pr_id, "--repo", "#{org}/#{project}", "--json", "state"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, %{"state" => "MERGED"}} -> :merged
          {:ok, %{"state" => "CLOSED"}} -> :closed
          {:ok, %{"state" => "OPEN"}} -> :open
          _ -> :open
        end

      {_, _} ->
        {:error, "gh command failed"}
    end
  end

  defp check_pr_status(%{vcs: "ado", org: org, project: project, pr_id: pr_id}) do
    url =
      "https://dev.azure.com/#{org}/#{project}/_apis/git/pullrequests/#{pr_id}?api-version=7.0"

    pat = System.get_env("ADO_PAT", "")

    case Req.get(url, headers: [{"authorization", "Basic #{Base.encode64(":#{pat}")}"}]) do
      {:ok, %{status: 200, body: %{"status" => "completed"}}} -> :merged
      {:ok, %{status: 200, body: %{"status" => "abandoned"}}} -> :closed
      {:ok, %{status: 200, body: %{"status" => "active"}}} -> :open
      {:ok, %{status: status}} -> {:error, "ADO API returned #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_pr_status(%{vcs: "gitlab", org: org, project: project, pr_id: pr_id}) do
    token = System.get_env("GITLAB_TOKEN", "")
    base = System.get_env("GITLAB_URL", "https://gitlab.com")
    encoded = URI.encode("#{org}/#{project}", &(&1 != ?/))

    case Req.get("#{base}/api/v4/projects/#{encoded}/merge_requests/#{pr_id}",
           headers: [{"PRIVATE-TOKEN", token}]
         ) do
      {:ok, %{status: 200, body: %{"state" => "merged"}}} -> :merged
      {:ok, %{status: 200, body: %{"state" => "closed"}}} -> :closed
      {:ok, %{status: 200, body: %{"state" => "opened"}}} -> :open
      {:ok, %{status: status}} -> {:error, "GitLab API returned #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_pr_status(_task) do
    # Unknown VCS — can't check, proceed with evaluation
    {:error, "Unknown VCS type"}
  end

  # --- PR Evaluation ---
  # Delegates to the pipeline runner for actual scoring.
  # Falls back to placeholder scores if pipeline execution fails.

  defp evaluate_pr(task) do
    repo_path =
      GitrepoAgent.RepoManager.repo_path(task.vcs, task.org, task.project)

    # Try running the PR review pipeline
    case run_pr_pipeline(repo_path, task.pr_id) do
      {:ok, scores} ->
        scores

      {:error, reason} ->
        Logger.warning(
          "[TaskProcessor] Pipeline failed for #{task.org}/#{task.project}##{task.pr_id}: #{inspect(reason)} — using placeholder scores"
        )

        # Placeholder until pipeline integration is complete
        %{security: 0, design: 0, practices: 0, style: 0, documentation: 0}
    end
  end

  defp run_pr_pipeline(repo_path, _pr_id) do
    # TODO: integrate with pipeline_runner for real scoring
    # For now, check if repo_path exists as a basic validation
    if File.dir?(repo_path) do
      {:error, "Pipeline integration pending"}
    else
      {:error, "Repo not cloned at #{repo_path}"}
    end
  end

  # --- Notifications for edge cases ---

  defp notify_pr_already_completed(_task, nil, _status), do: :ok

  defp notify_pr_already_completed(task, request_context, status) do
    from = request_context["from"] || "unknown"
    pr_ref = "#{task.vcs}:#{task.org}/#{task.project}##{task.pr_id}"
    status_label = if status == :merged, do: "already merged", else: "closed"

    body =
      if from == "mail_agent" do
        Jason.encode!(%{
          "action" => "reply_email",
          "context" => %{
            "pr" => pr_ref,
            "status" => to_string(status)
          },
          "email" => %{
            "subject" => "PR #{pr_ref} — #{status_label}",
            "body" => "PR #{pr_ref} is #{status_label}. No review required.",
            "reply_to_all" => true,
            "original_sender" =>
              GitrepoAgent.Notification.extract_email_context(request_context["body"])["from"],
            "original_cc" =>
              GitrepoAgent.Notification.extract_email_context(request_context["body"])["cc"]
          }
        })
      else
        "PR #{pr_ref} is #{status_label}. No review was performed."
      end

    GitrepoAgent.MqClient.send_message(
      from,
      "PR #{pr_ref} — #{status_label}",
      body,
      type: "response",
      reply_to: request_context["id"]
    )
  end

  defp notify_untracked_repo(_task, nil), do: :ok

  defp notify_untracked_repo(task, request_context) do
    from = request_context["from"] || "unknown"
    pr_ref = "#{task.vcs}:#{task.org}/#{task.project}##{task.pr_id}"

    GitrepoAgent.MqClient.send_message(
      from,
      "PR #{pr_ref} — repo not tracked",
      "Cannot evaluate #{pr_ref}: repository #{task.org}/#{task.project} is not in my watch list.",
      type: "response",
      reply_to: request_context["id"]
    )
  end

  defp notify_parse_error(message, reason) do
    from = message["from"] || "unknown"

    GitrepoAgent.MqClient.send_message(
      from,
      "PR review request — could not parse",
      "Could not extract a PR reference from your request. #{reason}\n\nExpected format: <vcs>:<org>/<project>#<pr_id> (e.g., github:myorg/myrepo#123)",
      type: "response",
      reply_to: message["id"]
    )
  end

  # --- File-based task management ---

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

      {:error, _} ->
        []
    end
  end

  defp remove_processed_tasks(_tasks) do
    task_path = Path.join(File.cwd!(), "input/TASK.md")

    case File.read(task_path) do
      {:ok, content} ->
        cleaned =
          Regex.replace(@task_pattern, content, "")
          |> String.replace(~r/\n{3,}/, "\n\n")

        File.write!(task_path, cleaned)

      {:error, _} ->
        :ok
    end
  end

  defp log_untracked_repo(task) do
    data_dir = System.get_env("GITREPO_AGENT_DATA_DIR", "/tmp/gitrepo-agent")
    log_path = Path.join([data_dir, "log", "untracked_repos.log"])
    File.mkdir_p!(Path.dirname(log_path))

    entry =
      "[#{DateTime.utc_now() |> DateTime.to_iso8601()}] Untracked: #{task.vcs}:#{task.org}/#{task.project}##{task.pr_id}\n"

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

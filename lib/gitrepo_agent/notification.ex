defmodule GitrepoAgent.Notification do
  @moduledoc """
  Builds and sends post-evaluation notifications back to requesting agents.

  When a PR review is requested via IAMQ (e.g., from mail_agent), this module
  constructs the appropriate response after evaluation is complete:

  - For approved PRs: notifies the requester with approval + context
  - For non-approved PRs: notifies with verdict, score, and key findings
  - Special handling for mail_agent: includes email reply instructions
    so the original requester (and CC'd recipients) get notified
  """
  require Logger

  @doc """
  Send the evaluation result back to the agent that requested the review.

  `request_context` is a map containing the original IAMQ request metadata:
    - "from"          — the agent that sent the request (e.g., "mail_agent")
    - "subject"       — original subject line
    - "body"          — original body (may contain email metadata)
    - "id"            — original message ID (used as reply_to)

  `evaluation` is a map with the scoring result:
    - :pr_id          — PR identifier (e.g., "456")
    - :repo           — repository name (e.g., "org/project")
    - :vcs            — VCS type (e.g., "ado", "github")
    - :score          — final weighted score (0-100)
    - :verdict        — :approve, :approve_with_comments, :request_changes, :reject
    - :category_scores — %{security: N, design: N, practices: N, style: N, documentation: N}
    - :findings       — list of key finding strings
    - :author         — PR author name
  """
  def notify_requester(request_context, evaluation) do
    from_agent = request_context["from"] || "unknown"
    original_msg_id = request_context["id"]

    pr_ref = build_pr_ref(evaluation)
    verdict = evaluation[:verdict]
    score = evaluation[:score]

    Logger.info(
      "[Notification] PR #{pr_ref} scored #{score} (#{verdict}) — notifying #{from_agent}"
    )

    cond do
      from_agent == "mail_agent" ->
        notify_mail_agent(request_context, evaluation)

      true ->
        notify_generic_agent(from_agent, original_msg_id, evaluation)
    end
  end

  # --- Mail Agent Response ---
  # When the request came from mail_agent, the response includes
  # instructions for the mail agent to reply to the original email.
  # For approved PRs, the email body is just "Approved".
  # For non-approved PRs, the email body includes the verdict and key context.

  defp notify_mail_agent(request_context, evaluation) do
    original_msg_id = request_context["id"]
    pr_ref = build_pr_ref(evaluation)
    verdict = evaluation[:verdict]
    score = evaluation[:score]

    # Extract email context from the original request body if available
    email_context = extract_email_context(request_context["body"])

    {email_body, subject_prefix} = build_email_content(verdict, score, pr_ref, evaluation)

    # Build the response payload for mail_agent
    # The mail_agent will use this to compose and send the reply email
    response_body =
      Jason.encode!(%{
        "action" => "reply_email",
        "context" => %{
          "pr" => pr_ref,
          "score" => score,
          "verdict" => to_string(verdict),
          "evaluated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        },
        "email" => %{
          "subject" => "#{subject_prefix}: #{pr_ref}",
          "body" => email_body,
          "reply_to_all" => true,
          "original_sender" => email_context["from"],
          "original_cc" => email_context["cc"],
          "original_subject" => email_context["subject"],
          "original_message_id" => email_context["message_id"]
        }
      })

    subject = "PR evaluation result: #{pr_ref} — #{verdict_label(verdict)}"

    case GitrepoAgent.MqClient.send_message(
           "mail_agent",
           subject,
           response_body,
           type: "request",
           priority: priority_for_verdict(verdict),
           reply_to: original_msg_id
         ) do
      {:ok, _} ->
        Logger.info("[Notification] Sent #{verdict} notification to mail_agent for #{pr_ref}")

      {:error, reason} ->
        Logger.error(
          "[Notification] Failed to notify mail_agent for #{pr_ref}: #{inspect(reason)}"
        )
    end
  end

  # --- Generic Agent Response ---
  # For any agent other than mail_agent, send a structured response
  # with the full evaluation context.

  defp notify_generic_agent(agent_id, original_msg_id, evaluation) do
    pr_ref = build_pr_ref(evaluation)
    verdict = evaluation[:verdict]
    score = evaluation[:score]
    categories = evaluation[:category_scores] || %{}
    findings = evaluation[:findings] || []

    body = build_generic_body(pr_ref, score, verdict, categories, findings, evaluation)
    subject = "PR evaluation result: #{pr_ref} — #{verdict_label(verdict)}"

    case GitrepoAgent.MqClient.send_message(
           agent_id,
           subject,
           body,
           type: "response",
           priority: priority_for_verdict(verdict),
           reply_to: original_msg_id
         ) do
      {:ok, _} ->
        Logger.info("[Notification] Sent #{verdict} response to #{agent_id} for #{pr_ref}")

      {:error, reason} ->
        Logger.error(
          "[Notification] Failed to notify #{agent_id} for #{pr_ref}: #{inspect(reason)}"
        )
    end
  end

  # --- Email Content Builders ---

  defp build_email_content(:approve, _score, _pr_ref, _evaluation) do
    {"Approved", "Approved"}
  end

  defp build_email_content(verdict, score, pr_ref, evaluation) do
    findings = evaluation[:findings] || []
    categories = evaluation[:category_scores] || %{}

    body =
      [
        "#{verdict_label(verdict)}",
        "",
        "PR: #{pr_ref}",
        "Score: #{score}/100",
        "Verdict: #{verdict_label(verdict)}",
        "",
        "Category Scores:",
        "  Security: #{Map.get(categories, :security, "—")}",
        "  Design: #{Map.get(categories, :design, "—")}",
        "  Practices: #{Map.get(categories, :practices, "—")}",
        "  Style: #{Map.get(categories, :style, "—")}",
        "  Documentation: #{Map.get(categories, :documentation, "—")}",
        if(findings != [],
          do: "\nKey Findings:\n" <> Enum.map_join(findings, "\n", &"  - #{&1}"),
          else: ""
        )
      ]
      |> Enum.join("\n")
      |> String.trim()

    {body, verdict_label(verdict)}
  end

  # --- Generic Body Builder ---

  defp build_generic_body(pr_ref, score, verdict, categories, findings, evaluation) do
    author = evaluation[:author] || "unknown"

    lines = [
      "PR: #{pr_ref}",
      "Author: #{author}",
      "Score: #{score}/100",
      "Verdict: #{verdict_label(verdict)}",
      "",
      "Security: #{Map.get(categories, :security, "—")} | " <>
        "Design: #{Map.get(categories, :design, "—")} | " <>
        "Practices: #{Map.get(categories, :practices, "—")} | " <>
        "Style: #{Map.get(categories, :style, "—")} | " <>
        "Docs: #{Map.get(categories, :documentation, "—")}"
    ]

    lines =
      if findings != [] do
        lines ++ ["", "Key findings:"] ++ Enum.map(findings, &"- #{&1}")
      else
        lines
      end

    Enum.join(lines, "\n")
  end

  # --- Helpers ---

  defp build_pr_ref(evaluation) do
    vcs = evaluation[:vcs] || ""
    repo = evaluation[:repo] || ""
    pr_id = evaluation[:pr_id] || ""

    case {vcs, repo} do
      {"", ""} -> "##{pr_id}"
      {_, ""} -> "#{vcs}:##{pr_id}"
      {"", _} -> "#{repo}##{pr_id}"
      _ -> "#{vcs}:#{repo}##{pr_id}"
    end
  end

  defp verdict_label(:approve), do: "Approved"
  defp verdict_label(:approve_with_comments), do: "Approved with Comments"
  defp verdict_label(:request_changes), do: "Changes Requested"
  defp verdict_label(:reject), do: "Rejected"
  defp verdict_label(other), do: to_string(other)

  defp priority_for_verdict(:reject), do: "HIGH"
  defp priority_for_verdict(:request_changes), do: "NORMAL"
  defp priority_for_verdict(_), do: "NORMAL"

  @doc """
  Extract email metadata from the original request body.

  The mail_agent is expected to include email context in the message body,
  either as JSON or as structured headers. This function attempts to parse it.
  """
  def extract_email_context(nil), do: %{}

  def extract_email_context(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"email" => email_meta}} -> email_meta
      {:ok, %{"from" => _} = meta} -> meta
      _ -> parse_email_headers(body)
    end
  end

  def extract_email_context(_), do: %{}

  defp parse_email_headers(body) do
    # Try to extract common email headers from plain-text body
    headers = %{}

    headers =
      case Regex.run(~r/From:\s*(.+)/i, body) do
        [_, from] -> Map.put(headers, "from", String.trim(from))
        _ -> headers
      end

    headers =
      case Regex.run(~r/CC:\s*(.+)/i, body) do
        [_, cc] ->
          cc_list =
            cc |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

          Map.put(headers, "cc", cc_list)

        _ ->
          headers
      end

    headers =
      case Regex.run(~r/Subject:\s*(.+)/i, body) do
        [_, subj] -> Map.put(headers, "subject", String.trim(subj))
        _ -> headers
      end

    headers =
      case Regex.run(~r/Message-ID:\s*(.+)/i, body) do
        [_, mid] -> Map.put(headers, "message_id", String.trim(mid))
        _ -> headers
      end

    headers
  end
end

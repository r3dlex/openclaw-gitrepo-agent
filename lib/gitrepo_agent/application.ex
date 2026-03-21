defmodule GitrepoAgent.Application do
  @moduledoc """
  OTP Application for the GitRepo Agent.

  Starts the supervision tree with:
  - MqClient: inter-agent message queue integration (registers, heartbeats, polls)
  - RepoManager: handles repository cloning and syncing
  - TaskProcessor: processes input/TASK.md entries
  - StatsCollector: gathers commit statistics
  - ReportGenerator: produces weekly reports
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GitrepoAgent.MqClient,
      GitrepoAgent.RepoManager,
      GitrepoAgent.TaskProcessor,
      GitrepoAgent.StatsCollector,
      GitrepoAgent.ReportGenerator
    ]

    opts = [strategy: :one_for_one, name: GitrepoAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

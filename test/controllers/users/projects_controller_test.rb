require "test_helper"

class Users::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "new" do
    get user_company_project_new_url

    assert_response :success
    assert_match "Create Project", @response.body
    assert_match "General Details", @response.body
  end

  test "new lists only active non-bot users in human member picker" do
    deactivated_user = users(:jz)
    deactivated_user.update!(status: :deactivated)

    get user_company_project_new_url

    assert_response :success
    assert_match 'option value="' + users(:kevin).id.to_s + '"', @response.body
    assert_no_match(/<select id="project_member_user_picker"[^>]*>.*#{Regexp.escape(users(:bender).effective_display_name)}.*<\/select>/m, @response.body)
    assert_no_match deactivated_user.effective_display_name, @response.body
  end

  test "new renders only workspace allowed bots" do
    account = accounts(:signal)
    allowed_bot = users(:bender)
    disallowed_bot = User.create_bot!(
      name: "Ops Bot",
      display_name: "Ops Bot",
      email_address: "ops-bot-#{SecureRandom.hex(4)}@example.com"
    )

    account.update!(settings: account.settings_with_allowed_bot_user_ids([ allowed_bot.id ]))

    get user_company_project_new_url

    assert_response :success
    assert_match allowed_bot.effective_display_name, @response.body
    assert_no_match disallowed_bot.effective_display_name, @response.body
    assert_no_match "value=\"assistant\"", @response.body
  end

  test "new shows empty state when no workspace bots are allowed" do
    account = accounts(:signal)
    account.update!(settings: account.settings_with_allowed_bot_user_ids([]))

    get user_company_project_new_url

    assert_response :success
    assert_match "No workspace bots are allowed yet.", @response.body
    assert_no_match users(:bender).effective_display_name, @response.body
  end

  test "create creates project and redirects to overview" do
    assert_difference("Project.count", 1) do
      post user_company_projects_url, params: {
        project: {
          name: "Apollo Program",
          short_code: "APOLLO",
          description: "Moonshot planning and delivery",
          private: "1"
        }
      }
    end

    project = Project.order(:created_at).last

    assert_redirected_to user_company_project_overview_url(id: project.id)
    assert_equal "Apollo Program", project.name
    assert_equal "APOLLO", project.short_code
    assert project.private?
    assert_includes project.users, users(:david)
    assert project.project_room.present?
    assert project.project_room.private?
    assert Membership.exists?(room: project.project_room, participant: users(:david))

    channel_names = project.rooms.opens.where(parent_id: project.project_room.id).pluck(:name)
    assert_equal [ "releases", "specifications" ], channel_names.sort
  end

  test "create only creates selected default channels" do
    assert_difference("Project.count", 1) do
      post user_company_projects_url, params: {
        project: {
          name: "Project Skylab",
          short_code: "SKYLAB",
          description: "Orbital workshop"
        },
        default_channel_keys: [ "", "releases" ]
      }
    end

    project = Project.order(:created_at).last
    channel_names = project.rooms.opens.where(parent_id: project.project_room.id).pluck(:name)

    assert_equal [ "releases" ], channel_names
    assert_not project.private?
    assert_not project.project_room.private?
  end

  test "create adds selected human team members to project and project room" do
    selected_user = users(:kevin)

    assert_difference("Project.count", 1) do
      post user_company_projects_url, params: {
        project: {
          name: "Project Mercury",
          short_code: "MERC",
          description: "Crewed mission planning"
        },
        member_user_ids: [ users(:david).id.to_s, selected_user.id.to_s ]
      }
    end

    project = Project.order(:created_at).last

    assert_redirected_to user_company_project_overview_url(id: project.id)
    assert_includes project.users, users(:david)
    assert_includes project.users, selected_user
    assert Membership.exists?(room: project.project_room, participant: selected_user)
  end

  test "create broadcasts sidebar refresh for creator and selected members" do
    selected_user = users(:kevin)

    assert_difference("Project.count", 1) do
      post user_company_projects_url, params: {
        project: {
          name: "Project Orion",
          short_code: "ORION",
          description: "Deep-space coordination"
        },
        member_user_ids: [ users(:david).id.to_s, selected_user.id.to_s ]
      }
    end

    assert_redirected_to user_company_project_overview_url(id: Project.order(:created_at).last.id)

    [ users(:david), selected_user ].each do |user|
      target = ActionView::RecordIdentifier.dom_id(user, :sidebar_refresh)
      stream = send(:find_broadcasts_for, user, :rooms)

      assert_equal 1, stream.scan(%(target="#{target}")).count
      assert_match(/data-sidebar-refresh-trigger-value="true"/, stream)
    end
  end

  test "create ignores duplicate invalid inactive and bot member ids" do
    inactive_user = users(:jz)
    inactive_user.update!(status: :deactivated)

    assert_difference("Project.count", 1) do
      post user_company_projects_url, params: {
        project: {
          name: "Project Gemini",
          short_code: "GEM",
          description: "Docking tests"
        },
        member_user_ids: [
          users(:david).id.to_s,
          users(:kevin).id.to_s,
          users(:kevin).id.to_s,
          users(:bender).id.to_s,
          inactive_user.id.to_s,
          "999999",
          "bad-id"
        ]
      }
    end

    project = Project.order(:created_at).last

    assert_includes project.users, users(:david)
    assert_includes project.users, users(:kevin)
    assert_equal 1, project.project_users.where(user: users(:kevin)).count
    assert_not_includes project.users, users(:bender)
    assert_not_includes project.users, inactive_user
    assert Membership.exists?(room: project.project_room, participant: users(:kevin))
    assert_not Membership.exists?(room: project.project_room, participant: users(:bender))
    assert_not Membership.exists?(room: project.project_room, participant: inactive_user)
  end

  test "create with blank name returns unprocessable entity" do
    assert_no_difference("Project.count") do
      post user_company_projects_url, params: {
        project: {
          name: "",
          short_code: "BLANK",
          description: "Should fail"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "can&#39;t be blank", @response.body
  end

  test "overview" do
    project = create_project_for(users(:david))
    project.update!(description: "Core platform description", short_code: "B2B")

    get user_company_project_overview_url(id: project.id)

    assert_response :success
    assert_match project.display_name, @response.body
    assert_match "Edit Project Details", @response.body
    assert_select ".project-overview-metrics-grid"
    assert_select ".project-overview-metric-card", count: 4
    assert_select ".project-overview-card-title", text: "Project Summary & Objectives"
    assert_select ".project-overview-card-title", text: "Key Milestones & Alignment"
    assert_match "Core platform description", @response.body
  end

  test "overview renders AI teammates from workspace bot users" do
    project = create_project_for(users(:david))
    project.project_users.create!(user: users(:bender))

    get user_company_project_overview_url(id: project.id)

    assert_response :success
    assert_match "Attached AI Teammates (1)", @response.body
    assert_match users(:bender).effective_display_name, @response.body
    assert_match "(AI)", @response.body
  end

  test "overview returns not found for non-member project" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get user_company_project_overview_url(id: -1)
    end
  end

  test "status" do
    project = create_project_for(users(:david))
    project.update!(
      current_phase: "Phase 2: Core Platform Development",
      progress_percent: 65,
      recently_completed: "Tailwind CSS styling applied to profile settings."
    )
    project.bottlenecks.create!(title: "Obsidian Vault Indexing Timeout", description: "Hermes agent timeout on large directories.")
    project.todos.create!(title: "Finalize Express.js API Routes", meta_text: "Connect Node.js backend.")
    project.knowledge_items.create!(title: "Infrastructure Routing", badge: "Architecture", description: "VPS hosted on Infomaniak.")

    get user_company_project_status_url(id: project.id)

    assert_response :success
    assert_match project.display_name, @response.body
    assert_match "Project Status &amp; Alignment", @response.body
    assert_match "Phase 2: Core Platform Development", @response.body
    assert_match "65% Complete", @response.body
    assert_match "Tailwind CSS styling applied", @response.body
    assert_match "Active Bottlenecks", @response.body
    assert_match "Obsidian Vault Indexing Timeout", @response.body
    assert_match "What Should Be Done", @response.body
    assert_match "Finalize Express.js API Routes", @response.body
    assert_match "Project Knowledge &amp; Context", @response.body
    assert_match "Infrastructure Routing", @response.body
    assert_match "Architecture", @response.body
  end

  test "status returns not found for non-member project" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get user_company_project_status_url(id: -1)
    end
  end

  test "all hands with empty state" do
    project = create_project_for(users(:david))

    get user_company_project_all_hands_url(id: project.id)

    assert_response :success
    assert_match "turbo-cable-stream-source", @response.body
    assert_match project.display_name, @response.body
    assert_match "All-Hands Hub", @response.body
    assert_match "No Active All-Hands Items", @response.body
    assert_match "This project does not currently have any active takeaways, action items, or decisions.", @response.body
    assert_no_match "Watch Recording", @response.body
  end

  test "all hands with dynamic project data" do
    project = create_project_for(users(:david))
    project.project_all_hands_takeaways.create!(category: "Performance", content: "Query latency reduced by 40% across all channels.", position: 1)
    project.project_all_hands_action_items.create!(title: "Deploy Redis cluster update", assignee_name: "David", due_date: "Sep 1", completed: false, position: 1)
    project.project_all_hands_decisions.create!(title: "Adopt WebSocket compression by default.", basis: "Approved by infra team", impact: "#infra", badge: "Logged in System", position: 1)
    inactive_takeaway = project.project_all_hands_takeaways.create!(category: "Operations", content: "Old stale note.", active: false, position: 2)

    get user_company_project_all_hands_url(id: project.id)

    assert_response :success
    assert_match project.display_name, @response.body
    assert_match "Performance", @response.body
    assert_match "Query latency reduced by 40%", @response.body
    assert_match "Deploy Redis cluster update", @response.body
    assert_match "Assignee: @David", @response.body
    assert_match "1 Pending", @response.body
    assert_match "Adopt WebSocket compression by default.", @response.body
    assert_match "Impact: #infra", @response.body
    assert_no_match inactive_takeaway.content, @response.body
    assert_no_match "Watch Recording", @response.body
  end

  test "all hands returns not found for non-member project" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get user_company_project_all_hands_url(id: -1)
    end
  end

  test "knowledge" do
    project = create_project_for(users(:david))
    project.obsidian_notes.create!(
      title: "Smart Contract Vault (V1)",
      tags: "#architecture #smart-contracts",
      content: "Core vault logic.",
      html_source_type: "internal_file",
      html_source_path: "obsidian/graph.html"
    )
    project.obsidian_notes.create!(
      title: "Archived Vault",
      tags: "#archived",
      content: "Old note.",
      html_source_type: "internal_file",
      html_source_path: "obsidian/archived.html",
      active: false
    )
    project.adrs.create!(
      identifier: "ADR-004",
      title: "Use ECDSA for State Channel Signatures",
      decision_date: Date.new(2024, 8, 10),
      status: "accepted"
    )
    project.adrs.create!(
      identifier: "ADR-999",
      title: "Deprecated idea",
      decision_date: Date.new(2023, 1, 1),
      status: "deprecated",
      active: false
    )
    project.external_assets.create!(
      title: "Trail of Bits Audit",
      url: "https://example.com/audit.pdf",
      source_type: "external_url",
      icon: "📄",
      meta_text: "PDF • Validated"
    )
    project.external_assets.create!(
      title: "Multi-Sig Runbook",
      url: "02_Smart_Contracts/Vault_V1.md",
      source_type: "internal_file",
      icon: "📘",
      meta_text: "Runbook • Playbook"
    )
    project.external_assets.create!(
      title: "Old Template",
      url: "https://example.com/old.pdf",
      source_type: "external_url",
      icon: "📄",
      meta_text: "Legacy",
      active: false
    )
    project.knowledge_activities.create!(
      actor_name: "Sarah",
      action_text: "created new note [[Postgres Migration Plan]]"
    )
    project.knowledge_activities.create!(
      actor_name: "Legacy",
      action_text: "created old note [[Old Plan]]",
      active: false
    )
    arch = project.directory_items.create!(
      name: "01_Architecture",
      item_type: "directory",
      position: 1
    )
    arch.children.create!(
      project: project,
      name: "System_Design.md",
      item_type: "file",
      content: "# System Architecture",
      position: 1
    )
    inactive_dir = project.directory_items.create!(
      name: "02_Archived",
      item_type: "directory",
      position: 2,
      active: false
    )
    inactive_dir.children.create!(
      project: project,
      name: "Old_Design.md",
      item_type: "file",
      content: "# Old Architecture",
      position: 1,
      active: false
    )

    get user_company_project_knowledge_url(id: project.id)

    assert_response :success
    assert_match project.display_name, @response.body
    assert_match "Knowledge Base", @response.body
    assert_match "Networked Notes (Obsidian Sync)", @response.body
    assert_match "id=\"obsidian-container\"", @response.body
    assert_match "class=\"obsidian-iframe\"", @response.body
    assert_match "path=obsidian%2Fgraph.html", @response.body
    assert_no_match "obsidian/archived.html", @response.body
    assert_match "External Assets &amp; Playbooks", @response.body
    assert_match "Trail of Bits Audit", @response.body
    assert_match "https://example.com/audit.pdf", @response.body
    assert_match "Multi-Sig Runbook", @response.body
    assert_no_match "Old Template", @response.body
    assert_match "Decision Records", @response.body
    assert_match "Directory Explorer", @response.body
    assert_match "01_Architecture", @response.body
    assert_match "System_Design.md", @response.body
    assert_no_match "02_Archived", @response.body
    assert_no_match "Old_Design.md", @response.body
    assert_match "Recent Knowledge Activity", @response.body
    assert_match "ADR-004", @response.body
    assert_no_match "ADR-999", @response.body
    assert_no_match "Legacy", @response.body
  end

  test "knowledge_file serves markdown from database directory item" do
    project = create_project_for(users(:david))
    item = project.directory_items.create!(
      name: "Roadmap.md",
      item_type: "file",
      content: "# Q3 Roadmap\n\n- Mainnet launch\n- Audit completion"
    )

    get user_company_project_knowledge_file_url(id: project.id, item_id: item.id, format: :json)

    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal "Roadmap.md", json["title"]
    assert_includes json["rendered_html"], "<h1>Q3 Roadmap</h1>"
    assert_includes json["rendered_html"], "<li>Mainnet launch</li>"
  end

  test "knowledge does not show obsidian section when project has no obsidian file" do
    project = create_project_for(users(:david))

    get user_company_project_knowledge_url(id: project.id)

    assert_response :success
    assert_no_match "Networked Notes (Obsidian Sync)", @response.body
    assert_no_match "obsidian-container", @response.body
    assert_match "No files or directories found in this project.", @response.body
    assert_match "No decision records found in this project.", @response.body
    assert_match "No recent knowledge activity found in this project.", @response.body
    assert_no_match "Sarah", @response.body
  end

  test "knowledge_file serves markdown as json" do
    project = create_project_for(users(:david))
    storage_dir = ProjectKnowledge.ensure_storage_dir(project)
    file_path = storage_dir.join("System_Design.md")
    File.write(file_path, "# System Architecture\n\nCore layout.")

    get user_company_project_knowledge_file_url(id: project.id, path: "System_Design.md", format: :json)

    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal "System_Design.md", json["title"]
    assert_includes json["rendered_html"], "<h1>System Architecture</h1>"
  ensure
    FileUtils.rm_rf(storage_dir) if storage_dir
  end

  test "knowledge_file serves html file directly" do
    project = create_project_for(users(:david))
    storage_dir = ProjectKnowledge.ensure_storage_dir(project)
    file_path = storage_dir.join("graph.html")
    File.write(file_path, "<html><body><div>Obsidian Graph</div></body></html>")

    get user_company_project_knowledge_file_url(id: project.id, path: "graph.html")

    assert_response :success
    assert_match "Obsidian Graph", @response.body
  ensure
    FileUtils.rm_rf(storage_dir) if storage_dir
  end

  test "knowledge_file rejects path traversal" do
    project = create_project_for(users(:david))

    get user_company_project_knowledge_file_url(id: project.id, path: "../../../etc/passwd")

    assert_response :not_found
  end

  test "knowledge returns not found for non-member project" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get user_company_project_knowledge_url(id: -1)
    end
  end

  private
    def create_project_for(user)
      project = Project.create!(
        name: "Basecamp",
        path: "/tmp/basecamp-#{SecureRandom.hex(4)}",
        description: "Project fixture replacement"
      )

      project.project_users.create!(user: user)
      project.ensure_project_room!
      project
    end
end

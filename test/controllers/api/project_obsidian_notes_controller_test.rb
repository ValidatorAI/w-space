require "test_helper"

class Api::ProjectObsidianNotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(
      id: rand(500_000..899_999),
      path: "/tmp/api-project-obsidian-notes-test-#{SecureRandom.hex(4)}",
      name: "Api Obsidian Notes Test Project"
    )
    @storage_dir = Rails.root.join("storage", "projects", @project.id.to_s)
    @note = @project.obsidian_notes.create!(
      title: "Architecture System Note",
      tags: "#architecture, #backend",
      content: "Main entrypoint notes.",
      html_source_type: "internal_file",
      html_source_path: "notes/main.html",
      active: true,
      position: 1
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
    FileUtils.rm_rf(@storage_dir) if Dir.exist?(@storage_dir)
  end

  test "returns all obsidian notes for a project with a valid token" do
    inactive_note = @project.obsidian_notes.create!(
      title: "Old Draft Note",
      tags: "#draft",
      content: "Legacy content.",
      html_source_type: "internal_file",
      html_source_path: "notes/draft.html",
      active: false,
      position: 2
    )

    get api_project_obsidian_notes_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @note.id, inactive_note.id ].sort, body["obsidian_notes"].map { |n| n["id"] }.sort
  end

  test "filters obsidian notes by active state with a valid token" do
    inactive_note = @project.obsidian_notes.create!(
      title: "Old Draft Note",
      tags: "#draft",
      content: "Legacy content.",
      html_source_type: "internal_file",
      html_source_path: "notes/draft.html",
      active: false,
      position: 2
    )

    get api_project_obsidian_notes_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @note.id ], body["obsidian_notes"].map { |n| n["id"] }

    get api_project_obsidian_notes_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ inactive_note.id ], body["obsidian_notes"].map { |n| n["id"] }
  end

  test "returns a single obsidian note with a valid token" do
    get api_project_obsidian_note_url(@project.id, @note.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @note.id, body["id"]
    assert_equal @note.title, body["title"]
    assert_equal @note.tags, body["tags"]
    assert_equal @note.html_source_path, body["html_source_path"]
  end

  test "creates an obsidian note with uploaded file and creates base directory" do
    uploaded_file = Rack::Test::UploadedFile.new(
      StringIO.new("<html><body><h1>Graph Notes</h1><p>Sync contents</p></body></html>"),
      "text/html",
      original_filename: "graph_view.html"
    )

    assert_difference -> { @project.obsidian_notes.count }, 1 do
      post api_project_obsidian_notes_url(@project.id),
        params: {
          file: uploaded_file,
          tags: "#graph, #visual",
          active: true,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "graph_view.html", body["title"]
    assert_equal "internal_file", body["html_source_type"]
    assert_equal "graph_view.html", body["html_source_path"]

    # Verify storage directory exists and file was written
    assert Dir.exist?(@storage_dir)
    target_file = @storage_dir.join("graph_view.html")
    assert File.exist?(target_file)
    assert_includes File.read(target_file), "<h1>Graph Notes</h1>"
  end

  test "creates an obsidian note with nested html source path" do
    uploaded_file = Rack::Test::UploadedFile.new(
      StringIO.new("<html><body>Nested Content</body></html>"),
      "text/html",
      original_filename: "nested.html"
    )

    post api_project_obsidian_notes_url(@project.id),
      params: {
        title: "Nested Note",
        file: uploaded_file,
        html_source_path: "subfolder/nested.html",
        active: true
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :created
    target_file = @storage_dir.join("subfolder", "nested.html")
    assert File.exist?(target_file)
    assert_equal "<html><body>Nested Content</body></html>", File.read(target_file)
  end

  test "updates an obsidian note with a new file" do
    uploaded_file = Rack::Test::UploadedFile.new(
      StringIO.new("<html><body>Updated Main Note Content</body></html>"),
      "text/html",
      original_filename: "main_updated.html"
    )

    patch api_project_obsidian_note_url(@project.id, @note.id),
      params: {
        title: "Architecture System Note (v2)",
        file: uploaded_file,
        html_source_path: "notes/main_v2.html",
        active: false,
        position: 4
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Architecture System Note (v2)", body["title"]
    assert_equal "notes/main_v2.html", body["html_source_path"]
    assert_equal false, body["active"]

    target_file = @storage_dir.join("notes", "main_v2.html")
    assert File.exist?(target_file)
    assert_equal "<html><body>Updated Main Note Content</body></html>", File.read(target_file)
  end

  test "deletes an obsidian note and removes internal file from disk" do
    target_file = @storage_dir.join("notes", "main.html")
    FileUtils.mkdir_p(File.dirname(target_file))
    File.write(target_file, "temporary note file")

    assert_difference -> { @project.obsidian_notes.count }, -1 do
      delete api_project_obsidian_note_url(@project.id, @note.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.obsidian_notes.find_by(id: @note.id)
    assert_not File.exist?(target_file)
  end

  test "rejects requests without a token" do
    get api_project_obsidian_notes_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_obsidian_notes_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end

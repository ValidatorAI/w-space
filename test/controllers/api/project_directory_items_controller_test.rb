require "test_helper"

class Api::ProjectDirectoryItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(
      id: rand(100_000..499_999),
      path: "/tmp/api-project-directory-items-test-#{SecureRandom.hex(4)}",
      name: "Api Directory Items Test Project"
    )
    @storage_dir = Rails.root.join("storage", "projects", @project.id.to_s)
    @item = @project.directory_items.create!(
      name: "docs",
      item_type: "directory",
      file_path: "docs",
      active: true,
      position: 1
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
    FileUtils.rm_rf(@storage_dir) if Dir.exist?(@storage_dir)
  end

  test "returns all directory items for a project with a valid token" do
    inactive_item = @project.directory_items.create!(
      name: "old_readme.md",
      item_type: "file",
      file_path: "old_readme.md",
      active: false,
      position: 2
    )

    get api_project_directory_items_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @item.id, inactive_item.id ].sort, body["directory_items"].map { |i| i["id"] }.sort
  end

  test "filters directory items by active state with a valid token" do
    inactive_item = @project.directory_items.create!(
      name: "old_readme.md",
      item_type: "file",
      file_path: "old_readme.md",
      active: false,
      position: 2
    )

    get api_project_directory_items_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @item.id ], body["directory_items"].map { |i| i["id"] }

    get api_project_directory_items_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ inactive_item.id ], body["directory_items"].map { |i| i["id"] }
  end

  test "returns a single directory item with a valid token" do
    get api_project_directory_item_url(@project.id, @item.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @item.id, body["id"]
    assert_equal @item.name, body["name"]
    assert_equal @item.item_type, body["item_type"]
  end

  test "creates a directory item with uploaded file and creates base directory" do
    uploaded_file = Rack::Test::UploadedFile.new(
      StringIO.new("# Architecture Overview\nAll services running smoothly."),
      "text/markdown",
      original_filename: "architecture.md"
    )

    assert_difference -> { @project.directory_items.count }, 1 do
      post api_project_directory_items_url(@project.id),
        params: {
          file: uploaded_file,
          active: true,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "architecture.md", body["name"]
    assert_equal "file", body["item_type"]
    assert_equal "architecture.md", body["file_path"]

    # Verify base directory and file on disk in storage/projects/[project_id]
    assert Dir.exist?(@storage_dir)
    target_file = @storage_dir.join("architecture.md")
    assert File.exist?(target_file)
    assert_includes File.read(target_file), "Architecture Overview"
  end

  test "creates a nested directory item with uploaded file into subfolder" do
    uploaded_file = Rack::Test::UploadedFile.new(
      StringIO.new("export const API_KEY = 'secret';"),
      "text/plain",
      original_filename: "config.js"
    )

    post api_project_directory_items_url(@project.id),
      params: {
        file: uploaded_file,
        file_path: "nested/subfolder/config.js",
        active: true
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :created
    target_file = @storage_dir.join("nested", "subfolder", "config.js")
    assert File.exist?(target_file)
    assert_equal "export const API_KEY = 'secret';", File.read(target_file)
  end

  test "updates a directory item with a new file" do
    uploaded_file = Rack::Test::UploadedFile.new(
      StringIO.new("Updated content v2"),
      "text/plain",
      original_filename: "notes.txt"
    )

    patch api_project_directory_item_url(@project.id, @item.id),
      params: {
        name: "notes.txt",
        item_type: "file",
        file: uploaded_file,
        active: false,
        position: 5
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "notes.txt", body["name"]
    assert_equal "file", body["item_type"]
    assert_equal false, body["active"]

    target_file = @storage_dir.join("notes.txt")
    assert File.exist?(target_file)
    assert_equal "Updated content v2", File.read(target_file)
  end

  test "deletes a directory item and removes file from disk" do
    file_path = @storage_dir.join("docs")
    FileUtils.mkdir_p(file_path)

    assert_difference -> { @project.directory_items.count }, -1 do
      delete api_project_directory_item_url(@project.id, @item.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.directory_items.find_by(id: @item.id)
  end

  test "rejects requests without a token" do
    get api_project_directory_items_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_directory_items_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end

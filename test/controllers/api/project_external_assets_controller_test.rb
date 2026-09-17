require "test_helper"

class Api::ProjectExternalAssetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_token = ENV["OUTPUT_EVENTS_TOKEN"]
    ENV["OUTPUT_EVENTS_TOKEN"] = "test-token"
    @project = Project.create!(path: "/tmp/api-project-external-assets-test", name: "Api External Assets Test Project")
    @asset = @project.external_assets.create!(
      title: "System Architecture Figma",
      url: "https://www.figma.com/file/architecture-v1",
      doc_type: "Design",
      icon: "figma",
      source_type: "external_url",
      meta_text: "Figma File",
      active: true,
      position: 1
    )
  end

  teardown do
    ENV["OUTPUT_EVENTS_TOKEN"] = @previous_token
  end

  test "returns all external assets for a project with a valid token" do
    inactive_asset = @project.external_assets.create!(
      title: "Old Wireframes",
      url: "https://www.figma.com/file/old-wireframes",
      doc_type: "Design",
      icon: "figma",
      source_type: "external_url",
      meta_text: "Legacy Figma",
      active: false,
      position: 2
    )

    get api_project_external_assets_url(@project.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
    assert_equal [ @asset.id, inactive_asset.id ].sort, body["external_assets"].map { |a| a["id"] }.sort
  end

  test "filters external assets by active state with a valid token" do
    inactive_asset = @project.external_assets.create!(
      title: "Old Wireframes",
      url: "https://www.figma.com/file/old-wireframes",
      doc_type: "Design",
      icon: "figma",
      source_type: "external_url",
      meta_text: "Legacy Figma",
      active: false,
      position: 2
    )

    get api_project_external_assets_url(@project.id, active: true), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["count"]
    assert_equal [ @asset.id ], body["external_assets"].map { |a| a["id"] }

    get api_project_external_assets_url(@project.id, active: false), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ inactive_asset.id ], body["external_assets"].map { |a| a["id"] }
  end

  test "returns a single external asset with a valid token" do
    get api_project_external_asset_url(@project.id, @asset.id), headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @asset.id, body["id"]
    assert_equal @asset.title, body["title"]
    assert_equal @asset.url, body["url"]
    assert_equal @asset.doc_type, body["doc_type"]
  end

  test "creates an external asset with a valid token" do
    assert_difference -> { @project.external_assets.count }, 1 do
      post api_project_external_assets_url(@project.id),
        params: {
          title: "API Swagger Docs",
          url: "https://api.example.com/docs",
          doc_type: "Documentation",
          icon: "swagger",
          source_type: "external_url",
          meta_text: "OpenAPI 3.0",
          active: true,
          position: 2
        },
        headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "API Swagger Docs", body["title"]
    assert_equal "https://api.example.com/docs", body["url"]
  end

  test "updates an external asset with a valid token" do
    patch api_project_external_asset_url(@project.id, @asset.id),
      params: {
        title: "System Architecture Figma (v2)",
        meta_text: "Updated Figma File",
        active: false,
        position: 3
      },
      headers: { "Authorization" => "Bearer test-token" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "System Architecture Figma (v2)", body["title"]
    assert_equal "Updated Figma File", body["meta_text"]
    assert_equal false, body["active"]
  end

  test "deletes an external asset with a valid token" do
    assert_difference -> { @project.external_assets.count }, -1 do
      delete api_project_external_asset_url(@project.id, @asset.id), headers: { "Authorization" => "Bearer test-token" }
    end

    assert_response :no_content
    assert_nil @project.external_assets.find_by(id: @asset.id)
  end

  test "rejects requests without a token" do
    get api_project_external_assets_url(@project.id)
    assert_response :unauthorized
  end

  test "returns not found for a missing project" do
    get api_project_external_assets_url(-1), headers: { "Authorization" => "Bearer test-token" }
    assert_response :not_found
  end
end

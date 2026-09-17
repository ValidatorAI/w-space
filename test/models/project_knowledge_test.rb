require "test_helper"

class ProjectKnowledgeTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(
      name: "Decentralized Settlement",
      path: "/tmp/settlement-#{SecureRandom.hex(4)}",
      description: "Knowledge tests"
    )
  end

  test "creates and associates obsidian notes" do
    note = @project.obsidian_notes.create!(
      title: "Architecture Map",
      tags: "#solidity #vault",
      content: "## Notes\nCore vault logic.",
      html_source_type: "internal_file",
      html_source_path: "obsidian/graph.html"
    )

    assert_equal 1, @project.obsidian_notes.count
    assert note.active
    assert_equal ["#solidity", "#vault"], note.tag_list
    assert note.internal_source?
    assert_not note.external_source?
  end

  test "creates and associates external assets" do
    asset = @project.external_assets.create!(
      title: "Audit PDF",
      doc_type: "pdf",
      icon: "📄",
      source_type: "external_url",
      url: "https://example.com/audit.pdf",
      meta_text: "PDF • Validated"
    )

    assert_equal 1, @project.external_assets.count
    assert asset.active
    assert asset.external_source?
  end

  test "creates and associates ADRs" do
    adr = @project.adrs.create!(
      identifier: "ADR-001",
      title: "Use ECDSA",
      decision_date: Date.new(2026, 8, 1),
      status: "accepted",
      file_path: "01_Architecture/ADR-001.md"
    )

    assert_equal 1, @project.adrs.count
    assert adr.active
    assert_equal "2026-08-01", adr.formatted_date
    assert_equal "accepted", adr.status
  end

  test "creates and associates knowledge activities" do
    activity = @project.knowledge_activities.create!(
      actor_name: "Sarah",
      actor_color: "var(--accent-blue)",
      action_text: "created new note [[Architecture]]",
      target_path: "01_Architecture/Design.md"
    )

    assert_equal 1, @project.knowledge_activities.count
    assert activity.active
    assert_equal "S", activity.actor_initial
    assert_includes activity.formatted_action_html, "data-knowledge-file-viewer-path-param=\"01_Architecture/Design.md\""
    assert_includes activity.formatted_action_html, "[[Architecture]]"
  end

  test "creates hierarchical directory items and builds database tree" do
    arch_dir = @project.directory_items.create!(
      name: "01_Architecture",
      item_type: "directory",
      position: 1
    )
    doc = arch_dir.children.create!(
      project: @project,
      name: "System_Design.md",
      item_type: "file",
      content: "# Architecture Overview",
      position: 1
    )

    assert_equal 2, @project.directory_items.count
    assert arch_dir.directory?
    assert doc.file?
    assert doc.markdown?
    assert_equal "01_Architecture/System_Design.md", doc.relative_path

    tree = ProjectKnowledge.directory_tree(@project)
    assert_equal 1, tree.length
    assert_equal "01_Architecture", tree.first[:name]
    assert_equal :directory, tree.first[:type]
    assert_equal 1, tree.first[:children].length
    assert_equal "System_Design.md", tree.first[:children].first[:name]
    assert_equal :file, tree.first[:children].first[:type]
  end

  test "safe resolve path prevents path traversal" do
    storage_dir = ProjectKnowledge.ensure_storage_dir(@project)
    test_file = storage_dir.join("test.md")
    File.write(test_file, "# Test Header")

    # Valid relative path inside project
    resolved = ProjectKnowledge.safe_resolve_path(@project, "test.md")
    assert_equal test_file.to_s, resolved.to_s

    # Path traversal attempt should return nil
    assert_nil ProjectKnowledge.safe_resolve_path(@project, "../../../etc/passwd")
    assert_nil ProjectKnowledge.safe_resolve_path(@project, "/etc/passwd")
    assert_nil ProjectKnowledge.safe_resolve_path(@project, "non_existent.md")
  ensure
    FileUtils.rm_rf(storage_dir)
  end

  test "renders markdown to HTML with tables and links" do
    markdown_text = "# Header 1\n\n- item 1\n- item 2\n\n| Col 1 | Col 2 |\n|---|---|\n| A | B |"
    html = ProjectKnowledge.render_markdown(markdown_text)

    assert_includes html, "<h1>Header 1</h1>"
    assert_includes html, "<li>item 1</li>"
    assert_includes html, "<table>"
    assert_includes html, "<td>A</td>"
  end
end

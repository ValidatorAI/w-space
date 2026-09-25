require "rexml/document"

class SeedSkillsFromDefaultProfileXml < ActiveRecord::Migration[8.0]
  DEFAULT_PROFILE_SKILL_NAMES = [
    "langfuse",
    "claude-code",
    "codex",
    "computer-use",
    "hermes-agent",
    "hermes-multi-agent-collaboration",
    "hermes-observability",
    "hermes-profile-admin",
    "opencode",
    "openviking-memory-mcp",
    "w-bridge-mcp",
    "architecture-diagram",
    "ascii-art",
    "ascii-video",
    "baoyu-infographic",
    "claude-design",
    "comfyui",
    "design-md",
    "excalidraw",
    "humanizer",
    "manim-video",
    "p5js",
    "popular-web-designs",
    "pretext",
    "sketch",
    "songwriting-and-ai-music",
    "touchdesigner-mcp",
    "himalaya",
    "codebase-inspection",
    "github-auth",
    "github-code-review",
    "github-issues",
    "github-pr-workflow",
    "github-repo-management",
    "gif-search",
    "songsee",
    "youtube-content",
    "evaluating-llms-harness",
    "huggingface-hub",
    "llama-cpp",
    "llm-observability-instrumentation",
    "serving-llms-vllm",
    "weights-and-biases",
    "obsidian",
    "airtable",
    "docx",
    "google-workspace",
    "maps",
    "nano-pdf",
    "notion",
    "ocr-and-documents",
    "pdf",
    "powerpoint",
    "teams-meeting-pipeline",
    "xlsx",
    "arxiv",
    "blogwatcher",
    "grounded-citations",
    "llm-wiki",
    "polymarket",
    "research-paper-writing",
    "openhue",
    "xurl",
    "dogfood",
    "hermes-agent-skill-authoring",
    "inspecting-hermes-desktop-dom",
    "node-inspect-debugger",
    "plan",
    "python-debugpy",
    "requesting-code-review",
    "simplify-code",
    "spike",
    "systematic-debugging",
    "test-driven-development"
  ].freeze

  def up
    return unless table_exists?(:skills)

    now = Time.current

    parse_skills_from_xml.each do |attributes|
      skill = skills_relation.find_or_initialize_by(name: attributes[:name])
      skill.category = attributes[:category]
      skill.description = attributes[:description]
      skill.skill_text = attributes[:skill_text]
      skill.add_by_default = true
      skill.created_at ||= now
      skill.updated_at = now
      skill.save! if skill.new_record? || skill.changed?
    end
  end

  def down
    return unless table_exists?(:skills)

    skills_relation.where(name: DEFAULT_PROFILE_SKILL_NAMES).delete_all
  end

  private

  def parse_skills_from_xml
    xml_path = Rails.root.join("..", "W-ai", "default-profile-skills.xml")

    unless File.exist?(xml_path)
      raise "Missing XML skill source at #{xml_path}"
    end

    document = REXML::Document.new(File.read(xml_path))

    document.elements.to_a("skills/skill").map do |node|
      {
        name: normalize(node.elements["name"]&.text),
        category: normalize(node.elements["category"]&.text),
        description: normalize(node.elements["description"]&.text),
        skill_text: normalize(node.elements["skill_text"]&.text)
      }
    end.select { |attrs| attrs[:name].present? }
  end

  def normalize(value)
    text = value.to_s.strip
    text.present? ? text : nil
  end

  def skills_relation
    @skills_relation ||= Class.new(ActiveRecord::Base) do
      self.table_name = "skills"
    end
  end
end

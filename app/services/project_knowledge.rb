# frozen_string_literal: true

class ProjectKnowledge
  ROOT_STORAGE_DIR = Rails.root.join("storage", "projects")

  class << self
    def root_path_for(project)
      ROOT_STORAGE_DIR.join(project.id.to_s)
    end

    def ensure_storage_dir(project)
      dir = root_path_for(project)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      dir
    end

    def safe_resolve_path(project, relative_path)
      base_dir = root_path_for(project).expand_path
      return nil unless Dir.exist?(base_dir)

      # Clean and sanitize relative path
      cleaned_rel = relative_path.to_s.strip.delete_prefix("/")
      return nil if cleaned_rel.blank?

      target_path = base_dir.join(cleaned_rel).expand_path

      # Security: Path traversal protection
      if target_path.to_s.start_with?(base_dir.to_s) && File.exist?(target_path)
        target_path
      else
        nil
      end
    end

    def directory_tree(project)
      items = project.directory_items.active.ordered.to_a
      return [] if items.empty?

      items_by_parent_id = items.group_by(&:parent_id)
      build_db_tree(nil, items_by_parent_id)
    end

    def render_markdown(text)
      renderer = Redcarpet::Render::HTML.new(
        filter_html: false,
        no_images: false,
        no_links: false,
        no_styles: false,
        safe_links_only: true,
        with_toc_data: false,
        hard_wrap: true,
        link_attributes: { target: "_blank", rel: "noopener noreferrer" }
      )

      markdown = Redcarpet::Markdown.new(renderer, {
        autolink: true,
        disable_indented_code_blocks: false,
        fenced_code_blocks: true,
        footnotes: false,
        highlight: false,
        no_intra_emphasis: true,
        space_after_headers: true,
        strikethrough: true,
        superscript: false,
        tables: true,
        underline: true
      })

      markdown.render(text.to_s)
    end

    private

    def build_db_tree(parent_id, items_by_parent_id)
      (items_by_parent_id[parent_id] || []).map do |item|
        {
          id: item.id,
          name: item.name,
          type: item.item_type.to_sym,
          relative_path: item.relative_path,
          is_markdown: item.markdown?,
          is_html: item.html?,
          children: item.directory? ? build_db_tree(item.id, items_by_parent_id) : []
        }
      end
    end
  end
end

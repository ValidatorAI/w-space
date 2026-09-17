class ProjectKnowledgeActivity < ApplicationRecord
  belongs_to :project

  validates :actor_name, presence: true
  validates :action_text, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }

  def actor_initial
    actor_name.to_s.strip[0]&.upcase || "U"
  end

  def formatted_action_html
    raw_text = action_text.to_s
    if target_path.present?
      if raw_text.include?("[[") && raw_text.include?("]]")
        raw_text.gsub(/\[\[(.*?)\]\]/) do
          title = Regexp.last_match(1)
          "<span role=\"button\" tabindex=\"0\" class=\"knowledge-link\" data-action=\"click->knowledge-file-viewer#openFile\" data-knowledge-file-viewer-path-param=\"#{ERB::Util.html_escape(target_path)}\" data-knowledge-file-viewer-title-param=\"#{ERB::Util.html_escape(title)}\">[[#{ERB::Util.html_escape(title)}]]</span>"
        end.html_safe
      else
        raw_text.html_safe
      end
    elsif target_url.present?
      if raw_text.include?("[[") && raw_text.include?("]]")
        raw_text.gsub(/\[\[(.*?)\]\]/) do
          title = Regexp.last_match(1)
          "<a href=\"#{ERB::Util.html_escape(target_url)}\" target=\"_blank\" rel=\"noopener noreferrer\" class=\"knowledge-link\">[[#{ERB::Util.html_escape(title)}]]</a>"
        end.html_safe
      else
        raw_text.html_safe
      end
    else
      if raw_text.include?("[[") && raw_text.include?("]]")
        raw_text.gsub(/\[\[(.*?)\]\]/) do
          title = Regexp.last_match(1)
          "<span class=\"knowledge-link\">[[#{ERB::Util.html_escape(title)}]]</span>"
        end.html_safe
      else
        raw_text.html_safe
      end
    end
  end
end

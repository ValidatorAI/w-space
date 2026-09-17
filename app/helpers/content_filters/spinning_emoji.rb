class ContentFilters::SpinningEmoji < ActionText::Content::Filter
  TOKEN = ":spin:".freeze
  HTML = '<span class="spinning-emoji" role="img" aria-label="spinning emoji">🌀</span>'.freeze

  def applicable?
    content.to_plain_text.include?(TOKEN)
  end

  def apply
    fragment.update do |source|
      source.xpath(".//text()").select { |node| node.content.include?(TOKEN) }.each do |node|
        replacement = Nokogiri::HTML5.fragment(node.content.gsub(TOKEN, HTML))
        node.replace(replacement.children)
      end
    end
  end
end
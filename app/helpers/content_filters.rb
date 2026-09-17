module ContentFilters
  TextMessagePresentationFilters = ActionText::Content::Filters.new(MarkdownFilter, RemoveSoloUnfurledLinkText, StyleUnfurledTwitterAvatars, SpinningEmoji, SanitizeTags)
end

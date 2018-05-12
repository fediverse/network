defmodule FdWeb.Scrubber do
  require HtmlSanitizeEx.Scrubber.Meta
  alias HtmlSanitizeEx.Scrubber.Meta

  @valid_schemes ["http", "https", "mailto"]

  # Removes any CDATA tags before the traverser/scrubber runs.
  Meta.remove_cdata_sections_before_scrub()

  Meta.strip_comments()

  Meta.allow_tag_with_uri_attributes("a", ["href"], @valid_schemes)
  Meta.allow_tag_with_these_attributes("a", ["name", "title"])

  Meta.allow_tag_with_this_attribute_values("a", "target", ["_blank"])

  Meta.allow_tag_with_this_attribute_values("a", "rel", [
    "noopener",
    "noreferrer"
  ])

  Meta.allow_tag_with_these_attributes("b", [])
  Meta.allow_tag_with_these_attributes("blockquote", [])
  Meta.allow_tag_with_these_attributes("br", [])
  Meta.allow_tag_with_these_attributes("code", ["class"])
  Meta.allow_tag_with_these_attributes("del", [])
  Meta.allow_tag_with_these_attributes("em", [])
  Meta.allow_tag_with_these_attributes("i", [])

  Meta.allow_tag_with_these_attributes("p", [])
  Meta.allow_tag_with_these_attributes("pre", [])
  Meta.allow_tag_with_these_attributes("span", [])
  Meta.allow_tag_with_these_attributes("strong", [])
  Meta.allow_tag_with_these_attributes("u", [])

  Meta.strip_everything_not_covered()
end

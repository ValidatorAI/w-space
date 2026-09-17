# Company Home Data Model

## Summary

The Company Home page is not rendered from a dedicated company table. It is a dashboard that aggregates attention items for the current user and groups them by category.

The main rendering logic lives in:

- [app/controllers/users/companies_controller.rb](../app/controllers/users/companies_controller.rb)
- [app/views/users/companies/home.html.erb](../app/views/users/companies/home.html.erb)
- [app/models/attention_item.rb](../app/models/attention_item.rb)

## Main source table

The homepage primarily reads from the `attention_items` table.

The controller does this in `Users::CompaniesController#home`:

```rb
@open_attention_items = AttentionItem.for_user(Current.user).open_items.ordered
@items_by_category = @open_attention_items.group_by(&:category)
```

This is defined in:

- [app/controllers/users/companies_controller.rb](../app/controllers/users/companies_controller.rb#L5-L10)

The view then loops through categories and renders each group:

```erb
<% AttentionItem::CATEGORIES.each do |cat| %>
  <% items = @items_by_category[cat] || [] %>
  <div class="home-attention-card" data-home-attention-target="card" data-category="<%= cat %>">
    <h3>
      <%= AttentionItem.category_title(cat) %>
      <span class="badge <%= AttentionItem.category_badge_class(cat) %> home-card-count"><%= items.count %></span>
    </h3>

    <div class="card-items-list">
      <% if items.any? %>
        <%= render partial: "attention_items/attention_item", collection: items %>
      <% else %>
        <div class="company-cell-muted txt-small" style="padding: 8px 0;">No active items</div>
      <% end %>
    </div>
  </div>
<% end %>
```

This is in:

- [app/views/users/companies/home.html.erb](../app/views/users/companies/home.html.erb#L33-L48)

## What categories are used

The categories are defined in the `AttentionItem` model:

```rb
CATEGORIES = %w[
  decisions_waiting
  blockers
  outcomes_review
  mentions
  material_changes
  ai_confirm
  knowledge_proposals
].freeze
```

This is in:

- [app/models/attention_item.rb](../app/models/attention_item.rb#L2-L18)

## Data model of attention items

The `attention_items` table includes fields such as:

- `user_id`
- `project_id`
- `room_id`
- `source_id` and `source_type`
- `target_id` and `target_type`
- `category`
- `status`
- `title`
- `meta_text`
- `due_at`
- `overdue`

This is confirmed by the schema in:

- [db/schema.rb](../db/schema.rb#L110-L127)

## Shared vs company-specific

There is no `company_id` field on `attention_items`.

That means these items are not strictly “company-owned” rows. Instead, they are contextual items that can be:

- user-specific (`user_id` set)
- globally visible or shared to a user (`user_id` nil or matched by `for_user`)
- tied to a project (`project_id` present)
- tied to a room (`room_id` present)
- associated with a polymorphic source or target object

The `AttentionItem` model shows these associations:

```rb
belongs_to :user, optional: true
belongs_to :project, optional: true
belongs_to :room, optional: true
belongs_to :source, polymorphic: true, optional: true
belongs_to :resolved_by, class_name: "User", optional: true
```

This is in:

- [app/models/attention_item.rb](../app/models/attention_item.rb#L20-L28)

## How project links are used on the home page

The item partial checks whether an attention item should open a project page:

```erb
<% if attention_item.target_type == "project_status" && attention_item.project_id.present? %>
  <%= link_to "Open Project Status", user_company_project_status_path(user_id: "me", id: attention_item.project_id), class: "action-btn nav-btn" %>
<% elsif attention_item.target_type == "project_knowledge" && attention_item.project_id.present? %>
  <%= link_to "Open Knowledge", user_company_project_knowledge_path(user_id: "me", id: attention_item.project_id), class: "action-btn nav-btn" %>
<% elsif attention_item.target_type == "room" && attention_item.room.present? %>
  <%= link_to "Open Room", room_path(attention_item.room), class: "action-btn nav-btn" %>
<% end %>
```

This is in:

- [app/views/attention_items/_attention_item.html.erb](../app/views/attention_items/_attention_item.html.erb#L12-L24)

## Conclusion

The Company Home page is best understood as a user-centric attention dashboard built on the `attention_items` table. The items are not locked to one table like `projects`; instead, they are shared or scoped by user, project, or room depending on the record. The home page simply surfaces the relevant items for the current user.

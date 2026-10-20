# Bonfire Pages: Sections, Entities, and W-bridge MCP Tools

## 1. Company Home
### What needs your attention?
- Entities used:
  - AttentionItem
  - User
  - Project
  - Room
- Related W-bridge MCP tools:
  - `decisions_waiting`
  - `blockers`
  - `outcomes_review`
  - `mentions`
  - `material_changes`
  - `ai_confirm`
  - `knowledge_proposals`

### Open Attention / Overdue / AI awaiting confirmation
- Entities used:
  - AttentionItem
- Related W-bridge MCP tools:
  - `ai_confirm`
  - `blockers`
  - `decisions_waiting`
  - `outcomes_review`
  - `mentions`
  - `material_changes`
  - `knowledge_proposals`

### Category cards
- Entities used:
  - AttentionItem
- Categories:
  - decisions_waiting
  - blockers
  - outcomes_review
  - mentions
  - material_changes
  - ai_confirm
  - knowledge_proposals

### Status values
- pending
- resolved
- dismissed

## 2. Company Status
### Current priorities & intended outcomes
- Entities used:
  - CompanyStatusItem
  - CompanyStatusPeriod
- Related W-bridge MCP tools:
  - `priorities`
  - `company_status_period`
  - `add_company_status_period`

### Progress supported by evidence
- Entities used:
  - CompanyStatusItem
- Related W-bridge MCP tools:
  - `progress`

### Risks & blockers
- Entities used:
  - CompanyStatusItem
- Related W-bridge MCP tools:
  - `risks`

### Cross-project dependencies
- Entities used:
  - CompanyStatusItem
- Related W-bridge MCP tools:
  - `dependencies`

### Material changes
- Entities used:
  - CompanyStatusItem
- Related W-bridge MCP tools:
  - `changes`

### Important decisions
- Entities used:
  - CompanyStatusItem
- Related W-bridge MCP tools:
  - `decisions`

### Learning that changed future work
- Entities used:
  - CompanyStatusItem
- Related W-bridge MCP tools:
  - `learnings`

### Company status categories
- priorities
- progress
- risks
- dependencies
- changes
- decisions
- learnings

## 3. Project Overview
### Project summary & objectives
- Entities used:
  - Project
- Related W-bridge MCP tools:
  - `project_milestones`
  - `project_todos`
  - `project_bottlenecks`

### Key milestones & alignment
- Entities used:
  - ProjectMilestone
  - Project
- Related W-bridge MCP tools:
  - `project_milestones`
  - `add_project_milestone`
  - `edit_project_milestone`

### Project contributors
- Entities used:
  - User
  - ProjectUser
  - Project
- Related W-bridge MCP tools:
  - No direct overview-only tool; related project room/user tools include `add_message` and room-level interaction tools.

### Attached AI teammates
- Entities used:
  - User
  - ProjectUser
- Related W-bridge MCP tools:
  - `list_ai_profiles`
  - `get_ai_profile`

### Resources & channels
- Entities used:
  - Room
  - Project
  - ProjectRoom association
- Related W-bridge MCP tools:
  - `add_message`
  - `approval_requests`
  - `project_todos`

## 4. Project Status
### Current phase progress
- Entities used:
  - Project
- Related W-bridge MCP tools:
  - `project_todos`
  - `project_bottlenecks`
  - `project_knowledge_items`

### Active bottlenecks
- Entities used:
  - ProjectBottleneck
  - Project
- Related W-bridge MCP tools:
  - `project_bottlenecks`
  - `add_project_bottleneck`
  - `edit_project_bottleneck`

### Next steps / what should be done
- Entities used:
  - ProjectTodo
  - Project
- Related W-bridge MCP tools:
  - `project_todos`
  - `add_project_todo`
  - `edit_project_todo`

### Project knowledge & context
- Entities used:
  - ProjectKnowledgeItem
  - Project
- Related W-bridge MCP tools:
  - `project_knowledge_items`
  - `add_project_knowledge_item`
  - `edit_project_knowledge_item`

## 5. Project All-Hands
### AI summary & key takeaways
- Entities used:
  - ProjectAllHandsTakeaway
  - Project
- Related W-bridge MCP tools:
  - `project_all_hands_takeaway`
  - `add_project_all_hands_takeaway`
  - `edit_project_all_hands_takeaway`

### Action items
- Entities used:
  - ProjectAllHandsActionItem
  - Project
- Related W-bridge MCP tools:
  - `project_all_hands_action_item`
  - `add_project_all_hands_action_item`
  - `edit_project_all_hands_action_item`

### Decisions logged
- Entities used:
  - ProjectAllHandsDecision
  - Project
- Related W-bridge MCP tools:
  - `project_all_hands_decision`
  - `add_project_all_hands_decision`
  - `edit_project_all_hands_decision`

## 6. Project Knowledge
### Networked notes (Obsidian sync)
- Entities used:
  - ObsidianNote
  - Project
- Related W-bridge MCP tools:
  - `project_obsidian_note`
  - `add_project_obsidian_note`
  - `edit_project_obsidian_note`

### External assets & playbooks
- Entities used:
  - ExternalAsset
  - Project
- Related W-bridge MCP tools:
  - `external_knowledge_assets`
  - `add_external_knowledge_asset`
  - `edit_external_knowledge_asset`

### Decision records
- Entities used:
  - ADR
  - Project
- Related W-bridge MCP tools:
  - `project_decision_records`
  - `add_project_decision_record`
  - `edit_project_decision_record`

### Directory explorer
- Entities used:
  - DirectoryItem
  - Project
- Related W-bridge MCP tools:
  - `tree_based_project_directory_data`
  - `add_tree_based_project_directory_item`
  - `edit_tree_based_project_directory_item`

### Recent knowledge activity
- Entities used:
  - KnowledgeActivity
  - Project
- Related W-bridge MCP tools:
  - `knowledge_activity_log`
  - `add_knowledge_activity_log`
  - `edit_knowledge_activity_log`

## Quick page-to-entity + MCP map
- Company Home -> AttentionItem + User + Project + Room ; MCP: `decisions_waiting`, `blockers`, `outcomes_review`, `mentions`, `material_changes`, `ai_confirm`, `knowledge_proposals`
- Company Status -> CompanyStatusPeriod + CompanyStatusItem ; MCP: `priorities`, `progress`, `risks`, `dependencies`, `changes`, `decisions`, `learnings`
- Project Overview -> Project + User + Room + ProjectMilestone + AttentionItem ; MCP: `project_milestones`, `project_todos`, `project_bottlenecks`, `add_message`
- Project Status -> Project + ProjectBottleneck + ProjectTodo + ProjectKnowledgeItem ; MCP: `project_bottlenecks`, `project_todos`, `project_knowledge_items`
- Project All-Hands -> Project + ProjectAllHandsTakeaway + ProjectAllHandsActionItem + ProjectAllHandsDecision ; MCP: `project_all_hands_takeaway`, `project_all_hands_action_item`, `project_all_hands_decision`
- Project Knowledge -> Project + ObsidianNote + ExternalAsset + ADR + DirectoryItem + KnowledgeActivity ; MCP: `project_obsidian_note`, `external_knowledge_assets`, `project_decision_records`, `tree_based_project_directory_data`, `knowledge_activity_log`

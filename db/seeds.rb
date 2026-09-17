# db/seeds.rb
# Run with: bin/rails db:seed

puts "Setting up MCP Agent Chat..."

# This creates:
# - Account (singleton)
# - Human Overseer user (administrator)
# - "All Talk" main room
# - "Meta Events" room for system events
overseer = FirstRun.setup!
FirstRun.ensure_company_bot!

if overseer
  puts "  Created Human Overseer: #{overseer.name}"
  puts "  Created account: #{Account.first.name}"
  puts "  Created rooms:"
  Room.all.each { |r| puts "    - #{r.name} (#{r.class.name.demodulize})" }
else
  puts "  Already set up (Account exists)"
end

puts "Seeding demo attention items..."
sample_items = [
  {
    category: "decisions_waiting",
    title: "Approve liquidity pool smart contract audit",
    meta_text: "Requested by @Siavash • Due today",
    overdue: true,
    action_label: "Approve",
    target_type: "company_status"
  },
  {
    category: "decisions_waiting",
    title: "Confirm multi-sig threshold update policy",
    meta_text: "Requested by @Alex • 2 hours ago",
    overdue: false,
    action_label: "Confirm",
    target_type: "company_status"
  },
  {
    category: "blockers",
    title: "Carrier SMS sender registration is blocked",
    meta_text: "Owner waiting on your compliance handoff • 1 day blocked",
    overdue: true,
    action_label: "Assign & Unblock",
    target_type: "company_status"
  },
  {
    category: "outcomes_review",
    title: "Evaluate onboarding improvement outcome",
    meta_text: "Output shipped 2 weeks ago • Measure against 30% target",
    overdue: false,
    action_label: "Record Result",
    target_type: "company_status"
  },
  {
    category: "mentions",
    title: "@Siavash review design token migration plan",
    meta_text: "From # design-system • 48 minutes ago",
    overdue: false,
    action_label: "Mark Reviewed",
    target_type: "company_status"
  },
  {
    category: "material_changes",
    title: "Deployment architecture moved to Ubuntu Cockpit",
    meta_text: "Potential impact on release process • Confirm team readiness",
    overdue: false,
    action_label: "Acknowledge",
    target_type: "company_status"
  },
  {
    category: "ai_confirm",
    title: "Builder prepared deployment rollback routine",
    meta_text: "Needs human approval before execution",
    overdue: false,
    ai_confirm: true,
    action_label: "Approve Action",
    target_type: "company_status"
  },
  {
    category: "knowledge_proposals",
    title: "Approve benchmark playbook from ERC-4337 review",
    meta_text: "Proposed by @Researcher • linked to thread evidence",
    overdue: false,
    action_label: "Approve Knowledge",
    target_type: "company_status"
  }
]

sample_items.each do |attrs|
  AttentionItem.find_or_create_by!(category: attrs[:category], title: attrs[:title]) do |item|
    item.meta_text = attrs[:meta_text]
    item.overdue = attrs[:overdue]
    item.ai_confirm = attrs.fetch(:ai_confirm, false)
    item.action_label = attrs[:action_label]
    item.target_type = attrs[:target_type]
    item.status = :pending
  end
end

puts "Seeding Company Status Periods and Items..."

august_period = CompanyStatusPeriod.find_or_create_by!(slug: "august-2026") do |period|
  period.name = "August 2026 (Current)"
  period.current = true
  period.starts_on = Date.new(2026, 8, 1)
  period.ends_on = Date.new(2026, 8, 31)
end

if august_period.company_status_items.empty?
  august_period.company_status_items.create!([
    {
      category: "priorities",
      position: 1,
      title: "1. Carevoo ERP MVP Launch",
      outcome: "Deploy core inventory and booking modules to beta salons by end of Q3.",
      detail_category: "Priority #1",
      description: "The primary milestone for Q3 is delivering the Minimum Viable Product (MVP) of Carevoo for beauty salon managers. The core release contains appointment scheduling, client management, and automated notification triggers.",
      owner: "Siavash (Lead Dev)",
      target_date: "Sept 30, 2026",
      status_label: "In Progress (68%)",
      impact: "Unlocks live user testing with initial 5 pilot salons and establishes real-world validation of our ClojureScript state management patterns.",
      actions: [
        "Finalize re-frame event handlers for multi-staff booking slots.",
        "Complete PostGIS spatial queries for nearby salon discovery.",
        "Conduct end-to-end user acceptance test with beta salon managers."
      ]
    },
    {
      category: "priorities",
      position: 2,
      title: "2. Infrastructure Stabilization",
      outcome: "Achieve zero-downtime deployments using current Ubuntu Cockpit configs.",
      detail_category: "Priority #2",
      description: "Transitioning server operations into an automated, GUI-visible system via Ubuntu Cockpit to monitor TLS certificates, service runtimes, and memory usage without manual SSH intervention.",
      owner: "Siavash",
      target_date: "Aug 28, 2026",
      status_label: "On Track",
      impact: "Ensures that infrastructure failures do not disrupt pilot users and reduces deployment time from 45 minutes to under 3 minutes.",
      actions: [
        "Automate certificate renewal checks within Cockpit.",
        "Script rollback routines in case of deployment failure."
      ]
    },
    {
      category: "priorities",
      position: 3,
      title: "3. Localized AI Integration",
      outcome: "Finalize local AI acceleration pipelines to reduce external API dependencies.",
      detail_category: "Priority #3",
      description: "Exporting localized generative AI pipelines using IREE and Vulkan runtimes to run directly on generalized AMD Radeon hardware, removing CUDA and paid cloud API lock-in.",
      owner: "AI R&D Team",
      target_date: "Mid Q4 2026",
      status_label: "Testing Phase",
      impact: "Cuts recurring cloud AI generation costs by ~90% for custom avatar and media processing.",
      actions: [
        "Benchmark Stable Diffusion export latency on Vulkan drivers.",
        "Test local GPU memory limits under concurrent load."
      ]
    },
    {
      category: "progress",
      position: 1,
      title: "Core UI Component Library (ClojureScript/re-frame)",
      percent: 85,
      color: "var(--accent-green, #10b981)",
      evidence: "All primary state subscriptions passing CI tests; forms rendering correctly in staging.",
      detail_category: "Progress Detail",
      description: "The core UI library provides reusable Reagent components powered by re-frame subscriptions. All forms, modals, tables, and navigational elements are standardizing on this structure.",
      owner: "Frontend Lead",
      target_date: "Aug 25, 2026",
      status_label: "85% Complete",
      impact: "Accelerates future feature development speed by 3x once all base atomic components are locked down.",
      actions: [
        "Polishing responsiveness on mobile screens.",
        "Finalizing accessible keyboard navigation across form controls."
      ]
    },
    {
      category: "progress",
      position: 2,
      title: "Automated SMS Pipeline",
      percent: 40,
      color: "var(--accent-yellow, #f59e0b)",
      evidence: "Backend gateway logic written, but waiting on external carrier verifications.",
      detail_category: "Progress Detail",
      description: "The SMS pipeline handles appointment reminders and registration confirmation codes sent directly to salon clients.",
      owner: "Backend Dev",
      target_date: "Pending Regulatory Clearance",
      status_label: "40% Complete (Blocked)",
      impact: "Crucial for salon client retention and reducing appointment no-shows.",
      actions: [
        "Maintain weekly check-ins with carrier registration support.",
        "Prepare fallback email template triggers."
      ]
    },
    {
      category: "risks",
      position: 1,
      title: "Carrier SMS Registration Delays",
      severity: "danger",
      icon: "🚨",
      description: "Carrier policies require extensive brand documentation before approving Alphanumeric Sender IDs and business registration bundles. Current review cycles are taking 4+ weeks with O2, Vodafone, and T-Mobile.",
      detail_category: "Critical Risk",
      owner: "Compliance / Ops",
      target_date: "Immediate",
      status_label: "Active Blocker",
      impact: "Outbound registration and appointment reminder texts risk being silently filtered by major cellular networks upon launch.",
      actions: [
        "Submitted updated registration forms directly to tier-1 aggregators.",
        "Evaluating temporary WhatsApp Business API integration as an emergency fallback."
      ]
    },
    {
      category: "risks",
      position: 2,
      title: "PostGIS Database Indexing",
      severity: "warning",
      icon: "⚠️",
      description: "Proximity calculations using SRID EPSG:4326 in PostGIS are hitting high latency spikes when executing spatial bounding-box checks over large datasets.",
      detail_category: "Technical Risk",
      owner: "Database Architect",
      target_date: "Sept 05, 2026",
      status_label: "Under Investigation",
      impact: "Could cause slow response times when salon clients search for nearby service providers.",
      actions: [
        "Implement spatial GIST indexes on coordinate columns.",
        "Benchmark radius search queries against cached bounding boxes."
      ]
    },
    {
      category: "dependencies",
      position: 1,
      title: "Carevoo Notification System → Compliance Review (Data Privacy)",
      from_name: "Carevoo Notification System",
      to_name: "Compliance Review (Data Privacy)",
      detail_category: "Cross-Project Dependency",
      description: "The customer notification engine requires strict ePrivacy and GDPR compliance validation regarding customer contact consent storage before sending live marketing messages.",
      owner: "Legal & Backend Lead",
      target_date: "Sept 10, 2026",
      status_label: "Pending Consent Audit",
      impact: "Prevents marketing automated campaigns from going live alongside the booking engine.",
      actions: [
        "Draft explicit opt-in checkbox components in customer-facing flows.",
        "Audit audit-log table schema for consent tracking."
      ]
    },
    {
      category: "changes",
      position: 1,
      title: "Pivoted primary deployment server architecture from raw Docker instances to utilizing Ubuntu Server via Cockpit.",
      detail_category: "Material Change",
      description: "We shifted from purely headless CLI Docker deployments to leveraging Ubuntu Server with Cockpit web services for server management.",
      owner: "DevOps",
      target_date: "Completed Aug 2026",
      status_label: "Implemented",
      impact: "Significantly reduces troubleshooting overhead for TLS handshake errors, memory leaks, and service logs.",
      actions: [
        "Configured hostname matching `.crt` SSL files in Cockpit.",
        "Created unified system administrative dashboard."
      ]
    },
    {
      category: "decisions",
      position: 1,
      title: "<strong>Frontend Framework:</strong> Standardized on ClojureScript with Reagent/re-frame.",
      detail_category: "Important Decision",
      description: "Chosen over standard React/TypeScript to guarantee strict immutability and centralized event routing across complex salon calendar screens.",
      owner: "Architecture Lead",
      target_date: "Locked In",
      status_label: "Active Standard",
      impact: "Eliminates state synchronization bugs across complex multi-paned interfaces.",
      actions: [
        "Document state subscription patterns in internal knowledge base.",
        "Maintain shadow-cljs build scripts."
      ]
    },
    {
      category: "learnings",
      position: 1,
      title: "<strong>Hardware Tooling:</strong> 500W spindles struggle with high-density materials compared to pulley-reduced 775 motors.",
      detail_category: "Key Learning",
      description: "Testing in our hardware lab showed 500W direct spindles stall under continuous load when milling aluminum brackets, whereas torque-reduced 775 motor setups maintain clean cutting speeds.",
      owner: "Hardware Lab",
      target_date: "N/A",
      status_label: "Applied to Prototypes",
      impact: "Saves hardware iteration cycles by establishing high-torque baselines for future physical enclosures.",
      actions: [
        "Update hardware component specs for all CNC milling builds.",
        "Order 3:1 pulley reduction gear sets."
      ]
    }
  ])
end

july_period = CompanyStatusPeriod.find_or_create_by!(slug: "july-2026") do |period|
  period.name = "July 2026"
  period.current = false
  period.starts_on = Date.new(2026, 7, 1)
  period.ends_on = Date.new(2026, 7, 31)
end

if july_period.company_status_items.empty?
  july_period.company_status_items.create!([
    {
      category: "priorities",
      position: 1,
      title: "1. Core Architecture Setup",
      outcome: "Establish base `project.clj` Leiningen configs for Carevoo.",
      detail_category: "July Milestone",
      description: "Initial foundational setup for the Carevoo repository using Clojure Leiningen project structures.",
      owner: "Siavash",
      target_date: "July 2026",
      status_label: "Completed",
      impact: "Established unified repo structure for frontend and backend.",
      actions: [ "Configured shadow-cljs and Leiningen aliases." ]
    }
  ])
end

june_period = CompanyStatusPeriod.find_or_create_by!(slug: "june-2026") do |period|
  period.name = "June 2026"
  period.current = false
  period.starts_on = Date.new(2026, 6, 1)
  period.ends_on = Date.new(2026, 6, 30)
end

if june_period.company_status_items.empty?
  june_period.company_status_items.create!([
    {
      category: "priorities",
      position: 1,
      title: "1. Feasibility & Mathematical Modeling",
      outcome: "Finalize matrix logic required for scheduling algorithms.",
      detail_category: "June Milestone",
      description: "Theoretical ground-level work using difference matrices over finite groups to design scheduling logic.",
      owner: "Siavash",
      target_date: "June 2026",
      status_label: "Completed",
      impact: "Validated mathematical feasibility for non-conflicting appointment slot generation.",
      actions: [ "Drafted thesis abstract and algorithm specs." ]
    }
  ])
end

puts "Seeding Demo Projects and Project Status..."

b2b_project = Project.find_or_create_by!(slug: "b2b-crypto-platform") do |project|
  project.name = "B2B Crypto Platform"
  project.path = "/projects/b2b-crypto-platform"
  project.short_code = "B2B"
  project.description = "B2B Crypto Platform is focused on secure institutional liquidity settlement with strong multi-signature governance and low-latency transaction confirmation workflows."
  project.current_phase = "Phase 2: Core Platform Development"
  project.progress_percent = 65
  project.recently_completed = "Tailwind CSS styling applied to profile settings and card-based booking selectors. Leaflet map integrations merged to main."
  project.private = false
end

b2b_project.update!(
  name: "B2B Crypto Platform",
  path: "/projects/b2b-crypto-platform",
  short_code: "B2B",
  description: "B2B Crypto Platform is focused on secure institutional liquidity settlement with strong multi-signature governance and low-latency transaction confirmation workflows.",
  current_phase: "Phase 2: Core Platform Development",
  progress_percent: 65,
  recently_completed: "Tailwind CSS styling applied to profile settings and card-based booking selectors. Leaflet map integrations merged to main."
)

user_to_assign = overseer || User.first
if user_to_assign
  b2b_project.project_users.find_or_create_by!(user: user_to_assign)
  project_room = b2b_project.ensure_project_room!
  Membership.find_or_create_by!(room: project_room, participant: user_to_assign)
end

if b2b_project.bottlenecks.empty?
  b2b_project.bottlenecks.create!([
    {
      title: "Obsidian Vault Indexing Timeout",
      description: "The Hermes agent is failing to scan larger directories when connected to the Obsidian Model Context Protocol server. We need to implement pagination or optimize the context window parsing.",
      severity: "active",
      position: 1
    }
  ])
end

if b2b_project.todos.empty?
  b2b_project.todos.create!([
    {
      title: "Finalize Express.js API Routes",
      meta_text: "Connect the Node.js backend to the newly merged frontend booking selectors.",
      completed: false,
      position: 1
    },
    {
      title: "Review Buzz Platform Workflows",
      meta_text: "Validate the latest decentralized agent workflows running on Block's Buzz project.",
      completed: false,
      position: 2
    }
  ])
end

if b2b_project.knowledge_items.empty?
  b2b_project.knowledge_items.create!([
    {
      title: "Infrastructure Routing",
      badge: "Architecture",
      description: "Our VPS is exclusively hosted on Infomaniak. Nginx Proxy Manager handles reverse proxy routing, and server administration is managed via Cockpit. Firewall rules have been updated to allow external binding.",
      position: 1
    },
    {
      title: "Custom Agent Delegation",
      badge: "AI Integration",
      description: "All queries regarding workspace documentation or generalized team knowledge should be @-mentioned to @orgknowledge in the relevant chatrooms, rather than querying external LLMs directly.",
      position: 2
    },
    {
      title: "Frontend Stack",
      badge: "Tech Stack",
      description: "The marketplace strictly adheres to vanilla JavaScript, HTML, and Tailwind CSS for mockups to ensure lightweight rendering before React/Vue integration.",
      position: 3
    }
  ])
end

if b2b_project.project_all_hands_takeaways.empty? && b2b_project.project_all_hands_action_items.empty? && b2b_project.project_all_hands_decisions.empty?
  b2b_project.project_all_hands_takeaways.create!([
    {
      category: "Security",
      content: "The core vault logic passed the external audit with zero critical vulnerabilities.",
      position: 1,
      active: true
    },
    {
      category: "Timeline",
      content: "Leadership confirmed the Q3 launch target is locked in for September 15th.",
      position: 2,
      active: true
    },
    {
      category: "Marketing",
      content: "The go-to-market strategy is shifting slightly to focus on enterprise liquidity providers first.",
      position: 3,
      active: true
    }
  ])

  b2b_project.project_all_hands_action_items.create!([
    {
      title: "Finalize Multi-sig threshold logic",
      assignee_name: "Alex",
      due_date: "Aug 25",
      completed: false,
      position: 1,
      active: true
    },
    {
      title: "Draft release notes for V1",
      assignee_name: "Sarah",
      due_date: "Aug 28",
      completed: false,
      position: 2,
      active: true
    },
    {
      title: "Send Vault contract to auditors",
      assignee_name: "Siavash",
      completed: true,
      completed_at: Time.zone.parse("2026-08-18 14:00:00"),
      position: 3,
      active: true
    }
  ])

  b2b_project.project_all_hands_decisions.create!([
    {
      title: "We will use 3-of-5 multisig for mainnet deployment.",
      basis: "Decided in consensus",
      impact: "#smart-contracts",
      badge: "Logged in System",
      position: 1,
      active: true
    }
  ])
end

if b2b_project.obsidian_notes.empty?
  b2b_project.obsidian_notes.create!([
    {
      title: "Smart Contract Vault (V1)",
      tags: "#architecture #smart-contracts",
      content: "This document outlines the core vault logic for the institutional liquidity settlement layer. The vault is designed to hold collateral securely while allowing sub-second state channels to finalize.\n\n**Dependencies:** We are relying heavily on the updated [[ERC-4337 Gas Optimization]] patterns discussed in last week's sync.\n\n### Security Clearances\nAs per the decision logged in the [[August 17 All-Hands]], the mainnet deployment requires a [[Multi-Sig Threshold]] of 3-of-5.",
      html_source_type: "internal_file",
      html_source_path: "obsidian/graph.html",
      position: 1
    }
  ])
end

if b2b_project.external_assets.empty?
  b2b_project.external_assets.create!([
    {
      title: "Trail of Bits Audit",
      doc_type: "pdf",
      icon: "📄",
      source_type: "internal_file",
      url: "02_Smart_Contracts/Audits/Trail_of_Bits_Audit.md",
      meta_text: "PDF • Updated Aug 15",
      position: 1
    },
    {
      title: "Platform UI / UX Design",
      doc_type: "figma",
      icon: "🎨",
      source_type: "external_url",
      url: "https://figma.com",
      meta_text: "Figma • External Link",
      position: 2
    },
    {
      title: "Multi-Sig Deployment",
      doc_type: "runbook",
      icon: "📘",
      source_type: "internal_file",
      url: "02_Smart_Contracts/Vault_V1.md",
      meta_text: "Runbook • Playbook",
      position: 3
    },
    {
      title: "API Documentation",
      doc_type: "swagger",
      icon: "⚙️",
      source_type: "external_url",
      url: "https://swagger.io",
      meta_text: "Swagger UI • Live",
      position: 4
    }
  ])
end

if b2b_project.adrs.empty?
  b2b_project.adrs.create!([
    {
      identifier: "ADR-004",
      title: "Use ECDSA for State Channel Signatures",
      decision_date: Date.new(2024, 8, 10),
      status: "accepted",
      file_path: "01_Architecture/ADR-004.md",
      position: 1
    },
    {
      identifier: "ADR-005",
      title: "Transition to Postgres for Off-chain Indexing",
      decision_date: Date.new(2024, 8, 18),
      status: "proposed",
      file_path: "01_Architecture/DB_Schemas.md",
      position: 2
    },
    {
      identifier: "ADR-002",
      title: "Use MongoDB for Order Book",
      decision_date: Date.new(2024, 1, 15),
      status: "deprecated",
      file_path: "01_Architecture/System_Design.md",
      position: 3
    }
  ])
end

if b2b_project.knowledge_activities.empty?
  b2b_project.knowledge_activities.create!([
    {
      actor_name: "Sarah",
      actor_color: "var(--accent-blue)",
      action_text: "created new note [[Postgres Migration Plan]]",
      target_path: "01_Architecture/DB_Schemas.md",
      created_at: 2.hours.ago,
      position: 1
    },
    {
      actor_name: "Mike",
      actor_color: "var(--accent-green)",
      action_text: "updated the <strong>Multi-Sig Deployment</strong> runbook",
      target_path: "02_Smart_Contracts/Vault_V1.md",
      created_at: 1.day.ago,
      position: 2
    },
    {
      actor_name: "Alex",
      actor_color: "var(--text-secondary)",
      action_text: "changed status of <strong>ADR-004</strong> to Accepted",
      target_path: "01_Architecture/ADR-004.md",
      created_at: 20.days.ago,
      position: 3
    }
  ])
end

if b2b_project.directory_items.empty?
  arch_dir = b2b_project.directory_items.create!(
    name: "01_Architecture",
    item_type: "directory",
    position: 1
  )
  arch_dir.children.create!([
    {
      project: b2b_project,
      name: "System_Design.md",
      item_type: "file",
      file_path: "01_Architecture/System_Design.md",
      position: 1
    },
    {
      project: b2b_project,
      name: "DB_Schemas.md",
      item_type: "file",
      file_path: "01_Architecture/DB_Schemas.md",
      position: 2
    },
    {
      project: b2b_project,
      name: "ADR-004.md",
      item_type: "file",
      file_path: "01_Architecture/ADR-004.md",
      position: 3
    }
  ])

  contracts_dir = b2b_project.directory_items.create!(
    name: "02_Smart_Contracts",
    item_type: "directory",
    position: 2
  )

  audits_dir = contracts_dir.children.create!(
    project: b2b_project,
    name: "Audits",
    item_type: "directory",
    position: 1
  )
  audits_dir.children.create!(
    project: b2b_project,
    name: "Trail_of_Bits_Audit.md",
    item_type: "file",
    file_path: "02_Smart_Contracts/Audits/Trail_of_Bits_Audit.md",
    position: 1
  )

  contracts_dir.children.create!(
    project: b2b_project,
    name: "Vault_V1.md",
    item_type: "file",
    file_path: "02_Smart_Contracts/Vault_V1.md",
    position: 2
  )

  b2b_project.directory_items.create!(
    name: "03_Meetings",
    item_type: "directory",
    position: 3
  )

  b2b_project.directory_items.create!(
    name: "99_Archives",
    item_type: "directory",
    position: 4
  )
end

# Seed sample storage files for the demo project
demo_storage_dir = Rails.root.join("storage", "projects", b2b_project.id.to_s)
FileUtils.mkdir_p(demo_storage_dir.join("01_Architecture"))
FileUtils.mkdir_p(demo_storage_dir.join("02_Smart_Contracts", "Audits"))
FileUtils.mkdir_p(demo_storage_dir.join("03_Meetings"))
FileUtils.mkdir_p(demo_storage_dir.join("99_Archives"))
FileUtils.mkdir_p(demo_storage_dir.join("obsidian"))

File.write(
  demo_storage_dir.join("01_Architecture", "System_Design.md"),
  "# System Design & Architecture\n\n## Overview\nThis document outlines the core architecture of the B2B Settlement Platform.\n\n- **Settlement Engine**: Asynchronous transaction processor.\n- **Off-chain State Channels**: Sub-second finality with zero gas overhead.\n- **Vault Storage**: Multi-sig protected smart contract pools.\n\n```mermaid\ngraph TD\n  Client --> Router\n  Router --> Vault\n```\n"
)

File.write(
  demo_storage_dir.join("01_Architecture", "DB_Schemas.md"),
  "# Database Schemas & Storage Migration\n\n## Postgres Off-chain Store\n\nTransitioning from MongoDB to PostgreSQL for relational transaction auditing.\n\n| Table | Purpose | Indexing Strategy |\n|---|---|---|\n| `settlements` | Finalized batches | B-Tree on `(batch_id, block_num)` |\n| `audit_logs` | State channel updates | Partitioned by month |\n"
)

File.write(
  demo_storage_dir.join("01_Architecture", "ADR-004.md"),
  "# ADR-004: Use ECDSA for State Channel Signatures\n\n**Status:** Accepted\n**Date:** 2024-08-10\n\n## Context\nState channels require lightweight and EVM-native cryptographic verification to ensure low transaction costs.\n\n## Decision\nWe standardize on `secp256k1` ECDSA signatures using OpenZeppelin ECDSA recovery helpers.\n\n## Consequences\n- Guarantees sub-10k gas verification.\n- Simplifies hardware wallet integrations.\n"
)

File.write(
  demo_storage_dir.join("02_Smart_Contracts", "Vault_V1.md"),
  "# Vault V1 Runbook & Deployment Guide\n\n## Deployment Sequence\n1. Deploy `VaultFactory.sol` to Base Sepolia testnet.\n2. Initialize signer set with 3-of-5 threshold.\n3. Verify bytecode on block explorer.\n\n```bash\nforge script script/DeployVault.s.sol --rpc-url $BASE_SEPOLIA_RPC --broadcast\n```\n"
)

File.write(
  demo_storage_dir.join("02_Smart_Contracts", "Audits", "Trail_of_Bits_Audit.md"),
  "# Trail of Bits Security Audit Summary\n\n**Date:** August 15, 2024\n**Scope:** Vault V1 and State Channel Router contracts.\n\n## Key Findings\n- **0 Critical Vulnerabilities**\n- **0 High Severity Vulnerabilities**\n- **2 Informational Notes**: Reentrancy guard ordering and event emission indexing.\n"
)

File.write(
  demo_storage_dir.join("obsidian", "graph.html"),
  <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Obsidian Sync View</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          background-color: #1e1e1e;
          color: #d4d4d4;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          height: 100vh;
          overflow: hidden;
          display: flex;
        }
        .obsidian-graph {
          width: 32%;
          background-color: #252526;
          border-right: 1px solid #333333;
          position: relative;
          padding: 16px;
          display: flex;
          flex-direction: column;
          flex-shrink: 0;
        }
        .obs-header {
          color: #d4d4d4;
          font-size: 11px;
          text-transform: uppercase;
          letter-spacing: 1px;
          font-weight: 600;
          margin-bottom: 16px;
          display: flex;
          justify-content: space-between;
        }
        .graph-visual {
          flex: 1;
          position: relative;
          background-image:
            radial-gradient(circle at 50% 50%, #c586c0 5px, transparent 6px),
            radial-gradient(circle at 20% 30%, #4ec9b0 4px, transparent 5px),
            radial-gradient(circle at 80% 70%, #d4d4d4 4px, transparent 5px),
            radial-gradient(circle at 30% 80%, #d4d4d4 4px, transparent 5px);
          background-size: 100% 100%;
        }
        .graph-line {
          position: absolute;
          background-color: #444444;
          height: 1px;
          transform-origin: 0 0;
        }
        .graph-node-label {
          position: absolute;
          font-size: 11px;
          font-weight: 500;
        }
        .obsidian-note {
          flex: 1;
          padding: 24px 32px;
          color: #d4d4d4;
          overflow-y: auto;
        }
        .obs-title {
          font-size: 22px;
          color: #ffffff;
          margin-bottom: 14px;
          font-weight: 600;
        }
        .obs-tags {
          display: flex;
          gap: 8px;
          margin-bottom: 20px;
        }
        .obs-tag {
          color: #9cdcfe;
          background: rgba(156, 220, 254, 0.12);
          padding: 3px 10px;
          border-radius: 12px;
          font-size: 12px;
        }
        .obs-content p {
          margin-bottom: 14px;
          line-height: 1.6;
          font-size: 14px;
        }
        .obs-content strong { color: #ffffff; }
        .obs-link { color: #4ec9b0; text-decoration: none; cursor: pointer; }
        .obs-link:hover { text-decoration: underline; }
        .obs-content h3 { color: #ffffff; margin: 20px 0 10px 0; font-size: 15px; }
      </style>
    </head>
    <body>
      <div class="obsidian-graph">
        <div class="obs-header"><span>Graph View</span><span>⚙️</span></div>
        <div class="graph-visual">
          <div class="graph-line" style="width: 80px; top: 50%; left: 50%; transform: rotate(-35deg);"></div>
          <div class="graph-line" style="width: 120px; top: 50%; left: 50%; transform: rotate(115deg);"></div>
          <div class="graph-line" style="width: 60px; top: 30%; left: 20%; transform: rotate(15deg);"></div>
          <div class="graph-node-label" style="top: 53%; left: 52%; color: #d4d4d4;">Smart Contract Vault</div>
          <div class="graph-node-label" style="top: 25%; left: 22%; color: #888888; font-size: 10px;">ERC-4337 Specs</div>
        </div>
      </div>

      <div class="obsidian-note">
        <h1 class="obs-title">Smart Contract Vault (V1)</h1>
        <div class="obs-tags">
          <span class="obs-tag">#architecture</span>
          <span class="obs-tag">#smart-contracts</span>
        </div>
        <div class="obs-content">
          <p>This document outlines the core vault logic for the institutional liquidity settlement layer. The vault is designed to hold collateral securely while allowing sub-second state channels to finalize.</p>
          <p><strong>Dependencies:</strong> We are relying heavily on the updated <span class="obs-link">[[ERC-4337 Gas Optimization]]</span> patterns discussed in last week's sync.</p>
          <h3>Security Clearances</h3>
          <p>As per the decision logged in the <span class="obs-link">[[August 17 All-Hands]]</span>, the mainnet deployment requires a <span class="obs-link">[[Multi-Sig Threshold]]</span> of 3-of-5.</p>
        </div>
      </div>
    </body>
    </html>
  HTML
)

puts "Seeding Action & Approval Messages in Chat Rooms..."

target_rooms = [ b2b_project.project_room, Room.find_by(name: "All Talk"), Room.find_by(name: "som") ].compact.uniq

w_assistant = Agent.find_or_create_by!(project: b2b_project, name: "W Assistant") do |agent|
  agent.model = "claude-3-5-sonnet-20241022"
  agent.program = "assistant"
  agent.task_description = "Architecture & Decision Tracking Assistant"
  agent.status = :online
end

researcher = Agent.find_or_create_by!(project: b2b_project, name: "Researcher") do |agent|
  agent.model = "claude-3-5-sonnet-20241022"
  agent.program = "researcher"
  agent.task_description = "Research and Playbook Synthesis"
  agent.status = :online
end

target_rooms.each do |room|
  Membership.find_or_create_by!(room: room, participant: w_assistant)
  Membership.find_or_create_by!(room: room, participant: researcher)
  Membership.find_or_create_by!(room: room, participant: user_to_assign) if user_to_assign

  # 1. Pending Decision Confirmation Action
  msg1 = room.messages.create!(
    creator: user_to_assign || w_assistant,
    body: "We should stick with the current gas optimization pattern for the ERC-4337 router.",
    client_message_id: SecureRandom.uuid
  )

  msg2 = room.messages.create!(
    creator: w_assistant,
    body: "I synthesized the proposal and drafted an architectural decision record for the router pattern.",
    client_message_id: SecureRandom.uuid
  )

  ar1 = ApprovalRequest.find_or_create_by!(message: msg2) do |req|
    req.room = room
    req.agent = w_assistant
    req.request_type = "decision"
    req.payload = { "decision" => "Use gas optimization pattern for ERC-4337 router." }
    req.status = :pending
    req.requested_at = 15.minutes.ago
  end

  # Link attention item if present
  if (att1 = AttentionItem.find_by(title: "Confirm multi-sig threshold update policy"))
    att1.update(room: room, source: ar1, project: b2b_project)
  end

  # 2. Pending Knowledge Proposal Approval Action
  msg3 = room.messages.create!(
    creator: user_to_assign || researcher,
    body: "@Researcher propose this benchmark analysis as reusable company knowledge for future smart contract reviews.",
    client_message_id: SecureRandom.uuid
  )

  msg4 = room.messages.create!(
    creator: researcher,
    body: "Benchmark analysis compiled with gas profiling metrics across Base Sepolia and Arbitrum One testnets.",
    client_message_id: SecureRandom.uuid
  )

  ar2 = ApprovalRequest.find_or_create_by!(message: msg4) do |req|
    req.room = room
    req.agent = researcher
    req.request_type = "knowledge_proposal"
    req.payload = { "decision" => "Approve benchmark playbook from ERC-4337 review as company knowledge." }
    req.status = :pending
    req.requested_at = 45.minutes.ago
  end

  if (att2 = AttentionItem.find_by(title: "Approve benchmark playbook from ERC-4337 review"))
    att2.update(room: room, source: ar2, project: b2b_project)
  end

  # 3. Approved / Resolved Decision Action
  msg5 = room.messages.create!(
    creator: w_assistant,
    body: "Mainnet deployment configuration requires final signer threshold verification.",
    client_message_id: SecureRandom.uuid
  )

  ar3 = ApprovalRequest.find_or_create_by!(message: msg5) do |req|
    req.room = room
    req.agent = w_assistant
    req.request_type = "decision"
    req.payload = { "decision" => "Standardize on 3-of-5 multisig for mainnet deployment." }
    req.status = :approved
    req.resolved_by = user_to_assign
    req.resolved_at = 1.day.ago
    req.requested_at = 2.days.ago
  end

  ar3.approval_request_actions.find_or_create_by!(action: "confirm", actor: user_to_assign) do |action|
    action.note = "Confirmed in consensus during all-hands sync"
  end
end

puts "Done!"

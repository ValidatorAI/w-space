module Mcp
  def self.load_tools!
    Registry.reset!

    # Baseline tool
    Registry.register(Tools::HelloTool.new, scopes: %i[all read action knowledge task])

    # Attention Items
    attention_tools = [
      Tools::AttentionItems::AttentionItemsTool.new,
      Tools::AttentionItems::DecisionsWaitingTool.new,
      Tools::AttentionItems::BlockersTool.new,
      Tools::AttentionItems::OutcomesReviewTool.new,
      Tools::AttentionItems::MentionsTool.new,
      Tools::AttentionItems::MaterialChangesTool.new,
      Tools::AttentionItems::AiConfirmTool.new,
      Tools::AttentionItems::KnowledgeProposalsTool.new,
      Tools::AttentionItems::AddDecisionsWaitingTool.new,
      Tools::AttentionItems::AddBlockersTool.new,
      Tools::AttentionItems::AddOutcomesReviewTool.new,
      Tools::AttentionItems::AddMentionsTool.new,
      Tools::AttentionItems::AddMaterialChangesTool.new,
      Tools::AttentionItems::AddAiConfirmTool.new,
      Tools::AttentionItems::AddKnowledgeProposalsTool.new,
      Tools::AttentionItems::EditDecisionsWaitingTool.new,
      Tools::AttentionItems::EditBlockersTool.new,
      Tools::AttentionItems::EditOutcomesReviewTool.new,
      Tools::AttentionItems::EditMentionsTool.new,
      Tools::AttentionItems::EditMaterialChangesTool.new,
      Tools::AttentionItems::EditAiConfirmTool.new,
      Tools::AttentionItems::EditKnowledgeProposalsTool.new,
      Tools::AttentionItems::DeleteAttentionItemTool.new
    ]
    attention_tools.each do |tool|
      scopes = tool.name.start_with?("add_", "edit_", "delete_") ? %i[all action] : %i[all read action]
      Registry.register(tool, scopes: scopes)
    end

    # Company Status
    status_tools = [
      Tools::CompanyStatus::CompanyStatusPeriodTool.new,
      Tools::CompanyStatus::AddCompanyStatusPeriodTool.new,
      Tools::CompanyStatus::EditCompanyStatusPeriodTool.new,
      Tools::CompanyStatus::PrioritiesTool.new,
      Tools::CompanyStatus::ProgressTool.new,
      Tools::CompanyStatus::RisksTool.new,
      Tools::CompanyStatus::DependenciesTool.new,
      Tools::CompanyStatus::ChangesTool.new,
      Tools::CompanyStatus::DecisionsTool.new,
      Tools::CompanyStatus::LearningsTool.new
    ]
    status_tools.each do |tool|
      scopes = tool.name.start_with?("add_", "edit_") ? %i[all action] : %i[all read action]
      Registry.register(tool, scopes: scopes)
    end

    # Project Items
    project_item_tools = [
      Tools::ProjectItems::ProjectMilestonesTool.new,
      Tools::ProjectItems::AddProjectMilestoneTool.new,
      Tools::ProjectItems::EditProjectMilestoneTool.new,
      Tools::ProjectItems::DeleteProjectMilestoneTool.new,
      Tools::ProjectItems::ProjectBottlenecksTool.new,
      Tools::ProjectItems::AddProjectBottleneckTool.new,
      Tools::ProjectItems::EditProjectBottleneckTool.new,
      Tools::ProjectItems::DeleteProjectBottleneckTool.new,
      Tools::ProjectItems::ProjectTodosTool.new,
      Tools::ProjectItems::AddProjectTodoTool.new,
      Tools::ProjectItems::EditProjectTodoTool.new,
      Tools::ProjectItems::DeleteProjectTodoTool.new
    ]
    project_item_tools.each do |tool|
      scopes = tool.name.start_with?("add_", "edit_", "delete_") ? %i[all action] : %i[all read action]
      Registry.register(tool, scopes: scopes)
    end

    # Project All-Hands
    all_hands_tools = [
      Tools::ProjectAllHands::ProjectAllHandsTakeawayTool.new,
      Tools::ProjectAllHands::AddProjectAllHandsTakeawayTool.new,
      Tools::ProjectAllHands::EditProjectAllHandsTakeawayTool.new,
      Tools::ProjectAllHands::DeleteProjectAllHandsTakeawayTool.new,
      Tools::ProjectAllHands::ProjectAllHandsDecisionTool.new,
      Tools::ProjectAllHands::AddProjectAllHandsDecisionTool.new,
      Tools::ProjectAllHands::EditProjectAllHandsDecisionTool.new,
      Tools::ProjectAllHands::DeleteProjectAllHandsDecisionTool.new,
      Tools::ProjectAllHands::ProjectAllHandsActionItemTool.new,
      Tools::ProjectAllHands::AddProjectAllHandsActionItemTool.new,
      Tools::ProjectAllHands::EditProjectAllHandsActionItemTool.new,
      Tools::ProjectAllHands::DeleteProjectAllHandsActionItemTool.new
    ]
    all_hands_tools.each do |tool|
      scopes = tool.name.start_with?("add_", "edit_", "delete_") ? %i[all action] : %i[all read action]
      Registry.register(tool, scopes: scopes)
    end

    # Project Knowledge
    knowledge_tools = [
      Tools::ProjectKnowledge::ProjectKnowledgeItemsTool.new,
      Tools::ProjectKnowledge::AddProjectKnowledgeItemTool.new,
      Tools::ProjectKnowledge::EditProjectKnowledgeItemTool.new,
      Tools::ProjectKnowledge::DeleteProjectKnowledgeItemTool.new,
      Tools::ProjectKnowledge::ProjectDecisionRecordsTool.new,
      Tools::ProjectKnowledge::AddProjectDecisionRecordTool.new,
      Tools::ProjectKnowledge::EditProjectDecisionRecordTool.new,
      Tools::ProjectKnowledge::DeleteProjectDecisionRecordTool.new,
      Tools::ProjectKnowledge::ProjectNoteTool.new,
      Tools::ProjectKnowledge::AddProjectNoteTool.new,
      Tools::ProjectKnowledge::EditProjectNoteTool.new,
      Tools::ProjectKnowledge::DeleteProjectNoteTool.new,
      Tools::ProjectKnowledge::TreeBasedProjectDirectoryDataTool.new,
      Tools::ProjectKnowledge::AddTreeBasedProjectDirectoryItemTool.new,
      Tools::ProjectKnowledge::EditTreeBasedProjectDirectoryItemTool.new,
      Tools::ProjectKnowledge::DeleteTreeBasedProjectDirectoryItemTool.new,
      Tools::ProjectKnowledge::ExternalKnowledgeAssetsTool.new,
      Tools::ProjectKnowledge::AddExternalKnowledgeAssetTool.new,
      Tools::ProjectKnowledge::EditExternalKnowledgeAssetTool.new,
      Tools::ProjectKnowledge::DeleteExternalKnowledgeAssetTool.new,
      Tools::ProjectKnowledge::KnowledgeActivityLogTool.new,
      Tools::ProjectKnowledge::AddKnowledgeActivityLogTool.new,
      Tools::ProjectKnowledge::EditKnowledgeActivityLogTool.new,
      Tools::ProjectKnowledge::DeleteKnowledgeActivityLogTool.new,
      Tools::ProjectKnowledge::KnowledgeSummaryItemsTool.new,
      Tools::ProjectKnowledge::AddKnowledgeSummaryItemTool.new,
      Tools::ProjectKnowledge::EditKnowledgeSummaryItemTool.new,
      Tools::ProjectKnowledge::DeleteKnowledgeSummaryItemTool.new
    ]
    knowledge_tools.each do |tool|
      scopes = tool.name.start_with?("add_", "edit_", "delete_") ? %i[all action] : %i[all read action]
      Registry.register(tool, scopes: scopes)
    end

    # Messaging & Rooms
    Registry.register(Tools::Messaging::ListRoomsTool.new, scopes: %i[all read action])
    Registry.register(Tools::Messaging::SearchRoomsTool.new, scopes: %i[all read action])
    Registry.register(Tools::Messaging::GetRoomMembersTool.new, scopes: %i[all read action])
    Registry.register(Tools::Messaging::GetUsersTool.new, scopes: %i[all read action])
    Registry.register(Tools::Messaging::GetProjectsTool.new, scopes: %i[all read action])
    Registry.register(Tools::Messaging::GetSingleProjectTool.new, scopes: %i[all read action])
    Registry.register(Tools::Messaging::GetProjectUsersTool.new, scopes: %i[all read action])
    Registry.register(Tools::Messaging::GetUserProjectsTool.new, scopes: %i[all read action])
    Registry.register(Tools::RoomContext::RoomDecisionContextTool.new, scopes: %i[all read])
    Registry.register(Tools::RoomContext::RoomEvidenceTool.new, scopes: %i[all read])
    Registry.register(Tools::RoomContext::RoomEconomicsTool.new, scopes: %i[all read])
    Registry.register(Tools::RoomContext::RoomContextSummaryTool.new, scopes: %i[all read])
    Registry.register(Tools::Messaging::AddMessageTool.new, scopes: %i[all action])
    Registry.register(Tools::Messaging::DeleteMessageTool.new, scopes: %i[all action])
    Registry.register(Tools::Messaging::AddLoadingMessageTool.new, scopes: %i[all action])
    Registry.register(Tools::Messaging::EditLoadingMessageTool.new, scopes: %i[all action])
    Registry.register(Tools::Messaging::DeleteLoadingMessageTool.new, scopes: %i[all action])
    Registry.register(Tools::Messaging::AddActionMessageTool.new, scopes: %i[all action])
    Registry.register(Tools::Messaging::AddDecisionMessageTool.new, scopes: %i[all action])

    # Approvals
    Registry.register(Tools::Approvals::ApprovalRequestsTool.new, scopes: %i[all read action])
    Registry.register(Tools::Approvals::GetApprovalRequestTool.new, scopes: %i[all read])
    Registry.register(Tools::Approvals::AddApprovalRequestTool.new, scopes: %i[all action])
    Registry.register(Tools::Approvals::AddApproveRequestWithMessageTool.new, scopes: %i[all action])
    Registry.register(Tools::Approvals::EditApprovalRequestTool.new, scopes: %i[all action])
    Registry.register(Tools::Approvals::DeleteApprovalRequestTool.new, scopes: %i[all action])

    # AI Config
    ai_config_tools = [
      Tools::AiConfig::ListAiProfilesTool.new,
      Tools::AiConfig::GetAiProfileTool.new,
      Tools::AiConfig::ListAiSettingsTool.new,
      Tools::AiConfig::GetAiSettingTool.new,
      Tools::AiConfig::ListMcpsTool.new,
      Tools::AiConfig::GetMcpTool.new,
      Tools::AiConfig::ListToolsTool.new,
      Tools::AiConfig::GetToolTool.new,
      Tools::AiConfig::ListSkillsTool.new,
      Tools::AiConfig::GetSkillTool.new,
      Tools::AiConfig::ListAiProfileToolsTool.new,
      Tools::AiConfig::GetAiProfileToolTool.new,
      Tools::AiConfig::ListAiProfileSkillsTool.new,
      Tools::AiConfig::GetAiProfileSkillTool.new,
      Tools::AiConfig::ListAiProfileMcpsTool.new,
      Tools::AiConfig::GetAiProfileMcpTool.new
    ]
    ai_config_tools.each { |tool| Registry.register(tool, scopes: %i[all read config]) }

    # Topics & Analysis
    topic_tools = [
      Tools::Topics::TopicsTool.new,
      Tools::Topics::GetTopicTool.new,
      Tools::Topics::CreateTopicTool.new,
      Tools::Topics::UpdateTopicTool.new,
      Tools::Topics::DeleteTopicTool.new,
      Tools::Topics::RoomTopicTreeTool.new,
      Tools::Topics::SearchTopicsTool.new,
      Tools::Topics::TopicToolCallLogsTool.new,
      Tools::Topics::GetTopicToolCallLogTool.new,
      Tools::Topics::CreateTopicToolCallLogTool.new,
      Tools::Topics::UpdateTopicToolCallLogTool.new,
      Tools::Topics::DeleteTopicToolCallLogTool.new,
      Tools::Topics::SearchMessagesOfRoomTool.new,
      Tools::Topics::MessageAnalysisTool.new,
      Tools::Topics::GetMessageAnalysisTool.new,
      Tools::Topics::CreateMessageAnalysisTool.new,
      Tools::Topics::UpdateMessageAnalysisTool.new,
      Tools::Topics::DeleteMessageAnalysisTool.new,
      Tools::Topics::MessageTopicsTool.new,
      Tools::Topics::GetMessageTopicTool.new,
      Tools::Topics::CreateMessageTopicTool.new,
      Tools::Topics::UpdateMessageTopicTool.new,
      Tools::Topics::DeleteMessageTopicTool.new,
      Tools::Topics::RoomHistoryTopicsTool.new,
      Tools::Topics::GetRoomHistoryTopicTool.new,
      Tools::Topics::CreateRoomHistoryTopicTool.new,
      Tools::Topics::UpdateRoomHistoryTopicTool.new,
      Tools::Topics::DeleteRoomHistoryTopicTool.new
    ]
    topic_tools.each do |tool|
      scopes = tool.name.start_with?("create_", "update_", "delete_") ? %i[all action knowledge] : %i[all read action knowledge]
      Registry.register(tool, scopes: scopes)
    end

    # Tasks
    task_tools = [
      Tools::Tasks::TasksTool.new,
      Tools::Tasks::GetTaskTool.new,
      Tools::Tasks::CreateTaskTool.new,
      Tools::Tasks::UpdateTaskTool.new,
      Tools::Tasks::DeleteTaskTool.new,
      Tools::Tasks::GetTaskChildrenTool.new,
      Tools::Tasks::GetTaskParentsTool.new,
      Tools::Tasks::TaskCostTool.new
    ]
    task_tools.each do |tool|
      scopes = tool.name.start_with?("create_", "update_", "delete_", "task_cost") ? %i[all action task] : %i[all read action task]
      Registry.register(tool, scopes: scopes)
    end
  end
end

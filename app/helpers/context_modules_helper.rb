#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

module ContextModulesHelper
  def cache_if_module(context_module, editable, differentiated_assignments, user, context, &block)
    if context_module
      visible_assignments = (differentiated_assignments && user) ? user.assignment_and_quiz_visibilities(context) : []
      cache_key_items = ['context_module_render_12_', context_module.cache_key, editable, true, Time.zone]
      cache_key_items << Digest::MD5.hexdigest(visible_assignments.to_s) if differentiated_assignments
      cache_key = cache_key_items.join('/')
      cache_key = add_menu_tools_to_cache_key(cache_key)
      cache(cache_key, nil, &block)
    else
      yield
    end
  end

  def add_menu_tools_to_cache_key(cache_key)
    tool_key = @menu_tools && @menu_tools.values.flatten.map(&:cache_key).join("/")
    cache_key += Digest::MD5.hexdigest(tool_key) if tool_key.present?
    # should leave it alone if there are no tools
    cache_key
  end

  def preload_can_unpublish(context, modules)
    items = modules.map(&:content_tags).flatten.map(&:content)
    asmnts = items.select{|item| item.is_a?(Assignment)}
    topics = items.select{|item| item.is_a?(DiscussionTopic)}
    quizzes = items.select{|item| item.is_a?(Quizzes::Quiz)}
    wiki_pages = items.select{|item| item.is_a?(WikiPage)}

    assmnt_ids_with_subs = Assignment.assignment_ids_with_submissions(context.assignments.pluck(:id))
    Assignment.preload_can_unpublish(asmnts, assmnt_ids_with_subs)
    DiscussionTopic.preload_can_unpublish(context, topics, assmnt_ids_with_subs)
    Quizzes::Quiz.preload_can_unpublish(quizzes, assmnt_ids_with_subs)
    WikiPage.preload_can_unpublish(context, wiki_pages)
  end

  def module_item_publishable_id(item)
    if item.nil?
      ''
    elsif (item.content_type_class == 'wiki_page')
      "page_id:#{item.content.id}"
    else
      (item.content && item.content.respond_to?(:published?) ? item.content.id : item.id)
    end
  end

  def module_item_publishable?(item)
    true
  end

  def prerequisite_list(prerequisites)
    prerequisites.map {|p| p[:name]}.join(', ')
  end

  def module_item_unpublishable?(item)
    return true if item.nil? || !item.content || !item.content.respond_to?(:can_unpublish?)
    item.content.can_unpublish?
  end

  def module_item_translated_content_type(item)
    return '' unless item

    case item.content_type
    when 'Announcement'
      I18n.t('Announcement')
    when 'Assignment'
      I18n.t('Assignment')
    when 'Attachment'
      I18n.t('Attachment')
    when 'ContextExternalTool'
      I18n.t('External Tool')
    when 'ContextModuleSubHeader'
      I18n.t('Context Module Sub Header')
    when 'DiscussionTopic'
      I18n.t('Discussion Topic')
    when 'ExternalUrl'
      I18n.t('External Url')
    when 'Quiz'
      I18n.t('Quiz')
    when 'Quizzes::Quiz'
      I18n.t('Quiz')
    when 'WikiPage'
      I18n.t('Wiki Page')
    else
      I18n.t('Unknown Content Type')
    end
  end

  def context_module_progression_for_user(context_module)
    context_module &&
    context_module.context_module_progressions.
      where(user_id: @current_user, context_module_id: context_module).first
  end

  def criterion(module_item, completion_criteria)
    completion_criteria && completion_criteria.find{|c| c[:id] == module_item.id}
  end

  def has_requirements?(context_module)
    context_module && context_module.completion_requirements.length > 0
  end

  def min_score_items(context_module, content_tags)
    ids = context_module.completion_requirements.map {|r| r[:id] if r[:type] == 'min_score'}.compact
    content_tags.select {|c| ids.include? c.id}
  end

  def has_submissions?(content_tags)
    content_tags.any? {|c| c.assignment.submissions.length > 0}
  end

  # This method creates a hash that is used to determine which icon is displayed for
  # a module item and which tooltip message is displayed on the icon
  def module_item_data(context_module, context_module_progression, module_item, criterion)
    return false unless context_module && context_module_progression && module_item &&
                        ContextModuleItemIcons.module_item_requirement?(context_module, module_item)
    icon_info = {}
    highest_score = context_module_progression.highest_submission_score(module_item)
    submission_status = ContextModuleItemIcons.submission_status(context_module, module_item, highest_score)
    completion_status = ContextModuleItemIcons.module_item_completed?(context_module_progression, module_item)
    past_due = ContextModuleItemIcons.past_due_date?(module_item)
    initial_message = ContextModuleItemIcons.initial_criterion_message(criterion, submission_status, highest_score)

    icon_info[:icon_type] =
      ContextModuleItemIcons.module_item_progress_icon(context_module, context_module_progression,
                                                      module_item, highest_score)
    icon_info[:criterion_message] =
      ContextModuleItemIcons.complete_criterion_message(initial_message, completion_status, past_due)
    icon_info
  end


end

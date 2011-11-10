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

module Api::V1::Submission
  include Api::V1::Assignment

  def submission_json(submission, assignment, context = nil, includes = [])
    context ||= assignment.context
    hash = submission_attempt_json(submission, assignment, nil, context)

    if includes.include?("submission_history")
      hash['submission_history'] = []
      submission.submission_history.each_with_index do |ver, idx|
        hash['submission_history'] << submission_attempt_json(ver, assignment, idx, context)
      end
    end

    if includes.include?("submission_comments")
      hash['submission_comments'] = submission.submission_comments.map do |sc|
        sc_hash = sc.as_json(
          :include_root => false,
          :only => %w(author_id author_name created_at comment))
        if sc.media_comment?
          sc_hash['media_comment'] = media_comment_json(:media_id => sc.media_comment_id, :media_type => sc.media_comment_type)
        end
        sc_hash['attachments'] = sc.attachments.map do |a|
          attachment_json(a)
        end unless sc.attachments.blank?
        sc_hash
      end
    end

    if includes.include?("rubric_assessment") && submission.rubric_assessment
      ra = submission.rubric_assessment.data
      hash['rubric_assessment'] = {}
      ra.each { |rating| hash['rubric_assessment'][rating[:criterion_id]] = rating.slice(:points, :comments) }
    end

    if includes.include?("assignment")
      hash['assignment'] = assignment_json(assignment)
    end

    hash
  end

  SUBMISSION_JSON_FIELDS = %w(user_id url score grade attempt submission_type submitted_at body assignment_id grade_matches_current_submission).freeze
  SUBMISSION_OTHER_FIELDS = %w(attachments discussion_entries)

  def submission_attempt_json(attempt, assignment, version_idx = nil, context = nil)
    context ||= assignment.context

    json_fields = SUBMISSION_JSON_FIELDS
    if params[:response_fields]
      json_fields = json_fields & params[:response_fields]
    end
    if params[:exclude_response_fields]
      json_fields -= params[:exclude_response_fields]
    end

    other_fields = SUBMISSION_OTHER_FIELDS
    if params[:response_fields]
      other_fields = other_fields & params[:response_fields]
    end
    if params[:exclude_response_fields]
      other_fields -= params[:exclude_response_fields]
    end

    hash = attempt.as_json(
      :include_root => false,
      :only => json_fields)

    hash['preview_url'] = course_assignment_submission_url(
      @context, assignment, attempt[:user_id], 'preview' => '1',
      'version' => version_idx)

    unless attempt.media_comment_id.blank?
      hash['media_comment'] = media_comment_json(:media_id => attempt.media_comment_id, :media_type => attempt.media_comment_type)
    end
    
    if attempt.turnitin_data && attempt.grants_right?(@current_user, :view_turnitin_report)
      turnitin_hash = attempt.turnitin_data.dup
      turnitin_hash.delete(:last_processed_attempt)
      hash['turnitin_data'] = turnitin_hash
    end

    if other_fields.include?('attachments')
      attachments = attempt.versioned_attachments.dup
      attachments << attempt.attachment if attempt.attachment && attempt.attachment.context_type == 'Submission' && attempt.attachment.context_id == attempt.id
      hash['attachments'] = attachments.map do |attachment|
        attachment_json(attachment)
      end.compact unless attachments.blank?
    end

    # include the discussion topic entries
    if other_fields.include?('discussion_entries') &&
           assignment.submission_types =~ /discussion_topic/ &&
           assignment.discussion_topic
      # group assignments will have a child topic for each group.
      # it's also possible the student posted in the main topic, as well as the
      # individual group one. so we search far and wide for all student entries.
      if assignment.has_group_category?
        entries = assignment.discussion_topic.child_topics.map {|t| t.discussion_entries.active.for_user(attempt.user_id) }.flatten.sort_by{|e| e.created_at}
      else
        entries = assignment.discussion_topic.discussion_entries.active.for_user(attempt.user_id)
      end
      hash['discussion_entries'] = entries.map do |entry|
        ehash = entry.as_json(
          :include_root => false,
          :only => %w(message user_id created_at updated_at)
        )
        attachments = (entry.attachments.dup + [entry.attachment]).compact
        ehash['attachments'] = attachments.map do |attachment|
          attachment_json(attachment)
        end.compact unless attachments.blank?
        ehash
      end
    end

    hash
  end
end


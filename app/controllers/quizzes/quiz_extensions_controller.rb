#
# Copyright (C) 2011 - 2014 Instructure, Inc.
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
# @API Quiz Extensions
# @beta
#
# @model QuizExtensions
#     {
#       "id": "QuizExtension",
#       "required": ["quiz_id", "user_id"],
#       "properties": {
#         "quiz_id": {
#           "description": "The ID of the Quiz the quiz extension belongs to.",
#           "example": 2,
#           "type": "integer",
#           "format": "int64"
#         },
#         "user_id": {
#           "description": "The ID of the Student that needs the quiz extension.",
#           "example": 3,
#           "type": "integer",
#           "format": "int64"
#         },
#         "extra_attempts": {
#           "description": "Number of times the student was allowed to re-take the quiz over the multiple-attempt limit.",
#           "example": 1,
#           "type": "integer",
#           "format": "int64"
#         },
#         "extra_time": {
#           "description": "Amount of extra time allowed for the quiz submission, in minutes.",
#           "example": 60,
#           "type": "integer",
#           "format": "int64"
#         },
#         "manually_unlocked": {
#           "description": "The student can take the quiz even if it's locked for everyone else",
#           "example": true,
#           "type": "boolean"
#         },
#         "extend_from_now": {
#           "description": "The number of extra minutes from now to extend the quiz",
#           "example": 60,
#           "type": "integer",
#           "format": "int64"
#         },
#         "extend_from_end_at": {
#           "description": "The number of extra minutes from the quiz's current end time to extend the quiz",
#           "example": 60,
#           "type": "integer",
#           "format": "int64"
#         }
#       }
#     }
class Quizzes::QuizExtensionsController < ApplicationController
  include Filters::Quizzes

  before_filter :require_user, :require_context, :require_quiz

  # @API Update student question scores and comments or add extensions
  # @beta
  #
  # @argument user_id [Optional, Integer]
  #   The ID of the user we want to add quiz extensions for.
  #
  # @argument extra_attempts [Optional, Integer]
  #   The number of extra attempts to allow for the submission. This will
  #   add to the existing number of allowed attempts. This is limited to
  #   1000 attempts or less.
  #
  # @argument extra_time [Optional, Integer]
  #   The number of extra minutes to allow for all attempts. This will
  #   add to the existing time limit on the submission. This is limited to
  #   10080 minutes (1 week)
  #
  # @argument manually_unlocked [Optional, Boolean]
  #   Allow the student to take the quiz even if it's locked for
  #   everyone else.
  #
  # @argument extend_from_now [Optional, Integer]
  #   The number of minutes to extend the quiz from the current time. This is
  #   mutually exclusive to extend_from_end_at. This is limited to 10080
  #   minutes (1 week)
  #
  # @argument extend_from_end_at [Optional, Integer]
  #   The number of minutes to extend the quiz beyond the quiz's current
  #   ending time. This is mutually exclusive to extend_from_now. This is
  #   limited to 10080 minutes (1 week)
  #
  # <b>Responses</b>
  #
  # * <b>200 OK</b> if the request was successful
  # * <b>403 Forbidden</b> if you are not allowed to extend quizzes for this course
  #
  # @example_request
  #  {
  #    "quiz_extensions": [{
  #      "user_id": 3,
  #      "extra_atempts": 2,
  #      "extra_time": 20,
  #      "manually_unlocked": true
  #    },{
  #      "user_id": 2,
  #      "extra_atempts": 2,
  #      "extra_time": 20,
  #      "manually_unlocked": false
  #    }]
  #  }
  #
  # @example_request
  #  {
  #    "quiz_extensions": [{
  #      "user_id": 3,
  #      "extend_from_now": 20
  #    }]
  #  }
  #
  # @example_response
  #  {
  #    "quiz_submissions": [QuizSubmission]
  #  }
  #
  def create
    unless params[:quiz_extensions].is_a?(Array)
      reject! 'missing required key :quiz_extensions'
    end

    # check permissions on all extensions before performing on submissions
    quiz_extensions = Quizzes::QuizExtension.build_extensions(
       students, submission_manager, params[:quiz_extensions]) do |extension|

      unless extension.quiz_submission.grants_right?(participant.user, :add_attempts)
        reject! 'you are not allowed to change extension settings for this submission', 403
      end
    end

    # after we've validated permissions on all extend all submissions
    quiz_extensions.each(&:extend_submission!)

    render json: serialize_jsonapi(quiz_extensions)
  end


  private

  def serialize_jsonapi(quiz_extensions)
    serialized_set = Canvas::APIArraySerializer.new(quiz_extensions, {
      each_serializer: Quizzes::QuizExtensionSerializer,
      controller: self,
      scope: @current_user,
      root: false,
      include_root: false
    }).as_json

    { quiz_extensions: serialized_set }
  end

  def participant
    Quizzes::QuizParticipant.new(@current_user, temporary_user_code)
  end

  def students
    @context.students
  end

  def submission_manager
    Quizzes::SubmissionManager.new(@quiz)
  end
end

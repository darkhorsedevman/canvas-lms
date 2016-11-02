#
# Copyright (C) 2011 - 2016 Instructure, Inc.
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

require_relative '../api_spec_helper'

describe 'Originality Reports API', type: :request do
  before :each do
    attachment_model

    course(active_all: true)
    student_in_course active_all: true
    teacher_in_course active_all: true

    @tool = @course.context_external_tools.create(name: "a",
                                                   domain: "google.com",
                                                   consumer_key: '12345',
                                                   shared_secret: 'secret')
    @tool.settings[:assignment_configuration] = {:url => "http://www.example.com", :icon_url => "http://www.example.com", :selection_width => 100, :selection_height => 100}.with_indifferent_access
    @tool.save!
    @assignment = @course.assignments.create!(title: "some assignment",
                                              assignment_group: @group,
                                              points_possible: 12,
                                              tool_settings_tools:[@tool])
    @attachment.context = @student
    @attachment.save!

    @submission = @assignment.submit_homework(@student, attachments: [@attachment])

    @endpoints = {
      create: "/api/v1/assignments/#{@assignment.id}/submissions/#{@submission.id}/originality_report"
    }

    Account.any_instance.stubs(:feature_enabled?).with(:plagiarism_detection_platform).returns(true)
  end

  describe "POST assignments/:assignment_id/submissions/:submission_id/originality_report (#create)" do
    it "creates an originality report when provided required params" do
      user_session(@teacher)
      score = 0.25
      api_create_originality_report(@attachment.id, score)

      expect(assigns[:report].attachment).to eq @attachment
      expect(assigns[:report].originality_score).to eq score
    end

    it "includes expected keys in JSON response" do
      user_session(@teacher)
      expected_keys = [
        'id',
        'file_id',
        'originality_score',
        'originality_report_file_id',
        'originality_report_url',
        'originality_report_lti_url',
        'created_at',
        'updated_at',
        'submission_id'
      ].freeze

      post @endpoints[:create], originality_report: {file_id: @attachment.id, originality_score: 0.4}
      expect(response).to be_success
      expect(JSON.parse(response.body).keys).to match_array(expected_keys)
    end

    it "checks for required params" do
      user_session(@teacher)

      post @endpoints[:create]
      expect(response.status).to eq 400

      post @endpoints[:create], originality_report: {}
      expect(response.status).to eq 400

      post @endpoints[:create], originality_report: {originality_score: 0.5}
      expect(response.status).to eq 404
    end

    it "checks that the specified assignment exists" do
      user_session(@teacher)
      invalid_attach_url = "/api/v1/assignments/#{@assignment.id + 1}/submissions/#{@submission.id}/originality_report"
      post invalid_attach_url, originality_report: {file_id: @attachment.id, originality_score: 0.4}
      expect(response).not_to be_success
    end

    it "checks that the specified file exists" do
      user_session(@teacher)
      post @endpoints[:create], originality_report: {file_id: @attachment.id + 1, originality_score: 0.4}
      expect(response).not_to be_success
    end

    it "requires manage_grades permission" do
      user_session(@student)
      post @endpoints[:create], originality_report: {file_id: @attachment.id, originality_score: 0.4}
      expect(response).not_to be_success
      expect(response.status).to eq 401

      user_session(@teacher)
      post @endpoints[:create], originality_report: {file_id: @attachment.id, originality_score: 0.4}
      expect(response).to be_success
    end

    it "gives useful error message on non unique tool/file combinations" do
      user_session(@teacher)
      post @endpoints[:create], originality_report: {file_id: @attachment.id, originality_score: 0.4}
      expect(response.status).to eq 201

      post @endpoints[:create], originality_report: {file_id: @attachment.id, originality_score: 0.4}
      expect(response.status).to eq 400
      expect(JSON.parse(response.body)['errors'].key?('base')).to be_truthy
    end

    it "requires the plagiarism feature flag" do
      Account.any_instance.stubs(:feature_enabled?).with(:plagiarism_detection_platform).returns(false)
      user_session(@teacher)
      post @endpoints[:create], originality_report: {file_id: @attachment.id, originality_score: 0.4}
      expect(response).not_to be_success
    end

    it "verifies the specified attachment is in the course" do
      user_session(@teacher)
      attachment = @attachment.dup
      attachment.context = @course
      attachment.save!

      post @endpoints[:create], originality_report: {file_id: attachment.id, originality_score: 0.4}
      expect(response.status).to eq 401
    end

    it "verifies that the specified submission includes the attachment" do
      user_session(@teacher)
      sub = @submission.dup
      sub.attachments = []
      sub.user = @teacher
      sub.save!
      endpoint = "/api/v1/assignments/#{@assignment.id}/submissions/#{sub.id}/originality_report"
      post endpoint, originality_report: {file_id: @attachment.id, originality_score: 0.4}
      expect(response.status).to eq 401
    end

    context "optional params" do
      before :each do
        user_session(@teacher)
        report_file = @attachment.dup
        report_file.save!

        @report = {
          file_id: @attachment.id,
          originality_score: 0.5,
          originality_report_file_id: report_file.id,
          originality_report_url: 'http://www.report-url.com',
          originality_report_lti_url: 'http://www.report-lti-url.com'
        }

        post @endpoints[:create], originality_report: @report
        @response_hash = JSON.parse response.body
      end

      it "sets the attachment" do
        expect(response).to be_success
        created_report = OriginalityReport.find(@response_hash['id'])
        expect(created_report.attachment).to eq @attachment
      end
    end

    def api_create_originality_report(file_id, score)
      api_call(
        :post,
        "/api/v1/assignments/#{@assignment.id}/submissions/#{@submission.id}/originality_report",
        {
          controller: 'originality_reports_api',
          action: 'create',
          format: 'json',
          assignment_id: @assignment.id,
          submission_id: @submission.id
        },
        {
          originality_report: {
            originality_score: score,
            file_id: file_id
          }
        }
      )
    end
  end
end

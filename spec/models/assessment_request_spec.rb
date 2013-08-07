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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe AssessmentRequest do
  describe "workflow" do
    let(:request) { user; AssessmentRequest.create!(user: @user, asset: @user, assessor_asset: @user, assessor: @user) }

    it "defaults to assigned" do
      request.should be_assigned
    end

    it "can be completed" do
      request.complete!
      request.should be_completed
    end
  end

  describe "notifications" do
    let(:notification_name) { 'Rubric Assessment Submission Reminder' }
    let(:notification)      { Notification.create!(:name => notification_name, :category => 'Invitation') }

    it "should send submission reminders" do
      course_with_student(:active_all => true)
      @student.communication_channels.create!(:path => 'test@example.com').confirm!
      NotificationPolicy.create!(:notification => notification,
        :communication_channel => @user.communication_channel, :frequency => 'immediately')

      request = AssessmentRequest.new(:user => @user, :asset => @student, :assessor_asset => @student, :assessor => @user)
      request.send_reminder!

      request.messages_sent.keys.should include(notification_name)
    end
  end
end

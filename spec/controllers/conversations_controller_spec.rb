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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ConversationsController do
  def conversation(num_other_users = 1, course = @course)
    user_ids = num_other_users.times.map{
      u = User.create
      enrollment = course.enroll_student(u)
      enrollment.workflow_state = 'active'
      enrollment.save
      u.associated_accounts << Account.default
      u.id
    }
    @conversation = @user.initiate_conversation(user_ids)
    @conversation.add_message('test')
    @conversation
  end

  describe "GET 'index'" do
    it "should require login" do
      course_with_student(:active_all => true)
      get 'index'
      assert_require_login
    end

    it "should assign variables" do
      course_with_student_logged_in(:active_all => true)
      conversation

      term = EnrollmentTerm.create! :name => "Fall"
      term.root_account_id = @course.root_account_id
      term.save!
      @course.update_attributes! :enrollment_term => term

      get 'index'
      response.should be_success
      assigns[:conversations_json].map{|c|c[:id]}.should == @user.conversations.map(&:conversation_id)
      assigns[:contexts][:courses].to_a.map{|p|p[1]}.
        reduce(true){|truth, con| truth and con.has_key?(:url)}.should be_true
      assigns[:contexts][:courses][@course.id][:term].should == "Fall"
      assigns[:filterable].should be_true
    end

    it "should work for an admin as well" do
      course
      account_admin_user
      user_session(@user)
      conversation

      get 'index'
      response.should be_success
      assigns[:conversations_json].map{|c|c[:id]}.should == @user.conversations.map(&:conversation_id)
    end

    it "should return conversations matching the specified filter" do
      course_with_student_logged_in(:active_all => true)
      @c1 = conversation
      @other_course = course(:active_all => true)
      enrollment = @other_course.enroll_student(@user)
      enrollment.workflow_state = 'active'
      enrollment.save!
      @user.reload
      @c2 = conversation(1, @other_course)

      get 'index', :filter => @other_course.asset_string
      response.should be_success
      assigns[:conversations_json].size.should eql 1
      assigns[:conversations_json][0][:id].should == @c2.conversation_id
    end

    it "should hide the filter UI if some conversations have not been tagged yet" do
      course_with_student_logged_in(:active_all => true)
      conversation
      Conversation.update_all "tags = NULL"
      ConversationParticipant.update_all "tags = NULL"
      ConversationMessageParticipant.update_all "tags = NULL"

      # create some more that are tagged
      conversation
      conversation

      get 'index'
      response.should be_success
      assigns[:filterable].should be_false
    end
  end

  describe "GET 'show'" do
    it "should redirect if not xhr" do
      course_with_student_logged_in(:active_all => true)
      conversation

      get 'show', :id => @conversation.conversation_id
      response.should be_redirect
    end

    it "should assign variables" do
      course_with_student_logged_in(:active_all => true)
      conversation

      xhr :get, 'show', :id => @conversation.conversation_id
      response.should be_success
      assigns[:conversation].should == @conversation
    end
  end

  describe "POST 'create'" do
    it "should create the conversation" do
      course_with_student_logged_in(:active_all => true)

      new_user = User.create
      enrollment = @course.enroll_student(new_user)
      enrollment.workflow_state = 'active'
      enrollment.save
      post 'create', :recipients => [new_user.id.to_s], :body => "yo"
      response.should be_success
      assigns[:conversation].should_not be_nil
    end

    it "should allow messages to be forwarded from the conversation" do
      course_with_student_logged_in(:active_all => true)
      conversation.update_attribute(:workflow_state, "unread")

      new_user = User.create
      enrollment = @course.enroll_student(new_user)
      enrollment.workflow_state = 'active'
      enrollment.save
      post 'create', :recipients => [new_user.id.to_s], :body => "here's the info", :forwarded_message_ids => @conversation.messages.map(&:id)
      response.should be_success
      assigns[:conversation].should_not be_nil
      assigns[:conversation].messages.first.forwarded_message_ids.should eql(@conversation.messages.first.id.to_s)
    end

    it "should create one conversation shared by all recipients" do
      old_count = Conversation.count

      course_with_teacher_logged_in(:active_all => true)

      new_user1 = User.create
      enrollment1 = @course.enroll_student(new_user1)
      enrollment1.workflow_state = 'active'
      enrollment1.save

      new_user2 = User.create
      enrollment2 = @course.enroll_student(new_user2)
      enrollment2.workflow_state = 'active'
      enrollment2.save

      post 'create', :recipients => [new_user1.id.to_s, new_user2.id.to_s], :body => "yo", :group_conversation => true
      response.should be_success

      Conversation.count.should eql(old_count + 1)
    end

    it "should create one conversation per recipient if not a group conversation" do
      old_count = Conversation.count

      course_with_teacher_logged_in(:active_all => true)

      new_user1 = User.create
      enrollment1 = @course.enroll_student(new_user1)
      enrollment1.workflow_state = 'active'
      enrollment1.save

      new_user2 = User.create
      enrollment2 = @course.enroll_student(new_user2)
      enrollment2.workflow_state = 'active'
      enrollment2.save

      post 'create', :recipients => [new_user1.id.to_s, new_user2.id.to_s], :body => "yo"
      response.should be_success

      Conversation.count.should eql(old_count + 2)
    end

    it "should correctly infer context tags" do
      course_with_teacher_logged_in(:active_all => true)
      @course1 = @course
      @group1 = @course1.groups.create!
      @group2 = @course1.groups.create!
      @group1.users << @user
      @group2.users << @user

      new_user1 = User.create
      enrollment1 = @course1.enroll_student(new_user1)
      enrollment1.workflow_state = 'active'
      enrollment1.save
      @group1.users << new_user1
      @group2.users << new_user1

      new_user2 = User.create
      enrollment2 = @course1.enroll_student(new_user2)
      enrollment2.workflow_state = 'active'
      enrollment2.save
      @group1.users << new_user2
      @group2.users << new_user2

      @course2 = course(:active_all => true)
      enrollment3 = @course2.enroll_student(@user)
      enrollment2.workflow_state = 'active'
      enrollment2.save

      post 'create', :recipients => [@course2.asset_string + "_students", @group1.asset_string], :body => "yo", :group_conversation => true
      response.should be_success

      c = Conversation.first
      c.tags.sort.should eql [@course1.asset_string, @course2.asset_string, @group1.asset_string].sort
      # course1 inferred from group1, course2 inferred from synthetic context,
      # group1 explicit, group2 not present (even though it's shared by everyone)
    end
  end

  describe "POST 'update'" do
    it "should update the conversation" do
      course_with_student_logged_in(:active_all => true)
      conversation(2).update_attribute(:workflow_state, "unread")

      post 'update', :id => @conversation.conversation_id, :conversation => {:subscribed => "0", :workflow_state => "archived", :starred => "1"}
      response.should be_success
      @conversation.reload
      @conversation.subscribed?.should be_false
      @conversation.should be_archived
      @conversation.starred.should be_true
    end
  end

  describe "POST 'add_message'" do
    it "should add a message" do
      course_with_student_logged_in(:active_all => true)
      conversation

      post 'add_message', :conversation_id => @conversation.conversation_id, :body => "hello world"
      response.should be_success
      @conversation.messages.size.should == 2
    end

    it "should generate a user note when requested" do
      Account.default.update_attribute :enable_user_notes, true
      course_with_teacher_logged_in(:active_all => true)
      @teacher.associated_accounts << Account.default
      conversation

      post 'add_message', :conversation_id => @conversation.conversation_id, :body => "hello world"
      response.should be_success
      message = @conversation.messages.first # newest message is first
      student = message.recipients.first
      student.user_notes.size.should == 0

      post 'add_message', :conversation_id => @conversation.conversation_id, :body => "make a note", :user_note => 1
      response.should be_success
      message = @conversation.messages.first
      student = message.recipients.first
      student.user_notes.size.should == 1
    end
  end

  describe "POST 'add_recipients'" do
    it "should add recipients" do
      course_with_student_logged_in(:active_all => true)
      conversation(2)

      new_user = User.create
      enrollment = @course.enroll_student(new_user)
      enrollment.workflow_state = 'active'
      enrollment.save
      post 'add_recipients', :conversation_id => @conversation.conversation_id, :recipients => [new_user.id.to_s]
      response.should be_success
      @conversation.reload.participants.size.should == 4 # includes @user
    end

    it "should correctly infer context tags" do
      course_with_student_logged_in(:active_all => true)
      conversation(2)

      @group = @course.groups.create!
      @conversation.participants.each{ |user| @group.users << user }
      2.times{ @group.users << User.create }

      post 'add_recipients', :conversation_id => @conversation.conversation_id, :recipients => [@group.asset_string]
      response.should be_success

      c = Conversation.first
      c.tags.sort.should eql [@course.asset_string, @group.asset_string]
      # course inferred (when created), group explicit
    end
  end

  describe "POST 'remove_messages'" do
    it "should remove messages" do
      course_with_student_logged_in(:active_all => true)
      message = conversation.add_message('another')

      post 'remove_messages', :conversation_id => @conversation.conversation_id, :remove => [message.id.to_s]
      response.should be_success
      @conversation.messages.size.should == 1
    end
  end

  describe "DELETE 'destroy'" do
    it "should delete conversations" do
      course_with_student_logged_in(:active_all => true)
      conversation

      delete 'destroy', :id => @conversation.conversation_id
      response.should be_success
      @user.conversations.should be_blank # the conversation_participant is no longer there
      @conversation.conversation.should_not be_nil # though the conversation is
    end
  end

  describe "GET 'find_recipients'" do
    it "should assign variables" do
      course_with_student_logged_in(:active_all => true)
      @course.update_attribute(:name, "this_is_a_test_course")

      other = User.create(:name => 'this_is_a_test_user')
      enrollment = @course.enroll_student(other)
      enrollment.workflow_state = 'active'
      enrollment.save

      group = @course.groups.create(:name => 'this_is_a_test_group')
      group.users = [@user, other]

      get 'find_recipients', :search => 'this_is_a_test_'
      response.should be_success
      response.body.should include(@course.name)
      response.body.should include(group.name)
      response.body.should include(other.name)
    end
  end
end

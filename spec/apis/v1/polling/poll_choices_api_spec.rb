#
# Copyright (C) 2014 Instructure, Inc.
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

require File.expand_path(File.dirname(__FILE__) + '/../../api_spec_helper')

describe Polling::PollChoicesController, type: :request do
  before :each do
    course_with_teacher_logged_in active_all: true
  end

  describe 'GET index' do
    before(:each) do
      @poll = @teacher.polls.create!(question: "Example Poll")
      5.times do |n|
        @poll.poll_choices.create!(text: "Poll Choice #{n+1}", is_correct: false)
      end
    end

    def get_index(raw = false, data = {})
      helper = method(raw ? :raw_api_call : :api_call)
      helper.call(:get,
                  "/api/v1/polls/#{@poll.id}/poll_choices",
                  { controller: 'polling/poll_choices', action: 'index', format: 'json',
                    poll_id: @poll.id.to_s
                  }, data)
    end

    it "returns all existing poll choices" do
      json = get_index
      json.size.should == 5

      json.each_with_index do |pc, i|
        pc['text'].should == "Poll Choice #{5-i}"
      end
    end

    context "as a student" do
      before(:each) do
        student_in_course(:active_all => true, :course => @course)
      end

      it "is unauthorized if there are no open sessions" do
        get_index(true)
        response.code.should == '401'
      end

      it "doesn't display is_correct within the poll choices" do
        session = Polling::PollSession.create!(course: @course, poll: @poll)
        session.publish!

        json = get_index
        json.each do |poll_choice|
          poll_choice.should_not have_key('is_correct')
        end
      end
    end
  end

  describe 'GET show' do
    before(:each) do
      @poll = @teacher.polls.create!(question: 'An Example Poll')
      @poll_choice = @poll.poll_choices.create!(text: 'A Poll Choice', is_correct: true)
    end

    def get_show(raw = false, data = {})
      helper = method(raw ? :raw_api_call : :api_call)
      helper.call(:get,
                  "/api/v1/polls/#{@poll.id}/poll_choices/#{@poll_choice.id}",
                  { controller: 'polling/poll_choices', action: 'show', format: 'json',
                    poll_id: @poll.id.to_s,
                    id: @poll_choice.id.to_s
                  }, data)
    end

    it "retrieves the poll specified" do
      json = get_show
      json['text'].should == 'A Poll Choice'
      json['is_correct'].should be_true
    end

    context "as a student" do
      before(:each) do
        student_in_course(:active_all => true, :course => @course)
      end

      it "is unauthorized if there are no open sessions" do
        get_show(true)
        response.code.should == '401'
      end

      it "doesn't display is_correct within poll choices" do
        session = Polling::PollSession.create!(course: @course, poll: @poll)
        session.publish!

        json = get_show
        json.should_not have_key('is_correct')
      end
    end
  end

  describe 'POST create' do
    before(:each) do
      @poll = @teacher.polls.create!(question: 'An Example Poll')
    end

    def post_create(params, raw=false)
      helper = method(raw ? :raw_api_call : :api_call)
      helper.call(:post,
                  "/api/v1/polls/#{@poll.id}/poll_choices",
                  { controller: 'polling/poll_choices', action: 'create', format: 'json',
                    poll_id: @poll.id.to_s
                  },
                  { poll_choice: params }, {}, {})
    end

    context "as a teacher" do
      it "creates a poll choice successfully" do
        post_create(text: 'Poll Choice 1', is_correct: false)
        @poll.poll_choices.first.text.should == 'Poll Choice 1'
      end

      it "sets is_correct to false if is_correct is provided but blank" do
        post_create(text: 'is correct poll choice', is_correct: '')
        @poll.poll_choices.first.text.should == 'is correct poll choice'
        @poll.poll_choices.first.is_correct.should be_false
      end
    end

    context "as a student" do
      it "is unauthorized" do
        student_in_course(:active_all => true, :course => @course)
        post_create({text: 'Poll Choice 1'}, true)
        response.code.should == '401'
      end
    end
  end

  describe 'PUT update' do
    before :each do
      @poll = @teacher.polls.create!(question: 'An Old Title')
      @poll_choice = @poll.poll_choices.create!(text: 'Old Poll Choice', is_correct: true)
    end

    def put_update(params, raw=false)
      helper = method(raw ? :raw_api_call : :api_call)

      helper.call(:put,
               "/api/v1/polls/#{@poll.id}/poll_choices/#{@poll_choice.id}",
               { controller: 'polling/poll_choices', action: 'update', format: 'json',
                 poll_id: @poll.id.to_s,
                 id: @poll_choice.id.to_s
               },
               { poll_choice: params }, {}, {})

    end

    context "as a teacher" do
      it "updates a poll choice successfully" do
        put_update(text: 'New Poll Choice Text')
        @poll_choice.reload.text.should == 'New Poll Choice Text'
      end

      it "sets is_correct to the poll choice's original value if is_correct is provided but blank" do
        original = @poll_choice.is_correct

        put_update(is_correct: '')
        @poll_choice.reload
        @poll_choice.is_correct.should == original
      end
    end

    context "as a student" do
      it "is unauthorized" do
        student_in_course(:active_all => true, :course => @course)
        put_update({text: 'New Text'}, true)
        response.code.should == '401'
      end
    end
  end

  describe 'DELETE destroy' do
    before :each do
      @poll = @teacher.polls.create!(question: 'A Poll Title')
      @poll_choice = @poll.poll_choices.create!(text: 'Poll Choice', is_correct: true)
    end

    def delete_destroy
      raw_api_call(:delete,
                  "/api/v1/polls/#{@poll.id}/poll_choices/#{@poll_choice.id}",
      { controller: 'polling/poll_choices', action: 'destroy', format: 'json',
        poll_id: @poll.id.to_s,
        id: @poll_choice.id.to_s
      },
      {}, {}, {})

    end

    context "as a teacher" do
      it "deletes a poll choice successfully" do
        delete_destroy

        response.code.should == '204'
        Polling::PollChoice.find_by_id(@poll_choice.id).should be_nil
      end
    end

    context "as a student" do
      it "is unauthorized" do
        student_in_course(:active_all => true, :course => @course)
        delete_destroy

        response.code.should == '401'
        Polling::PollChoice.find_by_id(@poll_choice.id).should == @poll_choice
      end
    end
  end

end

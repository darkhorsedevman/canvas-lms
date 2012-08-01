require File.expand_path(File.dirname(__FILE__) + '/helpers/discussion_announcement_specs')

describe "discussions" do
  it_should_behave_like "discussions selenium tests"
  context "as a teacher" do
    DISCUSSION_NAME = 'new discussion'

    before (:each) do
      course_with_teacher_logged_in
    end

    describe "shared bulk topics specs" do
      let(:url) { "/courses/#{@course.id}/discussion_topics" }
      let(:what_to_create) { DiscussionTopic }
      it_should_behave_like "discussion and announcement main page tests"
    end

    context "individual topic" do
      it "should display the current username when adding a reply" do
        create_and_go_to_topic
        get_all_replies.count.should == 0
        add_reply
        get_all_replies.count.should == 1
        @last_entry.find_element(:css, '.author').text.should == @user.name
      end

      it "should allow student view student to read/post" do
        enter_student_view
        create_and_go_to_topic
        get_all_replies.count.should == 0
        add_reply
        get_all_replies.count.should == 1
      end

      # note: this isn't desirable, but it's the way it is for this release
      it "should show student view posts to teacher and other students" do
        @fake_student = @course.student_view_student
        @topic = @course.discussion_topics.create!
        @entry = @topic.reply_from(:user => @fake_student, :text => 'i am a figment of your imagination')
        @topic.create_materialized_view

        get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
        wait_for_ajax_requests
        get_all_replies.first.should include_text @fake_student.name
      end

      it "should validate closing the discussion for comments" do
        create_and_go_to_topic
        expect_new_page_load { f('.discussion_locked_toggler').click }
        f('.discussion-fyi').text.should == 'This topic is closed for comments'
        ff('.discussion-reply-label').should be_empty
        DiscussionTopic.last.workflow_state.should == 'locked'
      end

      it "should validate reopening the discussion for comments" do
        create_and_go_to_topic('closed discussion', 'side_comment', true)
        expect_new_page_load { f('.discussion_locked_toggler').click }
        ff('.discussion-reply-label').should_not be_empty
        DiscussionTopic.last.workflow_state.should == 'active'
      end

      it "should escape correctly when posting an attachment" do
        create_and_go_to_topic
        message = "message that needs escaping ' \" & !@#^&*()$%{}[];: blah"
        add_reply(message, 'graded.png')
        @last_entry.find_element(:css, '.message').text.should == message
      end
    end

    context "main page" do
      describe "shared main page topics specs" do
        let(:url) { "/courses/#{@course.id}/discussion_topics/" }
        let(:what_to_create) { DiscussionTopic }
        it_should_behave_like "discussion and announcement individual tests"
      end

      it "should filter by assignments" do
        assignment_name = 'topic assignment'
        title = 'assignment topic title'
        @course.discussion_topics.create!(:title => title, :user => @user, :assignment => @course.assignments.create!(:name => assignment_name))
        get "/courses/#{@course.id}/discussion_topics"
        f('#onlyGraded').click
        ff('.discussionTopicIndexList .discussion-topic').count.should == 1
        f('.discussionTopicIndexList .discussion-topic').should include_text(title)
      end

      it "should filter by unread and assignments" do
        assignment_name = 'topic assignment'
        title = 'assignment topic title'
        expected_topic = @course.discussion_topics.create!(:title => title, :user => @user, :assignment => @course.assignments.create!(:name => assignment_name))
        @course.discussion_topics.create!(:title => title, :user => @user)
        expected_topic.change_read_state('unread', @user)
        get "/courses/#{@course.id}/discussion_topics"
        f('#onlyGraded').click
        f('#onlyUnread').click
        ff('.discussionTopicIndexList .discussion-topic').count.should == 1
        f('.discussionTopicIndexList .discussion-topic').should include_text(title)
      end

      it "should validate the discussion reply counter" do
        @topic = create_discussion('new topic', 'side_comment')
        get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
        add_reply('new reply')

        get "/courses/#{@course.id}/discussion_topics"
        f('.total-items').text.should == '1'
      end

      it "should create a podcast enabled topic" do
        get "/courses/#{@course.id}/discussion_topics"
        wait_for_ajaximations

        expect_new_page_load { f('.btn-primary').click }
        replace_content(f('input[name=title]'), "This is my test title")
        type_in_tiny('textarea[name=message]', 'This is the discussion description.')

        f('input[name=podcast_enabled]').click
        expect_new_page_load { submit_form('.form-actions') }
        get "/courses/#{@course.id}/discussion_topics"
        f('.discussion-topic .icon-rss').should be_displayed
        DiscussionTopic.last.podcast_enabled.should be_true
      end
    end
  end

  context "as a student" do
    before (:each) do
      course_with_teacher(:name => 'teacher@example.com')
      @course.offer!
      @student = user_with_pseudonym(:active_user => true, :username => 'student@example.com', :name => 'student@example.com', :password => 'asdfasdf')
      @course.enroll_student(@student).accept
      @topic = @course.discussion_topics.create!(:user => @teacher, :message => 'new topic from teacher', :discussion_type => 'side_comment')
      @entry = @topic.discussion_entries.create!(:user => @teacher, :message => 'new entry from teacher')
      user_session(@student)
    end

    it "should validate a group assignment discussion" do
      group_assignment = assignment_model({
                                              :course => @course,
                                              :name => 'group assignment',
                                              :due_at => (Time.now + 1.week),
                                              :points_possible => 5,
                                              :submission_types => 'online_text_entry',
                                              :assignment_group => @course.assignment_groups.create!(:name => 'new assignment groups'),
                                              :group_category => GroupCategory.create!(:name => "groups", :context => @course),
                                              :grade_group_students_individually => true
                                          })
      topic = @course.discussion_topics.build(:assignment => group_assignment, :title => "some topic", :message => "a little bit of content")
      topic.save!
      get "/courses/#{@course.id}/discussion_topics/#{topic.id}"
      f('.entry_content').should include_text('Since this is a group assignment')
    end

    it "should create a discussion and validate that a student can see it and reply to it" do
      new_student_entry_text = 'new student entry'
      get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
      wait_for_ajax_requests
      f('.message_wrapper').should include_text('new topic from teacher')
      f('#content').should_not include_text(new_student_entry_text)
      add_reply new_student_entry_text
      f('#content').should include_text(new_student_entry_text)
    end

    it "should let students post to a post-first discussion" do
      new_student_entry_text = 'new student entry'
      @topic.require_initial_post = true
      @topic.save
      get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
      wait_for_ajax_requests
      # shouldn't see the existing entry until after posting
      f('#content').should_not include_text("new entry from teacher")
      add_reply new_student_entry_text
      # now they should see the existing entry, and their entry
      entries = get_all_replies
      entries.length.should == 2
      entries[0].should include_text("new entry from teacher")
      entries[1].should include_text(new_student_entry_text)
    end

    it "should still show entries without users" do
      @topic.discussion_entries.create!(:user => nil, :message => 'new entry from nobody')
      get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
      wait_for_ajax_requests
      f('#content').should include_text('new entry from nobody')
    end

    it "should reply as a student and validate teacher can see reply" do
      pending "figure out delayed jobs"
      entry = @topic.discussion_entries.create!(:user => @student, :message => 'new entry from student')
      get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
      fj("[data-id=#{entry.id}]").should include_text('new entry from student')
    end

    it "should embed user content in an iframe" do
      message = %{<p><object width="425" height="350" data="http://www.example.com/swf/software/flash/about/flash_animation.swf" type="application/x-shockwave-flash</object></p>"}
      @topic.discussion_entries.create!(:user => nil, :message => message)
      get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
      wait_for_ajax_requests
      f('#content object').should_not be_present
      iframe = f('#content iframe.user_content_iframe')
      iframe.should be_present
      # the sizing isn't exact due to browser differences
      iframe.size.width.should be_between(405, 445)
      iframe.size.height.should be_between(330, 370)
      form = f('form.user_content_post_form')
      form.should be_present
      form['target'].should == iframe['name']
      in_frame(iframe) do
        keep_trying_until do
          src = driver.page_source
          doc = Nokogiri::HTML::DocumentFragment.parse(src)
          obj = doc.at_css('body object')
          obj.name.should == 'object'
          obj['data'].should == "http://www.example.com/swf/software/flash/about/flash_animation.swf"
        end
      end
    end

    it "should strip embed tags inside user content object tags" do
      # this avoids the js translation of user content trying to embed the same content twice
      message = %{<object width="560" height="315"><param name="movie" value="http://www.youtube.com/v/VHRKdpR1E6Q?version=3&amp;hl=en_US"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/VHRKdpR1E6Q?version=3&amp;hl=en_US" type="application/x-shockwave-flash" width="560" height="315" allowscriptaccess="always" allowfullscreen="true"></embed></object>}
      @topic.discussion_entries.create!(:user => nil, :message => message)
      get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
      wait_for_ajax_requests
      f('#content object').should_not be_present
      f('#content embed').should_not be_present
      iframe = f('#content iframe.user_content_iframe')
      iframe.should be_present
      forms = ff('form.user_content_post_form')
      forms.size.should == 1
      form = forms.first
      form['target'].should == iframe['name']
    end

    context "side comments" do

      it "should add a side comment" do
        side_comment_text = 'new side comment'
        get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
        wait_for_ajax_requests

        f('.add-side-comment-wrap .discussion-reply-label').click
        type_in_tiny '.reply-textarea', side_comment_text
        submit_form('.add-side-comment-wrap')
        wait_for_ajax_requests
        last_entry = DiscussionEntry.last
        validate_entry_text(last_entry, side_comment_text)
        last_entry.depth.should == 2
      end

      it "should create multiple side comments" do
        side_comment_number = 10
        side_comment_number.times { |i| @topic.discussion_entries.create!(:user => @student, :message => "new side comment #{i} from student", :parent_entry => @entry) }
        get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
        wait_for_ajax_requests

        ff('.discussion-entries .entry').count.should == (side_comment_number + 1) # +1 because of the initial entry
        DiscussionEntry.last.depth.should == 2
      end

      it "should delete a side comment" do
        pending("intermittently fails")
        entry = @topic.discussion_entries.create!(:user => @student, :message => "new side comment from student", :parent_entry => @entry)
        get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
        wait_for_ajax_requests

        delete_entry(entry)
      end

      it "should edit a side comment" do
        edit_text = 'this has been edited '
        entry = @topic.discussion_entries.create!(:user => @student, :message => "new side comment from student", :parent_entry => @entry)
        get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
        wait_for_ajax_requests
        wait_for_js

        edit_entry(entry, edit_text)
      end
    end
  end

  context "marking as read" do
    it "should mark things as read" do
      pending "figure out delayed jobs"
      reply_count = 3
      course_with_teacher_logged_in
      @topic = @course.discussion_topics.create!
      reply_count.times { @topic.discussion_entries.create!(:message => 'Lorem ipsum dolor sit amet') }

      # make sure everything looks unread
      get("/courses/#{@course.id}/discussion_topics/#{@topic.id}", false)
      ff('.can_be_marked_as_read.unread').length.should eql(reply_count + 1)
      f('.new-and-total-badge .new-items').text.should eql(reply_count.to_s)

      #wait for the discussionEntryReadMarker to run, make sure it marks everything as .just_read
      sleep 2
      ff('.can_be_marked_as_read.unread').should be_empty
      ff('.can_be_marked_as_read.just_read').length.should eql(reply_count + 1)
      f('.new-and-total-badge .new-items').text.should eql('')

      # refresh page and make sure nothing is unread/just_read and everthing is .read
      get("/courses/#{@course.id}/discussion_topics/#{@topic.id}", false)
      ['unread', 'just_read'].each do |state|
        ff(".can_be_marked_as_read.#{state}").should be_empty
      end
      f('.new-and-total-badge .new-items').text.should eql('')
    end
  end
end

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

require File.expand_path(File.dirname(__FILE__) + '/api_spec_helper')

describe UserContent, :type => :integration do
  it "should translate file links to directly-downloadable urls" do
    course_with_teacher(:active_all => true)
    attachment_model
    @assignment = @course.assignments.create!(:title => "first assignment", :description => <<-HTML)
    <p>
      Hello, students.<br>
      This will explain everything: <img src="/courses/#{@course.id}/files/#{@attachment.id}/preview" alt="important">
    </p>
    HTML

    json = api_call(:get,
                    "/api/v1/courses/#{@course.id}/assignments/#{@assignment.id}",
    { :controller => 'assignments_api', :action => 'show',
      :format => 'json', :course_id => @course.id.to_s, :id => @assignment.id.to_s })

    doc = Nokogiri::HTML::DocumentFragment.parse(json['description'])
    doc.at_css('img')['src'].should == "http://www.example.com/files/#{@attachment.id}/download?verifier=#{@attachment.uuid}"
  end

  it "should translate media comment links to embedded video tags" do
    course_with_teacher(:active_all => true)
    attachment_model
    @assignment = @course.assignments.create!(:title => "first assignment", :description => <<-HTML)
    <p>
      Hello, students.<br>
      Watch this awesome video: <a href="/media_objects/qwerty" class="instructure_inline_media_comment video_comment" id="media_comment_qwerty"><img></a>
    </p>
    HTML

    json = api_call(:get,
                    "/api/v1/courses/#{@course.id}/assignments/#{@assignment.id}",
    { :controller => 'assignments_api', :action => 'show',
      :format => 'json', :course_id => @course.id.to_s, :id => @assignment.id.to_s })

    doc = Nokogiri::HTML::DocumentFragment.parse(json['description'])
    video = doc.at_css('video')
    video.should be_present
    video['poster'].should match(%r{http://www.example.com/media_objects/qwerty/thumbnail})
    video['src'].should match(%r{http://www.example.com/courses/#{@course.id}/media_download})
    video['src'].should match(%r{entryId=qwerty})
  end
end


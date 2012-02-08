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

describe ApplicationHelper do
  include ApplicationHelper
  
  context "folders_as_options" do
    before(:each) do
      course_model
      @f = Folder.create!(:name => 'f', :context => @course)
      @f_1 = Folder.create!(:name => 'f_1', :parent_folder => @f, :context => @course)
      @f_2 = Folder.create!(:name => 'f_2', :parent_folder => @f, :context => @course)
      @f_2_1 = Folder.create!(:name => 'f_2_1', :parent_folder => @f_2, :context => @course)
      @f_2_1_1 = Folder.create!(:name => 'f_2_1_1', :parent_folder => @f_2_1, :context => @course)
      @all_folders = [ @f, @f_1, @f_2, @f_2_1, @f_2_1_1 ]
    end
    
    it "should work work recursively" do
      option_string = folders_as_options([@f], :all_folders => @all_folders)
      
      html = Nokogiri::HTML::DocumentFragment.parse("<select>#{option_string}</select>")
      html.css('option').count.should == 5
      html.css('option')[0].text.should == @f.name
      html.css('option')[1].text.should match /^\xC2\xA0\xC2\xA0\xC2\xA0- #{@f_1.name}/
      html.css('option')[4].text.should match /^\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0- #{@f_2_1_1.name}/
    end
    
    it "should limit depth" do
      option_string = folders_as_options([@f], :all_folders => @all_folders, :max_depth => 1)
      
      html = Nokogiri::HTML::DocumentFragment.parse("<select>#{option_string}</select>")
      html.css('option').count.should == 3
      html.css('option')[0].text.should == @f.name
      html.css('option')[1].text.should match /^\xC2\xA0\xC2\xA0\xC2\xA0- #{@f_1.name}/
      html.css('option')[2].text.should match /^\xC2\xA0\xC2\xA0\xC2\xA0- #{@f_2.name}/
    end
    
    it "should work without supplying all folders" do
      option_string = folders_as_options([@f])
      
      html = Nokogiri::HTML::DocumentFragment.parse("<select>#{option_string}</select>")
      html.css('option').count.should == 5
      html.css('option')[0].text.should == @f.name
      html.css('option')[1].text.should match /^\xC2\xA0\xC2\xA0\xC2\xA0- #{@f_1.name}/
      html.css('option')[4].text.should match /^\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0- #{@f_2_1_1.name}/
    end
  end

  it "show_user_create_course_button should work" do
    Account.default.update_attribute(:settings, { :teachers_can_create_courses => true, :students_can_create_courses => true })
    @domain_root_account = Account.default
    show_user_create_course_button(nil).should be_false
    user
    show_user_create_course_button(@user).should be_false
    course_with_teacher
    show_user_create_course_button(@teacher).should be_true
    account_admin_user
    show_user_create_course_button(@admin).should be_true
  end

  describe "tomorrow_at_midnight" do
    it "should always return a time in the future" do
      now = 1.day.from_now.midnight - 5.seconds
      tomorrow_at_midnight.should > now
    end
  end

  describe "cache_if" do
    it "should cache the fragment if the condition is true" do
      enable_cache do
        cache_if(true, "t1", :expires_in => 15.minutes, :no_locale => true) { output_buffer.concat "blargh" }
        @controller.read_fragment("t1").should == "blargh"
      end
    end

    it "should not cache if the condition is false" do
      enable_cache do
        cache_if(false, "t1", :expires_in => 15.minutes, :no_locale => true) { output_buffer.concat "blargh" }
        @controller.read_fragment("t1").should be_nil
      end
    end
  end

  describe "include account js" do
    before do
      @domain_root_account = Account.default
      @site_admin = Account.site_admin
      Account.stubs(:site_admin).returns(@site_admin)
      @settings = { :global_includes => true, :global_javascript => '/path/to/js' }
    end

    context "with no custom js" do
      it "should be empty" do
        include_account_js.should be_nil
      end
    end

    context "with custom js" do
      it "should include account javascript" do
        @domain_root_account.stubs(:settings).returns(@settings)
        output = include_account_js
        output.should have_tag 'script'
        output.should match %r{/path/to/js}
      end

      it "should include site admin javascript" do
        @site_admin.stubs(:settings).returns(@settings)
        output = include_account_js
        output.should have_tag 'script'
        output.should match %r{/path/to/js}
      end

      it "should include both site admin and account javascript" do
        Account.any_instance.stubs(:settings).returns(@settings)
        output = include_account_js
        output.should have_tag 'script'
        output.scan(%r{/path/to/js}).length.should eql 2
      end

      it "should include site admin javascript first" do
        @site_admin.stubs(:settings).returns({ :global_includes => true, :global_javascript => '/path/to/admin/js' })
        @domain_root_account.stubs(:settings).returns(@settings)
        output = include_account_js
        output.scan(%r{/path/to/(admin/)?js})[0].should eql ['admin/']
      end
    end
  end
end

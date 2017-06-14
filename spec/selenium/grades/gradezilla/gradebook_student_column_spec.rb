#
# Copyright (C) 2015 - present Instructure, Inc.
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

require_relative '../../helpers/gradezilla_common'
require_relative '../setup/gradebook_setup'
require_relative '../page_objects/gradezilla_page'

describe "Student column header options" do
  include_context "in-process server selenium tests"
  include GradezillaCommon
  include GradebookSetup

  before(:once) { init_course_with_students(3) }
  before(:each) { user_session(@teacher) }

  context "Display as" do
    before(:each) do
      Gradezilla.visit(@course)
    end

    it "displays student names as First Last", priority: "1", test_id: 3253319 do
      Gradezilla.click_student_menu_display_as('First,Last')
      expect(Gradezilla.fetch_student_names[0]).to eq(@course.students[0].name)
    end

    it "displays student names as Last,First", priority: "2", test_id: 3253320 do
      Gradezilla.click_student_menu_display_as('Last,First')

      student_name = @course.students[0].last_name + ", " + @course.students[0].first_name
      expect(Gradezilla.fetch_student_names[0]).to eq(student_name)
    end

    it "first,last display name persists", priority: "2", test_id: 3253322 do
      Gradezilla.click_student_menu_display_as('Last,First')
      Gradezilla.visit(@course)

      student_name = @course.students[0].last_name + ", " + @course.students[0].first_name
      expect(Gradezilla.fetch_student_names[0]).to eq(student_name)
    end

    it "hides student names with anonymous", priority: "2", test_id: 3253321 do
      Gradezilla.click_student_menu_display_as('Anonymous')
      Gradezilla.visit(@course)

      # the student real name element and "Student"(aka anonymous) are different elements
      # so test to see if the student's real name is empty
      expect(Gradezilla.fetch_student_names[0]).to eq("")
    end
  end

  context "Secondary Info" do
    before(:each) do
      Gradezilla.visit(@course)
    end

    it "hides Secondary info for display as none", priority: "1", test_id: 3253326 do
      Gradezilla.click_student_menu_secondary_info('None')

      expect(Gradezilla.student_column_cell_select(0,0)).not_to contain_css('secondary-info')
    end

    it "persists Secondary info selection", priority: "2", test_id: 3253327 do
      Gradezilla.click_student_menu_secondary_info('None')
      Gradezilla.visit(@course)

      expect(Gradezilla.student_column_cell_select(0,0)).not_to contain_css('secondary-info')
    end

  end
end

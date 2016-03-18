require_relative '../../helpers/gradebook2_common'
require_relative '../../helpers/gradebook2_srgb_common'

describe 'Screenreader Gradebook grading' do
  include_context 'in-process server selenium tests'
  include_context 'srgb_components'
  include_context 'srgb_course'
  include Gradebook2Common
  include Gradebook2SRGBCommon

  let(:course_setup) do
    enroll_teacher_and_students
    assignment_1
    assignment_2
    assignment_3
    assignment_4
    student_submission
  end
  let(:login_to_srgb) do
    user_session(teacher)
    get "/courses/#{test_course.id}/gradebook/change_gradebook_version?version=srgb"
    select_student(student)
  end

  before(:each) do
    course_setup
  end

  context 'in Grades section' do
    before(:each) do
      login_to_srgb
    end

    it 'displays correct Grade for: label on assignments', prority: "1", test_id: 615692 do
      select_assignment(assignment_1)

      expect(grade_for_label).to include_text('Grade for: Points Assignment')
    end

    it 'displays correct Grade for: label on next assignment', prority: "1", test_id: 615953 do
      select_assignment(assignment_1)
      next_assignment_button.click

      expect(grade_for_label).to include_text('Grade for: Percent Assignment')
    end

    it 'displays correct points for graded by Points', priority: "1", test_id: 615695 do
      select_assignment(assignment_1)
      grade_srgb_assignment(main_grade_input, 8)
      tab_out_of_input(main_grade_input)

      expect(main_grade_input).to have_value('8')
    end

    it 'displays correct points for graded by Percent', prority: "1", test_id: 163999 do
      select_assignment(assignment_2)
      grade_srgb_assignment(main_grade_input, 8)
      tab_out_of_input(main_grade_input)

      keep_trying_until do
        expect(main_grade_input).to have_value('80%')
      end
    end

    it 'displays correct points for graded by Complete/Incomplete', priority: "1", test_id: 615694 do
      select_assignment(assignment_3)
      click_option('#student_and_assignment_grade', 'Complete')
      tab_out_of_input(main_grade_input)

      expect(f('#grading div.ember-view')).to include_text('10 out of 10')
    end

    it 'displays correct points for graded by Letter Grade', prority: "1", test_id: 163999 do
      select_assignment(assignment_4)
      grade_srgb_assignment(main_grade_input, 8)
      tab_out_of_input(main_grade_input)

      expect(main_grade_input).to have_value('B-')
    end

    it 'displays submission details modal with correct grade', priority: "2", test_id: 615698 do
      select_assignment(assignment_1)
      grade_srgb_assignment(main_grade_input, 8)
      tab_out_of_input(main_grade_input)
      submission_details_button.click

      keep_trying_until do
        expect(f('.submission_details_dialog .assignment-name')).to include_text(assignment_1.name)
        expect(f('.submission_details_grade_form input')).to have_value('8')
      end
    end

    it 'updates grade in submission details modal', priority: "2", test_id: 949577 do
      select_assignment(assignment_2)
      replace_content(main_grade_input, 8)
      submission_details_button.click

      # change grade from 8 to 10 in the assignment details modal
      details_modal_grade_input = f('.submission_details_grade_form input')
      details_modal_grade_input.clear
      replace_content(details_modal_grade_input, 10)
      fj(".btn:contains('Update Grade')").click
      wait_for_ajaximations

      keep_trying_until do
        expect(main_grade_input).to have_value('100%')
      end
    end
  end

  context 'displays warning' do
    it 'on late submissions', priority: "2", test_id: 615701 do
      login_to_srgb
      select_assignment(assignment_1)
      expect(f('p.late.muted em')).to include_text('This submission was late.')
    end

    it 'on dropped assignments', priority: "2", test_id: 615700 do
      # create an assignment group with drop lowest 1 score rule
      drop_lowest(1)

      # grade a few assignments with one really low grade
      assignment_1.grade_student(student, grade: 3)
      assignment_2.grade_student(student, grade: 10)

      login_to_srgb
      select_assignment(assignment_1)

      # indicates assignment_1 was dropped
      expect(f('.dropped.muted em')).to include_text('This grade is currently dropped for this student.')
    end

    it 'on resubmitted assignments', priority: "2", test_id: 164000 do
      # grade assignment
      assignment_1.grade_student(student, grade: 8)

      # resubmit as student
      Timecop.travel(1.hour.from_now) do
        assignment_1.submit_homework(
          student,
          submission_type: 'online_text_entry',
          body: 're-submitting!'
        )
      end

      login_to_srgb
      select_assignment(assignment_1)

      # indicates assignment_1 was resubmitted
      expect(f('.resubmitted.muted em')).to include_text('This assignment has been resubmitted')

      # grade the assignment again
      grade_srgb_assignment(main_grade_input, 10)
      tab_out_of_input(main_grade_input)

      # warning should be removed
      expect(f('.resubmitted.muted em')).to be_nil
    end
  end
end
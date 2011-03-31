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
module Canvas::CC
  module QTI
    module QTIItems
      
      CC_SUPPORTED_TYPES = ['multiple_choice_question',
                            'multiple_answers_question', 
                            'true_false_question',
                            'short_answer_question',
                            'essay_question']
      
      CC_TYPE_PROFILES = {
              'multiple_choice_question' => 'cc.multiple_choice.v0p1',
              'multiple_answers_question' => 'cc.multiple_response.v0p1',
              'true_false_question' => 'cc.true_false.v0p1',
              'short_answer_question' => 'cc.fib.v0p1',
              'essay_question' => 'cc.essay.v0p1'
      }

      TYPE_PROFILES = {
              "multiple_choice_question" => 'multiple_choice',
              "multiple_answers_question" => 'multiple_answers',
              "true_false_question" => 'true_false',
              "short_answer_question" => 'short_answer',
              "essay_question" => 'essay',
              "matching_question" => 'matching',
              "missing_word_question" => 'multiple_dropdowns',
              "multiple_dropdowns_question" => 'multiple_dropdowns',
              "fill_in_multiple_blanks_question" => 'fill_in_multiple_blanks',
              "numerical_question" => 'numerical',
              "calculated_question" => 'calculated',
              "text_only_question" => 'text_only'
      }
      
      # These types don't stop processing response conditions once the correct
      # answer is found, so they need to show the incorrect response differently
      NO_INCORRECT_COND = ['matching_question', 
                           'multiple_dropdowns_question', 
                           'fill_in_multiple_blanks_question']

      # if the question is a supported CC type it will be added
      # it it's not supported it's just skipped
      # returns boolean - whether the question was added
      def add_cc_question(node, question)
        return false unless CC_SUPPORTED_TYPES.member?(question['question_type'])
        add_question(node, question, true)
        true
      end
      
      def add_question(node, question, for_cc=false)
        question['migration_id'] = create_key("assessment_question_#{question['assessment_question_id']}")
        node.item(
                :ident => question['migration_id'],
                :title => question['name']
        ) do |item_node|
          item_node.itemmetadata do |meta_node|
            meta_node.qtimetadata do |qm_node|
              if for_cc
                meta_field(qm_node, 'cc_profile', CC_TYPE_PROFILES[question['question_type']])
              else
                meta_field(qm_node, 'question_type', TYPE_PROFILES[question['question_type']])
                meta_field(qm_node, 'points_possible', question['points_possible'])
                #todo other canvas-metadata
              end
            end
          end # meta data
          
          item_node.presentation do |pres_node|
            pres_node.material do |mat_node|
              html = CCHelper.html_content(question['question_text'] || '', @course, @manifest.exporter.user)
              mat_node.mattext html, :texttype=>'text/html'
            end
            presentation_options(pres_node, question)
          end # presentation
          
          item_node.resprocessing do |res_node|
            res_node.outcomes do |out_node|
              out_node.decvar(
                      :maxvalue => '100',
                      :minvalue => '0',
                      :varname => 'SCORE',
                      :vartype => 'Decimal'
              )
            end
            resprocessing(res_node, question)
          end # resprocessing
          
          item_feedback(item_node, 'general_fb', question['neutral_comments']) unless question['neutral_comments'].blank?
          item_feedback(item_node, 'correct_fb', question['correct_comments']) unless question['correct_comments'].blank?
          item_feedback(item_node, 'general_incorrect_fb', question['incorrect_comments']) unless question['incorrect_comments'].blank?
          question['answers'].each do |answer|
            unless answer['comments'].blank?
              item_feedback(item_node, "#{answer['id']}_fb", answer['comments'])
            end
          end
          
        end # item
      end
      
      ## question response_str methods
      
      def presentation_options(node, question)
        if ['multiple_choice_question', 'true_false_question', 'multiple_answers_question'].member? question['question_type']
          multiple_choice_response_str(node, question)
        elsif ['short_answer_question', 'essay_question'].member? question['question_type']
          short_answer_response_str(node, question)
        elsif question['question_type'] == 'matching_question'
          matching_response_lid(node, question)
        elsif question['question_type'] == 'missing_word_question'
          missing_word_response_lid(node, question)
        elsif question['question_type'] == 'multiple_dropdowns_question'
          multiple_dropdowns_response_lid(node, question)
        elsif question['question_type'] == 'fill_in_multiple_blanks_question'
          multiple_dropdowns_response_lid(node, question)
        end
      end
      
      def multiple_choice_response_str(node, question)
        card = question['question_type'] == 'multiple_answers_question' ? 'Multiple' : 'Single'
        node.response_lid(
                :ident => "response1",
                :rcardinality => card
        ) do |r_node|
          r_node.render_choice do |rc_node|
            question['answers'].each do |answer|
              rc_node.response_label(
                      :ident => answer['id']
              ) do |rl_node|
                rl_node.material do |mat_node|
                  mat_node.mattext answer['text']
                end # mat_node
              end # rl_node
            end
          end # rc_node
        end
      end
      
      def matching_response_lid(node, question)
        question['answers'].each do |answer|
          node.response_lid(:ident=>"response_#{answer['id']}") do |lid_node|
            lid_node.material do |mat_node|
              mat_node.mattext answer['text']
            end
            
            lid_node.render_choice do |rc_node|
              question['matches'].each do |match|
                rc_node.response_label(:ident=>match['match_id']) do |r_node|
                  r_node.material do |mat_node|
                    mat_node.mattext match['text']
                  end
                end #r_node
              end
            end #rc_node
          end #lid_node
        end
      end
      
      def short_answer_response_str(node, question)
        node.response_str(
                :ident => "response1",
                :rcardinality => 'Single'
        ) do |r_node|
          r_node.render_fib {|n| n.response_label(:ident=>'answer1', :rshuffle=>'No')}
        end
      end
      
      def missing_word_response_lid(node, question)
        # Convert this to a multiple_dropdowns_question then send it on its way
        question['question_text'] = "#{question['question_text']} [drop1] #{question['text_after_answers']}"
        question['answers'].each do |answer|
          answer['blank_id'] = 'drop1'
        end
        question['question_type'] = 'multiple_dropdowns_question'
        
        multiple_dropdowns_response_lid(node, question)
      end
      
      def multiple_dropdowns_response_lid(node, question)
        groups = question['answers'].group_by{|a|a[:blank_id]}
        
        groups.each_pair do |id, answers|
          node.response_lid(:ident=>"response_#{id}") do |lid_node|
            lid_node.material do |mat_node|
              mat_node.mattext id
            end
            lid_node.render_choice do |rc_node|
              answers.each do |answer|
                rc_node.response_label(:ident=>answer['id']) do |r_node|
                  r_node.material do |mat_node|
                    mat_node.mattext answer['text']
                  end
                end # r_node
              end
            end # rc_node
          end # lid_node
        end
      end

      ## question resprocessing methods
      
      def resprocessing(node, question)
        if !question['neutral_comments'].blank?
          other_respcondition(node, 'Yes', 'general_fb')
        end
        
        unless question['question_type'] == 'matching_question'
          answer_feedback_respconditions(node, question)
        end
        
        # question type specific resprocessing
        if ['multiple_choice_question', 'true_false_question'].member? question['question_type']
          multiple_choice_resprocessing(node, question)
        elsif question['question_type'] == 'multiple_answers_question'
          multiple_answers_resprocessing(node, question)
        elsif question['question_type'] == 'short_answer_question'
          short_answer_resprocessing(node, question)
        elsif question['question_type'] == 'essay_question'
          essay_resprocessing(node, question)
        elsif question['question_type'] == 'matching_question'
          matching_resprocessing(node, question)
        elsif question['question_type'] == 'multiple_dropdowns_question'
          multiple_dropdowns_resprocessing(node, question)
        elsif question['question_type'] == 'fill_in_multiple_blanks_question'
          multiple_dropdowns_resprocessing(node, question)
        end
        
        if !question['incorrect_comments'].blank? && !NO_INCORRECT_COND.member?(question['question_type'])
          other_respcondition(node, 'Yes', 'general_incorrect_fb')
        end
      end
      
      def multiple_choice_resprocessing(node, question)
        correct_id = nil
        correct_answer = question['answers'].find{|a|a['weight'] > 0}
        correct_id = correct_answer['id'] if correct_answer
        node.respcondition(:continue=>'No') do |res_node|
          res_node.conditionvar do |c_node|
            c_node.varequal correct_id, :respident=>"response1"
          end #c_node
          res_node.setvar '100', :action => 'Set', :varname => 'SCORE'
          correct_feedback_ref(res_node, question)
        end #res_node
      end
      
      def multiple_answers_resprocessing(node, question)
        node.respcondition(:continue=>'No') do |res_node|
          res_node.conditionvar do |c_node|
            c_node.and do |and_node|
              # The CC implementation guide says the 'and' isn't needed but it doesn't validate without it.
              question['answers'].each do |answer|
                if answer['weight'] > 0
                  and_node.varequal answer['id'], :respident=>"response1"
                else
                  and_node.not do |not_node|
                    not_node.varequal answer['id'], :respident=>"response1"
                  end
                end
              end
            end
          end #c_node
          res_node.setvar '100', :action => 'Set', :varname => 'SCORE'
          correct_feedback_ref(res_node, question)
        end #res_node
      end
      
      def short_answer_resprocessing(node, question)
        node.respcondition(:continue=>'No') do |res_node|
          res_node.conditionvar do |c_node|
            question['answers'].each do |answer|
              c_node.varequal answer['text'], :respident=>"response1"
            end
          end #c_node
          res_node.setvar '100', :action => 'Set', :varname => 'SCORE'
          correct_feedback_ref(res_node, question)
        end #res_node
      end
      
      def essay_resprocessing(node, question)
        other_respcondition(node)
      end
      
      def matching_resprocessing(node, question)
        return nil unless question['answers'] && question['answers'].count > 0
        
        correct_points = 100.0 / question['answers'].count
        correct_points = "%.2f" % correct_points
        
        question['answers'].each do |answer|
          node.respcondition do |r_node|
            r_node.conditionvar do |c_node|
              c_node.varequal(answer['match_id'], :respident=>"response_#{answer['id']}")
            end
            r_node.setvar(correct_points, :varname => 'SCORE', :action => 'Add')
          end
          
          unless answer['comments'].blank?
            node.respcondition do |r_node|
              r_node.conditionvar do |c_node|
                c_node.not do |n_node|
                  c_node.varequal(answer['match_id'], :respident=>"response_#{answer['id']}")
                end
              end
              r_node.displayfeedback(:feedbacktype=>'Response', :linkrefid=>"#{answer['id']}_fb")
            end
          end
        end
      end
      
      def multiple_dropdowns_resprocessing(node, question)
        groups = question['answers'].group_by{|a|a[:blank_id]}
        correct_points = 100.0 / groups.length
        correct_points = "%.2f" % correct_points
        
        groups.each_pair do |id, answers|
          answer = answers.find{|a| a['weight'] > 0}
          node.respcondition do |r_node|
            r_node.conditionvar do |c_node|
              c_node.varequal(answer['id'], :respident=>"response_#{id}")
            end
            r_node.setvar(correct_points, :varname => 'SCORE', :action => 'Add')
          end
        end
        
      end
      
      # feedback helpers
      
      def answer_feedback_respconditions(node, question)
        question['answers'].each do |answer|
          unless answer['comments'].blank?
            respident = 'response1'
            if NO_INCORRECT_COND.member? question['question_type']
              respident = "response_#{answer['blank_id']}"
            end
            node.respcondition(:continue=>'Yes') do |res_node|
              res_node.conditionvar do |c_node|
                c_node.varequal answer['id'], :respident=>respident
              end #c_node
              node.displayfeedback(:feedbacktype=>'Response', :linkrefid=>"#{answer['id']}_fb")
            end
          end
        end
      end
      
      def other_respcondition(node, continue='No', feedback_ref=nil)
        node.respcondition(:continue=>continue) do |res_node|
          res_node.conditionvar do |c_node|
            c_node.other
          end #c_node
          res_node.displayfeedback(:feedbacktype=>'Response', :linkrefid=>feedback_ref) if feedback_ref
        end #res_node
      end
      
      def correct_feedback_ref(node, question)
        unless question['correct_comments'].blank?
          node.displayfeedback(:feedbacktype=>'Response', :linkrefid=>'correct_fb')
        end
      end
      
      def item_feedback(node, id, message)
        node.itemfeedback(:ident=>id) do |f_node|
          f_node.flow_mat do |flow_node|
            flow_node.material do |m_node|
              m_node.mattext(message, :texttype=>'text')
            end
          end
        end
      end
      
    end
  end
end

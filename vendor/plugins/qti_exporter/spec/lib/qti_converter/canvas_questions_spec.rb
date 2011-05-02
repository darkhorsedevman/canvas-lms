require File.dirname(__FILE__) + '/../../qti_helper'

describe "Converting Canvas QTI" do
  it "should convert multiple choice" do
    manifest_node=get_manifest_node('multiple_choice')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash[:answers].each { |a| a.delete(:id) }
    hash.should == CanvasExpected::MULTIPLE_CHOICE
  end
  
  it "should convert true false" do
    manifest_node=get_manifest_node('true_false')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash[:answers].each { |a| a.delete(:id) }
    hash.should == CanvasExpected::TRUE_FALSE
  end
  
  it "should convert multiple answers" do
    manifest_node=get_manifest_node('multiple_answers')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash[:answers].each { |a| a.delete(:id) }
    hash.should == CanvasExpected::MULTIPLE_ANSWERS
  end
  
  it "should convert essays" do
    manifest_node=get_manifest_node('essay')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash.should == CanvasExpected::ESSAY
  end
  
  it "should convert short answer" do
    manifest_node=get_manifest_node('short_answer')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash[:answers].each { |a| a.delete(:id) }
    hash.should == CanvasExpected::SHORT_ANSWER
  end
  
  it "should convert text only questions" do
    manifest_node=get_manifest_node('text_only')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash.should == CanvasExpected::TEXT_ONLY
  end
  
  it "should convert fill in multiple blanks questions" do
    manifest_node=get_manifest_node('fimb', :question_type=>'fill_in_multiple_blanks_question')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash[:answers].each { |a| a.delete(:id) }
    hash.should == CanvasExpected::FIMB
  end
  
  it "should convert fill in multiple drop downs questions" do
    manifest_node=get_manifest_node('multiple_dropdowns', :question_type=>'multiple_dropdowns_question')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash[:answers].each { |a| a.delete(:id) }
    hash.should == CanvasExpected::MULTIPLE_DROP_DOWNS
  end
  
  it "should convert matching questions" do
    manifest_node=get_manifest_node('matching', :question_type=>'matching_question')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash[:answers].each { |a| a.delete(:id) }
    hash.should == CanvasExpected::MATCHING
  end
  
  it "should convert calculated questions (simple)" do
    manifest_node=get_manifest_node('calculated_simple', :question_type=>'calculated_question', :interaction_type => 'extendedTextInteraction')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash[:answers].each { |a| a.delete(:id) }
    hash.should == CanvasExpected::CALCULATED_SIMPLE
  end
  
  it "should convert calculated questions (complex)" do
    manifest_node=get_manifest_node('calculated', :question_type=>'calculated_question', :interaction_type => 'extendedTextInteraction')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash[:answers].each { |a| a.delete(:id) }
    hash.should == CanvasExpected::CALCULATED_COMPLEX
  end
  
  it "should convert numerical questions" do
    manifest_node=get_manifest_node('numerical', :question_type=>'numerical_question', :interaction_type => 'extendedTextInteraction')
    hash = Qti::AssessmentItemConverter.create_instructure_question(:manifest_node=>manifest_node, :base_dir=>CANVAS_FIXTURE_DIR)
    hash[:answers].each { |a| a.delete(:id) }
    hash.should == CanvasExpected::NUMERICAL
  end

end

module CanvasExpected
  MULTIPLE_CHOICE = {:correct_comments=> "Good job, you are obviously familiar with: http://www.youtube.com/watch?v=KABUQxllGbk",
                     :answers=>
                             [{:comments=>"You are correct sir.",:weight=>100,:migration_id=>"RESPONSE_7611",:text=>"ole ole ole"},
                              {:weight=>0, :migration_id=>"RESPONSE_6958", :text=>"ole"},
                              {:comments=>"Oh so close.",:weight=>0,:migration_id=>"RESPONSE_5674",:text=>"ole ole"},
                              {:weight=>0, :migration_id=>"RESPONSE_465", :text=>"hoyt"}],
                     :incorrect_comments=>"You need to see this: http://www.youtube.com/watch?v=KABUQxllGbk",
                     :question_type=>"multiple_choice_question",
                     :question_name=>"Oi!",
                     :points_possible=>10.3,
                     :migration_id=>"if87ef626591c52375b6a4f16cdab8bd0",
                     :question_text=>"Ole"}

  TRUE_FALSE = {:points_possible=>10,
                :question_text=>"Generating QTI is \n<strong>super</strong> awesome!",
                :answers=>
                        [{:weight=>0, :migration_id=>"RESPONSE_5309", :text=>"True"},
                         {:comments=>"You're an idiot.", :weight=>100, :migration_id=>"RESPONSE_239",:text=>"False"}],
                :migration_id=>"ic4fa222080e0acadc1a93a1b847fadab",
                :incorrect_comments=>"",
                :question_type=>"true_false_question",
                :correct_comments=>"",
                :question_name=>"true false"}

  MULTIPLE_ANSWERS = {:correct_comments=>"",
                      :question_name=>"Multiple Answers",
                      :points_possible=>0.24,
                      :answers=>
                              [{:comments=>"What does it mean to have this feedback?",
                                :weight=>100,
                                :migration_id=>"RESPONSE_1702",
                                :text=>"Great idea"},
                               {:comments=>"I don't know!",
                                :weight=>100,
                                :migration_id=>"RESPONSE_6878",
                                :text=>"I'll do that!"},
                               {:comments=>"baby.",
                                :weight=>0,
                                :migration_id=>"RESPONSE_491",
                                :text=>"Now way! every 0.24 points counts."}],
                      :question_text=>"this question isn't even worth a whole point. Just skip it.",
                      :migration_id=>"iba79d2c5133c7e82f451eee0fda14079",
                      :incorrect_comments=>"",
                      :question_type=>"multiple_answers_question"}

  ESSAY = {:neutral_comments=>"You're wrong.",
           :question_type=>"essay_question",
           :correct_comments=>"",
           :question_name=>"essay",
           :answers=>[],
           :points_possible=>6,
           :question_text=>"Why do we have so many types now‽ &lt;-- unicode character, you're screwed!",
           :migration_id=>"id79fb07bfd06d28f0c92a599116244f1",
           :incorrect_comments=>""}
  
  SHORT_ANSWER = {:incorrect_comments=>"Incorrect overall feedback",
                  :question_type=>"short_answer_question",
                  :answers=>
                          [{:comments=>"", :weight=>100, :text=>"short answer", :comments=>"correct feedback"},
                           {:comments=>"", :weight=>100, :text=>"Something else", :comments=>"I guess that's technically true, but it's still wrong."}],
                  :correct_comments=>"Correct overall Feedback",
                  :question_name=>"FIB",
                  :points_possible=>19,
                  :question_text=>"By fill in the blank I of course mean...",
                  :migration_id=>"i8f5b9eafaa4800498f65343bba531038"}

  TEXT_ONLY = {:question_text=>"This is just a text area for stuff.",
               :migration_id=>"if47b767d37e06559ff801f2d253307ba",
               :incorrect_comments=>"",
               :answers=>[],
               :question_type=>"text_only_question",
               :correct_comments=>"",
               :question_name=>"Intermission",
               :points_possible=>0}

  FIMB = {:points_possible=>10.23,
          :question_text=>
                  "You have so many [problems] that I don't even know where to [begin] to fix them. You just need to give up and become a [something].",
          :answers=>
                  [{:comments=>"you have problems.",
                    :blank_id=>"problems",
                    :weight=>100,
                    :text=>"problems"},
                   {:comments=>"what, feedback here! that's just mean.",
                    :blank_id=>"begin",
                    :weight=>100,
                    :text=>"begin"},
                   {:comments=>"I would have preferred \"begin\" but this is okay too.",
                    :blank_id=>"begin",
                    :weight=>100,
                    :text=>"start"},
                   {:blank_id=>"something", :weight=>100, :text=>"something"},
                   {:blank_id=>"something", :weight=>100, :text=>"anything"}],
          :migration_id=>"i75996dc02b46cf432bc285f6ced9027b",
          :incorrect_comments=>"Hoyt!",
          :question_type=>"fill_in_multiple_blanks_question",
          :question_name=>"FIMB",
          :correct_comments=>"Oi!"}

  MATCHING = {:question_name=>"Match",
              :matches=>
                      [{:match_id=>4835, :text=>"a"},
                       {:match_id=>6247, :text=>"b"},
                       {:match_id=>5114, :text=>"c"},
                       {:match_id=>2840, :text=>"d"},
                       {:match_id=>9143, :text=>"e"},
                       {:match_id=>8466, :text=>"f"},
                       {:match_id=>6268, :text=>"g"}],
              :correct_comments=>"You did okay",
              :points_possible=>1,
              :answers=>
                      [{:right=>"a",
                        :comments=>"How could you get this wrong!?",
                        :match_id=>4835,
                        :text=>"1"},
                       {:right=>"b", :match_id=>6247, :text=>"2"},
                       {:right=>"c", :match_id=>5114, :text=>"3"},
                       {:right=>"d",
                        :comments=>"This one? You're so stupid",
                        :match_id=>2840,
                        :text=>"4"}],
              :question_text=>"Make it stop! Please!",
              :migration_id=>"i27a2844e09afc2eb6e4a6bf0599bf010",
              :assessment_question_migration_id=>"i7ee7c77592c6cd4ac58509c3e41dace8",
              :question_type=>"matching_question",
              :incorrect_comments=>"How could you get this wrong?"}
  
  MULTIPLE_DROP_DOWNS = {:question_type=>"multiple_dropdowns_question",
                         :migration_id=>"i36799979e4e9ad1be11a85889095e11c",
                         :incorrect_comments=>"",
                         :question_name=>"Multiple droppers",
                         :correct_comments=>"",
                         :answers=>
                                 [{:weight=>100, :blank_id=>"number2", :text=>"1"},
                                  {:weight=>0, :blank_id=>"number2", :text=>"2"},
                                  {:weight=>100, :blank_id=>"thisone", :text=>"72394"},
                                  {:weight=>0, :blank_id=>"thisone", :text=>"3"},
                                  {:weight=>100,
                                   :blank_id=>"number1tobemean",
                                   :comments=>"nice job",
                                   :text=>"1"},
                                  {:weight=>0,
                                   :blank_id=>"number1tobemean",
                                   :comments=>"you're so stupid.",
                                   :text=>"2"}],
                         :points_possible=>1,
                         :question_text=>
                                 "Select 1 from [number1tobemean], and 2 from [number2], and 72394 from [thisone]."}

  CALCULATED_SIMPLE = {:answer_tolerance=>0.01,
                       :correct_comments=>"",
                       :question_type=>"calculated_question",
                       :points_possible=>3,
                       :formula_decimal_places=>2,
                       :question_text=>"1+[x]",
                       :migration_id=>"i142fdc979baef6a8b5bc4168cb614423",
                       :imported_formula=>"1   x",
                       :variables=>[{:min=>1, :scale=>2, :max=>10, :name=>"x"}],
                       :answers=>
                               [{:answer=>10.84, :weight=>100, :variables=>[{:value=>9.84, :name=>"x"}]},
                                {:answer=>9.21, :weight=>100, :variables=>[{:value=>8.21, :name=>"x"}]},
                                {:answer=>9.57, :weight=>100, :variables=>[{:value=>8.57, :name=>"x"}]},
                                {:answer=>10.72, :weight=>100, :variables=>[{:value=>9.72, :name=>"x"}]},
                                {:answer=>10.2, :weight=>100, :variables=>[{:value=>9.2, :name=>"x"}]},
                                {:answer=>7.4, :weight=>100, :variables=>[{:value=>6.4, :name=>"x"}]},
                                {:answer=>10.18, :weight=>100, :variables=>[{:value=>9.18, :name=>"x"}]},
                                {:answer=>2.76, :weight=>100, :variables=>[{:value=>1.76, :name=>"x"}]},
                                {:answer=>10.52, :weight=>100, :variables=>[{:value=>9.52, :name=>"x"}]},
                                {:answer=>2.44, :weight=>100, :variables=>[{:value=>1.44, :name=>"x"}]}],
                       :incorrect_comments=>"",
                       :formulas=>[{:formula=>"1 + x"}],
                       :question_name=>"Formula question"}
  
  
  CALCULATED_COMPLEX = {:migration_id=>"i0ee13510954fd805d707623ee2c46729",
          :question_type=>"calculated_question",
          :variables=>
                  [{:scale=>2, :min=>1, :max=>10, :name=>"x"},
                   {:scale=>0, :min=>-10, :max=>10, :name=>"y"},
                   {:scale=>3, :min=>1, :max=>10, :name=>"brian"}],
          :incorrect_comments=>"Calculated incorrect. (idiot)",
          :question_name=>"Formula 2",
          :answer_tolerance=>0.1,
          :correct_comments=>"Calculated Correct",
          :formulas=>[{:formula=>"temp = 1 + x"}, {:formula=>"temp + x + y + brian"}],
          :points_possible=>15,
          :answers=>
                  [{:variables=>
                            [{:value=>7.88, :name=>"x"},
                             {:value=>1, :name=>"y"},
                             {:value=>5.566, :name=>"brian"}],
                    :answer=>23.33,
                    :weight=>100},
                   {:variables=>
                            [{:value=>4.71, :name=>"x"},
                             {:value=>8, :name=>"y"},
                             {:value=>6.831, :name=>"brian"}],
                    :answer=>25.25,
                    :weight=>100},
                   {:variables=>
                            [{:value=>1.98, :name=>"x"},
                             {:value=>9, :name=>"y"},
                             {:value=>7.116, :name=>"brian"}],
                    :answer=>21.08,
                    :weight=>100},
                   {:variables=>
                            [{:value=>8.19, :name=>"x"},
                             {:value=>3, :name=>"y"},
                             {:value=>2.923, :name=>"brian"}],
                    :answer=>23.3,
                    :weight=>100},
                   {:variables=>
                            [{:value=>4.45, :name=>"x"},
                             {:value=>4, :name=>"y"},
                             {:value=>5.631, :name=>"brian"}],
                    :answer=>19.53,
                    :weight=>100},
                   {:variables=>
                            [{:value=>6.44, :name=>"x"},
                             {:value=>4, :name=>"y"},
                             {:value=>6.755, :name=>"brian"}],
                    :answer=>24.64,
                    :weight=>100},
                   {:variables=>
                            [{:value=>2.41, :name=>"x"},
                             {:value=>6, :name=>"y"},
                             {:value=>2.35, :name=>"brian"}],
                    :answer=>14.17,
                    :weight=>100},
                   {:variables=>
                            [{:value=>2.33, :name=>"x"},
                             {:value=>2, :name=>"y"},
                             {:value=>6.798, :name=>"brian"}],
                    :answer=>14.46,
                    :weight=>100},
                   {:variables=>
                            [{:value=>1.29, :name=>"x"},
                             {:value=>8, :name=>"y"},
                             {:value=>2.589, :name=>"brian"}],
                    :answer=>14.17,
                    :weight=>100},
                   {:variables=>
                            [{:value=>4.45, :name=>"x"},
                             {:value=>5, :name=>"y"},
                             {:value=>7.926, :name=>"brian"}],
                    :answer=>22.83,
                    :weight=>100}],
          :formula_decimal_places=>2,
          :question_text=>"1 + [x] + [x] + [y] + [brian]",
          :imported_formula=>"temp = 1   x"}
  
  NUMERICAL = {:question_type=>"numerical_question",
               :incorrect_comments=>"So wrong!",
               :question_name=>"Numerical Answer",
               :correct_comments=>"Correct yo!",
               :points_possible=>1,
               :question_text=>"This is just getting annoying. The answer is 10.6652",
               :answers=>
                       [{:margin=>0.5,
                         :comments=>"You got it exactly! Nice.",
                         :numerical_answer_type=>"exact_answer",
                         :weight=>100,
                         :text=>"answer_text",
                         :exact=>10.6652},
                        {:end=>9,
                         :start=>11,
                         :comments=>"I guess I'll take this.",
                         :numerical_answer_type=>"range_answer",
                         :weight=>100,
                         :text=>"answer_text"}],
               :migration_id=>"ic7e7f06a79092f0672f0ee014b709e27"}
end

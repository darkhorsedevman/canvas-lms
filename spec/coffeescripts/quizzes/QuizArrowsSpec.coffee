#
# Copyright (C) 2016 - present Instructure, Inc.
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

define [
  'quiz_arrows'
  'helpers/fakeENV'
], (QuizArrowApplicator, fakeENV) ->

  QUnit.module 'QuizArrowApplicator',
    setup: ->
      fakeENV.setup()
      @arrowApplicator = new QuizArrowApplicator()

    teardown: ->
      fakeENV.teardown()

  test "applies 'correct' and 'incorrect' arrows when the quiz is not a survey", ->
    @spy(@arrowApplicator, 'applyCorrectAndIncorrectArrows')
    ENV.IS_SURVEY = false
    @arrowApplicator.applyArrows()
    ok @arrowApplicator.applyCorrectAndIncorrectArrows.calledOnce

  test "does not apply 'correct' and 'incorrect' arrows when the quiz is a survey", ->
    @spy(@arrowApplicator, 'applyCorrectAndIncorrectArrows')
    ENV.IS_SURVEY = true
    @arrowApplicator.applyArrows()
    ok @arrowApplicator.applyCorrectAndIncorrectArrows.notCalled

#
# Copyright (C) 2018 - present Instructure, Inc.
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

module Factories
  def line_item_model(overrides = {})
    params = {
      score_maximum: 10,
      label: 'Test Line Item',
      assignment: overrides.fetch(
        :assignment,
        assignment_model(
          course: overrides.fetch(:course, course_factory(active_course: true))
        )
      ),
      resource_link: overrides.fetch(
        :resource_link,
        overrides[:with_resource_link] ? resource_link_model : nil
      )
    }.merge(overrides.except!(:assignment, :course, :resource_link, :with_resource_link))
    Lti::LineItem.create!(params)
  end
end

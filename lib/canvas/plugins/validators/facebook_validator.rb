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

module Canvas::Plugins::Validators::FacebookValidator
  def self.validate(settings, plugin_setting)
    if settings.map(&:last).all?(&:blank?)
      {}
    else
      if settings.map(&:last).any?(&:blank?)
        plugin_setting.errors.add_to_base('All fields are required')
        false
      else
        res = Facebook.config_check(settings)
        if res
          plugin_setting.errors.add_to_base(res)
          false
        else
          settings[:disable_ssl] = ['1', true, 'true'].include?(settings[:disable_ssl])
          settings.slice(:app_id, :api_key, :secret, :disable_ssl, :canvas_name)
        end
      end
    end
  end
end
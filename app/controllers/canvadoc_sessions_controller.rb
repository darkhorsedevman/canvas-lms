#
# Copyright (C) 2014 Instructure, Inc.
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
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

class CanvadocSessionsController < ApplicationController
  before_filter :require_user

  def show
    unless Canvas::Security.verify_hmac_sha1(params[:hmac], params[:blob])
      render :text => 'unauthorized', :status => :unauthorized
      return
    end

    blob = JSON.parse(params[:blob])
    attachment = Attachment.find(blob["attachment_id"])

    unless @current_user.global_id == blob["user_id"]
      render :text => 'unauthorized', :status => :unauthorized
      return
    end

    if attachment.canvadocable?
      attachment.submit_to_canvadocs unless attachment.canvadoc_available?
      redirect_to attachment.canvadoc.session_url
    else
      render :text => "Not found", :status => :not_found
    end
  end
end

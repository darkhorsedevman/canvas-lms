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

module Multipart
  # From: http://deftcode.com/code/flickr_upload/multipartpost.rb
  ## Helper class to prepare an HTTP POST request with a file upload
  ## Mostly taken from
  #http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/113774
  ### WAS:
  ## Anything that's broken and wrong probably the fault of Bill Stilwell
  ##(bill@marginalia.org)
  ### NOW:
  ## Everything wrong is due to keith@oreilly.com
  require 'rubygems'
  require 'mime/types'
  require 'net/http'
  require 'cgi'

  class Param
    attr_accessor :k, :v
    def initialize( k, v )
      @k = k
      @v = v
    end

    def to_multipart
      #return "Content-Disposition: form-data; name=\"#{CGI::escape(k)}\"\r\n\r\n#{v}\r\n"
      # Don't escape mine...
      return "Content-Disposition: form-data; name=\"#{k}\"\r\n\r\n#{v}\r\n"
    end
  end

  class FileParam
    attr_accessor :k, :filename, :content
    def initialize( k, filename, content )
      @k = k
      @filename = filename || "file.csv"
      @content = content
    end

    def to_multipart
      #return "Content-Disposition: form-data; name=\"#{CGI::escape(k)}\"; filename=\"#{filename}\"\r\n" + "Content-Transfer-Encoding: binary\r\n" + "Content-Type: #{MIME::Types.type_for(@filename)}\r\n\r\n" + content + "\r\n "
      # Don't escape mine
      return "Content-Disposition: form-data; name=\"#{k}\"; filename=\"#{filename}\"\r\n" + "Content-Transfer-Encoding: binary\r\n" + "Content-Type: #{MIME::Types.type_for(@filename)}\r\n\r\n" + content + "\r\n"
    end
  end
  class MultipartPost
    BOUNDARY = AutoHandle.generate('canvas-rules', 15)
    HEADER = {"Content-type" => "multipart/form-data, boundary=" + BOUNDARY + " "}

    def prepare_query (params)
      fp = []
      creds = params.delete :basic_auth
      if creds
        require 'base64'
        puts creds[:username]
        puts creds[:password]
        puts Base64.encode64("#{creds[:username]}:#{creds[:password]}")
      end
      params.each {|k,v|
        if v.respond_to?(:read)
          fp.push(FileParam.new(k, v.path, v.read))
        else
          fp.push(Param.new(k,v))
        end
      }
      query = fp.collect {|p| "--" + BOUNDARY + "\r\n" + p.to_multipart }.join("") + "--" + BOUNDARY + "--"
      return query, HEADER
    end
  end  
end

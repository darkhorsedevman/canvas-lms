#
# Copyright (C) 2012 Instructure, Inc.
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

# @API Groups
#
# Groups serve as the data for a few different ideas in Canvas.  The first is
# that they can be a community in the canvas network.  The second is that they
# can be organized by students in a course, for study or communication (but not
# grading).  The third is that they can be organized by teachers or account
# administrators for the purpose of projects, assignments, and grading.  This
# last kind of group is always part of a group category, which adds the
# restriction that a user may only be a member of one group per category.
#
# All of these types of groups function similarly, and can be the parent
# context for many other types of functionality and interaction, such as
# collections, discussions, wikis, and shared files.
#
# A Group object looks like:
#
#     !!!javascript
#     {
#       // The ID of the group.
#       id: 17,
#
#       // The display name of the group.
#       name: "Math Group 1",
#
#       // A description of the group. This is plain text.
#       description: null,
#
#       // Whether or not the group is public.  Currently only community groups
#       // can be made public.  Also, once a group has been set to public, it
#       // cannot be changed back to private.
#       is_public: false,
#
#       // How people are allowed to join the group.  For all groups except for
#       // community groups, the user must share the group's parent course or
#       // account.  For student organized or community groups, where a user
#       // can be a member of as many or few as they want, the applicable
#       // levels are "parent_context_auto_join", "parent_context_request", and
#       // "invitation_only".  For class groups, where students are divided up
#       // and should only be part of one group of the category, this value
#       // will always be "invitation_only", and is not relevant.
#       //
#       // * If "parent_context_auto_join", anyone can join and will be
#       //   automatically accepted.
#       // * If "parent_context_request", anyone  can request to join, which
#       //   must be approved by a group moderator.
#       // * If "invitation_only", only those how have received an
#       //   invitation my join the group, by accepting that invitation.
#       join_level: "invitation_only",
#
#       // The number of members currently in the group
#       members_count: 0,
#
#       // The url of the group's avatar
#       avatar_url: "https://<canvas>/files/avatar_image.png",
#
#       // The ID of the group's category.
#       group_category_id: 4,
#     }
#
class GroupsController < ApplicationController
  before_filter :get_context
  before_filter :require_context, :only => [:create_category, :delete_category]

  include Api::V1::Attachment
  include Api::V1::Group

  SETTABLE_GROUP_ATTRIBUTES = %w(name description join_level is_public group_category avatar_attachment)

  def context_group_members
    @group = @context
    if authorized_action(@group, @current_user, :read_roster)
      respond_to do |format|
        format.json { render :json => @group.members_json_cached }
      end
    end
  end

  def unassigned_members
    category = @context.group_categories.find_by_id(params[:category_id])
    return render :json => {}, :status => :not_found unless category
    page = (params[:page] || 1).to_i rescue 1
    if category && !category.student_organized?
      groups = category.groups.active
    else
      groups = []
    end
    users = @context.paginate_users_not_in_groups(groups, page)

    if authorized_action(@context, @current_user, :manage)
      respond_to do |format|
        format.json { render :json => {
          :pages => users.total_pages,
          :current_page => users.current_page,
          :next_page => users.next_page,
          :previous_page => users.previous_page,
          :total_entries => users.total_entries,
          :pagination_html => render_to_string(:partial => 'user_pagination', :locals => { :users => users }),
          :users => users.map { |u| u.group_member_json(@context) }
        } }
      end
    end
  end

  def index
    return context_index if @context
    @groups = @current_user ? @current_user.groups.active : []
  end

  def context_index
    add_crumb (@context.is_a?(Account) ? t('#crumbs.users', "Users") : t('#crumbs.people', "People")), named_context_url(@context, :context_users_url)
    add_crumb t('#crumbs.groups', "Groups"), named_context_url(@context, :context_groups_url)
    @active_tab = @context.is_a?(Account) ? "users" : "people"
    @groups = @context.groups.active
    @categories = @context.group_categories
    group_ids = @groups.map(&:id)

    @user_groups = @current_user.group_memberships_for(@context).select{|g| group_ids.include?(g.id) } if @current_user
    @user_groups ||= []

    @available_groups = (@groups - @user_groups).select{|g| g.can_join?(@current_user) }
    if !@context.grants_right?(@current_user, session, :manage_groups)
      @groups = @user_groups
    end
    # sort by name, but with the student organized category in the back
    @categories = @categories.sort_by{|c| [ (c.student_organized? ? 1 : 0), c.name ] }
    @groups = @groups.sort_by{ |g| [(g.name || '').downcase, g.created_at]  }

    if authorized_action(@context, @current_user, :read_roster)
      respond_to do |format|
        if @context.grants_right?(@current_user, session, :manage_groups)
          format.html { render :action => 'context_manage_groups' }
        else
          format.html { render :action => 'context_groups' }
        end
        format.atom { render :xml => @groups.to_atom.to_xml }
      end
    end
  end

  # @API Get a single group
  #
  # Returns the data for a single group, or a 401 if the caller doesn't have
  # the rights to see it.
  #
  # @example_request
  #     curl https://<canvas>/api/v1/groups/<group_id> \ 
  #          -H 'Authorization: Bearer <token>'
  #
  # @example_response
  #     {
  #       id: 13,
  #       name: "Mary's Group",
  #       description: "A group for my friends",
  #       is_public: false,
  #       join_level: "parent_context_request",
  #       members_count: 3,
  #       avatar_url: "https://<canvas>/files/avatar_image.png",
  #       group_category_id: 2,
  #     },
  def show
    find_group

    # FIXME: do something with this stuff
    respond_to do |format|
      format.html do
        if @group && @group.context
          add_crumb @group.context.short_name, named_context_url(@group.context, :context_url)
          add_crumb @group.short_name, named_context_url(@group, :context_url)
        elsif @group
          add_crumb @group.short_name, named_context_url(@group, :context_url)
        end
        @context = @group
        if @group.deleted? && @group.context
          flash[:notice] = t('notices.already_deleted', "That group has been deleted")
          redirect_to named_context_url(@group.context, :context_url)
          return
        end
        @current_conferences = @group.web_conferences.select{|c| c.active? && c.users.include?(@current_user) } rescue []
        if params[:join] && @group.can_join?(@current_user)
          @group.request_user(@current_user)
          if !@group.grants_right?(@current_user, session, :read)
            render :action => 'membership_pending'
            return
          else
            flash[:notice] = t('notices.welcome', "Welcome to the group %{group_name}!", :group_name => @group.name)
            redirect_to named_context_url(@group.context, :context_groups_url)
            return
          end
        end
        if params[:leave] && @group.can_leave?(@current_user)
          membership = @group.membership_for_user(@current_user)
          if membership
            membership.destroy
            flash[:notice] = t('notices.goodbye', "You have removed yourself from the group %{group_name}.", :group_name => @group.name)
            redirect_to named_context_url(@group.context, :context_groups_url)
            return
          end
        end
        if authorized_action(@group, @current_user, :read)
          if @domain_root_account.show_new_dashboard?
            @use_new_styles = true
            js_env :GROUP_ID => @group.id
            return render :action => :dashboard, :layout => 'new_application'
          else
            @home_page = WikiNamespace.default_for_context(@group).wiki.wiki_page
          end
        end
      end
      format.json do
        if authorized_action(@group, @current_user, :read)
          render :json => group_json(@group, @current_user, session)
        end
      end
    end
  end

  def new
    if authorized_action(@context, @current_user, :manage_groups)
      @group = @context.groups.build
    end
  end

  # @API Create a group
  #
  # Creates a new group. Right now, only community groups can be created
  # through the API.
  #
  # @argument name
  # @argument description
  # @argument is_public
  # @argument join_level
  #
  # @example_request
  #     curl https://<canvas>/api/v1/groups/<group_id> \ 
  #          -F 'name=Math Teachers' \ 
  #          -F 'description=A place to gather resources for our classes.' \ 
  #          -F 'is_public=true' \ 
  #          -F 'join_level=parent_context_auto_join' \ 
  #          -H 'Authorization: Bearer <token>'
  #
  # @example_response
  #     {
  #       id: 25,
  #       name: "Math Teachers",
  #       description: "A place to gather resources for our classes.",
  #       is_public: true,
  #       join_level: "parent_context_auto_join",
  #       members_count: 13,
  #       avatar_url: "https://<canvas>/files/avatar_image.png",
  #       group_category_id: 7
  #     }
  def create
    # only allow community groups from the api right now
    if api_request?
      @context = @domain_root_account
      params[:group_category] = GroupCategory.communities_for(@context)
    elsif params[:group]
      group_category_id = params[:group].delete :group_category_id
      if group_category_id && @context.grants_right?(@current_user, session, :manage_groups)
        group_category = @context.group_categories.find_by_id(group_category_id)
        return render :json => {}, :status => :bad_request unless group_category
        params[:group][:group_category] = group_category
      else
        params[:group][:group_category] = nil
      end
    end

    attrs = api_request? ? params : params[:group]
    @group = @context.groups.new(attrs.slice(*SETTABLE_GROUP_ATTRIBUTES))

    if authorized_action(@group, @current_user, :create)
      respond_to do |format|
        if @group.save
          @group.add_user(@current_user, 'accepted', true) if @group.should_add_creator?
          @group.invitees = params[:invitees]
          flash[:notice] = t('notices.create_success', 'Group was successfully created.')
          format.html { redirect_to group_url(@group) }
          format.json { render :json => group_json(@group, @current_user, session) }
        else
          format.html { render :action => "new" }
          format.json { render :json => @group.errors, :status => :bad_request }
        end
      end
    end
  end

  def edit
    @group = (@context ? @context.groups : Group).find(params[:id])
    @context = @group
    if authorized_action(@group, @current_user, :update)
    end
  end

  # @API Edit a group
  #
  # Modifies an existing group.  Note that to set an avatar image for the
  # group, you must first upload the image file to the group, and the use the
  # id in the response as the argument to this function.  See the
  # {file:file_uploads.html File Upload Documentation} for details on the file
  # upload workflow.
  #
  # @argument name
  # @argument description
  # @argument is_public Currently you cannot set a group back to private once
  #   it has been made public.
  # @argument join_level
  # @argument avatar_id The id of the attachment previously uploaded to the
  #   group that you would like to use as the avatar image for this group.
  #
  # @example_request
  #     curl https://<canvas>/api/v1/groups/<group_id> \ 
  #          -X PUT \ 
  #          -F 'name=Algebra Teachers' \ 
  #          -F 'join_level=parent_context_request' \ 
  #          -H 'Authorization: Bearer <token>'
  #
  # @example_response
  #     {
  #       id: 25,
  #       name: "Algebra Teachers",
  #       description: "A place to gather resources for our classes.",
  #       is_public: true,
  #       join_level: "parent_context_request",
  #       members_count: 13,
  #       avatar_url: "https://<canvas>/files/avatar_image.png",
  #       group_category_id: 7
  #     }
  def update
    find_group
    if !api_request? && params[:group] && params[:group][:group_category_id]
      group_category_id = params[:group].delete :group_category_id
      group_category = @context.group_categories.find_by_id(group_category_id)
      return render :json => {}, :status => :bad_request unless group_category
      params[:group][:group_category] = group_category
    end
    attrs = api_request? ? params : params[:group]

    if avatar_id = (params[:avatar_id] || (params[:group] && params[:group][:avatar_id]))
      attrs[:avatar_attachment] = @group.active_images.find_by_id(avatar_id)
    end

    if authorized_action(@group, @current_user, :update)
      respond_to do |format|
        if @group.update_attributes(attrs.slice(*SETTABLE_GROUP_ATTRIBUTES))
          flash[:notice] = t('notices.update_success', 'Group was successfully updated.')
          format.html { redirect_to group_url(@group) }
          format.json { render :json => group_json(@group, @current_user, session) }
        else
          format.html { render :action => "edit" }
          format.json { render :json => @group.errors, :status => :bad_request }
        end
      end
    end
  end

  # @API Delete a group
  #
  # Deletes a group and removes all members.
  #
  # @example_request
  #     curl https://<canvas>/api/v1/groups/<group_id> \ 
  #          -X DELETE \ 
  #          -H 'Authorization: Bearer <token>'
  #
  # @example_response
  #     {
  #       id: 144,
  #       name: "My Group",
  #       description: null,
  #       is_public: false,
  #       join_level: "invitation_only",
  #       members_count: 0,
  #       avatar_url: "https://<canvas>/files/avatar_image.png",
  #       group_category_id: 9
  #     }
  def destroy
    find_group
    if authorized_action(@group, @current_user, :delete)
      if @group.destroy
        flash[:notice] = t('notices.delete_success', "Group successfully deleted")
        respond_to do |format|
          format.html { redirect_to(dashboard_url) }
          format.json { render :json => group_json(@group, @current_user, session) }
        end
      else
        respond_to do |format|
          format.html { redirect_to(dashboard_url) }
          format.json { render :json => @group.errors, :status => :bad_request }
        end
      end
    end
  end

  def create_category
    if authorized_action(@context, @current_user, :manage_groups)
      @group_category = @context.group_categories.build
      if populate_group_category_from_params
        create_default_groups_in_category
        flash[:notice] = t('notices.create_category_success', 'Category was successfully created.')
        render :json => [@group_category.as_json, @group_category.groups.map{ |g| g.as_json(:include => :users) }].to_json
      end
    end
  end

  def update_category
    if authorized_action(@context, @current_user, :manage_groups)
      @group_category = @context.group_categories.find_by_id(params[:category_id])
      return render(:json => { 'status' => 'not found' }, :status => :not_found) unless @group_category
      return render(:json => { 'status' => 'unauthorized' }, :status => :unauthorized) if @group_category.protected?
      if populate_group_category_from_params
        flash[:notice] = t('notices.update_category_success', 'Category was successfully updated.')
        render :json => @group_category.to_json
      end
    end
  end

  def delete_category
    if authorized_action(@context, @current_user, :manage_groups)
      @group_category = @context.group_categories.find_by_id(params[:category_id])
      return render(:json => { 'status' => 'not found' }, :status => :not_found) unless @group_category
      return render(:json => { 'status' => 'unauthorized' }, :status => :unauthorized) if @group_category.protected?
      if @group_category.destroy
        flash[:notice] = t('notices.delete_category_success', "Category successfully deleted")
        render :json => {:deleted => true}
      else
        render :json => {:deleted => false}
      end
    end
  end

  def add_user
    @group = @context
    if authorized_action(@group, @current_user, :manage)
      @membership = @group.add_user(User.find(params[:user_id]))
      if @membership.valid?
        @group.touch
        render :json => @membership.to_json
      else
        render :json => @membership.errors.to_json, :status => :bad_request
      end
    end
  end

  def remove_user
    @group = @context
    if authorized_action(@group, @current_user, :manage)
      @membership = @group.group_memberships.find_by_user_id(params[:user_id])
      @membership.group_id = nil
      @membership.destroy
      @group.touch
      render :json => @membership.to_json
    end
  end

  def edit
    @group = (@context ? @context.groups : Group).find(params[:id])
    @context = @group
    if authorized_action(@group, @current_user, :update)
    end
  end

  def profile
    @group = Group.find(params[:group_id])
    render :text => @group.name
  end

  def collections
    render :text => "TODO"
  end

  def public_feed
    return unless get_feed_context(:only => [:group])
    feed = Atom::Feed.new do |f|
      f.title = t(:feed_title, "%{course_or_account_name} Feed", :course_or_account_name => @context.full_name)
      f.links << Atom::Link.new(:href => group_url(@context), :rel => 'self')
      f.updated = Time.now
      f.id = group_url(@context)
    end
    @entries = []
    @entries.concat @context.calendar_events.active
    @entries.concat @context.discussion_topics.active
    @entries.concat WikiNamespace.default_for_context(@context).wiki.wiki_pages.select{|p| !p.new_record?}
    @entries = @entries.sort_by{|e| e.updated_at}
    @entries.each do |entry|
      feed.entries << entry.to_atom(:context => @context)
    end
    respond_to do |format|
      format.atom { render :text => feed.to_xml }
    end
  end

  def assign_unassigned_members
    return unless authorized_action(@context, @current_user, :manage_groups)

    # valid category?
    category = @context.group_categories.find_by_id(params[:category_id])
    return render(:json => {}, :status => :not_found) unless category

    # option disabled for student organized groups or section-restricted
    # self-signup groups. (but self-signup is ignored for non-Course groups)
    return render(:json => {}, :status => :bad_request) if category.student_organized?
    return render(:json => {}, :status => :bad_request) if @context.is_a?(Course) && category.restricted_self_signup?

    # do the distribution and note the changes
    groups = category.groups.active
    potential_members = @context.users_not_in_groups(groups)
    memberships = distribute_members_among_groups(potential_members, groups)

    # render the changes
    json = memberships.group_by{ |m| m.group_id }.map do |group_id, new_members|
      { :id => group_id, :new_members => new_members.map{ |m| m.user.group_member_json(@context) } }
    end
    render :json => json
  end

  # @API Upload a file
  #
  # Upload a file to the group.
  #
  # This API endpoint is the first step in uploading a file to a group.
  # See the {file:file_uploads.html File Upload Documentation} for details on
  # the file upload workflow.
  #
  # Only those with the "Manage Files" permission on a group can upload files
  # to the group. By default, this is anybody participating in the
  # group, or any admin over the group.
  def create_file
    @attachment = Attachment.new(:context => @context)
    if authorized_action(@attachment, @current_user, :create)
      api_attachment_preflight(@context, request)
    end
  end

  include Api::V1::StreamItem
  # @API Group activity stream
  # Returns the current user's group-specific activity stream, paginated.
  #
  # For full documentation, see the API documentation for the user activity
  # stream, in the user api.
  def activity_stream
    get_context
    if authorized_action(@context, @current_user, :read)
      api_render_stream_for_contexts([@context], :api_v1_group_activity_stream_url)
    end
  end

  protected

  def find_group
    if api_request?
      @group = Group.active.find(params[:group_id])
    else
      @group = (@context ? @context.groups : Group).find(params[:id])
    end
  end

  def populate_group_category_from_params
    name = params[:category][:name] || @group_category.name
    name = t(:default_category_title, "Study Groups") if name.blank?
    if GroupCategory.protected_name_for_context?(name, @context)
      render :json => { 'category[name]' => t('errors.category_name_reserved', "%{category_name} is a reserved name.", :category_name => name) }, :status => :bad_request
      return false
    elsif @context.group_categories.other_than(@group_category).find_by_name(name)
      render :json => { 'category[name]' => t('errors.category_name_unavailable', "%{category_name} is already in use.", :category_name => name) }, :status => :bad_request
      return false
    end

    enable_self_signup = params[:category][:enable_self_signup] == "1"
    restrict_self_signup = params[:category][:restrict_self_signup] == "1"
    if enable_self_signup && restrict_self_signup && @group_category.has_heterogenous_group?
      render :json => { 'category[restrict_self_signup]' => t('errors.cant_restrict_self_signup', "Can't enable while a mixed-section group exists in the category.") }, :status => :bad_request
      return false
    end

    @group_category.name = name
    @group_category.configure_self_signup(enable_self_signup, restrict_self_signup)
    @group_category.save
  end

  def create_default_groups_in_category
    self_signup = params[:category][:enable_self_signup] == "1"
    distribute_members = !self_signup && params[:category][:split_groups] == "1"
    return unless self_signup || distribute_members
    potential_members = distribute_members ? @context.users_not_in_groups([]) : nil

    count_field = self_signup ? :create_group_count : :split_group_count
    count = params[:category][count_field].to_i
    count = 0 if count < 0
    count = potential_members.length if distribute_members && count > potential_members.length
    return if count.zero?

    # TODO i18n
    group_name = @group_category.name
    group_name = group_name.singularize if I18n.locale == :en
    count.times do |idx|
      @group_category.groups.create(:name => "#{group_name} #{idx + 1}", :context => @context)
    end

    distribute_members_among_groups(potential_members, @group_category.groups) if distribute_members
  end

  def distribute_members_among_groups(members, groups)
    return [] if groups.empty?
    new_memberships = []
    touched_groups = [].to_set

    groups_by_size = {}
    groups.each do |group|
      size = group.users.size
      groups_by_size[size] ||= []
      groups_by_size[size] << group
    end
    smallest_group_size = groups_by_size.keys.min

    members.sort_by{ rand }.each do |member|
      group = groups_by_size[smallest_group_size].first
      membership = group.add_user(member)
      if membership.valid?
        new_memberships << membership
        touched_groups << group.id

        # successfully added member to group, move it to the new size bucket
        groups_by_size[smallest_group_size].shift
        groups_by_size[smallest_group_size + 1] ||= []
        groups_by_size[smallest_group_size + 1] << group

        # was that the last group of that size?
        if groups_by_size[smallest_group_size].empty?
          groups_by_size.delete(smallest_group_size)
          smallest_group_size += 1
        end
      end
    end
    Group.update_all({:updated_at => Time.now.utc}, :id => touched_groups.to_a) unless touched_groups.empty?
    return new_memberships
  end
end

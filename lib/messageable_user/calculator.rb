#
# Copyright (C) 2013 Instructure, Inc.
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

require_dependency 'messageable_user'

class MessageableUser
  class Calculator
    CONTEXT_RECIPIENT = /\A(course|section|group)_(\d+)(_([a-z]+))?\z/
    INDIVIDUAL_RECIPIENT = /\A\d+\z/

    # all work is done within the context of a user. avoid passing it around in
    # every single method call by being an object instead of just a collection
    # of class methods
    def initialize(user)
      @user = user
    end

    # convenience module versions of the primary three methods
    def self.load_messageable_users(viewing_user, target_users, options={})
      new(viewing_user).load_messageable_users(target_users, options)
    end

    def self.load_messageable_user(viewing_user, target_user, options={})
      new(viewing_user).load_messageable_user(target_user, options)
    end

    def self.messageable_users_in_context(viewing_user, asset_string)
      new(viewing_user).messageable_users_in_context(asset_string)
    end

    # Takes a list of Users (or ids, or MessageableUsers) and:
    #
    #  * turns them into MessageableUsers if they weren't already
    #  * bulk loads any common contexts for those MessageableUsers
    #  * filters them to just those actually messageable by the viewing user
    #
    # with the :strict_checks option false (default: true), all provided users
    # will be considered messageable and enrollments in unpublished courses,
    # etc. will be included when determining common contexts. should be used
    # only when loading contexts for users already in a conversation
    #
    # the :admin_context option allows specifying a context (course, section,
    # or group) to look for users in. the viewing user will be treated as
    # having full visibility in that context for the purpose of checking
    # messageability and loading common contexts.
    #
    # the :conversation_id option allows specifying a conversation to look
    # for users in. ignored if the viewing user is not already be a participant
    # in the conversation. any other user participating in that conversation is
    # considered messageable.
    def load_messageable_users(users, options={})
      strict_checks = {:strict_checks => true}.merge(options)[:strict_checks]

      # we can be given user ids, Users (from which we just use the ids), or
      # MessageableUsers. if they're not already MessageableUsers, make them so
      # (and check availability while at it, unless we're skipping that)
      return [] unless users.present?
      unless users.first.is_a?(MessageableUser)
        user_ids = users.first.is_a?(User) ? users.map(&:id) : users
        users = Shard.partition_by_shard(user_ids) do |shard_user_ids|
          MessageableUser.prepped(:strict_checks => strict_checks).
            where(:id => shard_user_ids).all
        end
        return [] unless users
      end

      # interpret admin context, if any
      case options[:admin_context]
      when Course then include_course_id = options[:admin_context].id
      when CourseSection then include_course_id = options[:admin_context].course_id
      when Group then include_group_id = options[:admin_context].id
      end

      # what common courses and groups do they have, if any. if they had some,
      # they're definitely messageable
      other_users = users.reject{ |u| u.id == @user.id }
      if other_users.present?
        load_common_courses_with_users(other_users, include_course_id, strict_checks)
        load_common_groups_with_users(other_users, include_group_id, strict_checks)
      end

      # keep only the ones that look messageable (have a shared context, are
      # self, or share the given conversation)
      if strict_checks
        questionable = users.select do |user|
          !user.common_courses.present? &&
          !user.common_groups.present? &&
          user.id != @user.id
        end

        if questionable.present? && options[:conversation_id].present?
          participants = participants_in_conversation([@user, *questionable], options[:conversation_id].to_i)
          if participants.detect{ |user| user == @user }
            questionable -= participants
          end
        end

        users -= questionable
      end

      users
    end

    # convenience method. as load_messageable_users, but for a single user
    def load_messageable_user(user, options={})
      load_messageable_users([user], options).first
    end

    # find and return all the messageable users in a particular context,
    # specified by an extended asset string (TODO: legacy, should improve
    # interface in the future)
    #
    # the string should be something like 'group_123', 'section_123_students',
    # 'course_123_admins', etc. the third portion of the asset string specifies
    # the types of enrollments to include for course or section contexts; it is
    # ignored for group contexts. the 'admins' enrollment type refers to
    # teachers and tas.
    #
    # NOTE: the common_courses and common_groups of the returned
    # MessageableUser objects will be populated only with the context given.
    # this is by design, and desired behavior for the use case this method is
    # directed at. it may be confusing, however, to those not expecting it.
    def messageable_users_in_context(asset_string)
      return [] unless asset_string.sub(/_all\z/, '') =~ CONTEXT_RECIPIENT

      context_type = $1
      context_id = $2.to_i
      enrollment_type = $4
      if enrollment_type == 'admins'
        enrollment_types = ['TeacherEnrollment','TaEnrollment']
      elsif enrollment_type
        enrollment_types = ["#{enrollment_type.capitalize.singularize}Enrollment"]
      end

      case context_type
      when 'course' then messageable_users_in_course(context_id, enrollment_types)
      when 'section' then messageable_users_in_section(context_id, enrollment_types)
      when 'group' then messageable_users_in_group(context_id)
      else []
      end
    end

    # ==========================  end of public API  ==========================
    # |                                                                       |
    # |  the rest of these methods are to simplify the implementation of the  |
    # |  above, and increase testability. they're not private so that they    |
    # |  can be tested in isolation, but should not be used directly          |
    # |                                                                       |
    # =========================================================================

    # given a list of MessageableUsers, loads the common courses between each
    # of those users and the viewing user into the respective MessageableUser
    # objects.
    #
    # the optional include_course_id lets you treat a specific course as if the
    # viewing user had full visibility in it. (TODO: is this right when
    # include_course_id came from a CourseSection admin_context?)
    #
    # the optional strict_checks parameter (default: true) is passed down to
    # the queried scopes (see enrollment_scope and account_user_scope).
    def load_common_courses_with_users(users, include_course_id=nil, strict_checks=true)
      # with messageability constraints, do I see any of the users in any of my visible
      # courses, and if so with which enrollment type(s)?
      Shard.with_each_shard(@user.associated_shards) do
        if all_courses.present?
          reverse_lookup = users.index_by(&:id)
          user_ids = reverse_lookup.keys
          visible_enrollment_scope(:strict_checks => strict_checks).where(:id => user_ids).each do |user|
            reverse_lookup[user.id].global_common_courses.merge!(user.global_common_courses)
          end
        end
      end

      # skipping messageability constraints, do I see the user in that specific
      # course, and if so with which enrollment type(s)?
      if include_course_id && course = Course.find_by_id(include_course_id)
        missing_users = users.reject{ |user| user.global_common_courses.keys.include?(course.global_id) }
        if missing_user.present?
          course.shard.activate do
            reverse_lookup = missing_users.index_by(&:id)
            missing_user_ids = reverse_lookup.keys
            enrollment_scope(:strict_checks => strict_checks).where(:id => missing_user_ids, 'courses.id' => course.id).each do |user|
              reverse_lookup[user.id].global_common_courses.merge!(user.global_common_courses)
            end
          end
        end
      end

      # do I see the user in any of the accounts I admin, and if so with what
      # primary enrollment type?
      Shard.with_each_shard(@user.associated_shards) do
        if visible_account_ids.present?
          reverse_lookup = users.index_by(&:id)
          user_ids = reverse_lookup.keys
          visible_account_user_scope(:strict_checks => strict_checks).where(:id => user_ids).each do |user|
            reverse_lookup[user.id].global_common_courses.merge!(user.global_common_courses)
          end
        end
      end
    end

    # given a list of MessageableUsers, loads the common groups between each
    # of those users and the viewing user into the respective MessageableUser
    # objects.
    #
    # the optional include_group_id lets you treat a specific group as if the
    # viewing user had full visibility in it.
    #
    # the optional strict_checks parameter (default: true) is passed down to
    # the queried scopes (see group_user_scope).
    def load_common_groups_with_users(users, include_group_id=nil, strict_checks=true)
      # with messageability constraints, do I see the user in any of my visible
      # groups?
      Shard.with_each_shard(@user.associated_shards) do
        if fully_visible_group_ids.present?
          reverse_lookup = users.index_by(&:id)
          user_ids = reverse_lookup.keys
          fully_visible_group_user_scope(:strict_checks => strict_checks).where(:id => user_ids).each do |user|
            reverse_lookup[user.id].global_common_groups.merge!(user.global_common_groups)
          end
        end
      end

      # skipping messageability constraints, do I see the user in that specific
      # group?
      if include_group_id && group = Group.find_by_id(include_group_id)
        missing_users = users.reject{ |user| user.global_common_groups.keys.include?(group.global_id) }
        if missing_users.present?
          group.shard.activate do
            reverse_lookup = missing_users.index_by(&:id)
            missing_user_ids = reverse_lookup.keys
            group_user_scope(:strict_checks => strict_checks).where(:id => missing_user_ids, 'group_memberships.group_id' => group.id).each do |user|
              reverse_lookup[user.id].global_common_groups.merge!(user.global_common_groups)
            end
          end
        end
      end
    end

    # filters the provided list of users to just those that are participants in
    # the conversation
    def participants_in_conversation(users, conversation_id)
      conversation = Conversation.find_by_id(conversation_id)
      return [] unless conversation

      conversation.shard.activate do
        reverse_lookup = users.index_by(&:id)
        user_ids = reverse_lookup.keys
        ConversationParticipant.where(
          :user_id => user_ids,
          :conversation_id => conversation_id
        ).all(:select => 'user_id').map{ |cp| reverse_lookup[cp.user_id] }
      end
    end

    # find and return all the messageable users in a particular course (see
    # messageable_users_in_context). the optional enrollment_type restricts to
    # just users with those enrollments
    #
    # NOTE: the common_courses of the returned MessageableUser objects will be
    # populated only with the course given.
    def messageable_users_in_course(course_id, enrollment_types=nil)
      course = Course.find_by_id(course_id)
      return [] unless course

      course.shard.activate do
        # make sure the course is recognized
        return [] unless course = course_index[course.id]

        scope =
          case course_visibility(course)
          when :full then enrollment_scope.where(full_visibility_clause([course]))
          when :sections then enrollment_scope.where(section_visibility_clause([course]))
          when :restricted then enrollment_scope.where(restricted_visibility_clause([course]))
          end
        scope = scope.where(observer_restriction_clause) if student_courses.present?
        scope = scope.where('enrollments.type' => enrollment_types) if enrollment_types
        scope.all
      end
    end

    # find and return all the messageable users in a particular course section
    # (see messageable_users_in_context). the optional enrollment_type
    # restricts to just users with those enrollments
    #
    # NOTE: the common_courses of the returned MessageableUser objects will be
    # populated only with the course of the given section.
    def messageable_users_in_section(section_id, enrollment_types=nil)
      section = CourseSection.find_by_id(section_id)
      return [] unless section

      section.shard.activate do
        return [] unless course = course_index[section.course_id]
        return [] unless
          fully_visible_courses.include?(course) ||
          section_visible_courses.include?(course) &&
          visible_section_ids_in_courses([course]).include?(section_id)

        scope = enrollment_scope.where('enrollments.course_section_id' => section_id)
        scope = scope.where(observer_restriction_clause) if student_courses.present?
        scope = scope.where('enrollments.type' => enrollment_types) if enrollment_types
        scope.all
      end
    end

    # find and return all the messageable users in a particular group (see
    # messageable_users_in_context).
    #
    # NOTE: the common_courses of the returned MessageableUser objects will be
    # populated only with the group given.
    def messageable_users_in_group(group_id)
      group = Group.find_by_id(group_id)
      return [] unless group

      group.shard.activate do
        if fully_visible_group_ids.include?(group.id)
          group_user_scope.where('group_memberships.group_id' => group.id).all
        elsif section_visible_group_ids.include?(group.id)
          # group.context is guaranteed to be a course from
          # section_visible_courses at this point
          course = course_index[group.context_id]
          scope = enrollment_scope(:common_group_column => group.id, :include_completed => false).where([
            "course_section_id IN (?) AND EXISTS(SELECT 1 FROM group_memberships WHERE user_id=users.id AND group_id=?)",
            visible_section_ids_in_courses([course]), group.id])
          scope = scope.where(observer_restriction_clause) if student_courses.present?
          scope.all
        else
          return []
        end
      end
    end

    # ==========================================
    # |  top-level query construction methods  |
    # ==========================================

    # restricts enrollments to those with extended states (see
    # User.enrollment_conditions) of active, invited, and (conditionally)
    # completed. also universally excludes student view enrollments
    #
    # with the :include_completed option false (default: true), completed
    # enrollments are excluded
    #
    # the :strict_checks option (default: true) is per load_messageable_users
    # and controls the strict_course_state parameter of
    # User.enrollment_conditions.
    def self.enrollment_conditions(options={})
      include_completed = {:include_completed => true}.merge(options)[:include_completed]
      strict_checks = {:strict_checks => true}.merge(options)[:strict_checks]
      states = [:active, :invited]
      states << :completed if include_completed
      state_clauses = states.map{ |state| User.enrollment_conditions(state, strict_checks) }
      "(#{state_clauses.join(' OR ')}) AND enrollments.type != 'StudentViewEnrollment'"
    end

    def base_scope(options={})
      MessageableUser.prepped(options)
    end

    # scopes MessageableUsers via enrollments in courses, setting up the common
    # context fields to produce common_course entries.
    #
    # which columns (or values) specify the course id (default:
    # enrollments.course_id) and enrollment type (default: enrollments.type)
    # for common courses can be overridden by the :common_course_column and
    # :common_role_column options.
    #
    # specifying a column (or value) for :common_group_column (default: none)
    # will add that group to the returned users' common_groups.
    #
    # the :include_completed and :strict_checks options are passed through to
    # enrollment_conditions; see its documentation.
    #
    # additionally, if :strict_checks is false (default: true), all users will
    # be included, not just active users. (see MessageableUser.prepped)
    def enrollment_scope(options={})
      common_context_options = {
        :common_course_column => 'enrollments.course_id',
        :common_role_column => 'enrollments.type'
      }.merge(options.slice(:common_course_column, :common_group_column, :common_role_column, :strict_checks))

      base_scope(common_context_options).scoped(
        :joins => <<-SQL,
          INNER JOIN enrollments ON enrollments.user_id=users.id
          INNER JOIN courses ON courses.id=enrollments.course_id
        SQL
        :conditions => self.class.enrollment_conditions(options.slice(:include_completed, :strict_checks)))
    end

    # further restricts the enrollment scope to users whose enrollment is
    # visible by the viewing user (see visibility_restriction_clause and
    # observer_restriction_clause)
    def visible_enrollment_scope(options={})
      scope = enrollment_scope(options).where(visibility_restriction_clause)
      scope = scope.where(observer_restriction_clause) if student_courses.present?

      # redundant with the visibility_restriction_clause, which is narrower, but
      # helps out the query planner
      scope.where('enrollments.course_id' => all_courses.map(&:id))
    end

    # sql clause to limit an enrollment scope to those in the viewing user's
    # full visiblity courses
    def full_visibility_clause(courses=fully_visible_courses)
      ["course_id IN (?)", courses.map(&:id)]
    end

    # sql clause to limit an enrollment scope to those in the viewing user's
    # sections from his section visibility courses
    def section_visibility_clause(courses=section_visible_courses)
      ["course_section_id IN (?)", visible_section_ids_in_courses(courses)]
    end

    # sql clause to limit an enrollment scope to those enrollments allowed by
    # the viewing user's restricted visibility courses (teachers, tas, and
    # observed students)
    def restricted_visibility_clause(courses=restricted_visibility_courses)
      # TODO: minor bug where if I observer student A in course X and student B in
      # course Y, and student A is enrolled in course Y but I do not observer him
      # in that class, I will still see that enrollment
      [
        "(course_id IN (?) AND (enrollments.type IN ('TeacherEnrollment','TaEnrollment') OR enrollments.user_id IN (?)))",
        courses.map(&:id),
        [@user.id] + observed_student_ids_in_courses(courses)
      ]
    end

    # combine the three course visibility clauses into a sql clause to limit an
    # enrollment scope to any enrollments visible to the viewing user
    def visibility_restriction_clause
      clauses = []
      clauses << full_visibility_clause if fully_visible_courses.present?
      clauses << section_visibility_clause if section_visible_courses.present?
      clauses << restricted_visibility_clause if restricted_visibility_courses.present?
      sql = "(#{clauses.map(&:shift).join(' OR ')})"
      clauses.inject([sql], &:concat)
    end

    # regardless of course visibility level, if the viewing user's best
    # enrollment in a course is as a student, he can't see observers that
    # aren't observing him
    def observer_restriction_clause
      clause = ["courses.id NOT IN (?) OR enrollments.type != 'ObserverEnrollment'", student_courses.map(&:id)]
      if linked_observer_ids.present?
        clause.first << " OR enrollments.user_id IN (?)"
        clause << linked_observer_ids
      end
      clause
    end

    # finds the primary enrollment type of the user across all active courses
    # in the account (user and account from user_account_associations in the
    # outer query). used to fake a common "course" context with that enrollment
    # type in users found via the account roster.
    HIGHEST_ENROLLMENT_SQL = <<-SQL
      (SELECT enrollments.type
      FROM enrollments
      INNER JOIN courses ON courses.id=enrollments.course_id
      INNER JOIN course_account_associations ON
        course_account_associations.course_id=courses.id AND
        course_account_associations.account_id=user_account_associations.account_id
      WHERE enrollments.user_id=user_account_associations.user_id
        AND #{enrollment_conditions(:include_completed => false)}
      ORDER BY #{Enrollment.type_rank_sql}
      LIMIT 1)
    SQL

    # scopes MessageableUsers via associations with accounts, setting up the
    # common context fields to produce fake common_course entries with the
    # primary enrollment type in the account (see above).
    #
    # if :strict_checks is false (default: true), all users will be included,
    # not just active users. (see MessageableUser.prepped)
    def account_user_scope(options={})
      options = {
        :common_course_column => 0,
        :common_role_column => HIGHEST_ENROLLMENT_SQL
      }.merge(options.slice(:strict_checks))

      base_scope(options).scoped(
        :joins => "INNER JOIN user_account_associations ON user_account_associations.user_id=users.id")
    end

    # further restricts the account user scope to users associated with
    # accounts in which I can read the roster (see visible_account_ids).
    def visible_account_user_scope(options={})
      account_user_scope(options).where('user_account_associations.account_id' => visible_account_ids)
    end

    # scopes MessageableUsers via group memberships, setting up the common
    # context fields to produce common_groups entries.
    #
    # if :strict_checks is false (default: true), all users will be included,
    # not just active users. (see MessageableUser.prepped)
    def group_user_scope(options={})
      options = {
        :common_group_column => 'group_id'
      }.merge(options.slice(:strict_checks))

      base_scope(options).scoped(
        :joins => "INNER JOIN group_memberships ON group_memberships.user_id=users.id",
        :conditions => {'group_memberships.workflow_state' => 'accepted'})
    end

    # further restricts the group user scope to users in groups for which I
    # have full visibility (see fully_visible_group_ids).
    def fully_visible_group_user_scope(options={})
      group_user_scope(options).where('group_memberships.group_id' => fully_visible_group_ids)
    end

    # ====================================================================
    # |  uncached utility methods used while populating external caches  |
    # ====================================================================

    def uncached_visible_section_ids
      ids = {}
      section_visible_courses.each do |course|
        ids[course.id] = uncached_visible_section_ids_in_course(course)
      end
      ids
    end

    def uncached_visible_section_ids_in_course(course)
      course.section_visibilities_for(@user).map{ |s| s[:course_section_id] }
    end

    def uncached_observed_student_ids
      ids = {}
      restricted_visibility_courses.each do |course|
        ids[course.id] = uncached_observed_student_ids_in_course(course)
      end
      ids
    end

    # the associated_user_id should be local to the current shard, but only
    # having it in that format and from those enrollments on the current shard
    # is acceptable, as this is specific to a course and the enrollments all
    # live on the same shard as the course
    def uncached_observed_student_ids_in_course(course)
      course.section_visibilities_for(@user).map{ |s| s[:associated_user_id] }.compact
    end

    def uncached_linked_observer_ids
      # because this is a has_many, we can't just rely on Shard.current for id
      # translation magic. we *have* to use with_each_shard... but we're
      # already in a with_each_shard from shard_cached, so we can restrict it
      # to this shard
      @user.observee_enrollments.with_each_shard(Shard.current) do |scope|
        scope.scoped(:include => :user).map{ |e| Shard.global_id_for(e.user_id) }
      end
    end

    def uncached_visible_account_ids
      # ditto
      @user.associated_accounts.with_each_shard(Shard.current).
        select{ |account| account.grants_right?(@user, nil, :read_roster) }.
        map(&:id)
    end

    def uncached_fully_visible_group_ids
      # ditto for current groups
      course_group_ids = uncached_group_ids_in_courses(recent_fully_visible_courses)
      own_group_ids = @user.current_groups.with_each_shard(Shard.current).map(&:id)
      (course_group_ids + own_group_ids).uniq
    end

    def uncached_section_visible_group_ids
      course_group_ids = uncached_group_ids_in_courses(recent_section_visible_courses)
      course_group_ids - fully_visible_group_ids
    end

    def uncached_group_ids_in_courses(courses)
      Group.active.scoped(
        :select => 'id',
        :conditions => {:context_type => 'Course', :context_id => courses.map(&:id)}).map(&:id)
    end

    # ==================================================
    # |  calculations cached externally with sharding  |
    # ==================================================

    # the optional methods list is a list of methods to call (not results of a
    # method call, since if there are multiple we want to distinguish them) to
    # get additional objects to include in the per-shard cache keys
    def shard_cached(key, *methods)
      @shard_caches ||= {}
      @shard_caches[key] ||= 
        begin
          by_shard = {}
          Shard.with_each_shard(@user.associated_shards) do
            shard_key = [@user, 'messageable_user', key]
            methods.each do |method|
              canonical = send(method).cache_key
              shard_key << method
              shard_key << Digest::MD5.hexdigest(canonical)
            end
            by_shard[Shard.current] = Rails.cache.fetch(shard_key.cache_key, :expires_in => 1.day) { yield }
          end
          by_shard
        end
    end

    def all_courses_by_shard
      @all_courses_by_shard ||=
        @user.courses_with_primary_enrollment(:current_and_concluded_courses, nil, :include_completed_courses => true).
        group_by(&:shard)
    end

    def visible_section_ids_by_shard
      shard_cached('visible_section_ids', :section_visible_courses) do
        uncached_visible_section_ids
      end
    end

    def observed_student_ids_by_shard
      shard_cached('observed_student_ids', :restricted_visibility_courses) do
        uncached_observed_student_ids
      end
    end

    # unlike the others, these aren't partitioned by shard; whichever shard
    # you're on, you'll get the full set when you call this method, since these
    # are user ids. but they are cached on the object by shard so that we
    # transpose from global ids to shard relative ids at most once per shard.
    def linked_observer_ids_by_shard
      @global_linked_observer_ids ||=
        begin
          by_shard = shard_cached('linked_observer_ids') do
            uncached_linked_observer_ids
          end
          by_shard.values.flatten.uniq
        end

      @linked_observer_ids_by_shard ||= Hash.new do |hash,shard|
        hash[shard] = []
        Shard.partition_by_shard(@global_linked_observer_ids) do |shard_ids|
          if Shard.current == shard
            hash[shard].concat(shard_ids)
          else
            hash[shard].concat(shard_ids.map{ |id| Shard.global_id_for(id) })
          end
        end
      end
    end

    def visible_account_ids_by_shard
      shard_cached('visible_account_ids') do
        uncached_visible_account_ids
      end
    end

    def fully_visible_group_ids_by_shard
      shard_cached('fully_visible_group_ids', :recent_fully_visible_courses) do
        uncached_fully_visible_group_ids
      end
    end

    def section_visible_group_ids_by_shard
      shard_cached('section_visible_group_ids', :recent_section_visible_courses, :recent_fully_visible_courses) do
        uncached_section_visible_group_ids
      end
    end

    # =======================================================================
    # |  shard-implicit object-cached accessors to the main sharded caches  |
    # =======================================================================

    def all_courses
      all_courses_by_shard[Shard.current] || []
    end

    def course_index
      @course_index_by_shard ||= {}
      @course_index_by_shard[Shard.current] ||= all_courses.index_by(&:id)
    end

    def course_visibility(course)
      @course_visibilities ||= {}
      @course_visibilities[course.global_id] ||= 
        course.enrollment_visibility_level_for(@user, course.section_visibilities_for(@user), true)
    end

    def all_courses_by_visibility(visibility)
      @all_courses_by_visibility_by_shard ||= {}
      @all_courses_by_visibility_by_shard[Shard.current] ||=
        all_courses.group_by{ |course| course_visibility(course) }
      @all_courses_by_visibility_by_shard[Shard.current][visibility] ||= []
    end

    def fully_visible_courses
      all_courses_by_visibility(:full)
    end

    def section_visible_courses
      all_courses_by_visibility(:sections)
    end

    def restricted_visibility_courses
      all_courses_by_visibility(:restricted)
    end

    def recent_courses
      @recent_courses_by_shard ||= {}
      @recent_courses_by_shard[Shard.current] ||=
        all_courses.reject{ |course| course.conclude_at && course.conclude_at < 1.month.ago }
    end

    def recent_courses_by_visibility(visibility)
      @recent_courses_by_visibility_by_shard ||= {}
      @recent_courses_by_visibility_by_shard[Shard.current] ||=
        recent_courses.group_by{ |course| course_visibility(course) }
      @recent_courses_by_visibility_by_shard[Shard.current][visibility] ||= []
    end

    def recent_fully_visible_courses
      recent_courses_by_visibility(:full)
    end

    def recent_section_visible_courses
      recent_courses_by_visibility(:sections)
    end

    def student_courses
      @student_courses_by_shard ||= {}
      @student_courses_by_shard[Shard.current] ||= all_courses.
        select{ |course| course.primary_enrollment == 'StudentEnrollment' }
    end

    def visible_section_ids_in_courses(courses)
      visible_section_ids = visible_section_ids_by_shard[Shard.current] || {}
      visible_section_ids.slice(courses.map(&:id)).values.flatten.uniq
    end

    def observed_student_ids_in_courses(courses)
      observed_student_ids = observed_student_ids_by_shard[Shard.current] || {}
      observed_student_ids.slice(courses.map(&:id)).values.flatten.uniq
    end

    def linked_observer_ids
      linked_observer_ids_by_shard[Shard.current] || []
    end

    def visible_account_ids
      visible_account_ids_by_shard[Shard.current] || []
    end

    def fully_visible_group_ids
      fully_visible_group_ids_by_shard[Shard.current] || []
    end

    def section_visible_group_ids
      section_visible_group_ids_by_shard[Shard.current] || []
    end
  end
end

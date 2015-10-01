define [
  'i18n!calendar'
  'jquery'
  'compiled/util/fcUtil'
  'jquery.ajaxJSON'
  'vendor/jquery.ba-tinypubsub'
], (I18n, $, fcUtil) ->

  class
    readableTypes:
      assignment: I18n.t('event_type.assignment', 'Assignment')
      discussion: I18n.t('event_type.discussion', 'Discussion')
      event: I18n.t('event_type.event', 'Event')
      quiz: I18n.t('event_type.quiz', 'Quiz')

    constructor: (data, contextInfo, actualContextInfo) ->
      @eventType = 'generic'
      @contextInfo = contextInfo
      @actualContextInfo = actualContextInfo
      @allPossibleContexts = null
      @className = []
      @object = {}

      @copyDataFromObject(data)

    isNewEvent: () ->
      @eventType == 'generic' || !@object?.id

    isAppointmentGroupFilledEvent: () ->
      @object?.child_events?.length > 0

    isAppointmentGroupEvent: () ->
      @object?.appointment_group_url

    contextCode: () ->
      @object?.effective_context_code || @object?.context_code || @contextInfo?.asset_string

    isUndated: () ->
      @start == null

    isCompleted: -> false

    displayTimeString: () -> ""
    readableType: () -> ""

    fullDetailsURL: () -> null

    startDate: () -> @originalStart || @date
    endDate: () -> @startDate()

    possibleContexts: () -> @allPossibleContexts || [ @contextInfo ]

    addClass: (newClass) ->
      found = false
      for c in @className
        if c == newClass
          found = true
          break
      if !found then @className.push newClass

    removeClass: (rmClass) ->
      idx = 0
      for c in @className
        if c == rmClass
          @className.splice(idx, 1)
        else
          idx += 1

    save: (params, success, error) ->
      onSuccess = (data) =>
        @copyDataFromObject(data)
        $.publish "CommonEvent/eventSaved", this
        success?()

      onError = (data) =>
        @copyDataFromObject(data)
        $.publish "CommonEvent/eventSaveFailed", this
        error?()

      [ method, url ] = @methodAndURLForSave()

      @forceMinimumDuration() # so short events don't look squished while waiting for ajax
      $.publish "CommonEvent/eventSaving", this
      $.ajaxJSON url, method, params, onSuccess, onError

    isDueAtMidnight: () ->
      @start && (@midnightFudged || (@start.hours() == 23 && @start.minutes() > 30) || (@start.hours() == 0 && @start.minutes() == 0))

    isPast: () ->
      now = $.fullCalendar.moment()
      @start && @start < now

    copyDataFromObject: (data) ->
      @originalStart = fcUtil.clone(@start) if @start
      @midnightFudged = false # clear out cached value because now we have new data
      if @isDueAtMidnight()
        @midnightFudged = true
        @start.minutes(30)
        @start.seconds(0)
        @end = fcUtil.clone(@start) unless @end
      else
        # minimum duration should only be enforced if not due at midnight
        @forceMinimumDuration()

    formatTime: (datetime) ->
      datetime = fcUtil.unwrap(datetime)
      "<time datetime='#{datetime.toISOString()}'>#{$.datetimeString(datetime)}</time>"

    forceMinimumDuration: () ->
      minimumDuration = 30 * 60 * 1000 # 30 minutes
      if @start && @end && (@end - @start) < minimumDuration
        # new date so we don't mutate the original
        @end = fcUtil.clone(@start).add(minimumDuration, "milliseconds")

    assignmentType: () ->
      return if !@assignment
      if @assignment.submission_types?.length
        type = @assignment.submission_types[0]
        if type == 'online_quiz'
          return 'quiz'
        if type == 'discussion_topic'
          return 'discussion'
      return 'assignment'

    iconType: ->
      if type = @assignmentType() then type else 'calendar-month'

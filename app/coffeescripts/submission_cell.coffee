this.SubmissionCell = class SubmissionCell

  tooltipTexts = {}

  constructor: (@opts) ->
    @init()

  init: () ->
    submission = @opts.item[@opts.column.field]
    @$wrapper = $(@cellWrapper('<input class="grade"/>')).appendTo(@opts.container)
    @$input = @$wrapper.find('input').focus().select()

  destroy: () ->
    @$input.remove()

  focus: () ->
    @$input.focus()

  loadValue: () ->
    @val = @opts.item[@opts.column.field].grade || ""
    @$input.val(@val)
    @$input[0].defaultValue = @val
    @$input.select()

  serializeValue: () ->
    @$input.val()


  applyValue: (item, state) ->
    item[@opts.column.field].grade = state
    @wrapper?.remove()
    @postValue(item, state)
    # TODO: move selection down to the next row, same column

  postValue: (item, state) ->
    submission = item[@opts.column.field]
    url = @opts.grid.getOptions().change_grade_url
    url = url.replace(":assignment", submission.assignment_id).replace(":submission", submission.user_id)
    $.ajaxJSON url, "PUT", { "submission[posted_grade]": state }

  isValueChanged: () ->
    @val != @$input.val()

  validate: () ->
    { valid: true, msg: null }

  @formatter: (row, col, submission, assignment) ->
    this.prototype.cellWrapper(submission.grade, {submission: submission, assignment: assignment, editable: false})
    # classes = []
    # "<div class='cell-content gradebook-cell #{classes.join(' ')}'>#{submission.grade}</div>"

  @imageForCell: (image_id) ->
    $(image_id)[0].outerHTML

  cellWrapper: (innerContents, options = {}) ->
    opts = $.extend({}, {
      innerContents: '',
      classes: '',
      editable: true
    }, options)
    opts.submission ||= @opts.item[@opts.column.field]
    opts.assignment ||= @opts.column.object
    specialClasses = SubmissionCell.classesBasedOnSubmission(opts.submission, opts.assignment)
    tooltipText = $.map(specialClasses, (c)->
      tooltipTexts[c] ?= $("#submission_tooltip_#{c}").text()
    ).join(', ')

    """
    <div class="gradebook-cell #{ if opts.editable then 'gradebook-cell-editable focus' else ''} #{opts.classes} #{specialClasses.join(' ')}">
      #{ if tooltipText then '<div class="gradebook-tooltip">'+ tooltipText + '</div>' else ''}
      <a href="#" class="gradebook-cell-comment"><span class="gradebook-cell-comment-label">submission comments</span></a>
      #{innerContents}
    </div>
    """

  @classesBasedOnSubmission: (submission={}, assignment={}) ->
    classes = []
    classes.push('resubmitted') if submission.grade_matches_current_submission == false
    classes.push('late') if assignment.due_at && submission.submitted_at && (submission.submitted_at.timestamp > assignment.due_at.timestamp)
    classes.push('dropped') if submission.drop
    classes

class SubmissionCell.out_of extends SubmissionCell
  init: () ->
    submission = @opts.item[@opts.column.field]
    @$wrapper = $(@cellWrapper("""
      <div class="overflow-wrapper">
        <div class="grade-and-outof-wrapper">
          <input type="number" class="grade"/><span class="outof"><span class="divider">/</span>#{@opts.column.object.points_possible}</span>
        </div>
      </div>
    """, { classes: 'gradebook-cell-out-of-formatter' })).appendTo(@opts.container)
    @$input = @$wrapper.find('input').focus().select()

class SubmissionCell.pass_fail extends SubmissionCell

  states = ['pass', 'fail', '']
  classFromSubmission = (submission) ->
    { pass: 'pass', complete: 'pass', fail: 'fail', incomplete: 'fail' }[submission.grade] || ''

  htmlFromSubmission: (options={}) ->
    cssClass = classFromSubmission(options.submission)
    SubmissionCell::cellWrapper("""
      <a data-value="#{cssClass}" class="gradebook-checkbox gradebook-checkbox-#{cssClass} #{'editable' if options.editable}" href="#">#{cssClass}</a>
    """, options)

  # htmlFromSubmission = (submission, editable = false) ->
  #   cssClass = classFromSubmission(submission)
  #   """
  #   <div class="gradebook-cell #{SubmissionCell.classesBasedOnSubmission(submission).join(' ')}">
  #     <a href="#" class="gradebook-cell-comment"><span class="gradebook-cell-comment-label">submission comments</span></a>
  #     <a data-value="#{cssClass}" class="gradebook-checkbox gradebook-checkbox-#{cssClass} #{'editable' if editable}" href="#">#{cssClass}</a>
  #   </div>
  #   """
  @formatter: (row, col, submission, assignment) ->
    pass_fail::htmlFromSubmission({ submission, assignment, editable: false})


  init: () ->
    @$wrapper = $(@cellWrapper())
    @$wrapper = $(@htmlFromSubmission({
      submission: @opts.item[@opts.column.field],
      assignment: @opts.column.object,
      editable: true})
    ).appendTo(@opts.container)
    @$input = @$wrapper.find('.gradebook-checkbox')
      .bind('click keypress', (event) =>
        event.preventDefault()
        currentValue = @$input.data('value')
        if currentValue is 'pass'
          newValue = 'fail'
        else if currentValue is 'fail'
          newValue = ''
        else
          newValue = 'pass'
        @transitionValue(newValue)
      ).focus()

  destroy: () ->
    @$wrapper.remove()

  focus: () ->
    @$input.focus()

  transitionValue: (newValue) ->
    @$input
      .removeClass('gradebook-checkbox-pass gradebook-checkbox-fail')
      .addClass('gradebook-checkbox-' + classFromSubmission(grade: newValue))
      .data('value', newValue)

  loadValue: () ->
    @val = @opts.item[@opts.column.field].grade || ""


  serializeValue: () ->
    @$input.data('value')

  applyValue: (item, state) ->
    item[@opts.column.field].grade = state
    this.postValue(item, state)
    # TODO: move selection down to the next row, same column

  postValue: (item, state) ->
    submission = item[@opts.column.field]
    url = @opts.grid.getOptions().change_grade_url
    url = url.replace(":assignment", submission.assignment_id).replace(":submission", submission.user_id)
    $.ajaxJSON url, "PUT", { "submission[posted_grade]": state }
    @$input.effect('highlight') #TODO: also highlight the group total and the TotalScore

  isValueChanged: () ->
    @val != @$input.data('value')

class SubmissionCell.points extends SubmissionCell

define [
  'Backbone'
  'underscore'
  'compiled/models/KollectionItem'
  'jst/KollectionItems/LinkDataView'
  'compiled/fn/preventDefault'
], (Backbone, _, KollectionItem, LinkDataViewTemplate, preventDefault) ->

  class LinkDataView extends Backbone.View

    template: LinkDataViewTemplate

    events:
      'click [data-event]' : 'handleClick'

    initialize: ->
      @render()
      @$el.disableWhileLoading @model.fetchLinkData().done(@render)
      @model.on('change', @render)

    render: =>
      locals = @model.toJSON()
      locals.showThumbForwardAndBack = locals.image_url && locals.images?.length > 1
      @$el.html @template locals

      # have to bind these manually and not in events hash because blur doesnt bubble in backbone
      _.each ['title', 'description'], (attribute) =>
        @$(":input.#{attribute}").on 'change blur', (event) =>
          @model.set attribute, event.target.value
          @render()

    prevImage: ->
      @model.changeImage -1

    nextImage: ->
      @model.changeImage 1

    toggleThumbnail: (event) ->
      checked = event.target.checked
      if checked
        @model.set('image_url', false)
      else
        @model.changeImage 0

    editTitle: ->
      @$('.title').hide().filter('input').show().focus()

    editDescription: ->
      @$('.description').hide().filter('textarea').show().focus()

    handleClick: (event) =>
      method = $(event.currentTarget).data 'event'
      preventDefault @[method] arguments...
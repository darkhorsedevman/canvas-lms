import _ from 'underscore'

export const handleActions = (actionHandler, def) => {
  return (state, action) => {
    state = state === undefined ? def : state

    if (actionHandler[action.type]) {
      let stateCopy = state
      if (_.isObject(state)) {
        stateCopy = _.extend({}, state)
      } else if (Array.isArray(state)) {
        stateCopy = state.slice()
      }

      return actionHandler[action.type](stateCopy, action)
    } else {
      return state
    }
  }
}

export const getPayload = (state, action) => action.payload

export const identity = (def = '') => (s, a) => s === undefined ? def : s

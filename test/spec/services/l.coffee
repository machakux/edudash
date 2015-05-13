'use strict'

describe 'Service: L', ->

  # load the service's module
  beforeEach module 'edudashApp'

  # instantiate service
  L = {}
  beforeEach inject (_L_) ->
    L = _L_

#  it 'should do something', ->
#    expect(!!L).toBe true

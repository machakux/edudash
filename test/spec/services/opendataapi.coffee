'use strict'

describe 'Service: OpenDataApi', ->

  # load the service's module
  beforeEach module 'edudashApp'

  # instantiate service
  OpenDataApi = {}
  beforeEach inject (_OpenDataApi_) ->
    OpenDataApi = _OpenDataApi_

  it 'should do something', ->
    expect(!!OpenDataApi).toBe true

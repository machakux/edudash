'use strict'

describe 'Service: CsvParser', ->

  # load the service's module
  beforeEach module 'edudashApp'

  # instantiate service
  CsvParser = {}
  beforeEach inject (_CsvParser_) ->
    CsvParser = _CsvParser_

  it 'should do something', ->
    expect(!!CsvParser).toBe true
